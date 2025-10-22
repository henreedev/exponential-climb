extends PerkModEffect


## Override with child classes to apply custom effects to a perk. 
## If the effect only changes perk stats, should return stat mods in an array. 
## Doing so, they will be cleared on deactivation automatically. 
func _apply_effect_to_perk(perk : Perk) -> Array[StatMod]:
	

## Override to update the effect as time goes on. 
## Overrides will likely need to reference the keys of the perks_to_stat_mods dict.
@abstract func _process_effect(delta: float) -> void

## Override to define custom behavior or cleanup upon removing this effect from the given perk.
## For example, disconnecting signals.
@abstract func _remove_effect_from_perk(perk: Perk) -> void

## Override to define custom behavior when inverting polarity. 
## For example, StatPme's invert their applied StatMod when polarity is inverted.
## The input parameter will already be the current polarity value.
@abstract func _do_polarity_inversion_logic(new_polarity: Polarity) -> void
