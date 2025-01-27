extends Node2D
## Describes an effect (active or passive) that occurs when a perk is activated.
class_name Effect

signal ended

enum Type {
	## Multiplicative stat modifier, constant over a duration. Uses `target_stat`.
	MULTIPLICATIVE_MOD,
	SPEED_BOOST, ## Stores charges on movement, release on hit to gain a buff.
	APPLE, ## Buffs next attack to do extra damage.
	CAT_ALERT, ## Stealths player periodically when standing still.
	FEATHER, ## Double jump, airborne attack speed.
	MATCH, ## Ignites enemies on hit.
	SUN_MOON, ## Other weapon deals extra while weapon on cooldown.
	SUNSET, ## Other weapon deals extra while weapon on cooldown.
	TARGET, ## Enemies get targeted, extra range and damage against targets.
	TREE, ## Loop speed and player loop speed increases.
	MUSCLE, ## Base damage based on loop speed, area bonus while grounded.
	BALLOON, ## Attacks raise enemies, hitting ceiling deals damage.
	COFFEE, ## Increased attack and movement speed after jumping.
}

const TYPE_TO_SUBCLASS : Dictionary = {
	Type.MULTIPLICATIVE_MOD : preload("res://scripts/perks/effects/multiplicative_mod_effect.gd"),
	Type.SPEED_BOOST : preload("res://scripts/perks/effects/speed_boost/speed_boost_effect.gd"), ## Stores charges on movement, release on hit to gain a buff.
	Type.APPLE : preload("res://scripts/perks/effects/apple/apple_effect.gd"),
	Type.CAT_ALERT : preload("res://scripts/perks/effects/cat_alert/cat_alert_effect.gd"), ## Stealths player periodically when standing still.
	Type.FEATHER : preload("res://scripts/perks/effects/feather/feather_effect.gd"),
	Type.MATCH : preload("res://scripts/perks/effects/match/match_effect.gd"), ## Ignites enemies on hit.
	Type.SUN_MOON : preload("res://scripts/perks/effects/sun_moon/sun_moon_effect.gd"), ## Other weapon deals extra while weapon on cooldown.
	Type.SUNSET : preload("res://scripts/perks/effects/sunset/sunset_effect.gd"), ## Other weapon deals extra while weapon on cooldown.
	Type.TARGET : preload("res://scripts/perks/effects/target/target_effect.gd"), ## Enemies get targeted, extra range and damage against targets.
	Type.TREE : preload("res://scripts/perks/effects/tree/tree_effect.gd"), ## Loop speed and player loop speed increases.
	Type.MUSCLE : preload("res://scripts/perks/effects/muscle/muscle_effect.gd"),
	Type.BALLOON : preload("res://scripts/perks/effects/balloon/balloon_effect.gd"), ## Attacks raise enemies, hitting ceiling deals damage.
	Type.COFFEE : preload("res://scripts/perks/effects/coffee/coffee_effect.gd"), ## Increased attack and movement speed after jumping.
}

const EFFECT_SCENE = preload("res://scenes/perks/effects/effect.tscn")

var type : Type 
var perk_type : Perk.Type

var duration : float
var duration_timer : float 

## Defines the number used in the effect. Could be anything; depends on the effect
var value : float 

var context : PerkContext

## The stat this effect targets, if applicable.
var target_stat : Stat

var is_instant := false

var active := false

## Dict from a mod to its attached target.
var attached_mods : Dictionary[Mod, Stat] 

## Tween for animating entrance and exit.
var animate_tween : Tween

## Sprites for background, art, border
@onready var background: AnimatedSprite2D = %Background
@onready var perk_art: AnimatedSprite2D = %PerkArt
@onready var border: AnimatedSprite2D = %Border
## Node holding visuals, can be shaken
@onready var shaker: ShakeableNode2D = $ShakeableNode2D


## Initializes an Effect of the given type for the given duration and value. 
## For infinite duration, pass `_duration = -1.0`.
static func activate(_type : Type, _value : float, _duration : float, _context : PerkContext, _target_stat : Stat = null) -> Effect:
	return _init_effect(_type, _value, _duration, _context, _target_stat)

static func _init_effect(_type : Type, _value : float, _duration : float, _context : PerkContext, _target_stat : Stat = null) -> Effect:
	var effect = EFFECT_SCENE.instantiate()
	effect.set_script(TYPE_TO_SUBCLASS[_type])
	effect.type = _type
	effect.value = _value
	effect.duration = _duration
	effect.duration_timer = effect.duration
	effect.context = _context
	effect.target_stat = _target_stat
	effect.perk_type = effect.context.perk.type
	effect.active = true
	effect.add_to_group("effect")
	effect.set_process(true)
	Global.effect_bar.add_effect(effect)
	return effect

func _ready() -> void:
	duration_timer = duration
	_pick_art()
	_pick_background()
	_pick_border()
	_animate_entrance()
	_start_effect()

## Child classes should override this function for effect start logic.
## Starting an effect should: 
## 1. Begin applying an actual effect in game by modifying or doing something
## 2. If not instant, set the duration timer to the duration 
func _start_effect() -> void:
	pass


func _process(delta: float) -> void:
	if active:
		# Duration of -1.0 = infinite. Duration of 0.0 is instant (will last one frame).
		if duration_timer != -1.0:
			if duration_timer <= 0:
				end_effect()
			else:
				duration_timer -= delta
		_process_effect(delta)
	else:
		_try_animate_exit()

## Child classes should override this function for process logic
func _process_effect(delta : float) -> void:
	pass # Subclass and add process logic for perks that need it (e.g. aoe dot)

## Child classes should override this function for process logic
func do_end_effect() -> void:
	pass # Subclass and add ending logic for perks that need it

## Child classes should override this function for ending logic
func end_effect() -> void:
	do_end_effect()
	for mod : Mod in attached_mods.keys():
		var target_stat : Stat = attached_mods[mod]
		target_stat.remove_mod(mod) 
	context.perk.running_effects.erase(self)
	Global.effect_bar.remove_effect(self)
	active = false
	ended.emit()
	
	_try_animate_exit()

## Animates the entrance into the UI.
func _animate_entrance():
	const START_POS := Vector2(0, -20)
	const DUR := 0.35
	animate_tween = create_tween().set_parallel()
	animate_tween.tween_property(shaker, "modulate", Color.WHITE, DUR).from(Color(10.0, 10.0, 10.0, 0.0)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animate_tween.tween_property(background, "offset", Vector2.ZERO, DUR).from(START_POS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	animate_tween.tween_property(perk_art, "offset", Vector2.ZERO, DUR).from(START_POS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	animate_tween.tween_property(border, "offset", Vector2.ZERO, DUR).from(START_POS).set_trans(Tween.TRANS_SINE	).set_ease(Tween.EASE_OUT)
	animate_tween.chain().tween_callback(set_animate_tween_null)


## Animates the exit (fade-out) of this perk from the UI, but only if not animating entrance. 
func _try_animate_exit():
	if not animate_tween:
		const END_POS := Vector2(0, -8)
		const DUR := 0.5
		animate_tween = create_tween().set_parallel()
		animate_tween.tween_property(shaker, "modulate", Color(0.0, 0.0, 0.0, 0.0), DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		animate_tween.tween_property(background, "offset", END_POS, DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		animate_tween.tween_property(perk_art, "offset", END_POS, DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		animate_tween.tween_property(border, "offset", END_POS, DUR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		animate_tween.chain().tween_callback(queue_free)

func set_animate_tween_null():
	animate_tween = null

func get_perk_type() -> Perk.Type:
	return context.perk.type

func _pick_border():
	border.animation = "effect"

func _pick_background():
	background.animation = "effect"

func _pick_art():
	if perk_art.sprite_frames.has_animation(context.perk.code_name):
		perk_art.animation = context.perk.code_name
	else:
		print("Effect PerkArt SpriteFrames doesn't have animation \"", context.perk.code_name, "\"")
