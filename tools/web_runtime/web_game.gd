extends Node

const CannonDuel := preload("res://scripts/combat/cannon_duel.gd")
const WebFriends := preload("res://web_friends.gd")
const WebInput := preload("res://web_input.gd")
var page: JavaScriptObject
var callback: JavaScriptObject
var router: PlayerInputRouter
var link: MatchLink
var friends: WebFriends
var preferred_mech: StringName
var session: MatchSession
var session_online: bool = false
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
	friends = WebFriends.new()
	friends.link = link
	add_child(friends)
	friends.failed.connect(func(message: String) -> void:
		link.close()
		_clear_match()
		page.friendError(message))
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
			friends.stop()
			link.close()
			for i in range(4):
				router.devices[i] = int(message.devices[i])
			_begin(message)
		"leave":
			friends.stop()
			link.close()
			_clear_match()
			router.clear_state()
		"pause":
			if link.active: link.suspended_local = bool(message.value)
			elif session: session.paused = bool(message.value)
			router.clear_state()
		"friend":
			_clear_match()
			link.close()
			preferred_mech = StringName(message.character)
			friends.start(bool(message.host), str(message.code), int(message.device), preferred_mech, StringName(message.stage))
		"connect":
			friends.stop()
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
	session_online = false
	events.clear()

func _begin(config: Dictionary) -> void:
	_clear_match()
	var roster: Array[StringName] = []
	for id in config.characters:
		roster.append(StringName(id) if Roster.IDS.has(StringName(id)) else &"nova")
	var duel: bool = not link.active and config.get("mode", "") == "cannon_duel"
	if duel:
		roster = [&"nova", &"terra"]
		config = config.merged({"stage": "skyport", "duration": 90.0}, true)
	elif roster.size() != (2 if link.friend_duel else 4): return
	router.clear_state()
	session = CannonDuel.new() if duel else MatchSession.new()
	add_child(session)
	session_online = link.active
	session.setup(router, roster, config)
	session.combat_event.connect(_event)
	if link.active: link.bind_match(session)
	page.started(JSON.stringify({"stage": config.stage, "characters": roster, "online": link.active, "duel": duel, "contested": duel and session.contested, "pickupTrial": session.pickup_trial if duel else "", "friend": link.friend_duel, "duration": session.duration, "devices": router.devices.slice(0, roster.size())}))

func _lobby() -> void:
	if not page: return
	if link.friend_duel and not link.authority and preferred_mech != &"" and link.own_slots().size() == 1:
		var chosen := preferred_mech
		preferred_mech = &""
		if link.seats[link.own_slots()[0]].character != String(chosen): link.choose_character(link.own_slots()[0], chosen)
	page.lobby(JSON.stringify({"active": link.active, "mode": link.mode, "status": link.status, "seats": link.seats, "own": link.own_slots() if link.active else [], "leader": link.can_manage_room() if link.active else false, "stage": link.selected_stage, "code": link.room_code, "friend": link.friend_duel, "setWins": link.set_wins}))

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
	if data.get("part") is PartInstance:
		event["part"] = String(data.part.definition.id)
		event["partUid"] = data.part.uid
	for key in ["armored", "shielded"]:
		if data.has(key): event[key] = data[key]
	if data.has("stolen"): event["stolen"] = data.stolen
	if data.get("fighter") is Fighter: event["facing"] = data.fighter.facing
	if kind == &"phase_shift":
		event["fromX"] = data.origin.x
		event["fromY"] = data.origin.y
	if kind == &"core_pop":
		event["credited"] = data.credited
		# Pre-duel room servers sent the KO position but no explicit cause.
		event["ringOut"] = data.ring_out if data.has("ring_out") else session.stage.is_outside(data.position + Vector2(0, 100))
	var where: Vector2 = data.get("position", Vector2.ZERO)
	if not data.has("position") and data.get("fighter") is Fighter: where = data.fighter.position + Vector2(0, -90)
	event["x"] = where.x
	event["y"] = where.y
	events.append(event)

func _part(fighter: Fighter, slot: StringName) -> Array:
	var item := fighter.part(slot)
	return [String(item.definition.id), snappedf(item.condition, 0.1)] if item else ["", 0]

func _process(delta: float) -> void:
	if not session or not page or (session_online and not link.active): return
	if link.friend_duel and not link.authority and session.phase == &"results" and link.last_reported_round != link.round_number: return
	var frames: Array = []
	for f in session.fighters:
		var point: Vector2 = f.visual_position(delta) if link.active else f.previous_position.lerp(f.position, Engine.get_physics_interpolation_fraction())
		var move_time := 0.0
		if f.attack: move_time = clampf(f.attack_time / f.attack.total_time(), 0.0, 1.0)
		var device: int = router.devices[f.slot]
		var nearby := ""
		var nearby_uid := -1
		if device not in [PlayerInputRouter.BOT, PlayerInputRouter.REMOTE] and f.alive() and not f.attack and f.reserved_part < 0 and f.stun <= 0.0 and f.dodge_time <= 0.0:
			var salvage: SalvageBody = session.parts.nearest(f)
			if salvage:
				nearby = String(salvage.part.definition.id)
				nearby_uid = salvage.part.uid
		frames.append({
			"id": f.data.id, "device": device, "nearby": nearby, "nearbyUid": nearby_uid,
			"moveId": String(f.attack.id) if f.attack else "", "serial": f.attack_serial,
			"x": snappedf(point.x, 0.1), "y": snappedf(point.y, 0.1),
			"vx": snappedf(f.velocity.x, 1), "vy": snappedf(f.velocity.y, 1), "facing": f.facing, "state": f.state,
			"cancelReady": f.data.id == &"kuren" and f.attack != null and f.attack_confirmed and f.can_dodge(),
			"hoverLeft": f.hover_left, "claimUid": f.reserved_part,
			"claimProgress": clampf(1.0 - f.attach_time / EquipmentStore.CLAIM_TIME, 0.0, 1.0) if f.reserved_part >= 0 else 0.0,
			"grounded": f.grounded(), "attack": move_time, "hurt": minf(1.0, f.stun * 4.0),
			"dead": not f.alive(), "safe": f.invulnerable > 0.0, "core": snappedf(f.core, 0.1),
			"weapon": _part(f, &"weapon_arm"), "shell": _part(f, &"shell"),
			"score": f.score, "steals": f.steals, "breaks": f.parts_broken, "pops": f.pops,
			"special": f.special_cooldown, "damage": f.damage_done,
		})
	var loose: Array = []
	for item in session.parts.instances.values():
		if item.state in [&"loose", &"claimed"] and is_instance_valid(item.entity):
			loose.append([item.uid, item.definition.id, snappedf(item.entity.position.x, 0.1), snappedf(item.entity.position.y, 0.1), item.entity.age, item.entity.settled, item.claimed_by])
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
	if link.friend_duel: frame["setWins"] = link.set_wins
	if session is CannonDuel:
		frame["duelStep"] = session.objective
		frame["duelReason"] = session.ended_reason
		frame["reclaims"] = session.reclaims
		frame["pickupTrial"] = session.pickup_trial
		frame["otherPickups"] = session.other_pickups
		if not session.pickup_trial.is_empty() and session.completed_at >= 0.0:
			frame["cannonHitAt"] = session.completed_at
	page.frame(JSON.stringify(frame))
	events.clear()
