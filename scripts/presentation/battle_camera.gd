class_name BattleCamera
extends Camera3D

var session: MatchSession
var shake: float = 0.0
var shake_amount: float = 0.65
var center := Vector2(0, 3.0)
var elapsed: float = 0.0

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	size = 16.0
	position = Vector3(0, 4, 30)
	rotation_degrees.x = -8.0
	current = true

func _process(delta: float) -> void:
	if session == null:
		return
	var low := Vector2(-7.5, 0)
	var high := Vector2(7.5, 7.0)
	for fighter in session.fighters:
		if not fighter.alive():
			continue
		var point := Vector2(clampf(fighter.position.x / 100, -16.5, 16.5), clampf(-fighter.position.y / 100, -6.0, 12.0))
		low = low.min(point)
		high = high.max(point + Vector2(0, fighter.data.height / 100.0))
	var aspect: float = get_viewport().get_visible_rect().size.x / maxf(1.0, get_viewport().get_visible_rect().size.y)
	var stage_width: float = session.stage.definition.camera_width()
	var stage_fit: float = stage_width / aspect
	var wanted_size: float = clampf(maxf((high.x - low.x + 3.8) / aspect, high.y - low.y + 4.5), maxf(13.6, stage_fit), maxf(21.0, stage_fit))
	size = lerpf(size, wanted_size, 1.0 - exp(-delta * (4.5 if wanted_size > size else 1.25)))
	var target: Vector2 = (low + high) * 0.5 + Vector2(0, -0.45)
	var pan_room: float = minf(2.6, maxf(0.0, (size * aspect - stage_width + 1.8) * 0.5))
	target.x = clampf(target.x, -pan_room, pan_room)
	target.y = clampf(target.y, 1.0, 4.8)
	center = center.lerp(target, 1.0 - exp(-delta * 2.5))
	center.x = clampf(center.x, -pan_room, pan_room)
	elapsed += delta
	shake = move_toward(shake, 0.0, delta * 1.7)
	var offset := Vector2(sin(elapsed * 109.0), cos(elapsed * 137.0)) * shake * shake_amount
	position = Vector3(center.x + offset.x, center.y + offset.y + 30.0 * tan(deg_to_rad(8.0)), 30)
