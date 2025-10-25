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
const PLAYER_DETECTION_RADIUS := 500.0
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
const REGENERATE_INTERVAL := 1.5
var regenerate_path_timer := 0.0
## The last point in a generated path, to be distance checked with the player when deciding if a path is outdated.
var original_endpoint : Vector2
## The distance between the player and the last point in the path required for a path to be outdated.
const ENDPOINT_DISTANCE_THRESHOLD := 80.0
## The threshold after receiving a random offset. 
var endpoint_distance_threshold_randomized : float
@onready var debug_label: Label = $DebugLabel

var player : Player
#endregion Player detection

#region Movement and physics
const BASE_MOVEMENT_ACCEL := 12.0
const AIR_ACCEL_MOD := 0.5
const STUNNED_ACCEL_MOD := 0.5
## The direction the enemy will try to move in.
var movement_dir := Vector2.ZERO
var movement_speed : Stat
var jump_strength : Stat
var gravity : Stat
var on_floor := false
## The enemes currently touching this enemy. Used in repulsion.
var touching_enemies : Array[Enemy] = []

## Flushed each physics tick, multiplied by delta time.
var forces : Vector2
## Flushed each physics tick.
var impulses : Vector2

#endregion Movement and physics

#region Health
const DEFAULT_MAX_HEALTH := 100
var hc : HealthComponent
#endregion Health

#region Level-ups and XP
## The experience points given when this enemy is killed.
var xp : int
var level : int
var level_base_health_mod : StatMod
var level_base_damage_mod : StatMod

#endregion Level-ups and XP

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

## How much longer the enemy is stunned for. 
var stunned_timer := 0.0
#endregion Shapes

#region Pathfinding vars
var currentPath : Array # of Vector2 or null
var currentTarget # Vector2 or null

var padding = 1
var finishPadding = 5
## True when a jump was required but enemy was midair. Causes a jump upon landing.
var jump_once_on_floor := false 
#endregion Pathfinding vars

#region Health

@onready var health_bar: TextureProgressBar = $HealthBar

#endregion Health

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.enemy = self
	player = Global.player
	state = State.IDLE
	velocity = Vector2(0, 0)
	
	_initialize_enemy_class()
	
	# Wait until after initializing health component
	hc.damage_taken.connect(update_health_bar)
	hc.healing_received.connect(update_health_bar)
	update_health_bar()



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
	# Increase base damage according to level
	base_damage.append_mult_mod(EnemySpawner.enemy_base_damage_mult)
	
	attack_windup = enemy_class.attack_windup
	attack_winddown = enemy_class.attack_winddown
	attack_duration = enemy_class.attack_duration
	attack_cooldown = enemy_class.attack_cooldown
	
	attack_speed = Stat.new()
	attack_speed.set_base(1.0)
	
	level = EnemySpawner.enemy_level
	xp = enemy_class.xp
	
	# Init health component and its max_health stat
	hc = HealthComponent.new()
	
	hc.max_health = Stat.new()
	hc.max_health.set_base(enemy_class.max_health * randf_range(1.0, 2.0)) # FIXME
	hc.max_health.set_type(true)
	# Increase max health according to level
	hc.max_health.append_mult_mod(EnemySpawner.enemy_health_mult)
	hc.died.connect(die)
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
			detect_player()
		detection_check_timer = DETECTION_INTERVAL * _get_randomness()
	if detection_duration_timer <= 0:
		player_detected = false

func detect_player():
	if not player_detected:
		detection_duration_timer = DETECTION_DURATION * _get_randomness()
		player_detected = true

func tick_timers(delta : float):
	if detection_check_timer > 0: 
		detection_check_timer -= delta 
	if detection_duration_timer > 0: 
		detection_duration_timer -= delta 
	if regenerate_path_timer > 0: 
		regenerate_path_timer -= delta
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	if stunned_timer > 0:
		stunned_timer -= delta

func _get_randomness():
	return randf_range(0.75, 1.25)

func _get_rand_sign():
	return int(randf() >= 0.5) * 2 - 1


func act_on_state(delta : float):
	match state:
		State.IDLE:
			do_custom_idle_movement(delta)
			tick_timers(delta)
			check_player_detection()
			if player_detected:
				state = State.CHASING
		State.CHASING:
			tick_timers(delta)
			if stunned_timer > 0:
				state = State.STUNNED
				return
			check_player_detection()
			if player_detected:
				# Check if has a path; if not, try to get one (on an interval)
				if not currentPath and not currentTarget and regenerate_path_timer <= 0:
					find_path(player.global_position)
				# If path: 
				if currentPath or currentTarget:
					# Regenerate if player is ENDPOINT_DISTANCE_THRESHOLD away from original endpoint
					if regenerate_path_timer <= 0 and \
							original_endpoint.distance_to(player.global_position) > endpoint_distance_threshold_randomized:
						find_path(player.global_position)
						endpoint_distance_threshold_randomized = ENDPOINT_DISTANCE_THRESHOLD * _get_randomness()
					# Move actual endpoint to player position (TODO)
				if not attack_cooldown_timer > 0 and \
						is_on_floor() and \
						player.global_position.distance_to(global_position) < get_attack_range():
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
			tick_timers(delta)
		State.STUNNED:
			tick_timers(delta)
			if stunned_timer <= 0:
				modulate = Color.WHITE
				state = State.CHASING
	debug_label.text = get_state_string()

func attack():
	# Change state to ATTACKING
	state = State.ATTACKING
	# Determine attack direction
	attack_area.scale.x = 1 if player.global_position.x >= global_position.x else -1
	# Stand still while attacking
	movement_dir = Vector2.ZERO
	var cooldown = get_attack_cooldown()
	attack_cooldown_timer = cooldown
	# Do the actual attack using a tween
	var attack_tween := create_tween()
	do_custom_attack(attack_tween)
	# Begin CHASING once done
	attack_tween.tween_property(self, "state", State.CHASING, 0.0)

func receive_stun(duration : float):
	movement_dir = Vector2.ZERO
	velocity = Vector2.ZERO
	state = State.STUNNED
	stunned_timer = duration
	modulate = Color.WHITE * 5
	# (Re-)detect the player, so as to path to them when unstunned 
	detect_player()

## Assumes that knockback direction is directly away from the player. 
func receive_knockback(knockback_str : float, direction := Vector2.INF):
	if direction == Vector2.INF:
		direction = player.position.direction_to(position)
	# Check for perfect overlap
	if direction == Vector2.ZERO: 
		direction = Vector2.RIGHT
	add_impulse(knockback_str * direction)



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

func deal_damage(damage : int):
	player.take_damage(damage)

func do_custom_idle_movement(delta : float):
	movement_dir = Vector2.ZERO

func player_in_los():
	var result = Pathfinding.do_raycast(global_position, player.global_position)
	return result != Vector2.INF

func get_state_string():
	match state:
		State.IDLE:
			return ""
			return "IDLE" + (("TARGET = " + str(currentTarget) + ", DISTANCE = " + str(currentTarget.distance_to(position)).pad_decimals(1)) if currentTarget else "")
		State.CHASING:
			return ""
			return (" FOR " + str(stunned_timer).pad_decimals(1))
			return "CHASING" + ((": PATH LEN " + str(len(currentPath))) if currentPath else "") + ((", DETECTED FOR " + str(detection_duration_timer).pad_decimals(1)) if detection_duration_timer > 0 else ", NOT DETECTED")
		State.STUNNED:
			return "STUNNED" # + ((" FOR " + str(stunned_timer).pad_decimals(1)))
		State.ATTACKING:
			return ""
			return "ATTACKING"

#func _draw():
	#draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.5))
	#draw_circle(Vector2.ZERO, PLAYER_DETECTION_RADIUS, Color(Color.CRIMSON, 0.4), false, 1.0)
	

#endregion Player detection methods

#region Repulsion methods
func calculate_repulsion_force():
	var other_enemies = touching_enemies
	other_enemies.erase(self)
	var cumulative_repulsion := Vector2.ZERO
	const STR = 10000
	for other : Enemy in other_enemies:
		var dx = position.x - other.position.x
		if dx == 0: dx = randf()
		var dy = position.y - other.position.y
		var dist_sqrd = position.distance_squared_to(other.position)
		var dist = sqrt(dist_sqrd)
		if dist > 16: continue
		
		const MIN_DIST = 4
		if dist < MIN_DIST:
			dist = MIN_DIST
			dist_sqrd = MIN_DIST * MIN_DIST
		var force_magnitude = STR / dist_sqrd
		cumulative_repulsion += Vector2(
			dx / dist * force_magnitude,
			dy / dist * force_magnitude
		)
	return cumulative_repulsion
		

func _on_hurtbox_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Enemy:
		touching_enemies.append(parent)

func _on_hurtbox_area_exited(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Enemy:
		touching_enemies.erase(parent)


#endregion Repulsion methods

#region Physics methods
## Should be called on physics ticks, not as a one-off (that would be an impulse)
func add_force(force : Vector2):
	forces += force

func add_impulse(impulse : Vector2):
	impulses += impulse

func _flush_forces_and_impulses(delta : float):
	velocity += forces * delta
	forces = Vector2.ZERO
	velocity += impulses 
	impulses = Vector2.ZERO

#endregion Physics methods

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
	
	_flush_forces_and_impulses(delta)
	
	
	# From mouse position, raycast down and tell the enemy to go to hit position
	if Input.is_action_just_pressed("test_navigation"):
		var mouse_pos = get_global_mouse_position()
		var target_pos = Pathfinding.do_raycast(mouse_pos, Vector2(mouse_pos.x, mouse_pos.y + 1000))
		if target_pos != Vector2.INF:
			find_path(target_pos)
	
	# Move horizontally.
	var speed = movement_speed.value()
	var direction : Vector2 = movement_dir * speed
	var accel_mod = 1.0 if is_on_floor() else AIR_ACCEL_MOD # Slows acceleration in air 
	if state == State.STUNNED:
		accel_mod *= STUNNED_ACCEL_MOD
	var accel_speed = speed * BASE_MOVEMENT_ACCEL * accel_mod
	
	# Move platforming velocity x in input direction
	velocity.x = move_toward(velocity.x, direction.x, accel_speed * delta)
	#var repulsion_force : Vector2 = calculate_repulsion_force()
	#var repulsion_force : Vector2 = Vector2.ZERO
	#velocity.x += repulsion_force.x * delta
	# Gravity
	if !is_on_floor():
		velocity.y += gravity.value() * delta

	
	move_and_slide() 
	# Populate `touching_enemies` for repulsion
	#touching_enemies.clear()
	#for i in get_slide_collision_count():
		#if i > 1:
			#print("pog")
		#var collision = get_slide_collision(i)
		#var collider = collision.get_collider()
		#if not collider is TileMapLayer:
			#touching_enemies.append(collider)

func _check_floor_landing():
	if is_on_floor() and not on_floor: # Just landed
		if jump_once_on_floor:
			nextPoint()
	on_floor = is_on_floor()

func find_path(target_pos : Vector2):
	regenerate_path_timer = REGENERATE_INTERVAL * _get_randomness()
	#await get_tree().create_timer(randf() * 0.2).timeout # Try to ensure enemies find paths on different ticks
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

#region Level-up and XP methods


#endregion Level-up and XP methods

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
func take_damage(damage : float, damage_color : DamageNumber.DamageColor = DamageNumber.DamageColor.DEFAULT):
	var damage_taken = hc.take_damage(damage)
	# Detect player and start chasing if idle
	detect_player()
	if state == State.IDLE:
		state = State.CHASING

	if damage_taken > 0:
		DamageNumbers.create_damage_number(damage_taken, global_position + Vector2.UP * 16, damage_color)

func die():
	XP.spawn_xp(xp, position)
	# TODO refine
	Global.player.receive_tokens(1)
	queue_free()

func _on_attack_area_area_entered(area: Area2D) -> void:
	var hit_player = area.get_parent()
	if hit_player is Player:
		hit_player.take_damage(get_attack_damage())

func update_health_bar():
	health_bar.max_value = hc.max_health.value()
	health_bar.value = hc.health
	if health_bar.value == health_bar.max_value:
		health_bar.hide()
	else:
		health_bar.show()


#endregion Damage interaction methods
