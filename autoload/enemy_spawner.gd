extends Node

## EnemySpawner
## Handles the spawning of enemies in waves and enemy strength scaling.

const ENEMY_SCENE = preload("res://scenes/enemy/enemy.tscn")
const ENEMY_COSTS : Dictionary[Enemy.Class, float] = {
	Enemy.Class.BASIC_MELEE : 0.25
}

var enemy_level := 1
var loop_speed_of_next_level := 1.05
var loop_speed_of_last_level := 1.00
var enemy_health_mult := 1.0
var enemy_base_damage_mult := 1.0


const WAVE_INTERVAL := 10.0
var wave_timer := 5.0

func _process(delta):
	if not Global.player:
		return
	if not Pathfinding.PATHFINDING_ENABLED:
		return
	_spawn_wave_on_timer(delta)
	_process_level_ups(delta)

#region Wave spawning
func _spawn_wave_on_timer(delta):
	assert(wave_timer != INF)
	if wave_timer > 0:
		wave_timer -= delta
	else:
		var enemy_speed_value = Loop.enemy_speed.value()
		wave_timer = WAVE_INTERVAL / enemy_speed_value
		spawn_wave(enemy_speed_value)

func spawn_wave(enemy_speed_value : float):
	var wave: Array[Enemy.Class] = _choose_wave_to_spawn(enemy_speed_value)
	for _class in wave:
		var spawn_pos = pick_spawn_position(_class)
		spawn_enemy(_class, spawn_pos)

## TODO Given the resource of loop speed, allocates it across enemy classes to create a wave.
func _choose_wave_to_spawn(loop_speed : float) -> Array[Enemy.Class]:
	var wave: Array[Enemy.Class] = []
	var keep_going = true
	while keep_going:
		var enemy_class = Enemy.Class.BASIC_MELEE # TODO pick a variety, within remaining budget
		var cost = ENEMY_COSTS[enemy_class]
		if loop_speed - cost >= 0:
			wave.append(enemy_class)
		loop_speed -= cost
		keep_going = loop_speed > 0
	return wave

func spawn_enemy(enemy_class : Enemy.Class, pos : Vector2):
	var new_enemy = ENEMY_SCENE.instantiate()
	new_enemy._class = enemy_class
	new_enemy.position = pos
	Global.game.add_child(new_enemy)

func pick_spawn_position(enemy_class : Enemy.Class):
	const MAX_SPAWN_DIST = 350.0
	const MIN_SPAWN_DIST = 50.0
	var spawn_pos := Global.player.global_position
	var start_angle := randf_range(-PI, PI)
	
	var i = 0
	var keep_going = true
	while keep_going:
		i += 1
		if i > 10000:
			keep_going = false
		# Pick a random tile in a ring around the player and see if it's valid (not a wall) 
		start_angle = start_angle + PI / 16
		spawn_pos = Vector2(randf_range(MIN_SPAWN_DIST, MAX_SPAWN_DIST), 0).rotated(start_angle)
		spawn_pos.y *= 0.5 # Don't spawn as far below the player as horizontal
		spawn_pos += Global.player.global_position
		
		if not is_valid_spawn_pos(spawn_pos):
			if keep_going: 
				continue
			else:
				break
		# Raycast down from that position. 
		# If raycast doesn't hit soon enough, enemy would spawn off-screen; find a new pos 
		const RAYCAST_DIST = 700.0
		var raycasted_pos = Pathfinding.do_raycast(spawn_pos, spawn_pos + Vector2.DOWN * RAYCAST_DIST)
		if raycasted_pos != Vector2.INF:
			# Valid spawn position. Move it up by half of enemy's height so they're not stuck
			raycasted_pos += Vector2.UP * 16
			# Terminate loop
			spawn_pos = raycasted_pos
			keep_going = false
	return spawn_pos

func is_valid_spawn_pos(spawn_pos : Vector2):
	return not spawn_pos == Vector2.INF and \
		not Pathfinding.is_wall(
			Pathfinding.tile_map_layer.local_to_map(spawn_pos),
			true # Don't spawn enemies inside of the "inside wall tiles"
		)

#endregion Spawning

#region Level-up and XP methods
## Can level down when supplying -1.
func level_up(direction := 1):
	enemy_level += direction
	print("Enemies levelled up to ", enemy_level)
	enemy_base_damage_mult = calculate_enemy_base_damage_mult(enemy_level)
	enemy_health_mult = calculate_enemy_health_mult(enemy_level)
	loop_speed_of_next_level = calculate_next_level_loop_speed(enemy_level)
	loop_speed_of_last_level = calculate_next_level_loop_speed(enemy_level - 1)

func _process_level_ups(delta : float):
	if Loop.display_enemy_speed >= loop_speed_of_next_level:
		level_up()
	if Loop.display_enemy_speed < loop_speed_of_last_level:
		level_up(-1)

func calculate_next_level_loop_speed(level : int):
	return pow(1.05, level)

func calculate_enemy_health_mult(level : int):
	return pow(1.05, level - 1)

func calculate_enemy_base_damage_mult(level : int):
	return pow(1.025, level - 1)

#endregion Level-up and XP methods
