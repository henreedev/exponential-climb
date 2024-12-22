extends CharacterBody2D

# Contains gameplay information for combat, as well as a perk build and a weapon. 
class_name Player

signal jumped

enum ClassType {LEAD, BRUTE, ANGEL}

@export var class_type : ClassType

## Dict from class type to the PlayerClass resource storing information on that class.
const CLASSES_DICT : Dictionary[ClassType, PlayerClass] = {
	ClassType.LEAD : preload("res://scripts/player/classes/class_lead.tres"),
	ClassType.BRUTE : preload("res://scripts/player/classes/class_brute.tres"),
	ClassType.ANGEL : preload("res://scripts/player/classes/class_angel.tres"),
}


var passive_perk_build : PerkBuild
var active_perk_build : PerkBuild
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
const DEFAULT_GRAVITY := 980.0
const DEFAULT_MOVEMENT_SPEED := 300.0
const DEFAULT_ACCELERATION_MOD := 6.0
const DEFAULT_JUMP_STRENGTH := 725.0
## Maximum speed at which the player can fall.
const TERMINAL_VELOCITY := 700.0
#endregion Physics variables

func _ready() -> void:
	Global.add_player(self)
	_initialize_perk_builds()
	_initialize_player_class()

func _process(delta: float) -> void:
	# FIXME testing
	print(movement_speed.get_final_value())

func _initialize_perk_builds():
	passive_perk_build = PerkBuild.new()
	passive_perk_build.is_active = false
	active_perk_build = PerkBuild.new()
	active_perk_build.is_active = true
	# FIXME adding perks manually for testing
	active_perk_build.place_perk(Perk.init_perk(Perk.Type.SPEED_BOOST, self), 0)
	active_perk_build.place_perk(Perk.init_perk(Perk.Type.SPEED_BOOST_ON_JUMP, self), 1)

func _initialize_player_class():
	weapon = Weapon.new()
	movement_speed = Stat.new()
	jump_strength = Stat.new()
	max_health = Stat.new()
	gravity = Stat.new()
	
	_load_player_class_values()

func _load_player_class_values():
	var player_class : PlayerClass = CLASSES_DICT[class_type]
	
	weapon.set_type_by_player_class(class_type)
	
	max_health.set_type(true)
	
	max_health.set_base(player_class.max_health)
	jump_strength.set_base(player_class.jump_strength)
	movement_speed.set_base(player_class.movement_speed)
	gravity.set_base(player_class.gravity)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		try_jump()
	elif Input.is_action_just_released("jump") and velocity.y < 0.0:
		# The player let go of jump early, reduce vertical momentum.
		velocity.y *= 0.6
	# Fall.
	var grav = gravity.get_final_value()
	velocity.y = minf(TERMINAL_VELOCITY, velocity.y + grav * delta)

	var speed = movement_speed.get_final_value()
	var direction : float = Input.get_axis("move_left", "move_right") * speed
	var accel_speed = speed * DEFAULT_ACCELERATION_MOD
	velocity.x = move_toward(velocity.x, direction, accel_speed * delta)

	move_and_slide()

func try_jump() -> void:
	if is_on_floor():
		velocity.y = -jump_strength.get_final_value()
		jumped.emit()
