extends Node

func _ready():
	Weapon.weapon_type_to_scene[Weapon.Type.GRAPPLE_HOOK] = load("res://scenes/weapons/grapple_hook/grapple_hook.tscn")
	Weapon.weapon_type_to_scene[Weapon.Type.BOOTS] = load("res://scenes/weapons/boots/boots.tscn")
	queue_free()
