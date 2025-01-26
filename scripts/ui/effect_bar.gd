extends Node2D

## Holds Effect icons in a horizontal line, smoothly moving icons when effects disappear or appear.
class_name EffectBar

const ICON_OFFSET := Vector2(37, 0)

## The perk effects in order in the bar. 
## (Uses the Perk Type enum because a given Effect Type can be reused across
## different perks, but Effect icons should be 1:1 with Perk icons.)
var effect_types : Array[Perk.Type]

## The tween used to move effects along the bar.
var effect_pos_tween : Tween

func _ready():
	Global.effect_bar = self

func add_effect(effect : Effect):
	add_child(effect)
	# Pick effect position along the bar. If type is already in the bar, 
	# stack this effect on top of the existing effect of same type
	if has_type(effect.perk_type):
		effect.position = get_type_pos(effect.perk_type)
	else:
		effect.position = get_next_effect_pos() 
	effect.reset_physics_interpolation()
	
	# Add type to stored array for purposes of stacking same types
	if not has_type(effect.perk_type):
		effect_types.append(effect.perk_type)

func remove_effect(effect : Effect):
	effect.reparent(Global.ui) # Effect should free itself
	effect.reset_physics_interpolation()
	erase_type_if_absent(effect.perk_type)
	update_effect_positions_by_index()

func get_next_effect_pos() -> Vector2:
	return ICON_OFFSET * effect_types.size()

## Returns whether the given perk type is stored in the bar. 
func has_type(type : Perk.Type):
	return effect_types.has(type)

func get_type_pos(type : Perk.Type):
	return ICON_OFFSET * effect_types.find(type)

## Called after removing an effect type to move effects based on the index of their type.
func update_effect_positions_by_index():
	if effect_pos_tween:
		effect_pos_tween.kill()
	if get_child_count():
		effect_pos_tween = create_tween().set_parallel() 
	
	const DUR := 0.4
	
	for effect : Effect in get_children():
		# Can assume `effect_types` has all possible types of the current children, 
		# since this method is only called after removal
		effect_pos_tween.tween_property(effect, "position:x", get_type_pos(effect.perk_type).x, DUR).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

## Called after removing an effect instance of a given perk type. 
## Removes the perk type from `effect_types` if no effects of that type still exist.
## Necessary because effect_types has no knowledge of how many are left of a given 
## type, so we have to check.
func erase_type_if_absent(type : Perk.Type):
	for effect : Effect in get_children():
		if effect.perk_type == type:
			return # Type still exists, don't erase
	# Type was absent from children, erase it
	effect_types.erase(type)
