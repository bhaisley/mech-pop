class_name SalvageBody
extends CharacterBody2D

var part: PartInstance
var lifetime: float = 14.0
var age: float = 0.0
var spin: float = 0.0
var settled: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 3
	floor_snap_length = 8.0
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	collision.shape = circle
	collision.position.y = -22.0
	add_child(collision)

func step(delta: float) -> void:
	age += delta
	lifetime -= delta
	if part.state == &"claimed":
		return
	velocity.y = minf(velocity.y + 1800.0 * delta, 1300.0)
	velocity.x = move_toward(velocity.x, 0.0, (1000.0 if is_on_floor() else 60.0) * delta)
	move_and_slide()
	settled = is_on_floor()
	if not settled:
		spin += delta * 4.0

