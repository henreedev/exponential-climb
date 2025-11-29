extends Node2D

class_name PlayerSkeleton

enum BodyPart {
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG,
}

#region Targets
@onready var larm_look_at_target: Marker2D = %LarmLookAtTarget
@onready var rarm_look_at_target: Marker2D = %RarmLookAtTarget
@onready var rleg_ik_target: Marker2D = %RlegIKTarget
@onready var lleg_ik_target: Marker2D = %LlegIKTarget
@onready var head_look_at_target: Marker2D = %HeadLookAtTarget
@onready var targets: Dictionary[BodyPart, Marker2D] = {
	BodyPart.LEFT_ARM : larm_look_at_target,
	BodyPart.RIGHT_ARM : rarm_look_at_target,
	BodyPart.LEFT_LEG : rleg_ik_target,
	BodyPart.RIGHT_LEG : lleg_ik_target,
}
#endregion Targets
#region Target base positions
@onready var larm_look_at_target_base: Marker2D = %LarmLookAtTargetBase
@onready var rarm_look_at_target_base: Marker2D = %RarmLookAtTargetBase
@onready var rleg_ik_target_base: Marker2D = %RlegIKTargetBase
@onready var lleg_ik_target_base: Marker2D = %LlegIKTargetBase
@onready var bases: Dictionary[BodyPart, Marker2D] = {
	BodyPart.LEFT_ARM : larm_look_at_target_base,
	BodyPart.RIGHT_ARM : rarm_look_at_target_base,
	BodyPart.LEFT_LEG : rleg_ik_target_base,
	BodyPart.RIGHT_LEG : lleg_ik_target_base,
}
#endregion Target base positions

#region Specific spots on skeleton
@onready var rhand_marker: Marker2D = %RhandMarker

#endregion Specific spots on skeleton

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
	_update_platforming_target_positions() # TODO replace with walking tween 
	_update_target_positions()
#endregion Built-ins

func _manual_update_head_target():
	if player.animating:
		return
	head_look_at_target.global_position = get_global_mouse_position()

func _init_dicts():
	for value in BodyPart.values():
		target_override_positions[value] = Vector2.ZERO
		physics_target_positions[value] = Vector2.ZERO
		platforming_target_positions[value] = Vector2.ZERO

func set_target_override_position(part: BodyPart, override_pos: Vector2):
	target_override_positions[part] = override_pos

func clear_target_override_position(part: BodyPart):
	target_override_positions[part] = Vector2.ZERO

func _update_physics_target_positions():
	const DRAG_FACTOR := 0.1
	for part: BodyPart in BodyPart.values():
		set_physics_global_position(part, \
			get_base_global_position(part) - player.velocity * DRAG_FACTOR
		)

func _update_platforming_target_positions():
	for part: BodyPart in BodyPart.values():
		set_platforming_global_position(part, \
			get_base_global_position(part)
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
func set_platforming_global_position(part: BodyPart, pos: Vector2):
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
