extends Area2D

## Shared hitbox class, capable of being dealt damage. 
## Allows for:
## - custom damage ratios
## - hitbox groups, where hitboxes in the same group for a given parent node can only be hit once total per Attack.
class_name Hitbox

signal took_damage(amount: float)
signal received_knockback(knockback_vec: Vector2)

@export_range(0.1, 2.0, 0.05) var damage_ratio := 1.0

## The node that this hitbox should redirect hits to.
## Must be a Player or Enemy or TODO Pot. 
@export var custom_parent_node: Node 
@export var custom_parent_node_group: String

@export_subgroup("Knockback")
@export var use_damage_ratio_as_knockback_ratio := true
@export var knockback_ratio := 1.0

func _ready() -> void:
	_populate_parent_if_null()
	if use_damage_ratio_as_knockback_ratio:
		knockback_ratio = damage_ratio

func _populate_parent_if_null():
	if not custom_parent_node:
		if custom_parent_node_group:
			custom_parent_node = get_tree().get_first_node_in_group(custom_parent_node_group)
		else:
			custom_parent_node = get_parent()

#region Public methods
func take_damage(amount: float, damage_color : DamageNumber.DamageColor = DamageNumber.DamageColor.DEFAULT):
	var scaled_damage = amount * damage_ratio
	var overridden_damage_color = _override_damage_number_color(damage_color)
	# Me when interfaces don't exist.. quack
	if custom_parent_node.has_method("take_damage"):
		custom_parent_node.call("take_damage", scaled_damage, overridden_damage_color)
	took_damage.emit(scaled_damage)

## Assumes that knockback direction is directly away from the player
## if direction is not passed. 
func receive_knockback(knockback_str : float, direction := Vector2.INF):
	if direction == Vector2.INF:
		direction = Global.player.position.direction_to(position)
	# Check for perfect overlap
	if direction == Vector2.ZERO: 
		direction = Vector2.RIGHT
	var knockback_vec := knockback_str * direction
	
	if custom_parent_node.has_method("receive_knockback"):
		custom_parent_node.call("receive_knockback", knockback_vec)
	received_knockback.emit(knockback_vec)

func get_hitbox_parent() -> Node2D:
	return custom_parent_node

func get_parent_global_position() -> Vector2:
	return get_hitbox_parent().global_position

func disable():
	process_mode = Node.PROCESS_MODE_DISABLED

func enable():
	process_mode = Node.PROCESS_MODE_INHERIT
#endregion Public methods

func _override_damage_number_color(damage_color : DamageNumber.DamageColor) -> DamageNumber.DamageColor:
	return damage_color
