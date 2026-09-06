extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var app: Node = load("res://ui/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	var accept := InputEventJoypadButton.new()
	accept.device = 7
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	Input.parse_input_event(accept)
	await process_frame
	accept.pressed = false
	Input.parse_input_event(accept)
	await process_frame
	check(app.screen == &"select", "controller south button activates the focused Play menu button")
	app._select()
	await process_frame
	check(app.front.portraits.size() == 4, "four character cards")
	for portrait in app.front.portraits:
		check(portrait.size.x <= 420 and portrait.size.y <= 350, "portrait contained by card")
	app.router.assign_device(1, 7)
	app.router.assign_device(2, 8)
	app.ready_slots[1] = false
	app.ready_slots[2] = false
	app._select(false)
	var before: Array[StringName] = app.selections.duplicate()
	var right := InputEventJoypadButton.new()
	right.device = 7
	right.button_index = JOY_BUTTON_DPAD_RIGHT
	right.pressed = true
	var confirm := InputEventJoypadButton.new()
	confirm.device = 7
	confirm.button_index = JOY_BUTTON_A
	confirm.pressed = true
	app.front._input(confirm)
	app.front._input(right)
	check(app.selections[1] != before[1] and app.selections[0] == before[0] and app.selections[2] == before[2], "controller selects only its own slot")
	app._launch_requested()
	check(app.screen == &"select", "unready human prevents accidental launch")
	app.ready_slots[1] = true
	app.ready_slots[2] = true
	var start := InputEventJoypadButton.new()
	start.device = 7
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	Input.parse_input_event(start)
	await process_frame
	check(app.screen == &"match" and app.session != null, "ready lobby launches")
	check(not app.session.paused, "controller Start launches without also pausing the new match")
	start.pressed = false
	Input.parse_input_event(start)
	app.session.simulation_enabled = false
	app.router.held_keys[KEY_D] = true
	app.router._on_focus_lost()
	check(app.session.paused and app.screen == &"pause", "focus loss pauses")
	check(app.router.held_keys.is_empty(), "focus loss clears held movement")
	app._resume()
	check(not app.session.paused and app.screen == &"match", "resume returns to active match")
	app._device_lost(1)
	check(app.session.paused and app.disconnected_slot == 1, "disconnect identifies and pauses the correct slot")
	app._resume()
	check(app.session.paused, "resume cannot silently replace disconnected human")
	app._bot_takeover()
	check(not app.session.paused and app.router.devices[1] == PlayerInputRouter.BOT, "explicit takeover resumes with a bot")
	app._pause()
	var saved: Dictionary = app.router.keyboard_bindings.duplicate()
	app._begin_remap(false)
	var remap := InputEventKey.new()
	remap.physical_keycode = KEY_Q
	remap.pressed = true
	app._remap_input(remap)
	check(app.remap_pending.size() == 1, "remapping buffers edits")
	app._cancel_remap()
	check(app.router.keyboard_bindings == saved, "canceling remap preserves saved controls")
	app._title()
	await process_frame
	check(app.session == null and app.view == null and app.hud == null, "return to title disposes the previous match")
	app.sound.stop_all()
	await create_timer(0.12).timeout
	print("FRONT END TESTS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
