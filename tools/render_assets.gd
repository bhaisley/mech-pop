extends SceneTree

var studio: SubViewport
var world: Node3D
var camera: Camera3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	studio = SubViewport.new()
	studio.size = Vector2i(1024, 1024)
	studio.own_world_3d = true
	studio.transparent_bg = true
	studio.msaa_3d = Viewport.MSAA_4X
	studio.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(studio)
	world = Node3D.new()
	studio.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	camera.position = Vector3(0.3, 1.12, 10)
	camera.current = true
	world.add_child(camera)
	DirAccess.make_dir_recursive_absolute("res://ui/portraits")
	var selected: Array[StringName] = Roster.IDS.duplicate()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--portraits="):
			selected.clear()
			for id in argument.trim_prefix("--portraits=").split(","):
				if Roster.IDS.has(StringName(id)): selected.append(StringName(id))
	for id in selected:
		camera.size = Roster.mech(id).portrait_size
		camera.position.x = Roster.mech(id).portrait_center_x
		var rig: Node3D = assembled(id, Roster.mech(id).native_weapon, Roster.mech(id).native_shell)
		world.add_child(rig)
		rig.rotation.y = -0.30
		rig.rotation.z = -0.035
		rig.get_node("Head").rotation.z = 0.045
		rig.get_node("LeftArm").rotation.z = 0.3 if id != &"terra" else 0.7
		rig.get_node("WeaponSocket").rotation.z = 0.15 if id == &"terra" else 0.30
		await _capture("res://ui/portraits/%s.png" % id)
		rig.queue_free()
		await process_frame
	if OS.get_cmdline_user_args().has("--portraits-only"):
		print("PORTRAITS COMPLETE: ", selected)
		quit()
		return
	studio.size = Vector2i(3840, 2160)
	studio.transparent_bg = false
	var background := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("c4dce5")
	background.environment = environment
	world.add_child(background)
	camera.size = 12.0
	camera.position = Vector3(0, 5.3, 20)
	for mode in [&"weapon", &"shell"]:
		for row_group in range(2):
			for column_group in range(2):
				await _gallery(mode, row_group, column_group)
	print("PRODUCTION RENDERS COMPLETE: eight portraits and eight 16-fit galleries")
	quit()

func _gallery(mode: StringName, row_group: int, column_group: int) -> void:
	var group := Node3D.new()
	world.add_child(group)
	var parts: Array[StringName] = []
	for id in Roster.IDS: parts.append(Roster.mech(id).native_weapon if mode == &"weapon" else Roster.mech(id).native_shell)
	for row in range(4):
		for col in range(4):
			var data: MechData = Roster.mech(Roster.IDS[row_group * 4 + row])
			var part_id: StringName = parts[column_group * 4 + col]
			var rig: Node3D = assembled(data.id, part_id if mode == &"weapon" else data.native_weapon, part_id if mode == &"shell" else data.native_shell)
			group.add_child(rig)
			rig.position = Vector3(-7.8 + col * 4.6, (3 - row) * 2.85, 0)
			rig.rotation.y = -0.20
			var label := Label3D.new()
			label.text = "%s / %s" % [data.display_name, Roster.part(part_id).short_name]
			label.font_size = 45
			label.pixel_size = 0.005
			label.outline_size = 0
			label.modulate = Color("17374e")
			label.position = rig.position + Vector3(0.4, -0.33, 0)
			group.add_child(label)
	await _capture("res://work/%s-compatibility-%d-%d.png" % [mode, row_group + 1, column_group + 1])
	group.queue_free()
	await process_frame

func assembled(chassis: StringName, weapon: StringName, shell: StringName) -> Node3D:
	var rig: Node3D = RigFactory.mech(Roster.mech(chassis))
	var arm: Node3D = RigFactory.module_mesh(Roster.part(weapon))
	arm.scale = Vector3.ONE / absf(rig.scale.y)
	rig.get_node("WeaponSocket").add_child(arm)
	rig.get_node("ShellSocket").add_child(RigFactory.module_mesh(Roster.part(shell)))
	return rig

func _capture(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = studio.get_texture().get_image()
	var error: Error = image.save_png(path)
	print("RENDER ", path, " ", error)
