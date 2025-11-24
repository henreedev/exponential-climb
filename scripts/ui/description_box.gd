extends RichTextLabel

## A POE2-inspired info popup that contains clickable keywords that can open new popups.
## Also parses formulas denoted by pairs of "$" (e.g. [code]$0.1 * power$[/code]).
class_name DescriptionBox

## Map from keyword to [code][explanation, text color][/code].
const KEYWORDS : Dictionary[String, Array] = {
	"Loop" : ["The fundamental force powering us. It activates Active perks during gameplay and Passive perks at Lock In based on its speed multiplier.", Color.DODGER_BLUE],
	"Lock In" : ["After entering a door, the moment where you choose your perk layout and activate Passive perks for the next room.", Color.WHITE],
	"Power" : ["The strength of a perk.", Color.YELLOW],
	"Area" : ["The space an attack takes up.", Color.WHITE],
	"Range" : ["The distance an attack travels or reaches.", Color.WHITE],
	"Runtime" : ["How long the Loop spends on a perk when activating it.", Color.WHITE],
	"Duration" : ["How long an Active perk's effect lasts.", Color.WHITE],
	"Cooldown" : ["How long before the Loop can activate a perk again. The Loop will idle at a perk if it is on cooldown.", Color.WHITE],
	"Active" : ["A type of perk that gets activated by the Loop during combat.", Color.WHITE],
	"Passive" : ["A type of perk that gets activated by the Loop once at Lock In.", Color.DIM_GRAY],
	"Activations" : ["How many times this perk instantiates its effect when told to activate.", Color.WHITE],
	"Trigger" : ["A type of Active perk that is activated only on a certain player action, not by the Loop.", Color.AQUA],
	"Ignite" : ["Deals damage over time. (TODO)", Color.ORANGE],
	"Primary Attack" : ["The player's main attack.", Color.WHITE],
	"Secondary Attack" : ["The player's alternative attack.", Color.WHITE],
}

const SWAPPABLE_WORDS: Dictionary[String, String] = {
	"Increases" : "Decreases",
	"Multiplies" : "Divides",
}

## Stats in formulas are expected to be properties of this node.
@export var formula_lookup_node: Node

const FORMULA_CHAR := "$"
var nonformula_chunks: Array[String]
var formula_chunks: Array[String]

## True when holding Left Alt - shows calculations of formulas instead of just output value.
var formula_mode_on := false
@export var waits_for_manual_initialization := true

var disappear_on_mouse_exit = false

#region Create keyword description boxes
#static var keyword_to_temp_description_box: Dictionary[String, DescriptionBox]
const DESCRIPTION_BOX = preload("uid://xh6jjs5v4ubs")
static func create_temp_keyword_description_box(keyword: String):
	#if keyword_to_temp_description_box.has(keyword) and \
			#keyword_to_temp_description_box[keyword] != null:
		#return
	
	var temp_desc_box: DescriptionBox = DESCRIPTION_BOX.instantiate()
	
	var arr: Array[Variant] = KEYWORDS[keyword]
	var keyword_color: Color = arr[1]
	var keyword_text = "[center][color=#" + keyword_color.to_html() + "]" + keyword + "[/color][/center]"
	
	var keyword_desc: String = arr[0]
	var keyword_desc_text: String = "[center]" + keyword_desc + "[/center]"
	var temp_desc_text = keyword_text + keyword_desc_text
	temp_desc_box.initialize(temp_desc_text)
	
	temp_desc_box.disappear_on_mouse_exit = true
	Global.perk_ui.toggled_off.connect(temp_desc_box._on_mouse_exited)
	
	# Pivot at center bottom
	Global.perk_ui.add_child(temp_desc_box)
	temp_desc_box.pivot_offset = Vector2((temp_desc_box.size / 2.0).x, temp_desc_box.size.y)
	var mouse_pos = Global.perk_ui.get_viewport().get_mouse_position()
	temp_desc_box.position = mouse_pos + Vector2.UP * 10 - temp_desc_box.pivot_offset
	
	#keyword_to_temp_description_box[keyword] = temp_desc_box
#endregion Create keyword description boxes


#region On ready
func _ready():
	if not waits_for_manual_initialization:
		_initialize_implicit()

func initialize(new_text: String = "", parent: Node = null) -> void:
	if new_text != "": 
		text = new_text
	init_parent(parent)
	_initialize_implicit()
	refresh()

func _initialize_implicit():
	_connect_signals()
	_setup_bbcode()
	_setup_keyword_urls()
	_try_swap_words()
	_parse_formulas()

func init_parent(parent: Node):
	formula_lookup_node = parent

func _connect_signals():
	if not Global.formula_mode_toggled.is_connected(toggle_formula_mode):
		Global.formula_mode_toggled.connect(toggle_formula_mode)
	if not meta_hover_started.is_connected(_on_meta_hover_started):
		meta_hover_started.connect(_on_meta_hover_started)
	if not meta_hover_ended.is_connected(_on_meta_hover_ended):
		meta_hover_ended.connect(_on_meta_hover_ended)
	if not meta_clicked.is_connected(_on_meta_clicked):
		meta_clicked.connect(_on_meta_clicked)

func _setup_bbcode():
	bbcode_enabled = true

func _setup_keyword_urls():
	var bbcode_text = text
	for word in KEYWORDS.keys():
		var color_hex = "#" + KEYWORDS[word][1].to_html()
		var prefix = "[color=" + color_hex + "][url]"
		const suffix = "[/url][/color]"
		bbcode_text = bbcode_text.replace(word, prefix + word + suffix) 
	text = bbcode_text

## Replaces positive words with opposite versions for a nerf effect.
## PME descriptions are written for their buff versions.
func _try_swap_words():
	var pme: PerkModEffect = formula_lookup_node as PerkModEffect
	if not pme:
		return
	if pme.is_buff():
		return
	
	var tokens = text.split(" ")
	var reconstructed_string_with_swaps := ""
	for i in range(len(tokens)):
		var token = tokens[i]
		for key in SWAPPABLE_WORDS:
			var value = SWAPPABLE_WORDS[key]
			if token == key: 
				tokens[i] = value
		for value in SWAPPABLE_WORDS.values():
			var key = SWAPPABLE_WORDS.find_key(value)
			if token == value: 
				tokens[i] = key
		reconstructed_string_with_swaps += tokens[i]
		if i != len(tokens):
			reconstructed_string_with_swaps += " "
	
	text = reconstructed_string_with_swaps
#endregion On ready

func toggle_formula_mode(on: bool):
	formula_mode_on = on
	refresh() 

func refresh() -> void:
	_reconstruct_text()

## Splits up the original text into chunks of formula and non-formula, 
## so that if they were appended back together in order it would form the original string without $'s.
func _parse_formulas() -> void:
	if text == "": return
	formula_chunks.clear()
	nonformula_chunks.clear()
	# True when first encountering a $, until the next $.
	var formula_opened := false
	# The portion of the overall text being built, either formula or nonformula
	var string_chunk := ""
	for i in range(text.length()):
		var character := text[i]
		if character == FORMULA_CHAR:
			if formula_opened:
				# Close formula
				formula_opened = false
				# Save string chunk as formula
				formula_chunks.append(string_chunk)
				string_chunk = ""
			else:
				# Open formula
				formula_opened = true
				# Save string chunk as nonformula
				nonformula_chunks.append(string_chunk)
				string_chunk = ""
		else:
			string_chunk += character
	if not string_chunk.is_empty():
		nonformula_chunks.append(string_chunk)
	#print("Parsed formulas for perk ", formula_lookup_node.code_name if formula_lookup_node else "", "got ", formula_chunks.size(), " formula chunks and ", nonformula_chunks.size(), " nonformula chunks for text: \"", text, "\"")

func _reconstruct_text() -> void:
	var assertion = text == "" or len(nonformula_chunks) - 1 == len(formula_chunks)
	if not assertion:
		printerr("Assertion failed: description chunks have incorrect ratio")
	var reconstructed_text := ""
	for i in range(nonformula_chunks.size()):
		if i == nonformula_chunks.size() - 1:
			# Last chunk should be only nonformula
			reconstructed_text += nonformula_chunks[i]
		else:
			var nonformula := nonformula_chunks[i]
			reconstructed_text += nonformula
			
			var formula := formula_chunks[i]
			if formula_mode_on:
				formula = _get_formula_calculation_as_string(formula)
			else:
				formula = _get_formula_value_as_string(formula)
			reconstructed_text += formula
		
	text = reconstructed_text

## Trims [url] tags, then splits the formula with spaces. 
## Assumes formulas just multiply values!
##
## - First token becomes base value of output value
## - Stats are converted into their calculation strings
## - Floats/ints are parsed
func _get_formula_value_as_string(formula: String) -> String:
	formula = formula.replace("[url]", "")
	formula = formula.replace("[/url]", "")
	formula = formula.replace("*", "")
	var tokens = formula.split(" ", false)
	var result_value := 0.0 
	var first_token := true
	
	for token: String in tokens:
		var token_value := 0.0
		var parsed := false
		# Try parse as float
		if token.is_valid_float():
			token_value = token.to_float()
			parsed = true
		
		# Try parse as int
		if token.is_valid_int():
			token_value = token.to_int()
			parsed = true
		
		# Try parse as Stat
		var token_stat := get_stat_from_string(token)
		if token_stat:
			assert(not parsed)
			token_value = token_stat.value()
			parsed = true
		
		assert(parsed)
		if first_token:
			result_value = token_value 
			first_token = false
		else:
			result_value *= token_value
	
	return PerkCard.get_float_string_with_fewest_decimals(result_value)

## Looks for any valid Stats in the input string and converts them to their calculation string.
func _get_formula_calculation_as_string(formula: String) -> String:
	# Find tokens without urls
	var tokens = formula.split(" ", false)
	# Replace those tokens with stats if the corresponding stat is nonnull.
	for token: String in tokens:
		var token_without_urls = token.replace("[url]", "")
		token_without_urls = token_without_urls.replace("[/url]", "")
		
		var stat := get_stat_from_string(token_without_urls)
		if stat:
			formula = formula.replace(token_without_urls, stat.to_calculation_string())
	return formula
	

## Returns null if the string could not be matched to a stat.
func get_stat_from_string(stat_string: String) -> Stat:
	var stat: Stat
	match stat_string:
		# Player stats
		"base_damage", "area", "attack_speed", "range", "gravity", "movement_speed", \
		"movement_accel", "jump_strength", "double_jumps", "health_regen":
			stat = Global.player.get(stat_string)
		# Loop stats
		"loop_speed", "global_increase":
			stat = Loop.get(stat_string)
		_:
			stat = formula_lookup_node.get(stat_string)
	return stat

func _on_meta_clicked(meta: Variant) -> void:
	print("meta clicked: ", meta)
	create_temp_keyword_description_box(meta)

func _on_meta_hover_ended(meta: Variant) -> void:
	print("meta hover ended: ", meta)

func _on_meta_hover_started(meta: Variant) -> void:
	print("meta hover started: ", meta)

func _on_mouse_exited() -> void:
	if disappear_on_mouse_exit:
		#keyword_to_temp_description_box[keyword_to_temp_description_box.find_key(self)] = null
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(5,5,5,0.0), 0.3).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(queue_free)
