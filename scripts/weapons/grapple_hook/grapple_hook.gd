extends Weapon

## A physics-based grappling hook that deals damage on hook passthrough and player contact. 
class_name GrappleHook

var hook : Hook
var attached := false
var retracting := false

const GRAPPLING_GRAVITY := 0.42
const POST_GRAPPLE_GRAVITY := 0.65
var grappling_gravity_mod : Mod
var post_grapple_gravity_mod : Mod

@onready var line : Line2D = %ChainLine

func _init():
	super._init()
	attack_1_damage = 1.0
	attack_2_damage = 1.0
	attack_3_damage = 3.0
	attack_speed = 700.0
	range = 300.0
	area = 16.0

func _ready():
	Global.player.landed_on_floor.connect(_land_on_floor)

func _process(delta):
	# Grapple inputs
	if Input.is_action_pressed("attack") and not hook:
		_shoot_hook()
	if Input.is_action_just_released("attack"):
		_remove_hook_collisions()
		if not retracting:
			_retract_hook()
		

func add_grappling_gravity_mod():
	remove_gravity_mods()
	grappling_gravity_mod = Global.player.gravity.append_mult_mod(GRAPPLING_GRAVITY)

func add_post_grapple_gravity_mod():
	remove_gravity_mods()
	post_grapple_gravity_mod = Global.player.gravity.append_mult_mod(POST_GRAPPLE_GRAVITY)

func remove_gravity_mods():
	if grappling_gravity_mod:
		Global.player.gravity.remove_mod(grappling_gravity_mod)
	if post_grapple_gravity_mod:
		Global.player.gravity.remove_mod(post_grapple_gravity_mod)

func _shoot_hook():
	var mouse_dir = get_local_mouse_position().normalized()
	hook = Hook.create_hook(mouse_dir * get_attack_speed())
	hook.max_length = get_range()
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
		if not player.is_on_floor():
			add_post_grapple_gravity_mod()
		else:
			_land_on_floor()


## Remove low gravity after touching floor 
func _land_on_floor():
	if not attached:
		player.end_ability_physics()
		remove_gravity_mods()

func _begin_hook_movement():
	attached = true
	player.start_ability_physics()
	add_grappling_gravity_mod()
	
	_jerk_towards_hook()

func _jerk_towards_hook():
	if hook:
		var dir_to_hook = player.global_position.direction_to(hook.global_position)
		const centripetal_impulse_str = 150.0 # TODO
		var centripetal_impulse = dir_to_hook * centripetal_impulse_str
		player.add_impulse(centripetal_impulse)

func _physics_process(delta : float) -> void:
	# Grapple graphics
	_show_grapple_line()
	
	_limit_hook_distance(delta)
	_do_hook_movement(delta)

func _limit_hook_distance(delta : float):
	if hook:
		var max_length = get_range()
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
		const centripetal_force_str = 800.0 
		var centripetal_force = dir_to_hook * centripetal_force_str
		# Move player in input direction
		var input_dir = _get_input_dir().normalized()
		const movement_force_str = 700.0 
		var movement_force = input_dir * movement_force_str
		
		# Reduce forces in same direction 
		# If exactly same, 0.7; if angle >= 90deg, 1.0 
		var same_direction_mod = 0.2 + 0.8 * abs(dir_to_hook.rotated(PI / 2).dot(input_dir))
		movement_force *= same_direction_mod
		var total_force = centripetal_force + movement_force
		
		player.add_force(total_force)

func _get_input_dir() -> Vector2:
	var hoz_axis = Input.get_axis("move_left", "move_right")
	var vert_axis = Input.get_axis("move_up", "move_down")
	return Vector2(hoz_axis, vert_axis).normalized()
