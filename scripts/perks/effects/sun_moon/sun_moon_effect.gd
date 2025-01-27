extends Effect

class_name SunMoonEffect

func _start_effect():
	context.player.weapon.attack_initiated.connect(buff_attack)

func buff_attack(attack : Weapon.Attack):
	match attack.type:
		Weapon.AttackType.PRIMARY:
			# If secondary on cooldown, deal extra damage
			if not context.player.weapon.can_secondary_attack():
				attack.damage.append_mult_mod(value)
		Weapon.AttackType.SECONDARY:
			# If primary on cooldown, deal extra damage
			if not context.player.weapon.can_primary_attack():
				attack.damage.append_mult_mod(value)

func do_end_effect():
	context.player.weapon.attack_initiated.disconnect(buff_attack)
