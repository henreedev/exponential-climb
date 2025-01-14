extends Node

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("fullscreen"):
		print("bruh")
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED
