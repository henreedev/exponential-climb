extends Control

## The UI card showing information about a perk.
class_name PerkCard

## Jobs: 
## 1. Be refreshable
## 	1a. Refresh visuals - bg tex, cooldown icon, trigger icon
## 	1b. Refresh values - perk stats
## 2. Init name, desc, etc. from perk
## 3. Be showable and hideable
@onready var background: TextureRect = $Background
@onready var power_label: Label = %PowerLabel
@onready var loop_label: Label = %LoopLabel
@onready var cooldown_icon: TextureRect = $Background/CooldownIcon
@onready var cooldown_label: Label = %CooldownLabel
@onready var activations_label: Label = %ActivationsLabel
@onready var trigger_icon: TextureRect = %TriggerIcon
@onready var rarity_type_descriptor: RarityTypeDescriptor = $RarityTypeDescriptor
@onready var perk_name_label: Label = $PerkNameLabel
@onready var perk_description_label: Label = $PerkDescriptionLabel

const ACTIVE_BG = preload("uid://b1u8uj1wv7tao")
const PASSIVE_BG = preload("uid://wcekbw4exanq")

var parent_perk: Perk

func init_with_perk(perk: Perk):
	parent_perk = perk
	init_text()
	refresh()
	_prepare_hidden_state()
	_adjust_font_color_for_active()
	_connect_refresh_signals()

func _connect_refresh_signals():
	parent_perk.any_stat_updated.connect(refresh)
	parent_perk.context_updated.connect(refresh)

func _prepare_hidden_state():
	showing = true
	hide_card()

func _adjust_font_color_for_active():
	if parent_perk.is_active:
		perk_description_label.label_settings = \
			perk_description_label.label_settings.duplicate_deep()
		perk_description_label.label_settings.font_color = Color.BLACK
		perk_description_label.label_settings.shadow_color.a = 0.1
		
		var stylebox: StyleBoxFlat = perk_description_label.get_theme_stylebox("normal")
		stylebox.border_color = Color(0.61, 0.61, 0.61)
		
		perk_name_label.label_settings = \
			perk_name_label.label_settings.duplicate_deep()
		perk_name_label.label_settings.font_color = Color.BLACK
		perk_name_label.label_settings.shadow_color.a = 0.1

func init_text():
	var perk_type = "PASSIVE" if not parent_perk.is_active else ("ACTIVE TRIGGER" if parent_perk.is_trigger else "ACTIVE") 
	rarity_type_descriptor.set_descriptor_text(parent_perk.rarity, perk_type)
	
	perk_name_label.text = parent_perk.display_name
	# Downsize perk name label
	var num_chars = perk_name_label.text.length()
	const MAX_FIT_CHARS = 10
	for i in range(maxf(0, num_chars - MAX_FIT_CHARS)):
		perk_name_label.scale *= 0.95
	
	perk_description_label.text = parent_perk.description

func refresh():
	print("Refreshing perk card for perk ", parent_perk.code_name)
	# Refresh visuals
	background.texture = ACTIVE_BG if parent_perk.is_active else PASSIVE_BG
	trigger_icon.visible = parent_perk.is_trigger
	cooldown_icon.visible = parent_perk.is_active
	
	# Refresh numbers
	const SECOND_SUFFIX := "s"
	power_label.text = get_float_string_with_fewest_decimals(parent_perk.power.value())
	if parent_perk.is_active:
		loop_label.text = get_float_string_with_fewest_decimals(parent_perk.runtime.value()) + SECOND_SUFFIX
	else:
		loop_label.text = get_float_string_with_fewest_decimals(parent_perk.loop_cost.value())
	if cooldown_icon.visible:
		cooldown_label.text = get_float_string_with_fewest_decimals(parent_perk.cooldown.value()) + SECOND_SUFFIX
	
	const ACTIVATIONS_SUFFIX := "x"
	activations_label.text = str(parent_perk.activations.value()) + ACTIVATIONS_SUFFIX
	
var visibility_tween: Tween
var showing := false
func show_card():
	if not showing:
		showing = true
		if visibility_tween:
			visibility_tween.kill()
		visibility_tween = create_tween()
		visibility_tween.tween_interval(.25)
		visibility_tween.tween_callback(show)
		visibility_tween.tween_property(self, "scale", Vector2.ONE, .2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		visibility_tween.parallel().tween_property(self, "modulate", Color.WHITE, .2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	

func hide_card():
	if showing:
		showing = false
		if visibility_tween:
			visibility_tween.kill()
		visibility_tween = create_tween()
		visibility_tween.tween_property(self, "scale", Vector2.ONE * .95, .2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		visibility_tween.parallel().tween_property(self, "modulate", Color(5, 5, 5, 0), .2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		visibility_tween.tween_callback(hide)


static func get_float_string_with_fewest_decimals(val: float) -> String:
	if int(val) == val:
		return str(val).pad_decimals(0)
	if int(val * 10) == val * 10:
		return str(val).pad_decimals(1)
	else:
		return str(val).pad_decimals(2)
