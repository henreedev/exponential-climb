extends Node
## Performs the cycling through active perks. Activates passive perks at Lock In.

@onready var effects_node: Node = $Effects

var running := false
var current_perk : Perk
var current_active_index := 0

const EMPTY_SLOT_DURATION := 0.5
var empty_slot_timer := 0.0
## True when moving to an active perk that's on cooldown. 
var waiting_for_cooldown := false

func _ready():
	#await get_tree().create_timer(1.5).timeout
	#activate_passive_perks()
	#start_running()
	pass

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_loop"):
		if running: 
			stop_running()
		else:
			start_running()

func activate_passive_perks():
	for player : Player in Global.players:
		for perk : Perk in player.passive_perk_build.perks:
			if perk != null:
				perk.activate()

func _toggle_active_trigger_perks(on : bool):
	for player : Player in Global.players:
		for perk : Perk in player.active_perk_build.perks:
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
		current_perk = Global.players[0].active_perk_build.perks[current_active_index] # FIXME
		if current_perk != null:
			current_perk.activate()

## Stops the cycle.
func stop_running():
	if running: 
		print("not running")
		running = false
		_toggle_active_trigger_perks(false)
		remove_all_effects()
		current_active_index = 0
		empty_slot_timer = 0.0
		waiting_for_cooldown = false

## To be called when completing a room.
func remove_all_effects():
	for player : Player in Global.players:
		player.active_perk_build.deactivate()
		player.passive_perk_build.deactivate()

func _process(delta: float) -> void:
	_process_active_builds(delta)

func _process_active_builds(delta: float) -> void:
	if running:
		if current_perk != null:
			if current_perk.cooldown_timer > 0 and waiting_for_cooldown:
				print("waiting for a cooldown: ", current_perk.cooldown_timer)
				pass # Arrived at a perk on cooldown, waiting for cooldown
			elif current_perk.cooldown_timer <= 0 and waiting_for_cooldown:
				current_perk.activate() # Perk finished cooldown; activate it
				waiting_for_cooldown = false
			elif current_perk.duration_timer > 0:
				pass # Just activated perk, waiting for its duration 
			else:
				goto_next_active_perk() # Perk's duration is over; go to next perk
		else:
			# Empty perk slot; wait for 0.5 sec
			if empty_slot_timer > 0:
				empty_slot_timer -= delta
			else:
				empty_slot_timer = 0.0
				goto_next_active_perk()

func goto_next_active_perk():
	current_active_index += 1
	current_active_index %= Global.max_perks
	current_perk = Global.players[0].active_perk_build.perks[current_active_index] # FIXME use other players
	if current_perk != null and current_perk.is_trigger:
		current_perk = null # Treat a trigger perk like an empty perk slot, ignoring it
		empty_slot_timer = EMPTY_SLOT_DURATION
	elif current_perk != null and current_perk.cooldown_timer > 0:
		waiting_for_cooldown = true
	else:
		current_perk.activate()
		

## Called by triggers to interrupt the loop and move execution to the trigger perk.
func jump_to_index(index : int):
	if running:
		var triggered_perk = Global.players[0].active_perk_build.perks[index]
		if triggered_perk.cooldown_timer > 0: 
			return # Don't jump to a perk that's on cooldown (shouldn't be called if so)
		waiting_for_cooldown = false
		current_active_index = index
		current_perk = triggered_perk
		triggered_perk.activate()
