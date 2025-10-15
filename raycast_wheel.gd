extends RayCast3D
class_name RaycastWheel

@export_group("Wheel properties")
@export var spring_strength := 100.0
@export var spring_damping := 2.0
@export var rest_dist := 0.5
@export var over_extend := 0.0
@export var wheel_radius := 0.4
@export var z_traction := 0.005
@export var z_brake_traction := 0.025

@export_category("Motor")
@export var is_motor := false
@export var is_steer := false

@export_category("Debug")
@export var show_debug := false

@onready var wheel: Node3D = get_child(0)

var engine_force := 0.0
var grip_factor := 0.0
var brake_input := 0.0

func _ready() -> void:
	target_position.y = -(rest_dist + wheel_radius + over_extend)
	
func apply_wheel_physics(car: RaycastCar, delta: float) -> void:
	force_raycast_update()
	target_position.y = -(rest_dist + wheel_radius + over_extend)
	
	## Rotate wheel visuals
	var forward_dir := -global_basis.z
	var vel := forward_dir.dot(car.linear_velocity)
	wheel.rotate_x((-vel * get_physics_process_delta_time()) / wheel_radius)
	
	if not is_colliding(): return
	# From here on, the wheel raycast is now colliding
	
	var contact := get_collision_point()
	var spring_len := maxf(0.0, global_position.distance_to(contact) - wheel_radius)
	var offset := rest_dist - spring_len
	
	# TODO: Consider moving to shapecast instead
	wheel.position.y = move_toward(wheel.position.y, -spring_len, 5 * get_physics_process_delta_time()) # Local y position of the wheel
	contact = wheel.global_position # Contact is now the wheel origin point
	var force_pos := contact - car.global_position
	
	## Spring forces
	var spring_force := spring_strength * offset
	var tire_vel := car._get_point_velocity(contact) # Center of the wheel
	var spring_damp_f := spring_damping * global_basis.y.dot(tire_vel)
	
	var y_force := (spring_force - spring_damp_f) * get_collision_normal()
	
	## Acceleration
	if is_motor and car.throttle_input:
		var speed_ratio := vel / car.max_speed
		var accel_force := forward_dir * car.acceleration * car.throttle_input * car.accel_curve.sample_baked(speed_ratio)
		car.apply_force(accel_force, force_pos)
		if show_debug: DebugDraw3D.draw_arrow_ray(contact, accel_force / car.mass, 2.5, Color.RED, 0.5, true)
		
	## Tire X traction (Steering)
	var side_dir := global_basis.x
	var v_side := side_dir.dot(tire_vel)

	var m_eff := car.mass / car.total_wheels
	var x_force := -(m_eff * v_side / delta) * side_dir  # cancel in one step
	
	## Tire Z traction (Longitudinal)
	var f_vel := forward_dir.dot(tire_vel)
	var z_friction := z_traction
	if brake_input > 0.0:
		z_friction = z_brake_traction * brake_input
	var z_force := global_basis.z * f_vel * z_friction * (car.mass / delta) / car.total_wheels
	
	car.apply_force(y_force, force_pos)
	car.apply_force(x_force, force_pos)
	car.apply_force(z_force, force_pos)
	
	if show_debug: DebugDraw3D.draw_arrow_ray(contact, y_force / car.mass, 2.5, Color.BLUE, 0.5, true)
	if show_debug: DebugDraw3D.draw_arrow_ray(contact, x_force / car.mass, 1.5, Color.YELLOW, 0.2, true)
	if show_debug: DebugDraw3D.draw_arrow_ray(contact, z_force / car.mass, 1.5, Color.ORANGE, 0.2, true)
