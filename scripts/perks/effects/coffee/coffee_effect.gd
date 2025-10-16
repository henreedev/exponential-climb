extends Effect

class_name CoffeeEffect

func _start_effect():
	var atk_spd_mod : StatMod = Global.player.attack_speed.append_mult_mod(value)
	attached_mods.append(atk_spd_mod)
	var move_spd_mod : StatMod = Global.player.movement_speed.append_mult_mod(value)
	attached_mods.append(move_spd_mod)
	PerkArtParticle.create(Perk.Type.COFFEE, Global.player, 1.0, Vector2(0, -20))
