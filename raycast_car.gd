extends RigidBody3D

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
@export var rolling_resistance_coef := 0.005
@export var brake_power := 0.02

@export_category("Debug")
@export var show_debug := false

@onready var total_wheels := wheels.size()

var throttle_input := 0.0
var brake_input := 0.0

func _get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

func _ready() -> void:
	for wheel in wheels:
		wheel.target_position.y = -(rest_dist + wheel_radius + over_extend)

func _physics_process(delta: float) -> void:
	throttle_input = Input.get_action_strength("throttle")
	brake_input = Input.get_action_strength("brake")

	var car_mass_share := mass / total_wheels

	for wheel in wheels:
		var wheel_mesh: Node3D = wheel.get_child(0)

		## Steer wheels
		var is_steering_wheel := to_local(wheel.global_position).z < 0
		if is_steering_wheel:
			var car_velocity := -global_basis.z.dot(linear_velocity)
			var speed_ratio := car_velocity / max_speed
			var steer_input := Input.get_axis("steer_right", "steer_left") * tire_turn_speed
			if steer_input:
				wheel.rotation.y = clampf(wheel.rotation.y + steer_input * delta,
				deg_to_rad(-tire_max_turn_degrees * max_turn_curve.sample_baked(speed_ratio)), 
				deg_to_rad(tire_max_turn_degrees) * max_turn_curve.sample_baked(speed_ratio))
			else:
				wheel.rotation.y = move_toward(wheel.rotation.y, 0, tire_turn_speed * delta)

		wheel.force_raycast_update()
		wheel.target_position.y = -(rest_dist + wheel_radius + over_extend)
		
		## Rotate wheels
		var wheel_forward_dir := -wheel.global_basis.z
		var wheel_forward_velocity := wheel_forward_dir.dot(linear_velocity)
		wheel_mesh.rotate_x((-wheel_forward_velocity * delta) / wheel_radius)
		
		if not wheel.is_colliding(): continue
		
		var contact_point := wheel.get_collision_point()
		var spring_len := maxf(0.0, wheel.global_position.distance_to(contact_point) - wheel_radius)
		var spring_offset := rest_dist - spring_len
		
		# Smooth wheel movement over bumps. TODO: Consider moving to shapecast instead
		wheel_mesh.position.y = move_toward(wheel_mesh.position.y, -spring_len, 5 * delta) # Local y position of the wheel
		var wheel_center := wheel_mesh.global_position
		var force_pos := wheel_center - global_position
		
		## Suspension
		var spring_force := spring_strength * spring_offset
		var tire_velocity := _get_point_velocity(wheel_center)
		var damping_force := spring_damping * wheel.global_basis.y.dot(tire_velocity)
		var suspension_force = (spring_force - damping_force) * wheel.get_collision_normal()
		
		## Acceleration
		var is_powered_wheel := to_local(wheel.global_position).z > 0
		if is_powered_wheel and throttle_input:
			var speed_ratio := wheel_forward_velocity / max_speed
			var engine_force := wheel_forward_dir * acceleration * throttle_input * accel_curve.sample_baked(speed_ratio)
			apply_force(engine_force, force_pos)
			if show_debug: DebugDraw3D.draw_arrow_ray(wheel_center, engine_force / mass, 2.5, Color.RED, 0.5, true)
			
		## Steering
		var wheel_sideways_dir := wheel.global_basis.x
		var wheel_sideways_velocity := wheel_sideways_dir.dot(tire_velocity)
		var grip_impulse := -wheel_sideways_velocity * car_mass_share * wheel_sideways_dir
		
		## Rolling resistance
		var rolling_resistance := rolling_resistance_coef
		if brake_input > 0.0:
			rolling_resistance += brake_power * brake_input
		var rolling_resistance_impulse := wheel.global_basis.z * wheel_forward_velocity * rolling_resistance * car_mass_share
		
		apply_force(suspension_force, force_pos)
		apply_impulse(grip_impulse, force_pos)
		apply_impulse(rolling_resistance_impulse, force_pos)
		
		if show_debug: DebugDraw3D.draw_arrow_ray(wheel_center, suspension_force / mass, 2.5, Color.BLUE, 0.5, true)
		if show_debug: DebugDraw3D.draw_arrow_ray(wheel_center, grip_impulse / mass, 1.5, Color.YELLOW, 0.2, true)
		if show_debug: DebugDraw3D.draw_arrow_ray(wheel_center, rolling_resistance_impulse / mass, 1.5, Color.ORANGE, 0.2, true)
