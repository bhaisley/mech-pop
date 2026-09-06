extends SceneTree
var app: Node
var output: String = "res://captures/pitch"
var claimed: Dictionary = {}
var busy: bool = false
var duration: float = 88.0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="):
			output = argument.trim_prefix("--capture-output=")
		elif argument.begins_with("--capture-seconds="):
			duration = maxf(1.0, argument.trim_prefix("--capture-seconds=").to_float())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	_run.call_deferred()
func _run() -> void:
	app = load("res://ui/app.tscn").instantiate()
	root.add_child(app)
	await _capture("01-title", "Native title UI", 0.1)
	app._select()
	await _capture("02-roster", "Native character-select UI", 0.1)
	app._watch()
	app.session.combat_event.connect(_event)
	await create_timer(duration).timeout
	app.session.combat_event.disconnect(_event)
	app.session.paused = true
	while busy:
		await process_frame
	print("PRESENTATION CAPTURES COMPLETE ", claimed)
	await app._quit_game()
func _event(kind: StringName, data: Dictionary) -> void:
	if busy: return
	if kind == &"part_pop" and not claimed.has("03-part-pop") and data.part.definition.slot == &"weapon_arm":
		_capture("03-part-pop", "Unmodified four-bot gameplay: weapon part breaks", 0.22)
	elif kind == &"core_pop" and not claimed.has("05-core-pop") and absf(data.position.x) < 1050 and data.position.y < 40 and data.position.y > -1050:
		_capture("05-core-pop", "Unmodified four-bot gameplay: onstage Core Pop", 0.075)
func _capture(name: String, description: String, delay: float) -> void:
	claimed[name] = true
	busy = true
	await create_timer(delay).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var file_path: String = output.path_join(name + ".png")
	var error: Error = root.get_texture().get_image().save_png(file_path)
	var metadata: Dictionary = {"description": description, "runtime_source_commit": "63f8ec8dc6649c3baa28dac5c72f17b7c3789a10", "engine": Engine.get_version_info().string, "resolution": root.get_texture().get_size(), "renderer": RenderingServer.get_current_rendering_method(), "debug": false, "forced_gameplay_events": false, "save_error": error}
	if app.session: metadata["elapsed_match_seconds"] = app.session.elapsed
	var file := FileAccess.open(output.path_join(name + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "  "))
	print("CAPTURE ", name, " ", error)
	busy = false
