extends Camera3D

@export var distance := 3.5
@export var height := 1.0
@export var vertical_smooth_speed := 25.0 # Tune this to make the bungee cord tighter or looser

@onready var target: Node3D = get_parent().get_parent()
@onready var freecam: Camera3D = target.get_node("Freecam") as Camera3D

func _physics_process(delta: float) -> void:
	# 1. Get the world-space vector from the car to the camera
	var from_target := global_position - target.global_position

	# 2. Flatten it to 2D (the horizontal "tow cable"). 
	# This ensures the 3.5m distance is only enforced horizontally,
	# preventing the camera from pulling forward when going up hills.
	from_target.y = 0

	# 3. Enforce the strict horizontal distance
	if not from_target.is_zero_approx() and from_target.length() != distance:
		from_target = from_target.normalized() * distance

	# 4. Calculate the desired X/Z coordinates
	var target_pos := target.global_position + from_target

	# 5. The Bungee Cord: Calculate desired height and lerp the Y axis smoothly
	var desired_y := target.global_position.y + height
	target_pos.y = lerp(global_position.y, desired_y, vertical_smooth_speed * delta)

	# Apply the new position
	global_position = target_pos

	# 6. Look at the car using World UP. 
	# Using the car's local UP (target.global_basis.y) causes nausea/stiffness
	# when the car bounces over uneven terrain. World UP keeps the horizon level.
	var to_target := global_position.direction_to(target.global_position)
	if abs(to_target.dot(Vector3.UP)) < 0.999:
		look_at_from_position(global_position, target.global_position, Vector3.UP)

	# Keep freecam synced
	if self.current:
		freecam.global_transform = self.global_transform

	# Handle toggling
	if Input.is_action_just_pressed("freecam_toggle"):
		if self.current:
			freecam.make_current()
			self.clear_current()
		else:
			self.make_current()
			freecam.clear_current()
