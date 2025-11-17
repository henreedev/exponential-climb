extends Node2D

## The base class for all perks. 
class_name Perk 

## Emitted when a perk is selected with the mouse.
signal selected

## Emitted just before a perk activates.
signal activating

## Emitted just after a perk finishes its cooldown, but before it's possibly reactivated.
signal ended_cooldown

## Emitted by trigger perks when they activate. 
signal trigger_activating

## Emitted when the perk's context is updated. 
signal context_updated

## Emitted when a stat on this perk changes.
signal any_stat_updated

enum Category {
	POWER, 
	REACH, 
	TEMPO, 
	EFFICIENCY,
	TRIGGER,
	UTILITY,
}

enum Rarity {
	COMMON, 
	RARE, 
	EPIC, 
	LEGENDARY,
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
## The perk's primary category that it most cleanly fits into.
var primary_category: Category
## The perk's secondary category.
var secondary_category: Category
## The perk's power, a value that perk effects can choose to scale off of.
var power : Stat
## The perk's description, shown to the player in-game. 
## Supplied to a RichTextLabel, so bbcode can be used.
var description : String

#region Active

var runtime : Stat ## Perk takes this duration of loop time before the loop can move on.
var duration : Stat ## Perk's effect lasts for this long.
var cooldown : Stat ## Perk cannot be activated more often than this duration.
var is_active : bool ## A perk is either active or passive.

#endregion Active

#region Passive

## Perk will be activated this many times total
## whenever it is told to activate once.
var activations : Stat  
var loop_cost : Stat ## Perk uses up this much of the loop's value when activated.

#endregion Passive

#region Trigger
var is_trigger : bool
var trigger_type : TriggerType
#region Player distance traveled tracking (for distance triggers)
var player_dist_traveled := 0.0
#endregion Player distance traveled tracking 

#endregion Trigger

#region Modifiers
var perk_mods : Dictionary[PerkMod.Direction, PerkMod] = {
	PerkMod.Direction.SELF : null,
	PerkMod.Direction.LEFT : null,
	PerkMod.Direction.RIGHT : null,
	PerkMod.Direction.UP : null,
	PerkMod.Direction.DOWN : null,
}

var unavailable_mod_directions: Array[PerkMod.Direction] = []
var available_mod_directions: Array[PerkMod.Direction] = [
	PerkMod.Direction.SELF,
	PerkMod.Direction.LEFT,
	PerkMod.Direction.RIGHT,
	PerkMod.Direction.UP,
	PerkMod.Direction.DOWN,
]

#region Modifier Visuals
@onready var modifier_indicator_self: Polygon2D = %ModifierIndicatorSelf
@onready var modifier_indicator_left: Polygon2D = %ModifierIndicatorLeft
@onready var modifier_indicator_right: Polygon2D = %ModifierIndicatorRight
@onready var modifier_indicator_up: Polygon2D = %ModifierIndicatorUp
@onready var modifier_indicator_down: Polygon2D = %ModifierIndicatorDown

@onready var dir_to_modifier_indicator : Dictionary[PerkMod.Direction, CanvasItem] = {
	PerkMod.Direction.SELF : modifier_indicator_self,
	PerkMod.Direction.LEFT : modifier_indicator_left,
	PerkMod.Direction.RIGHT : modifier_indicator_right,
	PerkMod.Direction.UP : modifier_indicator_up,
	PerkMod.Direction.DOWN : modifier_indicator_down,
}

@onready var modifier_buff_highlight: Polygon2D = %ModifierBuffHighlight
@onready var modifier_nerf_highlight: Polygon2D = %ModifierNerfHighlight

var dir_to_mouse_hovering : Dictionary[PerkMod.Direction, bool] = {
	PerkMod.Direction.SELF : false,
	PerkMod.Direction.LEFT : false,
	PerkMod.Direction.RIGHT : false,
	PerkMod.Direction.UP : false,
	PerkMod.Direction.DOWN : false,
}

#endregion Modifier Visuals

#endregion Modifiers

#endregion Perk attributes

#region Perk UI drag-and-drop
## The value that `position` will return to upon this perk being dropped.
var root_pos := Vector2.ZERO 
var mouse_hovering := false
var mouse_holding := false
## True when anything is being held by the mouse. Used by perks and modifiers to only hold one thing at a time.
static var anything_held := false
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
## Whether this perk will be deleted on drop (due to being put in the trash).
var hovering_trash := false
#endregion Perk UI drag-and-drop

#region Perk UI Info
@onready var perk_card: PerkCard = $PerkCard
#endregion Perk UI Info


#region Perk animations
@onready var background: AnimatedSprite2D = %Background
@onready var perk_art: PerkArt = %PerkArt
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
	material = material.duplicate_deep()
	material.get_shader_parameter("dissolve_texture").noise.seed = randi()
	player.traveled_distance.connect(increment_player_dist_traveled)
	Global.perk_ui.toggled_off.connect(perk_card.hide_card)

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
func activate(apply_effect := true) -> void:
	for i in range(activations.value()):
		activating.emit()
		var final_dur = duration.value()
		var final_pow = power.value()
		if is_active:
			runtime_timer = runtime.value()
			cooldown_timer = cooldown.value() 
		#else:
			#activations.append_add_mod(-1) # Subtract one activation
		# Show visual
		show_activation_visual()
		if apply_effect:
			# Activate effect
			match type:
				Type.SPEED_BOOST: # Race Kick
					var charges = player_dist_traveled / 60.0 * final_pow
					final_dur = charges / 10.0
					var mult = 1 + charges * 0.02
					var movement_buff = Effect.activate(Effect.Type.SPEED_BOOST,\
					 	mult, final_dur, context)
					running_effects.append(movement_buff)
					reset_player_dist_traveled()
				Type.APPLE: 
					var damage_mult = 1 + final_pow * 0.1
					var apple_buff = Effect.activate(Effect.Type.APPLE, damage_mult, final_dur, context)
					running_effects.append(apple_buff)
				Type.BALLOON:
					var balloon_buff = Effect.activate(Effect.Type.BALLOON, final_pow, final_dur, context)
					running_effects.append(balloon_buff)
				Type.MUSCLE:
					var damage_mult = 1 + final_pow * 0.1
					var muscle_buff = Effect.activate(Effect.Type.MUSCLE, damage_mult, final_dur, context, player.base_damage)
					running_effects.append(muscle_buff)
				Type.COFFEE:
					var mult = 1 + final_pow * 0.1
					var coffee_buff = Effect.activate(Effect.Type.COFFEE, mult, final_dur, context, player.base_damage)
					running_effects.append(coffee_buff)
				Type.FEATHER:
					var attack_speed_mult = 1 + final_pow * 0.1
					var feather_buff = Effect.activate(Effect.Type.FEATHER, attack_speed_mult, final_dur, context)
					running_effects.append(feather_buff)
				Type.MATCH: 
					var ignite_damage = final_pow * 0.1
					var match_buff = Effect.activate(Effect.Type.MATCH, ignite_damage, final_dur, context)
					running_effects.append(match_buff)
				Type.SUN_MOON:
					var damage_mult = 1 + final_pow * 0.1
					var sun_moon_buff = Effect.activate(Effect.Type.SUN_MOON, damage_mult, final_dur, context)
					running_effects.append(sun_moon_buff)
				Type.SUNSET:
					var area_mult = 1 + final_pow * 0.05
					var sunset_buff = Effect.activate(Effect.Type.SUNSET, area_mult, final_dur, context)
					running_effects.append(sunset_buff)
				Type.TARGET:
					var range_mult = 1 + Loop.display_loop_speed * 0.1
					var target_buff = Effect.activate(Effect.Type.TARGET, range_mult, final_dur, context)
					running_effects.append(target_buff)
				Type.TREE:
					var mult = 1 + final_pow * 0.1
					var tree_buff = Effect.activate(Effect.Type.TREE, mult, final_dur, context)
					running_effects.append(tree_buff)

## Tell all running effects to deactivate prematurely.
func deactivate() -> void:
	runtime_timer = 0.0
	cooldown_timer = 0.0
	for effect : Effect in running_effects:
		if effect != null:
			effect.end_effect()

func delete() -> void:
	deactivate()
	pickupable = false
	selectable = false
	hoverable = false
	remove_from_group("perk") # Make sure it doesnt factor into any perk group checks
	if not is_empty_perk():
		PerkManager.return_perk_to_pool(self)
	detach_mods()
	
	# Display a dissolve animation, then delete
	const DELETE_DUR := 1.0
	var dur = DELETE_DUR * randf_range(0.8, 1.2)
	var tween := create_tween().set_parallel()
	tween.tween_method(set_burn_shader_progress, 1.0, 0.0, dur)
	tween.tween_callback(queue_free).set_delay(dur)

func detach_mods(): 
	var seen = []
	for mod: PerkMod in perk_mods.values():
		if mod:
			if not seen.has(mod):
				seen.append(mod)
				mod.try_detach_and_deactivate()

func set_burn_shader_progress(progress : float):
	material.set_shader_parameter("dissolve_value", progress)

func _process_timers(delta : float) -> void:
	if not Global.perk_ui.active:
		delta *= Loop.display_player_speed
		if cooldown_timer > 0:
			cooldown_timer = maxf(0, cooldown_timer - delta)
			if cooldown_timer == 0:
				# Cooldown just ended
				ended_cooldown.emit()
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
	primary_category = perk_info.primary_category
	secondary_category = perk_info.secondary_category
	
	# Load stats
	power = Stat.new()
	power.set_base(perk_info.base_power)
	
	runtime = Stat.new()
	runtime.set_base(perk_info.runtime)
	runtime.set_minimum(0.05)
	
	duration = Stat.new()
	duration.set_base(perk_info.duration)
	
	cooldown = Stat.new()
	cooldown.set_base(perk_info.cooldown)
	cooldown.set_minimum(0.0)
	
	loop_cost = Stat.new()
	loop_cost.set_base(perk_info.loop_cost)
	loop_cost.set_minimum(0.05)
	
	activations = Stat.new()
	activations.set_base(perk_info.activations)
	activations.set_type(true)
	activations.set_minimum(0)
	
	_connect_any_stat_updated(power, runtime, duration, cooldown, loop_cost, activations)

func _connect_any_stat_updated(...args: Array):
	for stat: Stat in args:
		stat.mods_changed.connect(any_stat_updated.emit)

func _load_perk_visuals():
	if is_empty_perk(): 
		background.modulate = Color.TRANSPARENT
		perk_art.modulate = Color.TRANSPARENT
		border.modulate = Color.WEB_GREEN
	
	_pick_art()
	_pick_background()
	_pick_border()
	perk_card.init_with_perk(self)
#endregion Core functions

#region Player position tracking
func increment_player_dist_traveled(dist : float):
	player_dist_traveled += dist

func reset_player_dist_traveled():
	player_dist_traveled = 0.0
#endregion Player position tracking

#region Trigger functions
func enable_trigger():
	if is_trigger:
		var trigger_signal = _get_trigger_signal()
		trigger_signal.connect(_activate_trigger)

func disable_trigger():
	if is_trigger:
		var trigger_signal = _get_trigger_signal()
		trigger_signal.disconnect(_activate_trigger)

func _get_trigger_signal():
	match trigger_type:
		TriggerType.ON_JUMP:
			return player.jumped
		TriggerType.ON_HIT:
			return player.weapon.attack_hit_no_args
		TriggerType.ON_LAND:
			return player.landed_on_floor

func _activate_trigger():
	if cooldown_timer > 0:
		return
	trigger_activating.emit()
	Loop.jump_to_index(context.build, context.slot_index)
#endregion Trigger functions

#region Context functions
func refresh_context(build : PerkBuild, new_slot_index : int):
	context.refresh(build, new_slot_index)

func repopulate_context_neighbors():
	context.populate_neighbors()

func is_inside_build():
	assert(context)
	return context.build != null

func emit_context_updated():
	context_updated.emit()
#endregion Context functions

#region Pickup logic
func _process_ui_interaction(delta : float):
	if Global.perk_ui.active: 
		if not is_empty_perk():
			move_while_held(delta)
			update_drop_vars_while_held()
			_show_info_and_indicators_on_hover()
			if Input.is_action_just_pressed("attack"):
				# Try to pick up a modifier first
				var picked_up_mod := _try_pick_up_modifier()
				
				# Otherwise try clicking the perk
				if not picked_up_mod:
					_try_click_perk()
			if Input.is_action_just_released("attack") and mouse_holding:
				drop_perk()
#region Selection
func select():
	is_selected = true
	selected.emit()
	modulate = Color.WHITE * 1.3
	deselect_other_perks()

func deselect():
	is_selected = false
	modulate = Color.WHITE 

func deselect_other_perks():
	for perk : Perk in get_tree().get_nodes_in_group("perk"):
		if perk != self:
			perk.deselect()

#endregion Selection

#region Pickups
func _try_click_perk():
	if mouse_hovering:
		if pickupable and not anything_held:
			mouse_holding = true
			anything_held = true
			Loop.finish_animating_passive_builds()
			reset_pos_tween(false)
		if selectable:
			select()

func _try_pick_up_modifier() -> bool:
	var hovered_mod: PerkMod
	for dir: PerkMod.Direction in dir_to_mouse_hovering:
		if dir_to_mouse_hovering[dir]:
			hovered_mod = perk_mods[dir]
			break
	if hovered_mod:
		hovered_mod.pick_up()
		return true
	return false

func _show_info_and_indicators_on_hover():
	if mouse_hovering and hoverable and not mouse_holding:
		perk_card.show_card()
	#else:
		#perk_card.hide_card()
	if mouse_hovering and not Perk.anything_held:
		show_unavailable_modifier_directions()
	else:
		hide_unavailable_modifier_directions()
#endregion Pickups

func move_while_held(delta : float):
	if mouse_holding:
		if drop_build and drop_position != Vector2.ZERO:
			global_position = global_position.lerp(drop_build.global_position + drop_position * drop_build.global_scale, 25.0 * delta)
		else:
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
	anything_held = false
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
	if hovering_trash or Global.perk_ui.perk_trash.global_position.distance_to(global_position) < 37:
		reparent(Global.perk_ui.perk_trash)
		reset_physics_interpolation()
		root_pos = Vector2.ZERO
		if context.build:
			context.build.remove_perk(context.build.perks.find(self))
		delete()
	move_to_root_pos()
	if replaced_perk:
		replaced_perk.move_to_root_pos()

func move_to_root_pos(dur := 0.5, trans := Tween.TransitionType.TRANS_QUINT, _ease := Tween.EaseType.EASE_OUT):
	reset_pos_tween(true)
	pos_tween.tween_property(self, "position", root_pos, dur).set_trans(trans).set_ease(_ease)

	if get_parent() != Global.perk_ui.chest_opening_root:
		pos_tween.parallel().tween_property(self, "scale", Vector2.ONE, dur).set_trans(trans).set_ease(_ease)
	else:
		pos_tween.parallel().tween_property(self, "scale", Vector2.ONE * 2, dur).set_trans(trans).set_ease(_ease)

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
	# TODO don't do below on each frame
	var builds = Global.player.build_container.active_builds.duplicate() 
	builds.append_array(Global.player.build_container.passive_builds)
	for build : PerkBuild in builds:
		var dist = build.global_position.distance_to(get_global_mouse_position())
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
func _on_pickup_area_area_entered(area: Area2D) -> void:
	if area is PerkTrash:
		hovering_trash = true
		self_modulate = Color.WHITE * 0.9
func _on_pickup_area_area_exited(area: Area2D) -> void:
	if area is PerkTrash:
		hovering_trash = false
		self_modulate = Color.WHITE


#endregion Pickup logic

#region Loop animation logic
## Set the loop fx framerate such that the runtime of the perk will be completed 
## at the same time as the processing animation.
func _update_loop_process_frame_rate():
	var process_frame_count = loop.sprite_frames.get_frame_count("process")
	var dur = runtime.value()
	var frame_rate = 1.0 / dur * float(process_frame_count)
	loop.sprite_frames.set_animation_speed("process", frame_rate)

func _update_anim_speed_scale():
	loop.speed_scale = Loop.display_player_speed if not Global.perk_ui.active else 0.0



func _pick_border():
	if is_empty_perk():
		border.animation = "empty"
		return
	var border_rarity : String
	var active_or_passive : String
	
	match rarity:
		Rarity.COMMON, Rarity.RARE, Rarity.EPIC:
			border_rarity = "normal"
		Rarity.LEGENDARY:
			border_rarity = "legendary"
		_:
			assert(false)
	if is_trigger:
		active_or_passive = "trigger"
	elif is_active:
		active_or_passive = "active"
	else:
		active_or_passive = "passive"
		
	border.animation = border_rarity + "_" + active_or_passive

func _pick_background():
	if is_empty_perk():
		background.animation = "empty"
		return
	match rarity:
		Rarity.COMMON: 
			background.animation = "common"
		Rarity.RARE: 
			background.animation = "rare"
		Rarity.EPIC:
			background.animation = "epic"
		Rarity.LEGENDARY:
			background.animation = "legendary"
		_:
			assert(false)

func _pick_art():
	if perk_art.sprite_frames.has_animation(code_name):
		perk_art.animation = code_name
	else:
		printerr("PerkArt SpriteFrames doesn't have animation \"", code_name, "\"")
	# Set art color
	perk_art.set_rarity(rarity)

func get_loop_process_animation_speed():
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
		next_perk = context.build.idx_to_perk(0)
	else:
		next_perk = context.build.idx_to_perk(context.slot_index + 1)
	if next_perk:
		var frame_rate = next_perk.get_loop_process_animation_speed()
		loop.sprite_frames.set_animation_speed("end", frame_rate)
	else:
		var frame_rate = get_loop_process_animation_speed()
		loop.sprite_frames.set_animation_speed("end", frame_rate)
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

#region Activation visuals
func show_activation_visual():
	var art_dupe = perk_art.duplicate()
	add_child(art_dupe)
	var tween : Tween = create_tween().set_parallel()
	
	const END_POS = Vector2(7, -7)
	const DUR := 1.0
	const BRIGHTNESS := 1.25
	tween.tween_property(art_dupe, "position", END_POS, DUR)
	tween.tween_property(art_dupe, "modulate", Color(10, 10, 10, 1), DUR / 2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).from(Color(2, 2, 2, 0))
	tween.tween_property(art_dupe, "modulate", Color(20, 20, 20, 0), DUR / 2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(DUR / 2)
	tween.tween_property(background, "modulate", Color(BRIGHTNESS, BRIGHTNESS, BRIGHTNESS, 1), DUR / 5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(background, "modulate", Color.WHITE, DUR * 4 / 5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(DUR / 5)
	tween.tween_callback(art_dupe.queue_free).set_delay(DUR)
#endregion Activation visuals

#region Modifiers
## Calculates available directions for modifier placement on the given perk. 
func get_available_directions_out_of(mod_dirs: Array[PerkMod.Direction]) -> Array[PerkMod.Direction]:
	return available_mod_directions.filter(func(dir): return mod_dirs.has(dir))

## Calculates available directions for modifier placement on the given perk. 
func get_available_directions() -> Array[PerkMod.Direction]:
	return available_mod_directions

## Shows a perk's available modifier directions out of the given options.
func show_available_directions_out_of(mod_dirs: Array[PerkMod.Direction]):
	if can_hold_modifier(mod_dirs):
		for dir: PerkMod.Direction in get_available_directions_out_of(mod_dirs):
			dir_to_modifier_indicator[dir].show()

## Hides a perk's available modifier directions.
func hide_available_modifier_directions():
	for dir in available_mod_directions:
		dir_to_modifier_indicator[dir].hide()

## Shows a perk's unavailable modifier directions out of the given options.
func show_unavailable_modifier_directions():
	for dir in unavailable_mod_directions:
			dir_to_modifier_indicator[dir].show()

## Shows a perk's unavailable modifier directions out of the given options.
func hide_unavailable_modifier_directions():
	for dir in unavailable_mod_directions:
			dir_to_modifier_indicator[dir].hide()

## Returns whether this perk has availability for a modifier given its directions.
func can_hold_modifier(mod_dirs: Array[PerkMod.Direction]):
	if is_empty_perk(): 
		return false
	
	var available_dirs = get_available_directions_out_of(mod_dirs)
	return available_dirs.size() == mod_dirs.size()

## Adds a modifier to this perk. The modifier itself handles when it should activate its effects.
## The modifier should only be added if it's allowed to be added. Assert guards this.
func add_mod(mod: PerkMod):
	for dir in mod.target_directions:
		assert(perk_mods[dir] == null)
		perk_mods[dir] = mod
		assert(not unavailable_mod_directions.has(dir))
		unavailable_mod_directions.append(dir)
		assert(available_mod_directions.has(dir))
		available_mod_directions.erase(dir)

# TODO add "add/remove directions from existing owned mod" method if mod directions update

## Removes a modifier from this perk.
func remove_mod(mod: PerkMod):
	for dir in mod.target_directions:
		assert(perk_mods[dir] == mod)
		perk_mods[dir] = null
		assert(unavailable_mod_directions.has(dir))
		unavailable_mod_directions.erase(dir)
		assert(not available_mod_directions.has(dir))
		available_mod_directions.append(dir)



## Shows a modifier buff highlight.
func show_modifier_buff_highlight():
	modifier_buff_highlight.show()

## Hides a modifier buff highlight.
func hide_modifier_buff_highlight():
	modifier_buff_highlight.hide()

## Shows a modifier nerf highlight.
func show_modifier_nerf_highlight():
	modifier_nerf_highlight.show()

## Hides a modifier nerf highlight.
func hide_modifier_nerf_highlight():
	modifier_nerf_highlight.hide()

#endregion Modifiers


func _on_modifier_pickup_area_self_mouse_shape_entered(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.SELF] == false)
	dir_to_mouse_hovering[PerkMod.Direction.SELF] = true


func _on_modifier_pickup_area_left_mouse_shape_entered(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.LEFT] == false)
	dir_to_mouse_hovering[PerkMod.Direction.LEFT] = true


func _on_modifier_pickup_area_right_mouse_shape_entered(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.RIGHT] == false)
	dir_to_mouse_hovering[PerkMod.Direction.RIGHT] = true


func _on_modifier_pickup_area_up_mouse_shape_entered(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.UP] == false)
	dir_to_mouse_hovering[PerkMod.Direction.UP] = true


func _on_modifier_pickup_area_down_mouse_shape_entered(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.DOWN] == false)
	dir_to_mouse_hovering[PerkMod.Direction.DOWN] = true


func _on_modifier_pickup_area_self_mouse_shape_exited(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.SELF] == true)
	dir_to_mouse_hovering[PerkMod.Direction.SELF] = false


func _on_modifier_pickup_area_left_mouse_shape_exited(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.LEFT] == true)
	dir_to_mouse_hovering[PerkMod.Direction.LEFT] = false


func _on_modifier_pickup_area_right_mouse_shape_exited(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.RIGHT] == true)
	dir_to_mouse_hovering[PerkMod.Direction.RIGHT] = false


func _on_modifier_pickup_area_up_mouse_shape_exited(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.UP] == true)
	dir_to_mouse_hovering[PerkMod.Direction.UP] = false


func _on_modifier_pickup_area_down_mouse_shape_exited(_shape_idx: int) -> void:
	assert(dir_to_mouse_hovering[PerkMod.Direction.DOWN] == true)
	dir_to_mouse_hovering[PerkMod.Direction.DOWN] = false
