extends Node2D

# Configurable parameters
@export var cell_size: int = 8
@export var jump_height: int = 10
@export var jump_distance: int = 10
@export var show_lines: bool = true

var tile_map_layer: TileMapLayer
var graph: AStar2D = AStar2D.new()
var no_diagonal_graph: AStar2D = AStar2D.new()

const INDICATOR_SCENE = preload("res://scenes/enemy/pathfinding_indicator.tscn")
const LINE_SCENE = preload("res://scenes/enemy/indicator_line.tscn")

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
	var line : Line2D
	for point_id in path:
		var pos = graph.get_point_position(point_id)
		if show_lines:
			if not line:
				line = LINE_SCENE.instantiate()
				line.default_color = Color.from_hsv(randf(), 1, 1)
				line.width = 2.5
			line.add_point(pos)
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

	if show_lines:
		tile_map_layer.add_child(line)
	actions.append(end)
	print("Actions: ", actions)
	return actions

func update_graph():
	graph.clear()
	no_diagonal_graph.clear()
	tile_map_layer = get_tree().get_nodes_in_group("tilemap")[-1] as TileMapLayer
	build_map()
	build_connections()

func build_map():
	var used_cells = tile_map_layer.get_used_cells()
	for cell in used_cells:
		var cell_status = get_cell_status(cell, false, false)
		if cell_status:
			add_graph_point(cell)

			if cell_status.x == -1:
				add_graph_point(find_below_point(cell, Vector2.LEFT))
			if cell_status.y == -1:
				add_graph_point(find_below_point(cell, Vector2.RIGHT))
		var no_diag_cell_status = get_cell_status(cell, false, false, true)
		if no_diag_cell_status:
			add_no_diag_graph_point(cell)

			if no_diag_cell_status.x == -1:
				add_no_diag_graph_point(find_below_point(cell, Vector2.LEFT))
			if no_diag_cell_status.y == -1:
				add_no_diag_graph_point(find_below_point(cell, Vector2.RIGHT))

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
			if cell_status and cell_status.y == 0 and right_diagonal_path_exists(pos, other_pos):
				connections.append(other_id)
			if cell_status and cell_status.x == -1 and is_valid_jump_left(pos, other_pos):
				connections.append(other_id)
				print("Left jump added")
			if cell_status and cell_status.y == -1 and is_valid_jump_right(pos, other_pos):
				connections.append(other_id)
				print("Right jump added")

		for conn_id in connections:
			if show_lines:
				var line : Line2D = LINE_SCENE.instantiate()
				line.add_point(graph.get_point_position(point_id))
				line.add_point(graph.get_point_position(conn_id))
				tile_map_layer.add_child(line)
			graph.connect_points(point_id, conn_id)

		for conn_id in one_way_connections:
			if show_lines:
				var line : Line2D = LINE_SCENE.instantiate()
				line.default_color = Color.PALE_GREEN
				line.add_point(graph.get_point_position(point_id))
				line.add_point(graph.get_point_position(conn_id))
				tile_map_layer.add_child(line)
			graph.connect_points(point_id, conn_id, false)

func get_cell_status(pos: Vector2, global: bool = false, is_above: bool = false, \
					 ignore_diagonal_movement := false) -> Vector2:
	if not tile_map_layer: tile_map_layer = get_tree().get_first_node_in_group("tilemap")
	if global:
		pos = tile_map_layer.local_to_map(pos)
	if is_above:
		pos += Vector2.DOWN
	
	var results = Vector2.ZERO
	
	# Check that this is a valid tile
	if not is_wall(pos) or is_wall(pos + Vector2.UP, true): 
		return Vector2.ZERO

	if ignore_diagonal_movement:
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
	else:
		# Check left
		if is_wall(pos + Vector2.LEFT + Vector2.UP * 2):
			results.x = 1
		# Are the four tiles to the left and down empty? Then this is a valid left drop
		elif not is_wall(pos + Vector2.LEFT) \
			#and not is_wall(pos + Vector2.LEFT * 2) \ # For enemy width > 1 tile
			and not is_wall(pos + Vector2.LEFT + Vector2.DOWN): \
			#and not is_wall(pos + Vector2.LEFT * 2 + Vector2.DOWN): # For enemy width > 1 tile
			results.x = -1
		# Check right
		if is_wall(pos + Vector2.RIGHT + Vector2.UP * 2):
			results.y = 1
		elif not is_wall(pos + Vector2.RIGHT) \
			#and not is_wall(pos + Vector2.RIGHT * 2)\ # For enemy width > 1 tile
			and not is_wall(pos + Vector2.RIGHT + Vector2.DOWN): \
			#and not is_wall(pos + Vector2.RIGHT * 2 + Vector2.DOWN): # For enemy width > 1 tile
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
		make_debug_dot(pos)

func add_no_diag_graph_point(cell: Vector2):
	if cell == Vector2.INF: return
	var above_cell = cell + Vector2.UP
	var pos = tile_map_layer.map_to_local(above_cell) 
	if no_diagonal_graph.get_point_count() and no_diagonal_graph.get_point_position(no_diagonal_graph.get_closest_point(pos)).distance_to(pos) < cell_size:
		return
	
	no_diagonal_graph.add_point(no_diagonal_graph.get_available_point_id(), pos)
	
	if show_lines:
		make_debug_dot(pos + Vector2.UP * cell_size)

func find_below_point(cell: Vector2, direction: Vector2) -> Vector2:
	var start_pos = tile_map_layer.map_to_local(cell + direction)
	var end_pos = start_pos + Vector2(0, 1000)
	var hit_pos = do_raycast(start_pos, end_pos)
	if hit_pos == Vector2.INF:
		return hit_pos
	return tile_map_layer.local_to_map(hit_pos)

func can_jump(from_pos: Vector2, to_pos: Vector2, cell_status: Vector2) -> bool:
	return from_pos.y >= to_pos.y - (cell_size * jump_height) and (
		(from_pos.x < to_pos.x and cell_status.x < 0) or 
		(from_pos.x > to_pos.x and cell_status.y < 0)
	)

## Searches from a starting point to an ending point, returning whether there's a path between the two that can be travelled without jumping. 
func right_diagonal_path_exists(from_pos: Vector2, to_pos: Vector2):
	var from_id = no_diagonal_graph.get_closest_point(from_pos)
	var to_id = no_diagonal_graph.get_closest_point(to_pos)
	var curr_id = from_id
	var visited = [curr_id]
	var line : Line2D
	while curr_id != -1:
		if curr_id == to_id:
			print("Diagonal pathfinding returning true")
			if show_lines:
				tile_map_layer.add_child(line)
			return true
		var curr_pos = no_diagonal_graph.get_point_position(curr_id)
		if show_lines:
			if not line:
				line = LINE_SCENE.instantiate()
				line.default_color = Color.from_hsv(randf() * 0.2 + 0.8, 1, 1)
				line.modulate.a = 1.0
				line.width = 5
			line.add_point(curr_pos)
		var found = false
		for next_id in no_diagonal_graph.get_point_ids(): # TODO improve with spatial partitioning
			if visited.has(next_id): 
				continue
			var next_pos = no_diagonal_graph.get_point_position(next_id)
			var adj_case = is_adjacent(curr_pos, next_pos)
			var hoz_case = is_direct_right(curr_pos, next_pos)
			var los_case = do_raycast(curr_pos, next_pos) == Vector2.INF
			var flat_case = is_flat_ground(curr_pos, next_pos)

			
			if adj_case or (hoz_case and los_case and flat_case):
				found = true
				curr_id = next_id
				visited.append(next_id)
				break
		if not found: curr_id = -1
	if show_lines:
		tile_map_layer.add_child(line)
	print("Diagonal pathfinding returning false")
	return false

func is_adjacent(pos: Vector2, other_pos: Vector2):
	const directions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, -1),  # Up-Right
		Vector2i(1, 0),   # Right
		Vector2i(1, 1),   # Down-Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 1),  # Down-Left
		Vector2i(-1, 0),  # Left
		Vector2i(-1, -1)  # Up-Left
	]
	for dir in directions:
		dir = Vector2(dir)
		dir *= cell_size
		if pos.is_equal_approx(other_pos + dir):
			return true
	return false

func is_direct_right(pos: Vector2, other_pos: Vector2) -> bool:
	return pos.y == other_pos.y and other_pos.x > pos.x

func do_raycast(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos, 4)
	query.hit_from_inside = true
	var result = space_state.intersect_ray(query)
	return result["position"] if result else Vector2.INF

func is_flat_ground(from_pos: Vector2, to_pos: Vector2, raycasts := 4) -> bool:
	if from_pos.y == -4.0 and to_pos.y == -4.0:
		print()
	if from_pos.y != to_pos.y: 
		return false
	var flat_y = -INF
	for i in range(raycasts):
		var intermed_pos = lerp(from_pos, to_pos, float(i + 1) / (raycasts + 1))
		var hit_y = do_raycast(intermed_pos, intermed_pos + Vector2(0, 10)).y
		if flat_y == -INF: 
			flat_y = hit_y
		if abs(hit_y - flat_y) > cell_size / 2 or flat_y == INF:
			return false
	return true

func is_valid_jump_left(pos: Vector2, other_pos: Vector2) -> bool:
	var cond = pos.x - cell_size * (jump_distance + 2) <= other_pos.x and \
			other_pos.x < pos.x and \
		   other_pos.y >= pos.y - (cell_size * jump_height) and \
		   get_cell_status(other_pos, true, true).y == -1 and \
			do_raycast(pos, other_pos) == Vector2.INF
	if cond: make_debug_line(pos, other_pos, Color.GREEN_YELLOW)
	return cond

func is_valid_jump_right(pos: Vector2, other_pos: Vector2) -> bool:
	var cond = pos.x < other_pos.x and other_pos.x <= pos.x + cell_size * (jump_distance + 2) and \
		   other_pos.y >= pos.y - (cell_size * jump_height) and \
		   get_cell_status(other_pos, true, true).x == -1 and \
			do_raycast(pos, other_pos) == Vector2.INF
	if cond: make_debug_line(pos, other_pos, Color.MEDIUM_VIOLET_RED)
	return cond

func make_debug_line(pos: Vector2, other_pos: Vector2, color := Color.BLACK):
	var line : Line2D = LINE_SCENE.instantiate()
	if color != Color.BLACK:
		line.default_color = color
	line.add_point(pos)
	line.add_point(other_pos)
	tile_map_layer.add_child(line)

func make_debug_dot(pos: Vector2, size_mult := 1.0):
	var dot : Sprite2D = INDICATOR_SCENE.instantiate()
	dot.scale *= size_mult
	dot.position = pos
	dot.z_index = 1
	tile_map_layer.add_child(dot)
