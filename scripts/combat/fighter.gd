class_name Fighter
extends CharacterBody2D

var slot: int
var data: MechData
var session: Node
var brain: RefCounted
var facing: float = 1.0
var core: float = 100.0
var equipment: Dictionary = {}
var attack: AttackData
var attack_time: float = 0.0
var attack_serial: int = 0
var attack_hits: Dictionary = {}
var attack_emitted: bool = false
var attack_is_special: bool = false
var attack_confirmed: bool = false
var attack_motion_applied: bool = false
var state: StringName = &"idle"
var previous_position: Vector2
var hitstop: float = 0.0
var stun: float = 0.0
var invulnerable: float = 0.0
var dodge_time: float = 0.0
var dodge_cooldown: float = 0.0
var special_cooldown: float = 0.0
var coyote: float = 0.0
var drop_time: float = 0.0
var jumps_left: int = 1
var air_boost_left: bool = true
var hover_left: float = 0.7
var jump_buffer: float = 0.0
var action_buffer: StringName = &""
var action_buffer_time: float = 0.0
var buffered_direction: Vector2
var respawn_time: float = 0.0
var attach_time: float = 0.0
var reserved_part: int = -1
var last_attacker: int = -1
var credit_time: float = 0.0
var combo_window: float = 0.0
var combo_hits: int = 0
var snared: float = 0.0
var repair_budget: float = 28.0
var score: int = 0
var pops: int = 0
var steals: int = 0
var parts_broken: int = 0
var assists: int = 0
var damage_done: float = 0.0
var contributors: Dictionary = {}
var invincible_debug: bool = false
var last_command := FighterCommand.new()
var network_replica: bool = false
var network_local: bool = false
var network_grounded: bool = false
var network_visual_origin := Vector2.ZERO
var network_visual_target := Vector2.ZERO
var network_visual_offset := Vector2.ZERO
var network_visual_elapsed: float = 1.0
var network_visual_interval: float = 0.04
var network_visual_ready: bool = false

func configure(player_slot: int, definition: MechData, match_session: Node) -> void:
	slot = player_slot
	data = definition
	session = match_session
	name = "Fighter%d" % (slot + 1)
	collision_layer = 0
	collision_mask = 3
	floor_snap_length = 14.0
	floor_stop_on_slope = true
	platform_floor_layers = 3
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = data.width * 0.38
	capsule.height = data.height * 0.89
	collider.shape = capsule
	collider.position.y = -capsule.height * 0.5
	add_child(collider)

func alive() -> bool:
	return respawn_time <= 0.0 and core > 0.0

func part(slot_name: StringName) -> PartInstance:
	return equipment.get(slot_name) as PartInstance

func shell_definition() -> ModuleData:
	var shell: PartInstance = part(&"shell")
	return shell.definition if shell != null else null

func adaptive_mode() -> StringName:
	var weapon: PartInstance = part(&"weapon_arm")
	if weapon == null: return &"STRIKE"
	if weapon.definition.action in [&"projectile", &"rail", &"field"]: return &"SCOPE"
	if weapon.definition.action == &"repair": return &"SYNC"
	return &"STRIKE"

func hurt_rect() -> Rect2:
	return Rect2(position + Vector2(-data.width * 0.48, -data.height * 0.94), Vector2(data.width * 0.96, data.height * 0.9))

func grounded() -> bool:
	return network_grounded if network_replica else is_on_floor()

func move_body() -> void:
	move_and_slide()
	if network_replica: network_grounded = is_on_floor()

func visual_position(delta: float) -> Vector2:
	if not network_replica:
		return previous_position.lerp(position, Engine.get_physics_interpolation_fraction())
	if network_local:
		network_visual_offset *= exp(-delta * 18.0)
		return position + network_visual_offset
	network_visual_elapsed += delta
	return network_visual_origin.lerp(network_visual_target, clampf(network_visual_elapsed / network_visual_interval, 0.0, 1.0))

func step(command: FighterCommand, delta: float) -> void:
	previous_position = position
	last_command = command
	if not alive():
		respawn_time = maxf(0.0, respawn_time - delta)
		return
	_buffer_input(command, delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	special_cooldown = maxf(0.0, special_cooldown - delta)
	credit_time = maxf(0.0, credit_time - delta)
	combo_window = maxf(0.0, combo_window - delta)
	snared = maxf(0.0, snared - delta)
	if combo_window == 0.0:
		combo_hits = 0
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - delta)
		return
	var on_ground: bool = grounded()
	if on_ground:
		coyote = 0.08
		jumps_left = 1
		air_boost_left = true
		hover_left = 0.7 + (shell_definition().hover_bonus if shell_definition() else 0.0)
	else:
		coyote = maxf(0.0, coyote - delta)
	drop_time = maxf(0.0, drop_time - delta)
	set_collision_mask_value(2, drop_time <= 0.0)
	stun = maxf(0.0, stun - delta)
	if stun > 0.0:
		state = &"hurt"
		velocity.x += command.move.x * 360.0 * delta
		velocity.y += data.gravity * delta
		move_body()
		return
	if reserved_part >= 0:
		state = &"attach"
		attach_time -= delta
		velocity.x = move_toward(velocity.x, 0.0, 3900.0 * delta)
		velocity.y += data.gravity * delta
		move_body()
		return
	if dodge_time > 0.0:
		dodge_time = maxf(0.0, dodge_time - delta)
		state = &"dodge"
		velocity.y += data.gravity * delta * 0.25
		move_body()
		return
	var can_cancel: bool = attack == null or (data.id == &"kuren" and attack_confirmed)
	if command.dodge and dodge_cooldown <= 0.0 and (on_ground or air_boost_left) and can_cancel:
		_start_dodge(command, on_ground)
		move_body()
		return
	if attack != null:
		attack_time += delta
		if not attack_motion_applied and attack_time >= attack.startup and attack.delivery == &"blink":
			attack_motion_applied = true
			var origin: Vector2 = position
			move_and_collide(Vector2(facing * attack.travel_distance, 0.0))
			previous_position = position
			invulnerable = 0.055
			session.broadcast(&"phase_shift", {"fighter": self, "origin": origin, "position": position})
		if attack_time >= attack.total_time():
			attack = null
		if attack != null:
			state = &"attack"
			if attack.is_active(attack_time) and attack.movement > 0.0:
				velocity.x = facing * attack.movement
			else:
				velocity.x = move_toward(velocity.x, 0.0, (2200.0 if on_ground else 800.0) * delta)
			velocity.y += data.gravity * delta
			move_body()
			return
	if absf(command.move.x) > 0.12:
		facing = signf(command.move.x)
	if jump_buffer > 0.0:
		if command.move.y > 0.55 and on_ground and position.y < -150.0:
			drop_time = 0.26
			set_collision_mask_value(2, false)
			position.y += 12.0
			velocity.y = 220.0
			jump_buffer = 0.0
		elif coyote > 0.0:
			velocity.y = -data.jump_speed
			coyote = 0.0
			jump_buffer = 0.0
			session.broadcast(&"jump", {"fighter": self, "air": false})
		elif jumps_left > 0:
			velocity.y = -data.air_jump_speed
			jumps_left -= 1
			jump_buffer = 0.0
			session.broadcast(&"jump", {"fighter": self, "air": true})
	if not command.jump_held and velocity.y < -500.0:
		velocity.y = maxf(velocity.y, -500.0)
	var gravity_scale: float = 1.0
	if command.move.y > 0.55 and velocity.y > 0.0:
		gravity_scale = 1.7
	elif data.id == &"momo" and command.jump_held and velocity.y > 0.0 and hover_left > 0.0:
		hover_left -= delta
		velocity.y = minf(velocity.y, 100.0)
		gravity_scale = 0.12
	velocity.y = minf(velocity.y + data.gravity * gravity_scale * delta, 1800.0)
	var modifier: ModuleData = shell_definition()
	var acceleration: float = data.acceleration if on_ground else data.air_acceleration
	if modifier:
		acceleration *= modifier.acceleration_scale if on_ground else modifier.air_scale
	var max_speed: float = data.speed * (0.52 if snared > 0.0 else 1.0)
	velocity.x = move_toward(velocity.x, command.move.x * max_speed, acceleration * delta)
	if action_buffer_time > 0.0:
		_start_buffered_attack()
	state = &"attack" if attack else (&"air" if not on_ground else (&"run" if absf(velocity.x) > 40.0 else &"idle"))
	move_body()
	if not on_ground and grounded():
		session.broadcast(&"land", {"fighter": self})

func _buffer_input(command: FighterCommand, delta: float) -> void:
	if hitstop <= 0.0:
		jump_buffer = maxf(0.0, jump_buffer - delta)
	if command.jump_pressed:
		jump_buffer = 0.08
	# Participant hitstop keeps accepted inputs alive until the action clock resumes.
	if hitstop <= 0.0:
		action_buffer_time = maxf(0.0, action_buffer_time - delta)
	if command.light or command.heavy or command.special:
		action_buffer = &"special" if command.special else (&"heavy" if command.heavy else &"light")
		buffered_direction = command.move
		action_buffer_time = 0.1

func _start_buffered_attack() -> void:
	var next: AttackData
	attack_is_special = false
	if action_buffer == &"special":
		var weapon: PartInstance = part(&"weapon_arm")
		if weapon == null or special_cooldown > 0.0:
			return
		next = weapon.definition.attack
		if buffered_direction.y < -0.5 and weapon.definition.up_attack: next = weapon.definition.up_attack
		elif buffered_direction.y > 0.5 and weapon.definition.down_attack: next = weapon.definition.down_attack
		special_cooldown = weapon.definition.cooldown
		attack_is_special = true
	elif action_buffer == &"heavy":
		next = data.uppercut if buffered_direction.y < -0.5 else (data.slam if buffered_direction.y > 0.5 else data.heavy)
		if data.id == &"zero" and absf(buffered_direction.y) <= 0.5:
			if adaptive_mode() == &"SCOPE": next = data.ranged_heavy
			elif adaptive_mode() == &"SYNC": next = data.support_heavy
	else:
		next = data.light
	attack = next
	attack_time = 0.0
	attack_serial += 1
	attack_hits.clear()
	attack_emitted = false
	attack_confirmed = false
	attack_motion_applied = false
	action_buffer_time = 0.0
	invulnerable = 0.0
	session.broadcast(&"attack_start", {"fighter": self, "attack": attack, "special": attack_is_special})

func _start_dodge(command: FighterCommand, grounded: bool) -> void:
	if not grounded and not air_boost_left:
		return
	if not grounded:
		air_boost_left = false
	var direction: float = signf(command.move.x) if absf(command.move.x) > 0.1 else facing
	dodge_time = 0.20
	invulnerable = 0.11
	dodge_cooldown = 0.8
	if shell_definition(): dodge_cooldown *= shell_definition().dodge_cooldown_scale
	attack = null
	velocity = Vector2(direction * (data.speed * 1.35 if grounded else data.air_boost_speed), -110.0 if not grounded else 0.0)
	session.broadcast(&"dodge", {"fighter": self})

func can_be_hit() -> bool:
	return alive() and invulnerable <= 0.0 and not invincible_debug

func armored() -> bool:
	return data.id == &"terra" and attack != null and not attack_is_special and attack.breaker and attack_time < attack.startup and attack_time > 0.065

func apply_hit(source: Fighter, move: AttackData, direction: float) -> void:
	# Eligibility was snapshotted by MatchSession, so valid simultaneous hits can trade.
	if not alive():
		return
	var was_armored: bool = armored() and move.id != &"terra_clinch"
	var preferred: StringName = move.target_slot
	if not equipment.has(preferred):
		preferred = &"shell" if equipment.has(&"shell") else &"weapon_arm"
	var component: PartInstance = part(preferred)
	var shielded: bool = part(&"shell") != null
	var core_damage: float = move.damage * (0.2 if shielded else (1.15 if part(&"weapon_arm") == null else 1.0)) * data.incoming_damage_scale
	if was_armored:
		core_damage *= 0.8
	var old_core: float = core
	core = maxf(1.0 if shielded else 0.0, core - core_damage)
	source.damage_done += old_core - core
	last_attacker = source.slot
	credit_time = 5.0
	contributors[source.slot] = session.elapsed
	if component:
		component.condition = maxf(0.0, component.condition - move.component_damage * session.component_wear_scale)
		if component.condition <= 0.0 and move.breaker:
			session.parts.break_part(self, preferred, Vector2(direction * 430.0, -680.0))
			source.parts_broken += 1
	combo_hits += 1
	combo_window = 0.7
	if not was_armored:
		var resistance: float = data.mass
		if shell_definition():
			resistance *= shell_definition().resistance
		velocity = Vector2(move.knockback.x * direction, move.knockback.y) / resistance
		stun = minf(move.hitstun, 0.42)
		attack = null
		dodge_time = 0.0
		if reserved_part >= 0:
			session.parts.cancel_claim(self)
		if combo_hits >= 4:
			stun = minf(stun, 0.15)
			invulnerable = 0.30
			combo_hits = 0
	hitstop = maxf(hitstop, move.hitstop)
	source.hitstop = maxf(source.hitstop, move.hitstop)
	source.attack_confirmed = true
	session.broadcast(&"hit", {"fighter": self, "source": source, "attack": move, "position": position + Vector2(0, -data.height * 0.55), "armored": was_armored, "shielded": shielded})
	if core <= 0.0:
		session.knock_out(self, source.slot)

func reset_at(point: Vector2) -> void:
	position = point
	previous_position = point
	velocity = Vector2.ZERO
	core = 100.0
	attack = null
	attack_hits.clear()
	attack_motion_applied = false
	state = &"air"
	hitstop = 0.0
	stun = 0.0
	snared = 0.0
	dodge_time = 0.0
	dodge_cooldown = 0.0
	special_cooldown = 0.0
	respawn_time = 0.0
	reserved_part = -1
	attach_time = 0.0
	invulnerable = 1.1
	last_attacker = -1
	credit_time = 0.0
	combo_hits = 0
	combo_window = 0.0
	jump_buffer = 0.0
	action_buffer_time = 0.0
	jumps_left = 1
	air_boost_left = true
	repair_budget = 28.0
	contributors.clear()
