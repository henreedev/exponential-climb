extends AnimatedSprite2D

class_name Ignite

var total_damage := 0.0
var duration := 0.0
var parent_hitbox: Hitbox

## Calculated in reset_duration.
var dps : float
var duration_timer := 0.0
var rand_pos_offset := Vector2(randf_range(-4, 4), randf_range(-4, 4))

func reset_duration():
	assert(duration != 0)
	duration_timer = duration
	dps = total_damage / duration

func _ready():
	reset_duration()
	#var tween := create_tween()
	#tween.tween_property(self, "modulate", Color.WHITE, 0.5).from(Color.WHITE * 2)
	global_position = parent_hitbox.global_position + Vector2(0, -4) + rand_pos_offset
	reset_physics_interpolation()

var i := 0

func _physics_process(delta: float) -> void:
	if duration_timer > 0:
		duration_timer -= delta
		if duration_timer <= 0.0 or not parent_hitbox:
			end()
			return
		else:
			global_position = parent_hitbox.global_position + Vector2(0, -4) + rand_pos_offset
	i += 1
	if i % 120 == 0:
		delta *= 120
		parent_hitbox.take_damage(dps * delta, DamageNumber.DamageColor.IGNITE) 


func end():
	queue_free()
