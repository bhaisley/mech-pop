class_name PartInstance
extends RefCounted

var uid: int
var definition: ModuleData
var original_owner: int
var carrier: int = -1
var condition: float
var state: StringName = &"equipped"
var drop_reason: StringName = &""
var fresh_coupler: bool = false
var claimed_by: int = -1
var recalled: bool = false
var entity: Node2D

func is_cracked() -> bool:
	return condition <= definition.maximum * 0.25

