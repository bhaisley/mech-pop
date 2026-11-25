class_name AttackData
extends Resource

@export var id: StringName = &"light"
@export var startup: float = 0.06
@export var active: float = 0.07
@export var recovery: float = 0.18
@export var damage: float = 9.0
@export var component_damage: float = 8.0
@export var hitstun: float = 0.18
@export var hitstop: float = 0.04
@export var knockback: Vector2 = Vector2(440.0, -270.0)
@export var offset: Vector2 = Vector2(82.0, -92.0)
@export var size: Vector2 = Vector2(145.0, 78.0)
@export var breaker: bool = false
enum Ejection { FORWARD, RISE, DROP }
@export var ejection: Ejection = Ejection.FORWARD
@export var target_slot: StringName = &"weapon_arm"
@export var movement: float = 0.0
@export var feedback: StringName = &"light"
@export var delivery: StringName = &"melee"
@export var travel_distance: float = 0.0
@export var projectile_speed: Vector2 = Vector2.ZERO
@export var projectile_lifetime: float = 1.0
@export var phase_delay: float = 0.0
@export var projectile_radius: Vector2 = Vector2(48, 34)
@export var piercing: bool = false

func total_time() -> float:
	return startup + active + recovery

func ejection_velocity(direction: float) -> Vector2:
	match ejection:
		Ejection.RISE: return Vector2(direction * 115.0, -1020.0)
		Ejection.DROP: return Vector2(-direction * 105.0, 440.0)
		_: return Vector2(direction * 690.0, -350.0)

func is_active(time: float) -> bool:
	return time >= startup and time < startup + active

func hit_rect(origin: Vector2, facing: float) -> Rect2:
	return Rect2(origin + Vector2(offset.x * facing, offset.y) - size * 0.5, size)
