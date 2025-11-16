extends RichTextLabel

class_name RarityTypeDescriptor

func set_descriptor_text(rarity: Perk.Rarity, type: String, object_type := "PERK"):
	text = ""
	
	var rarity_color = Chest.RARITY_TO_BODY_COLOR[rarity]
	var rarity_text = Perk.Rarity.find_key(rarity)
	push_color(rarity_color)
	add_text(rarity_text)
	pop()
	
	if type:
		add_text(" ")
		match type.to_lower():
			"active":
				push_color(Color.AZURE)
				add_text(type)
				pop()
			"passive":
				push_color(Color.DIM_GRAY)
				add_text(type)
				pop()
			"buff":
				push_color(PmeUiSlotDirs.get_tint_color(true))
				add_text(type)
				pop()
			"nerf":
				push_color(PmeUiSlotDirs.get_tint_color(false))
				add_text(type)
				pop()
			"active trigger":
				push_color(Color.AZURE)
				add_text(type.split(" ")[0] + " ")
				pop()
				push_color(Color.DEEP_SKY_BLUE)
				add_text(type.split(" ")[1])
				pop()
			_:
				assert(false)
		
		
		# While we have active/passive info, adjust text shadowing to be darker for active
		match type.to_lower():
			"active","active trigger":
				add_theme_color_override("font_shadow_color", Color(0,0,0,0.75))

	
	if object_type:
		match object_type:
			"MODIFIER, EFFECT":
				add_text(" ")
				push_color(Color.AQUA)
				add_text(object_type)
				pop()
			_:
				add_text(" ")
				push_color(Color.WHITE_SMOKE)
				add_text(object_type)
				pop()
	
