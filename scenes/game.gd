extends Node2D

class_name Game

## Caches the world, so that RoomGenerator's thread doesn't try to get it. 
@onready var world_2d: World2D = get_world_2d()

func _ready() -> void:
	Global.game = self
