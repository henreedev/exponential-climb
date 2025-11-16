extends Control

class_name PmeUiSlot

var pme: PerkModEffect

@onready var rarity_bg: AnimatedSprite2D = %RarityBg
@onready var scope: AnimatedSprite2D = %Scope
@onready var pme_ui_slot_dirs: PmeUiSlotDirs = %PmeUiSlotDirs
@onready var pme_description_label: DescriptionBox = %PmeDescriptionLabel
@onready var rarity_type_descriptor: RarityTypeDescriptor = %RarityTypeDescriptor

func initialize(parent_pme: PerkModEffect):
	pme = parent_pme
	modulate = Color.WHITE # Doing this in case a clear()'d ui slot has an effect subsequently added
	_refresh_rarity()
	_initialize_dirs()
	_refresh_scope()
	_initialize_description()
	_refresh_rarity_type_descriptor()

func refresh():
	assert(pme)
	_refresh_dirs()
	_refresh_scope()
	_refresh_description()
	_refresh_rarity_type_descriptor()

func clear():
	modulate = Color.TRANSPARENT

func _initialize_dirs():
	pme_ui_slot_dirs.initialize(pme)

func _refresh_dirs():
	pme_ui_slot_dirs.refresh()

func _refresh_rarity():
	rarity_bg.animation = Perk.Rarity.find_key(pme.rarity).to_lower()

func _refresh_scope():
	scope.animation = PerkModEffect.Scope.find_key(pme.scope).to_lower()
	scope.modulate = PmeUiSlotDirs.get_tint_color(pme.is_buff())

func _initialize_description():
	pme_description_label.initialize(pme.description, pme)

func _refresh_description():
	pme_description_label.refresh()
 
func _refresh_rarity_type_descriptor():
	rarity_type_descriptor.set_descriptor_text(pme.rarity, "BUFF" if pme.is_buff() else "NERF", "")
