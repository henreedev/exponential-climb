extends Node2D

## Modifiers that apply to perks. Each perk can hold modifiers that apply directionally to other perks or itself.
class_name PerkMod

enum Direction {
	SELF, 
	LEFT,
	RIGHT,
	UP,
	DOWN
}

## The directions that this mod modifies. Determined by its effects. 
## Set on initialization, and updated upon adding / removing / changing effects.
var target_directions : Array[Direction]

## The perks currently highlighted. 
## Also used upon placement to assign effects to their perks.
var effect_to_target_perks: Dictionary[PerkModEffect, Array] # Array[Perk]

## Perk currently holding the modifier. Can be null.
var parent_perk : Perk

## Effects that this modifier applies upon activation.
var effects : Array[PerkModEffect]

## Adds this modifier to the perk, activating its effects.
func activate(_parent_perk: Perk):
	assert(_parent_perk)
	parent_perk = _parent_perk
	for effect in effects:
		effect.activate(effect_to_target_perks[effect])

## Removes this modifier from the perk, deactivating its effects.
func deactivate(_parent_perk: Perk):
	assert(_parent_perk == parent_perk)
	parent_perk = null
	for effect in effects:
		effect.deactivate()

## Picks up this modifier, potentially removing it from a perk. 

## Places this modifier, potentially adding it to a perk. 

## Calculates the perks that this mod can be placed onto.

## Notices which perk is currently being hovered over. If it changes, updates highlights accordingly. 


## Given the perk being hovered, if it can be placed onto, determines which perks to highlight and adds a highlight to them. 
func apply_target_highlights_at_perk(perk: Perk):
	assert(effect_to_target_perks.is_empty(), "Highlights should have been cleared before applying them") 
	if perk.can_hold_modifier(target_directions):
		var context: PerkContext = perk.context
		for effect: PerkModEffect in effects:
			var targets = get_target_perks(effect, context)
			effect_to_target_perks[effect] = targets
			for target: Perk in targets:
				match effect.category:
					PerkModEffect.Category.BUFF:
						target.show_modifier_buff_highlight()
					PerkModEffect.Category.NERF:
						target.show_modifier_nerf_highlight()

## Finds a child effect's target perks based on the given perk context.
func get_target_perks(effect: PerkModEffect, context: PerkContext) -> Array[Perk]:
	assert(context != null)
	assert(effect != null)
	var target_perks: Array[Perk]
	for dir: PerkMod.Direction in effect.get_target_directions():
		match dir:
			PerkMod.Direction.SELF:
				assert(context.perk != null)
				target_perks.append(context.perk)
			PerkMod.Direction.LEFT:
				match effect.scope:
					PerkModEffect.Scope.NEIGHBOR:
						if context.left_neighbor:
							target_perks.append(context.left_neighbor)
					PerkModEffect.Scope.SECOND_NEIGHBOR:
						if context.second_left_neighbor:
							target_perks.append(context.second_left_neighbor)
					PerkModEffect.Scope.ALL:
						if context.second_left_neighbor:
							target_perks.append(context.left_neighbors)
			PerkMod.Direction.RIGHT:
				match effect.scope:
					PerkModEffect.Scope.NEIGHBOR:
						if context.right_neighbor:
							target_perks.append(context.right_neighbor)
					PerkModEffect.Scope.SECOND_NEIGHBOR:
						if context.second_right_neighbor:
							target_perks.append(context.second_right_neighbor)
					PerkModEffect.Scope.ALL:
						if context.second_right_neighbor:
							target_perks.append(context.right_neighbors)
			PerkMod.Direction.UP:
				match effect.scope:
					PerkModEffect.Scope.NEIGHBOR:
						if context.up_neighbor:
							target_perks.append(context.up_neighbor)
					PerkModEffect.Scope.SECOND_NEIGHBOR:
						if context.second_up_neighbor:
							target_perks.append(context.second_up_neighbor)
					PerkModEffect.Scope.ALL:
						if context.second_up_neighbor:
							target_perks.append(context.up_neighbors)
			PerkMod.Direction.DOWN:
				match effect.scope:
					PerkModEffect.Scope.NEIGHBOR:
						if context.down_neighbor:
							target_perks.append(context.down_neighbor)
					PerkModEffect.Scope.SECOND_NEIGHBOR:
						if context.second_down_neighbor:
							target_perks.append(context.second_down_neighbor)
					PerkModEffect.Scope.ALL:
						if context.second_down_neighbor:
							target_perks.append(context.down_neighbors)
	return target_perks

## Removes highlights from the current perks and clears the targeted perks.
func clear_highlights():
	for perk: Perk in effect_to_target_perks.values():
		perk.hide_modifier_buff_highlight()
		perk.hide_modifier_nerf_highlight()
	effect_to_target_perks.clear()

## Tells all perks to display their modifier availability for this mod's directions
func show_modifier_availability_of_all_perks():
	for perk: Perk in get_tree().get_nodes_in_group("perk"):
		perk.show_available_directions(target_directions)

## Tells all perks to STOP displaying their modifier availability. 
func hide_modifier_availability_of_all_perks():
	for perk: Perk in get_tree().get_nodes_in_group("perk"):
		perk.hide_available_directions()

## Adds an effect to this modifier.
func add_effect(effect: PerkModEffect) -> void:
	effects.append(effect)
	_refresh_target_directions()
	
## Removes an effect from this modifier.
func remove_effect(effect: PerkModEffect) -> void:
	assert(effects.has(effect), "Shouldn't try to remove an effect that doesn't exist on this mod")
	effects.erase(effect)
	_refresh_target_directions()

## Refreshes target directions. Call when effects update. 
func _refresh_target_directions() -> void:
	target_directions.clear()
	for effect: PerkModEffect in effects:
		for dir in effect.get_target_directions():
			if not target_directions.has(dir):
				target_directions.append(dir)
