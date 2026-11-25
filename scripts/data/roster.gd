class_name Roster
extends RefCounted

const IDS: Array[StringName] = [&"nova", &"kuren", &"terra", &"momo", &"shadow", &"lumi", &"kai", &"zero", &"rivet", &"kite", &"rook", &"coda"]
const PLAYER_COLORS: Array[Color] = [Color("57caff"), Color("ff687f"), Color("c8eb57"), Color("ff9ee0")]
static var _mechs: Dictionary = {}
static var _modules: Dictionary = {}
static var _portraits: Dictionary = {}

static func mech(id: StringName) -> MechData:
	if not _mechs.has(id):
		_mechs[id] = load("res://characters/%s.tres" % id)
	return _mechs[id] as MechData

static func part(id: StringName) -> ModuleData:
	if not _modules.has(id):
		_modules[id] = load("res://modules/%s.tres" % id)
	return _modules[id] as ModuleData

static func all_modules() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in IDS: ids.append(mech(id).native_weapon)
	for id in IDS: ids.append(mech(id).native_shell)
	return ids

static func portrait(id: StringName) -> Texture2D:
	if not _portraits.has(id):
		var path: String = "res://ui/portraits/%s.png" % id
		if ResourceLoader.exists(path): _portraits[id] = load(path)
	return _portraits.get(id) as Texture2D
