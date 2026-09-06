# Multiplayer

MECH★POP supports local parties and authoritative four-fighter matches. Use matching game versions and content fingerprints on every participating device.

## One device

Use each player card's **Input** button to select Bot, Keyboard, Touch on iPad or a connected controller. Moving an input to a new player makes its previous player a bot. A/Cross edits a field, B/Circle returns, and separate Start presses join, ready and launch.

## Local Wi-Fi

Put the devices on the same local network. Choose **Play with Friends → Local Wi-Fi**. One device hosts and shares the address and room code shown in the game; the other enters those details to join. Connect the local party's controllers before joining.

Address entry is manual; automatic Bonjour discovery is not implemented. Allow Local Network access when prompted on iPad.

## Internet rooms

Run the included [room server](../server/README.md) behind an HTTPS/WebSocket endpoint. In **Play with Friends → Internet**, enter that endpoint and create or join a six-character room code. The first party leads the room and selects its arena and unclaimed bot slots.

The game does not include a permanent public matchmaking service. Deployments and latency depend on your chosen host. A temporary native Mac–iPad test across two different Internet connections completed a match and rematch with matching final results; human-rated responsiveness and recovery still need wider playtesting.

## Authority and recovery

- The authority simulates combat, equipment ownership, projectiles, respawns and scores at 120 Hz.
- Clients send bounded commands for their assigned players. Duplicate packets cannot repeat action edges, and stale held movement expires.
- Snapshots are validated before being applied. Client prediction covers local movement; combat and equipment remain authoritative.
- A disconnected party's slots are reserved for 20 seconds and temporarily driven by bots. Rejoining with the same local player count reclaims those slots.
- Host migration is not implemented. Server loss or stale match state produces a recovery message.

Build 16 uses protocol **4**, ruleset **mech-pop-0.2-network-4.0**, state format **2**. Print the exact content fingerprint with:

```sh
godot --headless --path . -- --network-info
```

`tools/test_network.py`, `tools/test_internet_rooms.py` and `tools/run_network_rotation.py` provide repeatable generated-input checks. Their local latency/loss simulations do not establish Internet performance. See [the validation summary](TESTING.md).
