extends SceneTree

var app: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	app = load("res://ui/app.tscn").instantiate()
	root.add_child(app)
	app.network.start_match_requested.disconnect(app._network_start_match)
	app.network.start_match_requested.connect(_load_after_delay)

func _load_after_delay(config: Dictionary, remote: bool) -> void:
	await create_timer(4.5).timeout
	if app.network.active:
		print("NETWORK_DELAYED_LOAD ", JSON.stringify({"seconds": 4.5, "round": config.round}))
		app._network_start_match(config, remote)
