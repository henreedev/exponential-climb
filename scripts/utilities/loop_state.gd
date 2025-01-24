extends Resource

## The information on an instance of the loop moving through an active build.
class_name LoopState

var current_perk : Perk
var build : PerkBuild

#region Active 
var current_index := 0
var empty_slot_timer := 0.0
## True when moving to an active perk that's on cooldown. 
var waiting_for_cooldown := false
#endregion Active 

#region Passive 
var loop_value_left := 0.0
var next_loop_value := 0.0
var loop_value_tween : Tween
## Done animating.
var done := false
#endregion Passive 
