extends Node
## PeerServer exchanges WebRTC offers and ICE candidates. MatchLink owns gameplay.
signal failed(message: String)

const SIGNAL_URL := "wss://0.peerjs.com/peerjs?key=peerjs"
const PREFIX := "mechpop-duel-"
const GAME := "mechpop-friends-v1"
const ICE := {"iceServers": [
	{"urls": ["stun:stun.l.google.com:19302"]},
	{"urls": ["turn:eu-0.turn.peerjs.com:3478", "turn:us-0.turn.peerjs.com:3478"], "username": "peerjs", "credential": "peerjsp"}
]}
const CHANNELS := [MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, MultiplayerPeer.TRANSFER_MODE_RELIABLE, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE]

var link: MatchLink
var socket: WebSocketPeer
var transport: WebRTCMultiplayerPeer
var connection: WebRTCPeerConnection
var hosting := false
var registered := false
var room := ""
var remote_id := ""
var negotiation := ""
var device: int
var character: StringName
var arena: StringName
var deadline := 0.0
var heartbeat := 0.0
var remote_description := false
var pending_ice: Array[Dictionary] = []

func start(host: bool, code: String, input_device: int, mech: StringName, stage: StringName) -> void:
	stop()
	hosting = host
	if code.length() != 32 or not code.is_valid_hex_number(false):
		_fail("This duel invite is incomplete.")
		return
	room = code
	device = input_device
	character = mech
	arena = stage
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	var id := PREFIX + (room if hosting else token)
	remote_id = "" if hosting else PREFIX + room
	negotiation = "" if hosting else token
	socket = WebSocketPeer.new()
	deadline = 12.0
	var error := socket.connect_to_url(SIGNAL_URL + "&id=" + id + "&token=" + Crypto.new().generate_random_bytes(16).hex_encode())
	if error != OK: _fail("Could not open the friend room service.")

func stop() -> void:
	if socket: socket.close()
	socket = null
	if connection: connection.close()
	connection = null
	transport = null
	registered = false
	remote_description = false
	pending_ice.clear()
	heartbeat = 0.0
	deadline = 0.0

func _fail(message: String) -> void:
	stop()
	failed.emit(message)

func _process(delta: float) -> void:
	if not socket: return
	if registered and not link.active:
		stop()
		return
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		# An established game no longer needs the signaling service.
		if connection and connection.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED:
			socket = null
		else: _fail("The friend room service disconnected. Open a new invite and try again.")
		return
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		heartbeat += delta
		if heartbeat >= 5.0:
			heartbeat = 0.0
			socket.send_text(JSON.stringify({"type": "HEARTBEAT"}))
		while socket and socket.get_available_packet_count() > 0:
			var packet := socket.get_packet()
			if packet.size() <= 65536:
				var msg: Variant = JSON.parse_string(packet.get_string_from_utf8())
				if msg is Dictionary: _message(msg)
	if not socket: return
	if registered and connection and connection.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED:
		deadline = 0.0
		# Once both players have seats, retire the invite. Their data channels
		# stay open for the full set, including rematches and chassis changes.
		if link.seats.size() == 2 and link.seats[1].peer != 0:
			socket.close()
			socket = null
			return
	if deadline > 0.0:
		deadline -= delta
		if deadline <= 0.0:
			if hosting and registered and link.peers.is_empty():
				if transport.has_peer(2): transport.remove_peer(2)
				if connection: connection.close()
				connection = null
				remote_id = ""
				negotiation = ""
			else: _fail("Could not join. The invite may be in use, or the network may require a server-backed private room.")

func _message(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"OPEN":
			if registered: return
			registered = true
			transport = WebRTCMultiplayerPeer.new()
			var err := transport.create_server(CHANNELS) if hosting else transport.create_client(2, CHANNELS)
			if err != OK:
				_fail("WebRTC data channels are unavailable in this browser.")
				return
			deadline = 0.0 if hosting else 23.0
			link.open_friend(transport, hosting, device, room, character, arena)
			if not hosting and _new_connection(1):
				if connection.create_offer() != OK: _fail("Could not start the duel connection.")
		"ID-TAKEN", "INVALID-KEY", "ERROR":
			_fail("The invite service could not register this room. Open a new room and try again.")
		"EXPIRE":
			if not hosting and (not connection or connection.get_connection_state() != WebRTCPeerConnection.STATE_CONNECTED):
				_fail("This invite is full or expired. Ask your friend to open a new duel.")
		"OFFER", "ANSWER", "CANDIDATE":
			_exchange(str(msg.type), str(msg.get("src", "")), msg.get("payload"))

func _new_connection(id: int) -> bool:
	remote_description = false
	pending_ice.clear()
	connection = WebRTCPeerConnection.new()
	if connection.initialize(ICE) != OK or transport.add_peer(connection, id, 100) != OK:
		_fail("This browser could not start a WebRTC data connection.")
		return false
	connection.session_description_created.connect(_description)
	connection.ice_candidate_created.connect(func(mid: String, index: int, candidate: String) -> void:
		_send("CANDIDATE", {"candidate": {"sdpMid": mid, "sdpMLineIndex": index, "candidate": candidate}}))
	return true

func _description(type: String, sdp: String) -> void:
	if not connection: return
	if connection.set_local_description(type, sdp) != OK:
		_fail("Could not finish negotiating the duel connection.")
		return
	_send(type.to_upper(), {"sdp": {"type": type, "sdp": sdp}})

func _send(kind: String, payload: Dictionary) -> void:
	if not socket or socket.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	payload.merge({"connectionId": negotiation, "type": "data"})
	if kind == "OFFER":
		payload.merge({"metadata": {"game": GAME}, "label": GAME, "reliable": true, "serialization": "raw"})
	socket.send_text(JSON.stringify({"type": kind, "dst": remote_id, "payload": payload}))

func _exchange(kind: String, sender: String, payload: Variant) -> void:
	if not registered or not sender.begins_with(PREFIX) or sender.length() != PREFIX.length() + 32: return
	if not payload is Dictionary or payload.get("type") != "data": return
	if kind == "OFFER" and payload.get("label") != GAME: return
	var id: String = str(payload.get("connectionId", ""))
	if id.length() != 32 or not id.is_valid_hex_number(false): return
	if kind == "OFFER" and hosting:
		if not remote_id.is_empty(): return
		if not _valid_sdp(payload, "offer"): return
		remote_id = sender
		negotiation = id
		deadline = 23.0
		if not _new_connection(2): return
	elif sender != remote_id or id != negotiation or not connection: return
	if kind == "CANDIDATE":
		var candidate: Variant = payload.get("candidate")
		if not candidate is Dictionary or not candidate.get("candidate") is String or candidate.candidate.length() > 2048 or not candidate.get("sdpMid") is String or candidate.sdpMid.length() > 32 or not MatchWire.number(candidate.get("sdpMLineIndex")): return
		if remote_description: _add_ice(candidate)
		elif pending_ice.size() < 64: pending_ice.append(candidate)
		return
	var type := "offer" if hosting else "answer"
	if remote_description or kind != type.to_upper() or not _valid_sdp(payload, type): return
	if connection.set_remote_description(type, payload.sdp.sdp) != OK:
		_fail("The two browsers could not negotiate a duel.")
		return
	remote_description = true
	for candidate in pending_ice: _add_ice(candidate)
	pending_ice.clear()

func _valid_sdp(payload: Dictionary, type: String) -> bool:
	var desc: Variant = payload.get("sdp")
	return desc is Dictionary and desc.get("type") == type and desc.get("sdp") is String and desc.sdp.length() < 49152

func _add_ice(candidate: Dictionary) -> void:
	connection.add_ice_candidate(candidate.sdpMid, int(candidate.sdpMLineIndex), candidate.candidate)
