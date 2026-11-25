class_name FrontEnd
extends Control

var app: Node
var mode: StringName
var canvas: Control
var heading: Font = preload("res://ui/fonts/BarlowCondensed-BlackItalic.ttf")
var bold: Font = preload("res://ui/fonts/BarlowCondensed-Bold.ttf")
var body: Font = preload("res://ui/fonts/Barlow-SemiBold.ttf")
var clock: float = 0.0
var axis_times: Dictionary = {}
var portraits: Array[TextureRect] = []
var message: String = ""
var selection_options: Array[Button] = []
var setup_fields: Dictionary = {}
var arena_choices: Array[Button] = []

func setup(owner_app: Node, page: StringName, page_message: String = "") -> void:
	app = owner_app
	mode = page
	message = page_message
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.size = Vector2(1920, 1080)
	add_child(canvas)
	resized.connect(_layout)
	_layout()
	match mode:
		&"title": _title()
		&"select": _select()
		&"network": _network()
		&"arena": _arena()
		&"pause": _pause()
		&"results": _results()
		&"settings": _settings()
		&"controls": _controls()
		&"credits": _credits()
	set_process_input(true)

func _layout() -> void:
	if canvas:
		var fit: float = minf(size.x / 1920.0, size.y / 1080.0)
		canvas.scale = Vector2.ONE * fit
		canvas.position = (size - Vector2(1920, 1080) * fit) * 0.5
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	for i in range(portraits.size()):
		portraits[i].position.y = float(portraits[i].get_meta("base_y")) + sin(clock * 1.4 + i * 0.9) * 4.0
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(1920, 1080))
	if mode == &"pause":
		draw_rect(Rect2(0, 0, 1920, 1080), Color(0.025, 0.045, 0.09, 0.91))
	else:
		draw_rect(Rect2(0, 0, 1920, 1080), Color("101d31"))
		draw_colored_polygon(PackedVector2Array([Vector2(900, 0), Vector2(1920, 0), Vector2(1920, 1080), Vector2(555, 1080)]), Color("192d45"))
		for i in range(26):
			var x: float = i * 95 + fmod(clock * 9.0, 95.0)
			draw_line(Vector2(x, 0), Vector2(x - 460, 1080), Color("20364d"), 1.0, true)
		draw_circle(Vector2(1500, 430), 540, Color("1b344f"))
		draw_arc(Vector2(1500, 430), 510, 0, TAU, 120, Color("2c4b62"), 2, true)
		draw_arc(Vector2(1500, 430), 480, clock * 0.04, clock * 0.04 + 4.4, 100, Color("315770"), 3, true)
	draw_rect(Rect2(0, 0, 1920, 9), Color("ffcf4d"))
	draw_rect(Rect2(0, 1012, 1920, 68), Color("0a1526"))
	_text("MECH", Vector2(72, 1055), 27, Color("b8d8e5"), bold)
	_text("★", Vector2(128, 1055), 23, Color("ffcf4d"), body)
	_text("POP", Vector2(154, 1055), 27, Color("b8d8e5"), bold)
	_text("SMALL MECHS. MASSIVE MAYHEM.", Vector2(252, 1055), 21, Color("7592aa"), body)
	_text("LOCAL + NETWORK  /  %s" % ProjectSettings.get_setting("application/config/version"), Vector2(1460, 1055), 22, Color("7896ad"), bold)

func _text(value: String, at: Vector2, font_size: int, color: Color, font: Font) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func label(value: String, at: Vector2, font_size: int = 28, tint: Color = Color.WHITE, width: float = 0, font: Font = null) -> Label:
	var node := Label.new()
	node.text = value
	node.position = at
	node.add_theme_font_override("font", font if font else body)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", tint)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if width > 0:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(node)
	if width > 0:
		node.size = Vector2(width, font_size * 1.5)
		node.set_deferred("size", Vector2(width, font_size * 1.5))
	return node

func panel(rect: Rect2, fill: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0 else 0)
	style.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", style)
	canvas.add_child(p)
	return p

func button(title: String, rect: Rect2, action: Callable, primary: bool = false, focus: bool = false) -> Button:
	var node := Button.new()
	node.text = title
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", bold)
	node.add_theme_font_size_override("font_size", 30)
	node.add_theme_color_override("font_color", Color("15253a") if primary else Color("e6f3fb"))
	node.add_theme_color_override("font_focus_color", Color("101d31"))
	node.add_theme_color_override("font_hover_color", Color("101d31"))
	var base := StyleBoxFlat.new()
	base.bg_color = Color("ffcf4d") if primary else Color("27405b")
	base.set_corner_radius_all(7)
	base.border_color = Color("ffdc74") if primary else Color("416080")
	base.set_border_width_all(1)
	node.add_theme_stylebox_override("normal", base)
	var active: StyleBoxFlat = base.duplicate()
	active.bg_color = Color("b9eff3")
	active.border_color = Color("efffff")
	active.set_border_width_all(3)
	for state in ["hover", "focus", "pressed"]:
		node.add_theme_stylebox_override(state, active)
	node.pressed.connect(action)
	node.pressed.connect(func() -> void: app.sound.ui_cue())
	node.focus_entered.connect(func() -> void: app.sound.ui_cue("ui_move"))
	canvas.add_child(node)
	if focus:
		node.grab_focus.call_deferred()
	return node

func portrait(id: StringName, rect: Rect2, tint: Color = Color.WHITE) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = Roster.portrait(id)
	picture.position = rect.position
	picture.size = rect.size
	picture.modulate = tint
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_meta("base_y", rect.position.y)
	canvas.add_child(picture)
	picture.set_deferred("size", rect.size)
	portraits.append(picture)
	return picture

func _selection_option(node: Button) -> Button:
	var index: int = selection_options.size()
	selection_options.append(node)
	node.focus_entered.connect(func() -> void:
		if app.selection_options_device >= 0: app.selection_options_index = index)
	return node

func _restore_selection_focus() -> void:
	if app.selection_options_device >= 0 and not selection_options.is_empty():
		selection_options[mini(app.selection_options_index, selection_options.size() - 1)].grab_focus.call_deferred()

func _selection_hint() -> String:
	if app.selection_options_device >= 0:
		return "Pad: move focus  ·  A choose  ·  B back to your mech"
	return "Pad: ←/→ mech  ·  ↓ options  ·  A ready  ·  Start play"

func _title() -> void:
	label("WELCOME TO THE SCRAP PARTY", Vector2(100, 104), 26, Color("80cee0"), 0, bold)
	label("MECH", Vector2(90, 151), 182, Color("f3f7fb"), 0, heading)
	label("★POP", Vector2(88, 301), 182, Color("ffcf4d"), 0, heading)
	label("Fight. Break. Steal. Rebuild.", Vector2(106, 534), 34)
	label("The mech you start with isn't the mech\nyou finish with.", Vector2(108, 597), 28, Color("a4bed3"))
	label("CHOOSE YOUR MECH", Vector2(790, 102), 35, Color("c8e6ef"), 0, bold)
	for index in range(Roster.IDS.size()):
		var mech: MechData = Roster.mech(Roster.IDS[index])
		var origin := Vector2(790 + (index % 4) * 270, 182 + floori(index / 4.0) * 264)
		panel(Rect2(origin, Vector2(252, 250)), Color("172b43"), Color(mech.energy, 0.45))
		portrait(mech.id, Rect2(origin + Vector2(31, 2), Vector2(190, 190)))
		label(mech.display_name, origin + Vector2(18, 185), 35, mech.energy, 0, bold)
		label(mech.role, origin + Vector2(19, 222), 18, Color("a4bed3"), 0, bold)
	button("PLAY  /  POP RUSH     →", Rect2(104, 694, 575, 70), app._select, true, true)
	button("PLAY WITH FRIENDS", Rect2(104, 778, 575, 57), app._network_menu)
	button("WATCH THE CHAOS", Rect2(104, 849, 350, 49), app._watch)
	button("HOW TO PLAY", Rect2(472, 849, 207, 49), func() -> void: app._page(&"controls"))
	button("SETTINGS", Rect2(104, 912, 186, 52), func() -> void: app._page(&"settings"))
	button("CREDITS", Rect2(304, 912, 184, 52), func() -> void: app._page(&"credits"))
	button("QUIT", Rect2(502, 912, 177, 52), app._quit_game)

func _entry(value: String, placeholder: String, rect: Rect2, changed: Callable) -> LineEdit:
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = placeholder
	field.position = rect.position
	field.size = rect.size
	field.add_theme_font_override("font", body)
	field.add_theme_font_size_override("font_size", 29)
	field.max_length = 253
	field.text_changed.connect(changed)
	canvas.add_child(field)
	return field

func _network() -> void:
	label("BRING YOUR SCRAP CREW", Vector2(72, 52), 76, Color.WHITE, 0, heading)
	var link: MatchLink = app.network
	label(link.status if not link.status.is_empty() else "Up to four fighters. Mac + iPad. Bots fill open slots.", Vector2(78, 151), 28, Color("a5c7dc"), 1720)
	if link.seats.size() != 4 and app.internet_mode:
		_internet_landing()
		return
	if link.seats.size() != 4:
		button("INTERNET ROOMS  →", Rect2(1350, 73, 490, 62), func() -> void: app._network_mode(true)).disabled = link.active
		panel(Rect2(76, 246, 853, 610), Color("172b43"))
		panel(Rect2(953, 246, 890, 610), Color("172b43"))
		label("HOST ON YOUR WI-FI", Vector2(111, 282), 48, Color("ffcf4d"), 0, heading)
		label("Open a room, then share your address\nand room code with your friends.", Vector2(114, 364), 27, Color("bfd5e3"))
		label("THIS DEVICE'S ADDRESS", Vector2(114, 467), 23, Color("7ebccc"), 0, bold)
		label(app.network_local_addresses(), Vector2(114, 510), 25, Color.WHITE, 755)
		button("OPEN ROOM  →", Rect2(113, 725, 777, 83), app._network_host, true, true).disabled = link.active
		label("JOIN A FRIEND", Vector2(989, 282), 48, Color("ffcf4d"), 0, heading)
		label("ROOM ADDRESS", Vector2(991, 377), 24, Color("9ac8dd"), 0, bold)
		_entry(app.network_address, "Host address or server name", Rect2(989, 420, 813, 65), func(value: String) -> void: app.network_address = value)
		label("ROOM CODE", Vector2(991, 509), 24, Color("9ac8dd"), 0, bold)
		_entry(app.network_code, "Code from your friend", Rect2(989, 550, 495, 65), func(value: String) -> void: app.network_code = value).max_length = 24
		label("PORT", Vector2(1524, 509), 24, Color("9ac8dd"), 0, bold)
		var port_field: LineEdit = _entry(str(app.network_port), "24872", Rect2(1522, 550, 280, 65), func(value: String) -> void: app.network_port = int(value))
		port_field.max_length = 5
		port_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		button("JOIN ROOM  →", Rect2(989, 725, 813, 83), app._network_join, true).disabled = link.active
		button("LOCAL PLAYERS: %d  /  REFRESH PADS" % app.network_devices.size(), Rect2(336, 906, 749, 66), app._network_local_inputs).disabled = link.active
		label("Press START on each extra controller before joining.", Vector2(1120, 925), 24, Color("8daec5"), 675)
	else:
		for slot in range(4):
			var seat: Dictionary = link.seats[slot]
			var x: float = 72 + slot * 452
			var tint: Color = Roster.PLAYER_COLORS[slot]
			var local: bool = link.owns(slot)
			panel(Rect2(x, 247, 420, 517), Color("172b43"), tint.darkened(0.28))
			var owner: String = "BOT" if seat.peer == 0 else ("YOU" if local else "FRIEND")
			label("P%d  /  %s" % [slot + 1, owner], Vector2(x + 25, 266), 28, tint, 0, bold)
			var state: String = "READY" if seat.ready else "CHOOSING"
			if not seat.connected: state = "RECONNECTING"
			label(state, Vector2(x + 228, 273), 20, Color("b9eaa9") if seat.ready else Color("d6b48e"))
			portrait(StringName(seat.character), Rect2(x + 4, 313, 412, 315))
			label(String(seat.character).to_upper(), Vector2(x + 25, 627), 57, Color.WHITE, 0, heading)
			label(app.device_label(slot) if local else ("ARCADE BOT" if seat.peer == 0 else seat.name), Vector2(x + 29, 706), 22, Color("98bfd3"), 350)
			if link.can_choose(slot):
				button("‹", Rect2(x, 788, 80, 55), func() -> void: app._cycle(slot, -1)).focus_mode = Control.FOCUS_CLICK
				button("›", Rect2(x + 340, 788, 80, 55), func() -> void: app._cycle(slot, 1)).focus_mode = Control.FOCUS_CLICK
		label(_selection_hint(), Vector2(78, 197), 22, Color("88a9be"))
		if app.internet_mode:
			label("PRIVATE ROOM  %s   /   Share this code with your friends" % link.room_code, Vector2(76, 878), 25, Color("8dc8db"), 1570)
		elif link.authority:
			label("ADDRESS  %s    /    CODE  %s" % [app.network_local_addresses(), link.room_code], Vector2(76, 878), 25, Color("8dc8db"), 1570)
		var all_ready: bool = true
		for slot in link.own_slots(): all_ready = all_ready and bool(link.seats[slot].ready)
		var ready := button("UNREADY" if all_ready else "READY UP", Rect2(336, 932, 429, 63), app._network_ready, not all_ready)
		if link.can_manage_room():
			_selection_option(button("ARENA: " + StageCatalog.stage(link.selected_stage).display_name, Rect2(790, 932, 516, 63), app._arena_menu))
			_selection_option(button("LAUNCH MATCH  →", Rect2(1340, 923, 505, 74), app._start_match, true, app.selection_options_device < 0))
		else: label("%s  /  The room leader launches the match." % StageCatalog.stage(link.selected_stage).display_name, Vector2(820, 948), 26, Color("b6d2e1"), 1020)
		_selection_option(ready)
	_selection_option(button("LEAVE ROOM" if link.active else "BACK", Rect2(72, 932, 241, 63), app._title))
	_restore_selection_focus()

func _internet_landing() -> void:
	var busy: bool = app.internet_rooms.busy or app.network.active
	button("LOCAL WI-FI  →", Rect2(1350, 73, 490, 62), func() -> void: app._network_mode(false)).disabled = busy
	panel(Rect2(76, 242, 1767, 167), Color("172b43"))
	label("ROOM SERVER", Vector2(111, 269), 23, Color("82c4d8"), 0, bold)
	_entry(app.internet_rooms.server_url, "https://your-room-server", Rect2(111, 314, 1694, 65), func(value: String) -> void: app.internet_rooms.server_url = value).editable = not busy
	panel(Rect2(76, 438, 853, 417), Color("172b43"))
	panel(Rect2(953, 438, 890, 417), Color("172b43"))
	label("START YOUR SCRAP PARTY", Vector2(111, 475), 43, Color("ffcf4d"), 0, heading)
	label("Create a private room and share its code.\nThe first player chooses the arena and launches.", Vector2(113, 552), 27, Color("bfd5e3"), 750)
	button("CREATE PRIVATE ROOM  →", Rect2(113, 726, 777, 82), func() -> void: app._internet_open(true), true, true).disabled = busy
	label("JOIN YOUR FRIENDS", Vector2(989, 475), 43, Color("ffcf4d"), 0, heading)
	label("Use the same room server as your friend.", Vector2(991, 552), 27, Color("bfd5e3"), 790)
	_entry(app.network_code, "ABC234", Rect2(989, 615, 813, 65), func(value: String) -> void: app.network_code = value).max_length = 6
	button("JOIN PRIVATE ROOM  →", Rect2(989, 726, 813, 82), func() -> void: app._internet_open(false), true).disabled = busy
	button("LOCAL PLAYERS: %d  /  REFRESH PADS" % app.network_devices.size(), Rect2(336, 922, 749, 66), app._network_local_inputs).disabled = busy
	label("Bots fill open slots. A room holds four fighters.", Vector2(1120, 939), 25, Color("8daec5"), 675)
	button("CANCEL" if busy else "BACK", Rect2(72, 932, 241, 63), app._title)

func _select() -> void:
	label("CHOOSE YOUR CHAOS", Vector2(72, 52), 76, Color("f6f9ff"), 0, heading)
	label(_setup_hint(), Vector2(78, 151), 27, Color("a5c7dc"), 1770)
	label("START: JOIN  /  READY  /  LAUNCH", Vector2(1307, 87), 26, Color("ffcf4d"), 0, bold)
	for slot in range(4):
		var x: float = 72 + slot * 452
		var id: StringName = app.selections[slot]
		var data: MechData = Roster.mech(id)
		var device: int = app.router.devices[slot]
		var color: Color = Roster.PLAYER_COLORS[slot]
		panel(Rect2(x, 218, 420, 580), Color("172b43"), color.darkened(0.28))
		panel(Rect2(x + 12, 230, 396, 50), color.darkened(0.75))
		label("P%d  /  %s" % [slot + 1, "PAD" if device >= 0 else app.device_label(slot)], Vector2(x + 28, 235), 28, color, 0, bold)
		if device != PlayerInputRouter.BOT:
			label("READY" if app.ready_slots[slot] else "SELECTING", Vector2(x + 267, 243), 19, Color("b9eaa9") if app.ready_slots[slot] else Color("97b4c8"))
		portrait(id, Rect2(x + 3, 275, 414, 348))
		label(String(id).to_upper(), Vector2(x + 30, 596), 57, Color.WHITE, 0, heading)
		label("%s / %s" % [data.role, Roster.part(data.native_weapon).short_name], Vector2(x + 29, 670), 21, color, 368, bold)
		label(data.description, Vector2(x + 29, 711), 21, Color("a6bed1"), 368)
		var field := button("", Rect2(x, 218, 420, 580), func() -> void: _setup_mouse_field(slot))
		var outline := StyleBoxFlat.new()
		outline.bg_color = Color.TRANSPARENT
		outline.set_corner_radius_all(12)
		outline.border_color = Color("ffcf4d") if _setup_editing(slot) else Color("b9eff3")
		outline.set_border_width_all(5)
		var invisible := StyleBoxEmpty.new()
		field.add_theme_stylebox_override("normal", outline if _setup_editing(slot) else invisible)
		for state in ["focus", "hover", "pressed"]: field.add_theme_stylebox_override(state, outline)
		_setup_field(slot, field)
		button("‹", Rect2(x, 818, 63, 52), func() -> void: app._cycle(slot, -1)).focus_mode = Control.FOCUS_CLICK
		button("›", Rect2(x + 357, 818, 63, 52), func() -> void: app._cycle(slot, 1)).focus_mode = Control.FOCUS_CLICK
		var input_field := button("INPUT: " + app.device_label(slot), Rect2(x + 76, 818, 269, 52), func() -> void: _setup_mouse_field(slot + 8))
		input_field.add_theme_font_size_override("font_size", 26)
		_setup_field(slot + 8, input_field)
	label("8 CHASSIS  /  16 SWAPPABLE PARTS", Vector2(76, 905), 22, Color("8aabbf"), 0, bold)
	_setup_field(4, button("ARENA: " + StageCatalog.stage(app.selected_stage).display_name, Rect2(760, 896, 539, 57), app._arena_menu))
	_setup_field(5, button(("‹ BOTS: %s ›" if _setup_editing(5) else "BOTS: %s") % ["CASUAL", "ARCADE", "ACE"][app.difficulty], Rect2(259, 948, 265, 48), app._cycle_difficulty, _setup_editing(5)))
	_setup_field(6, button("BACK", Rect2(72, 948, 170, 48), app._title))
	_setup_field(7, button("LAUNCH MATCH  →", Rect2(1340, 923, 505, 74), app._launch_requested, true))
	label("A / CROSS: EDIT     B / CIRCLE: BACK", Vector2(579, 967), 21, Color("88a9be"))
	var state: Dictionary = app.setup_state(app.setup_device)
	if state.editing and int(state.field) >= 8:
		_input_picker()
	else:
		setup_fields[int(state.field)].grab_focus.call_deferred()

func _input_picker() -> void:
	for node in canvas.find_children("*", "Button", true, false): node.focus_mode = Control.FOCUS_NONE
	var state: Dictionary = app.setup_state(app.setup_device)
	var slot: int = int(state.field) - 8
	var options: Array[int] = app.setup_input_options()
	if not options.has(int(state.get("input_choice", PlayerInputRouter.BOT))): state.input_choice = PlayerInputRouter.BOT
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.09, 0.9)
	shade.size = canvas.size
	canvas.add_child(shade)
	panel(Rect2(440, 139, 1040, 796), Color("172b43"), Roster.PLAYER_COLORS[slot])
	label("PLAYER %d INPUT" % (slot + 1), Vector2(481, 167), 61, Roster.PLAYER_COLORS[slot], 0, heading)
	label("Stick / D-pad: choose   ·   A: assign   ·   B: cancel", Vector2(484, 247), 28, Color("bfd5e3"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(480, 304)
	scroll.size = Vector2(960, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	canvas.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for device in options:
		var title: String = app.input_label(device)
		var owner: int = app.router.devices.find(device) if device != PlayerInputRouter.BOT else -1
		if owner >= 0: title += "   /   PLAYER %d" % (owner + 1)
		if device >= 0 and Input.get_connected_joypads().has(device): title += "   ·   " + Input.get_joy_name(device)
		var option := button(title, Rect2(0, 0, 940, 58), func() -> void: app.setup_assign_input(slot, device), device == app.router.devices[slot])
		option.reparent(list)
		option.custom_minimum_size.y = 58
		option.add_theme_font_size_override("font_size", 28)
		option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		option.focus_entered.connect(func() -> void: state.input_choice = device)
		if device == int(state.input_choice):
			option.grab_focus.call_deferred()
			scroll.ensure_control_visible.call_deferred(option)
	label("Moving an input here makes its previous player a bot.", Vector2(484, 786), 25, Color("a5c7dc"), 945)
	button("CANCEL", Rect2(480, 845, 960, 55), func() -> void:
		state.editing = false
		app.setup_notice = ""
		app._select(false))

func _arena() -> void:
	label("PICK YOUR PLAYGROUND", Vector2(72, 52), 76, Color.WHITE, 0, heading)
	var selected: StringName = app.network.selected_stage if app.network.active else app.selected_stage
	for index in range(StageCatalog.IDS.size()):
		var id: StringName = StageCatalog.IDS[index]
		var arena: StageData = StageCatalog.stage(id)
		var x: float = 73 + (index % 4) * 448
		var y: float = 175 + floorf(float(index) / 4.0) * 354
		panel(Rect2(x, y, 429, 335), Color("172b43"), arena.accent if id == selected else Color("34506b"))
		if ResourceLoader.exists(arena.matte):
			var thumbnail := TextureRect.new()
			thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			thumbnail.texture = load(arena.matte)
			thumbnail.position = Vector2(x + 10, y + 10)
			thumbnail.size = Vector2(409, 139)
			thumbnail.clip_contents = true
			thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			canvas.add_child(thumbnail)
			thumbnail.set_deferred("size", Vector2(409, 139))
		label(arena.display_name, Vector2(x + 16, y + 151), 37, Color.WHITE, 401, heading)
		label(arena.description, Vector2(x + 17, y + 202), 22, Color("afcadd"), 396)
		arena_choices.append(button("SELECTED" if id == selected else "PLAY HERE  →", Rect2(x + 12, y + 271, 405, 53), func() -> void: app._choose_stage(id), id == selected, id == selected))
	arena_choices.append(button("BACK", Rect2(74, 924, 266, 67), func() -> void: app._show(&"network" if app.network.active else &"select")))
	label("STICK / D-PAD: CHOOSE ARENA     A / CROSS: SELECT     B / CIRCLE: BACK", Vector2(405, 946), 25, Color("a5c7dc"))

func _pause() -> void:
	label(message if not message.is_empty() else "TAKE A BREATHER", Vector2(480, 167), 73, Color("ffcf4d"), 950, heading)
	label("THE MATCH KEEPS GOING WHILE THIS MENU IS OPEN." if app.network.active else "THE SCRAP WILL STILL BE HERE.", Vector2(485, 272), 29, Color("9acddd"), 0, bold)
	button("RESUME", Rect2(480, 363, 950, 82), app._resume, true, true)
	if not app.network.active:
		button("RUN IT BACK", Rect2(480, 465, 462, 72), app._start_match)
		button("CHANGE MECHS", Rect2(962, 465, 468, 72), app._select)
	button("SETTINGS", Rect2(480, 557, 462, 72), func() -> void: app._page(&"settings"))
	button("HOW TO PLAY", Rect2(962, 557, 468, 72), func() -> void: app._page(&"controls"))
	button("MAIN MENU", Rect2(480, 649, 950, 65), app._title)
	if app.disconnected_slot >= 0:
		var slot: int = app.disconnected_slot
		button("LET BOT TAKE OVER PLAYER %d" % (slot + 1), Rect2(480, 739, 950, 62), app._bot_takeover)
		label("Reconnect the same pad, or press START on its replacement.", Vector2(480, 825), 27, Color("abc8d9"))
	else:
		label("Crack a coupler. Land a breaker. Claim the part with Salvage.", Vector2(482, 775), 28, Color("bdd2e3"))

func _results() -> void:
	var winners: Array[int] = app.session.winners()
	var winner: Fighter = app.session.fighters[winners[0]]
	label("THAT'S A WRAP!", Vector2(75, 69), 28, Color("84cada"), 0, bold)
	label("%s WINS" % winner.data.display_name if winners.size() == 1 else "SHARED VICTORY", Vector2(70, 110), 112, Color("ffcf4d"), 0, heading)
	label("POP RUSH  /  %s  /  FINAL SCORE" % app.session.stage.definition.display_name, Vector2(77, 264), 28, Color("b5d2e1"), 0, bold)
	portrait(winner.data.id, Rect2(1130, 283, 740, 740))
	var ranking: Array[Fighter] = app.session.fighters.duplicate()
	ranking.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.score > b.score if a.score != b.score else a.damage_done > b.damage_done)
	for i in range(ranking.size()):
		var fighter: Fighter = ranking[i]
		var y: float = 345 + i * 113
		var tint: Color = Roster.PLAYER_COLORS[fighter.slot]
		panel(Rect2(76, y, 1030, 96), Color("1b334c"), tint.darkened(0.6))
		label("%02d" % (i + 1), Vector2(100, y + 18), 40, tint, 0, bold)
		label("P%d  %s" % [fighter.slot + 1, fighter.data.display_name], Vector2(193, y + 13), 37, Color.WHITE, 0, bold)
		label("%d CORE POPS    %d STEALS" % [fighter.pops, fighter.steals], Vector2(193, y + 59), 18, Color("93b1c7"))
		label("%+d" % fighter.score, Vector2(967, y + 16), 45, tint, 0, bold)
		var arm: PartInstance = fighter.part(&"weapon_arm")
		var shell: PartInstance = fighter.part(&"shell")
		label("%s / %s" % [arm.definition.short_name if arm else "BARE ARM", shell.definition.short_name if shell else "EXPOSED"], Vector2(625, y + 33), 23, Color("c5dee9"), 0, bold)
	if app.network.active:
		button("BACK TO ROOM  →", Rect2(76, 856, 789, 88), app._network_menu, true, true)
	else:
		button("RUN IT BACK  →", Rect2(76, 856, 500, 88), app._start_match, true, true)
		button("CHANGE MECHS", Rect2(596, 856, 269, 88), app._select)
	button("MAIN MENU", Rect2(885, 856, 221, 88), app._title)
	label("WINNING CHASSIS", Vector2(1373, 321), 25, Color("81a7be"), 0, bold)

func _settings() -> void:
	label("MAKE IT YOURS", Vector2(73, 58), 83, Color("ffcf4d"), 0, heading)
	label("AUDIO & DISPLAY", Vector2(78, 188), 30, Color("8dcee1"), 0, bold)
	var controls: Array[Dictionary] = [
		{"name": "MASTER", "value": app.sound.master_volume, "property": &"master_volume"},
		{"name": "MUSIC", "value": app.sound.music_volume, "property": &"music_volume"},
		{"name": "SOUND EFFECTS", "value": app.sound.sfx_volume, "property": &"sfx_volume"},
		{"name": "MENU SOUNDS", "value": app.sound.ui_volume, "property": &"ui_volume"},
		{"name": "RUMBLE", "value": app.sound.rumble, "property": &"rumble"}]
	for i in range(controls.size()):
		var entry: Dictionary = controls[i]
		var y: float = 264 + i * 76
		label(entry.name, Vector2(83, y), 27, Color("cce0ed"), 0, bold)
		var slider := HSlider.new()
		slider.position = Vector2(340, y + 9)
		slider.size = Vector2(440, 30)
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = entry.value
		var percent: Label = label("%d%%" % roundi(entry.value * 100), Vector2(808, y), 26, Color("ffcf4d"), 0, bold)
		slider.value_changed.connect(func(value: float) -> void:
			app.sound.set(entry.property, value)
			app.sound.apply_volumes()
			percent.text = "%d%%" % roundi(value * 100)
			app._save_settings())
		canvas.add_child(slider)
	label("SCREEN SHAKE", Vector2(83, 653), 27, Color("cce0ed"), 0, bold)
	button("%s" % ["OFF", "REDUCED", "FULL"][app.shake_setting], Rect2(340, 646, 510, 53), app._cycle_shake)
	if app.router.touch_enabled:
		label("LANDSCAPE  /  TOUCH + CONTROLLERS", Vector2(83, 748), 27, Color("8dcee1"), 0, bold)
	else:
		button("FULLSCREEN / WINDOW", Rect2(80, 737, 770, 61), app._toggle_fullscreen)
	label("INPUT", Vector2(1055, 188), 30, Color("8dcee1"), 0, bold)
	label("STICK DEAD ZONE", Vector2(1060, 268), 27, Color("cce0ed"), 0, bold)
	button("%d%%   ›" % roundi(app.router.deadzone * 100), Rect2(1430, 258, 370, 59), app._cycle_deadzone)
	if app.router.touch_enabled:
		button("TOUCH CONTROLS GUIDE", Rect2(1060, 369, 740, 75), func() -> void: app._page(&"controls"))
	else:
		button("REMAP KEYBOARD", Rect2(1060, 369, 740, 75), func() -> void: app._begin_remap(false))
	button("REMAP CONTROLLER", Rect2(1060, 464, 740, 75), func() -> void: app._begin_remap(true))
	button("RESTORE DEFAULT CONTROLS", Rect2(1060, 571, 740, 62), app._reset_bindings)
	label("Remapping guides you through every action.\nUse Cancel to leave. Bindings save on this device.\n\nController labels use physical button positions:\nsouth = jump, west = light, north = breaker, east = special.", Vector2(1064, 684), 25, Color("8daec5"), 740)
	button("DONE", Rect2(78, 894, 430, 79), app._back, true, true)

func _controls() -> void:
	label("FIVE STEPS TO MAYHEM", Vector2(74, 57), 79, Color("ffcf4d"), 0, heading)
	var steps: Array[Array] = [["01", "FIGHT", "Lights wear down couplers.\nDirection + breaker changes your attack."], ["02", "BREAK", "Yellow means cracked.\nA breaker can POP that part off."], ["03", "STEAL", "Get close to a loose yellow part.\nSalvage claims and equips it."], ["04", "REBUILD", "Your new weapon changes Special.\nYour chassis keeps its own basics."], ["05", "POP", "Strip the shell. Finish the Core.\nScore +1. Everyone respawns."]]
	for i in range(5):
		var x: float = 77 + i * 357
		panel(Rect2(x, 197, 337, 259), Color("1a334c"))
		label(steps[i][0], Vector2(x + 24, 213), 28, Color("688fa8"), 0, bold)
		label(steps[i][1], Vector2(x + 23, 251), 52, Color("fcdf77"), 0, heading)
		label(steps[i][2], Vector2(x + 24, 333), 21, Color("bbd5e5"), 291)
	label("TOUCH" if app.router.touch_enabled else "KEYBOARD", Vector2(91, 493), 32, Color("7dcce1"), 0, bold)
	label("CONTROLLER", Vector2(981, 493), 32, Color("7dcce1"), 0, bold)
	var actions: Array[StringName] = [&"jump", &"light", &"heavy", &"special", &"dodge", &"salvage"]
	var names: Array[String] = ["JUMP / DOUBLE JUMP", "LIGHT ATTACK", "BREAKER + DIRECTION", "WEAPON SPECIAL", "DODGE / AIR BOOST", "SALVAGE / SWAP"]
	var pad_names: Array[String] = ["SOUTH", "WEST", "NORTH", "EAST", "LEFT SHOULDER", "RIGHT SHOULDER"]
	var movement_prompt: String = "LEFT THUMB STICK  /  MOVE + AIM" if app.router.touch_enabled else "%s %s %s %s  /  MOVE" % [OS.get_keycode_string(app.router.keyboard_bindings[&"up"]), OS.get_keycode_string(app.router.keyboard_bindings[&"left"]), OS.get_keycode_string(app.router.keyboard_bindings[&"down"]), OS.get_keycode_string(app.router.keyboard_bindings[&"right"])]
	label(movement_prompt, Vector2(94, 551), 26)
	label("LEFT STICK / D-PAD  /  MOVE", Vector2(984, 551), 26)
	for i in range(actions.size()):
		var y: float = 596 + i * 39
		label(TouchControls.TITLES[actions[i]] if app.router.touch_enabled else OS.get_keycode_string(app.router.keyboard_bindings[actions[i]]), Vector2(94, y), 24, Color("ffcf4d"), 0, bold)
		label(names[i], Vector2(291, y), 24, Color("c2d8e7"), 0, bold)
		label(app.pad_button_label(app.router.gamepad_bindings[actions[i]]), Vector2(984, y), 23, Color("ffcf4d"), 0, bold)
		label(names[i], Vector2(1286, y), 24, Color("c2d8e7"), 0, bold)
	label("Tap jump for a short hop. Down + jump drops through. Falling off costs 1 point. Most points in 3 minutes wins.", Vector2(93, 865), 25, Color("90b4ca"))
	button("GOT IT", Rect2(78, 929, 424, 65), app._back, true, true)

func _credits() -> void:
	label("BUILT FOR A LITTLE MAYHEM", Vector2(74, 62), 80, Color("ffcf4d"), 0, heading)
	label("MECH★POP  /  THE SCRAP CREW EXPANSION", Vector2(80, 207), 36, Color.WHITE, 0, bold)
	label("An original game developed with Codex.\nCharacter design, combat, modular equipment, 3D models, interface and effects\ncreated for this project from the supplied MECH★POP concept direction.", Vector2(85, 285), 30, Color("aecbdc"), 1690)
	label("MADE WITH OPEN TOOLS", Vector2(80, 437), 33, Color("89d2e4"), 0, bold)
	label("Godot Engine 4.7.2  /  MIT license\nBlender 4.5 LTS  /  original models and attachment rigs\nSuperCollider 3.14.1  /  original synthesized sound effects\nFFmpeg & NumPy  /  audio finishing and verification\nBarlow typefaces by Jeremy Tribby  /  SIL Open Font License 1.1", Vector2(85, 498), 28, Color("b4cedf"))
	label("GENERATED ART & MUSIC", Vector2(1048, 435), 33, Color("89d2e4"), 0, bold)
	label("Eight arena mattes and the Nova reference use ImageGen.\nThree instrumental scores rendered with YuE2-3B by M-A-P.\nOriginal arena music generated with MiniMax Music 3.\nBuilt with MiniMax-Music3.\n\nPrompts, source files and license notices accompany the project.\nThe MiniMax Music 3 community license has additional\ncommercial conditions; see the included license inventory.", Vector2(1054, 498), 25, Color("b4cedf"), 770)
	label("Thank you for playing. Now go steal something ridiculous.", Vector2(85, 806), 33, Color("e8f1f8"))
	button("BACK TO THE HANGAR", Rect2(78, 918, 614, 73), app._back, true, true)

func _input(event: InputEvent) -> void:
	if mode == &"select" and event is InputEventKey:
		var state: Dictionary = app.setup_state(app.setup_device)
		if state.editing and int(state.field) >= 8:
			if event.pressed and event.physical_keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				state.editing = false
				app._select(false)
			return
	if mode == &"select" and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		_setup_input(event)
		return
	if mode == &"arena" and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		app._show(&"network" if app.network.active else &"select")
		return
	if mode != &"select" and not (mode == &"network" and app.network.seats.size() == 4): return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var owned_slot: int = app.router.devices.find(event.device)
		if owned_slot >= 0 and _selection_options_input(event): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_A, KEY_D]:
			var keyboard_slot: int = app.router.devices.find(PlayerInputRouter.KEYBOARD)
			if keyboard_slot >= 0: app._cycle(keyboard_slot, -1 if event.physical_keycode == KEY_A else 1)
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var slot: int = app.router.devices.find(event.device)
		if slot < 0: return
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: app._cycle(slot, -1)
			JOY_BUTTON_DPAD_RIGHT: app._cycle(slot, 1)
			JOY_BUTTON_A: app._toggle_ready(slot)
			JOY_BUTTON_START: app.setup_start(event.device)
			JOY_BUTTON_B:
				if not app.network.active:
					app.router.devices[slot] = PlayerInputRouter.BOT
					app.ready_slots[slot] = true
					app._select(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var slot: int = app.router.devices.find(event.device)
		if slot < 0: return
		if event.axis == JOY_AXIS_LEFT_X and absf(event.axis_value) > 0.65:
			var now: int = Time.get_ticks_msec()
			if now - int(app.selection_repeat.get(event.device, 0)) > 260:
				app.selection_repeat[event.device] = now
				app._cycle(slot, signi(int(event.axis_value * 100)))
		get_viewport().set_input_as_handled()

func _selection_options_input(event: InputEvent) -> bool:
	if app.selection_options_device == event.device:
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_B:
				get_viewport().set_input_as_handled()
				app.selection_options_device = -1
				app._show(mode)
			elif event.button_index == JOY_BUTTON_START:
				get_viewport().set_input_as_handled()
				app.setup_start(event.device)
			elif event.button_index == JOY_BUTTON_A and not selection_options.has(get_viewport().gui_get_focus_owner()):
				# A mouse/keyboard focus change must not let this pad alter a
				# different player's card when returning to controller input.
				get_viewport().set_input_as_handled()
				_restore_selection_focus()
		# Let Godot navigate and activate the common menu buttons. Card
		# buttons accept mouse/touch focus but are excluded from this path.
		return true
	var enter_options: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_DOWN
	if event is InputEventJoypadMotion:
		enter_options = event.axis == JOY_AXIS_LEFT_Y and event.axis_value > 0.65
	if enter_options:
		get_viewport().set_input_as_handled()
		app.selection_options_device = event.device
		app.selection_options_index = 0
		app._show(mode)
		return true
	return false

func _setup_field(index: int, node: Button) -> void:
	setup_fields[index] = node
	node.focus_entered.connect(func() -> void:
		var state: Dictionary = app.setup_state(app.setup_device)
		if not state.editing: state.field = index)

func _setup_editing(index: int) -> bool:
	var state: Dictionary = app.setup_state(app.setup_device)
	return state.editing and int(state.field) == index

func _setup_hint() -> String:
	if not app.setup_notice.is_empty(): return app.setup_notice
	var state: Dictionary = app.setup_state(app.setup_device)
	if state.editing:
		if int(state.field) < 4:
			return "EDIT P%d  ·  ←/→ mech  ·  A done  ·  B back  ·  Use INPUT below to choose a bot or controller" % (int(state.field) + 1)
		if int(state.field) >= 8: return "Choose how this player is controlled."
		return "BOT DIFFICULTY  ·  ←/→ change  ·  A done  ·  B back"
	return "Stick / D-pad: choose any field  ·  A edit  ·  B back  ·  Start join / ready / launch"

func _setup_mouse_field(index: int) -> void:
	app.setup_device = -1
	var state: Dictionary = app.setup_state(-1)
	state.field = index
	state.editing = true
	if index >= 8: state.input_choice = app.router.devices[index - 8]
	app.setup_notice = ""
	app._select(false)

func _setup_input(event: InputEvent) -> void:
	# Consume both edges before the gameplay router: one Start press must
	# perform exactly one of joining, readying or launching, never two.
	get_viewport().set_input_as_handled()
	var device: int = event.device
	var state: Dictionary = app.setup_state(device)
	var changed_device: bool = app.setup_device != device
	if event is InputEventJoypadButton and not event.pressed: return
	var direction: Vector2i = _setup_direction(event)
	if event is InputEventJoypadMotion and direction == Vector2i.ZERO: return
	app.setup_device = device
	if state.editing and int(state.field) >= 8:
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
			app.setup_assign_input(int(state.field) - 8, int(state.input_choice))
		elif event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B:
			state.editing = false
			app.setup_notice = ""
			app._select(false)
		elif direction != Vector2i.ZERO:
			var options: Array[int] = app.setup_input_options()
			var step: int = direction.x if direction.x != 0 else direction.y
			state.input_choice = options[posmod(options.find(int(state.input_choice)) + step, options.size())]
			app._select(false)
		elif changed_device: app._select(false)
		return
	if event is InputEventJoypadButton:
		match event.button_index:
			JOY_BUTTON_START:
				app.setup_start(device)
				return
			JOY_BUTTON_A:
				_setup_activate(device)
				return
			JOY_BUTTON_B:
				if state.editing:
					state.editing = false
					app.setup_notice = ""
					app._select(false)
				else: app._title()
				return
	if direction == Vector2i.ZERO:
		if changed_device: app._select(false)
		return
	app.setup_notice = ""
	var field: int = int(state.field)
	if state.editing:
		if field < 4 and app.setup_can_edit(device, field):
			if direction.x != 0: app._cycle(field, direction.x)
		elif field == 5 and direction.x != 0: app._cycle_difficulty(direction.x)
		return
	var bottom: Array[int] = [6, 5, 4, 7]
	if field < 4:
		if direction.x != 0: state.field = posmod(field + direction.x, 4)
		elif direction.y > 0: state.field = field + 8
	elif field >= 8:
		var column: int = field - 8
		state.field = 8 + posmod(column + direction.x, 4) if direction.x != 0 else (column if direction.y < 0 else bottom[column])
	else:
		var column: int = bottom.find(field)
		if direction.x != 0: state.field = bottom[posmod(column + direction.x, 4)]
		elif direction.y < 0: state.field = column + 8
	app._select(false)

func _setup_direction(event: InputEvent) -> Vector2i:
	if event is InputEventJoypadButton:
		return {JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT, JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT, JOY_BUTTON_DPAD_UP: Vector2i.UP, JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN}.get(event.button_index, Vector2i.ZERO)
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var key: String = "%s:%s" % [event.device, event.axis]
		if absf(event.axis_value) < 0.35:
			app.selection_repeat.erase(key)
		elif absf(event.axis_value) > 0.65:
			var now: int = Time.get_ticks_msec()
			if now - int(app.selection_repeat.get(key, -1000)) > 230:
				app.selection_repeat[key] = now
				return Vector2i(signi(int(event.axis_value * 100)), 0) if event.axis == JOY_AXIS_LEFT_X else Vector2i(0, signi(int(event.axis_value * 100)))
	return Vector2i.ZERO

func _setup_activate(device: int) -> void:
	var state: Dictionary = app.setup_state(device)
	app.setup_notice = ""
	if state.editing:
		state.editing = false
		app._select(false)
		return
	var field: int = int(state.field)
	if field < 4:
		if app.setup_can_edit(device, field): state.editing = true
		else: app.setup_notice = "PLAYER %d CONTROLS THIS CHARACTER" % (field + 1)
		app._select(false)
	elif field == 4: app._arena_menu()
	elif field == 5:
		state.editing = true
		app._select(false)
	elif field == 6: app._title()
	elif field == 7: app.setup_start(device)
	elif field >= 8:
		state.editing = true
		state.input_choice = app.router.devices[field - 8]
		app._select(false)
