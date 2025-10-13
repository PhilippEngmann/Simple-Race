extends RayCast3D
class_name RaycastWheel

@export_group("Wheel properties")
@export var spring_strength := 100.0
@export var spring_damping := 2.0
@export var rest_dist := 0.5
@export var over_extend := 0.0
@export var wheel_radius := 0.4
@export var z_traction := 0.05
@export var z_brake_traction := 0.25

@export_category("Motor")
@export var is_motor := false
@export var is_steer := false
@export var grip_curve : Curve

@export_category("Debug")
@export var show_debug := false

@onready var wheel: Node3D = get_child(0)

var engine_force := 0.0
var grip_factor := 0.0
var is_braking := false

func _ready() -> void:
	target_position.y = -(rest_dist + wheel_radius + over_extend)
	
func apply_wheel_physics(car: RaycastCar) -> void:
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
	
	# TODO: Move to shapecast instead
	wheel.position.y = move_toward(wheel.position.y, -spring_len, 5 * get_physics_process_delta_time()) # Local y position of the wheel
	contact = wheel.global_position # Contact is now the wheel origin point
	var force_pos := contact - car.global_position
	
	## Spring forces
	var spring_force := spring_strength * offset
	var tire_vel := car._get_point_velocity(contact) # Center of the wheel
	var spring_damp_f := spring_damping * global_basis.y.dot(tire_vel)
	
	var y_force := (spring_force - spring_damp_f) * get_collision_normal()
	
	## Acceleration
	if is_motor and car.motor_input:
		var speed_ratio := vel / car.max_speed
		var ac := car.accel_curve.sample_baked(speed_ratio)
		var accel_force := forward_dir * car.acceleration * car.motor_input * ac
		car.apply_force(accel_force, force_pos)
		if show_debug: DebugDraw3D.draw_arrow_ray(contact, accel_force / car.mass, 2.5, Color.RED, 0.5, true)
		
	## Tire X traction (Steering)
	var steering_x_vel := global_basis.x.dot(tire_vel)
	
	grip_factor = absf(steering_x_vel / tire_vel.length())
	var x_traction := grip_curve.sample_baked(grip_factor)
	
	if not car.handbrake_input and grip_factor < 0.2:
		car.is_slipping = false
	if car.handbrake_input:
		x_traction = 0.01
	elif car.is_slipping:
		x_traction = 0.1
		
	var gravity := -car.get_gravity().y
	var x_force := -global_basis.x * steering_x_vel * x_traction * ((car.mass * gravity) / car.total_wheels)
	
	## Tire Z traction (Longitudinal)
	var f_vel := forward_dir.dot(tire_vel)
	var z_friction := z_traction
	if is_braking:
		z_friction = z_brake_traction
	var z_force := global_basis.z * f_vel * z_friction * ((car.mass * gravity) / car.total_wheels)
	
	car.apply_force(y_force, force_pos)
	car.apply_force(x_force, force_pos)
	car.apply_force(z_force, force_pos)
	
	if show_debug: DebugDraw3D.draw_arrow_ray(contact, y_force / car.mass, 2.5, Color.BLUE, 0.5, true)
	if show_debug: DebugDraw3D.draw_arrow_ray(contact, x_force / car.mass, 1.5, Color.YELLOW, 0.2, true)
