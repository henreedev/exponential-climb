extends Line2D

class_name WebBallLine

@export var target_parent: Node2D
const UPDATES_PER_SEC = 120
const UPDATE_INTERVAL = 1.0 / float(UPDATES_PER_SEC)
var update_timer := 0.0
const MAX_POINTS = 60
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	clear_points()

func _process(delta: float) -> void:
	# Remove old points
	while get_point_count() > MAX_POINTS:
		remove_point(0)
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		# Add new point
		add_point(target_parent.global_position)
	else:
		update_timer += delta
