extends Node

## Loop
## Performs the cycling through active perks. Activates passive perks at Lock In.

## There are three versions of the Loop speed: 
## Global - the main value, 
## Player - based on global, used by the player
## Enemy - based on global, used to spawn and level enemies.
## Global increases over time based on difficulty, floor depth, and loop-related perks.
## Player and enemy speeds take the value of global and use it as a base. 
##   They can then have modifiers on top of that. 

## Emitted when the lock in passive build animation finishes. 
## Does not emit for a simulated animation.
signal lock_in_animation_finished

#region Loop attributes
## The value of the global Loop before mods, indicating the speed at which it loops through perks.
## This value is increased over time as defined in `increase_loop_speed()`, 
var _base_speed := 1.00
## The multiplier on the global Loop's increase rate.
@onready var global_increase : Stat = Stat.new()
## The value of the global Loop after modifiers from perks and bonuses.
@onready var global_speed : Stat = Stat.new()
## Player loop speed, which can have separate modifiers.
@onready var player_speed : Stat = Stat.new()
## Enemy loop speed, which can have separate modifiers.
@onready var enemy_speed : Stat = Stat.new()
## The loop speed value shown to the player, with two decimal places.
var display_global_speed := 1.00 
## The loop speed value shown to the player, with two decimal places.
var display_player_speed := 1.00 
## The loop speed value shown to the player, with two decimal places.
var display_enemy_speed := 1.00 
## The value that the internal speed multiplier must increase by to change on screen.
const SPEED_DIFF_THRESHOLD := 0.01

#region Active perks
## Activated during gameplay whenever the loop is processing active perks and incrementing speed.
var running := false
const EMPTY_SLOT_DURATION := 0.05

## Information on each active build the loop is processing.
var active_states : Dictionary[PerkBuild, LoopState]
#endregion Active perks

#region Passive perks
## The loop value left to activate passive perks with. 
var loop_value_left : float
## Set true when the player decides to skip the passive perk animation
var skip_animation : bool

## True when animating the activation of passive builds. 
## This is true when doing the final, actual activation of passive perks after locking in.
var animating_passive_builds := false

## Information on each passive build the loop is processing.
var passive_states : Dictionary[PerkBuild, LoopState]

## Base speed multiplier on the passive perk activation animation.
const BASE_ANIMATION_SPEED := 0.2

## Speed multiplier on the passive perk activation animation.
var animation_speed := BASE_ANIMATION_SPEED

## True when the current animation of passive builds is only a visual simulation; 
##  no perks apply their effects.
var simulating := false
#endregion Loop attributes

func _ready():
	global_increase.set_base(1.0)
	global_speed.set_base(1.0)
	player_speed.set_base(1.0)
	enemy_speed.set_base(1.0)
	await get_tree().create_timer(1.0).timeout
	start_running()

#func _input(event: InputEvent) -> void:
	#if event.is_action_pressed("toggle_loop"):
		#if running: 
			#stop_running()
		#else:
			#start_running()

func _process(delta: float) -> void:
	if running:
		_increase_speed_mult(delta)
		_process_active_builds(delta)
		_update_speed_displays()
	elif animating_passive_builds:
		_process_passive_builds(delta)
		if animation_speed != BASE_ANIMATION_SPEED:
			_update_animation_speeds()

#region Lock in / passive perks
func activate_passive_perks():
		# Set loop value
		loop_value_left = _calculate_loop_value_left()
		var loop_value_before = loop_value_left
		while loop_value_left > 0:
			for passive_build in Global.player.build_container.passive_builds:
				for perk : Perk in Global.player.passive_perk_build.perks:
					activate_passive_perk(perk, perk.loop_cost.value())
			if loop_value_left == loop_value_before:
				# No perks are consuming any loop cost; end immediately to avoid infinite loop
				break

## Used by a perk to activate a passive perk an extra time during lock in.  
## Returns false if the perk failed to activate due to running out of loop cost. 
func activate_passive_perk(perk : Perk, loop_cost : float):
	if perk != null:
		var loop_value_after_perk = loop_value_left - loop_cost
		if loop_value_after_perk >= 0.0:
			loop_value_left = loop_value_after_perk
			if not simulating:
				perk.activate()
		else:
			loop_value_left = 0.0
			return false
	return true

func animate_passive_builds(_simulating := false):
	process_mode = Node.PROCESS_MODE_ALWAYS
	for perk : Perk in get_tree().get_nodes_in_group("perk"):
		perk.set_loop_anim("none")
	loop_value_left = _calculate_loop_value_left()
	animating_passive_builds = true
	animation_speed = BASE_ANIMATION_SPEED
	simulating = _simulating
	_setup_passive_loop_states()
	# _process_passive_builds() will take it from here

func _process_passive_builds(delta : float):
	# TODO skip_animation
	var states_done := 0
	# Collect the remaining loop values and pass to the UI to fill in labels
	var loop_values_left : Array[float] = []
	for state : LoopState in passive_states.values():
		var perk : Perk = state.current_perk
		var loop_cost = perk.loop_cost.value()
		loop_values_left.append(state.loop_value_left)
		# Check if done
		if state.done:
			states_done += 1
			continue
		# Check if switching to next perk (reached next loop value, or 
		#  reached 0.0 when next_loop_value is negative)
		if state.loop_value_left == state.next_loop_value:
			if not simulating and not state.loop_value_left == _calculate_loop_value_left():
				perk.activate()
			#perk.end_loop_anim() # TODO add end animation maybe
			perk.set_loop_anim("none")
			# Set current_perk to next perk
			if not state.loop_value_left == _calculate_loop_value_left():
				goto_next_passive_perk(state)
			perk = state.current_perk
			loop_cost = perk.loop_cost.value()
			# Begin animating next perk (show first frame)
			perk.animate_loop_process(0.0)
			# Subtract perk loop cost from next_loop_value, clamped to >=0.0
			state.next_loop_value -= loop_cost
			if state.next_loop_value < 0.0:
				# Can't activate next perk; not enough loop value left
				# Tween to the ending spot
				var diff = state.loop_value_left
				if state.loop_value_tween:
					state.loop_value_tween.custom_step(1000)
					state.loop_value_tween.kill()
				# Create tween for the next section of loop value movement
				state.loop_value_tween = create_tween()
				state.loop_value_tween.set_speed_scale(animation_speed)
				
				# Extra duration when loop fails to activate a perk
				const FAIL_DUR := 0.1
				
				# Move loop value to next_loop_value over time
				state.loop_value_tween.tween_property(state, "loop_value_left", 0.0, diff + FAIL_DUR)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				# Animate loop animation on perk over time
				state.loop_value_tween.parallel().tween_method(perk.animate_loop_process, 0.0, state.loop_value_left / loop_cost, diff + FAIL_DUR)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				# Set done once animation finishes
				state.loop_value_tween.tween_property(state, "done", true, 0.0)
			elif state.next_loop_value == 0.0:
				# Tween to 0.0
				var diff = state.loop_value_left
				if state.loop_value_tween:
					state.loop_value_tween.custom_step(1000)
					state.loop_value_tween.kill()
				state.loop_value_tween = create_tween()
				state.loop_value_tween.set_speed_scale(animation_speed)
				# Move loop value to next_loop_value over time
				state.loop_value_tween.tween_property(state, "loop_value_left", 0.0, diff)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				# Animate loop animation on perk over time
				state.loop_value_tween.parallel().tween_method(perk.animate_loop_process, 0.0, 1.0, diff)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				# Set done once animation finishes
				state.loop_value_tween.tween_property(state, "done", true, 0.0)
			else:
				var diff = state.loop_value_left - state.next_loop_value
				if state.loop_value_tween:
					state.loop_value_tween.custom_step(1000)
					state.loop_value_tween.kill()
				state.loop_value_tween = create_tween()
				state.loop_value_tween.set_speed_scale(animation_speed)
				# Move loop value to next_loop_value over time
				state.loop_value_tween.tween_property(state, "loop_value_left", state.next_loop_value, diff)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				# Animate loop animation on perk over time
				state.loop_value_tween.parallel().tween_method(perk.animate_loop_process, 0.0, 1.0, diff)\
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Global.perk_ui.set_passive_animation_labels(loop_values_left)
	# If all done, quit
	if states_done == passive_states.values().size():
		finish_animating_passive_builds()

func finish_animating_passive_builds():
	if animating_passive_builds:
		for state : LoopState in passive_states.values():
			if state.loop_value_tween:
				state.loop_value_tween.kill()
		passive_states.clear()
		Global.perk_ui.reset_passive_animation_labels()
		animating_passive_builds = false
		animation_speed = BASE_ANIMATION_SPEED
		var was_simulating = simulating
		simulating = false
		
		process_mode = Node.PROCESS_MODE_INHERIT
		
		if not was_simulating:
			lock_in_animation_finished.emit()


func _update_animation_speeds():
	for state : LoopState in passive_states.values():
		if state.loop_value_tween:
			state.loop_value_tween.set_speed_scale(animation_speed)

func increase_animation_speed():
	const SPEED_MULT = 2.0
	animation_speed *= SPEED_MULT


func goto_next_passive_perk(state : LoopState):
	state.current_index += 1
	state.current_index %= state.build.get_size()
	state.current_perk = state.build.perks[state.current_index]

func _setup_passive_loop_states():
	passive_states.clear()
	var loop_value = _calculate_loop_value_left()
	for passive_build in Global.player.build_container.passive_builds:
		var state = LoopState.new()
		state.current_perk = passive_build.perks[0]
		state.build = passive_build
		state.loop_value_left = loop_value
		state.next_loop_value = loop_value
		passive_states[passive_build] = state
		for perk in passive_build.perks:
			perk.set_loop_anim("none")



#endregion Lock in / passive perks

func _calculate_loop_value_left():
	var loop_value = display_player_speed
	return loop_value


func _toggle_active_trigger_perks(on : bool):
	for build : PerkBuild in Global.player.build_container.active_builds:
		for perk : Perk in build.perks:
			if perk != null and perk.is_trigger:
				if on: 
					perk.enable_trigger()
				else:
					perk.disable_trigger()

## Active perks will be triggered in a cycle.
func start_running():
	if not Global.player:
		printerr("Loop could not find Global.player!")
		return
	
	if not running:
		running = true
		print("Loop is now running")
		_toggle_active_trigger_perks(true)
		_setup_loop_states()

## Stops the cycle.
func stop_running():
	if running: 
		print("Loop is now NOT running")
		running = false
		_toggle_active_trigger_perks(false)
		_teardown_loop_states()
		remove_all_effects()

func _setup_loop_states():
	for active_build in Global.player.build_container.active_builds:
		var state = LoopState.new()
		state.current_perk = active_build.perks[state.current_index]
		state.build = active_build
		active_states[active_build] = state
		if state.current_perk != null:
			state.current_perk.activate()

func _teardown_loop_states():
	active_states.clear()

## To be called when completing a room.
func remove_all_effects():
	Global.player.build_container.deactivate_all()

func _update_speed_displays():
	# Get speed values
	var global_speed_val = global_speed.value()
	var player_speed_val = player_speed.value()
	var enemy_speed_val = enemy_speed.value()
	
	# Update speed display values
	if snappedf(global_speed_val, 0.01) != display_global_speed:
		display_global_speed = snappedf(global_speed.value(), 0.01) 
		Global.perk_ui.set_global_loop_speed(display_global_speed)
	if snappedf(player_speed_val, 0.01) != display_player_speed:
		display_player_speed = snappedf(player_speed.value(), 0.01)
		Global.perk_ui.set_player_loop_speed(display_player_speed)
	if snappedf(enemy_speed_val, 0.01) != display_enemy_speed:
		display_enemy_speed = snappedf(enemy_speed.value(), 0.01)
		Global.perk_ui.set_enemy_loop_speed(display_enemy_speed)
	
	

func _increase_speed_mult(delta : float) -> void:
	# Increase the base speed
	_base_speed += delta * get_increase_rate()
	
	# Set the global speed's base to the base speed
	global_speed.set_base(_base_speed)
	var global_speed_val = global_speed.value()
	
	# Set the player and enemy speeds' bases to the *global* speed
	enemy_speed.set_base(global_speed_val)
	player_speed.set_base(global_speed_val)


## Calculates the increase per second of the global loop speed. 
## Rate is based on floor depth, difficulty chosen, and relevant perks.
## TODO
func get_increase_rate():
	const INCREASE_RATE = 0.003
	return INCREASE_RATE * global_increase.value()

func _process_active_builds(delta: float) -> void:
	if running:
		for state : LoopState in active_states.values():
			var perk : Perk = state.current_perk
			if perk != null:
				if perk.cooldown_timer > 0 and state.waiting_for_cooldown:
					pass # Waiting for cooldown
				elif perk.cooldown_timer <= 0 and state.waiting_for_cooldown:
					# Perk finished cooldown; activate
					perk.activate() 
					perk.start_loop_process_anim()
					state.waiting_for_cooldown = false
				elif perk.runtime_timer > 0:
					pass # Waiting for runtime 
				else:
					# Perk's runtime is over; go to next perk
					perk.end_loop_anim()
					goto_next_active_perk(state) 
			else:
				# Empty perk slot; wait for 0.5 sec
				if state.empty_slot_timer > 0:
					state.empty_slot_timer -= delta
				else:
					state.empty_slot_timer = 0.0
					goto_next_active_perk(state)

func goto_next_active_perk(state : LoopState):
	state.current_index += 1
	state.current_index %= state.build.get_size()
	state.current_perk = state.build.perks[state.current_index]
	if state.current_perk != null and state.current_perk.is_trigger:
		state.current_perk = null # Treat a trigger perk like an empty perk slot, ignoring it
		state.empty_slot_timer = EMPTY_SLOT_DURATION
	elif state.current_perk != null and state.current_perk.cooldown_timer > 0:
		state.waiting_for_cooldown = true
		state.current_perk.start_loop_cooldown_anim()
	else:
		state.current_perk.activate()
		state.current_perk.start_loop_process_anim()

## Called by triggers to interrupt the loop and move execution to the trigger perk.
func jump_to_index(build : PerkBuild, index : int):
	if running:
		var triggered_perk = build.perks[index]
		assert(triggered_perk.cooldown_timer <= 0, "Don't jump to a perk that's on cooldown (shouldn't be called if so)") 
		var state = active_states[build]
		if state.current_perk:
			state.current_perk.end_loop_anim()
		state.waiting_for_cooldown = false
		state.current_index = index
		state.current_perk = triggered_perk
		triggered_perk.activate()
		triggered_perk.start_loop_process_anim()
