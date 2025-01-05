extends Resource

class_name RoomInfo

@export var type : Room.Type

var main_path : PathInfo
var side_paths : Array[PathInfo]

@export var start_door_type : Room.Type
@export var start_door_pos : Vector2i

@export var main_door_type : Room.Type
@export var main_door_pos : Vector2i

@export var side_doors_types : Array[Room.Type]
@export var side_doors_positions : Array[Vector2i]
