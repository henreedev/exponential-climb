extends Resource

## Contains data describing a player class (a certain character to be picked).
class_name PlayerClass

@export var class_type : Player.ClassType

@export var weapon_type : Weapon.Type

@export var movement_speed : float = Player.DEFAULT_MOVEMENT_SPEED
@export var jump_strength : float = Player.DEFAULT_JUMP_STRENGTH
@export var gravity : float = Player.DEFAULT_GRAVITY
@export var max_health : int = Player.DEFAULT_MAX_HEALTH
