class_name EquipmentStore
extends Node

const MAX_LOOSE: int = 8
const PICKUP_RANGE: float = 150.0
var aimed_salvage: bool = false
var session: Node
var instances: Dictionary = {}
var loose: Array[SalvageBody] = []
var next_uid: int = 1
var tie_turn: int = 0

func create_native(fighter: Fighter) -> void:
	for id in [fighter.data.native_weapon, fighter.data.native_shell]:
		var item := PartInstance.new()
		item.uid = next_uid
		next_uid += 1
		item.definition = Roster.part(id)
		item.condition = item.definition.maximum
		item.original_owner = fighter.slot
		item.carrier = fighter.slot
		instances[item.uid] = item
		fighter.equipment[item.definition.slot] = item

func break_part(fighter: Fighter, slot_name: StringName, impulse: Vector2) -> PartInstance:
	var item: PartInstance = fighter.part(slot_name)
	if item == null:
		return null
	item.condition = 0.0
	item.fresh_coupler = true
	_drop(fighter, item, impulse, &"break")
	fighter.hitstop = maxf(fighter.hitstop, 0.105)
	session.broadcast(&"part_pop", {"fighter": fighter, "part": item, "position": item.entity.position})
	return item

func _drop(fighter: Fighter, item: PartInstance, impulse: Vector2, reason: StringName) -> void:
	fighter.equipment.erase(item.definition.slot)
	item.carrier = -1
	item.claimed_by = -1
	item.state = &"loose"
	item.drop_reason = reason
	var body := SalvageBody.new()
	body.part = item
	body.position = fighter.position + Vector2(fighter.facing * 45.0, -fighter.data.height * 0.57)
	body.velocity = impulse
	item.entity = body
	session.add_child(body)
	loose.append(body)
	while loose.size() > MAX_LOOSE:
		var candidate: SalvageBody = null
		for entry in loose:
			if entry.part.state == &"loose":
				candidate = entry
				break
		if candidate == null:
			break
		retire(candidate.part)
	session.broadcast(&"part_loose", {"part": item})

func nearest(fighter: Fighter) -> SalvageBody:
	var closest: SalvageBody = null
	var best_cost: float = INF
	var origin := fighter.position + Vector2(0.0, -fighter.data.height * 0.35)
	var aim := Vector2.ZERO
	if aimed_salvage and fighter.last_command.move.length_squared() >= 0.25:
		aim = fighter.last_command.move.normalized()
	for body in loose:
		if body.part.state != &"loose" or body.age < 0.15: continue
		var offset := body.position - origin
		var distance := offset.length()
		if distance >= PICKUP_RANGE: continue
		# A neutral stick keeps nearest-part selection. A deliberate aim favors
		# the reachable item in that direction; physical reach never changes.
		var cost := distance - PICKUP_RANGE * maxf(0.0, aim.dot(offset.normalized()))
		if cost < best_cost:
			best_cost = cost
			closest = body
	return closest

func resolve_requests(requesters: Array[Fighter]) -> void:
	# Collect bids first. Equal-distance contests rotate priority by slot.
	var bids: Array[Dictionary] = []
	for fighter in requesters:
		if not fighter.alive() or fighter.stun > 0.0 or fighter.reserved_part >= 0 or fighter.attack != null or fighter.dodge_time > 0.0:
			continue
		var body: SalvageBody = nearest(fighter)
		if body:
			bids.append({"fighter": fighter, "body": body, "distance": (fighter.position + Vector2(0, -fighter.data.height * 0.35)).distance_squared_to(body.position), "tie": (fighter.slot - tie_turn + 4) % 4})
	bids.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if absf(float(a.distance) - float(b.distance)) < 0.01:
			return int(a.tie) < int(b.tie)
		return float(a.distance) < float(b.distance))
	for bid in bids:
		var body: SalvageBody = bid.body
		var fighter: Fighter = bid.fighter
		if body.part.state != &"loose":
			continue
		body.part.state = &"claimed"
		body.part.claimed_by = fighter.slot
		fighter.reserved_part = body.part.uid
		fighter.attach_time = 0.18
		fighter.invulnerable = 0.0
		tie_turn = (fighter.slot + 1) % 4
		session.broadcast(&"attach_start", {"fighter": fighter, "part": body.part})

func cancel_claim(fighter: Fighter) -> void:
	var item: PartInstance = instances.get(fighter.reserved_part)
	if item and item.state == &"claimed" and item.claimed_by == fighter.slot:
		item.state = &"loose"
		item.claimed_by = -1
		if is_instance_valid(item.entity):
			item.entity.velocity = Vector2(0, -180)
	fighter.reserved_part = -1
	fighter.attach_time = 0.0

func commit_claim(fighter: Fighter) -> void:
	var item: PartInstance = instances.get(fighter.reserved_part)
	if item == null or item.state != &"claimed" or item.claimed_by != fighter.slot or not fighter.alive():
		cancel_claim(fighter)
		return
	var old: PartInstance = fighter.part(item.definition.slot)
	if old:
		_drop(fighter, old, Vector2(-fighter.facing * 180.0, -300.0), &"swap")
	if item.fresh_coupler:
		item.condition = item.definition.maximum * 0.5
		item.fresh_coupler = false
	_remove_entity(item)
	item.state = &"equipped"
	item.carrier = fighter.slot
	item.claimed_by = -1
	fighter.equipment[item.definition.slot] = item
	fighter.reserved_part = -1
	fighter.attach_time = 0.0
	if item.original_owner != fighter.slot:
		fighter.steals += 1
	session.broadcast(&"snap", {"fighter": fighter, "part": item, "stolen": item.original_owner != fighter.slot})

func step(delta: float) -> void:
	for body in loose.duplicate():
		body.step(delta)
		if body.lifetime <= 0.0:
			if body.part.state == &"claimed":
				cancel_claim(session.fighters[body.part.claimed_by])
			retire(body.part)
		elif session.stage.is_outside(body.position):
			if not body.part.recalled:
				body.part.recalled = true
				body.position = session.stage.safe_salvage_point(body.position)
				body.velocity = Vector2(0, -220)
				session.broadcast(&"recall", {"part": body.part, "position": body.position})
			else:
				retire(body.part)

func release_on_ko(fighter: Fighter) -> void:
	cancel_claim(fighter)
	var weapon: PartInstance = fighter.part(&"weapon_arm")
	if weapon:
		_drop(fighter, weapon, Vector2(-fighter.facing * 320, -750), &"ko")
	var shell: PartInstance = fighter.part(&"shell")
	if shell:
		fighter.equipment.erase(&"shell")
		retire(shell)

func retire(item: PartInstance) -> void:
	_remove_entity(item)
	item.state = &"retired"
	item.carrier = -1
	item.claimed_by = -1
	instances.erase(item.uid)

func _remove_entity(item: PartInstance) -> void:
	if is_instance_valid(item.entity):
		loose.erase(item.entity)
		item.entity.queue_free()
	item.entity = null

func conservation_errors() -> Array[String]:
	var errors: Array[String] = []
	for uid in instances:
		var item: PartInstance = instances[uid]
		var owners: int = 0
		for fighter in session.fighters:
			if fighter.equipment.values().has(item):
				owners += 1
		var bodies: int = 0
		for body in loose:
			if body.part == item:
				bodies += 1
		if item.state == &"equipped" and (owners != 1 or bodies != 0 or item.carrier < 0):
			errors.append("Equipped part %d has %d carriers and %d bodies" % [uid, owners, bodies])
		elif item.state in [&"loose", &"claimed"] and (owners != 0 or bodies != 1 or item.carrier != -1):
			errors.append("Loose part %d has %d carriers and %d bodies" % [uid, owners, bodies])
	return errors
