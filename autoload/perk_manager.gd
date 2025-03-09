extends Node


## Populated once on ready by reading the perks folder for PerkInfo resource files.
static var PERK_INFO_DICT : Dictionary[Perk.Type, PerkInfo] = {
	
}

var rarity_to_perk_types : Dictionary[Perk.Rarity, Array] = {
		Perk.Rarity.COMMON : [],
		Perk.Rarity.RARE : [],
		Perk.Rarity.EPIC : [],
		Perk.Rarity.LEGENDARY : [],
		Perk.Rarity.EMPTY : [],
}


func _ready():
	load_perk_files("res://resources/perks/")
	populate_pools()

func populate_pools():
	for perk_info : PerkInfo in PERK_INFO_DICT.values():
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
		return Perk.Type.EMPTY

func pick_perk_from_pool(rarity : Perk.Rarity):
	return Perk.init_perk(pick_perk_type_from_pool(rarity))


static func load_perk_files(path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				print("Found directory: " + file_name)
			else:
				if file_name.get_extension() == "import":
					file_name = file_name.replace(".import", "")
				if file_name.get_extension() == "remap":
					file_name = file_name.replace(".remap", "")
					
				var perk_info : PerkInfo = ResourceLoader.load(path + "/" + file_name)
				PERK_INFO_DICT[perk_info.type] = perk_info
				
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")



static func load_asset(path : String) -> Resource:
	if OS.has_feature("export"):
		# Check if file is .remap
		if not path.ends_with(".remap"):
			return load(path)

		# Open the file
		var __config_file = ConfigFile.new()
		__config_file.load(path)

		# Load the remapped file
		var __remapped_file_path = __config_file.get_value("remap", "path")
		__config_file = null
		return load(__remapped_file_path)
	else:
		return load(path)
