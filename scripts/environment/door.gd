extends Node2D

## Entrances and exits to rooms. Have color-coded types that define their respective room.
class_name Door

var type : Room.Type

## If locked, player cannot enter.
var locked := true
## True after the player enters this door's hitbox. 
var player_entered := false

# TODO unlock on condition, depending on the room this door is in


func _ready():
	Global.perk_ui.locked_in.connect(go_to_next_room)

## Triggers a lock in sequence upon the player entering this door.
func enter_door():
	player_entered = true
	Loop.stop_running()
	Global.perk_ui.start_lock_in_sequence()


func go_to_next_room():
	if player_entered:
		Global.floor.generate_new_room.call_deferred(global_position)
		Loop.start_running.call_deferred()
		Loop.global_speed.append_add_mod(1.0)

# TODO on player enter: generate and switch to new room of this door's type
func _on_area_2d_body_entered(body):
	if body is Player:
		if not locked:
			enter_door()
