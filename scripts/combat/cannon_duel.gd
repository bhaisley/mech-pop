extends MatchSession
## A two-fighter local exercise on Skyport's main deck.

var pickup_trial: String = ""
var other_pickups: int = 0
var objective: String = "break"
var cannon: PartInstance
var stole_cannon: bool = false
var next_jab: float = 3.5
var completed_at: float = -1.0
var ended_reason: String = ""
var contested: bool = false
var reclaims: int = 0
var contest_at: float = 0.0

func setup(router: PlayerInputRouter, selections: Array[StringName], config: Dictionary = {}) -> void:
	super.setup(router, selections, config)
	contested = bool(config.get("contested", false))
	pickup_trial = "" if contested else str(config.get("pickup_trial", ""))
	parts.aimed_salvage = pickup_trial == "aim"
	var nova := fighters[0]
	var terra := fighters[1]
	nova.reset_at(Vector2(-100, -3))
	terra.reset_at(Vector2(35 if contested else 85, -3))
	cannon = terra.part(&"weapon_arm")
	cannon.condition = 1.0
	command_source = _sparring_input
	combat_event.connect(_track_objective)
	tick_completed.connect(_check_attempt)

func _sparring_input(slot: int, _delta: float) -> FighterCommand:
	if slot == 0:
		return input_router.command_for(slot)
	var command := FighterCommand.new()
	var terra := fighters[1]
	var distance := fighters[0].position.x - terra.position.x
	if contested: return _contest_cannon(terra, distance)
	if objective == "break":
		# Give the trainee time to read the prompt, then spar at close range.
		if absf(distance) > 175.0 and absf(terra.position.x) < 850.0:
			command.move.x = signf(distance) * 0.40
		elif absf(distance) < 150.0 and elapsed >= next_jab:
			terra.facing = signf(distance) if absf(distance) > 1.0 else terra.facing
			command.light = true
			next_jab = elapsed + 3.5
	elif objective in ["take", "fire"]:
		# Step clear of the loose cannon and give the trainee a visible target.
		var mark := 700.0 if terra.position.x >= fighters[0].position.x else -700.0
		if absf(distance) < 340.0 and absf(mark - terra.position.x) > 35.0:
			command.move.x = signf(mark - terra.position.x) * 0.55
		else:
			terra.facing = signf(distance) if absf(distance) > 1.0 else terra.facing
	return command

func _contest_cannon(terra: Fighter, distance: float) -> FighterCommand:
	var command := FighterCommand.new()
	var nova := fighters[0]
	var loose := is_instance_valid(cannon.entity)
	var destination := cannon.entity.position if loose else nova.position
	var offset := destination - terra.position
	var reach := 52.0 if loose else 145.0
	if absf(offset.x) > reach and (absf(terra.position.x) < 1040.0 or signf(offset.x) != signf(terra.position.x)):
		command.move.x = signf(offset.x) * (0.86 if loose else 0.63)
	if elapsed < contest_at: return command
	if loose and offset.y < -210.0 and absf(offset.x) < 270.0:
		command.jump = terra.grounded()
		command.jump_held = true
	# Terra must win the same range check and interruptible claim as the player.
	if loose and parts.nearest(terra) == cannon.entity:
		command.salvage = true
	if not loose or nova.reserved_part == cannon.uid:
		if absf(distance) > 1.0: terra.facing = signf(distance)
		var strike := terra.data.heavy if objective == "fire" else terra.data.light
		if elapsed >= next_jab and strike.hit_rect(terra.position, terra.facing).intersects(nova.hurt_rect()):
			command.move.x = 0.0
			command.heavy = objective == "fire"
			command.light = not command.heavy
			next_jab = elapsed + (1.25 if loose else 1.7)
	return command

func _track_objective(kind: StringName, data: Dictionary) -> void:
	if completed_at >= 0.0 or not ended_reason.is_empty(): return
	match kind:
		&"part_pop":
			if data.part == cannon and data.fighter == fighters[1]:
				objective = "take"
				# Track the drop immediately. Leave a beat after Nova's recovery for a close catch.
				contest_at = elapsed + 0.70
				next_jab = contest_at
				if pickup_trial in ["aim", "nearest"]: _place_trial_parts()
		&"snap":
			if contested and data.part == cannon and data.fighter == fighters[1]:
				reclaims += 1
				cannon.condition = minf(cannon.condition, 1.0)
				objective = "break"
				stole_cannon = false
				next_jab = elapsed + 1.0
			if objective == "take" and data.fighter == fighters[0] and data.part != cannon:
				other_pickups += 1
			if objective == "take" and data.part == cannon and data.fighter == fighters[0]:
				objective = "fire"
				stole_cannon = true
		&"hit":
			# Only Terra's cannon can produce this move in the Nova/Terra duel.
			if stole_cannon and data.fighter == fighters[1] and data.source == fighters[0] and data.attack.id == &"pile_shot":
				objective = "done"
				completed_at = elapsed
		&"core_pop":
			ended_reason = "A mech was knocked out before the cannon hit."

func _place_trial_parts() -> void:
	# Both variants use the same two real modules, positions and claim rules.
	var shell := parts.break_part(fighters[1], &"shell", Vector2.ZERO)
	if not shell: return
	var center := Vector2(clampf(fighters[0].position.x, -850.0, 850.0), stage.platform_rect(0).position.y - 16.0)
	var forward := fighters[0].facing
	cannon.entity.position = center + Vector2(forward * 102.0, 0)
	cannon.entity.velocity = Vector2.ZERO
	shell.entity.position = center - Vector2(forward * 12.0, 0)
	shell.entity.lifetime = remaining

func _check_attempt() -> void:
	if phase != &"fight": return
	if completed_at >= 0.0:
		if elapsed - completed_at < 0.5: return
	elif ended_reason.is_empty():
		if objective == "fire" and cannon.carrier != 0:
			objective = "take"
		if objective == "take" and is_instance_valid(cannon.entity):
			# Leave time to read the prompt or check the bindings in the pause menu.
			cannon.entity.lifetime = maxf(cannon.entity.lifetime, remaining)
		if cannon.state != &"retired": return
		ended_reason = "The loose cannon left play."
	phase = &"results"
	broadcast(&"match_end", {"winners": winners()})
	match_finished.emit()
