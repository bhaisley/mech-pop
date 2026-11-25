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
	_test_duel_rounds(router)
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
	collector.attach_time = EquipmentStore.CLAIM_TIME * 0.5
	host.parts.step(1.0 / 120.0)
	_roundtrip("in-flight salvage reservation")
	var remote_body: SalvageBody = replica.parts.instances[item.uid].entity
	check(remote_body.position.is_equal_approx(item.entity.position) and replica.fighters[3].reserved_part == item.uid, "guest sees the same moving cannon and claimant")
	host.parts.cancel_claim(collector)
	var fumble := MatchWire.event_to_wire(&"fumble", {"fighter": collector, "part": item, "position": item.entity.position})
	check(MatchLink.EVENT_KINDS.has("fumble") and MatchWire.valid_event(fumble) and MatchWire.event_from_wire(replica, fumble).part.uid == item.uid, "replicated fumble cue identifies the dropped cannon")
	_roundtrip("interrupted cannon at its in-flight position")
	check(replica.parts.instances[item.uid].claimed_by == -1 and replica.fighters[3].reserved_part == -1, "both guest reservations clear on a fumble")
	host.parts.resolve_requests([collector])
	collector.attach_time = 0.0
	host.parts.commit_claim(collector)
	_roundtrip("stolen weapon and dropped previous arm")
	check(replica.fighters[3].part(&"weapon_arm").definition.id == &"pile_cannon", "replica shows the actual stolen cannon")
	check(replica.fighters[3].steals == 1, "authoritative steal count copied once")
	collector.state = &"hover"
	collector.hover_left = 0.12
	var kuren := host.fighters[1]
	kuren.attack = kuren.data.light
	kuren.attack_confirmed = true
	_roundtrip("late Momo hover and Kuren hit-confirm")
	check(replica.fighters[3].state == &"hover" and is_equal_approx(replica.fighters[3].hover_left, 0.12), "guest sees Momo's remaining hover fuel")
	check(replica.fighters[1].attack_confirmed and replica.fighters[1].can_dodge(), "guest sees Kuren's open cancel window")
	kuren.attack = null
	kuren.attack_confirmed = false
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
	var knockouts: Array[Dictionary] = []
	host.combat_event.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"core_pop": knockouts.append(MatchWire.event_to_wire(kind, data)))
	host.knock_out(donor, collector.slot)
	var core_event := knockouts.back() as Dictionary
	check(MatchWire.valid_event(core_event) and not core_event.ring_out, "credited core break crosses the wire with its cause")
	check(not core_event.payload.has("ring_out") and core_event.payload.credited == collector.slot, "old clients receive the original KO payload and scorer")
	var legacy := core_event.duplicate(true)
	legacy.erase("ring_out")
	check(MatchWire.valid_event(legacy) and not MatchWire.event_from_wire(replica, legacy).has("ring_out"), "older room authorities still decode")
	var ring := host.fighters[0]
	var score_before := collector.score
	ring.position = host.stage.definition.blast_bounds.end + Vector2(300, 300)
	ring.last_attacker = collector.slot
	ring.credit_time = 2.0
	host.step(1.0 / 120.0)
	var ring_event := knockouts.back() as Dictionary
	check(MatchWire.valid_event(ring_event) and MatchWire.event_from_wire(replica, ring_event).ring_out and collector.score == score_before + 1, "scorer earns a point on a credited ring-out")
	host._respawn(ring)
	score_before = ring.score
	ring.position = host.stage.definition.blast_bounds.end + Vector2(300, 300)
	host.step(1.0 / 120.0)
	var fall := knockouts.back() as Dictionary
	check(fall.ring_out and fall.payload.credited == -1 and ring.score == score_before - 1, "uncredited fall costs the falling fighter one point")
	var malformed_cause := ring_event.duplicate(true)
	malformed_cause.ring_out = "yes"
	check(not MatchWire.valid_event(malformed_cause), "KO cause must be a boolean")
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

func _test_duel_rounds(router: PlayerInputRouter) -> void:
	var game := MatchSession.new()
	var copy := MatchSession.new()
	var roster: Array[StringName] = [&"kai", &"zero"]
	for match_game in [game, copy]:
		root.add_child(match_game)
		match_game.setup(router, roster, {"skip_intro": true})
		match_game.simulation_enabled = false
	var wire := MatchWire.capture(game)
	check(MatchWire.valid(wire, 2) and MatchWire.restore(copy, wire), "two actual fighters round-trip")
	check(not MatchWire.valid(wire, 4), "four-seat rooms only accept four-fighter state")
	var invalid := wire.duplicate(true)
	invalid.parts[0].original_owner = 3
	check(not MatchWire.restore(copy, invalid), "duel ownership cannot refer to an absent fighter")
	check(not MatchWire.valid_event({"kind":"core_pop", "payload":{"fighter":{"fighter":1}, "credited":2, "position":Vector2.ZERO}}, 2), "duel KO credit must refer to a playing seat")
	var room := MatchLink.new()
	root.add_child(room)
	room.active = true
	room.friend_duel = true
	room.authority = true
	room._open_seats(2)
	room.session = game
	check(not room.request_start(true), "an empty duel seat never becomes a bot")
	room.mode = &"match"
	room._match_finished()
	check(room.set_wins == [0, 0], "a drawn round awards no set point")
	game.fighters[0].score = 1
	room.mode = &"match"
	room._match_finished()
	room._match_finished()
	check(room.set_wins == [1, 0], "a round awards only one set point even on repeated finish")
	room._set_character(1, 0, "shadow")
	check(room.set_wins == [1, 0], "a chassis change preserves the seat's set score")
	room.mode = &"match"
	room._match_finished()
	check(room.set_wins == [2, 0], "two round wins finish the set")
	check(MatchLink.valid_set_wins([2, 1]) and not MatchLink.valid_set_wins([2, 2]) and not MatchLink.valid_set_wins([3, 0]), "only attainable set scores cross the wire")
	room.close()
	room.free()
	game.free()
	copy.free()

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
