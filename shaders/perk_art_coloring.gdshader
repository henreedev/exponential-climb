shader_type canvas_item;

uniform vec4 common_color : source_color;
uniform vec4 rare_color : source_color;
uniform vec4 epic_color : source_color;
uniform vec4 legendary_color : source_color;

uniform int current_rarity : hint_enum("COMMON", "RARE", "EPIC", "LEGENDARY");

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	if (COLOR.a > 0.0) {
		switch(current_rarity) {
			case 0:
				COLOR = common_color;
				break;
			case 1:
				COLOR = rare_color;
				break;
			case 2:
				COLOR = epic_color;
				break;
			case 3:
				COLOR = legendary_color;
				break;
		}
	}
	COLOR = modulate * COLOR;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
