extends CanvasGroup

## Displays the 5 rarity directions and their rarities, given a perk mod.
class_name PerkModPolarityVisual

var parent_mod: PerkMod
const PERK_MOD_POLARITY_ANIMATED_SPRITE = preload("uid://bhsv0ofcb18ro")

func init_parent_mod(mod: PerkMod):
	parent_mod = mod

func refresh():
	assert(parent_mod)
	for child in get_children():
		child.queue_free()
		remove_child(child)
	for dir in parent_mod.target_directions:
		# Collect the unique polarities to determine what kind of arrow to show
		# (Buff, Nerf, Both)
		var polarity_arr: Array[PerkModEffect.Polarity] = []
		for pme: PerkModEffect in parent_mod.effects:
			if pme.has_direction(dir):
				if not polarity_arr.has(pme.polarity):
					polarity_arr.append(pme.polarity)
		# Add an animated sprite for the max rarity in this direction.
		var anim: String
		if polarity_arr.has(PerkModEffect.Polarity.BUFF):
			if polarity_arr.has(PerkModEffect.Polarity.NERF):
				anim = "both"
			else:
				anim = "buff"
		elif polarity_arr.has(PerkModEffect.Polarity.NERF):
			anim = "nerf"
		
		var polarity_sprite: AnimatedSprite2D = PERK_MOD_POLARITY_ANIMATED_SPRITE.instantiate()
		polarity_sprite.animation = anim
		polarity_sprite.frame = dir
		add_child(polarity_sprite)
