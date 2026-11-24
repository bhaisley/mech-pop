extends SceneTree

func _initialize() -> void:
	var catalog := {"mechs": {}, "parts": {}, "stages": {}, "moves": {}}
	for id in Roster.IDS:
		var m := Roster.mech(id)
		_record_move(catalog.moves, m.light, "light")
		_record_move(catalog.moves, m.heavy, "heavy")
		_record_move(catalog.moves, m.uppercut, "rise")
		_record_move(catalog.moves, m.slam, "slam")
		_record_move(catalog.moves, m.ranged_heavy, "heavy")
		_record_move(catalog.moves, m.support_heavy, "heavy")
		catalog.mechs[id] = {"name": m.display_name.capitalize(), "role": m.role.capitalize(), "description": m.description.replace("\n", " "), "weapon": m.native_weapon, "shell": m.native_shell, "color": "#" + m.color.to_html(false), "energy": "#" + m.energy.to_html(false), "height": m.height, "speed": m.speed}
	for id in Roster.all_modules():
		var part := Roster.part(id)
		_record_move(catalog.moves, part.attack, "special", id)
		_record_move(catalog.moves, part.up_attack, "rise", id)
		_record_move(catalog.moves, part.down_attack, "slam", id)
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

func _record_move(moves: Dictionary, move: AttackData, kind: String, weapon: StringName = &"") -> void:
	if not move: return
	moves[move.id] = {
		"kind": kind, "weapon": weapon, "delivery": move.delivery, "breaker": move.breaker,
		"startup": move.startup, "active": move.active, "recovery": move.recovery,
		"offset": [move.offset.x / 100.0, -move.offset.y / 100.0],
		"size": [move.size.x / 100.0, move.size.y / 100.0],
		"radius": [move.projectile_radius.x / 100.0, move.projectile_radius.y / 100.0],
	}
