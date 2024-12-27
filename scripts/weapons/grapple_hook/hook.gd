extends RigidBody2D

class_name Hook

const SCENE = preload("res://scenes/weapons/grapple_hook/hook.tscn")

signal enemy_hit
signal hooked_on_surface

var max_length : float

static func create_hook(velocity : Vector2):
	var hook = SCENE.instantiate()
	hook.linear_velocity = velocity
	hook.rotation = velocity.angle()
	hook.lock_rotation = true
	return hook

func _on_body_entered(body):
	# TODO add Enemy class
	#if body is Enemy:
		#enemy_hit.emit()
	if body is Map:
		set_deferred("freeze", true)
		hooked_on_surface.emit()
