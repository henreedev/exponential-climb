extends AnimatedSprite2D

## Sets perk line art color based on rarity using a shader.
class_name PerkArt

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Make material unique
	assert(material)
	var shader_mat = material as ShaderMaterial
	assert(shader_mat)
	material = shader_mat.duplicate_deep()

func set_rarity(rarity: Perk.Rarity):
	var shader_mat = material as ShaderMaterial
	shader_mat.set_shader_parameter("current_rarity", rarity)
