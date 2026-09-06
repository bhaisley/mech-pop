# Private room server — MECH★POP 0.2.0 preview

This service creates short-lived private game rooms. Each room has its own headless Godot authority. The gateway exposes the room API and forwards game WebSockets; the game ports stay on loopback. The native Mac app and the portable `game.pck` must have the same protocol and content fingerprint as the clients.

The release's **MECH_POP_0.2.0_build16_SERVER.zip** contains the Python service and portable game pack; it does not include an engine executable. Supply the Mac app from **MECH_POP_0.2.0_build16_macOS.zip**, or a standard Godot 4.7.2 engine with `--engine` and `--pack`. The Mac download includes both the app and service. Linux execution remains pending on the chosen host.

Build 16 passed automated native four-client room checks. Earlier Mac–iPad Internet rounds passed across separate networks, but additional responsiveness and recovery playtests remain open. There is no persistent production server included. See [testing and known limits](../docs/TESTING.md) for the tested builds and remaining checks.

## Start on the tested Mac

Python 3.11 or newer is required. From the package directory, create an isolated environment and install the pinned dependencies once:

```sh
python3 -m venv server/.venv
server/.venv/bin/python -m pip install -r server/requirements.txt
server/.venv/bin/python server/start_rooms.py --check
server/.venv/bin/python server/start_rooms.py --max-rooms 2
```

`start_rooms.py` locates `MECH POP 0.2.0.app` beside `server/`. In the source checkout it also recognizes `builds/expansion/MECH POP 0.2.0.app`. Use `--app '/absolute/path/to/the.app'` to choose another copy. The service runs in the foreground. Ctrl-C closes the gateway, connected sockets and its child game servers. It does not install a login service or change the firewall.

The default address is `http://127.0.0.1:24880`; this address is for local tests. `GET /health` returns the loaded game version, protocol, fingerprint and remaining room capacity. Logs stay in `server/logs/`. The default match is 180 seconds. `--max-rooms` bounds simultaneous rooms (default 4, range 1–16); each room permits at most four connections and four fighters, including parties sharing one connection and bots. An empty room expires after five minutes, and all rooms expire after six hours.

## A persistent public endpoint

Prepare a host close to the players, an approved public DNS name and HTTPS termination. A starting capacity of two rooms is proposed; CPU and memory sizing must be verified on the chosen host. No host, account purchase, DNS change or router forwarding is made by these files.

On Linux, install the standard [Godot 4.7.2 engine](https://godotengine.org/download/archive/4.7.2-stable/) matching the CPU architecture, Python 3.11+ and Caddy. The included portable `server/game.pck` is the same pack used by the Mac client. This pack's Linux execution still needs a smoke test on the selected host. Run:

```sh
server/.venv/bin/python server/start_rooms.py --engine /opt/mech-pop/bin/godot --pack server/game.pck --check
server/.venv/bin/python server/start_rooms.py --engine /opt/mech-pop/bin/godot --pack server/game.pck --max-rooms 2
```

`Caddyfile.example` proxies only to the loopback gateway. Set `MECH_POP_HOST` to the approved domain and point that domain's DNS records to the host. Caddy supports WebSocket upgrades and obtains/renews public certificates when DNS and ports 80/443 are configured. See Caddy's [reverse proxy documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy) and [HTTPS requirements](https://caddyserver.com/docs/quick-starts/https). Do not expose ports 24880 or 24900–24915 publicly. Keep administration access limited to the operator.

The optional systemd example assumes a dedicated `mechpop` user, `/opt/mech-pop`, a writable `server/logs` directory and `/var/lib/mechpop`. It directs Godot's Linux user data to the writable state directory using `XDG_DATA_HOME`. Review and adapt its paths before installing it. Restarting the service disconnects active rooms; it does not persist matches. Keep the previous package for rollback, stop the service, replace the complete versioned package, verify `/health`, then reopen rooms.

In the game choose **Play with Friends → Internet**, enter `https://your-approved-host`, create a room, and share the six-character code. Friends use the same server address. The first connected party leads the room and can select the map, configure bots and launch once parties are ready. Local Wi-Fi mode continues to use direct ENet connections independently of this service.

## Limits and acceptance

Rooms require knowledge of their code; there are no accounts, public listing or ranked matches. Room creation is limited to six requests per minute per direct gateway source, with 90 room lookups/upgrades per minute. Forwarding headers are not trusted, so a reverse proxy shares those limits across its clients. HTTP bodies are bounded at 2 KiB, game WebSocket messages at 256 KiB and each bridge direction at 2 MB/s. Room names never become shell commands or filesystem paths supplied by clients. This is a small private-play service, not a public matchmaking platform.

Before accepting a hosted endpoint, run a full match with the Mac and physical iPad on genuinely separate networks. Record p95 and maximum RTT, corrections, final world/score agreement, rejoining and server-loss behavior. The automated harness rejects p95 RTT above 500 ms and multi-second queues; passing those ceilings alone does not establish good fighting-game feel. The temporary Cloudflare tunnel exceeded those limits and is not an accepted hosting route. A same-Mac test through a public address does not count as a separate-network test.

Raw room logs can contain private room codes. Share validation extracts deliberately. No signing credentials or private keys are included in the package.
