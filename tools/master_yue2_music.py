"""Cut each YuE2 performance on a recurring beat and export the native and web loops."""
import json
import shutil
import subprocess

import numpy as np

from master_expansion_music import ROOT, RATE, decode, encode, features, loudness, sha, tempo


def loop_points(samples, bpm):
    bands, flux, envelope = features(samples)
    pulse = tempo(flux, bpm)
    bands /= np.maximum(bands.std(axis=0), .25)
    onsets = np.flatnonzero((flux[1:-1] > flux[:-2]) & (flux[1:-1] >= flux[2:])) + 1
    onsets = onsets[(onsets > 70) & (onsets < len(bands) - 110)]
    onsets = onsets[flux[onsets] > np.percentile(flux, 68)]
    candidates = []
    for bars in range(16, 49, 4):
        period = 24000 * bars / pulse
        for a in onsets[onsets < len(bands) * .35]:
            for b in onsets[np.abs(onsets - a - period) < 12]:
                if b - a < 6000:
                    continue
                distance = np.mean((bands[a-35:a+45] - bands[b-35:b+45]) ** 2)
                level = abs(np.log((envelope[a:a+40].mean()+1e-5) / (envelope[b:b+40].mean()+1e-5)))
                cost = distance + .5 * level + .025 * abs(b-a-period) + 1.1 * (1-(b-a)/len(bands))
                candidates.append((cost, a, b, bars))
    if not candidates:
        # Ladle Run already ends on the 36th bar. Keep the complete performance
        # and join its short natural decay to the pickup preceding its first beat.
        bars = round(len(samples) / RATE * bpm / 240)
        length = round(bars * 240 * RATE / bpm)
        first = round(.09 * RATE)
        last = min(len(samples)-length, RATE)
        if length < 60*RATE or first > last:
            raise ValueError("No full-length musical loop fits the performance")
        offsets = range(first, last+1, 48)
        a = min(offsets, key=lambda n: np.mean((samples[n-480:n] - samples[n+length-480:n+length])**2))
        return a, a+length, bars, pulse
    _, a, b, bars = min(candidates)
    return a * RATE // 100, b * RATE // 100, bars, pulse


def master(receipt):
    data = json.loads(receipt.read_text())
    name = receipt.stem
    original = receipt.with_suffix(".flac")
    assert sha(original) == data["source_flac_sha256"]
    samples = decode(original)
    a, b, bars, pulse = loop_points(samples, data["bpm"])
    loop = samples[a:b].copy()
    fade = round(.085 * RATE)
    blend = (.5 - .5 * np.cos(np.linspace(0, np.pi, fade)))[:, None]
    loop[-fade:] = loop[-fade:] * (1-blend) + samples[a-fade:a] * blend
    folder = ROOT / "work" / "yue2-masters"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / ".gdignore").touch()
    wav = folder / (name + ".wav")
    encode(wav, loop)
    raw = loudness(wav)
    gain = min(-18.0 - float(raw["input_i"]), -2.5 - float(raw["input_tp"]))
    loop *= 10 ** (gain/20)
    encode(wav, loop)
    native = ROOT / "audio/music" / (name.replace("_", "-") + ".ogg")
    web = ROOT / "docs/game/assets/music" / (name + ".mp3")
    subprocess.run([shutil.which("oggenc"), "-Q", "-q", "6", "-s", str(int(sha(original)[:7], 16)),
                    "-o", str(native), str(wav)], check=True)
    subprocess.run([shutil.which("lame"), "--silent", "-V", "2", str(wav), str(web)], check=True)
    data["loop"] = dict(estimated_bpm=round(pulse, 3), bars=int(bars), start_sample=int(a),
                        end_sample=int(b), sample_rate=RATE, tail_crossfade_ms=85,
                        seconds=round(len(loop)/RATE, 3), gain_db=round(gain, 3))
    for label, path in [("vorbis", native), ("mp3", web)]:
        stats = loudness(path)
        measured = decode(path)
        assert 60 <= len(measured)/RATE <= 120 and float(stats["input_tp"]) < -1
        data["loop"][label] = dict(sha256=sha(path), lufs=float(stats["input_i"]),
                                   peak_dbtp=float(stats["input_tp"]),
                                   seam_step=round(float(np.max(np.abs(measured[0]-measured[-1]))), 5))
    receipt.write_text(json.dumps(data, indent=2) + "\n")
    print(name, data["loop"], flush=True)


if __name__ == "__main__":
    for score in sorted((ROOT / "audio/source/music/yue2").glob("*.abc")):
        master(score.with_suffix(".json"))
