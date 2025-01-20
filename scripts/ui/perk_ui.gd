extends CanvasLayer

class_name PerkUI

## If opening a chest, can't close perk UI until done.
var opening_chest := false
## Whether the perk UI is meant to be visible on screen. May not actually be `visible`, due to transition times.
var showing := false
## Node2D parenting the perk builds.
@onready var builds_root: Node2D = $BuildsRoot

## Node2D parenting the nodes involved in the chest opening sequence.
@onready var chest_opening_root: Node2D = $ChestOpeningRoot
@onready var chest_confirm_button: Button = $ChestConfirmButton

func _ready() -> void:
	visible = false
	Global.perk_ui = self

func toggle():
	if showing:
		toggle_off()
	else:
		toggle_on()

func toggle_on():
	if not showing:
		showing = true
		visible = true
		get_tree().paused = true

func toggle_off():
	if opening_chest: return
	
	if showing:
		showing = false
		visible = false
		get_tree().paused = false
#region Chest opening
func show_chest_opening(perks : Array[Perk]):
	opening_chest = true
	chest_confirm_button.show()
	toggle_on()
	
	const POS_OFFSET := Vector2(100, 0)
	var perk_pos := -POS_OFFSET
	
	for perk in perks:
		if perk.get_parent():
			perk.reparent(self)
		else:
			add_child(perk)
		
		perk.position = perk_pos + chest_opening_root.position
		perk.reset_physics_interpolation()
		perk.root_pos = perk.position
		perk_pos += POS_OFFSET

func finish_chest_opening():
	opening_chest = false
	chest_confirm_button.hide()
	for child in chest_opening_root.get_children():
		child.queue_free()
	
	toggle_off()
#region Chest opening


func _on_chest_confirm_button_pressed() -> void:
	finish_chest_opening()
