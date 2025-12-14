extends Node2D

class_name SpiderSkeleton
@onready var head_look_at_target: Marker2D = %HeadLookAtTarget

@onready var spider_skeleton_leg: SpiderSkeletonLeg = %SpiderSkeletonLeg
@onready var spider_skeleton_leg_2: SpiderSkeletonLeg = %SpiderSkeletonLeg2
@onready var spider_skeleton_leg_3: SpiderSkeletonLeg = %SpiderSkeletonLeg3
@onready var spider_skeleton_leg_4: SpiderSkeletonLeg = %SpiderSkeletonLeg4
@onready var spider_skeleton_leg_5: SpiderSkeletonLeg = %SpiderSkeletonLeg5
@onready var spider_skeleton_leg_6: SpiderSkeletonLeg = %SpiderSkeletonLeg6
@onready var spider_skeleton_leg_7: SpiderSkeletonLeg = %SpiderSkeletonLeg7
@onready var spider_skeleton_leg_8: SpiderSkeletonLeg = %SpiderSkeletonLeg8

@onready var right_mandible_angle_target: Marker2D = %RightMandibleAngleTarget
@onready var left_mandible_angle_target: Marker2D = %LeftMandibleAngleTarget

@onready var right_fang: Sprite2D = %RightFang
@onready var left_fang: Sprite2D = %LeftFang
@onready var fangs: Array[Sprite2D] = [
	right_fang,
	left_fang
]

@onready var legs: Array[SpiderSkeletonLeg] = [
	spider_skeleton_leg,
	spider_skeleton_leg_2,
	spider_skeleton_leg_3,
	spider_skeleton_leg_4,
	spider_skeleton_leg_5,
	spider_skeleton_leg_6,
	spider_skeleton_leg_7,
	spider_skeleton_leg_8,
]

## When true, hit/hurt boxes are disabled. Visual animation only.
var animating := true

## Animation for coming out of the door: 
## 1. (Skeleton) Reset all legs to global pos
## 2. (Skeleton) Set rightmost leg to global pos + far to the right
## 3. Start moving to the right
## 4. (Skeleton) Leg touches the ground, other legs poke out
## 5. Reach final position after duration, end
func start_animation(total_dur: float):
	animating = true
	
	var chosen_leg_index := 7 # Could randomize this
	
	var tween := create_tween()
	## 1. 
	_reset_legs_to_local_pos(position - Vector2(1000, BossPlatform.BOSS_SPAWN_OFFSET.y))
	
	## 2. 
	set_leg_foot_target_pos(chosen_leg_index, global_position + Vector2.RIGHT * 180)
	
	## 4. 
	tween.tween_interval(0.5 * total_dur)
	tween.tween_callback(_lower_leg_to_ground.bind(chosen_leg_index))
	

func _lower_leg_to_ground(index: int):
	var floor_offset = Vector2.LEFT * 15 + Vector2.DOWN * (abs(BossPlatform.BOSS_SPAWN_OFFSET.y) - 4) # Platform thickness
	set_leg_foot_target_pos(index, get_leg_foot_target_pos(index) + floor_offset)

func _reset_legs_to_local_pos(pos: Vector2):
	for leg in legs:
		leg.set_foot_target_pos(global_position + pos)

func set_leg_foot_target_pos(index: int, target_pos: Vector2):
	legs[index].set_foot_target_pos(target_pos)

func get_leg_foot_target_pos(index: int) -> Vector2:
	return legs[index].get_foot_target_pos()

func end_animation():
	animating = false
	activate_legs()
	show_fangs()
	create_tween().tween_callback(hide_fangs).set_delay(1.0)

func activate_legs():
	for leg in legs:
		leg.automatically_walk = true

func set_mouth_open_angle(angle_degrees: float):
	right_mandible_angle_target.rotation_degrees = -angle_degrees + 180
	left_mandible_angle_target.rotation_degrees = angle_degrees

func show_fangs():
	var tween = create_tween().set_parallel()
	for fang in fangs:
		fang.show()
		tween.tween_property(fang, "modulate", Color.WHITE, 0.25).from(Color.WHITE * 5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	set_mouth_open_angle(45.0)

func hide_fangs():
	var tween = create_tween().set_parallel()
	const DUR = 0.25
	for fang in fangs:
		tween.tween_property(fang, "modulate", Color.WHITE * 5, DUR * 0.5).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(fang, "modulate", Color(5,5,5,0), DUR * 0.5).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(fang.hide).set_delay(DUR)
	set_mouth_open_angle(0.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	head_look_at_target.global_position = Global.player.global_position
