extends Node2D

## Manages the rooms generated on a given floor. 
class_name Floor

const ROOM_SCENE = preload("res://scenes/environment/room.tscn")

func _ready():
	Room.generate_room(Vector2(0, 0), Vector2(1000, 0), self)

func _input(event):
	if event.is_action_pressed("jump"):
		get_child(0).queue_free() 
		get_child(1).queue_free() 
		get_child(2).queue_free() 
		remove_child(get_child(0))
		remove_child(get_child(0))
		remove_child(get_child(0))
		var rand_start = Vector2.ZERO
		var rand_end = Vector2(1000, 0)
		Room.generate_room(rand_start, rand_end, self)
