extends SceneTree

func _initialize() -> void:
	var catalog := {"mechs": {}, "parts": {}, "stages": {}}
	for id in Roster.IDS:
		var m := Roster.mech(id)
		catalog.mechs[id] = {"name": m.display_name.capitalize(), "role": m.role.capitalize(), "description": m.description.replace("\n", " "), "weapon": m.native_weapon, "shell": m.native_shell, "color": "#" + m.color.to_html(false), "energy": "#" + m.energy.to_html(false), "height": m.height, "speed": m.speed}
	for id in Roster.all_modules():
		var part := Roster.part(id)
		catalog.parts[id] = {"name": part.display_name.capitalize(), "short": part.short_name, "donor": part.donor, "slot": part.slot, "max": part.maximum, "color": "#" + part.color.to_html(false), "energy": "#" + part.energy.to_html(false)}
	for id in StageCatalog.IDS:
		var stage := StageCatalog.stage(id)
		var rects := []
		for r in stage.platforms:
			rects.append([r.position.x, r.position.y, r.size.x, r.size.y])
		var data := {"name": stage.display_name.capitalize(), "description": stage.description, "moving_index": stage.moving_index, "platforms": rects}
		for key in ["accent", "deck", "dark", "trim", "sunlight", "ambient"]:
			data[key] = "#" + stage.get(key).to_html(false)
		catalog.stages[id] = data
	var out := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	out.store_string("window.MechCatalog = " + JSON.stringify(catalog, "\t", false) + ";\n")
	out.close()
	quit()
