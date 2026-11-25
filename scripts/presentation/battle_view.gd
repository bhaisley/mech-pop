class_name BattleView
extends Node3D

var session: MatchSession
var camera: BattleCamera
var mechs: Array[MechView] = []
var loose_views: Dictionary = {}
var projectile_views: Dictionary = {}
var effects: Array[Dictionary] = []

func setup(match_session: MatchSession) -> void:
	session = match_session
	var stage := StageView.new()
	add_child(stage)
	stage.setup(session)
	camera = BattleCamera.new()
	camera.session = session
	add_child(camera)
	for fighter in session.fighters:
		var view := MechView.new()
		add_child(view)
		view.setup(fighter)
		mechs.append(view)
	session.combat_event.connect(_on_event)

func _process(delta: float) -> void:
	if session == null:
		return
	var valid: Dictionary = {}
	for body in session.parts.loose:
		var uid: int = body.part.uid
		valid[uid] = true
		if not loose_views.has(uid):
			var root := Node3D.new()
			var mesh: Node3D = RigFactory.module_mesh(body.part.definition)
			mesh.name = "Part"
			root.add_child(mesh)
			var ring: MeshInstance3D = RigFactory.cylinder(root, Vector3(0, -0.08, 0), 0.57, 0.035, Color("ffdc56"), true)
			ring.name = "Ring"
			var label := Label3D.new()
			label.name = "Label"
			label.text = "◆ " + body.part.definition.short_name
			label.font_size = 38
			label.pixel_size = 0.006
			label.outline_size = 10
			label.modulate = Color("ffdf6b")
			label.position.y = 0.83
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			root.add_child(label)
			add_child(root)
			loose_views[uid] = root
		var root: Node3D = loose_views[uid]
		root.position = Vector3(body.position.x / 100.0, -body.position.y / 100.0 + 0.28, 0.25)
		root.get_node("Part").rotation.z = body.spin if not body.settled else sin(body.age * 2.5) * 0.08
		root.get_node("Ring").visible = body.settled
		root.get_node("Label").visible = body.settled
		root.visible = body.lifetime > 2.0 or fmod(body.lifetime, 0.24) > 0.08
	for uid in loose_views.keys():
		if not valid.has(uid):
			loose_views[uid].queue_free()
			loose_views.erase(uid)
	valid.clear()
	for projectile in session.projectiles:
		var uid: int = projectile.uid
		valid[uid] = true
		if not projectile_views.has(uid):
			var root := Node3D.new()
			var color: Color = projectile.source.data.energy
			if projectile.type == &"cannon":
				color = Color("dfff87")
			elif projectile.type == &"rail": color = Color("93edff") if projectile.attack.id == &"rail_shot" else Color("ff91a8")
			elif projectile.type == &"field": color = Color("ffe39a") if projectile.attack.id == &"prism_zone" else Color("ff809c")
			if projectile.type in [&"cannon", &"rail"]:
				RigFactory.ball(root, Vector3.ZERO, Vector3(0.88, 0.31, 0.31), Color.WHITE, true)
				RigFactory.ball(root, Vector3(-projectile.facing * 0.7, 0, -0.01), Vector3(2.3 if projectile.type == &"rail" else 1.6, 0.12 if projectile.type == &"rail" else 0.21, 0.2), color, true)
			elif projectile.type == &"field":
				var ring: MeshInstance3D = _ring(root, color, projectile.attack.projectile_radius.x / 100.0)
				ring.rotation = Vector3(PI / 2, 0, 0)
				for side in [-1, 1]:
					var prism: MeshInstance3D = RigFactory.box(root, Vector3(side * 0.55, 0, 0), Vector3(0.24, 0.24, 0.16), color, true)
					prism.rotation.z = PI / 4
			else:
				var halo: MeshInstance3D = _ring(root, color, 0.48)
				halo.rotation.x = 0.5
				if projectile.type == &"repair":
					RigFactory.ball(root, Vector3.ZERO, Vector3(0.35, 0.27, 0.28), Color("f7fbff"), true)
			add_child(root)
			projectile_views[uid] = root
		projectile_views[uid].position = Vector3(projectile.position.x / 100.0, -projectile.position.y / 100.0 + 0.15, 0.3)
		if projectile.type == &"field": projectile_views[uid].rotation.z = projectile.age * 2.5
	for uid in projectile_views.keys():
		if not valid.has(uid):
			projectile_views[uid].queue_free()
			projectile_views.erase(uid)
	if session.paused:
		return
	for effect in effects.duplicate():
		effect.life -= delta
		var node: Node3D = effect.node
		node.position += effect.velocity * delta
		node.scale *= 1.0 + delta * float(effect.get("grow", 0.0))
		node.rotation.z += delta * float(effect.get("spin", 0.0))
		if effect.life <= 0.0:
			node.queue_free()
			effects.erase(effect)

func _on_event(kind: StringName, payload: Dictionary) -> void:
	if kind == &"hit":
		if payload.get("armored", false):
			var guard_color: Color = payload.fighter.data.energy
			var toward := signf(payload.source.position.x - payload.fighter.position.x)
			var face: Vector2 = payload.position + Vector2(toward * 47.0, 0)
			var rim := _ring(self, guard_color, 0.86)
			rim.position = Vector3(face.x / 100.0, -face.y / 100.0, 1.1)
			rim.scale.x = 0.57
			effects.append({"node": rim, "life": 0.32, "velocity": Vector3.ZERO, "grow": 1.1})
			burst(face, guard_color, 7, 0.24)
			return
		if payload.get("shielded", false):
			burst(payload.position, payload.fighter.data.energy, 3, 0.14)
		mechs[payload.fighter.slot].impact = 1.0
		camera.shake = minf(0.15, camera.shake + (0.065 if payload.attack.breaker else 0.025))
		burst(payload.position, Color.WHITE, 7 if payload.attack.breaker else 4, 0.18)
		if payload.attack.breaker:
			shockwave(payload.position, payload.source.data.energy, 0.28, 0.4)
	elif kind == &"part_pop":
		burst(payload.position, Color("ffdb54"), 11, 0.36)
		callout(payload.position, "POP!", Color("ffdf55"), 0.7)
		shockwave(payload.position, Color("ffdc54"), 0.44, 0.6)
		camera.shake = maxf(camera.shake, 0.13)
	elif kind == &"core_pop":
		burst(payload.position, payload.fighter.data.energy, 22, 0.65)
		callout(payload.position, "CORE POP!", Color("ffabf5"), 1.0)
		camera.shake = 0.22
		shockwave(payload.position, payload.fighter.data.energy, 0.65, 1.1)
		shockwave(payload.position, Color.WHITE, 0.38, 0.4)
	elif kind == &"snap":
		mechs[payload.fighter.slot].snap = 1.0
		callout(payload.fighter.position + Vector2(0, -200), "SNATCH!" if payload.stolen else "SNAP!", Color("ffdf55"), 0.7)
		burst(payload.fighter.position + Vector2(40, -100), Color("ffdf55"), 6, 0.28)
	elif kind == &"attack_active":
		if payload.attack.delivery not in [&"cannon", &"rail", &"field"]:
			var fighter: Fighter = payload.fighter
			var hit: Rect2 = payload.attack.hit_rect(fighter.position, fighter.facing)
			slash(hit.get_center(), fighter.data.energy, fighter.facing, payload.attack.breaker or payload.special)
		else:
			burst(payload.fighter.position + Vector2(payload.fighter.facing * 150, -100), payload.fighter.data.energy, 8, 0.2)
	elif kind == &"phase_shift":
		var tint: Color = Color("dc82ff")
		for index in range(3):
			var point: Vector2 = payload.origin.lerp(payload.position, float(index) / 3.0)
			burst(point + Vector2(0, -80), tint, 3, 0.18)
		shockwave(payload.position + Vector2(0, -75), tint, 0.22, 0.45)
	elif kind == &"jump" or kind == &"dodge":
		burst(payload.fighter.position + Vector2(0, -15), payload.fighter.data.energy, 4, 0.18)
	elif kind == &"land":
		burst(payload.fighter.position, Color("d7ebed"), 3, 0.15)

func burst(point: Vector2, color: Color, count: int, life: float) -> void:
	for i in range(count):
		if effects.size() >= 140:
			break
		var mesh := MeshInstance3D.new()
		var shape := PrismMesh.new()
		shape.size = Vector3(0.09, 0.45 if life > 0.2 else 0.28, 0.05)
		mesh.mesh = shape
		mesh.material_override = RigFactory.material(color, true)
		var angle: float = float(i) / float(count) * TAU + float(session.tick % 13) * 0.14
		mesh.position = Vector3(point.x / 100.0, -point.y / 100.0, 1.0)
		mesh.rotation.z = angle - PI / 2.0
		add_child(mesh)
		effects.append({"node": mesh, "life": life, "velocity": Vector3(cos(angle), sin(angle), 0) * (4.5 if life > 0.2 else 2.8), "grow": -1.5})

func callout(point: Vector2, message: String, color: Color, life: float) -> void:
	var label := Label3D.new()
	label.text = message
	label.font = load("res://ui/fonts/BarlowCondensed-BlackItalic.ttf")
	label.font_size = 92
	label.pixel_size = 0.01
	label.outline_size = 22
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(point.x / 100.0, -point.y / 100.0 + 0.5, 1.1)
	add_child(label)
	effects.append({"node": label, "life": life, "velocity": Vector3(0, 0.85, 0), "grow": 0.0})

func _ring(parent: Node3D, color: Color, radius: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := TorusMesh.new()
	shape.inner_radius = radius * 0.90
	shape.outer_radius = radius
	shape.rings = 32
	shape.ring_segments = 6
	mesh.mesh = shape
	mesh.material_override = RigFactory.material(color, true)
	mesh.rotation.x = PI / 2.0
	parent.add_child(mesh)
	return mesh

func shockwave(point: Vector2, color: Color, life: float, radius: float) -> void:
	var ring: MeshInstance3D = _ring(self, color, radius)
	ring.position = Vector3(point.x / 100, -point.y / 100, 1.1)
	effects.append({"node": ring, "life": life, "velocity": Vector3.ZERO, "grow": 5.5})

func slash(point: Vector2, color: Color, facing: float, heavy: bool) -> void:
	var mesh := MeshInstance3D.new()
	var shape := ImmediateMesh.new()
	shape.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius: float = 1.0 if heavy else 0.63
	for i in range(14):
		var a: float = lerpf(-1.5, 1.35, float(i) / 14.0)
		var b: float = lerpf(-1.5, 1.35, float(i + 1) / 14.0)
		var thickness: float = sin(float(i + 1) / 15.0 * PI) * 0.35
		var inner: float = radius * (1.0 - thickness)
		var p := Vector3(cos(a) * facing, sin(a), 0)
		var q := Vector3(cos(b) * facing, sin(b), 0)
		for vertex in [p * inner, p * radius, q * radius, p * inner, q * radius, q * inner]:
			shape.surface_add_vertex(vertex)
	shape.surface_end()
	mesh.mesh = shape
	var mat: StandardMaterial3D = RigFactory.material(color, true).duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = mat
	mesh.position = Vector3(point.x / 100, -point.y / 100, 1.0)
	add_child(mesh)
	effects.append({"node": mesh, "life": 0.16 if heavy else 0.1, "velocity": Vector3(facing * 1.7, 0, 0), "grow": 1.7, "spin": -facing * 4.0})
