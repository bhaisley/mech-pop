"""Build the browser simulation from the same combat, AI, data and netcode as native."""
import argparse
import gzip
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "docs/game"
SOURCE = ROOT / "tools/web_runtime"
TEMPLATE_SHA256 = "d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot 4.7.2 Standard executable")
    parser.add_argument("--template", type=Path, required=True, help="web_nothreads_release.zip from the 4.7.2 official export templates")
    args = parser.parse_args()
    template = args.template.resolve()
    if hashlib.sha256(template.read_bytes()).hexdigest() != TEMPLATE_SHA256:
        parser.error("Expected the official Godot 4.7.2 single-threaded release template")
    if not subprocess.check_output([args.godot, "--version"], text=True).startswith("4.7.2.stable"):
        parser.error("Use Godot 4.7.2 to match the native room protocol")
    runtime = WEB / "runtime"
    runtime.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mech-pop-web-") as temp:
        project = Path(temp) / "game"
        project.mkdir()
        for group in ["ai", "combat", "data", "network"]:
            shutil.copytree(ROOT / "scripts" / group, project / "scripts" / group)
        inputs = project / "scripts/input"
        inputs.mkdir()
        for stem in ["fighter_command", "input_router"]:
            shutil.copy(ROOT / f"scripts/input/{stem}.gd", inputs)
        for group in ["stages", "characters", "modules"]:
            (project / group).mkdir()
            for resource in (ROOT / group).glob("*.tres"):
                shutil.copy(resource, project / group)
        for source in SOURCE.glob("*.gd"):
            shutil.copy(source, project)
        (project / "main.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://web_game.gd" id="1"]\n[node name="MechPop" type="Node"]\nscript = ExtResource("1")\n')
        (project / "project.godot").write_text('''config_version=5
[application]
config/name="MECH POP Browser"
config/version="0.4.0-web"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[display]
window/size/viewport_width=2
window/size/viewport_height=2
[physics]
common/physics_ticks_per_second=120
common/max_physics_steps_per_frame=16
2d/default_gravity=0.0
[rendering]
renderer/rendering_method="gl_compatibility"
[debug]
gdscript/warnings/untyped_declaration=0
''')
        (project / "export_presets.cfg").write_text('''[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="catalog.gd"
[preset.0.options]
variant/thread_support=false
''')
        base = [args.godot, "--headless", "--path", str(project), "--log-file", str(Path(temp) / "build.log")]
        subprocess.run(base + ["--editor", "--import", "--quit"], check=True)
        subprocess.run(base + ["--script", "catalog.gd", "--", str(WEB / "catalog.js")], check=True)
        subprocess.run(base + ["--export-pack", "Web", str(runtime / "sim.pck")], check=True)
    # Pages serves static files. Store the 39 MB engine as a 10 MB payload and
    # decompress its response before the normal streaming WebAssembly compile.
    with zipfile.ZipFile(template) as archive:
        loader = archive.read("godot.js").decode()
        load = 'preloader.loadPromise(`${loadPath}.wasm`, size, true)'
        compressed = 'preloader.loadPromise(`${loadPath}.wasm.gz`, size, true).then(async response => { const bytes = new Uint8Array(await response.arrayBuffer()); const body = new Blob([bytes]).stream(); return new Response(bytes[0] === 31 ? body.pipeThrough(new DecompressionStream("gzip")) : body, {headers: {"Content-Type":"application/wasm"}}); })'
        assert loader.count(load) == 1
        (runtime / "sim.js").write_text(loader.replace(load, compressed))
        (runtime / "sim.wasm.gz").write_bytes(gzip.compress(archive.read("godot.wasm"), compresslevel=9, mtime=0))
        for name in ["audio.worklet.js", "audio.position.worklet.js"]:
            (runtime / ("sim." + name)).write_bytes(archive.read("godot." + name))
    shutil.copy2(ROOT / "third_party/GODOT_NOTICES.txt", runtime)

if __name__ == "__main__":
    main()
