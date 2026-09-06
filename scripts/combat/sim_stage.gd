class_name SimStage
extends Node2D

var definition: StageData
var ferry: AnimatableBody2D
var ferry_offset := Vector2.ZERO
var elapsed: float = 0.0
var moving_enabled: bool = true

func _ready() -> void:
	if definition == null: definition = StageCatalog.stage(&"skyport")
	for i in range(definition.platforms.size()):
		var rect: Rect2 = definition.platforms[i]
		var body: PhysicsBody2D
		if i == definition.moving_index:
			ferry = AnimatableBody2D.new()
			ferry.sync_to_physics = false
			body = ferry
		else:
			body = StaticBody2D.new()
		body.collision_layer = 1 if i == 0 else 2
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		shape.one_way_collision = i > 0
		shape.one_way_collision_margin = 12.0
		body.add_child(shape)
		add_child(body)

func step(delta: float) -> void:
	elapsed += delta
	set_motion(sin(elapsed * definition.moving_speed) * definition.moving_amplitude if moving_enabled else Vector2.ZERO)

func set_motion(offset: Vector2) -> void:
	ferry_offset = offset
	if ferry: ferry.position = definition.platforms[definition.moving_index].get_center() + offset

func platform_rect(index: int) -> Rect2:
	var rect: Rect2 = definition.platforms[index]
	if index == definition.moving_index: rect.position += ferry_offset
	return rect

func spawn_point(slot: int) -> Vector2:
	return definition.spawns[slot]

func is_outside(point: Vector2) -> bool:
	return not definition.blast_bounds.has_point(point)

func safe_salvage_point(point: Vector2) -> Vector2:
	var floor: Rect2 = definition.floor_rect()
	return Vector2(clampf(point.x, floor.position.x + 250.0, floor.end.x - 250.0), floor.position.y - 95.0)
