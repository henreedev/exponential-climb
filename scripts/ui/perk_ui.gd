extends CanvasLayer

class_name PerkUI

const PERK_BUILD_SCENE = preload("res://scenes/perks/perk_build.tscn")
const BUILD_OFFSET = Vector2(0, 37) ## Distance between each build.

## If opening a chest, can't close perk UI until done.
var opening_chest := false
## Whether the perk UI is interactable and taking up more screen space.
var active := true

#region Toggling
## How long it takes to transition to perk UI being active.
const TOGGLE_ON_DUR = 1.2
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


## Node2D parenting the nodes involved in the chest opening sequence.
@onready var chest_opening_root: Node2D = $ChestOpeningRoot
## Button to confirm being finished with chest perk selection.
@onready var chest_confirm_button: Button = %ChestConfirmButton
## The visual chest being opened with perks coming out of it.
@onready var chest_sprite: Sprite2D = %ChestSprite

## Labels showing loop speeds.
@onready var global_loop_speed: Label = %GlobalLoopSpeed
@onready var player_loop_speed: Label = %PlayerLoopSpeed
@onready var enemy_loop_speed: Label = %EnemyLoopSpeed

#endregion References to Nodes


func _ready() -> void:
	toggle_off()
	Global.perk_ui = self

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
		
		
		# Fade things in
		toggle_tween.tween_property(color_rect, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		toggle_tween.tween_property(active_build_label, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(TOGGLE_ON_DUR / 2.0)
		toggle_tween.tween_property(passive_build_label, "modulate:a", 1.0, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(TOGGLE_ON_DUR / 2.0)
		# Grow active builds
		toggle_tween.tween_property(active_builds_root, "scale", Vector2.ONE * 2, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		toggle_tween.tween_property(passive_builds_root, "scale", Vector2.ONE * 2, TOGGLE_OFF_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		# Move things around
		toggle_tween.tween_property(passive_builds_root, "position", passive_perks_active_marker.position, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		toggle_tween.tween_property(active_builds_root, "position", active_perks_active_marker.position, TOGGLE_ON_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		


func toggle_off():
	if opening_chest: return
	if active:	
		active = false
		get_tree().paused = false
		
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
		

func _reset_toggle_tween(create_new := true):
	if toggle_tween: 
		toggle_tween.kill()
	if create_new:
		toggle_tween = create_tween().set_parallel()

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
	toggle_on()
	
	const POS_OFFSET := Vector2(100, 0)
	var perk_pos := -POS_OFFSET
	## Tween the perks from the chest to one of 3 side-by-side locations
	var chest_tween : Tween = create_tween()
	chest_tween.tween_property(chest_sprite, "modulate:a", 1.0, 0.5).set_delay(1.0)
	
	var i := 0
	for perk in perks:
		if perk.get_parent():
			perk.reparent(chest_opening_root)
		else:
			chest_opening_root.add_child(perk)
		chest_tween.tween_callback(perk.move_to_root_pos).set_delay(i * 0.125)
		
		perk.position = chest_sprite.position
		perk.root_pos = perk_pos
		perk.reset_physics_interpolation()
		
		perk_pos += POS_OFFSET
		i += 1
	chest_tween.tween_property(chest_sprite, "modulate:a", 0.0, 0.5).set_delay(1.0)
	chest_tween.tween_property(chest_confirm_button, "modulate:a", 1.0, 0.5).set_delay(1.0)

func finish_chest_opening():
	opening_chest = false
	chest_confirm_button.hide()
	chest_sprite.hide()
	for child in chest_opening_root.get_children():
		if not (child == chest_confirm_button or child == chest_sprite):
			child.queue_free()
	
	toggle_off()

func _on_chest_confirm_button_pressed() -> void:
	finish_chest_opening()

#endregion Chest opening
