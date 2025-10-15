extends Effect

class_name MuscleEffect

const AREA_BUFF := 1.5

var mod : StatMod

func _start_effect():
	context.player.weapon.attack_initiated.connect(buff_attack)
	mod = target_stat.append_mult_mod(value)
	attached_mods[mod] = target_stat 

func buff_attack(attack : Weapon.Attack):
	if Global.player.is_on_floor():
		attack.area.append_mult_mod(AREA_BUFF)

func do_end_effect():
	context.player.weapon.attack_initiated.disconnect(buff_attack)
