extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	MatchWire.prepare()
	var router := PlayerInputRouter.new()
	root.add_child(router)
	router.devices = [-2, -2, -2, -2]
	Engine.time_scale = 8.0
	for id in StageCatalog.IDS:
		var host := MatchSession.new()
		root.add_child(host)
		host.setup(router, [&"nova", &"kuren", &"terra", &"momo"], {"skip_intro": true, "stage": String(id)})
		host.simulation_enabled = false
		for slot in range(4): host.injected_commands[slot] = FighterCommand.new()
		# Exercise the actual physics world: every spawn must land on its intended deck.
		for frame in range(100):
			await physics_frame
			host.step(1.0 / 120.0)
		for fighter in host.fighters:
			check(fighter.grounded(), "%s P%d spawn lands on collision" % [id, fighter.slot + 1])
			check(not host.stage.is_outside(fighter.position), "%s P%d spawn is inside arena" % [id, fighter.slot + 1])
		# A vertical/diagonal platform's two coordinates must survive serialization.
		host.stage.step(4.5)
		var snapshot: Dictionary = MatchWire.capture(host)
		check(MatchWire.valid(snapshot), "%s world snapshot valid" % id)
		var remote := MatchSession.new()
		root.add_child(remote)
		remote.setup(router, [&"nova", &"kuren", &"terra", &"momo"], {"skip_intro": true, "stage": String(id)})
		remote.simulation_enabled = false
		remote.replica = true
		for fighter in remote.fighters: fighter.network_replica = true
		check(MatchWire.restore(remote, bytes_to_var(var_to_bytes(snapshot))), "%s wire roundtrip applies" % id)
		check(remote.stage.ferry.position.is_equal_approx(host.stage.ferry.position), "%s moving deck collision agrees across peers" % id)
		check(MatchWire.digest(MatchWire.capture(remote)) == MatchWire.digest(snapshot), "%s complete state agrees" % id)
		var wrong: Dictionary = snapshot.duplicate(true)
		wrong.stage_id = "reactor_ring" if id != &"reactor_ring" else "skyport"
		check(not MatchWire.restore(remote, wrong), "%s refuses a snapshot for different geometry" % id)
		var safe: Vector2 = host.stage.safe_salvage_point(Vector2(9999, 9999))
		check(not host.stage.is_outside(safe) and safe.x < host.stage.definition.floor_rect().end.x - 100.0, "%s recalled salvage stays on the main deck" % id)
		host.queue_free()
		remote.queue_free()
		await process_frame
	router.queue_free()
	await process_frame
	print("ARENA TESTS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
