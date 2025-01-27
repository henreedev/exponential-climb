extends Effect

class_name FeatherEffect

const FEATHER_PARTICLES = preload("res://scenes/perks/effects/feather/feather_particles.tscn")

func _start_effect():
	context.player.weapon.attack_initiated.connect(buff_attack)
	context.player.double_jumped.connect(spawn_feathers)
	var double_jump_mod = Global.player.double_jumps.append_add_mod(1)
	attached_mods[double_jump_mod] = Global.player.double_jumps

func buff_attack(attack : Weapon.Attack):
	if not Global.player.is_on_floor():
		attack.attack_speed.append_mult_mod(value)

func do_end_effect():
	context.player.weapon.attack_initiated.disconnect(buff_attack)
	context.player.double_jumped.disconnect(spawn_feathers)

func spawn_feathers():
	if Global.player.double_jumps_left > 0:
		var feather_particles = FEATHER_PARTICLES.instantiate()
		Global.game.add_child(feather_particles)
		feather_particles.global_position = Global.player.global_position + Vector2(0, 14)
		feather_particles.reset_physics_interpolation()
