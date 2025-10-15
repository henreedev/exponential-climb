@abstract
extends Node

## An abstract class representing one effect in a modifier. A modifier can have any number of effects.
class_name PerkModEffect

## Defines how many perks are affected by this effect in its target directions.
enum Scope {
	NEIGHBOR, 
	ALL
}

## The directions that this effect applies in.
var target_directions : Array[PerkMod.Direction]

## The scope of this effect.
var scope : Scope

## The stat mods currently applied to perks. Should be erased on deactivation.
var perks_to_stat_mods: Dictionary[Perk, Array] # Array[StatMod]


func activate(target_perks : Array[Perk]):
	for perk: Perk in target_perks:
		var _stat_mods := _apply_effect_to_perk(perk)
		perks_to_stat_mods[perk] = _stat_mods

#func _process(delta: float) -> void:
	

## Loops through targeted perks and clears their StatMods.
func deactivate():
	for perk: Perk in perks_to_stat_mods.keys():
		_remove_effect_from_perk(perk)
		for stat_mod: StatMod in perks_to_stat_mods[perk]:
			stat_mod.remove_from_parent_stat()

## Override with child classes to apply custom effects to a perk. 
## If the effect only changes perk stats, should return stat mods in an array. 
## Doing so, they will be cleared on deactivation automatically. 
@abstract func _apply_effect_to_perk(perk : Perk) -> Array[StatMod] 

## Override to define custom behavior or cleanup upon removing this effect from the given perk.
## For example, disconnecting signals.
@abstract func _remove_effect_from_perk(perk: Perk) -> void
