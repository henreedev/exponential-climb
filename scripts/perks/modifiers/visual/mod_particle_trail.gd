extends Node2D

## Has a start, trail, and end. 
## One trail is instantiated per effect application that a modifier does.
class_name ModParticleTrail

static func cleanup_all_mod_particle_trails():
	pass

static func create_particle_trail(start_perk: Perk, end_perk: Perk, rarity: Perk.Rarity, polarity: PerkModEffect.Polarity, ):
	pass

static func _pick_start_end_locations

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
