extends Node

## PerkModFactory
## Handles the creation of new modifiers, given rarity and quantity values or parent perks.

const PERK_MOD_SCENE: PackedScene = preload("uid://b6gpu6jgdwklf")

## Creates and returns a perk modifier. 
## If given a parent perk, attaches the mod to the perk after creation. 
## Rarity value is received from the noise map, from 0.0 to 1.0. 
## Quantity value is received from the noise map, from 0.0 to 1.0. 
## Parent perk is used to pick modifier theme if present; otherwise, a random effect's theme is chosen.
## Modifier creation steps:
## 1. Calculate budget
## 2. Calculate number of effect slots
## 3. Choose effects in budget, potentially leaving extra budget
## 4. Enhance effects with remaining budget
## 5. Instantiate modifier with effects
## 6. Try to attach to parent perk and activate
func create_modifier(parent_perk: Perk, rarity_value: float, quantity_value: float) -> PerkMod:
	# 1.
	var budget: int = _calculate_budget(rarity_value, quantity_value)
	# 2.
	var num_slots: int = _calculate_num_slots(quantity_value)
	# 3. 
	var result: Array = _select_effects(budget, num_slots)
	var effects: Array[PerkModEffect] = result[0] as Array[PerkModEffect]
	var remaining_budget = result[1] as int
	# 4.
	_enhance_effects(effects, remaining_budget)
	# 5.
	var modifier: PerkMod = PERK_MOD_SCENE.instantiate()
	modifier.add_effects(effects)
	# 6.
	if parent_perk:
		modifier.try_attach_and_activate(parent_perk)
	
	return modifier

## 
func _calculate_budget(rarity_value: float, quantity_value: float) -> int:
	
	return 0

func _calculate_num_slots(quantity_value: float) -> int:
	
	return 3

## Returns an array that looks like [effects: Array[PerkModEffect], remaining_budget: int].
func _select_effects(budget: int, num_slots: int) -> Array:
	var effects: Array[PerkModEffect]
	
	
	return effects

## Mutates the effects array, potentially changing properties of each effect in the array. 
func _enhance_effects(effects: Array[PerkModEffect], remaining_budget: int) -> void:
	pass
