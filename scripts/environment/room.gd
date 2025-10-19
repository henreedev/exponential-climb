extends Node2D

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
const CHEST_SCENE = preload("res://scenes/environment/chest.tscn")

const BG_ATLAS_COORDS := Vector2i(0, 1)
const WALL_ATLAS_COORDS := Vector2i(1, 1)
const PLATFORM_ATLAS_COORDS := Vector2i(1, 0)
const TERRAIN_WALL_INSIDE_ATLAS_COORDS := Vector2i(1, 1)


@export var terrain_noise : FastNoiseLite
const terrain_noise_scale := 1.0
const terrain_noise_threshold = 0.1
const terrain_noise_distortion_vec := Vector2(0.5, 2.0)

@export var tunnel_noise : FastNoiseLite
const tunnel_noise_scale := 1.0
const tunnel_noise_threshold := 0.8

@export var map_edge_noise : FastNoiseLite
const map_edge_noise_sample_scale := 3
const map_edge_noise_strength := 5
const map_edge_base_thickness := 6

@onready var wall_layer : TileMapLayer = $WallLayer
@onready var bg_layer : TileMapLayer = $BGLayer

## Room is entered through this door, and immediately closes permanently afterwards.
var start_door : Door
## The main path leads to this door.
var main_door : Door
## Contains all level generation details about this room, produced randomly before creating it. 
var info : RoomInfo

## Determines door positions and generates room tiles, returning the new room.
static func generate_room(start_pos : Vector2i, attach_to : Node, rng_seed : int, x_bounds := Vector2i(-150, 150), y_bounds := Vector2i(-150, 150), type : Type = Type.TEST) -> Room:
	# Generate room based on info
	var room : Room = ROOM_SCENE.instantiate()
	# Set random seed for noise gens
	room.map_edge_noise.seed = rng_seed
	room.terrain_noise.seed = rng_seed
	room.tunnel_noise.seed = rng_seed
	var room_info : RoomInfo = room.generate_room_info(start_pos, type)
	room.info = room_info
	room.start_door = DOOR_SCENE.instantiate()
	room.main_door = DOOR_SCENE.instantiate()
	room.add_child(room.start_door)
	room.add_child(room.main_door)
	
	room.add_child(Chest.create(room_info.start_door_pos + Vector2i.LEFT * 100, 0.0))
	room.start_door.global_position = room_info.start_door_pos
	room.main_door.global_position = room_info.main_door_world_pos
	room.main_door.locked = false
	attach_to.add_child(room)
	
	# Begin procedural generation
	# Clear old map
	room.clear_tiles()
	
	# Determine bounds in world tile coords by shifting relative bounds by the start pos
	var room_x_bounds = Vector2i(x_bounds.x + start_pos.x, x_bounds.y + start_pos.x)
	var room_y_bounds = Vector2i(y_bounds.x + start_pos.y, y_bounds.y + start_pos.y)
	
	# Generate map edges (top, bottom, left, right walls)
	room.generate_edges(room_x_bounds, room_y_bounds)
	
	# Generate basic terrain 
	room.generate_terrain(room_x_bounds, room_y_bounds)
	# TODO Add tunnels
	
	if Global.player: 
		Global.player.global_position = start_pos
	
	return room

func generate_room_info(start_pos : Vector2, type : Type = Type.TEST) -> RoomInfo:
	var start_grid_pos := Vector2i(start_pos)
	info = RoomInfo.new()
	info.type = type
	info.start_door_pos = start_grid_pos
	info.start_door_type = type
	info.main_door_world_pos = info.start_door_pos + Vector2i.RIGHT * 150
	#match type:
		#_: # Generate a typical room
			# Calculate main path
			# TODO
			#info.main_door_world_pos = info.main_path.end
			#info.main_door_type = pick_random_door_type()
	return info


static func pick_random_door_type():
	return Type.TEST # TODO

func clear_tiles():
	wall_layer.clear()
	bg_layer.clear()

func generate_edges(x_bounds : Vector2i, y_bounds : Vector2i):
	# The terrain tiles to be placed at the end.
	var wall_cells : Array[Vector2i] = []
	
	var left = x_bounds.x
	var right = x_bounds.y
	var top = y_bounds.x
	var bottom = y_bounds.y
	
	# Calculate left edge wall tiles.
	# Traverse vertically, calculating how many tiles off of the left edge to add horizontally.
	var left_noise_sample_x : int = left + map_edge_base_thickness
	for y in range(top, bottom + 1): # Include bottom
		var scaled_sample_vec := Vector2(left_noise_sample_x, y) * map_edge_noise_sample_scale
		var noise_val = map_edge_noise.get_noise_2dv(scaled_sample_vec)
		
		var edge_height: int = map_edge_base_thickness + noise_val * map_edge_noise_strength
		for x in range(left, left + edge_height):
			wall_cells.append(Vector2i(x, y))
	
	# Calculate right edge wall tiles.
	# Traverse vertically, calculating how many tiles off of the right edge to add horizontally.
	var right_noise_sample_x : int = right - map_edge_base_thickness
	for y in range(top, bottom + 1): # Include bottom
		var scaled_sample_vec := Vector2(right_noise_sample_x, y) * map_edge_noise_sample_scale
		var noise_val = map_edge_noise.get_noise_2dv(scaled_sample_vec)
		
		var edge_height: int = map_edge_base_thickness + noise_val * map_edge_noise_strength
		for x in range(right - edge_height, right):
			wall_cells.append(Vector2i(x, y))
	
	# Calculate top edge wall tiles.
	# Traverse vertically, calculating how many tiles off of the top edge to add horizontally.
	var top_noise_sample_y : int = top + map_edge_base_thickness
	for x in range(left, right + 1): # Include right
		var scaled_sample_vec := Vector2(x, top_noise_sample_y) * map_edge_noise_sample_scale
		var noise_val = map_edge_noise.get_noise_2dv(scaled_sample_vec)
		
		var edge_height: int = map_edge_base_thickness + noise_val * map_edge_noise_strength
		for y in range(top, top + edge_height):
			wall_cells.append(Vector2i(x, y))
	
	# Calculate bottom edge wall tiles.
	# Traverse vertically, calculating how many tiles off of the bottom edge to add horizontally.
	var bottom_noise_sample_y : int = bottom + map_edge_base_thickness
	for x in range(left, right + 1): # Include right
		var scaled_sample_vec := Vector2(x, bottom_noise_sample_y) * map_edge_noise_sample_scale
		var noise_val = map_edge_noise.get_noise_2dv(scaled_sample_vec)
		
		var edge_height: int = map_edge_base_thickness + noise_val * map_edge_noise_strength
		for y in range(bottom - edge_height, bottom):
			wall_cells.append(Vector2i(x, y))
	
	# Fill in edge walls
	var time = Time.get_ticks_msec()
	#for coord in wall_cells:
		#wall_layer.set_cell(coord, 1, TERRAIN_WALL_INSIDE_ATLAS_COORDS)
	print("Set down edge tiles in ", Time.get_ticks_msec() - time, " ms")
	
	time = Time.get_ticks_msec()
	wall_layer.set_cells_terrain_connect(wall_cells, 0, 0)
	print("Connected edge terrain in ", Time.get_ticks_msec() - time, " ms")


func generate_terrain(x_bounds : Vector2i, y_bounds : Vector2i):
	# The terrain tiles to be placed at the end.
	var wall_cells : Array[Vector2i] = []
	
	# Sample terrain noise for general terrain shape 
	for x in range(x_bounds.x, x_bounds.y + 1):
		for y in range(y_bounds.x, y_bounds.y + 1):
			var scaled_sample_vec = Vector2(x, y) * terrain_noise_scale * terrain_noise_distortion_vec
			var noise_val = terrain_noise.get_noise_2dv(scaled_sample_vec)
			if noise_val >= terrain_noise_threshold:
				wall_cells.append(Vector2i(x, y))
	
	
	# Add tunnels to terrain
	for x in range(x_bounds.x, x_bounds.y + 1):
		for y in range(y_bounds.x, y_bounds.y + 1):
			var scaled_sample_vec = Vector2(x, y) * tunnel_noise_scale * terrain_noise_distortion_vec
			# NOTE negating tunnel noise because i want to use black parts of ping pong noise
			var noise_val = tunnel_noise.get_noise_2dv(scaled_sample_vec) * -1 
			if noise_val >= tunnel_noise_threshold:
				wall_cells.erase(Vector2i(x, y))
	
	# Set camera limits FIXME disabled for easier testing
	var top_left_pos := Vector2i(x_bounds.x, y_bounds.x)
	var bottom_right_pos := Vector2i(x_bounds.y, y_bounds.y)
	#var world_top_left_pos = wall_layer.map_to_local(top_left_pos) - Vector2(4, 4)
	#var world_bottom_right_pos = wall_layer.map_to_local(bottom_right_pos) - Vector2(4, 4)
	#Global.player.camera.limit_left = world_top_left_pos.x
	#Global.player.camera.limit_top = world_top_left_pos.y
	#Global.player.camera.limit_right = world_bottom_right_pos.x
	#Global.player.camera.limit_bottom = world_bottom_right_pos.y
	
	#const PADDING_TILES := 1
	#var expansion = Vector2i(PADDING_TILES, PADDING_TILES)
	#top_left_pos -= expansion
	#bottom_right_pos += expansion
	
	# Fill in tilemap background
	var time = Time.get_ticks_msec()
	for y in range(top_left_pos.y, bottom_right_pos.y):
		for x in range(top_left_pos.x, bottom_right_pos.x):
			var coord = Vector2i(x, y)
			bg_layer.set_cell(coord, 0, BG_ATLAS_COORDS)
	# Fill in walls
	#for coord in wall_cells:
		#wall_layer.set_cell(coord, 1, TERRAIN_WALL_INSIDE_ATLAS_COORDS)

	print("Set down tiles in ", Time.get_ticks_msec() - time, " ms")
	time = Time.get_ticks_msec()
	wall_layer.set_cells_terrain_connect(wall_cells, 0, 0)
	print("Connected terrain in ", Time.get_ticks_msec() - time, " ms")
