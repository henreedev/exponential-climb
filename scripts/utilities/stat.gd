extends Resource
## Stat class that has a base value and can append modifiers in a specific order.
class_name Stat

signal mods_changed

@export var base := 0.0
@export var is_int := false

var mods : Array[StatMod]

## Returns a float value as a percentage (1.0 -> "100%", 3.568 -> "357%")
static func float_to_percent_string(value : float):
	return str(int(roundf(value * 100))) + "%"

func set_base(value : float):
	base = value

func set_type(_is_int : bool):
	is_int = _is_int

## Appends a multiplicative modifier to this stat.
func append_mult_mod(value : float) -> StatMod:
	var mult_mod = StatMod.new()
	mult_mod.type = StatMod.Type.MULTIPLICATIVE
	mult_mod.value = value
	mods.append(mult_mod)
	mods_changed.emit()
	return mult_mod

## Appends an additive modifier to this stat.
func append_add_mod(value : float) -> StatMod:
	var add_mod = StatMod.new()
	add_mod.type = StatMod.Type.ADDITIVE
	add_mod.value = value
	add_mod.parent = self
	mods.append(add_mod)
	mods_changed.emit()
	return add_mod

## Returns the final value of this stat, taking the base value and adding on modifiers in order.  
func value():
	var final_value := base
	for mod : StatMod in mods:
		match mod.type:
			StatMod.Type.ADDITIVE:
				final_value += mod.value
			StatMod.Type.MULTIPLICATIVE:
				final_value *= mod.value
	if is_int:
		return int(final_value)
	else: 
		return final_value

func remove_mod(mod : StatMod):
	# Check how many mods there are, to see if mods change due to removal
	var num_mods = len(mods)
	
	mods.erase(mod)
	
	# Notify if the mods changed
	if num_mods != len(mods):
		mods_changed.emit()

func clear_mods():
	# Check how many mods there are, to see if mods change due to clearing
	var num_mods = len(mods)
	
	mods.clear()
	
	# Notify if the mods changed
	if num_mods > 0:
		mods_changed.emit()
