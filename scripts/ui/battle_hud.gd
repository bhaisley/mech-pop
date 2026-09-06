class_name BattleHUD
extends Control

var session: MatchSession
var camera: BattleCamera
var debug_visible: bool = false
var font: Font
var elapsed: float = 0.0
var headline: Font = preload("res://ui/fonts/BarlowCondensed-BlackItalic.ttf")
var body_font: Font = preload("res://ui/fonts/Barlow-SemiBold.ttf")
var notice: String = ""
var notice_time: float = 0.0
var notice_color := Color("ffcf4d")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = load("res://ui/fonts/BarlowCondensed-Bold.ttf")
	session.combat_event.connect(_notice)

func _process(delta: float) -> void:
	elapsed += delta
	notice_time = maxf(0.0, notice_time - delta)
	queue_redraw()

func text_at(message: String, point: Vector2, font_size: int, color: Color = Color.WHITE) -> void:
	draw_string_outline(font, point, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color("101824"))
	draw_string(font, point, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if session == null:
		return
	var viewport_size: Vector2 = size
	var sx: float = viewport_size.x / 1920.0
	var sy: float = sx
	var logical_height: float = viewport_size.y / maxf(sx, 0.001)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sx))
	var ink := Color("142338")
	var quiet := Color("9cbbc9")
	draw_style_box(_panel(ink, Color("3b5b71")), Rect2(853, 39, 214, 83))
	var seconds: int = ceili(session.remaining)
	text_at("%d:%02d" % [seconds / 60, seconds % 60], Vector2(898, 96), 46, Color("ffdb60") if seconds <= 30 else Color.WHITE)
	draw_style_box(_panel(ink, Color("3b5b71")), Rect2(65, 38, 429, 53))
	text_at("%s  /  POP RUSH" % session.stage.definition.display_name, Vector2(87, 75), 27)
	text_at("+1 CORE POP   /   −1 FALL", Vector2(1610, 75), 25, Color("e3f5ff"))
	for fighter in session.fighters:
		var x: float = 66 + fighter.slot * 451
		var y: float = logical_height - 187
		var tint: Color = Roster.PLAYER_COLORS[fighter.slot]
		draw_style_box(_panel(ink, tint.darkened(0.25)), Rect2(x, y, 433, 135))
		draw_rect(Rect2(x, y, 8, 135), tint)
		draw_style_box(_panel(tint.darkened(0.79), tint.darkened(0.35)), Rect2(x + 17, y + 12, 82, 112))
		var portrait_tint: Color = Color.WHITE if fighter.alive() else Color(0.5, 0.55, 0.65)
		var portrait: Texture2D = Roster.portrait(fighter.data.id)
		if portrait: draw_texture_rect_region(portrait, Rect2(x + 18, y + 16, 80, 80), fighter.data.face_region, portrait_tint)
		text_at("PLAYER %d" % (fighter.slot + 1), Vector2(x + 25, y + 115), 17, tint)
		text_at(fighter.data.display_name, Vector2(x + 112, y + 36), 29)
		var device: int = session.input_router.devices[fighter.slot]
		var input_name: String = {PlayerInputRouter.BOT: "BOT", PlayerInputRouter.REMOTE: "NET", PlayerInputRouter.KEYBOARD: "KEYS", PlayerInputRouter.TOUCH: "TOUCH"}.get(device, "PAD")
		text_at(input_name, Vector2(x + 250, y + 32), 18, quiet)
		text_at("%+d" % fighter.score, Vector2(x + 348, y + 37), 32, tint)
		var core_color: Color = Color("e957d9") if fighter.part(&"shell") == null else tint
		draw_rect(Rect2(x + 112, y + 52, 237, 17), Color("2c3c51"))
		draw_rect(Rect2(x + 112, y + 52, 237 * fighter.core / 100.0, 17), core_color)
		text_at(str(ceili(fighter.core)), Vector2(x + 363, y + 69), 23, core_color)
		var arm: PartInstance = fighter.part(&"weapon_arm")
		var shell: PartInstance = fighter.part(&"shell")
		_module(x + 112, y + 89, arm, "ARM LOST", 141)
		_module(x + 268, y + 89, shell, "EXPOSED!", 142)
		if not fighter.alive():
			text_at("REBOOT  %.1f" % fighter.respawn_time, Vector2(x + 92, y - 15), 29, tint)
		var nearest: SalvageBody = session.parts.nearest(fighter)
		if nearest and device not in [PlayerInputRouter.BOT, PlayerInputRouter.REMOTE]:
			var key: String = "SALVAGE" if device == PlayerInputRouter.TOUCH else (OS.get_keycode_string(session.input_router.keyboard_bindings[&"salvage"]) if device == PlayerInputRouter.KEYBOARD else "RB")
			text_at("[%s]  %s" % [key, nearest.part.definition.display_name], Vector2(x + 18, y - 20), 26, Color("ffdc58"))
	draw_rect(Rect2(0, logical_height - 38, 1920, 38), Color("111f32"))
	var binds: Dictionary = session.input_router.keyboard_bindings
	var prompt: String = "%s JUMP   %s LIGHT   %s + DIRECTION BREAKER   %s SPECIAL   %s DODGE   %s SALVAGE   ESC PAUSE" % [OS.get_keycode_string(binds[&"jump"]), OS.get_keycode_string(binds[&"light"]), OS.get_keycode_string(binds[&"heavy"]), OS.get_keycode_string(binds[&"special"]), OS.get_keycode_string(binds[&"dodge"]), OS.get_keycode_string(binds[&"salvage"])]
	if session.input_router.devices.has(PlayerInputRouter.TOUCH):
		prompt = "LEFT THUMB MOVE + AIM   •   RIGHT THUMB ACTIONS   •   CRACK A PART, BREAK IT, THEN TAP SALVAGE"
	elif not session.input_router.devices.has(PlayerInputRouter.KEYBOARD):
		prompt = "SOUTH JUMP   WEST LIGHT   NORTH + DIRECTION BREAKER   EAST SPECIAL   LB DODGE   RB SALVAGE   START PAUSE"
	text_at(prompt, Vector2(277, logical_height - 12), 22, Color("95b6cc"))
	if notice_time > 0 and session.phase == &"fight":
		var width: float = font.get_string_size(notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 29).x + 58
		draw_style_box(_panel(ink, notice_color.darkened(0.4)), Rect2((1920 - width) / 2, 141, width, 58))
		text_at(notice, Vector2((1920 - width) / 2 + 29, 182), 29, notice_color)
	if session.phase == &"intro":
		var message: String = "READY TO POP?" if session.countdown > 1.0 else "LET'S GO!"
		draw_colored_polygon(PackedVector2Array([Vector2(545, 337), Vector2(1400, 337), Vector2(1360, 508), Vector2(505, 508)]), Color("142c46"))
		var width: float = headline.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 97).x
		draw_string(headline, Vector2((1920 - width) / 2, 445), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 97, Color("ffda50"))
		text_at("FIGHT  →  BREAK  →  STEAL  →  REBUILD", Vector2(660, 486), 26)
	if debug_visible:
		text_at("DEV  |  %d FPS  |  TICK %d  |  PARTS %d  |  PROJECTILES %d" % [Engine.get_frames_per_second(), session.tick, session.parts.instances.size(), session.projectiles.size()], Vector2(74, 150), 21, Color("ffe18a"))
		text_at("F2 ARM POP   F3 SHELL POP   F4 GIVE CANNON   F5 CORE POP   F6 BOT P1   F7 SLOW   F8 STEP", Vector2(74, 180), 20, Color("ffe18a"))
		text_at("F9 P1 INVINCIBLE   F10 BOT LEVEL   F11 FREEZE   |   CAMERA %0.1f   |   BOT %s" % [camera.size, ["CASUAL", "ARCADE", "ACE"][session.fighters[0].brain.difficulty]], Vector2(74, 209), 20, Color("ffe18a"))
		if camera:
			for fighter in session.fighters:
				if not fighter.alive():
					continue
				_draw_world_rect(fighter.hurt_rect(), Color(0.4, 1.0, 0.7, 0.65), sx, sy)
				if fighter.attack and fighter.attack.is_active(fighter.attack_time):
					_draw_world_rect(fighter.attack.hit_rect(fighter.position, fighter.facing), Color(1, 0.4, 0.2, 0.8), sx, sy)

func _module(x: float, y: float, item: PartInstance, empty: String, width: float) -> void:
	var tint: Color = Color("ed6eda") if item == null else (Color("ffdb60") if item.is_cracked() else Color("b4d0de"))
	text_at(item.definition.short_name if item else empty, Vector2(x, y + 8), 21, tint)
	draw_rect(Rect2(x, y + 17, width, 6), Color("314158"))
	if item:
		draw_rect(Rect2(x, y + 17, width * item.condition / item.definition.maximum, 6), tint)

func _panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style

func _draw_world_rect(rect: Rect2, tint: Color, sx: float, sy: float) -> void:
	var a: Vector2 = camera.unproject_position(Vector3(rect.position.x / 100, -rect.position.y / 100, 0))
	var b: Vector2 = camera.unproject_position(Vector3(rect.end.x / 100, -rect.end.y / 100, 0))
	draw_rect(Rect2(a / Vector2(sx, sy), (b - a) / Vector2(sx, sy)), tint, false, 2.0)

func _notice(kind: StringName, payload: Dictionary) -> void:
	if kind == &"part_pop":
		notice = "PART LOOSE!   GET CLOSE + SALVAGE"
		notice_time = 2.4
		notice_color = Color("ffcf4d")
	elif kind == &"snap" and payload.stolen:
		notice = "%s STOLE %s!" % [payload.fighter.data.display_name, payload.part.definition.display_name.to_upper()]
		notice_time = 2.1
		notice_color = Roster.PLAYER_COLORS[payload.fighter.slot]
	elif kind == &"final_thirty":
		notice = "FINAL 30!   EVERY POP COUNTS"
		notice_time = 3.0
		notice_color = Color("ffcf4d")
