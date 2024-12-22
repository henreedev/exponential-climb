extends Node

class_name Weapon

enum Type {
	GRAPPLE_HOOK, BOOTS, WINGS
}

const PLAYER_CLASS_TO_WEAPON_TYPE_DICT : Dictionary[Player.ClassType, Type] = {
	Player.ClassType.LEAD : Type.GRAPPLE_HOOK,
	Player.ClassType.BRUTE : Type.BOOTS,
	Player.ClassType.ANGEL : Type.WINGS,
}

var type : Type
var power : Stat

func set_type_by_player_class(class_type : Player.ClassType):
	type = PLAYER_CLASS_TO_WEAPON_TYPE_DICT[class_type]
