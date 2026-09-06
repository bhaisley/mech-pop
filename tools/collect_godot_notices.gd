extends SceneTree
func _initialize() -> void:
	var file := FileAccess.open("res://third_party/GODOT_NOTICES.txt", FileAccess.WRITE)
	file.store_string("Godot Engine " + Engine.get_version_info().string + "\n\n" + Engine.get_license_text() + "\n\n")
	for entry in Engine.get_copyright_info():
		file.store_string("\n" + str(entry.name) + "\n")
		for part in entry.parts:
			file.store_string(str(part) + "\n")
	var licenses: Dictionary = Engine.get_license_info()
	for name in licenses:
		file.store_string("\n\n" + str(name) + "\n" + str(licenses[name]) + "\n")
	print("GODOT NOTICES EXTRACTED FROM PINNED ENGINE")
	quit()
