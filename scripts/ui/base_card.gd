@abstract
extends Control

## Base class for PerkCard and ModCard, housing show/hide and update methods.
class_name BaseCard

var visibility_tween: Tween
var showing := false

@abstract func _connect_refresh_signals()

@abstract func refresh()

func show_card():
	if not showing:
		showing = true
		if visibility_tween:
			visibility_tween.kill()
		visibility_tween = create_tween()
		visibility_tween.tween_interval(.25)
		visibility_tween.tween_callback(show)
		visibility_tween.tween_property(self, "scale", Vector2.ONE, .2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		visibility_tween.parallel().tween_property(self, "modulate", Color.WHITE, .2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func hide_card():
	if showing:
		showing = false
		if visibility_tween:
			visibility_tween.kill()
		visibility_tween = create_tween()
		visibility_tween.tween_property(self, "scale", Vector2.ONE * .95, .2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		visibility_tween.parallel().tween_property(self, "modulate", Color(5, 5, 5, 0), .2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		visibility_tween.tween_callback(hide)
