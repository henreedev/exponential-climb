extends Hitbox

class_name PlayerHitbox

func _override_damage_number_color(_damage_color : DamageNumber.DamageColor) -> DamageNumber.DamageColor:
	return DamageNumber.DamageColor.ENEMY
