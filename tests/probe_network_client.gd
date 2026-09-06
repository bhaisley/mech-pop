extends SceneTree

var app: Node
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _until(condition: Callable, seconds: float = 12.0) -> bool:
	var limit: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < limit:
		if condition.call(): return true
		await process_frame
	return false

func _run() -> void:
	app = load("res://ui/app.tscn").instantiate()
	root.add_child(app)
	var started: bool = await _until(func() -> bool: return app.session != null and app.session.phase == &"fight")
	if not started:
		printerr("NETWORK_PROBE_FAILED no match started")
		quit(1)
		return
	var link: MatchLink = app.network
	var original_slots: Array[int] = link.own_slots()
	var original_round: int = link.round_number
	var original_character: String = link.seats[original_slots[0]].character
	await create_timer(2.0).timeout
	# These travel through ENet and the actual remote-sender authorization path.
	var attack := FighterCommand.new()
	attack.heavy = true
	var other: int = (original_slots[0] + 1) % 4
	link._inputs.rpc_id(1, original_round, [{"slot": other, "frames": [NetworkInputBuffer.pack(1, attack)]}])
	link._inputs.rpc_id(1, original_round, [{"slot": original_slots[0], "frames": [[0, Vector2.ZERO, 0]]}])
	link._character_request.rpc_id(1, other, "nova")
	await create_timer(0.5).timeout
	var address: String = link.address
	var port: int = link.port
	var devices: Array[int] = link.local_devices.duplicate()
	var token: String = link.resume_token
	link.close()
	await create_timer(1.5).timeout
	link.join(address, port, devices)
	var resumed: bool = await _until(func() -> bool: return link.active and link.session != null and link.latest_snapshot_tick > 0 and not link.loading)
	if not resumed: failures.append("did not resume a running match")
	if link.resume_token != token: failures.append("resume token changed")
	if link.own_slots() != original_slots: failures.append("reconnect did not preserve party slots")
	if link.round_number != original_round: failures.append("reconnect restarted the round")
	if resumed and link.seats[original_slots[0]].character != original_character: failures.append("character changed during reconnect")
	print("NETWORK_RECOVERY_PROBE ", JSON.stringify({"resumed": resumed, "same_slots": link.own_slots() == original_slots, "same_round": link.round_number == original_round, "invalid_messages_sent": 2, "failures": failures}))
	if not failures.is_empty(): quit(1)
