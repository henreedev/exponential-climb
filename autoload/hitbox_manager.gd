extends Node

class_name HitboxManager

#signal took_damage(amount: int)

## Searches recursively for any Hitboxes under the parent node, hooking them up 
## to the parent node's take_damage method (this must exist).
#func connect_hitboxes(parent: Node):
	

#func _on_hitbox_took_damage(amount: int):
	# TODO logic for hitbox groups taking only one hit
	#took_damage.emit(amount)
