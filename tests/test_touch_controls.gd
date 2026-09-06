extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func _run() -> void:
	var app: Node = load("res://ui/app.tscn").instantiate()
	root.add_child(app)
	check(app.router.devices[0] == app.router.primary_device() and app.network_devices == [app.router.primary_device()], "local and network parties start with the platform's default input")
	app.router.touch_enabled = true
	app.router.assign_device(0, PlayerInputRouter.TOUCH)
	app.router.assign_device(1, 6)
	app.router.assign_device(2, PlayerInputRouter.KEYBOARD)
	app._start_match()
	app.session.simulation_enabled = false
	await process_frame
	var controls: TouchControls = app.touch_controls
	var router: PlayerInputRouter = app.router
	controls._process(0)
	var unit: float = controls.size.x / 1920.0
	check(controls.active, "touch overlay active during a match")
	check(controls.feed_touch(0, (controls.stick_center() + Vector2(116, 0)) * unit, true), "movement finger accepted")
	controls.feed_touch(1, controls.action_center(&"jump") * unit, true)
	controls.feed_touch(2, controls.action_center(&"heavy") * unit, true)
	var command: FighterCommand = router.command_for(0)
	check(command.move.x > 0.99 and command.jump_pressed and command.jump_held and command.heavy, "movement, jump and breaker work simultaneously")
	var other: FighterCommand = router.command_for(1)
	check(other.move.is_zero_approx() and not other.jump_pressed and not other.heavy, "touch cannot control another player's pad")
	var pad := InputEventJoypadButton.new()
	pad.device = 6
	pad.button_index = JOY_BUTTON_X
	pad.pressed = true
	router.feed_event(pad)
	check(router.command_for(1).light and not router.command_for(0).light, "pad actions stay independent of touch")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	router.feed_event(key)
	key.physical_keycode = KEY_A
	router.feed_event(key)
	var keyboard: FighterCommand = router.command_for(2)
	command = router.command_for(0)
	check(keyboard.jump_pressed and keyboard.jump_held and keyboard.move.x < -0.99, "keyboard controls its own player alongside touch and a pad")
	check(not command.jump_pressed and command.jump_held and command.move.x > 0.99, "keyboard presses and movement do not leak into the touch player")
	controls.feed_touch(2, controls.action_center(&"heavy") * unit, true, true)
	check(not router.command_for(0).heavy, "holding or dragging a button does not repeat its press edge")
	controls.feed_touch(1, Vector2.ZERO, false)
	command = router.command_for(0)
	check(not command.jump_held and command.move.x > 0.99, "releasing jump keeps movement held")
	controls.feed_touch(3, controls.action_center(&"jump") * unit, true)
	controls.feed_touch(4, controls.action_center(&"jump") * unit, true)
	controls.feed_touch(3, Vector2.ZERO, false)
	check(router.command_for(0).jump_held, "two fingers on one action retain the remaining hold")
	controls.feed_touch(4, Vector2.ZERO, false)
	check(not router.command_for(0).jump_held, "last finger releases the action")
	controls.feed_touch(0, (controls.stick_center() + Vector2(-500, -500)) * unit, true, true)
	command = router.command_for(0)
	check(command.move.x < -0.6 and command.move.y < -0.6 and command.move.length() <= 1.001, "directional aim follows the stick and clamps outside its circle")
	router._on_focus_lost()
	controls._process(0)
	check(app.screen == &"pause" and controls.fingers.is_empty(), "focus loss pauses and releases all touch pointers")
	check(router.touch_move.is_zero_approx() and router.touch_held.values().all(func(value: Variant) -> bool: return not value), "focus loss cannot leave held movement or jump")
	app._resume()
	controls._process(0)
	controls.feed_touch(8, Vector2(1826, 147) * unit, true)
	check(app.screen == &"pause", "touch pause is available without a keyboard")
	app._resume()
	router.assign_device(0, PlayerInputRouter.BOT)
	controls._process(0)
	check(not controls.feed_touch(10, controls.action_center(&"light") * unit, true), "touch actions are hidden and inactive when no player uses touch")
	controls.feed_touch(11, Vector2(1826, 147) * unit, true)
	check(app.screen == &"pause", "touch pause remains available when every player uses a controller, keyboard or bot")
	app._title()
	await process_frame
	check(app.touch_controls == null, "leaving the match disposes touch controls")
	app.front.size = Vector2(1536, 1152)
	app.front._layout()
	check(is_equal_approx(app.front.canvas.scale.x, app.front.canvas.scale.y), "tablet menus preserve portrait proportions")
	app.sound.stop_all()
	await create_timer(0.12).timeout
	print("TOUCH TESTS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
