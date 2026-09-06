extends SceneTree

var checks: int = 0
var failures: Array[String] = []
var host: MatchSession
var replica: MatchSession

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	MatchWire.prepare()
	_test_inputs()
	var router := PlayerInputRouter.new()
	root.add_child(router)
	router.devices = [-2, -2, -2, -2]
	host = MatchSession.new()
	replica = MatchSession.new()
	root.add_child(host)
	root.add_child(replica)
	host.setup(router, [&"nova", &"kuren", &"terra", &"momo"], {"skip_intro": true})
	replica.setup(router, [&"nova", &"kuren", &"terra", &"momo"], {"skip_intro": true})
	host.simulation_enabled = false
	replica.simulation_enabled = false
	replica.replica = true
	for fighter in replica.fighters: fighter.network_replica = true
	await physics_frame
	_roundtrip("initial native equipment")
	var donor: Fighter = host.fighters[2]
	var collector: Fighter = host.fighters[3]
	var item: PartInstance = host.parts.break_part(donor, &"weapon_arm", Vector2(220, -540))
	item.entity.position = collector.position + Vector2(0, -collector.data.height * 0.35)
	item.entity.age = 0.3
	_roundtrip("broken part with one loose body")
	host.parts.resolve_requests([collector])
	check(item.claimed_by == collector.slot, "real salvage claim begins")
	_roundtrip("in-flight salvage reservation")
	collector.attach_time = 0.0
	host.parts.commit_claim(collector)
	_roundtrip("stolen weapon and dropped previous arm")
	check(replica.fighters[3].part(&"weapon_arm").definition.id == &"pile_cannon", "replica shows the actual stolen cannon")
	check(replica.fighters[3].steals == 1, "authoritative steal count copied once")
	collector.attack = item.definition.attack
	collector.attack_is_special = true
	collector.attack_serial = 8
	collector.attack_time = 0.2
	collector.state = &"attack"
	host._spawn_projectile(collector, collector.attack, &"cannon", Vector2(1920, 0), 1.0)
	_roundtrip("equipped special animation and live projectile")
	check(replica.projectiles[0].source == replica.fighters[3], "projectile owner resolves to replica identity")
	var event: Dictionary = MatchWire.event_to_wire(&"snap", {"fighter": collector, "part": item, "stolen": true})
	check(MatchWire.valid_event(event), "real cosmetic event schema accepted")
	var decoded: Dictionary = MatchWire.event_from_wire(replica, bytes_to_var(var_to_bytes(event)))
	check(decoded.fighter == replica.fighters[3] and decoded.part == replica.parts.instances[item.uid] and decoded.stolen, "event references resolve to current local entities")
	var malformed: Dictionary = event.duplicate(true)
	malformed.payload.fighter.fighter = 999
	check(not MatchWire.valid_event(malformed), "out-of-bounds cosmetic event rejected")
	host.knock_out(donor, collector.slot)
	_roundtrip("Core Pop and retired shell")
	host._respawn(donor)
	_roundtrip("respawn allocates fresh unique parts")
	for body in host.parts.loose.duplicate(): host.parts.retire(body.part)
	host.projectiles.clear()
	_roundtrip("expired entities removed from replica")
	await process_frame
	check(replica.parts.loose.is_empty(), "replica has no orphan loose parts after expiration")
	var valid: Dictionary = MatchWire.capture(host)
	var broken: Dictionary = valid.duplicate(true)
	broken.parts.append(broken.parts[0].duplicate(true))
	var before: String = MatchWire.digest(MatchWire.capture(replica))
	check(not MatchWire.restore(replica, broken), "duplicate part UID rejected")
	check(MatchWire.digest(MatchWire.capture(replica)) == before, "invalid state rejected before mutation")
	broken = valid.duplicate(true)
	broken.fighters[0].position = Vector2(NAN, 0)
	check(not MatchWire.valid(broken), "nonfinite coordinates rejected")
	broken = valid.duplicate(true)
	broken.fighters[0].attack = "../../untrusted-resource"
	check(not MatchWire.valid(broken), "unknown attack cannot load a peer-controlled resource path")
	broken = valid.duplicate(true)
	broken.parts[1].carrier = broken.parts[0].carrier
	broken.parts[1].definition = broken.parts[0].definition
	check(not MatchWire.valid(broken), "two parts cannot occupy the same carrier socket")
	host.phase = &"results"
	host.remaining = 0.0
	_roundtrip("results")
	check(host.winners() == replica.winners(), "both peers compute identical final winners")
	host.queue_free()
	replica.queue_free()
	router.queue_free()
	await process_frame
	print("NETWORK STATE TESTS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _roundtrip(label: String) -> void:
	var source: Dictionary = MatchWire.capture(host)
	# Exercise the actual safe Variant wire serialization, not just shared references.
	var wire: Dictionary = bytes_to_var(var_to_bytes(source))
	check(MatchWire.restore(replica, wire), label + ": snapshot accepted")
	check(MatchWire.digest(MatchWire.capture(replica)) == MatchWire.digest(wire), label + ": state identical after decode")
	check(replica.parts.conservation_errors().is_empty(), label + ": equipment ownership conserved")

func _test_inputs() -> void:
	var diagonal := FighterCommand.new()
	diagonal.move = Vector2(1, -1)
	var diagonal_frame: Array = NetworkInputBuffer.pack(1, diagonal)
	check(NetworkInputBuffer.valid(diagonal_frame) and NetworkInputBuffer.unpack(diagonal_frame).move == diagonal.move, "directional breakers retain full horizontal input over the network")
	var command := FighterCommand.new()
	command.move = Vector2(0.8, -0.2)
	command.jump_pressed = true
	command.jump_held = true
	command.special = true
	var frame: Array = NetworkInputBuffer.pack(1, command)
	var queue := NetworkInputBuffer.new()
	check(queue.push([frame], 0.0), "valid movement and simultaneous actions accepted")
	var result: FighterCommand = queue.take(0.0)
	check(result.move == command.move and result.jump_pressed and result.jump_held and result.special, "commands retain analog movement and independent action edges")
	queue.push([frame], 0.01)
	result = queue.take(0.01)
	check(result.jump_held and not result.jump_pressed and not result.special, "duplicate packet cannot replay a press edge")
	check(queue.consumed == 1, "acknowledgment tracks consumed input")
	result = queue.take(0.5)
	check(result.move == Vector2.ZERO and not result.jump_held, "connection stall releases held inputs")
	var bad: Array = [2, Vector2(INF, 0), 127]
	check(not queue.push([NetworkInputBuffer.pack(2, command), bad], 0.6) and queue.pending.is_empty(), "invalid batch has no partial input side effects")
	check(not queue.push([[2, Vector2.ZERO, 256]], 0.6), "unknown action bits rejected")
	check(not queue.push([[99999, Vector2.ZERO, 0]], 0.6), "unbounded future sequence rejected")
	check(queue.push([NetworkInputBuffer.pack(3, command), NetworkInputBuffer.pack(2, command)], 0.7), "out-of-order packet accepted")
	queue.take(0.7)
	check(queue.consumed == 2, "queued commands execute by sequence")
	queue.clear()
	check(queue.take(0.7).move == Vector2.ZERO and queue.pending.is_empty(), "explicit focus release clears pending commands")
	var burst := NetworkInputBuffer.new()
	var backlog: Array = []
	for sequence in range(1, 17):
		var recent := FighterCommand.new()
		recent.move = Vector2.RIGHT
		recent.light = sequence == 4
		backlog.append(NetworkInputBuffer.pack(sequence, recent))
	check(burst.push(backlog, 1.0), "delayed input burst is accepted")
	var caught_up: FighterCommand = burst.take(1.0)
	check(burst.consumed == 14 and burst.pending.size() == 2 and caught_up.move == Vector2.RIGHT, "delayed movement catches up without running extra physics steps")
	check(caught_up.light and not burst.take(1.01).light and not burst.take(1.02).light, "coalesced press edge fires once")
