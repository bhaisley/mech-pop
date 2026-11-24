extends PlayerInputRouter

# The page owns the keyboard, touch pointers and Gamepad API. Each physics
# tick reads held axes and consumes the button presses for this player.
var page: JavaScriptObject

func _ready() -> void:
	set_process_input(false)

func command_for(slot: int) -> FighterCommand:
	var result := FighterCommand.new()
	if page == null: return result
	var bits := int(page.readInput(devices[slot]))
	result.move = Vector2(((bits & 255) - 127) / 127.0, (((bits >> 8) & 255) - 127) / 127.0)
	result.jump_held = bool(bits & (1 << 16))
	result.jump_pressed = bool(bits & (1 << 17))
	result.light = bool(bits & (1 << 18))
	result.heavy = bool(bits & (1 << 19))
	result.special = bool(bits & (1 << 20))
	result.dodge = bool(bits & (1 << 21))
	result.salvage = bool(bits & (1 << 22))
	return result

func clear_state() -> void:
	super()
	if page: page.clearInputs()
