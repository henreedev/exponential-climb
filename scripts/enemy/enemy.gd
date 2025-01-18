extends CharacterBody2D

## The base class for all enemies. 
class_name Enemy

enum Class {
	BASIC_MELEE, ## e.g. Lemurian from RoR1 
}

enum State {
	IDLE, ## The enemy is unaware of the player.
	CHASING, ## The enemy has a path to the player and is following it.
	ATTACKING, ## The enemy is performing an attack.
	STUNNED, ## The enemy is in hitstun.
}

## Dict from class type to the PlayerClass resource storing information on that class.
const CLASSES_DICT : Dictionary[Class, EnemyClass] = {
	Class.BASIC_MELEE : preload("res://resources/enemy_classes/class_basic_melee.tres"),
}


## The type of this enemy.
var _class : Class

## The current state of this enemy.
var state : State

#region Player detection
## The radius within which the enemy will path to the player.
const PLAYER_DETECTION_RADIUS := 250.0
const PLAYER_DETECTION_RADIUS_SQRD := PLAYER_DETECTION_RADIUS * PLAYER_DETECTION_RADIUS
## Multiply y by this value when checking player distance, so as to detect the player in a horizontal oval shape
const PLAYER_DETECTION_Y_MULT := 0.5
## The time between detection radius checks.
const DETECTION_INTERVAL := 1.0
var detection_check_timer := DETECTION_INTERVAL

## The time the player remains detected after a successful radius check.
const DETECTION_DURATION := 5.0
## Whether the player has recently been in the detection radius.
var player_detected := false
## How much longer the player is detected for.
var detection_duration_timer := 0.0
## The minimum interval between regenerating paths when the current one is outdated.
const REGENERATE_INTERVAL := 0.5
var regenerate_path_timer := 0.0
## The last point in a generated path, to be distance checked with the player when deciding if a path is outdated.
var original_endpoint : Vector2
## The distance between the player and the last point in the path required for a path to be outdated.
const ENDPOINT_DISTANCE_THRESHOLD := 80.0
@onready var debug_label: Label = $DebugLabel

var player : Player
#endregion Player detection

#region Movement and physics
## The direction the enemy will try to move in.
var movement_dir := Vector2.ZERO
const BASE_MOVEMENT_ACCEL := 12.0
var movement_speed : Stat
var jump_strength : Stat
var gravity : Stat
var on_floor := false
#endregion Movement and physics

#region Health
const DEFAULT_MAX_HEALTH := 100
var hc : HealthComponent
#endregion Health

#region Attack stats
## Determines overall strength, factoring into damage on hit.
var base_damage : Stat 

## The range at which the enemy will attempt to attack the player.
var range : Stat

## Duration between starting an attack and it actually dealing damage.
var attack_windup : float
## The duration the attack hitbox is active for.
var attack_duration : float
## The delay after attacking before the enemy can move again.
var attack_winddown : float
## The duration the enemy must wait between attacks.
var attack_cooldown : float

## Multiplier on the speed of attacks. Affects attack delay, duration, and cooldown
var attack_speed : Stat
#endregion Attack stats

#region Attack logic

var attack_cooldown_timer := 0.0
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/AttackShape

#endregion Shapes

#region Pathfinding vars
var currentPath : Array # of Vector2 or null
var currentTarget # Vector2 or null

var padding = 1
var finishPadding = 5
## True when a jump was required but enemy was midair. Causes a jump upon landing.
var jump_once_on_floor := false 
#endregion Pathfinding vars

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.enemy = self
	player = Global.player
	state = State.IDLE
	velocity = Vector2(0, 0)
	_initialize_enemy_class()

#region Classes 
func _initialize_enemy_class():
	# Lookup the class resource file by type 
	var enemy_class : EnemyClass = CLASSES_DICT[_class]
	# Init stats
	movement_speed = Stat.new()
	movement_speed.set_base(enemy_class.movement_speed)
	
	jump_strength = Stat.new()
	jump_strength.set_base(enemy_class.jump_strength)
	
	gravity = Stat.new()
	gravity.set_base(Global.GRAVITY)
	
	range = Stat.new()
	range.set_base(enemy_class.range)
	
	base_damage = Stat.new()
	base_damage.set_base(enemy_class.base_damage)
	base_damage.set_type(true)
	
	attack_windup = enemy_class.attack_windup
	attack_winddown = enemy_class.attack_winddown
	attack_duration = enemy_class.attack_duration
	attack_cooldown = enemy_class.attack_cooldown
	
	attack_speed = Stat.new()
	attack_speed.set_base(1.0)
	
	# Init health component and its max_health stat
	hc = HealthComponent.new()
	
	hc.max_health = Stat.new()
	hc.max_health.set_base(enemy_class.max_health)
	hc.max_health.set_type(true)
	hc.set_health_to_full()

#endregion Classes 

#region Player detection methods
func player_in_detection_radius():
	var diff = player.global_position - global_position
	diff.y *= PLAYER_DETECTION_Y_MULT
	return diff.length_squared() < PLAYER_DETECTION_RADIUS_SQRD

func check_player_detection():
	if detection_check_timer <= 0:
		# Check if can detect player right now
		if player_in_detection_radius():
			detection_duration_timer = DETECTION_DURATION
			player_detected = true
		detection_check_timer = DETECTION_INTERVAL * _get_timer_randomness()
	if detection_duration_timer <= 0:
		player_detected = false

func tick_timers(delta : float):
	if detection_check_timer > 0: 
		detection_check_timer -= delta 
	if detection_duration_timer > 0: 
		detection_duration_timer -= delta 
	if regenerate_path_timer > 0: 
		regenerate_path_timer -= delta
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

func _get_timer_randomness():
	return randf_range(0.9, 1.1)

func _get_rand_sign():
	return int(randf() >= 0.5) * 2 - 1


func act_on_state(delta : float):
	queue_redraw()
	match state:
		State.IDLE:
			do_custom_idle_movement(delta)
			tick_timers(delta)
			check_player_detection()
			if player_detected:
				state = State.CHASING
		State.CHASING:
			tick_timers(delta)
			check_player_detection()
			if player_detected:
				# Check if has a path; if not, try to get one (on an interval)
				if not currentPath and not currentTarget and regenerate_path_timer <= 0:
					find_path(player.global_position)
				# If path: 
				if currentPath or currentTarget:
					# Regenerate if player is ENDPOINT_DISTANCE_THRESHOLD away from original endpoint
					if regenerate_path_timer <= 0 and \
							original_endpoint.distance_to(player.global_position) > ENDPOINT_DISTANCE_THRESHOLD:
						find_path(player.global_position)
						print("REGENERATED")
					# Move actual endpoint to player position (TODO)
				if player.global_position.distance_to(global_position) < get_attack_range():
					attack()
			if state == State.CHASING: # Might have attacked
				# If path:
					# Move along the path
				if currentPath or currentTarget:
					# Pathfinding movement
					path_towards_target()
				else:
					movement_dir = Vector2.ZERO
				# Transition out of the state if player isn't detected and there isn't an old path to follow
				if not player_detected and not currentPath and not currentTarget:
					currentPath = []
					currentTarget = null
					state = State.IDLE
		State.ATTACKING:
			movement_dir = Vector2.ZERO
			tick_timers(delta)
		State.STUNNED:
			tick_timers(delta)
	debug_label.text = get_state_string()

func attack():
	# Change state to ATTACKING
	state = State.ATTACKING
	# Determine attack direction
	attack_area.scale.x = 1 if movement_dir.x >= 0 else -1
	# Stand still while attacking
	movement_dir = Vector2.ZERO
	var cooldown = get_attack_cooldown()
	attack_cooldown_timer = cooldown
	# Do the actual attack using a tween
	var attack_tween := create_tween()
	do_custom_attack(attack_tween)
	# Begin CHASING once done
	attack_tween.tween_property(self, "state", State.CHASING, 0.0)

## Overridden by child Enemy classes to implement custom attacks using the given tween.
func do_custom_attack(attack_tween : Tween):
	var damage = get_attack_damage()
	
	var windup = get_attack_windup()
	var duration = get_attack_duration()
	var winddown = get_attack_winddown()
	
	attack_tween.tween_interval(windup)
	
	attack_tween.tween_property(attack_shape, "disabled", false, 0.0)
	attack_tween.tween_interval(duration)
	
	attack_tween.tween_property(attack_shape, "disabled", true, 0.0)
	attack_tween.tween_interval(winddown)

func do_custom_idle_movement(delta : float):
	movement_dir = Vector2.ZERO

func player_in_los():
	var result = Pathfinding.do_raycast(global_position, player.global_position)
	return result != Vector2.INF

func get_state_string():
	match state:
		State.IDLE:
			return "IDLE" + (("TARGET = " + str(currentTarget) + ", DISTANCE = " + str(currentTarget.distance_to(position)).pad_decimals(1)) if currentTarget else "")
		State.CHASING:
			return "CHASING" + ((": PATH LEN " + str(len(currentPath))) if currentPath else "") + ((", DETECTED FOR " + str(detection_duration_timer).pad_decimals(1)) if detection_duration_timer > 0 else ", NOT DETECTED")
		State.STUNNED:
			return "STUNNED"
		State.ATTACKING:
			return "ATTACKING"

func _draw():
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, PLAYER_DETECTION_RADIUS, Color(Color.CRIMSON, 0.4), false, 1.0)


#endregion Player detection methods

#region Pathfinding methods
func nextPoint():
	if len(currentPath) == 0:
		currentTarget = null
		return
	if not jump_once_on_floor: 
		currentTarget = currentPath.pop_front()
	
	# Jump action
	if currentTarget == null:
		if jump(): # Go to next point if jump was successful
			nextPoint()

func jump():
	if is_on_floor():
		velocity.y = -jump_strength.value()
		jump_once_on_floor = false
		return true
	else:
		jump_once_on_floor = true
		return false # unsuccessful jump
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta : float):
	# Update state, setting `movement_dir`.
	act_on_state(delta)
	
	# Ensure velocity does not grow while at a visible standstill
	if get_real_velocity().length_squared() < 0.005:
		velocity = get_real_velocity()
	# From mouse position, raycast down and tell the enemy to go to hit position
	if Input.is_action_just_pressed("test_navigation"):
		var mouse_pos = get_global_mouse_position()
		var target_pos = Pathfinding.do_raycast(mouse_pos, Vector2(mouse_pos.x, mouse_pos.y + 1000))
		if target_pos != Vector2.INF:
			find_path(target_pos)
	# Teleport enemy to mouse position
	if Input.is_action_just_pressed("teleport_enemy"):
		global_position = get_global_mouse_position()
	

	
	# Move horizontally.
	var speed = movement_speed.value()
	var direction : Vector2 = movement_dir * speed
	#var accel_mod = 1.0 if is_on_floor() else AIR_ACCEL_MOD # Slows acceleration in air 
	var accel_speed = speed * BASE_MOVEMENT_ACCEL # * accel_mod
	
	# Move platforming velocity x in input direction
	velocity.x = move_toward(velocity.x, direction.x, accel_speed * delta)
	# Gravity
	if !is_on_floor():
		velocity.y += gravity.value() * delta

	
	move_and_slide()

func _check_floor_landing():
	if is_on_floor() and not on_floor: # Just landed
		if jump_once_on_floor:
			nextPoint()
	on_floor = is_on_floor()

func find_path(target_pos : Vector2):
	regenerate_path_timer = REGENERATE_INTERVAL * _get_timer_randomness()
	currentPath = Pathfinding.find_path(position, target_pos)
	if len(currentPath) > 0 and currentPath[-1] != null:
		# Set original endpoint
		original_endpoint = currentPath[-1]
	nextPoint()


func path_towards_target():
	if currentTarget:
		if (currentTarget.x - padding > position.x): 
			movement_dir.x = 1
		elif (currentTarget.x + padding < position.x): 
			movement_dir.x = -1
		else:
			movement_dir.x = 0
			
		if (abs(position.x - currentTarget.x) < finishPadding) and is_on_floor():
			nextPoint()
	else:
		movement_dir.x = 0
#endregion Pathfinding methods

#region Stat calculation methods


func get_attack_windup():
	return attack_windup / attack_speed.value()

func get_attack_duration():
	return attack_duration / attack_speed.value()

func get_attack_winddown():
	return attack_windup / attack_speed.value()

func get_attack_cooldown():
	return attack_cooldown / attack_speed.value()

func get_attack_damage():
	return base_damage.value()

func get_attack_range():
	return range.value()

#endregion Stat calculation methods

#region Damage interaction methods
## Deals damage to the enemy's health component, displays visuals, and applies knockback (TODO)
func take_damage(damage : float):
	hc.take_damage(damage)
	print("Damage taken: ", damage, ", New health: ", hc.health)
	DamageNumbers.create_damage_number(damage, global_position + Vector2.UP * 16)

#func die()

#endregion Damage interaction methods
