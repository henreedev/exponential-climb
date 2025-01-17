extends Label

## A singular damage number object that spawns into the game scene, then frees itself. 
class_name DamageNumber

const LABEL_SETTINGS_RESOURCE = preload("res://resources/utilities/damage_number_label_settings.tres")
const DELETING_SCALE = Vector2(0.33, 0.33)
const DELETING_FONT_SIZE = 1
const SMALLEST_SIZE_DAMAGE = 1.0
const LARGEST_SIZE_DAMAGE = 100.0
const SMALLEST_SCALE = 1.0
const LARGEST_SCALE = 2.0

## The scale to grow to, calculated based on the damage value. More damage == larger label.
var grow_to_scale : Vector2 

func set_label_settings_to_new_copy():
	label_settings = LABEL_SETTINGS_RESOURCE.duplicate()

func setup(damage : float, pos : Vector2) -> void:
	set_label_settings_to_new_copy()
	text = str(damage).pad_decimals(1)
	pivot_offset = size / 2.0
	position = pos - pivot_offset
	grow_to_scale = get_grow_to_scale(damage)
	scale = grow_to_scale

func get_grow_to_scale(damage : int):
	var fraction = fraction_between(SMALLEST_SIZE_DAMAGE, LARGEST_SIZE_DAMAGE, damage)
	var scale_val = lerpf(SMALLEST_SCALE, LARGEST_SCALE, smoothstep(0, 1, fraction))
	return Vector2(scale_val, scale_val)

static func fraction_between(min : float, max : float, value : float):
	var fraction = (value - min) / (max - min)
	return clampf(fraction, 0, 1)
	

func _ready():
	#setup(100, Vector2.ZERO)
	var tween = create_tween()
	
	# Pop up and grow
	var rise_height = 10 * grow_to_scale.x
	var rand_vert_movement = randf_range(rise_height * 0.5, rise_height * 1.5)
	var rand_hoz_movement = randf_range(-8, 8)
	const RISE_DUR = 0.35
	tween.tween_property(self, "position:y", position.y - rand_vert_movement, RISE_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, RISE_DUR).set_ease(Tween.EASE_OUT).from(Color.WHITE * 2)
	tween.parallel().tween_property(self, "position:x", position.x + rand_hoz_movement, RISE_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label_settings, "font_size", 16, RISE_DUR * 1.2).from(1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	# Wait a bit
	const WAIT_DUR = 0.1
	tween.tween_interval(WAIT_DUR)
	
	# Shrink and delete
	const DELETE_DUR = 0.5
	tween.tween_property(label_settings, "font_size", DELETING_FONT_SIZE, DELETE_DUR)
	#tween.parallel().tween_property(self, "scale", DELETING_SCALE, DELETE_DUR)
	tween.parallel().tween_property(self, "modulate:a", 0.2, DELETE_DUR).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "self_modulate", Color.BLACK, DELETE_DUR)
	tween.tween_callback(queue_free)
