class_name FighterCommand
extends RefCounted

var move: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var jump_held: bool = false
var light: bool = false
var heavy: bool = false
var special: bool = false
var dodge: bool = false
var salvage: bool = false

func copy() -> FighterCommand:
	var result := FighterCommand.new()
	result.move = move
	result.jump_pressed = jump_pressed
	result.jump_held = jump_held
	result.light = light
	result.heavy = heavy
	result.special = special
	result.dodge = dodge
	result.salvage = salvage
	return result
