extends Node2D
## Contains a Player's set of perks. Can be active or passive. 
class_name PerkBuild


#region UI logic
# Placement of slots
## How far apart slots are horizontally.
const SLOT_POS_OFFSET = Vector2(36, 0) # TODO change to 38 by adjusting art
## How many pixels away a held perk can be let go to land into this slot.
const SLOT_SNAP_DIST = 40.0
## Centers correctly for 4 slots
const LEFTMOST_SLOT_POS = -1.5 * SLOT_POS_OFFSET

## The build's sprite, showing empty perk slots and locked slots.
@onready var build_sprite: AnimatedSprite2D = $BuildSprite
#endregion UI logic

#region Gameplay logic
## Determines whether this is an Active or Passive perk 
## build (not whether it's enabled or not)
@export var is_active : bool 
var perks : Array[Perk]
## The extra size added to the perk build's length.
var extra_size : int
## The size of the perk build before any modifiers. Exported for testing.
@export var base_size := 1
## The total size of the perk build.
var size : int
#endregion Gameplay logic


func _ready() -> void:
	_resize_to_max()
	Global.player.add_build(self) 

#region Gameplay methods
func add_perk_slot(amount: int):
	base_size = mini(base_size + amount, Global.BUILD_SIZE + extra_size)
	
	_resize_to_max()

## Sets build_sprite animation to indicate the number of locked slots, and whether this build is 
## active or passive. Ex: "0_locked_passive"
func _pick_lock_animation():
	var anim_str = ""
	
	var num_locked_slots = Global.BUILD_SIZE - get_size()
	assert(num_locked_slots >= 0)
	anim_str = anim_str + str(num_locked_slots) + "_locked_"
	
	
	if is_active:
		anim_str = anim_str + "active"
	else:
		anim_str = anim_str + "passive"
	
	build_sprite.animation = anim_str

## Fills the perks array with nulls until reaching the global max perks size. 
func _resize_to_max():
	size = base_size + extra_size
	while perks.size() < size:
		var empty_perk = create_empty_perk()
		perks.append(empty_perk) 
	_refresh_build()
	move_perks_to_slot_positions()
	_pick_lock_animation()

func get_size():
	return size

func set_extra_size(_extra_size : int):
	extra_size = _extra_size
	_resize_to_max()

func deactivate():
	for perk : Perk in perks:
		if perk != null:
			perk.deactivate()

## Places the given perk at the given index, returning the Perk that gets replaced (if it exists).
func place_perk(perk : Perk, index : int) -> Perk:
	print("Placed perk of type ", perk.code_name, " into index ", index)
	var replaced_perk := perks[index]
	perks[index] = perk
	if replaced_perk:
		print("Replaced perk of type ", replaced_perk.code_name)
		replaced_perk.refresh_context(null, -1)
	_refresh_build()
	return replaced_perk


## Removes the perk at the given index, returning it (if it exists).
func remove_perk(index : int) -> Perk:
	var removed_perk := perks[index]
	if removed_perk != null:
		perks[index] = create_empty_perk()
		removed_perk.refresh_context(null, -1)
		_refresh_build()
		move_perks_to_slot_positions()
		return removed_perk
	else:
		return null

func create_empty_perk() -> Perk:
	var empty_perk = Perk.init_perk(Perk.Type.EMPTY)
	empty_perk.is_active = is_active
	add_child(empty_perk)
	return empty_perk


func _refresh_build():
	for i in range(size):
		if perks[i] != null:
			perks[i].refresh_context(self, i)
#endregion Gameplay methods

#region UI logic
## Returns the index of the slot nearest to the given position.
func pos_to_nearest_idx(pos : Vector2) -> int:
	var nearest_idx := -1
	var nearest_dist := INF
	for i in range(size):
		var slot_pos = idx_to_pos(i)
		var perk : Perk = idx_to_perk(i)
		if perk:
			# If the perk isn't a nonempty, pickupable perk, continue
			if not (perk.pickupable or perk.is_empty_perk()):
				continue
		var dist = slot_pos.distance_to(pos)
		if dist <= SLOT_SNAP_DIST and dist < nearest_dist:
			nearest_idx = i
			nearest_dist = dist
	return nearest_idx

func idx_to_pos(idx : int):
	return LEFTMOST_SLOT_POS + idx * SLOT_POS_OFFSET

func idx_to_perk(idx : int):
	if idx >= 0 and idx < size:
		return perks[idx]
	return null

func move_perks_to_slot_positions():
	for i in range(perks.size()):
		var perk : Perk = perks[i]
		if perk:
			perk.root_pos = idx_to_pos(i)
			perk.move_to_root_pos()

#endregion UI logic
