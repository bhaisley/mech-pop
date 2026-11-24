#!/usr/bin/env python3
"""Bounded private-room gateway. Each room owns one headless Godot authority.

Only /health, room creation/lookup, and game WebSockets are exposed. Put HTTPS
in front with Caddy or a tunnel. The Godot ports bind to loopback only.
"""
import argparse
import asyncio
from collections import defaultdict, deque
from dataclasses import dataclass, field
import json
from pathlib import Path
import secrets
import time

from aiohttp import ClientSession, ClientTimeout, WSMsgType, web

ROOT = Path(__file__).resolve().parents[1]
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
PAGES_ORIGIN = "https://bhaisley.github.io"


def browser_access(origins):
    """Allow the game page to call the same room API as native clients."""
    @web.middleware
    async def middleware(request, handler):
        origin = request.headers.get("Origin")
        if not origin:
            return await handler(request)
        if origin not in origins:
            raise web.HTTPForbidden()
        if request.method == "OPTIONS":
            response = web.Response(status=204)
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "Content-Type"
            response.headers["Access-Control-Max-Age"] = "600"
        else:
            try:
                response = await handler(request)
            except web.HTTPException as error:
                error.headers["Access-Control-Allow-Origin"] = origin
                error.headers["Vary"] = "Origin"
                raise
        if not response.prepared:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Vary"] = "Origin"
        return response

    return middleware


@dataclass
class Room:
    code: str
    port: int
    process: asyncio.subprocess.Process
    created: float = field(default_factory=time.monotonic)
    last_active: float = field(default_factory=time.monotonic)
    sockets: set = field(default_factory=set)
    bridges: int = 0
    reader: asyncio.Task | None = None


class Gateway:
    def __init__(self, args):
        self.args = args
        # Native macOS app bundles may change their working directory on launch.
        # Give the child an absolute log path so readiness can still be observed.
        self.args.logs = self.args.logs.resolve()
        self.rooms = {}
        self.lock = asyncio.Lock()
        self.rates = defaultdict(deque)
        self.info = {}
        self.http = None
        self.sweeper = None
        self.test_routes = {}
        self.args.logs.mkdir(parents=True, exist_ok=True)

    def command(self):
        result = [self.args.engine, "--headless"]
        if self.args.pack:
            result += ["--main-pack", str(self.args.pack)]
        elif not self.args.embedded:
            result += ["--path", str(self.args.project)]
        return result

    async def start(self, _app):
        (self.args.logs / "version.log").unlink(missing_ok=True)
        command = self.command() + ["--log-file", str(self.args.logs / "version.log"), "--", "--network-info"]
        process = await asyncio.create_subprocess_exec(*command, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
        try:
            output, _ = await asyncio.wait_for(process.communicate(), 30)
        except TimeoutError:
            process.kill()
            await process.wait()
            raise RuntimeError("Game server version probe timed out")
        for line in output.decode(errors="replace").splitlines():
            if line.startswith("NETWORK_INFO "):
                self.info = json.loads(line.removeprefix("NETWORK_INFO "))
        if not self.info and (self.args.logs / "version.log").exists():
            for line in (self.args.logs / "version.log").read_text().splitlines():
                if line.startswith("NETWORK_INFO "):
                    self.info = json.loads(line.removeprefix("NETWORK_INFO "))
        if process.returncode or not self.info:
            raise RuntimeError("Could not verify game server: " + output.decode(errors="replace")[-2000:])
        self.http = ClientSession(timeout=ClientTimeout(total=None, sock_connect=5))
        self.sweeper = asyncio.create_task(self.sweep())
        print("ROOM_GATEWAY " + json.dumps(self.info), flush=True)

    def rate_limit(self, request, creating=False):
        # Do not trust spoofable forwarding headers; this also bounds requests
        # globally when a reverse proxy connects through one local address.
        key = (request.remote or "unknown", creating)
        now = time.monotonic()
        records = self.rates[key]
        while records and records[0] < now - 60:
            records.popleft()
        if len(records) >= (6 if creating else 90):
            raise web.HTTPTooManyRequests()
        records.append(now)

    async def health(self, request):
        return web.json_response({**self.info, "available_rooms": max(0, self.args.max_rooms-len(self.rooms))})

    def get_room(self, code):
        room = self.rooms.get(code)
        if not room or room.process.returncode is not None:
            raise web.HTTPNotFound()
        return room

    async def lookup(self, request):
        self.rate_limit(request)
        room = self.get_room(request.match_info["code"])
        return web.json_response({"code": room.code, "connections": room.bridges, **self.info})

    async def create(self, request):
        self.rate_limit(request, True)
        try:
            details = await request.json()
        except (ValueError, UnicodeError):
            raise web.HTTPBadRequest()
        if not isinstance(details, dict) or details.get("protocol") != self.info["protocol"] or details.get("fingerprint") != self.info["fingerprint"]:
            if isinstance(details, dict):
                print("ROOM_VERSION_MISMATCH " + json.dumps({"protocol": str(details.get("protocol"))[:16], "fingerprint": str(details.get("fingerprint"))[:64], "expected": self.info["fingerprint"]}), flush=True)
            raise web.HTTPConflict()
        async with self.lock:
            if len(self.rooms) >= self.args.max_rooms:
                raise web.HTTPServiceUnavailable()
            code = "".join(secrets.choice(ALPHABET) for _ in range(6))
            while code in self.rooms:
                code = "".join(secrets.choice(ALPHABET) for _ in range(6))
            used = {r.port for r in self.rooms.values()}
            port = next(p for p in range(self.args.first_game_port, self.args.first_game_port+self.args.max_rooms) if p not in used)
            command = self.command() + ["--log-file", str(self.args.logs / (code + ".engine.log")), "--", "--server", "--net-websocket", f"--net-host={port}", f"--net-code={code}", f"--net-test-duration={self.args.match_seconds}"]
            if self.args.test_auto_start:
                command.append(f"--net-auto-start={self.args.test_auto_start}")
            if self.args.test_stage:
                command.append(f"--stage={self.args.test_stage}")
            if self.args.test_roster:
                command.append(f"--roster={self.args.test_roster}")
            if self.args.test_rematch:
                command.append("--net-rematch")
            process = await asyncio.create_subprocess_exec(*command, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
            room = Room(code, port, process)
            self.rooms[code] = room
            room.reader = asyncio.create_task(self.read_log(room))
            try:
                await asyncio.wait_for(self.wait_ready(room), 12)
            except TimeoutError:
                await self.remove(room)
                raise web.HTTPServiceUnavailable()
        return web.json_response({"code": code, **self.info}, status=201)

    async def wait_ready(self, room):
        # A native macOS app writes Godot's engine log even when its bundle
        # entry point does not forward print() to the parent's stdout pipe.
        path = self.args.logs / (room.code + ".engine.log")
        while room.process.returncode is None:
            if path.exists() and "NETWORK_HOST " in path.read_text():
                return
            await asyncio.sleep(.05)
        raise TimeoutError("Room exited during startup")

    async def read_log(self, room):
        with (self.args.logs / (room.code + ".log")).open("wb") as log:
            while line := await room.process.stdout.readline():
                log.write(line)
                log.flush()
        await room.process.wait()

    async def play(self, request):
        self.rate_limit(request)
        room = self.get_room(request.match_info["code"])
        if room.bridges >= 4:
            raise web.HTTPConflict()
        # Reserve before yielding, so concurrent upgrades cannot exceed four.
        room.bridges += 1
        room.last_active = time.monotonic()
        external = web.WebSocketResponse(heartbeat=15, max_msg_size=262144, compress=False)
        internal = None
        try:
            internal = await self.http.ws_connect(f"http://127.0.0.1:{room.port}", max_msg_size=262144, compress=0, heartbeat=15)
            await external.prepare(request)
            room.sockets.add(external)
            if self.args.test_route_audit:
                # Only for an explicitly requested tunnel test. Keep addresses
                # in memory; logs show opaque per-run route numbers, never IPs.
                origin = request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
                if origin and len(origin) <= 128 and origin not in self.test_routes and len(self.test_routes) < 64:
                    self.test_routes[origin] = len(self.test_routes) + 1
                print("ROOM_TEST_ROUTE " + json.dumps({"room": room.code, "route": self.test_routes.get(origin, 0), "forwarded_origin_present": bool(origin)}), flush=True)

            async def copy(source, destination):
                count, start = 0, time.monotonic()
                async for message in source:
                    if message.type != WSMsgType.BINARY:
                        break
                    now = time.monotonic()
                    if now-start >= 1:
                        count, start = 0, now
                    count += len(message.data)
                    if count > 2_000_000:
                        break
                    room.last_active = now
                    await destination.send_bytes(message.data)

            tasks = [asyncio.create_task(copy(external, internal)), asyncio.create_task(copy(internal, external))]
            _, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
            for task in pending:
                task.cancel()
            await asyncio.gather(*tasks, return_exceptions=True)
        finally:
            room.sockets.discard(external)
            room.bridges -= 1
            room.last_active = time.monotonic()
            if internal:
                await internal.close()
            await external.close()
        return external

    async def remove(self, room):
        self.rooms.pop(room.code, None)
        for socket in tuple(room.sockets):
            await socket.close(code=1001, message=b"Room closed")
        if room.process.returncode is None:
            room.process.terminate()
            try:
                await asyncio.wait_for(room.process.wait(), 3)
            except TimeoutError:
                room.process.kill()
                await room.process.wait()
        if room.reader:
            await room.reader

    async def sweep(self):
        while True:
            await asyncio.sleep(5)
            now = time.monotonic()
            for room in tuple(self.rooms.values()):
                if room.process.returncode is not None or (not room.bridges and now-room.last_active > self.args.idle_seconds) or now-room.created > 21600:
                    await self.remove(room)
            for key in tuple(self.rates):
                if not self.rates[key] or self.rates[key][-1] < now-60:
                    self.rates.pop(key, None)

    async def stop(self, _app):
        if self.sweeper:
            self.sweeper.cancel()
            await asyncio.gather(self.sweeper, return_exceptions=True)
        for room in tuple(self.rooms.values()):
            await self.remove(room)
        if self.http:
            await self.http.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", default="/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--pack", type=Path)
    parser.add_argument("--embedded", action="store_true", help="Native export loads its bundled game pack")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=24880)
    parser.add_argument("--browser-origin", action="append", default=[PAGES_ORIGIN],
                        help="Additional browser game origin, e.g. http://localhost:8000")
    parser.add_argument("--first-game-port", type=int, default=24900)
    parser.add_argument("--max-rooms", type=int, choices=range(1, 17), default=4)
    parser.add_argument("--idle-seconds", type=float, default=300)
    parser.add_argument("--match-seconds", type=float, default=180)
    parser.add_argument("--test-auto-start", type=int, default=0, choices=range(5))
    parser.add_argument("--test-stage", choices=["skyport", "neon_alley", "junk_fields", "blossom_core", "reactor_ring"])
    parser.add_argument("--test-roster", help="Four comma-separated character IDs for an automated room")
    parser.add_argument("--test-rematch", action="store_true")
    parser.add_argument("--test-route-audit", action="store_true", help="Record opaque route numbers from test-tunnel forwarding headers; diagnostic only, never authentication")
    parser.add_argument("--logs", type=Path, default=ROOT / "work/room-server")
    args = parser.parse_args()
    if args.test_roster:
        characters = args.test_roster.split(",")
        if len(characters) != 4 or any(character not in ["nova", "kuren", "terra", "momo", "shadow", "lumi", "kai", "zero"] for character in characters):
            parser.error("The test roster must contain four existing character IDs")
    gateway = Gateway(args)
    app = web.Application(client_max_size=2048, middlewares=[browser_access(set(args.browser_origin))])
    app.add_routes([web.get("/health", gateway.health), web.post("/rooms", gateway.create), web.get("/rooms/{code}", gateway.lookup), web.get("/rooms/{code}/play", gateway.play)])
    app.on_startup.append(gateway.start)
    app.on_cleanup.append(gateway.stop)
    web.run_app(app, host=args.host, port=args.port, access_log=None)


if __name__ == "__main__":
    main()
