#!/usr/bin/env python3
"""Run both roster halves on every map through the native ENet transport."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--engine", required=True)
parser.add_argument("--duration", type=float, default=70)
parser.add_argument("--output", default="work/native-network-rotation")
args = parser.parse_args()
out = ROOT / args.output
out.mkdir(parents=True, exist_ok=True)
report = {"topology": "native Mac export, one headless server and two headless clients, loopback ENet", "physical_input": False, "separate_networks": False, "rendering_test": False, "cases": [], "failures": []}
started = time.monotonic()
for stage in ["skyport", "neon_alley", "junk_fields", "blossom_core", "reactor_ring"]:
    for half, roster in enumerate(["nova,kuren,terra,momo", "shadow,lumi,kai,zero"]):
        name = f"{stage}-{half+1}"
        target = out / name
        command = [sys.executable, str(ROOT / "tools/test_network.py"), "--engine", args.engine, "--embedded", "--duration", str(args.duration), "--port", str(25100+len(report["cases"])), "--stage", stage, "--roster", roster, "--rtt", "80", "--jitter", "10", "--loss", "0.03", "--duplicates", "0.02", "--output", str(target)]
        result = subprocess.run(command, cwd=ROOT)
        case = json.loads((target / "report.json").read_text())
        report["cases"].append({"name": name, "stage": stage, "roster": roster.split(","), "host_rounds": len(case["host_rounds"]), "acknowledgements": len(case["acknowledgements"]), "failures": case["failures"], "report": str(target.relative_to(ROOT)) + "/report.json", "native_runtime": case.get("native_runtime")})
        if result.returncode:
            report["failures"].append(name)
        report["wall_seconds"] = round(time.monotonic()-started, 2)
        (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"cases": len(report["cases"]), "failures": report["failures"], "wall_seconds": report["wall_seconds"]}))
raise SystemExit(bool(report["failures"]))
