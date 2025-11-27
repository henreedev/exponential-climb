extends Node2D

class_name PlayerSkeleton
@onready var head_look_at_target: Marker2D = $Skeleton/Targets/HeadLookAtTarget

const FPS = 120
const FRAME_INTERVAL = 1.0 / float(FPS)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#process_mode = Node.PROCESS_MODE_DISABLED
	#var tween := Global.create_tween().set_loops()
	#tween.tween_property(self, "process_mode", ProcessMode.PROCESS_MODE_INHERIT, 0.0)
	#tween.tween_callback(_process.bind(FRAME_INTERVAL)).set_delay(FRAME_INTERVAL)
	#tween.tween_property(self, "process_mode", ProcessMode.PROCESS_MODE_DISABLED, 0.0)
	pass
func _process(_delta: float) -> void:
	head_look_at_target.global_position = get_global_mouse_position()
