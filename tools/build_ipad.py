#!/usr/bin/env python3
"""Export and development-sign the iPad app with an existing local Apple team.

The portable export preset is restored after export. Signing credentials remain
in Xcode and Keychain; this script neither reads nor exports private keys.
"""
import argparse
import os
from pathlib import Path
import plistlib
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--team", required=True)
parser.add_argument("--bundle", required=True)
parser.add_argument("--output", default="builds/expansion/ipad")
parser.add_argument("--export-only", action="store_true")
args = parser.parse_args()
if not re.fullmatch(r"[A-Z0-9]{10}", args.team) or not re.fullmatch(r"[A-Za-z0-9.-]+", args.bundle):
    parser.error("Use the actual Xcode Team ID and an existing bundle identifier")
output = (ROOT / args.output).resolve()
if not output.is_relative_to(ROOT / "builds"):
    parser.error("Output must be within this project's builds directory")
output.mkdir(parents=True, exist_ok=True)
environment = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")
preset = ROOT / "export_presets.cfg"
original = preset.read_text()
try:
    configured, changes = re.subn(r'application/app_store_team_id="[^"]*"', f'application/app_store_team_id="{args.team}"', original)
    if changes != 1:
        raise RuntimeError("Expected one iPad export team setting")
    preset.write_text(configured)
    with (output / "export.log").open("w") as log:
        subprocess.run(["/Applications/Godot.app/Contents/MacOS/Godot", "--headless", "--path", str(ROOT), "--log-file", "/private/tmp/mech-ipad-export.log", "--export-debug", "iPad", str(output / "MECHPOP.xcodeproj")], env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
finally:
    preset.write_text(original)

project = output / "MECHPOP.xcodeproj/project.pbxproj"
text = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = [^;]+;", f"PRODUCT_BUNDLE_IDENTIFIER = {args.bundle};", project.read_text())
text = re.sub(r"DEVELOPMENT_TEAM = [^;]+;", f"DEVELOPMENT_TEAM = {args.team};", text)
project.write_text(text)
info = output / "MECHPOP/MECHPOP-Info.plist"
properties = plistlib.loads(info.read_bytes())
properties["NSLocalNetworkUsageDescription"] = "MECH★POP connects to your friends on Wi-Fi for multiplayer matches."
info.write_bytes(plistlib.dumps(properties, sort_keys=False))
print(f"Export ready: {project.parent}", flush=True)
if not args.export_only:
    with (output / "build.log").open("w") as log:
        subprocess.run(["xcrun", "xcodebuild", "-project", str(project.parent), "-scheme", "MECHPOP", "-configuration", "Debug", "-destination", "generic/platform=iOS", "-derivedDataPath", str(output / "DerivedData"), "CODE_SIGN_STYLE=Automatic", "CODE_SIGN_IDENTITY=Apple Development", "-allowProvisioningUpdates", "build"], env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
    print(f"Signed app: {output / 'DerivedData/Build/Products/Debug-iphoneos/MECHPOP.app'}", flush=True)
