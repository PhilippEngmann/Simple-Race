extends Camera3D

@export var distance := 4.5
@export var height := 1.5

@onready var target : Node3D = get_parent().get_parent()
@onready var freecam: Camera3D = target.get_node("Freecam") as Camera3D

func _physics_process(_delta: float) -> void:
	var from_target := global_position - target.global_position
	
	if from_target.length() != distance:
		from_target = from_target.normalized() * distance
		
	from_target.y = height
	global_position = target.global_position + from_target

	var look_dir := global_position.direction_to(target.global_position).abs() - Vector3.UP
	if not look_dir.is_zero_approx():
		look_at_from_position(global_position, target.global_position, Vector3.UP)
	
	if self.current:
		freecam.global_transform = self.global_transform

	if Input.is_action_just_pressed("freecam_toggle"):
		if self.current:
			freecam.make_current()
			self.clear_current()
		else:
			self.make_current()
			freecam.clear_current()
