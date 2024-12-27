extends Node

## The base class for all perks. 
class_name Perk 

enum Rarity {COMMON, RARE, LEGENDARY}
enum Type {SPEED_BOOST, SPEED_BOOST_ON_JUMP}
enum TriggerType {ON_JUMP, ON_HIT, ON_DISTANCE_TRAVELLED, ON_KILL, ON_LAND}

## Dict from perk type to the PerkInfo resource storing information on that perk.
const PERK_INFO_DICT : Dictionary[Type, PerkInfo] = {
	Type.SPEED_BOOST : preload("res://resources/perks/perk_speed_boost.tres"),
	Type.SPEED_BOOST_ON_JUMP : preload("res://resources/perks/perk_speed_boost_on_jump.tres"),
}

#region Perk attributes

var type : Type
var rarity : Rarity
var power : Stat
var description : String

#region Active

var duration : Stat ## Perk cannot be activated more often than this duration.
var cooldown : Stat ## Perk cannot be activated more often than this duration.
var is_active : bool ## A perk is either active or passive.

#endregion Active

#region Passive

var activations : Stat ## Perk will be activated this many times total.
var loop_cost : Stat ## Perk uses up this much of the loop's value when activated.

#endregion Passive

#region Trigger
var is_trigger : bool
var trigger_type : TriggerType
#endregion Trigger

#endregion Perk attributes



#region Perk metadata
var context : PerkContext ## Contains slot information about this perk and its neighbors.
var player : Player ## The parent player of this perk.

var cooldown_timer : float ## Actual time left of the cooldown.
var duration_timer : float ## Actual time left of the duration.

var running_effects : Array[Effect]
#endregion Perk metadata


#region Base functions
func _ready() -> void:
	if player == null: printerr("ERROR: player must be populated before adding a perk to the scene tree.")
	_load_perk_info()
	context = PerkContext.new()
	context.initialize(self, player)

func _process(delta: float) -> void:
	_process_timers(delta)
#endregion Base functions



#region Core functions

static func init_perk(_type : Type) -> Perk:
	var perk = Perk.new()
	perk.type = _type
	perk.player = Global.player
	perk.player.add_child(perk)
	return perk

## Each perk activation should:
## 1. Initialize effect(s)
## 2. Add them to the effect list
## Each active perk activation should:
## 1. Set duration timer
## 2. Set cooldown timer
## Each passive perk activation should:
## 1. Subtract an activation 
## 2. Use up loop cost
func activate() -> void:
	var final_dur = duration.get_final_value()
	var final_pow = power.get_final_value()
	if is_active:
		duration_timer = final_dur
		cooldown_timer = cooldown.get_final_value() 
	else:
		activations.append_add_mod(-1) # Subtract one activation
	# Activate effect
	match type:
		Type.SPEED_BOOST, Type.SPEED_BOOST_ON_JUMP:
			var speed_mult = 1 + final_pow * 0.1 
			var movement_buff = Effect.activate(Effect.Type.MOVEMENT_SPEED_INCREASE_MULT,\
											 	speed_mult, final_dur, context)
			running_effects.append(movement_buff)

## Tell all running effects to deactivate prematurely.
func deactivate() -> void:
	duration_timer = 0.0
	cooldown_timer = 0.0
	for effect : Effect in running_effects:
		if effect != null:
			effect.end_effect()

func delete() -> void:
	deactivate()
	queue_free()

func _process_timers(delta : float) -> void:
	if cooldown_timer > 0:
		cooldown_timer = maxf(0, cooldown_timer - delta)
	if duration_timer > 0:
		duration_timer = maxf(0, duration_timer - delta)

func _load_perk_info():
	var perk_info := PERK_INFO_DICT[type]
	rarity = perk_info.rarity
	power = Stat.new()
	duration = Stat.new()
	cooldown = Stat.new()
	power.set_base(perk_info.base_power)
	duration.set_base(perk_info.duration)
	cooldown.set_base(perk_info.cooldown)
	description = perk_info.description
	is_active = perk_info.is_active
	is_trigger = perk_info.is_trigger
	trigger_type = perk_info.trigger_type

#endregion Core functions


#region Trigger functions
func enable_trigger():
	var trigger_signal = _get_trigger_signal()
	trigger_signal.connect(_activate_trigger)

func disable_trigger():
	var trigger_signal = _get_trigger_signal()
	trigger_signal.disconnect(_activate_trigger)

func _get_trigger_signal():
	match trigger_type:
		TriggerType.ON_JUMP:
			return player.jumped

func _activate_trigger():
	if cooldown_timer > 0:
		return
	Loop.jump_to_index(context.build, context.slot_index)
#endregion Trigger functions


#region Context functions
func refresh_context(build : PerkBuild, new_slot_index : int):
	context.refresh(build, new_slot_index)
#endregion Context functions
