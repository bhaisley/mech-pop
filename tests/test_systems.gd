extends SceneTree

var failures: Array[String] = []
var checks: int = 0
var router: PlayerInputRouter
var session: MatchSession

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _run() -> void:
	router = PlayerInputRouter.new()
	root.add_child(router)
	_test_input()
	router.devices = [-2, -2, -2, -2]
	session = MatchSession.new()
	root.add_child(session)
	session.setup(router, [&"nova", &"kuren", &"terra", &"momo"], {"skip_intro": true})
	session.simulation_enabled = false
	await physics_frame
	_test_combat()
	_test_equipment()
	await _test_movement()
	_test_specials_and_compatibility()
	_test_lifecycle()
	check(session.parts.conservation_errors().is_empty(), "all live part instances have one authoritative owner")
	print("SYSTEM TESTS: %d checks, %d failures" % [checks, failures.size()])
	var result: Dictionary = {"checks": checks, "failures": failures, "event_counts": session.event_counts}
	var file := FileAccess.open("res://work/system-test-results.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(result, "  "))
	session.queue_free()
	router.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_input() -> void:
	check(router.assign_device(1, 7), "first gamepad gets its own slot")
	check(router.assign_device(2, 8), "second gamepad gets its own slot")
	check(not router.assign_device(3, 7), "a physical pad cannot own two fighters")
	var press := InputEventJoypadButton.new()
	press.device = 7
	press.button_index = JOY_BUTTON_X
	press.pressed = true
	router.feed_event(press)
	check(router.command_for(1).light, "pad attack reaches assigned fighter")
	check(not router.command_for(1).light, "pressed input is consumed exactly once")
	check(not router.command_for(2).light, "pad attack does not leak to another device")
	var motion := InputEventJoypadMotion.new()
	motion.device = 8
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.9
	router.feed_event(motion)
	check(router.command_for(2).move.x > 0.8, "analog move reaches the correct fighter")
	check(is_zero_approx(router.command_for(1).move.x), "analog motion remains isolated")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	router.feed_event(key)
	var first: FighterCommand = router.command_for(0)
	var held: FighterCommand = router.command_for(0)
	check(first.jump_pressed and first.jump_held and not held.jump_pressed and held.jump_held, "held jump is separate from its press edge")
	router.clear_state()
	check(not router.command_for(0).jump_held and router.command_for(2).move == Vector2.ZERO, "focus reset clears all device state")

func _prepare_pair() -> Array[Fighter]:
	var a: Fighter = session.fighters[0]
	var b: Fighter = session.fighters[1]
	a.reset_at(Vector2(-60, 0))
	b.reset_at(Vector2(60, 0))
	a.facing = 1
	b.facing = -1
	a.invulnerable = 0
	b.invulnerable = 0
	for i in [2, 3]:
		session.fighters[i].position = Vector2(800 + i * 100, -500)
	return [a, b]

func _test_combat() -> void:
	var pair: Array[Fighter] = _prepare_pair()
	var a: Fighter = pair[0]
	var b: Fighter = pair[1]
	var light: AttackData = a.data.light
	b.apply_hit(a, light, 1)
	check(is_equal_approx(b.core, 100.0 - light.damage * 0.2), "shell passes only 20 percent Core chip")
	check(is_equal_approx(b.part(&"weapon_arm").condition, 40 - light.component_damage * session.component_wear_scale), "light strains the authored component with the match wear tuning")
	b.part(&"weapon_arm").condition = 1
	b.apply_hit(a, light, 1)
	check(b.part(&"weapon_arm") != null and b.part(&"weapon_arm").condition == 0.0, "light cannot detach a depleted component")
	var before: int = session.parts.loose.size()
	b.apply_hit(a, a.data.heavy, 1)
	check(b.part(&"weapon_arm") == null and session.parts.loose.size() == before + 1, "breaker creates one loose arm and clears equipped ownership")
	check(b.velocity.x > 0 and b.velocity.y < 0, "heavy has directional launch and upward knockback")
	var arm: PartInstance = session.parts.loose.back().part
	check(arm.fresh_coupler and arm.condition == 0, "a broken part receives one future rebuild allowance")
	b.core = 1
	b.apply_hit(a, light, 1)
	check(b.core == 1 and b.alive(), "shell protection prevents chip-only Core Pop")
	var shell: PartInstance = b.part(&"shell")
	shell.condition = 1
	b.apply_hit(a, a.data.slam, 1)
	check(b.part(&"shell") == null and b.alive(), "shell break exposes the Core without bypassing pre-hit shielding")
	var score_before: int = a.score
	b.apply_hit(a, light, 1)
	check(not b.alive() and a.score == score_before + 1, "exposed Core damage causes one credited elimination")
	session.knock_out(b, a.slot)
	check(a.score == score_before + 1, "duplicate knockout calls cannot award another point")
	# Restore b's native loadout through the actual respawn path.
	session._respawn(b)
	pair = _prepare_pair()
	a = pair[0]
	b = pair[1]
	a.attack = a.data.light
	b.attack = b.data.light
	a.attack_time = a.attack.startup + 0.005
	b.attack_time = b.attack.startup + 0.005
	a.attack_hits.clear()
	b.attack_hits.clear()
	var contacts: Array[Dictionary] = session.collect_melee_contacts()
	check(contacts.size() == 2, "simultaneous active attacks collect both contacts before damage")
	for contact in contacts:
		contact.target.apply_hit(contact.source, contact.attack, contact.direction)
	check(a.core < 100 and b.core < 100, "simultaneous attacks trade even when the first hit interrupts")
	check(session.collect_melee_contacts().is_empty(), "a hit cannot repeat from the same attack instance")
	# Fast movement passes through the victim between ticks: the swept shape must still hit.
	a.hitstop = 0
	a.attack = a.data.heavy
	a.attack_time = a.attack.startup + 0.01
	a.attack_hits.clear()
	a.previous_position = Vector2(-300, 0)
	a.position = Vector2(300, 0)
	b.invulnerable = 0
	b.position = Vector2.ZERO
	check(session.collect_melee_contacts().size() == 1, "fast authored melee motion sweeps across targets")

func _test_equipment() -> void:
	var a: Fighter = session.fighters[0]
	var b: Fighter = session.fighters[1]
	a.reset_at(Vector2(0, 0))
	b.reset_at(Vector2(0, 0))
	a.invulnerable = 0
	b.invulnerable = 0
	var item: PartInstance = session.parts.break_part(a, &"weapon_arm", Vector2.ZERO)
	var body: SalvageBody = item.entity
	body.position = Vector2(0, -60)
	body.age = 0.3
	session.parts.resolve_requests([a, b])
	var claim_count: int = int(a.reserved_part == item.uid) + int(b.reserved_part == item.uid)
	check(claim_count == 1, "simultaneous pickup requests have exactly one winner")
	var claimant: Fighter = a if a.reserved_part == item.uid else b
	check(item.state == &"claimed" and item.carrier == -1, "reservation is not premature equipment transfer")
	session.parts.cancel_claim(claimant)
	check(item.state == &"loose" and claimant.reserved_part == -1, "an interrupted attach releases the claim")
	# Move every other loose item out of pickup range and make b perform a rival steal.
	for other in session.parts.loose:
		if other != body:
			other.position = Vector2(1000, -80)
	session.parts.resolve_requests([b])
	var old: PartInstance = b.part(&"weapon_arm")
	old.condition = 13.0
	session.parts.commit_claim(b)
	check(b.part(&"weapon_arm") == item and item.carrier == b.slot, "rival steal commits its actual part instance")
	check(item.condition == 20.0 and not item.fresh_coupler, "first rebuild repairs exactly half a broken coupler once")
	check(old.state == &"loose" and old.condition == 13, "full-slot replacement ejects the previous condition unchanged")
	check(b.steals > 0 and item.definition.attack.id == &"arc_sweep", "stolen weapon supplies its donor's special")
	check(b.core == 100, "rebuilding does not alter Core health")
	b.core = 17
	# Swap away and recover intact equipment: no second free repair.
	session.parts._drop(b, item, Vector2.ZERO, &"swap")
	item.entity.position = Vector2(0, -60)
	item.entity.age = 0.3
	for other in session.parts.loose:
		if other.part != item:
			other.position = Vector2(1000, -80)
	session.parts.resolve_requests([b])
	session.parts.commit_claim(b)
	check(item.condition == 20.0 and b.core == 17, "drop/reclaim loops repair neither coupler nor Core")
	var repeated: PartInstance = session.parts.break_part(b, &"weapon_arm", Vector2.ZERO)
	check(repeated == item and item.fresh_coupler, "a later genuine break creates its next one-use coupler")
	item.entity.position = Vector2(2500, 1000)
	session.parts.step(0.01)
	check(item.recalled and not session.stage.is_outside(item.entity.position), "offstage salvage recalls once to a safe rack")
	item.entity.position = Vector2(2500, 1000)
	session.parts.step(0.01)
	check(not session.parts.instances.has(item.uid), "second offstage loss retires that instance")
	var expired: PartInstance = old
	if session.parts.instances.has(expired.uid):
		expired.entity.lifetime = 0.001
		session.parts.step(0.01)
		check(not session.parts.instances.has(expired.uid), "loose equipment expires at its lifetime")
	check(session.parts.conservation_errors().is_empty(), "ownership is conserved across break, contest, cancel, steal, swap and retire")

func _test_movement() -> void:
	var fighter: Fighter = session.fighters[0]
	fighter.reset_at(Vector2(0, -10))
	var empty := FighterCommand.new()
	for i in range(30):
		fighter.step(empty, 1.0 / 120.0)
		await physics_frame
	check(fighter.is_on_floor(), "fighter lands on the shared stage collision")
	var move := FighterCommand.new()
	move.move.x = 1
	fighter.step(move, 1.0 / 120.0)
	check(fighter.velocity.x > 0, "movement starts on the accepted input tick")
	var jump := FighterCommand.new()
	jump.jump_pressed = true
	jump.jump_held = true
	fighter.step(jump, 1.0 / 120.0)
	check(fighter.velocity.y < -1100, "ground jump starts at authored launch speed")
	await physics_frame
	fighter.step(empty, 1.0 / 120.0)
	check(fighter.velocity.y > -550, "releasing jump cuts ascent for variable height")
	await physics_frame
	fighter.step(jump, 1.0 / 120.0)
	check(fighter.jumps_left == 0 and fighter.velocity.y < -1000, "one independent air jump restores ascent")
	var dodge := FighterCommand.new()
	dodge.dodge = true
	dodge.move.x = 1
	fighter.step(dodge, 1.0 / 120.0)
	check(not fighter.air_boost_left and fighter.velocity.x > 1100, "air dodge spends exactly one recovery boost")
	check(fighter.invulnerable > 0 and fighter.dodge_cooldown > fighter.dodge_time, "dodge has a finite safe interval and longer cooldown")
	fighter.hitstop = 0.12
	var buffered := FighterCommand.new()
	buffered.heavy = true
	fighter.step(buffered, 1.0 / 120.0)
	for i in range(12):
		fighter.step(empty, 1.0 / 120.0)
	check(fighter.action_buffer_time > 0.05, "attack buffer survives participant hitstop")

func _test_specials_and_compatibility() -> void:
	# Gameplay compatibility matrix. Visual fit is a separate rendered review.
	for fighter in session.fighters:
		fighter.reset_at(Vector2(0, -100))
		for id in [&"arc_blade", &"burst_knuckle", &"pile_cannon", &"halo_caster"]:
			var existing: PartInstance = fighter.part(&"weapon_arm")
			var saved: ModuleData = existing.definition if existing else null
			var temporary := PartInstance.new()
			temporary.definition = Roster.part(id)
			temporary.condition = 20
			fighter.equipment[&"weapon_arm"] = temporary
			fighter.special_cooldown = 0
			fighter.action_buffer = &"special"
			fighter._start_buffered_attack()
			check(fighter.attack == Roster.part(id).attack and fighter.special_cooldown > 0, "%s can execute %s with its donor cooldown" % [fighter.data.id, id])
			if id == &"pile_cannon":
				session._on_active_attack(fighter)
				check(is_equal_approx(absf(fighter.velocity.x), 560.0 / fighter.data.mass), "%s cannon recoil respects host mass" % fighter.data.id)
			if existing:
				existing.definition = saved
				fighter.equipment[&"weapon_arm"] = existing
			else:
				fighter.equipment.erase(&"weapon_arm")
		for id in [&"fin_plate", &"vent_shell", &"bulwark", &"halo_shell"]:
			var temporary := PartInstance.new()
			temporary.definition = Roster.part(id)
			var existing: PartInstance = fighter.part(&"shell")
			fighter.equipment[&"shell"] = temporary
			check(fighter.shell_definition().id == id, "%s accepts shell modifier %s" % [fighter.data.id, id])
			if existing:
				fighter.equipment[&"shell"] = existing
			else:
				fighter.equipment.erase(&"shell")

func _test_lifecycle() -> void:
	var fighter: Fighter = session.fighters[3]
	var old_weapon: PartInstance = fighter.part(&"weapon_arm")
	session.knock_out(fighter, 0)
	check(old_weapon.state == &"loose" and old_weapon.carrier == -1, "Core Pop releases only the surviving weapon as salvage")
	session._respawn(fighter)
	check(fighter.part(&"weapon_arm").uid != old_weapon.uid and old_weapon.state == &"loose", "respawn creates new native parts without recalling existing salvage")
	check(fighter.core == 100 and fighter.invulnerable > 0 and fighter.alive(), "respawn restores Core and a short safe entry")
	for entry in session.fighters:
		entry.score = 2
		entry.damage_done = 100
	check(session.winners().size() == 4, "an exact tie produces shared winners")
	session.fighters[2].damage_done = 101
	check(session.winners() == [2], "Core damage breaks a score tie")
	session.elapsed = session.duration - 0.001
	for entry in session.fighters:
		session.injected_commands[entry.slot] = FighterCommand.new()
	session.step(1.0 / 120.0)
	check(session.phase == &"results" and session.remaining == 0, "timer completion enters results once")
