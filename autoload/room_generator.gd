extends Node

## Manages generating rooms, including each step of the 
## procedural generation process.
## 
## Generates rooms by creating a new thread and emitting a 
## signal when that thread is done with its room.
# RoomGenerator - Autoload

## Emitted when a new room has been generated. Only one room should be generated
## at a time, to avoid ambiguity in which room is returned by this signal.
signal room_generated(new_room: Room)

## Emitted when the thread finishes generating a room. 
signal _thread_done_generating_room
## Room object to pass to a thread to generate. 
## Same room object is eventually returned in the room_generated signal
## once the thread finishes.
var room_to_generate: Room

## True when a new room should not be requested to be generated, because a thread is still working.
var generating_room := false
#region Threading stuff
var semaphore: Semaphore
var thread: Thread
var exit_thread := false
var direct
#endregion Threading stuff

## TODO This method can return the instantiated room's loading status object
## for a loading screen to read. 
## Starts a background thread that generates a new room.
## Caller should be prepared to receive the room_generated signal. 
func generate_new_room_in_bg() -> void:
	# Confirm only one room generating at a time
	#assert(room_to_generate == null)
	assert(not generating_room)
	
	generating_room = true
	room_to_generate = Room.new()# generate_room(Vector2i.ZERO, 1) # FIXME seed hardcode
	#_thread_done_generating_room.emit()
	tell_thread_generate_room() # FIXME do it on the thread?

func _ready():
	semaphore = Semaphore.new()
	exit_thread = false

	# Start up a thread that waits to be told to generate a room
	thread = Thread.new()
	thread.start(_thread_generate_room_semaphore)
	
	# Listen for thread finishing a room
	_thread_done_generating_room.connect(
		_on_thread_done_generating_room
	)
	
	# Start processing, so the thread has a source to await frames from
	set_process(true)
	set_physics_process(true)

func is_generating_room() -> bool:
	return generating_room

#func _thread_generate_room(room: Room):
	# FIXME call the room generation steps on room instead of calling Room's static generator
	# FIXME 2 don't hardcode seed



## NOTE: if this code breaks, it's because I removed the mutex usage.
func _thread_generate_room_semaphore():
	while true:
		semaphore.wait() # Wait until posted.

		# Break if exiting tree.
		var should_exit = exit_thread 
		if should_exit:
			break
		
		# Generate a room.
		assert(room_generated != null)
		assert(generating_room)
	
		room_to_generate = await Room.generate_room(Vector2i.ZERO, 1) 
		#Pathfinding.update_graph(room_to_generate.wall_layer)
		_thread_done_generating_room.emit.call_deferred()

func tell_thread_generate_room():
	semaphore.post() # Make the thread process.

## Returns false when no room is being generated.
#func is_room_gen_completed() -> bool:
	#return room_to_generate.is_fully_generated() if room_generated else false

# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
	# Set exit condition to true.
	exit_thread = true 

	# Unblock by posting.
	semaphore.post()

	# Wait until it exits.
	thread.wait_to_finish()

	print("RoomGenerator thread exited tree!") 

func _on_thread_done_generating_room():
	generating_room = false
	room_generated.emit(room_to_generate)
	room_to_generate = null
