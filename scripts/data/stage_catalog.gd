class_name StageCatalog
extends RefCounted

const IDS: Array[StringName] = [&"skyport", &"neon_alley", &"junk_fields", &"blossom_core", &"reactor_ring"]
static var _stages: Dictionary = {}

static func stage(id: StringName) -> StageData:
	assert(IDS.has(id), "Unknown arena identifier")
	if not _stages.has(id): _stages[id] = load("res://stages/%s.tres" % id)
	return _stages[id] as StageData
