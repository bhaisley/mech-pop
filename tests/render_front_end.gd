extends SceneTree
var app: Node
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	app = load("res://ui/app.tscn").instantiate()
	root.add_child(app)
	await _capture("title")
	app._network_menu()
	await _capture("network-connect")
	var local_devices: Array[int] = [PlayerInputRouter.KEYBOARD]
	app.network.host(24888, local_devices, "NEON42")
	await _capture("network-room")
	app._title()
	app._select()
	await _capture("select")
	app._page(&"controls")
	await _capture("controls")
	app._page(&"settings")
	await _capture("settings")
	app._page(&"credits")
	await _capture("credits")
	app._watch()
	await create_timer(1.0).timeout
	await _capture("intro")
	await create_timer(12.0).timeout
	app.session.paused = true
	await _capture("battle")
	app._show(&"pause")
	await _capture("pause")
	app._results()
	await _capture("results")
	app._title()
	await process_frame
	print("FRONT END RENDERS COMPLETE")
	app._quit_game()
func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png("res://work/screen-%s.png" % name)
	print("CAPTURE ", name, " ", result)
