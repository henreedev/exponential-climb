extends Node2D

## Collects its child nodes and information about the overall dimensions, so that
## ChunkManager can place the POI.
## Defines:
## - bounding box dimensions around itself - equal to box containing child chunks expanded by border of 1
## - the possible local connection chunk coordinates that other POIs can route to. 
class_name POI

# Support custom bounding box adjustments, so that the start door POI can be flush
# against a boundary wall, for example.
@export_subgroup("Bounding Box")
@export var add_left_perimeter := true
@export var add_right_perimeter := true
@export var add_top_perimeter := true
@export var add_bottom_perimeter := true

## Local/relative coordinates of connection chunks
var connection_chunk_coords: Array[Vector2i]

## Dict from:
## - chunk that supports a connection to 
## - the Array of Vector2i chunk coords relative to it that allow it
var connectable_chunk_to_connection_coords: Dictionary[Chunk, Array] # Array[Vector2i]

var chunks: Array[Chunk]
var non_chunk_children: Array[Node2D]

var bounding_box: Rect2i

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_populate_child_arrays()
	_calculate_bounding_box_and_connection_chunks()

func _populate_child_arrays() -> void:
	for maybe_chunk in get_children():
		if maybe_chunk is Chunk:
			chunks.append(maybe_chunk)
		else:
			non_chunk_children.append(maybe_chunk)

func _calculate_bounding_box_and_connection_chunks() -> void:
	assert(len(connection_chunk_coords) == 0)
	var all_chunk_coords: Array[Vector2i] # for bounding box
	
	for chunk: Chunk in chunks:
		var chunk_coords := _chunk_to_coords(chunk)
		var chunk_connection_coords: Array[Vector2i] = chunk.get_all_connection_dirs_as_vector2is()
		
		# Add new connection coords if they exist
		if not chunk_connection_coords.is_empty():
			connectable_chunk_to_connection_coords[chunk] = chunk_connection_coords
		
		# Record chunk coords for bounding box calculation
		assert(not all_chunk_coords.has(chunk_coords), "No two chunks should be at the same position. Change this when adding hidden or overlaid chunks")
		all_chunk_coords.append(chunk_coords)
	
	_calculate_bounding_box(all_chunk_coords)

func _calculate_bounding_box(all_chunk_coords: Array[Vector2i]):
	var bounding_box_dims_x = Vector2i.ZERO
	var bounding_box_dims_y = Vector2i.ZERO
	for coord in all_chunk_coords:
		if coord.x < bounding_box_dims_x.x: bounding_box_dims_x.x = coord.x 
		if coord.x > bounding_box_dims_x.y: bounding_box_dims_x.y = coord.x 
		if coord.y < bounding_box_dims_y.x: bounding_box_dims_y.x = coord.y 
		if coord.y > bounding_box_dims_y.y: bounding_box_dims_y.y = coord.y 
	# Now add a 1 unit perimeter so that connection chunks are all included
	# Don't add the perimeter if user decides to ignore it
	const PERIMETER_SIZE := 1
	var perimeter_vec = Vector2i(-PERIMETER_SIZE, PERIMETER_SIZE)
	var hoz_perim_vec = Vector2i(perimeter_vec.x if add_left_perimeter else 0, 
								 perimeter_vec.y if add_right_perimeter else 0)
	var vert_perim_vec = Vector2i(perimeter_vec.x if add_top_perimeter else 0, 
								 perimeter_vec.y if add_bottom_perimeter else 0)
	bounding_box_dims_x += hoz_perim_vec
	bounding_box_dims_y += vert_perim_vec
	
	# Convert to Rect2i
	var top_left = Vector2i(bounding_box_dims_x.x, bounding_box_dims_y.x)
	var size = Vector2i(bounding_box_dims_x.y - bounding_box_dims_x.x, 
						bounding_box_dims_y.y - bounding_box_dims_y.x)
	bounding_box = Rect2i(top_left, size)

## Input NEEDS to be in the POI's local space!
## Returns the closest chunk coords to connect to, adding a connection to the POI chunk supporting that connection. 
func connect_to_closest_available_chunk_connection(connecting_from_local_coords: Vector2i) -> Vector2i:
	assert(can_be_connected_to())
	# Sort all the available chunks by their closest connection chunk's distance to input
	var chunk_to_closest_connection_chunk_coord: Dictionary[Vector2i, Chunk]
	for chunk: Chunk in connectable_chunk_to_connection_coords.keys():
		assert(chunk)
		if not chunk.can_add_connection():
			continue
		var chunk_closest_conn_coord = _find_closest_conn_ch_coord(chunk, connecting_from_local_coords)
		chunk_to_closest_connection_chunk_coord[chunk_closest_conn_coord] = chunk
	# Sort keys by distance, then use the first key.  
	# Could be a tie, so it would be arbitrary in that case
	var keys = chunk_to_closest_connection_chunk_coord.keys()
	keys.sort_custom(func(a, b): return coord_dist(connecting_from_local_coords, a) < coord_dist(connecting_from_local_coords, b))
	var closest_conn_coords: Vector2i = keys[0]
	var closest_conn_chunk: Chunk = chunk_to_closest_connection_chunk_coord[closest_conn_coords]
	# Add connection to this chunk
	closest_conn_chunk.add_connection()
	return closest_conn_coords

## Returns absolute connection chunk coord relative to this POI that's closest to the given coord.
func _find_closest_conn_ch_coord(chunk: Chunk, to_coord: Vector2i) -> Vector2i:
	assert(chunk.can_add_connection())
	var closest_coord = null # Nullable vector2i
	var closest_dist := 99999.0
	var chunk_abs_coord = _chunk_to_coords(chunk)
	for conn_ch_coord in chunk.get_all_connection_dirs_as_vector2is():
		var absolute_coord = conn_ch_coord + chunk_abs_coord
		var dist = coord_dist(to_coord, absolute_coord)
		if dist < closest_dist:
			closest_coord = absolute_coord
			closest_dist = dist
	assert(closest_coord is Vector2i)
	return closest_coord

func can_be_connected_to() -> bool:
	return get_connectable_chunks().size() > 0

func get_connectable_chunks() -> Array[Chunk]:
	var connectable_chunks: Array[Chunk]
	for chunk: Chunk in connectable_chunk_to_connection_coords.keys():
		if chunk.can_add_connection():
			connectable_chunks.append(chunk)
	return connectable_chunks
	
func _chunk_to_coords(chunk: Chunk) -> Vector2i:
	var pos := chunk.position
	var x: int = int(pos.x) / Chunk.TOTAL_CHUNK_SIZE_PX.x
	var y: int = int(pos.y) / Chunk.TOTAL_CHUNK_SIZE_PX.y
	assert(x * Chunk.TOTAL_CHUNK_SIZE_PX.x == pos.x)
	assert(y * Chunk.TOTAL_CHUNK_SIZE_PX.y == pos.y)
	return Vector2i(x, y)

## Euclidean dist, values diagonals
func coord_dist(a: Vector2i, b: Vector2i):
	return a.distance_to(b) 

func get_nonchunk_children() -> Array[Node2D]:
	return non_chunk_children

func get_chunks() -> Array[Chunk]:
	return chunks

func get_chunks_and_coords() -> Dictionary[Chunk, Vector2i]:
	var coords_dict: Dictionary[Chunk, Vector2i]
	for chunk in chunks:
		coords_dict[chunk] = _chunk_to_coords(chunk)
	return coords_dict

func get_bounding_box() -> Rect2i:
	return bounding_box
