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

## Perk currently holding the modifier. Can be null.
var parent_perk : Perk

## Places the modifier onto the perk, activating its effects.

## Removes the modifier from the perk, deactivating its effects.

## Picks up the modifier, potentially removing it from a perk. 

## Places the modifier, potentially adding it to a perk. 

## Calculates the perks that this mod can be placed onto.

## Notices updates of the perk being hovered over. If this perk changes, updates highlights accordingly. 

## Given the perk being hovered, if it can be placed onto, determines which perks to highlight and adds a highlight to them. 

## Removes highlights from the current perks and clears the target_perks array.

## Adds a highlight to the given perk.
## Removes a highlight from the given perk.

## Tells all perks to display their modifier availability. 
## Tells all perks to STOP displaying their modifier availability. 

## Calculates available directions for modifier placement on the given perk. (Perk class)
## Displays a perk's available directions. (Perk class)
