extends Area2D
## Particle that contains loop speed / loop energy and can be ingested by enemies.
## Spreads out from player on player death and then flies into a random enemy.
## On environment interaction, flies to player along a curved path. 
class_name LoopFragment

var been_ingested := false
var can_ingest := false

var loop_energy := 0.0


var target: Node2D
var target_position: Vector2
var velocity := Vector2.ZERO
var temporary_slow := 0.0

# Used on ready
var next_target: Node2D
var next_target_delay: float
const LOOP_FRAGMENT = preload("uid://cujdvbb7gcd1o")

static func create(_loop_energy: float, _target_position: Vector2, _next_target: Node2D, _next_target_delay: float) -> LoopFragment:
	var frag: LoopFragment = LOOP_FRAGMENT.instantiate()
	
	frag.loop_energy = _loop_energy
	frag.target_position = _target_position
	frag.next_target = _next_target
	frag.next_target_delay = _next_target_delay
	
	return frag

func _ready() -> void:
	# Move to position for certain duration, then allow ingestion and move towards target
	var tween = create_tween()
	tween.tween_property(self, "can_ingest", true, next_target_delay)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * (1.0 + loop_energy * 5), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_callback(set_target.bind(next_target))

func _physics_process(delta: float) -> void:
	if been_ingested:
		rotation += TAU * delta * 1.5
		return
	if target:
		target_position = target.global_position
	
	var dist = global_position.distance_to(target_position)
	var dir = global_position.direction_to(target_position)

	const MAX_SPEED = 800.0
	const DIST_FACTOR = 20
	var desired_vel = dir * minf(pow(dist, 0.75) * DIST_FACTOR, MAX_SPEED) * (1.0 - temporary_slow)
	velocity = lerp(velocity, desired_vel, 10.0 * delta)

	var desired_rot = velocity.angle() + -PI / 2.0
	rotation = lerp_angle(rotation, desired_rot, 5 * delta)
	
	temporary_slow = maxf(0, temporary_slow - delta)
	
	global_position += velocity * delta

func set_target(_target: Node2D):
	target = _target
	temporary_slow = 0.0

## Triggers on enemies or players using collision mask.
func _on_area_entered(area: Area2D) -> void:
	if not been_ingested and can_ingest:
		var parent = area.get_parent()
		set_target(parent)
		parent.receive_loop_energy(loop_energy)
		been_ingested = true
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.5)
		tween.tween_callback(queue_free)
