extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app: Node = load("res://ui/app.tscn").instantiate()
	root.add_child(app)
	app.router.touch_enabled = true
	app.router.assign_device(0, PlayerInputRouter.TOUCH)
	app._start_match()
	await create_timer(12.0).timeout
	app.session.paused = true
	await process_frame
	# Keep the touch overlay visible for this clearly labeled layout preview.
	app.touch_controls.active = true
	app.touch_controls.visible = true
	app.touch_controls.set_process(false)
	app.touch_controls.queue_redraw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/ipad-layout-preview.png")
	print("TABLET LAYOUT PREVIEW: Mac rendering at an iPad aspect ratio; not a physical-device test.")
	await app._quit_game()
