class_name StageView
extends Node3D

var session: MatchSession
var definition: StageData
var ferry: Node3D
var traffic: Array[Node3D] = []
var fans: Array[Node3D] = []
var clock: float = 0.0
var backdrop: MeshInstance3D
var IVORY := Color("e7f4f5")
var NAVY := Color("213b59")
var TEAL := Color("3bccd5")
var YELLOW := Color("ffcd55")

func setup(match_session: MatchSession) -> void:
	session = match_session
	definition = session.stage.definition
	IVORY = definition.deck
	NAVY = definition.dark
	TEAL = definition.accent
	YELLOW = definition.trim
	process_priority = 10
	_lighting()
	_city()
	for i in range(definition.platforms.size()):
		var rect: Rect2 = definition.platforms[i]
		var platform := Node3D.new()
		platform.position = Vector3(rect.get_center().x / 100.0, -rect.position.y / 100.0, 0)
		add_child(platform)
		if i == definition.moving_index:
			ferry = platform
		_platform(platform, rect.size.x / 100.0, i)
	if definition.id != &"skyport":
		_arena_props()
		return
	for side in [-1, 1]:
		var station := Node3D.new()
		station.position = Vector3(side * 13.8, -2.8, -9.0)
		add_child(station)
		RigFactory.cylinder(station, Vector3(0, -4, 0), 2.7, 7.0, Color("7dabbc"))
		RigFactory.cylinder(station, Vector3(0, -0.2, 0), 3.5, 0.4, IVORY)
		RigFactory.cylinder(station, Vector3(0, 0.04, 0), 2.3, 0.14, Color("648c88"))
		_tree(station, Vector3(0, 0.1, 0), 1.2)
		_tree(station, Vector3(side * 1.5, 0.1, -0.8), 0.65)
		RigFactory.box(station, Vector3(0, 0.8, -1.4), Vector3(3.2, 0.15, 0.12), IVORY)

func _lighting() -> void:
	var world_environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = definition.sky_top
	sky_material.sky_horizon_color = definition.sky_horizon
	sky_material.sky_curve = 0.35
	sky_material.ground_bottom_color = definition.sky_top
	sky_material.ground_horizon_color = definition.sky_horizon
	sky_material.sun_angle_max = 8.0
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = definition.ambient
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.1
	world_environment.environment = env
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-51, -24, -12)
	sun.light_color = definition.sunlight
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

func _platform(root: Node3D, width: float, index: int) -> void:
	var depth: float = 3.8 if index == 0 else 2.1
	# Collision and top surface share the same authoritative anchor.
	RigFactory.box(root, Vector3(0, -0.20, 0), Vector3(width, 0.4, depth), IVORY)
	RigFactory.box(root, Vector3(0, -0.53, -0.12), Vector3(width - 0.5, 0.35, depth - 0.3), NAVY)
	RigFactory.box(root, Vector3(0, -0.81, -0.25), Vector3(width - 1.1, 0.22, depth - 0.6), NAVY.lightened(0.16))
	RigFactory.box(root, Vector3(0, -0.03, depth / 2.0 + 0.02), Vector3(width, 0.11, 0.08), TEAL, true)
	RigFactory.box(root, Vector3(0, 0.012, 0), Vector3(width - 0.3, 0.018, 0.16), NAVY.lightened(0.15))
	for i in range(int(width)):
		var x: float = float(i) - width / 2.0 + 0.5
		RigFactory.box(root, Vector3(x, 0.018, 0), Vector3(0.016, 0.024, depth - 0.1), IVORY.darkened(0.16))
		if i % 2 == 0:
			RigFactory.box(root, Vector3(x, -0.51, depth / 2.0 - 0.08), Vector3(0.58, 0.12, 0.07), TEAL.lightened(0.22), true)
	for side in [-1, 1]:
		RigFactory.box(root, Vector3(side * (width / 2.0 - 0.2), 0.016, 0), Vector3(0.25, 0.04, depth), YELLOW, true)
		RigFactory.box(root, Vector3(side * (width / 2.0 - 0.38), -0.43, depth / 2.0), Vector3(0.52, 0.38, 0.16), YELLOW)
		if index < 3:
			var booster: Node3D = RigFactory.pivot(root, "Thruster%d" % side, Vector3(side * (width * 0.34), -1.0, -0.12))
			RigFactory.cylinder(booster, Vector3.ZERO, 0.45, 0.42, NAVY)
			RigFactory.cylinder(booster, Vector3(0, -0.22, 0), 0.34, 0.08, TEAL, true)
			var fan: Node3D = RigFactory.pivot(booster, "Fan", Vector3(0, -0.28, 0))
			for blade in range(3):
				var leaf: MeshInstance3D = RigFactory.box(fan, Vector3.ZERO, Vector3(0.8, 0.025, 0.12), TEAL.lightened(0.36), true)
				leaf.rotation.y = float(blade) * TAU / 3.0
			fans.append(fan)
	if index == 0:
		_sign(root, "MECH / POP     •     " + definition.display_name, Vector3(0, -0.54, depth / 2.0 + 0.02), 0.0035, Color("c9e9e9"))
		for side in [-1, 1]:
			for i in range(4):
				var chevron: MeshInstance3D = RigFactory.box(root, Vector3(side * (width * 0.38 - i * 0.3), 0.03, 1.0), Vector3(0.13, 0.02, 0.45), YELLOW)
				chevron.rotation.y = side * -0.35
	else:
		_sign(root, "TRANSIT" if index == definition.moving_index else "0%d" % index, Vector3(0, -0.51, depth / 2.0 + 0.02), 0.003, IVORY)

func _city() -> void:
	backdrop = MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(48, 27)
	backdrop.mesh = plane
	var matte := StandardMaterial3D.new()
	matte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if ResourceLoader.exists(definition.matte): matte.albedo_texture = load(definition.matte)
	else: matte.albedo_color = definition.sky_horizon
	backdrop.material_override = matte
	backdrop.position = Vector3(0, -2.5, -48)
	backdrop.rotation_degrees.x = -8.0
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)
	if definition.id != &"skyport": return
	for i in range(4):
		var craft := Node3D.new()
		craft.position = Vector3(i * 14.0 - 22, 1.8 + i * 1.4, -10 - i * 2.0)
		craft.scale = Vector3.ONE * 0.65
		RigFactory.ball(craft, Vector3.ZERO, Vector3(2.8, 0.48, 0.68), Color("e6f3ef"), true)
		RigFactory.box(craft, Vector3(0.12, 0.035, 0.35), Vector3(1.95, 0.15, 0.05), Color("70a9bb"), true)
		RigFactory.box(craft, Vector3(-0.9, 0.3, 0), Vector3(0.09, 0.35, 0.25), Color("e6f3ef"), true)
		RigFactory.ball(craft, Vector3(-1.4, -0.05, 0), Vector3(0.34, 0.12, 0.3), Color("a1edeb"), true)
		add_child(craft)
		traffic.append(craft)

func _tree(parent: Node3D, at: Vector3, height: float) -> void:
	var tree: Node3D = RigFactory.pivot(parent, "CloudTree", at)
	RigFactory.cylinder(tree, Vector3(0, height * 0.5, 0), 0.10, height, Color("71989b"))
	RigFactory.ball(tree, Vector3(0, height * 1.2, 0), Vector3(height * 1.5, height, height * 1.5), Color("72c9b4"))
	RigFactory.ball(tree, Vector3(height * 0.4, height, 0.2), Vector3(height, height * 0.8, height), Color("97d9be"))

func _sign(parent: Node3D, message: String, at: Vector3, pixel_size: float, color: Color) -> void:
	var sign := Label3D.new()
	sign.text = message
	sign.font = load("res://ui/fonts/BarlowCondensed-Bold.ttf")
	sign.font_size = 70
	sign.pixel_size = pixel_size
	sign.outline_size = 0
	sign.modulate = color
	sign.position = at
	parent.add_child(sign)

func _process(delta: float) -> void:
	_compose_backdrop()
	if session == null or session.paused:
		return
	clock += delta
	var moving_rect: Rect2 = session.stage.platform_rect(definition.moving_index)
	ferry.position = Vector3(moving_rect.get_center().x / 100.0, -moving_rect.position.y / 100.0, 0)
	for i in range(traffic.size()):
		traffic[i].position.x = fmod(clock * (0.36 + i * 0.15) + i * 15.0, 70.0) - 35.0
	for fan in fans:
		fan.rotation.y += delta * 8.0

func _compose_backdrop() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or backdrop == null:
		return
	# Preserve the painted city/ring composition when combat zoom changes.
	# The old fixed 48-unit plane cropped away both skyline edges.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(viewport_size.y, 1.0)
	var plane: QuadMesh = backdrop.mesh
	plane.size = Vector2(camera.size * aspect, camera.size) * 1.045
	backdrop.global_basis = camera.global_basis
	backdrop.global_position = camera.global_position - camera.global_basis.z * 78.0
	var pan := Vector2(camera.position.x, camera.position.y - 7.2) * -0.055
	backdrop.global_position += camera.global_basis.x * pan.x + camera.global_basis.y * pan.y

func _arena_props() -> void:
	match definition.id:
		&"neon_alley":
			for side in [-1, 1]:
				var tower: Node3D = RigFactory.pivot(self, "NeonTower", Vector3(side * 15.8, -3.2, -13.0))
				RigFactory.box(tower, Vector3(0, 3, 0), Vector3(3.8, 13, 5), NAVY)
				for floor_index in range(7):
					var y: float = float(floor_index) * 1.6 - 2.0
					RigFactory.box(tower, Vector3(0, y, 2.55), Vector3(3.7, 0.14, 0.08), TEAL if floor_index % 2 else YELLOW, true)
				RigFactory.box(tower, Vector3(side * -1.5, 5.4, 2.75), Vector3(0.85, 4.6, 0.25), YELLOW)
				_sign(tower, "P\nO\nP", Vector3(side * -1.5, 5.4, 2.9), 0.011, NAVY)
			_sign(ferry, "NIGHT SHIFT", Vector3(0, -0.56, 1.16), 0.003, TEAL)
		&"junk_fields":
			for side in [-1, 1]:
				var crane: Node3D = RigFactory.pivot(self, "SalvageCrane", Vector3(side * 18.8, -2, -12))
				RigFactory.box(crane, Vector3(0, 5, 0), Vector3(0.8, 15, 0.8), YELLOW)
				RigFactory.box(crane, Vector3(-side * 3.0, 12.4, 0), Vector3(6.6, 0.6, 0.7), YELLOW)
				RigFactory.box(crane, Vector3(-side * 5.6, 8.5, 0), Vector3(0.055, 7.5, 0.055), NAVY)
				RigFactory.cylinder(crane, Vector3(-side * 5.6, 4.6, 0), 0.42, 0.45, NAVY)
				RigFactory.cylinder(crane, Vector3(-side * 5.6, 4.32, 0), 0.62, 0.18, IVORY.darkened(0.2))
				for stack in range(3):
					RigFactory.box(crane, Vector3(side * float(stack), -1.2 + stack * 0.7, 2), Vector3(2.8, 1.3, 2.0), IVORY.darkened(stack * 0.12))
		&"blossom_core":
			for side in [-1, 1]:
				var garden: Node3D = RigFactory.pivot(self, "BlossomGarden", Vector3(side * 17.8, -4.5, -12))
				garden.scale = Vector3.ONE * 0.64
				RigFactory.cylinder(garden, Vector3(0, -1, 0), 3.2, 2.0, IVORY)
				RigFactory.cylinder(garden, Vector3(0, 0.05, 0), 2.9, 0.2, TEAL.darkened(0.2))
				RigFactory.cylinder(garden, Vector3(0, 3, 0), 0.32, 6.0, NAVY)
				for petal in range(7):
					var angle: float = float(petal) * TAU / 7.0
					RigFactory.ball(garden, Vector3(cos(angle) * 1.8, 5.4 + sin(angle * 2) * 0.6, sin(angle) * 1.4), Vector3(3.4, 2.5, 2.8), YELLOW.lightened(float(petal % 3) * 0.12))
				RigFactory.ball(garden, Vector3(0, 6.1, 0), Vector3(3.4, 2.6, 3.4), YELLOW.lightened(0.2))
		&"reactor_ring":
			for layer in range(3):
				var ring := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 6.8 + float(layer) * 1.1
				torus.outer_radius = torus.inner_radius + 0.07
				torus.rings = 64
				torus.ring_segments = 8
				ring.mesh = torus
				ring.position = Vector3(0, 5.7, -15.0 - float(layer) * 1.5)
				ring.rotation_degrees.x = 90.0
				ring.material_override = RigFactory.material(NAVY.lerp(TEAL, 0.24 if layer % 2 else 0.13))
				add_child(ring)
			for side in [-1, 1]:
				var coil: Node3D = RigFactory.pivot(self, "ReactorCoil", Vector3(side * 15.2, -1.0, -10))
				RigFactory.cylinder(coil, Vector3(0, 3.0, 0), 0.7, 7, NAVY)
				for band in range(7): RigFactory.cylinder(coil, Vector3(0, float(band), 0), 1.0, 0.15, TEAL, true)
