extends Node2D

class_name SpiderWebBall

signal cocooned_player

var is_player_cocooned := false
var is_player_in_hitbox := false
const PLAYER_COCOON_PROGRESS_RATE := 4.0
var player_cocoon_progress := 0.0
## Apply this drag strength linearly with cocooned progress
const PLAYER_COCOON_DRAG_STRENGTH := 10.0
const PLAYER_FULLY_COCOONED_EXTRA_DRAG_STRENGTH := 5.0
const PLAYER_COCOON_ARMOR_BUFF := 100.0
const PLAYER_COCOON_DURATION := 4.0

const DPS := 10.0

var size_tween: Tween
var armor_mod_inst: StatMod

@onready var hitbox: Area2D = $Hitbox
@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	deactivate_hitbox()

func show_ball(transition_dur := 2.5):
	size_tween = Utils.kill_and_remake_tween(size_tween)
	show()
	size_tween.tween_property(self, "scale", Vector2.ONE, transition_dur).from(Vector2.ZERO).set_trans(Tween.TRANS_SINE)
	size_tween.tween_callback(activate_hitbox)


## Also activates particles. 
func activate_hitbox(after_dur := 2.5):
	var tween := create_tween()
	gpu_particles_2d.emitting = true
	tween.tween_property(gpu_particles_2d, "amount_ratio", 1.0, after_dur).from(0.0)
	tween.tween_property(hitbox, "process_mode", Node.PROCESS_MODE_INHERIT, 0)

func deactivate_hitbox():
	is_player_in_hitbox = false
	hitbox.process_mode = Node.PROCESS_MODE_DISABLED
	gpu_particles_2d.emitting = false

func hide_ball(transition_dur := 1.0):
	player_cocoon_progress = 0.0
	deactivate_hitbox()
	is_player_cocooned = false
	size_tween = Utils.kill_and_remake_tween(size_tween)
	size_tween.tween_property(self, "scale", Vector2.ZERO, transition_dur).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	size_tween.tween_callback(queue_free)
	if armor_mod_inst:
		Global.player.armor.remove_mod(armor_mod_inst)

func cocoon_player():
	if not is_player_cocooned:
		is_player_cocooned = true
		player_cocoon_progress = 1.0
		cocooned_player.emit()
		reparent(Global.player)
		deactivate_hitbox()
		# Apply armor buff
		armor_mod_inst = Global.player.armor.append_add_mod(PLAYER_COCOON_ARMOR_BUFF)
		create_tween().tween_property(self, "position", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		# Hide after cocoon duration
		create_tween().tween_callback(hide_ball).set_delay(PLAYER_COCOON_DURATION)

func hide_if_not_cocooning_player():
	if not is_player_cocooned: hide_ball()

func update_cocoon_progress(delta: float):
	if is_player_cocooned: 
		return
	if is_player_in_hitbox:
		player_cocoon_progress += PLAYER_COCOON_PROGRESS_RATE * delta
		player_cocoon_progress = minf(1.0, player_cocoon_progress)
	else: # FIXME using 0.0
		player_cocoon_progress -= PLAYER_COCOON_PROGRESS_RATE * 0.0 * delta
		player_cocoon_progress = maxf(0.0, player_cocoon_progress)
	
	if player_cocoon_progress == 1:
		cocoon_player()

func _physics_process(delta: float) -> void:
	update_cocoon_progress(delta)
	apply_cocoon_debuff(delta)

func apply_cocoon_debuff(delta: float):
	var friction = player_cocoon_progress * PLAYER_COCOON_DRAG_STRENGTH + \
					(PLAYER_FULLY_COCOONED_EXTRA_DRAG_STRENGTH if is_player_cocooned else 0.0)
	print(friction)
	if friction > 0:
		Global.player.add_friction(friction)
	if is_player_cocooned:
		Global.player.take_damage(DPS * delta)


func _on_hitbox_area_entered(_area: Area2D) -> void:
	is_player_in_hitbox = true

func _on_hitbox_area_exited(_area: Area2D) -> void:
	is_player_in_hitbox = false
