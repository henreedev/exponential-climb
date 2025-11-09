extends CanvasGroup

## Displays the 5 rarity directions and their rarities, given a perk mod.
class_name PerkModRarityVisual

var parent_mod: PerkMod
const PERK_MOD_RARITY_ANIMATED_SPRITE = preload("uid://bljw1eq8dlpb1")

func init_parent_mod(mod: PerkMod):
	parent_mod = mod

func refresh():
	assert(parent_mod)
	for child in get_children():
		child.queue_free()
		remove_child(child)
	for dir in parent_mod.target_directions:
		# Find the effect of highest rarity in this direction
		var max_rarity: Perk.Rarity = Perk.Rarity.COMMON
		for pme: PerkModEffect in parent_mod.effects:
			if int(pme.rarity) > int(max_rarity):
				max_rarity = pme.rarity
		# Add an animated sprite for the max rarity in this direction.
		var rarity_sprite: AnimatedSprite2D = PERK_MOD_RARITY_ANIMATED_SPRITE.instantiate()
		rarity_sprite.animation = str(Perk.Rarity.find_key(max_rarity)).to_lower()
		rarity_sprite.frame = dir
		add_child(rarity_sprite)
