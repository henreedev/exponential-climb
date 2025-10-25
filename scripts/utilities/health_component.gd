extends Node2D

class_name HealthComponent

signal died
signal revived
signal damage_taken
signal healing_received

var max_health : Stat
var health : int

## When taking float damage, the fraction is stored here. 
## Once >= 1, flush it onto the next instance of damage as an integer.
var fractional_dmg : float

## When receiving float healing, the fraction is stored here. 
## Once >= 1, flush it onto the next instance of healing as an integer.
var fractional_heal : float

## Once dead, cannot receive healing or damage, and health is zero.
var dead := false

## Deals damage, storing fractional values and dying if applicable. Returns actual integer damage taken.
func take_damage(damage : float) -> int:
	# Don't take damage while dead
	if dead: return 0
	
	# Store total damage in variable
	var total_dmg := int(damage)
	
	# Add fractional part of damage to `fractional_dmg`
	fractional_dmg += damage - int(damage)
	
	# Flush `fractional_dmg` as an int if >= 1
	if fractional_dmg >= 1:
		var flushed_fractional_dmg = int(fractional_dmg)
		fractional_dmg -= flushed_fractional_dmg
		total_dmg += flushed_fractional_dmg
	
	# Remove total damage from health
	health -= total_dmg
	
	# Die if dead
	if health <= 0:
		die()
	
	# Emit signal
	damage_taken.emit()
	
	return total_dmg

## Heals, storing fractional values. Returns actual integer health healed.
func receive_healing(healing : float) -> int:
	# Don't heal while dead
	if dead: return 0
	
	# Store total healing in variable
	var total_heal := int(healing)
	
	# Add fractional part of healing to `fractional_heal`
	fractional_heal += healing - int(healing)
	
	# Flush `fractional_heal` as an int if >= 1
	if fractional_heal >= 1:
		var flushed_fractional_heal = int(fractional_heal)
		fractional_heal -= flushed_fractional_heal
		total_heal += flushed_fractional_heal
	
	# Add total healing to health
	health += total_heal
	
	# Clamp health to max health
	health = clampi(health, 0, max_health.value())
	
	# Emit signal
	healing_received.emit()
	
	return total_heal

func die():
	if not dead:
		dead = true
		health = 0
		fractional_dmg = 0
		fractional_heal = 0
		died.emit()

func revive():
	dead = false
	set_health_to_full()
	revived.emit()


func set_health_to_full():
	health = max_health.value()
	healing_received.emit()
