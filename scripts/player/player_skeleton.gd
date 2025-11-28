extends Node2D

class_name PlayerSkeleton
@onready var head_look_at_target: Marker2D = $Skeleton/Targets/HeadLookAtTarget

const FPS = 120
const FRAME_INTERVAL = 1.0 / float(FPS)
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#process_mode = Node.PROCESS_MODE_DISABLED
	#var tween := Global.create_tween().set_loops()
	#tween.tween_property(self, "process_mode", ProcessMode.PROCESS_MODE_INHERIT, 0.0)
	#tween.tween_callback(_process.bind(FRAME_INTERVAL)).set_delay(FRAME_INTERVAL)
	#tween.tween_property(self, "process_mode", ProcessMode.PROCESS_MODE_DISABLED, 0.0)
	
	# Make sure pinned bodies are on top of each other
	for child in get_children():
		if child is PinJoint2D:
			var nodepatha: NodePath = child.node_a
			var nodepathb: NodePath = child.node_b
			var nodea: Node2D = get_node(nodepatha)
			var nodeb: Node2D = get_node(nodepathb)
			child.node_b = null
			nodea.global_position = nodeb.global_position
			await get_tree().physics_frame
			child.node_b = nodepathb
	pass
func _process(_delta: float) -> void:
	head_look_at_target.global_position = get_global_mouse_position()

@onready var lfoot_body: StaticBody2D = %LfootBody
@onready var wiggly_lfoot: RigidBody2D = %WigglyLfoot

func _physics_process(delta: float) -> void:
	wiggly_lfoot.collision_mask = 4 if lfoot_body.global_position.distance_to(wiggly_lfoot.global_position) > 5.0 else 0 
		 
