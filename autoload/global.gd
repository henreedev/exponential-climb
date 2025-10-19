extends Node

signal max_perks_updated
signal max_builds_updated

const GRAVITY := 850.0

var debug_mode := true

var time_scale := 1.0
## The tween used to stop time during freeze frames.
var freeze_tween : Tween

var game : Game
var perk_ui : PerkUI:
	get: 
		if not perk_ui:
			perk_ui = get_tree().get_first_node_in_group("perk_ui")
		return perk_ui
var ui : UI
var effect_bar : EffectBar:
	get: 
		if not effect_bar:
			effect_bar = get_tree().get_first_node_in_group("effect_bar")
		return effect_bar
var player : Player
var enemy : Enemy
var floor : Floor

var max_perks := 4
var max_build_size := 4
var max_builds := 4
var builds: Array[PerkBuild]
const BUILD_SIZE = 4
#var enemies : Array[Enemy]

## Collision layer 1.
const PLAYER_LAYER = 1

## Collision layer 2.
const ENEMY_LAYER = 2

## Collision layer 3.
const MAP_LAYER = 4

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_perk_ui"):
		perk_ui.toggle()

func add_perk_slot():
	max_perks += 1
	if max_build_size < BUILD_SIZE: 
		max_build_size += 1
	if max_perks > BUILD_SIZE * max_builds: # More perks than player has space for
		# Add a new build to put perks in
		max_builds += 1
		max_builds_updated.emit()
	max_perks_updated.emit()

func refresh_builds_array():
	builds.clear()
	builds.append_array(player.build_container.passive_builds)
	builds.append_array(player.build_container.active_builds)
	# Re-index the builds
	for i in range(builds.size()):
		builds[i].index = i

func get_build_safe(build_index: int):
	if build_index < 0 or build_index >= builds.size():
		return null
	return builds[build_index]

func do_freeze_frame(duration : float):
	if freeze_tween: 
		freeze_tween.kill()
	freeze_tween = create_tween()
	freeze_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	freeze_tween.tween_property(get_tree(), "paused", true, 0.0)
	freeze_tween.tween_interval(duration)
	freeze_tween.tween_property(get_tree(), "paused", false, 0.0)

func is_player_collider(body : CollisionObject2D):
	return body.collision_layer == PLAYER_LAYER

func is_enemy_collider(body : CollisionObject2D):
	return body.collision_layer == ENEMY_LAYER

func is_map_collider(body : CollisionObject2D):
	return body.collision_layer == MAP_LAYER
