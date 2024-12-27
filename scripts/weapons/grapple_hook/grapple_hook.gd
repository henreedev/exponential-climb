extends Weapon

class_name GrappleHook

var grapple_range : float ## Depends on range
var hook : Hook
const hook_speed := 350.0
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
	if hook: hook.queue_free() 
	hook.hooked_on_surface.disconnect(_begin_hook_movement)

func _begin_hook_movement():
	attached = true

func _physics_process(delta : float) -> void:
	_do_hook_movement(delta)

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
	if attached:
		var dir_to_hook = player.global_position.direction_to(hook.global_position)
		const centrifugal_force_str = 200.0 # TODO
		player.add_force(dir_to_hook * centrifugal_force_str)
		var input_dir = _get_input_dir()
		const movement_force_str = 200.0 # TODO
		player.add_force(input_dir * movement_force_str)

func _get_input_dir() -> Vector2:
	var hoz_axis = Input.get_axis("move_left", "move_right")
	var vert_axis = Input.get_axis("move_up", "move_down")
	return Vector2(hoz_axis, vert_axis).normalized()
