class_name MatchWire
extends RefCounted

const VERSION: int = 2
const MAX_PARTS: int = 32
const MAX_PROJECTILES: int = 24
const FLOATS: Array[String] = ["facing", "core", "attack_time", "hitstop", "stun", "invulnerable", "dodge_time", "dodge_cooldown", "special_cooldown", "coyote", "drop_time", "hover_left", "jump_buffer", "action_buffer_time", "respawn_time", "attach_time", "credit_time", "combo_window", "snared", "repair_budget", "damage_done"]
const INTS: Array[String] = ["attack_serial", "jumps_left", "reserved_part", "last_attacker", "combo_hits", "score", "pops", "steals", "parts_broken", "assists"]
const BOOLS: Array[String] = ["attack_emitted", "attack_is_special", "attack_confirmed", "attack_motion_applied", "air_boost_left"]
const STATES: Array[StringName] = [&"idle", &"air", &"run", &"dodge", &"attack", &"hurt", &"attach", &"ko"]
static var attacks: Dictionary = {}

static func prepare() -> void:
	attacks.clear()
	for id in Roster.IDS:
		var mech: MechData = Roster.mech(id)
		for move in [mech.light, mech.heavy, mech.uppercut, mech.slam, mech.ranged_heavy, mech.support_heavy]:
			if move: attacks[String(move.id)] = move
	for id in Roster.all_modules():
		var module: ModuleData = Roster.part(id)
		for move in [module.attack, module.up_attack, module.down_attack]:
			if move: attacks[String(move.id)] = move

static func capture(session: MatchSession) -> Dictionary:
	var fighters: Array = []
	for fighter in session.fighters:
		var state: Dictionary = {"slot": fighter.slot, "mech": String(fighter.data.id), "position": fighter.position, "previous_position": fighter.previous_position, "velocity": fighter.velocity, "buffered_direction": fighter.buffered_direction, "state": String(fighter.state), "action_buffer": String(fighter.action_buffer), "attack": String(fighter.attack.id) if fighter.attack else "", "grounded": fighter.grounded(), "attack_hits": fighter.attack_hits.duplicate(), "contributors": fighter.contributors.duplicate()}
		for property in FLOATS + INTS + BOOLS: state[property] = fighter.get(property)
		fighters.append(state)
	var parts: Array = []
	var ids: Array = session.parts.instances.keys()
	ids.sort()
	for uid in ids:
		var item: PartInstance = session.parts.instances[uid]
		var state: Dictionary = {"uid": uid, "definition": String(item.definition.id), "original_owner": item.original_owner, "carrier": item.carrier, "condition": item.condition, "state": String(item.state), "drop_reason": String(item.drop_reason), "fresh_coupler": item.fresh_coupler, "claimed_by": item.claimed_by, "recalled": item.recalled}
		if is_instance_valid(item.entity):
			var body: SalvageBody = item.entity
			state.body = {"position": body.position, "velocity": body.velocity, "lifetime": body.lifetime, "age": body.age, "spin": body.spin, "settled": body.settled}
		parts.append(state)
	var projectiles: Array = []
	for projectile in session.projectiles:
		var state: Dictionary = projectile.duplicate()
		state.source = projectile.source.slot
		state.attack = String(projectile.attack.id)
		state.type = String(projectile.type)
		state.hits = projectile.hits.duplicate()
		projectiles.append(state)
	return {"version": VERSION, "tick": session.tick, "elapsed": session.elapsed, "duration": session.duration, "remaining": session.remaining, "countdown": session.countdown, "phase": String(session.phase), "paused": session.paused, "final_warning_sent": session.final_warning_sent, "stage_id": String(session.stage.definition.id), "stage_elapsed": session.stage.elapsed, "ferry_offset": session.stage.ferry_offset, "moving_enabled": session.stage.moving_enabled, "next_part_uid": session.parts.next_uid, "tie_turn": session.parts.tie_turn, "projectile_serial": session.projectile_serial, "events": session.event_counts.duplicate(), "fighters": fighters, "parts": parts, "projectiles": projectiles}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) < 1.0e9

static func vector(value: Variant) -> bool:
	return value is Vector2 and value.is_finite() and value.length_squared() < 1.0e12

static func slot_map(value: Variant, count: int) -> bool:
	if not value is Dictionary or value.size() > count: return false
	for key in value:
		if not key is int or key < 0 or key >= count: return false
		if not (value[key] is bool or number(value[key])): return false
	return true

static func valid(state: Dictionary, count: int = 4) -> bool:
	if count not in [2, 4]: return false
	if state.get("version") != VERSION: return false
	if attacks.is_empty(): prepare()
	for key in ["tick", "next_part_uid", "tie_turn", "projectile_serial"]:
		if not state.get(key) is int or state[key] < 0 or state[key] > 2147483647: return false
	if not StageCatalog.IDS.has(StringName(str(state.get("stage_id", "")))) or not vector(state.get("ferry_offset")): return false
	for key in ["elapsed", "duration", "remaining", "countdown", "stage_elapsed"]:
		if not number(state.get(key)): return false
	for key in ["paused", "final_warning_sent", "moving_enabled"]:
		if not state.get(key) is bool: return false
	if state.get("phase") not in ["intro", "fight", "results"]: return false
	if not state.get("events") is Dictionary or state.events.size() > 96: return false
	for key in state.events:
		if not (key is String or key is StringName) or String(key).length() > 48 or not state.events[key] is int or state.events[key] < 0: return false
	if not state.get("fighters") is Array or state.fighters.size() != count: return false
	if not state.get("parts") is Array or state.parts.size() > MAX_PARTS: return false
	if not state.get("projectiles") is Array or state.projectiles.size() > MAX_PROJECTILES: return false
	for i in range(count):
		var entry: Variant = state.fighters[i]
		if not entry is Dictionary or entry.get("slot") != i or not Roster.IDS.has(StringName(str(entry.get("mech", "")))): return false
		for key in FLOATS:
			if not number(entry.get(key)): return false
		for key in INTS:
			if not entry.get(key) is int or absi(entry[key]) > 2147483647: return false
		for key in BOOLS + ["grounded"]:
			if not entry.get(key) is bool: return false
		for key in ["position", "previous_position", "velocity", "buffered_direction"]:
			if not vector(entry.get(key)): return false
		if StringName(str(entry.get("state"))) not in STATES: return false
		if entry.get("action_buffer") not in ["", "light", "heavy", "special"]: return false
		if not entry.get("attack") is String or (entry.attack != "" and not attacks.has(entry.attack)): return false
		if not slot_map(entry.get("attack_hits"), count) or not slot_map(entry.get("contributors"), count): return false
	var uids: Dictionary = {}
	var owners: Dictionary = {}
	var claims: Dictionary = {}
	for entry in state.parts:
		if not entry is Dictionary: return false
		var uid: Variant = entry.get("uid")
		if not uid is int or uid < 1 or uid >= state.next_part_uid or uids.has(uid): return false
		uids[uid] = true
		if not Roster.all_modules().has(StringName(str(entry.get("definition", "")))): return false
		for key in ["carrier", "original_owner", "claimed_by"]:
			if not entry.get(key) is int or entry[key] < -1 or entry[key] >= count: return false
		if entry.original_owner < 0: return false
		if not number(entry.get("condition")) or entry.condition < 0.0: return false
		for key in ["fresh_coupler", "recalled"]:
			if not entry.get(key) is bool: return false
		if entry.get("drop_reason") not in ["", "break", "swap", "ko"]: return false
		if entry.get("state") == "equipped":
			if entry.carrier < 0 or entry.claimed_by != -1 or entry.has("body"): return false
			var owner_key: String = "%d:%s" % [entry.carrier, Roster.part(StringName(entry.definition)).slot]
			if owners.has(owner_key): return false
			owners[owner_key] = true
		elif entry.get("state") in ["loose", "claimed"]:
			if entry.carrier != -1 or not entry.get("body") is Dictionary: return false
			if (entry.state == "claimed") != (entry.claimed_by >= 0): return false
			if entry.claimed_by >= 0:
				if claims.has(entry.claimed_by) or state.fighters[entry.claimed_by].reserved_part != uid: return false
				claims[entry.claimed_by] = uid
			for key in ["position", "velocity"]:
				if not vector(entry.body.get(key)): return false
			for key in ["lifetime", "age", "spin"]:
				if not number(entry.body.get(key)): return false
			if not entry.body.get("settled") is bool: return false
		else: return false
	for entry in state.fighters:
		if entry.reserved_part >= 0 and claims.get(entry.slot, -1) != entry.reserved_part: return false
	uids.clear()
	for entry in state.projectiles:
		if not entry is Dictionary or not entry.get("uid") is int or entry.uid < 1 or uids.has(entry.uid): return false
		uids[entry.uid] = true
		if not entry.get("source") is int or entry.source < 0 or entry.source >= count: return false
		if not attacks.has(entry.get("attack")) or entry.get("type") not in ["cannon", "snare", "repair", "field", "rail"]: return false
		for key in ["position", "previous", "velocity"]:
			if not vector(entry.get(key)): return false
		for key in ["remaining", "age", "facing"]:
			if not number(entry.get(key)): return false
		if not entry.get("pulsed") is bool or not slot_map(entry.get("hits"), count): return false
	return true

static func restore(session: MatchSession, snapshot: Dictionary) -> bool:
	if not valid(snapshot, session.fighters.size()): return false
	if String(session.stage.definition.id) != snapshot.stage_id: return false
	for i in range(session.fighters.size()):
		if String(session.fighters[i].data.id) != snapshot.fighters[i].mech: return false
	for key in ["tick", "elapsed", "duration", "remaining", "countdown", "paused", "final_warning_sent", "projectile_serial"]:
		session.set(key, snapshot[key])
	session.phase = StringName(snapshot.phase)
	session.event_counts = snapshot.events.duplicate()
	session.stage.elapsed = snapshot.stage_elapsed
	session.stage.moving_enabled = snapshot.moving_enabled
	session.stage.set_motion(snapshot.ferry_offset)
	session.parts.next_uid = snapshot.next_part_uid
	session.parts.tie_turn = snapshot.tie_turn
	for i in range(session.fighters.size()):
		var fighter: Fighter = session.fighters[i]
		var entry: Dictionary = snapshot.fighters[i]
		for property in FLOATS + INTS + BOOLS + ["position", "previous_position", "velocity", "buffered_direction"]:
			fighter.set(property, entry[property])
		fighter.network_grounded = entry.grounded
		fighter.state = StringName(entry.state)
		fighter.action_buffer = StringName(entry.action_buffer)
		fighter.attack = attacks.get(entry.attack)
		fighter.attack_hits = entry.attack_hits.duplicate()
		fighter.contributors = entry.contributors.duplicate()
		fighter.equipment.clear()
	var seen: Dictionary = {}
	session.parts.loose.clear()
	for entry in snapshot.parts:
		var item: PartInstance = session.parts.instances.get(entry.uid)
		if item == null:
			item = PartInstance.new()
			item.uid = entry.uid
			session.parts.instances[item.uid] = item
		seen[item.uid] = true
		item.definition = Roster.part(StringName(entry.definition))
		for property in ["original_owner", "carrier", "condition", "fresh_coupler", "claimed_by", "recalled"]:
			item.set(property, entry[property])
		item.state = StringName(entry.state)
		item.drop_reason = StringName(entry.drop_reason)
		if entry.has("body"):
			if not is_instance_valid(item.entity):
				var body := SalvageBody.new()
				body.part = item
				item.entity = body
				session.add_child(body)
			for property in ["position", "velocity", "lifetime", "age", "spin", "settled"]:
				item.entity.set(property, entry.body[property])
			session.parts.loose.append(item.entity)
		else:
			if is_instance_valid(item.entity): item.entity.queue_free()
			item.entity = null
			session.fighters[item.carrier].equipment[item.definition.slot] = item
	for uid in session.parts.instances.keys():
		if not seen.has(uid): session.parts.retire(session.parts.instances[uid])
	session.projectiles.clear()
	for entry in snapshot.projectiles:
		var projectile: Dictionary = entry.duplicate()
		projectile.source = session.fighters[entry.source]
		projectile.attack = attacks[entry.attack]
		projectile.type = StringName(entry.type)
		projectile.hits = entry.hits.duplicate()
		session.projectiles.append(projectile)
	return true

static func digest(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot, "", true).sha256_text()

static func event_to_wire(kind: StringName, payload: Dictionary) -> Dictionary:
	var encoded: Dictionary = {}
	var event := {"kind": String(kind), "payload": encoded}
	for key in payload:
		# Older peers validate every payload field but ignore optional envelope metadata.
		if kind == &"core_pop" and key == "ring_out":
			event["ring_out"] = payload[key]
			continue
		var value: Variant = payload[key]
		if value is Fighter: encoded[key] = {"fighter": value.slot}
		elif value is AttackData: encoded[key] = {"attack": String(value.id)}
		elif value is PartInstance: encoded[key] = {"part": value.uid, "definition": String(value.definition.id)}
		elif value is Vector2 or value is bool or value is int or value is float or value is String or value is StringName or value is Array:
			encoded[key] = value
	return event

static func event_from_wire(session: MatchSession, event: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	if event.kind == "core_pop" and event.has("ring_out"):
		payload["ring_out"] = event.ring_out
	for key in event.get("payload", {}):
		var value: Variant = event.payload[key]
		if value is Dictionary:
			if value.has("fighter") and value.fighter is int and value.fighter >= 0 and value.fighter < session.fighters.size():
				payload[key] = session.fighters[value.fighter]
			elif value.has("attack") and attacks.has(value.attack): payload[key] = attacks[value.attack]
			elif value.has("part") and value.has("definition") and Roster.all_modules().has(StringName(str(value.definition))):
				var part: PartInstance = session.parts.instances.get(value.part)
				if part == null:
					part = PartInstance.new()
					part.uid = value.part
					part.definition = Roster.part(StringName(value.definition))
				payload[key] = part
		else: payload[key] = value
	return payload

static func valid_event(event: Dictionary, count: int = 4) -> bool:
	var required: Dictionary = {
		"hit": ["fighter", "source", "attack", "position", "armored"],
		"part_pop": ["fighter", "part", "position"],
		"core_pop": ["fighter", "credited", "position"],
		"snap": ["fighter", "part", "stolen"],
		"attack_active": ["fighter", "attack", "special"],
		"attack_start": ["fighter", "attack", "special"],
		"jump": ["fighter", "air"], "dodge": ["fighter"], "land": ["fighter"],
		"repair": ["fighter", "amount"], "go": [], "final_thirty": [],
		"match_end": ["winners"], "part_loose": ["part"], "attach_start": ["fighter", "part"],
		"recall": ["part", "position"], "respawn": ["fighter"], "cannon_recoil": ["fighter"],
		"phase_shift": ["fighter", "origin", "position"]
	}
	if not required.has(event.get("kind")) or not event.get("payload") is Dictionary or event.payload.size() > 12: return false
	if event.has("ring_out") and (event.kind != "core_pop" or not event.ring_out is bool): return false
	for key in required[event.kind]:
		if not event.payload.has(key): return false
	for key in event.payload:
		var value: Variant = event.payload[key]
		match String(key):
			"fighter", "source":
				if not value is Dictionary or not value.get("fighter") is int or value.fighter < 0 or value.fighter >= count: return false
			"attack":
				if not value is Dictionary or not attacks.has(value.get("attack")): return false
			"part":
				if not value is Dictionary or not value.get("part") is int or value.part < 1 or not Roster.all_modules().has(StringName(str(value.get("definition", "")))): return false
			"position", "origin":
				if not vector(value): return false
			"armored", "shielded", "stolen", "special", "air":
				if not value is bool: return false
			"credited":
				if not value is int or value < -1 or value >= count: return false
			"amount":
				if not number(value): return false
			"winners":
				if not value is Array or value.size() > count: return false
				for slot in value:
					if not slot is int or slot < 0 or slot >= count: return false
			_: return false
	return true
