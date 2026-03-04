extends RigidBody3D

@export_group("Car properties")
@export var wheels: Array[ShapeCast3D]
@export var accel_curve: Curve
@export var tire_turn_speed := 1.3
@export var tire_max_turn_degrees := 35
@export var max_turn_curve : Curve

@export_group("Wheel properties")
@export var spring_strength := 5000.0
@export var spring_damping := 200.0
@export var rest_dist := 0.1
@export var over_extend := 0.05
@export var wheel_radius := 0.27
@export var rolling_resistance_coef := 0.005
@export var brake_power := 0.02

@export_category("Debug")
@export var show_debug := false

@onready var total_wheels := wheels.size()

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - to_global(center_of_mass))

func _physics_process(delta: float) -> void:
	var throttle_input := Input.get_action_strength("throttle")
	var brake_input := Input.get_action_strength("brake")
	var steer_input := Input.get_axis("steer_right", "steer_left") * tire_turn_speed

	var car_mass_share := mass / total_wheels
	
	for wheel in wheels:
		var wheel_center := wheel.global_position
		var force_pos := wheel_center - global_position
		
		wheel.target_position.y = -(rest_dist + over_extend)
		var car_velocity := -global_basis.z.dot(linear_velocity)

		## Rotate wheels
		var is_steering_wheel := to_local(wheel.global_position).z < 0
		if is_steering_wheel:
			var steer_ratio := max_turn_curve.sample_baked(car_velocity*3.6)
			if steer_input:
				wheel.rotation.y = clampf(wheel.rotation.y + steer_input * delta,
				deg_to_rad(-tire_max_turn_degrees * steer_ratio), 
				deg_to_rad(tire_max_turn_degrees) * steer_ratio)
			else:
				wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * delta)
		## Spin wheels
		var wheel_forward_dir := -wheel.global_basis.z
		var wheel_forward_velocity := wheel_forward_dir.dot(linear_velocity)
		#wheel_mesh.rotate_x((-wheel_forward_velocity * delta) / wheel_radius)
		DebugDraw3D.draw_sphere(wheel.global_position)
		if not wheel.is_colliding(): continue
		
		var contact_point := wheel.get_collision_point(0)
		var spring_len := maxf(0.0, wheel.global_position.distance_to(contact_point) - wheel_radius)
		var spring_offset := rest_dist - spring_len
		
		## Suspension
		var spring_force := spring_strength * spring_offset
		var tire_velocity := _get_point_velocity(wheel_center)
		var damping_force := spring_damping * wheel.global_basis.y.dot(tire_velocity)
		var suspension_force = (spring_force - damping_force) * wheel.get_collision_normal(0)
		apply_force(suspension_force, force_pos)
		if show_debug: DebugDraw3D.draw_arrow_ray(global_position + force_pos, suspension_force, 0.02, Color.BLUE, 0.3, true)
		
		## Acceleration
		var is_powered_wheel := to_local(wheel.global_position).z > 0
		if is_powered_wheel and throttle_input:
			var engine_force := throttle_input * mass * accel_curve.sample_baked(car_velocity*3.6) * 0.5 * wheel_forward_dir
			apply_force(engine_force, force_pos)
			if show_debug: DebugDraw3D.draw_arrow_ray(global_position + force_pos, engine_force, 0.05, Color.RED, 0.3, true)
		
		## Grippy steering
		var wheel_sideways_dir := wheel.global_basis.x
		var wheel_sideways_velocity := wheel_sideways_dir.dot(tire_velocity)
		var grip_factor := 1.0
		var grip_force := (-wheel_sideways_velocity * car_mass_share) * grip_factor * wheel_sideways_dir
		apply_impulse(grip_force, force_pos)
		if show_debug: DebugDraw3D.draw_arrow_ray(global_position + force_pos, grip_force, 0.5, Color.YELLOW, 0.3, true)
		
		## Rolling resistance
		var rolling_resistance := rolling_resistance_coef
		if brake_input > 0.0:
			rolling_resistance += brake_power * brake_input
		var rolling_resistance_force := (1 - throttle_input) * wheel.global_basis.z * wheel_forward_velocity * (rolling_resistance * car_mass_share)
		apply_impulse(rolling_resistance_force, force_pos)
		if show_debug: DebugDraw3D.draw_arrow_ray(global_position + force_pos, rolling_resistance_force, 1.0, Color.ORANGE, 0.3, true)
