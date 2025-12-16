extends Node2D

class_name SpiderSkeleton
@onready var head_look_at_target: Marker2D = %HeadLookAtTarget
@onready var legs_parent: Sprite2D = %LegsParent
@onready var hitbox: Hitbox = $Sprites/Head/Hitbox

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
@onready var head_look_at: SoupLookAt = $Skeleton2D/HeadGroup/HeadLookAt
@onready var right_fang_particles: GPUParticles2D = $Sprites/Head/RightMandible/RightFang/RightFangParticles
@onready var left_fang_particles: GPUParticles2D = $Sprites/Head/LeftMandible/LeftFang/LeftFangParticles

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
@onready var player_hitbox: Area2D = $Sprites/Head/PlayerHitbox
@onready var head: Sprite2D = $Sprites/Head
const SPIDER_WEB_BALL = preload("uid://cpr4spep6mkfi")
@onready var spider_web_ball: SpiderWebBall = $Sprites/Head/SpiderWebBall
@onready var spider_web_ball_pos := spider_web_ball.position

const PLAYER_CLOSE_DIST = 120.0

#region State vars
## When true, hit/hurt boxes are disabled. Visual animation only.
var animating := true
var showing_fangs := true
var biting := false
var webbing := false
#endregion
 
## Animation for coming out of the door: 
## 1. (Skeleton) Reset all legs to global pos
## 2. (Skeleton) Set rightmost leg to global pos + far to the right
## 3. Start moving to the right
## 4. (Skeleton) Leg touches the ground, other legs poke out
## 5. Reach final position after duration, end
func start_animation(total_dur: float):
	animating = true
	hide_fangs()
	
	var chosen_leg_index := 7 # Could randomize this
	
	var tween := create_tween()
	## 1. 
	_reset_legs_to_local_pos(position - Vector2(100, BossPlatform.BOSS_SPAWN_OFFSET.y))
	
	## 2. 
	set_leg_foot_target_pos(global_position + Vector2.RIGHT * 220, chosen_leg_index)
	
	## 4. 
	tween.tween_interval(0.5 * total_dur)
	tween.tween_callback(_lower_leg_to_ground.bind(chosen_leg_index, 0.1 * total_dur))
	tween.tween_interval(0.3 * total_dur)
	tween.tween_callback(_set_legs_to_spread_position.bind(global_position + Vector2.RIGHT * 230))

func start_webbing():
	if not webbing:
		webbing = true
		hide_fangs()
		if not spider_web_ball:
			spider_web_ball = SPIDER_WEB_BALL.instantiate()
			spider_web_ball.position = spider_web_ball_pos
			head.add_child(spider_web_ball)
		spider_web_ball.cocooned_player.connect(stop_webbing)
		spider_web_ball.show_ball()
		create_tween().tween_method(set_mouth_open_angle, 0.0, 40.0, 2.5).set_trans(Tween.TRANS_SINE)

func stop_webbing():
	if webbing:
		webbing = false
		if spider_web_ball:
			spider_web_ball.hide_if_not_cocooning_player()

func _set_legs_to_spread_position(relative_to_pos: Vector2):
	for leg in legs:
		var leg_vec = Vector2.from_angle(leg.rotation + PI / 2)
		var hit_pos = Pathfinding.do_raycast(relative_to_pos, relative_to_pos + leg_vec * 200)
		
		leg.set_foot_target_pos(hit_pos if hit_pos != Vector2.INF else relative_to_pos + Vector2.UP * 1000)

func _lower_leg_to_ground(index: int, duration: float):
	var floor_offset = Vector2.LEFT * 30 + Vector2.DOWN * (abs(BossPlatform.BOSS_SPAWN_OFFSET.y) + 6)
	create_tween().tween_method(
		set_leg_foot_target_pos.bind(index), 
		get_leg_foot_target_pos(index), 
		get_leg_foot_target_pos(index) + floor_offset, 
		duration
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func _reset_legs_to_local_pos(pos: Vector2):
	for leg in legs:
		leg.set_foot_target_pos(global_position + pos)

func set_leg_foot_target_pos(target_pos: Vector2, index: int):
	legs[index].set_foot_target_pos(target_pos)

func get_leg_foot_target_pos(index: int) -> Vector2:
	return legs[index].get_foot_target_pos()

func get_legs_on_ground() -> Array[SpiderSkeletonLeg]:
	var ground_legs: Array[SpiderSkeletonLeg] = []
	for leg in legs:
		if leg.is_on_ground:
			ground_legs.append(leg)
	return ground_legs

func get_fraction_of_legs_on_ground() -> float:
	return float(len(get_legs_on_ground())) / float(len(legs)) 

func get_average_leg_pos() -> Vector2:
	var ground_legs := get_legs_on_ground()
	var count = len(ground_legs)
	if count == 0:
		return Vector2.ZERO
	
	var avg_position: Vector2 = Vector2.ZERO
	for leg in ground_legs:
		avg_position += leg.foot_target.global_position / float(count)
	
	return avg_position

func disable_head_look_at():
	head_look_at.enabled = false

func end_animation():
	animating = false
	activate_legs()

func activate_legs():
	for leg in legs:
		leg.automatically_walk = true

func set_mouth_open_angle(angle_degrees: float):
	right_mandible_angle_target.rotation_degrees = -angle_degrees + 180
	left_mandible_angle_target.rotation_degrees = angle_degrees

var fang_tween: Tween
func show_fangs(for_bite := false):
	if not showing_fangs or for_bite:
		showing_fangs = true
		if fang_tween: fang_tween.kill()
		fang_tween = create_tween().set_parallel()
		for fang in fangs:
			fang.show()
			fang_tween.tween_property(fang, "modulate", Color.WHITE, 0.35).from(Color.WHITE * 5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		set_mouth_open_angle(75.0 if for_bite else 40.0)
		right_fang_particles.emitting = for_bite
		left_fang_particles.emitting = for_bite
		

func bite_fangs():
	assert(showing_fangs and biting)
	set_mouth_open_angle(10.0)
	for fang in fangs:
		if fang_tween: fang_tween.kill()
		fang_tween = create_tween().set_parallel()
		fang_tween.tween_property(fang, "modulate", Color.WHITE, 0.35).from(Color.WHITE * 5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fang_tween.tween_property(fang, "modulate", Color.WHITE, 0.35).from(Color.WHITE * 5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fang_tween.tween_property(right_fang_particles, "emitting", false, 0.0)
		fang_tween.tween_property(left_fang_particles, "emitting", false, 0.0)

func hide_fangs():
	if showing_fangs:
		showing_fangs = false
		if fang_tween: fang_tween.kill()
		fang_tween = create_tween().set_parallel()
		const DUR = 0.35
		for fang in fangs:
			fang_tween.tween_property(fang, "modulate", Color.WHITE * 5, DUR * 0.5).set_trans(Tween.TRANS_CUBIC)
			fang_tween.tween_property(fang, "modulate", Color(5,5,5,0), DUR * 0.5).set_trans(Tween.TRANS_CUBIC)
			fang_tween.tween_callback(fang.hide).set_delay(DUR)
		set_mouth_open_angle(0.0)

func get_player_look_at_when_close_frac() -> float:
	var player_pos = Global.player.global_position
	var pos = global_position
	var dist = player_pos.distance_to(pos)
	return clampf(inverse_lerp(PLAYER_CLOSE_DIST,  50, dist), 0.0, 1.0) 

	# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	legs_parent.show()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if not animating:
		# 1. Define the components of the interpolation
		var player_position: Vector2 = Global.player.global_position
		var neutral_look_position: Vector2 = global_position + Vector2.DOWN * 200.0
		
		# 2. Calculate the base fractions
		var legs_on_ground_frac: float = get_fraction_of_legs_on_ground()
		var player_close_frac: float = get_player_look_at_when_close_frac()
		
		# 3. Calculate the final interpolation factor (t)
		# The inner lerpf is the 't' value for the outer lerp
		var interpolation_factor: float = lerpf(legs_on_ground_frac, (1.0 - player_close_frac), 1.0)
		
		# 4. Perform the final interpolation and set the position
		head_look_at_target.global_position = lerp(player_position, neutral_look_position, interpolation_factor)
		
		if biting or webbing: head_look_at_target.global_position = player_position 
		
		# Decide whether to show fangs
		if not (biting or webbing):
			if player_close_frac > 0:
				show_fangs()
			else:
				hide_fangs()


func _on_player_hitbox_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		area.take_damage(30.0) # TODO fix double hitting here
