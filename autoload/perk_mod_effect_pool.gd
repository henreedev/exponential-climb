extends Node

## PerkModEffectPool
## Initialized once, contains effects sorted into buckets of either rarity or theme. 


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_initialize_dicts()

func _initialize_dicts() -> void:
	pass # TODO

func get_random_effect_of_theme_and_rarity()
