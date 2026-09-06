extends SceneTree

func _initialize() -> void:
	var scripts: Array[String] = ["res://scripts/app.gd", "res://scripts/combat/match_session.gd", "res://scripts/presentation/battle_view.gd"]
	for path in scripts:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("COMPILE FAILED: ", path)
			quit(1)
			return
	for id in Roster.IDS:
		assert(Roster.mech(id) != null)
	for id in Roster.all_modules():
		assert(Roster.part(id) != null)
	print("COMPILE PASS: scripts and all authored combat resources")
	quit()
