@tool
extends TileMapLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	tile_set.tile_size = Chunk.TOTAL_CHUNK_SIZE_PX


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
