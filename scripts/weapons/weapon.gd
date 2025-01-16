extends Node2D

class_name Weapon

enum Type {
	GRAPPLE_HOOK, BOOTS, WINGS, TELEPORT
}

## Populated in `register_weapons.gd`
static var weapon_type_to_scene : Dictionary[Type, PackedScene] = {}

var type : Type

var area : float
var attack_speed : float
var range : float
var attack_1_damage : float
var attack_2_damage : float
var attack_3_damage : float
var attack_4_damage : float
@onready var damage_arr := [attack_1_damage, attack_2_damage, attack_3_damage, attack_4_damage]

var player : Player

# Arrays of enemies hit, for attacks to use in not double-hitting
var attack_1_enemies_hit : Array[Enemy] = []
var attack_2_enemies_hit : Array[Enemy] = []
var attack_3_enemies_hit : Array[Enemy] = []
var attack_4_enemies_hit : Array[Enemy] = []
var enemies_hit_arr := [attack_1_enemies_hit, attack_2_enemies_hit, attack_3_enemies_hit, attack_4_enemies_hit]

@onready var detached_projectiles = $DetachedProjectiles

static func init_weapon(_type : Type):
	var new_weapon = weapon_type_to_scene[_type].instantiate()
	new_weapon.type = _type
	return new_weapon

func _init():
	player = Global.player

#region Stat calculation methods

func get_area() -> float:
	return area * player.area.value()

func get_range() -> float:
	return range * player.range.value()

func get_attack_speed() -> float:
	return attack_speed * player.attack_speed.value()

## Given an attack index (1,2,3,4), returns its damage value as a float multiplier of base damage.
func get_attack_damage(attack_idx : int) -> float:
	return damage_arr[attack_idx - 1]

#endregion Stat calculation methods

#region Dealing damage with hitboxes
## Given an attack index (1,2,3,4), returns its list of enemies hit.
func get_enemies_hit(attack_idx : int) -> Array[Enemy]:
	return enemies_hit_arr[attack_idx - 1]

## Deals attack_damage * base_damage to the enemy, adding it to the respective enemies_hit array.
func deal_damage(attack_idx : int, to_enemy : Enemy, damage := -1.0):
	if not to_enemy in get_enemies_hit(attack_idx):
		if damage == -1.0: # Need to calculate actual damage, since it wasn't supplied
			damage = player.base_damage.value() 
			damage *= get_attack_damage(attack_idx)
	to_enemy.take_damage(damage)

## Clears the given attacks' enemies hit arrays, so that enemies can be hit by the attack again.
func clear_enemies_hit(attack_idxs : Array[int] = [1, 2, 3, 4]):
	for idx in attack_idxs:
		get_enemies_hit(idx).clear()
#endregion Dealing damage with hitboxes
