extends Node


const PERK_APPLE: PerkInfo = preload("uid://bvsejnl5hvg6w")
const PERK_BALLOON: PerkInfo = preload("uid://clabewkb2ojy0")
const PERK_COFFEE: PerkInfo = preload("uid://cq0j44d15irf1")
const PERK_EMPTY: PerkInfo = preload("uid://p4awhf6jsft2")
const PERK_FEATHER: PerkInfo = preload("uid://kjat51gt3dvi")
const PERK_MATCH: PerkInfo = preload("uid://bveww58kit4xh")
const PERK_MUSCLE: PerkInfo = preload("uid://c2olwfjmtrtry")
const PERK_SPEED_BOOST: PerkInfo = preload("uid://clfcowt8sjly2")
const PERK_SUNSET: PerkInfo = preload("uid://cwd3hqkpk3mj1")
const PERK_SUN_MOON: PerkInfo = preload("uid://clrsdu5hhq4yt")
const PERK_TARGET: PerkInfo = preload("uid://u647phdpdbm0")
const PERK_TREE: PerkInfo = preload("uid://4ndnjl11pkp0")
# const PERK_CAT_ALERT: PerkInfo = preload("uid://c7kwe3al6cwni")


static var PERK_INFOS: Array[PerkInfo] = [
	PERK_APPLE,
	PERK_BALLOON,
	PERK_COFFEE,
	PERK_EMPTY,
	PERK_FEATHER,
	PERK_MATCH,
	PERK_MUSCLE,
	PERK_SPEED_BOOST,
	PERK_SUNSET,
	PERK_SUN_MOON,
	PERK_TARGET,
	PERK_TREE,
	# PERK_CAT_ALERT,  # Uncomment when ready
]


## Populated once on ready by reading the PerkInfo resource files for their type
static var PERK_INFO_DICT : Dictionary[Perk.Type, PerkInfo] = {
	
}

var rarity_to_perk_types : Dictionary[Perk.Rarity, Array] = {
		Perk.Rarity.COMMON : [],
		Perk.Rarity.RARE : [],
		Perk.Rarity.EPIC : [],
		Perk.Rarity.LEGENDARY : [],
}


func _ready():
	populate_pools_and_dict()

func populate_pools_and_dict():
	for perk_info : PerkInfo in PERK_INFOS:
		assert(not PERK_INFO_DICT.has(perk_info.type), "No two PerkInfos should use the same Type")
		PERK_INFO_DICT[perk_info.type] = perk_info
		rarity_to_perk_types[perk_info.rarity].append(perk_info.type)

func return_perk_to_pool(perk : Perk):
	rarity_to_perk_types[perk.rarity].append(perk.type)

func pick_perk_type_from_pool(rarity : Perk.Rarity):
	var types_arr = rarity_to_perk_types[rarity] 
	if types_arr.size() > 0:
		var rand_perk_type = types_arr.pick_random()
		types_arr.erase(rand_perk_type)
		return rand_perk_type
	else:
		printerr("Ran out of non-empty perks in PerkManager's rarity pool for rarity: ", str(rarity))
		return Perk.Type.EMPTY

func pick_perk_from_pool(rarity : Perk.Rarity):
	return Perk.init_perk(pick_perk_type_from_pool(rarity))
