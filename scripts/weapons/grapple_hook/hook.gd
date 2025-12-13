extends RigidBody2D

class_name Hook

const SCENE = preload("res://scenes/weapons/grapple_hook/hook.tscn")

signal enemy_hit
signal hooked_on_surface

var max_length : float
var speed : float
## Set true when reaching max length. 
var moving_towards_player := false

var grapple_hook : GrappleHook
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_shape_circle: CircleShape2D = $Hitbox/CollisionShape2D.shape

static func create_hook(velocity : Vector2, _grapple_hook : GrappleHook):
	var hook = SCENE.instantiate()
	hook.grapple_hook = _grapple_hook
	hook.linear_velocity = velocity
	hook.speed = velocity.length()
	hook.rotation = velocity.angle()
	hook.lock_rotation = true
	return hook

func _ready():
	resize_hitbox()

func resize_hitbox():
	var radius = grapple_hook.get_area()
	hitbox_shape_circle.radius = radius

func _integrate_forces(state):
	var progress_along_length = clampf(global_position.distance_to(Global.player.global_position) \
										/ max_length, 0.0, 1.0)
	if moving_towards_player and not freeze:
		var dir = global_position.direction_to(Global.player.global_position)
		var added_player_speed = Global.player.velocity.project(dir)
		var speed_mod = lerp(1.5, 1.0, progress_along_length)
		state.linear_velocity = added_player_speed + (speed) * speed_mod * dir
		state.transform = Transform2D(state.linear_velocity.angle() + PI, state.transform.get_origin())
	elif not freeze: # Moving away from player. 
		var speed_mod = lerp(1.5, 1.0, progress_along_length)
		#var dir = global_position.direction_to(Global.player.global_position)
		linear_velocity = linear_velocity.normalized() * speed * speed_mod 

## Map collisions, to start grappling using.
func _on_body_entered(body):
	if (body is TileMapLayer or Global.is_map_collider(body)) and not collision_layer == 0:
		set_deferred("freeze", true)
		hooked_on_surface.emit()

## Hitbox collisions, to deal damage
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		var enemy: Enemy = area.get_hitbox_parent() as Enemy
		
		if not moving_towards_player: # Attack 1 (extending hook)
			if grapple_hook.deal_damage(1, area):
				if enemy:
					enemy.receive_knockback(230, linear_velocity.normalized())
					enemy.receive_stun(0.2)
		else: # Attack 2 (extending hook)
			if grapple_hook.deal_damage(2, area):
				if enemy:
					enemy.receive_knockback(100, linear_velocity.normalized())

## Draws a line connecting the player and the hook.
func _draw_debug_hitbox():
	queue_redraw()

func _draw() -> void:
	if Global.debug_mode:
		draw_circle(hitbox_shape.position, hitbox_shape_circle.radius, Color.ORANGE_RED, false, 1)
