extends Node2D

class_name Weapon

enum Type {
	GRAPPLE_HOOK, BOOTS, WINGS, TELEPORT
}

const PLAYER_CLASS_TO_WEAPON_TYPE : Dictionary[Player.ClassType, Type] = {
	Player.ClassType.LEAD : Type.GRAPPLE_HOOK,
	Player.ClassType.BRUTE : Type.BOOTS,
	Player.ClassType.ANGEL : Type.WINGS,
}

## Populated in `register_weapons.gd`
static var weapon_type_to_scene : Dictionary[Type, PackedScene] = {}

var type : Type
var power : Stat
var area : Stat
var attack_range : Stat
var projectile_speed : Stat
var player : Player

@onready var detached_projectiles = $DetachedProjectiles

static func init_weapon(_type : Type):
	var new_weapon = weapon_type_to_scene[_type].instantiate()
	new_weapon.type = _type
	return new_weapon

func _init():
	power = Stat.new()
	area = Stat.new()
	attack_range = Stat.new()
	attack_range.set_base(1)
	projectile_speed = Stat.new()
	projectile_speed.set_base(1)
	player = Global.player
	

func set_type_by_player_class(class_type : Player.ClassType):
	type = PLAYER_CLASS_TO_WEAPON_TYPE[class_type]
