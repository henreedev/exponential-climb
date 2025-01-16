extends CharacterBody2D

## The base class for all enemies. 
class_name Enemy

enum Class {
	BASIC_MELEE, ## e.g. Lemurian from RoR1 
}

## Dict from class type to the PlayerClass resource storing information on that class.
const CLASSES_DICT : Dictionary[Class, EnemyClass] = {
	Class.BASIC_MELEE : preload("res://resources/enemy_classes/class_basic_melee.tres"),
}


## The type of this enemy.
var _class : Class

## Determines overall strength, factoring into damage on hit.
var base_damage : Stat 

#region Health
const DEFAULT_MAX_HEALTH := 100
var hc : HealthComponent
#endregion Health

## The range at which the enemy will attempt to attack the player.
var range : Stat

## The duration the enemy must wait between attacks.
var attack_cooldown : float

## Duration between starting an attack and it actually dealing damage (aka windup).
var attack_delay : float

## Multiplier on the speed of attacks. Affects attack delay and cooldown
var attack_speed : Stat


#region Physics vars
var movement_speed : Stat
var jump_strength : Stat
var gravity : Stat

#endregion Physics vars

#region Pathfinding vars
var currentPath : Array # of Vector2 or null
var currentTarget # Vector2 or null

var padding = 1
var finishPadding = 5
#endregion Pathfinding vars

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.enemy = self
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
	
	base_damage = Stat.new()
	base_damage.set_base(enemy_class.base_damage)
	base_damage.set_type(true)
	
	attack_delay = enemy_class.attack_delay
	attack_cooldown = enemy_class.attack_cooldown
	
	attack_speed = Stat.new()
	attack_speed.set_base(1.0)
	
	# Init health component and its max_health stat
	hc = HealthComponent.new()
	
	hc.max_health = Stat.new()
	hc.max_health.set_type(true)
	
	hc.set_health_to_full()

#endregion Classes 


#region Pathfinding methods
func nextPoint():
	if len(currentPath) == 0:
		currentTarget = null
		return
	
	currentTarget = currentPath.pop_front()
	
	# Jump action
	if currentTarget == null:
		jump()
		nextPoint()

func jump():
	if is_on_floor():
		velocity.y = -jump_strength.value()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	# From mouse position, raycast down and tell the enemy to go to hit position
	if Input.is_action_just_pressed("test_navigation"):
		var mouse_pos = get_global_mouse_position()
		var target_pos = Pathfinding.do_raycast(mouse_pos, Vector2(mouse_pos.x, mouse_pos.y + 1000))
		if target_pos != Vector2.INF:
			currentPath = Pathfinding.find_path(position, target_pos)
			nextPoint()
	# Teleport enemy to mouse position
	if Input.is_action_just_pressed("teleport_enemy"):
		global_position = get_global_mouse_position()
	
	# Pathfinding movement
	path_towards_target()
	
	if !is_on_floor():
		velocity.y += gravity.value() * delta

	
	move_and_slide()


func path_towards_target():
	var speed = movement_speed.value()
	if currentTarget:
		if (currentTarget.x - padding > position.x): 
			velocity.x = speed
		elif (currentTarget.x + padding < position.x): 
			velocity.x = -speed
		else:
			velocity.x = 0
			
		if position.distance_to(currentTarget) < finishPadding and is_on_floor():
			nextPoint()
	else:
		velocity.x = 0
#endregion Pathfinding methods

#region Stat calculation methods

func get_attack_cooldown():
	return attack_cooldown / attack_speed.value()

func get_attack_delay():
	return attack_delay / attack_speed.value()

func get_attack_damage():
	return base_damage.value()

#endregion Stat calculation methods
