extends Weapon

class_name GrappleHook

var grapple_range : float ## Depends on range
var hook : Hook
const hook_speed := 700.0
#const max_length := 175.0
const max_length := 400.0
var attached := false
var retracting := false

const GRAPPLE_GRAVITY := 0.65
var gravity_mod : Mod

@onready var line : Line2D = %ChainLine

func _process(delta):
	# Grapple graphics
	_show_grapple_line()
	
	# Grapple inputs
	if Input.is_action_pressed("attack") and not hook:
		_shoot_hook()
	if Input.is_action_just_released("attack"):
		_remove_hook_collisions()
		if not retracting:
			_retract_hook()
		

func add_gravity_mod():
	remove_gravity_mod()
	gravity_mod = Global.player.gravity.append_mult_mod(GRAPPLE_GRAVITY)

func remove_gravity_mod():
	if gravity_mod:
		Global.player.gravity.remove_mod(gravity_mod)

func _shoot_hook():
	var mouse_dir = get_local_mouse_position().normalized()
	hook = Hook.create_hook(mouse_dir * hook_speed)
	hook.max_length = max_length
	hook.hooked_on_surface.connect(_begin_hook_movement)
	hook.position = player.global_position + mouse_dir * 2.0
	detached_projectiles.add_child(hook)

func _retract_hook():
	attached = false
	retracting = true
	if hook:
		hook.moving_towards_player = true
		# If the hook was attached, detach and allow it to pass through walls
		hook.collision_layer = 0
		hook.collision_mask = 0
		hook.freeze = false

func _remove_hook_collisions():
	if hook:
		hook.collision_layer = 0
		hook.collision_mask = 0
		hook.freeze = false

func _cancel_hook():
	attached = false
	retracting = false 
	if hook: 
		if hook.hooked_on_surface.is_connected(_begin_hook_movement):
			hook.hooked_on_surface.disconnect(_begin_hook_movement)
		hook.queue_free() 
	player.end_ability_physics()
	remove_gravity_mod()

func _begin_hook_movement():
	attached = true
	player.start_ability_physics()
	add_gravity_mod()
	
	_jerk_towards_hook()

func _jerk_towards_hook():
	if hook:
		var dir_to_hook = player.global_position.direction_to(hook.global_position)
		const centripetal_impulse_str = 150.0 # TODO
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
		var extra_dist = dist - max_length
		if past_max_dist:
			if attached: 
				const ratio = 100.0
				# This ratio (100:1) per second will be projected to the 
				# perpendicular of the chain when at max distance, forcing a 
				# circular path at the end of the chain 
				player.velocity = player.velocity * (1 - ratio * delta) + ratio * delta * player.velocity.project(player_to_hook.normalized().rotated(PI / 2))
				player.global_position += player_to_hook.normalized() * (dist - max_length)
			else:
				_retract_hook()
		if dist < 20.0 and retracting: 
			_cancel_hook()

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
		# Pull player towards hook
		var dir_to_hook = player.global_position.direction_to(hook.global_position)
		const centripetal_force_str = 800.0 # TODO
		var centripetal_force = dir_to_hook * centripetal_force_str
		# Move player in input direction
		var input_dir = _get_input_dir().normalized()
		const movement_force_str = 500.0 # TODO
		var movement_force = input_dir * movement_force_str
		
		var total_force = centripetal_force + movement_force
		# Reduce forces in same direction 
		# If exactly same, 0.5; if angle >= 90deg, 1.0 FIXME
		var same_direction_mod = -maxf(0, dir_to_hook.dot(input_dir)) * 0.3 + 1.0
		total_force *= same_direction_mod
		
		player.add_force(total_force)

func _get_input_dir() -> Vector2:
	var hoz_axis = Input.get_axis("move_left", "move_right")
	var vert_axis = Input.get_axis("move_up", "move_down")
	return Vector2(hoz_axis, vert_axis).normalized()
