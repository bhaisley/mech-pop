extends SceneTree

class MenuTestApp extends "res://scripts/app.gd":
	var available_controllers: Array[int] = [7, 8]
	func connected_controllers() -> Array[int]:
		return available_controllers.duplicate()
	func _save_settings() -> void:
		pass

var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL ", message)

func _initialize() -> void:
	_run.call_deferred()

func press(device: int, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func focus_text() -> String:
	var focus: Control = root.gui_get_focus_owner()
	return focus.text if focus is Button else ""

func move_axis(device: int, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event.axis_value = 0.0
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	var app := MenuTestApp.new()
	root.add_child(app)
	await process_frame
	await process_frame
	await press(7, JOY_BUTTON_A)
	check(app.screen == &"select", "controller opens character selection")
	await press(7, JOY_BUTTON_START)
	check(app.router.devices == [7, -2, -2, -2], "first Start claims the default solo P1 seat; three bots remain")
	check(not app.ready_slots[0] and app.screen == &"select", "joining does not also ready or launch")
	for slot in range(4):
		check(int(app.setup_state(7).field) == slot, "overview focuses character field %d" % slot)
		var before: Array[StringName] = app.selections.duplicate()
		await press(7, JOY_BUTTON_A)
		check(app.setup_state(7).editing, "A enters character field %d" % slot)
		await move_axis(7, JOY_AXIS_LEFT_X, 1.0)
		check(app.selections[slot] != before[slot], "single controller changes character %d with thumbstick" % slot)
		var others_unchanged: bool = true
		for other in range(4):
			if other != slot: others_unchanged = others_unchanged and app.selections[other] == before[other]
		check(others_unchanged, "editing field %d preserves the other three choices" % slot)
		await press(7, JOY_BUTTON_B)
		check(not app.setup_state(7).editing and app.router.devices[0] == 7, "B exits field without unjoining")
		if slot < 3:
			before = app.selections.duplicate()
			await press(7, JOY_BUTTON_DPAD_RIGHT)
			check(app.selections == before, "overview navigation does not change characters")
	await press(7, JOY_BUTTON_DPAD_DOWN)
	check(int(app.setup_state(7).field) == 11, "Down reaches P4 input from its character card")
	await press(7, JOY_BUTTON_DPAD_DOWN)
	check(int(app.setup_state(7).field) == 7, "Down reaches bottom row from P4")
	await press(7, JOY_BUTTON_DPAD_LEFT)
	check(int(app.setup_state(7).field) == 4, "controller reaches Arena from overview")
	await press(7, JOY_BUTTON_A)
	check(app.screen == &"arena", "A enters Arena")
	await move_axis(7, JOY_AXIS_LEFT_X, 1.0)
	await press(7, JOY_BUTTON_A)
	check(app.screen == &"select" and app.selected_stage == &"neon_alley", "existing arena thumbstick navigation chooses another map")
	check(int(app.setup_state(7).field) == 4, "Arena returns focus to its setup field")
	await press(7, JOY_BUTTON_DPAD_LEFT)
	check(int(app.setup_state(7).field) == 5, "controller reaches Bots")
	var old_difficulty: int = app.difficulty
	await press(7, JOY_BUTTON_A)
	check(app.setup_state(7).editing and app.difficulty == old_difficulty, "A enters difficulty without immediately changing it")
	await move_axis(7, JOY_AXIS_LEFT_X, -1.0)
	check(app.difficulty == posmod(old_difficulty - 1, 3), "thumbstick changes difficulty inside its field")
	await press(7, JOY_BUTTON_A)
	check(not app.setup_state(7).editing and int(app.setup_state(7).field) == 5, "A finishes difficulty editing")
	await press(7, JOY_BUTTON_START)
	check(app.ready_slots[0] and app.screen == &"select", "second Start readies the joined player")
	await press(7, JOY_BUTTON_START)
	check(app.screen == &"match" and not app.session.paused, "third Start launches without also pausing")
	app.session.simulation_enabled = false
	app._select()
	await process_frame
	await press(8, JOY_BUTTON_START)
	check(app.router.devices[0] == 7 and app.router.devices[1] == 8, "another controller joins a free slot without stealing P1")
	await press(7, JOY_BUTTON_DPAD_RIGHT)
	await press(7, JOY_BUTTON_A)
	check(not app.setup_state(7).editing and not app.setup_notice.is_empty(), "P1 cannot enter another human's character field")
	var player_two: StringName = app.selections[1]
	await press(7, JOY_BUTTON_DPAD_RIGHT)
	check(app.selections[1] == player_two, "P1 navigation cannot change P2")
	await press(8, JOY_BUTTON_A)
	await press(8, JOY_BUTTON_DPAD_RIGHT)
	check(app.selections[1] != player_two and int(app.setup_state(8).field) == 1, "P2 retains an independent cursor and edits their own character")
	await press(8, JOY_BUTTON_B)
	await press(7, JOY_BUTTON_START)
	await press(7, JOY_BUTTON_START)
	check(app.screen == &"select", "ready P1 cannot launch while P2 is unready")
	await press(8, JOY_BUTTON_START)
	await press(7, JOY_BUTTON_START)
	check(app.screen == &"match" and not app.session.paused, "Start launches once both controllers are ready")
	app.session.simulation_enabled = false
	app._select()
	await process_frame
	await press(7, JOY_BUTTON_DPAD_DOWN)
	await press(7, JOY_BUTTON_DPAD_DOWN)
	check(int(app.setup_state(7).field) == 6, "controller reaches Back from P1")
	await press(7, JOY_BUTTON_A)
	check(app.screen == &"title", "controller activates Back")
	check(app.network.host(24974, [7, 8], "PADCHK") == OK, "local room created for existing controller menu coverage")
	app._network_menu()
	await process_frame
	await press(7, JOY_BUTTON_DPAD_DOWN)
	check(focus_text().begins_with("ARENA:"), "room leader can focus arena options")
	await press(7, JOY_BUTTON_A)
	check(app.screen == &"arena", "room leader opens arena selection with controller")
	await press(7, JOY_BUTTON_DPAD_RIGHT)
	await press(7, JOY_BUTTON_A)
	check(app.screen == &"network" and app.network.selected_stage != &"skyport", "controller changes authoritative room arena")
	await press(7, JOY_BUTTON_START)
	check(app.screen == &"network" and app.network.seats[0].ready and app.network.seats[1].ready, "network Start readies the local party before launching")
	await press(7, JOY_BUTTON_START)
	check(app.screen == &"match" and not app.session.paused, "network leader's next Start launches without pausing")
	app._title()
	await _test_input_assignments(app)
	app.sound.stop_all()
	await create_timer(0.12).timeout
	print("CONTROLLER MENU TESTS: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	app = null
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_input_assignments(app: MenuTestApp) -> void:
	app.router.devices = [PlayerInputRouter.KEYBOARD, 7, PlayerInputRouter.BOT, PlayerInputRouter.BOT]
	app._select()
	await process_frame
	check(app.setup_input_options() == [PlayerInputRouter.BOT, PlayerInputRouter.KEYBOARD, 7, 8], "Mac input choices contain keyboard and each connected controller")
	await press(7, JOY_BUTTON_DPAD_LEFT)
	await press(7, JOY_BUTTON_DPAD_DOWN)
	check(int(app.setup_state(7).field) == 8, "P2's controller can reach P1's input selector")
	await press(7, JOY_BUTTON_A)
	await move_axis(7, JOY_AXIS_LEFT_Y, -1.0)
	check(app.setup_state(7).input_choice == PlayerInputRouter.BOT and app.router.devices[0] == PlayerInputRouter.KEYBOARD, "browsing Bot does not change the current input")
	await press(7, JOY_BUTTON_B)
	check(not app.setup_state(7).editing and app.router.devices[0] == PlayerInputRouter.KEYBOARD, "B cancels input assignment")
	await press(7, JOY_BUTTON_A)
	await press(7, JOY_BUTTON_DPAD_UP)
	await press(7, JOY_BUTTON_A)
	check(app.router.devices == [PlayerInputRouter.BOT, 7, PlayerInputRouter.BOT, PlayerInputRouter.BOT], "P2 can turn the idle keyboard player into a bot")
	await press(7, JOY_BUTTON_DPAD_RIGHT)
	await press(7, JOY_BUTTON_DPAD_RIGHT)
	await press(7, JOY_BUTTON_A)
	await press(7, JOY_BUTTON_DPAD_DOWN)
	await press(7, JOY_BUTTON_DPAD_DOWN)
	check(app.router.devices[1] == 7 and app.router.devices[2] == PlayerInputRouter.BOT, "browsing an assigned controller preserves its previous player")
	app.router.axes[7] = Vector2.RIGHT
	app.router.edges[1][&"light"] = true
	await press(7, JOY_BUTTON_A)
	check(app.router.devices == [PlayerInputRouter.BOT, PlayerInputRouter.BOT, 7, PlayerInputRouter.BOT], "assigning Controller 1 to P3 releases P2 to a bot")
	check(app.device_label(2) == "CONTROLLER 1", "controller numbering is independent of player numbering")
	check(not app.ready_slots[2] and app.ready_slots[1], "moving a controller requires its new player to ready")
	check(app.router.command_for(2).move == Vector2.ZERO and not app.router.command_for(1).light, "input reassignment clears held movement and stale action edges")
	app.setup_assign_input(0, PlayerInputRouter.KEYBOARD)
	app.setup_assign_input(3, PlayerInputRouter.KEYBOARD)
	check(app.router.devices[0] == PlayerInputRouter.BOT and app.router.devices[3] == PlayerInputRouter.KEYBOARD, "keyboard can move to any slot and cannot own two fighters")
	app.router.touch_enabled = true
	check(app.setup_input_options() == [PlayerInputRouter.BOT, PlayerInputRouter.KEYBOARD, PlayerInputRouter.TOUCH, 7, 8], "tablet offers Touch separately from Keyboard")
	app.setup_assign_input(0, PlayerInputRouter.TOUCH)
	app.setup_assign_input(1, PlayerInputRouter.TOUCH)
	check(app.router.devices == [PlayerInputRouter.BOT, PlayerInputRouter.TOUCH, 7, PlayerInputRouter.KEYBOARD], "touch moves independently while keyboard and controller keep their assignments")
	app.front._setup_mouse_field(8)
	await process_frame
	check(app.setup_state(-1).editing and int(app.setup_state(-1).field) == 8, "click or touch opens the same player input picker")
	app.setup_state(-1).input_choice = 8
	app.available_controllers = [7]
	app._device_connection(8, false)
	await process_frame
	check(app.setup_state(-1).input_choice == PlayerInputRouter.BOT and not app.setup_input_options().has(8), "disconnect refreshes an open picker and removes the unavailable controller")
	check(not app.setup_assign_input(0, 8) and app.router.devices[2] == 7, "an unavailable controller cannot be assigned or displace a connected player")
	app._title()
