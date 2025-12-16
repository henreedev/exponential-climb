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

## True when lunging and then executing a bite. 
var biting := false

## True when generating and chasing the player with a web ball.
var webbing := false

const BITE_CLOSENESS_DIST = SpiderSkeleton.PLAYER_CLOSE_DIST
const BITE_CLOSENESS_DURATION := 0.75
var bite_closeness_timer := BITE_CLOSENESS_DURATION

#region Acceleration in same direction
const GOAL_SPEED = 150.0
var prev_direction := Vector2.RIGHT
# How much of base speed is added per second
const SAME_DIR_SPEED_BONUS_INCREASE_RATE := 0.05
var same_dir_extra_speed := 0.0
const MAX_SAME_DIR_SPEED_BONUS := 0.5
const PREV_DIRECTION_UPDATE_INTERVAL := 0.5
var prev_direction_update_timer := 0.0

#region Acceleration in same direction

#region Jumping
const JUMP_COOLDOWN := 10.0
var jump_cooldown_timer := 0.0 # Let the spider jump immediately if necessary
const JUMP_DISTANCE_THRESHOLD := 250.0
#endregion Jumping

#region Webbing
const WEB_COOLDOWN := 30.0
var web_cooldown_timer := 0.0 # FIXME WEB_COOLDOWN
const WEB_BONUS_SPEED_MULT := 1.5
#var web_bonus_speed_mult := 1.0
const WEB_CHASE_DURATION := 10.0
#endregion Webbing

@onready var base_linear_damp := linear_damp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("BASE LINEAR DAMP IS ", base_linear_damp)
	_init_stats()
	_setup_knockback_signal()
	start_animation_after_delay()

func start_animation_after_delay(delay := 1.0):
	animating = true
	invincible = true
	var tween = create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(start_animation)

func _init_stats() -> void:
	hc = HealthComponent.new()
	hc.init(20000)
	hc.died.connect(die)

func _setup_knockback_signal() -> void:
	skeleton.hitbox.received_knockback.connect(_apply_impulse)

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
	tween.tween_interval(total_dur * 0.2)
	
	# 5. Jump out of door
	tween.tween_property(self, "global_position:x", global_position.x + 270, total_dur * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "global_position:y", global_position.y - 25, total_dur * 0.3).set_trans(Tween.TRANS_BACK)
	
	tween.tween_callback(end_animation)
	
func end_animation():
	print("Ending animation!")
	skeleton.end_animation()
	ended_animation.emit()
	create_tween().tween_property(self, "linear_damp", linear_damp, 1.0).from(999.0)
	animating = false
	invincible = false
	freeze = false


func _physics_process(delta: float) -> void:
	if animating: 
		return
	try_web(delta)
	try_bite(delta)
	try_jump(delta)
	apply_force_towards_player(delta)
	apply_gravity()

func try_web(delta: float):
	if webbing: 
		return
	if web_cooldown_timer > 0.0:
		web_cooldown_timer -= delta
		return
	if len(skeleton.get_legs_on_ground()) == 0:
		return
	
	webbing = true
	web_cooldown_timer = WEB_COOLDOWN
	
	var tween: Tween = create_tween()
	
	tween.tween_callback(skeleton._set_legs_to_spread_position.bind(Vector2.ZERO))
	tween.tween_property(skeleton, "animating",true,0)
	tween.tween_property(self, "animating",true,0)
	tween.tween_interval(0.5)
	tween.tween_callback(skeleton.start_webbing)
	tween.tween_callback(_connect_player_cocooned_signal)
	tween.tween_interval(2.5)
	
	tween.tween_property(skeleton, "animating", false, 0)
	tween.tween_property(self, "animating",false,0)
	tween.tween_property(self, "linear_damp",3.0,0.5)
	tween.tween_interval(WEB_CHASE_DURATION)
	tween.tween_callback(stop_webbing)

func _connect_player_cocooned_signal():
	skeleton.spider_web_ball.cocooned_player.connect(stop_webbing)

func stop_webbing():
	if webbing:
		webbing = false
		skeleton.stop_webbing()
		create_tween().tween_property(self, "linear_damp", base_linear_damp, 1.0)

func try_jump(delta: float) -> void:
	if jump_cooldown_timer > 0.0:
		jump_cooldown_timer -= delta
		return
	if len(skeleton.get_legs_on_ground()) == 0:
		return
	if biting or webbing:
		return
	var player_dist = get_player_dist() 
	if player_dist < JUMP_DISTANCE_THRESHOLD:
		return
	else:
		print("Jumping!")
		jump_cooldown_timer = JUMP_COOLDOWN
		
		var predict_ratio = inverse_lerp(0, 1500, player_dist)
		var player_dir = global_position.direction_to(Global.player.global_position + Global.player.velocity * predict_ratio * 0.5 + Vector2.UP * 50 * predict_ratio)
		var jump_impulse = player_dir * 400.0 * (1.0 + predict_ratio)
		
		var tween: Tween = create_tween()
		
		
		var windup_pos := global_position + get_ground_direction() * get_ground_dist() * .5
		
		tween.tween_property(self, "global_position", windup_pos, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(apply_central_impulse.bind(jump_impulse))
		tween.tween_callback(skeleton._reset_legs_to_local_pos.bind(jump_impulse * 0.3))
		tween.tween_property(skeleton, "animating",true,0)
		tween.tween_property(self, "animating",true,0)
		tween.tween_interval(1.0 * predict_ratio)
		tween.tween_property(skeleton, "animating", false, 0)
		tween.tween_property(self, "animating",false,0)
		
func get_player_dist() -> float:
	return global_position.distance_to(Global.player.global_position)

func apply_force_towards_player(delta: float):
	update_same_dir_accel(delta)
	var player_dir := global_position.direction_to(Global.player.global_position)
	var web_bonus := (WEB_BONUS_SPEED_MULT if webbing else 1.0)
	var goal_speed_with_same_dir_accel := GOAL_SPEED * web_bonus + same_dir_extra_speed 
	var goal_diff := goal_speed_with_same_dir_accel - linear_velocity.project(player_dir).length()
	goal_diff = maxf(goal_diff, 0) # Never slow down  when moving towards player
	var force_strength := goal_diff * 6 * web_bonus
	_apply_force(player_dir * force_strength)

func update_same_dir_accel(delta: float):
	var curr_dir := linear_velocity.normalized()
	var prev_dir_similarity = (prev_direction.dot(curr_dir) - 0.5) * 2
	if prev_dir_similarity < 0: prev_dir_similarity *= 2
	same_dir_extra_speed += prev_dir_similarity * SAME_DIR_SPEED_BONUS_INCREASE_RATE * GOAL_SPEED * delta
	same_dir_extra_speed = clampf(same_dir_extra_speed, 0, GOAL_SPEED * MAX_SAME_DIR_SPEED_BONUS)
	if prev_direction_update_timer <= 0.0:
		prev_direction_update_timer = PREV_DIRECTION_UPDATE_INTERVAL
		prev_direction = curr_dir
	else:
		prev_direction_update_timer -= delta

func apply_gravity():
	_apply_force(calculate_gravity())

func _apply_force(force: Vector2):
	apply_central_force(force * mass)

func _apply_impulse(impulse: Vector2):
	apply_central_impulse(impulse)

func get_ground_direction() -> Vector2:
	return global_position.direction_to(skeleton.get_average_leg_pos())

func get_ground_dist() -> float:
	return global_position.distance_to(skeleton.get_average_leg_pos())

## In this method, "floor" is straight down and "ground" is towards leg foot positions.
func calculate_gravity() -> Vector2:
	var ground_frac = skeleton.get_fraction_of_legs_on_ground()
	var ground_dir = get_ground_direction()
	var ground_dist = get_ground_dist()
	
	# Try to stay this far from the ground.
	const IDEAL_GROUND_DIST = 60.0
	var ideal_ground_diff_ratio = clampf(inverse_lerp(IDEAL_GROUND_DIST, 100, ground_dist), -1, 1) * 2
	
	const GRAVITY_STR = 700.0
	const FLOOR_DIR = Vector2.DOWN
	var floor_gravity := GRAVITY_STR * FLOOR_DIR
	
	var ground_gravity = ground_dir * GRAVITY_STR * ideal_ground_diff_ratio
	
	var blended_grav = lerp(floor_gravity, ground_gravity, sqrt(ground_frac)) # Strengthen the power of fewer legs
	
	return blended_grav 
	
func take_damage(amount: float, damage_color: DamageNumber.DamageColor):
	if invincible: 
		return
	var damage_taken = hc.take_damage(amount)
	
	if damage_taken > 0:
		DamageNumbers.create_damage_number(damage_taken, global_position, damage_color)

## Lunge at player 
func try_bite(delta: float):
	if bite_closeness_timer > 0.0 or biting or webbing:
		if get_player_dist() < BITE_CLOSENESS_DIST:
			bite_closeness_timer -= delta
		else:
			bite_closeness_timer = BITE_CLOSENESS_DURATION
		return
	print("Biting!")
	
	# Wind up, then lunge, then enable hitbox. 
	const LUNGE_DUR := 0.6	
	biting = true
	skeleton.biting = true
	skeleton.show_fangs(true)
	var tween: Tween = create_tween()
	
	# Find where to lunge to
	var lunge_to_pos = Global.player.global_position + (Global.player.velocity * 0.5).clampf(-100, 100) 
	var lunge_dir = global_position.direction_to(lunge_to_pos) 
	var hit_pos = Pathfinding.do_raycast(global_position, lunge_to_pos)
	lunge_to_pos = hit_pos - lunge_dir * 30 if hit_pos != Vector2.INF else lunge_to_pos
	
	tween.tween_property(self, "global_position", lunge_to_pos, LUNGE_DUR * 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_callback(enable_bite_hitbox.bind(LUNGE_DUR * 0.2)).set_delay(LUNGE_DUR * 0.6)
	tween.tween_callback(skeleton.bite_fangs)
	tween.tween_interval(LUNGE_DUR * 0.2)
	tween.tween_property(self, "biting", false, 0.0)
	tween.tween_property(skeleton, "biting", false, 0.0)
	tween.tween_property(self, "bite_closeness_timer", BITE_CLOSENESS_DURATION, 0.0)

func enable_bite_hitbox(for_dur: float):
	var tween = create_tween()
	tween.tween_property(skeleton.player_hitbox, "process_mode", ProcessMode.PROCESS_MODE_INHERIT, 0.0)
	tween.tween_interval(for_dur)
	tween.tween_property(skeleton.player_hitbox, "process_mode", ProcessMode.PROCESS_MODE_DISABLED, 0.0)

func die():
	var tween := create_tween()
	const DUR = 3.0
	skeleton.disable_head_look_at()
	skeleton.animating = true
	animating = true
	invincible = true 
	set_deferred("lock_rotation", false)
	tween.tween_property(self, "angular_velocity", 30.0, DUR).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", Vector2.ZERO, DUR).set_trans(Tween.TRANS_CIRC)
	tween.tween_callback(queue_free)
	died.emit()
