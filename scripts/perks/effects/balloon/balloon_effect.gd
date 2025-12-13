extends Effect

class_name BalloonEffect

const BALLOON = preload("res://scenes/perks/effects/balloon/balloon.tscn")

## Store the buffed attack to check whether a weapon hit was from the buffed attack
## (if so, spawn apple particle).
var buffed_attack : Weapon.Attack

func _start_effect():
	context.player.weapon.attack_initiated.connect(buff_attack)
	context.player.weapon.attack_hit.connect(attach_balloon)

func buff_attack(attack : Weapon.Attack):
	buffed_attack = attack
	end_effect()

func do_end_effect():
	context.player.weapon.attack_initiated.disconnect(buff_attack)


func attach_balloon(attack : Weapon.Attack, damage_dealt : int, hitbox: Hitbox):
	if attack == buffed_attack:
		var balloon = BALLOON.instantiate()
		var hitbox_parent: Enemy = hitbox.get_hitbox_parent()
		assert(hitbox_parent)
		balloon.parent_enemy = hitbox_parent
		balloon.stored_damage = damage_dealt
		balloon.duration = value
		Global.game.add_child(balloon)
		balloon.set_pos_to_parent_pos_with_offset()
		balloon.reset_physics_interpolation()
