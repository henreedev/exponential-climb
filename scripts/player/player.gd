extends CharacterBody2D

# Contains gameplay information for combat, as well as a perk build and a weapon. 
class_name Player

signal jumped

enum ClassType {LEAD, BRUTE, ANGEL}

@export var class_type : ClassType

## Dict from class type to the PlayerClass resource storing information on that class.
const CLASSES_DICT : Dictionary[ClassType, PlayerClass] = {
	ClassType.LEAD : preload("res://resources/classes/class_lead.tres"),
	ClassType.BRUTE : preload("res://resources/classes/class_brute.tres"),
	ClassType.ANGEL : preload("res://resources/classes/class_angel.tres"),
}

var build_container : BuildContainer
var weapon : Weapon

var gravity : Stat
var movement_speed : Stat
var jump_strength : Stat
const DEFAULT_MAX_HEALTH := 100
var max_health : Stat
var health : float
var tokens : int

var index : int 

#region Physics variables
const DEFAULT_GRAVITY := 750.0
const DEFAULT_MOVEMENT_SPEED := 150.0
const DEFAULT_ACCELERATION_MOD := 12.0
const DEFAULT_JUMP_STRENGTH := 300.0
## Maximum speed at which the player can fall.
const TERMINAL_VELOCITY := 700.0
## Flushed each physics tick, multiplied by delta time.
var forces : Vector2
## Flushed each physics tick.
var impulses : Vector2
## Indicates the proportion of ability physics to use in the velocity calculation (0.0 to 1.0)
var physics_ratio := 0.0
var physics_ratio_decrease := 0.0

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

## Applies friction as a percentage per second (given a percentage as a decimal),
## typically for damping of physics velocity along the ground.
func apply_friction(delta : float, amount : float):
	physics_velocity -= physics_velocity * amount * delta


func _flush_forces_and_impulses(delta : float):
	physics_velocity += forces * delta
	forces = Vector2.ZERO
	physics_velocity += impulses 
	impulses = Vector2.ZERO

#endregion Reimplementing basic physics

func _physics_process(delta: float) -> void:
	# Calculate physics velocity
	physics_velocity = velocity
	_flush_forces_and_impulses(delta)
	
	# Calculate platforming velocity 
	platforming_velocity = velocity
	
	if Input.is_action_just_pressed("jump"):
		try_jump()
	elif Input.is_action_just_released("jump") and platforming_velocity.y < 0.0:
		# The player let go of jump early, reduce vertical momentum.
		platforming_velocity.y *= 0.6
		physics_velocity *= 0.6
	# Fall.
	#var grav = gravity.get_final_value()
	var grav = DEFAULT_GRAVITY
	platforming_velocity.y = minf(TERMINAL_VELOCITY, platforming_velocity.y + grav * delta)
	physics_velocity.y = minf(TERMINAL_VELOCITY, physics_velocity.y + 0.65 * grav * delta)

	#var speed = movement_speed.get_final_value()
	var speed = DEFAULT_MOVEMENT_SPEED
	var direction : float = Input.get_axis("move_left", "move_right") * speed
	var accel_mod = 1.0 if is_on_floor() else 0.5 # Slows acceleration in air 
	var accel_speed = speed * DEFAULT_ACCELERATION_MOD * accel_mod
	platforming_velocity.x = move_toward(platforming_velocity.x, direction, accel_speed * delta)
	# If the physics velocity x would decrease, do it\
	var phys_vel_after_mvmnt = move_toward(physics_velocity.x, direction, accel_speed * delta)
	if direction and not (are_same_sign(physics_velocity.x, direction) and abs(phys_vel_after_mvmnt) < abs(physics_velocity.x)):
		physics_velocity.x = phys_vel_after_mvmnt
	
	_reduce_physics_ratio_on_floor(delta)
	
	# Mix both velocities depending on ratio
	velocity = lerp(platforming_velocity, physics_velocity, physics_ratio)

	move_and_slide()

func are_same_sign(a: float, b: float) -> bool:
	return a * b > 0


func try_jump() -> void:
	if is_on_floor():
		#var jump_str = jump_strength.get_final_value()
		var jump_str = DEFAULT_JUMP_STRENGTH
		platforming_velocity.y = -jump_str
		physics_velocity.y -= jump_str
		jumped.emit()

func set_physics_ratio(proportion : float):
	physics_ratio = proportion
	
func set_physics_ratio_decrease(decrease : float):
	physics_ratio_decrease = decrease

func _reduce_physics_ratio_on_floor(delta : float):
	if is_on_floor():
		physics_ratio = maxf(0, physics_ratio - physics_ratio_decrease * delta)
		if physics_ratio == 0.0:
			physics_ratio_decrease = 0.0
#endregion Movement
