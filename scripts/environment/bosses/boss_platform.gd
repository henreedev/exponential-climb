extends Node2D

class_name BossPlatform

const BOSS_SPAWN_OFFSET = Vector2(-140, -35)
const SPIDER_BOSS = preload("uid://dibt1c2ikcn2u")

@onready var boss_door: BossDoor = $BossDoor
@onready var teleporter_blood: Sprite2D = $Platform/TeleporterBlood

var boss: SpiderBoss # TODO generalize
var summoning_boss := false
var boss_dead := false

var knock_count := 0

## True when the door can be interacted with (knocked or entered)
var can_interact := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if can_interact and Input.is_action_just_pressed("interact"):
		interact()

func _physics_process(delta: float) -> void:
	can_interact = boss_dead or \
					(not boss \
					and Global.player.global_position.distance_to(global_position + Vector2.UP * 35) < 40)

func spawn_boss() -> void:
	boss = SPIDER_BOSS.instantiate()
	boss.position = BOSS_SPAWN_OFFSET
	boss_door.add_boss_clip_polygon_child(boss)
	boss.ended_animation.connect(boss_door.reparent_clipped_bosses_to_game)
	boss.ended_animation.connect(Global.player.set_camera_focus_on_pos.bind(false))
	boss.ended_animation.connect(boss_door.close_door_visual)
	boss.died.connect(_on_boss_died)

func start_summoning_boss() -> void:
	if not summoning_boss:
		summoning_boss = true
		Global.player.set_camera_focus_on_pos(true, self)
		# TODO enclose player in a circle
		
		var tween: Tween = create_tween()
		tween.tween_interval(1.0)
		tween.tween_callback(boss_door.open_door_visual)
		tween.tween_callback(spawn_boss)
	

var showing_hand_animation := false
func show_knock() -> void:
	boss_door.lower_slightly_on_knock()
	
	var knock_text_base_pos := global_position + Vector2(3, -61)
	var knock_text_pos := knock_text_base_pos + Vector2(randf_range(-10, 10), randf_range(-5, 5))
	var knock_text_color: DamageNumber.DamageColor
	match knock_count:
		0: 
			knock_text_color = DamageNumber.DamageColor.DEFAULT
		1: 
			knock_text_color = DamageNumber.DamageColor.MEDIUM_DAMAGE
		2: 
			knock_text_color = DamageNumber.DamageColor.HIGH_DAMAGE
		_: 
			knock_text_color = DamageNumber.DamageColor.VERY_HIGH_DAMAGE
	DamageNumbers.create_debug_string("*KNOCK*", knock_text_pos, knock_text_color)
	
	if showing_hand_animation:
		return
	
	showing_hand_animation = true
	var knock_top_pos := global_position + Vector2.UP * 60
	var knock_bottom_pos := global_position + Vector2.UP * 40
	
	const DUR = 0.25
	var hand_tween := create_tween()
	hand_tween.tween_method(set_hand_target, get_hand_target(), knock_top_pos, DUR * 0.5).set_trans(Tween.TRANS_BACK)
	hand_tween.tween_method(set_hand_target, knock_top_pos, knock_bottom_pos, DUR * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	hand_tween.tween_callback(clear_hand_target)
	hand_tween.tween_property(self, "showing_hand_animation", false, 0)

func get_hand_target() -> Vector2:
	return Global.player.player_skeleton.get_target_override_position(PlayerSkeleton.BodyPart.RIGHT_ARM)

func set_hand_target(pos: Vector2):
	Global.player.player_skeleton.set_target_override_position(PlayerSkeleton.BodyPart.RIGHT_ARM, pos)

func clear_hand_target():
	Global.player.player_skeleton.clear_target_override_position(PlayerSkeleton.BodyPart.RIGHT_ARM)

func interact() -> void:
	if boss_dead:
		DamageNumbers.create_debug_string("TODO", global_position)
	else:
		knock()

func knock() -> void:
	if knock_count == 2:
		# This is the third knock
		start_summoning_boss()
		flash_blood_visual(15, 2.5)
	else: 
		flash_blood_visual(3 + knock_count * 3)
	show_knock()
	
	knock_count += 1

var spikes_tween: Tween
func flash_blood_visual(to_intensity: float, fadeout_dur := 1.0):
	spikes_tween = Utils.kill_and_remake_tween(spikes_tween)
	spikes_tween.tween_property(teleporter_blood, "modulate", Color.WHITE * to_intensity, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	spikes_tween.tween_property(teleporter_blood, "modulate", Color.WHITE, fadeout_dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _on_boss_died():
	boss_dead = true
