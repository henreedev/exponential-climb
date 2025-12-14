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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_init_stats()
	start_animation()

func _init_stats() -> void:
	hc = HealthComponent.new()
	hc.init(2000)
	hc.died.connect(died.emit)

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
	tween.parallel().tween_property(self, "global_position:y", global_position.y - 40, total_dur * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.tween_callback(end_animation)
	
func end_animation():
	skeleton.end_animation()
	ended_animation.emit()
	animating = false
	invincible = false


func _physics_process(_delta: float) -> void:
	if animating: 
		return
	apply_force_towards_player()

func apply_force_towards_player():
	var player_dir := global_position.direction_to(Global.player.global_position)
	const GOAL_SPEED = 150.0
	var goal_diff := GOAL_SPEED - linear_velocity.project(player_dir).length()
	var force_strength := goal_diff * 6
	apply_central_force(player_dir * force_strength)
	
	#var gravity = num_legs_on_ground
#
#func get_fraction_of_legs_on_ground() -> float:
	#for leg in skeleton.legs
	#return  len(skeleton.legs)

func take_damage(amount: float, damage_color: DamageNumber.DamageColor):
	if invincible: 
		return
	var damage_taken = hc.take_damage(amount)
	
	if damage_taken > 0:
		DamageNumbers.create_damage_number(damage_taken, global_position, damage_color)
