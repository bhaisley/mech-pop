#!/usr/bin/env python3
"""Exercise real ENet sessions in separate native Godot processes.

This is a loopback protocol regression, not physical input or internet evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--engine", default="/Applications/Godot.app/Contents/MacOS/Godot")
parser.add_argument("--duration", type=float, default=15)
parser.add_argument("--rounds", type=int, default=1)
parser.add_argument("--clients", type=int, default=2, choices=range(1, 5))
parser.add_argument("--port", type=int, default=24874)
parser.add_argument("--output", default="work/network-loopback")
parser.add_argument("--rtt", type=float, default=0)
parser.add_argument("--jitter", type=float, default=0)
parser.add_argument("--loss", type=float, default=0)
parser.add_argument("--duplicates", type=float, default=0)
parser.add_argument("--probe-recovery", action="store_true")
parser.add_argument("--stage", default="skyport")
parser.add_argument("--roster", default="nova,kuren,terra,momo")
parser.add_argument("--websocket", action="store_true")
parser.add_argument("--bandwidth-bps", type=int, default=0, help="Pace each loopback WebSocket TCP connection in both directions; no WAN claim")
parser.add_argument("--embedded", action="store_true", help="Use the native export's bundled game")
parser.add_argument("--trace", action="store_true", help="Log transport timing for a reproducible connection fault")
parser.add_argument("--delayed-client", action="store_true", help="Delay the second client's scene load for 4.5 seconds")
parser.add_argument("--render-client", type=int, default=0, help="Render this numbered native client at 1080p; zero keeps every process headless")
parser.add_argument("--capture-rendered", action="store_true", help="Save the rendered client's frame; this run is not capture-free performance evidence")
args = parser.parse_args()
if args.bandwidth_bps and (not args.websocket or not 1000 <= args.bandwidth_bps <= 10_000_000):
    parser.error("Bandwidth pacing requires WebSocket and 1,000–10,000,000 bytes per second")
if not 0 <= args.render_client <= args.clients or (args.capture_rendered and not args.render_client):
    parser.error("Choose an existing rendered client before requesting its capture")
output = ROOT / args.output
output.mkdir(parents=True, exist_ok=True)
seconds = args.rounds * (args.duration + 5) + 1
if args.delayed_client:
    if args.embedded or args.clients < 2:
        parser.error("Delayed scene-load probe uses the source and requires two clients")
    seconds += 6
common = [args.engine]
if not args.embedded:
    common += ["--path", str(ROOT)]
test = ["--net-bots", f"--stage={args.stage}", f"--roster={args.roster}", f"--net-test-seconds={seconds}", f"--net-lag={args.rtt / 2}", f"--net-jitter={args.jitter}", f"--net-loss={args.loss}", f"--net-duplicates={args.duplicates}"]
if args.trace:
    test.append("--net-trace")
processes = []
streams = []
failures = []
proxy = None

def launch(name, flags):
    stream = (output / f"{name}.log").open("w")
    streams.append(stream)
    script = ["--script", "res://tests/probe_network_client.gd"] if args.probe_recovery and name == "client-1" else []
    if args.delayed_client and name == "client-2":
        script = ["--script", "res://tests/probe_delayed_network_client.gd"]
    rendered = name == f"client-{args.render_client}"
    presentation = ["--resolution", "1920x1080"] if rendered else ["--headless"]
    if rendered:
        flags = [flag for flag in flags if flag != "--net-no-view"]
    capture = [f"--capture={output / (name + '.png')}"] if rendered and args.capture_rendered else []
    command = common + presentation + script + ["--log-file", f"/private/tmp/mech-net-{args.port}-{name}.log", "--"] + flags + test + capture
    process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    processes.append((name, process))

try:
    if args.bandwidth_bps:
        stream = (output / "bandwidth-proxy.log").open("w")
        streams.append(stream)
        proxy = subprocess.Popen([sys.executable, str(ROOT / "tools/throttle_tcp.py"), "--listen-port", str(args.port + 1), "--upstream-port", str(args.port), "--bytes-per-second", str(args.bandwidth_bps)], stdout=stream, stderr=subprocess.STDOUT)
    flags = ["--server", f"--net-host={args.port}", f"--net-auto-start={args.clients}", f"--net-test-duration={args.duration}"]
    if args.websocket:
        flags.append("--net-websocket")
    if args.rounds > 1:
        flags.append("--net-rematch")
    launch("host", flags)
    time.sleep(0.5)
    for number in range(args.clients):
        websocket_port = args.port + (1 if args.bandwidth_bps else 0)
        address = f"ws://127.0.0.1:{websocket_port}" if args.websocket else "127.0.0.1"
        launch(f"client-{number + 1}", ["--net-no-view", f"--net-join={address}", f"--net-port={args.port}"])
    deadline = time.monotonic() + seconds + 50
    while any(process.poll() is None for _, process in processes):
        if time.monotonic() > deadline:
            failures.append("Timed out waiting for a complete network match")
            if sys.platform == "darwin":
                for name, process in processes:
                    if process.poll() is None:
                        try:
                            subprocess.run(["/usr/bin/sample", str(process.pid), "2", "-file", str(output / (name + ".sample.txt"))], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
                        except (OSError, subprocess.TimeoutExpired) as error:
                            failures.append(f"Could not sample {name}: {type(error).__name__}")
            break
        time.sleep(0.2)
finally:
    for name, process in processes:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        if process.returncode:
            failures.append(f"{name} exited with {process.returncode}")
    if proxy:
        if proxy.poll() is not None:
            failures.append("Bandwidth proxy exited before the clients")
        else:
            proxy.terminate()
            proxy.wait(timeout=5)
    for stream in streams:
        stream.close()

def records(name, prefix):
    return [json.loads(line.removeprefix(prefix)) for line in (output / f"{name}.log").read_text().splitlines() if line.startswith(prefix)]

hosts = records("host", "NETWORK_HOST_ROUND ")
acks = records("host", "NETWORK_ROUND_ACK ")
if len(hosts) < args.rounds:
    failures.append(f"Host completed {len(hosts)} rounds, expected {args.rounds}")
if len(acks) < args.rounds * args.clients or any(not ack["matched"] for ack in acks):
    failures.append("Missing or mismatched client acknowledgements")
summary = {"transport": "ENet / loopback", "physical_input": False, "internet_test": False, "duration": args.duration, "requested_rounds": args.rounds, "clients": args.clients, "host_rounds": hosts, "acknowledgements": acks, "processes": {}}
summary["synthetic_impairment"] = {"rtt_ms": args.rtt, "jitter_ms": args.jitter, "loss": args.loss, "duplicates": args.duplicates}
summary["synthetic_bandwidth_bps_per_connection_each_direction"] = args.bandwidth_bps or None
summary["stage"] = args.stage
summary["transport"] = ("WebSocket" if args.websocket else "ENet") + " / loopback"
summary["roster"] = args.roster.split(",")
summary["process_exit_codes"] = {name: process.returncode for name, process in processes}
summary["rendered_client"] = args.render_client or None
summary["capture_in_frame_sample"] = args.capture_rendered
if args.embedded:
    executable = Path(args.engine).resolve()
    pack = next((executable.parents[1] / "Resources").glob("*.pck"))
    summary["native_runtime"] = {"binary_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(), "pack_sha256": hashlib.sha256(pack.read_bytes()).hexdigest()}
for name, _ in processes:
    text = (output / f"{name}.log").read_text()
    if "SCRIPT ERROR:" in text or "ERROR:" in text:
        failures.append(f"{name} logged a runtime error")
    ends = records(name, "NETWORK_TEST_END ")
    if not ends:
        failures.append(f"{name} did not complete the test")
        continue
    report = ends[-1]
    summary["processes"][name] = report
    metrics = report["metrics"]
    expected_rejections = 2 if args.probe_recovery and name == "host" else 0
    if metrics["state_mismatches"] or metrics["rejected_messages"] != expected_rejections:
        failures.append(f"{name} recorded state mismatches or rejected valid test packets")
    for round_report in report["rounds"]:
        if round_report["conservation_errors"]:
            failures.append(f"{name} equipment ownership failed")
    if name != "host":
        if args.bandwidth_bps and (metrics["ping_p95_ms"] >= 500 or metrics["ping_max_ms"] >= 2000):
            failures.append(f"{name} exceeded the paced-link latency limit")
        rounds = records(name, "NETWORK_CLIENT_ROUND ")
        if len(rounds) < args.rounds:
            failures.append(f"{name} completed too few rounds")
        for expected, actual in zip(hosts, rounds):
            if list(actual.get("network_peers", [])) != [1]:
                failures.append(f"{name} was not connected exclusively to the authority during play")
            if expected["digest"] != actual["digest"] or expected["scores"] != actual["scores"]:
                failures.append(f"{name} final world or score differs from host")
if args.probe_recovery:
    probes = records("client-1", "NETWORK_RECOVERY_PROBE ")
    summary["recovery_probes"] = probes
    if len(probes) != 1 or probes[0]["failures"]:
        failures.append("Reconnect or invalid-input probe failed")
summary["failures"] = failures
(output / "report.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps({"completed_host_rounds": len(hosts), "acknowledgements": len(acks), "failures": failures, "report": str(output / "report.json")}, indent=2))
raise SystemExit(bool(failures))
