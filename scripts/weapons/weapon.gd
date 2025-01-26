extends Node2D

class_name Weapon

## Perks can listen for this signal to apply mods to an attack before it deals damage.
signal attack_initiated(attack : Attack)
## Perks can react to attack hits using this signal.
signal attack_hit(attack : Attack, damage_dealt : int, enemy : Enemy)

enum Type {
	GRAPPLE_HOOK, BOOTS, WINGS, TELEPORT
}

enum AttackType {
	PRIMARY,
	SECONDARY,
}

## Populated in `register_weapons.gd`
static var weapon_type_to_scene : Dictionary[Type, PackedScene] = {}

var type : Type

var damage_mult
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

## The current primary attack.
var primary_attack : Attack

## The current primary attack.
var secondary_attack : Attack

## Describes which attack indices are used in each attack type. 
## Should be populated by a subclass before any attacking occurs.
var attack_types_to_indices : Dictionary[AttackType, Array] = {
	AttackType.PRIMARY : [],
	AttackType.SECONDARY : [],
}

#region Attack child class, describing stats of a singular attack
class Attack:
	var type : AttackType
	var damage : Stat
	var attack_speed : Stat
	var area : Stat
	var range : Stat

	func _init(_type : AttackType) -> void:
		type = _type
		
		damage = Stat.new()
		attack_speed = Stat.new()
		area = Stat.new()
		range = Stat.new()
		
		damage.set_base(1.0)
		attack_speed.set_base(1.0)
		area.set_base(1.0)
		range.set_base(1.0)
	
	## Getters
	func get_damage():
		return damage.value()
	func get_area():
		return area.value()
	func get_range():
		return range.value()
	func get_attack_speed():
		return attack_speed.value()
#endregion Attack child class


@onready var detached_projectiles = $DetachedProjectiles

static func init_weapon(_type : Type):
	var new_weapon = weapon_type_to_scene[_type].instantiate()
	new_weapon.type = _type
	return new_weapon

func _init():
	player = Global.player

func _process(delta : float) -> void:
	if Input.is_action_pressed("attack"):
		start_attack(AttackType.PRIMARY)
	if Input.is_action_pressed("secondary_attack"):
		start_attack(AttackType.SECONDARY)


#region Attacks
func start_attack(attack_type : AttackType):
	match attack_type:
		AttackType.PRIMARY:
			if can_primary_attack():
				var new_attack : Attack = Attack.new(attack_type)
				primary_attack = new_attack
				attack_initiated.emit(new_attack)
				do_primary_attack()
		AttackType.SECONDARY:
			if can_secondary_attack():
				var new_attack : Attack = Attack.new(attack_type)
				secondary_attack = new_attack
				attack_initiated.emit(new_attack)
				do_secondary_attack()


## Subclasses must implement this method. `primary_weapon` is populated before this method is run. 
func do_primary_attack():
	pass

## Subclasses must implement this method. `secondary_weapon` is populated before this method is run. 
func do_secondary_attack():
	pass

## Subclasses must implement this method. `primary_weapon` is populated before this method is run. 
func can_primary_attack():
	pass

## Subclasses must implement this method. `secondary_weapon` is populated before this method is run. 
func can_secondary_attack():
	pass

func end_attack(attack_type : AttackType):
	match attack_type:
		AttackType.PRIMARY:
			primary_attack = null
		AttackType.SECONDARY:
			secondary_attack = null
#endregion Attacks


#region Stat calculation methods

func get_attack(attack_type : AttackType):
	match attack_type:
		AttackType.PRIMARY:
			return primary_attack
		AttackType.SECONDARY:
			return secondary_attack
		_: 
			assert(false)

func get_area(attack_type := AttackType.PRIMARY, include_base := true) -> float:
	return (area if include_base else 1.0) * player.get_area() * get_attack(attack_type).get_area()

func get_range(attack_type := AttackType.PRIMARY, include_base := true) -> float:
	return (range if include_base else 1.0) * player.get_range() * get_attack(attack_type).get_range()

func get_attack_speed(attack_type := AttackType.PRIMARY, include_base := true) -> float:
	return (attack_speed if include_base else 1.0) * player.get_attack_speed() * get_attack(attack_type).get_attack_speed()

## Given an attack index (1,2,3,4), returns its damage value as a float multiplier of base damage.
func get_attack_damage(attack_idx : int) -> float:
	return damage_arr[attack_idx - 1] * get_attack(get_attack_type(attack_idx)).get_damage()

#endregion Stat calculation methods

#region Dealing damage with hitboxes
## Returns the AttackType of an attack index. Depending on the weapon, multiple attack indices 
## could be used for PRIMARY or SECONDARY attacks. 
func get_attack_type(attack_idx : int) -> AttackType:
	for attack_type : AttackType in AttackType.values():
		if attack_types_to_indices[attack_type].has(attack_idx):
			return attack_type
	assert(false)
	return AttackType.PRIMARY

## Given an attack index (1,2,3,4), returns its list of enemies hit.
func get_enemies_hit(attack_idx : int) -> Array[Enemy]:
	return enemies_hit_arr[attack_idx - 1]

## Deals attack_damage * base_damage to the enemy, adding it to the respective enemies_hit array.
## Returns the damage dealt. Returns 0 if the enemy cannot be hit by this attack.
func deal_damage(attack_idx : int, to_enemy : Enemy, damage := -1.0):
	if not to_enemy in get_enemies_hit(attack_idx):
		if damage == -1.0: # Need to calculate actual damage, since it wasn't supplied
			damage = player.get_base_damage() 
			damage *= get_attack_damage(attack_idx)
		to_enemy.take_damage(damage)
		get_enemies_hit(attack_idx).append(to_enemy)
		attack_hit.emit(get_attack(get_attack_type(attack_idx)), damage, to_enemy)
		return damage
	else:
		return 0

## Clears the given attacks' enemies hit arrays, so that enemies can be hit by the attack again.
func clear_enemies_hit(attack_idxs : Array[int] = [1, 2, 3, 4]):
	for idx in attack_idxs:
		get_enemies_hit(idx).clear()

#endregion Dealing damage with hitboxes
