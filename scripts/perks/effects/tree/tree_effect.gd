extends Effect

class_name TreeEffect

const PLAYER_BUFF_RATIO := 1.5

func _start_effect():
	var increase_mod : StatMod = Loop.global_increase.append_mult_mod(value)
	var player_speed_mod : StatMod = Loop.player_speed.append_mult_mod((value - 1) * PLAYER_BUFF_RATIO + 1)
	attached_mods[increase_mod] = Loop.global_increase
	attached_mods[player_speed_mod] = Loop.player_speed
