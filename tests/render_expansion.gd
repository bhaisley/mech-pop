extends SceneTree

var app: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	app = load("res://ui/app.tscn").instantiate()
	root.add_child(app)
	app.router.pause_requested.disconnect(app._pause)
	app.selections.assign([&"shadow", &"lumi", &"kai", &"zero"])
	app._select()
	await _capture("expansion-select")
	app._arena_menu()
	await _capture("expansion-arenas")
	app.router.devices.assign([-2, -2, -2, -2])
	for id in StageCatalog.IDS:
		app.selected_stage = id
		app._create_match({"stage": String(id), "skip_intro": true})
		await create_timer(3.0).timeout
		app.session.paused = true
		await _capture("arena-" + String(id))
		print("ARENA_VISUAL ", JSON.stringify({"id": id, "fighters": app.selections, "events": app.session.event_counts, "conservation_errors": app.session.parts.conservation_errors()}))
	app._title()
	root.size = Vector2i(1180, 820)
	app._select()
	await _capture("expansion-select-tablet-layout-on-mac")
	app._arena_menu()
	await _capture("expansion-arenas-tablet-layout-on-mac")
	app._title()
	await process_frame
	print("EXPANSION VISUAL CAPTURES COMPLETE")
	app._quit_game()

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://work/%s.png" % name)
	print("CAPTURE ", name, " ", error)
