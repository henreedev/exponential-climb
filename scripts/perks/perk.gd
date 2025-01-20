extends Node2D

## The base class for all perks. 
class_name Perk 

enum Rarity {
	COMMON, 
	RARE, 
	LEGENDARY,
}

enum Type {
	EMPTY, ## Placeholder for an empty, available perk slot.
	LOCKED_SLOT, ## Placeholder for a locked perk slot.
	SPEED_BOOST, 
	SPEED_BOOST_ON_JUMP,
}

enum TriggerType {
	ON_JUMP, 
	ON_HIT, 
	ON_DISTANCE_TRAVELLED, 
	ON_KILL, 
	ON_LAND,
}

const PERK_SCENE = preload("res://scenes/perks/perk.tscn")

## Dict from perk type to the PerkInfo resource storing information on that perk.
const PERK_INFO_DICT : Dictionary[Type, PerkInfo] = {
	Type.EMPTY : preload("res://resources/perks/perk_empty.tres"),
	Type.SPEED_BOOST : preload("res://resources/perks/perk_speed_boost.tres"),
	Type.SPEED_BOOST_ON_JUMP : preload("res://resources/perks/perk_speed_boost_on_jump.tres"),
}

#region Perk attributes

var type : Type
var rarity : Rarity
var power : Stat
var description : String

#region Active

var runtime : Stat ## Perk takes this duration of loop time before the loop can move on.
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

#region Perk UI logic
## The value that `position` will return to upon an unsuccessful drop (did not drop into a new slot).
var root_pos := Vector2.ZERO 
var mouse_hovering := false
var mouse_holding := false
## Where the perk will move to upon being dropped. 
var drop_position : Vector2
## The build the perk will slot into upon being dropped. Can be null if no build is close enough.
var drop_build : PerkBuild
## The slot index within the drop_build the perk will slot into upon being dropped.
var drop_idx : int

## The tween used for animating position changes.
var pos_tween : Tween
#endregion Perk UI logic



#region Perk metadata
var context : PerkContext ## Contains slot information about this perk and its neighbors.
var player : Player ## The parent player of this perk.

var cooldown_timer : float ## Actual time left of the cooldown.
var runtime_timer : float ## Actual time left of the runtime.

var running_effects : Array[Effect]
#endregion Perk metadata


#region Base functions
func _ready() -> void:
	player = Global.player
	_load_perk_info()
	_load_perk_visuals()
	context = PerkContext.new()
	context.initialize(self, player)

func _process(delta: float) -> void:
	_process_timers(delta)

func _physics_process(delta: float) -> void:
	_process_ui_interaction(delta)

#endregion Base functions



#region Core functions
## Instantiates and returns a perk of the given type. Does not add the perk to the scene tree.
static func init_perk(_type : Type) -> Perk:
	var perk : Perk = PERK_SCENE.instantiate()
	perk.type = _type
	perk.player = Global.player
	return perk

## Each perk activation should:
## 1. Initialize effect(s)
## 2. Add them to the effect list
## Each active perk activation should:
## 1. Set runtime timer
## 2. Set cooldown timer
## Each passive perk activation should:
## 1. Subtract an activation 
## 2. Use up loop cost
func activate() -> void:
	var final_dur = runtime.value()
	var final_pow = power.value()
	if is_active:
		runtime_timer = final_dur
		cooldown_timer = cooldown.value() 
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
	runtime_timer = 0.0
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
	if runtime_timer > 0:
		runtime_timer = maxf(0, runtime_timer - delta)

func _load_perk_info():
	var perk_info := PERK_INFO_DICT[type]
	rarity = perk_info.rarity
	power = Stat.new()
	runtime = Stat.new()
	cooldown = Stat.new()
	power.set_base(perk_info.base_power)
	runtime.set_base(perk_info.runtime)
	cooldown.set_base(perk_info.cooldown)
	description = perk_info.description
	is_active = perk_info.is_active
	is_trigger = perk_info.is_trigger
	trigger_type = perk_info.trigger_type

func _load_perk_visuals():
	if is_empty_perk(): 
		modulate = Color.BLACK
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

#region Pickup logic
func _process_ui_interaction(delta : float):
	if not is_empty_perk():
		if Global.perk_ui.showing:
			move_while_held(delta)
			update_drop_vars_while_held()
			if Input.is_action_just_pressed("attack"):
				if mouse_hovering:
					mouse_holding = true
					
			if Input.is_action_just_released("attack") and mouse_holding:
				drop_perk()

## TODO Returns whether the perk was successfully placed into an available build slot or not.
#func put_perk_in_next_build_slot() -> bool:

func move_while_held(delta : float):
	if mouse_holding:
		global_position = global_position.lerp(get_global_mouse_position(), 25.0 * delta)

func update_drop_vars_while_held():
	if mouse_holding:
		z_index = 1
		drop_build = get_nearest_build()
		var local_build_mouse_pos = drop_build.get_local_mouse_position()
		drop_idx = drop_build.pos_to_nearest_idx(local_build_mouse_pos)
		if drop_idx == -1:
			drop_build = null
			drop_position = Vector2.ZERO
			return
		else:
			drop_position = drop_build.idx_to_pos(drop_idx)
	else:
		z_index = 0

func drop_perk():
	mouse_holding = false
	var replaced_perk : Perk
	if drop_build:
		var parent = get_parent()
		reparent(drop_build)
		reset_physics_interpolation()
		
		# Place this perk in the build, and store the perk that was replaced
		replaced_perk = drop_build.place_perk(self, drop_idx)
		# Swap root positions
		if replaced_perk: 
			replaced_perk.reparent(parent)
			replaced_perk.reset_physics_interpolation()
			replaced_perk.root_pos = root_pos 
		
		root_pos = drop_position
	
	move_to_root_pos()
	if replaced_perk:
		replaced_perk.move_to_root_pos()

func move_to_root_pos(dur := 0.3, trans := Tween.TransitionType.TRANS_CUBIC, ease := Tween.EaseType.EASE_OUT):
	reset_pos_tween(true)
	pos_tween.tween_property(self, "position", root_pos, dur).set_trans(trans).set_ease(ease)

func reset_pos_tween(create_new := false):
	if pos_tween:
		pos_tween.kill() 
	if create_new:
		pos_tween = create_tween()


## Returns whether this perk is an empty, placeholder perk.
func is_empty_perk() -> bool:
	return type == Type.EMPTY

func get_nearest_build() -> PerkBuild:
	var nearest_build : PerkBuild
	var nearest_dist := INF
	for build : PerkBuild in Global.perk_ui.builds_root.get_children():
		var dist = build.global_position.distance_to(global_position)
		if dist < nearest_dist:
			nearest_build = build
			nearest_dist = dist
	return nearest_build

func _on_pickup_area_mouse_entered() -> void:
	if Global.perk_ui.showing and not is_empty_perk():
		mouse_hovering = true
		print("mouse entered")

func _on_pickup_area_mouse_exited() -> void:
	if not is_empty_perk():
		mouse_hovering = false
		print("mouse exited")

## Called when a perk enters this perk's area.
#func _on_pickup_area_area_entered(area: Area2D) -> void:
	#var perk : Perk = area.get_parent()
	## TODO 


#endregion Pickup logic
