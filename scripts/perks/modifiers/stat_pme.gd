extends PerkModEffect

class_name StatPme

var target_stat: String
var stat_mod_type: StatMod.Type

## Override with child classes to apply custom effects to a perk. 
## If the effect only changes perk stats, should return stat mods in an array. 
## Doing so, they will be cleared on deactivation automatically. 
func _apply_effect_to_perk(perk : Perk) -> Array[StatMod]:
	var stat_mods: Array[StatMod]
	var stat: Stat = perk.get(target_stat)
	var stat_mod: StatMod
	match stat_mod_type:
		StatMod.Type.ADDITIVE:
			stat_mod = stat.append_add_mod(power.value())
		StatMod.Type.MULTIPLICATIVE:
			stat_mod = stat.append_mult_mod(power.value())
	if is_polarity_inverted:
		stat_mod.invert()
	stat_mods.append(stat_mod)
	return stat_mods

## Override to update the effect as time goes on. 
## Overrides will likely need to reference the keys of the perks_to_stat_mods dict.
func _process_effect(_delta: float) -> void:
	pass

## Override to define custom behavior or cleanup upon removing this effect from the given perk.
## For example, disconnecting signals.
func _remove_effect_from_perk(_perk: Perk) -> void:
	pass

## Override to define custom behavior when inverting polarity. 
## The input parameter will already be the current polarity value.
func _do_polarity_inversion_logic(new_polarity: Polarity) -> void:
	pass
