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
const terrain_noise_threshold = 0.55
const terrain_noise_distortion_vec := Vector2(0.5, 2.0)

@export var tunnel_noise : FastNoiseLite
const tunnel_noise_scale := 1.0
const tunnel_noise_threshold := 0.85
const tunnel_noise_distortion_vec := Vector2(0.5, 1.0)

@export var rarity_noise : FastNoiseLite
const rarity_noise_scale := 1.0

@export var quantity_noise : FastNoiseLite
const quantity_noise_scale := 1.0

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

var _x_bounds: Vector2i
var _y_bounds: Vector2i

## Determines door positions and generates room tiles, returning the new room.
static func generate_room(start_pos : Vector2i, attach_to : Node, rng_seed : int, x_bounds := Vector2i(-150, 150), y_bounds := Vector2i(-150, 150), type : Type = Type.TEST) -> Room:
	# Generate room based on info
	var room : Room = ROOM_SCENE.instantiate()
	# Set random seed for noise gens
	room.map_edge_noise.seed = rng_seed
	room.terrain_noise.seed = rng_seed
	room.tunnel_noise.seed = rng_seed
	room.rarity_noise.seed = rng_seed + 1
	room.quantity_noise.seed = rng_seed + 2
	
	var room_info : RoomInfo = room.generate_room_info(start_pos, type)
	room.info = room_info
	room.start_door = DOOR_SCENE.instantiate()
	room.main_door = DOOR_SCENE.instantiate()
	room.add_child(room.start_door)
	room.add_child(room.main_door)
	
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
	
	room.set_bounds(room_x_bounds, room_y_bounds)
	
	# Generate map edges (top, bottom, left, right walls)
	room.generate_edges(room_x_bounds, room_y_bounds)
	
	# Generate basic terrain 
	room.generate_terrain(room_x_bounds, room_y_bounds)
	
	# Place main door near edge of map
	room.place_main_door(room_x_bounds, room_y_bounds)
	
	# Room's physics polygons do not exist until 2 frames later. 
	# Pathfinding and chest generation use raycasts that rely on them.
	await room.get_tree().physics_frame
	await room.get_tree().physics_frame
	
	# Add chests
	room.generate_chests(room_x_bounds, room_y_bounds)
	
	if Global.player: 
		Global.player.global_position = start_pos
	
	#room.analyze_noise_values(10000)
	
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

## Sets the room's horizontal and vertical boundaries in tile coordinates.
func set_bounds(x_bounds: Vector2i, y_bounds: Vector2i):
	_x_bounds = x_bounds
	_y_bounds = y_bounds

func generate_edges(x_bounds : Vector2i, y_bounds : Vector2i):
	# The terrain tiles to be placed at the end.
	var wall_cells : Array[Vector2i] = []
	
	var left = x_bounds.x
	var right = x_bounds.y
	var top = y_bounds.x
	var bottom = y_bounds.y
	
	# Start timing tile selection
	var time = Time.get_ticks_msec()
	
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
	
	print("Selected edge tiles in ", Time.get_ticks_msec() - time, " ms")
	
	
	# Fill in edge walls
	time = Time.get_ticks_msec()
	#for coord in wall_cells:
		#wall_layer.set_cell(coord, 1, TERRAIN_WALL_INSIDE_ATLAS_COORDS)
	print("Set down edge tiles in ", Time.get_ticks_msec() - time, " ms")
	
	time = Time.get_ticks_msec()
	wall_layer.set_cells_terrain_connect(wall_cells, 0, 0)
	print("Connected edge terrain in ", Time.get_ticks_msec() - time, " ms")

func generate_terrain(x_bounds : Vector2i, y_bounds : Vector2i):
	# Outer edges of walls.
	var wall_cells_terrain: Array[Vector2i] = []
	# Insides of walls.
	var wall_cells_bg: Array[Vector2i] = []
	
	# Start timing tile selection
	var time = Time.get_ticks_msec()
	
	const OUTER_EDGE_NOISE_THRESHOLD := 0.1
	
	# Sample terrain noise for general terrain shape 
	for x in range(x_bounds.x, x_bounds.y + 1):
		for y in range(y_bounds.x, y_bounds.y + 1):
			var noise_val = sample_terrain_noise(x,y)
			if noise_val >= terrain_noise_threshold:
				if noise_val < terrain_noise_threshold + OUTER_EDGE_NOISE_THRESHOLD:
					wall_cells_terrain.append(Vector2i(x, y))
				else:
					wall_cells_bg.append(Vector2i(x, y))
	
	
	# Add tunnels to terrain
	for x in range(x_bounds.x, x_bounds.y + 1):
		for y in range(y_bounds.x, y_bounds.y + 1):
			var noise_val = sample_tunnel_noise(x,y)
			if noise_val >= tunnel_noise_threshold - OUTER_EDGE_NOISE_THRESHOLD:
				if noise_val >= tunnel_noise_threshold:
					wall_cells_terrain.erase(Vector2i(x, y))
					wall_cells_bg.erase(Vector2i(x, y))
				else:
					if wall_cells_bg.has(Vector2i(x,y)):
						wall_cells_terrain.append(Vector2i(x,y))
					wall_cells_bg.erase(Vector2i(x, y))
	
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
	print("Selected wall tiles in ", Time.get_ticks_msec() - time, " ms")
	
	
	# Fill in tilemap background
	time = Time.get_ticks_msec()
	for y in range(top_left_pos.y, bottom_right_pos.y):
		for x in range(top_left_pos.x, bottom_right_pos.x):
			var coord = Vector2i(x, y)
			bg_layer.set_cell(coord, 0, BG_ATLAS_COORDS)
	# Fill in walls
	for coord in wall_cells_bg:
		wall_layer.set_cell(coord, 1, TERRAIN_WALL_INSIDE_ATLAS_COORDS)
	print("Set down wall tiles in ", Time.get_ticks_msec() - time, " ms")

	time = Time.get_ticks_msec()
	wall_layer.set_cells_terrain_connect(wall_cells_terrain, 0, 0)
	print("Connected wall terrain in ", Time.get_ticks_msec() - time, " ms")

#region Chest generation
func generate_chests(x_bounds : Vector2i, y_bounds : Vector2i):
	# Pick a random number of chests 
	var num_chests := randi_range(5, 7)
	print("Spawning ", num_chests, " chests")
	var time = Time.get_ticks_msec()
	
	var chests_spawned_counter := 0
	
	while chests_spawned_counter < num_chests:
		# Pick a random spot
		var x = randi_range(x_bounds.x, x_bounds.y)
		var y = randi_range(y_bounds.x, y_bounds.y)
		var coord := Vector2i(x,y)
		
		# Move coord towards higher gradient values (gradient ascent)
		const GRADIENT_ITERS := 0
		for i in range(GRADIENT_ITERS):
			# Amount to move in highest grad dir
			const GRAD_MOVEMENT := 16
			# Look in all 8 directions and find the direction with the highest quantity gradient
			var highest_grad_dir := _find_highest_quantity_grad_dir(coord, GRAD_MOVEMENT)
			
			var grad_coord := coord + highest_grad_dir * GRAD_MOVEMENT
			coord = grad_coord
		
		# Now roll for quantity
		var quantity := sample_quantity_noise(coord.x, coord.y)
		if (
			randf() > quantity * 1.5
			#or 
		#quantity < 0.3
		):
			continue
			
		# Raycast down a maximum distance
		var hit_coord: Vector2i = find_below_point(coord, 10.0)
		if hit_coord == Vector2i.MAX:
			continue
		
		# If hit, place chest there 
		const TILE_SIZE := 8
		# Instead of being centered on the hit tile, move 1.5 tiles up and half a tile left. 
		# Then ensure the tile left of the hit tile is solid and the tiles the chest is inside are not solid.
		var hit_coord_left := hit_coord + Vector2i.LEFT
		var hit_coord_right := hit_coord + Vector2i.RIGHT
		var hit_coord_up := hit_coord + Vector2i.UP
		var hit_coord_left_up := hit_coord_left + Vector2i.UP
		#if wall_cells.has(hit_coord_up) or wall_cells.has(hit_coord_left_up):
			#continue
		wall_layer.erase_cell(hit_coord_up)
		#wall_layer.set_cells_terrain_connect(hit_coord_up)
		#if not wall_cells.has(hit_coord_left_up):
		wall_layer.erase_cell(hit_coord_left_up)
		#if not wall_cells.has(hit_coord_left) or not wall_cells.has(hit_coord_right):
			#continue
		wall_layer.set_cells_terrain_connect([hit_coord_left, hit_coord_right], 0, 0)
		var chest_pos := wall_layer.map_to_local(hit_coord) + Vector2(TILE_SIZE / 2.0, -TILE_SIZE * 1.5)
		
		var chest_rarity := sample_rarity_noise(coord.x, coord.y)
		print("Creating chest using hit at ", hit_coord, " of rarity ", chest_rarity, " and quantity ", quantity)
		var chest := Chest.create(chest_pos, chest_rarity, quantity)
		add_child(chest)
		chests_spawned_counter += 1
	print("Spawned ", num_chests, " chests in ", Time.get_ticks_msec() - time, " ms")

func _find_highest_quantity_grad_dir(coord: Vector2i, dir_distance: int) -> Vector2i:
	var coord_quantity = sample_quantity_noise(coord.x, coord.y)
	var highest_quantity_dir := Vector2i.MAX
	var highest_quantity_grad := -1.0
	for x in range(-1, 2):
		for y in range(-1, 2):
			var dir = Vector2i(x,y) * dir_distance
			var dir_coord = coord + dir
			var dir_quantity = sample_quantity_noise(dir_coord.x, dir_coord.y)
			var grad = dir_quantity - coord_quantity
			if grad > highest_quantity_grad:
				highest_quantity_dir = dir
				highest_quantity_grad = grad
	return highest_quantity_dir
#endregion Chest generation

#region Door placement
func place_main_door(x_bounds: Vector2i, y_bounds: Vector2i):
	print("Placing main door near map edge...")
	var time = Time.get_ticks_msec()
	
	const TILE_SIZE := 8
	const MAX_RAYCAST_DIST := 25.0
	const EDGE_OFFSET := 8      # how far inward from the map edge we sample
	const MAX_ATTEMPTS := 300
	
	var attempts := 0
	var placed := false
	
	while attempts < MAX_ATTEMPTS and not placed:
		attempts += 1
		
		# Choose a random edge (0 = left, 1 = right, 2 = top, 3 = bottom)
		var edge_choice := randi() % 4
		var coord: Vector2i
		
		match edge_choice:
			0: # Left edge
				coord = Vector2i(x_bounds.x + EDGE_OFFSET, randi_range(y_bounds.x, y_bounds.y))
			1: # Right edge
				coord = Vector2i(x_bounds.y - EDGE_OFFSET, randi_range(y_bounds.x, y_bounds.y))
			2: # Top edge
				coord = Vector2i(randi_range(x_bounds.x, x_bounds.y), y_bounds.x + EDGE_OFFSET)
			3: # Bottom edge
				coord = Vector2i(randi_range(x_bounds.x, x_bounds.y), y_bounds.y - EDGE_OFFSET)
		
		# Skip if the spot itself is solid
		if wall_layer.get_cell_source_id(coord) != -1:
			continue
		
		# Raycast downward to find the ground
		var hit_coord := find_below_point(coord, MAX_RAYCAST_DIST)
		if hit_coord == Vector2i.MAX:
			continue
		
		# Check if hit tile is solid (valid ground)
		if wall_layer.get_cell_source_id(hit_coord) == -1:
			continue
		
		# Place the door slightly above ground
		var world_pos := wall_layer.map_to_local(hit_coord) + Vector2(0, -TILE_SIZE * 2)
		main_door.global_position = world_pos
		print("Main door placed at ", world_pos, " after ", attempts, " attempts.")
		placed = true
	
	if not placed:
		print("Failed to place main door after ", MAX_ATTEMPTS, " attempts. Using fallback near right edge.")
		var fallback := Vector2i(x_bounds.y - EDGE_OFFSET, (y_bounds.x + y_bounds.y) / 2)
		main_door.global_position = wall_layer.map_to_local(fallback)
	
	print("Placed main door in ", Time.get_ticks_msec() - time, " ms")


#endregion Door placement



func generate_pots():
	pass

#region Helpers
	#TEST ================================
	#TERRAIN: min=0.208, max=0.802, avg=0.507, std=0.111
	#TUNNEL: min=0.000, max=1.000, avg=0.485, std=0.282
	#RARITY: min=0.083, max=0.863, avg=0.497, std=0.152
	#QUANTITY: min=0.001, max=0.994, avg=0.481, std=0.289
	#====================================

func sample_terrain_noise(x: int, y: int) -> float:
	var scaled_sample_vec = Vector2(x, y) * terrain_noise_scale * terrain_noise_distortion_vec
	var noise_val = terrain_noise.get_noise_2dv(scaled_sample_vec)
	# Rescale to 0-1
	noise_val = inverse_lerp(-1, 1, noise_val)
	
	# Now rescale to 0-1 based on calculated min and max values above
	noise_val = inverse_lerp(0.20, 0.80, noise_val)
	
	return noise_val

func sample_tunnel_noise(x: int, y: int) -> float:
	var scaled_sample_vec = Vector2(x, y) * tunnel_noise_scale * tunnel_noise_distortion_vec
	var noise_val = tunnel_noise.get_noise_2dv(scaled_sample_vec)
	# NOTE negating tunnel noise because i want to use black parts of ping pong noise
	noise_val *= -1
	# Rescale to 0-1
	noise_val = inverse_lerp(-1, 1, noise_val)
	
	return noise_val

func sample_rarity_noise(x: int, y: int) -> float:
	var scaled_sample_vec = Vector2(x, y) * rarity_noise_scale 
	var noise_val = rarity_noise.get_noise_2dv(scaled_sample_vec) 
	# Rescale to 0-1
	noise_val = inverse_lerp(-1, 1, noise_val)
	
	# Now rescale to 0-1 based on calculated min and max values above
	noise_val = inverse_lerp(0.06, 0.88, noise_val)
	
	return noise_val

func sample_quantity_noise(x: int, y: int) -> float:
	var scaled_sample_vec = Vector2(x, y) * quantity_noise_scale 
	var noise_val = quantity_noise.get_noise_2dv(scaled_sample_vec) 
	# Rescale to 0-1
	noise_val = inverse_lerp(-1, 1, noise_val)
	return noise_val

func analyze_noise_values(num_samples := 1000000):
		print("TEST ================================")
		var noise_types := {
			"terrain": [],
			"tunnel": [],
			"rarity": [],
			"quantity": []
		}
		
		for i in range(num_samples):
			var x = randi_range(_x_bounds.x, _y_bounds.y)
			var y = randi_range(_x_bounds.x, _y_bounds.y)
			
			noise_types["terrain"].append(sample_terrain_noise(x, y))
			noise_types["tunnel"].append(sample_tunnel_noise(x, y))
			noise_types["rarity"].append(sample_rarity_noise(x, y))
			noise_types["quantity"].append(sample_quantity_noise(x, y))
		
		var stats = func(arr: Array) -> Dictionary:
			if arr.is_empty():
				return {"min": 0, "max": 0, "avg": 0, "std": 0}
			var min_v = arr[0]
			var max_v = arr[0]
			var sum_v = 0.0
			for v in arr:
				if v < min_v: min_v = v
				if v > max_v: max_v = v
				sum_v += v
			var avg_v = sum_v / arr.size()
			var variance = 0.0
			for v in arr:
				variance += pow(v - avg_v, 2)
			variance /= arr.size()
			var std_v = sqrt(variance)
			return {"min": min_v, "max": max_v, "avg": avg_v, "std": std_v}
		
		for _name in noise_types.keys():
			var s = stats.call(noise_types[_name])
			print(_name.to_upper(), ": min=%.3f, max=%.3f, avg=%.3f, std=%.3f" % [s.min, s.max, s.avg, s.std])
		
		print("====================================")


func find_below_point(cell: Vector2i, max_below_dist := 1000.0) -> Vector2i:
	var start_pos = wall_layer.map_to_local(cell)
	var end_pos = start_pos + Vector2(0, max_below_dist)
	var hit_pos = do_raycast(start_pos, end_pos)
	if hit_pos == Vector2.INF:
		return Vector2i.MAX
	return wall_layer.local_to_map(hit_pos)

func do_raycast(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var space_state = Global.game.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 4)
	query.hit_from_inside = true
	var result = space_state.intersect_ray(query)
	# Return the hit if it didn't happen immediately inside a wall (L mans)
	if result and not result["normal"] == Vector2.ZERO:
		return result["position"]
	else:
		return Vector2.INF
#endregion Helpers
