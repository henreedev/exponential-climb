extends Area2D
class_name BouncyLine

signal touched(hit_position: Vector2, hit_direction: Vector2)

const stiffness: float = 500.0
const damping: float = 3.0
const max_displacement: float = 400.0
const max_velocity: float = 50000.0

const influence_radius: float = 100.0
const cooldown_time: float = 0.0

const end_lock_strength: float = 0.2
const locked_end_points: int = 1
const edge_falloff_points: int = 20

@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var line: Line2D = $Line2D

var _base_points: PackedVector2Array
var _velocities: PackedFloat32Array
var _cooldown_timer: float = 0.0

func _ready() -> void:
	line.top_level = true
	_sync_line_transform()
	_generate_points_from_collision_shape()
	_velocities.resize(_base_points.size())
	_velocities.fill(0.0)


func _sync_line_transform() -> void:
	line.global_position = global_position
	line.global_rotation = global_rotation


func _generate_points_from_collision_shape() -> void:
	var shape := collision_shape_2d.shape
	if shape == null or not shape is RectangleShape2D:
		push_error("BouncyLine requires a RectangleShape2D")
		return

	# Include parent scale (line will NOT inherit it)
	var global_width = shape.size.x * global_scale.x
	var point_count := int(global_width)

	if point_count <= 1:
		push_error("CollisionShape2D width too small")
		return

	line.clear_points()

	var half_width = global_width * 0.5

	for i in range(point_count):
		var x = float(i) - half_width
		line.add_point(Vector2(x, 0.0))

	_base_points = line.points.duplicate()



func _process(delta: float) -> void:
	_update_cooldown(delta)
	_update_springs(delta)

func _update_cooldown(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func _update_springs(delta: float) -> void:
	for i in range(line.points.size()):
		if _is_point_locked(i):
			line.points[i] = _base_points[i]
			_velocities[i] = 0.0
			continue

		var displacement_y := line.points[i].y - _base_points[i].y

		var accel := (-stiffness * displacement_y) - (damping * _velocities[i])
		_velocities[i] += accel * delta
		_velocities[i] = clamp(_velocities[i], -max_velocity, max_velocity)

		var new_y := line.points[i].y + _velocities[i] * delta
		var min_y := _base_points[i].y - max_displacement
		var max_y := _base_points[i].y + max_displacement
		line.points[i].y = clamp(new_y, min_y, max_y)


func _is_point_locked(index: int) -> bool:
	if index < locked_end_points:
		return true
	if index >= line.points.size() - locked_end_points:
		return true
	return false

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if _cooldown_timer > 0.0:
		return

	_cooldown_timer = cooldown_time

	var player_velocity: Vector2 = Global.player.velocity

	# Line direction based on this node's rotation
	var line_direction: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	
	# Reflect velocity
	var reflected_velocity := player_velocity.reflect(line_direction)
	
	# Add bonus speed tangent to line
	var velocity_along_line := player_velocity.project(line_direction)
	reflected_velocity += velocity_along_line * 0.1

	# Apply impulse difference with bonus to new direction
	var impulse := reflected_velocity * 1.2 - player_velocity
	#const apply_dur := 0.075
	#create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_method(
		#Global.player.add_force,
		#impulse / apply_dur, 
		#impulse / apply_dur, 
		#apply_dur 
	#)
	Global.player.add_impulse(impulse)
	

	var player_global_position: Vector2 = Global.player.global_position
	apply_hit(player_global_position, player_velocity.normalized(), player_velocity.length())

func apply_hit(hit_position: Vector2, hit_direction: Vector2, force: float = 1.0) -> void:
	touched.emit(hit_position, hit_direction)

	var local_hit := line.to_local(hit_position)
	var dir := hit_direction.normalized()

	for i in range(line.points.size()):
		if _is_point_locked(i):
			continue

		var point_to_hit := local_hit - line.points[i]
		var dist := float(abs(point_to_hit.x))

		if dist > influence_radius:
			continue

		var falloff := 1.0 - (dist / influence_radius)
		falloff = smoothstep(0, 1, falloff)

		# Linear edge resistance across a wide band
		var edge_dist = min(i, line.points.size() - 1 - i)

		var edge_factor := 1.0
		if edge_dist < edge_falloff_points:
			var t := float(edge_dist) / float(edge_falloff_points)
			t = smoothstep(0,1,t) # smoothstep
			edge_factor = lerp(end_lock_strength, 1.0, t)

		var impulse := dir.y * force * falloff * edge_factor
		_velocities[i] += impulse
