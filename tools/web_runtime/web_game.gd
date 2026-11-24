extends Node

const WebInput := preload("res://web_input.gd")
var page: JavaScriptObject
var callback: JavaScriptObject
var router: PlayerInputRouter
var link: MatchLink
var session: MatchSession
var events: Array[Dictionary] = []

func _ready() -> void:
	page = JavaScriptBridge.get_interface("MechBridge")
	router = WebInput.new()
	router.page = page
	add_child(router)
	link = MatchLink.new()
	# The RPC path matches the one used by the native room authority.
	link.name = "MatchLink"
	link.router = router
	add_child(link)
	link.lobby_changed.connect(_lobby)
	link.status_changed.connect(func(_message: String) -> void: _lobby())
	link.start_match_requested.connect(func(config: Dictionary, _replica: bool) -> void: _begin(config))
	callback = JavaScriptBridge.create_callback(_receive)
	if page: page.ready(callback, link.content_fingerprint(), MatchLink.PROTOCOL)

func _receive(args: Array) -> void:
	if args.size() != 1: return
	var message: Variant = JSON.parse_string(str(args[0]))
	if not message is Dictionary: return
	match message.get("action", ""):
		"local":
			link.close()
			for i in range(4):
				router.devices[i] = int(message.devices[i])
			_begin(message)
		"leave":
			link.close()
			_clear_match()
			router.clear_state()
		"pause":
			if link.active: link.suspended_local = bool(message.value)
			elif session: session.paused = bool(message.value)
			router.clear_state()
		"connect":
			_clear_match()
			var devices: Array[int] = []
			for value in message.devices:
				if int(value) != PlayerInputRouter.BOT: devices.append(int(value))
			if devices.is_empty(): devices.append(PlayerInputRouter.KEYBOARD)
			link.join(str(message.url), MatchLink.DEFAULT_PORT, devices, str(message.code))
		"ready": link.set_ready(bool(message.value))
		"character": link.choose_character(int(message.slot), StringName(message.value))
		"stage": link.choose_stage(StringName(message.value))
		"launch": link.launch_room()

func _clear_match() -> void:
	if session:
		link.detach_match()
		session.simulation_enabled = false
		remove_child(session)
		session.queue_free()
		session = null
	events.clear()

func _begin(config: Dictionary) -> void:
	_clear_match()
	var roster: Array[StringName] = []
	for id in config.characters:
		roster.append(StringName(id) if Roster.IDS.has(StringName(id)) else &"nova")
	if roster.size() != 4: return
	router.clear_state()
	session = MatchSession.new()
	add_child(session)
	session.setup(router, roster, config)
	session.combat_event.connect(_event)
	if link.active: link.bind_match(session)
	page.started(JSON.stringify({"stage": config.stage, "characters": config.characters, "online": link.active}))

func _lobby() -> void:
	if not page: return
	page.lobby(JSON.stringify({"active": link.active, "mode": link.mode, "status": link.status, "seats": link.seats, "own": link.own_slots() if link.active else [], "leader": link.can_manage_room() if link.active else false, "stage": link.selected_stage, "code": link.room_code}))

func _event(kind: StringName, data: Dictionary) -> void:
	var event := {"kind": String(kind)}
	for key in ["fighter", "source"]:
		if data.get(key) is Fighter: event[key] = data[key].slot
	if data.get("attack") is AttackData:
		event["cue"] = String(data.attack.feedback)
		event["breaker"] = data.attack.breaker
		event["attackId"] = String(data.attack.id)
		event["special"] = bool(data.get("special", false))
		if kind == &"attack_active" and data.get("fighter") is Fighter:
			var area: Rect2 = data.attack.hit_rect(data.fighter.position, data.fighter.facing)
			event["hitX"] = area.get_center().x
			event["hitY"] = area.get_center().y
			event["hitW"] = area.size.x
			event["hitH"] = area.size.y
	if data.get("part") is PartInstance: event["part"] = String(data.part.definition.id)
	if data.has("stolen"): event["stolen"] = data.stolen
	if data.get("fighter") is Fighter: event["facing"] = data.fighter.facing
	if kind == &"phase_shift":
		event["fromX"] = data.origin.x
		event["fromY"] = data.origin.y
	var where: Vector2 = data.get("position", Vector2.ZERO)
	if not data.has("position") and data.get("fighter") is Fighter: where = data.fighter.position + Vector2(0, -90)
	event["x"] = where.x
	event["y"] = where.y
	events.append(event)

func _part(fighter: Fighter, slot: StringName) -> Array:
	var item := fighter.part(slot)
	return [String(item.definition.id), snappedf(item.condition, 0.1)] if item else ["", 0]

func _process(delta: float) -> void:
	if not session or not page: return
	var frames: Array = []
	for f in session.fighters:
		var point: Vector2 = f.visual_position(delta) if link.active else f.previous_position.lerp(f.position, Engine.get_physics_interpolation_fraction())
		var move_time := 0.0
		if f.attack: move_time = clampf(f.attack_time / f.attack.total_time(), 0.0, 1.0)
		var device: int = router.devices[f.slot]
		var nearby := ""
		if device not in [PlayerInputRouter.BOT, PlayerInputRouter.REMOTE] and f.alive() and not f.attack and f.reserved_part < 0 and f.stun <= 0.0 and f.dodge_time <= 0.0:
			var salvage: SalvageBody = session.parts.nearest(f)
			if salvage: nearby = String(salvage.part.definition.id)
		frames.append({
			"id": f.data.id, "device": device, "nearby": nearby,
			"moveId": String(f.attack.id) if f.attack else "", "serial": f.attack_serial,
			"x": snappedf(point.x, 0.1), "y": snappedf(point.y, 0.1),
			"vx": snappedf(f.velocity.x, 1), "facing": f.facing, "state": f.state,
			"grounded": f.grounded(), "attack": move_time, "hurt": minf(1.0, f.stun * 4.0),
			"dead": not f.alive(), "safe": f.invulnerable > 0.0, "core": snappedf(f.core, 0.1),
			"weapon": _part(f, &"weapon_arm"), "shell": _part(f, &"shell"),
			"score": f.score, "steals": f.steals, "breaks": f.parts_broken, "pops": f.pops,
			"special": snappedf(f.special_cooldown, 0.1),
		})
	var loose: Array = []
	for item in session.parts.instances.values():
		if item.state in [&"loose", &"claimed"] and is_instance_valid(item.entity):
			loose.append([item.uid, item.definition.id, snappedf(item.entity.position.x, 0.1), snappedf(item.entity.position.y, 0.1), item.entity.age, item.entity.settled])
	var shots: Array = []
	for shot in session.projectiles:
		shots.append([shot.uid, shot.type, shot.position.x, shot.position.y, shot.facing, shot.source.slot, shot.age, String(shot.attack.id)])
	var offset := session.stage.ferry_offset
	var frame := {
		"fighters": frames, "parts": loose, "shots": shots, "ferry": [offset.x, offset.y],
		"phase": session.phase, "time": session.elapsed, "remaining": session.remaining,
		"countdown": session.countdown, "paused": session.paused, "events": events,
		"winners": session.winners() if session.phase == &"results" else [],
	}
	page.frame(JSON.stringify(frame))
	events.clear()
