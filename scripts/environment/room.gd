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

const BG_ATLAS_COORDS := Vector2i(0, 1)
const WALL_ATLAS_COORDS := Vector2i(1, 1)
const PLATFORM_ATLAS_COORDS := Vector2i(1, 0)

@export var noise : FastNoiseLite

@onready var wall_layer : TileMapLayer = $WallLayer
@onready var bg_layer : TileMapLayer = $BGLayer

## Room is entered through this door, and immediately closes permanently afterwards.
var start_door : Door
## The main path leads to this door.
var main_door : Door
## Contains all level generation details about this room, produced randomly before creating it. 
var info : RoomInfo

## Determines door positions and generates room tiles, returning the new room.
static func generate_room(start_pos : Vector2, attach_to : Node, end_pos : Vector2 = Vector2.INF, type : Type = Type.TEST) -> Room:
	# Generate room info (defines all level generation attributes
	# Generate room based on info
	var room : Room = ROOM_SCENE.instantiate()
	var info : RoomInfo = room.generate_room_info(start_pos, type)
	room.info = info
	room.start_door = DOOR_SCENE.instantiate()
	room.start_door.position = info.start_door_pos
	room.main_door = DOOR_SCENE.instantiate()
	room.main_door.locked = false
	room.main_door.position = info.main_door_pos
	attach_to.add_child(room)
	room.add_child(room.start_door)
	room.add_child(room.main_door)

	room.place_room_tiles()
	
	if Global.player: 
		Global.player.global_position = start_pos

	return room

func generate_room_info(start_pos : Vector2, type : Type = Type.TEST) -> RoomInfo:
	var start_grid_pos := Vector2i(start_pos)
	info = RoomInfo.new()
	info.type = type
	info.start_door_pos = start_grid_pos
	info.start_door_type = type
	match type:
		_: # Generate a typical room
			# Calculate main path
			info.main_path = generate_path(true)
			info.main_door_pos = info.main_path.end
			info.main_door_type = pick_random_door_type()
	return info

func generate_path(is_main : bool) -> PathInfo:
	var path = PathInfo.new()
	# Set path length
	var length = pick_path_length(is_main)
	path.length = length
	# Set path angle
	var angle = randf_range(-PI / 6, PI / 6)
	path.angle = angle
	if is_main:
		path.end = Vector2i(Vector2(info.start_door_pos) + Vector2(length, 0).rotated(angle))
	else: 
		path.end = Vector2.ZERO # FIXME
	path.start = info.start_door_pos
	
	
	var radius_curve = Curve.new()
	# Set max x domain to the number of tiles, so path generator can sample based 
	# on tile number
	var num_tiles = (int(length) / 8.0 + 1)
	radius_curve.max_domain = num_tiles
	radius_curve.max_value = INF
	const MAIN_PATH_RADIUS = 16
	const MAIN_PATH_RADIUS_DEVIATION = 7
	for point in pick_radius_curve_points(randi_range(2,6), MAIN_PATH_RADIUS, MAIN_PATH_RADIUS_DEVIATION, num_tiles, 0.1, 3, 2):
		radius_curve.add_point(point, 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	path.radius_curve = radius_curve
	return path


func pick_path_length(is_main : bool):
	match info.type:
		_:
			if is_main:
				return randf_range(2000, 2500)
			else:
				return randf_range(500, 700)

static func pick_random_door_type():
	return Type.TEST # TODO


static func pick_random_path_radius(radius : float, deviation : float) -> int:
	return int(radius + randf_range(-deviation, deviation))


static func pick_radius_curve_points(num_points : int, radius : int, deviation : int, \
						x_domain : float, random_x_offset_frac : float, narrow_start_to := -1, \
						narrow_end_to := -1) -> Array[Vector2]:
	if narrow_start_to != -1:
		num_points += 1
	if narrow_end_to != -1:
		num_points += 1
	var points : Array[Vector2] = []
	var x_increment = x_domain / num_points
	for i in range(num_points):
		if i == 0 and narrow_start_to != -1: # Narrow start of path
			points.append(Vector2(0, narrow_start_to))
			continue
		if i == num_points - 1 and narrow_end_to != -1: # Narrow end of path
			points.append(Vector2(x_domain, narrow_end_to))
			break
			
		var x_value = x_increment * i
		var rand_x_offset = x_domain * randf_range(-random_x_offset_frac / 2, random_x_offset_frac / 2)
		x_value += rand_x_offset
		var random_radius = pick_random_path_radius(radius, deviation)
		points.append(Vector2(x_value, random_radius))
	print(points)
	return points


func place_room_tiles():
	var start_door_pos := wall_layer.local_to_map(info.start_door_pos)
	var main_door_pos := wall_layer.local_to_map(info.main_door_pos)
	
	var top_left_pos := Vector2i(mini(start_door_pos.x, main_door_pos.x), mini(start_door_pos.y, main_door_pos.y))
	var bottom_right_pos := Vector2i(maxi(start_door_pos.x, main_door_pos.x), maxi(start_door_pos.y, main_door_pos.y))
	# Fill in bg
	const PADDING_TILES := 100
	for x in range(top_left_pos.x - PADDING_TILES, bottom_right_pos.x + PADDING_TILES):
		for y in range(top_left_pos.y - PADDING_TILES, bottom_right_pos.y + PADDING_TILES):
			var coord = Vector2i(x, y)
			bg_layer.set_cell(coord, 0, WALL_ATLAS_COORDS)
	
	var main_path_coords : Array[Vector2i] = TilePath.find_straight_path(wall_layer, info.main_path)
	TilePath.add_noise_to_path(main_path_coords, noise, 20)
	info.main_path.path_core = main_path_coords
	
	# Calculate and store edges
	var main_path_edges : Array = TilePath.find_edges_of_path(main_path_coords, info.main_path.radius_curve)
	
	var main_path_top_edge = main_path_edges[0]
	var main_path_bot_edge = main_path_edges[1]
	var main_path_inside = main_path_edges[2]
	
	info.main_path.top_edge = main_path_top_edge
	info.main_path.bottom_edge = main_path_bot_edge
	info.main_path.inside = main_path_inside
	
	TilePath.add_noise_to_path(main_path_top_edge, noise, 3)
	
	# Carve out path
	for coord in main_path_top_edge:
		wall_layer.set_cell(coord, 0, WALL_ATLAS_COORDS)
	for coord in main_path_bot_edge:
		wall_layer.set_cell(coord, 0, PLATFORM_ATLAS_COORDS)
	for coord in main_path_inside:
		bg_layer.set_cell(coord, 0, BG_ATLAS_COORDS)
		#wall_layer.set_cell(coord + upward_offset, 0, WALL_ATLAS_COORDS)
		#wall_layer.set_cell(coord + downward_offset, 0, WALL_ATLAS_COORDS)
