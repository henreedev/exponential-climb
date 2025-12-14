extends Node

class_name Utils

static func kill_and_remake_tween(tween: Tween) -> Tween:
	if tween:
		tween.kill()
	return Global.game.create_tween()
