extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app: Node = load("res://ui/app.tscn").instantiate()
	root.add_child(app)
	app._network_menu()
	for size in [Vector2i(1440, 810), Vector2i(1180, 820)]:
		root.size = size
		for internet in [false, true]:
			app._network_mode(internet)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/rooms-%s-%s.png" % ["internet" if internet else "lan", "mac" if size.x == 1440 else "tablet-layout-on-mac"])
	app._quit_game()
