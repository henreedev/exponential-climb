extends Node


@onready var perk_apple: PerkInfo = load("uid://bvsejnl5hvg6w")
@onready var perk_balloon: PerkInfo = load("uid://clabewkb2ojy0")
@onready var perk_coffee: PerkInfo = load("uid://cq0j44d15irf1")
@onready var perk_empty: PerkInfo = load("res://resources/perks/perk_empty.tres")
@onready var perk_feather: PerkInfo = load("uid://kjat51gt3dvi")
@onready var perk_match: PerkInfo = load("uid://bveww58kit4xh")
@onready var perk_muscle: PerkInfo = load("uid://c2olwfjmtrtry")
@onready var perk_speed_boost: PerkInfo = load("uid://clfcowt8sjly2")
@onready var perk_sunset: PerkInfo = load("uid://cwd3hqkpk3mj1")
@onready var perk_sun_moon: PerkInfo = load("uid://clrsdu5hhq4yt")
@onready var perk_target: PerkInfo = load("uid://u647phdpdbm0")
@onready var perk_tree: PerkInfo = load("uid://4ndnjl11pkp0")
# @onready var perk_cat_alert: PerkInfo = preload("uid://c7kwe3al6cwni")

@onready var perk_infos: Array[PerkInfo] = [
	perk_apple,
	perk_balloon,
	perk_coffee,
	perk_empty,
	perk_feather,
	perk_match,
	perk_muscle,
	perk_speed_boost,
	perk_sunset,
	perk_sun_moon,
	perk_target,
	perk_tree,
	# perk_cat_alert,
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
	for perk_info in perk_infos:
		PERK_INFO_DICT[perk_info.type] = perk_info
		if perk_info.type != Perk.Type.EMPTY:
			rarity_to_perk_types[perk_info.rarity].append(perk_info.type)
	print("Populated perk pool with: ", PERK_INFO_DICT.values().map(func(value): return value.code_name))

func return_perk_to_pool(perk : Perk):
	rarity_to_perk_types[perk.rarity].append(perk.type)

func pick_perk_type_from_pool(rarity : Perk.Rarity):
	var types_arr = rarity_to_perk_types[rarity] 
	if types_arr.size() > 0:
		var rand_perk_type = types_arr.pick_random()
		#types_arr.erase(rand_perk_type) # FIXME uncomment to remove perks from pool
		return rand_perk_type
	else:
		printerr("Ran out of non-empty perks in PerkManager's rarity pool for rarity: ", Perk.Rarity.find_key(rarity))
		return Perk.Type.EMPTY

func pick_perk_from_pool(rarity : Perk.Rarity):
	return Perk.init_perk(pick_perk_type_from_pool(rarity))
