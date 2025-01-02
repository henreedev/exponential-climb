extends Node

class_name Room

enum Type {
	TEST, 
	WAVE_COMBAT, 
	MINIBOSS_COMBAT, 
	EXPLORATION, 
	PUZZLE, 
	MOVEMENT_CHALLENGE,
}

const ROOM_SCENE = preload("res://scenes/environment/room.tscn")
const DOOR_SCENE = preload("res://scenes/environment/door.tscn")

const BG_ATLAS_COORDS := Vector2i(0, 1)
const WALL_ATLAS_COORDS := Vector2i(1, 1)
const PLATFORM_ATLAS_COORDS := Vector2i(1, 0)

@onready var wall_layer : TileMapLayer = $WallLayer
@onready var bg_layer : TileMapLayer = $BGLayer

## Room is entered through this door, and immediately closes permanently afterwards.
var start_door : Door
## The main path leads to this door.
var main_path_door : Door

## Determines door positions and generates room tiles, returning the new room.

static func generate_room(start_pos : Vector2, end_pos : Vector2, attach_to : Node) -> Room:
	var room : Room = ROOM_SCENE.instantiate()
	var _start_door : Door = DOOR_SCENE.instantiate()
	room.start_door = _start_door
	room.start_door.position = start_pos
	room.main_path_door = DOOR_SCENE.instantiate()
	room.main_path_door.position = end_pos
	attach_to.add_child(room)
	
	room.generate_room_tiles()
	
	return room


func generate_room_tiles():
	var start_door_pos := wall_layer.local_to_map(start_door.position)
	var main_path_door_pos := wall_layer.local_to_map(main_path_door.position)
	
	for x in range(start_door_pos.x - 10, main_path_door_pos.x + 10):
		for y in range(start_door_pos.y - 10, main_path_door_pos.y + 10):
			var coord = Vector2i(x, y)
			bg_layer.set_cell(coord, 0, BG_ATLAS_COORDS)
	
	var main_path : Array[Vector2i] = TilePath.find_path(wall_layer, start_door_pos, main_path_door_pos)
	#print(main_path)
	const RADIUS = 3
	
	var upward_offset = Vector2i(0, -RADIUS)
	var downward_offset = Vector2i(0, RADIUS)
	
	for coord in main_path:
		bg_layer.set_cell(coord, 0, BG_ATLAS_COORDS)
		wall_layer.set_cell(coord + upward_offset, 0, WALL_ATLAS_COORDS)
		wall_layer.set_cell(coord + downward_offset, 0, WALL_ATLAS_COORDS)
