# Build MECH★POP

The public source snapshot is the **0.2.0 preview, build 16**. Runtime code and production assets match the tested development build. Private signing data, raw device logs, machine-specific job receipts and local build caches are excluded.

## Requirements

- Godot **4.7.2 Standard** and its matching export templates.
- Python **3.11+** for the room server and network tools; install `server/requirements.txt` in a virtual environment.
- Xcode and an Apple development team for a physical iPad export.
- Blender, SuperCollider and the audio tools are needed only to regenerate their source assets. They are not needed to run the game.

## Open and run

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
