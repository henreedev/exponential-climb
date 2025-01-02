extends Node2D

## Manages the rooms generated on a given floor. 
class_name Floor

const ROOM_SCENE = preload("res://scenes/environment/room.tscn")

func _ready():
	Room.generate_room(Vector2(0, 0), Vector2(100, 1020), self)

func _input(event):
	if event.is_action_pressed("jump"): 
		remove_child(get_child(0))
		Room.generate_room(Vector2(0, 0), Vector2(1000, 1200), self)
