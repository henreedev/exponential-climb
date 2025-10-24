extends Node


## NoiseVisualizer

const CAN_VISUALIZE_NOISE := true

enum NoiseType {
	TERRAIN,
	TUNNEL,
	RARITY,
	QUANTITY,
}

var terrain_viz_on := false
var tunnel_viz_on := false
var rarity_viz_on := false
var quantity_viz_on := false

var rects: Array[ColorRect]

const NOISE_TYPE_TO_COLOR: Dictionary[NoiseType, Color] = {
	NoiseType.TERRAIN : Color.WHITE,
	NoiseType.TUNNEL : Color.BLUE,
	NoiseType.RARITY : Color.GREEN_YELLOW,
	NoiseType.QUANTITY : Color.AQUAMARINE,
}
const NOISE_TYPE_TO_BOTTOM_COLOR: Dictionary[NoiseType, Color] = {
	NoiseType.TERRAIN : Color.BLACK,
	NoiseType.TUNNEL : Color.BLACK,
	NoiseType.RARITY : Color.DARK_RED,
	NoiseType.QUANTITY : Color.BLACK,
}

var _room: Room

func _input(event: InputEvent) -> void:
	if CAN_VISUALIZE_NOISE:
		if event.is_action_pressed("generate_noise_visualization_rects"):
			regenerate_rects_for_room(Global.current_floor.current_room)
		if event.is_action_pressed("clear_noise_visualization_rects"):
			clear_rects()
		if event.is_action_pressed("toggle_terrain_noise_visualization"):
			toggle_type(NoiseType.TERRAIN)
		if event.is_action_pressed("toggle_tunnel_noise_visualization"):
			toggle_type(NoiseType.TUNNEL)
		if event.is_action_pressed("toggle_rarity_noise_visualization"):
			toggle_type(NoiseType.RARITY)
		if event.is_action_pressed("toggle_quantity_noise_visualization"):
			toggle_type(NoiseType.QUANTITY)

func clear_rects():
	print("Freeing ", rects.size(), " rects...")
	for rect: ColorRect in rects:
		if rect:
			rect.free.call_deferred()
		#print("freed")
	print("Done freeing rects")
	rects.clear()
	print("Done clearing rects")

func regenerate_rects_for_room(room: Room):
	if not Global.current_floor.new_room_generated.is_connected(clear_rects):
		Global.current_floor.new_room_generated.connect(clear_rects)
	print("REGENERATE CALLED FOR NOISE VISUALIZATION")
	_room = room
	terrain_viz_on = false
	tunnel_viz_on = false
	rarity_viz_on = false
	quantity_viz_on = false
	clear_rects()
	for x in range(room._x_bounds.x, room._x_bounds.y + 1, TILE_SCALE):
		for y in range(room._y_bounds.x, room._y_bounds.y + 1, TILE_SCALE):
			rects.append(create_rect(Vector2i(x,y)))
	print("Done regenerating")
	
const TILE_SCALE = 4
const TILE_SIZE = Vector2(8,8) * TILE_SCALE
func create_rect(tile_pos: Vector2i):
	var world_pos = _room.wall_layer.map_to_local(tile_pos) - TILE_SIZE / 2
	var rect: ColorRect = ColorRect.new()
	rect.position = world_pos
	rect.size = TILE_SIZE
	rect.color = Color.TRANSPARENT
	Global.current_floor.add_child(rect)
	return rect

func toggle_type(type: NoiseType):
	if not rects: return
	print("TOGGLING NOISE VISUALIZATION FOR NOISE TYPE ", NoiseType.find_key(type))
	#var group_name = str(NoiseType.find_key(type), GROUP_SUFFIX)
	var target_alpha: float
	match type:
		NoiseType.TERRAIN:
			target_alpha = 0.0 if terrain_viz_on else 0.5
			terrain_viz_on = not terrain_viz_on
			tunnel_viz_on = false
			rarity_viz_on = false
			quantity_viz_on = false
		NoiseType.TUNNEL:
			target_alpha = 0.0 if tunnel_viz_on else 0.5
			tunnel_viz_on = not tunnel_viz_on
			terrain_viz_on = false
			rarity_viz_on = false
			quantity_viz_on = false
		NoiseType.RARITY:
			target_alpha = 0.0 if rarity_viz_on else 0.5
			rarity_viz_on = not rarity_viz_on
			terrain_viz_on = false
			tunnel_viz_on = false
			quantity_viz_on = false
		NoiseType.QUANTITY:
			target_alpha = 0.0 if quantity_viz_on else 0.5
			quantity_viz_on = not quantity_viz_on
			terrain_viz_on = false
			tunnel_viz_on = false
			rarity_viz_on = false
	var tween = create_tween().set_parallel()
	for rect in rects:
		var noise_val: float
		var tile_pos: Vector2i = _room.wall_layer.local_to_map(rect.position)
		match type:
			NoiseType.TERRAIN:
				noise_val = inverse_lerp(-1, 1, _room.sample_terrain_noise(tile_pos.x, tile_pos.y))
			NoiseType.TUNNEL:
				noise_val = inverse_lerp(-1, 1, _room.sample_tunnel_noise(tile_pos.x, tile_pos.y))
			NoiseType.RARITY:
				noise_val = _room.sample_rarity_noise(tile_pos.x, tile_pos.y)
			NoiseType.QUANTITY:
				noise_val = _room.sample_quantity_noise(tile_pos.x, tile_pos.y)
			
		var target_color: Color = lerp(NOISE_TYPE_TO_BOTTOM_COLOR[type],
		 NOISE_TYPE_TO_COLOR[type], noise_val)
		target_color.a = target_alpha
		tween.tween_property(rect, "color", target_color, 0.4).set_trans(Tween.TRANS_CUBIC)
