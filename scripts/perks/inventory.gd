extends Node2D
## Stores extra perks for a player to manage their inventory with. Has a set amount of slots.  
class_name Inventory


#region UI logic
## How far apart slots are vertically.
const SLOT_POS_OFFSET = Vector2(0, 36)
## How many pixels away a held perk can be let go to land into this slot.
const SLOT_SNAP_DIST = 40.0
## Centers correctly for 4 slots
const TOPMOST_SLOT_POS = -1 * SLOT_POS_OFFSET

#endregion UI logic

#region Gameplay logic
var perks : Array[Perk]
## The total size of the perk build.
const size := 3
#endregion Gameplay logic


func _ready() -> void:
	_init_empty_slots()
#region Gameplay methods
## Fills the perks array with nulls until reaching the global max perks size. 
func _init_empty_slots():
	while perks.size() < size:
		var empty_perk = create_empty_perk()
		perks.append(empty_perk) 
	_refresh_all_perk_contexts()
	move_perks_to_slot_positions()

## Places the given perk at the given index, returning the Perk that gets replaced (if it exists).
## If a perk gets replaced, it swaps indices (and/or builds) with the new perk.
func place_perk(perk : Perk, index : int) -> Perk:
	# Store old perk at this index
	var replaced_perk := perks[index]
	# Place new perk at the index
	perks[index] = perk
	perk.disable_trigger()
	perk.refresh_context(null, -1)
	if replaced_perk:
		# Try placing it into the replacing perk's build
		var old_index = perk.context.slot_index
		var old_build = perk.context.build
		if old_build:
			old_build.perks[old_index] = replaced_perk
		else:
			# Try placing it into the inventory slot it was in
			var old_inv_idx = perk.context.inventory_slot_index
			if old_inv_idx >= 0:
				replaced_perk.context.set_inventory_slot(old_inv_idx)
				perks[old_inv_idx] = replaced_perk
	
	# Ensure perks in all builds think they're in the correct slots
	# and see correct neighbors
	_refresh_all_perk_contexts()
	move_perks_to_slot_positions()
	
	return replaced_perk


## Removes the perk at the given index, returning it (if it exists).
func remove_perk(index : int) -> Perk:
	var removed_perk := perks[index]
	if removed_perk != null:
		perks[index] = create_empty_perk()
		removed_perk.refresh_context(null, -1)
		_refresh_all_perk_contexts()
		move_perks_to_slot_positions()
		return removed_perk
	else:
		return null

func create_empty_perk() -> Perk:
	var empty_perk = Perk.init_perk(Perk.Type.EMPTY)
	add_child(empty_perk)
	return empty_perk


func _refresh_all_perk_contexts():
	var all_builds = get_tree().get_nodes_in_group("perk_build")
	var all_perks = get_tree().get_nodes_in_group("perk")
	# Ensure perks know their build and slot index
	for build: PerkBuild in all_builds:
		for i in range(build.size):
			if build.perks[i] != null:
				build.perks[i].refresh_context(build, i)
	# Recalculate perk neighbors
	for perk: Perk in all_perks:
		perk.repopulate_context_neighbors()
	# Now that all perk neighbors are fully recalculated,
	# indicate the update to perks.
	for perk: Perk in all_perks:
		perk.emit_context_updated()
#endregion Gameplay methods

#region UI logic
## Returns the index of the slot nearest to the given position.
func pos_to_nearest_idx(pos : Vector2) -> int:
	var nearest_idx := -1
	var nearest_dist := INF
	for i in range(size):
		var slot_pos = idx_to_pos(i)
		var dist = slot_pos.distance_to(pos)
		if dist <= SLOT_SNAP_DIST and dist < nearest_dist:
			nearest_idx = i
			nearest_dist = dist
	return nearest_idx

func idx_to_pos(idx : int):
	return TOPMOST_SLOT_POS + idx * SLOT_POS_OFFSET

func idx_to_perk(idx : int):
	if idx >= -1 and idx < size:
		return perks[idx]
	return null

func move_perks_to_slot_positions():
	for i in range(perks.size()):
		var perk : Perk = perks[i]
		if perk:
			perk.root_pos = idx_to_pos(i)
			perk.move_to_root_pos()

#endregion UI logic
