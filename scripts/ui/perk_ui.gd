extends CanvasLayer

class_name PerkUI

## Emitted after the lock in sequence completely finishes.
signal locked_in  

const PERK_BUILD_SCENE = preload("res://scenes/perks/perk_build.tscn")
const BUILD_OFFSET = Vector2(0, 37) ## Distance between each build.

## If opening a chest, can't close perk UI until done.
var opening_chest := false
## Whether the perk UI is interactable and taking up more screen space.
var active := true
## Whether the lock in sequence is currently ongoing, allowing perks to be moved around freely.
var locking_in := false

#region Toggling
## How long it takes to transition to perk UI being active.
const TOGGLE_ON_DUR = 1.1
## How long it takes to transition to perk UI being inactive.
const TOGGLE_OFF_DUR = 0.5
## The Tween used to move UI elements upon toggling.
var toggle_tween : Tween
#endregion Toggling

#region References to Nodes
## Tinted background that appears when perk UI is active.
@onready var color_rect: ColorRect = $ColorRect


## Node2D parenting the perk builds.
@onready var builds_root: Node2D = $BuildsRoot
## Within the builds root, parents the active perk builds.
@onready var active_builds_root: Node2D = $BuildsRoot/ActiveBuildsRoot
@onready var active_build_label: Label = %ActiveBuildLabel
## Within the builds root, parents the passive perk builds.
@onready var passive_builds_root: Node2D = $BuildsRoot/PassiveBuildsRoot
@onready var passive_build_label: Label = %PassiveBuildLabel


## Markers for where to move things on toggle on (active) and off (inactive).
@onready var passive_perks_active_marker: Marker2D = $BuildsRoot/PassivePerksActiveMarker
@onready var active_perks_inactive_marker: Marker2D = $BuildsRoot/ActivePerksInactiveMarker
@onready var passive_perks_inactive_marker: Marker2D = $BuildsRoot/PassivePerksInactiveMarker
@onready var active_perks_active_marker: Marker2D = $BuildsRoot/ActivePerksActiveMarker
@onready var passive_perks_lock_in_marker: Marker2D = $BuildsRoot/PassivePerksLockInMarker
@onready var active_perks_lock_in_marker: Marker2D = $BuildsRoot/ActivePerksLockInMarker


## Node2D parenting the nodes involved in the chest opening sequence.
@onready var chest_opening_root: Node2D = $ChestOpeningRoot
## Button to confirm being finished with chest perk selection.
@onready var chest_confirm_button: Button = %ChestConfirmButton
## The visual chest being opened with perks coming out of it.
@onready var chest_sprite: Sprite2D = %ChestSprite

## Lock in button.
@onready var lock_in_button: Button = %LockInButton
## Simulate a lock in button.
@onready var simulate_button: Button = %SimulateButton
## Fast forward simulation button.
@onready var fast_forward_button: Button = %FastForwardButton

## Labels showing loop speeds.
@onready var global_loop_speed: Label = %GlobalLoopSpeed
@onready var player_loop_speed: Label = %PlayerLoopSpeed
@onready var enemy_loop_speed: Label = %EnemyLoopSpeed

# TODO switch from label to cool number thingy
## Populated with labels displaying loop_value_left for each passive build in its animations.
var passive_animation_labels : Array[Label] = []

#endregion References to Nodes


func _ready() -> void:
	toggle_off()
	Global.perk_ui = self
	Loop.lock_in_animation_finished.connect(_on_loop_passive_animation_finished)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("test_add_perk_build"):
		add_perk_build()
	if event.is_action_pressed("test_add_perk_slot"):
		add_perk_slot()


#region Toggling
func toggle():
	if active:
		toggle_off()
	else:
		toggle_on()
 
func toggle_on():
	if not active:
		active = true
		get_tree().paused = true
		# Display the toggle by moving around UI elements
		# Reset tween, creating a new one
		_reset_toggle_tween()
		
		const BUILD_SCALE = Vector2(2, 2)
		
		if locking_in:
			# Move elements to positions for the lock in sequence
			# Fade things in
			toggle_tween.tween_property(lock_in_button, "visible", true, 0.0).set_delay(2.5)
			toggle_tween.tween_property(simulate_button, "visible", true, 0.0).set_delay(1.5)
			toggle_tween.tween_property(fast_forward_button, "visible", true, 0.0).set_delay(1.7)
			toggle_tween.tween_property(lock_in_button, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).from(0.0).set_delay(2.5)
			toggle_tween.tween_property(simulate_button, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).from(0.0).set_delay(1.5)
			toggle_tween.tween_property(fast_forward_button, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).from(0.0).set_delay(1.7)
			
			toggle_tween.tween_property(color_rect, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			toggle_tween.tween_property(active_build_label, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(TOGGLE_ON_DUR / 2.0)
			toggle_tween.tween_property(passive_build_label, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(TOGGLE_ON_DUR / 2.0)
			# Grow active builds
			toggle_tween.tween_property(active_builds_root, "scale", BUILD_SCALE, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			toggle_tween.tween_property(passive_builds_root, "scale", BUILD_SCALE, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
			# Move things around
			toggle_tween.tween_property(passive_builds_root, "position", passive_perks_lock_in_marker.position, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			toggle_tween.tween_property(active_builds_root, "position", active_perks_lock_in_marker.position, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			# Move elements to normal viewing positions
			# Fade things in
			toggle_tween.tween_property(color_rect, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			toggle_tween.tween_property(active_build_label, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(TOGGLE_ON_DUR / 2.0)
			toggle_tween.tween_property(passive_build_label, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(TOGGLE_ON_DUR / 2.0)
			# Grow active builds
			toggle_tween.tween_property(active_builds_root, "scale", BUILD_SCALE, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			toggle_tween.tween_property(passive_builds_root, "scale", BUILD_SCALE, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
			# Move things around
			toggle_tween.tween_property(passive_builds_root, "position", passive_perks_active_marker.position, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			toggle_tween.tween_property(active_builds_root, "position", active_perks_active_marker.position, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		


func toggle_off():
	if opening_chest: 
		shake_floating_perks()
		return 
	if locking_in: return
	if active:
		active = false
		get_tree().paused = false
		
		# Lock perks into position
		for perk : Perk in get_tree().get_nodes_in_group("perk"):
			if perk.pickupable and perk.context.build: 
				perk.pickupable = false
		
		# Display the toggle by moving around UI elements
		_reset_toggle_tween()
		
		toggle_tween.tween_property(color_rect, "modulate:a", 0.0, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		toggle_tween.tween_property(passive_build_label, "modulate:a", 0.0, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		toggle_tween.tween_property(active_build_label, "modulate:a", 0.0, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Shrink builds
		toggle_tween.tween_property(active_builds_root, "scale", Vector2.ONE, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		toggle_tween.tween_property(passive_builds_root, "scale", Vector2.ONE, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Move things around
		toggle_tween.tween_property(passive_builds_root, "position", passive_perks_inactive_marker.position, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		toggle_tween.tween_property(active_builds_root, "position", active_perks_inactive_marker.position, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		for label : Label in passive_animation_labels:
			toggle_tween.tween_property(label, "modulate:a", 0.0, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		toggle_tween.chain().tween_callback(clear_passive_animation_labels)

func _reset_toggle_tween(create_new := true):
	if toggle_tween: 
		toggle_tween.kill()
	if create_new:
		toggle_tween = create_tween().set_parallel()


func shake_floating_perks():
	for perk : Perk in get_tree().get_nodes_in_group("perk"):
		if not perk.context.build:
			perk.shaker.shake()
#endregion Toggling

#region Builds
## Adds a new active and passive build to the perk UI.
func add_perk_build():
	var active_build = PERK_BUILD_SCENE.instantiate()
	active_build.is_active = true 
	var passive_build = PERK_BUILD_SCENE.instantiate()
	active_build.position = get_last_build(true).position + BUILD_OFFSET
	passive_build.position = get_last_build(false).position + BUILD_OFFSET
	active_builds_root.add_child(active_build)
	passive_builds_root.add_child(passive_build)
	# TODO organize build positions

## Adds a perk slot to the oldest build that has a locked slot.
func add_perk_slot():
	get_last_build(true).add_perk_slot(1)
	get_last_build(false).add_perk_slot(1)

func get_last_build(get_active : bool):
	if get_active:
		return Global.player.build_container.active_builds[-1]
	else:
		return Global.player.build_container.passive_builds[-1]


#endregion Builds

#region Loop speed display

func set_global_loop_speed(value : float):
	set_loop_speed(value, global_loop_speed)
func set_player_loop_speed(value : float):
	set_loop_speed(value, player_loop_speed)
func set_enemy_loop_speed(value : float):
	set_loop_speed(value, enemy_loop_speed)

func set_loop_speed(value : float, label : Label):  
	var old_value = label.text.to_float()
	# TODO compare old value to new; find which digits changed; update those digits accordingly
	label.text = str(value).pad_decimals(2)

#endregion Loop speed display


#region Chest opening
func show_chest_opening(chest : Chest, perks : Array[Perk]):
	opening_chest = true
	chest_confirm_button.show()
	chest_confirm_button.modulate.a = 0.0
	chest_sprite.modulate.a = 0.0
	chest_sprite.show()
	for perk in perks:
		perk.modulate.a = 0.0
	toggle_on()
	
	const POS_OFFSET := Vector2(100, 0)
	var perk_pos := -POS_OFFSET
	## Tween the perks from the chest to one of 3 side-by-side locations
	var chest_tween : Tween = create_tween()
	# Show chest
	chest_tween.tween_property(chest_sprite, "modulate:a", 1.0, 0.5).set_delay(1.0)
	
	var i := 0
	for perk in perks:
		# Add perk to chest opening root
		if perk.get_parent():
			perk.reparent(chest_opening_root)
		else:
			chest_opening_root.add_child(perk)
		# Show perk (behind chest)
		chest_tween.tween_property(perk, "modulate:a", 1.0, 0.0)
		# Tween perk to final position
		chest_tween.tween_callback(perk.move_to_root_pos).set_delay(i * 0.2)
		
		# Teleport perk to chest position
		perk.position = chest_sprite.position
		perk.root_pos = perk_pos
		perk.reset_physics_interpolation()
		perk_pos += POS_OFFSET
		i += 1
	# Remove chest
	# Make perks interactable
	for perk in perks:
		chest_tween.tween_property(perk, "selectable", true, 0.0)
		chest_tween.tween_property(perk, "hoverable", true, 0.0)
	# Show confirmation button
	chest_tween.tween_property(chest_confirm_button, "modulate:a", 1.0, 0.5)

func finish_chest_opening():
	var one_perk_selected := false
	for perk : Perk in get_tree().get_nodes_in_group("perk"):
		if perk.is_selected:
			one_perk_selected = true
	if one_perk_selected:
		opening_chest = false
		chest_confirm_button.hide()
		chest_sprite.hide()
		for child in chest_opening_root.get_children():
			if not (child == chest_confirm_button or child == chest_sprite):
				if child is Perk:
					if child.is_selected:
						child.pickupable = true
						child.selectable = false
						child.deselect()
					else:
						child.delete()
	else:
		shake_floating_perks()

func _on_chest_confirm_button_pressed() -> void:
	finish_chest_opening()

#endregion Chest opening

#region Locking in

## Player can move perks around during the lock in sequence, then lock in their positions.
## Can simulate passive perk lock in before actual lock in.
func start_lock_in_sequence():
	locking_in = true
	create_passive_animation_labels()
	for perk : Perk in get_tree().get_nodes_in_group("perk"):
		perk.pickupable = true
		perk.set_loop_anim("none")
	toggle_on()


## Display passive perks activating, then signal to create a new room
func end_lock_in_sequence():
	locking_in = false
	fast_forward_button.hide()
	for perk : Perk in get_tree().get_nodes_in_group("perk"):
		perk.set_loop_anim("none")
	toggle_off()
	# Emit locked_in after toggling off fully
	create_tween().tween_callback(locked_in.emit).set_delay(TOGGLE_OFF_DUR)

func create_passive_animation_labels():
	const POS = Vector2(-93, -8)
	const DUR = 1.5
	const DELAY = 2.5
	var pos_tween := create_tween().set_parallel()
	for passive_build : PerkBuild in Global.player.build_container.passive_builds:
		var new_label : Label = player_loop_speed.duplicate()
		new_label.visible = false
		new_label.scale = Vector2.ONE * 0.5
		var start_pos = Vector2(48, -36.5) - passive_build.position
		passive_build.add_child(new_label)
		new_label.reset_physics_interpolation()
		new_label.position = start_pos
		pos_tween.tween_property(new_label, "visible", true, 0.0).set_delay(DELAY - 1)
		pos_tween.tween_property(new_label, "position:x", POS.x, DUR).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(DELAY)
		pos_tween.tween_property(new_label, "position:y", POS.y, DUR).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(DELAY + DUR * 0.6)
		
		passive_animation_labels.append(new_label)

func set_passive_animation_labels(loop_speed_values : Array[float]):
	for i in range(loop_speed_values.size()):
		passive_animation_labels[i].text = str(loop_speed_values[i]).pad_decimals(2)

func reset_passive_animation_labels():
	for label : Label in passive_animation_labels:
		label.text = str(Loop.display_player_speed).pad_decimals(2)

func clear_passive_animation_labels():
	for label : Label in passive_animation_labels:
		label.queue_free()
	passive_animation_labels.clear()
	

func _on_lock_in_button_pressed() -> void:
	lock_in_button.hide()
	simulate_button.hide()
	for perk : Perk in get_tree().get_nodes_in_group("perk"):
		if perk.context.build:
			perk.pickupable = false
	Loop.animate_passive_builds(false)

func _on_loop_passive_animation_finished():
	if locking_in:
		end_lock_in_sequence()

func _on_simulate_button_pressed() -> void:
	Loop.animate_passive_builds(true)


func _on_fast_forward_button_pressed() -> void:
	Loop.increase_animation_speed()

#endregion Locking in
