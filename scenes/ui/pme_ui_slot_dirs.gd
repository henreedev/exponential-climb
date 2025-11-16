extends Control

class_name PmeUiSlotDirs


var pme: PerkModEffect


@onready var Self: Sprite2D = $Self
@onready var right: Sprite2D = $Right
@onready var left: Sprite2D = $Left
@onready var down: Sprite2D = $Down
@onready var up: Sprite2D = $Up

@onready var enum_dir_to_node_dir: Dictionary[PerkMod.Direction, Sprite2D] = {
	PerkMod.Direction.SELF : Self,
	PerkMod.Direction.RIGHT : right,
	PerkMod.Direction.LEFT : left,
	PerkMod.Direction.DOWN : down,
	PerkMod.Direction.UP : up,
}

func initialize(parent_pme: PerkModEffect):
	pme = parent_pme
	refresh()

func refresh():
	var active_tint_color := get_tint_color(pme.is_buff())
	const INACTIVE_TINT_COLOR := Color(0.5,0.5,0.5,0.5)
	
	for dir: PerkMod.Direction in enum_dir_to_node_dir:
		if pme.has_direction(dir):
			enum_dir_to_node_dir[dir].modulate = active_tint_color
		else:
			enum_dir_to_node_dir[dir].modulate = INACTIVE_TINT_COLOR

static func get_tint_color(is_buff: bool) -> Color:
	return Color.GREEN_YELLOW if is_buff else Color.CRIMSON
