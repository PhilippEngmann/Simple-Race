extends RigidBody3D
class_name RaycastCar

@export_group("Car properties")
@export var wheels: Array[RayCast3D]
@export var acceleration := 600.0
@export var max_speed := 20.0
@export var accel_curve : Curve
@export var tire_turn_speed := 2.0
@export var tire_max_turn_degrees := 25
@export var max_turn_curve : Curve

@export_group("Wheel properties")
@export var spring_strength := 5000.0
@export var spring_damping := 200.0
@export var rest_dist := 0.1
@export var over_extend := 0.05
@export var wheel_radius := 0.33
@export var z_traction := 0.005
@export var z_brake_traction := 0.025

@export_category("Debug")
@export var show_debug := false

@onready var total_wheels := wheels.size()

var throttle_input := 0.0
var brake_input := 0.0

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)	

func _basic_steering_rotation(wheel: RayCast3D, delta: float) -> void:
	var is_steering_wheel := to_local(wheel.global_position).z < 0
	if not is_steering_wheel: return
	var forward_dir := -global_basis.z
	var vel := forward_dir.dot(linear_velocity)
	var speed_ratio := vel / max_speed
	var turn_input := Input.get_axis("steer_right", "steer_left") * tire_turn_speed
	if turn_input:
		wheel.rotation.y = clampf(wheel.rotation.y + turn_input * delta, 
		deg_to_rad(-tire_max_turn_degrees * max_turn_curve.sample_baked(speed_ratio)), deg_to_rad(tire_max_turn_degrees) * max_turn_curve.sample_baked(speed_ratio))
	else:
		wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * delta)

func _ready() -> void:
	for wheel in wheels:
		wheel.target_position.y = -(rest_dist + wheel_radius + over_extend)

func _physics_process(delta: float) -> void:
	throttle_input = Input.get_action_strength("throttle")
	brake_input = Input.get_action_strength("brake")

	for wheel in wheels:
		var wheel_mesh: Node3D = wheel.get_child(0)
		_basic_steering_rotation(wheel, delta)
		
		wheel.force_raycast_update()
		wheel.target_position.y = -(rest_dist + wheel_radius + over_extend)
		
		## Rotate wheel visuals
		var forward_dir := -wheel.global_basis.z
		var vel := forward_dir.dot(linear_velocity)
		wheel_mesh.rotate_x((-vel * delta) / wheel_radius)
		
		if not wheel.is_colliding(): continue
		# From here on, the wheel raycast is now colliding
		
		var contact := wheel.get_collision_point()
		var spring_len := maxf(0.0, wheel.global_position.distance_to(contact) - wheel_radius)
		var offset := rest_dist - spring_len
		
		# TODO: Consider moving to shapecast instead
		wheel_mesh.position.y = move_toward(wheel_mesh.position.y, -spring_len, 5 * delta) # Local y position of the wheel
		contact = wheel_mesh.global_position # Contact is now the wheel origin point
		var force_pos := contact - global_position
		
		## Spring forces
		var spring_force := spring_strength * offset
		var tire_vel := _get_point_velocity(contact) # Center of the wheel
		var spring_damp_f := spring_damping * wheel.global_basis.y.dot(tire_vel)
		
		var y_force := (spring_force - spring_damp_f) * wheel.get_collision_normal()
		
		## Acceleration
		var is_powered_wheel := to_local(wheel.global_position).z > 0
		if is_powered_wheel and throttle_input:
			var speed_ratio := vel / max_speed
			var accel_force := forward_dir * acceleration * throttle_input * accel_curve.sample_baked(speed_ratio)
			apply_force(accel_force, force_pos)
			if show_debug: DebugDraw3D.draw_arrow_ray(contact, accel_force / mass, 2.5, Color.RED, 0.5, true)
			
		## Tire X traction (Steering)
		var side_dir := wheel.global_basis.x
		var v_side := side_dir.dot(tire_vel)

		var m_eff := mass / total_wheels
		var x_force := -(m_eff * v_side / delta) * side_dir  # cancel in one step
		
		## Tire Z traction (Longitudinal)
		var f_vel := forward_dir.dot(tire_vel)
		var z_friction := z_traction
		if brake_input > 0.0:
			z_friction = z_brake_traction * brake_input
		var z_force := wheel.global_basis.z * f_vel * z_friction * (mass / delta) / total_wheels
		
		apply_force(y_force, force_pos)
		apply_force(x_force, force_pos)
		apply_force(z_force, force_pos)
		
		if show_debug: DebugDraw3D.draw_arrow_ray(contact, y_force / mass, 2.5, Color.BLUE, 0.5, true)
		if show_debug: DebugDraw3D.draw_arrow_ray(contact, x_force / mass, 1.5, Color.YELLOW, 0.2, true)
		if show_debug: DebugDraw3D.draw_arrow_ray(contact, z_force / mass, 1.5, Color.ORANGE, 0.2, true)
