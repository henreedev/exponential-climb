extends Node2D

@onready var parent: Node2D = $"../.."

func _process(_delta: float) -> void:
	global_position = parent.global_position
