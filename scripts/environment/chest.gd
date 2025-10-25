extends Node2D

class_name Chest

#region Interaction
const INTERACTION_RADIUS := 64.0
const INTERACTION_RADIUS_SQRD := INTERACTION_RADIUS * INTERACTION_RADIUS
var interactable := true
#endregion Interaction

#region Perk selection
var rarity : Perk.Rarity = Perk.Rarity.COMMON
#endregion Perk selection

#region Modifier generation
var rarity_value : float
var quantity_value : float
#endregion Modifier generation

#region Generation
const CHEST_SCENE = preload("uid://dnbfk0be25rph")
#endregion Generation

#region Rarity cutoffs
## Rarity value must be >= this value to correspond with this rarity.
## If you update this, rarity_curve.tres should always have points exactly on these cutoffs.
const RARITY_TO_CUTOFF : Dictionary[Perk.Rarity, float] = {
	Perk.Rarity.COMMON : 0.0,
	Perk.Rarity.RARE : 0.4,
	Perk.Rarity.EPIC : 0.7,
	Perk.Rarity.LEGENDARY : 0.95,
}
#endregion Rarity cutoffs

@onready var chest_sprite: Sprite2D = $ChestSprite
@onready var label: Label = $Label

static func create(world_pos: Vector2, _rarity_value: float, _quantity_value: float) -> Chest:
	var new_chest: Chest = CHEST_SCENE.instantiate()
	new_chest.rarity = calculate_rarity_from_value(_rarity_value)
	new_chest.position = world_pos
	new_chest.rarity_value = _rarity_value
	new_chest.quantity_value = _quantity_value
	return new_chest

func _ready():
	pick_rarity_visuals()

func pick_rarity_visuals():
	chest_sprite.modulate = PerkMod.RARITY_TO_BODY_COLOR[rarity]

func _process(_delta: float) -> void:
	if interactable and position.distance_squared_to(Global.player.position) < INTERACTION_RADIUS_SQRD:
		modulate = Color.WHITE * 1.5
		scale = Vector2.ONE * 1.5
		label.text = "PRESS [E]"
		if Input.is_action_just_pressed("interact"):
			open_chest()
	else: # Can't interact
		modulate = Color.WHITE
		scale = Vector2.ONE
		if interactable: # Out of range
			label.text = str("Rarity: ", str(rarity_value).pad_decimals(2), "\n", "Quantity: ", str(quantity_value).pad_decimals(2))
		else: # Already interacted
			label.text = "CHEST OPENED"

func open_chest():
	interactable = false
	# Get a perk selection for the player to choose from
	var perks : Array[Perk] = []
	# Get 3 random perks from pool
	perks.append(PerkManager.pick_perk_from_pool(rarity))
	perks.append(PerkManager.pick_perk_from_pool(rarity))
	perks.append(PerkManager.pick_perk_from_pool(rarity))
	
	# Open perk UI and show the perks
	Global.perk_ui.show_chest_opening(self, perks)

## Given a rarity value from 0.0 to 1.0, determines the enum rarity based on cutoffs.
static func calculate_rarity_from_value(rarity_value: float) -> Perk.Rarity:
	var _rarity: Perk.Rarity = Perk.Rarity.COMMON
	for r in RARITY_TO_CUTOFF:
		var cutoff = RARITY_TO_CUTOFF[r]
		if rarity_value >= cutoff:
			_rarity = r
		else:
			break
	return _rarity
