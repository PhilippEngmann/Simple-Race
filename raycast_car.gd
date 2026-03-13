extends RigidBody3D

@export_group("Car properties")
@export var wheels: Array[ShapeCast3D]
@export var accel_curve: Curve
@export var tire_turn_speed := 1.3
@export var tire_max_turn_degrees := 35
@export var max_turn_curve : Curve

@export_group("Wheel properties")
@export var spring_strength := 5000.0
@export var spring_damping := 600.0
@export var rest_dist := 0.2
@export var over_extend := 0.0
@export var wheel_radius := 0.3
@export var rolling_resistance_coef := 0.005
@export var brake_power := 0.005
@export var grip_curve_front : Curve
@export var grip_curve_rear : Curve
@export var grip_curve_drift_front : Curve
@export var grip_curve_drift_rear : Curve

@export_group("Air physics")
@export var air_pitch_torque := 0.2 ## How strongly the nose pulls down
@export var max_air_pitch_velocity := 1.5 ## Prevents the car from front-flipping uncontrollably

@export_category("Debug")
@export var show_debug := false

@onready var total_wheels := wheels.size()
var is_drifting := false

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - to_global(center_of_mass))

func _physics_process(delta: float) -> void:
	var throttle_input := Input.get_action_strength("throttle")
	var brake_input := Input.get_action_strength("brake")
	$BrakeLight.visible = true if brake_input > 0 else false
	var steer_input := Input.get_axis("steer_right", "steer_left") * tire_turn_speed

	var car_mass_share := mass / total_wheels
	var grounded_wheels := 0
	
	for wheel in wheels:
		var wheel_center := wheel.global_position
		var force_pos := wheel_center - global_position
		
		wheel.target_position.y = -(rest_dist + over_extend)
		var car_velocity := -global_basis.z.dot(linear_velocity)

		## Rotate wheels
		var is_front_wheel := to_local(wheel.global_position).z < 0
		if is_front_wheel:
			var steer_ratio := max_turn_curve.sample_baked(car_velocity*3.6)
			if steer_input:
				wheel.rotation.y = clampf(wheel.rotation.y + steer_input * delta,
				deg_to_rad(-tire_max_turn_degrees * steer_ratio), 
				deg_to_rad(tire_max_turn_degrees) * steer_ratio)
			else:
				wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * delta)
		## Spin wheels
		var wheel_forward_dir := -wheel.global_basis.z
		var tire_velocity := _get_point_velocity(wheel_center)
		var wheel_forward_velocity := wheel_forward_dir.dot(tire_velocity)
		#wheel_mesh.rotate_x((-wheel_forward_velocity * delta) / wheel_radius)
		if not wheel.is_colliding(): continue
		grounded_wheels += 1
		
		var contact_point := wheel.get_collision_point(0)
		var spring_len := maxf(0.0, wheel.global_position.distance_to(contact_point) - wheel_radius)
		var spring_offset := rest_dist - spring_len
		
		## Suspension
		var spring_force := spring_strength * spring_offset
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
		
		var slip_angle = atan2(wheel_sideways_velocity, wheel_forward_velocity)
		var slip_angle_norm = remap(abs(slip_angle), 0, PI/2, 0, 1)
		
		if brake_input > 0: is_drifting = true
		if brake_input == 0 and slip_angle_norm < 0.05: is_drifting = false
		
		var grip_factor := grip_curve_front.sample_baked(slip_angle_norm)
		if !is_front_wheel: grip_factor = grip_curve_rear.sample_baked(slip_angle_norm)
		if is_drifting:
			grip_factor = grip_curve_drift_front.sample_baked(slip_angle_norm)
			if !is_front_wheel: grip_factor = grip_curve_drift_rear.sample_baked(slip_angle_norm)
		var normal_load := car_mass_share * 9.8
		var grip_force := -wheel_sideways_velocity * wheel_sideways_dir * normal_load * grip_factor
		#print(rad_to_deg(abs(slip_angle)))
		apply_force(grip_force, force_pos)
		
		if show_debug: DebugDraw3D.draw_arrow_ray(global_position + force_pos, grip_force, 0.5, Color.YELLOW, 0.3, true)
		
		## Rolling resistance
		var rolling_resistance := rolling_resistance_coef
		if brake_input > 0.0:
			rolling_resistance += brake_power * brake_input
		var rolling_resistance_force := (1 - throttle_input) * wheel.global_basis.z * wheel_forward_velocity * rolling_resistance * car_mass_share
		apply_impulse(rolling_resistance_force, force_pos)
		if show_debug: DebugDraw3D.draw_arrow_ray(global_position + force_pos, rolling_resistance_force, 1.0, Color.ORANGE, 0.3, true)
		
	## Air Pitching logic
	if grounded_wheels == 0:
		var pitch_force := -global_basis.x * air_pitch_torque * mass
		apply_torque(pitch_force)
