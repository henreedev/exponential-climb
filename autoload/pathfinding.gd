extends Node2D

# Configurable parameters
@export var cell_size: int = 8
@export var jump_height: int = 2
@export var jump_distance: int = 2
@export var show_lines: bool = true

var tile_map_layer: TileMapLayer
var graph: AStar2D = AStar2D.new()

const INDICATOR_SCENE = preload("res://scenes/enemy/pathfinding_indicator.tscn")

func find_path(start: Vector2, end: Vector2) -> Array:
	print("Finding path from ", start, " to ", end)
	var start_point = graph.get_closest_point(start)
	var end_point = graph.get_closest_point(end)
	print("Points: ", start_point, " to ", end_point)
	var path = graph.get_id_path(start_point, end_point)
	print("Path: ", path)
	if path.is_empty():
		return []

	var actions: Array = []
	var last_pos: Vector2

	for point_id in path:
		var pos = graph.get_point_position(point_id)
		var cell_status = get_cell_status(pos, true, true)

		if last_pos and can_jump(last_pos, pos, cell_status):
			actions.append(null)

		if point_id == path[0] and path.size() > 1:
			var next_pos = graph.get_point_position(path[1])
			if start.distance_to(next_pos) > pos.distance_to(next_pos):
				actions.append(pos)
		elif point_id == path[-1] and path.size() > 1:
			if graph.get_point_position(path[-2]).distance_to(end) < pos.distance_to(end):
				actions.append(pos)
		else:
			actions.append(pos)

		last_pos = pos

	actions.append(end)
	print("Actions: ", actions)
	return actions

func update_graph():
	graph.clear()
	tile_map_layer = get_tree().get_nodes_in_group("tilemap")[-1] as TileMapLayer
	build_map()
	build_connections()

func build_map():
	var used_cells = tile_map_layer.get_used_cells()
	for cell in used_cells:
		var cell_status = get_cell_status(cell)
		if cell_status:
			add_graph_point(cell)

			if cell_status[1] == -1:
				add_graph_point(find_below_point(cell, Vector2.RIGHT))
			if cell_status[0] == -1:
				add_graph_point(find_below_point(cell, Vector2.LEFT))

func build_connections():
	for point_id in graph.get_point_ids():
		var pos = graph.get_point_position(point_id)
		var cell_status = get_cell_status(pos, true, true)

		var connections = []
		var one_way_connections = []

		for other_id in graph.get_point_ids():
			if point_id == other_id:
				continue
			
			var other_pos = graph.get_point_position(other_id)
			if cell_status and cell_status[1] == 0 and is_direct_right(pos, other_pos):
				connections.append(other_id)
			if cell_status and cell_status[0] == -1 and is_valid_jump_left(pos, other_pos):
				connections.append(other_id)
			if cell_status and cell_status[1] == -1 and is_valid_jump_right(pos, other_pos):
				connections.append(other_id)

		for conn_id in connections:
			graph.connect_points(point_id, conn_id)

		for conn_id in one_way_connections:
			graph.connect_points(point_id, conn_id, false)

func get_cell_status(pos: Vector2, global: bool = false, is_above: bool = false) -> Vector2:
	if global:
		pos = tile_map_layer.local_to_map(pos)
	if is_above:
		pos += Vector2.DOWN
	
	var results = Vector2.ZERO
	
	# Check that this is a valid tile
	if not is_wall(pos) or is_wall(pos + Vector2.UP, true): 
		return Vector2.ZERO

	# Check left
	if is_wall(pos + Vector2.LEFT + Vector2.UP):
		results.x = 1
	elif not is_wall(pos + Vector2.LEFT):
		results.x = -1

	# Check right
	if is_wall(pos + Vector2.RIGHT + Vector2.UP):
		results.y = 1
	elif not is_wall(pos + Vector2.RIGHT):
		results.y = -1

	return results

func is_wall(cell : Vector2, count_wall_inside := false):
	if count_wall_inside:
		if tile_map_layer.get_cell_tile_data(cell):
			return true
	else:
		if tile_map_layer.get_cell_tile_data(cell) and tile_map_layer.get_cell_atlas_coords(cell) \
				!= Room.TERRAIN_WALL_INSIDE_ATLAS_COORDS:
			return true
	return false

func add_graph_point(cell: Vector2):
	if cell == Vector2.INF: return
	var above_cell = cell + Vector2.UP
	var pos = tile_map_layer.map_to_local(above_cell) 
	if graph.get_point_count() and graph.get_point_position(graph.get_closest_point(pos)).distance_to(pos) < cell_size:
		return
	
	graph.add_point(graph.get_available_point_id(), pos)
	
	if show_lines:
		var indicator = INDICATOR_SCENE.instantiate()
		indicator.position = pos 
		tile_map_layer.add_child(indicator)

func find_below_point(cell: Vector2, direction: Vector2) -> Vector2:
	var start_pos = tile_map_layer.map_to_local(cell + direction)
	var end_pos = start_pos + Vector2(0, 1000)
	var space_state = get_world_2d().direct_space_state
	var result = space_state.intersect_ray(PhysicsRayQueryParameters2D.create(start_pos, end_pos, 4))
	return result.position if result else Vector2.INF

func can_jump(from_pos: Vector2, to_pos: Vector2, cell_status: Vector2) -> bool:
	return false
	return from_pos.y >= to_pos.y - (cell_size * jump_height) and (
		(from_pos.x < to_pos.x and cell_status.x < 0) or 
		(from_pos.x > to_pos.x and cell_status.y < 0)
	)

func is_direct_right(pos: Vector2, other_pos: Vector2) -> bool:
	return pos.y == other_pos.y and other_pos.x > pos.x

func is_valid_jump_left(pos: Vector2, other_pos: Vector2) -> bool:
	return false
	return pos.x - cell_size * jump_distance <= other_pos.x and other_pos.x < pos.x and \
		   other_pos.y >= pos.y - (cell_size * jump_height) and \
		   get_cell_status(other_pos, true, true).y == -1

func is_valid_jump_right(pos: Vector2, other_pos: Vector2) -> bool:
	return false
	return pos.x < other_pos.x and other_pos.x <= pos.x + cell_size * jump_distance and \
		   other_pos.y >= pos.y - (cell_size * jump_height) and \
		   get_cell_status(other_pos, true, true).x == -1
