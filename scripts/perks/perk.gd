extends Node2D

## The base class for all perks. 
class_name Perk 

## Emitted when a perk is selected with the mouse.
signal selected

enum Rarity {
	COMMON, 
	RARE, 
	EPIC, 
	LEGENDARY,
	EMPTY
}

enum TriggerType {
	ON_JUMP, 
	ON_HIT, 
	ON_DISTANCE_TRAVELLED, 
	ON_KILL, 
	ON_LAND,
}

enum Type {
	EMPTY, ## Placeholder for an empty, available perk slot.
	SPEED_BOOST, 
	APPLE,
	CAT_ALERT,
	FEATHER,
	MATCH, 
	SUN_MOON,
	TARGET,
	TREE,
}


const PERK_SCENE = preload("res://scenes/perks/perk.tscn")

#region Perk attributes

## The perk name used in code, likely not the final display name.
var code_name : String
## The perk name displayed to the player in-game.
var display_name : String
## The perk's type, indicating its unique effect.
var type : Type
## The perk's rarity. See `Rarity`.
var rarity : Rarity
## The perk's power, a value that perk effects can choose to scale off of.
var power : Stat
## The perk's description, shown to the player in-game. 
## Supplied to a RichTextLabel, so bbcode can be used.
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

#region Perk UI drag-and-drop
## The value that `position` will return to upon this perk being dropped.
var root_pos := Vector2.ZERO 
var mouse_hovering := false
var mouse_holding := false
## True when any perk is being held. Used to only hold one perk at a time.
static var any_perk_held := false
## Where the perk will move to upon being dropped. 
var drop_position : Vector2
## The build the perk will slot into upon being dropped. Can be null if no build is close enough.
var drop_build : PerkBuild
## The slot index within the drop_build the perk will slot into upon being dropped.
var drop_idx : int

## The tween used for animating position changes.
var pos_tween : Tween

## Whether this perk can be hovered for info.
var hoverable := false
## Whether this perk can be picked up.
var pickupable := false
## Whether this perk can be clicked to be selected. 
## Generally mutually exclusive with hoverable, but a perk can be both
## not selectable and not hoverable (such as a perk pickup on the floor).
var selectable := false
## Whether this perk is selected. Used for chest perk selection.
var is_selected := false
#endregion Perk UI drag-and-drop

#region Perk UI Info on hover
@onready var name_label: Label = $NameLabel
@onready var description_label: RichTextLabel = $DescriptionLabel

const KEY_WORDS : Dictionary[String, Color] = {
	"player loop speed" : Color.PALE_GREEN,
	"loop speed" : Color.WHITE,
	"power" : Color.WHITE,
	"area" : Color.WHITE,
	"range" : Color.WHITE,
	"runtime" : Color.WHITE,
	"cooldown" : Color.WHITE,
	"active" : Color.WHITE,
	"passive" : Color.WHITE,
}

#endregion Perk UI Info on hover

#region Perk animations
@onready var background: AnimatedSprite2D = %Background
@onready var perk_art: AnimatedSprite2D = %PerkArt
@onready var border: AnimatedSprite2D = %Border
@onready var loop: AnimatedSprite2D = %Loop

#endregion Perk animations

# Shake perk using shaker
@onready var shaker: ShakeableNode2D = $Shaker


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
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	_process_timers(delta)
	_update_loop_process_frame_rate()
	_update_anim_speed_scale()

func _physics_process(delta: float) -> void:
	_process_ui_interaction(delta)

#endregion Base functions



#region Gameplay logic functions
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
	#else:
		#activations.append_add_mod(-1) # Subtract one activation
	# Activate effect
	match type:
		Type.SPEED_BOOST:
			var speed_mult = 1 + final_pow * 0.1 
			var effect_dur = 3.0 
			var movement_buff = Effect.activate(Effect.Type.MOVEMENT_SPEED_INCREASE_MULT,\
											 	speed_mult, effect_dur, context)
			running_effects.append(movement_buff)
		Type.APPLE: 
			pass
		Type.CAT_ALERT:
			pass
		Type.FEATHER:
			pass
		Type.MATCH: 
			pass
		Type.SUN_MOON:
			pass
		Type.TARGET:
			pass
		Type.TREE:
			pass

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
	if not Global.perk_ui.active:
		delta *= Loop.display_player_speed
		if cooldown_timer > 0:
			cooldown_timer = maxf(0, cooldown_timer - delta)
		if runtime_timer > 0:
			runtime_timer = maxf(0, runtime_timer - delta)

func _load_perk_info():
	var perk_info := PerkManager.PERK_INFO_DICT[type]
	rarity = perk_info.rarity
	code_name = perk_info.code_name
	display_name = perk_info.display_name
	description = perk_info.description
	is_active = perk_info.is_active
	is_trigger = perk_info.is_trigger
	trigger_type = perk_info.trigger_type
	# Load stats
	power = Stat.new()
	runtime = Stat.new()
	cooldown = Stat.new()
	loop_cost = Stat.new()
	power.set_base(perk_info.base_power)
	runtime.set_base(perk_info.runtime)
	cooldown.set_base(perk_info.cooldown)
	loop_cost.set_base(perk_info.loop_cost)

func _load_perk_visuals():
	if is_empty_perk(): 
		background.modulate = Color.TRANSPARENT
		perk_art.modulate = Color.TRANSPARENT
		border.modulate = Color.WEB_GREEN
	
	_pick_art()
	_pick_background()
	_pick_border()
	_pick_label_contents()
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
	if Global.perk_ui.active: 
		if not is_empty_perk():
			move_while_held(delta)
			update_drop_vars_while_held()
			if Input.is_action_just_pressed("attack"):
				if mouse_hovering:
					if pickupable and not any_perk_held:
						mouse_holding = true
						any_perk_held = true
						Loop.finish_animating_passive_builds()
					if selectable:
						select()
			if Input.is_action_just_released("attack") and mouse_holding:
				drop_perk()
			if mouse_hovering and not mouse_holding and hoverable:
				name_label.show()
				description_label.show()
			else:
				name_label.hide()
				description_label.hide()
#region Selection
func select():
	is_selected = true
	modulate = Color.WHITE * 1.3
	deselect_other_perks()

func deselect():
	is_selected = false
	modulate = Color.WHITE 

func deselect_other_perks():
	for perk : Perk in get_tree().get_nodes_in_group("perk"):
		if perk != self:
			perk.deselect()

#region Selection
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
		else:
			drop_position = drop_build.idx_to_pos(drop_idx)
	else:
		z_index = 0

func drop_perk():
	mouse_holding = false
	any_perk_held = false
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
			replaced_perk.set_loop_anim("none")
		
		root_pos = drop_position
	
	move_to_root_pos()
	if replaced_perk:
		replaced_perk.move_to_root_pos()

func move_to_root_pos(dur := 0.5, trans := Tween.TransitionType.TRANS_QUINT, ease := Tween.EaseType.EASE_OUT):
	reset_pos_tween(true)
	pos_tween.tween_property(self, "position", root_pos, dur).set_trans(trans).set_ease(ease)
	if context.build:
		pos_tween.parallel().tween_property(self, "scale", Vector2.ONE, dur).set_trans(trans).set_ease(ease)
	else:
		pos_tween.parallel().tween_property(self, "scale", Vector2.ONE * 2, dur).set_trans(trans).set_ease(ease)

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
	var builds = Global.player.build_container.active_builds.duplicate() 
	builds.append_array(Global.player.build_container.passive_builds)
	for build : PerkBuild in builds:
		var dist = build.global_position.distance_to(global_position)
		if dist < nearest_dist and build.is_active == is_active:
			nearest_build = build
			nearest_dist = dist
	return nearest_build

func _on_pickup_area_mouse_entered() -> void:
	if Global.perk_ui.active and not is_empty_perk():
		mouse_hovering = true

func _on_pickup_area_mouse_exited() -> void:
	if not is_empty_perk():
		mouse_hovering = false

## Called when a perk enters this perk's area.
#func _on_pickup_area_area_entered(area: Area2D) -> void:
	#var perk : Perk = area.get_parent()
	## TODO 


#endregion Pickup logic

#region Loop animation logic
## Set the loop fx framerate such that the runtime of the perk will be completed 
## at the same time as the processing animation.
func _update_loop_process_frame_rate():
	var process_frame_count = loop.sprite_frames.get_frame_count("process")
	var dur = runtime.value()
	var frame_rate = 1.0 / dur * float(process_frame_count)
	const ENTER_EXIT_FPS = Loop.EMPTY_SLOT_DURATION
	loop.sprite_frames.set_animation_speed("process", frame_rate)

func _update_anim_speed_scale():
	loop.speed_scale = Loop.display_player_speed if not Global.perk_ui.active else 0.0



func _pick_border():
	if is_empty_perk():
		border.animation = "normal_active" # FIXME
		return
	var border_rarity : String
	var active_or_passive : String
	
	match rarity:
		Rarity.COMMON, Rarity.RARE, Rarity.EPIC:
			border_rarity = "normal"
		Rarity.LEGENDARY:
			border_rarity = "legendary"
		Rarity.EMPTY:
			border_rarity = "empty" 
		_:
			assert(false)
	if is_trigger:
		active_or_passive = "trigger"
	elif is_active:
		active_or_passive = "active"
	else:
		active_or_passive = "passive"
		
	border.animation = border_rarity + "_" + active_or_passive

func _pick_label_contents():
	# Set name
	name_label.text = display_name
	
	# Set description, generating perk details at the bottom and highlighting keywords.
	description_label.text = description
	# Generate details
	var details = ""
	if is_active:
		details += "Active"

func _pick_background():
	match rarity:
		Rarity.COMMON: 
			background.animation = "common"
		Rarity.RARE: 
			background.animation = "rare"
		Rarity.EPIC:
			background.animation = "epic"
		Rarity.LEGENDARY:
			background.animation = "legendary"
		Rarity.EMPTY:
			background.animation = "empty" 
		_:
			assert(false)

func _pick_art():
	if perk_art.sprite_frames.has_animation(code_name):
		perk_art.animation = code_name
	else:
		print("PerkArt SpriteFrames doesn't have animation \"", code_name, "\"")

func get_loop_process_frame_rate():
	return loop.sprite_frames.get_animation_speed("process")

func start_loop_cooldown_anim():
	set_loop_anim("wait_for_cooldown")

func start_loop_process_anim():
	set_loop_anim("process")

## Figures out the next perk's frame rate, and sets the "end" animation to that before playing it.
func end_loop_anim():
	if not context.build:
		set_loop_anim("none")
		return
	var next_perk : Perk
	# If we're the last perk, look at the first perk as the next perk.
	var last_perk : Perk = context.build.idx_to_perk(-1)
	if self == last_perk:
		# Get first perk
		next_perk = context.build.idx_to_perk(0)
	else:
		next_perk = context.build.idx_to_perk(context.slot_index + 1)
	if next_perk and self != next_perk:
		loop.sprite_frames.set_animation_speed("end", next_perk.get_loop_process_frame_rate())
	set_loop_anim("end")

func set_loop_anim(anim : String):
	loop.animation = anim
	loop.play(anim)

#region Locking in passive perk animation

## Determines which loop process frame to display based on a progress value from 0.0 to 1.0.
## Also displays it.
func animate_loop_process(progress : float):
	var frames = loop.sprite_frames.get_frame_count("process")
	loop.animation = "process"
	loop.frame = lerp(0, frames, progress)

#endregion Locking in passive perk animation


#endregion Loop animation logic
