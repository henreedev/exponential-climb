@tool
extends Node2D
class_name ChunkConnectionSprites

@export var connection_sprite_texture: Texture2D
@export var sprite_scale := Vector2.ONE

@onready var chunk: Chunk = get_parent() as Chunk

func _ready() -> void:
	if not chunk:
		push_error("ChunkConnectionSprites must be a child of a Chunk node.")
		return
	regenerate()


func regenerate() -> void:
	if not chunk:
		return

	# Clear existing sprites
	for c in get_children():
		c.queue_free()

	var chunk_size_px := Chunk.TOTAL_CHUNK_SIZE_PX
	var center := Vector2(chunk_size_px / 2)

	for dir in chunk.poi_connection_dirs:
		var dir_vec := Vector2(chunk.convert_connection_dir_to_vector2i(dir))
		var sprite := Sprite2D.new()
		sprite.texture = connection_sprite_texture
		sprite.scale = sprite_scale
		sprite.offset = Vector2.RIGHT * 16

		# Position sprite centered on chunk border in that direction
		sprite.position = center + Vector2(dir_vec.x * center.x, dir_vec.y * center.y)

		# Rotate sprite to point away from chunk center
		sprite.rotation = dir_vec.angle()

		add_child(sprite)
		sprite.owner = get_tree().edited_scene_root
