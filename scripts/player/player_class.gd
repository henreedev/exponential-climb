extends Resource

## Contains data describing a player class (a certain character to be picked).
class_name PlayerClass

@export var class_type : Player.ClassType

@export var name : String

@export_category("Stats")
## Multiplicative base damage modifier.
@export_range(0.0, 2.0, 0.05) var base_damage_mod := 1.0 
## Multiplicative range modifier.
@export_range(0.0, 2.0, 0.05) var range_mod := 1.0 
## Multiplicative attack speed modifier.
@export_range(0.0, 2.0, 0.05) var attack_speed_mod := 1.0 
## Multiplicative area modifier.
@export_range(0.0, 2.0, 0.05) var area_mod := 1.0 
## Multiplicative max health modifier.
@export_range(0.0, 2.0, 0.05) var max_health_mod := 1.0
## Multiplicative health regen modifier.
@export_range(0.0, 2.0, 0.05) var health_regen_mod := 1.0

@export_category("Movement")
## Multiplicative movement speed modifier.
@export_range(0.0, 2.0, 0.05) var movement_speed_mod := 1.0
## Multiplicative jump strength modifier.
@export_range(0.0, 2.0, 0.05) var jump_strength_mod := 1.0
## Additive double jumps modifier.
@export_range(-1, 5, 1) var double_jumps_mod := 0
