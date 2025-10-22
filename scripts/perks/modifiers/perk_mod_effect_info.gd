extends Resource

## Stores everything about a PerkModEffect except its actual effect logic.
## Effect logic is stored in a subclass script of PerkModEffect.
class_name PerkModEffectInfo


## The rarity of this effect.
@export var rarity: Perk.Rarity
## The type of perks this effect is allowed to apply to.
@export var target_type : PerkModEffect.TargetType
## The directions that this effect applies in.
@export var target_directions : Array[PerkMod.Direction]
## The scope of this effect.
@export var scope : PerkModEffect.Scope
## The polarity of this effect. 
@export var polarity: PerkModEffect.Polarity
## Whether this effect can switch polarity from BUFF to NERF and vice versa.
@export var can_switch_polarity := false
## The numeric strength of this effect.
@export var power: Stat

@export_group("Enhancements")
## Whether this effect utilizes a numeric power value.
@export var uses_power := true
## False for effects that want to have specific directions on init.
@export var can_enhance_directions := true
## False for effects that want to have specific scope on init.
@export var can_enhance_scope := true
