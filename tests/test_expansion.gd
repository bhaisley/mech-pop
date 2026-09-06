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
	for group in range(2):
		session = MatchSession.new()
		root.add_child(session)
		var ids: Array[StringName] = []
		for index in range(4): ids.append(Roster.IDS[group * 4 + index])
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
		session.queue_free()
		await process_frame
	check(loadouts == 512, "all eight chassis × eight arms × eight shells exercised")
	router.queue_free()
	await process_frame
	print("EXPANSION TESTS: %d checks, %d loadouts, %d failures" % [checks, loadouts, failures.size()])
	var output := FileAccess.open("res://work/expansion-test-results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "loadouts": loadouts, "failures": failures}, "  "))
	quit(0 if failures.is_empty() else 1)

func _start_special(fighter: Fighter, direction: Vector2 = Vector2.ZERO) -> void:
	fighter.reset_at(Vector2(-300, -200))
	fighter.invulnerable = 0.0
	fighter.facing = 1.0
	fighter.action_buffer = &"special"
	fighter.buffered_direction = direction
	fighter._start_buffered_attack()

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
