class_name BotBrain
extends RefCounted

var rng := RandomNumberGenerator.new()
var difficulty: int = 1
var decision_time: float = 0.0
var attack_delay: float = 0.0
var jump_delay: float = 0.0
var dodge_delay: float = 0.0
var salvage_delay: float = 0.0
var last_steals: int = 0
var target_slot: int = -1
var intent: StringName = &"approach"
var held := FighterCommand.new()

func _init(seed_value: int = 1, level: int = 1) -> void:
	rng.seed = seed_value
	difficulty = level

func command(fighter: Fighter, session: Node, delta: float) -> FighterCommand:
	var result := FighterCommand.new()
	attack_delay -= delta
	jump_delay -= delta
	dodge_delay -= delta
	salvage_delay -= delta
	if fighter.steals != last_steals:
		last_steals = fighter.steals
		salvage_delay = 3.0
	decision_time -= delta
	if not fighter.alive():
		return result
	result.jump_held = fighter.velocity.y < -180.0
	var half_width: float = session.stage.definition.half_width()
	# Recovery takes priority over targets, including tempting offstage salvage.
	if absf(fighter.position.x) > half_width - 80.0 and not fighter.grounded():
		intent = &"recover"
		result.move.x = -signf(fighter.position.x)
		if fighter.velocity.y > -80.0 and jump_delay <= 0.0 and fighter.position.y > -180.0:
			result.jump_pressed = true
			result.jump_held = true
			jump_delay = 0.25
		if absf(fighter.position.x) > half_width + 270.0 and fighter.air_boost_left and fighter.position.y < 160.0:
			result.dodge = true
		return result
	if decision_time <= 0.0:
		decision_time = [0.28, 0.17, 0.10][difficulty]
		var best: float = INF
		for other in session.fighters:
			if other == fighter or not other.alive():
				continue
			var cost: float = fighter.position.distance_to(other.position)
			if other.slot == target_slot:
				cost *= 0.78
			if other.part(&"shell") == null:
				cost *= 0.86
			if cost < best:
				best = cost
				target_slot = other.slot
	if target_slot < 0:
		return result
	var enemy: Fighter = session.fighters[target_slot]
	var goal: Vector2 = enemy.position
	var collectible: SalvageBody = null
	var salvage_score: float = 450.0
	for body in session.parts.loose:
		if salvage_delay > 0.0 or body.part.state != &"loose" or absf(body.position.x) > half_width - 50.0 or body.position.y > 80.0:
			continue
		var distance: float = fighter.position.distance_to(body.position)
		var current: PartInstance = fighter.part(body.part.definition.slot)
		var potential: float = body.part.definition.maximum * 0.5 if body.part.fresh_coupler else body.part.condition
		if current == null:
			distance *= 0.45
		elif potential > current.condition + 7.0:
			distance *= 0.7
		else:
			continue
		if distance < salvage_score:
			salvage_score = distance
			collectible = body
	if collectible:
		intent = &"salvage"
		goal = collectible.position
		if session.parts.nearest(fighter) == collectible:
			result.salvage = true
	else:
		intent = &"pressure"
		# Keep an attack position on the deck instead of following a launched rival off the edge.
		goal.x = clampf(goal.x, -half_width + 210.0, half_width - 210.0)
	var difference: Vector2 = goal - fighter.position
	var reach: float = 120.0 if fighter.data.id != &"terra" else 125.0
	var equipped: PartInstance = fighter.part(&"weapon_arm")
	var preferred_distance: float = reach * 0.7
	if equipped and equipped.definition.action in [&"projectile", &"rail", &"field"]:
		preferred_distance = 310.0
		if equipped.definition.action == &"rail": preferred_distance = 540.0
		elif equipped.definition.action == &"field": preferred_distance = 240.0
	if fighter.data.id == &"momo":
		reach = 155.0
		preferred_distance = 135.0
	if absf(difference.x) > (35.0 if collectible else preferred_distance):
		result.move.x = signf(difference.x)
	elif not collectible and absf(difference.x) > 5.0:
		result.move.x = signf(difference.x) * 0.16
	if difference.y < -120.0 and jump_delay <= 0.0:
		if fighter.grounded() or (fighter.velocity.y > -120.0 and difference.y < -220.0):
			result.jump_pressed = true
			result.jump_held = true
			jump_delay = 0.4
	elif difference.y > 220.0 and fighter.grounded() and fighter.position.y < -200.0:
		result.move.y = 1.0
		result.jump_pressed = true
		jump_delay = 0.4
	if collectible:
		return result
	# Attack range uses the opponent, not the safe movement destination.
	difference = enemy.position - fighter.position
	if absf(difference.y) < 145.0 and absf(difference.x) < reach + 35.0 and attack_delay <= 0.0:
		var target_part: PartInstance = enemy.part(&"weapon_arm")
		var shell: PartInstance = enemy.part(&"shell")
		var roll: float = rng.randf()
		if shell and (target_part == null or roll < 0.32):
			result.move.y = 1.0
			result.heavy = true
		elif target_part and target_part.condition < 22.0:
			result.heavy = true
		elif roll < 0.32:
			result.heavy = true
		else:
			result.light = true
		attack_delay = [0.7, 0.40, 0.26][difficulty] + rng.randf_range(0.0, 0.18)
	var weapon: PartInstance = fighter.part(&"weapon_arm")
	if weapon and fighter.special_cooldown <= 0.0 and absf(difference.y) < 120.0 and fighter.attack == null:
		var use_special: bool = false
		match weapon.definition.action:
			&"projectile": use_special = absf(difference.x) > 200.0 and absf(difference.x) < 1150.0
			&"rail": use_special = absf(difference.x) > 300.0 and absf(difference.x) < 1450.0
			&"field": use_special = absf(difference.x) > 170.0 and absf(difference.x) < 580.0
			&"blink": use_special = absf(difference.x) > 245.0 and absf(difference.x) < 415.0
			&"repair": use_special = fighter.repair_budget > 0.0 and _needs_repair(fighter)
			&"rush": use_special = absf(difference.x) > 130.0 and absf(difference.x) < 430.0
			_: use_special = absf(difference.x) < 255.0 and attack_delay <= 0.05
		if use_special:
			result.special = true
			result.light = false
			result.heavy = false
			if weapon.definition.action == &"adaptive":
				result.move.y = -1.0 if difference.y < -65.0 else (1.0 if rng.randf() < 0.35 else 0.0)
	if fighter.data.id == &"zero" and fighter.attack == null and attack_delay <= 0.0 and absf(difference.y) < 110.0:
		if (fighter.adaptive_mode() == &"SCOPE" and absf(difference.x) > 180.0 and absf(difference.x) < 850.0) or (fighter.adaptive_mode() == &"SYNC" and _needs_repair(fighter) and fighter.repair_budget > 0.0):
			result.heavy = true
			result.special = false
			result.move.y = 0.0
			attack_delay = 0.9
	if difficulty > 0 and enemy.attack and enemy.attack.breaker and enemy.attack_time < enemy.attack.startup and absf(difference.x) < 230.0 and dodge_delay <= 0.0:
		if rng.randf() < (0.006 if difficulty == 1 else 0.014):
			result.move.x = -signf(difference.x)
			result.dodge = true
			dodge_delay = 1.3
	if fighter.grounded() and absf(fighter.position.x) > half_width - 135.0:
		result.move.x = -signf(fighter.position.x)
	return result

func _needs_repair(fighter: Fighter) -> bool:
	for item in fighter.equipment.values():
		if item.condition < item.definition.maximum - 10.0:
			return true
	return false
