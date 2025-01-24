extends Node2D

## Manages the rooms generated on a given floor. 
class_name Floor

const ROOM_SCENE = preload("res://scenes/environment/room.tscn")

var current_room : Room

func _ready():
	seed(1)
	Global.floor = self
	await get_tree().process_frame
	generate_new_room()



func _input(event):
	if event.is_action_pressed("test_generate_new_room"):
		generate_new_room()

func generate_new_room(start_pos := Vector2.ZERO):
	# Remove previous room
	remove_children()
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	
	# Create the new room, timing how long it takes and printing it
	print("Starting room generation")
	var time = Time.get_ticks_msec()
	current_room = Room.generate_room(start_pos, self)
	print("Room created in ", Time.get_ticks_msec() - time, "ms")
	
	# Room's physics polygons do not exist until 2 frames later. 
	# Pathfinding uses raycasts that rely on them.
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Create the pathfinding graph for this room, timing it
	print("Starting pathfinding")
	time = Time.get_ticks_msec()
	Pathfinding.update_graph()
	print("Pathfinding graph created in ", Time.get_ticks_msec() - time, "ms")

func remove_children():
	while get_child_count() >= 1: 
		get_child(0).queue_free() 
		remove_child(get_child(0))
