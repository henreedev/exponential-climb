extends Resource
## Helper class used by Stats to add on modifiers to the stat value.
class_name Mod

enum Type {ADDITIVE, MULTIPLICATIVE}

var type : Type

var value : float
