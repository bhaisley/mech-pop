# Build MECH★POP

The public source snapshot is the **0.2.0 preview, build 16**. Runtime code and production assets match the tested development build. Private signing data, raw device logs, machine-specific job receipts and local build caches are excluded.

## Requirements

The browser game is ready to serve from this checkout. The following toolchain is for native development and regenerating the browser simulation.

- Godot **4.7.2 Standard** and its matching export templates.
- Python **3.11+** for the room server and network tools; install `server/requirements.txt` in a virtual environment.
- Xcode and an Apple development team for a physical iPad export.
- Blender, SuperCollider and the audio tools are needed only to regenerate their source assets. They are not needed to run the game.

## Run the browser game

Serve the `docs` directory from the repository root.

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory docs
```

Open [the local game](http://127.0.0.1:8000/) in a browser with WebGL, WebAssembly and gzip stream decompression. Three.js r160, the JavaScript game, art, audio and fonts are served from the same origin. Launching the first match downloads the compressed simulation. GitHub Pages serves this directory from the `main` branch.

The hangar, inputs, Three.js models, arena geometry and HUD live in `docs/game/`. Edits to those JavaScript and CSS files take effect on reload. The simulation uses the native files in `scripts/combat`, `scripts/ai`, `scripts/network`, `scripts/data` and the roster and stage resources.

After a simulation or roster change, rebuild the web pack and catalog with Godot **4.7.2 Standard** and the matching official single-threaded web release template.

```sh
python3 tools/build_web_runtime.py --godot godot \
  --template /path/to/4.7.2.stable/web_nothreads_release.zip
```

The builder checks the engine version and template checksum, stages a physics-only project in a temporary directory and exports `docs/game/runtime/` and `docs/game/catalog.js`. Commit the regenerated files with their source changes. The browser draws each game frame with Three.js.

## Run the native game

From the repository root:

```sh
godot --editor --path .
godot --path .
```

On macOS, a downloaded Godot application can also be invoked as `/Applications/Godot.app/Contents/MacOS/Godot`.

## Export

Install the matching Godot export templates. The `macOS` and `iPad` presets are included in `export_presets.cfg`.

```sh
mkdir -p builds
godot --headless --path . --export-debug macOS 'builds/MECH POP.app'
```

The Mac preset creates a universal app with its engine and assets. It uses an ad-hoc signature; distribution notarization is not configured. The iPad preset leaves the personal team identifier blank. See [iPad setup](IPAD_SETUP.md).

## Tests

```sh
godot --headless --path . --script tests/test_systems.gd
godot --headless --path . --script tests/test_cannon_duel.gd
godot --headless --path . --script tests/test_controller_menus.gd
godot --headless --path . --script tests/test_touch_controls.gd -- --touch-preview
godot --headless --path . --script tests/test_front_end.gd
godot --headless --path . --script tests/test_network_state.gd
```

Check the available filenames in `tests/` if adding more checks. These exercise simulation and generated input; they do not substitute for a controller or fingers on an iPad. [Validation summary](TESTING.md).

For HTTP/WebSocket room checks:

```sh
python3 -m venv server/.venv
server/.venv/bin/pip install -r server/requirements.txt
server/.venv/bin/python tools/test_internet_rooms.py --parties 1,1,1,1 --duration 25
```

## Source assets

Runtime models are in `characters/models/` and `modules/models/`; authored sources are in `art_source/`. Audio sources and accepted lossless masters are in `audio/source/`. Fonts and engine notices are retained.

`tools/music_job.py` uses the `COMFYUI_URL` environment variable for a developer's own music-generation service. Its default is a local service at `http://127.0.0.1:8188`. Generation is optional; all accepted runtime audio is already included.

## Record native gameplay

Godot's Movie Maker records frames and the mixed audio bus. The existing unattended bot mode prevents a browser or editor taking focus from pausing the capture:

```sh
godot --path . --write-movie builds/gameplay.avi --fixed-fps 60 --quit-after 3000 -- \
  --benchmark=45 --stage=neon_alley --roster=nova,momo,kai,zero
```

The `--benchmark` option starts a normal four-bot match and exits after its requested duration. Measurements from a video recording are not performance evidence. Use FFmpeg to select a 30-second segment and encode H.264/AAC MP4.
