extends Node2D

## The Pathfinding class. 
## Generates an enemy pathfinding graph given the wall tiles.
## Finds paths within the graph using A*.

# Configurable parameters
## The size of wall tiles.
@export var cell_size: int = 8
## The maximum vertical distance two nodes can be placed apart when expecting the enemy to jump.
@export var jump_height: int = 11
## The maximum horizontal distance two nodes can be placed apart when expecting the enemy to jump.
@export var jump_distance: int = 12
## Shows node locations and colored path lines for debugging.
@export var show_lines := true

## The WALL tilemap layer.
var tile_map_layer: TileMapLayer
## The graph of points and connections the enemy can travel between.
var graph: AStar2D = AStar2D.new()
## The same graph, but does not account for diagonal movement; 
## assumes every tile is square and has to be jumped over if encountered horizontally.
var no_diagonal_graph: AStar2D = AStar2D.new()

## Dictionary from grid cell position to point_ids in that grid cell
var spatial_grid : Dictionary[Vector2, Array]
var spatial_grid_cell_size = 16
## The image placed on each point when `show_lines` is true.
const INDICATOR_SCENE = preload("res://scenes/enemy/pathfinding_indicator.tscn")
## The line drawn along connections or paths.
const LINE_SCENE = preload("res://scenes/enemy/indicator_line.tscn")

## Sorts the given position into a spatial grid slot using integer division.
func get_cell_pos(point_pos : Vector2):
	return Vector2(floor(point_pos.x / cell_size), floor(point_pos.y / cell_size))

## Adds a point to the spatial partitioning grid.
func add_point_to_grid(point_id : int, point_pos : Vector2):
	var cell_pos : Vector2 = get_cell_pos(point_pos)
	if not spatial_grid.has(cell_pos):
		spatial_grid[cell_pos] = []
	spatial_grid[cell_pos].append(point_id)

## Returns a list of all point ids in cells to the right of the given point's cell. 
func get_right_points(point_pos : Vector2, max_cell_dist := 20):
	var right_points := []
	var cell_pos = get_cell_pos(point_pos)
	for x in range(cell_pos.x, cell_pos.x + max_cell_dist):
		cell_pos = Vector2(x, cell_pos.y)
		if spatial_grid.has(cell_pos):
			right_points.append_array(spatial_grid[cell_pos])
	return right_points

## Returns a list of all point ids in cells right-adjacent to this point (top right, right, bottom right)
func get_right_adj_points(point_pos: Vector2):
	var right_adj_points := []
	var cell_pos = get_cell_pos(point_pos)
	
	# Add top-right points
	var top_right_cell_pos = cell_pos + Vector2(1, -1)
	if spatial_grid.has(top_right_cell_pos):
		right_adj_points.append_array(spatial_grid[top_right_cell_pos])
	# Add right points
	var right_cell_pos = cell_pos + Vector2.RIGHT
	if spatial_grid.has(right_cell_pos):
		right_adj_points.append_array(spatial_grid[right_cell_pos])
	# Add bottom-right points
	var bot_right_cell_pos = cell_pos + Vector2(1, 1)
	if spatial_grid.has(bot_right_cell_pos):
		right_adj_points.append_array(spatial_grid[bot_right_cell_pos])
	
	return right_adj_points



## Takes start and end points in global coordinates and returns an array of actions, 
## where each action is either a point to path towards or a jump command (null). 
func find_path(start_pos: Vector2, end_pos: Vector2) -> Array:
	# Find the id of the start point and store it
	# Find the id of the end point and store it
	# Find the graph's id path between those ids
	# For each id in the path, add it to the actions as a position
	# If need to jump to next position, append null as an action
	print("Finding path from ", start_pos, " to ", end_pos)
	var time = Time.get_ticks_usec()
	var start_point = graph.get_closest_point(start_pos)
	var end_point = graph.get_closest_point(end_pos)
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
			if next_pos.distance_to(start_pos) > next_pos.distance_to(pos):
				actions.append(pos)
		elif point_id == path[-1] and path.size() > 1:
			if graph.get_point_position(path[-2]).distance_to(end_pos) < pos.distance_to(end_pos):
				actions.append(pos)
		else:
			actions.append(pos)

		last_pos = pos
	# If the end point is directly accessible, go straight there 
	# instead of to a nearby point first
	if len(actions) <= 1:
		actions.clear() 
	actions.append(end_pos)
	# If showing debug lines, for each action, add a point to a debug line at its position, 
	# and add a vertically raised point from the last one if the action is a jump
	if show_lines:
		var line : Line2D = LINE_SCENE.instantiate()
		line.default_color = Color.from_hsv(randf(), 1, 1)
		line.width = 2.5
		var last_debug_pos = start_pos
		for pos in actions:
			if pos:
				line.add_point(pos)
			else:
				line.add_point(last_debug_pos + (Vector2.UP * jump_height * cell_size))
			last_debug_pos = pos
		tile_map_layer.add_child(line)
	print("Actions: ", actions)
	print("Found path in ", Time.get_ticks_usec() - time, " us")
	return actions

func update_graph():
	graph.clear()
	no_diagonal_graph.clear()
	spatial_grid.clear()
	tile_map_layer = get_tree().get_nodes_in_group("tilemap")[-1] as TileMapLayer
	# Generate the graph (map), timing it
	var time = Time.get_ticks_msec()
	build_map()
	print("Built map in ", Time.get_ticks_msec() - time, " ms")
	print(spatial_grid)
	# Generate the graph (map) connections, timing it
	time = Time.get_ticks_msec()
	build_connections()
	print("Built connections in ", Time.get_ticks_msec() - time, " ms")
	
	no_diagonal_graph.clear() # Clear memory, was only used for generation of `graph`
	spatial_grid.clear() # Same thing
	
	# Print out ids for debugging
	if show_lines:
		var ids = graph.get_point_ids()
		ids.sort()
		for id in ids:
			print("{", id, ": ", graph.get_point_connections(id), "}")

func build_map():
	var used_cells = tile_map_layer.get_used_cells()
	for cell in used_cells:
		if not is_wall(cell): 
			continue
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
		
		var tile_pos = Vector2(tile_map_layer.local_to_map(pos)) + Vector2.DOWN

		# Add drop connections by: 
		# 1. Raycasting down the left and right drops to find the drop point 
		# (which should have been placed there in build_map())
		# 2. Determining if enemy can jump from the bottom drop to the higher point; 
		# if so, bidirectional connection, else one-way connection
		if cell_status:
			if cell_status.x == -1: # There's a drop on the left of this tile
				var left_drop = find_below_point(Vector2(tile_map_layer.local_to_map(pos)) + Vector2.DOWN, Vector2.LEFT)
				if left_drop != Vector2.INF:
					var left_drop_pos = tile_map_layer.map_to_local(left_drop)
					var left_drop_id = graph.get_closest_point(left_drop_pos)
					# If can jump back up, the connection should be bidirectional
					var can_jump_back_up = tile_pos.distance_to(left_drop) <= jump_height
					if can_jump_back_up:
						connections.append(left_drop_id)
					else:
						one_way_connections.append(left_drop_id)
			if cell_status.y == -1: # There's a right drop
				var right_drop = find_below_point(Vector2(tile_map_layer.local_to_map(pos)) + Vector2.DOWN, Vector2.RIGHT)
				if right_drop != Vector2.INF:
					var right_drop_pos = tile_map_layer.map_to_local(right_drop)
					var right_drop_id = graph.get_closest_point(right_drop_pos)
					# If can jump back up, the connection should be bidirectional
					var can_jump_back_up = tile_pos.distance_to(right_drop) <= jump_height
					if can_jump_back_up:
						connections.append(right_drop_id)
					else:
						one_way_connections.append(right_drop_id)
		# Loop through all other ids to see if a connection can be formed with it.
		for other_id in graph.get_point_ids():
			if point_id == other_id:
				continue
			if point_id == 8 and other_id == 0:
				point_id # TODO remove
			var other_pos = graph.get_point_position(other_id)
			if cell_status.y == 0 and right_diagonal_path_exists(pos, other_pos):
				connections.append(other_id)
			if cell_status and cell_status.x == -1 and is_valid_jump_left(pos, other_pos):
				one_way_connections.append(other_id)
			if cell_status and cell_status.y == -1 and is_valid_jump_right(pos, other_pos):
				one_way_connections.append(other_id)

		# Finish up two-way connections, drawing debug lines as necessary
		for conn_id in connections:
			if show_lines:
				make_debug_line(graph.get_point_position(point_id), graph.get_point_position(conn_id))
			graph.connect_points(point_id, conn_id)

		# Finish up one-way connections, drawing different color debug lines as necessary
		for conn_id in one_way_connections:
			if show_lines:
				make_debug_line(graph.get_point_position(point_id), graph.get_point_position(conn_id), Color.PALE_GREEN)
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
	if not is_wall(pos) or \
			is_wall(pos + Vector2.UP, true) or \
			is_wall(pos + Vector2.UP * 2, true) or \
			is_wall(pos + Vector2.UP * 3, true) or \
			is_wall(pos + Vector2.UP * 4, true): 
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
		# Are the tiles to the left and down empty? Then this is a valid left drop
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
	var id = no_diagonal_graph.get_available_point_id()
	no_diagonal_graph.add_point(id, pos)
	add_point_to_grid(id, pos)
	if show_lines:
		make_debug_dot(pos + Vector2.UP * cell_size)

func find_below_point(cell: Vector2, direction: Vector2) -> Vector2:
	var start_pos = tile_map_layer.map_to_local(cell + direction)
	var end_pos = start_pos + Vector2(0, 1000)
	var hit_pos = do_raycast(start_pos, end_pos)
	if hit_pos == Vector2.INF:
		return hit_pos
	return tile_map_layer.local_to_map(hit_pos)

## Can jump between given positions if 
## 1. Starting y plus jump height is as high or higher than ending y
## 2. Starting x is to the left of ending x, and ending position has a left drop
## 2. Starting x is to the right of ending x, and ending position has a right drop
func can_jump(from_pos: Vector2, to_pos: Vector2, cell_status: Vector2) -> bool:
	return from_pos.y - (cell_size * jump_height) <= to_pos.y and (
		(from_pos.x < to_pos.x and cell_status.x == -1) or 
		(from_pos.x > to_pos.x and cell_status.y == -1)
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
			if show_lines:
				if not line: 
					make_debug_line(from_pos, to_pos, Color.CORNSILK)
				else:
					tile_map_layer.add_child(line)
			return true
		var curr_pos = no_diagonal_graph.get_point_position(curr_id)
		if show_lines:
			if not line:
				line = LINE_SCENE.instantiate()
				line.default_color = Color.from_hsv(randf() * 0.2 + 0.8, 1, 0.2)
				line.modulate.a = 1.0
				line.width = 5
			line.add_point(curr_pos)
		var found = false
		var found_x = INF
		var found_id = -1
		# Get ids in adjacent spatial cells or cells to the direct right
		var relevant_ids = []
		relevant_ids.append_array(get_right_adj_points(curr_pos))
		relevant_ids.append_array(get_right_points(curr_pos))
		for next_id in relevant_ids: 
			if visited.has(next_id): 
				continue 
			var next_pos = no_diagonal_graph.get_point_position(next_id)
			# Check:
			# 1. Within bounds: next x is not to the right of target x
			# 2. Adjacent: If point is adjacent (to the right), definitely can walk between
			# Or, 3. Directly to the right; 4. Line of sight isn't obstructed;  5. Ground is flat between points
			# If all 3 ^, definitely can walk between
			if next_pos.x <= to_pos.x and \
				(is_right_adjacent(curr_pos, next_pos) or \
					(is_direct_right(curr_pos, next_pos) and \
					do_raycast(curr_pos, next_pos) == Vector2.INF and \
					is_flat_ground(curr_pos, next_pos))):
			
			#var within_bounds_case = next_pos.x <= to_pos.x
			#var adj_case = is_right_adjacent(curr_pos, next_pos)
			#var hoz_case = is_direct_right(curr_pos, next_pos)
			#var los_case = do_raycast(curr_pos, next_pos) == Vector2.INF
			#var flat_case = is_flat_ground(curr_pos, next_pos)
			#if within_bounds_case and (adj_case or (hoz_case and los_case and flat_case)):
				found = true
				if next_pos.x < found_x: 
					found_id = next_id
		if found:
			curr_id = found_id
			visited.append(found_id)
		else: 
			curr_id = -1
	if show_lines:
		tile_map_layer.add_child(line)
	return false

func is_right_adjacent(pos: Vector2, other_pos: Vector2):
	const directions = [
		Vector2i(1, -1),  # Up-Right
		Vector2i(1, 0),   # Right
		Vector2i(1, 1),   # Down-Right
	]
	for dir in directions:
		dir = Vector2(dir)
		if other_pos.is_equal_approx(pos + dir * cell_size):
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
	if cond and show_lines: make_debug_line(pos, other_pos, Color.GREEN_YELLOW)
	return cond

func is_valid_jump_right(pos: Vector2, other_pos: Vector2) -> bool:
	var cond = pos.x < other_pos.x and other_pos.x <= pos.x + cell_size * (jump_distance + 2) and \
		   other_pos.y >= pos.y - (cell_size * jump_height) and \
		   get_cell_status(other_pos, true, true).x == -1 and \
			do_raycast(pos, other_pos) == Vector2.INF
	if cond and show_lines: make_debug_line(pos, other_pos, Color.MEDIUM_VIOLET_RED)
	return cond

func make_debug_line(pos: Vector2, other_pos: Vector2, color := Color.BLACK, width := 1.0):
	var line : Line2D = LINE_SCENE.instantiate()
	if color != Color.BLACK:
		line.default_color = color
	line.width = 1.0
	line.add_point(pos)
	line.add_point(other_pos)
	tile_map_layer.add_child(line)

func make_debug_dot(pos: Vector2, size_mult := 1.0):
	var dot : Sprite2D = INDICATOR_SCENE.instantiate()
	dot.scale *= size_mult
	dot.position = pos
	dot.z_index = 1
	tile_map_layer.add_child(dot)
