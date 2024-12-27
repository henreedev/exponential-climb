extends Resource

## Contains all of a player's active and passive builds.
class_name BuildContainer

var player : Player
var active_builds : Array[PerkBuild]
var passive_builds : Array[PerkBuild]

func add_active_build(build : PerkBuild):
	active_builds.append(build)

func add_passive_build(build : PerkBuild):
	passive_builds.append(build)

func deactivate_all():
	for build in active_builds:
		build.deactivate()
	for build in passive_builds:
		build.deactivate()
