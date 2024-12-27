extends Resource

## The information on an instance of the loop moving through an active build.
class_name LoopState

var current_perk : Perk
var current_active_index := 0
var build : PerkBuild

var empty_slot_timer := 0.0
## True when moving to an active perk that's on cooldown. 
var waiting_for_cooldown := false
