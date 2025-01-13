extends Node

## Contains utilities for generating paths between tile coordinates.
class_name TilePath


## Returns an array of tile coordinates between the start and end coordinates.
static func find_straight_path(start : Vector2i, end : Vector2i, convert_to_cell_coords := true) \
						-> Array[Vector2i]:
	if convert_to_cell_coords:
		start = local_to_map(start)
		end = local_to_map(end)
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

static func local_to_map(point : Vector2i = Vector2i.MAX, _point : Vector2 = Vector2.INF):
	if point != Vector2i.MAX:
		return point / 8
	elif _point != Vector2.INF:
		return Vector2i(_point) / 8

static func map_to_local(point):
	return Vector2(point) * 8 + Vector2(4, 4)

## Adds points to a path as necessary to fill gaps between any non-adjacent 
## points that are within the given radius of each other .
static func stitch_together_path(path : Array[Vector2i], radius : int):
	var i := -1
	while i < len(path) - 2:
		i += 1
		if not is_adjacent(path[i], path[i + 1]):
			if euclidean_dist(path[i], path[i + 1]) > radius:
				continue # TODO potentially remove 
			# Add straight line to path if each point doesn't already exist in the path
			var j := 0
			for point in find_straight_path(path[i], path[i + 1], false):
				if not path.has(point):
					path.insert(i + j, point)
					j += 1

#static func stitch_together_path(path: Array[Vector2i], radius: int):
	#var i := 0
	#while i < path.size() - 1:
		#if not is_adjacent(path[i], path[i + 1]):
			#if euclidean_dist(path[i], path[i + 1]) <= radius:
				## Insert points
				#var new_points := find_straight_path(path[i], path[i + 1], false)
				#for j in range(new_points.size()):
					#if not path.has(new_points[j]):
						#path.insert(i + 1 + j, new_points[j])
						## Reset index to recheck newly inserted points
						#i = max(0, i - 1)
		#i += 1

#static func stitch_together_path(path: Array[Vector2i], radius: int):
	## Spatial hash for efficient neighbor lookup
	#var bucket_size := radius
	#var buckets := {}
#
	## Helper to get a bucket key
	#var get_bucket_key = func(point: Vector2i) -> String:
		#return str(point.x / bucket_size) + "_" + str(point.y / bucket_size)
#
	## Populate buckets with points
	#for point in path:
		#var key = get_bucket_key.call(point)
		#if not buckets.has(key):
			#buckets[key] = []
		#buckets[key].append(point)
#
	## Helper to find neighbors
	#var  get_neighbors = func(point: Vector2i):
		#var neighbors := []
		#var bucket_key = get_bucket_key.call(point)
		#var nearby_keys := [
			#bucket_key,
			#str((point.x - bucket_size) / bucket_size) + "_" + str(point.y / bucket_size),
			#str((point.x + bucket_size) / bucket_size) + "_" + str(point.y / bucket_size),
			#str(point.x / bucket_size) + "_" + str((point.y - bucket_size) / bucket_size),
			#str(point.x / bucket_size) + "_" + str((point.y + bucket_size) / bucket_size)
		#]
		#for key in nearby_keys:
			#if buckets.has(key):
				#for other in buckets[key]:
					#if euclidean_dist(point, other) <= radius and point != other:
						#neighbors.append(other)
		#return neighbors
#
	## Stitch path using neighbors
	#var stitched_path := []
	#var visited := {}
	#var stack := [path[0]]  # Start from the first point
#
	#while stack.size() > 0:
		#var current = stack.pop_back()
		#if visited.has(current):
			#continue
		#visited[current] = true
		#stitched_path.append(current)
#
		## Add unvisited neighbors to the stack
		#for neighbor in get_neighbors.call(current):
			#if not visited.has(neighbor):
				#stack.append(neighbor)
#
	#return stitched_path



## Checks whether two coordinates are touching in any of 8 directions
static func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var x_diff = abs(a.x - b.x)
	var y_diff = abs(a.y - b.y)
	return x_diff + y_diff == 1 or x_diff == 1 and y_diff == 1 


## Adds given noise to a path, ensuring the start and end points remain the same.
static func add_noise_to_path(path : Array[Vector2i], \
							noise : FastNoiseLite, strength := 7, stitch_together := false, use_2d_noise := false, seed := randi()):
	noise.seed = seed
	var path_len = len(path)
	var progress = 0.0
	var path_slope = Vector2(path[-1] - path[0]).normalized().rotated(PI / 2)
	
	var i = 0
	for coord : Vector2i in path:
		progress = lerp(0.0, 1.0, float(i) / (path_len - 1)) if path_len != 1 else 0 
		# 0 to 1, multiplied onto the noise to ensure start and end are connected
		var noise_intensity = 2 * (-abs(progress - 0.5) + 0.5)
		noise_intensity = pow(noise_intensity, 0.3)
		var noise_sample : float
		if use_2d_noise:
			noise_sample = noise.get_noise_2d(coord.x, coord.y) * strength * noise_intensity
		else:
			noise_sample = noise.get_noise_1d(i) * strength * noise_intensity
		coord += Vector2i(noise_sample * path_slope)
		path[i] = coord
		i += 1
	
	if stitch_together:
		stitch_together_path(path, strength)
	
	return noise.seed


## Finds the top and bottom edge of a path by dragging a circle along it, where the edge of the
## circle defines the edge of the path and the inside of the circle deletes the edges, 
## creating a hollow shell around the path. 
## Returns both edges and the entire edge in an array of shape [top, bottom, inside]
static func find_edges_of_path(path : Array[Vector2i], radius_curve : Curve = null, base_radius := 5) -> Array:
	var angle = Vector2(path[-1] - path[0]).angle()
	# Tracks the final set of tiles defining the edge.
	var top_edge_set := {} 
	var bottom_edge_set := {} 
	# Tracks the tiles visited so far, so that visited tiles do not rejoin 
	# the edge but *can* be removed from the edge. 
	var visited := {} 
	var i := 0
	for path_coord : Vector2i in path: 
		# Calculate radius to carve path with
		var radius : int = base_radius
		if radius_curve:
			radius = radius_curve.sample_baked(i)
		# Calculate square area containing radius circle 
		var x_range = range(-radius - 1, radius + 2) # range is inclusive then exclusive
		var y_range = range(-radius - 1, radius + 2)
		for dx in x_range:
			for dy in y_range:
				# Look in a square around the point
				var coord_offset = Vector2i(dx, dy)
				var coord = path_coord + coord_offset
				var dist = euclidean_dist(path_coord, coord)
				#var dist = manhattan_dist(path_coord, coord)
				
				if dist <= radius: # Remove tiles on the inside of the circle
					top_edge_set.erase(coord)
					bottom_edge_set.erase(coord)
					visited[coord] = null # Add to visited
				elif dist == radius + 1:
					if visited.has(coord): 
						continue # Don't add as an edge tile if already visited
					# Calculate tangent to place tile into top or bottom edge
					if coord_offset.y < 0:
						top_edge_set[coord] = null # null is dummy value, just using key
					else: 
						bottom_edge_set[coord] = null 
					visited[coord] = null
		i += 1
	
	# Return the edges of the path
	var top_edge : Array[Vector2i] = []
	var bottom_edge : Array[Vector2i] = []
	top_edge.append_array(top_edge_set.keys())
	bottom_edge.append_array(bottom_edge_set.keys())
	bottom_edge.reverse()
	
	var path_edge : Array[Vector2i] = []
	path_edge.append_array(top_edge)
	path_edge.append_array(bottom_edge)
	
	var packed_arr : PackedVector2Array = PackedVector2Array(path_edge)
	var polygon : Polygon2D = Polygon2D.new()
	polygon.polygon = map_to_packed_vec2_arr(PackedVector2Array(reorder_points(path_edge)))
	polygon.z_index = -1
	return [top_edge, bottom_edge, path_edge, packed_arr, polygon]

static func map_to_packed_vec2_arr(tile_coords, convert_to_world_coords := true, convert_to_map_coords := false) -> PackedVector2Array:
	var arr = []
	for tile_coord in tile_coords:
		var new_coord := Vector2(tile_coord)
		if convert_to_world_coords:
			new_coord = map_to_local(new_coord)
		if convert_to_map_coords:
			new_coord = local_to_map(new_coord)
		arr.append(new_coord) 
	return PackedVector2Array(arr)

static func euclidean_dist(a : Vector2i, b : Vector2i):
	return int(sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)))

static func manhattan_dist(a : Vector2i, b : Vector2i):
	return abs(a.x - b.x) + abs(a.y - b.y)

#static func reorder_points(points: Array) -> Array:
	## Convert points to a set for fast lookup
	#var point_set = {}
	#for point in points:
		#point_set[point] = true
#
	## Find the starting point (lowest-leftmost point)
	#var start_point = points[0]
	#for point in points:
		#if point.y < start_point.y or (point.y == start_point.y and point.x < start_point.x):
			#start_point = point
#
	## Trace the edge with backtracking
	#var ordered_points = {}
	#var stack = [start_point]  # Stack to manage the traversal path
	#var visited = {}  # To track visited points
	#visited[start_point] = true
#
	#while stack.size() > 0:
		#var current = stack[stack.size() - 1]  # Peek at the top of the stack
		#ordered_points[current] = null
		##point_set.erase(current)  # Mark as visited by removing it from the set
#
		## Find unvisited neighbors
		#var neighbors = get_unvisited_neighbors(current, visited, point_set)
		#if neighbors.size() > 0:
			## Choose the first neighbor (clockwise priority)
			#var next_point = neighbors[0]
			#stack.append(next_point)  # Add to stack
			#visited[next_point] = true
		#else:
			## Dead end, backtrack
			#stack.pop_back()
#
		## If we complete the loop, stop
		#if stack.size() > 1 and stack[stack.size() - 1] == start_point:
			#print("POG!!!")
			#break
	#
	#var res = ordered_points.keys()
	#res.append(start_point)
	#return res

# Helper function to get neighbors in clockwise order
static func get_unvisited_neighbors(current, visited, point_set):
	var neighbors = []
		# Directions for neighbors in clockwise order
	var directions = [
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
		var neighbor = current + dir
		if point_set.has(neighbor) and not visited.has(neighbor):
			neighbors.append(neighbor)
	return neighbors

#region chatgpt
static func reorder_points(points: Array) -> Array:
	# Convert points to a set for fast lookup
	var point_set = {}
	for point in points:
		point_set[point] = true

	# Find the starting point (lowest-leftmost point)
	var start_point = points[0]
	for point in points:
		if point.y < start_point.y or (point.y == start_point.y and point.x < start_point.x):
			start_point = point

	# Trace the edge with backtracking
	var ordered_points = []
	var stack = [start_point]  # Stack to manage the traversal path
	var visited = {}  # To track visited points
	visited[start_point] = true

	while stack.size() > 0:
		#var current = stack[stack.size() - 1]  # Peek at the top of the stack
		var current = stack[stack.size() - 1]  # Peek at the top of the stack
		if not ordered_points.has(current):
			ordered_points.append(current)  # Add current to ordered points

		# Special case: Check if the start point can be revisited to complete the loop
		if len(ordered_points) > 2 and is_adjacent(current, start_point):
			ordered_points.append(start_point)
			break
		
		# Find unvisited neighbors
		var neighbors = get_unvisited_neighbors(current, visited, point_set)

		if neighbors.size() > 0:
			#for next_point in neighbors:
			# Choose the first neighbor (clockwise priority)
			var next_point = neighbors[0]
			stack.append(next_point)  # Add to stack
			visited[next_point] = true
		else:
			## Dead end, backtrack
			stack.pop_back()

	return ordered_points
#endregion chatgpt
