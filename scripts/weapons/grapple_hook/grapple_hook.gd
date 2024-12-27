extends Weapon

class_name GrappleHook

var grapple_range : float ## Depends on range
var hook : Hook
const hook_speed := 750.0
const max_length := 175.0
const DETACH_DASH_DELAY := 0.1
var detach_dash_timer := 0.0
var attached := false
@onready var line : Line2D = %ChainLine

func _input(event):
	if event.is_action_pressed("attack"):
		_shoot_hook()
	if event.is_action_released("attack"):
		_cancel_hook()


func _shoot_hook():
	var mouse_dir = get_local_mouse_position().normalized()
	hook = Hook.create_hook(mouse_dir * hook_speed)
	hook.hooked_on_surface.connect(_begin_hook_movement)
	hook.position = player.global_position + mouse_dir * 2.0
	detached_projectiles.add_child(hook)

func _cancel_hook():
	attached = false
	if hook: 
		hook.queue_free() 
		if hook.hooked_on_surface.is_connected(_begin_hook_movement):
			hook.hooked_on_surface.disconnect(_begin_hook_movement)
	player.set_physics_ratio_decrease(1.0)

func _begin_hook_movement():
	attached = true
	player.set_physics_ratio(1.0)
	_jerk_towards_hook()

func _jerk_towards_hook():
	var dir_to_hook = player.global_position.direction_to(hook.global_position)
	const centripetal_impulse_str = 250.0 # TODO
	var centripetal_impulse = dir_to_hook * centripetal_impulse_str
	player.add_impulse(centripetal_impulse)

func _physics_process(delta : float) -> void:
	_limit_hook_distance(delta)
	_do_hook_movement(delta)

func _limit_hook_distance(delta : float):
	if hook:
		var player_to_hook = hook.global_position - player.global_position
		var dist = player_to_hook.length()
		var past_max_dist = dist > max_length
		if past_max_dist:
			if attached: 
				const ratio = 5.0
				player.velocity = player.velocity * (1 - ratio * delta) + ratio * delta * player.velocity.project(player_to_hook.normalized().rotated(PI / 2))
			else:
				_cancel_hook()
func _process(delta):
	_show_grapple_line()

## Draws a line connecting the player and the hook.
func _show_grapple_line():
	if hook:
		line.clear_points()
		line.add_point(hook.global_position)
		line.add_point(player.global_position)
	elif line.get_point_count() > 0:
		line.clear_points()

func _do_hook_movement(delta : float) -> void:
	print(player.physics_ratio)
	if attached:
		# Pull player towards hook
		var dir_to_hook = player.global_position.direction_to(hook.global_position)
		const centripetal_force_str = 800.0 # TODO
		var centripetal_force = dir_to_hook * centripetal_force_str
		# Move player in input direction
		var input_dir = _get_input_dir().normalized()
		const movement_force_str = 400.0 # TODO
		var movement_force = input_dir * movement_force_str
		
		var total_force = centripetal_force + movement_force
		# Reduce forces in same direction 
		# If exactly same, 0.5; if angle >= 90deg, 1.0
		var same_direction_mod = -maxf(0, dir_to_hook.dot(input_dir)) * 0.5 + 1.0
		total_force *= same_direction_mod
		
		player.add_force(total_force)

func _get_input_dir() -> Vector2:
	var hoz_axis = Input.get_axis("move_left", "move_right")
	var vert_axis = Input.get_axis("move_up", "move_down")
	return Vector2(hoz_axis, vert_axis).normalized()
