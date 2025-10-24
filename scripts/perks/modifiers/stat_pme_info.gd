extends PerkModEffectInfo

## Stores everything about a PerkModEffect except its actual effect logic.
## Effect logic is stored in a subclass script of PerkModEffect.
class_name StatPmeInfo

@export var target_stat: String
@export var stat_mod_type: StatMod.Type
