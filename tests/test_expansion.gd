extends SceneTree

var checks: int = 0
var failures: Array[String] = []
var session: MatchSession
var router: PlayerInputRouter
var loadouts: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	MatchWire.prepare()
	router = PlayerInputRouter.new()
	root.add_child(router)
	router.devices = [-2, -2, -2, -2]
	for group in range(ceili(Roster.IDS.size() / 4.0)):
		session = MatchSession.new()
		root.add_child(session)
		var ids: Array[StringName] = []
		for index in range(group * 4, mini(group * 4 + 4, Roster.IDS.size())): ids.append(Roster.IDS[index])
		session.setup(router, ids, {"skip_intro": true, "stage": "neon_alley"})
		session.simulation_enabled = false
		await physics_frame
		for fighter in session.fighters:
			for weapon_id in Roster.IDS:
				for shell_id in Roster.IDS:
					fighter.part(&"weapon_arm").definition = Roster.part(Roster.mech(weapon_id).native_weapon)
					fighter.part(&"shell").definition = Roster.part(Roster.mech(shell_id).native_shell)
					fighter.special_cooldown = 0.0
					fighter.buffered_direction = Vector2.ZERO
					fighter.action_buffer = &"special"
					fighter._start_buffered_attack()
					check(fighter.attack == fighter.part(&"weapon_arm").definition.attack and fighter.special_cooldown > 0.0 and fighter.data.light != null and fighter.shell_definition() != null, "%s / %s / %s constructs a usable loadout" % [fighter.data.id, weapon_id, shell_id])
					loadouts += 1
			fighter.part(&"weapon_arm").definition = Roster.part(fighter.data.native_weapon)
			fighter.part(&"shell").definition = Roster.part(fighter.data.native_shell)
			fighter.reset_at(Vector2.ZERO)
		check(session.parts.conservation_errors().is_empty(), "compatibility permutations preserve single ownership")
		check(MatchWire.valid(MatchWire.capture(session)), "all chassis and module identifiers serialize")
		if group == 1: await _new_mechanics()
		if group == 2: _challenger_mechanics()
		session.queue_free()
		await process_frame
	check(loadouts == 1728, "all twelve chassis × twelve arms × twelve shells exercised")
	router.queue_free()
	await process_frame
	print("EXPANSION TESTS: %d checks, %d loadouts, %d failures" % [checks, loadouts, failures.size()])
	if DirAccess.dir_exists_absolute("res://work"):
		var output := FileAccess.open("res://work/expansion-test-results.json", FileAccess.WRITE)
		if output:
			output.store_string(JSON.stringify({"checks": checks, "loadouts": loadouts, "failures": failures}, "  "))
	quit(0 if failures.is_empty() else 1)

func _start_special(fighter: Fighter, direction: Vector2 = Vector2.ZERO) -> void:
	fighter.reset_at(Vector2(-300, -200))
	fighter.invulnerable = 0.0
	fighter.facing = 1.0
	fighter.action_buffer = &"special"
	fighter.buffered_direction = direction
	fighter._start_buffered_attack()

func _challenger_mechanics() -> void:
	var rivet := session.fighters[0]
	var kite := session.fighters[1]
	var rook := session.fighters[2]
	var coda := session.fighters[3]
	var down := FighterCommand.new()
	down.move = Vector2.DOWN
	coda.reset_at(Vector2(0, -800))
	coda.velocity.y = 200.0
	coda.step(down, 0.01)
	check(is_equal_approx(coda.velocity.y, 200.0 + coda.data.gravity * 2.7 * 0.01), "holding down accelerates Coda's descent")
	rook.network_replica = true
	rook.network_grounded = true
	rook.apply_hit(rivet, rivet.data.light, 1)
	var planted_launch := rook.velocity.x
	rook.velocity.x = 100.0
	rook.apply_hit(rivet, rivet.data.light, 1)
	check(is_equal_approx(planted_launch * rook.data.ground_brace, rook.velocity.x) and planted_launch < rook.velocity.x, "a planted Rook takes less launch than a moving Rook")
	rook.network_replica = false
	_start_special(rook)
	rook.facing = -1
	rook.attack_time = rook.attack.startup + 0.01
	var before := rook.core
	check(not rook.apply_hit(rivet, rivet.data.light, 1) and rook.attack.id == &"gate_bash" and rook.core == before,
		"an active forward shield blocks the hit and begins its counter")
	_start_special(rook)
	rook.attack_time = rook.attack.startup + 0.01
	check(rook.apply_hit(rivet, rivet.data.light, 1) and rook.core < before, "a rear hit beats the shield")
	_start_special(rook)
	rook.facing = -1
	check(rook.apply_hit(rivet, rivet.data.light, 1), "the shield has a vulnerable startup")
	_start_special(kite)
	check(kite.jumps_left == 2 and rivet.data.air_jumps == 1, "Kite has two midair hops on its chassis")
	session.projectiles.clear()
	session._on_active_attack(kite)
	var disc: Dictionary = session.projectiles[0]
	for f in [rivet,rook,coda]: f.reset_at(Vector2(900,-200))
	var target := Vector2(kite.position.x + 180.0, kite.position.y)
	rook.reset_at(target)
	rook.invulnerable = 0.0
	var hits: Array[Dictionary] = []
	session._step_projectiles(0.04, hits)
	check(hits.size() == 1 and hits[0].target == rook, "disc can hit on its outward flight")
	hits.clear()
	session._step_projectiles(0.01, hits)
	check(hits.is_empty(), "an overlapping opponent takes one hit per pass")
	kite.position.x -= 80.0
	disc.age = disc.attack.phase_delay
	session._step_projectiles(0.01, hits)
	check(disc.pulsed and disc.velocity.x < 0 and hits.size() == 1, "disc homes to the moving carrier with one fresh return hit")
	check(MatchWire.valid(MatchWire.capture(session)), "return flight serializes with its phase and hit list")
	kite.core = 0.0
	session._step_projectiles(0.01, hits)
	check(session.projectiles.is_empty(), "returning disc clears when its pilot is knocked out")
	_start_special(coda)
	session._on_active_attack(coda)
	var echo: Dictionary = session.projectiles[0]
	var mark := coda.attack.hit_rect(coda.position,coda.facing).get_center()
	rook.reset_at(mark + Vector2(0,85))
	rook.invulnerable = 0.0
	coda.position.x += 430.0
	hits.clear()
	session._step_projectiles(0.2, hits)
	check(hits.is_empty() and echo.position.is_equal_approx(mark), "echo stays at the strike and gives time to escape")
	session._step_projectiles(0.29,hits)
	check(echo.pulsed and hits.size() == 1 and hits[0].target == rook, "second beat hits a rival left inside the marked area")
	hits.clear()
	session._step_projectiles(0.03,hits)
	check(hits.is_empty(), "second beat cannot repeatedly hit its victim")
	_start_special(rivet)
	var gate := session.parts.break_part(rook, &"weapon_arm", Vector2.ZERO)
	var socket := session.parts.socket_position(rivet,&"weapon_arm")
	gate.entity.age = 0.3
	gate.entity.position = socket + Vector2(390,20)
	session._on_active_attack(rivet)
	check(gate.entity.velocity.x < -600.0 and gate.state == &"loose" and rivet.reserved_part == -1, "Mag Fork reels the actual loose part without claiming it")
	var start := rivet.position + Vector2(0,-rivet.data.height*.35)
	gate.entity.position = start + Vector2(180,0)
	rivet.attack = null
	check(session.parts.nearest(rivet) == gate.entity, "Rivet reaches beyond the usual salvage radius")
	session.parts.resolve_requests([rivet])
	gate.entity.velocity = Vector2(27,19)
	coda.position = gate.entity.position + Vector2(-145,90)
	coda.facing = 1
	session.parts.reel_nearest(coda)
	check(gate.entity.velocity == Vector2(27,19) and gate.claimed_by == rivet.slot, "magnet leaves a reserved part and its claim intact")
	session.parts.commit_claim(rivet)
	_start_special(rivet)
	rivet.attack_time = rivet.attack.startup + 0.01
	check(not rivet.apply_hit(coda,coda.data.light,-1) and rivet.attack == gate.definition.counter_attack, "stolen Gate Shield counters on Rivet")
	var parry := MatchWire.event_to_wire(&"parry", {"fighter": rivet, "source": coda, "position": rivet.position})
	var reel := MatchWire.event_to_wire(&"magnet_reel", {"fighter": rivet, "part": gate, "position": socket})
	check(MatchWire.valid_event(parry) and MatchLink.EVENT_KINDS.has("parry"), "peers accept the shield counter cue")
	check(MatchWire.valid_event(reel) and MatchLink.EVENT_KINDS.has("magnet_reel"), "peers accept the loose-part reel cue")
	check(session.parts.conservation_errors().is_empty() and MatchWire.valid(MatchWire.capture(session)), "mixed challenger equipment, cues and attacks preserve network state")

func _new_mechanics() -> void:
	var shadow: Fighter = session.fighters[0]
	_start_special(shadow)
	var start: Vector2 = shadow.position
	shadow.attack_time = shadow.attack.startup - 0.02
	shadow.step(FighterCommand.new(), 1.0 / 120.0)
	check(is_equal_approx(shadow.position.x, start.x) and shadow.invulnerable == 0.0, "Shadow remains visible and vulnerable during the blink tell")
	shadow.attack_time = shadow.attack.startup - 0.001
	shadow.step(FighterCommand.new(), 1.0 / 120.0)
	check(shadow.position.x > start.x + 250.0 and shadow.attack_motion_applied, "Shadow blinks on the committed active frame")
	check(is_equal_approx(shadow.previous_position.x, shadow.position.x), "blink cannot sweep melee damage through the skipped space")
	var after: float = shadow.position.x
	shadow.step(FighterCommand.new(), 1.0 / 120.0)
	check(is_equal_approx(shadow.position.x, after), "blink movement applies once per attack")
	# The blink uses collision motion, so it cannot tunnel through a solid wall.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(-110, -210)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(25, 420)
	shape.shape = rect
	wall.add_child(shape)
	session.add_child(wall)
	await physics_frame
	_start_special(shadow)
	shadow.attack_time = shadow.attack.startup - 0.001
	shadow.step(FighterCommand.new(), 1.0 / 120.0)
	check(shadow.position.x < -135.0, "blink stops before solid collision")
	wall.queue_free()
	var event: Dictionary = MatchWire.event_to_wire(&"phase_shift", {"fighter": shadow, "origin": start, "position": shadow.position})
	check(MatchWire.valid_event(event), "phase effect has a validated network schema")
	var lumi: Fighter = session.fighters[1]
	_start_special(lumi)
	session.projectiles.clear()
	session._on_active_attack(lumi)
	var field: Dictionary = session.projectiles[0]
	check(field.type == &"field" and field.remaining > 2.0, "Lumi deploys a persistent prism zone")
	field.age = 0.40
	field.position = Vector2(0, -100)
	field.previous = field.position
	for fighter in session.fighters:
		fighter.reset_at(Vector2(0 if fighter.slot != 1 else -500, 0))
		fighter.invulnerable = 0.0
	var contacts: Array[Dictionary] = []
	session._step_projectiles(1.0 / 120.0, contacts)
	check(field.velocity == Vector2.ZERO and contacts.size() == 3, "prism stops traveling and controls space against multiple opponents")
	contacts.clear()
	session._step_projectiles(1.0 / 120.0, contacts)
	check(contacts.is_empty(), "prism cannot repeatedly damage the same fighter each tick")
	var kai: Fighter = session.fighters[2]
	_start_special(kai)
	check(kai.attack.startup >= 0.6 and kai.data.mass < 0.8 and kai.data.incoming_damage_scale > 1.0, "Kai commits to a long charge on a fragile chassis")
	session.projectiles.clear()
	session._on_active_attack(kai)
	var rail: Dictionary = session.projectiles[0]
	rail.position = Vector2(-100, -90)
	rail.previous = rail.position
	for fighter in session.fighters:
		fighter.reset_at(Vector2(0 if fighter.slot != 2 else -500, 0))
		fighter.invulnerable = 0.0
	contacts.clear()
	session._step_projectiles(0.10, contacts)
	check(rail.type == &"rail" and contacts.size() == 3, "charged rail pierces and uses a swept hitbox without tunneling")
	var zero: Fighter = session.fighters[3]
	for direction in [Vector2.ZERO, Vector2.UP, Vector2.DOWN]:
		_start_special(zero, direction)
		var expected: StringName = &"drive_lift" if direction.y < 0 else (&"drive_guard" if direction.y > 0 else &"drive_strike")
		check(zero.attack.id == expected, "Switch Driver accepts directional special %s" % expected)
	for id in [&"rail_lance", &"halo_caster", &"phase_talon"]:
		zero.part(&"weapon_arm").definition = Roster.part(id)
		zero.action_buffer = &"heavy"
		zero.buffered_direction = Vector2.ZERO
		zero._start_buffered_attack()
		var expected: AttackData = zero.data.ranged_heavy if id == &"rail_lance" else (zero.data.support_heavy if id == &"halo_caster" else zero.data.heavy)
		check(zero.attack == expected, "Zero adapts its neutral breaker to %s" % id)
	check(MatchWire.valid(MatchWire.capture(session)), "new attacks, zones and rail projectiles serialize with conserved ownership")
