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

func _duel(trial: String = "") -> CannonDuel:
	var duel := CannonDuel.new()
	root.add_child(duel)
	duel.simulation_enabled = false
	duel.setup(router, [&"nova", &"terra"], {"stage": "skyport", "duration": 90.0, "skip_intro": true, "pickup_trial": trial})
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
	router.free()
	print("CANNON DUEL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
