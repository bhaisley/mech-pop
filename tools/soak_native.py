#!/usr/bin/env python3
"""Measure a real exported Mac app; preserve process RSS and frame windows."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--app", required=True, type=Path)
parser.add_argument("--seconds", type=float, default=1830)
parser.add_argument("--output", default="work/native-expansion-soak")
parser.add_argument("--stage", help="First arena for a focused native regression")
parser.add_argument("--roster", help="Four comma-separated fighters for the first round")
args = parser.parse_args()
app = args.app.resolve()
out = (ROOT / args.output).resolve()
out.mkdir(parents=True, exist_ok=True)
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
binary = app / "Contents/MacOS" / info["CFBundleExecutable"]
pack = next((app / "Contents/Resources").glob("*.pck"))
command = [str(binary), "--resolution", "1920x1080", "--log-file", str(out / "engine.log"), "--", f"--soak={args.seconds}", "--rotate-content", f"--frame-windows={out / 'frame-windows.json'}"]
if args.stage:
    command.append("--stage=" + args.stage)
if args.roster:
    command.append("--roster=" + args.roster)
report = {"command": command, "bundle_version": info.get("CFBundleVersion"), "bundle_short_version": info.get("CFBundleShortVersionString"), "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(), "pack_sha256": hashlib.sha256(pack.read_bytes()).hexdigest(), "native": True, "physical_input": False, "rss": [], "failures": []}
with (out / "stdout.log").open("w") as stdout:
    started = time.monotonic()
    process = subprocess.Popen(command, stdout=stdout, stderr=subprocess.STDOUT)
    try:
        while process.poll() is None:
            elapsed = time.monotonic()-started
            if elapsed > args.seconds + 90:
                raise TimeoutError("Native app did not finish the test")
            rss = subprocess.run(["ps", "-o", "rss=", "-p", str(process.pid)], capture_output=True, text=True)
            if rss.returncode == 0 and rss.stdout.strip():
                report["rss"].append({"elapsed": round(elapsed, 2), "kib": int(rss.stdout.strip())})
            time.sleep(5)
        report["exit_code"] = process.returncode
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
    report["wall_seconds"] = round(time.monotonic()-started, 2)
log = (out / "engine.log").read_text()
benchmarks = [json.loads(line.removeprefix("BENCHMARK ")) for line in log.splitlines() if line.startswith("BENCHMARK ")]
if not benchmarks:
    report["failures"].append("No completion record")
else:
    benchmark = benchmarks[-1]
    report["benchmark"] = benchmark
    if benchmark["conservation_errors"]:
        report["failures"].append("Equipment ownership failed")
if "ERROR:" in log or "SCRIPT ERROR:" in log:
    report["failures"].append("Engine or script error in native log")
if process.returncode:
    report["failures"].append("App exited unsuccessfully")
if (out / "frame-windows.json").exists():
    windows = json.loads((out / "frame-windows.json").read_text())["windows"]
    fight = [row for row in windows if row["phase"] == "fight"]
    if fight:
        report["fight_fps"] = {"minimum": min(row["fps"] for row in fight), "below_58_5": sum(row["fps"] < 58.5 for row in fight), "total_windows": len(fight)}
        if report["fight_fps"]["below_58_5"]:
            report["failures"].append("At least one ordinary-fight window fell below 58.5 fps; inspect frame windows")
(out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"wall_seconds": report["wall_seconds"], "fight_fps": report.get("fight_fps"), "failures": report["failures"], "report": str(out / "report.json")}, indent=2))
raise SystemExit(bool(report["failures"]))
