extends CharacterBody2D

## Contains gameplay information for combat, as well as perk builds and a weapon. 
class_name Player

#region Signals
signal jumped
signal double_jumped

## Used by weapons (e.g. boots) to override jump behaviors, in combination with `skip_next_jump`.
signal trying_jump
signal trying_double_jump

## Used by boots to slam on jump release.
signal released_jump
signal released_double_jump

## Used by weapons to deal damage on landing.
signal landed_on_floor

## Emits when an attack successfully fires, not when on cooldown.
signal attacked

## Emits when xp value changes.
signal xp_changed
#endregion Signals

enum ClassType {LEAD, BRUTE, ANGEL}

## Dict from class type to the PlayerClass resource storing information on that class.
const CLASSES_DICT : Dictionary[ClassType, PlayerClass] = {
	ClassType.LEAD : preload("res://resources/player_classes/class_lead.tres"),
	ClassType.BRUTE : preload("res://resources/player_classes/class_brute.tres"),
	ClassType.ANGEL : preload("res://resources/player_classes/class_angel.tres"),
}

@export var class_type : ClassType
var build_container : BuildContainer
var weapon : Weapon

#region Player stats
var gravity : Stat
var movement_speed : Stat
var movement_accel : Stat

#region Jumps
const DEFAULT_DOUBLE_JUMPS := 1
var jump_strength : Stat
var double_jumps : Stat
var double_jumps_left : int

## Set true when a weapon wants to apply its own jump behavior. 
var skip_next_jump : bool = false
#endregion Jumps

#region Health
const DEFAULT_MAX_HEALTH := 100
var hc : HealthComponent
const DEFAULT_HEALTH_REGEN := 1.0
var health_regen : Stat
#endregion Health

#region XP and Levels
## Used to level up.
var xp : int
const BASE_XP_TO_NEXT_LEVEL := 10
var xp_to_next_level := BASE_XP_TO_NEXT_LEVEL
var level := 1
var level_base_damage_mult := 1.00
var level_base_damage_mod : Mod
var level_health_mult := 1.00
var level_health_mod : Mod
#endregion XP and Levels

#region Weapon-related stats
const DEFAULT_BASE_DAMAGE := 10.0
var base_damage : Stat ## Float defaulting to 10
var area : Stat ## Float modifier defaulting to 1.00
var attack_speed : Stat ## Float modifier defaulting to 1.00
var range : Stat ## Float modifier defaulting to 1.00
#endregion Weapon-related stats

#endregion Player stats

#region Currency
## Used to unlock chests and reroll perks.
var tokens : int
## Used to unlock a new build slot.
var boss_tokens : int
#endregion Currency


#region Physics variables
const DEFAULT_MOVEMENT_SPEED := 150.0
const DEFAULT_ACCELERATION_MOD := 18.0
const DEFAULT_JUMP_STRENGTH := 350.0
## If velocity's y value is within this distance to 0, gravity is reduced. 
## Gives a floatier top arc of jumps.
const HALF_GRAV_Y_SPEED := 15.0
const HALF_GRAV_MOD := 0.4

## Horizontal accel is multiplied by this while airborne. 
const AIR_ACCEL_MOD := 0.5

## If velocity surpasses this speed limit, this amount of drag as %/second is applied.
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
## Decrease per second, occurs only when on the ground.
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

#region Animation
@onready var sprite : Sprite2D = $Sprite2D
#endregion Animation

#region Camera
@onready var camera: Camera2D = %Camera2D
## The camera can look ahead of the movement direction when the player's moving quickly. 
var look_ahead_enabled := true
## These are the bounds of the look-ahead.
const CAMERA_LOOK_AHEAD_BOUNDS = Vector2(100, 100)
## The camera offset that the camera smoothly moves towards.
var target_offset : Vector2

## Bounds of the camera, used to keep offset within camera limits.
const CAMERA_WIDTH = 768
const HALF_CAMERA_WIDTH = 768 / 2
const CAMERA_HEIGHT = 432
const HALF_CAMERA_HEIGHT = 432 / 2
#endregion Camera

func _ready() -> void:
	Global.player = self # Give everything a reference to the player
	
	_initialize_build_container()
			 
	_initialize_player_class()
	
	pick_weapon(Weapon.Type.GRAPPLE_HOOK)

func _process(delta : float) -> void:
	if look_ahead_enabled:
		_calculate_target_offset(delta)
		_move_towards_target_offset(delta)
	else:
		camera.offset = Vector2.ZERO
	if Input.is_action_just_pressed("test_teleport"):
		position += get_local_mouse_position()
	elif Input.is_action_just_pressed("test_kill_all_enemies"):
		for enemy : Enemy in get_tree().get_nodes_in_group("enemy"):
			enemy.die()
	elif Input.is_action_just_pressed("teleport_enemy"):
		# Spawn more enemies
		for _i in range(10):
			EnemySpawner.spawn_enemy(Enemy.Class.BASIC_MELEE, get_global_mouse_position())
		# Teleport enemy to mouse position
		for enemy : Enemy in get_tree().get_nodes_in_group("enemy"):
			enemy.global_position = get_global_mouse_position()
	_process_level_ups(delta)

#region Perks 


func _initialize_build_container():
	build_container = BuildContainer.new()


func add_build(build : PerkBuild):
	assert(build)
	if build.is_active:
		build_container.add_active_build(build)
	else:
		build_container.add_passive_build(build)


#endregion Perks
 
#region Weapon
func pick_weapon(type : Weapon.Type):
	weapon = Weapon.init_weapon(type)
	add_child(weapon)
#endregion Weapon

#region Combat
## Deals damage to the player's health component and displays visuals
func take_damage(damage : float):
	hc.take_damage(damage)
	
	DamageNumbers.create_damage_number(damage, global_position + Vector2.UP * 16, DamageNumber.DamageColor.ENEMY)

func die():
	hc.revive()

#endregion Combat

#region Classes 
func _initialize_player_class():
	# Init weapon
	weapon = Weapon.new() # TODO
	# Init stats
	movement_speed = Stat.new()
	movement_speed.set_base(DEFAULT_MOVEMENT_SPEED)
	
	movement_accel = Stat.new()
	movement_accel.set_base(DEFAULT_ACCELERATION_MOD)
	
	jump_strength = Stat.new()
	jump_strength.set_base(DEFAULT_JUMP_STRENGTH)
	
	gravity = Stat.new()
	gravity.set_base(Global.GRAVITY)
	
	health_regen = Stat.new()
	health_regen.set_base(DEFAULT_HEALTH_REGEN)
	
	double_jumps = Stat.new()
	double_jumps.set_base(DEFAULT_DOUBLE_JUMPS)
	double_jumps.set_type(true)
	
	area = Stat.new()
	area.set_base(1.0)
	
	range = Stat.new()
	range.set_base(1.0)
	
	attack_speed = Stat.new()
	attack_speed.set_base(1.0)
	
	base_damage = Stat.new()
	base_damage.set_base(DEFAULT_BASE_DAMAGE)
	base_damage.set_type(true)
	
	# Init health component and its max_health stat
	hc = HealthComponent.new()
	
	hc.max_health = Stat.new()
	hc.max_health.set_base(DEFAULT_MAX_HEALTH)
	hc.max_health.set_type(true)
	hc.died.connect(die)
	
	# Load in the actual values into the stats based on the class
	_load_player_class_values()

func _load_player_class_values():
	# Lookup the class resource file by type 
	var player_class : PlayerClass = CLASSES_DICT[class_type]
	
	# Set health
	hc.max_health.append_mult_mod(player_class.max_health_mod)
	hc.set_health_to_full()
	
	# Add mods to base stats
	movement_speed.append_mult_mod(player_class.movement_speed_mod)
	jump_strength.append_mult_mod(player_class.jump_strength_mod)
	health_regen.append_mult_mod(player_class.health_regen_mod)
	
	base_damage.append_mult_mod(player_class.base_damage_mod)
	area.append_mult_mod(player_class.area_mod)
	attack_speed.append_mult_mod(player_class.attack_speed_mod)
	range.append_mult_mod(player_class.range_mod)
	
	double_jumps.append_add_mod(player_class.double_jumps_mod) # Additive
#endregion Classes 

#region XP and Levels
func receive_xp(amount : int):
	xp += amount
	xp_changed.emit()

## Can level down when supplying -1.
func level_up(direction := 1):
	level += direction
	xp -= xp_to_next_level
	print("Player levelled up to ", level)
	level_base_damage_mult = calculate_level_base_damage_mult(level)
	apply_level_base_damage_mult()
	level_health_mult = calculate_base_health_mult(level)
	apply_level_health_mult()
	xp_to_next_level = calculate_xp_to_next_level(level)
	xp_changed.emit()


func _process_level_ups(delta : float):
	if xp >= xp_to_next_level:
		level_up()

func regen_health(delta : float):
	hc.receive_healing(delta * health_regen.value())

func calculate_xp_to_next_level(level : int):
	return pow(1.05, level) * BASE_XP_TO_NEXT_LEVEL

func calculate_base_health_mult(level : int):
	return pow(1.05, level - 1)

func calculate_level_base_damage_mult(level : int):
	return pow(1.025, level - 1)
	
func apply_level_base_damage_mult():
	base_damage.remove_mod(level_base_damage_mod)
	level_base_damage_mod = base_damage.append_mult_mod(level_base_damage_mult)

func apply_level_health_mult():
	hc.max_health.remove_mod(level_health_mod)
	level_health_mod = hc.max_health.append_mult_mod(level_health_mult)

#endregion XP and Levels

#region Builds
func add_new_build():
	assert(false)
	var active_build = PerkBuild.new()
	active_build.is_active = true
	var passive_build = PerkBuild.new()
	build_container.add_active_build(active_build)
	build_container.add_passive_build(passive_build)
#endregion Builds

#region Movement
#region Reimplementing basic physics
## Should be called on physics ticks, not as a one-off (that would be an impulse)
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
	platforming_velocity = new_vel
	
	frictions = Vector2.ZERO

func _flush_forces_and_impulses(delta : float):
	physics_velocity += forces * delta
	platforming_velocity += forces * delta
	forces = Vector2.ZERO
	physics_velocity += impulses 
	platforming_velocity += impulses 
	impulses = Vector2.ZERO
	apply_frictions(delta)

#endregion Reimplementing basic physics
func _physics_process(delta: float) -> void:
	# Ensure velocity does not grow while at a visible standstill
	if get_real_velocity().length_squared() < 0.005:
		velocity = get_real_velocity()

	# Calculate physics velocity
	physics_velocity = velocity
	
	# Calculate platforming velocity 
	platforming_velocity = velocity
	
	# Apply physics to both
	_flush_forces_and_impulses(delta)
	
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
	var grav = gravity.value()
	# Lower gravity near the top of jumps if holding jump button
	if Input.is_action_pressed("jump") and abs(velocity.y) < HALF_GRAV_Y_SPEED:
		grav *= HALF_GRAV_MOD
	platforming_velocity.y = minf(TERMINAL_VELOCITY, platforming_velocity.y + grav * delta)
	physics_velocity.y = minf(TERMINAL_VELOCITY, physics_velocity.y + grav * delta)
	# Move horizontally.
	var speed = movement_speed.value()
	var direction : float = Input.get_axis("move_left", "move_right") * speed
	var accel_mod = 1.0 if is_on_floor() else AIR_ACCEL_MOD # Slows acceleration in air 
	var accel_speed = speed * movement_accel.value() * accel_mod
	
	# Move platforming velocity x in input direction
	platforming_velocity.x = move_toward(platforming_velocity.x, direction, accel_speed * delta)
	
	# Move physics velocity x in input direction, but avoid slowing down in the direction of input
	var phys_vel_after_mvmnt = move_toward(physics_velocity.x, direction, accel_speed * delta)
	if direction and not (are_same_sign(physics_velocity.x, direction) \
				 and abs(phys_vel_after_mvmnt) < abs(physics_velocity.x)):
		physics_velocity.x = phys_vel_after_mvmnt
	
	# If touching the floor, reduce the ability physics ratio
	_reduce_physics_ratio_on_floor(delta)
	
	# Mix both velocities depending on ratio
	velocity = lerp(platforming_velocity, physics_velocity, physics_ratio)
	# Apply drag above speed limit
	#if velocity.length() > SPEED_LIMIT: velocity -= velocity * SPEED_LIMIT_DRAG * delta
	
	# Move and slide using `velocity`.
	move_and_slide()

func _check_floor_landing():
	if is_on_floor() and not on_floor: # Just landed
		double_jumps_left = double_jumps.value()
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
				if platforming_velocity.y < 0.0: 
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
	if is_on_floor() or (coyote_timer > 0 and double_jumps_left == double_jumps.value()):
		trying_jump.emit()
		jump_buffer = 0.0
		if not skip_next_jump:
			var jump_str = jump_strength.value()
			platforming_velocity.y = -jump_str
			physics_velocity.y -= jump_str
		has_released_jump = false
		jump_buffer = 0.0
		jumped.emit()
	elif double_jumps_left > 0:
		trying_double_jump.emit()
		if not skip_next_jump:
			var jump_str = jump_strength.value()
			const KEEP_RATIO = 0.2
			platforming_velocity.y = platforming_velocity.y * KEEP_RATIO - jump_str
			physics_velocity.y = physics_velocity.y * KEEP_RATIO - jump_str
		double_jumps_left -= 1
		has_double_jumped = true
		has_released_jump = false
		jump_buffer = 0.0
		double_jumped.emit()

## Adds a double jump, but not over the cap.
func add_double_jump():
	double_jumps_left = clampi(double_jumps_left + 1, 0, double_jumps.value())

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

#region Camera
func _move_towards_target_offset(delta : float):
	const LERP_STR = 2.0
	const LINEAR_STR = 50.0
	var offset = camera.offset
	if not target_offset.is_equal_approx(camera.offset): 
		offset = camera.offset
		var new_cam_pos = camera.get_screen_center_position()
		var new_cam_x_bounds = Vector2(new_cam_pos.x - HALF_CAMERA_WIDTH, new_cam_pos.x + HALF_CAMERA_WIDTH)
		var new_cam_y_bounds = Vector2(new_cam_pos.y - HALF_CAMERA_HEIGHT, new_cam_pos.y + HALF_CAMERA_HEIGHT)
		var limited_x_bounds = new_cam_x_bounds.clampf(camera.limit_left, camera.limit_right)
		var limited_y_bounds = new_cam_y_bounds.clampf(camera.limit_top, camera.limit_bottom)
		var x_bounds_diff = limited_x_bounds - new_cam_x_bounds
		var y_bounds_diff = limited_y_bounds - new_cam_y_bounds
		var x_adj = 0.0
		if x_bounds_diff.x != 0:
			x_adj = x_bounds_diff.x
		else:
			x_adj = x_bounds_diff.y
		var y_adj = 0.0
		if y_bounds_diff.x != 0:
			y_adj = y_bounds_diff.x
		else:
			y_adj = y_bounds_diff.y
			
		var diff = Vector2(x_adj, y_adj)
		camera.offset += diff
		#target_offset += diff
		camera.offset = 0.2 * camera.offset.move_toward(target_offset, delta * LINEAR_STR) + \
						0.8 * lerp(camera.offset, target_offset, delta * LERP_STR)

func _calculate_target_offset(delta : float):
	var x_speed = abs(velocity.x)
	var y_speed = abs(velocity.y)
	const VEL_WEIGHT = 3.0 # How much does velocity move camera?
	var x_vel_weight = clampf(lerpf(999, VEL_WEIGHT, x_speed / 400.0), 3, 999)
	var y_vel_weight = clampf(lerpf(999, VEL_WEIGHT, y_speed / 400.0), 3, 999)

	target_offset.x = lerp(target_offset.x, velocity.x / x_vel_weight, delta * 3.0)
	target_offset.y = lerp(target_offset.y, velocity.y / y_vel_weight, delta * 3.0)
	target_offset.x = clampf(target_offset.x, -CAMERA_LOOK_AHEAD_BOUNDS.x, CAMERA_LOOK_AHEAD_BOUNDS.x)
	target_offset.y = clampf(target_offset.y, -CAMERA_LOOK_AHEAD_BOUNDS.y, CAMERA_LOOK_AHEAD_BOUNDS.y)

#endregion Camera

#region Stat access
func get_range():
	return range.value()

func get_area():
	return area.value()

func get_base_damage():
	return base_damage.value()

func get_attack_speed():
	return attack_speed.value()


#endregion Stat access

#region Helpers
func are_same_sign(a: float, b: float) -> bool:
	return a * b > 0
#endregion Helpers
