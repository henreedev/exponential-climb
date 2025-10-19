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

## Used to store the modifier's categories and weight them when rolling a new effect's category.
var _categories_by_weight: Dictionary[Perk.Category, float]

## Creates and returns a perk modifier. 
## If given a parent perk, attaches the mod to the perk after creation. 
## Rarity value is received from the noise map, from 0.0 to 1.0. 
## Quantity value is received from the noise map, from 0.0 to 1.0. 
## Parent perk is used to pick modifier category if present; otherwise, a random effect's category is chosen.
## Modifier creation steps:
## 1. Calculate setup values
##   - Calculate rarity
##   - Calculate category weights
##   - Calculate number of effect slots
##   - Calculate budget
## 2. Choose effects in budget, potentially leaving extra budget
## 3. Enhance effects with remaining budget
## 4. Setup and return modifier instance
##   - Instantiate modifier with effects
##   - Try to attach to parent perk and activate
func create_modifier(parent_perk: Perk, rarity_value: float, quantity_value: float) -> PerkMod:
	# 1.
	var rarity: Perk.Rarity = Chest.calculate_rarity_from_value(rarity_value)
	_set_categories_and_weights(parent_perk, rarity)
	var num_slots: int = _calculate_num_slots(quantity_value)
	var budget: float = _calculate_budget(rarity_value, quantity_value)
	
	# 2.
	var result: Array = _select_effects(budget, num_slots, rarity)
	var effects: Array[PerkModEffect] = result[0] as Array[PerkModEffect]
	var remaining_budget = result[1] as float
	
	# 3. 
	_enhance_effects(effects, remaining_budget)
	
	# 4.
	var modifier: PerkMod = PERK_MOD_SCENE.instantiate()
	modifier.add_effects(effects)
	if parent_perk:
		modifier.try_attach_and_activate(parent_perk)
	
	return modifier

func create_modifier_with_set_rarity(parent_perk: Perk, rarity: Perk.Rarity, bonus_rarity_value: float, quantity_value: float) -> PerkMod:
	return create_modifier(parent_perk, Chest.calculate_rarity_from_value(rarity) + bonus_rarity_value, quantity_value)

#region 1.
## If parent_perk is non-null, uses its primary and secondary categories (if unique), 
##   or primary category + random other category as the two categories to weight.
## Otherwise, picks a random effect by given rarity and uses it as the primary category, 
##   then picks a random other secondary category from any rarity.
func _set_categories_and_weights(parent_perk: Perk, rarity: Perk.Rarity):
	var primary_category: Perk.Category
	var secondary_category: Perk.Category
	# Selection
	if parent_perk:
		primary_category = parent_perk.primary_category
		secondary_category = parent_perk.secondary_category
		if primary_category == secondary_category:
			# Try to find a different secondary category
			var rand_effect := PerkModEffectPool.select_random_effect_of_different_category(primary_category)
			if rand_effect:
				secondary_category = rand_effect.category
	else:
		var rand_effect := PerkModEffectPool.select_random_effect_of_rarity(rarity)
		primary_category = rand_effect.category
		rand_effect = PerkModEffectPool.select_random_effect_of_different_category(primary_category)
		if rand_effect:
			secondary_category = rand_effect.category
		else:
			secondary_category = primary_category
	# Weighting
	_categories_by_weight[primary_category] = 1.0
	_categories_by_weight[secondary_category] = randf_range(0.0, 0.4)

func _calculate_budget(rarity_value: float, num_slots: int) -> float:
	var rarity_budget = _sample_rarity_curve(rarity_value)
	var num_slots_factor = 1.0 + (num_slots * 0.1) 
	return rarity_budget * num_slots_factor

func _calculate_num_slots(quantity_value: float) -> int:
	return _sample_quantity_curve(quantity_value)
#endregion 1.

#region 2.
## Returns an array that looks like [effects: Array[PerkModEffect], remaining_budget: int].
## Effect selection algorithm:
## 1. For first effect, select buff of max rarity
## 	1a. Subtract the rarity's cost from the budget  
## 2. Next effect(s): Roll if buff/nerf
func _select_effects(budget: float, num_slots: int, max_rarity: Perk.Rarity) -> Array:
	var effects: Array[PerkModEffect]
	var remaining_slots := num_slots
	var remaining_budget := budget
	while remaining_slots > 0:
		remaining_budget = _add_effect_using_budget(effects, remaining_budget, num_slots, remaining_slots, max_rarity)
	return [effects, remaining_budget]

## Adds an effect to the input array and returns the remaining budget. 
func _add_effect_using_budget(effects: Array[PerkModEffect], budget: float, num_slots: int, remaining_slots: int, max_rarity: Perk.Rarity) -> float:
	var nerf_chance: float = _calculate_nerf_chance(budget, num_slots, remaining_slots, max_rarity)
	if randf() < nerf_chance:
		# TODO grab nerf from pool, of rarity anywhere from max to common,
	else:
		# TODO grab buff from pool of maximum rarity given budget
	return budget # TODO

func _calculate_nerf_chance(budget: float, num_slots: int, remaining_slots: int, max_rarity: Perk.Rarity) -> float:
	# Never make the first effect a nerf.
	if num_slots == remaining_slots:
		return 0.0
	
	var nerf_chance := 0.0
	
	# As budget approaches 0 from max_rarity, increase nerf chance
	var budget_chance = lerpf(0.0, 1.0, inverse_lerp(rarity_to_budget[max_rarity], 0.0, budget))
	nerf_chance += budget_chance
	
	var current_slot_dist_from_0 = num_slots - remaining_slots
	var slots_chance = current_slot_dist_from_0 * 0.05
	nerf_chance += slots_chance
	
	return nerf_chance
	

#endregion 2.


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
