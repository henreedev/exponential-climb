extends RigidBody2D

class_name Hook

const SCENE = preload("res://scenes/weapons/grapple_hook/hook.tscn")

signal enemy_hit
signal hooked_on_surface

var max_length : float
var speed : float
## Set true when reaching max length. 
var moving_towards_player := false

static func create_hook(velocity : Vector2):
	var hook = SCENE.instantiate()
	hook.linear_velocity = velocity
	hook.speed = velocity.length()
	hook.rotation = velocity.angle()
	hook.lock_rotation = true
	return hook

func _on_body_entered(body):
	# TODO add Enemy class
	#if body is Enemy:
		#enemy_hit.emit()
	if body is Map or body is TileMapLayer:
		set_deferred("freeze", true)
		hooked_on_surface.emit()	

func _integrate_forces(state):
	var progress_along_length = clampf(global_position.distance_to(Global.player.global_position) \
										/ max_length, 0.0, 1.0)
	var added_player_speed = Global.player.velocity.length() / 2 
	if moving_towards_player and not freeze:
		var speed_mod = lerp(1.5, 0.6, progress_along_length)
		state.linear_velocity = (speed + added_player_speed) * speed_mod * \
			global_position.direction_to(Global.player.global_position)
		state.transform = Transform2D(state.linear_velocity.angle() + PI, state.transform.get_origin())
	elif not freeze: # Moving away from player. 
		# Add some of player's speed so the hook doesnt lag behind
		var speed_mod = lerp(3.0, 1.0, progress_along_length)
		linear_velocity = linear_velocity.normalized() * (speed + added_player_speed) * speed_mod 
