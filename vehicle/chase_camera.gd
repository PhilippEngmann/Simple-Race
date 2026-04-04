extends Camera3D

@export var distance := 3.5
@export var height := 1.0
@export var vertical_stiffness := 25.0

@onready var target: Node3D = get_parent().get_parent()
@onready var freecam: Camera3D = target.get_node("Freecam") as Camera3D

var target_finished: bool = false

func _physics_process(delta: float) -> void:
	if target_finished: return
	
	var from_target := global_position - target.global_position
	
	# Calculate xz distance first
	from_target.y = 0
	from_target = from_target.normalized() * distance
	var target_pos := target.global_position + from_target

	# Calculate y distance second
	var desired_y := target.global_position.y + height
	target_pos.y = lerp(global_position.y, desired_y, vertical_stiffness * delta)
	
	look_at_from_position(target_pos, target.global_position)
	
	if current: freecam.global_transform = global_transform

	if Input.is_action_just_pressed("freecam_toggle"):
		if current:
			freecam.make_current()
			clear_current()
		else:
			make_current()
			freecam.clear_current()
