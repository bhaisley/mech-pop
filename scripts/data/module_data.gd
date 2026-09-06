class_name ModuleData
extends Resource

@export var id: StringName
@export var display_name: String
@export var short_name: String
@export var slot: StringName = &"weapon_arm"
@export var donor: StringName
@export var color: Color
@export var energy: Color
@export var maximum: float = 40.0
@export var cooldown: float = 0.8
@export var action: StringName = &"melee"
@export var attack: AttackData
@export var up_attack: AttackData
@export var down_attack: AttackData
@export var acceleration_scale: float = 1.0
@export var air_scale: float = 1.0
@export var resistance: float = 1.0
@export var hover_bonus: float = 0.0
@export var dodge_cooldown_scale: float = 1.0
