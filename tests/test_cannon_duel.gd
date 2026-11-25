extends SceneTree

const CannonDuel := preload("res://scripts/combat/cannon_duel.gd")
var failures: int = 0
var checks: int = 0
var router: PlayerInputRouter

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	_run.call_deferred()

func _duel(trial: String = "", contested: bool = false) -> CannonDuel:
	var duel := CannonDuel.new()
	root.add_child(duel)
	duel.simulation_enabled = false
	duel.setup(router, [&"nova", &"terra"], {"stage": "skyport", "duration": 90.0, "skip_intro": true, "pickup_trial": trial, "contested": contested})
	return duel

func _run() -> void:
	router = PlayerInputRouter.new()
	root.add_child(router)
	var duel := _duel()
	var nova := duel.fighters[0]
	var terra := duel.fighters[1]
	check(duel.fighters.size() == 2 and duel.objective == "break", "practice has two actual fighters")
	duel.parts.break_part(terra, &"shell", Vector2.ZERO)
	check(duel.objective == "break", "breaking a shell does not count as breaking the cannon")
	var cannon := duel.parts.break_part(terra, &"weapon_arm", Vector2.ZERO)
	check(duel.objective == "take" and cannon.original_owner == terra.slot, "Terra's individual cannon is tracked")
	cannon.entity.age = 1.0
	cannon.entity.position = nova.position + Vector2(0, -nova.data.height * 0.35)
	duel._check_attempt()
	check(cannon.entity.lifetime >= duel.remaining, "the practice cannon stays available while the learner reads")
	duel.parts.resolve_requests([nova])
	check(duel.objective == "take", "starting a claim does not count as equipping")
	duel.parts.commit_claim(nova)
	check(duel.objective == "fire" and nova.part(&"weapon_arm") == cannon, "committed steal advances the challenge")
	terra.apply_hit(nova, nova.data.light, 1.0)
	check(duel.objective == "fire", "hitting Terra with a different move does not finish the duel")
	duel.parts.break_part(nova, &"weapon_arm", Vector2.ZERO)
	duel._check_attempt()
	check(duel.objective == "take", "losing the cannon allows another pickup")
	duel.parts.retire(cannon)
	duel._check_attempt()
	check(duel.phase == &"results" and not duel.ended_reason.is_empty(), "a lost cannon leads to a retry")
	duel.free()
	duel = _duel()
	check(duel.objective == "break" and not duel.stole_cannon, "new attempts start with fresh gear and progress")
	duel.knock_out(duel.fighters[1], 0, true)
	duel._check_attempt()
	check(duel.phase == &"results" and duel.objective != "done", "a ring-out cannot win the challenge")
	duel.free()
	for mode in ["nearest", "aim"]:
		var trial := _duel(mode)
		var pilot := trial.fighters[0]
		var target := trial.fighters[1]
		var shell := target.part(&"shell")
		var wanted := trial.parts.break_part(target, &"weapon_arm", Vector2.ZERO)
		for entry in trial.parts.loose: entry.age = 1.0
		check(trial.parts.nearest(pilot).part == shell, "neutral aim selects the nearer shell in " + mode)
		pilot.last_command.move = Vector2.RIGHT
		var expected := wanted if mode == "aim" else shell
		check(trial.parts.nearest(pilot).part == expected, "aiming toward the cannon obeys " + mode)
		trial.parts.resolve_requests([pilot])
		check(pilot.reserved_part == expected.uid, "the actual claim takes the highlighted instance in " + mode)
		trial.parts.cancel_claim(pilot)
		wanted.entity.position.x = pilot.position.x + 200.0
		check(trial.parts.nearest(pilot).part == shell, "aim cannot extend pickup range in " + mode)
		trial.free()
	_test_breaks_and_reclaims()
	router.free()
	print("CANNON DUEL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_breaks_and_reclaims() -> void:
	for id in Roster.IDS:
		var mech := Roster.mech(id)
		check(mech.heavy.ejection == AttackData.Ejection.FORWARD and mech.uppercut.ejection == AttackData.Ejection.RISE and mech.slam.ejection == AttackData.Ejection.DROP, "three distinct breaker routes on " + String(id))
	var driver := Roster.part(&"switch_driver")
	check(driver.up_attack.ejection == AttackData.Ejection.RISE and driver.down_attack.ejection == AttackData.Ejection.DROP, "borrowed and already-fired driver attacks retain their own route")
	for facing: float in [-1.0,1.0]:
		for route in ["heavy","uppercut","slam"]:
			var fight := _duel("", true)
			var pilot := fight.fighters[0]
			var rival := fight.fighters[1]
			var gun := fight.cannon
			rival.apply_hit(pilot, pilot.data.get(route), facing)
			check(gun.state == &"loose" and rival.part(&"shell") != null, route + " detaches the worn cannon")
			var velocity: Vector2 = gun.entity.velocity
			if route == "uppercut": check(velocity.y < -900 and absf(velocity.x) < 180, "uppercut lofts a catch")
			elif route == "slam": check(velocity.y > 0 and velocity.x*facing < 0, "slam drops the part toward the attacker")
			else: check(velocity.x*facing > 600 and absf(velocity.y) < 450, "forward breaker ejects downrange")
			fight.free()
	var fight := _duel("", true)
	var nova := fight.fighters[0]
	var terra := fight.fighters[1]
	var gun := fight.parts.break_part(terra, &"weapon_arm", Vector2.ZERO)
	gun.entity.age = 0.4
	gun.entity.position = nova.position + Vector2(90,-60)
	var start: Vector2 = gun.entity.position
	fight.parts.resolve_requests([nova])
	nova.attach_time = EquipmentStore.CLAIM_TIME / 2.0
	fight.parts.step(EquipmentStore.CLAIM_TIME / 2.0)
	var midpoint: Vector2 = gun.entity.position
	check(midpoint != start and midpoint.distance_to(fight.parts.socket_position(nova, &"weapon_arm")) < start.distance_to(fight.parts.socket_position(nova, &"weapon_arm")), "claimed body travels toward the new socket")
	nova.apply_hit(terra, terra.data.light, -1.0)
	check(gun.state == &"loose" and gun.entity.position == midpoint and gun.entity.velocity.y < 0, "interrupt releases the same module at its in-flight position")
	fight.elapsed = 2.0
	gun.entity.position = terra.position + Vector2(0,-70)
	var chase := fight._sparring_input(1, 1.0/120.0)
	check(chase.salvage and gun.carrier == -1, "Terra requests a contested claim through the normal inputs")
	fight.parts.resolve_requests([terra])
	check(fight.objective == "take" and gun.claimed_by == terra.slot, "no reclaim is credited during a windup")
	fight.parts.commit_claim(terra)
	check(fight.reclaims == 1 and fight.objective == "break" and terra.part(&"weapon_arm") == gun, "Terra can recover his own instance and reset the objective")
	terra.apply_hit(nova,nova.data.slam,1)
	gun.entity.position = nova.position + Vector2(0,-65)
	gun.entity.age = 0.25
	nova.stun = 0
	fight.parts.resolve_requests([nova])
	fight.parts.commit_claim(nova)
	check(fight.objective == "fire" and nova.part(&"weapon_arm") == gun, "player can win back Terra's reclaimed cannon")
	terra.apply_hit(nova,gun.definition.attack,1)
	check(fight.objective == "done" and fight.parts.conservation_errors().is_empty(), "only the actual cannon hit finishes the rematch")
	fight.free()
