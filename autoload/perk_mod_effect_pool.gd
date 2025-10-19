extends Node

## PerkModEffectPool
## Initialized once, contains effects sorted into buckets of either rarity or theme. 

@onready var all_effects: Array[PerkModEffect] = [
	# TODO add effect loads here
]

var rarity_to_effects: Dictionary[Perk.Rarity, Array]
var category_to_effects: Dictionary[Perk.Category, Array]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_initialize_dicts()

func _initialize_dicts() -> void:
	for rarity: Perk.Rarity in rarity_to_effects.keys():
		var bucket: Array[PerkModEffect] = all_effects.filter(
			func(eff: PerkModEffect): return eff.rarity == rarity
		)
		rarity_to_effects[rarity] = bucket
	for category: Perk.Category in category_to_effects.keys():
		var bucket: Array[PerkModEffect] = all_effects.filter(
			func(eff: PerkModEffect): return eff.category == category
		)
		category_to_effects[category] = bucket

func select_random_effect_of_category_and_rarity(category: Perk.Category, rarity: Perk.Rarity) -> PerkModEffect:
	var effect: PerkModEffect
	var matches = category_to_effects[category].filter(
		func(eff: PerkModEffect): return eff.rarity == rarity
	)
	if not matches:
		printerr("No effect was available from the pool of category ", category, " and rarity ", rarity, "!")
	else:
		effect = matches.pick_random()
	return effect

func select_random_effect_of_different_category(category_to_avoid: Perk.Category) -> PerkModEffect:
	var matches = all_effects.filter(
		func(eff: PerkModEffect): return eff.category != category_to_avoid
	)
	if matches.is_empty():
		printerr("No effects in pool that are not of category ", category_to_avoid)
		return null
	return matches.pick_random()

func select_random_effect() -> PerkModEffect:
	if all_effects.is_empty():
		assert(false, "No effects in pool!")
		return null
	return all_effects.pick_random()

func select_random_effect_of_rarity(rarity: Perk.Rarity) -> PerkModEffect:
	var effect: PerkModEffect
	var matches = rarity_to_effects[rarity]
	if not matches:
		printerr("No effect was available from the pool of rarity ", rarity, "!")
	else:
		effect = matches.pick_random()
	return effect
