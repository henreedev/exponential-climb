extends Sprite2D

class_name XP 

enum Size {SMALL, MEDIUM, LARGE, EXTRA_LARGE}
const SIZE_TO_AMOUNT : Dictionary[Size, int] = {
	Size.SMALL : 1, 
	Size.MEDIUM : 5, 
	Size.LARGE : 25, 
	Size.EXTRA_LARGE : 50,
}
const AMOUNTS_DESCENDING: Array[int] = [
	SIZE_TO_AMOUNT[Size.EXTRA_LARGE],
	SIZE_TO_AMOUNT[Size.LARGE],
	SIZE_TO_AMOUNT[Size.MEDIUM],
	SIZE_TO_AMOUNT[Size.SMALL],
]

const XP_SCENE = preload("res://scenes/enemy/xp.tscn")

## The amount of xp this orb gives to the player on contact.
var amount : int 

## The spawn point of this xp orb.
var start_pos : Vector2
## The start pos of this orb after spreading out.
var final_start_pos : Vector2


## Base time the orb takes to reach the player after spawning.
const DURATION = 1.7
## The duration for this orb, which will be randomized.
var duration : float
var rate : float

## Direction the orb spreads in upon spawning.
var rand_spread_vector : Vector2
## The base speed at which orbs spread out upon spawning.
const SPREAD_SPEED = 40.0
## The spread speed for this orb, which will be randomized.
var spread_speed : float
## The offset from the player's actual position that the orb will fake going 
## towards, in order to curve the path towards the player.
var destination_offset : Vector2
## How far along the animation towards the player this orb is. (0.0 -> 1.0) 
var progress := 0.0


## The curve that movement between the spawn point and the player follows.
@export var movement_curve : Curve
## The curve that the spread of the spawn point follows.
@export var spread_curve : Curve
## The curve that spread of the destination point.
@export var destination_curve : Curve


## Given a desired amount of total xp to drop, spawns xp orbs of the largest sizes possible.
static func spawn_xp(_amount : int, pos : Vector2):
	while _amount > 0:
		var new_orb_amount = get_largest_size_amount(_amount)
		_amount -= new_orb_amount
		var xp_orb : XP = XP_SCENE.instantiate()
		xp_orb.start_pos = pos
		xp_orb.position = pos
		
		xp_orb.rand_spread_vector = Vector2(randf_range(-1, 1), 0).rotated(randf_range(-PI, PI))
		xp_orb.spread_speed = SPREAD_SPEED * randf_range(0.1, 1.0)
		
		xp_orb.duration = DURATION * randf_range(0.5, 1.0)
		xp_orb.duration *= (pos.distance_to(Global.player.position) / 1000 + 1)
		print((pos.distance_to(Global.player.position) / 300 + 1))
		xp_orb.rate = 1.0 / xp_orb.duration
		xp_orb.amount = new_orb_amount
		
		Global.game.add_child(xp_orb)

func _ready():
	final_start_pos = start_pos + rand_spread_vector * spread_speed * duration
	destination_offset = rand_spread_vector * spread_speed * duration

func _physics_process(delta: float) -> void:
	progress += rate * delta
	var spread_start_pos = lerp(start_pos, final_start_pos, spread_curve.sample_baked(progress))
	var end_pos = lerp(Global.player.position, Global.player.position + destination_offset, destination_curve.sample_baked(progress))
	if progress > 0.2 and (progress > 1.00 or Global.player.position.distance_squared_to(position) < 4.0):
		Global.player.receive_xp(amount)
		queue_free()
	var last_pos = position
	position = lerp(spread_start_pos, end_pos, movement_curve.sample_baked(progress))
	rotation = lerp_angle(rotation, (position - last_pos).angle() + PI / 2, delta * 20.0)

static func get_largest_size_amount(_amount: float):
	assert (_amount != 0)
	# Find the largest xp orb size that fits within the _amount budget
	for amt in AMOUNTS_DESCENDING:
		if _amount >= amt:
			return amt
