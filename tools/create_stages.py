"""Reproducible arena layouts and presentation/music metadata."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
STAGES = [
    dict(id="skyport", title="SKYPORT", subtitle="HIGH-SKY SCRAP PARTY", description="Open decks and a drifting transit platform.",
         platforms=[(-1100, 0, 2200, 100), (-1000, -360, 600, 32), (400, -360, 600, 32), (-200, -620, 400, 32)],
         spawns=[(-750, -100), (750, -100), (-600, -470), (600, -470)], moving_index=3, amplitude=(300, 0), speed=.24,
         colors=["3bccd5", "e7f4f5", "213b59", "ffcd55", "317faf", "bde7ea", "cce7f1", "fff0d5"],
         music="sky-port", matte="skyport/skyport-matte"),
    dict(id="neon_alley", title="NEON ALLEY", subtitle="ROOFTOP RUMBLE", description="Tight rooftops, a high center perch and a roaming signboard.",
         platforms=[(-980, 0, 1960, 100), (-1170, -300, 480, 32), (690, -280, 480, 32), (-290, -430, 580, 32), (-150, -710, 300, 28)],
         spawns=[(-650, -100), (650, -100), (-930, -410), (930, -390)], moving_index=4, amplitude=(620, 0), speed=.31,
         colors=["55e7f0", "434477", "18243e", "ff72bf", "202447", "705b91", "b7d6ff", "ffe7f5"],
         music="neon-alley", matte="neon_alley/neon-alley-matte"),
    dict(id="junk_fields", title="JUNK FIELDS", subtitle="HEAVY METAL PLAYGROUND", description="Wide scrap decks and uneven stacks beneath a crane lift.",
         platforms=[(-1220, 0, 2440, 110), (-1000, -250, 430, 32), (-240, -320, 480, 32), (510, -480, 630, 32), (-190, -650, 380, 32)],
         spawns=[(-940, -100), (940, -100), (-820, -360), (830, -590)], moving_index=4, amplitude=(0, 130), speed=.38,
         colors=["72e2c9", "ddac62", "3c5261", "f38440", "7bb6bd", "f1d5a5", "d8e7d2", "ffe1b1"],
         music="junk-fields", matte="junk_fields/junk-fields-matte"),
    dict(id="blossom_core", title="BLOSSOM CORE", subtitle="PETALS & POWER CELLS", description="Garden terraces around a floating petal lift.",
         platforms=[(-1030, 0, 2060, 100), (-980, -300, 620, 32), (360, -300, 620, 32), (-340, -650, 680, 32), (-160, -155, 320, 32)],
         spawns=[(-720, -100), (720, -100), (-670, -410), (670, -410)], moving_index=4, amplitude=(540, -150), speed=.28,
         colors=["73e2c5", "fff0ed", "536e84", "ed98c9", "75c6d9", "e6f6ef", "d9f3e9", "fff2dd"],
         music="blossom-core", matte="blossom_core/blossom-core-matte"),
    dict(id="reactor_ring", title="REACTOR RING", subtitle="FULL-CHARGE FREE-FOR-ALL", description="A broad central ring and a fast vertical reactor lift.",
         platforms=[(-1100, 0, 2200, 100), (-1160, -480, 440, 32), (720, -480, 440, 32), (-410, -310, 820, 32), (-225, -680, 450, 32)],
         spawns=[(-770, -100), (770, -100), (-940, -590), (940, -590)], moving_index=4, amplitude=(0, 140), speed=.55,
         colors=["52e7ff", "d5e4eb", "27344f", "ff9848", "202f52", "5b849e", "bddbf0", "d9f9ff"],
         music="reactor-ring", matte="reactor_ring/reactor-ring-matte"),
]

def vector(kind, values):
    return f"{kind}({', '.join(str(v) for v in values)})"

def build():
    for entry in STAGES:
        fields = {
            "id": '&' + json.dumps(entry["id"]), "display_name": json.dumps(entry["title"]),
            "subtitle": json.dumps(entry["subtitle"]), "description": json.dumps(entry["description"]),
            "platforms": "Array[Rect2]([" + ", ".join(vector("Rect2", r) for r in entry["platforms"]) + "])",
            "spawns": "Array[Vector2]([" + ", ".join(vector("Vector2", r) for r in entry["spawns"]) + "])",
            "moving_index": str(entry["moving_index"]), "moving_amplitude": vector("Vector2", entry["amplitude"]),
            "moving_speed": str(entry["speed"]), "music": json.dumps(f'res://audio/music/{entry["music"]}.{"wav" if entry["id"] == "skyport" else "ogg"}'),
            "matte": json.dumps(f'res://stages/{entry["matte"]}.png'),
        }
        for name, color in zip(["accent", "deck", "dark", "trim", "sky_top", "sky_horizon", "ambient", "sunlight"], entry["colors"]):
            fields[name] = vector("Color", [round(int(color[i:i+2], 16) / 255, 6) for i in (0, 2, 4)] + [1])
        text = '[gd_resource type="Resource" script_class="StageData" load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/data/stage_data.gd" id="1"]\n\n[resource]\nscript = ExtResource("1")\n'
        text += "\n".join(f"{key} = {value}" for key, value in fields.items()) + "\n"
        (ROOT / f'stages/{entry["id"]}.tres').write_text(text)
    print(f"Authored {len(STAGES)} distinct arena layouts.")

if __name__ == "__main__":
    build()
