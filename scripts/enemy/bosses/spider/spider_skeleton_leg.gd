extends Node2D

class_name SpiderSkeletonLeg
@onready var foot_target: Marker2D = $Node/FootTarget
@onready var legs: Sprite2D = $".."


## Legs automatically choose nearby positions when enabled. 
var automatically_walk := false

## True when leg target is moving.
var moving_leg := false

## True when the foot target was found based on a successful tilemap raycast.
var is_on_ground := false

var leg_tween: Tween

const LEG_TOTAL_LENGTH := 102.0

func set_foot_target_pos(pos: Vector2):
	foot_target.global_position = pos

func get_foot_target_pos() -> Vector2:
	return foot_target.global_position


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	legs.show()
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	var curr_target_pos := foot_target.global_position
	var curr_dist := global_position.distance_to(curr_target_pos)
	
	if curr_dist > LEG_TOTAL_LENGTH or not is_on_ground:
		# Find a new position
		_find_nearby_leg_position_or_air() 


func _find_nearby_leg_position_or_air():
	if not automatically_walk or moving_leg:
		return
	
	var found_foot_location := false
	var foot_location: Vector2
	
	is_on_ground = true
	
	# Raycast in a circle starting from leg rotation, shifted in movement direction
	# Circle direction is also random
	
	#var movement_dir_rotation = # TODO use spider rigidbody linvel, add to start rotation
	var start_rotation := rotation
	var rotate_left_or_right_multiplier := 1 if randf() > 0.5 else -1
	var raycast_unrotated_vec := Vector2(LEG_TOTAL_LENGTH, 0).rotated(PI / 2)
	
	const TOTAL_RAYCASTS := 5
	var rotation_increment := TAU / TOTAL_RAYCASTS * rotate_left_or_right_multiplier
	
	for i in range(TOTAL_RAYCASTS):
		var raycast_rot = start_rotation + rotation_increment * i
		var rotation_diff := angle_difference(start_rotation, raycast_rot)
		var length_decrease_ratio = 1.0 - abs(rotation_diff) / PI * 0.5
		var raycast_vec = raycast_unrotated_vec.rotated(raycast_rot) * length_decrease_ratio
		var hit_pos := Pathfinding.do_raycast(global_position, global_position + raycast_vec)
		if hit_pos != Vector2.INF: 
			found_foot_location = true
			foot_location = hit_pos
			break
	
	if not found_foot_location:
		is_on_ground = false
		# Pull the target towards the body, curling up the leg
		foot_location = lerp(foot_target.global_position, self.global_position, 0.5) 
	
	leg_tween = create_tween()
	moving_leg = true
	leg_tween.tween_property(foot_target, "global_position", foot_location, 0.5).set_trans(Tween.TRANS_CUBIC)
	leg_tween.tween_property(self, "moving_leg", false, 0.0)
	
