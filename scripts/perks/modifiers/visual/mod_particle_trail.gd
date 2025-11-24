extends Node2D

## Has a start, trail, and end. 
## One trail is instantiated per effect application that a modifier does.
## Alt should show all particle trails, while hovering should show only hovered perk's trails. Issue is perk card covering things to the right. 
## Maybe 2 seconds of hover should show trails?
## Also placing a modifier down should show trails until perk ui disabled. or until alt is unpressed. 
## For testing, just have alt unpress cause 
class_name ModParticleTrail

const POLARITY_TO_COLOR: Dictionary[PerkModEffect.Polarity, Color] = {
	PerkModEffect.Polarity.BUFF : Color.LIME_GREEN,
	PerkModEffect.Polarity.NERF : Color.RED,
}

var _trail_curve2d := Curve2D.new()
var _start_point: Vector2
var _end_point: Vector2
var _start_perk: Perk
var _end_perk: Perk
var _effect: PerkModEffect
var _perk_radius := 32.0
const MOD_PARTICLE_TRAIL_INITIAL_RAMP_GRADIENT: Gradient = preload("uid://bafatee2owwtg")
const MOD_PARTICLE_TRAIL = preload("uid://dn83q3lh1t725")

@onready var start: GPUParticles2D = %Start
@onready var start_mat: ParticleProcessMaterial = start.process_material
@onready var trail: GPUParticles2D = %Trail
@onready var trail_mat: ParticleProcessMaterial = trail.process_material
@onready var end: GPUParticles2D = %End
@onready var end_mat: ParticleProcessMaterial = end.process_material


var _trail_x_vel_curve: Curve
var _trail_y_vel_curve: Curve 

@onready var init_ramp_gradient: Gradient = MOD_PARTICLE_TRAIL_INITIAL_RAMP_GRADIENT.duplicate_deep()

#region Static methods
static func create_particle_trail(start_perk: Perk, end_perk: Perk, effect: PerkModEffect) -> ModParticleTrail:
	var new_particle_trail: ModParticleTrail = MOD_PARTICLE_TRAIL.instantiate()
	new_particle_trail.init(start_perk, end_perk, effect)
	return new_particle_trail
#endregion Static methods

func _ready() -> void:
	Global.formula_mode_toggled.connect(_on_formula_mode_toggled)
	_setup()
	kick_off()
	print(global_scale)

func init(start_perk: Perk, end_perk: Perk, effect: PerkModEffect) -> void:
	_start_perk = start_perk
	_end_perk = end_perk
	_effect = effect

func _setup() -> void:
	_setup_unique_particle_mats()
	_setup_dir_vel_curve_instances()
	_setup_coloring(_effect)
	_setup_trail(_start_perk, _end_perk)
 
## Setup coloring - calls bottom 3 functions 
func _setup_coloring(effect: PerkModEffect) -> void:
	_setup_shared_gradient()
	_set_gradient_rarity_color(effect)
	_set_gradient_polarity_color(effect)

## Set shared gradient
## Gives start, trail and end the same duplicate of the gradient resource
func _setup_unique_particle_mats() -> void:
	start_mat = start_mat.duplicate_deep()
	trail_mat = trail_mat.duplicate_deep()
	end_mat = end_mat.duplicate_deep()
	var start_grad_tex = start_mat.color_initial_ramp as GradientTexture1D
	start_grad_tex.gradient = init_ramp_gradient
	var trail_grad_tex = trail_mat.color_initial_ramp as GradientTexture1D
	trail_grad_tex.gradient = init_ramp_gradient
	var end_grad_tex = end_mat.color_initial_ramp as GradientTexture1D
	end_grad_tex.gradient = init_ramp_gradient

func _setup_dir_vel_curve_instances():
	const BOUND = 1000
	_trail_x_vel_curve = Curve.new()
	_trail_x_vel_curve.min_value = -BOUND
	_trail_x_vel_curve.max_value = BOUND
	
	_trail_y_vel_curve = Curve.new()
	_trail_y_vel_curve.min_value = -BOUND
	_trail_y_vel_curve.max_value = BOUND


## Set shared gradient
## Gives start, trail and end the same duplicate of the gradient resource
func _setup_shared_gradient() -> void:
	var start_grad_tex = start_mat.color_initial_ramp as GradientTexture1D
	start_grad_tex.gradient = init_ramp_gradient
	var trail_grad_tex = trail_mat.color_initial_ramp as GradientTexture1D
	trail_grad_tex.gradient = init_ramp_gradient
	var end_grad_tex = end_mat.color_initial_ramp as GradientTexture1D
	end_grad_tex.gradient = init_ramp_gradient

## Set rarity color
func _set_gradient_rarity_color(effect: PerkModEffect) -> void:
	var rarity: Perk.Rarity = effect.rarity
	var color := Chest.RARITY_TO_BODY_COLOR[rarity]
	
	# First color is base, second is rarity, third is polarity.
	init_ramp_gradient.set_color(1, color)

## Set polarity color
func _set_gradient_polarity_color(effect: PerkModEffect) -> void:
	var polarity: PerkModEffect.Polarity = effect.polarity
	var color := Chest.RARITY_TO_BODY_COLOR[polarity]
	
	# First color is base, second is rarity, third is polarity.
	init_ramp_gradient.set_color(2, color)

## Setup trail - calls bottom two functions
func _setup_trail(start_perk: Perk, end_perk: Perk) -> void:
	# For SELF direction, just show the start circle. 
	if start_perk == end_perk:
		trail.visible = false
		end.visible = false
		return
	_pick_start_end_locations(start_perk, end_perk)
	_calculate_trail_curve2d()
	_calculate_dir_vel_curves()
	

func _pick_start_end_locations(start_perk: Perk, end_perk: Perk) -> void:
	global_position = start_perk.global_position
	if start_perk == end_perk:
		return
	
	# Start position:
	# Determine dir based on position diff from start to end
	var diff_angle := start_perk.global_position.angle_to_point(end_perk.global_position)
	
	var dir := _get_quadrant_dir_from_angle(diff_angle)
	_start_point = dir * _perk_radius
	start.position = _start_point
	trail.position = _start_point
	
	# End position:
	#  The end perk receives the trail of particles from the 
	#  opposite dir from where it's sent out
	var end_perk_receive_dir := -dir
	
	# Find a point somewhere on the two sides facing in the receive dir
	var dict: Dictionary = pick_rhombus_side_point_and_angle(end_perk_receive_dir)
	var end_side_point: Vector2 = dict["point"]
	var end_side_angle: float = dict["angle"]
	
	_end_point = end_perk.global_position - global_position + end_side_point
	end.position = _end_point
	end.rotation = end_side_angle

func _get_quadrant_dir_from_angle(ang: float) -> Vector2:
	# Normalize angle to 0..TAU (same as 0..2π)
	ang = fposmod(ang, TAU)
	
	const RIGHT_START = 7 * PI / 4      # 315°
	const RIGHT_END   = PI / 4          # 45°
	const DOWN_START  = PI / 4          # 45°
	const DOWN_END    = 3 * PI / 4      # 135°
	const LEFT_START  = 3 * PI / 4      # 135°
	const LEFT_END    = 5 * PI / 4      # 225°
	const UP_START    = 5 * PI / 4      # 225°
	const UP_END      = 7 * PI / 4      # 315°
	
	var dir: Vector2
	
	if ang >= RIGHT_START or ang < RIGHT_END:
		dir = Vector2.RIGHT
	elif ang >= DOWN_START and ang < DOWN_END:
		dir = Vector2.DOWN
	elif ang >= LEFT_START and ang < LEFT_END:
		dir = Vector2.LEFT
	elif ang >= UP_START and ang < UP_END:
		dir = Vector2.UP
	else:
		assert(false)
	
	return dir

## Calculate trail curve2d - Start point, end point, picks random gradients
func _calculate_trail_curve2d():
	_trail_curve2d.add_point(_start_point)
	_trail_curve2d.add_point(_end_point)
	var curve_left = randf() > 0.5
	var control: Vector2
	const CONTROL_DIST = 50.0
	var control_dist = CONTROL_DIST * (_start_point.distance_to(_end_point) / 100.0) * randf_range(0.8, 1.2)
	var dir = _start_point.direction_to(_end_point)
	if curve_left:
		control = dir.rotated(-PI / 2.0) * control_dist 
	else:
		control = dir.rotated(PI / 2.0) * control_dist
	
	_trail_curve2d.set_point_out(0, control)
	_trail_curve2d.set_point_in(1, control)

	_trail_curve2d.bake_interval = 5 # px
	for point in _trail_curve2d.get_baked_points():
		var debug_visual = PlaceholderTexture2D.new()
		debug_visual.size = Vector2.ONE * 2
		var debug_sprite = Sprite2D.new()
		debug_sprite.position = point
		debug_sprite.texture = debug_visual
		add_child(debug_sprite)

## Calculate directional velocity curves - for each point on trail curve2d bake, 
## find the derivative with the last point and add a point to the x,y dir vel curves for the x,y of deriv.
## Try this out. Might work if we divide by baked length?
func _calculate_dir_vel_curves():
	# Follow along baked points in trail curve2d 
	# Find derivative at each pair, then add that derivative 
	# (divided by total length) as a point on the x,y curves for trail particle dir vel
	var total_length := _trail_curve2d.get_baked_length()
	assert(total_length > 0)
	
	# Set speed equal to total length
	trail_mat.directional_velocity_min = total_length
	trail_mat.directional_velocity_max = total_length + 5
	
	#var bake_interval := _trail_curve2d.bake_interval
	var prev_point: Vector2 = _start_point
	var next_point: Vector2
	var points := _trail_curve2d.get_baked_points()
	var num_points := points.size()
	var progress := 0.0 
	var progress_inc := 1.0 / float(num_points)
	
	for point: Vector2 in points:
		next_point = point
		
		var deriv := next_point - prev_point
		deriv /= total_length 
		
		_trail_x_vel_curve.add_point(Vector2(progress, deriv.x)) 
		_trail_y_vel_curve.add_point(Vector2(progress, deriv.y)) 
		
		progress += progress_inc 
		prev_point = next_point
	
	# Set changes in trail mat
	trail_mat.directional_velocity_curve.curve_x = _trail_x_vel_curve
	trail_mat.directional_velocity_curve.curve_y = _trail_y_vel_curve
	
## Kick off (start emitting start and trail, then after trail lifetime start emitting end.)
var kick_off_tween: Tween

func kick_off() -> void:
	start.emitting = start.visible
	trail.emitting = trail.visible
	
	var end_delay = trail.lifetime
	const WHITE_FLASH_DUR = 0.15
	const WHITE_FLASH_COLOR := Color.WHITE * 10
	kick_off_tween = create_tween().set_parallel()
	# Flash start and trail white for a moment
	kick_off_tween.tween_property(start_mat, "color", Color.WHITE, WHITE_FLASH_DUR).from(WHITE_FLASH_COLOR)
	kick_off_tween.tween_property(trail_mat, "color", Color.WHITE, WHITE_FLASH_DUR).from(WHITE_FLASH_COLOR)
	# Show end once trail reaches it, with the same flash
	kick_off_tween.tween_property(end, "emitting", end.visible, 0.0).set_delay(end_delay)
	kick_off_tween.tween_property(end_mat, "color", Color.WHITE, WHITE_FLASH_DUR).from(WHITE_FLASH_COLOR)\
		.set_delay(end_delay)
	
## Remove (set emitting to false on all, queue free after 1.0 sec)
func kill() -> void:
	if kick_off_tween:
		kick_off_tween.kill()
	const DUR = 1.0
	var tween := create_tween().set_parallel()
	tween.tween_property(start, "speed_scale", 0.0, DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(trail, "speed_scale", 0.0, DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(end, "speed_scale", 0.0, DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(start, "modulate", Color(.5,.5,.5,0), DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(trail, "modulate", Color(.5,.5,.5,0), DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(end, "modulate", Color(.5,.5,.5,0), DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free).set_delay(DUR)
	

func _on_formula_mode_toggled(on: bool):
	return # FIXME
	if not on:
		kill()

func _on_perk_moved(_new_global_pos: Vector2):
	_setup_trail(_start_perk, _end_perk)

#region Chat rhombus code. woo
const HALF = PI / 8.0    # 22.5 deg
const SPAN = PI / 4.0    # 45 deg total

const SIDE_CENTERS: Dictionary[String, float] = {
	"top_right":    -PI * 0.25,    
	"bottom_right": PI * 0.25,    # 135°
	"bottom_left":  PI * 0.75,    # 225°
	"top_left":     PI * 1.25,    # 315° == -45°
}

const SIDE_SURFACE_ANGLE: Dictionary[String, float] = {
	"top_right":    PI * 0.75 - PI * 0.5,   # 135°
	"bottom_right": PI * 0.25 - PI * 0.5,   # 45°
	"bottom_left":  PI * 1.75 - PI * 0.5,   # 315° or -45°
	"top_left":     PI * 1.25 - PI * 0.5,   # 225° or -135°
}

func side_range(center_angle: float) -> Vector2:
	return Vector2(
		fposmod(center_angle - HALF, TAU),
		fposmod(center_angle + HALF, TAU)
	)

const DIR_SIDES = {
	Vector2.RIGHT: ["top_right", "bottom_right"],
	Vector2.LEFT:  ["top_left", "bottom_left"],
	Vector2.UP:    ["top_left", "top_right"],
	Vector2.DOWN:  ["bottom_left", "bottom_right"],
}
func rand_angle_in_range(start_angle: float, end_angle: float) -> float:
	if start_angle <= end_angle:
		return randf_range(start_angle, end_angle)
	# Wrapped range
	var span = TAU - start_angle + end_angle
	return fposmod(start_angle + randf() * span, TAU)

func point_on_rhombus(angle: float) -> Vector2:
	var dx = cos(angle)
	var dy = sin(angle)
	var _scale = _perk_radius / (abs(dx) + abs(dy))
	return Vector2(dx, dy) * _scale
	
func pick_rhombus_side_point_and_angle(dir: Vector2) -> Dictionary:
	dir = dir.normalized()
	
	var possible_sides: Array = DIR_SIDES.get(dir, [])
	if possible_sides.is_empty():
		push_error("Invalid direction for rhombus side selection")
		return {"point": Vector2.ZERO, "angle": 0.0}

	# Pick one of the two side names
	var side_name: String = possible_sides[randi() % possible_sides.size()]
	var center_angle: float = SIDE_CENTERS[side_name]

	# Compute the narrowed angle range (±22.5°)
	var _range := side_range(center_angle)
	var angle := rand_angle_in_range(_range.x, _range.y)

	# Convert that angle to a rhombus point
	var point := point_on_rhombus(angle)

	# Surface angle for aligning objects
	var surface_angle := SIDE_SURFACE_ANGLE[side_name]

	return {
		"point": point,
		"angle": surface_angle,
	}

#endregion Chat rhombus code. woo
