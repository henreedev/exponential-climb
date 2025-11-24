extends Node2D

## Has a start, trail, and end. 
## One trail is instantiated per effect application that a modifier does.
## Alt should show all particle trails, while hovering should show only hovered perk's trails. Issue is perk card covering things to the right. 
## Maybe 2 seconds of hover should show trails?
## Also placing a modifier down should show trails until perk ui disabled. or until alt is unpressed. 
## For testing, just have alt unpress cause 
class_name ModParticleTrail

#region Static methods
static func cleanup_all_mod_particle_trails():
	pass

static func create_particle_trail(start_perk: Perk, end_perk: Perk, effect: PerkModEffect):
	pass
#endregion Static methods

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _pick_start_end_locations(start_perk: Perk, end_perk: Perk, effect: PerkModEffect) -> void:
	pass
 
## Setup coloring - calls bottom 3 functions 

## Set shared gradient

## Set rarity color

## Set polarity color

## Setup trail velocity - calls bottom two functions

## Calculate trail curve2d - Start point, end point, picks random gradients

## Calculate directional velocity curves - for each point on trail curve2d bake, 
## find the derivative with the last point and add a point to the x,y dir vel curves for the x,y of deriv.
## Try this out. Might work if we divide by baked length?


## Kick off (start emitting start and trail, then after trail lifetime start emitting end.)

## Remove (set emitting to false on all, queue free after 1.0 sec)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
