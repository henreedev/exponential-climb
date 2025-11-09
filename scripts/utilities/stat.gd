extends Resource
## Stat class that has a base value and can append modifiers in a specific order.
class_name Stat

signal mods_changed

@export var base := 0.0
@export var is_int := false
@export_group("Minimum Value")
@export var has_minimum := false
@export var minimum_value: float

var mods : Array[StatMod]

## Returns a float value as a percentage (1.0 -> "100%", 3.568 -> "357%")
static func float_to_percent_string(value : float):
	return str(int(roundf(value * 100))) + "%"

func set_base(value : float):
	base = value

func set_type(_is_int : bool):
	is_int = _is_int

func set_minimum(val : float):
	has_minimum = true
	minimum_value = val

## Appends a multiplicative modifier to this stat.
func append_mult_mod(value : float) -> StatMod:
	var mult_mod = StatMod.new()
	mult_mod.type = StatMod.Type.MULTIPLICATIVE
	mult_mod.value = value
	append_mod(mult_mod)
	return mult_mod

## Appends an additive modifier to this stat.
func append_add_mod(value : float) -> StatMod:
	var add_mod = StatMod.new()
	add_mod.type = StatMod.Type.ADDITIVE
	add_mod.value = value
	append_mod(add_mod)
	return add_mod

func append_mod(mod: StatMod) -> StatMod:
	mod.parent = self
	mods.append(mod)
	mods_changed.emit()
	return mod

## Returns the final value of this stat, taking the base value and adding on modifiers in order.  
func value():
	var final_value := base
	for mod : StatMod in mods:
		match mod.type:
			StatMod.Type.ADDITIVE:
				final_value += mod.value
			StatMod.Type.MULTIPLICATIVE:
				final_value *= mod.value
	if has_minimum:
		final_value = max(final_value, minimum_value)
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

func to_calculation_string():
	var calculation_string := str(base)
	var final_value := base
	
	# Store last mod type as enum or null here. If last was 
	var last_mod_type = null
	
	const TIMES = "×"
	const PLUS = "+"
	const EQUALS = "="
	
	for mod : StatMod in mods:
		match mod.type:
			StatMod.Type.ADDITIVE:
				final_value += mod.value
				calculation_string += PLUS + " " + clean_float(mod.value)
			StatMod.Type.MULTIPLICATIVE:
				final_value *= mod.value
				if last_mod_type == StatMod.Type.ADDITIVE:
					# Add parens
					calculation_string = "(" + calculation_string + ")"
				calculation_string += TIMES + " " + clean_float(mod.value)
		last_mod_type = mod.type
	
	if has_minimum:
		if final_value < minimum_value:
			calculation_string += " with min(" + clean_float(minimum_value) + ")"
		final_value = max(final_value, minimum_value)
	if is_int:
		if int(final_value) != final_value:
			calculation_string += " as int"
	# Add final equals
	calculation_string += " " + EQUALS + " " + clean_float(final_value)
	
	# Add wave teehee
	calculation_string = "[wave amp=5.0 freq=2.0 connected=1]" + calculation_string + "[/wave]"
	return calculation_string;

func clean_float(val: float):
	return PerkCard.get_float_string_with_fewest_decimals(val)
