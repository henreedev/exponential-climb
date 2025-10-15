extends Effect
 
## Applies a mod multiplying `target_stat` by `value`.
class_name MultiplicativeModEffect


func _start_effect():
	if target_stat:
		var mod : StatMod = target_stat.append_mult_mod(value)
		attached_mods[mod] = target_stat 
