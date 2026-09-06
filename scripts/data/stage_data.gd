class_name StageData
extends Resource

@export var id: StringName = &"skyport"
@export var display_name: String = "SKYPORT"
@export var subtitle: String = "HIGH-SKY SCRAP PARTY"
@export var description: String = "Open decks and a drifting transit platform."
@export var platforms: Array[Rect2] = []
@export var spawns: Array[Vector2] = []
@export var moving_index: int = 3
@export var moving_amplitude: Vector2 = Vector2(300, 0)
@export var moving_speed: float = 0.24
@export var blast_bounds: Rect2 = Rect2(-1880, -1800, 3760, 2620)
@export var accent: Color = Color("3bccd5")
@export var deck: Color = Color("e7f4f5")
@export var dark: Color = Color("213b59")
@export var trim: Color = Color("ffcd55")
@export var sky_top: Color = Color("317faf")
@export var sky_horizon: Color = Color("bde7ea")
@export var ambient: Color = Color("cce7f1")
@export var sunlight: Color = Color("fff0d5")
@export var music: String = "res://audio/music/sky-port.wav"
@export var matte: String = "res://stages/skyport/skyport-matte.png"

func floor_rect() -> Rect2:
	return platforms[0]

func half_width() -> float:
	return floor_rect().size.x * 0.5

func camera_width() -> float:
	var bounds: Rect2 = platforms[0]
	for index in range(platforms.size()):
		var rect: Rect2 = platforms[index]
		if index == moving_index:
			rect = rect.grow_individual(absf(moving_amplitude.x), 0.0, absf(moving_amplitude.x), 0.0)
		bounds = bounds.merge(rect)
	return bounds.size.x / 100.0 + 2.2
