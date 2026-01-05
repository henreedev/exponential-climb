extends Node2D

## Generates, then contains information about, all chunks in the room. 
## Instantiated once per Room as a child of the Room.
## Does:
## - Initial chunk generation
## - POI selection (for now, all POIs are used)
## - POI placement (PDS but with AABBs)
## - Telling chunks to decide their tiles
## - Reporting tiles to Room's tilemaps
class_name ChunkManager
#region Constants
const CHUNK_SCENE = preload("uid://ce61xmb155lxh")
const START_DOOR_POI_SCENE = preload("uid://di8y4jlxratil") # FIXME
const BOSS_PLATFORM_POI_SCENE = preload("uid://1v30deb6xoqs") # FIXME
const SECONDARY_POI_SCENES: Array[PackedScene] = [
	
]
#endregion Constants

var boundary_bboxes: Array[Rect2i]
var poi_to_bbox: Dictionary[POI, Rect2i] 
var poi_to_coords: Dictionary[POI, Vector2i]
var poi_to_graph_id: Dictionary[POI, int]
var chunkmap: Array[Array]# of Chunks
## Contains each POI and its connections to other POIs.
var poi_graph := AStar2D.new()
## Contains the 2d array of navigable chunks to use when carving out paths. 
var chunk_graph := AStarGrid2D.new()

#region Results to pass to Room
# TODO optimize by splitting into terrain / non-terrain
var all_wall_tiles: Array[Vector2i]
var scene_children: Array[Node2D]
#endregion

#region Builtins
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
#endregion 

## Entry point for the room chunk generation pipeline. 
## Creates the room boundary Rect2is
func generate_room_chunks(room: Room) -> Array[Array]:
	var bounds := room.get_bounds()
	_initialize_chunks_and_boundaries(bounds)
	await _place_pois()
	_connect_pois()
	_place_poi_paths()
	_realize_chunks()
	_collect_poi_scene_children()
	return [all_wall_tiles, scene_children]


func _initialize_chunks_and_boundaries(bounds: Array[Vector2i]):
	var x_bounds: Vector2i = bounds[0]
	var y_bounds: Vector2i = bounds[1]
	# Mod the x and y bounds by chunk dims, since they are in tile units
	var chunk_x_bounds := Vector2i(x_bounds.x / Chunk.CHUNK_DIMENSIONS.x, 
									x_bounds.y / Chunk.CHUNK_DIMENSIONS.x)
	var chunk_y_bounds := Vector2i(y_bounds.x / Chunk.CHUNK_DIMENSIONS.y, 
									y_bounds.y / Chunk.CHUNK_DIMENSIONS.y)
	
	var chunk_x_bounds_len = chunk_x_bounds.y - chunk_x_bounds.x
	var chunk_y_bounds_len = chunk_y_bounds.y - chunk_y_bounds.x
	# Resize the chunkmap 2d arr to match the bounds
	var res = chunkmap.resize(chunk_x_bounds_len)
	assert(res == OK)
	for inner_arr: Array in chunkmap:
		var res_2 = inner_arr.resize(chunk_y_bounds_len)
		assert(res_2 == OK)
	
	debug_print("Chunkmap dims (" , chunk_x_bounds_len, ", " , chunk_y_bounds_len , ")")
	
	# Initialize a land chunk for each empty slot. If it's on the boundary, make it unchangeable
	# Place the chunks in the scene tree with visually accurate positions, to support visualizing this step
	for x in range(chunkmap.size()):
		for y in range(chunkmap[0].size()):
			var new_chunk: Chunk = CHUNK_SCENE.instantiate()
			set_chunk(x, y, new_chunk)
			add_child.call_deferred(new_chunk)
			# Set boundary with unchangeable edge tiles
			if is_on_boundary(x, y): 
				new_chunk.set_to_unchangeable_type_and_default()
			else:
				new_chunk.set_to_changeable_type_and_default()
	
	await Global.game.get_tree().process_frame
	
	# Create the bounding boxes that include the boundary edge chunks.
	var left_bbox := Rect2i(Vector2i.ZERO, Vector2i(1, get_chunkmap_height()))
	var right_bbox := Rect2i(Vector2i(get_chunkmap_width() - 2, 0), Vector2i(1, get_chunkmap_height()))
	var top_bbox := Rect2i(Vector2i.ZERO, Vector2i(get_chunkmap_width(), 1))
	var bottom_bbox := Rect2i(Vector2i(0, get_chunkmap_height() - 2), Vector2i(get_chunkmap_width(), 1))
	
	boundary_bboxes.append_array([left_bbox, right_bbox, top_bbox, bottom_bbox])

## Places start door on left edge of map, then places each secondary POI, 
## then the boss teleporter off of the furthest POI. 
## Checks each POI placement with an OOB check of the placement coord, then
## boundary bboxes and existing poi bboxes intersections.
func _place_pois() -> void:
	# Start door
	const START_DOOR_X := 1 # exclude edge
	var start_door_poi := await instantiate_poi(START_DOOR_POI_SCENE)
	var height_boundary = start_door_poi.get_bounding_box().size.y / 2 + 1
	var start_door_y = randi_range(1 + height_boundary, get_chunkmap_height() - 2 - height_boundary) # exclude edge
	_place_poi(start_door_poi, START_DOOR_X, start_door_y)
	
	# Secondary POIs
	# Track last POI and its center coord of its bbox. 
	# TODO: use a more complex approach with picking a random point along the bbox perimeter, 
	# 	using radius in the 180 deg range of the direction of the random point
	#	Fixes large pois being limited to spawning other pois near their center
	var last_poi_center := get_poi_center(start_door_poi)
	const RADIUS = 5
	for secondary_poi_scene in SECONDARY_POI_SCENES:
		var secondary_poi := await instantiate_poi(secondary_poi_scene)
		# Pick secondary poi chunkmap coords
		var coords := find_placeable_coords(secondary_poi, last_poi_center, RADIUS)
		_place_poi(secondary_poi, coords.x, coords.y)
		last_poi_center = get_poi_center(secondary_poi)
	# Find furthest POI from start door, place teleporter near it
	# FIXME placement could fail in some cases, say the furthest is already stuck in a corner
	# Should fallback to next furthest in that case
	var pois: Array[POI] = get_pois()
	pois.sort_custom(
		func(a: POI, b: POI): return a.position.distance_to(start_door_poi.position) < \
									b.position.distance_to(start_door_poi.position))
	var furthest_poi_center = get_poi_center(pois[0])
	var boss_platform_poi := await instantiate_poi(BOSS_PLATFORM_POI_SCENE)
	var boss_platform_coords := find_placeable_coords(boss_platform_poi, furthest_poi_center, RADIUS)
	_place_poi(boss_platform_poi, boss_platform_coords.x, boss_platform_coords.y)

## Assumes valid placement location. 
## Sets necessary chunks to POI chunk data, then adds poi bbox to dict.
func _place_poi(poi: POI, x: int, y: int) -> void:
	if not _can_place_poi(poi, x, y):
		assert(false)
	debug_print("Placing poi ", poi.name, " at (", x, ", ", y, ")")
	# Store poi info
	poi.position = coord_to_px_pos(x, y)
	poi_to_coords[poi] = Vector2i(x, y)
	poi_to_bbox[poi] = poi.get_bounding_box()
	
	# Set chunks
	var chunks_to_coords := poi.get_chunks_and_coords()
	for chunk: Chunk in chunks_to_coords:
		var chunk_local_coord = chunks_to_coords[chunk]
		var abs_coord_x = chunk_local_coord.x + x
		var abs_coord_y = chunk_local_coord.y + y
		set_chunk(abs_coord_x, abs_coord_y, chunk)

func _can_place_poi(poi: POI, x: int, y: int) -> bool:
	if not is_in_bounds(x, y): 
		return false
	
	var bbox_local = poi.get_bounding_box()
	# Copy local bbox and shift to global chunk coords
	var bbox = Rect2i(bbox_local.position + Vector2i(x, y), bbox_local.size)
	
	if intersects_boundaries(bbox):
		return false
	
	if intersects_existing_pois(bbox):
		return false
	
	return true

## Populates the poi AStar graph.
func _connect_pois() -> void:
	debug_print("Connecting POIs...")
	var all_pois: Array[POI] = get_pois()
	# Place POIs in graph
	for poi in all_pois:
		var coords := poi_to_coords[poi]
		poi_graph.add_point(encode_poi_id(poi), coords)
	
	# Connect each POI with its two closest
	for poi in all_pois:
		var other_pois = all_pois.duplicate()
		other_pois.erase(poi)
		other_pois.sort_custom(
			func(a: POI, b: POI): return (
				get_poi_center(a).distance_to(get_poi_center(poi)) < \
				get_poi_center(b).distance_to(get_poi_center(poi))
		))
		var closest_poi = other_pois[0]
		# FIXME do second closest POI too
		#var second_closest_poi = other_pois[1]
		poi_graph.connect_points(encode_poi_id(poi), encode_poi_id(closest_poi))
		#poi_graph.connect_points(encode_poi_id(poi), encode_poi_id(second_closest_poi))
	debug_print("Connected POIs.")
	
	# TODO ensure connections between all points
	#for id in poi_graph.get_point_ids():
		#poi_graph.are_points_connected()

func _place_poi_paths() -> void:
	debug_print("Placing POI paths...")
	
	# Generate astar graph where only adjacent nodes are connected
	chunk_graph.region = Rect2i(Vector2i.ZERO, Vector2i(get_chunkmap_width(), get_chunkmap_height()))
	chunk_graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	chunk_graph.update()
	for x in range(get_chunkmap_width()):
		for y in range(get_chunkmap_height()):
			var chunk = get_chunk(x, y)
			chunk_graph.set_point_solid(Vector2i(x, y), chunk.is_unchangeable())
	
	# For each edge between POIs, find connection chunk of each POI
	# then find the path in terms of coords between them using A*, 
	# then make all those chunks air. 
	var poi_graph_edges: Array[Array] = get_unique_poi_graph_edges()
	for edge: Array[int] in poi_graph_edges:
		# Find closest connection chunks of POIs
		var id_1 = edge[0]
		var id_2 = edge[1]
		var poi_1 : POI= poi_to_coords.find_key(decode_poi_id(id_1))
		var poi_2 :POI= poi_to_coords.find_key(decode_poi_id(id_2))
		var poi_1_relative_to_poi_2 = poi_to_coords[poi_1] - poi_to_coords[poi_2]
		var poi_2_relative_to_poi_1 = poi_to_coords[poi_2] - poi_to_coords[poi_1]
		assert(poi_1.can_be_connected_to())
		assert(poi_2.can_be_connected_to())
		# TODO this could be improved by finding their two closest connectable chunks
		# to each other and returning both at once.
		var poi_1_conn_coords := poi_1.connect_to_closest_available_chunk_connection(poi_2_relative_to_poi_1)\
					+ poi_to_coords[poi_1]
		
		var poi_2_conn_coords := poi_2.connect_to_closest_available_chunk_connection(poi_1_relative_to_poi_2)\
					+ poi_to_coords[poi_2]
		
		# Find path
		var chunk_path := chunk_graph.get_id_path(poi_1_conn_coords, poi_2_conn_coords)
		assert(chunk_path)
		debug_print("Placing POI path between ", poi_1.name, " and " ,poi_2.name, ": ", chunk_path)
		
		# Make path air chunks
		for coords in chunk_path:
			var chunk = get_chunk(coords.x, coords.y)
			assert(not chunk.is_unchangeable())
			chunk.set_to_changeable_type_and_default(Chunk.Type.AIR)
	debug_print("Placed POI paths.")
	
## Populate the wall tiles array based on the tiles in each chunk.
func _realize_chunks() -> void:
	debug_print("Realizing chunks...")
	
	debug_print("Realizing chunks - Width: ", get_chunkmap_width())
	debug_print("Realizing chunks - Height: ", get_chunkmap_height())
	var i := 0
	for x in range(get_chunkmap_width()):
		for y in range(get_chunkmap_height()):
			if i % 100 == 0: debug_print("Realizing chunk at " ,Vector2i(x, y), ", chunk ", i)
			i += 1
			var chunk = get_chunk(x, y)
			var chunk_local_wall_tiles := chunk.decide_tiles()
			if chunk.type == Chunk.Type.AIR: 
				assert(chunk_local_wall_tiles.is_empty())
			for local_tile in chunk_local_wall_tiles:
				var abs_tile_coord = local_tile + Vector2i(x, y) * Chunk.CHUNK_DIMENSIONS
				all_wall_tiles.append(abs_tile_coord)
	
	debug_print("Realized chunks.")

func _collect_poi_scene_children():
	debug_print("Collecting scene children...")
	for poi in get_pois():
		scene_children.append_array(poi.get_nonchunk_children())
	debug_print("Collected scene children.")

#region Helpers
func get_chunk(x: int, y: int) -> Chunk:
	assert(is_in_bounds(x, y))
	return chunkmap[x][y]

func set_chunk(x: int, y: int, chunk: Chunk) -> void:
	assert(is_in_bounds(x, y))
	var current_chunk := get_chunk(x, y)
	if current_chunk:
		current_chunk.free()
	if not chunk.get_parent() is POI:
		chunk.position = coord_to_px_pos(x, y)
	chunkmap[x][y] = chunk

func get_chunkmap_width() -> int:
	return chunkmap.size()

func get_chunkmap_height() -> int:
	return chunkmap[0].size()

func is_on_boundary(x: int, y: int) -> bool:
	return x == 0 or x == get_chunkmap_width() - 1 or y == 0 or y == get_chunkmap_height() - 1

func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < get_chunkmap_width() and y >= 0 and y < get_chunkmap_height()

func intersects_boundaries(bbox: Rect2i) -> bool:
	for boundary_bbox in boundary_bboxes:
		if bbox.intersects(boundary_bbox):
			return true
	return false

func intersects_existing_pois(bbox: Rect2i) -> bool:
	for poi_bbox: Rect2i in poi_to_bbox.values():
		if bbox.intersects(poi_bbox):
			return true
	return false

func coord_to_px_pos(x: int, y: int) -> Vector2i:
	return Vector2i(x, y) * Chunk.TOTAL_CHUNK_SIZE_PX

## Returns a chunkmap coord
func pick_random_coord_with_dist(from_coords: Vector2i, radius: int) -> Vector2i:
	var offset := Vector2i((Vector2.RIGHT * radius).rotated(randf() * TAU))
	return from_coords + offset

func debug_print(...strs):
	print("Chunkgen: ", strs)

## In chunkmap coords
func get_poi_center(poi: POI) -> Vector2i:
	return (
		poi_to_coords[poi] + # abs coord
		poi.get_bounding_box().get_center() # local bbox center
	)

func get_pois() -> Array[POI]:
	var pois: Array[POI]
	for poi in poi_to_coords.keys():
		pois.append(poi)
	return pois

## 
func find_placeable_coords(poi: POI, from_coords: Vector2i, radius: int) -> Vector2i:
	debug_print("Finding placeable coords for ", poi.name, "...")
	var attempts := 1
	var coords := pick_random_coord_with_dist(from_coords, radius) 
	while not _can_place_poi(poi, coords.x, coords.y):
		var random_radius := int(randf_range(radius * 3, radius * 3))
		coords = pick_random_coord_with_dist(from_coords, random_radius)
		attempts += 1
	
	debug_print("Found placeable coords for ", poi.name, " after ", attempts, " attempts")
	return coords

func instantiate_poi(poi_scene: PackedScene) -> POI:
	var poi: POI = poi_scene.instantiate()
	add_child.call_deferred(poi)
	await Global.game.get_tree().process_frame
	return poi

# No two POIs should be in same pos
func encode_poi_id(poi: POI):
	var coords := poi_to_coords[poi]
	return (coords.x << 32) | (coords.y & 0xffffffff)

func decode_poi_id(id: int) -> Vector2i:
	return Vector2i(id >> 32, id & 0xffffffff)

func get_unique_poi_graph_edges() -> Array[Array]: # Tuples of (id, id)
	var edges: Array[Array] = []
	var seen := {}

	for id in poi_graph.get_point_ids():
		for neighbor_id in poi_graph.get_point_connections(id):
			var a = min(id, neighbor_id)
			var b = max(id, neighbor_id)
			var key = str(a, "-", b)
			if not seen.has(key):
				seen[key] = true
				edges.append([a, b])
	return edges

#endregion
