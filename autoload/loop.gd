extends Node
## Performs the cycling through active perks. Activates passive perks at Lock In.

#region Loop attributes
## The value of the Loop before mods, indicating the speed at which it loops through perks.
var _base_speed_multiplier := 1.00
## The value of the Loop after modifiers from perks and bonuses.
@onready var speed_multiplier : Stat = Stat.new()
## The loop speed value shown to the player, with two decimal places.
var display_speed_multiplier := 1.00
## The value that the internal speed multiplier must increase by to change on screen.
var SPEED_DIFF_THRESHOLD := 0.01

#region Active perks
## Activated during gameplay whenever the loop is processing active perks and incrementing speed.
var running := false
const EMPTY_SLOT_DURATION := 0.05

## Information on each active build the loop is processing.
var states : Dictionary[PerkBuild, LoopState]
#endregion Active perks

#region Passive perks
## The loop value left to activate passive perks with. 
var loop_value_left : float
## Set true when the player decides to skip the passive perk animation
var skip_animation : bool

#endregion Loop attributes


func _ready():
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_loop"):
		if running: 
			stop_running()
		else:
			start_running()

func activate_passive_perks():
		# Set loop value
		loop_value_left = _calculate_loop_value_left()
		var loop_value_before = loop_value_left
		while loop_value_left > 0:
			for passive_build in Global.player.build_container.passive_builds:
				for perk : Perk in Global.player.passive_perk_build.perks:
					activate_passive_perk(perk, perk.loop_cost.get_final_value())
			if loop_value_left == loop_value_before:
				# No perks are consuming any loop cost; end immediately to avoid infinite loop
				break

## Used by a perk to activate a passive perk an extra time during lock in.  
## Returns false if the perk failed to activate due to running out of loop cost. 
func activate_passive_perk(perk : Perk, loop_cost : float):
	if perk != null:
		var loop_value_after_perk = loop_value_left - perk.loop_cost.get_final_value()
		if loop_value_after_perk >= 0.0:
			loop_value_left = loop_value_after_perk
			perk.activate()
		else:
			loop_value_left = 0.0
			return false
	return true

func _calculate_loop_value_left():
	var loop_value = speed_multiplier.get_final_value()
	# TODO check if player has full builds, add bonuses
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
	if not running:
		running = true
		print("running")
		_toggle_active_trigger_perks(true)
		_setup_loop_states()

## Stops the cycle.
func stop_running():
	if running: 
		print("not running")
		running = false
		_toggle_active_trigger_perks(false)
		_teardown_loop_states()
		remove_all_effects()

func _setup_loop_states():
	for active_build in Global.player.build_container.active_builds:
		var state = LoopState.new()
		state.current_perk = active_build.perks[state.current_active_index]
		state.build = active_build
		states[active_build] = state
		if state.current_perk != null:
			state.current_perk.activate()

func _teardown_loop_states():
	states.clear()


## To be called when completing a room.
func remove_all_effects():
	Global.player.build_container.deactivate_all()


func _process(delta: float) -> void:
	_increase_speed_mult(delta)
	_process_active_builds(delta)

func _increase_speed_mult(delta : float) -> void:
	_base_speed_multiplier += delta * 0.1
	speed_multiplier.set_base(_base_speed_multiplier)
	if speed_multiplier.get_final_value() >= display_speed_multiplier + SPEED_DIFF_THRESHOLD:
		display_speed_multiplier = roundf(speed_multiplier.get_final_value() * 100) / 100.0 

func _process_active_builds(delta: float) -> void:
	if running:
		for state : LoopState in states.values():
			if state.current_perk != null:
				if state.current_perk.cooldown_timer > 0 and state.waiting_for_cooldown:
					print("waiting for a cooldown: ", state.current_perk.cooldown_timer)
					pass # Arrived at a perk on cooldown, waiting for cooldown
				elif state.current_perk.cooldown_timer <= 0 and state.waiting_for_cooldown:
					state.current_perk.activate() # Perk finished cooldown; activate it
					state.waiting_for_cooldown = false
				elif state.current_perk.duration_timer > 0:
					pass # Just activated perk, waiting for its duration 
				else:
					goto_next_active_perk(state) # Perk's duration is over; go to next perk
			else:
				# Empty perk slot; wait for 0.5 sec
				if state.empty_slot_timer > 0:
					state.empty_slot_timer -= delta
				else:
					state.empty_slot_timer = 0.0
					goto_next_active_perk(state)

func goto_next_active_perk(state : LoopState):
	state.current_active_index += 1
	state.current_active_index %= Global.max_perks
	state.current_perk = state.build.perks[state.current_active_index]
	if state.current_perk != null and state.current_perk.is_trigger:
		state.current_perk = null # Treat a trigger perk like an empty perk slot, ignoring it
		state.empty_slot_timer = EMPTY_SLOT_DURATION
	elif state.current_perk != null and state.current_perk.cooldown_timer > 0:
		state.waiting_for_cooldown = true
	else:
		state.current_perk.activate()
		

## Called by triggers to interrupt the loop and move execution to the trigger perk.
func jump_to_index(build : PerkBuild, index : int):
	if running:
		var triggered_perk = build.perks[index]
		if triggered_perk.cooldown_timer > 0: 
			return # Don't jump to a perk that's on cooldown (shouldn't be called if so)
		var state = states[build]
		state.waiting_for_cooldown = false
		state.current_active_index = index
		state.current_perk = triggered_perk
		triggered_perk.activate()
