extends Resource

## Contains data describing a player class (a certain character to be picked).
class_name EnemyClass

@export var _class : Enemy.Class

@export var name : String

@export_category("Stats")
## The max health of this enemy class.
@export_range(1, 500, 1) var max_health := 1
## The base damage of this enemy class.
@export_range(1, 100, 1) var base_damage := 10 
## The delay between an attack initiating and the hitbox coming out.
@export_range(0.0, 3.0, 0.01) var attack_windup := 0.25 
## The delay after attacking before the enemy can ATTACK again. 
## Begins upon initiating an attack, not upon finishing the attack sequence.
@export_range(0.0, 5.0, 0.01) var attack_cooldown := 1.50 
## The delay after attacking before the enemy can MOVE again.
@export_range(0.0, 5.0, 0.01) var attack_winddown := 0.50
## The duration the attack hitbox is active for.
@export_range(0.0, 5.0, 0.01) var attack_duration := 0.1
## The pixel range within which the enemy will attempt to attack the player.
@export_range(1.0, 1000.0, 1.0) var range := 20.0 
## The XP dropped by this enemy.
@export_range(1, 1000, 1) var xp := 1 


@export_category("Movement")
## The movement speed of this enemy class.
@export_range(0.0, 400.0, 10.0) var movement_speed := 100.0
## The jump strength of this enemy class.
@export_range(0.0, 600.0, 10.0) var jump_strength := 450.0
## Multiplicative gravity modifier.
@export_range(0.0, 2.0, 0.05) var gravity_mod := 1.0
