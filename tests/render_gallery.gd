extends SceneTree

var world: Node3D
var camera: Camera3D
var output: String = "res://work/nova-model-review.png"
var frame: int = 0

func _initialize() -> void:
	_setup.call_deferred()

func _setup() -> void:
	root.size = Vector2i(1920, 1080)
	world = Node3D.new()
	root.add_child(world)
	var background := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b6d5e1")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	background.environment = environment
	world.add_child(background)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.65
	camera.position = Vector3(0, 2.7, 15)
	world.add_child(camera)
	var data: MechData = Roster.mech(&"nova")
	var headings: Array[String] = ["NOVA / FRONT", "THREE QUARTER", "EMPTY / EXPOSED", "MOMO + PILE CANNON"]
	for i in range(4):
		var group := Node3D.new()
		group.position.x = -2.9 if i % 2 == 0 else 2.5
		group.position.y = 3.05 if i < 2 else 0.10
		world.add_child(group)
		var mech_data: MechData = Roster.mech(&"momo") if i == 3 else data
		var rig: Node3D = RigFactory.mech(mech_data)
		group.add_child(rig)
		if i == 1:
			rig.rotation.y = -0.55
		elif i == 2:
			rig.rotation.y = 0.25
		if i != 2:
			var weapon: Node3D = RigFactory.module_mesh(Roster.part(&"pile_cannon" if i == 3 else &"arc_blade"))
			weapon.scale = Vector3.ONE / absf(rig.scale.y)
			rig.get_node("WeaponSocket").add_child(weapon)
			var shell: Node3D = RigFactory.module_mesh(Roster.part(mech_data.native_shell))
			rig.get_node("ShellSocket").add_child(shell)
		var platform: MeshInstance3D = RigFactory.cylinder(group, Vector3(0, -0.1, 0), 1.08, 0.15, Color("809aae"))
		var label := Label3D.new()
		label.text = headings[i]
		label.font_size = 56
		label.pixel_size = 0.004
		label.position = Vector3(group.position.x, group.position.y - 0.42, 0)
		label.modulate = Color("15324d")
		label.outline_size = 0
		world.add_child(label)
	var title := Label3D.new()
	title.text = "MECH★POP   /   MODEL & SOCKET REVIEW"
	title.font_size = 78
	title.pixel_size = 0.004
	title.position = Vector3(0, 5.75, 0)
	title.modulate = Color("143650")
	title.outline_size = 0
	world.add_child(title)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(output)
	print("GALLERY CAPTURE: ", ProjectSettings.globalize_path(output))
	quit()
