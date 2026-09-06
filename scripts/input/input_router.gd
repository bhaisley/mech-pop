class_name PlayerInputRouter
extends Node

signal pause_requested
signal device_lost(slot: int)
signal join_requested(device: int)

const KEYBOARD: int = -1
const BOT: int = -2
const REMOTE: int = -3
const TOUCH: int = -4
const ACTIONS: Array[StringName] = [&"jump", &"light", &"heavy", &"special", &"dodge", &"salvage"]
const DEFAULT_KEYS: Dictionary = {
	&"left": KEY_A, &"right": KEY_D, &"up": KEY_W, &"down": KEY_S,
	&"jump": KEY_SPACE, &"light": KEY_J, &"heavy": KEY_K,
	&"special": KEY_L, &"dodge": KEY_SHIFT, &"salvage": KEY_E,
}
const DEFAULT_BUTTONS: Dictionary = {
	&"jump": JOY_BUTTON_A, &"light": JOY_BUTTON_X, &"heavy": JOY_BUTTON_Y,
	&"special": JOY_BUTTON_B, &"dodge": JOY_BUTTON_LEFT_SHOULDER,
	&"salvage": JOY_BUTTON_RIGHT_SHOULDER,
}

var touch_enabled: bool = OS.has_feature("ios") or OS.get_cmdline_user_args().has("--touch-preview")
var devices: Array[int] = [primary_device(), BOT, BOT, BOT]
var keyboard_bindings: Dictionary = DEFAULT_KEYS.duplicate()
var gamepad_bindings: Dictionary = DEFAULT_BUTTONS.duplicate()
var gamepad_profiles: Dictionary = {}
var deadzone: float = 0.2
var held_keys: Dictionary = {}
var held_buttons: Dictionary = {}
var axes: Dictionary = {}
var edges: Array[Dictionary] = [{}, {}, {}, {}]
var touch_move := Vector2.ZERO
var touch_held: Dictionary = {}

func _ready() -> void:
	Input.use_accumulated_input = false
	# Keep menu confirmation explicit: the engine's built-in ui_accept
	# bindings in this version include keyboard keys but no gamepad button.
	var menu_accept := InputEventJoypadButton.new()
	menu_accept.device = -1
	menu_accept.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event(&"ui_accept", menu_accept):
		InputMap.action_add_event(&"ui_accept", menu_accept)
	Input.joy_connection_changed.connect(_on_device_connection)
	get_window().focus_exited.connect(_on_focus_lost)

func primary_device() -> int:
	return TOUCH if touch_enabled else KEYBOARD

func _input(event: InputEvent) -> void:
	feed_event(event)

func feed_event(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.echo:
			return
		var code: int = key_event.physical_keycode
		if code == 0:
			code = key_event.keycode
		held_keys[code] = key_event.pressed
		if key_event.pressed and code == KEY_ESCAPE:
			pause_requested.emit()
		for slot in range(4):
			if devices[slot] != KEYBOARD:
				continue
			for action in ACTIONS:
				if key_event.pressed and int(keyboard_bindings[action]) == code:
					edges[slot][action] = true
	elif event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		var state: Dictionary = held_buttons.get(event.device, {})
		state[button_event.button_index] = button_event.pressed
		held_buttons[event.device] = state
		var slot: int = devices.find(event.device)
		if button_event.pressed and button_event.button_index == JOY_BUTTON_START:
			if slot < 0:
				join_requested.emit(event.device)
			else:
				pause_requested.emit()
		if slot >= 0:
			for action in ACTIONS:
				if button_event.pressed and int(buttons_for(event.device)[action]) == button_event.button_index:
					edges[slot][action] = true
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var state: Vector2 = axes.get(event.device, Vector2.ZERO)
		if motion.axis == JOY_AXIS_LEFT_X:
			state.x = motion.axis_value
		elif motion.axis == JOY_AXIS_LEFT_Y:
			state.y = motion.axis_value
		axes[event.device] = state

func command_for(slot: int) -> FighterCommand:
	var command := FighterCommand.new()
	var device: int = devices[slot]
	if device == KEYBOARD:
		command.move = Vector2(float(_key(&"right")) - float(_key(&"left")), float(_key(&"down")) - float(_key(&"up")))
		command.jump_held = _key(&"jump")
	elif device == TOUCH and touch_enabled:
		command.move = touch_move
		command.jump_held = bool(touch_held.get(&"jump", false))
	elif device >= 0:
		var state: Dictionary = held_buttons.get(device, {})
		var stick: Vector2 = axes.get(device, Vector2.ZERO)
		if stick.length() > deadzone:
			command.move = stick.normalized() * clampf((stick.length() - deadzone) / (1.0 - deadzone), 0.0, 1.0)
		var dpad := Vector2(float(state.get(JOY_BUTTON_DPAD_RIGHT, false)) - float(state.get(JOY_BUTTON_DPAD_LEFT, false)), float(state.get(JOY_BUTTON_DPAD_DOWN, false)) - float(state.get(JOY_BUTTON_DPAD_UP, false)))
		if not dpad.is_zero_approx():
			command.move = dpad
		command.jump_held = bool(state.get(buttons_for(device)[&"jump"], false))
	command.jump_pressed = bool(edges[slot].get(&"jump", false))
	command.light = bool(edges[slot].get(&"light", false))
	command.heavy = bool(edges[slot].get(&"heavy", false))
	command.special = bool(edges[slot].get(&"special", false))
	command.dodge = bool(edges[slot].get(&"dodge", false))
	command.salvage = bool(edges[slot].get(&"salvage", false))
	edges[slot].clear()
	return command

func _key(action: StringName) -> bool:
	return bool(held_keys.get(keyboard_bindings[action], false))

func clear_state() -> void:
	held_keys.clear()
	held_buttons.clear()
	axes.clear()
	touch_move = Vector2.ZERO
	touch_held.clear()
	for entry in edges:
		entry.clear()

func set_touch_action(action: StringName, pressed: bool) -> void:
	if not touch_enabled or not ACTIONS.has(action):
		return
	var was_held: bool = bool(touch_held.get(action, false))
	touch_held[action] = pressed
	var slot: int = devices.find(TOUCH)
	if slot >= 0 and pressed and not was_held:
		edges[slot][action] = true

func assign_device(slot: int, device: int) -> bool:
	if slot < 0 or slot > 3:
		return false
	if device != BOT and devices.has(device) and devices[slot] != device:
		return false
	devices[slot] = device
	edges[slot].clear()
	return true

func _on_device_connection(device: int, connected: bool) -> void:
	if not connected:
		var slot: int = devices.find(device)
		held_buttons.erase(device)
		axes.erase(device)
		if slot >= 0:
			edges[slot].clear()
			device_lost.emit(slot)

func _on_focus_lost() -> void:
	clear_state()
	pause_requested.emit()

func buttons_for(device: int) -> Dictionary:
	if not Input.get_connected_joypads().has(device):
		return gamepad_bindings
	var guid: String = Input.get_joy_guid(device)
	return gamepad_profiles.get(guid, gamepad_bindings)
