extends Effect

class_name AppleEffect

const APPLE_PARTICLE = preload("res://scenes/perks/effects/apple/apple_particle.tscn")

## Store the buffed attack to check whether a weapon hit was from the buffed attack
## (if so, spawn apple particle).
var buffed_attack : Weapon.Attack

func _start_effect():
	context.player.weapon.attack_initiated.connect(buff_attack)
	context.player.weapon.attack_hit.connect(spawn_apple_particle)

func buff_attack(attack : Weapon.Attack):
	attack.damage.append_mult_mod(value)
	buffed_attack = attack
	end_effect()

func do_end_effect():
	context.player.weapon.attack_initiated.disconnect(buff_attack)

func spawn_apple_particle(attack : Weapon.Attack, damage_dealt : int, enemy : Enemy):
	if attack == buffed_attack:
		var apple_particle = APPLE_PARTICLE.instantiate()
		Global.game.add_child(apple_particle)
		apple_particle.global_position = enemy.global_position
		apple_particle.reset_physics_interpolation()
