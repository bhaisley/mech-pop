"""Inspect authored WAV assets without rewriting their masters."""
import audioop
import json
import math
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
results = []
for path in sorted((ROOT / 'audio/sfx').glob('*.wav')):
    with wave.open(str(path), 'rb') as sound:
        width = sound.getsampwidth()
        rate = sound.getframerate()
        channels = sound.getnchannels()
        frames = sound.readframes(sound.getnframes())
        peak = audioop.max(frames, width) / (2 ** (8*width - 1))
        rms = audioop.rms(frames, width) / (2 ** (8*width - 1))
        results.append(dict(file=path.name, rate=rate, channels=channels,
                            seconds=round(len(frames)/width/channels/rate,3),
                            peak_db=round(20*math.log10(max(peak,1e-9)),2),
                            rms_db=round(20*math.log10(max(rms,1e-9)),2)))
errors = [r['file'] for r in results if r['peak_db'] >= -0.05 or r['peak_db'] < -40 or r['rate'] != 48000]
(ROOT / 'work/audio-analysis.json').write_text(json.dumps(dict(files=results, errors=errors),indent=2))
print(json.dumps(dict(files=results, errors=errors), indent=2))
raise SystemExit(bool(errors))
