extends SceneTree

var checks: int = 0
var failures: Array[String] = []
var message: String = ""
var opened: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures.append(description)

func _run() -> void:
	var rooms := InternetRooms.new()
	root.add_child(rooms)
	rooms.status_changed.connect(func(value: String) -> void: message = value)
	rooms.room_ready.connect(func(_code: String, _url: String) -> void: opened += 1)
	rooms.busy = true
	rooms._completed(HTTPRequest.RESULT_SUCCESS, 503, [], "503: Service Unavailable".to_utf8_buffer())
	check(message.contains("full") and not rooms.busy and opened == 0, "Plain-text HTTP errors return a usable message without parsing JSON")
	rooms.busy = true
	rooms._completed(HTTPRequest.RESULT_SUCCESS, 409, [], "409: Conflict".to_utf8_buffer())
	check(message.contains("versions") and opened == 0, "Version mismatch stays in the room screen")
	rooms.busy = true
	rooms._completed(HTTPRequest.RESULT_SUCCESS, 200, [], "invalid json".to_utf8_buffer())
	check(message.contains("invalid room") and opened == 0, "Malformed success responses are rejected")
	rooms.busy = true
	rooms._completed(HTTPRequest.RESULT_SUCCESS, 200, [], '{"code":"../../"}'.to_utf8_buffer())
	check(message.contains("invalid room") and opened == 0, "Unusable room codes cannot form a socket path")
	rooms.busy = true
	rooms.origin = "https://rooms.example.com"
	rooms._completed(HTTPRequest.RESULT_SUCCESS, 201, [], '{"code":"ABC234"}'.to_utf8_buffer())
	check(opened == 1, "A valid response can open a room")
	print("INTERNET_ROOM_ERRORS ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
