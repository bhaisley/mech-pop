class_name TouchControls
extends Control

var app: Node
var router: PlayerInputRouter
var fingers: Dictionary = {}
var stick_offset := Vector2.ZERO
var active: bool = false
var font: Font = preload("res://ui/fonts/BarlowCondensed-Bold.ttf")
const STICK_RADIUS: float = 116.0
const BUTTON_RADIUS: float = 59.0
const ACTION_ORDER: Array[StringName] = [&"dodge", &"special", &"salvage", &"light", &"heavy", &"jump"]
const TITLES := {&"dodge": "DODGE", &"special": "SPECIAL", &"salvage": "SALVAGE", &"light": "LIGHT", &"heavy": "BREAK", &"jump": "JUMP"}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_window().focus_exited.connect(release_all)

func _process(_delta: float) -> void:
	var should_show: bool = app.session != null and app.screen == &"match" and not app.session.paused
	if not should_show and not fingers.is_empty():
		release_all()
	active = should_show
	visible = active
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active or app.screen != &"match":
		return
	if event is InputEventScreenTouch:
		if feed_touch(event.index, event.position, event.pressed):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if feed_touch(event.index, event.position, true, true):
			get_viewport().set_input_as_handled()

func reference_size() -> Vector2:
	return size / maxf(size.x / 1920.0, 0.001)

func stick_center() -> Vector2:
	return Vector2(175, reference_size().y - 340)

func action_center(action: StringName) -> Vector2:
	var index: int = ACTION_ORDER.find(action)
	return Vector2(1438 + (index % 3) * 153, reference_size().y - (422 if index < 3 else 274))

func feed_touch(index: int, pixel_position: Vector2, pressed: bool, dragging: bool = false) -> bool:
	if not pressed:
		if not fingers.has(index): return false
		_release(index)
		return true
	var at: Vector2 = pixel_position / maxf(size.x / 1920.0, 0.001)
	if fingers.has(index):
		if fingers[index] == &"move": _move_stick(at)
		return true
	if dragging: return false
	if at.distance_to(Vector2(1826, 147)) < 54:
		release_all()
		router.pause_requested.emit()
		return true
	if not router.devices.has(PlayerInputRouter.TOUCH): return false
	if at.distance_to(stick_center()) < STICK_RADIUS * 1.3 and not fingers.values().has(&"move"):
		fingers[index] = &"move"
		_move_stick(at)
		return true
	for action in ACTION_ORDER:
		if at.distance_to(action_center(action)) <= BUTTON_RADIUS * 1.1:
			fingers[index] = action
			router.set_touch_action(action, true)
			return true
	return false

func _move_stick(at: Vector2) -> void:
	stick_offset = (at - stick_center()).limit_length(STICK_RADIUS)
	var strength: float = stick_offset.length() / STICK_RADIUS
	router.touch_move = Vector2.ZERO if strength < 0.14 else stick_offset.normalized() * inverse_lerp(0.14, 1.0, strength)

func _release(index: int) -> void:
	var action: StringName = fingers[index]
	fingers.erase(index)
	if action == &"move":
		stick_offset = Vector2.ZERO
		router.touch_move = Vector2.ZERO
	elif not fingers.values().has(action):
		router.set_touch_action(action, false)

func release_all() -> void:
	for index in fingers.keys(): _release(index)

func _exit_tree() -> void:
	release_all()

func _draw() -> void:
	if not active: return
	var scale_factor: float = size.x / 1920.0
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * scale_factor)
	_button(Vector2(1826, 147), 46, "Ⅱ", Color("aee8f3"), false)
	if not router.devices.has(PlayerInputRouter.TOUCH): return
	var center: Vector2 = stick_center()
	draw_circle(center, STICK_RADIUS, Color(0.04, 0.10, 0.18, 0.37))
	draw_arc(center, STICK_RADIUS, 0, TAU, 64, Color(0.67, 0.86, 0.95, 0.75), 3, true)
	draw_line(center - Vector2(73, 0), center + Vector2(73, 0), Color(0.7, 0.9, 1, 0.25), 2)
	draw_line(center - Vector2(0, 73), center + Vector2(0, 73), Color(0.7, 0.9, 1, 0.25), 2)
	draw_circle(center + stick_offset * 0.62, 43, Color(0.68, 0.89, 0.97, 0.72))
	for action in ACTION_ORDER:
		var tint: Color = Color("ffdf65") if action == &"salvage" else (Color("ff93c5") if action == &"special" else Color("bce5f3"))
		_button(action_center(action), BUTTON_RADIUS, TITLES[action], tint, fingers.values().has(action))

func _button(at: Vector2, radius: float, text: String, tint: Color, held: bool) -> void:
	draw_circle(at, radius, Color(tint, 0.75) if held else Color(0.035, 0.08, 0.15, 0.58))
	draw_arc(at, radius, 0, TAU, 40, tint, 3, true)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	draw_string(font, at + Vector2(-text_width * 0.5, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("142338") if held else tint)
