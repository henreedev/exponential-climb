extends Node2D

class_name PerkModVisual

@onready var perk_mod_loop_visual: PerkModLoopVisual = %PerkModLoopVisual
@onready var perk_mod_rarity_visual: PerkModRarityVisual = %PerkModRarityVisual
@onready var perk_mod_polarity_visual: PerkModPolarityVisual = %PerkModPolarityVisual

var parent: PerkMod

func init_parent_mod(parent_mod: PerkMod):
	parent = parent_mod
	perk_mod_loop_visual.init_parent_mod(parent_mod)
	perk_mod_rarity_visual.init_parent_mod(parent_mod)
	perk_mod_polarity_visual.init_parent_mod(parent_mod)

func refresh():
	perk_mod_loop_visual.refresh()
	perk_mod_rarity_visual.refresh()
	perk_mod_polarity_visual.refresh()
