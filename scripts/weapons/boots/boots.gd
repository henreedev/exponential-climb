extends Weapon

class_name Boots

## Applies as a force over the jump duration
const JUMP_STRENGTH := 600.0
const JUMP_DURATION := .5
const PREFLOATING_DRAG := 2.0
const DRAG_DURATION := 0.25
const FLOAT_DURATION := 2.0
const FLOATING_GRAV_MOD := 0.5
const MOVEMENT_SPEED_MOD = 1.4

var jump_tween : Tween
var gravity_mod : StatMod
var movement_speed_mod : StatMod
var slamming := false
var double_jumps_used := 0

func _ready():
	Global.player.trying_jump.connect(jump)
	Global.player.trying_double_jump.connect(begin_double_jump)
	Global.player.released_double_jump.connect(begin_slam)
	
	Global.player.landed_on_floor.connect(land_slam)

func jump():
	Global.player.skip_next_jump = true
	
	Global.player.set_physics_ratio(1.0)
	Global.player.set_physics_ratio_decrease(0.0)
	
	remove_floating_gravity_mod()
	
	# Reset jump tween
	_reset_jump_tween(true)
	
	const INITIAL_BURST_DUR = 0.15
	const WINDUP_DUR = 0.05
	const INITIAL_BURST_MOD = 3.0
	
	# Wind up briefly
	jump_tween.tween_method(Global.player.add_force, \
						Vector2(0, 0), \
						Vector2(0, -JUMP_STRENGTH), \
						WINDUP_DUR)
	jump_tween.tween_callback(Global.player.add_impulse.bind(Vector2(0, -50)))
	# Jump up quickly (no impulse)
	jump_tween.tween_method(Global.player.add_force, \
						Vector2(0, -JUMP_STRENGTH * INITIAL_BURST_MOD), \
						Vector2(0, -JUMP_STRENGTH), \
						INITIAL_BURST_DUR)
	# Slow down the acceleration
	jump_tween.tween_method(Global.player.add_force, \
						Vector2(0, -JUMP_STRENGTH), \
						Vector2(0, -JUMP_STRENGTH * 1.0 / INITIAL_BURST_MOD), \
						JUMP_DURATION - INITIAL_BURST_DUR - WINDUP_DUR)
	# Slow speed by a lot at the top, start floating at this height
	jump_tween.tween_method(Global.player.add_vert_friction, \
						PREFLOATING_DRAG, \
						PREFLOATING_DRAG, \
						DRAG_DURATION)
	# Reduce gravity for a duration, to float better
	jump_tween.tween_callback(add_floating_gravity_mod)
	jump_tween.tween_callback(remove_floating_gravity_mod).set_delay(FLOAT_DURATION)
#region Mods
func add_floating_gravity_mod():
	remove_floating_gravity_mod()
	gravity_mod = Global.player.gravity.append_mult_mod(FLOATING_GRAV_MOD)

func remove_floating_gravity_mod():
	if gravity_mod:
		Global.player.gravity.remove_mod(gravity_mod)

func add_movement_speed_mod():
	remove_movement_speed_mod()
	movement_speed_mod = Global.player.movement_speed.append_mult_mod(MOVEMENT_SPEED_MOD)

func remove_movement_speed_mod():
	if movement_speed_mod:
		Global.player.movement_speed.remove_mod(movement_speed_mod)
#endregion Mods

## Starts a double jump, where the player moves more quickly horizontally and has less gravity.
## Basically Samus down-B.
## On release, a slam starts.
func begin_double_jump():
	Global.player.skip_next_jump = true
	slamming = false
	double_jumps_used += 1
	remove_movement_speed_mod()
	
	
	const DOUBLE_JUMP_DUR = 0.25
	_reset_jump_tween(true)
	
	Global.player.add_impulse(Vector2(0, -100))
	
	jump_tween.tween_method(
						Global.player.add_force, \
						Vector2(0, -JUMP_STRENGTH), \
						Vector2(0, -JUMP_STRENGTH), \
						DOUBLE_JUMP_DUR)
	jump_tween.parallel().tween_method(
						Global.player.add_vert_friction, \
						PREFLOATING_DRAG, \
						PREFLOATING_DRAG, \
						DOUBLE_JUMP_DUR)
	jump_tween.tween_callback(add_movement_speed_mod)


## Slams the player towards the ground, dealing damage on contact 
## while travelling. Accelerates quickly towards the ground.
## Called on double jump release.
func begin_slam():
	Global.player.skip_next_jump = true
	slamming = true
	
	Global.player.velocity = Vector2(Global.player.velocity.x, Global.player.velocity.y * 0)
	Global.player.add_impulse(Vector2(0, 100 * double_jumps_used))

	# Reset jump tween
	_reset_jump_tween(true)
	
	var downward_accel_strength = (JUMP_STRENGTH * 0.5) * sqrt(double_jumps_used)
	
	jump_tween.tween_method(
						Global.player.add_force, \
						Vector2(0, downward_accel_strength), \
						Vector2(0, downward_accel_strength), \
						999)

## Deals an AOE on landing based on impact speed and double jumps used.
func land_slam():
	if slamming:
		# Reset variables
		slamming = false
		_reset_jump_tween()
		Global.player.add_friction(1000000) # Stop the player
		# TODO slam aoe ,potentially slow player in place for a sec
	remove_floating_gravity_mod()
	remove_movement_speed_mod()
	double_jumps_used = 0
	Global.player.set_physics_ratio_decrease(1.0)
	

func _reset_jump_tween(create_new := false):
	# Reset jump tween
	if jump_tween:
		jump_tween.kill()
	if create_new:
		jump_tween = create_tween()
