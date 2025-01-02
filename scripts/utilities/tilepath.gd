extends Node

## Contains utilities for generating paths between tile coordinates.
class_name TilePath

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
		TileSet.CellNeighbor.CELL_NEIGHBOR_TOP_RIGHT_CORNER
	]

	for neighbor_dir in neighbor_directions:
		var neighbor = tilemap.get_neighbor_cell(tile, neighbor_dir)
		neighbors.append(neighbor)

	return neighbors
