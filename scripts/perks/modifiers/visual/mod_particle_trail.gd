extends Node2D

## Has a start, trail, and end. 
## One trail is instantiated per effect application that a modifier does.
## Alt should show all particle trails, while hovering should show only hovered perk's trails. Issue is perk card covering things to the right. 
## Maybe 2 seconds of hover should show trails?
## Also placing a modifier down should show trails until perk ui disabled. or until alt is unpressed. 
## For testing, just have alt unpress cause 
class_name ModParticleTrail

var trail_curve2d: Curve2D
const MOD_PARTICLE_TRAIL_INITIAL_RAMP_GRADIENT: Gradient = preload("uid://bafatee2owwtg")

@onready var start: GPUParticles2D = %Start
@onready var start_mat: ParticleProcessMaterial = start.process_material
@onready var trail: GPUParticles2D = %Trail
@onready var trail_mat: ParticleProcessMaterial = trail.process_material
@onready var end: GPUParticles2D = %End
@onready var end_mat: ParticleProcessMaterial = end.process_material

@onready var init_ramp_gradient: Gradient = MOD_PARTICLE_TRAIL_INITIAL_RAMP_GRADIENT.duplicate_deep()

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
func _setup_coloring(effect: PerkModEffect) -> void:
	_setup_shared_gradient(effect)

## Set shared gradient
## Gives start, trail and end the same duplicate of the gradient resource
func _setup_shared_gradient(effect: PerkModEffect) -> void:
	var start_grad_tex = start_mat.color_initial_ramp as GradientTexture1D
	start_grad_tex.gradient = init_ramp_gradient
	var trail_grad_tex = trail_mat.color_initial_ramp as GradientTexture1D
	trail_grad_tex.gradient = init_ramp_gradient
	var end_grad_tex = end_mat.color_initial_ramp as GradientTexture1D
	end_grad_tex.gradient = init_ramp_gradient
	

## Set rarity color
func _set_gradient_rarity_color(effect: PerkModEffect) -> void:
	var rarity: Perk.Rarity = effect.rarity
	var color := Chest.RARITY_TO_BODY_COLOR[rarity]
	
	# First color is base, second is rarity, third is polarity.
	init_ramp_gradient.set_color(1, color)

const POLARITY_TO_COLOR: Dictionary[PerkModEffect.Polarity, Color] = {
	PerkModEffect.Polarity.BUFF : Color.LIME_GREEN,
	PerkModEffect.Polarity.NERF : Color.LIME_GREEN,
}
## Set polarity color
func _set_gradient_polarity_color(effect: PerkModEffect) -> void:
	var polarity: Perk.Rarity = effect.polarity
	var color := Chest.RARITY_TO_BODY_COLOR[polarity]
	
	# First color is base, second is rarity, third is polarity.
	init_ramp_gradient.set_color(1, color)

	
	
	
	
	

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
