extends Label

## A singular damage number object that spawns into the game scene, then frees itself. 
class_name DamageNumber

enum DamageColor {
	DEFAULT, 
	MEDIUM_DAMAGE, 
	HIGH_DAMAGE, 
	VERY_HIGH_DAMAGE, 
	CRIT,
	HEAL,
	ENEMY,
	IGNITE,
}
@export_subgroup("Thresholds")
@export_range(1, 1000, 1) var medium_damage := 50
@export_range(1, 1000, 1) var high_damage := 100
@export_range(1, 1000, 1) var very_high_damage := 150

@export_subgroup("Colors")
@export var default_color := Color.WHITE
@export var medium_color := Color(1, .96, .52)
@export var high_color := Color(1, .77, .52)
@export var very_high_color := Color(1, .62, .52)
@export var crit_color := Color(.81, .81, .29)
@export var heal_color := Color(.46, .83, .51)
@export var enemy_color := Color(.58, .40, .78)
@export var ignite_color := Color(1, .80, 0)

var DAMAGE_COLORS : Dictionary[DamageColor, Color] = {
	DamageColor.DEFAULT : default_color,
	DamageColor.MEDIUM_DAMAGE : medium_color,
	DamageColor.HIGH_DAMAGE : high_color,
	DamageColor.VERY_HIGH_DAMAGE : very_high_color,
	DamageColor.CRIT : crit_color,
	DamageColor.HEAL : heal_color,
	DamageColor.ENEMY : enemy_color,
	DamageColor.IGNITE : ignite_color,
}

const LABEL_SETTINGS_RESOURCE = preload("res://resources/utilities/damage_number_label_settings.tres")
const DELETING_SCALE = Vector2(0.33, 0.33)
const DELETING_FONT_SIZE = 1
const SMALLEST_SIZE_DAMAGE = 1.0
const LARGEST_SIZE_DAMAGE = 200.0
const SMALLEST_SCALE = 1.0
const LARGEST_SCALE = 2.0



## The scale to grow to, calculated based on the damage value. More damage == larger label.
var grow_to_scale : Vector2 

func set_label_settings_to_new_copy():
	label_settings = LABEL_SETTINGS_RESOURCE.duplicate()

func setup(damage : int, pos : Vector2, damage_color : DamageColor = DamageColor.DEFAULT, use_debug := false, debug_float := 0.0, debug_string := "") -> void:
	set_label_settings_to_new_copy()
	if use_debug:
		if debug_float:
			text = str(debug_float).pad_decimals(1)
		elif debug_string:
			text = debug_string
	else:
		text = str(damage)
	if damage_color == DamageColor.DEFAULT:
		if damage > very_high_damage:
			damage_color = DamageColor.VERY_HIGH_DAMAGE
		elif damage > high_damage:
			damage_color = DamageColor.HIGH_DAMAGE
		elif damage > medium_damage:
			damage_color = DamageColor.MEDIUM_DAMAGE
	label_settings.font_color = DAMAGE_COLORS[damage_color]
	pivot_offset = size / 2.0
	position = pos - pivot_offset
	grow_to_scale = get_grow_to_scale(damage)
	scale = grow_to_scale

func get_grow_to_scale(damage : int):
	var fraction = fraction_between(SMALLEST_SIZE_DAMAGE, LARGEST_SIZE_DAMAGE, damage)
	var scale_val = lerpf(SMALLEST_SCALE, LARGEST_SCALE, fraction)
	return Vector2(int(scale_val), int(scale_val))



static func fraction_between(min : float, max : float, value : float):
	var fraction = (value - min) / (max - min)
	return clampf(fraction, 0, 1)
	

func _ready():
	if text == "0":
		queue_free()
		return
	
	var tween = create_tween()
	
	# Pop up and grow
	var rise_height = 10 * grow_to_scale.x
	var rand_vert_movement = randf_range(rise_height * 0.5, rise_height * 1.5)
	var rand_hoz_movement = randf_range(-8, 8)
	const RISE_DUR = 0.35
	tween.tween_property(self, "position:y", position.y - rand_vert_movement, RISE_DUR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, RISE_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).from(Color.WHITE * 2)
	tween.parallel().tween_property(self, "position:x", position.x + rand_hoz_movement, RISE_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label_settings, "font_size", 16, RISE_DUR * 1.2).from(1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	# Wait a bit
	const WAIT_DUR = 0.15
	tween.tween_interval(WAIT_DUR)
	
	# Shrink and delete
	const DELETE_DUR = 0.5
	tween.tween_property(label_settings, "font_size", DELETING_FONT_SIZE, DELETE_DUR).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(self, "modulate:a", 0.2, DELETE_DUR).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "self_modulate", Color.BLACK, DELETE_DUR)
	tween.tween_callback(queue_free)
