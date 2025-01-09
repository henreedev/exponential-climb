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
	if body is TileMapLayer and not moving_towards_player:
		set_deferred("freeze", true)
		hooked_on_surface.emit()

func _integrate_forces(state):
	var progress_along_length = clampf(global_position.distance_to(Global.player.global_position) \
										/ max_length, 0.0, 1.0)
	if moving_towards_player and not freeze:
		var dir = global_position.direction_to(Global.player.global_position)
		var added_player_speed = Global.player.velocity.project(dir)
		var speed_mod = lerp(3.0, 1.0, progress_along_length)
		state.linear_velocity = added_player_speed + (speed) * speed_mod * dir
		state.transform = Transform2D(state.linear_velocity.angle() + PI, state.transform.get_origin())
	elif not freeze: # Moving away from player. 
		var speed_mod = lerp(3.0, 1.0, progress_along_length)
		var dir = global_position.direction_to(Global.player.global_position)
		# Add some of player's speed so the hook doesnt lag behind
		var added_player_speed = Global.player.velocity.project(dir)
		linear_velocity = linear_velocity.normalized() * speed * speed_mod # + added_player_speed
