extends Node2D

## Modifiers that apply to perks. Each perk can hold modifiers that apply directionally to other perks or itself.
class_name PerkMod

## Emitted on refresh. Updates the ModCard.
signal refreshed

enum Direction {
	SELF, 
	LEFT,
	RIGHT,
	UP,
	DOWN
}

## The directions that this mod modifies. Determined by its effects. 
## Set on initialization, and updated upon adding / removing / changing effects.
var target_directions : Array[Direction]

## The perks affected by this modifier, organized by effect. 
## Set upon placement to assign effects to their perks.
var effect_to_target_perks: Dictionary[PerkModEffect, Array] # Array[Perk]

## Perk currently holding the modifier. Can be null.
var parent_perk : Perk

## Effects that this modifier applies upon activation.
var effects : Array[PerkModEffect]

## Whether this modifier is on a perk that's in a build.
## Implies that its effects are active too.
var active := false

## The modifier's overall rarity. Determined by PerkModFactory. Sets body color.
var rarity: Perk.Rarity

## The overall category of this effect.
var category: Perk.Category

#region Placement logic
## How close the mod needs to be to a perk to consider it as hovered. 
const PLACEMENT_HOVER_RANGE := 50.0

## The perk that this mod will be placed into if dropped.
var hovered_perk: Perk

## Whether the mouse is holding this mod.
var mouse_holding := false

## Whether the mouse can click to start holding this mod. 
## True based on DetachedPickupArea collisions.
var mouse_hovering := false

## Where this modifier will return to when dropped without a hovered perk.
var ui_root_pos := Vector2(randf_range(200,500), randf_range(0, 200))

## The current tween moving the modifier's position in the UI.
var pos_tween: Tween

## True after _ready when visual nodes have been given parents and refreshed.
var visuals_initialized := false

## The area the mouse can grab the mod from when it's not on a perk. 
## (When on a perk, the perk's directional mod hitboxes are used instead. Handled by the perk. 
@onready var pickup_area: Area2D = $DetachedPickupArea
#endregion Placement logic

#region Visuals
@onready var perk_mod_visual: PerkModVisual = $PerkModVisual
@onready var slot_hover_visual: SlotHoverVisual = Global.perk_ui.slot_hover_visual

@onready var mod_card: ModCard = $ModCard
#endregion Visuals

#region Builtins
func _ready() -> void:
	_init_visuals()
	if PerkModFactory.DEBUG_LOG:
		debug_print_mod_info() 
	_init_mod_card()

func _process(delta: float) -> void:
	_process_mouse_pickup_and_drop(delta)
#endregion Builtins

## Activates this modifier's effects. 
## Called when attached to a perk in a build or parent perk enters a build.
func activate():
	assert(parent_perk)
	assert(not active)
	
	active = true
	parent_perk.context_updated.connect(_refresh)
	
	_refresh_effect_targets()
	for effect in effects:
		var effect_targets = effect_to_target_perks[effect]
		if not effect_targets.is_empty():
			effect.activate(effect_to_target_perks[effect])
	
	print("activated mod ", self, " on perk ", parent_perk)
	

## Deactivates this modifier's effects.
## Called when removed from a perk in a build.
func deactivate():
	assert(parent_perk, "To deactivate, parent perk should have been non-null.")
	assert(active)
	active = false
	parent_perk.context_updated.disconnect(_refresh)
	for effect in effects:
		var effect_targets = effect_to_target_perks[effect]
		if not effect_targets.is_empty():
			effect.deactivate()
	print("deactivated mod ", self, " on perk ", parent_perk)
	

## Adds modifier to the perk.
func attach(_parent_perk: Perk):
	assert(_parent_perk)
	assert(pickup_area.process_mode == Node.PROCESS_MODE_INHERIT)
	pickup_area.process_mode = Node.PROCESS_MODE_DISABLED
	parent_perk = _parent_perk
	parent_perk.add_mod(self)
	hide()
	print("attached mod ", self, " to perk ", parent_perk)

## Removes this modifier from the perk.
func detach():
	assert(parent_perk, "To detach, parent perk should have been non-null.")
	assert(not active, "Should not be active and detached at the same time. Deactivate before detaching.")
	assert(pickup_area.process_mode == Node.PROCESS_MODE_DISABLED)
	parent_perk.remove_mod(self)
	parent_perk = null
	pickup_area.process_mode = Node.PROCESS_MODE_INHERIT
	show()
	print("detached mod ", self, " from perk ", parent_perk)

## Picks up this modifier, potentially detaching it from a perk and deactivating it. 
## Attaches it to the mouse.
func pick_up():
	 #TODO assert( in inventory or ...
	assert(mouse_hovering or parent_perk)
	try_detach_and_deactivate()
	assert(not mouse_holding)
	mouse_holding = true
	Perk.anything_held = true
	reset_pos_tween(false)
	mod_card.hide_card()
	
	show_modifier_availability_of_all_perks()
	
	if PerkModFactory.DEBUG_LOG:
		debug_print_mod_info()

## Drops this modifier, potentially attaching it to a hovered perk and 
## potentially activating it if that perk's in a build.
func drop():
	assert(mouse_holding)
	mouse_holding = false
	Perk.anything_held = false
	clear_highlights()
	slot_hover_visual.hide_selector()
	if hovered_perk:
		var attached_successfully = try_attach_and_activate(hovered_perk)
		if attached_successfully: 
			hovered_perk = null
		else:
			ui_root_pos = position 
			move_to_root_pos()
	else:
		ui_root_pos = position 
		move_to_root_pos()
	hide_modifier_availability_of_all_perks()

## Returns whether this mod could successfully attach to the perk. 
## True does not mean it activated on the perk.
func try_attach_and_activate(perk: Perk) -> bool:
	if perk.can_hold_modifier(self.target_directions):
		attach(perk)
		if perk.is_inside_build():
			assert(not active)
			activate()
		return true
	return false

## Returns whether this mod successfuly detached from its parent perk. 
func try_detach_and_deactivate() -> bool:
	if active:
		assert(parent_perk)
		deactivate()
	if parent_perk:
		detach()
		return true
	else:
		return false

## Notices which perk is currently being hovered over. If it changes, updates highlights accordingly. 
func _update_hovered_perk_and_highlights():
	var lowest_dist := PLACEMENT_HOVER_RANGE
	var lowest_dist_perk: Perk = null
	
	for perk: Perk in get_tree().get_nodes_in_group("perk"):
		if perk.can_hold_modifier(target_directions):
			var dist = perk.global_position.distance_to(get_global_mouse_position())
			if dist < lowest_dist:
				lowest_dist = dist
				lowest_dist_perk = perk
	if lowest_dist_perk != hovered_perk:
		hovered_perk = lowest_dist_perk
		clear_highlights()
		if hovered_perk:
			apply_target_highlights_at_perk(hovered_perk)

func _process_mouse_pickup_and_drop(delta: float):
	if Global.perk_ui.active: 
		if mouse_hovering:
			if Input.is_action_just_pressed("attack"):
				if not Perk.anything_held:
					pick_up()
			if not Perk.anything_held:
				mod_card.show_card()
		if mouse_holding:
			mod_card.hide_card()
			move_while_held(delta)
			_update_hovered_perk_and_highlights()
			if Input.is_action_just_released("attack"):
				drop()
	#else:
		#mod_card.hide_card()

## Moves this modifier to its root position in the UI. 
func move_to_root_pos(dur := 0.5, trans := Tween.TransitionType.TRANS_QUINT, _ease := Tween.EaseType.EASE_OUT):
	reset_pos_tween(true)
	pos_tween.tween_property(self, "position", ui_root_pos, dur).set_trans(trans).set_ease(_ease)

	#if get_parent() != Global.perk_ui.chest_opening_root:
		#pos_tween.parallel().tween_property(self, "scale", Vector2.ONE, dur).set_trans(trans).set_ease(_ease)
	#else:
		#pos_tween.parallel().tween_property(self, "scale", Vector2.ONE * 2, dur).set_trans(trans).set_ease(_ease)

func reset_pos_tween(create_new := false):
	if pos_tween:
		pos_tween.kill() 
	if create_new:
		pos_tween = create_tween()

func move_while_held(delta : float):
	if mouse_holding:
		global_position = global_position.lerp(get_global_mouse_position(), 25.0 * delta)
		if hovered_perk:
			slot_hover_visual.move_to(hovered_perk.global_position)
		else:
			slot_hover_visual.hide_selector()

## Refreshes this modifier's targets. Called when the parent perk's context is refreshed.
## Does so by diffing the contents of effect_to_target_perks.
func _refresh_and_apply_effect_target_diffs() -> void:
	assert(parent_perk, "Refresh should only be called when a perk owning a modifier is moved.")
	assert(active, "Refresh should only be called when active")
	
	var old_effect_to_target_perks = effect_to_target_perks
	effect_to_target_perks = create_effect_to_target_perks_dict(parent_perk.context)
	
	assert(old_effect_to_target_perks.keys() == effect_to_target_perks.keys(),
		"Should just be a perk context change, no effects should be added or removed upon refresh")
	
	for effect: PerkModEffect in effect_to_target_perks.keys():
		var old_targets = old_effect_to_target_perks[effect]
		var new_targets = effect_to_target_perks[effect]
		
		if old_targets == new_targets:
			continue
		
		# If a target is in new but not old, apply effect to it
		for target: Perk in new_targets:
			if not old_targets.has(target):
				effect.apply_to_perk(target)
		# If a target is in old but not new, remove effect from it
		for target: Perk in old_targets:
			if not new_targets.has(target):
				effect.remove_from_perk(target)


## Given the perk being hovered, if it can be placed onto, determines which perks to highlight and adds a highlight to them. 
func apply_target_highlights_at_perk(perk: Perk):
	if perk.can_hold_modifier(target_directions):
		var context: PerkContext = perk.context
		var _effect_to_target_perks := create_effect_to_target_perks_dict(context)
		for effect: PerkModEffect in effects:
			var targets = _effect_to_target_perks[effect]
			for target: Perk in targets:
				match effect.polarity:
					PerkModEffect.Polarity.BUFF:
						target.show_modifier_buff_highlight()
					PerkModEffect.Polarity.NERF:
						target.show_modifier_nerf_highlight()

## Populates a dict shaped like effect_to_target_perks with the up-to-date target perks given a perk context.
func create_effect_to_target_perks_dict(context: PerkContext) -> Dictionary[PerkModEffect, Array]: # Array[Perk]
	var _effect_to_target_perks: Dictionary[PerkModEffect, Array] # Array[Perk]
	for effect: PerkModEffect in effects:
		var targets = get_target_perks(effect, context)
		_effect_to_target_perks[effect] = targets
	return _effect_to_target_perks

## Finds a child effect's target perks based on the given perk context.
func get_target_perks(effect: PerkModEffect, context: PerkContext) -> Array[Perk]:
	assert(context != null)
	assert(effect != null)
	var target_perks: Array[Perk]
	for dir: PerkMod.Direction in effect.get_target_directions():
		match dir:
			PerkMod.Direction.SELF:
				assert(context.perk != null)
				target_perks.append(context.perk)
			PerkMod.Direction.LEFT:
				match effect.scope:
					PerkModEffect.Scope.NEIGHBOR:
						if context.left_neighbor:
							target_perks.append(context.left_neighbor)
					PerkModEffect.Scope.SECOND_NEIGHBOR:
						if context.second_left_neighbor:
							target_perks.append(context.second_left_neighbor)
					PerkModEffect.Scope.ALL:
						if context.left_neighbors:
							target_perks.append_array(context.left_neighbors)
			PerkMod.Direction.RIGHT:
				match effect.scope:
					PerkModEffect.Scope.NEIGHBOR:
						if context.right_neighbor:
							target_perks.append(context.right_neighbor)
					PerkModEffect.Scope.SECOND_NEIGHBOR:
						if context.second_right_neighbor:
							target_perks.append(context.second_right_neighbor)
					PerkModEffect.Scope.ALL:
						if context.right_neighbors:
							target_perks.append_array(context.right_neighbors)
			PerkMod.Direction.UP:
				match effect.scope:
					PerkModEffect.Scope.NEIGHBOR:
						if context.up_neighbor:
							target_perks.append(context.up_neighbor)
					PerkModEffect.Scope.SECOND_NEIGHBOR:
						if context.second_up_neighbor:
							target_perks.append(context.second_up_neighbor)
					PerkModEffect.Scope.ALL:
						if context.up_neighbors:
							target_perks.append_array(context.up_neighbors)
			PerkMod.Direction.DOWN:
				match effect.scope:
					PerkModEffect.Scope.NEIGHBOR:
						if context.down_neighbor:
							target_perks.append(context.down_neighbor)
					PerkModEffect.Scope.SECOND_NEIGHBOR:
						if context.second_down_neighbor:
							target_perks.append(context.second_down_neighbor)
					PerkModEffect.Scope.ALL:
						if context.down_neighbors:
							target_perks.append_array(context.down_neighbors)
	return target_perks

## Removes buff/nerf highlights from all perks.
func clear_highlights():
	for perk: Perk in get_tree().get_nodes_in_group("perk"):
		perk.hide_modifier_buff_highlight()
		perk.hide_modifier_nerf_highlight()

## Tells all perks to display their modifier availability for this mod's directions
func show_modifier_availability_of_all_perks():
	for perk: Perk in get_tree().get_nodes_in_group("perk"):
		perk.show_available_directions_out_of(target_directions)

## Tells all perks to STOP displaying their modifier availability. 
func hide_modifier_availability_of_all_perks():
	for perk: Perk in get_tree().get_nodes_in_group("perk"):
		perk.hide_available_modifier_directions()

func add_effects(effects_to_add: Array[PerkModEffect]):
	for effect in effects_to_add:
		add_effect(effect)

## Adds an effect to this modifier.
## Adds it to effects and effect_to_target_perks, and activates it. 
func add_effect(effect: PerkModEffect) -> void:
	add_child(effect)
	effects.append(effect)
	# Note the effect's targets in our dict
	var target_perks = []
	if parent_perk:
		target_perks = get_target_perks(effect, parent_perk.context)
	assert(not effect_to_target_perks.has(effect))
	effect_to_target_perks[effect] = target_perks
	# Activate the effect if this modifier is already active
	if active: 
		assert(parent_perk)
		effect.activate(target_perks)
	_refresh_target_directions()
	
## Removes an effect from this modifier.
func remove_effect(effect: PerkModEffect) -> void:
	assert(effects.has(effect), "Shouldn't try to remove an effect that doesn't exist on this mod")
	remove_child(effect)
	if effect.active:
		effect.deactivate()
	effects.erase(effect)
	assert(effect_to_target_perks.has(effect))
	effect_to_target_perks.erase(effect)
	_refresh_target_directions()

#region Print Info
func _init_mod_card():
	mod_card.init_with_mod(self)
	Global.perk_ui.toggled_off.connect(mod_card.hide_card)



func _get_self_description() -> String:
	# Build a compact header: ◆ <RARITY> <CATEGORY> • dirs: <symbols> • effects: N [ACTIVE]
	var rarity_name := ""
	if rarity != null:
		# try to resolve readable enum name for rarity (fallback to tostring)
		rarity_name = Perk.Rarity.find_key(rarity)
	# category might be an enum or string
	var category_name := ""
	category_name = str(category)
	
	# map directions to symbols
	var dir_symbols := []
	var sym_map := {
		Direction.SELF: "◎",
		Direction.LEFT: "←",
		Direction.RIGHT: "→",
		Direction.UP: "↑",
		Direction.DOWN: "↓",
	}
	for d in target_directions:
		if d in sym_map:
			dir_symbols.append(sym_map[d])
		else:
			# fallback to name if unknown
			dir_symbols.append(PerkMod.Direction.find_key(d))
	var dirs_s := ", ".join(dir_symbols) if dir_symbols.size() > 0 else "—"
	
	var active_s := " • Active" if active else ""
	var effects_count := effects.size() if effects else 0
	return "◆ %s %s • dirs: %s • effects: %d%s" % [rarity_name, category_name, dirs_s, effects_count, active_s]



func _get_effects_string_descriptions() -> String:
	var total_string = ""
	for effect: PerkModEffect in effects:
		total_string += effect.get_description()
		total_string += "\n"
	return total_string

# PerkMod: print concise header about the mod and then every child effect
func debug_print_mod_info() -> void:
	var sep := "##################################################"
	var small := "──────────────────────────────────────────────────"
	
	# build directions string
	var dir_names := []
	for d in target_directions:
		dir_names.append(PerkMod.Direction.find_key(d))
	var dirs_s := "[" + ", ".join(dir_names) + "]" if dir_names.size() > 0 else "[]"
	
	# try resolve rarity name
	var rarity_name = Perk.Rarity.find_key(rarity)
	
	print("\n", sep)
	print("◆ PerkMod:", self, "  (parent_perk:", str(parent_perk), ")")
	print("  • active:", str(active), "  • rarity:", rarity_name, "  • category:", str(category))
	print("  • target_directions:", dirs_s, "  • effects:", str(effects.size()))
	print(small)
	# print each effect's compact info (calls the effect's own printer)
	for i in range(effects.size()):
		var e := effects[i]
		if e:
			print("→ Effect #", str(i + 1), ":")
			# call the PerkModEffect debug printer if available, otherwise print a fallback line
			if e.has_method("debug_print_effect_info"):
				e.debug_print_effect_info()
			else:
				print("   (no debug_print_effect_info on effect) ", e)
		else:
			print("→ Effect #", str(i + 1), ": null")
	print(sep, "\n")
#endregion Print Info


## Updates target directions (for visuals), effect applications (if context changed and active). 
func _refresh():
	_refresh_and_apply_effect_target_diffs()
	_refresh_target_directions()
	refreshed.emit()

## Recalculates the targets for each effect.
func _refresh_effect_targets():
	assert(parent_perk)
	effect_to_target_perks = create_effect_to_target_perks_dict(parent_perk.context)


## Refreshes target directions. Call when effects update. 
func _refresh_target_directions() -> void:
	target_directions.clear()
	for effect: PerkModEffect in effects:
		for dir in effect.get_target_directions():
			if not target_directions.has(dir):
				target_directions.append(dir)
	_refresh_visuals()


func _init_visuals():
	perk_mod_visual.init_parent_mod(self)
	visuals_initialized = true
	_refresh_visuals()

func _refresh_visuals() -> void:
	if not visuals_initialized:
		return
	perk_mod_visual.refresh()


func _on_detached_pickup_area_mouse_entered() -> void:
	if Global.perk_ui.active:
		mouse_hovering = true

func _on_detached_pickup_area_mouse_exited() -> void:
	mouse_hovering = false
