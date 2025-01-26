extends GPUParticles2D

const APPLE_GREEN = preload("res://assets/image/effects/apple/apple_green.png")
const APPLE_RED = preload("res://assets/image/effects/apple/apple_red.png")

func _ready():
	texture = APPLE_GREEN if randf() > 0.25 else APPLE_RED
	one_shot = true
	emitting = true
	create_tween().tween_callback(queue_free).set_delay(lifetime)
