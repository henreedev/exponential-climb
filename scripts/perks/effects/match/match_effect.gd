extends Effect

class_name MatchEffect

const IGNITE = preload("res://scenes/perks/effects/match/ignite.tscn")

func _start_effect():
	context.player.weapon.attack_hit.connect(attach_ignite)

func do_end_effect():
	context.player.weapon.attack_hit.disconnect(attach_ignite)

func attach_ignite(attack : Weapon.Attack, damage_dealt : int, enemy : Enemy):
	var ignite = IGNITE.instantiate()
	ignite.parent_enemy = enemy
	ignite.total_damage = damage_dealt * value
	ignite.duration = value * 10
	Global.game.add_child(ignite)
	# Ignite will handle its positioning
