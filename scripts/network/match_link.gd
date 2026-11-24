class_name MatchLink
extends Node

signal lobby_changed
signal start_match_requested(config: Dictionary, remote: bool)
signal status_changed(message: String)
signal round_verified(report: Dictionary)

const PROTOCOL: int = 4
const RULESET: String = "mech-pop-0.2-network-4.0"
const DEFAULT_PORT: int = 24872
const RECONNECT_SECONDS: float = 20.0
const MAX_SNAPSHOT_BYTES: int = 131072
const SNAPSHOT_CHUNK_BYTES: int = 1100
const MAX_WEBSOCKET_SNAPSHOTS: int = 2
const EVENT_KINDS: Array[String] = ["hit", "part_pop", "core_pop", "snap", "attack_active", "attack_start", "jump", "dodge", "land", "repair", "go", "final_thirty", "match_end", "part_loose", "attach_start", "recall", "respawn", "cannon_recoil", "phase_shift"]

var active: bool = false
var authority: bool = false
var dedicated: bool = false
var loading: bool = false
var mode: StringName = &"offline"
var status: String = ""
var session: MatchSession
var router: PlayerInputRouter
var peer: MultiplayerPeer
var websocket_transport: bool = false
var local_devices: Array[int] = [PlayerInputRouter.KEYBOARD]
var seats: Array[Dictionary] = []
var peers: Dictionary = {}
var awaiting_hello: Dictionary = {}
var input_buffers: Dictionary = {}
var local_history: Dictionary = {}
var local_sequence: int = 0
var round_number: int = 0
var configuration: Dictionary = {}
var pending_snapshot: Dictionary = {}
var snapshot_fragments: Dictionary = {}
var latest_snapshot_tick: int = -1
var events: Array[Dictionary] = []
var pending_events: Array[Dictionary] = []
var event_serial: int = 0
var last_event: int = 0
var final_digest: String = ""
var last_reported_round: int = 0
var room_code: String = ""
var resume_token: String = ""
var player_name: String = "PLAYER"
var address: String = ""
var port: int = DEFAULT_PORT
var suspended_local: bool = false
var bot_local_inputs: bool = false
var auto_start_peers: int = 0
var auto_rematch: bool = false
var test_duration: float = 180.0
var selected_stage: StringName = &"skyport"
var starting_characters: Array[StringName] = [&"nova", &"kuren", &"terra", &"momo"]
var clock: float = 0.0
var result_clock: float = 0.0
var heartbeat_clock: float = 0.0
var connection_clock: float = 0.0
var packet_clock: float = 0.0
var state_packet_clock: float = 0.0
var last_ping_msec: int = 0
var ping_ms: float = 0.0
var ping_samples: Array[float] = []
var test_latency_ms: float = 0.0
var test_jitter_ms: float = 0.0
var test_loss: float = 0.0
var test_duplicates: float = 0.0
var delayed_packets: Array[Dictionary] = []
var trace_clock: float = 0.0
var impairment_rng := RandomNumberGenerator.new()
var metrics: Dictionary = {"snapshots_sent": 0, "snapshots_received": 0, "bytes_sent": 0, "bytes_received": 0, "rejected_messages": 0, "state_mismatches": 0, "correction_samples": 0, "correction_total": 0.0, "correction_max": 0.0, "ping_p95_ms": 0.0, "ping_max_ms": 0.0, "ws_buffer_max": 0, "unacked_frames_max": 0, "snapshot_inflight_max": 0, "snapshot_backpressure_skips": 0, "input_frames_sent": 0}

func _ready() -> void:
	process_physics_priority = -50
	# Every client communicates only with the authority. Relaying virtual
	# client peers adds unnecessary connect/disconnect broadcasts.
	(multiplayer as SceneMultiplayer).server_relay = false
	MatchWire.prepare()
	impairment_rng.seed = 893413
	resume_token = Crypto.new().generate_random_bytes(16).hex_encode()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connect_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)

func content_fingerprint() -> String:
	var data: Array = [RULESET]
	for id in Roster.IDS: data.append(_resource_data(Roster.mech(id)))
	for id in Roster.all_modules(): data.append(_resource_data(Roster.part(id)))
	for id in StageCatalog.IDS: data.append(_resource_data(StageCatalog.stage(id)))
	return JSON.stringify(data, "", true).sha256_text()

func _resource_data(resource: Resource) -> Dictionary:
	var result: Dictionary = {}
	for property in resource.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_STORAGE:
			var value: Variant = resource.get(property.name)
			result[property.name] = _resource_data(value) if value is Resource else value
	return result

func host(listen_port: int = DEFAULT_PORT, devices: Array[int] = [PlayerInputRouter.KEYBOARD], code: String = "", websocket: bool = false) -> Error:
	close()
	if listen_port < 1024 or listen_port > 65535 or devices.size() > 4: return ERR_INVALID_PARAMETER
	port = listen_port
	local_devices = devices.duplicate()
	dedicated = devices.is_empty()
	authority = true
	room_code = code.strip_edges().to_upper()
	websocket_transport = websocket
	var error: Error
	if websocket:
		var socket := WebSocketMultiplayerPeer.new()
		socket.inbound_buffer_size = 262144
		socket.outbound_buffer_size = 262144
		socket.handshake_timeout = 8.0
		error = socket.create_server(port, "127.0.0.1" if dedicated else "*")
		peer = socket
	else:
		var enet := ENetMultiplayerPeer.new()
		error = enet.create_server(port, 4, 4)
		peer = enet
	if error != OK:
		_set_status("Could not open this room. Try another port.")
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	mode = &"lobby"
	seats.clear()
	for slot in range(4):
		seats.append({"slot": slot, "peer": 1 if slot < devices.size() else 0, "character": String(starting_characters[slot]), "name": player_name if slot < devices.size() else "BOT", "ready": true, "connected": true, "reserved_until": 0.0})
	_publish_lobby()
	_set_status("Room open. Waiting for friends.")
	print("NETWORK_HOST ", JSON.stringify({"port": port, "dedicated": dedicated, "protocol": PROTOCOL, "transport": "WebSocket" if websocket else "ENet"}))
	return OK

func join(host_address: String, host_port: int = DEFAULT_PORT, devices: Array[int] = [PlayerInputRouter.KEYBOARD], code: String = "") -> Error:
	close()
	if host_address.strip_edges().is_empty() or host_address.length() > 512 or host_port < 1024 or host_port > 65535 or devices.is_empty() or devices.size() > 4: return ERR_INVALID_PARAMETER
	address = host_address.strip_edges()
	port = host_port
	local_devices = devices.duplicate()
	room_code = code.strip_edges().to_upper()
	websocket_transport = address.begins_with("wss://") or address.begins_with("ws://")
	var error: Error
	if websocket_transport:
		var socket := WebSocketMultiplayerPeer.new()
		socket.inbound_buffer_size = 262144
		socket.outbound_buffer_size = 262144
		socket.handshake_timeout = 8.0
		error = socket.create_client(address)
		peer = socket
	else:
		var enet := ENetMultiplayerPeer.new()
		error = enet.create_client(address, port, 4)
		peer = enet
	if error != OK:
		_set_status("Could not connect. Check the room address.")
		return error
	multiplayer.multiplayer_peer = peer
	active = true
	mode = &"connecting"
	connection_clock = 0.0
	packet_clock = 0.0
	state_packet_clock = 0.0
	_set_status("Connecting to the room…")
	return OK

func close() -> void:
	active = false
	authority = false
	loading = false
	mode = &"offline"
	if is_inside_tree(): multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if peer: peer.close()
	peer = null
	detach_match()
	seats.clear()
	peers.clear()
	awaiting_hello.clear()
	input_buffers.clear()
	local_history.clear()
	events.clear()
	pending_events.clear()
	pending_snapshot.clear()
	snapshot_fragments.clear()
	delayed_packets.clear()
	round_number = 0
	latest_snapshot_tick = -1
	final_digest = ""
	last_reported_round = 0
	suspended_local = false

func detach_match() -> void:
	if is_instance_valid(session):
		if session.tick_completed.is_connected(_tick_completed): session.tick_completed.disconnect(_tick_completed)
		if session.combat_event.is_connected(_collect_event): session.combat_event.disconnect(_collect_event)
		if session.match_finished.is_connected(_match_finished): session.match_finished.disconnect(_match_finished)
		session.command_source = Callable()
	session = null

func bind_match(match_session: MatchSession) -> void:
	detach_match()
	session = match_session
	session.replica = not authority
	session.simulation_enabled = false
	session.command_source = _command_for_slot if authority else Callable()
	_sync_router()
	for fighter in session.fighters:
		fighter.network_replica = not authority
		fighter.network_local = owns(fighter.slot)
		fighter.network_visual_origin = fighter.position
		fighter.network_visual_target = fighter.position
		fighter.network_visual_interval = 0.06 if websocket_transport else 0.04
	if authority:
		session.tick_completed.connect(_tick_completed)
		session.combat_event.connect(_collect_event)
		session.match_finished.connect(_match_finished)
		_release_loading()
	else:
		_client_loaded.rpc_id(1, round_number)

func owns(slot: int) -> bool:
	return active and slot >= 0 and slot < seats.size() and seats[slot].peer == multiplayer.get_unique_id()

func own_slots() -> Array[int]:
	var result: Array[int] = []
	for slot in range(seats.size()):
		if owns(slot): result.append(slot)
	return result

func _sync_router() -> void:
	if router == null or seats.size() != 4: return
	var local_index: int = 0
	for slot in range(4):
		var seat: Dictionary = seats[slot]
		if owns(slot):
			router.devices[slot] = local_devices[local_index] if local_index < local_devices.size() else PlayerInputRouter.BOT
			local_index += 1
		elif seat.peer == 0 or not seat.connected: router.devices[slot] = PlayerInputRouter.BOT
		else: router.devices[slot] = PlayerInputRouter.REMOTE

func _peer_connected(id: int) -> void:
	if peer is ENetMultiplayerPeer and (authority or id == 1):
		# Cold startup can briefly lower ENet's unreliable packet throttle.
		# Recover on a one-second window, before the state-silence timeout.
		(peer as ENetMultiplayerPeer).get_peer(id).throttle_configure(1000, 32, 2)
	if websocket_transport and not OS.has_feature("web") and peer is WebSocketMultiplayerPeer and (authority or id == 1):
		peer.get_peer(id).set_no_delay(true)
	if active and authority: awaiting_hello[id] = clock

func _connected() -> void:
	if not active or authority: return
	if websocket_transport and not OS.has_feature("web"):
		(peer as WebSocketMultiplayerPeer).get_peer(1).set_no_delay(true)
	_hello.rpc_id(1, PROTOCOL, content_fingerprint(), {"players": local_devices.size(), "name": player_name.substr(0, 24), "room": room_code, "resume": resume_token})

@rpc("any_peer", "call_remote", "reliable", 0)
func _hello(version: int, fingerprint: String, details: Dictionary) -> void:
	if not active or not authority: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not awaiting_hello.has(sender): return
	awaiting_hello.erase(sender)
	if version != PROTOCOL or fingerprint != content_fingerprint():
		_reject_peer(sender, "Different game versions. Update both devices.")
		return
	if details.get("room", "") != room_code:
		_reject_peer(sender, "That room code does not match.")
		return
	if not details.get("players") is int or details.players < 1 or details.players > 4 or not details.get("name") is String or details.name.length() > 24 or not details.get("resume") is String or details.resume.length() != 32:
		_reject_peer(sender, "Invalid player details.")
		return
	var available: Array[int] = []
	for slot in range(4):
		if seats[slot].peer == 0: available.append(slot)
	# A resume token reclaims only this party's disconnected slots.
	for old_id in peers.keys():
		var old: Dictionary = peers[old_id]
		if not old.connected and old.token == details.resume and clock < old.reserved_until:
			var reserved: Array[int] = []
			for slot in range(4):
				if seats[slot].peer == old_id: reserved.append(slot)
			if reserved.size() != details.players:
				_reject_peer(sender, "Reconnect with the same number of local players, or wait 20 seconds for the old slots to reopen.")
				return
			available = reserved
			peers.erase(old_id)
			break
	if available.size() < details.players:
		_reject_peer(sender, "This room does not have enough open player slots.")
		return
	peers[sender] = {"token": details.resume, "connected": true, "loaded": false, "reserved_until": 0.0, "input_time": clock, "messages": 0, "message_clock": clock, "snapshot_ticks": []}
	for index in range(details.players):
		var slot: int = available[index]
		seats[slot].peer = sender
		seats[slot].name = details.name if not details.name.is_empty() else "PLAYER"
		seats[slot].connected = true
		seats[slot].ready = bot_local_inputs
		seats[slot].reserved_until = 0.0
		input_buffers[slot] = NetworkInputBuffer.new()
	_publish_lobby()
	if mode == &"match" or mode == &"results":
		_begin_round.rpc_id(sender, configuration)
	print("NETWORK_PEER_JOINED ", JSON.stringify({"players": details.players, "connected_peers": connected_peer_count()}))

func _reject_peer(id: int, message: String) -> void:
	_refused.rpc_id(id, message)
	await get_tree().create_timer(0.2).timeout
	if active and authority and peer and multiplayer.get_peers().has(id): peer.disconnect_peer(id)

@rpc("authority", "call_remote", "reliable", 0)
func _refused(message: String) -> void:
	if authority: return
	close()
	_set_status(message.substr(0, 200))
	lobby_changed.emit()

func _connect_failed() -> void:
	if not active: return
	close()
	_set_status("Could not reach the room. Check Wi-Fi, address and local-network access.")
	lobby_changed.emit()

func _server_disconnected() -> void:
	if not active or authority: return
	if session: session.paused = true
	close()
	_set_status("Connection lost. Return to the room to reconnect.")
	lobby_changed.emit()

func _peer_disconnected(id: int) -> void:
	if not active or not authority: return
	awaiting_hello.erase(id)
	if not peers.has(id): return
	peers[id].connected = false
	peers[id].reserved_until = clock + RECONNECT_SECONDS
	for slot in range(4):
		if seats[slot].peer == id:
			seats[slot].connected = false
			seats[slot].ready = false
			seats[slot].reserved_until = clock + RECONNECT_SECONDS
			if input_buffers.has(slot): input_buffers[slot].clear()
	_publish_lobby()
	_release_loading()

func _publish_lobby() -> void:
	_sync_router()
	for id in peers:
		if peers[id].connected and _transport_connected(id): _lobby.rpc_id(id, seats, String(mode), String(selected_stage), leader_peer())
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable", 0)
func _lobby(state: Array, phase: String, arena: String, leader: int) -> void:
	if authority or not active or state.size() != 4: return
	if not StageCatalog.IDS.has(StringName(arena)) or leader < 0: return
	for index in range(4):
		var seat: Variant = state[index]
		if not seat is Dictionary or seat.get("slot") != index or not seat.get("peer") is int or seat.peer < 0 or not Roster.IDS.has(StringName(str(seat.get("character", "")))): return
		if not seat.get("connected") is bool or not seat.get("ready") is bool or not seat.get("name") is String or seat.name.length() > 24: return
	seats.assign(state)
	selected_stage = StringName(arena)
	room_leader = leader
	if phase in ["lobby", "match", "results"]: mode = StringName(phase)
	_sync_router()
	packet_clock = 0.0
	_set_status("Connected. Choose your mech and ready up.")
	lobby_changed.emit()

func set_ready(ready: bool) -> void:
	if not active: return
	if authority: _set_peer_ready(1, ready)
	else: _ready_request.rpc_id(1, ready)

@rpc("any_peer", "call_remote", "reliable", 0)
func _ready_request(ready: bool) -> void:
	if not active or not authority: return
	var sender: int = multiplayer.get_remote_sender_id()
	if peers.has(sender) and peers[sender].connected: _set_peer_ready(sender, ready)

func _set_peer_ready(id: int, ready: bool) -> void:
	if mode not in [&"lobby", &"results"]: return
	for seat in seats:
		if seat.peer == id: seat.ready = ready
	_publish_lobby()

func choose_character(slot: int, id: StringName) -> void:
	if not active or not can_choose(slot) or not Roster.IDS.has(id): return
	if authority: _set_character(1, slot, String(id))
	else: _character_request.rpc_id(1, slot, String(id))

@rpc("any_peer", "call_remote", "reliable", 0)
func _character_request(slot: int, id: String) -> void:
	if active and authority: _set_character(multiplayer.get_remote_sender_id(), slot, id)

func _set_character(sender: int, slot: int, id: String) -> void:
	if mode not in [&"lobby", &"results"] or slot < 0 or slot > 3 or not Roster.IDS.has(StringName(id)): return
	if seats[slot].peer != sender and not (seats[slot].peer == 0 and sender == leader_peer()): return
	seats[slot].character = id
	seats[slot].ready = seats[slot].peer == 0
	_publish_lobby()

var room_leader: int = 1

func leader_peer() -> int:
	if not authority: return room_leader
	if not dedicated: return 1
	for seat in seats:
		if seat.peer > 0 and seat.connected: return seat.peer
	return 0

func can_manage_room() -> bool:
	return active and multiplayer.get_unique_id() == leader_peer()

func can_choose(slot: int) -> bool:
	return owns(slot) or (can_manage_room() and slot >= 0 and slot < seats.size() and seats[slot].peer == 0)

func choose_stage(id: StringName) -> void:
	if not can_manage_room() or mode not in [&"lobby", &"results"] or not StageCatalog.IDS.has(id): return
	if authority: _set_stage(id)
	else: _stage_request.rpc_id(1, String(id))

@rpc("any_peer", "call_remote", "reliable", 0)
func _stage_request(id: String) -> void:
	if authority and multiplayer.get_remote_sender_id() == leader_peer() and mode in [&"lobby", &"results"] and StageCatalog.IDS.has(StringName(id)):
		_set_stage(StringName(id))

func _set_stage(id: StringName) -> void:
	selected_stage = id
	for seat in seats:
		if seat.peer != 0: seat.ready = false
	_publish_lobby()

func launch_room() -> void:
	if not can_manage_room(): return
	if authority: request_start()
	else: _launch_request.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable", 0)
func _launch_request() -> void:
	if authority and multiplayer.get_remote_sender_id() == leader_peer(): request_start()

func connected_peer_count() -> int:
	var count: int = 1 if not local_devices.is_empty() else 0
	for info in peers.values():
		if info.connected: count += 1
	return count

func request_start(force: bool = false) -> bool:
	if not active or not authority or mode not in [&"lobby", &"results"]: return false
	for seat in seats:
		if not force and seat.peer != 0 and seat.connected and not seat.ready:
			_set_status("Waiting for every player to ready up.")
			return false
	round_number += 1
	var characters: Array[String] = []
	for seat in seats: characters.append(seat.character)
	configuration = {"round": round_number, "characters": characters, "duration": test_duration, "difficulty": 1, "stage": String(selected_stage)}
	mode = &"match"
	loading = true
	for id in peers:
		peers[id].loaded = false
		if peers[id].connected: _begin_round.rpc_id(id, configuration)
	_start_round(configuration)
	_publish_lobby()
	return true

@rpc("authority", "call_remote", "reliable", 0)
func _begin_round(config: Dictionary) -> void:
	if authority or not active: return
	if not StageCatalog.IDS.has(StringName(str(config.get("stage", "")))): return
	if not config.get("round") is int or config.round < round_number or not config.get("characters") is Array or config.characters.size() != 4 or not MatchWire.number(config.get("duration")) or config.duration < 1.0 or config.duration > 1800.0: return
	for id in config.characters:
		if not Roster.IDS.has(StringName(str(id))): return
	round_number = config.round
	configuration = config.duplicate(true)
	mode = &"match"
	loading = true
	_start_round(config)

func _start_round(config: Dictionary) -> void:
	input_buffers.clear()
	local_history.clear()
	for info in peers.values(): info.snapshot_ticks = []
	local_sequence = 0
	latest_snapshot_tick = -1
	pending_snapshot.clear()
	snapshot_fragments.clear()
	events.clear()
	pending_events.clear()
	event_serial = 0
	last_event = 0
	final_digest = ""
	result_clock = 0.0
	state_packet_clock = 0.0
	packet_clock = 0.0
	suspended_local = false
	for slot in range(4):
		input_buffers[slot] = NetworkInputBuffer.new()
		local_history[slot] = []
	if router: router.clear_state()
	start_match_requested.emit(config, not authority)

@rpc("any_peer", "call_remote", "reliable", 0)
func _client_loaded(round_id: int) -> void:
	if not active or not authority or round_id != round_number: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not peers.has(sender) or not peers[sender].connected: return
	peers[sender].loaded = true
	_release_loading()
	if session: _send_snapshot(sender, session.phase == &"results")

func _release_loading() -> void:
	if not authority or not session: return
	for info in peers.values():
		if info.connected and not info.loaded: return
	loading = false
	session.simulation_enabled = true
	_set_status("Match started.")

func _command_for_slot(slot: int, delta: float) -> FighterCommand:
	var seat: Dictionary = seats[slot]
	if seat.peer == 0 or not seat.connected: return session.fighters[slot].brain.command(session.fighters[slot], session, delta)
	if owns(slot): return _local_command(slot, delta)
	if peers.has(seat.peer) and not peers[seat.peer].loaded: return session.fighters[slot].brain.command(session.fighters[slot], session, delta)
	if input_buffers.has(slot): return input_buffers[slot].take(clock)
	return FighterCommand.new()

func _local_command(slot: int, delta: float) -> FighterCommand:
	if suspended_local: return FighterCommand.new()
	if bot_local_inputs or router.devices[slot] == PlayerInputRouter.BOT: return session.fighters[slot].brain.command(session.fighters[slot], session, delta)
	return router.command_for(slot)

func _physics_process(delta: float) -> void:
	if not active: return
	if not authority and not pending_snapshot.is_empty() and session:
		_apply_pending()
	if authority or session == null or session.phase != &"fight" or loading: return
	local_sequence += 1
	var batch: Array = []
	for slot in own_slots():
		var command: FighterCommand = _local_command(slot, delta)
		var history: Array = local_history[slot]
		history.append(NetworkInputBuffer.pack(local_sequence, command))
		while history.size() > 120: history.pop_front()
		session.fighters[slot].step(command, delta)
		# TCP already delivers each WebSocket command. Keep UDP redundancy on
		# ENet, but send each new command just once on the reliable stream.
		var frame_count: int = 2 if websocket_transport else 12
		batch.append({"slot": slot, "frames": history.slice(maxi(0, history.size() - frame_count))})
	if local_sequence % 2 == 0 and not batch.is_empty():
		for entry in batch: metrics.input_frames_sent += entry.frames.size()
		_send_unreliable(1, &"_inputs", [round_number, batch])

@rpc("any_peer", "call_remote", "unreliable", 1)
func _inputs(round_id: int, batch: Array) -> void:
	if not active or not authority or round_id != round_number or session == null or session.phase != &"fight" or batch.is_empty() or batch.size() > 4: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not peers.has(sender) or not peers[sender].connected: return
	var info: Dictionary = peers[sender]
	if clock - float(info.message_clock) > 1.0:
		info.message_clock = clock
		info.messages = 0
	info.messages += 1
	if info.messages > 180:
		metrics.rejected_messages += 1
		return
	var seen: Dictionary = {}
	for entry in batch:
		if not entry is Dictionary or not entry.get("slot") is int or entry.slot < 0 or entry.slot > 3 or seats[entry.slot].peer != sender or seen.has(entry.slot) or not entry.get("frames") is Array:
			metrics.rejected_messages += 1
			return
		seen[entry.slot] = true
	for entry in batch:
		if not input_buffers[entry.slot].push(entry.frames, clock): metrics.rejected_messages += 1
	info.input_time = clock

func _tick_completed() -> void:
	if not active or not authority or session == null: return
	var snapshot_stride: int = 6 if websocket_transport else 4
	if session.tick % snapshot_stride == 0: _send_snapshot()
	if session.tick % 4 == 0:
		if not events.is_empty():
			for id in peers:
				if peers[id].connected and peers[id].loaded and _transport_connected(id): _effects.rpc_id(id, round_number, events)
			events.clear()

func _send_snapshot(target: int = 0, terminal: bool = false) -> void:
	if session == null: return
	var ack: Array[int] = []
	for slot in range(4): ack.append(input_buffers[slot].consumed if input_buffers.has(slot) else 0)
	var state: Dictionary = MatchWire.capture(session)
	var envelope: Dictionary = {"state": state, "acks": ack, "terminal": terminal, "loading": loading}
	var raw: PackedByteArray = var_to_bytes(envelope)
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_u32(0, raw.size())
	bytes.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	for id in peers:
		if not peers[id].connected or not peers[id].loaded or not _transport_connected(id) or (target != 0 and target != id): continue
		if terminal: _final_snapshot.rpc_id(id, round_number, bytes)
		elif websocket_transport:
			# WebSockets frame/reassemble on a reliable stream. ENet's small UDP
			# fragments only multiply tiny TCP records and queueing on a proxy.
			var buffered: int = (peer as WebSocketMultiplayerPeer).get_peer(id).get_current_outbound_buffered_amount()
			metrics.ws_buffer_max = maxi(metrics.ws_buffer_max, buffered)
			var inflight: Array = peers[id].snapshot_ticks
			# A proxy can consume the local socket while its remote link is
			# congested. Bound state waiting for actual client application too.
			if buffered > 8192 or inflight.size() >= MAX_WEBSOCKET_SNAPSHOTS:
				metrics.snapshot_backpressure_skips += 1
				continue
			inflight.append(session.tick)
			metrics.snapshot_inflight_max = maxi(metrics.snapshot_inflight_max, inflight.size())
			_send_unreliable(id, &"_snapshot", [round_number, session.tick, 0, 1, bytes])
		else:
			var chunks: int = ceili(float(bytes.size()) / SNAPSHOT_CHUNK_BYTES)
			for index in range(chunks):
				_send_unreliable(id, &"_snapshot", [round_number, session.tick, index, chunks, bytes.slice(index * SNAPSHOT_CHUNK_BYTES, (index + 1) * SNAPSHOT_CHUNK_BYTES)])
		metrics.snapshots_sent += 1
		metrics.bytes_sent += bytes.size()

@rpc("any_peer", "call_remote", "reliable", 0)
func _snapshot_received(round_id: int, tick: int) -> void:
	if not active or not authority or not websocket_transport or round_id != round_number: return
	var sender: int = multiplayer.get_remote_sender_id()
	if not peers.has(sender) or not peers[sender].connected or not peers[sender].loaded: return
	var inflight: Array = peers[sender].snapshot_ticks
	if not inflight.has(tick): return
	while not inflight.is_empty() and int(inflight[0]) <= tick: inflight.pop_front()

@rpc("authority", "call_remote", "unreliable", 1)
func _snapshot(round_id: int, tick: int, index: int, count: int, packet: PackedByteArray) -> void:
	if not active or authority or round_id != round_number or tick < latest_snapshot_tick or count < 1 or count > 120 or index < 0 or index >= count or packet.is_empty() or packet.size() > (65536 if websocket_transport and count == 1 else SNAPSHOT_CHUNK_BYTES): return
	if count == 1:
		_accept_packet(round_id, packet)
		return
	for old_tick in snapshot_fragments.keys():
		if old_tick < latest_snapshot_tick or clock - float(snapshot_fragments[old_tick].created) > 0.5: snapshot_fragments.erase(old_tick)
	if not snapshot_fragments.has(tick):
		if snapshot_fragments.size() >= 8: snapshot_fragments.erase(snapshot_fragments.keys().min())
		snapshot_fragments[tick] = {"count": count, "chunks": {}, "created": clock}
	var fragments: Dictionary = snapshot_fragments[tick]
	if fragments.count != count: return
	fragments.chunks[index] = packet
	if fragments.chunks.size() == count:
		var assembled := PackedByteArray()
		for part in range(count): assembled.append_array(fragments.chunks[part])
		snapshot_fragments.erase(tick)
		_accept_packet(round_id, assembled)

@rpc("authority", "call_remote", "reliable", 0)
func _final_snapshot(round_id: int, packet: PackedByteArray) -> void:
	_accept_packet(round_id, packet)

func _accept_packet(round_id: int, packet: PackedByteArray) -> void:
	if not active or authority or round_id != round_number or packet.size() < 5 or packet.size() > 65536: return
	var raw_size: int = packet.decode_u32(0)
	if raw_size < 32 or raw_size > MAX_SNAPSHOT_BYTES: return
	var decoded: PackedByteArray = packet.slice(4).decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if decoded.is_empty(): return
	var envelope: Variant = bytes_to_var(decoded)
	if not envelope is Dictionary or not envelope.get("state") is Dictionary or not envelope.get("acks") is Array or envelope.acks.size() != 4 or not envelope.get("terminal") is bool or not envelope.get("loading") is bool: return
	for ack in envelope.acks:
		if not ack is int or ack < 0 or ack > 2147483647: return
	if not MatchWire.valid(envelope.state):
		metrics.rejected_messages += 1
		return
	var tick: int = envelope.state.tick
	if tick < latest_snapshot_tick or (not pending_snapshot.is_empty() and tick < int(pending_snapshot.state.tick)): return
	if not pending_snapshot.is_empty() and pending_snapshot.terminal and not envelope.terminal: return
	if not final_digest.is_empty() and not envelope.terminal: return
	pending_snapshot = envelope
	metrics.bytes_received += packet.size()
	packet_clock = 0.0
	state_packet_clock = 0.0

func _apply_pending() -> void:
	var envelope: Dictionary = pending_snapshot
	pending_snapshot = {}
	var before: Array[Vector2] = []
	var old_alive: Array[bool] = []
	for fighter in session.fighters:
		before.append(fighter.position)
		old_alive.append(fighter.alive())
		if not fighter.network_local:
			fighter.network_visual_origin = fighter.network_visual_origin.lerp(fighter.network_visual_target, clampf(fighter.network_visual_elapsed / fighter.network_visual_interval, 0.0, 1.0))
	if not MatchWire.restore(session, envelope.state):
		metrics.rejected_messages += 1
		return
	latest_snapshot_tick = session.tick
	metrics.snapshots_received += 1
	if websocket_transport and not envelope.terminal and _transport_connected(1):
		_snapshot_received.rpc_id(1, round_number, latest_snapshot_tick)
	for slot in own_slots(): metrics.unacked_frames_max = maxi(metrics.unacked_frames_max, local_sequence - int(envelope.acks[slot]))
	# A first snapshot can arrive while another device is still creating its
	# scene. Preserve the authority's loading state until simulation resumes.
	loading = envelope.loading
	# Verify before local prediction; after prediction local positions intentionally lead authority.
	var restored_digest: String = MatchWire.digest(MatchWire.capture(session))
	if restored_digest != MatchWire.digest(envelope.state): metrics.state_mismatches += 1
	for fighter in session.fighters:
		var slot: int = fighter.slot
		if fighter.network_local:
			var ack: int = envelope.acks[slot]
			var retained: Array = []
			for frame in local_history.get(slot, []):
				if frame[0] > ack: retained.append(frame)
			local_history[slot] = retained
			if session.phase == &"fight":
				for frame in retained: fighter.step(NetworkInputBuffer.unpack(frame), 1.0 / 120.0)
			var correction: Vector2 = before[slot] - fighter.position
			if fighter.network_visual_ready and old_alive[slot] == fighter.alive():
				metrics.correction_samples += 1
				metrics.correction_total += correction.length()
				metrics.correction_max = maxf(metrics.correction_max, correction.length())
				fighter.network_visual_offset += correction
				if fighter.network_visual_offset.length() > 250.0: fighter.network_visual_offset = Vector2.ZERO
			else: fighter.network_visual_offset = Vector2.ZERO
		else:
			fighter.network_visual_target = fighter.position
			fighter.network_visual_elapsed = 0.0
			if not fighter.network_visual_ready or before[slot].distance_to(fighter.position) > 600.0:
				fighter.network_visual_origin = fighter.position
		fighter.network_visual_ready = true
	_flush_effects()
	if envelope.terminal and last_reported_round != round_number:
		final_digest = MatchWire.digest(envelope.state)
		mode = &"results"
		last_reported_round = round_number
		var report: Dictionary = _round_report(final_digest)
		_round_ack.rpc_id(1, round_number, final_digest, metrics.state_mismatches)
		round_verified.emit(report)
		print("NETWORK_CLIENT_ROUND ", JSON.stringify(report))
		session.match_finished.emit()

func _collect_event(kind: StringName, payload: Dictionary) -> void:
	if not authority or not EVENT_KINDS.has(String(kind)): return
	event_serial += 1
	var event: Dictionary = MatchWire.event_to_wire(kind, payload)
	event.id = event_serial
	events.append(event)

@rpc("authority", "call_remote", "reliable", 2)
func _effects(round_id: int, batch: Array) -> void:
	if not active or authority or round_id != round_number or batch.size() > 128: return
	for event in batch:
		if event is Dictionary and event.get("id") is int and event.id > last_event and MatchWire.valid_event(event) and pending_events.size() < 512:
			pending_events.append(event)
	if session and latest_snapshot_tick >= 0: _flush_effects()

func _flush_effects() -> void:
	for event in pending_events:
		if event.id <= last_event: continue
		last_event = event.id
		var payload: Dictionary = MatchWire.event_from_wire(session, event)
		session.combat_event.emit(StringName(event.kind), payload)
	pending_events.clear()

func _match_finished() -> void:
	if not authority or session == null: return
	mode = &"results"
	result_clock = 0.0
	final_digest = MatchWire.digest(MatchWire.capture(session))
	_send_snapshot(0, true)
	for seat in seats:
		if seat.peer != 0: seat.ready = false
	_publish_lobby()
	var report: Dictionary = _round_report(final_digest)
	round_verified.emit(report)
	print("NETWORK_HOST_ROUND ", JSON.stringify(report))

@rpc("any_peer", "call_remote", "reliable", 0)
func _round_ack(round_id: int, digest: String, mismatches: int) -> void:
	if not active or not authority or round_id != round_number or not peers.has(multiplayer.get_remote_sender_id()): return
	var matched: bool = digest == final_digest and mismatches == 0
	if not matched: metrics.state_mismatches += 1
	print("NETWORK_ROUND_ACK ", JSON.stringify({"round": round_id, "matched": matched, "snapshot_mismatches": mismatches, "digest": digest}))

func _round_report(digest: String) -> Dictionary:
	var scores: Array[int] = []
	for fighter in session.fighters: scores.append(fighter.score)
	return {"round": round_number, "tick": session.tick, "scores": scores, "winners": session.winners(), "events": session.event_counts.duplicate(), "digest": digest, "conservation_errors": session.parts.conservation_errors(), "metrics": metrics.duplicate(), "network_peers": multiplayer.get_peers(), "platform": OS.get_name(), "test_bot_inputs": bot_local_inputs, "synthetic_impairment": {"one_way_ms": test_latency_ms, "jitter_ms": test_jitter_ms, "loss": test_loss, "duplicates": test_duplicates}}

func _send_unreliable(target: int, method: StringName, arguments: Array) -> void:
	if not _transport_connected(target): return
	if test_latency_ms == 0.0 and test_jitter_ms == 0.0 and test_loss == 0.0 and test_duplicates == 0.0:
		callv("rpc_id", [target, method] + arguments)
		return
	if impairment_rng.randf() < test_loss: return
	var copies: int = 2 if impairment_rng.randf() < test_duplicates else 1
	for copy in range(copies):
		if delayed_packets.size() >= 1024: return
		var delay: float = maxf(0.0, test_latency_ms + impairment_rng.randf_range(-test_jitter_ms, test_jitter_ms) + copy * 7.0) / 1000.0
		delayed_packets.append({"at": clock + delay, "round": round_number, "target": target, "method": method, "arguments": arguments.duplicate(true)})

func _send_due_packets() -> void:
	for index in range(delayed_packets.size() - 1, -1, -1):
		var packet: Dictionary = delayed_packets[index]
		if packet.at > clock: continue
		delayed_packets.remove_at(index)
		if packet.round != round_number: continue
		if authority and (not peers.has(packet.target) or not peers[packet.target].connected): continue
		if not authority and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: continue
		if not _transport_connected(packet.target): continue
		callv("rpc_id", [packet.target, packet.method] + packet.arguments)

func _transport_connected(id: int) -> bool:
	if peer == null or not multiplayer.get_peers().has(id): return false
	if peer is ENetMultiplayerPeer:
		var connection: ENetPacketPeer = (peer as ENetMultiplayerPeer).get_peer(id)
		return connection != null and connection.get_state() == ENetPacketPeer.STATE_CONNECTED and connection.get_channels() > 0
	if peer is WebSocketMultiplayerPeer:
		var connection: WebSocketPeer = (peer as WebSocketMultiplayerPeer).get_peer(id)
		return connection != null and connection.get_ready_state() == WebSocketPeer.STATE_OPEN
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _process(delta: float) -> void:
	if not active: return
	clock += delta
	_send_due_packets()
	connection_clock += delta
	packet_clock += delta
	state_packet_clock += delta
	trace_clock += delta
	if OS.get_cmdline_user_args().has("--net-trace") and trace_clock > 0.5:
		trace_clock = 0.0
		var links: Array = []
		if peer is ENetMultiplayerPeer:
			for id in multiplayer.get_peers():
				if not authority and id != 1: continue
				var connection: ENetPacketPeer = (peer as ENetMultiplayerPeer).get_peer(id)
				if connection == null: continue
				links.append({"id": id, "state": connection.get_state(), "channels": connection.get_channels(), "rtt": connection.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME), "throttle": connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE), "loaded": peers.get(id, {}).get("loaded", false)})
		var trace: Dictionary = {"authority": authority, "clock": clock, "phase": session.phase if session else mode, "tick": session.tick if session else -1, "last_state": latest_snapshot_tick, "state_age": state_packet_clock, "loading": loading, "links": links}
		print("NETWORK_TRACE ", JSON.stringify(trace))
	heartbeat_clock += delta
	if authority:
		for id in awaiting_hello.keys():
			if clock - float(awaiting_hello[id]) > 8.0:
				peer.disconnect_peer(id)
				awaiting_hello.erase(id)
		var changed: bool = false
		for id in peers.keys():
			if not peers[id].connected and clock >= peers[id].reserved_until:
				for seat in seats:
					if seat.peer == id:
						seat.peer = 0
						seat.name = "BOT"
						seat.connected = true
						seat.ready = true
				peers.erase(id)
				changed = true
		if changed: _publish_lobby()
		if mode == &"lobby" and auto_start_peers > 0 and connected_peer_count() >= auto_start_peers:
			request_start(true)
		elif mode == &"results" and auto_rematch:
			result_clock += delta
			if result_clock > 2.0: request_start(true)
	else:
		if mode == &"connecting" and connection_clock > 12.0:
			_connect_failed()
			return
		if mode in [&"match", &"results"] and packet_clock > 8.0 and final_digest.is_empty():
			_server_disconnected()
			return
		if mode == &"match" and not loading and state_packet_clock > 3.0 and final_digest.is_empty():
			_server_disconnected()
			_set_status("Match updates stalled. Rejoin within 20 seconds to reclaim your players.")
			return
		var now: int = Time.get_ticks_msec()
		if peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED and now - last_ping_msec > 1000:
			last_ping_msec = now
			_send_unreliable(1, &"_ping", [now])
	if heartbeat_clock > 30.0:
		heartbeat_clock = 0.0
		print("NETWORK_HEARTBEAT ", JSON.stringify({"round": round_number, "mode": mode, "authority": authority, "ping_ms": ping_ms, "metrics": metrics, "conservation_errors": session.parts.conservation_errors() if session else []}))

@rpc("any_peer", "call_remote", "unreliable", 3)
func _ping(sent: int) -> void:
	if active and authority and peers.has(multiplayer.get_remote_sender_id()): _send_unreliable(multiplayer.get_remote_sender_id(), &"_pong", [sent])

@rpc("authority", "call_remote", "unreliable", 3)
func _pong(sent: int) -> void:
	if active and not authority:
		ping_ms = float(Time.get_ticks_msec() - sent)
		ping_samples.append(ping_ms)
		if ping_samples.size() > 512: ping_samples.pop_front()
		var ordered: Array[float] = ping_samples.duplicate()
		ordered.sort()
		metrics.ping_p95_ms = ordered[mini(ordered.size()-1, int(ordered.size() * 0.95))]
		metrics.ping_max_ms = maxf(metrics.ping_max_ms, ping_ms)
		if bot_local_inputs:
			print("NETWORK_PING ", JSON.stringify({"rtt_ms": ping_ms, "phase": session.phase if session else mode, "tick": latest_snapshot_tick, "local_sequence": local_sequence, "clock": snappedf(clock, 0.01)}))
		packet_clock = 0.0

func _set_status(message: String) -> void:
	status = message
	status_changed.emit(message)

func _exit_tree() -> void:
	close()
