extends GPUParticles2D

class_name OneshotParticles

func _ready():
	one_shot = true
	emitting = true
	create_tween().tween_callback(queue_free).set_delay(lifetime)
