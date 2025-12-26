extends Node2D

## Entrances and exits to rooms. Have color-coded types that define their respective room.
class_name Door

## If locked, player cannot enter.
var locked := true
## True after the player enters this door's hitbox. 
var player_entered := false

func _ready():
	Global.perk_ui.locked_in.connect(go_to_next_room)

## Triggers a lock in sequence upon the player entering this door.
func enter_door():
	if not player_entered:
		player_entered = true
		Loop.stop_running()
		Global.perk_ui.start_lock_in_sequence()


func go_to_next_room():
	if player_entered:
		Global.current_floor.swap_to_next_room()
		Loop.start_running.call_deferred()
		Loop.loop_speed.append_add_mod(1.0)

func _on_area_2d_body_entered(body):
	if body is Player:
		if not locked:
			enter_door()
