class_name RigFactory
extends RefCounted

static var materials: Dictionary = {}
static var toon_materials: Dictionary = {}
static var outline_material: ShaderMaterial
static var packed_models: Dictionary = {}

static func production_model(path: String, root_name: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	if not packed_models.has(path):
		packed_models[path] = load(path)
	var wrapper: Node3D = (packed_models[path] as PackedScene).instantiate()
	var model: Node3D = wrapper if wrapper.name == root_name else wrapper.find_child(root_name, true, false) as Node3D
	if model == null:
		model = wrapper
	elif model != wrapper:
		model.get_parent().remove_child(model)
		wrapper.free()
	_apply_production_materials(model)
	return model

static func _apply_production_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for i in range(instance.mesh.get_surface_count()):
			var original: Material = instance.mesh.surface_get_material(i)
			if original is StandardMaterial3D:
				var standard := original as StandardMaterial3D
				var color: Color = standard.albedo_color
				var glow: bool = standard.emission_enabled
				var key: String = color.to_html() + str(glow)
				if not toon_materials.has(key):
					var toon := ShaderMaterial.new()
					toon.shader = load("res://vfx/shaders/mech_toon.gdshader")
					toon.set_shader_parameter("base_color", color)
					toon.set_shader_parameter("luminous", glow)
					toon_materials[key] = toon
				instance.set_surface_override_material(i, toon_materials[key])
		if outline_material == null:
			outline_material = ShaderMaterial.new()
			outline_material.shader = load("res://vfx/shaders/mech_outline.gdshader")
		var hull := MeshInstance3D.new()
		hull.name = "InkOutline"
		hull.mesh = instance.mesh
		hull.material_override = outline_material
		hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.add_child(hull)
	for child in node.get_children():
		if child.name != "InkOutline":
			_apply_production_materials(child)

static func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + str(glow)
	if not materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.65
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
		if glow:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 1.4
		materials[key] = mat
	return materials[key]

static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material(color, glow)
	instance.position = at
	parent.add_child(instance)
	return instance

static func ball(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.radius = 0.5
	mesh.height = 1.0
	instance.mesh = mesh
	instance.scale = size
	instance.position = at
	instance.material_override = material(color, glow)
	parent.add_child(instance)
	return instance

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, glow: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material(color, glow)
	parent.add_child(instance)
	return instance

static func pivot(parent: Node3D, name: String, at: Vector3) -> Node3D:
	var result := Node3D.new()
	result.name = name
	result.position = at
	parent.add_child(result)
	return result

static func mech(data: MechData) -> Node3D:
	var production: Node3D = production_model("res://characters/models/%s.glb" % data.id, "Rig")
	if production:
		production.scale = Vector3.ONE * (data.height / data.authored_height)
		return production
	# This rig is the simulation/attachment blockout. Production meshes replace its named pivots.
	var root := Node3D.new()
	root.name = "Rig"
	var ink := Color("152238")
	var white := Color("edf5ff")
	var color: Color = data.color
	var torso: Node3D = pivot(root, "Torso", Vector3(0, 0.87, 0))
	box(torso, Vector3.ZERO, Vector3(0.66, 0.64, 0.44), ink)
	var core: MeshInstance3D = ball(torso, Vector3(0, 0.03, 0.27), Vector3(0.29, 0.29, 0.12), data.energy, true)
	core.name = "Core"
	var head: Node3D = pivot(root, "Head", Vector3(0, 1.52, 0.02))
	ball(head, Vector3.ZERO, Vector3(1.0, 0.76, 0.68), white if data.id == &"nova" else color)
	ball(head, Vector3(0, -0.025, 0.31), Vector3(0.79, 0.42, 0.16), ink)
	for side in [-1, 1]:
		var eye: MeshInstance3D = box(head, Vector3(side * 0.19, 0.005, 0.405), Vector3(0.22, 0.085, 0.035), data.energy, true)
		eye.name = "EyeLeft" if side < 0 else "EyeRight"
		var fin: MeshInstance3D
		match data.id:
			&"nova":
				fin = box(head, Vector3(side * 0.5, 0.2, -0.07), Vector3(0.13, 0.61, 0.31), color)
				fin.rotation.z = side * -0.42
			&"kuren":
				fin = box(head, Vector3(side * 0.48, 0.12, 0.02), Vector3(0.3, 0.47, 0.35), color)
				fin.rotation.z = side * 0.45
			&"terra":
				box(head, Vector3(side * 0.5, -0.03, 0), Vector3(0.24, 0.47, 0.63), color.darkened(0.18))
			&"momo":
				fin = ball(head, Vector3(side * 0.29, 0.54, 0), Vector3(0.2, 0.54, 0.21), white)
				fin.rotation.z = side * -0.3
	for side in [-1, 1]:
		var leg: Node3D = pivot(root, "LeftLeg" if side < 0 else "RightLeg", Vector3(side * 0.24, 0.54, 0))
		box(leg, Vector3(0, -0.11, 0), Vector3(0.2, 0.38, 0.25), ink)
		ball(leg, Vector3(0, -0.31, 0.11), Vector3(0.4, 0.38, 0.53), white if data.id == &"nova" else color)
	var left: Node3D = pivot(root, "LeftArm", Vector3(-0.49, 1.03, 0))
	ball(left, Vector3.ZERO, Vector3(0.32, 0.35, 0.37), color)
	box(left, Vector3(0, -0.24, 0), Vector3(0.22, 0.32, 0.25), ink)
	ball(left, Vector3(0, -0.39, 0.08), Vector3(0.34, 0.35, 0.34), white if data.id == &"nova" else color)
	pivot(root, "WeaponSocket", Vector3(0.49, 0.98, 0.08))
	pivot(root, "ShellSocket", Vector3(0, 0.96, 0))
	root.scale = Vector3.ONE * (data.height / 195.0)
	if data.id == &"terra":
		root.scale.x *= 1.18
	return root

static func module_mesh(definition: ModuleData) -> Node3D:
	var production: Node3D = production_model("res://modules/models/%s.glb" % definition.id, "Module")
	if production:
		return production
	var root := Node3D.new()
	var color: Color = definition.color
	var ink := Color("152238")
	if definition.slot == &"shell":
		box(root, Vector3(0, 0, 0.25), Vector3(0.69, 0.4, 0.12), color)
		for side in [-1, 1]:
			var armor: MeshInstance3D = box(root, Vector3(side * 0.45, 0.17, -0.06), Vector3(0.43, 0.36, 0.55), color)
			if definition.id == &"fin_plate":
				armor.rotation.z = side * 0.3
			elif definition.id == &"bulwark":
				armor.scale = Vector3(1.45, 1.25, 1.25)
		ball(root, Vector3(0, 0, 0.33), Vector3(0.15, 0.15, 0.04), definition.energy, true)
		return root
	ball(root, Vector3.ZERO, Vector3(0.34, 0.34, 0.34), ink)
	match definition.id:
		&"arc_blade":
			box(root, Vector3(0.14, -0.14, 0), Vector3(0.4, 0.42, 0.4), color)
			var blade: MeshInstance3D = box(root, Vector3(0.67, 0.04, 0.08), Vector3(1.07, 0.095, 0.16), definition.energy, true)
			blade.rotation.z = 0.24
		&"burst_knuckle":
			box(root, Vector3(0.27, -0.06, 0.02), Vector3(0.73, 0.61, 0.61), color)
			for i in range(3):
				box(root, Vector3(0.64, -0.06 + (i - 1) * 0.15, 0.04), Vector3(0.08, 0.09, 0.46), definition.energy, true)
		&"pile_cannon":
			box(root, Vector3(0.26, 0.0, 0), Vector3(0.71, 0.69, 0.65), color)
			var barrel: MeshInstance3D = cylinder(root, Vector3(0.82, 0.0, 0), 0.27, 1.15, ink)
			barrel.rotation.z = PI / 2.0
			var muzzle: MeshInstance3D = cylinder(root, Vector3(1.38, 0.0, 0), 0.33, 0.19, color)
			muzzle.rotation.z = PI / 2.0
			var glow: MeshInstance3D = cylinder(root, Vector3(1.485, 0.0, 0), 0.19, 0.015, definition.energy, true)
			glow.rotation.z = PI / 2.0
		&"halo_caster":
			ball(root, Vector3(0.22, -0.1, 0), Vector3(0.6, 0.6, 0.55), color)
			var halo := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.2
			torus.outer_radius = 0.31
			halo.mesh = torus
			halo.material_override = material(definition.energy, true)
			halo.position = Vector3(0.45, 0.25, 0)
			halo.rotation.z = PI / 2.0
			root.add_child(halo)
	return root
