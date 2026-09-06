extends Node

var router: PlayerInputRouter
var session: MatchSession
var view: BattleView
var hud: BattleHUD
var touch_controls: TouchControls
var ui_layer: CanvasLayer
var overlay: Control
var selections: Array[StringName] = [&"nova", &"kuren", &"terra", &"momo"]
var difficulty: int = 1
var selected_stage: StringName = &"skyport"
var screen: StringName = &"title"
var debug_enabled: bool = false
var perf_seconds: float = 0.0
var perf_elapsed: float = 0.0
var frame_samples: Array[float] = []
var capture_path: String = ""
var capture_taken: bool = false
var previous_frame_usec: int = 0
var sound: SoundDirector
var ready_slots: Array[bool] = [true, true, true, true]
var selection_repeat: Dictionary = {}
var selection_options_device: int = -1
var selection_options_index: int = 0
var setup_device: int = -1
var setup_states: Dictionary = {}
var setup_notice: String = ""
var shake_setting: int = 1
var page_return: StringName = &"title"
var disconnected_slot: int = -1
var disconnected_guid: String = ""
var device_guids: Dictionary = {}
var remap_actions: Array[StringName] = []
var remap_pending: Dictionary = {}
var remap_pad: bool = false
var remap_device: int = -1
var remap_prompt: Label
var remap_status: String = ""
var closing: bool = false
var front: FrontEnd
var soak: bool = false
var rotate_content: bool = false
var soak_rounds: Array[Dictionary] = []
var capture_directory: String = ""
var captured_events: Dictionary = {}
var capture_busy: bool = false
var benchmark_errors: Array[String] = []
var telemetry_clock: float = 0.0
var mix_recording: AudioEffectRecord
var mix_recording_path: String = ""
var mix_saved: bool = false
var network: MatchLink
var network_address: String = ""
var network_code: String = ""
var network_port: int = MatchLink.DEFAULT_PORT
var network_devices: Array[int] = [PlayerInputRouter.KEYBOARD]
var network_test_seconds: float = 0.0
var network_elapsed: float = 0.0
var network_wait_elapsed: float = 0.0
var network_rounds: Array[Dictionary] = []
var presentation_enabled: bool = true
var frame_window_path: String = ""
var frame_windows: Array[Dictionary] = []
var frame_window_seconds: float = 0.0
var frame_window_count: int = 0
var frame_window_max: float = 0.0
var frame_window_phase: String = ""
var internet_rooms: InternetRooms
var internet_mode: bool = false

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	router = PlayerInputRouter.new()
	add_child(router)
	network_devices = [router.primary_device()]
	if OS.get_cmdline_user_args().has("--touch-preview"):
		Input.emulate_touch_from_mouse = true
	router.pause_requested.connect(_pause)
	router.device_lost.connect(_device_lost)
	Input.joy_connection_changed.connect(_device_connection)
	router.join_requested.connect(_join_device)
	network = MatchLink.new()
	network.name = "MatchLink"
	network.router = router
	add_child(network)
	network.lobby_changed.connect(_network_changed)
	network.status_changed.connect(_network_changed)
	network.start_match_requested.connect(_network_start_match)
	network.round_verified.connect(func(report: Dictionary) -> void: network_rounds.append(report))
	internet_rooms = InternetRooms.new()
	add_child(internet_rooms)
	internet_rooms.status_changed.connect(func(message: String) -> void: network._set_status(message))
	internet_rooms.room_ready.connect(_internet_room_ready)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("--network-info"):
		print("NETWORK_INFO ", JSON.stringify({"protocol": MatchLink.PROTOCOL, "fingerprint": network.content_fingerprint(), "version": ProjectSettings.get_setting("application/config/version")}))
		get_tree().quit()
		return
	presentation_enabled = not arguments.has("--server") and not arguments.has("--net-no-view")
	if presentation_enabled:
		sound = SoundDirector.new()
		add_child(sound)
		_load_settings()
		ui_layer = CanvasLayer.new()
		add_child(ui_layer)
	var network_host: bool = false
	var network_join: bool = false
	var internet_action: int = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark="):
			perf_seconds = float(arg.get_slice("=", 1))
		elif arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--frame-windows="):
			frame_window_path = arg.trim_prefix("--frame-windows=")
		elif arg.begins_with("--stage="):
			var id: StringName = StringName(arg.trim_prefix("--stage="))
			if StageCatalog.IDS.has(id):
				selected_stage = id
				network.selected_stage = id
		elif arg.begins_with("--roster="):
			var ids: PackedStringArray = arg.trim_prefix("--roster=").split(",")
			var valid: bool = ids.size() == 4
			for id in ids: valid = valid and Roster.IDS.has(StringName(id))
			if valid:
				selections.clear()
				for id in ids: selections.append(StringName(id))
				network.starting_characters = selections.duplicate()
		elif arg.begins_with("--soak="):
			soak = true
			perf_seconds = float(arg.get_slice("=", 1))
		elif arg == "--rotate-content": rotate_content = true
		elif arg.begins_with("--capture-events="):
			capture_directory = arg.trim_prefix("--capture-events=")
			DirAccess.make_dir_recursive_absolute(capture_directory)
		elif arg.begins_with("--record-audio="):
			mix_recording_path = arg.trim_prefix("--record-audio=")
		elif arg.begins_with("--net-host="):
			network_host = true
			network_port = int(arg.get_slice("=", 1))
		elif arg.begins_with("--net-join="):
			network_join = true
			network_address = arg.trim_prefix("--net-join=")
		elif arg.begins_with("--net-port="):
			network_port = int(arg.get_slice("=", 1))
		elif arg.begins_with("--net-code="):
			network_code = arg.trim_prefix("--net-code=")
		elif arg.begins_with("--internet-server="):
			internet_rooms.server_url = arg.trim_prefix("--internet-server=")
			internet_mode = true
		elif arg == "--internet-create": internet_action = 1
		elif arg.begins_with("--internet-join="):
			internet_action = 2
			network_code = arg.trim_prefix("--internet-join=")
		elif arg.begins_with("--net-auto-start="):
			network.auto_start_peers = int(arg.get_slice("=", 1))
		elif arg.begins_with("--net-test-duration="):
			network.test_duration = clampf(float(arg.get_slice("=", 1)), 1.0, 1800.0)
		elif arg.begins_with("--net-test-seconds="):
			network_test_seconds = maxf(1.0, float(arg.get_slice("=", 1)))
		elif arg.begins_with("--net-test-party=") and arguments.has("--net-bots"):
			network_devices.clear()
			for index in range(clampi(int(arg.get_slice("=", 1)), 1, 4)):
				network_devices.append(router.primary_device() if index == 0 else index - 1)
		elif arg == "--net-bots": network.bot_local_inputs = true
		elif arg == "--net-rematch": network.auto_rematch = true
		elif arg.begins_with("--net-lag="): network.test_latency_ms = clampf(float(arg.get_slice("=", 1)), 0.0, 1000.0)
		elif arg.begins_with("--net-jitter="): network.test_jitter_ms = clampf(float(arg.get_slice("=", 1)), 0.0, 500.0)
		elif arg.begins_with("--net-loss="): network.test_loss = clampf(float(arg.get_slice("=", 1)), 0.0, 0.5)
		elif arg.begins_with("--net-duplicates="): network.test_duplicates = clampf(float(arg.get_slice("=", 1)), 0.0, 0.5)
	if not mix_recording_path.is_empty():
		mix_recording = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, mix_recording)
		mix_recording.set_recording_active(true)
	if internet_action > 0:
		internet_mode = true
		if presentation_enabled: _show(&"network")
		internet_rooms.open_room(internet_action == 1, network_code, network.content_fingerprint())
	elif network_host or network_join:
		if arguments.has("--server"): network_devices.clear()
		if presentation_enabled: _show(&"network")
		if network_host: network.host(network_port, network_devices, network_code, arguments.has("--net-websocket"))
		else: network.join(network_address, network_port, network_devices, network_code)
	elif OS.get_cmdline_user_args().has("--autoplay") or perf_seconds > 0.0:
		router.devices = [-2, -2, -2, -2]
		_start_match()
	else:
		_title()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()

func _process(delta: float) -> void:
	if closing: return
	var now_usec: int = Time.get_ticks_usec()
	var measured_ms: float = float(now_usec - previous_frame_usec) / 1000.0 if previous_frame_usec > 0 else 0.0
	previous_frame_usec = now_usec
	if not frame_window_path.is_empty() and maxf(perf_elapsed, network_elapsed) > 5.0 and session:
		_record_frame_window(measured_ms)
	if not capture_path.is_empty() and not capture_taken and maxf(perf_elapsed, network_elapsed) > 12.0 and presentation_enabled:
		capture_taken = true
		_capture.call_deferred()
	if network_test_seconds > 0.0:
		network_wait_elapsed += delta
		if session:
			network_elapsed += delta
			if network_elapsed > 5.0: frame_samples.append(measured_ms)
		if network_elapsed >= network_test_seconds or (session == null and network_wait_elapsed > 45.0):
			frame_samples.sort()
			var sample_count: int = frame_samples.size()
			var report: Dictionary = {"seconds": network_elapsed, "platform": OS.get_name(), "samples": sample_count, "metrics": network.metrics, "rounds": network_rounds, "status": network.status, "active": network.active, "test_bot_inputs": network.bot_local_inputs}
			report["own_slots"] = network.own_slots()
			report["local_devices"] = network.local_devices.duplicate()
			report["network_peers"] = multiplayer.get_peers()
			if sample_count > 0:
				report.merge({"median_ms": frame_samples[int(sample_count * 0.5)], "p99_ms": frame_samples[mini(sample_count - 1, int(sample_count * 0.99))], "p999_ms": frame_samples[mini(sample_count - 1, int(sample_count * 0.999))], "maximum_ms": frame_samples[-1]})
			print("NETWORK_TEST_END ", JSON.stringify(report))
			_quit_game()
	if perf_seconds > 0.0:
		perf_elapsed += delta
		if mix_recording and not mix_saved and perf_elapsed > 40.0:
			mix_saved = true
			mix_recording.set_recording_active(false)
			var recording: AudioStreamWAV = mix_recording.get_recording()
			recording.save_to_wav(mix_recording_path)
			print("MIX_CAPTURE ", mix_recording_path)
		telemetry_clock += delta
		if telemetry_clock > 60.0 and session:
			telemetry_clock = 0.0
			var errors: Array[String] = session.parts.conservation_errors()
			benchmark_errors.append_array(errors)
			print("SOAK_HEARTBEAT ", JSON.stringify({"seconds": snappedf(perf_elapsed, 0.1), "round": soak_rounds.size() + 1, "memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "parts": session.parts.instances.size(), "effects": view.effects.size(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "errors": errors}))
		if perf_elapsed > 5.0:
			frame_samples.append(measured_ms)
		if perf_elapsed >= perf_seconds:
			frame_samples.sort()
			var count: int = frame_samples.size()
			print("BENCHMARK ", JSON.stringify({"seconds": perf_elapsed, "samples": count, "median_ms": frame_samples[int(count * 0.5)], "p99_ms": frame_samples[mini(count - 1, int(count * 0.99))], "p999_ms": frame_samples[mini(count - 1, int(count * 0.999))], "maximum_ms": frame_samples[-1], "events": session.event_counts, "parts": session.parts.instances.size(), "conservation_errors": benchmark_errors + session.parts.conservation_errors(), "rounds": soak_rounds, "renderer": RenderingServer.get_current_rendering_method(), "devices": Input.get_connected_joypads(), "window_pixels": get_viewport().get_texture().get_size()}))
			_quit_game()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var result: Error = image.save_png(capture_path)
	print("CAPTURE ", capture_path, " result=", result)

func _input(event: InputEvent) -> void:
	if not remap_actions.is_empty():
		_remap_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1 and hud:
			debug_enabled = not debug_enabled
			hud.debug_visible = debug_enabled
		elif debug_enabled and session:
			_debug_key(event.physical_keycode)

func _debug_key(code: int) -> void:
	if network.active: return
	var fighter: Fighter = session.fighters[0]
	match code:
		KEY_F2: session.parts.break_part(fighter, &"weapon_arm", Vector2(220, -550))
		KEY_F3: session.parts.break_part(fighter, &"shell", Vector2(-180, -550))
		KEY_F4:
			var donor: Fighter = session.fighters[2]
			var item: PartInstance = session.parts.break_part(donor, &"weapon_arm", Vector2(0, -200))
			if item:
				item.entity.position = fighter.position + Vector2(30, -50)
				item.entity.age = 0.3
		KEY_F5: session.knock_out(fighter, 1)
		KEY_F6: router.devices[0] = PlayerInputRouter.BOT if router.devices[0] != PlayerInputRouter.BOT else router.primary_device()
		KEY_F7: session.time_scale = 0.25 if session.time_scale == 1.0 else 1.0
		KEY_F8:
			session.paused = false
			session.step(1.0 / 120.0)
			session.paused = true
		KEY_F9: fighter.invincible_debug = not fighter.invincible_debug
		KEY_F10:
			difficulty = (difficulty + 1) % 3
			for actor in session.fighters: actor.brain.difficulty = difficulty
		KEY_F11: session.paused = not session.paused

func _show(page: StringName, message: String = "") -> void:
	if overlay:
		overlay.queue_free()
	screen = page
	front = FrontEnd.new()
	overlay = front
	ui_layer.add_child(front)
	front.setup(self, page, message)

func _clear_match() -> void:
	if network: network.detach_match()
	if sound: sound.session = null
	if touch_controls:
		touch_controls.release_all()
		touch_controls.queue_free()
		touch_controls = null
	if hud:
		hud.queue_free()
		hud = null
	if view:
		view.queue_free()
		view = null
	if session:
		session.queue_free()
		session = null
	disconnected_slot = -1

func _title() -> void:
	selection_options_device = -1
	setup_device = -1
	setup_states.clear()
	setup_notice = ""
	if internet_rooms: internet_rooms.cancel()
	if network and network.active:
		network.close()
		router.devices = [router.primary_device(), PlayerInputRouter.BOT, PlayerInputRouter.BOT, PlayerInputRouter.BOT]
	_clear_match()
	sound.menu_music()
	_show(&"title")

func _network_menu() -> void:
	_clear_match()
	sound.menu_music()
	_show(&"network")

func _network_changed(_message: String = "") -> void:
	if not presentation_enabled or ui_layer == null or closing: return
	if screen == &"network":
		_show(&"network")
	elif not network.active and screen in [&"match", &"pause", &"results"]:
		_clear_match()
		sound.menu_music()
		_show(&"network")

func _network_start_match(config: Dictionary, _remote: bool) -> void:
	for slot in range(4): selections[slot] = StringName(config.characters[slot])
	selected_stage = StringName(config.stage)
	_create_match(config)

func _network_host() -> void:
	if network_code.is_empty(): network_code = Crypto.new().generate_random_bytes(3).hex_encode().to_upper()
	network.host(network_port, network_devices, network_code)

func _network_join() -> void:
	network.join(network_address, network_port, network_devices, network_code)

func _internet_open(create: bool) -> void:
	_save_settings()
	internet_rooms.open_room(create, network_code, network.content_fingerprint())

func _internet_room_ready(code: String, socket_url: String) -> void:
	network_code = code
	network_address = socket_url
	print("INTERNET_ROOM_READY ", JSON.stringify({"code": code, "url": socket_url}))
	network.join(socket_url, MatchLink.DEFAULT_PORT, network_devices, code)

func _network_mode(internet: bool) -> void:
	internet_mode = internet
	network.status = ""
	_show(&"network")

func _network_ready() -> void:
	var ready: bool = true
	for slot in network.own_slots(): ready = ready and bool(network.seats[slot].ready)
	network.set_ready(not ready)

func _network_local_inputs() -> void:
	network_devices = [router.primary_device()]
	for device in Input.get_connected_joypads():
		if network_devices.size() < 4: network_devices.append(device)
	_show(&"network")

func network_local_addresses() -> String:
	var addresses: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."): addresses.append(ip)
	return ", ".join(addresses) if not addresses.is_empty() else "Connect to Wi-Fi to find your address"

func _select(reset_match: bool = true) -> void:
	if network.active:
		_network_menu()
		return
	if reset_match:
		selection_options_device = -1
		setup_device = -1
		setup_states.clear()
		setup_notice = ""
		_clear_match()
		for slot in range(4):
			ready_slots[slot] = router.devices[slot] < 0
		if not sound.music.playing:
			sound.menu_music()
	_show(&"select")

func device_label(slot: int) -> String:
	return input_label(router.devices[slot])

func connected_controllers() -> Array[int]:
	var controllers: Array[int] = Input.get_connected_joypads()
	controllers.sort()
	return controllers

func input_label(device: int) -> String:
	if device == PlayerInputRouter.KEYBOARD: return "KEYBOARD"
	if device == PlayerInputRouter.TOUCH: return "TOUCH"
	if device == PlayerInputRouter.BOT: return "BOT"
	if device == PlayerInputRouter.REMOTE: return "NETWORK"
	var index: int = connected_controllers().find(device)
	return "CONTROLLER %d" % (index + 1) if index >= 0 else "DISCONNECTED PAD"

func setup_input_options() -> Array[int]:
	var options: Array[int] = [PlayerInputRouter.BOT, PlayerInputRouter.KEYBOARD]
	if router.touch_enabled: options.append(PlayerInputRouter.TOUCH)
	options.append_array(connected_controllers())
	return options

func pad_button_label(button: int) -> String:
	return {JOY_BUTTON_A: "SOUTH / A / CROSS", JOY_BUTTON_B: "EAST / B / CIRCLE", JOY_BUTTON_X: "WEST / X / SQUARE", JOY_BUTTON_Y: "NORTH / Y / TRIANGLE", JOY_BUTTON_LEFT_SHOULDER: "LEFT SHOULDER", JOY_BUTTON_RIGHT_SHOULDER: "RIGHT SHOULDER", JOY_BUTTON_LEFT_STICK: "LEFT STICK CLICK", JOY_BUTTON_RIGHT_STICK: "RIGHT STICK CLICK"}.get(button, "BUTTON %d" % button)

func _cycle(slot: int, direction: int) -> void:
	if network.active:
		if not network.can_choose(slot): return
		var current: StringName = StringName(network.seats[slot].character)
		network.choose_character(slot, Roster.IDS[posmod(Roster.IDS.find(current) + direction, Roster.IDS.size())])
		return
	selections[slot] = Roster.IDS[posmod(Roster.IDS.find(selections[slot]) + direction, Roster.IDS.size())]
	ready_slots[slot] = router.devices[slot] < 0
	sound.ui_cue("ui_move")
	_select(false)

func _toggle_ready(slot: int) -> void:
	if network.active:
		if network.owns(slot): network.set_ready(not network.seats[slot].ready)
		return
	ready_slots[slot] = not ready_slots[slot]
	sound.ui_cue()
	_select(false)

func _cycle_difficulty(direction: int = 1) -> void:
	difficulty = posmod(difficulty + direction, 3)
	_save_settings()
	_select(false)

func setup_state(device: int) -> Dictionary:
	if not setup_states.has(device):
		setup_states[device] = {"field": maxi(0, router.devices.find(device)), "editing": false}
	return setup_states[device]

func setup_can_edit(device: int, slot: int) -> bool:
	var owner: int = router.devices[slot]
	if owner >= 0: return owner == device
	if owner == PlayerInputRouter.BOT or device < 0: return true
	# Before the first pad joins, P1 is the default solo keyboard/touch seat.
	for assigned in router.devices:
		if assigned >= 0: return false
	return true

func setup_start(device: int) -> void:
	if network.active:
		if not network.local_devices.has(device): return
		var party_ready: bool = true
		for owned in network.own_slots(): party_ready = party_ready and bool(network.seats[owned].ready)
		if not party_ready: network.set_ready(true)
		elif network.can_manage_room(): network.launch_room()
		return
	var slot: int = router.devices.find(device)
	var state: Dictionary = setup_state(device)
	state.editing = false
	setup_device = device
	setup_notice = ""
	if slot < 0:
		var target: int = int(state.field)
		if target >= 8: target -= 8
		if target >= 4 or not setup_can_edit(device, target): target = router.devices.find(PlayerInputRouter.BOT)
		if target < 0:
			setup_notice = "All four player slots are occupied."
			_select(false)
			return
		router.assign_device(target, device)
		device_guids[device] = Input.get_joy_guid(device) if Input.get_connected_joypads().has(device) else ""
		ready_slots[target] = false
		state.field = target
		_select(false)
	elif not ready_slots[slot]:
		_toggle_ready(slot)
	else:
		_launch_requested()

func setup_assign_input(slot: int, device: int) -> bool:
	if network.active or slot < 0 or slot >= 4 or not setup_input_options().has(device): return false
	var previous: int = router.devices.find(device) if device != PlayerInputRouter.BOT else -1
	if previous >= 0 and previous != slot:
		router.devices[previous] = PlayerInputRouter.BOT
		ready_slots[previous] = true
	var changed: bool = router.devices[slot] != device
	router.assign_device(slot, device)
	if changed: ready_slots[slot] = device < 0
	if device >= 0:
		device_guids[device] = Input.get_joy_guid(device) if Input.get_connected_joypads().has(device) else ""
	# A reassigned device must never carry held gameplay input to its new fighter.
	router.clear_state()
	for state in setup_states.values():
		if int(state.field) in [slot, previous] or int(state.field) >= 8: state.editing = false
	setup_notice = "P%d INPUT: %s" % [slot + 1, input_label(device)]
	_select(false)
	return true

func _watch() -> void:
	router.devices = [-2, -2, -2, -2]
	_start_match()

func _launch_requested() -> void:
	if network.active:
		if network.can_manage_room(): network.launch_room()
		else: _network_ready()
		return
	for slot in range(4):
		if router.devices[slot] >= 0 and not ready_slots[slot]:
			setup_notice = "PLAYER %d: PRESS START TO READY" % (slot + 1)
			_select(false)
			sound.ui_cue("warning")
			return
	_start_match()

func _join_device(device: int) -> void:
	if screen == &"network" and not network.active:
		if not network_devices.has(device) and network_devices.size() < 4:
			network_devices.append(device)
			_show(&"network")
		return
	if disconnected_slot >= 0:
		router.assign_device(disconnected_slot, device)
		if network.active:
			var index: int = network.own_slots().find(disconnected_slot)
			if index >= 0: network.local_devices[index] = device
		device_guids[device] = Input.get_joy_guid(device)
		disconnected_slot = -1
		_show(&"pause", "CONTROLLER CONNECTED")
		return
	if screen != &"select": return
	for slot in range(4):
		if router.devices[slot] == PlayerInputRouter.BOT:
			router.assign_device(slot, device)
			device_guids[device] = Input.get_joy_guid(device)
			ready_slots[slot] = false
			_select(false)
			return

func _device_lost(slot: int) -> void:
	if selection_options_device == router.devices[slot]: selection_options_device = -1
	setup_states.erase(router.devices[slot])
	if setup_device == router.devices[slot]: setup_device = -1
	disconnected_slot = slot
	disconnected_guid = str(device_guids.get(router.devices[slot], ""))
	# Release the dead numeric ID while paused; replacement START must join explicitly.
	router.devices[slot] = PlayerInputRouter.BOT
	if screen == &"select":
		router.devices[slot] = PlayerInputRouter.BOT
		ready_slots[slot] = true
		disconnected_slot = -1
		_select(false)
	else:
		_pause("PLAYER %d: CONTROLLER LOST" % (slot + 1))

func _device_connection(device: int, connected: bool) -> void:
	if connected and disconnected_slot >= 0 and not disconnected_guid.is_empty() and Input.get_joy_guid(device) == disconnected_guid:
		_join_device(device)
	elif screen == &"select":
		_select(false)

func _bot_takeover() -> void:
	if disconnected_slot >= 0:
		router.devices[disconnected_slot] = PlayerInputRouter.BOT
		if network.active:
			var index: int = network.own_slots().find(disconnected_slot)
			if index >= 0: network.local_devices[index] = PlayerInputRouter.BOT
		disconnected_slot = -1
	_resume()

func _start_match() -> void:
	if network.active:
		network.launch_room()
		return
	_create_match({"difficulty": difficulty, "stage": String(selected_stage)})

func _arena_menu() -> void:
	if network.active and not network.can_manage_room(): return
	_show(&"arena")

func _choose_stage(id: StringName) -> void:
	if not StageCatalog.IDS.has(id): return
	selected_stage = id
	if network.active: network.choose_stage(id)
	_show(&"network" if network.active else &"select")

func _create_match(config: Dictionary) -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	_clear_match()
	router.clear_state()
	session = MatchSession.new()
	add_child(session)
	session.setup(router, selections, config)
	if network.active: session.simulation_enabled = false
	if presentation_enabled:
		sound.attach(session)
		session.match_finished.connect(_results)
	else:
		if network.active: network.bind_match(session)
		screen = &"match"
		return
	if not capture_directory.is_empty(): session.combat_event.connect(_capture_event)
	view = BattleView.new()
	add_child(view)
	view.setup(session)
	view.camera.shake_amount = [0.0, 0.35, 0.65][shake_setting]
	hud = BattleHUD.new()
	hud.session = session
	hud.camera = view.camera
	hud.debug_visible = debug_enabled
	ui_layer.add_child(hud)
	if router.touch_enabled:
		touch_controls = TouchControls.new()
		touch_controls.app = self
		touch_controls.router = router
		ui_layer.add_child(touch_controls)
	screen = &"match"
	if network.active:
		# A client is ready only after its first rendered frame; shader compilation
		# must not consume the opening seconds of the shared match.
		var loaded_session: MatchSession = session
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		if session == loaded_session and is_instance_valid(loaded_session) and network.active:
			network.bind_match(loaded_session)

func _pause(message: String = "TAKE A BREATHER") -> void:
	if session == null or perf_seconds > 0.0 or network_test_seconds > 0.0: return
	if screen != &"match" and disconnected_slot < 0: return
	if network.active:
		network.suspended_local = true
		router.clear_state()
	else: session.paused = true
	_show(&"pause", message)

func _resume() -> void:
	if disconnected_slot >= 0:
		sound.ui_cue("warning")
		return
	if overlay:
		overlay.queue_free()
		overlay = null
	router.clear_state()
	if network.active: network.suspended_local = false
	session.paused = false
	screen = &"match"

func _results() -> void:
	_show(&"results")
	if not capture_directory.is_empty() and not captured_events.has("results"):
		_capture_named("results", {"kind": "live-match-results"}, 0.5)
	if soak and not network.active:
		soak_rounds.append({"round": soak_rounds.size() + 1, "stage": selected_stage, "roster": selections.duplicate(), "events": session.event_counts.duplicate(), "memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "errors": session.parts.conservation_errors()})
		print("SOAK_ROUND ", JSON.stringify(soak_rounds[-1]))
		await get_tree().create_timer(2.0).timeout
		if not closing:
			if rotate_content:
				selected_stage = StageCatalog.IDS[soak_rounds.size() % StageCatalog.IDS.size()]
				for slot in range(4): selections[slot] = Roster.IDS[(slot + (soak_rounds.size() % 2) * 4) % Roster.IDS.size()]
			_start_match()
			for fighter in session.fighters:
				fighter.brain.rng.seed += soak_rounds.size() * 397

func _page(page: StringName) -> void:
	page_return = &"pause" if session and (session.paused or network.suspended_local) else &"title"
	_show(page)

func _back() -> void:
	_show(&"pause") if page_return == &"pause" and session else _title()

func _save_settings() -> void:
	var config := ConfigFile.new()
	for property in [&"master_volume", &"music_volume", &"sfx_volume", &"ui_volume", &"rumble"]:
		config.set_value("audio", property, sound.get(property))
	config.set_value("input", "keyboard", router.keyboard_bindings)
	config.set_value("input", "gamepad", router.gamepad_bindings)
	config.set_value("input", "profiles", router.gamepad_profiles)
	config.set_value("input", "deadzone", router.deadzone)
	config.set_value("display", "shake", shake_setting)
	config.set_value("game", "difficulty", difficulty)
	config.set_value("network", "room_server", internet_rooms.server_url)
	config.save("user://settings.cfg")

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK: return
	for property in [&"master_volume", &"music_volume", &"sfx_volume", &"ui_volume", &"rumble"]:
		sound.set(property, clampf(float(config.get_value("audio", property, sound.get(property))), 0, 1))
	var keys: Dictionary = config.get_value("input", "keyboard", {})
	for action in PlayerInputRouter.DEFAULT_KEYS:
		if keys.has(action) and keys[action] is int:
			router.keyboard_bindings[action] = keys[action]
	var buttons: Dictionary = config.get_value("input", "gamepad", {})
	for action in PlayerInputRouter.DEFAULT_BUTTONS:
		if buttons.has(action) and buttons[action] is int:
			router.gamepad_bindings[action] = buttons[action]
	router.gamepad_profiles = config.get_value("input", "profiles", {})
	router.deadzone = clampf(float(config.get_value("input", "deadzone", 0.2)), 0.1, 0.35)
	shake_setting = clampi(int(config.get_value("display", "shake", 1)), 0, 2)
	difficulty = clampi(int(config.get_value("game", "difficulty", 1)), 0, 2)
	internet_rooms.server_url = str(config.get_value("network", "room_server", ""))
	sound.apply_volumes()

func _cycle_shake() -> void:
	shake_setting = (shake_setting + 1) % 3
	if view: view.camera.shake_amount = [0.0, 0.35, 0.65][shake_setting]
	_save_settings()
	_show(&"settings")

func _cycle_deadzone() -> void:
	router.deadzone = router.deadzone + 0.05 if router.deadzone < 0.34 else 0.1
	_save_settings()
	_show(&"settings")

func _toggle_fullscreen() -> void:
	get_window().mode = Window.MODE_WINDOWED if get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_FULLSCREEN

func _reset_bindings() -> void:
	router.keyboard_bindings = PlayerInputRouter.DEFAULT_KEYS.duplicate()
	router.gamepad_bindings = PlayerInputRouter.DEFAULT_BUTTONS.duplicate()
	router.gamepad_profiles.clear()
	router.deadzone = 0.2
	_save_settings()
	_show(&"settings")

func _begin_remap(pad: bool) -> void:
	remap_pad = pad
	remap_device = -1
	remap_pending.clear()
	remap_status = "Press a button on the controller you want to remap." if pad else "Use a different physical key for each action."
	remap_actions.assign(PlayerInputRouter.ACTIONS if pad else PlayerInputRouter.DEFAULT_KEYS.keys())
	_render_remap()

func _render_remap() -> void:
	_show(&"remap")
	front.label("YOUR HANDS. YOUR RULES.", Vector2(260, 167), 83, Color("ffcf4d"), 0, front.heading)
	front.label("CONTROLLER REMAP" if remap_pad else "KEYBOARD REMAP", Vector2(267, 290), 35, Color("9bcee0"), 0, front.bold)
	front.panel(Rect2(265, 389, 1390, 223), Color("213d56"))
	remap_prompt = front.label("PRESS FOR:  %s" % String(remap_actions[0]).to_upper(), Vector2(307, 443), 68, Color.WHITE, 0, front.heading)
	front.label(remap_status, Vector2(274, 671), 30, Color("aac9dc"), 1350)
	front.button("CANCEL  /  ESC", Rect2(270, 805, 470, 76), _cancel_remap)

func _cancel_remap() -> void:
	remap_actions.clear()
	remap_pending.clear()
	router.clear_state()
	_show(&"settings")

func _remap_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_cancel_remap()
		get_viewport().set_input_as_handled()
		return
	var value: int = -1
	if remap_pad and event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_START, JOY_BUTTON_BACK, JOY_BUTTON_GUIDE]: return
		if remap_device < 0: remap_device = event.device
		if event.device != remap_device: return
		value = event.button_index
	elif not remap_pad and event is InputEventKey and event.pressed and not event.echo:
		value = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if value in [KEY_ESCAPE, KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_META]: return
	if value < 0: return
	get_viewport().set_input_as_handled()
	if remap_pending.values().has(value):
		remap_status = "That input is already assigned. Choose another."
		_render_remap()
		return
	remap_pending[remap_actions.pop_front()] = value
	sound.ui_cue()
	if remap_actions.is_empty():
		if remap_pad:
			var guid: String = Input.get_joy_guid(remap_device)
			if not guid.is_empty():
				router.gamepad_profiles[guid] = remap_pending.duplicate()
			else:
				router.gamepad_bindings = remap_pending.duplicate()
		else:
			router.keyboard_bindings = remap_pending.duplicate()
		_save_settings()
		router.clear_state()
		_show(&"settings")
	else:
		remap_status = "Saved for this controller model." if remap_pad else "Escape cancels without changing your saved bindings."
		_render_remap()

func _quit_game() -> void:
	if closing: return
	closing = true
	if not frame_window_path.is_empty():
		var output := FileAccess.open(frame_window_path, FileAccess.WRITE)
		if output:
			output.store_string(JSON.stringify({"platform": OS.get_name(), "version": ProjectSettings.get_setting("application/config/version"), "presentation": presentation_enabled, "renderer": RenderingServer.get_current_rendering_method(), "windows": frame_windows}, "  "))
			output.close()
	if session: session.paused = true
	if network: network.close()
	if sound:
		sound.session = null
		sound.set_process(false)
		sound.stop_all()
	await get_tree().create_timer(0.10).timeout
	get_tree().quit()

func _record_frame_window(milliseconds: float) -> void:
	if milliseconds <= 0: return
	var phase: String = String(session.phase)
	if frame_window_count == 0: frame_window_phase = phase
	elif frame_window_phase != phase: frame_window_phase = "transition"
	frame_window_seconds += milliseconds / 1000.0
	frame_window_count += 1
	frame_window_max = maxf(frame_window_max, milliseconds)
	if frame_window_seconds >= 1.0:
		frame_windows.append({"elapsed": snappedf(maxf(perf_elapsed, network_elapsed), 0.01), "stage": session.stage.definition.id, "phase": frame_window_phase, "frames": frame_window_count, "seconds": snappedf(frame_window_seconds, 0.0001), "fps": snappedf(frame_window_count / frame_window_seconds, 0.01), "max_frame_ms": frame_window_max})
		frame_window_seconds = 0.0
		frame_window_count = 0
		frame_window_max = 0.0

func _capture_event(kind: StringName, payload: Dictionary) -> void:
	if capture_busy: return
	var fighter: Fighter = payload.get("fighter")
	var name: String = ""
	var delay: float = 0.055
	if kind == &"part_pop": name = "part-pop"
	elif kind == &"core_pop": name = "core-pop"
	elif kind == &"snap" and payload.stolen:
		name = "steal"
		if fighter.data.id == &"momo" and payload.part.definition.id == &"pile_cannon":
			name = "momo-cannon-snap"
			delay = 0.32
	elif kind == &"attack_active" and fighter.data.id == &"momo" and payload.attack.id == &"pile_shot":
		name = "momo-cannon-fire"
	elif kind == &"go":
		name = "skyport-battle"
		delay = 1.8
	if name.is_empty() or captured_events.has(name): return
	var details: Dictionary = {"kind": "live-four-bot-gameplay", "event": kind, "tick": session.tick, "round": soak_rounds.size() + 1, "seconds": snappedf(session.elapsed, 0.01), "debug": false}
	if fighter:
		details.mech = fighter.data.id
		details.slot = fighter.slot
	_capture_named(name, details, delay)

func _capture_named(name: String, details: Dictionary, delay: float = 0.05) -> void:
	captured_events[name] = true
	capture_busy = true
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var path: String = capture_directory.path_join(name + ".png")
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	details["viewport"] = get_viewport().get_texture().get_size()
	details["capture_delay"] = delay
	details["error"] = error
	var file := FileAccess.open(capture_directory.path_join(name + ".json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(details, "  "))
	print("EVENT_CAPTURE ", name, " ", error)
	capture_busy = false
