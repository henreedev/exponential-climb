@tool
extends Node2D
class_name ChunkOutlineSquare

var size := Chunk.TOTAL_CHUNK_SIZE_PX:
	set(value):
		size = value
		queue_redraw()

@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()

@export var thickness := 1.0:
	set(value):
		thickness = value
		queue_redraw()

func _ready():
	# This runs in the editor because of @tool
	size = Chunk.TOTAL_CHUNK_SIZE_PX
	queue_redraw()

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()

func _draw():
	draw_rect(
		Rect2(Vector2.ZERO, size),
		color,
		false,
		thickness
	)
