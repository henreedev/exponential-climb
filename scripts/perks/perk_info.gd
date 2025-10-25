extends Resource

class_name PerkInfo

@export var display_name : String
@export var code_name : String 
@export var type : Perk.Type
@export var rarity : Perk.Rarity
@export var primary_category: Perk.Category
@export var secondary_category: Perk.Category
@export var base_power : int
@export var activations: int = 1
@export var is_active : bool ## A perk is either active or passive.
@export_multiline var description : String


@export_subgroup("Passive")
@export_range(0.0, 20.0, 0.05) var loop_cost : float

@export_subgroup("Active")
## Perk's effect lasts for this long.
## Passive perks should pick a duration of -1.0 (infinite duration).
## Instant perks should pick 0.0.
@export_range(-1.0, 60.0, 0.01) var duration : float = -1.0
@export var runtime : float ## Perk takes this duration of loop time before the loop can move on.
@export var cooldown : float ## Perk cannot be activated more often than this duration.

@export_subgroup("Trigger")
@export var is_trigger : bool
@export var trigger_type : Perk.TriggerType
