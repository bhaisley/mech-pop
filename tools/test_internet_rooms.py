#!/usr/bin/env python3
"""Real room API + Godot WebSocket clients, on loopback; no WAN claim."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, default=24881)
parser.add_argument("--duration", type=float, default=25)
parser.add_argument("--output", default="work/internet-room-regression")
parser.add_argument("--url", help="Existing public gateway; skips local lifecycle/capacity tests")
parser.add_argument("--engine", default="/Applications/Godot.app/Contents/MacOS/Godot")
parser.add_argument("--pack", type=Path, help="Exported runtime pack, for native package validation")
parser.add_argument("--embedded", action="store_true", help="Use the game packaged beside the native executable")
parser.add_argument("--parties", default="1,1", help="Local player counts per client, e.g. 2,1 or 2,2")
args = parser.parse_args()
parties = [int(value) for value in args.parties.split(",")]
if not 1 <= len(parties) <= 4 or any(not 1 <= value <= 4 for value in parties) or sum(parties) > 4:
    parser.error("One to four parties must contain one to four players in total")
out = ROOT / args.output
out.mkdir(parents=True, exist_ok=True)
base = args.url or f"http://127.0.0.1:{args.port}"
engine = args.engine
names = ["creator"] + [f"joiner-{number}" for number in range(1, len(parties))]
processes, streams, failures = [], [], []


def spawn(name, command):
    log = (out / (name + ".log")).open("w")
    streams.append(log)
    proc = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    processes.append((name, proc))
    return proc


def api(path, body=None):
    req = urllib.request.Request(base + path, data=json.dumps(body).encode() if body is not None else None, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, None


def wait_for(predicate, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        try:
            value = predicate()
            if value:
                return value
        except (OSError, ValueError):
            pass
        time.sleep(.15)
    raise AssertionError("Timed out waiting for test state")


def records(name, prefix):
    for suffix in [".log", ".engine.log"]:
        path = out / (name + suffix)
        if path.exists():
            found = [json.loads(line.removeprefix(prefix)) for line in path.read_text().splitlines() if line.startswith(prefix)]
            if found:
                return found
    return []


report = {"topology": "public gateway from this Mac" if args.url else f"loopback gateway + {len(parties)} game clients", "genuine_cross_network_test": False, "physical_input": False, "parties": parties, "engine": engine, "pack": str(args.pack) if args.pack else None, "api_checks": [], "client_rounds": [], "client_metrics": {}, "party_slots": {}}
if args.embedded:
    executable = Path(engine).resolve()
    pack = next((executable.parents[1] / "Resources").glob("*.pck"))
    report["native_runtime"] = {"binary_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(), "pack_sha256": hashlib.sha256(pack.read_bytes()).hexdigest()}
gateway = None
try:
    if not args.url:
        # Exercise a relative CLI log path even with a native macOS bundle.
        server_logs = (out / "rooms").relative_to(ROOT) if out.is_relative_to(ROOT) else out / "rooms"
        command = [sys.executable, "server/room_gateway.py", "--engine", engine, "--port", str(args.port), "--first-game-port", str(args.port+20), "--max-rooms", "2", "--idle-seconds", "8", "--test-auto-start", str(len(parties)), "--match-seconds", str(args.duration), "--logs", str(server_logs)]
        if args.pack:
            command += ["--pack", str(args.pack.resolve())]
        if args.embedded:
            command.append("--embedded")
        gateway = spawn("gateway", command)
    status, health = wait_for(lambda: api("/health"), 20)
    assert status == 200
    report["server_info"] = health
    assert api("/rooms", {"protocol": -1, "fingerprint": "wrong"})[0] == 409
    assert api("/rooms/ABC234")[0] == 404
    report["api_checks"] += ["health", "version mismatch rejected", "missing room rejected"]
    seconds = args.duration + 12
    common = [engine, "--headless"]
    if args.pack:
        common += ["--main-pack", str(args.pack.resolve())]
    elif not args.embedded:
        common += ["--path", str(ROOT)]
    test = ["--net-no-view", "--net-bots", f"--internet-server={base}", f"--net-test-seconds={seconds}"]
    spawn("creator", common + ["--log-file", str(out / "creator.engine.log"), "--", "--internet-create", f"--net-test-party={parties[0]}"] + test)
    opened = wait_for(lambda: records("creator", "INTERNET_ROOM_READY "), 20)[0]
    code = opened["code"]
    report["room"] = code
    for name, count in zip(names[1:], parties[1:]):
        spawn(name, common + ["--log-file", str(out / (name + ".engine.log")), "--", f"--internet-join={code}", f"--net-test-party={count}"] + test)
    if not args.url:
        status, other = api("/rooms", {"protocol": health["protocol"], "fingerprint": health["fingerprint"]})
        assert status == 201 and other["code"] != code
        assert api("/rooms", {"protocol": health["protocol"], "fingerprint": health["fingerprint"]})[0] == 503
        report["api_checks"] += ["distinct isolated room", "bounded room capacity"]
    wait_for(lambda: all(p.poll() is not None for name, p in processes if name != "gateway"), seconds + 20)
    rounds = report["client_rounds"]
    for name, count in zip(names, parties):
        result = records(name, "NETWORK_CLIENT_ROUND ")
        assert len(result) == 1, f"{name} did not complete one full round"
        rounds.append(result[0])
        assert not result[0]["conservation_errors"]
        assert result[0]["network_peers"] == [1], f"{name} was not connected exclusively to the authority"
        assert next(proc.returncode for process_name, proc in processes if process_name == name) == 0, f"{name} exited unsuccessfully"
        end = records(name, "NETWORK_TEST_END ")[-1]
        report["client_metrics"][name] = end["metrics"]
        report["party_slots"][name] = end["own_slots"]
        assert len(end["own_slots"]) == count
        assert end["metrics"]["state_mismatches"] == 0
        assert end["metrics"]["rejected_messages"] == 0
        assert end["metrics"]["ping_p95_ms"] < 500, f"{name} latency exceeded 500 ms at p95"
        assert end["metrics"]["ping_max_ms"] < 2000, f"{name} developed a multi-second network queue"
        for suffix in [".log", ".engine.log"]:
            assert "ERROR:" not in (out / (name + suffix)).read_text(), f"{name} logged a runtime error"
    assert all(value["digest"] == rounds[0]["digest"] and value["scores"] == rounds[0]["scores"] for value in rounds)
    slots = [slot for party in report["party_slots"].values() for slot in party]
    assert len(slots) == len(set(slots)) == sum(parties)
    if not args.url:
        server_text = (out / "rooms" / (code + ".engine.log")).read_text()
        host_rounds = [json.loads(line.removeprefix("NETWORK_HOST_ROUND ")) for line in server_text.splitlines() if line.startswith("NETWORK_HOST_ROUND ")]
        assert host_rounds[0]["digest"] == rounds[0]["digest"]
        report["server_round"] = host_rounds[0]
        wait_for(lambda: api("/rooms/" + code)[0] == 404, 17)
        report["api_checks"].append("empty room expires and process closes")
        for path in (out / "rooms").glob("*.log"):
            text = path.read_text()
            assert "ERROR:" not in text and "Traceback (most recent call last)" not in text, f"Server logged a runtime error: {path.name}"
        assert "Traceback (most recent call last)" not in (out / "gateway.log").read_text(), "Gateway logged an unhandled exception"
        report["api_checks"].append("server logs remain clean through disconnect and expiry")
except Exception as error:
    failures.append(f"{type(error).__name__}: {error}")
finally:
    for name, proc in reversed(processes):
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=6)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
    for stream in streams:
        stream.close()
report["failures"] = failures
(out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({"api_checks": report["api_checks"], "completed_clients": len(report["client_rounds"]), "failures": failures, "report": str(out / "report.json")}, indent=2))
raise SystemExit(bool(failures))
