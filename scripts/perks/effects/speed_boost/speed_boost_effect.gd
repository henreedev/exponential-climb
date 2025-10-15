extends Effect

class_name SpeedBoostEffect

func _start_effect():
	var atk_spd_mod : StatMod = Global.player.attack_speed.append_mult_mod(value)
	attached_mods[atk_spd_mod] = Global.player.attack_speed 
	var move_spd_mod : StatMod = Global.player.movement_speed.append_mult_mod(value)
	attached_mods[move_spd_mod] = Global.player.movement_speed 
	var base_dmg_mod : StatMod = Global.player.base_damage.append_mult_mod(value)
	attached_mods[base_dmg_mod] = Global.player.base_damage 
	var half_val = ((value - 1) / 2.0 + 1)
	PerkArtParticle.create(Perk.Type.SPEED_BOOST, Global.player, 1.0, Vector2(0, -20) * half_val, 8.0, Vector2(half_val, half_val))
