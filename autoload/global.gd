extends Node

signal max_perks_updated
signal max_builds_updated

var player : Player

var max_perks := 2
var max_build_size := 2
var max_builds := 1
const BUILD_SIZE = 4
#var enemies : Array[Enemy]

func add_perk_slot():
	max_perks += 1
	if max_build_size < BUILD_SIZE: 
		max_build_size += 1
	if max_perks > BUILD_SIZE * max_builds: # More perks than player has space for
		# Add a new build to put perks in
		max_builds += 1
		max_builds_updated.emit()
	max_perks_updated.emit()
