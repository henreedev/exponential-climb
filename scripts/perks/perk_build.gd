extends Resource
## Contains a Player's set of perks. Can be active or passive. 
class_name PerkBuild

## Determines whether this is an Active or Passive perk 
## build (not whether it's enabled or not)
var is_active : bool 
var perks : Array[Perk]
## The extra size added to the perk build's length.
var extra_size : int
## The size of the perk build.
var size : int


func _init() -> void:
	Global.max_perks_updated.connect(_resize_to_max)
	_resize_to_max()


## Fills the perks array with nulls until reaching the global max perks size. 
func _resize_to_max():
	size = Global.max_build_size + extra_size
	while(perks.size() < size):
		perks.append(null) # null acts as an empty perk slot
		

func set_extra_size(_extra_size : int):
	extra_size = _extra_size
	_resize_to_max()

func deactivate():
	for perk : Perk in perks:
		if perk != null:
			perk.deactivate()

## Places the given perk at the given index, returning the Perk that gets replaced (if it exists).
func place_perk(perk : Perk, index : int) -> Perk:
	var replaced_perk := perks[index]
	perks[index] = perk
	if replaced_perk:
		replaced_perk.refresh_context(null, -1)
	_refresh_build()
	return replaced_perk


## Removes the perk at the given index, returning it (if it exists).
func remove_perk(index : int) -> Perk:
	var removed_perk := perks[index]
	if removed_perk != null:
		removed_perk.refresh_context(null, -1)
		_refresh_build()
		return removed_perk
	else:
		return null


func _refresh_build():
	for i in range(size):
		if perks[i] != null:
			perks[i].refresh_context(self, i)
