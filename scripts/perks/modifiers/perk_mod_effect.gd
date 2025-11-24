@abstract
extends Node

## An abstract class representing one effect in a modifier. A modifier can have any number of effects.
class_name PerkModEffect

## The unique identifier enum for each effect.
## StatPmes are prefixed by "STAT_".
enum Type {
	STAT_COOLDOWN_MULT,
	STAT_COOLDOWN_ADD,
	STAT_RUNTIME_MULT,
	STAT_RUNTIME_ADD,
	STAT_DURATION_MULT,
	STAT_DURATION_ADD,
	STAT_ACTIVATIONS_MULT,
	STAT_ACTIVATIONS_ADD,
	STAT_POWER_MULT,
	STAT_POWER_ADD,
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

## The category of this effect.
var category: Perk.Category

## Whether this effect can switch polarity.
var can_switch_polarity := false

## True if the polarity has been inverted for this effect.
var is_polarity_inverted := false

## Whether power_multiplier should be inverted when applying it to power.
## True for e.g. cooldown multiplier of 0.5
var has_inverse_power_relationship := false

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

var power_multiplier_stat_mod: StatMod

## The type of perks this effect is allowed to apply to.
var target_type : TargetType

## The directions that this effect applies in.
var target_directions : Array[PerkMod.Direction]

## The stat mods currently applied to perks. 
## Erased on deactivation.
var perks_to_stat_mods: Dictionary[Perk, Array] # Array[StatMod]

## The trails currently visibly flowing to perks. 
## Erased on deactivation, killing the trails.
var perk_to_trail: Dictionary[Perk, ModParticleTrail]


## Whether this effect is currently active on its targets or not.
var active := false

## The description of this effect.
var description: String

## The parent modifier. 
## Currently only used to access the parent perk when creating particle trails.
var parent_mod: PerkMod

## Called by PerkModFactory to set up one instance of each effect.
static func create(type: Type) -> PerkModEffect:
	var new_pme: PerkModEffect = PerkModEffectPool.all_effect_types_to_effect_infos[type]\
													.subclass_script.new()
	new_pme._type = type
	new_pme._load_info()
	return new_pme

static func duplicate_effect(orig_effect: PerkModEffect) -> PerkModEffect:
	var script: Script = orig_effect.get_script()
	if not script: assert(false)
	var duped_effect: PerkModEffect = script.new()
	duped_effect.set_script(script)
	
	for prop: Dictionary in orig_effect.get_property_list():
		var field_name = prop.name
		match field_name:
			"name", "script":
				continue
		if not field_name in duped_effect:
			continue
		var field_value = orig_effect.get(field_name)
		if field_value:
			if field_value is Resource or field_value is Array or field_value is Dictionary:
				field_value = field_value.duplicate_deep(2) # Super deep duplicate
		duped_effect.set(field_name, field_value)
	
	# Duped effect should have all properties copied over
	return duped_effect

func _ready() -> void:
	_apply_power_multiplier()

func _load_info() -> void:
	var info: PerkModEffectInfo = PerkModEffectPool.all_effect_types_to_effect_infos[_type]
	assert(info, str("Couldn't load info for effect type ", Type.find_key(_type)))
	# Apply info's properties onto self.
	for prop: Dictionary in info.get_property_list():
		if not prop["usage"] & PROPERTY_USAGE_EDITOR: # Must be exported
			continue
		var field = prop.name
		match field:
			"script", "resource_path", "resource_local_to_scene":
				continue
		if field in self:
			self.set(field, info.get(field))

func _apply_power_multiplier():
	power_multiplier_stat_mod = StatMod.new()
	power_multiplier_stat_mod.type = StatMod.Type.MULTIPLICATIVE
	power_multiplier_stat_mod.value = power_multiplier
	if has_inverse_power_relationship:
		power_multiplier_stat_mod.invert()
	power.append_mod(power_multiplier_stat_mod)

## Applies effects to targeted perks and activates this effect.
func activate(target_perks : Array[Perk]):
	assert(not active, "Effect should not be active when activate() is called.")
	assert(not target_perks.is_empty(), "Target perks array should not be empty when calling activate().")
	active = true
	for perk: Perk in target_perks:
		var _stat_mods := _apply_effect_to_perk(perk)
		perks_to_stat_mods[perk] = _stat_mods
		add_trail_to_perk(perk)

func _process(delta: float) -> void:
	if active:
		_process_effect(delta)

## Loops through targeted perks and clears their StatMods.
func deactivate():
	assert(active, "Effect should be active when deactivate() is called.")
	active = false
	for perk: Perk in perks_to_stat_mods.keys():
		_remove_effect_from_perk(perk)
		for stat_mod: StatMod in perks_to_stat_mods[perk]:
			stat_mod.remove_from_parent_stat()
		perks_to_stat_mods.erase(perk)
		remove_trail_from_perk(perk)

## Applies this effect onto a singular perk. Called when the parent modifier's perk changes context.
func apply_to_perk(perk: Perk):
	assert(not perk in perks_to_stat_mods, "Should not apply effect to a perk that's already applied to")
	var _stat_mods := _apply_effect_to_perk(perk)
	perks_to_stat_mods[perk] = _stat_mods
	add_trail_to_perk(perk)
	

## Removes this effect from a singular perk. Called when the parent modifier's perk changes context.
func remove_from_perk(perk: Perk):
	assert(perk in perks_to_stat_mods, "Should not remove effect from a perk that doesn't have it applied")
	perks_to_stat_mods.erase(perk)
	remove_trail_from_perk(perk)


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

func is_buff() -> bool:
	return polarity == Polarity.BUFF

func invert_polarity():
	is_polarity_inverted = not is_polarity_inverted
	match polarity:
		Polarity.BUFF:
			polarity = Polarity.NERF
		Polarity.NERF:
			polarity = Polarity.BUFF
	_do_polarity_inversion_logic(polarity)

#region Particle Trails
func add_trail_to_perk(perk: Perk):
	assert(parent_mod)
	assert(parent_mod.parent_perk)
	
	var new_trail: ModParticleTrail = \
		ModParticleTrail.create_particle_trail(parent_mod.parent_perk, perk, self)
	Global.perk_ui.add_child(new_trail)
	
	perk_to_trail[perk] = new_trail
	print(perk_to_trail)

func remove_trail_from_perk(perk: Perk):
	assert(parent_mod)
	assert(perk_to_trail.has(perk))
	
	perk_to_trail[perk].kill()
	perk_to_trail.erase(perk)

#endregion Particle Trails

#endregion Helpers
