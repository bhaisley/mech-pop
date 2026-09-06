extends SceneTree

var failures: Array[String] = []
var rounds: Array[Dictionary] = []
var router: PlayerInputRouter
var first_pop: float = -1
var session: MatchSession
var max_parts: int = 0
var check_clock: float = 0
var total_rounds: int = 10
var wear_scale: float = 0.18
var round_duration: float = 180.0
var report_name: String = "bot-match-results"
var expansion: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _physics_process(delta: float) -> bool:
	if session and is_instance_valid(session) and session.parts:
		max_parts = maxi(max_parts, session.parts.instances.size())
		check_clock += delta
		if check_clock > 1.0:
			check_clock = 0
			var errors: Array[String] = session.parts.conservation_errors()
			for error in errors:
				if not failures.has(error):
					failures.append(error)
	return false

func _run() -> void:
	router = PlayerInputRouter.new()
	root.add_child(router)
	router.devices = [-2, -2, -2, -2]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rounds="):
			total_rounds = int(arg.get_slice("=", 1))
		elif arg.begins_with("--wear="):
			wear_scale = float(arg.get_slice("=", 1))
		elif arg.begins_with("--duration="):
			round_duration = float(arg.get_slice("=", 1))
		elif arg.begins_with("--report="):
			report_name = arg.get_slice("=", 1)
		elif arg == "--expansion": expansion = true
	for round_number in range(total_rounds):
		first_pop = -1
		session = MatchSession.new()
		root.add_child(session)
		var roster: Array[StringName] = [&"nova", &"kuren", &"terra", &"momo"]
		var stage: StringName = &"skyport"
		if expansion:
			stage = StageCatalog.IDS[round_number % StageCatalog.IDS.size()]
			for slot in range(4): roster[slot] = Roster.IDS[slot + (round_number % 2) * 4]
		session.setup(router, roster, {"stage": stage, "skip_intro": true, "difficulty": round_number % 3, "wear_scale": wear_scale, "duration": round_duration})
		for fighter in session.fighters:
			fighter.brain.rng.seed += round_number * 397
		session.combat_event.connect(func(kind: StringName, _payload: Dictionary) -> void:
			if kind == &"part_pop" and first_pop < 0:
				first_pop = session.elapsed)
		await session.match_finished
		var scores: Array[Dictionary] = []
		for fighter in session.fighters:
			scores.append({"mech": fighter.data.id, "score": fighter.score, "damage": snappedf(fighter.damage_done, 0.1), "steals": fighter.steals, "pops": fighter.pops})
		var result: Dictionary = {"round": round_number + 1, "stage": stage, "difficulty": round_number % 3, "first_part_pop": snappedf(first_pop, 0.01), "events": session.event_counts.duplicate(), "scores": scores, "live_parts": session.parts.instances.size(), "memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT)}
		rounds.append(result)
		if first_pop < 0 or first_pop > 45:
			failures.append("Round %d failed to show an ordinary part break within 45 seconds" % (round_number + 1))
		if int(session.event_counts.get(&"snap", 0)) == 0:
			failures.append("Round %d had no rebuilt equipment" % (round_number + 1))
		if int(session.event_counts.get(&"core_pop", 0)) < 2:
			failures.append("Round %d had fewer than two Core Pops" % (round_number + 1))
		print("ROUND ", round_number + 1, " ", JSON.stringify(result))
		session.queue_free()
		session = null
		await process_frame
		await process_frame
	var output := FileAccess.open("res://work/%s.json" % report_name, FileAccess.WRITE)
	output.store_string(JSON.stringify({"rounds": rounds, "failures": failures, "max_live_parts": max_parts}, "  "))
	print("BOT MATCH TESTS: ", total_rounds, " rounds, ", total_rounds * round_duration, " simulated seconds, wear=", wear_scale, " failures=", failures, " max_parts=", max_parts)
	router.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
