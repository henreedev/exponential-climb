extends Weapon

class_name Teleport

const TELEPORT_DISTANCE := 250.0
const POST_TELEPORT_MOVEMENT_SPEED_MOD := 1.6
const POST_TELEPORT_GRAVITY_MOD := 0.5
const TELEPORT_DURATION := 0.1
const TELEPORT_DRAG := 20.0
const TELEPORT_IMPULSE_STRENGTH := 300.0
const TELEPORT_COOLDOWN := 2.5

var cooldown_timer := 0.0
## Recalculated at each teleport.
var teleport_dir : Vector2

var teleport_tween : Tween
var gravity_mod : Mod
var movement_speed_mod : Mod

## Used to trace along the teleport path 
@onready var shapecast : ShapeCast2D = $PlayerShapeCast
@onready var raycast : RayCast2D = $LOSRayCast

func _ready():
	Global.player.landed_on_floor.connect(land_on_floor)

func _process(delta):
	# Check for teleport input
	if not is_on_cooldown() and Input.is_action_pressed("attack"):
		teleport()
	cooldown_timer = maxf(cooldown_timer - delta, 0)

func teleport():
	Global.player.start_ability_physics()
	Global.player.attacked.emit()
	cooldown_timer = TELEPORT_COOLDOWN
	
	remove_gravity_mod()
	remove_movement_speed_mod()
	
	_reset_teleport_tween(true)
	
	teleport_tween.tween_method(
		Global.player.add_friction,
		TELEPORT_DRAG,
		TELEPORT_DRAG,
		TELEPORT_DURATION
	)
	teleport_tween.tween_callback(_teleport_player_towards_mouse)
	teleport_tween.tween_method(
		Global.player.add_friction,
		TELEPORT_DRAG,
		TELEPORT_DRAG,
		TELEPORT_DURATION
	)
	teleport_tween.tween_callback(_impulse_in_teleport_direction)
	teleport_tween.tween_callback(add_gravity_mod)
	teleport_tween.tween_callback(add_movement_speed_mod)

#func _teleport_player_towards_mouse():
	#var mouse_rot = get_local_mouse_position().angle()
	#teleport_dir = Vector2.from_angle(mouse_rot)
	#shapecast.rotation = mouse_rot
	#shapecast.target_position = Vector2(TELEPORT_DISTANCE, 0)
	#var position_offset = Vector2(TELEPORT_DISTANCE, 0).rotated(mouse_rot)
	#
	##var teleport_destination = get_global_mouse_position()
	#
	#shapecast.force_shapecast_update()
	#
	#if not shapecast.is_colliding():
		## Teleport full distance
		#Global.player.position += position_offset
	#else:
		#Global.player.position += lerp(
			#Vector2.ZERO,
			#position_offset,
			#shapecast.get_closest_collision_safe_fraction()
		#)
		
## Teleports the player to the mouse position, ensuring a maximum teleport distance and that the
## player fits into the teleport location. Uses raycast to check the line of sight to the teleport
## destination, then a shapecast to find the first location the player fits into.
func _teleport_player_towards_mouse():
	var teleport_destination := get_local_mouse_position()
	# Limit max teleport length
	if teleport_destination.length() > TELEPORT_DISTANCE:
		teleport_destination = teleport_destination.normalized() * TELEPORT_DISTANCE
	# Raycast towards clicked location
	raycast.target_position = teleport_destination
	
	# Check raycast for line-of-sight
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		# Shapecast from collision point to player to find final teleport location
		var ray_collision_point = to_local(raycast.get_collision_point())
		shapecast.position = ray_collision_point
		shapecast.target_position = -ray_collision_point
	else:
		# Shapecast back from clicked location, to find furthest fitting spot
		shapecast.position = teleport_destination
		shapecast.target_position = -teleport_destination
	shapecast.force_shapecast_update()
	if shapecast.is_colliding():
		var frac = shapecast.get_closest_collision_safe_fraction()
		print(frac)
		teleport_destination = lerp(shapecast.position, shapecast.target_position, frac)
	player.global_position = to_global(teleport_destination)
	
func _impulse_in_teleport_direction():
	if not teleport_dir.is_zero_approx():
		Global.player.add_impulse(teleport_dir * TELEPORT_IMPULSE_STRENGTH)

func land_on_floor():
	remove_gravity_mod()
	remove_movement_speed_mod()
	Global.player.end_ability_physics()

#region Helpers
func is_on_cooldown():
	return cooldown_timer > 0.0

func _reset_teleport_tween(create_new := false):
	# Reset teleport tween
	if teleport_tween:
		teleport_tween.kill()
	if create_new:
		teleport_tween = create_tween()
#endregion Helpers

#region Mods
func add_gravity_mod():
	remove_gravity_mod()
	if not Global.player.is_on_floor():
		gravity_mod = Global.player.gravity.append_mult_mod(POST_TELEPORT_GRAVITY_MOD)

func remove_gravity_mod():
	if gravity_mod:
		Global.player.gravity.remove_mod(gravity_mod)

func add_movement_speed_mod():
	remove_movement_speed_mod()
	if not Global.player.is_on_floor():
		movement_speed_mod = Global.player.movement_speed.append_mult_mod(POST_TELEPORT_MOVEMENT_SPEED_MOD)

func remove_movement_speed_mod():
	if movement_speed_mod:
		Global.player.movement_speed.remove_mod(movement_speed_mod)
#endregion Mods
