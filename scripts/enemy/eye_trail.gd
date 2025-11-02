extends Line2D

class_name EyeTrail

@export var target_parent: Node2D
const UPDATES_PER_SEC = 15
const UPDATE_INTERVAL = 1.0 / float(UPDATES_PER_SEC)
var update_timer := 0.0
const MAX_POINTS = 10
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	clear_points()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Remove old points
	while get_point_count() > MAX_POINTS:
		remove_point(0)
	# Raise points with gravity
	for i in range(get_point_count()):
		var oldness = MAX_POINTS - i # New points are added to last index
		var up = Vector2.UP * 5.0 * delta * oldness
		set_point_position(i, get_point_position(i) + up)
	if get_point_count():
		set_point_position(get_point_count() - 1, target_parent.global_position)
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		# Add new point
		add_point(target_parent.global_position)
	else:
		update_timer += delta
