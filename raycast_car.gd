extends RigidBody3D
class_name RaycastCar

@export var wheels: Array[RaycastWheel]
@export var acceleration := 600.0
@export var max_speed := 20.0
@export var accel_curve : Curve
@export var tire_turn_speed := 2.0
@export var tire_max_turn_degrees := 25
@export var max_turn_curve : Curve

@onready var total_wheels := wheels.size()

var throttle_input := 0.0

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)	

func _basic_steering_rotation(wheel: RaycastWheel, delta: float) -> void:
	if not wheel.is_steer: return
	var forward_dir := -global_basis.z
	var vel := forward_dir.dot(linear_velocity)
	var speed_ratio := vel / max_speed
	var turn_input := Input.get_axis("steer_right", "steer_left") * tire_turn_speed
	if turn_input:
		wheel.rotation.y = clampf(wheel.rotation.y + turn_input * delta, 
		deg_to_rad(-tire_max_turn_degrees * max_turn_curve.sample_baked(speed_ratio)), deg_to_rad(tire_max_turn_degrees) * max_turn_curve.sample_baked(speed_ratio))
	else:
		wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * delta)

func _physics_process(delta: float) -> void:
	throttle_input = Input.get_action_strength("throttle")

	for wheel in wheels:
		wheel.apply_wheel_physics(self, delta)
		_basic_steering_rotation(wheel, delta)
		
		wheel.brake_input = Input.is_action_pressed("brake")
