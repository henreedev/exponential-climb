extends Node2D

## Entrances and exits to rooms. Have color-coded types that define their respective room.
class_name Door

var type : Room.Type

var locked := true


# TODO unlock on condition, depending on the room this door is in


# TODO on player enter: generate and switch to new room of this door's type
func _on_area_2d_body_entered(body):
	if body is Player:
		if not locked:
			Global.floor.generate_new_room.call_deferred(global_position)
