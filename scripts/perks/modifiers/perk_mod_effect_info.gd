extends Resource

## Stores everything about a PerkModEffect except its actual effect logic.
## Effect logic is stored in a subclass script of PerkModEffect.
class_name PerkModEffectInfo

#@export var type: PerkModEffect.Type
@export var is_buff := true
@export_group("Nerfs")
@export var can_be_nerf := false
