extends Resource
## Helper class used by Stats to add on modifiers to the stat value.
class_name StatMod

enum Type {ADDITIVE, MULTIPLICATIVE}

var type : Type

var value : float
var inverted := false

var parent : Stat


func remove_from_parent_stat():
	if parent:
		parent.remove_mod(self)

func invert():
	inverted = not inverted
	match type:
		Type.ADDITIVE:
			value = -value
		Type.MULTIPLICATIVE:
			value = 1.0 / value
