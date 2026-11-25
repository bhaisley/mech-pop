class_name MechView
extends Node3D

var fighter: Fighter
var rig: Node3D
var head: Node3D
var left_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var weapon_socket: Node3D
var shell_socket: Node3D
var weapon_mesh: Node3D
var shell_mesh: Node3D
var weapon_uid: int = -1
var shell_uid: int = -1
var clock: float = 0.0
var impact: float = 0.0
var snap: float = 0.0
var marker: Label3D
var core_mesh: MeshInstance3D
var core_scale := Vector3.ONE
var flash: ShaderMaterial
var warning_arm: MeshInstance3D
var warning_shell: MeshInstance3D
var energy_ring: MeshInstance3D
var charge_light: MeshInstance3D

func setup(source: Fighter) -> void:
	fighter = source
	rig = RigFactory.mech(fighter.data)
	add_child(rig)
	flash = ShaderMaterial.new()
	flash.shader = load("res://vfx/shaders/hit_flash.gdshader")
	_set_flash(rig)
	head = rig.get_node("Head")
	left_arm = rig.get_node("LeftArm")
	left_leg = rig.get_node("LeftLeg")
	right_leg = rig.get_node("RightLeg")
	weapon_socket = rig.get_node("WeaponSocket")
	shell_socket = rig.get_node("ShellSocket")
	warning_arm = RigFactory.ball(weapon_socket, Vector3(0, 0, 0.3), Vector3(0.23, 0.23, 0.09), Color("ffcd49"), true)
	warning_shell = RigFactory.ball(shell_socket, Vector3(0, 0.15, 0.6), Vector3(0.21, 0.21, 0.06), Color("ffcd49"), true)
	energy_ring = RigFactory.cylinder(self, Vector3(0, 0.08, 0), 0.64, 0.05, fighter.data.energy, true)
	charge_light = RigFactory.ball(self, Vector3(1.4, 1.0, 0.25), Vector3.ONE * 0.10, fighter.data.energy, true)
	charge_light.visible = false
	core_mesh = rig.get_node("Torso/Core")
	core_scale = core_mesh.scale
	marker = Label3D.new()
	marker.text = "▼ %d" % (fighter.slot + 1)
	marker.font_size = 58
	marker.pixel_size = 0.006
	marker.outline_size = 14
	marker.modulate = Roster.PLAYER_COLORS[fighter.slot]
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.position.y = fighter.data.height / 100.0 + 0.65
	add_child(marker)
	_sync_modules()

func _process(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter):
		return
	visible = fighter.alive()
	if not visible:
		return
	var point: Vector2 = fighter.visual_position(delta)
	position = Vector3(point.x / 100.0, -point.y / 100.0, 0)
	_sync_modules()
	if fighter.session.paused:
		return
	clock += delta * (0.05 if fighter.hitstop > 0.0 else 1.0)
	impact = move_toward(impact, 0.0, delta * 6.0)
	flash.set_shader_parameter("amount", maxf(0.0, impact - 0.55) * 1.7)
	var arm_item: PartInstance = fighter.part(&"weapon_arm")
	var shell_item: PartInstance = fighter.part(&"shell")
	warning_arm.visible = arm_item != null and arm_item.is_cracked() and fmod(clock, 0.22) < 0.15
	warning_shell.visible = shell_item != null and shell_item.is_cracked() and fmod(clock, 0.22) < 0.15
	energy_ring.visible = fighter.snared > 0.0
	energy_ring.scale = Vector3.ONE * (1.0 + sin(clock * 13.0) * 0.12)
	charge_light.visible = fighter.attack != null and fighter.attack_time < fighter.attack.startup and fighter.attack.delivery in [&"rail", &"field", &"blink"]
	if charge_light.visible:
		var charging: float = clampf(fighter.attack_time / fighter.attack.startup, 0.0, 1.0)
		var energy: Color = arm_item.definition.energy if arm_item and fighter.attack_is_special else fighter.data.energy
		charge_light.material_override = RigFactory.material(energy, true)
		charge_light.position = Vector3(fighter.facing * (1.3 if fighter.attack.delivery == &"rail" else 0.75), fighter.data.height / 100.0 * 0.57, 0.4)
		charge_light.scale = Vector3.ONE * (0.35 + charging * 1.9 + sin(clock * 55.0) * 0.1)
	if fighter.data.id == &"zero": marker.text = "▼ %d · %s" % [fighter.slot + 1, fighter.adaptive_mode()]
	snap = move_toward(snap, 0.0, delta * 4.0)
	rig.scale.x = absf(rig.scale.x) * fighter.facing
	rig.rotation.y = -0.20
	var running: bool = fighter.state == &"run"
	var stride: float = sin(clock * 20.0) if running else sin(clock * 3.0) * 0.045
	left_leg.rotation.z = stride * 0.45
	right_leg.rotation.z = -stride * 0.45
	left_arm.rotation.z = -stride * 0.38
	weapon_socket.rotation.z = stride * 0.1
	rig.position.y = absf(stride) * (0.055 if running else 0.06)
	rig.rotation.z = -fighter.velocity.x * fighter.facing / 8500.0
	head.rotation.z = -rig.rotation.z * 0.5
	if fighter.state in [&"air", &"hover"]:
		left_leg.rotation.z = -0.38
		right_leg.rotation.z = 0.32
		left_arm.rotation.z = -0.55
		if fighter.data.id == &"lumi":
			left_arm.rotation.z = -0.75
			right_leg.rotation.z = 0.58
	elif fighter.state == &"dodge":
		rig.rotation.z = -0.52
		left_arm.rotation.z = -1.15
	elif fighter.attack:
		var move: AttackData = fighter.attack
		var anticipation: float = clampf(fighter.attack_time / move.startup, 0.0, 1.0)
		var active: bool = fighter.attack_time >= move.startup
		var follow: float = clampf((fighter.attack_time - move.startup - move.active) / move.recovery, 0.0, 1.0)
		var angle: float = lerpf(-0.85 * anticipation, 0.0, follow) if not active else lerpf(1.15, 0.0, follow)
		if fighter.attack_is_special:
			weapon_socket.rotation.z = angle * (0.12 if move.delivery in [&"cannon", &"rail"] else 1.0)
			if move.delivery == &"field":
				weapon_socket.rotation.z = lerpf(-0.3, 0.25, anticipation) if not active else lerpf(0.35, 0.0, follow)
				left_arm.rotation.z = -0.7 * (1.0 - follow)
			elif move.delivery == &"rail":
				left_leg.rotation.z = -0.28
				right_leg.rotation.z = 0.30
				left_arm.rotation.z = -0.50
			elif move.delivery == &"blink":
				left_leg.rotation.z = -0.46
				right_leg.rotation.z = 0.42
				rig.position.y -= 0.08 * anticipation
		else:
			left_arm.rotation.z = angle * 1.4
		rig.rotation.z = (0.12 * anticipation if not active else -0.14 * (1.0 - follow))
	elif fighter.state == &"attach":
		left_arm.rotation.z = -0.9
		weapon_socket.rotation.z = 0.5
	if impact > 0.0:
		rig.rotation.z += sin(impact * 35.0) * impact * 0.14
		head.rotation.z += impact * 0.2
	if snap > 0.0 and weapon_mesh:
		weapon_mesh.position.x = snap * 0.6
	elif weapon_mesh:
		weapon_mesh.position.x = 0.0
	var blinking: bool = fighter.invulnerable > 0.0 and fmod(clock, 0.13) < 0.055
	rig.visible = true
	if blinking:
		flash.set_shader_parameter("amount", maxf(0.28, impact))
	var critical: bool = fighter.part(&"shell") == null
	core_mesh.material_override = RigFactory.material(Color("ef4fe7") if critical else fighter.data.energy, true)
	core_mesh.scale = core_scale * (1.0 + sin(clock * 11.0) * 0.15 if critical else 1.0)
	for eye_name in ["EyeLeft", "EyeRight"]:
		var eye: MeshInstance3D = head.get_node(eye_name)
		eye.scale.y = 0.28 if impact > 0.15 else (0.75 if fighter.attack else 1.0)
		if fmod(clock + fighter.slot * 1.15, 4.6) < 0.10:
			eye.scale.y = 0.06

func _sync_modules() -> void:
	var weapon: PartInstance = fighter.part(&"weapon_arm")
	var shell: PartInstance = fighter.part(&"shell")
	var new_weapon_id: int = weapon.uid if weapon else -1
	var new_shell_id: int = shell.uid if shell else -1
	if new_weapon_id != weapon_uid:
		weapon_uid = new_weapon_id
		if weapon_mesh:
			weapon_mesh.queue_free()
		weapon_mesh = null
		if weapon:
			weapon_mesh = RigFactory.module_mesh(weapon.definition)
			# Module scale is donor-authored; inverse host scale preserves the oversized cannon.
			weapon_mesh.scale = Vector3.ONE / absf(rig.scale.y)
			weapon_socket.add_child(weapon_mesh)
			_set_flash(weapon_mesh)
	if new_shell_id != shell_uid:
		shell_uid = new_shell_id
		if shell_mesh:
			shell_mesh.queue_free()
		shell_mesh = null
		if shell:
			shell_mesh = RigFactory.module_mesh(shell.definition)
			shell_socket.add_child(shell_mesh)
			_set_flash(shell_mesh)

func _set_flash(node: Node) -> void:
	if node is MeshInstance3D and node.name != "InkOutline":
		(node as MeshInstance3D).material_overlay = flash
	for child in node.get_children():
		_set_flash(child)
