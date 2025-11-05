extends CanvasGroup

## Displays the 5 rarity directions and their rarities, given a perk mod.
class_name PerkModLoopVisual

var parent_mod: PerkMod
const PERK_MOD_LOOP_ANIMATED_SPRITE = preload("uid://dleofbjiwkvrb")

func init_parent_mod(mod: PerkMod):
	parent_mod = mod

func refresh():
	assert(parent_mod)
	for child in get_children():
		child.queue_free()
		remove_child(child)
	for dir in parent_mod.target_directions:
		if not dir == PerkMod.Direction.SELF:
			var loop_sprite: AnimatedSprite2D = PERK_MOD_LOOP_ANIMATED_SPRITE.instantiate()
			loop_sprite.frame = int(dir) - 1
			add_child(loop_sprite)
