extends CharacterBody2D

## Contains gameplay information for combat, as well as perk builds and a weapon. 
class_name Player

signal jumped
signal double_jumped

## Used by weapons (e.g. boots) to override jump behaviors, in combination with `skip_next_jump`.
signal trying_jump
signal trying_double_jump
signal released_jump
signal released_double_jump


signal landed_on_floor

## Works when an attack successfully fires, not when on cooldown.
signal attacked

enum ClassType {LEAD, BRUTE, ANGEL}


## Dict from class type to the PlayerClass resource storing information on that class.
const CLASSES_DICT : Dictionary[ClassType, PlayerClass] = {
	ClassType.LEAD : preload("res://resources/classes/class_lead.tres"),
	ClassType.BRUTE : preload("res://resources/classes/class_brute.tres"),
	ClassType.ANGEL : preload("res://resources/classes/class_angel.tres"),
}

@export var class_type : ClassType
var build_container : BuildContainer
var weapon : Weapon

#region Player stats
var gravity : Stat
var movement_speed : Stat
var movement_accel : Stat
## Jumps
var jump_strength : Stat
var double_jumps : Stat
var double_jumps_left : int
## Set true when a weapon wants to apply its own jump behavior. 
var skip_next_jump : bool = false
## Health
const DEFAULT_MAX_HEALTH := 100
var max_health : Stat
var health : float
#region Player stats
## Currency
var tokens : int

#region Physics variables
const DEFAULT_GRAVITY := 950.0
#const DEFAULT_GRAVITY := 0.0
const DEFAULT_MOVEMENT_SPEED := 150.0
const DEFAULT_ACCELERATION_MOD := 12.0
const DEFAULT_JUMP_STRENGTH := 350.0
const SPEED_LIMIT_DRAG := 1.0 # NOTE not currently in use
const SPEED_LIMIT := 450.0 # NOTE not currently in use
## The value to multiply y velocity by when cancelling a jump early.
const JUMP_CANCEL_MOD := 0.6
## Maximum speed at which the player can fall.
const TERMINAL_VELOCITY := 700.0
## Flushed each physics tick, multiplied by delta time.
var forces : Vector2
## Flushed each physics tick.
var impulses : Vector2
## Flushed each physics tick.
var frictions : Vector2
## Indicates the proportion of ability physics to use in the velocity calculation (0.0 to 1.0)
var physics_ratio := 0.0
## In seconds, occurs only when on the ground.
var physics_ratio_decrease := 0.0
## Whether the player's on the floor. Used to check for when the player lands on the ground.
var on_floor := false
## The amount of time after leaving a platform the player can still jump.
const COYOTE_TIME := 0.08
var coyote_timer := 0.0
## The amount of time before landing that a jump input will register upon landing.
const JUMP_BUFFER_DURATION := 0.2
var jump_buffer := 0.0
## True if the player has double jumped at least once.
var has_double_jumped := false
## Set false when a jump starts, true on release. 
var has_released_jump := false
## Separate from the velocity for typical platforming, so that physics-based 
## movement can coexist with typical platformer mechanics. 
var physics_velocity : Vector2
var platforming_velocity : Vector2
#endregion Physics variables

func _ready() -> void:
	Global.player = self
	Global.max_perks_updated.connect(add_new_build)
	_initialize_perk_builds()
	_initialize_player_class()
	pick_weapon(Weapon.Type.GRAPPLE_HOOK)
#region Perks 

func _initialize_perk_builds():
	build_container = BuildContainer.new()
	var passive_perk_build = PerkBuild.new()
	passive_perk_build.is_active = false
	build_container.add_passive_build(passive_perk_build)
	var active_perk_build = PerkBuild.new()
	active_perk_build.is_active = true
	build_container.add_active_build(active_perk_build)
	# FIXME adding perks manually for testing
	build_container.active_builds[0].place_perk(Perk.init_perk(Perk.Type.SPEED_BOOST), 0)
	build_container.active_builds[0].place_perk(Perk.init_perk(Perk.Type.SPEED_BOOST_ON_JUMP), 1)

#endregion Perks
 
#region Weapon
func pick_weapon(type : Weapon.Type):
	add_child(Weapon.init_weapon(type))
#endregion Weapon

#region Classes 

func _initialize_player_class():
	weapon = Weapon.new()
	movement_speed = Stat.new()
	movement_speed.set_base(DEFAULT_MOVEMENT_SPEED)
	jump_strength = Stat.new()
	jump_strength.set_base(DEFAULT_JUMP_STRENGTH)
	max_health = Stat.new()
	gravity = Stat.new()
	gravity.set_base(DEFAULT_GRAVITY)
	double_jumps = Stat.new()
	double_jumps.set_type(true)
	double_jumps.set_base(1)
	
	_load_player_class_values()

func _load_player_class_values():
	var player_class : PlayerClass = CLASSES_DICT[class_type]
	
	weapon.set_type_by_player_class(class_type)
	
	max_health.set_type(true)
	
	max_health.set_base(player_class.max_health)
	#jump_strength.set_base(player_class.jump_strength)
	#movement_speed.set_base(player_class.movement_speed)
	#gravity.set_base(player_class.gravity)

#endregion Classes 

#region Builds
func add_new_build():
	var active_build = PerkBuild.new()
	active_build.is_active = true
	var passive_build = PerkBuild.new()
	build_container.add_active_build(active_build)
	build_container.add_passive_build(passive_build)
#endregion Builds


#region Movement
#region Reimplementing basic physics
## Should be called on physics ticks.
func add_force(force : Vector2):
	forces += force

func add_impulse(impulse : Vector2):
	impulses += impulse

## Adds friction for the next physics tick of the given percentage.
func add_friction(friction : float):
	frictions += Vector2(friction, friction)

## Adds friction for the next physics tick of the given percentage.
func add_hoz_friction(friction : float):
	frictions += Vector2(friction, 0)

## Adds friction for the next physics tick of the given percentage.
func add_vert_friction(friction : float):
	frictions += Vector2(0, friction)

## Applies friction as a percentage per second (given a percentage as a decimal),
## typically for damping of physics velocity along the ground.
func apply_frictions(delta : float):
	if frictions.x < 0 or frictions.y < 0:
		printerr("Negative friction encountered: ", frictions)
		
	var delta_vel = physics_velocity * frictions * delta
	var new_vel = physics_velocity - delta_vel
	
	if not are_same_sign(new_vel.x, physics_velocity.x):
		new_vel.x = 0
	if not are_same_sign(new_vel.y, physics_velocity.y):
		new_vel.y = 0
	
	physics_velocity = new_vel
	
	frictions = Vector2.ZERO

func _flush_forces_and_impulses(delta : float):
	physics_velocity += forces * delta
	forces = Vector2.ZERO
	physics_velocity += impulses 
	impulses = Vector2.ZERO
	apply_frictions(delta)

#endregion Reimplementing basic physics

func _physics_process(delta: float) -> void:
	#print("Physics vel: ",  Vector2i(physics_velocity))
	#print("Platfor vel: ",  Vector2i(platforming_velocity))
	# Calculate physics velocity
	physics_velocity = velocity
	_flush_forces_and_impulses(delta)
	# Calculate platforming velocity 
	platforming_velocity = velocity
	# Land on the ground.
	_check_floor_landing()
	# Jump.
	if Input.is_action_just_pressed("jump"):
		jump_buffer = JUMP_BUFFER_DURATION
	if jump_buffer > 0:
		try_jump()
	_check_jump_releases()
	_process_jump_timers(delta)
	
	# Fall.
	var grav = gravity.get_final_value()
	#var grav = DEFAULT_GRAVITY
	platforming_velocity.y = minf(TERMINAL_VELOCITY, platforming_velocity.y + grav * delta)
	#physics_velocity.y = minf(TERMINAL_VELOCITY * 2, physics_velocity.y + 0.65 * grav * delta)
	physics_velocity.y = physics_velocity.y + 0.65 * grav * delta
	var speed = movement_speed.get_final_value()
	#var speed = DEFAULT_MOVEMENT_SPEED
	var direction : float = Input.get_axis("move_left", "move_right") * speed
	var accel_mod = 1.0 if is_on_floor() else 0.5 # Slows acceleration in air 
	var accel_speed = speed * DEFAULT_ACCELERATION_MOD * accel_mod
	platforming_velocity.x = move_toward(platforming_velocity.x, direction, accel_speed * delta)
	# Move in input direction, ignoring the case where movement is already enough in that direction
	var phys_vel_after_mvmnt = move_toward(physics_velocity.x, direction, accel_speed * delta)
	if direction and not (are_same_sign(physics_velocity.x, direction) and abs(phys_vel_after_mvmnt) < abs(physics_velocity.x)):
		physics_velocity.x = phys_vel_after_mvmnt
	
	_reduce_physics_ratio_on_floor(delta)
	
	# Mix both velocities depending on ratio
	velocity = lerp(platforming_velocity, physics_velocity, physics_ratio)
	# Apply drag above speed limit
	#if velocity.length() > SPEED_LIMIT: velocity -= velocity * SPEED_LIMIT_DRAG * delta
	move_and_slide()

func _check_floor_landing():
	if is_on_floor() and not on_floor: # Just landed
		double_jumps_left = double_jumps.get_final_value()
		has_double_jumped = false
		landed_on_floor.emit()
	elif not is_on_floor() and on_floor: # Just left floor
		coyote_timer = COYOTE_TIME
	on_floor = is_on_floor()
	

func _process_jump_timers(delta : float):
	coyote_timer -= delta
	jump_buffer -= delta

func _check_jump_releases():
	if not is_on_floor() and not has_released_jump:
		if Input.is_action_just_released("jump"):
				if platforming_velocity.y > 0.0: 
					platforming_velocity.y *= JUMP_CANCEL_MOD
				has_released_jump = true
				# Emit release signals
				if has_double_jumped:
						released_double_jump.emit()
				else:
						released_jump.emit()

func try_jump() -> void:
	# Will be set true by a weapon with its own jump logic when trying a jump
	skip_next_jump = false
	if is_on_floor() or coyote_timer > 0:
		trying_jump.emit()
		jump_buffer = 0.0
		if not skip_next_jump:
			#var jump_str = jump_strength.get_final_value()
			var jump_str = DEFAULT_JUMP_STRENGTH
			platforming_velocity.y = -jump_str
			physics_velocity.y -= jump_str
		has_released_jump = false
		jump_buffer = 0.0
		jumped.emit()
	elif double_jumps_left > 0:
		trying_double_jump.emit()
		if not skip_next_jump:
			var jump_str = DEFAULT_JUMP_STRENGTH
			const KEEP_RATIO = 0.2
			platforming_velocity.y = platforming_velocity.y * KEEP_RATIO - jump_str
			physics_velocity.y = physics_velocity.y * KEEP_RATIO - jump_str
		double_jumps_left -= 1
		has_double_jumped = true
		has_released_jump = false
		jump_buffer = 0.0
		double_jumped.emit()

func set_physics_ratio(proportion : float):
	physics_ratio = proportion
	
func set_physics_ratio_decrease(decrease : float):
	physics_ratio_decrease = decrease

func start_ability_physics():
	set_physics_ratio(1.0)
	set_physics_ratio_decrease(0.0)

func end_ability_physics():
	set_physics_ratio_decrease(1.0)

func _reduce_physics_ratio_on_floor(delta : float):
	if is_on_floor():
		physics_ratio = maxf(0, physics_ratio - physics_ratio_decrease * delta)
		if physics_ratio == 0.0:
			set_physics_ratio_decrease(0.0)
#endregion Movement

#region Helpers
func are_same_sign(a: float, b: float) -> bool:
	return a * b > 0
#endregion Helpers
