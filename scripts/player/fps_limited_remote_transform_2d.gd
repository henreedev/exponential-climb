extends Node2D

class_name FpsLimitedRemoteTransform2D

@export var remote_path: NodePath
@export_range(1, 120) var FPS := 12 
@export var update_position := true
@export var update_rotation := true
@export var update_scale := true

var _frame_timer := 0.0
@onready var _frame_interval := 1.0 / float(FPS)
@onready var node: Node2D = get_node(remote_path) 
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if _frame_timer <= 0.0:
		_frame_timer = _frame_interval
		if update_position:
			node.global_position = global_position
		if update_rotation:
			node.global_rotation = global_rotation
		if update_scale:
			node.global_scale = global_scale
	_frame_timer -= delta
