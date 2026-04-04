extends RigidBody3D

@export_group("Car properties")
@export var wheels: Array[Node3D]
@export var brake_light_mesh: MeshInstance3D
@export var brake_light_material: StandardMaterial3D
@export var engine_power := 18
@export var downhill_multiplier := 1.3
@export var brake_power := 25
@export var tire_turn_speed := 1.3
@export var tire_max_turn_degrees := 35
@export var max_turn_curve : Curve

@export_group("Wheel properties")
@export var rolling_resistance_curve : Curve
@export var grip_curve_front : Curve
@export var grip_curve_rear : Curve
@export var grip_curve_drift_front : Curve
@export var grip_curve_drift_rear : Curve

@export_group("Air physics")
@export var air_pitch_torque := 0.2
@export var extra_gravity := 12

@export_group("Wall Collision")
@export var wall_penalty_multiplier := 0.8
@export var wall_spin_damping := 0.5

@export_category("Debug")
@export var show_debug := false

@onready var total_wheels := wheels.size()
var is_drifting := false
var is_grounded := false
var car_velocity := 0.0
var _prev_linear_velocity := Vector3.ZERO # Velocity right before wall collision

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - to_global(center_of_mass))

func _physics_process(delta: float) -> void:
	var throttle_input := Input.get_action_strength("throttle")
	var brake_input := Input.get_action_strength("brake")
	brake_light_material.albedo_color = Color(sign(brake_input) + 0.2, 0, 0)
	var steer_input := Input.get_axis("steer_right", "steer_left") * tire_turn_speed
	
	var car_mass_share := mass / total_wheels
	
	car_velocity = -global_basis.z.dot(linear_velocity)
	for wheel in wheels:
		## Rotate wheels
		var is_front_wheel := to_local(wheel.global_position).z < 0
		var is_rear_wheel := not is_front_wheel
		if is_front_wheel:
			var steer_ratio := max_turn_curve.sample_baked(car_velocity*3.6)
			if steer_input:
				wheel.rotation.y = clampf(wheel.rotation.y + steer_input * delta,
				deg_to_rad(-tire_max_turn_degrees * steer_ratio), 
				deg_to_rad(tire_max_turn_degrees) * steer_ratio)
			else:
				wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * delta)
		
		if not is_grounded: continue
		
		# Vehicle Forces
		var wheel_center := wheel.global_position
		var force_pos := wheel_center - global_position
		var wheel_forward_dir := -wheel.global_basis.z
		var tire_velocity := _get_point_velocity(wheel_center)
		var wheel_forward_velocity := wheel_forward_dir.dot(tire_velocity)
		
		# Acceleration
		var is_powered_wheel := to_local(wheel.global_position).z > 0
		if is_powered_wheel and throttle_input:
			var wheel_power_share := 0.5
			var engine_force := throttle_input * mass * engine_power * wheel_power_share * wheel_forward_dir
			if linear_velocity.y < -1: engine_force *= downhill_multiplier
			apply_force(engine_force, force_pos)
			if show_debug: DebugDraw3D.draw_arrow_ray(global_position + force_pos, engine_force, 0.01, Color.RED, 0.3, true)
		
		# Grippy steering
		var wheel_sideways_dir := wheel.global_basis.x
		var wheel_sideways_velocity := wheel_sideways_dir.dot(tire_velocity)
		
		var slip_angle = atan2(wheel_sideways_velocity, wheel_forward_velocity)
		var slip_angle_norm = remap(abs(slip_angle), 0, PI/2, 0, 1)
		
		if brake_input > 0: is_drifting = true
		if brake_input == 0 and slip_angle_norm < 0.05: is_drifting = false
		
		var grip_factor := grip_curve_front.sample_baked(slip_angle_norm)
		if is_rear_wheel: grip_factor = grip_curve_rear.sample_baked(slip_angle_norm)
		if is_drifting:
			grip_factor = grip_curve_drift_front.sample_baked(slip_angle_norm)
			if is_rear_wheel: grip_factor = grip_curve_drift_rear.sample_baked(slip_angle_norm)
		var normal_load := car_mass_share * 9.8
		var grip_force := -wheel_sideways_velocity * wheel_sideways_dir * normal_load * grip_factor
		apply_force(grip_force, force_pos)
		if show_debug: DebugDraw3D.draw_arrow_ray(global_position + force_pos, grip_force, 0.01, Color.YELLOW, 0.3, true)
		
		# Rolling resistance
		var rolling_resistance := rolling_resistance_curve.sample_baked(abs(car_velocity)*3.6)
		var rolling_resistance_force := wheel.global_basis.z * signf(car_velocity) * rolling_resistance * car_mass_share * (2 - throttle_input)
		apply_force(rolling_resistance_force, force_pos)
		var brake_modifier := 0.4 if car_velocity < 0.1 else 1.0
		var braking_force := wheel.global_basis.z * car_mass_share * brake_power * brake_modifier * brake_input
		apply_force(braking_force, force_pos)
		if show_debug: DebugDraw3D.draw_arrow_ray(global_position + force_pos, rolling_resistance_force + braking_force, 0.01, Color.ORANGE, 0.3, true)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	is_grounded = false
	var hit_wall := false
	var max_impact := 0.0
	# Loop through all current collisions
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		if normal.y > 0.5: 
			is_grounded = true
			
		var is_wall: bool = abs(normal.y) < 0.3
		if is_wall:
			hit_wall = true
			var impact_velocity: float = abs(_prev_linear_velocity.dot(normal))
			if impact_velocity > max_impact:
				max_impact = impact_velocity
	
	if hit_wall and max_impact > 0.5:
		var car_forward_dir := -global_basis.z
		var current_forward_speed := state.linear_velocity.dot(car_forward_dir)
		var speed_reduction := max_impact * wall_penalty_multiplier
		var new_forward_speed := move_toward(current_forward_speed, 0.0, speed_reduction)
		var actual_reduction := current_forward_speed - new_forward_speed
		state.linear_velocity -= car_forward_dir * actual_reduction
		state.angular_velocity *= wall_spin_damping
	_prev_linear_velocity = state.linear_velocity
	
	if not is_grounded:
		linear_damp = 0.0
		var pitch_force := -global_basis.x * air_pitch_torque * mass
		apply_torque(pitch_force)
		var extra_gravity_force := Vector3.DOWN * extra_gravity * mass
		apply_central_force(extra_gravity_force)
	else:
		linear_damp = 0.1
