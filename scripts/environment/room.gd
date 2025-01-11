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
const TERRAIN_WALL_INSIDE_ATLAS_COORDS := Vector2i(1, 1)

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
	room.main_door = DOOR_SCENE.instantiate()
	room.add_child(room.start_door)
	room.add_child(room.main_door)
	room.start_door.global_position = info.start_door_pos
	room.main_door.global_position = info.main_door_world_pos
	room.main_door.locked = false
	attach_to.add_child(room)

	room.place_room_tiles()
	
	if Global.player: 
		Global.player.global_position = start_pos
		#Global.player.global_position = Vector2.ZERO
		Global.enemy.global_position = start_pos

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
			info.main_door_world_pos = info.main_path.end
			info.main_door_type = pick_random_door_type()
			
			# Calculate side paths, which branch randomly off of the main path
			#for i in range(randi_range(2, 4)): # FIXME
				#var side_path = generate_path(false)
				#info.side_paths.append(side_path) 
	return info

func generate_path(is_main : bool) -> PathInfo:
	var path = PathInfo.new()
	# Set path length
	var length = pick_path_length(is_main)
	path.length = length
	# Set path angle
	if is_main:
		var angle = randf_range(-PI, PI)
		path.angle = angle
	
		path.start = info.start_door_pos
		path.end = Vector2i(Vector2(info.start_door_pos) + Vector2(length, 0).rotated(angle))
	else: 
		var start_on_top_edge = randf() > 0.5
		var random_angle_offset = randf_range(-PI / 4, PI / 4)
		if start_on_top_edge:
			# Pick a tile along the top of the main path, using its position as the start
			path.start = info.main_path.top_edge.pick_random() * Vector2i(8, 8)
			# Pick an angle perpendicular to main path angle 
			path.angle = info.main_path.angle - PI / 2 + random_angle_offset
		else:
			# Pick a tile along the top of the main path, using its position as the start
			path.start = info.main_path.bottom_edge.pick_random() * Vector2i(8, 8)
			# Pick an angle perpendicular to main path angle 
			path.angle = info.main_path.angle + PI / 2 + random_angle_offset
		# Place endpoint using start and angle
		path.end = path.start + Vector2i(Vector2(length, 0).rotated(path.angle))
		# Create side door at end of path
		var side_door : Door = DOOR_SCENE.instantiate()
		side_door.type = pick_random_door_type()
		side_door.global_position = path.end
		side_door.locked = false
		add_child(side_door)
		# Populate room info
		info.side_doors_positions.append(path.end)
		info.side_doors_types.append(side_door.type)
		
	
	path.radius_curve = pick_radius_curve(is_main, length)
	
	var path_core : Array[Vector2i] = TilePath.find_straight_path(path.start, path.end)
	TilePath.add_noise_to_path(path_core, noise, pick_noise_strength(is_main), true, true)
	path.path_core = path_core
	
	# Calculate and store edges
	var path_edges : Array = TilePath.find_edges_of_path(path_core, path.radius_curve)
	
	var top_edge = path_edges[0]
	var bot_edge = path_edges[1]
	
	path.top_edge = top_edge
	path.bottom_edge = bot_edge
	path.total_edge = path_edges[2]
	path.packed_edge = path_edges[3]
	path.polygon = path_edges[4]
	
	#var top_noise_seed = TilePath.add_noise_to_path(path.top_edge, noise, 3, true)
	#TilePath.add_noise_to_path(path.bottom_edge, noise, 3, true, top_noise_seed)
	
	return path


func pick_path_length(is_main : bool):
	match info.type:
		_:
			if is_main:
				#return randf_range(1000, 3500)
				return 2000
			else:
				return randf_range(1000, 1500)

func pick_noise_strength(is_main : bool):
	match info.type:
		_:
			if is_main:
				return randf_range(5,20)
			else:
				return randf_range(5, 10)

func pick_path_radius(is_main : bool):
	match info.type:
		_:
			if is_main:
				return 15
			else:
				return 4

func pick_path_radius_deviation(is_main : bool):
	match info.type:
		_:
			if is_main:
				return 10
			else:
				return 2

static func pick_random_door_type():
	return Type.TEST # TODO

func pick_radius_curve(is_main : bool, length : float) -> Curve:
	var radius_curve = Curve.new()
	var radius : int = pick_path_radius(is_main)
	var deviation : int = pick_path_radius_deviation(is_main)
	# Set max x domain to the number of tiles, so path generator can sample based 
	# on tile number
	var num_tiles = (int(length) / 8.0 + 1)
	radius_curve.max_domain = num_tiles
	radius_curve.max_value = INF
	for point in pick_radius_curve_points(randi_range(2,6), radius, deviation, num_tiles, 0.1, 3, 2):
		radius_curve.add_point(point, 0, 0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	return radius_curve

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
	return points


func place_room_tiles():
	var start_door_pos := wall_layer.local_to_map(info.start_door_pos)
	var main_door_pos := wall_layer.local_to_map(info.main_door_world_pos)
	
	var top_left_pos := Vector2i(mini(start_door_pos.x, main_door_pos.x), mini(start_door_pos.y, main_door_pos.y))
	var bottom_right_pos := Vector2i(maxi(start_door_pos.x, main_door_pos.x), maxi(start_door_pos.y, main_door_pos.y))
	# Fill in bg
	# Carve out edges first, then insides (to clear up any edges overlapping with insides)
	var wall_cells : Array[Vector2i] = []
	var main_polygon := TilePath.map_to_packed_vec2_arr(info.main_path.polygon.polygon, false, true)
	var main_convex_hull = Geometry2D.convex_hull(main_polygon)
	var side_polygons := []
	var side_convex_hulls := []
	for side_path in info.side_paths:
		var poly = TilePath.map_to_packed_vec2_arr(side_path.polygon.polygon, false, true)
		var convex_hull = Geometry2D.convex_hull(poly)
		side_polygons.append(poly)
		side_convex_hulls.append(convex_hull)
		
	for i in range(len(side_polygons)):
		var merged_polys = Geometry2D.merge_polygons(main_polygon, side_polygons[i])
		main_polygon = merged_polys[0]
		var merged_hulls = Geometry2D.merge_polygons(main_convex_hull, side_convex_hulls[i])
		main_convex_hull = merged_hulls[0]
	main_convex_hull = Geometry2D.offset_polygon(main_convex_hull, 1)[0]
	#main_polygon = Geometry2D.offset_polygon(main_polygon, -3)[0]
	const PADDING_TILES := 50
	for y in range(top_left_pos.y - PADDING_TILES, bottom_right_pos.y + PADDING_TILES):
		for x in range(top_left_pos.x - PADDING_TILES, bottom_right_pos.x + PADDING_TILES):
			var coord = Vector2(x, y)
			bg_layer.set_cell(coord, 0, BG_ATLAS_COORDS)
			if Geometry2D.is_point_in_polygon(coord, main_convex_hull):
				if not Geometry2D.is_point_in_polygon(coord, main_polygon):
					wall_cells.append(Vector2i(coord)) 
			else:
				#continue
				wall_layer.set_cell(coord, 1, TERRAIN_WALL_INSIDE_ATLAS_COORDS)

	wall_layer.set_cells_terrain_connect(wall_cells, 0, 0)
