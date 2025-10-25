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
var up_neighbor : Perk
var down_neighbor : Perk

var second_left_neighbor : Perk
var second_right_neighbor : Perk
var second_up_neighbor : Perk
var second_down_neighbor : Perk

var left_neighbors : Array[Perk]
var right_neighbors : Array[Perk]
var up_neighbors : Array[Perk]
var down_neighbors : Array[Perk]

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
		# Perk is still in some build - populate neighbors
		slot_index = new_slot_index
		populate_neighbors()

func _clear():
	# Perk is not currently in a build 
	slot_index = -1
	
	left_neighbor = null
	right_neighbor = null
	up_neighbor = null
	down_neighbor = null
	
	second_left_neighbor = null
	second_right_neighbor = null
	second_up_neighbor = null
	second_down_neighbor = null
	
	left_neighbors = []
	right_neighbors = []
	up_neighbors = []
	down_neighbors = []

## Populates fields that inform a perk of its neighbors.
func populate_neighbors():
	if build: 
		left_neighbor = _get_perk_by_offset(-1, 0)
		right_neighbor = _get_perk_by_offset(1, 0)
		up_neighbor = _get_perk_by_offset(0, -1)
		down_neighbor = _get_perk_by_offset(0, 1)
		
		second_left_neighbor = _get_perk_by_offset(-2, 0)
		second_right_neighbor = _get_perk_by_offset(2, 0)
		second_up_neighbor = _get_perk_by_offset(0, -2)
		second_down_neighbor = _get_perk_by_offset(0, 2)
		
		left_neighbors = _get_perks_in_direction(-1, 0)
		right_neighbors = _get_perks_in_direction(1, 0)
		up_neighbors = _get_perks_in_direction(0, -1)
		down_neighbors = _get_perks_in_direction(0, 1)

## Returns the perk at the given offset in this perk's build, null if empty or out of range
func _get_perk_by_offset(index_offset : int, build_offset: int) -> Perk:
	var offsetted_slot_index = slot_index + index_offset
	var offsetted_build_index = build.index + build_offset
	return _get_perk_safe(offsetted_slot_index, Global.get_build_safe(offsetted_build_index))

func _get_perks_in_direction(index_dir: int, build_dir: int) -> Array[Perk]:
	assert(abs(index_dir) <= 1)
	assert(abs(build_dir) <= 1)
	var perks: Array[Perk] = []
	if index_dir:
		for idx in range(slot_index + index_dir, slot_index + index_dir * (Global.max_build_size + 1), index_dir):
			var _perk: Perk = _get_perk_safe(idx, build)
			if _perk:
				perks.append(_perk)
	elif build_dir:
		for bld_idx in range(build.index + build_dir, build.index + build_dir * (Global.max_build_size + 1), build_dir):
			var _perk: Perk = _get_perk_safe(slot_index, Global.get_build_safe(bld_idx))
			if _perk:
				perks.append(_perk)
	else:
		assert(false)
	return perks

func _get_perk_safe(index : int, _build: PerkBuild) -> Perk:
	if _within_build_bounds(_build, index):
		var _perk := _build.perks[index]
		#if not _perk.is_empty_perk(): # FIXME 
		return _perk
	return null

static func _within_build_bounds(_build : PerkBuild, index : int):
	if not _build: return false
	return index >= 0 and index < _build.size
