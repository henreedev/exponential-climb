extends Node

## PerkModFactory
## Handles the creation of new modifiers, given rarity and quantity values or parent perks.

const PERK_MOD_SCENE: PackedScene = preload("uid://b6gpu6jgdwklf")
const RARITY_CURVE: Curve = preload("uid://clkdtfpfmybwi")
const QUANTITY_CURVE: Curve = preload("uid://sxeykp5alcxc")

## The base budget value of each rarity. Reads from chest rarity cutoffs and 
## inputs them into the rarity curve to receive the value at each cutoff.
@onready var rarity_to_budget: Dictionary[Perk.Rarity, int] = {
	Perk.Rarity.COMMON: _sample_rarity_curve(Chest.RARITY_TO_CUTOFF[Perk.Rarity.COMMON]),
	Perk.Rarity.RARE: _sample_rarity_curve(Chest.RARITY_TO_CUTOFF[Perk.Rarity.RARE]),
	Perk.Rarity.EPIC: _sample_rarity_curve(Chest.RARITY_TO_CUTOFF[Perk.Rarity.EPIC]),
	Perk.Rarity.LEGENDARY: _sample_rarity_curve(Chest.RARITY_TO_CUTOFF[Perk.Rarity.LEGENDARY]),
}

## Creates and returns a perk modifier. 
## If given a parent perk, attaches the mod to the perk after creation. 
## Rarity value is received from the noise map, from 0.0 to 1.0. 
## Quantity value is received from the noise map, from 0.0 to 1.0. 
## Parent perk is used to pick modifier theme if present; otherwise, a random effect's theme is chosen.
## Modifier creation steps:
## 1. Calculate rarity
## 2. Calculate number of effect slots
## 3. Calculate budget
## 4. Choose effects in budget, potentially leaving extra budget
## 5. Enhance effects with remaining budget
## 6. Instantiate modifier with effects
## 7. Try to attach to parent perk and activate
func create_modifier(parent_perk: Perk, rarity_value: float, quantity_value: float) -> PerkMod:
	var rarity: Perk.Rarity = Chest.calculate_rarity_from_value(rarity_value)
	# 1.
	var num_slots: int = _calculate_num_slots(quantity_value)
	# 2.
	var budget: float = _calculate_budget(rarity_value, quantity_value)
	# 3. 
	var result: Array = _select_effects(budget, num_slots, rarity)
	var effects: Array[PerkModEffect] = result[0] as Array[PerkModEffect]
	var remaining_budget = result[1] as float
	# 4.
	_enhance_effects(effects, remaining_budget)
	# 5.
	var modifier: PerkMod = PERK_MOD_SCENE.instantiate()
	modifier.add_effects(effects)
	# 6.
	if parent_perk:
		modifier.try_attach_and_activate(parent_perk)
	
	return modifier

func create_modifier_with_set_rarity(parent_perk: Perk, rarity: Perk.Rarity, bonus_rarity_value: float, quantity_value: float) -> PerkMod:
	return create_modifier(parent_perk, Chest.calculate_rarity_from_value(rarity) + bonus_rarity_value, quantity_value)

## 
func _calculate_budget(rarity_value: float, num_slots: int) -> float:
	var rarity_budget = _sample_rarity_curve(rarity_value)
	var num_slots_factor = 1.0 + (num_slots * 0.1) 
	return rarity_budget * num_slots_factor

func _calculate_num_slots(quantity_value: float) -> int:
	return _sample_quantity_curve(quantity_value)

## Returns an array that looks like [effects: Array[PerkModEffect], remaining_budget: int].
## Effect selection algorithm:
## 1. For first effect, select buff of max rarity
## 	1a. Subtract the rarity's cost from the budget  
## 2. Next effect(s): Roll if buff/nerf
func _select_effects(budget: float, num_slots: int, max_rarity: Perk.Rarity) -> Array:
	var effects: Array[PerkModEffect]
	
	
	return effects

## Adds an effect to the input array and returns the remaining budget. 
func _add_effect_using_budget(effects: Array[PerkModEffect], budget: float, num_slots: int, used_slots: int, max_rarity: Perk.Rarity) -> float:
	return budget # TODO

## Tries to select a random effect of the given theme and rarity from the effect pool.  


## Mutates the effects array, potentially changing properties of each effect in the array. 
## Iteratively applies enhancements from a weighted pool until budget is fully drained. 
func _enhance_effects(effects: Array[PerkModEffect], budget: int) -> void:
	pass

#region Helpers
func _sample_rarity_curve(x_value: float) -> float:
	return RARITY_CURVE.sample_baked(x_value)
## Returns num_slots.
func _sample_quantity_curve(x_value: float) -> int:
	return int(QUANTITY_CURVE.sample_baked(x_value))
#endregion Helpers
