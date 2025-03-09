extends Effect

class_name SunsetEffect

var same_count := 0
var same_type : Weapon.AttackType

func _start_effect():
	context.player.weapon.attack_initiated.connect(buff_attack)

func buff_attack(attack : Weapon.Attack):
	if attack.type == same_type:
		same_count = mini(same_count + 1, 10)
		attack.area.append_add_mod(value * same_count)
	else:
		same_type = attack.type
		same_count = 0
		return

func do_end_effect():
	context.player.weapon.attack_initiated.disconnect(buff_attack)
