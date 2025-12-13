extends AnimatedSprite2D

class_name Balloon

## Populated by initializer
var parent_enemy: Enemy
var stored_damage : float
var duration : float

var damage_mult_per_second := 0.1
var damage_mult := 0.5
var upward_force := Vector2(0, randf_range(-Global.GRAVITY, -Global.GRAVITY - 100))

func _ready():
	play("grow")

func _physics_process(delta: float) -> void:
	if duration > 0:
		if not parent_enemy or not is_instance_valid(parent_enemy):
			duration = 0.0
			pop(false)
			return
		duration -= delta
		if parent_enemy.is_on_ceiling():
			pop(true)
			duration = 0.0
		elif duration <= 0.0:
			pop(false)
		set_pos_to_parent_pos_with_offset()
		parent_enemy.velocity += upward_force * delta
		damage_mult += damage_mult_per_second * delta

func set_pos_to_parent_pos_with_offset():
	const OFFSET = Vector2(0, -12)
	global_position = parent_enemy.global_position + OFFSET

func pop(deal_damage := false):
	if parent_enemy and deal_damage:
		parent_enemy.take_damage(stored_damage * damage_mult)
	play("pop")

func _on_animation_finished() -> void:
	if animation == "grow":
		play("default")
	elif animation == "pop":
		queue_free()
