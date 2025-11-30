extends Node2D

class_name PlayerSkeleton

enum BodyPart {
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG,
	TORSO,
	TORSO_ANGLE,
}

#region Targets
@onready var larm_look_at_target: Marker2D = %LarmLookAtTarget
@onready var rarm_look_at_target: Marker2D = %RarmLookAtTarget
@onready var rleg_ik_target: Marker2D = %RlegIKTarget
@onready var lleg_ik_target: Marker2D = %LlegIKTarget
@onready var head_look_at_target: Marker2D = %HeadLookAtTarget
@onready var torso_stay_at_target: Marker2D = %TorsoStayAtTarget
@onready var torso_look_at_target: Marker2D = %TorsoLookAtTarget

@onready var targets: Dictionary[BodyPart, Marker2D] = {
	BodyPart.LEFT_ARM : larm_look_at_target,
	BodyPart.RIGHT_ARM : rarm_look_at_target,
	BodyPart.LEFT_LEG : rleg_ik_target,
	BodyPart.RIGHT_LEG : lleg_ik_target,
	BodyPart.TORSO : torso_stay_at_target,
	BodyPart.TORSO_ANGLE : torso_look_at_target,
}
#endregion Targets
#region Target base positions
@onready var larm_look_at_target_base: Marker2D = %LarmLookAtTargetBase
@onready var rarm_look_at_target_base: Marker2D = %RarmLookAtTargetBase
@onready var rleg_ik_target_base: Marker2D = %RlegIKTargetBase
@onready var lleg_ik_target_base: Marker2D = %LlegIKTargetBase
@onready var torso_stay_at_target_base: Marker2D = %TorsoStayAtTargetBase
@onready var torso_look_at_target_base: Marker2D = %TorsoLookAtTargetBase

@onready var bases: Dictionary[BodyPart, Marker2D] = {
	BodyPart.LEFT_ARM : larm_look_at_target_base,
	BodyPart.RIGHT_ARM : rarm_look_at_target_base,
	BodyPart.LEFT_LEG : rleg_ik_target_base,
	BodyPart.RIGHT_LEG : lleg_ik_target_base,
	BodyPart.TORSO : torso_stay_at_target_base,
	BodyPart.TORSO_ANGLE : torso_look_at_target_base,
}
#endregion Target base positions

#region Specific spots on skeleton
@onready var rhand_marker: Marker2D = %RhandMarker

#endregion Specific spots on skeleton

#region Remote Transforms
@onready var remote_transforms: Array[FpsLimitedRemoteTransform2D] = _find_fps_remote_transforms(self)
#endregion
## Stores world-position overrides of body part targets, or Vector2.ZERO if no override.
var target_override_positions: Dictionary[BodyPart, Vector2]

## Stores world-position target positions for platforming.
var platforming_target_positions: Dictionary[BodyPart, Vector2]

## Stores world-position target positions for physics.
var physics_target_positions: Dictionary[BodyPart, Vector2]

@onready var player: Player = get_parent() if Global.player == null else Global.player

#region Built-ins
func _ready() -> void:
	_init_dicts()

func _process(_delta: float) -> void:
	_manual_update_head_target()

func _physics_process(delta: float) -> void:
	_update_physics_target_positions()
	_update_platforming_target_positions() 
	_update_target_positions()
#endregion Built-ins
#region Public methods
func turn_towards(right: bool):
	var new_scale_x = 1 if right else -1
	if scale.x == new_scale_x: return
	# Turn overall character
	scale.x = new_scale_x
	# Turn foot aim locations to be forwards
	lleg_ik_target.scale.x = new_scale_x
	rleg_ik_target.scale.x = new_scale_x
	# Take a new step immediately
	if left_leg_tween and left_leg_tween.is_valid():
		left_leg_tween.kill()
	#if right_leg_tween and right_leg_tween.is_valid():
		#right_leg_tween.kill()
	# Reduce the jitter on turn by processing some of it
	_process(0.1)
	_physics_process(0.1)
	_process(0.1)
	_physics_process(0.1)
	_process(0.1)
	_physics_process(0.1)
	for rt: FpsLimitedRemoteTransform2D in remote_transforms:
		rt.update_immediately()
		print("UPDATED")


#endregion Public methods

func _manual_update_head_target():
	if player.animating:
		return
	head_look_at_target.global_position = get_global_mouse_position()

func _init_dicts():
	for value in BodyPart.values():
		target_override_positions[value] = Vector2.ZERO
		physics_target_positions[value] = Vector2.ZERO
		platforming_target_positions[value] = Vector2.ZERO

func _find_fps_remote_transforms(node: Node) -> Array[FpsLimitedRemoteTransform2D]:
	var out: Array[FpsLimitedRemoteTransform2D] = []
	for c in node.get_children():
		if c is FpsLimitedRemoteTransform2D:
			out.append(c)
		out += _find_fps_remote_transforms(c)
	return out



func set_target_override_position(part: BodyPart, override_pos: Vector2):
	target_override_positions[part] = override_pos

func clear_target_override_position(part: BodyPart):
	target_override_positions[part] = Vector2.ZERO

func _update_physics_target_positions():
	const DRAG_FACTOR := 0.1
	for part: BodyPart in BodyPart.values():
		if is_leg(part) and player.is_on_floor():
			set_physics_global_position(part, \
				get_base_global_position(part) + player.velocity * DRAG_FACTOR
			)
		elif part == BodyPart.TORSO and player.is_on_floor():
			set_physics_global_position(part, \
				get_base_global_position(part) + Vector2.DOWN * 5
			)
		else: 
			set_physics_global_position(part, \
				get_base_global_position(part) - player.velocity * DRAG_FACTOR
			)
var next_leg_can_step_dur := 0.0
func _update_platforming_target_positions():
	# Walk with left leg, or right leg if left leg is halfway done.
	if left_leg_tween and left_leg_tween.is_valid():
		if left_leg_tween.get_total_elapsed_time() > next_leg_can_step_dur:
			do_walking_leg_motion(BodyPart.RIGHT_LEG)
	elif right_leg_tween and right_leg_tween.is_valid():
		if right_leg_tween.get_total_elapsed_time() > next_leg_can_step_dur:
			do_walking_leg_motion(BodyPart.LEFT_LEG)
	else:
		do_walking_leg_motion(BodyPart.LEFT_LEG)
	
	# Keep torso rotation vertical.
	set_platforming_global_position(
		get_base_global_position(BodyPart.TORSO_ANGLE), BodyPart.TORSO_ANGLE
	)


## Calculates where each target should go based on:
##  1. Overrides
##  2. Otherwise, a blend between physics and platforming using the player's ratio
func _update_target_positions() -> void:
	for part in BodyPart.values():
		if has_override(part):
			set_target_global_position(part, target_override_positions[part])
		elif not player.animating:
			var physics_ratio: float = player.physics_ratio
			var platforming_ratio = 1 - physics_ratio
			var combined_pos = physics_ratio * physics_target_positions[part] + \
							platforming_ratio * platforming_target_positions[part]
			set_target_global_position(part, combined_pos)

#region Setters
## Args swapped for compability with bind() calls in walking method
func set_platforming_global_position(pos: Vector2, part: BodyPart):
	platforming_target_positions[part] = pos

func set_physics_global_position(part: BodyPart, pos: Vector2):
	physics_target_positions[part] = pos

func set_target_global_position(part: BodyPart, pos: Vector2):
	targets[part].global_position = pos
#endregion Setters

func get_base_global_position(part: BodyPart) -> Vector2:
	return bases[part].global_position

func has_override(part: BodyPart) -> bool:
	return target_override_positions[part] != Vector2.ZERO

func is_leg(part: BodyPart) -> bool:
	return part == BodyPart.LEFT_LEG or \
		part == BodyPart.RIGHT_LEG

#region Platforming walking animations
var left_leg_tween: Tween
var right_leg_tween: Tween
func do_walking_leg_motion(leg: BodyPart):
	var tween := left_leg_tween if leg == BodyPart.LEFT_LEG else right_leg_tween
	if tween and tween.is_valid():# or player.velocity.length() < 10:
		return # Don't interrupt a leg motion in progress
	if leg == BodyPart.LEFT_LEG:
		left_leg_tween = create_tween()
		tween = left_leg_tween
	else:
		right_leg_tween = create_tween()
		tween = right_leg_tween
	
	# Goal: place leg IK target above final foot pos, then lower it down.  
	
	# Find final pos
	var final_foot_pos := _calculate_final_foot_pos(leg)
	var set_pos_callable := set_platforming_global_position.bind(leg)
	
	# Determine step durations
	var step_duration := 0.5 # TODO scale with speed?
	next_leg_can_step_dur = step_duration / 2.0
	const RAISE_LEG_RATIO := 0.5
	var raise_leg_dur := step_duration * RAISE_LEG_RATIO
	var lower_leg_dur := step_duration * (1.0 - RAISE_LEG_RATIO) 
	
	# Raise leg up by more for larger steps
	var speed := player.velocity.length()
	var speed_ratio := speed / Player.DEFAULT_MOVEMENT_SPEED
	var on_floor_float := 1.0 if player.is_on_floor() else 0.0
	const BASE_RAISE_PX := 6.0
	var raise_vec := Vector2.UP * BASE_RAISE_PX * speed_ratio
	var start_pos := platforming_target_positions[leg]
	var raise_pos := final_foot_pos + raise_vec
	
	# Get torso movement positions and timings
	const TORSO_BOB_PX := 2
	var torso_bob_vec := Vector2.UP * TORSO_BOB_PX * speed_ratio * on_floor_float
	var torso_bob_half_dur := step_duration / 4.0
	
	# Get arm movement positions and timings
	const ARM_SWING_PX := 5
	var forward_arm: BodyPart = BodyPart.RIGHT_ARM if leg == BodyPart.LEFT_LEG else BodyPart.LEFT_ARM
	var backward_arm: BodyPart = BodyPart.LEFT_ARM if leg == BodyPart.LEFT_LEG else BodyPart.RIGHT_ARM
	var is_right_arm_forward := forward_arm == BodyPart.RIGHT_ARM
	var forward_arm_callable := set_right_arm_platforming_offset_vec if is_right_arm_forward else set_left_arm_platforming_offset_vec
	var backward_arm_callable := set_left_arm_platforming_offset_vec if is_right_arm_forward else set_right_arm_platforming_offset_vec
	# Find unit direction to swing forward arm in
	var arm_swing_dir := ((get_base_global_position(BodyPart.RIGHT_ARM) - global_position) * Vector2(1,0)).normalized()
	# Reset arms to rest pose if not moving horizontally
	if abs(player.velocity.x) < 10.0: arm_swing_dir = Vector2.ZERO
	var forward_arm_offset_vec := arm_swing_dir * ARM_SWING_PX * on_floor_float
	var backward_arm_offset_vec := -forward_arm_offset_vec
	var arm_swing_dur := step_duration / 2.0
	if is_right_arm_forward:
		print("RIGHT ARM SWING")
	else:
		print("LEFT ARM SWING")
	# Do the movements
	tween.tween_method(set_pos_callable, start_pos, raise_pos, raise_leg_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(set_torso_platforming_offset_vec, -torso_bob_vec, torso_bob_vec, torso_bob_half_dur)
	tween.parallel().tween_method(set_torso_platforming_offset_vec, torso_bob_vec, -torso_bob_vec, torso_bob_half_dur).set_delay(torso_bob_half_dur)
	tween.parallel().tween_method(forward_arm_callable, platforming_target_positions[forward_arm] - get_base_global_position(forward_arm), forward_arm_offset_vec, arm_swing_dur)
	tween.parallel().tween_method(backward_arm_callable, platforming_target_positions[backward_arm] - get_base_global_position(backward_arm), backward_arm_offset_vec, arm_swing_dur)
	tween.tween_method(set_pos_callable, raise_pos, final_foot_pos, lower_leg_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func set_left_arm_platforming_offset_vec(offset: Vector2) -> void:
	var base := get_base_global_position(BodyPart.LEFT_ARM)
	set_platforming_global_position(base + offset, BodyPart.LEFT_ARM)
	
func set_right_arm_platforming_offset_vec(offset: Vector2) -> void:
	var base := get_base_global_position(BodyPart.RIGHT_ARM)
	set_platforming_global_position(base + offset, BodyPart.RIGHT_ARM)

func set_torso_platforming_offset_vec(offset: Vector2) -> void:
	var base := get_base_global_position(BodyPart.TORSO)
	set_platforming_global_position(base + offset, BodyPart.TORSO)

func _calculate_final_foot_pos(leg: BodyPart) -> Vector2:
	# Get player's velocity and find a point to step onto in that direction using raycasts.
	var player_vel := player.velocity
	const VEL_SCALE = 0.33
	var raycast_diff_vec := player_vel * VEL_SCALE
	# Raycast from skeleton center in velocity direction
	var start_pos := global_position
	var end_pos := global_position + raycast_diff_vec
	var forward_hit_pos := Pathfinding.do_raycast(start_pos, end_pos)
	
	# If we hit something, move back a couple px so downward raycast doesn't collide in-place
	const BACK_UP_PX := 2
	var raycast_down_start_pos = end_pos if forward_hit_pos == Vector2.INF else forward_hit_pos
	raycast_down_start_pos -= (end_pos - start_pos).normalized() * BACK_UP_PX
	
	# Raycast down to get the final position for the IK target. 
	# The place we are stepping onto.
	const DOWN_DIST := 500
	var raycast_down_end_pos = raycast_down_start_pos + Vector2.DOWN * DOWN_DIST
	var raycast_down_hit_pos = Pathfinding.do_raycast(raycast_down_start_pos, raycast_down_end_pos)
	
	var final_foot_pos = raycast_down_end_pos if raycast_down_hit_pos == Vector2.INF else raycast_down_hit_pos
	
	# Apply an offset based on left or right foot
	var foot_base_x = bases[leg].global_position.x - global_position.x
	return final_foot_pos + Vector2.RIGHT * foot_base_x

#endregion Platforming walking animations
