extends Node2D

class_name Chest

#region Interaction
const INTERACTION_RADIUS := 64.0
const INTERACTION_RADIUS_SQRD := INTERACTION_RADIUS * INTERACTION_RADIUS
var interactable := true
#endregion Interaction

#region Perk selection
var rarity : Perk.Rarity = Perk.Rarity.COMMON
#region Perk selection

@onready var label: Label = $Label

func _process(delta: float) -> void:
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
			label.text = "CHEST"
		else: # Already interacted
			label.text = "CHEST OPENED"

func open_chest():
	interactable = false
	# Get a perk selection for the player to choose from
	var perks : Array[Perk] = []
	const PERK = preload("res://scenes/perks/perk.tscn")
	# Get 3 random perks from pool
	perks.append(Perk.init_perk(Perk.Type.SPEED_BOOST))
	perks.append(Perk.init_perk(Perk.Type.SPEED_BOOST))
	perks.append(Perk.init_perk(Perk.Type.SPEED_BOOST))
	#perks.append(PerkManager.get_random_perk(rarity))
	#perks.append(PerkManager.get_random_perk(rarity))
	#perks.append(PerkManager.get_random_perk(rarity))
	
	# Open perk UI and show the perks
	Global.perk_ui.show_chest_opening(perks)
