extends RichTextLabel

## A POE2-inspired info popup that contains clickable keywords that can open new popups.
class_name DescriptionBox

## Map from keyword to [code][explanation, text color][/code].
const KEYWORDS : Dictionary[String, Array] = {
	"player loop speed" : ["Explanation here.", Color.PALE_GREEN],
	"loop speed" : ["Explanation here.", Color.WHITE],
	"power" : ["Explanation here.", Color.WHITE],
	"area" : ["Explanation here.", Color.WHITE],
	"range" : ["Explanation here.", Color.WHITE],
	"runtime" : ["Explanation here.", Color.WHITE],
	"cooldown" : ["Explanation here.", Color.WHITE],
	"active" : ["Explanation here.", Color.WHITE],
	"passive" : ["Explanation here.", Color.WHITE],
}

#endregion Perk UI Info on hover

func _ready() -> void:
	var bbcode_text = text
	for word in KEYWORDS.keys():
		bbcode_text = bbcode_text.replacen(word, "[url]" + word.to_upper() + "[/url]") 
	text = bbcode_text


func _on_meta_clicked(meta: Variant) -> void:
	print("meta clicked!")


func _on_meta_hover_ended(meta: Variant) -> void:
	print("meta hover ended!")


func _on_meta_hover_started(meta: Variant) -> void:
	print("meta hover started!")
