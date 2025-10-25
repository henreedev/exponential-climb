extends Node

## DamageNumbers
## Handles the instantiation of DamageNumber objects. 

const DAMAGE_NUMBER_SCENE = preload("res://scenes/utilities/damage_number.tscn")

func create_damage_number(damage : int, pos : Vector2, damage_color := DamageNumber.DamageColor.DEFAULT) -> DamageNumber:
	var damage_number : DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.setup(damage, pos, damage_color)
	Global.game.add_child(damage_number)
	return damage_number

func create_debug_number(value : float, pos : Vector2, damage_color := DamageNumber.DamageColor.DEFAULT) -> DamageNumber:
	var damage_number : DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.setup(0, pos, damage_color, true, value)
	Global.game.add_child(damage_number)
	return damage_number

func create_debug_string(string : String, pos : Vector2, damage_color := DamageNumber.DamageColor.DEFAULT) -> DamageNumber:
	var damage_number : DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.setup(0, pos, damage_color, true, 0.0, string)
	Global.game.add_child(damage_number)
	return damage_number
