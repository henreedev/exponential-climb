extends Effect

class_name TargetEffect

const DAMAGE_BUFF := 1.2

var targeted_hitbox: Hitbox
const UNTARGET_INTERVAL := 5.0
var detarget_timer := UNTARGET_INTERVAL

var target_reticle : PerkArtParticle 

func _start_effect():
	context.player.weapon.attack_initiated.connect(buff_attack)
	context.player.weapon.attack_hit.connect(target_hitbox)

func buff_attack(attack : Weapon.Attack):
	if targeted_hitbox:
		# If the attack's direction is towards the targeted hitbox, give it more damage and range
		var hitbox_dir = Global.player.global_position.angle_to_point(targeted_hitbox.global_position)
		if abs(hitbox_dir - attack.dir) < PI / 3: 
			attack.range.append_mult_mod(value)
			attack.damage.append_mult_mod(DAMAGE_BUFF)

func _process_effect(delta : float):
	if targeted_hitbox:
		if detarget_timer > 0.0:
			detarget_timer -= delta
		else:
			untarget_hitbox()

func do_end_effect():
	context.player.weapon.attack_initiated.disconnect(buff_attack)

#region Targeting
func target_hitbox(attack : Weapon.Attack, damage_dealt : int, hitbox: Hitbox):
	# If no target or hitbox has more hp than target, retarget
	if not targeted_hitbox or hitbox.hc.health > targeted_hitbox.hc.health:
		untarget_hitbox()
		targeted_hitbox = hitbox
		target_reticle = PerkArtParticle.create(Perk.Type.TARGET, targeted_hitbox, UNTARGET_INTERVAL, Vector2(0, 0), 0)
		detarget_timer = UNTARGET_INTERVAL

func untarget_hitbox():
	if targeted_hitbox:
		if target_reticle:
			target_reticle.kill_early()

#endregion Targeting
