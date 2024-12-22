extends Resource

class_name PerkInfo

@export var type : Perk.Type
@export var rarity : Perk.Rarity
@export var base_power : int
@export_multiline var description : String

@export var duration : float ## Perk cannot be activated more often than this duration.
@export var cooldown : float ## Perk cannot be activated more often than this duration.
@export var is_active : bool ## A perk is either active or passive.

@export_subgroup("Trigger")
@export var is_trigger : bool
@export var trigger_type : Perk.TriggerType
