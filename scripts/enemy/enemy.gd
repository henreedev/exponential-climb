extends CharacterBody2D

## The base class for all enemies. 
class_name Enemy

enum Type {
	BASIC_MELEE, ## e.g. Lemurian from RoR1 
}

## Jump height in tiles.
var jump_height : Stat

## Horizontal gap that can be crossed with a jump.
var jump_distance : Stat

## The type of this enemy.
var type : Type

## Determines overall strength, factoring into damage on hit.
var power : Stat

## The current health of this enemy.
var health : float

## The range at which the enemy will attempt to attack the player.
var attack_range : Stat

## The duration the enemy must wait between attacks.
var attack_cooldown : Stat

## Multiplier on the speed of attacks.
var attack_speed : Stat

#region Pathfinding
var currentPath
var currentTarget

var speed = 100
const jumpForce = 350
var gravity = 550
var padding = 1
var finishPadding = 5

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.enemy = self
	velocity = Vector2(0, 0)

func nextPoint():
	if len(currentPath) == 0:
		currentTarget = null
		return
	
	currentTarget = currentPath.pop_front()
#	print(currentTarget)
	
	if !currentTarget:
		jump()
		nextPoint()

func jump():
	if (self.is_on_floor()):
		velocity.y = -jumpForce
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	var space_state = get_world_2d().direct_space_state
	if Input.is_action_just_pressed("test_navigation"):
		var mousePos = get_global_mouse_position()
		# Collide with map downwards
		var ray_query = PhysicsRayQueryParameters2D.create(mousePos, Vector2(mousePos.x, mousePos.y + 1000), 4) 
		var result = space_state.intersect_ray(ray_query)
		if (result):
			var goTo = result["position"]
			currentPath = Pathfinding.find_path(position, goTo)
			nextPoint()
	if Input.is_action_just_pressed("teleport_enemy"):
		global_position = get_global_mouse_position()
	if currentTarget:
		if (currentTarget.x - padding > position.x): # and position.distance_to(currentTarget) > padding:
			velocity.x = speed
		elif (currentTarget.x + padding < position.x): # and position.distance_to(currentTarget) > padding:
			velocity.x = -speed
		else:
			velocity.x = 0
			
		if position.distance_to(currentTarget) < finishPadding and is_on_floor():
				nextPoint()
	else:
		velocity.x = 0
	
	if !is_on_floor():
		velocity.y += gravity * delta
#	elif velocity.y > 0:
#		velocity.y = 0
	
	move_and_slide()
#endregion Pathfinding
