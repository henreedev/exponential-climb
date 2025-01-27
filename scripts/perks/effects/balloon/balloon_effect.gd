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


func attach_balloon(attack : Weapon.Attack, damage_dealt : int, enemy : Enemy):
	if attack == buffed_attack:
		var balloon = BALLOON.instantiate()
		balloon.parent_enemy = enemy
		balloon.stored_damage = damage_dealt
		balloon.duration = value
		Global.game.add_child(balloon)
		balloon.global_position = enemy.global_position + Vector2(0, -16)
		balloon.reset_physics_interpolation()
