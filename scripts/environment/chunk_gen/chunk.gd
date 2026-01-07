@tool
extends TileMapLayer

## One square collection of tiles in the in-game map. 
## Describes where to place tiles in the overall Room tilemap, 
## but does not actually parent any in-game tiles. 
## Can parent scenes like Pots or Chests, which will be transferred to the parent Room.
## The Chunk tilemap can be painted to describe where land and air tiles must or adaptively can go. 
class_name Chunk

#region Attributes
const BOTTOM_LEFT := Vector2i.DOWN + Vector2i.LEFT
const BOTTOM_RIGHT := Vector2i.DOWN + Vector2i.RIGHT
const TOP_LEFT := Vector2i.UP + Vector2i.LEFT
const TOP_RIGHT := Vector2i.UP + Vector2i.RIGHT

const CHUNK_DIMENSIONS := Vector2i(8, 8)
const TILE_SIZE_PX := Vector2i(8, 8)
const TOTAL_CHUNK_SIZE_PX = CHUNK_DIMENSIONS * TILE_SIZE_PX 
## Decides what chunk tile to default to. The chunk tiles themselves determine final 
## tile placements.
enum Type {
	AIR, 
	LAND, 
}
@export var type: Type = Type.LAND

# This creates a button labeled "Rebuild Defaults"
# When pressed, it calls the method _rebuild_defaults.
@export_tool_button("Rebuild Defaults") var _rebuild_defaults_button = \
	_replace_chunk_tilemap_with_defaults

enum ConnectionDir {
	LEFT,
	RIGHT,
	UP,
	DOWN,
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}

enum NeighborsType {
	ALL_LAND, 
	THREE_LAND, # returned with center coord of the 3
	TWO_ADJACENT_LAND, # Returned with the left of the two
	TWO_OPPOSITE_LAND, # Returned with arbitrary one of the two 
	ONE_LAND,
	NONE_LAND,
}


## This is false for tiles that shouldn't change type during generation,  
## such as tiles involved in a POI. 
## TODO: Any chunk that ChunkManager places initially should be changeable, and any POI 
## chunks placed on top should not be changeable. 
@export var can_change_type := false

@export_subgroup("Connections")
## The directions off of this Chunk that are valid chunks to 
## connect to when finding a chunk-level path to the POI owning this Chunk.
@export var poi_connection_dirs: Array[ConnectionDir] = []:
	set(value):
		poi_connection_dirs = value
		_on_poi_connection_dirs_changed()

## If true, then any number of POIs can connect to this chunk's connective chunks. 
@export var allows_infinite_connections := false
## Only applies if not allowing infinite connections. The exact number of connections allowed. 
@export_range(0, 8, 1) var num_connections_allowed := 0
var connection_count := 0
## Node2D parenting visual indicators, automatically generated and updated in-editor 
## to show which directions are viable connections for this chunk.
@onready var connection_sprites: ChunkConnectionSprites = $ChunkConnectionSprites



## Tilemap describing where required land/air and adaptive land/air tiles are. 
## If a tile is unfilled, defaults to the adaptive tile of the current Type.  
const CHUNK_TILEMAP_SOURCE_ID := 0
const LAND_CHUNK_TILE_COORDS := Vector2i(0, 0)
const ADAPTIVE_CHUNK_TILE_COORDS := Vector2i(2, 0)
const AIR_CHUNK_TILE_COORDS := Vector2i(1, 0)
#endregion Attributes

#region Builtins
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_validate_position_in_editor()

func _validate_position_in_editor() -> void:
	if Engine.is_editor_hint():
		assert(
			int(position.x) == position.x and
			int(position.x) % CHUNK_DIMENSIONS.x == 0 and 
			int(position.x) == position.y and
			int(position.y) % CHUNK_DIMENSIONS.y == 0
			, "Non-chunk size multiple position was " + str(position)
		)

func set_to_unchangeable_type_and_default(_type: Type = Type.LAND):
	type = _type
	can_change_type = false
	_replace_chunk_tilemap_with_defaults()

func set_to_changeable_type_and_default(_type: Type = Type.LAND):
	type = _type
	can_change_type = true
	_replace_chunk_tilemap_with_defaults()
	

func _replace_chunk_tilemap_with_defaults() -> void:
	clear()
	for coord in get_all_coords_in_chunk():
		match type:
			Type.AIR:
				set_cell(coord, CHUNK_TILEMAP_SOURCE_ID, AIR_CHUNK_TILE_COORDS)
			Type.LAND:
				set_cell(coord, CHUNK_TILEMAP_SOURCE_ID, ADAPTIVE_CHUNK_TILE_COORDS)

#endregion Builtins

#region Public methods
## Fills in the chunk based on its type and potentially its neighbors. Returns the
## wall tiles this chunk inhabits. 
## TODO return BG tiles too. 
## Returns the tiles it would place in local coordinates. 
## For non-adaptive tiles, adds them to the land tiles array if they are land.
## For adaptive tiles, TODO does magic to decide which of them are land.
## This method expects that the chunk tilemap has been populated based on the Chunk's Type.
func decide_tiles(is_land_dict: Dictionary[Vector2i, bool]) -> Array[Vector2i]:
	var valid_adaptive_coords: Array[Vector2i]
	if is_land():
		var neighbors_type_and_air_dir := get_neighbors_type_and_air_dir(is_land_dict)
		var neighbors_type: NeighborsType = neighbors_type_and_air_dir[0]
		var air_dir: Vector2i = neighbors_type_and_air_dir[1]
		valid_adaptive_coords = pick_valid_adaptive_coords(neighbors_type, air_dir)
	
	var wall_tiles: Array[Vector2i]
	
	for coords in get_used_cells():
		var atlas_coords = get_cell_atlas_coords(coords)
		match atlas_coords:
			LAND_CHUNK_TILE_COORDS:
				wall_tiles.append(coords)
			ADAPTIVE_CHUNK_TILE_COORDS:
				if valid_adaptive_coords.has(coords):
					wall_tiles.append(coords)
			AIR_CHUNK_TILE_COORDS:
				pass # no tiles in air
	return wall_tiles

## increments the number of connections this chunk has.
func add_connection() -> void:
	assert(can_add_connection())
	connection_count += 1

func can_add_connection() -> bool:
	return (allows_infinite_connections or (connection_count + 1 <= num_connections_allowed)) \
	 	and poi_connection_dirs.size() > 0

#endregion Public methods

#region Helpers
## Returns all tile coords
func get_all_coords_in_chunk() -> Array[Vector2i]:
	var tiles: Array[Vector2i]
	for x in range(CHUNK_DIMENSIONS.x):
		for y in range(CHUNK_DIMENSIONS.y):
			tiles.append(Vector2i(x, y))
	return tiles

func convert_connection_dir_to_vector2i(dir: ConnectionDir) -> Vector2i:
	var result: Vector2i
	match dir:
		ConnectionDir.LEFT:         result = Vector2i.LEFT
		ConnectionDir.RIGHT:        result = Vector2i.RIGHT
		ConnectionDir.UP:           result = Vector2i.UP
		ConnectionDir.DOWN:         result = Vector2i.DOWN
		ConnectionDir.TOP_LEFT:     result = TOP_LEFT
		ConnectionDir.TOP_RIGHT:    result = TOP_RIGHT
		ConnectionDir.BOTTOM_LEFT:  result = BOTTOM_LEFT
		ConnectionDir.BOTTOM_RIGHT: result = BOTTOM_RIGHT
		_:
			push_error("Invalid ConnectionDir passed to convert_connection_dir_to_vector2i")
			assert(false)
	return result

func get_all_connection_dirs_as_vector2is() -> Array[Vector2i]:
	var connection_coords: Array[Vector2i] = []
	for dir in poi_connection_dirs:
		connection_coords.append(convert_connection_dir_to_vector2i(dir))
	return connection_coords

func _on_poi_connection_dirs_changed() -> void:
	if Engine.is_editor_hint() and is_instance_valid(connection_sprites) and connection_sprites != null:
		connection_sprites.regenerate()

func is_unchangeable() -> bool:
	return not can_change_type

## Returns [NeighborsType, air_dir: Vector2i]. Air dir is only needed for certain neighbors types. 
func get_neighbors_type_and_air_dir(is_land_dict: Dictionary[Vector2i, bool]) -> Array:
	var land_neighbor_dirs: Array[Vector2i]
	for dir in is_land_dict:
		if is_land_dict[dir]:
			land_neighbor_dirs.append(dir)
	
	match land_neighbor_dirs.size():
		0:
			return [NeighborsType.NONE_LAND, Vector2i.ZERO]
		1: # Find it, then return opposite dir as air dir
			return [NeighborsType.ONE_LAND, -land_neighbor_dirs[0]]
		2: # Check for opposite-ness
			var neighbors_opposite := land_neighbor_dirs[0] == -land_neighbor_dirs[1]
			if neighbors_opposite:
				var neighbor := land_neighbor_dirs[0] # Doesn't matter which
				var air_dir = Vector2i(neighbor.y, -neighbor.x) # Rotate 90 deg cw
				return [NeighborsType.TWO_OPPOSITE_LAND, air_dir]
			else:
				# Sum, then negate the two adjacent dirs for air_dir
				var air_dir = -(land_neighbor_dirs[0] + land_neighbor_dirs[1])
				return [NeighborsType.TWO_ADJACENT_LAND, air_dir]
		3: # Negate the sum of neighbor directions as air dir
			var sum_dir := Vector2i.ZERO
			for dir in land_neighbor_dirs:
				sum_dir += dir
			var air_dir = -sum_dir
			return [NeighborsType.THREE_LAND, air_dir]
		4:
			return [NeighborsType.ALL_LAND, Vector2i.ZERO]
		_:
			assert(false, "Num neighbors of a chunk exceeded 4: " + str(land_neighbor_dirs.size()))
			return [NeighborsType.NONE_LAND, Vector2i.ZERO]



func pick_valid_adaptive_coords(neighbors_type: NeighborsType, air_dir: Vector2i) -> Array[Vector2i]:
	var coords: Array[Vector2i]
	match neighbors_type:
		NeighborsType.ALL_LAND:
			coords = get_all_coords_in_chunk()
		NeighborsType.THREE_LAND:
			coords = get_all_coords_in_chunk() # could make this more complex
		NeighborsType.TWO_ADJACENT_LAND:
			# air dir points to the corner between two air sides, with vector x, y of 1 or -1
			# We want to choose a root coord from which we want to measure manhattan distance to create
			# diagonal slopes
			# Convert air_dir to that root coord
			# (-1, -1) -> (7, 7)
			# (1, 1) -> (0, 0)
			var land_corner_coord = ((air_dir * -1 + Vector2i.ONE) / 2) * (Chunk.CHUNK_DIMENSIONS - Vector2i.ONE)
			
			# Only allow tiles that are half-chunk of dist away
			for coord in get_all_coords_in_chunk():
				if abs_diff(coord.x, land_corner_coord.x) < CHUNK_DIMENSIONS.x / 2 and\
					abs_diff(coord.y, land_corner_coord.y) < CHUNK_DIMENSIONS.y / 2:
					coords.append(coord)
		NeighborsType.TWO_OPPOSITE_LAND:
			const TUNNEL_RADIUS := 3
			const CENTER_X := CHUNK_DIMENSIONS.x / 2
			const CENTER_Y := CHUNK_DIMENSIONS.y / 2
			var is_hoz_tunnel: bool = abs(air_dir.x) > 0
			for coord in get_all_coords_in_chunk():
				if is_hoz_tunnel:
					if abs_diff(CENTER_Y, coord.y) >= TUNNEL_RADIUS:
						coords.append(coord)
				else:
					if abs_diff(CENTER_X, coord.x) >= TUNNEL_RADIUS:
						coords.append(coord)
		NeighborsType.ONE_LAND:
			var spike_root_coord = ((air_dir * -1 + Vector2i.ONE) / 2) * (Chunk.CHUNK_DIMENSIONS - Vector2i.ONE)
			for coord in get_all_coords_in_chunk():
				if manhattan_dist(spike_root_coord, coord) <= CHUNK_DIMENSIONS.x / 2:
					coords.append(coord)
		NeighborsType.NONE_LAND:
			const CENTER := CHUNK_DIMENSIONS / 2
			for coord in get_all_coords_in_chunk():
				if abs_diff(coord.x, CENTER.x) < CHUNK_DIMENSIONS.x / 4 and\
					abs_diff(coord.y, CENTER.y) < CHUNK_DIMENSIONS.y / 4:
						coords.append(coord)
	return coords

func abs_diff(a: int, b: int) -> int:
	return abs(a - b)
func manhattan_dist(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func is_land() -> bool:
	return type == Type.LAND
#endregion Helpers
