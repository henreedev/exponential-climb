extends Node


const DAMAGE_NUMBER_SCENE = preload("res://scenes/utilities/damage_number.tscn")


func create_damage_number(damage : int, pos : Vector2) -> DamageNumber:
	var damage_number : DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.setup(damage, pos)
	add_child(damage_number)
	return damage_number
