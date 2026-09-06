"""Submit/poll only MECH POP's jobs on a configured MiniMax Music3 ComfyUI service."""
import argparse
import os
import json
import time
import urllib.request
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = os.environ.get('COMFYUI_URL', 'http://127.0.0.1:8188')
SOURCE = ROOT / 'audio/source/music'
CANDIDATES = ROOT / 'audio/candidates'

def request(path, data=None):
    payload = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(BASE + path, data=payload, headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)

def submit(name, seed, brief=None):
    SOURCE.mkdir(parents=True, exist_ok=True)
    receipt = SOURCE / f'{name}.receipt.json'
    if receipt.exists():
        raise SystemExit('Receipt already exists; refusing an accidental duplicate job.')
    queue = request('/queue')
    if queue.get('queue_running') or queue.get('queue_pending'):
        raise SystemExit('Music lane is busy; no job submitted and no other job was changed.')
    caption = '''Global Metadata: Original instrumental arcade battle theme for MECH POP, a colorful game about expressive tiny robots fighting and swapping oversized weapons on a futuristic sky port. Japanese arcade energy, electronic rock, playful heroic anime adventure. 144 BPM, 4/4, E minor with bright major-color lift in the hook. Exactly 108 seconds of continuous energetic music. Confident, propulsive, mischievous, optimistic; energetic without oppressive aggression. Studio-quality stereo mix with crisp controlled drums, punchy bass, clear memorable melody and space for game sound effects.

Vocal Details: Entirely instrumental. No singing, no speech, no rap, no choir, no vocal chops, no human voices. The lead melody is played only by bright synthesizers and electric guitar.

Arrangement: Start directly on the strong downbeat with an instantly catchy four-bar bright synth lead hook answered by playful plucked bell notes. Tight electronic drums with real rock snare character, syncopated warm synth bass, short crunchy distorted guitar accents and futuristic mechanical percussion. Arrange 64 bars: 8-bar hook, 16-bar driving A section, 16-bar soaring B section, 8-bar playful half-density break, 8-bar A variation, 8-bar hook reprise that leads seamlessly back into the opening downbeat. Keep rhythm and tempo steady. Change orchestration and drum fills every eight bars to maintain excitement. Wide synth and guitar accents, focused centered kick and bass, restrained cymbals. Avoid a long intro, cinematic build, abrupt tempo changes, fade-out or final resolving ending. End with a short pickup fill that naturally continues into the beginning for an arcade gameplay loop. Do not imitate any existing artist or song.'''
    if brief is not None:
        caption = Path(brief).read_text().strip()
        if not caption:
            raise SystemExit('The stage music brief is empty; no job submitted.')
    lyrics = '[Instrumental intro]\n\n[Instrumental hook]\n\n[Instrumental verse]\n\n[Instrumental chorus]\n\n[Instrumental bridge]\n\n[Instrumental chorus]\n\n[Instrumental outro]'
    workflow = {
        '1': {'class_type': 'UNETLoader', 'inputs': {'unet_name': 'minimax_music3_dit_fp16.safetensors', 'weight_dtype': 'default'}},
        '2': {'class_type': 'CLIPLoader', 'inputs': {'clip_name': 'minimax_music3_text_encoder_pruned_bf16.safetensors', 'type': 'minimax', 'device': 'default'}},
        '3': {'class_type': 'VAELoader', 'inputs': {'vae_name': 'minimax_music3_dav.safetensors'}},
        '4': {'class_type': 'MiniMaxMusic3TextEncode', 'inputs': {'clip': ['2', 0], 'caption': caption, 'lyrics': lyrics, 'seed': seed, 'max_duration': 108.0, 'cfg_scale': 1.7, 'top_k': 50}},
        '5': {'class_type': 'EmptyMiniMaxMusic3LatentAudio', 'inputs': {'seconds': 108.0, 'batch_size': 1}},
        '6': {'class_type': 'ConditioningZeroOut', 'inputs': {'conditioning': ['4', 0]}},
        '7': {'class_type': 'KSampler', 'inputs': {'model': ['1', 0], 'seed': seed + 1, 'steps': 30, 'cfg': 1.7, 'sampler_name': 'euler', 'scheduler': 'simple', 'positive': ['4', 0], 'negative': ['6', 0], 'latent_image': ['5', 0], 'denoise': 1.0}},
        '8': {'class_type': 'VAEDecodeAudio', 'inputs': {'samples': ['7', 0], 'vae': ['3', 0]}},
        '9': {'class_type': 'SaveAudio', 'inputs': {'audio': ['8', 0], 'filename_prefix': f'audio/mech-pop/{name}'}},
    }
    (SOURCE / f'{name}.workflow.json').write_text(json.dumps(workflow, indent=2))
    (SOURCE / f'{name}.prompt.txt').write_text(caption + '\n\nLyrics field:\n' + lyrics + '\n')
    result = request('/prompt', {'prompt': workflow, 'client_id': 'mech-pop-production'})
    result['submitted_utc'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    result['lane'] = BASE
    result['duration_limit_seconds'] = 108
    receipt.write_text(json.dumps(result, indent=2))
    print(json.dumps(result))

def poll(name, download=False):
    receipt = json.loads((SOURCE / f'{name}.receipt.json').read_text())
    prompt_id = receipt['prompt_id']
    history = request('/history/' + prompt_id)
    if prompt_id not in history:
        queue = request('/queue')
        running = any(entry[1] == prompt_id for entry in queue.get('queue_running', []))
        print(json.dumps({'prompt_id': prompt_id, 'state': 'running' if running else 'queued_or_not_reported'}))
        return
    result = history[prompt_id]
    (SOURCE / f'{name}.history.json').write_text(json.dumps(result, indent=2))
    print(json.dumps({'prompt_id': prompt_id, 'status': result.get('status'), 'outputs': result.get('outputs')})[:10000])
    if download and result.get('status', {}).get('status_str') == 'success':
        CANDIDATES.mkdir(parents=True, exist_ok=True)
        for output in result.get('outputs', {}).values():
            for entry in output.get('audio', []):
                query = urllib.parse.urlencode({k: entry[k] for k in ('filename', 'subfolder', 'type') if k in entry})
                destination = CANDIDATES / f'{name}{Path(entry["filename"]).suffix}'
                with urllib.request.urlopen(BASE + '/view?' + query, timeout=120) as response:
                    destination.write_bytes(response.read())
                print('Downloaded', destination)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['submit', 'poll', 'download'])
    parser.add_argument('--name', default='sky-port-battle-a')
    parser.add_argument('--seed', type=int, default=27491)
    parser.add_argument('--brief', type=Path, help='Original stage-specific composition brief; the established SkyPort brief remains the default.')
    args = parser.parse_args()
    if args.action == 'submit':
        submit(args.name, args.seed, args.brief)
    else:
        poll(args.name, args.action == 'download')
