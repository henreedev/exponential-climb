extends Node

signal max_perks_updated

var players : Array[Player]

var max_perks := 2

#var enemies : Array[Enemy]

func add_player(player : Player):
	players.append(player)


func add_perk_slot():
	max_perks += 1
	max_perks_updated.emit()
