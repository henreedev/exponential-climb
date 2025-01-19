extends Node


const DAMAGE_NUMBER_SCENE = preload("res://scenes/utilities/damage_number.tscn")


func create_damage_number(damage : float, pos : Vector2, damage_color := DamageNumber.DamageColor.DEFAULT) -> DamageNumber:
	var damage_number : DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.setup(damage, pos, damage_color)
	add_child(damage_number)
	return damage_number

func create_debug_number(value : float, pos : Vector2, damage_color := DamageNumber.DamageColor.DEFAULT) -> DamageNumber:
	var damage_number : DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.setup(0, pos, damage_color, true, value)
	add_child(damage_number)
	return damage_number
