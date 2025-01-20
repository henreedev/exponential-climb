extends Sprite2D

@onready var camera_2d: Camera2D = $Camera2D

func _ready() -> void:
	print(camera_2d.get_screen_center_position())

func _process(delta: float) -> void:
	camera_2d.offset += Vector2.RIGHT
	print(camera_2d.get_target_position())
