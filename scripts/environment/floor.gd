extends Node2D

## Manages the rooms generated on a given floor. 
class_name Floor

signal new_room_generated

const ROOM_SCENE = preload("res://scenes/environment/room.tscn")

@onready var room_seed_label : Label = get_tree().get_first_node_in_group("roomseed")
var current_room : Room
var room_seed : int = -1

func _ready():
	seed(1)
	Global.current_floor = self
	await get_tree().process_frame
	generate_new_room()

func _input(event):
	if event.is_action_pressed("test_generate_same_room"):
		generate_new_room(Vector2.ZERO, room_seed)
	if event.is_action_pressed("test_generate_new_room"):
		generate_new_room()

func generate_new_room(start_pos := Vector2.ZERO, seed := -1):
	# Pick a new seed and display it 
	var new_seed = seed if seed != -1 else randi()
	seed(new_seed)
	room_seed = new_seed
	
	room_seed_label.text = str(room_seed)
	print("Room seed: ", room_seed)
	
	# Remove previous room
	remove_children()
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.queue_free()
	
	# Create the new room, timing how long it takes and printing it
	print("Starting room generation")
	var time = Time.get_ticks_msec()
	current_room = await Room.generate_room(start_pos, self, new_seed)
	print("Room created in ", Time.get_ticks_msec() - time, "ms")
	
	# Let noise visualization know there's been a new room created.
	new_room_generated.emit()

	# Create the pathfinding graph for this room, timing it
	print("Starting pathfinding")
	time = Time.get_ticks_msec()
	Pathfinding.update_graph()
	print("Pathfinding graph created in ", Time.get_ticks_msec() - time, "ms")

func remove_children():
	while get_child_count() >= 1: 
		get_child(0).queue_free() 
		remove_child(get_child(0))
