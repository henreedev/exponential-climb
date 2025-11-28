@tool
extends Node2D
class_name FpsLimitedRemoteTransform2D

@export var remote_path: NodePath:
	set(value):
		remote_path = value
		_update_node()

@export_range(1, 120) var FPS := 12 
@export var update_position := true
@export var update_rotation := true
@export var update_scale := false

var node: Node2D
var _frame_timer := 0.0
var _frame_interval := 1.0

func _ready():
	_frame_interval = 1.0 / float(FPS)
	_update_node()

func _process(delta):
	if not node:
		return

	_frame_timer -= delta
	if _frame_timer <= 0.0:
		_frame_timer = _frame_interval
		_update_transform()

func _update_node():
	if has_node(remote_path):
		node = get_node(remote_path)

func _update_transform():
	if update_position and node:
		node.global_position = global_position
	if update_rotation:
		node.global_rotation = global_rotation
	if update_scale:
		node.global_scale = global_scale
