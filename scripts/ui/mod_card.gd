extends BaseCard

class_name ModCard

var parent_mod: PerkMod
@onready var effects_container: VBoxContainer = $EffectsContainer
@onready var ui_slots: Array[PmeUiSlot] = [
	%PmeUiSlot, %PmeUiSlot2, %PmeUiSlot3
]
@onready var rarity_type_descriptor: RarityTypeDescriptor = $RarityTypeDescriptor
@onready var perk_mod_visual: PerkModVisual = $PerkModVisual

func init_with_mod(mod: PerkMod):
	parent_mod = mod
	_prepare_hidden_state()
	_connect_refresh_signals()
	_init_mod_visual()
	refresh()

func _prepare_hidden_state():
	showing = true
	hide_card()

func _connect_refresh_signals():
	parent_mod.refreshed.connect(refresh)

func _init_mod_visual():
	perk_mod_visual.init_parent_mod(parent_mod)

func refresh():
	print("Refreshing mod card for ", parent_mod)
	# Refresh effects
	for i in range(parent_mod.effects.size()):
		ui_slots[i].initialize(parent_mod.effects[i])
	for i in range(parent_mod.effects.size(), 3):
		ui_slots[i].clear()
	
	# Refresh descriptor
	rarity_type_descriptor.set_descriptor_text(parent_mod.rarity, "", "MODIFIER")
	
	perk_mod_visual.refresh()
