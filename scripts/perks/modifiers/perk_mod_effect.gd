@abstract
extends Node

## An abstract class representing one effect in a modifier. A modifier can have any number of effects.
class_name PerkModEffect

const TYPE_TO_INFO: Dictionary[Type, PerkModEffectInfo] = {
	Type.STAT_COOLDOWN_MULT : preload("uid://8ym3o5vosoq6")
}

## The unique identifier enum for each effect.
## StatPmeEffects are prefixed by "STAT_".
enum Type {
	STAT_COOLDOWN_MULT,
}

## Defines how many perks are affected by this effect in its target directions.
enum Scope {
	NEIGHBOR, 
	SECOND_NEIGHBOR, 
	ALL,
}

enum TargetType {
	ALL,
	PASSIVE,
	ACTIVE, # Includes active trigger perks
	ACTIVE_TRIGGER,
}

## Whether an effect buffs or nerfs its targets. 
enum Polarity {
	BUFF,
	NERF,
}

## The type of this effect.
var _type: Type

## The scope of this effect.
var scope : Scope

## The polarity of this effect. 
var polarity: Polarity

## The rarity of this effect.
var rarity: Perk.Rarity

## Whether this effect can switch polarity.
var can_switch_polarity := false

## True if the polarity has been inverted for this effect.
var is_polarity_inverted := false

## Whether this effect utilizes a numeric power value.
var uses_power := true

## False for effects that want to have specific directions on init.
var can_enhance_directions := true

## False for effects that want to have specific scope on init.
var can_enhance_scope := true

## The numeric strength of this effect.
var power: Stat

## Multiplier applied to the effect's power. 
var power_multiplier := 1.0

## The type of perks this effect is allowed to apply to.
var target_type : TargetType

## The directions that this effect applies in.
var target_directions : Array[PerkMod.Direction]

## The stat mods currently applied to perks. 
## Erased on deactivation.
var perks_to_stat_mods: Dictionary[Perk, Array] # Array[StatMod]

## Whether this effect is currently active on its targets or not.
var active := false

func _ready() -> void:
	_load_info()

func _load_info() -> void:
	var info: PerkModEffectInfo = TYPE_TO_INFO[_type]
	assert(info, str("Couldn't load info for effect type ", Type.find_key([_type])))
	# Apply info's properties onto self.
	for prop: Dictionary in info.get_property_list():
		if not prop["usage"] & PROPERTY_USAGE_EDITOR: # Must be exported
			continue
		var field = prop.name
		if field in self:
			self.set(field, info.get(field))

## Applies effects to targeted perks and activates this effect.
func activate(target_perks : Array[Perk]):
	assert(not active, "Modifier should not be active when activate() is called.")
	assert(not target_perks.is_empty(), "Target perks array should not be empty when calling activate().")
	active = true
	for perk: Perk in target_perks:
		var _stat_mods := _apply_effect_to_perk(perk)
		perks_to_stat_mods[perk] = _stat_mods

func _process(delta: float) -> void:
	if active:
		_process_effect(delta)

## Loops through targeted perks and clears their StatMods.
func deactivate():
	assert(active, "Modifier should be active when deactivate() is called.")
	
	for perk: Perk in perks_to_stat_mods.keys():
		_remove_effect_from_perk(perk)
		for stat_mod: StatMod in perks_to_stat_mods[perk]:
			stat_mod.remove_from_parent_stat()

## Applies this effect onto a singular perk. Called when the parent modifier's perk changes context.
func apply_to_perk(perk: Perk):
	assert(not perk in perks_to_stat_mods, "Should not apply effect to a perk that's already applied to")
	var _stat_mods := _apply_effect_to_perk(perk)
	perks_to_stat_mods[perk] = _stat_mods

## Removes this effect from a singular perk. Called when the parent modifier's perk changes context.
func remove_from_perk(perk: Perk):
	assert(perk in perks_to_stat_mods, "Should not remove effect from a perk that doesn't have it applied")
	perks_to_stat_mods.erase(perk)


## Override with child classes to apply custom effects to a perk. 
## If the effect only changes perk stats, should return stat mods in an array. 
## Doing so, they will be cleared on deactivation automatically. 
@abstract func _apply_effect_to_perk(perk : Perk) -> Array[StatMod] 

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

#region Getters

func get_target_directions() -> Array[PerkMod.Direction]:
	return target_directions

#endregion Getters

#region Helpers
func has_direction(dir: PerkMod.Direction):
	return target_directions.has(dir)

func add_direction(dir: PerkMod.Direction):
	assert (not has_direction(dir))
	target_directions.append(dir)

func get_unowned_directions() -> Array[PerkMod.Direction]:
	return PerkMod.Direction.values().filter(func(dir): return not has_direction(dir))

func set_scope(_scope: Scope):
	scope = _scope

func invert_polarity():
	match polarity:
		Polarity.BUFF:
			polarity = Polarity.NERF
		Polarity.NERF:
			polarity = Polarity.BUFF
	_do_polarity_inversion_logic(polarity)

#endregion Helpers
