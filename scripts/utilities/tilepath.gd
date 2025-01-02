extends Node

## Contains utilities for generating paths between tile coordinates.
class_name TilePath

## Returns an array of tile coordinates between the start and end coordinates.
static func find_straight_path(map : TileMapLayer, start : Vector2i, \
						end : Vector2i) -> Array[Vector2i]:
	var path : Array[Vector2i] = []
	var diff = end - start
	
	if diff == Vector2i.ZERO:
		path.append(start)
		return path
	
	var num_steps = max(abs(diff.x), abs(diff.y))
	num_steps *= 1.1 # Fill in gaps by oversampling slightly
	var coords_set := {}
	
	for i in range(num_steps):
		var step = i + 1
		var progress = float(step) / num_steps
		var x = lerp(0, diff.x, progress)
		var y = lerp(0, diff.y, progress)
		var point = Vector2i(start.x + x, start.y + y)
		coords_set[point] = null # Dummy value, just storing key
	path.append_array(coords_set.keys())
	return path

## Adds given noise to a path, ensuring the start and end points remain the same.
static func add_noise_to_path(path : Array[Vector2i], \
							noise : FastNoiseLite):
	var i = 0
	for coord : Vector2i in path:
		var noise_sample = noise.get_noise_1d(i) * 7
		coord.y += noise_sample
		path[i] = coord
		i += 1
	return path

#region A-star pathfinding

# Finds the shortest path between start and goal tile coordinates
static func find_path(tilemap: TileMapLayer, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if start == goal:
		return [start]

	# Open list and closed list
	var open_list = []
	var closed_list = {}

	# G cost and F cost dictionaries
	var g_cost = {}
	var f_cost = {}

	# Parent dictionary for reconstructing the path
	var parent = {}

	# Add start node to the open list
	open_list.append(start)
	g_cost[start] = 0
	f_cost[start] = heuristic(start, goal)

	while open_list.size() > 0:
		# Find the node with the lowest F cost
		open_list.sort_custom(func(a, b): return f_cost[a] < f_cost[b])
		var current = open_list.pop_front()

		# Add to the closed list
		closed_list[current] = true

		# Goal reached
		if current == goal:
			return reconstruct_path(parent, current)

		# Check neighbors
		for neighbor in get_neighbors(tilemap, current):
			if neighbor in closed_list:
				continue

			var tentative_g_cost = g_cost[current] + 1

			if neighbor not in g_cost or tentative_g_cost < g_cost[neighbor]:
				parent[neighbor] = current
				g_cost[neighbor] = tentative_g_cost
				f_cost[neighbor] = g_cost[neighbor] + heuristic(neighbor, goal)

				if neighbor not in open_list:
					open_list.append(neighbor)

	# No path found
	return []

# Heuristic function (Manhattan distance)
static func heuristic(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

# Reconstructs the path from the parent dictionary
static func reconstruct_path(parent: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path : Array[Vector2i] = [current]
	while current in parent:
		current = parent[current]
		path.append(current)
	path.reverse()
	return path

# Returns the neighbors of a tile
static func get_neighbors(tilemap: TileMapLayer, tile: Vector2i) -> Array[Vector2i]:
	var neighbors : Array[Vector2i] = []
	var neighbor_directions = [
		TileSet.CellNeighbor.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CellNeighbor.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
		TileSet.CellNeighbor.CELL_NEIGHBOR_BOTTOM_SIDE,
		TileSet.CellNeighbor.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
		TileSet.CellNeighbor.CELL_NEIGHBOR_LEFT_SIDE,
		TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_LEFT_CORNER,
		TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_SIDE,
		TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	]

	for neighbor_dir in neighbor_directions:
		var neighbor = tilemap.get_neighbor_cell(tile, neighbor_dir)
		neighbors.append(neighbor)

	return neighbors

#endregion A-star pathfinding
