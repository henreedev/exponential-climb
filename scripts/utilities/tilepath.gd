extends Node

## Contains utilities for generating paths between tile coordinates.
class_name TilePath


## Returns an array of tile coordinates between the start and end coordinates.
static func find_straight_path(map : TileMapLayer, info : PathInfo):
	var start = info.start
	var end = info.end
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
							noise : FastNoiseLite, strength := 7):
	noise.seed += 1
	var path_len = len(path)
	var progress = 0.0
	var path_slope = Vector2(path[-1] - path[0]).normalized().rotated(PI / 2)
	
	var i = 0
	for coord : Vector2i in path:
		progress = lerp(0.0, 1.0, float(i) / (path_len - 1)) if path_len != 1 else 0 
		# 0 to 1, multiplied onto the noise to ensure start and end are connected
		var noise_intensity = 2 * (-abs(progress - 0.5) + 0.5)
		noise_intensity = pow(noise_intensity, 0.3)
		
		var noise_sample = noise.get_noise_1d(i) * strength * noise_intensity
		coord += Vector2i(noise_sample * path_slope)
		path[i] = coord
		i += 1
	return path


## Finds the top and bottom edge of a path by dragging a circle along it, where the edge of the
## circle defines the edge of the path and the inside of the circle deletes the edges, 
## creating a hollow shell around the path. 
## Returns both edges and the tiles inside in an array of shape [top, bottom, inside]
static func find_edges_of_path(path : Array[Vector2i], radius_curve : Curve = null, base_radius := 5) -> Array:
	# Tracks the final set of tiles defining the edge.
	var edge_coord_set := {} 
	# Tracks the final set of tiles defining the center (everything inside the edge).
	var inside_coord_set := {} 
	# Tracks the tiles visited so far, so that visited tiles do not rejoin 
	# the edge but *can* be removed from the edge. 
	var visited := {} 
	var i := 0 # Used for sampling base_radius curve at each tile
	for path_coord : Vector2i in path: 
		var radius : int = base_radius
		if radius_curve:
			radius = radius_curve.sample_baked(i) # NOTE maybe should use `sample_baked()`
		var x_range = range(-radius - 1, radius + 2) # range is inclusive then exclusive
		var y_range = range(-radius - 1, radius + 2)
		for x_offset in x_range:
			for y_offset in y_range:
				# Look in a square around the point
				var coord_offset = Vector2i(x_offset, y_offset)
				var coord = path_coord + coord_offset
				var mh_dist = euclidean_dist(path_coord, coord)         
				
				if mh_dist <= radius:
					edge_coord_set.erase(coord) # Can remove visited tiles 
					inside_coord_set[coord] = null 
					visited[coord] = null # Add to visited
				if mh_dist == radius + 1:
					if visited.has(coord): 
						continue # Don't add as an edge tile if already visited
					inside_coord_set.erase(coord)
					edge_coord_set[coord] = null # null is dummy value, just using key
					visited[coord] = null
		i += 1
	# Create the overall circular edge of the path
	var path_edge : Array[Vector2i] = []
	path_edge.append_array(edge_coord_set.keys())
	# Use visited to only add non-visited tiles to top and bottom edges
	visited.clear()
	# Generate the top and bottom of the path by looking at each point and finding a point below it;
	# if that point exists, mark them as top and bottom points. 
	var top_edge : Array[Vector2i] = []
	var bottom_edge : Array[Vector2i] = []
	for path_edge_coord_top in path_edge:
		if visited.has(path_edge_coord_top): continue
		# Find a coord below. If exists, this is top, else this is bot edge.
		for path_edge_coord_bot in path_edge:
			if visited.has(path_edge_coord_top): continue
			if path_edge_coord_top.x == path_edge_coord_bot.x and \
					path_edge_coord_top.y < path_edge_coord_bot.y:
				top_edge.append(path_edge_coord_top)
				bottom_edge.append(path_edge_coord_bot)
				visited[path_edge_coord_top] = null
				visited[path_edge_coord_bot] = null
				break
		# Add to bottom edge if no vertical match below was found
		if not visited.has(path_edge_coord_top):
			bottom_edge.append(path_edge_coord_top)
			visited[path_edge_coord_top] = null
	
	# Also return the inside of the edges, to be filled with background tiles
	var inside : Array[Vector2i] = []
	inside.append_array(inside_coord_set.keys())
	
	return [top_edge, bottom_edge, inside]


static func euclidean_dist(a : Vector2i, b : Vector2i):
	#return abs(a.x - b.x) + abs(a.y - b.y) # Uncomment for manhattan distance formula
	return int(sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)))
	
