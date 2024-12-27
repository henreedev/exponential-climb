extends Resource

## An object containing relevant information on a perk for an effect to use.
class_name PerkContext

## This class stores the neighbors of a perk as a context for its effects to access.
## Active perks only need context of other perks in the active build; they don't
## interact with the passive build, since it's locked in before a room.
## Passive perks need context of other passive perks, but also active perks, 
## in case they affect those.

## The build this perk is inside of.
var build : PerkBuild

var perk : Perk ## The parent perk of this context.
var player : Player ## The player holding this perk.

var slot_index : int

var is_active : bool

var left_neighbor : Perk
var right_neighbor : Perk

var second_left_neighbor : Perk
var second_right_neighbor : Perk

var left_neighbors : Array[Perk]
var right_neighbors : Array[Perk]

## Active perk versions of neighbor fields, for passive perks to use 
var active_perk : Perk ## The active perk in the same slot index as the passive perk.

var active_left_neighbor : Perk
var active_right_neighbor : Perk

var active_second_left_neighbor : Perk
var active_second_right_neighbor : Perk

var active_left_neighbors : Array[Perk]
var active_right_neighbors : Array[Perk]

## Initializes a perk context, attaching it to a perk.
func initialize(_perk : Perk, _player : Player, _build : PerkBuild = null, _slot_index := -1):
	perk = _perk
	player = _player
	slot_index = _slot_index
	is_active = perk.is_active
	build = _build
	if slot_index != -1 and _build != null:
		refresh(_build, slot_index)


## Updates this perk context to be up to date after perks have moved. 
func refresh(_build : PerkBuild, new_slot_index : int):
	build = _build
	if not _within_build_bounds(_build, new_slot_index):
		# Perk is no longer within build
		_clear()
	else:
		# Perk is still in build - populate neighbors
		slot_index = new_slot_index
		_populate_neighbors()


func _clear():
	# Perk is not currently in a build 
	slot_index = -1
	left_neighbor = null
	right_neighbor = null
	second_left_neighbor = null
	second_right_neighbor = null
	left_neighbors = []
	right_neighbors = []
	
	active_left_neighbor = null
	active_right_neighbor = null
	active_second_left_neighbor = null
	active_second_right_neighbor = null
	active_left_neighbors = []
	active_right_neighbors = []


## Populates fields that inform a perk of its neighbors.
## If passive, also populates neighbor information for the active build.
func _populate_neighbors():
	pass
	
	#left_neighbor = _get_perk_by_offset(-1)
	#right_neighbor = _get_perk_by_offset(1)
	#second_left_neighbor = _get_perk_by_offset(-2)
	#second_right_neighbor = _get_perk_by_offset(2)
	#left_neighbors = _get_perks_or_empty(true)
	#right_neighbors = _get_perks_or_empty(false)

	#if not is_active:
		#active_perk = _get_perk_by_offset(0, true)
		#active_left_neighbor = _get_perk_by_offset(-1, true)
		#active_right_neighbor = _get_perk_by_offset(1, true)
		#active_second_left_neighbor = _get_perk_by_offset(-2, true)
		#active_second_right_neighbor = _get_perk_by_offset(2, true)
		#active_left_neighbors = _get_perks_or_empty(true, true)
		#active_right_neighbors = _get_perks_or_empty(false, true)


## Returns the perk at the given offset in this perk's build, null if empty or out of range
func _get_perk_by_offset(index_offset : int, get_active := is_active) -> Perk:
	return _get_perk_safe(slot_index + index_offset, get_active)


func _get_perk_safe(index : int, get_active := is_active) -> Perk:
	if _within_build_bounds(build, index):
		return build.perks[index]
	else:
		return null


## Returns the left or right neighbors of this perk, or an empty list if none exist
func _get_perks_or_empty(left : bool, get_active := is_active) -> Array[Perk]:
	var perks : Array[Perk] = []
	if left:
		for i in range(0, slot_index):
			var found_perk = _get_perk_safe(i, get_active)
			if found_perk: perks.append(found_perk)
	else:
		for i in range(slot_index + 1, Global.max_perks):
			var found_perk = _get_perk_safe(i, get_active)
			if found_perk: perks.append(found_perk)
	return perks


static func _within_build_bounds(_build : PerkBuild, index : int):
	if not _build: return false
	return index >= 0 and index < _build.size
