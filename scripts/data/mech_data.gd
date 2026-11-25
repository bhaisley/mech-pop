class_name MechData
extends Resource

@export var id: StringName = &"nova"
@export var display_name: String = "NOVA"
@export var role: String = "BALANCED"
@export var quote: String = "Precision in every strike."
@export_multiline var description: String = "Quick blade arcs. Clean movement.\nA little bit of everything."
@export var authored_height: float = 292.0
@export var face_region: Rect2 = Rect2(190, 230, 440, 440)
@export var portrait_size: float = 2.9
@export var portrait_center_x: float = 0.3
@export var incoming_damage_scale: float = 1.0
@export var color: Color = Color("2875ef")
@export var energy: Color = Color("54e8ff")
@export var height: float = 180.0
@export var width: float = 77.0
@export var mass: float = 1.0
@export var speed: float = 780.0
@export var acceleration: float = 6400.0
@export var air_acceleration: float = 2800.0
@export var gravity: float = 2400.0
@export var jump_speed: float = 1360.0
@export var air_jump_speed: float = 1150.0
@export var air_boost_speed: float = 1260.0
@export var air_jumps: int = 1
@export var pickup_reach: float = 150.0
@export var ground_brace: float = 1.0
@export var fast_fall: float = 1.7
@export var native_weapon: StringName = &"arc_blade"
@export var native_shell: StringName = &"fin_plate"
@export var light: AttackData
@export var heavy: AttackData
@export var uppercut: AttackData
@export var slam: AttackData
@export var ranged_heavy: AttackData
@export var support_heavy: AttackData
