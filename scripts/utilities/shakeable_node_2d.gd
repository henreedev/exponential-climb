extends Node2D

class_name ShakeableNode2D

@export_range(0.1, 50.0, 0.01) var shake_strength := 5.0
@export_range(0.1, 50.0, 0.01) var shake_decay := 15.0
@export var shake_parent_instead := false

var curr_shake_strength := 0.0

# If shake_parent_instead is true, store the last offset, so as to reverse it before applying another 
var last_offset : Vector2
var offset : Vector2

@onready var parent = get_parent()

func shake(strength := shake_strength):
	curr_shake_strength = strength


func _physics_process(delta: float) -> void:
	if curr_shake_strength > 0:
		curr_shake_strength = maxf(curr_shake_strength - delta * shake_decay, 0.0)
		if shake_parent_instead:
			parent.position -= last_offset
			offset = Vector2(randf_range(-curr_shake_strength, curr_shake_strength), randf_range(-curr_shake_strength, curr_shake_strength))
			parent.position += offset
			last_offset = offset
		else:
			offset = Vector2(randf_range(-curr_shake_strength, curr_shake_strength), randf_range(-curr_shake_strength, curr_shake_strength))
			position = offset
