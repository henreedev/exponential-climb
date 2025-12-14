extends RigidBody2D

class_name SpiderBoss

signal died
signal ended_animation

const ANIMATION_DURATION := 5.0

var hc: HealthComponent

@onready var skeleton: SpiderSkeleton = $SpiderSkeleton

## True while doing a cutscene (animating)
var invincible := false

## Body doesn't move towards player automatically.  Also should be invincible. 
var animating := false

#region Jumping
var jump_cooldown_timer := 0.0
const JUMP_COOLDOWN := 10.0
const JUMP_DISTANCE_THRESHOLD := 250.0
#endregion Jumping

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_init_stats()
	start_animation_after_delay()

func start_animation_after_delay(delay := 1.0):
	var tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(start_animation)

func _init_stats() -> void:
	hc = HealthComponent.new()
	hc.init(200)
	hc.died.connect(die)

## Animation for coming out of the door: 
## 1. (Skeleton) Reset all legs to global pos
## 2. (Skeleton) Set rightmost leg to global pos + far to the right
## 3. Start moving to the right
## 4. (Skeleton) Leg touches the ground, other legs poke out
## 5. Reach final position after duration, end
func start_animation(total_dur := ANIMATION_DURATION):
	animating = true
	invincible = true
	skeleton.start_animation(total_dur)
	
	# 3. Initial movement near door
	var tween := create_tween()
	tween.tween_property(self, "global_position", global_position + Vector2.RIGHT * 80, total_dur * 0.5)	
	tween.tween_interval(total_dur * 0.1)
	
	# 5. Jump out of door
	tween.tween_property(self, "global_position:x", global_position.x + 230, total_dur * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "global_position:y", global_position.y - 40, total_dur * 0.4).set_trans(Tween.TRANS_BACK)
	
	tween.tween_callback(end_animation)
	
func end_animation():
	skeleton.end_animation()
	ended_animation.emit()
	animating = false
	invincible = false
	freeze = false


func _physics_process(delta: float) -> void:
	if animating: 
		return
	try_jump(delta)
	apply_force_towards_player()
	apply_gravity()

func try_jump(delta: float) -> void:
	if jump_cooldown_timer > 0.0:
		jump_cooldown_timer -= delta
		return
	if len(skeleton.get_legs_on_ground()) == 0:
		return
	var player_dist = get_player_dist() 
	if player_dist < JUMP_DISTANCE_THRESHOLD:
		return
	else:
		jump_cooldown_timer = JUMP_COOLDOWN
		
		var predict_ratio = inverse_lerp(0, 2000, player_dist)
		var player_dir = global_position.direction_to(Global.player.global_position + Global.player.velocity * predict_ratio + Vector2.UP * 100 * predict_ratio)
		var jump_impulse = player_dir * 500.0 * (1.0 + predict_ratio)
		
		var tween: Tween = create_tween()
		
		
		var windup_pos := global_position + get_ground_direction() * get_ground_dist() * .5
		
		tween.tween_property(self, "global_position", windup_pos, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(apply_central_impulse.bind(jump_impulse))
		tween.tween_callback(skeleton._reset_legs_to_local_pos.bind(jump_impulse * 0.3))
		tween.tween_property(skeleton, "animating",true,0)
		tween.tween_property(self, "animating",true,0)
		tween.tween_interval(1.0 * predict_ratio)
		tween.tween_property(skeleton, "animating", false, 0)
		tween.tween_property(self, "animating",false,0)
		
func get_player_dist() -> float:
	return global_position.distance_to(Global.player.global_position)

func apply_force_towards_player():
	var player_dir := global_position.direction_to(Global.player.global_position)
	const GOAL_SPEED = 180.0
	var goal_diff := GOAL_SPEED - linear_velocity.project(player_dir).length()
	goal_diff = maxf(goal_diff, 0) # Never slow down  when moving towards player
	var force_strength := goal_diff * 6
	apply_central_force(player_dir * force_strength)

func apply_gravity():
	apply_central_force(calculate_gravity())

func get_ground_direction() -> Vector2:
	return global_position.direction_to(skeleton.get_average_leg_pos())

func get_ground_dist() -> float:
	return global_position.distance_to(skeleton.get_average_leg_pos())

func calculate_gravity() -> Vector2:
	var ground_frac = skeleton.get_fraction_of_legs_on_ground()
	var ground_dir = get_ground_direction()
	var ground_dist = get_ground_dist()
	
	# Try to stay this far from the ground.
	const IDEAL_GROUND_DIST = 70.0
	if ground_dist < IDEAL_GROUND_DIST:
		ground_dir *= -1
	
	const FLOOR_DIR = Vector2.DOWN
	var effective_dir = lerp(FLOOR_DIR, ground_dir, sqrt(ground_frac)) # Strengthen the power of fewer legs
	
	const GRAVITY_STR = 500.0
	var gravity = effective_dir * GRAVITY_STR
	return gravity 
	
func take_damage(amount: float, damage_color: DamageNumber.DamageColor):
	if invincible: 
		return
	var damage_taken = hc.take_damage(amount)
	
	if damage_taken > 0:
		DamageNumbers.create_damage_number(damage_taken, global_position, damage_color)

func die():
	var tween := create_tween()
	const DUR = 3.0
	tween.tween_property(skeleton, "rotation", 20.0, DUR).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, DUR).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)
	died.emit()

#func jump():
	#
