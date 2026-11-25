class_name MatchSession
extends Node2D

signal combat_event(kind: StringName, payload: Dictionary)
signal match_finished
signal tick_completed

var stage: SimStage
var parts: EquipmentStore
var input_router: PlayerInputRouter
var fighters: Array[Fighter] = []
var projectiles: Array[Dictionary] = []
var projectile_serial: int = 0
var elapsed: float = 0.0
var duration: float = 180.0
var remaining: float = 180.0
var countdown: float = 3.0
var phase: StringName = &"intro"
var paused: bool = false
var time_scale: float = 1.0
var tick: int = 0
var event_counts: Dictionary = {}
var injected_commands: Dictionary = {}
var simulation_enabled: bool = true
var settings: Dictionary = {}
var final_warning_sent: bool = false
var component_wear_scale: float = 0.18
var command_source: Callable
var replica: bool = false

func setup(router: PlayerInputRouter, selections: Array[StringName], config: Dictionary = {}) -> void:
	input_router = router
	settings = config
	component_wear_scale = float(config.get("wear_scale", 0.18))
	duration = float(config.get("duration", 180.0))
	remaining = duration
	stage = SimStage.new()
	stage.definition = StageCatalog.stage(StringName(config.get("stage", "skyport")))
	add_child(stage)
	parts = EquipmentStore.new()
	parts.session = self
	add_child(parts)
	for slot in range(selections.size()):
		var fighter := Fighter.new()
		fighter.configure(slot, Roster.mech(selections[slot]), self)
		add_child(fighter)
		fighter.reset_at(stage.spawn_point(slot))
		fighter.facing = 1.0 if slot % 2 == 0 else -1.0
		fighter.brain = BotBrain.new(1337 + slot * 7919, int(config.get("difficulty", 1)))
		fighters.append(fighter)
		parts.create_native(fighter)
	if bool(config.get("skip_intro", false)):
		phase = &"fight"
		countdown = 0.0

func _physics_process(delta: float) -> void:
	if simulation_enabled:
		step(delta * time_scale)

func step(delta: float) -> void:
	if paused or phase == &"results" or fighters.is_empty():
		return
	tick += 1
	stage.step(delta)
	if phase == &"intro":
		countdown -= delta
		for fighter in fighters:
			fighter.step(FighterCommand.new(), delta)
		if countdown <= 0.0:
			phase = &"fight"
			input_router.clear_state()
			broadcast(&"go", {})
		tick_completed.emit()
		return
	elapsed += delta
	remaining = maxf(0.0, duration - elapsed)
	if remaining <= 30.0 and not final_warning_sent:
		final_warning_sent = true
		broadcast(&"final_thirty", {})
	var claim_requests: Array[Fighter] = []
	for fighter in fighters:
		var was_dead: bool = not fighter.alive()
		var command: FighterCommand
		if injected_commands.has(fighter.slot):
			command = injected_commands[fighter.slot]
		elif command_source.is_valid():
			command = command_source.call(fighter.slot, delta)
		elif input_router.devices[fighter.slot] == PlayerInputRouter.BOT:
			command = fighter.brain.command(fighter, self, delta)
		else:
			command = input_router.command_for(fighter.slot)
		fighter.step(command, delta)
		if was_dead and fighter.respawn_time <= 0.0:
			_respawn(fighter)
		if command.salvage:
			claim_requests.append(fighter)
	# Snapshot all eligible contacts before applying damage, allowing fair trades.
	var contacts: Array[Dictionary] = collect_melee_contacts()
	_step_projectiles(delta, contacts)
	for contact in contacts:
		var victim: Fighter = contact.target
		var source: Fighter = contact.source
		var landed := victim.apply_hit(source, contact.attack, float(contact.direction))
		if landed and bool(contact.get("snare", false)) and victim.alive():
			victim.snared = 0.7
	for fighter in fighters:
		if fighter.alive() and stage.is_outside(fighter.position):
			knock_out(fighter, fighter.last_attacker if fighter.credit_time > 0.0 else -1, true)
		if fighter.reserved_part >= 0 and fighter.attach_time <= 0.0 and fighter.stun <= 0.0:
			parts.commit_claim(fighter)
	parts.resolve_requests(claim_requests)
	parts.step(delta)
	if remaining <= 0.0:
		phase = &"results"
		broadcast(&"match_end", {"winners": winners()})
		match_finished.emit()
	tick_completed.emit()

func collect_melee_contacts() -> Array[Dictionary]:
	var contacts: Array[Dictionary] = []
	for source in fighters:
		if not source.alive() or source.attack == null or source.hitstop > 0.0:
			continue
		var move: AttackData = source.attack
		if not move.is_active(source.attack_time):
			continue
		if not source.attack_emitted:
			source.attack_emitted = true
			_on_active_attack(source)
		if move.delivery in [&"cannon", &"snare", &"field", &"rail", &"disc", &"parry"]:
			continue
		var current_rect: Rect2 = move.hit_rect(source.position, source.facing)
		var previous_rect: Rect2 = move.hit_rect(source.previous_position, source.facing)
		var swept: Rect2 = current_rect.merge(previous_rect)
		for target in fighters:
			if target == source or not target.can_be_hit() or source.attack_hits.has(target.slot):
				continue
			if swept.intersects(target.hurt_rect()):
				source.attack_hits[target.slot] = true
				contacts.append({"source": source, "target": target, "attack": move, "direction": source.facing})
	return contacts

func _on_active_attack(fighter: Fighter) -> void:
	var move: AttackData = fighter.attack
	broadcast(&"attack_active", {"fighter": fighter, "attack": move, "special": fighter.attack_is_special})
	if move.delivery == &"magnet":
		parts.reel_nearest(fighter)
	if move.delivery in [&"cannon", &"snare", &"repair", &"field", &"rail", &"disc", &"echo"]:
		_spawn_projectile(fighter, move, move.delivery, Vector2(fighter.facing * move.projectile_speed.x, move.projectile_speed.y), move.projectile_lifetime)
		if move.id in [&"pile_shot", &"rail_shot"]:
			fighter.velocity.x = -fighter.facing * (560.0 if move.id == &"pile_shot" else 680.0) / fighter.data.mass
			broadcast(&"cannon_recoil", {"fighter": fighter})

func _spawn_projectile(source: Fighter, move: AttackData, type: StringName, velocity: Vector2, lifetime: float) -> void:
	projectile_serial += 1
	var point: Vector2 = source.position + Vector2(source.facing * 105.0, -source.data.height * 0.57)
	if type == &"echo":
		point = move.hit_rect(source.position, source.facing).get_center()
	projectiles.append({"uid": projectile_serial, "source": source, "attack": move, "type": type, "position": point, "previous": point, "velocity": velocity, "remaining": lifetime, "age": 0.0, "facing": source.facing, "hits": {}, "pulsed": false})
	if projectiles.size() > 24:
		projectiles.pop_front()

func _step_projectiles(delta: float, contacts: Array[Dictionary]) -> void:
	for projectile in projectiles.duplicate():
		projectile.remaining -= delta
		projectile.age += delta
		projectile.previous = projectile.position
		var source: Fighter = projectile.source
		if projectile.type == &"repair":
			if not source.alive():
				projectile.remaining = 0.0
			projectile.position = source.position + Vector2(cos(float(projectile.age) * 8.0) * 100.0, -source.data.height - 40.0)
			if projectile.age > 0.6 and not projectile.pulsed and source.alive():
				projectile.pulsed = true
				var spent: float = 0.0
				for item in source.equipment.values():
					var amount: float = minf(8.0, minf(item.definition.maximum - item.condition, source.repair_budget))
					item.condition += amount
					source.repair_budget -= amount
					spent += amount
				broadcast(&"repair", {"fighter": source, "amount": spent})
		else:
			if projectile.type == &"disc":
				if not source.alive():
					projectiles.erase(projectile)
					continue
				if projectile.age >= projectile.attack.phase_delay:
					if not projectile.pulsed:
						projectile.pulsed = true
						projectile.hits.clear()
					var home := parts.socket_position(source, &"weapon_arm") - Vector2(projectile.position)
					projectile.velocity = home.limit_length(1490.0 * delta) / delta
					if absf(projectile.velocity.x) > 1.0: projectile.facing = signf(projectile.velocity.x)
					if home.length() < 32.0: projectile.remaining = 0.0
			elif projectile.type == &"echo":
				projectile.pulsed = projectile.age >= projectile.attack.phase_delay
			elif projectile.type == &"snare":
				projectile.velocity.y += 1700.0 * delta
			elif projectile.type == &"field" and projectile.age >= 0.35:
				projectile.velocity = Vector2.ZERO
			projectile.position += projectile.velocity * delta
			if projectile.type == &"snare":
				for index in range(stage.definition.platforms.size()):
					var rect: Rect2 = stage.platform_rect(index)
					var left: float = rect.position.x
					if projectile.position.x > left and projectile.position.x < left + rect.size.x and projectile.previous.y <= rect.position.y and projectile.position.y >= rect.position.y:
						projectile.position.y = rect.position.y
						projectile.velocity = Vector2.ZERO
			var radius: Vector2 = projectile.attack.projectile_radius
			var hitbox := Rect2(projectile.position - radius, radius * 2.0)
			hitbox = hitbox.merge(Rect2(projectile.previous - radius, radius * 2.0))
			for target in fighters:
				if projectile.type == &"echo" and not projectile.pulsed: break
				if target == source or not target.can_be_hit() or projectile.hits.has(target.slot):
					continue
				if hitbox.intersects(target.hurt_rect()):
					projectile.hits[target.slot] = true
					contacts.append({"source": source, "target": target, "attack": projectile.attack, "direction": projectile.facing, "snare": projectile.type == &"snare"})
					if not projectile.attack.piercing:
						projectile.remaining = 0.0
						break
		if projectile.remaining <= 0.0 or stage.is_outside(projectile.position):
			projectiles.erase(projectile)

func knock_out(fighter: Fighter, credited_slot: int, ring_out: bool = false) -> void:
	if fighter.respawn_time > 0.0:
		return
	var position_at_ko: Vector2 = fighter.position
	fighter.core = 0.0
	fighter.respawn_time = 2.0
	fighter.attack = null
	fighter.state = &"ko"
	fighter.velocity = Vector2.ZERO
	parts.release_on_ko(fighter)
	if credited_slot >= 0 and credited_slot != fighter.slot:
		fighters[credited_slot].score += 1
		fighters[credited_slot].pops += 1
	else:
		fighter.score -= 1
	for contributor in fighter.contributors:
		if int(contributor) != credited_slot and elapsed - float(fighter.contributors[contributor]) < 5.0:
			fighters[int(contributor)].assists += 1
	broadcast(&"core_pop", {"fighter": fighter, "credited": credited_slot, "ring_out": ring_out, "position": position_at_ko + Vector2(0, -100)})

func _respawn(fighter: Fighter) -> void:
	var best: Vector2 = stage.spawn_point(fighter.slot)
	var safety: float = -1.0
	for i in range(4):
		var candidate: Vector2 = stage.spawn_point(i)
		var nearest_enemy: float = INF
		for other in fighters:
			if other != fighter and other.alive():
				nearest_enemy = minf(nearest_enemy, candidate.distance_to(other.position))
		if nearest_enemy > safety:
			safety = nearest_enemy
			best = candidate
	fighter.reset_at(best)
	parts.create_native(fighter)
	broadcast(&"respawn", {"fighter": fighter})

func winners() -> Array[int]:
	var result: Array[int] = []
	var score_best: int = -9999
	var damage_best: float = -1.0
	for fighter in fighters:
		if fighter.score > score_best or (fighter.score == score_best and fighter.damage_done > damage_best + 0.001):
			result = [fighter.slot]
			score_best = fighter.score
			damage_best = fighter.damage_done
		elif fighter.score == score_best and absf(fighter.damage_done - damage_best) <= 0.001:
			result.append(fighter.slot)
	return result

func broadcast(kind: StringName, payload: Dictionary) -> void:
	# Prediction advances local movement/poses only. Combat and effects arrive from authority.
	if replica: return
	event_counts[kind] = int(event_counts.get(kind, 0)) + 1
	combat_event.emit(kind, payload)
