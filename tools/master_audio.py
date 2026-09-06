"""Finish the original MiniMax candidate and SC cues. Requires NumPy + FFmpeg.
Keeps the generated lossless candidate and exact NRT source untouched.
"""
from pathlib import Path
import subprocess, json, numpy as np
ROOT = Path(__file__).resolve().parents[1]
FF = '/opt/homebrew/bin/ffmpeg'
RATE = 48000

def decode(path, rate=RATE):
    return np.frombuffer(subprocess.check_output([FF,'-v','error','-i',str(path),'-f','f32le','-ar',str(rate),'-ac','2','pipe:1']), dtype='<f4').reshape(-1,2).copy()

def encode(path, samples):
    subprocess.run([FF,'-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','2','-i','pipe:0','-c:a','pcm_s16le',str(path)], input=samples.astype('<f4').tobytes(), check=True)

music=decode(ROOT/'audio/source/music/sky-port-battle-a.flac')
# Estimate percussive pulse from broadband onset envelope, with no model claim of exact BPM.
mono=music.mean(axis=1)
hop=480
energy=np.sqrt(np.mean(mono[:len(mono)//hop*hop].reshape(-1,hop)**2,axis=1))
onset=np.maximum(0,np.diff(energy))
score=[]
for bpm in np.arange(130,156,0.1):
    lag=int(round(6000/bpm))
    score.append((float(np.dot(onset[lag:],onset[:-lag])),float(bpm)))
bpm=max(score)[1]
# Find a musically aligned long segment by comparing boundary envelope neighborhoods.
# Use a whole number of four-beat measures, then circularly crossfade 120 ms to eliminate clicks.
period=240/bpm
candidates=[]
for bars in range(48,61,8):
    length=bars*period
    if length>len(music)/RATE-2: continue
    for start in np.arange(0.5, min(7,len(music)/RATE-length),0.02):
        a=int(start*100); b=int((start+length)*100)
        left=energy[a:a+80]; right=energy[b:b+80]
        if len(right)!=80: continue
        err=float(np.mean((left-right)**2))
        candidates.append((err-0.000001*bars,start,length,bars))
_,start,length,bars=min(candidates)
a=int(start*RATE); n=int(length*RATE)
loop=music[a:a+n].copy()
fade=int(0.12*RATE)
# Tail fades into samples preceding the start, making the wrap a continuous neighborhood.
t=np.linspace(0,1,fade,endpoint=False)[:,None]
loop[-fade:]=loop[-fade:]*(1-t)+music[a-fade:a]*t
# Preserve dynamics with gain and transparent peak ceiling; no hard clipping.
loop*=10**(-3.8/20)
peak=float(np.max(np.abs(loop)))
if peak>10**(-2/20): loop*=10**(-2/20)/peak
out=ROOT/'audio/music'; out.mkdir(parents=True,exist_ok=True)
encode(out/'sky-port.wav',loop)
# A gentler title cue from the same original theme, with an intentional 2 s loop crossfade.
menu=music[int(12*RATE):int(44*RATE)].copy()
f=int(2*RATE); t=np.linspace(0,1,f)[:,None]
menu[-f:]=menu[-f:]*(1-t)+menu[:f]*t
menu=menu[f:]*0.40
encode(out/'hangar.wav',menu)
report={'source':'sky-port-battle-a.flac','source_seconds':len(music)/RATE,'estimated_bpm':round(bpm,2),'bars':bars,'start_seconds':round(start,3),'loop_seconds':len(loop)/RATE,'crossfade_ms':120,'sample_peak_db':round(float(20*np.log10(np.max(np.abs(loop)))),2),'seam_step':float(np.max(np.abs(loop[-1]-loop[0]))),'method':'broadband onset autocorrelation and boundary-envelope alignment; not a human beat-grid confirmation'}
(ROOT/'audio/source/music/loop-edit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
