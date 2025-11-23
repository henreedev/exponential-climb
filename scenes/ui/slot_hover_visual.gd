extends AnimatedSprite2D

class_name SlotHoverVisual

var movement_tween: Tween
## Tweens to new position unless it's far.
func move_to(new_global_pos: Vector2):
	play("default")
	if movement_tween: 
		movement_tween.kill()
	#const MAX_DIST = 100 # px
	if not visible:
		global_position = new_global_pos
	else:
		movement_tween = create_tween()
		movement_tween.tween_property(self, "global_position", new_global_pos, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	# Assume selector should be visible if moving
	show_selector() 

var visibility_tween: Tween
var showing := false
## Tweens in selector with a flash.
func show_selector():
	if not showing:
		showing = true
		if visibility_tween: 
			visibility_tween.kill()
		visibility_tween = create_tween()
		show()
		visibility_tween.tween_property(self, "modulate", Color(4,4,4,0.8), 0.2)
		visibility_tween.tween_property(self, "modulate", Color.WHITE, 0.1)

## Tweens out selector with darkening. 
func hide_selector():
	if showing:
		showing = false
		if visibility_tween: 
			visibility_tween.kill()
		visibility_tween = create_tween()
		visibility_tween.tween_property(self, "modulate", Color(0,0,0,0), 0.25)
		visibility_tween.tween_callback(hide)
