#!/usr/bin/env python3
"""Refresh retained asset hashes and add expansion provenance categories."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "docs/ASSET_MANIFEST.json"
assets = {item["path"]: item for item in json.loads(path.read_text())["assets"]}


def add(pattern, provider, source, terms, runtime=True):
    for file in ROOT.glob(pattern):
        relative = str(file.relative_to(ROOT))
        if relative not in assets:
            assets[relative] = {"path": relative, "provider": provider, "source": source(file), "terms": terms, "runtime": runtime}


original = "Original game content; no open-source license assigned"
music = "third_party/MiniMax-Music3-LICENSE.txt"
for directory in ["characters", "modules"]:
    add(directory + "/models/*.glb", "Project-specific Blender geometry", lambda p: f"art_source/models/{p.stem}.blend; tools/build_mechs.py", original)
add("ui/portraits/*.png", "Native render of the production character model", lambda p: f"characters/models/{p.stem}.glb; tools/render_assets.gd", original)
yue2 = "https://github.com/multimodal-art-projection/YuE/blob/main/MODEL_LICENSE"
for score in (ROOT / "audio/source/music/yue2").glob("*.abc"):
    name = score.stem
    receipt = str(score.with_suffix(".json").relative_to(ROOT))
    add(f"audio/music/{name.replace('_', '-')}.ogg", "YuE2-3B instrumental, edited for MECH POP", lambda p: receipt, yue2)
    add(f"audio/source/music/yue2/{name}.flac", "Original YuE2-3B performance", lambda p: receipt, yue2, False)
    add(f"stages/{name}/*-matte.png", "Built-in ImageGen", lambda p: f"stages/{name}/matte-prompt.txt", original)
add("audio/sfx/chassis/*.wav", "Original SuperCollider chassis instruments", lambda p: "audio/source/render_chassis_sfx.scd", original)
add("stages/*/*-matte.png", "Built-in ImageGen; model identifier not exposed", lambda p: "art_source/arena-prompts.json; art_source/arena-provenance.json", "Project-specific generated asset")
add("audio/sfx/*.wav", "Original SuperCollider synthesis", lambda p: "audio/source/render_expansion_sfx.scd", original)
add("audio/music/*.ogg", "MiniMax-Music3 composition, edited and mastered for this game", lambda p: f"audio/source/music/{p.stem}-loop-edit.json; tools/master_expansion_music.py", music)
add("audio/source/music/*-battle-a.flac", "MiniMax-Music3 generated original lossless recording", lambda p: str(p.with_suffix(".workflow.json").relative_to(ROOT)), music, False)
add("audio/source/music/masters/*.wav", "Edited 48 kHz/24-bit lossless loop master", lambda p: "tools/master_expansion_music.py; audio/source/music/*-loop-edit.json", music, False)
for item in assets.values():
    file = ROOT / item["path"]
    item["sha256"] = hashlib.sha256(file.read_bytes()).hexdigest()
    item["bytes"] = file.stat().st_size
asset_commit = subprocess.check_output(["git", "log", "-1", "--format=%H", "--", "characters", "modules", "stages", "audio", "art_source", "ui/portraits"], cwd=ROOT, text=True).strip()
path.write_text(json.dumps({"version": "0.2.0-preview", "asset_source_commit": asset_commit, "assets": sorted(assets.values(), key=lambda item: item["path"])}, indent=2) + "\n")
print(json.dumps({"assets": len(assets), "manifest": str(path)}))
