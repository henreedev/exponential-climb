extends Node

## EnemySpawner class. Handles the spawning of enemies, including their positions, strength scaling based on loop speed, etc.

const ENEMY_SCENE = preload("res://scenes/enemy/enemy.tscn")


#region Spawning
func spawn_enemy(enemy_class : Enemy.Class, pos : Vector2):
	var new_enemy = ENEMY_SCENE.instantiate()
	new_enemy._class = enemy_class
	new_enemy.position = pos
	add_child(new_enemy)

#endregion Spawning
