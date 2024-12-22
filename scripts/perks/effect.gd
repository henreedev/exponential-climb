extends Node
## Describes an effect (active or passive) that occurs when a perk is activated.
class_name Effect

enum Type {
	## Multiplicative movement speed multiplier, constant over a duration
	MOVEMENT_SPEED_INCREASE_MULT, 
}

var type : Type 

var duration : float
var duration_timer : float 

## Defines the number used in the effect. Could be anything; depends on the effect
var value : float 

var context : PerkContext

var is_instant := false

## Dict from a mod to its attached target.
var attached_mods : Dictionary[Mod, Stat] 

# Initializes an Effect of the given type for the given duration and value. 
static func activate(_type : Type, _value : float, _duration : float, _context : PerkContext) -> Effect:
	return _init_effect(_type, _value, _duration, _context)

static func _init_effect(_type : Type, _value : float, _duration : float, _context : PerkContext):
	var effect = Effect.new()
	effect.type = _type
	effect.value = _value
	effect.duration = _duration
	effect.duration_timer = effect.duration
	effect.context = _context
	effect.add_to_group("effect")
	_context.perk.add_child(effect)
	return effect

func _ready() -> void:
	_start_effect()

## Starting an effect should: 
## 1. Begin applying an actual effect in game by modifying or doing something
## 2. If not instant, set the duration timer to the duration 
func _start_effect() -> void:
	duration_timer = duration
	match type:
		Type.MOVEMENT_SPEED_INCREASE_MULT:
			var target_stat : Stat = context.player.movement_speed
			var mod : Mod = target_stat.append_mult_mod(value)
			attached_mods[mod] = target_stat 


func _process(delta: float) -> void:
	_process_effect(delta)


func _process_effect(delta : float) -> void:
	if duration_timer <= 0:
		end_effect()
	else:
		duration_timer -= delta
	# TODO add process logic for perks that need it (e.g. aoe dot)

func end_effect() -> void:
	for mod : Mod in attached_mods.keys():
		var target_stat : Stat = attached_mods[mod]
		target_stat.remove_mod(mod) 
	context.perk.running_effects.erase(self)
	queue_free()
