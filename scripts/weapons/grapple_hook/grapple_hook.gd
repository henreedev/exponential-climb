extends Weapon

## A physics-based grappling hook that deals damage on hook passthrough and player contact. 
class_name GrappleHook

var hook : Hook
var attached := false
var retracting := false
var hook_cooldown_timer := 0.0
const BASE_HOOK_COOLDOWN := 0.75

#region Melee (Attack 2)
const BASE_MELEE_RANGE := 64.0
const BASE_MELEE_WIDTH_RADIUS := 8.0
const BASE_MELEE_DASH_STRENGTH := 400.0 # Affected by range
const BASE_MELEE_WINDUP := 0.25
const BASE_MELEE_DURATION := 0.4
const BASE_MELEE_WINDDOWN := 0.15
const BASE_MELEE_COOLDOWN := 2.5

var melee_cooldown_timer := 0.0
## If melee attacking, can't extend hook or be attached. 
var melee_attacking := false
## True if the last (or current) melee attack was started on the floor.
var doing_floor_melee_attack := false
#endregion Melee (Attack 2)

const GRAPPLING_GRAVITY := 0.6
const POST_GRAPPLE_GRAVITY := 0.8
var grappling_gravity_mod : Mod
var post_grapple_gravity_mod : Mod

@onready var line : Line2D = %ChainLine
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_hitbox_shape: CollisionShape2D = $MeleeHitbox/CollisionShape2D
@onready var melee_hitbox_shape_rect: RectangleShape2D = $MeleeHitbox/CollisionShape2D.shape

func _init():
	super._init()
	attack_1_damage = 1.0 # Hook extension
	attack_2_damage = 1.0 # Hook retraction
	attack_3_damage = 3.0 # Melee attack
	attack_speed = 700.0
	range = 275.0
	area = 4.0

func _ready():
	Global.player.landed_on_floor.connect(_land_on_floor)

func _process(delta):
	# Display grapple line in _draw()
	_redraw_hook_line()
	
	# Melee inputs
	if Input.is_action_pressed("secondary_attack"):
		do_melee_attack()
	
	# Grapple inputs
	if Input.is_action_pressed("attack") and not hook and not melee_attacking:
		_shoot_hook()
	if Input.is_action_just_released("attack"):
		_remove_hook_collisions()
		if not retracting:
			_retract_hook()
		

func _physics_process(delta : float) -> void:
	_limit_hook_distance(delta)
	_do_hook_movement(delta)
	_update_melee_hitbox(delta)
	_tick_cooldowns(delta)

func _tick_cooldowns(delta):
	if melee_cooldown_timer > 0: 
		melee_cooldown_timer -= delta
	if hook_cooldown_timer > 0: 
		hook_cooldown_timer -= delta
	

## Draws a line connecting the player and the hook.
func _redraw_hook_line():
	#if hook:
	queue_redraw()

func _draw() -> void:
	if hook:
		for pixel in Geometry2D.bresenham_line(Vector2.ZERO, hook.global_position - global_position):
			draw_rect(Rect2(pixel, Vector2.ONE), Color.REBECCA_PURPLE)
#region Mods
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
#endregion Mods

#region Hook (Attack 1)
func _shoot_hook():
	if not hook_cooldown_timer > 0:
		retracting = false
		var atk_spd = player.attack_speed.value()
		var cooldown = BASE_HOOK_COOLDOWN / atk_spd
		hook_cooldown_timer = cooldown
		
		var mouse_dir = get_local_mouse_position().normalized()
		hook = Hook.create_hook(mouse_dir * get_attack_speed(), self)
		hook.max_length = get_range()
		hook.hooked_on_surface.connect(_begin_hook_movement)
		hook.position = player.global_position + mouse_dir * 2.0
		detached_projectiles.add_child(hook)

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

func _retract_hook():
	retracting = true
	if hook:
		hook.moving_towards_player = true

func _remove_hook_collisions():
	attached = false
	if hook:
		# If the hook was attached, detach and allow it to pass through walls
		hook.collision_layer = 0
		hook.collision_mask = 0
		hook.freeze = false

func _cancel_hook():
	clear_enemies_hit([1, 2])
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
		if dist < 10.0 and retracting: 
			_cancel_hook()

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
#endregion Hook (Attack 1)


## Remove low gravity after touching floor 
func _land_on_floor():
	if not attached:
		player.end_ability_physics()
		remove_gravity_mods()



func _get_input_dir() -> Vector2:
	var hoz_axis = Input.get_axis("move_left", "move_right")
	var vert_axis = Input.get_axis("move_up", "move_down")
	return Vector2(hoz_axis, vert_axis).normalized()

#region Melee (Attack 2)
## If grounded, does a forward attack that knocks back enemies.
## If airborne, does a flying attack in the mouse direction that damages based on speed.
func do_melee_attack():
	if not melee_attacking and not melee_cooldown_timer > 0:
		melee_attacking = true
		
		update_melee_hitbox_size()
		
		# Retract the hook
		_remove_hook_collisions()
		_retract_hook()
		
		var attack_dir = get_local_mouse_position().normalized()
		if attack_dir == Vector2.ZERO: attack_dir = Vector2.RIGHT # Mouse pos == center of player
		
		var atk_spd = player.get_attack_speed()
		var windup = BASE_MELEE_WINDUP / atk_spd
		var duration = BASE_MELEE_DURATION / atk_spd
		var winddown = BASE_MELEE_WINDDOWN / atk_spd
		var cooldown = BASE_MELEE_COOLDOWN / atk_spd
		
		# Start the melee cooldown
		melee_cooldown_timer = cooldown
		
		var melee_tween := create_tween()
		
		# Grounded kick that knocks back enemies and player, defensive tool for creating distance
		if player.is_on_floor(): 
			doing_floor_melee_attack = true
			# Apply horizontal drag and wind up attack
			melee_tween.tween_method(player.add_hoz_friction, 20.0, 20.0, windup)
			
			
			
			# Do attack hitbox, even more drag
			duration *= 0.25
			melee_tween.tween_property(melee_hitbox_shape, "disabled", false, 0.0)
			melee_tween.tween_callback(player.add_impulse.bind(-attack_dir * 700))
			melee_tween.tween_method(player.add_hoz_friction, 0.0, 100.0, duration)
			melee_tween.parallel().tween_method(player.add_vert_friction, 0.0, 100.0, duration)
			
			# Finish attack, dash backwards
			var backwards = -attack_dir
			melee_tween.tween_property(melee_hitbox_shape, "disabled", true, 0.0)
			melee_tween.tween_method(player.add_force, backwards * 1000, backwards * 1000, winddown)
		else: 
			doing_floor_melee_attack = false
			player.double_jumps_left = clampi(player.double_jumps_left + 1, 0, player.double_jumps.value())
			# Flying punch in mouse direction, damaging based on speed
			# Store velocity before, to return to it and multiply it after a windup
			var velocity_before_windup = player.physics_velocity
			var color_before_windup = melee_hitbox_shape.debug_color
			
			var dash_strength = BASE_MELEE_DASH_STRENGTH * player.get_range() + velocity_before_windup.length() * 0.4
			
			var mouse_dir_velocity = attack_dir * dash_strength
			# If punching in dir of movement, speed *= (0.8 + 0.6)
			var velocity_in_attack_dir = velocity_before_windup * velocity_before_windup.normalized().dot(attack_dir) 
			var punch_velocity = 0.4 * velocity_in_attack_dir + 0.6 * mouse_dir_velocity
			# Apply drag and wind up attack
			melee_tween.tween_method(player.add_hoz_friction, 0.0, 10.0, windup)
			melee_tween.parallel().tween_method(player.add_vert_friction, 0.0, 10.0, windup)
			
			# Accelerate quickly based on calculated speed
			duration *= get_melee_damage_speed_mult() # More speed == more duration
			melee_tween.tween_property(player, "velocity", punch_velocity, duration * 0.2).from(Vector2.ZERO).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
			
			
			# Do attack hitbox, dash towards mouse 
			melee_tween.tween_property(melee_hitbox_shape, "disabled", false, 0.0)
			melee_tween.parallel().tween_property(melee_hitbox_shape, "debug_color", Color.ORANGE, duration)
			melee_tween.parallel().tween_method(player.add_force, mouse_dir_velocity * 0.3, Vector2.ZERO, duration)
			
			# Finish attack
			melee_tween.tween_property(melee_hitbox_shape, "disabled", true, 0.0)
			melee_tween.tween_property(melee_hitbox_shape, "debug_color", color_before_windup, 0.0)
		melee_tween.tween_property(self, "melee_attacking", false, 0.0)
		# Clear the enemies_hit array for this attack
		var weapon_idx_to_clear : Array[int] = [3]
		melee_tween.tween_callback(clear_enemies_hit.bind(weapon_idx_to_clear))


## Resizes the melee hitbox using the player's area and range and the weapon's range. 
func update_melee_hitbox_size():
	# This will be the length the attack extends from the player
	var melee_range = get_range() * get_melee_range_ratio()
	
	# The height dimension of the attack. Area represents the radius
	var melee_height = get_area() * 2
	
	melee_hitbox_shape_rect.size = Vector2(melee_range, melee_height)
	melee_hitbox_shape.position = Vector2(melee_hitbox_shape_rect.size.x / 2.0, 0)


## 
func _update_melee_hitbox(delta):
	if not melee_attacking: 
		melee_hitbox.rotation = get_local_mouse_position().angle()

## Find the multiplier needed to convert from `range` to `BASE_MELEE_RANGE`
func get_melee_range_ratio():
	return BASE_MELEE_RANGE / range 

func get_melee_damage():
	var damage = player.base_damage.value() * get_attack_damage(3) * get_melee_damage_speed_mult()
	return damage

func get_melee_damage_speed_mult():
	if doing_floor_melee_attack:
		return 1.0 # No speed multiplier for grounded attacks
	
	# For every 1.5x the default movement speed, increase damage multiplier by 1.0
	const MOVEMENT_UNIT = Player.DEFAULT_MOVEMENT_SPEED * 1.5
	const MAX_DAMAGE_MULTIPLIER = 3.0
	var mult = clampf(player.velocity.length() / MOVEMENT_UNIT, 1.0, MAX_DAMAGE_MULTIPLIER)
	
	return mult

func _on_melee_hitbox_area_entered(area: Area2D) -> void:
	var enemy = area.get_parent()
	if enemy is Enemy:
		if deal_damage(3, enemy, get_melee_damage()):
			enemy.receive_stun(1.00)
			enemy.receive_knockback(400)
#endregion Melee (Attack 2)
