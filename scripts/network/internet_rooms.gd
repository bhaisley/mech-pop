class_name InternetRooms
extends Node

signal room_ready(code: String, socket_url: String)
signal status_changed(message: String)

const CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
var busy: bool = false
var server_url: String = ""
var request: HTTPRequest
var origin: String = ""

func _ready() -> void:
	request = HTTPRequest.new()
	request.timeout = 15.0
	request.body_size_limit = 8192
	request.max_redirects = 0
	add_child(request)
	request.request_completed.connect(_completed)

func open_room(create: bool, code: String, fingerprint: String) -> void:
	if busy: return
	origin = server_url.strip_edges().trim_suffix("/")
	if not _valid_origin(origin):
		status_changed.emit("Enter the HTTPS address of your room server.")
		return
	code = code.strip_edges().to_upper()
	if not create and not valid_code(code):
		status_changed.emit("Enter the room code from your friend.")
		return
	busy = true
	status_changed.emit("Opening your private room…" if create else "Finding your room…")
	var path: String = "/rooms" if create else "/rooms/" + code
	var body: String = JSON.stringify({"protocol": MatchLink.PROTOCOL, "fingerprint": fingerprint}) if create else ""
	var error: Error = request.request(origin + path, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST if create else HTTPClient.METHOD_GET, body)
	if error != OK:
		busy = false
		status_changed.emit("Could not contact the room server. Check its address.")

static func valid_code(code: String) -> bool:
	if code.length() != 6: return false
	for character in code:
		if not CODE_ALPHABET.contains(character): return false
	return true

static func _valid_origin(value: String) -> bool:
	if value.length() > 253 or value.contains("?") or value.contains("#") or value.contains("@") or value.contains(" "): return false
	if value.begins_with("https://"):
		return value.trim_prefix("https://").length() > 3 and not value.trim_prefix("https://").contains("/")
	# Explicit loopback support is for the reproducible server test harness.
	return value.begins_with("http://127.0.0.1:") and value.trim_prefix("http://127.0.0.1:").is_valid_int()

func cancel() -> void:
	if request: request.cancel_request()
	busy = false

func _completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not busy: return
	busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		status_changed.emit("Room server unavailable. Check your connection and server address.")
		return
	if status != 200 and status != 201:
		var message: String = "Could not open this room. Try again."
		match status:
			404, 410: message = "This room has expired. Ask your friend to create another."
			409: message = "Different game versions. Update the game and room server."
			429, 503: message = "The room server is full. Try again in a moment."
		status_changed.emit(message)
		return
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		status_changed.emit("The room server returned an invalid room.")
		return
	var data: Variant = parser.data
	if not data is Dictionary or not data.get("code") is String or not valid_code(data.code):
		status_changed.emit("The room server returned an invalid room.")
		return
	var scheme: String = "wss://" if origin.begins_with("https://") else "ws://"
	var host: String = origin.trim_prefix("https://").trim_prefix("http://")
	room_ready.emit(data.code, scheme + host + "/rooms/" + data.code + "/play")
