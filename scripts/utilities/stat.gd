extends Resource
## Stat class that has a base value and can append modifiers in a specific order.
class_name Stat

@export var base := 0.0
@export var is_int := false

var mods : Array[Mod]

func set_base(value : float):
	base = value

func set_type(_is_int : bool):
	is_int = _is_int

## Appends a multiplicative modifier to this stat.
func append_mult_mod(value : float) -> Mod:
	var mult_mod = Mod.new()
	mult_mod.type = Mod.Type.MULTIPLICATIVE
	mult_mod.value = value
	mods.append(mult_mod)
	return mult_mod

## Appends an additive modifier to this stat.
func append_add_mod(value : float) -> Mod:
	var add_mod = Mod.new()
	add_mod.type = Mod.Type.ADDITIVE
	add_mod.value = value
	mods.append(add_mod)
	return add_mod

func get_final_value():
	var final_value := base
	for mod : Mod in mods:
		match mod.type:
			Mod.Type.ADDITIVE:
				final_value += mod.value
			Mod.Type.MULTIPLICATIVE:
				final_value *= mod.value
	if is_int:
		return int(final_value)
	else: 
		return final_value

func remove_mod(mod : Mod):
	mods.erase(mod)

func clear_mods():
	mods.clear()
