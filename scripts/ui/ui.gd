extends CanvasLayer

class_name UI

@onready var health_bar: TextureProgressBar = %HealthBar
@onready var xp_bar: TextureProgressBar = %XpBar
@onready var health_label: Label = %HealthLabel
@onready var xp_label: Label = %XpLabel

func _ready():
	Global.player.hc.damage_taken.connect(update_health_bar)
	Global.player.hc.healing_received.connect(update_health_bar)
	Global.player.xp_changed.connect(update_xp_bar)
	
	update_health_bar()
	update_xp_bar()

func update_health_bar():
	health_bar.max_value = Global.player.hc.max_health.value()
	health_bar.value = Global.player.hc.health
	health_label.text = str(int(health_bar.value)) + "/" + str(int(health_bar.max_value))

func update_xp_bar():
	xp_bar.max_value = Global.player.xp_to_next_level
	xp_bar.value = Global.player.xp
	xp_label.text = str(int(xp_bar.value)) + "/" + str(int(xp_bar.max_value))
