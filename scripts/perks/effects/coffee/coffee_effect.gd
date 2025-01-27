extends Effect

class_name CoffeeEffect

func _start_effect():
	var atk_spd_mod : Mod = Global.player.attack_speed.append_mult_mod(value)
	attached_mods[atk_spd_mod] = Global.player.attack_speed 
	var move_spd_mod : Mod = Global.player.movement_speed.append_mult_mod(value)
	attached_mods[move_spd_mod] = Global.player.movement_speed 
	PerkArtParticle.create(Perk.Type.COFFEE, Global.player, 1.0, Vector2(0, -20))
