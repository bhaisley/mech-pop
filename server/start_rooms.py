#!/usr/bin/env python3
"""Run the bundled game as a bounded room service; stays in the foreground."""
import argparse
import importlib.util
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, help="Native Mac app; defaults to the accompanying expansion app")
    parser.add_argument("--engine", type=Path, help="Godot 4.7.2 executable for a source project or portable pack")
    parser.add_argument("--pack", type=Path, help="Portable game.pck, with --engine")
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--check", action="store_true", help="Print the actual game version and exit")
    args, gateway_options = parser.parse_known_args()
    app = args.app
    if app is None and args.engine is None:
        for candidate in [ROOT / "MECH POP 0.2.0.app", ROOT / "builds/expansion/MECH POP 0.2.0.app"]:
            if candidate.exists():
                app = candidate
                break
    if app:
        app = app.resolve()
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        engine = app / "Contents/MacOS" / info["CFBundleExecutable"]
        content = ["--embedded"]
        probe_content = []
    elif args.engine:
        engine = args.engine.resolve()
        content = ["--pack", str(args.pack.resolve())] if args.pack else ["--project", str(args.project.resolve())]
        probe_content = ["--main-pack", str(args.pack.resolve())] if args.pack else ["--path", str(args.project.resolve())]
    else:
        parser.error("Place the expansion app beside server/, or specify --app or --engine")
    if not engine.is_file():
        parser.error(f"Game executable does not exist: {engine}")
    if args.check:
        with tempfile.TemporaryDirectory(prefix="mech-room-check-") as temporary:
            return subprocess.call([str(engine), "--headless", *probe_content, "--log-file", str(Path(temporary) / "version.log"), "--", "--network-info"])
    if sys.version_info < (3, 11):
        parser.error("Room hosting requires Python 3.11 or newer")
    if importlib.util.find_spec("aiohttp") is None:
        parser.error("Install the pinned dependencies from server/requirements.txt in a Python virtual environment first")
    command = [sys.executable, str(Path(__file__).with_name("room_gateway.py")), "--engine", str(engine), *content, "--logs", str(ROOT / "server/logs"), *gateway_options]
    os.execv(sys.executable, command)


if __name__ == "__main__":
    raise SystemExit(main())
