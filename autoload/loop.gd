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


#region Loop attributes
## The value of the global Loop before mods, indicating the speed at which it loops through perks.
## This value is increased over time as defined in `increase_loop_speed()`, 
var _base_speed := 1.00
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
var states : Dictionary[PerkBuild, LoopState]
#endregion Active perks

#region Passive perks
## The loop value left to activate passive perks with. 
var loop_value_left : float
## Set true when the player decides to skip the passive perk animation
var skip_animation : bool

#endregion Loop attributes

func _ready():
	global_speed.set_base(1.0)
	player_speed.set_base(1.0)
	enemy_speed.set_base(1.0)
	process_mode = Node.PROCESS_MODE_ALWAYS # FIXME
	await get_tree().create_timer(1.0).timeout
	start_running()

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
					activate_passive_perk(perk, perk.loop_cost.value())
			if loop_value_left == loop_value_before:
				# No perks are consuming any loop cost; end immediately to avoid infinite loop
				break

## Used by a perk to activate a passive perk an extra time during lock in.  
## Returns false if the perk failed to activate due to running out of loop cost. 
func activate_passive_perk(perk : Perk, loop_cost : float):
	if perk != null:
		var loop_value_after_perk = loop_value_left - perk.loop_cost.value()
		if loop_value_after_perk >= 0.0:
			loop_value_left = loop_value_after_perk
			perk.activate()
		else:
			loop_value_left = 0.0
			return false
	return true

func _calculate_loop_value_left():
	var loop_value = player_speed.value()
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
	if running:
		_increase_speed_mult(delta)
		_process_active_builds(delta)
		_update_speed_displays()

func _update_speed_displays():
	# Get speed values
	var global_speed_val = global_speed.value()
	var player_speed_val = player_speed.value()
	var enemy_speed_val = enemy_speed.value()
	
	# Update speed display values
	if global_speed_val >= display_global_speed + SPEED_DIFF_THRESHOLD:
		display_global_speed = snappedf(global_speed.value(), 0.01) 
		Global.perk_ui.set_global_loop_speed(display_global_speed)
	if player_speed_val >= display_player_speed + SPEED_DIFF_THRESHOLD:
		display_player_speed = snappedf(player_speed.value(), 0.01)
		Global.perk_ui.set_player_loop_speed(display_global_speed)
	if enemy_speed_val >= display_enemy_speed + SPEED_DIFF_THRESHOLD:
		display_enemy_speed = snappedf(enemy_speed.value(), 0.01)
		Global.perk_ui.set_enemy_loop_speed(display_global_speed)
	
	

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
	return INCREASE_RATE

func _process_active_builds(delta: float) -> void:
	if running:
		for state : LoopState in states.values():
			var perk : Perk = state.current_perk
			if perk != null:
				if perk.cooldown_timer > 0 and state.waiting_for_cooldown:
					#print("waiting for a cooldown: ", perk.cooldown_timer)
					pass # Arrived at a perk on cooldown, waiting for cooldown
				elif perk.cooldown_timer <= 0 and state.waiting_for_cooldown:
					perk.activate() # Perk finished cooldown; activate it
					perk.start_loop_process_anim()
					state.waiting_for_cooldown = false
				elif perk.runtime_timer > 0:
					pass # Just activated perk, waiting for its runtime 
				else:
					perk.end_loop_anim()
					goto_next_active_perk(state) # Perk's runtime is over; go to next perk
			else:
				# Empty perk slot; wait for 0.5 sec
				if state.empty_slot_timer > 0:
					state.empty_slot_timer -= delta
				else:
					state.empty_slot_timer = 0.0
					goto_next_active_perk(state)

func goto_next_active_perk(state : LoopState):
	state.current_active_index += 1
	state.current_active_index %= state.build.get_size()
	state.current_perk = state.build.perks[state.current_active_index]
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
		# Don't jump to a perk that's on cooldown (shouldn't be called if so)
		assert(triggered_perk.cooldown_timer > 0) 
		var state = states[build]
		state.current_perk.end_loop_anim()
		state.waiting_for_cooldown = false
		state.current_active_index = index
		state.current_perk = triggered_perk
		triggered_perk.activate()
		triggered_perk.start_loop_process_anim()
