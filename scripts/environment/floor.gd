extends Node2D

## Manages the rooms generated on a given floor. 
class_name Floor

const ROOM_SCENE = preload("res://scenes/environment/room.tscn")

func _ready():
	seed(1)
	Global.floor = self
	generate_new_room()



func _input(event):
	if event.is_action_pressed("test_generate_new_room"):
		generate_new_room()

func generate_new_room(start_pos := Vector2.ZERO):
	remove_children()
	Room.generate_room(start_pos, self)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("Starting pathfinding")
	Pathfinding.update_graph()
	print("Pathfinding graph created")

func remove_children():
	while get_child_count() >= 1: 
		get_child(0).queue_free() 
		remove_child(get_child(0))
