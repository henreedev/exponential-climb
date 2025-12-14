extends Node2D

class_name BossDoor

@onready var boss_clip_polygon: Polygon2D = $BossClipPolygon
@onready var door_inner: Sprite2D = $DoorInnerClipPolygon/DoorInner

var knock_count := 0

func add_boss_clip_polygon_child(boss: Node2D): # TODO replace with Boss type
	boss_clip_polygon.add_child(boss)

func reparent_clipped_bosses_to_game() -> void:
	for child in boss_clip_polygon.get_children():
		child.reparent(Global.game)

var door_tween: Tween

func kill_and_remake_tween(tween: Tween) -> Tween:
	if tween:
		tween.kill()
	return create_tween()

func lower_slightly_on_knock():
	const LOWER_AMOUNT = 2.0
	door_tween = kill_and_remake_tween(door_tween)
	door_tween.tween_property(door_inner, "position:y", minf(door_inner.position.y + LOWER_AMOUNT, 61), 0.1)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

func open_door_visual():
	door_tween = kill_and_remake_tween(door_tween)
	door_tween.tween_property(door_inner, "position:y", clampf(door_inner.position.y + 61, 61, 80), 1.0)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)

func close_door_visual():
	door_tween = kill_and_remake_tween(door_tween)
	door_tween.tween_property(door_inner, "position:y", 0.0, 1.0)\
		.set_trans(Tween.TRANS_SINE)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
