extends Node

## PerkModFactory
## Handles the creation of new modifiers, given rarity and quantity values or parent perks.

## Debug toggle: set false to silence all debug prints.
const DEBUG_LOG := false

enum EnhancementType {
	ADD_DIRECTION,
	SET_SCOPE_ALL,
	ADD_POWER,
}

const BASE_ADD_POWER_MULTIPLIER := 0.05

const ENHANCEMENT_TYPE_TO_BUDGET_COST: Dictionary[EnhancementType, float] = {
	EnhancementType.ADD_DIRECTION : 2.5,
	EnhancementType.SET_SCOPE_ALL : 4.0,
	EnhancementType.ADD_POWER : 0.2,
}
const RARITY_TO_ENHANCEMENT_BUDGET_COST_MULT: Dictionary[Perk.Rarity, float] = {
	Perk.Rarity.COMMON: 0.75,
	Perk.Rarity.RARE: 1.0,
	Perk.Rarity.EPIC: 2.0,
	Perk.Rarity.LEGENDARY: 3.0,
}

## Weights used in the random selection of directions on a buff effect.
const BUFF_DIR_TO_WEIGHT: Dictionary[PerkMod.Direction, float] = {
	PerkMod.Direction.SELF: 0.10,
	PerkMod.Direction.LEFT: 0.25,
	PerkMod.Direction.RIGHT: 0.25,
	PerkMod.Direction.UP: 0.20,
	PerkMod.Direction.DOWN: 0.20,
}

## Weights used in the random selection of directions on a nerf effect.
const NERF_DIR_TO_WEIGHT: Dictionary[PerkMod.Direction, float] = {
	PerkMod.Direction.SELF: 0.30,
	PerkMod.Direction.LEFT: 0.15,
	PerkMod.Direction.RIGHT: 0.15,
	PerkMod.Direction.UP: 0.15,
	PerkMod.Direction.DOWN: 0.15,
}

## Weights used in the random selection of scopes on an effect.
const SCOPE_TO_WEIGHT: Dictionary[PerkModEffect.Scope, float] = {
	PerkModEffect.Scope.NEIGHBOR: 0.5,
	PerkModEffect.Scope.SECOND_NEIGHBOR: 0.3,
	PerkModEffect.Scope.ALL: 0.2,
}

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

#region Public methods
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
	if DEBUG_LOG:
		print("create_modifier() start — parent_perk:", parent_perk, " rarity_value:", rarity_value, " quantity_value:", quantity_value)
	
	# 1.
	var rarity: Perk.Rarity = Chest.calculate_rarity_from_value(rarity_value)
	_set_categories_and_weights(parent_perk, rarity)
	var num_slots: int = _calculate_num_slots(quantity_value)
	var budget: float = _calculate_budget(rarity_value, num_slots)
	
	if DEBUG_LOG:
		print("create_modifier: rarity =", rarity, " num_slots =", num_slots, " initial_budget =", budget)

	# 2.
	var result: Array = _select_effects(budget, num_slots, rarity)
	var effects: Array[PerkModEffect] = result[0] as Array[PerkModEffect]
	var remaining_budget = result[1] as float
	
	if DEBUG_LOG:
		print("create_modifier: selected", effects.size(), " effects; remaining_budget =", remaining_budget)
		print("create_modifier: effects list:", effects)
	
	# 3. 
	_enhance_effects(effects, remaining_budget)
	
	# 4.
	var modifier: PerkMod = PERK_MOD_SCENE.instantiate()
	modifier.add_effects(effects)
	
	Global.perk_ui.add_child(modifier)
	
	if parent_perk:
		var attached := modifier.try_attach_and_activate(parent_perk)
		assert(attached, "Should only generate a modifier for a perk that goes in the directions it can hold?")
	
	_categories_by_weight.clear()
	
	if DEBUG_LOG:
		print("create_modifier: instantiated modifier:", modifier, " final_effect_count: ", effects.size())
		if parent_perk:
			print("create_modifier: attempted attach to parent_perk:", parent_perk)

	return modifier

func create_modifier_with_set_rarity(parent_perk: Perk, rarity: Perk.Rarity, bonus_rarity_value: float, quantity_value: float) -> PerkMod:
	return create_modifier(parent_perk, Chest.calculate_rarity_from_value(rarity) + bonus_rarity_value, quantity_value)
#endregion Public methods

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
	const PRIMARY_WEIGHT = 1.0
	var secondary_weight = randf_range(0.0, 0.4)
	var total = PRIMARY_WEIGHT + secondary_weight
	
	# Divide by total so weights add to 1.0
	_categories_by_weight[primary_category] = PRIMARY_WEIGHT / total
	_categories_by_weight[secondary_category] = secondary_weight / total

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
		remaining_slots -= 1
	return [effects, remaining_budget]

## Adds an effect to the input array and returns the remaining budget. 
func _add_effect_using_budget(effects: Array[PerkModEffect], budget: float, num_slots: int, remaining_slots: int, max_rarity: Perk.Rarity) -> float:
	if DEBUG_LOG:
		print("_add_effect_using_budget: entering — budget=", budget, " num_slots=", num_slots, " remaining_slots=", remaining_slots, " max_rarity=", max_rarity)
	var nerf_chance: float = _calculate_nerf_chance(budget, num_slots, remaining_slots, max_rarity)
	if randf() < nerf_chance:
		# Grab nerf from pool of rarity anywhere from max to common,
		var nerf_budget = randf_range(rarity_to_budget[Perk.Rarity.COMMON], rarity_to_budget[max_rarity] + 3)
		var nerf_rarity: Perk.Rarity = _calculate_max_rarity_in_budget(nerf_budget, max_rarity)
		var nerf_effect = _select_effect_from_pool(nerf_rarity, PerkModEffect.Polarity.NERF)
		effects.append(nerf_effect)
		
		# Add budget based on nerf rarity
		budget += rarity_to_budget[nerf_rarity]
		
		if DEBUG_LOG:
			print("_add_effect_using_budget: picked NERF ->", nerf_effect, " nerf_rarity=", nerf_rarity, " new_budget=", budget)
	else:
		# Grab buff from pool of maximum rarity given budget
		var is_first_effect := num_slots == remaining_slots
		var buff_rarity = _calculate_max_rarity_in_budget(budget, max_rarity)
		# Use primary category if first effect.
		var category_override = _categories_by_weight.keys()[0] if is_first_effect else null
		var buff_effect = _select_effect_from_pool(buff_rarity, PerkModEffect.Polarity.BUFF, category_override)
		effects.append(buff_effect)
		
		budget -= rarity_to_budget[buff_rarity]
		
		if DEBUG_LOG:
			print("_add_effect_using_budget: picked BUFF ->", buff_effect, " buff_rarity=", buff_rarity, " category_override=", category_override, " new_budget=", budget)
	
	return budget

func _calculate_nerf_chance(budget: float, num_slots: int, remaining_slots: int, max_rarity: Perk.Rarity) -> float:
	# Never make the first effect a nerf.
	if num_slots == remaining_slots:
		return 0.0
	
	var nerf_chance := 0.0
	
	# As budget approaches 0 from max_rarity, increase nerf chance
	# NOTE use pow() here if nerfs are too frequent
	var budget_chance = inverse_lerp(rarity_to_budget[max_rarity], 0.0, budget)
	budget_chance = pow(budget_chance, 2)
	nerf_chance += budget_chance
	
	# As further slots are used, increase nerf chance. 
	var current_slot_dist_from_0 = num_slots - remaining_slots
	var slots_chance = current_slot_dist_from_0 * 0.05
	nerf_chance += slots_chance
	
	if DEBUG_LOG:
		print("_calculate_nerf_chance: budget=", budget, " num_slots=", num_slots, " remaining_slots=", remaining_slots, " max_rarity=", max_rarity, " nerf_chance=", nerf_chance)
	
	return nerf_chance

func _select_effect_from_pool(rarity: Perk.Rarity, polarity: PerkModEffect.Polarity, category_override = null) -> PerkModEffect:
	var category = category_override 
	if not category:
		category = _select_category_from_dict()
	return PerkModEffectPool.select_random_effect_of_rarity_and_polarity_and_category(rarity, polarity, category)

func _select_category_from_dict() -> Perk.Category:
	var categories: Array[Perk.Category] = _categories_by_weight.keys()
	var weights = _categories_by_weight.values()
	
	var primary_weight = weights[0]
	
	if randf() <= primary_weight: 
		return categories[0] 
	return categories[1]

# TODO ensure this works as intended
func _calculate_max_rarity_in_budget(budget: float, max_rarity_constraint: Perk.Rarity):
	for rarity: Perk.Rarity in range(max_rarity_constraint, -1, -1) as Array[Perk.Rarity]: # Goes max -> COMMON
		if rarity_to_budget[rarity] <= budget:
			return rarity
	return null
#endregion 2.

#region 3.
## Mutates the effects array, potentially changing properties of each effect in the array. 
## Iteratively applies enhancements from a random pool until budget is fully drained. 
func _enhance_effects(effects: Array[PerkModEffect], budget: float) -> void:
	if DEBUG_LOG:
		print("_enhance_effects: starting with budget=", budget, " effects_count=", effects.size())

	_set_initial_direction_and_scope(effects)
	var budget_has_not_changed_iters = 0 # Guard against int effects not being able to be ADD_POWER enhanced.
	while budget > 0 and budget_has_not_changed_iters < 5:
		if DEBUG_LOG:
			print("_enhance_effects: loop start -> budget=", budget, " iters_no_change=", budget_has_not_changed_iters, " effects:", effects)
		var enhancement_type_and_target = _pick_enhancement_target_and_type(effects, budget)
		if not enhancement_type_and_target:
			if DEBUG_LOG:
				print("_enhance_effects: no enhancement available, breaking out. wasted budget=", budget)
			break
		var target: PerkModEffect = enhancement_type_and_target[0]
		var enhancement_type: EnhancementType = enhancement_type_and_target[1]
		
		var budget_delta := _do_enhancement(target, enhancement_type, budget)
		if budget_delta == 0.0:
			budget_has_not_changed_iters += 1
		budget += budget_delta

## Sets an initial direction and scope for each effect that doesn't have them.
func _set_initial_direction_and_scope(effects: Array[PerkModEffect]):
	for effect: PerkModEffect in effects:
		if effect.target_directions.is_empty():
			effect.add_direction(_select_random_dir(effect.polarity))
		if effect.scope == PerkModEffect.Scope.NEIGHBOR and effect.can_enhance_scope:
			effect.set_scope(_select_random_scope())

## Uses a weighted random selection from available directions.
func _select_random_dir(polarity: PerkModEffect.Polarity, dirs_to_avoid: Array[PerkMod.Direction] = []) -> PerkMod.Direction:
	var dirs: Array = PerkMod.Direction.values().filter(
		func(dir): return not dir in dirs_to_avoid
	)
	var weight_dict := BUFF_DIR_TO_WEIGHT if polarity == PerkModEffect.Polarity.BUFF else NERF_DIR_TO_WEIGHT
	var weights = dirs.map(
		func(dir): return weight_dict[dir]
	)
	# Select from all if empty 
	if dirs.is_empty():
		return _pick_weighted(weight_dict.keys(), weight_dict.values())
	return _pick_weighted(dirs, weights)
	
func _select_random_scope() -> PerkModEffect.Scope:
	return _pick_weighted(SCOPE_TO_WEIGHT.keys(), SCOPE_TO_WEIGHT.values())

func _pick_weighted(items: Array, weights: Array) -> Variant:
	assert(items.size() == weights.size())
	assert(not items.is_empty())
	var total_weight = 0.0
	for w in weights:
		total_weight += w
	
	var rand = randf() * total_weight
	var cumulative = 0.0
	
	for i in range(items.size()):
		cumulative += weights[i]
		if rand < cumulative:
			return items[i]
	
	# fallback (should never reach)
	assert(false)
	return items[-1]


## Picks next EnhancementType based on a roll of
##   the EnhancementTypes that are within budget after rarity multipliers.
## Returns [target: PerkModEffect, type: EnhancementType].
func _pick_enhancement_target_and_type(effects: Array[PerkModEffect], budget: float) -> Array:
	# Collect possible enhancements
	var effect_to_available_enhancements: Dictionary[PerkModEffect, Array] # Array[EnhancementType]
	for effect: PerkModEffect in effects:
		# Instantiate enhancement bucket
		effect_to_available_enhancements[effect] = []
		
		if effect.uses_power:
			var enhancement: EnhancementType = EnhancementType.ADD_POWER
			var cost: float = ENHANCEMENT_TYPE_TO_BUDGET_COST[enhancement] * \
					RARITY_TO_ENHANCEMENT_BUDGET_COST_MULT[effect.rarity]
			if cost <= budget:
				effect_to_available_enhancements[effect].append(enhancement)
		if effect.can_enhance_directions and effect.target_directions.size() != PerkMod.Direction.size():
			var enhancement: EnhancementType = EnhancementType.ADD_DIRECTION
			var cost: float = ENHANCEMENT_TYPE_TO_BUDGET_COST[enhancement] * \
					RARITY_TO_ENHANCEMENT_BUDGET_COST_MULT[effect.rarity]
			if cost <= budget:
				effect_to_available_enhancements[effect].append(enhancement)
		if effect.can_enhance_scope and effect.scope != PerkModEffect.Scope.ALL \
				and not (effect.target_directions == [PerkMod.Direction.SELF]):
			var enhancement: EnhancementType = EnhancementType.SET_SCOPE_ALL
			var cost: float = ENHANCEMENT_TYPE_TO_BUDGET_COST[enhancement] * \
					RARITY_TO_ENHANCEMENT_BUDGET_COST_MULT[effect.rarity]
			if cost <= budget:
				effect_to_available_enhancements[effect].append(enhancement)
	
	# Each possible enhancement option that can be rolled, as an array of pairs of shape [effect, enhancement_type].
	var options_arr: Array[Array]
	for effect: PerkModEffect in effect_to_available_enhancements:
		for enhancement_type: EnhancementType in effect_to_available_enhancements[effect]:
			var option = [effect, enhancement_type]
			options_arr.append(option)
	
	if DEBUG_LOG:
		print("_pick_enhancement_type_and_target: options_arr count =", options_arr.size())
		# show a short preview of options (pairs of effect + enhancement type)
		for option in options_arr:
			if option.size() >= 2:
				var opt_eff = option[0]
				var opt_type = option[1]
				print("  option -> effect:", opt_eff, "  enhancement:", opt_type)

	
	# Force power buffs if possible
	if options_arr.is_empty():
		# Don't force power buffs for ints
		if not effects.all(func(eff: PerkModEffect): return eff.power.is_int):
			if DEBUG_LOG:
				print("_pick_enhancement_type_and_target: forcing ADD_POWER fallback options")

			for effect: PerkModEffect in effects:
				if effect.uses_power:
					var option = [effect, EnhancementType.ADD_POWER]
					options_arr.append(option)
	
	# Completely fail if nothing can be power-enhanced despite nonzero budget 
	if options_arr.is_empty():
		printerr("Effect enhancement (stage 2) couldn't stat buff on the last bit of budget for effects: ", effects)
		return []
	
	# Pick an enhancement based on weighted selection. Nerfs get less weight.
	const BUFF_ENHANCEMENT_SELECTION_WEIGHT := 1.0
	const NERF_ENHANCEMENT_SELECTION_WEIGHT := 0.25

	var options_to_weights: Dictionary = {}

	for i in range(options_arr.size()):
		var opt_eff: PerkModEffect = options_arr[i][0]
		var opt_enh: EnhancementType = options_arr[i][1]

		# base weight by polarity
		if opt_eff.polarity == PerkModEffect.Polarity.NERF:
			options_to_weights[i] = NERF_ENHANCEMENT_SELECTION_WEIGHT
		else:
			options_to_weights[i] = BUFF_ENHANCEMENT_SELECTION_WEIGHT

		# small tuning: prefer ADD_POWER when the effect uses power, slightly penalize integer power
		if opt_enh == EnhancementType.ADD_POWER:
			if opt_eff.uses_power:
				options_to_weights[i] *= 1.25
			if opt_eff.power.is_int:
				options_to_weights[i] *= 0.8

	# single roll selection
	var total_weight := 0.0
	for k in options_to_weights.keys():
		total_weight += float(options_to_weights[k])

	var roll := randf() * total_weight
	var acc := 0.0
	for i in range(options_arr.size()):
		acc += float(options_to_weights[i])
		if roll <= acc:
			if DEBUG_LOG:
				print("_pick_enhancement_type_and_target: selected index =", i, "weight =", options_to_weights[i], "option =", options_arr[i])
			return options_arr[i]
	
	assert(false)
	# unreachable if weights > 0 (loop sums to total_weight), but keep as guard (won't be used normally)
	return options_arr[options_arr.size() - 1]

## Does an enhancement of the given type, returning the budget delta.
func _do_enhancement(effect: PerkModEffect, enhancement_type: EnhancementType, budget: float) -> float:
	if DEBUG_LOG:
		print("_do_enhancement: starting -> type = ", EnhancementType.find_key(enhancement_type), " target=", effect, " budget_before=", budget)
	
	
	var cost = ENHANCEMENT_TYPE_TO_BUDGET_COST[enhancement_type]
	cost *= RARITY_TO_ENHANCEMENT_BUDGET_COST_MULT[effect.rarity]
	
	match enhancement_type:
		EnhancementType.ADD_DIRECTION:
			var new_dir = _select_random_dir(effect.polarity, effect.get_target_directions())
			effect.add_direction(new_dir)
		EnhancementType.SET_SCOPE_ALL:
			effect.set_scope(PerkModEffect.Scope.ALL)
		EnhancementType.ADD_POWER:
			# We want to add BASE_ADD_POWER_MULTIPLIER, varied by a random multiplier.
			# But, don't let the random multiplier cause us to go above the current budget.
			var cost_ratio := 1.0
			var random_multiplier := 1.0
			if budget <= cost:
				cost_ratio = budget / cost
				# Even though we're at the last bit of budget, sometimes do a <1 multiplier.
				# This allows for lots of little small increases across various effects to happen at the end.
				if randf() < 0.1:
					random_multiplier = randf_range(0.5, 1.0)
			else:
				const rand_upper = 1.3 
				# Ensure a multiplier > 1.0 doesn't exceed budget.
				var upper_limit = minf(budget / cost, rand_upper)
				var is_hard_upper_limit = upper_limit < rand_upper
				
				# For small int effects, just increment them if within budget, otherwise return 0.0
				if effect.power.is_int and effect.power.value() <= 8:
					# Calculate min random_multiplier necessary to increase by 1 from its current value
					var current_power: int = int(effect.power.value() * effect.power_multiplier)
					var overall_multiplier_required: float
					# Don't divide by 0 current_power
					if current_power == 0:
						overall_multiplier_required = 1.0  # treat as "need full BASE_ADD_POWER_MULTIPLIER"
					else:
						overall_multiplier_required = (float(current_power + 1) / float(current_power)) - 1
					var random_multiplier_required = overall_multiplier_required / BASE_ADD_POWER_MULTIPLIER
					# Give up and do nothing if increasing by 1 is out of budget.
					if is_hard_upper_limit and random_multiplier_required * cost > budget:
						return 0.0
					# Otherwise, always increase by 1. 
					# Could decide not to always increase, but it's already a small chance for this 
					#   enhancement to occur in the first place
					random_multiplier = random_multiplier_required + 0.0001
				else:
					random_multiplier = randf_range(0.8, upper_limit)
			
			cost *= random_multiplier
			var power_multiplier_bonus := BASE_ADD_POWER_MULTIPLIER * cost_ratio * random_multiplier
			effect.power_multiplier += power_multiplier_bonus
	
	if DEBUG_LOG:
		# try to print the most useful bits after mutation
		var power_mult := "N/A"
		if effect.has_method("get") and effect.has_method("set"): # safe-ish guard; optional
			# best-effort: print the object and its known fields (may be null if not present)
			power_mult = str(effect.power_multiplier) if "power_multiplier" in effect else "N/A"
		print("_do_enhancement: applied", enhancement_type, " -> new effect:", effect, " power_multiplier:", power_mult, " cost_estimate:", cost)

	
	# If buff, return a negative budget delta.
	# If nerf, return a positive one.
	match effect.polarity:
		PerkModEffect.Polarity.BUFF:
			return -cost
		PerkModEffect.Polarity.NERF:
			return cost
		_:
			assert(false)
			return -cost
#endregion 3.

#region Helpers
func _sample_rarity_curve(x_value: float) -> float:
	return RARITY_CURVE.sample_baked(x_value)
## Returns num_slots.
func _sample_quantity_curve(x_value: float) -> int:
	return int(QUANTITY_CURVE.sample_baked(x_value))
#endregion Helpers
