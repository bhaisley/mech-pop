"""Reproducible MiniMax source → phrase-length loop → lossless master + Vorbis.

NumPy/FFmpeg perform analysis and click prevention; listening approval is recorded
separately. Overrides make subsequent listening-based edit decisions repeatable.
The original SkyPort source and its existing loop are never rewritten.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
OGGENC = shutil.which("oggenc") or "/opt/homebrew/bin/oggenc"
RATE = 48000
TRACKS = {"neon-alley": 152, "junk-fields": 140, "blossom-core": 144, "reactor-ring": 160}


def decode(path, rate=RATE):
    data = subprocess.check_output([FFMPEG, "-v", "error", "-i", str(path), "-f", "f32le", "-ar", str(rate), "-ac", "2", "pipe:1"])
    return np.frombuffer(data, dtype="<f4").reshape(-1, 2).copy()


def encode(path, samples):
    subprocess.run([FFMPEG, "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "pipe:0", "-c:a", "pcm_s24le", str(path)], input=samples.astype("<f4").tobytes(), check=True)


def loudness(path):
    result = subprocess.run([FFMPEG, "-hide_banner", "-i", str(path), "-af", "loudnorm=I=-18:TP=-2:LRA=14:print_format=json", "-f", "null", "-"], capture_output=True, text=True, check=True)
    return json.loads(result.stderr[result.stderr.rfind("{"):result.stderr.rfind("}") + 1])


def features(samples):
    # 100 Hz feature clock, 24 kHz analysis, log-frequency spectral flux.
    mono = samples[::2].mean(axis=1)
    window = 1024
    frames = np.lib.stride_tricks.sliding_window_view(mono, window)[::240]
    spectrum = np.abs(np.fft.rfft(frames * np.hanning(window), axis=1))
    edges = np.unique(np.geomspace(2, spectrum.shape[1] - 1, 34).astype(int))
    bands = np.stack([np.log1p(spectrum[:, a:b].mean(axis=1) * 20) for a, b in zip(edges[:-1], edges[1:])], axis=1)
    flux = np.maximum(0, np.diff(bands, axis=0)).mean(axis=1)
    envelope = np.sqrt(np.mean(frames * frames, axis=1))
    return bands, flux, envelope


def tempo(flux, intended):
    onset = flux - np.mean(flux)
    padded = 1 << (2 * len(onset) - 1).bit_length()
    ac = np.fft.irfft(np.abs(np.fft.rfft(onset, padded)) ** 2)[:len(onset)]
    ac /= np.maximum(1, np.arange(len(onset), 0, -1))
    scores = []
    for bpm in np.arange(intended * .84, intended * 1.14, .02):
        beat = 6000 / bpm
        # Prefer a pulse reinforced over many beats, not one rounded lag.
        score = sum(float(np.interp(beat * multiple, np.arange(len(ac)), ac)) / np.sqrt(multiple) for multiple in range(1, 17))
        scores.append((score, bpm))
    return float(max(scores)[1])


def choose_cut(samples, bands, envelope, bpm):
    seconds = len(samples) / RATE
    standardized = bands / np.maximum(np.std(bands, axis=0), .25)
    options = []
    for bars in range(40, 73, 4):
        duration = bars * 240 / bpm
        if not 68 < duration < seconds - 4:
            continue
        for start in np.arange(1.0, min(17.0, seconds - duration - 1.2), .02):
            a, b = round(start * 100), round((start + duration) * 100)
            before, after = standardized[a-35:a+80], standardized[b-35:b+80]
            if len(before) != 115 or len(after) != 115:
                continue
            spectral = float(np.mean((before - after) ** 2))
            level = float(abs(np.log((envelope[a:a+50].mean()+1e-6) / (envelope[b:b+50].mean()+1e-6))))
            # Prefer a substantial arrangement while prioritizing seam similarity.
            options.append((spectral + level * .55 - duration * .0015, start, duration, bars))
    if not options:
        raise ValueError("No phrase-length loop fits the source")
    return sorted(options)[:10]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def master(name, overrides):
    source = ROOT / "audio/source/music" / (name + "-battle-a.flac")
    candidate = ROOT / "audio/candidates" / source.name
    if not source.exists():
        shutil.copy2(candidate, source)
    elif sha(candidate) != sha(source):
        raise ValueError("Retained source differs from candidate; select explicitly")
    samples = decode(source)
    bands, flux, envelope = features(samples)
    estimated = tempo(flux, TRACKS[name])
    bpm = overrides.bpm or estimated
    choices = choose_cut(samples, bands, envelope, bpm)
    _, start, duration, bars = choices[0]
    if overrides.start is not None:
        start = overrides.start
    if overrides.bars is not None:
        bars = overrides.bars
        duration = bars * 240 / bpm
    begin, length = round(start * RATE), round(duration * RATE)
    crossfade = round(overrides.crossfade_ms * RATE / 1000)
    assert begin >= crossfade and begin + length < len(samples)
    loop = samples[begin:begin+length].copy()
    # End in the actual neighborhood preceding the first sample. There is no
    # duplicated downbeat and no fade to silence at the wrap point.
    blend = (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, crossfade)))[:, None]
    loop[-crossfade:] = loop[-crossfade:] * (1-blend) + samples[begin-crossfade:begin] * blend
    folder = ROOT / "audio/source/music/masters"
    folder.mkdir(parents=True, exist_ok=True)
    output = folder / (name + "-loop.wav")
    encode(output, loop)
    raw = loudness(output)
    gain_db = min(-18 - float(raw["input_i"]), -2.2 - float(raw["input_tp"]))
    loop *= 10 ** (gain_db / 20)
    encode(output, loop)
    final = loudness(output)
    runtime = ROOT / "audio/music" / (name + ".ogg")
    subprocess.run([OGGENC, "-Q", "-q", "7", "-s", str(int(sha(source)[:7], 16)), "-o", str(runtime), str(output)], check=True)
    compressed = decode(runtime)
    encoded_loudness = loudness(runtime)
    # Keep a small, repeatable transition audition, not a huge 10-full-loop file.
    seam = np.concatenate([loop[-RATE*4:], loop[:RATE*4]])
    audition = ROOT / "work" / (name + "-seam-10x.wav")
    encode(audition, np.tile(seam, (10, 1)))
    record = {
        "source": str(source.relative_to(ROOT)), "source_sha256": sha(source),
        "source_seconds": len(samples)/RATE, "requested_bpm": TRACKS[name],
        "estimated_bpm": round(estimated, 3), "edit_bpm": round(bpm, 3),
        "start_seconds": begin/RATE, "bars": bars, "loop_seconds": length/RATE,
        "crossfade_ms": overrides.crossfade_ms, "gain_db": round(gain_db, 3),
        "lossless_master": str(output.relative_to(ROOT)), "master_sha256": sha(output),
        "master_lufs": float(final["input_i"]), "master_true_peak_db": float(final["input_tp"]),
        "runtime": str(runtime.relative_to(ROOT)), "runtime_sha256": sha(runtime),
        "runtime_lufs": float(encoded_loudness["input_i"]), "runtime_true_peak_db": float(encoded_loudness["input_tp"]),
        "runtime_bytes": runtime.stat().st_size,
        "master_seam_step": float(np.max(np.abs(loop[-1]-loop[0]))),
        "vorbis_seam_step": float(np.max(np.abs(compressed[-1]-compressed[0]))),
        "top_cut_candidates": [{"score": round(a, 4), "start": round(b, 3), "duration": round(c, 3), "bars": d} for a,b,c,d in choices],
        "listening_status": "Pending: analysis does not establish musical quality or a human-confirmed beat grid.",
        "method": "100 Hz log-band spectral flux, multi-beat autocorrelation, phrase-length spectral/level recurrence, cosine tail-to-pre-start crossfade, linear loudness gain, 48 kHz 24-bit lossless master, Vorbis quality 7 runtime."
    }
    (ROOT / "audio/source/music" / (name + "-loop-edit.json")).write_text(json.dumps(record, indent=2) + "\n")
    if float(final["input_tp"]) > -1.9 or float(encoded_loudness["input_tp"]) > -1:
        raise ValueError("True-peak headroom check failed")
    print(json.dumps(record), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", choices=list(TRACKS))
    parser.add_argument("--bpm", type=float)
    parser.add_argument("--start", type=float)
    parser.add_argument("--bars", type=int)
    parser.add_argument("--crossfade-ms", type=float, default=160)
    args = parser.parse_args()
    if not args.name and any(x is not None for x in (args.bpm, args.start, args.bars)):
        parser.error("Edit overrides require one --name")
    for track in [args.name] if args.name else TRACKS:
        master(track, args)
