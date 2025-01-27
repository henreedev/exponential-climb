extends AnimatedSprite2D

class_name PerkArtParticle

const SCENE = preload("res://scenes/perks/effects/perk_art_particle.tscn")

var dur := 1.0
var tween : Tween
var raise_amount := 8.0

static func create(perk_type : Perk.Type, attach_to : Node = null, _dur := 1.0, pos : Vector2 = Vector2.ZERO, _raise_amount := 8.0, _scale := Vector2.ONE):
	var new_particle : PerkArtParticle = SCENE.instantiate()
	new_particle.animation = PerkManager.PERK_INFO_DICT[perk_type].code_name
	new_particle.dur = _dur
	new_particle.position = pos
	new_particle.raise_amount = _raise_amount
	new_particle.scale = _scale
	if attach_to:
		attach_to.add_child(new_particle)
	else:
		Global.game.add_child(new_particle)
	new_particle.reset_physics_interpolation()
	return new_particle

func _ready():
	tween = create_tween()
	
	var END_OFFSET = Vector2(0, -raise_amount) 
	
	tween.tween_property(self, "position", position + END_OFFSET, dur)
	tween.parallel().tween_property(self, "modulate", Color(10, 10, 10, 1), dur * 0.2)
	tween.tween_property(self, "modulate", Color(10, 10, 10, 0), dur * 0.8)
	tween.tween_callback(queue_free)

func kill_early(kill_dur := 0.2):
	if tween: 
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate", Color(10, 10, 10, 0), kill_dur)
	tween.tween_callback(queue_free)
