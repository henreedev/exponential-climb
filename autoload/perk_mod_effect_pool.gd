extends Node

## PerkModEffectPool
## Initialized once, contains effects sorted into buckets of either rarity or theme. 

var all_effects: Array[PerkModEffect] 
	
	
@onready var all_effect_types_to_effect_infos: Dictionary[PerkModEffect.Type, PerkModEffectInfo] = {
	PerkModEffect.Type.STAT_COOLDOWN_MULT : load("uid://8ym3o5vosoq6"),
	PerkModEffect.Type.STAT_COOLDOWN_ADD : load("uid://bntb4tx1dwrg7"), 
	PerkModEffect.Type.STAT_RUNTIME_MULT : load("uid://cgyoga80n2x7j"),
	PerkModEffect.Type.STAT_RUNTIME_ADD : load("uid://dlr235mdp3ye7"),
	PerkModEffect.Type.STAT_DURATION_MULT : load("uid://bk52yddprmmue"),
	PerkModEffect.Type.STAT_DURATION_ADD : load("uid://dkjisfqvrdeuk"),
	PerkModEffect.Type.STAT_ACTIVATIONS_MULT : load("uid://b2jyn2i667lmn"),
	PerkModEffect.Type.STAT_ACTIVATIONS_ADD : load("uid://dvtu1fnhfh8qq"),
	PerkModEffect.Type.STAT_POWER_MULT : load("uid://cd0qsis271rpq"),
	PerkModEffect.Type.STAT_POWER_ADD : load("uid://b3gk2aivhc07b"),
}

var rarity_to_effects: Dictionary[Perk.Rarity, Array]
var category_to_effects: Dictionary[Perk.Category, Array]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for type: PerkModEffect.Type in all_effect_types_to_effect_infos.keys():
		var effect: PerkModEffect = PerkModEffect.create(type)
		all_effects.append(effect)
		add_child(effect)
	_initialize_dicts()

func _initialize_dicts() -> void:
	for rarity: Perk.Rarity in Perk.Rarity.values():
		var bucket: Array[PerkModEffect]
		for eff: PerkModEffect in all_effects: 
			if eff.rarity == rarity:
				bucket.append(eff)
		rarity_to_effects[rarity] = bucket
	for category: Perk.Category in Perk.Category.values():
		var bucket: Array[PerkModEffect]
		for eff: PerkModEffect in all_effects: 
			if eff.category == category:
				bucket.append(eff)
		category_to_effects[category] = bucket
	print("Initialized perk effect pool with ", all_effects.size(), " effects: \n", all_effect_types_to_effect_infos.keys().map(func(type: PerkModEffect.Type): PerkModEffect.Type.find_key(type)))
	print("all_effects:", all_effects) 
	print("category_to_effects:", category_to_effects) 
	print("rarity_to_effects:", rarity_to_effects) 

func select_random_effect_of_category_and_rarity(category: Perk.Category, rarity: Perk.Rarity) -> PerkModEffect:
	var effect: PerkModEffect
	var matches = category_to_effects[category].filter(
		func(eff: PerkModEffect): return eff.rarity == rarity
	)
	if not matches:
		printerr("No effect was available from the pool of category ", category, " and rarity ", rarity, "!")
		printerr("Falling back to rarity-only selection.")
		return select_random_effect_of_rarity(rarity)
	else:
		effect = matches.pick_random()
		var duped := PerkModEffect.duplicate_effect(effect)
		return duped

func select_random_effect_of_different_category(category_to_avoid: Perk.Category) -> PerkModEffect:
	var matches = all_effects.filter(
		func(eff: PerkModEffect): return eff.category != category_to_avoid
	)
	if matches.is_empty():
		printerr("No effects in pool that are not of category ", Perk.Category.find_key(category_to_avoid))
		return null
	var _eff : PerkModEffect = matches.pick_random()
	var duped := PerkModEffect.duplicate_effect(_eff)
	return duped

func select_random_effect() -> PerkModEffect:
	if all_effects.is_empty():
		assert(false, "No effects in pool!")
		return null
	var eff : PerkModEffect = all_effects.pick_random()
	var duped := PerkModEffect.duplicate_effect(eff)
	return duped

func select_random_effect_of_rarity(rarity: Perk.Rarity) -> PerkModEffect:
	var effect: PerkModEffect
	var matches = rarity_to_effects[rarity]
	if not matches:
		printerr("No effect was available from the pool of rarity ", rarity, "!")
	else:
		var eff : PerkModEffect = matches.pick_random()
		effect = PerkModEffect.duplicate_effect(eff)
	return effect

func select_random_effect_of_rarity_and_polarity_and_category(rarity: Perk.Rarity, polarity: PerkModEffect.Polarity, category: Perk.Category) -> PerkModEffect:
	var matches = category_to_effects[category].filter(
		func(eff: PerkModEffect): return eff.rarity == rarity and effect_can_be_polarity(eff, polarity)
	)
	if not matches:
		printerr("No effect was available from the pool of rarity ", Perk.Rarity.find_key(rarity), " and polarity ", PerkModEffect.Polarity.find_key(polarity), " and category ", Perk.Category.find_key(category), "!")
		printerr("Ignoring category...")
		matches = rarity_to_effects[rarity].filter(
			func(eff: PerkModEffect): return effect_can_be_polarity(eff, polarity)
		)
		if not matches:
			printerr("COMPLETE FAIL: No effect was available from the pool of rarity ", Perk.Rarity.find_key(rarity), " and polarity ", PerkModEffect.Polarity.find_key(polarity), "!")
			return null
	var _eff : PerkModEffect = matches.pick_random()
	var duped = PerkModEffect.duplicate_effect(_eff)
	convert_effect_to_polarity(duped, polarity)
	return duped

func effect_can_be_polarity(effect: PerkModEffect, polarity: PerkModEffect.Polarity):
	return effect.polarity == polarity or effect.polarity != polarity and effect.can_switch_polarity

## Mutates the given PME, inverting its polarity if its current polarity is not the desired
func convert_effect_to_polarity(effect: PerkModEffect, desired_polarity: PerkModEffect.Polarity):
	if effect.polarity != desired_polarity and effect.can_switch_polarity:
		effect.invert_polarity()
	elif effect.polarity == desired_polarity:
		return
	else: assert(false) # Shouldn't reach here
