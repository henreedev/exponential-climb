extends Effect

class_name TargetEffect

const DAMAGE_BUFF := 1.2

var targeted_enemy : Enemy
const UNTARGET_INTERVAL := 5.0
var detarget_timer := UNTARGET_INTERVAL

var target_reticle : PerkArtParticle 

func _start_effect():
	context.player.weapon.attack_initiated.connect(buff_attack)
	context.player.weapon.attack_hit.connect(target_enemy)

func buff_attack(attack : Weapon.Attack):
	if targeted_enemy:
		# If the attack's direction is towards the targeted enemy, give it more damage and range
		var enemy_dir = Global.player.global_position.angle_to_point(targeted_enemy.global_position)
		var attack_dir = attack.dir
		if abs(enemy_dir - attack.dir) < PI / 3: 
			attack.range.append_mult_mod(value)
			attack.damage.append_mult_mod(DAMAGE_BUFF)

func _process_effect(delta : float):
	if targeted_enemy:
		if detarget_timer > 0.0:
			detarget_timer -= delta
		else:
			untarget_enemy()

func do_end_effect():
	context.player.weapon.attack_initiated.disconnect(buff_attack)

#region Targeting
func target_enemy(attack : Weapon.Attack, damage_dealt : int, enemy : Enemy):
	# If no target or enemy has more hp than target, retarget
	if not targeted_enemy or enemy.hc.health > targeted_enemy.hc.health:
		untarget_enemy()
		targeted_enemy = enemy
		target_reticle = PerkArtParticle.create(Perk.Type.TARGET, targeted_enemy, UNTARGET_INTERVAL, Vector2(0, 0), 0)
		detarget_timer = UNTARGET_INTERVAL

func untarget_enemy():
	if targeted_enemy:
		if target_reticle:
			target_reticle.kill_early()

#endregion Targeting
