extends Node

@export_category("References")
@export var car: RigidBody3D
@export var audio_player: AudioStreamPlayer
@export var camera: Camera3D
@export var current_time_label: Label
@export var race_time_label: Label
@export var sector_label: Label
@export var speed_label: Label
@export var distance_label: Label
@export var lap_count_label: Label
@export var countdown: Label
@export var controls: BoxContainer

@export_category("Race Settings")
@export var total_laps: int = 3 

var sector_times: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var expected_checkpoints: Array[String] = ["Sector 1", "Sector 2", "Sector 3", "Sector 4", "Sector 5", "Finish Line"]
var current_checkpoint_index: int = 0
var current_lap: int = 1 

var race_start_time: float = 0.0
var last_checkpoint_time: float = 0.0
var distance_traveled: float = 0.0
var hide_labels_time: float = 0.0 
var race_finished: bool = false
var race_started: bool = false

# Added to prevent countdown overlapping if the player spams the reset button
var race_id: int = 0 

func _ready() -> void:
	var node_names = ["sector1", "sector2", "sector3", "sector4", "sector5", "finish"]
	for node_name in node_names:
		var node = get_node_or_null("../" + node_name)
		if node:
			node.sector_entered.connect(_on_sector_entered)
	
	# Start the game initially
	reset_race()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		reset_race()

func reset_race() -> void:
	# Invalidate any running countdowns
	race_id += 1 
	
	# Reset logic variables
	sector_times = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	current_checkpoint_index = 0
	current_lap = 1 
	distance_traveled = 0.0
	hide_labels_time = 0.0 
	race_finished = false
	race_started = false
	
	audio_player.target_finished = false
	
	# Reset Car Physics & Position using PhysicsServer3D
	if car:
		car.freeze = true
		
		var reset_basis = Basis.from_euler(Vector3(0, deg_to_rad(-90), 0))
		var reset_position = Vector3(6, 0.25, 0)
		var reset_transform = Transform3D(reset_basis, reset_position)
		
		camera.global_position = Vector3(0,0,0)
		camera.target_finished = false
		
		# Force the physics server to accept the new transform and zero out velocities
		PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, reset_transform)
		PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
		PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	
	# Reset UI Elements
	if current_time_label:
		current_time_label.text = format_laptime(0.0)
	if speed_label:
		speed_label.text = "0"
		speed_label.show()
	if distance_label:
		distance_label.text = "0 m"
		distance_label.show()
		
	update_lap_label()
	clear_flash_labels()
	
	start_countdown()

func start_countdown() -> void:
	var current_race_id = race_id
	
	if car:
		car.freeze = true
		
	if countdown:
		countdown.show()
		
		countdown.text = "3"
		countdown.add_theme_color_override("font_color", Color(0.0, 0.1, 1.0)) 
		await get_tree().create_timer(1.0).timeout
		if current_race_id != race_id: return # Exit if reset was pressed
		
		countdown.text = "2"
		countdown.add_theme_color_override("font_color", Color(0.0, 0.3, 1.0)) 
		await get_tree().create_timer(1.0).timeout
		if current_race_id != race_id: return
		
		countdown.text = "1"
		countdown.add_theme_color_override("font_color", Color(0.0, 0.5, 1.0)) 
		await get_tree().create_timer(1.0).timeout
		if current_race_id != race_id: return
		
		countdown.text = "Go!"
		countdown.add_theme_color_override("font_color", Color(0.0, 0.7, 1.0)) 
		
	start_race()
	
	if countdown:
		await get_tree().create_timer(1.0).timeout
		if current_race_id != race_id: return
		countdown.hide()

func start_race() -> void:
	var current_time = Time.get_ticks_msec()
	race_start_time = current_time
	last_checkpoint_time = current_time
	race_started = true
	controls.hide()
	
	if car:
		car.freeze = false

func _physics_process(delta: float) -> void:
	var current_time = Time.get_ticks_msec()
	
	if hide_labels_time > 0.0 and current_time > hide_labels_time:
		clear_flash_labels()
		hide_labels_time = 0.0 
	
	if race_started and not race_finished:
		var running_time = (current_time - race_start_time) / 1000.0
		if current_time_label:
			current_time_label.text = format_laptime(running_time)

		if car:
			var speed_mps := car.linear_velocity.length()
			var speed_kmh := speed_mps * 3.6
			
			if speed_label:
				speed_label.text = str(int(speed_kmh))
				
			distance_traveled += speed_mps * delta
			if distance_label:
				distance_label.text = "%d m" % int(distance_traveled)

func _on_sector_entered(sector_name: String) -> void:
	if not race_started or race_finished:
		return

	var current_time = Time.get_ticks_msec()

	if sector_name == expected_checkpoints[current_checkpoint_index]:
		var sector_duration = (current_time - last_checkpoint_time) / 1000.0
		var current_race_time = (current_time - race_start_time) / 1000.0
		
		sector_times[current_checkpoint_index] = sector_duration
		last_checkpoint_time = current_time
		
		if sector_label:
			sector_label.text = format_laptime(sector_duration)
			sector_label.show()
			
		if race_time_label:
			race_time_label.text = format_laptime(current_race_time)
			race_time_label.show()
			
		hide_labels_time = current_time + 2000.0
		
		if sector_name == "Finish Line":
			if current_lap < total_laps:
				current_lap += 1
				update_lap_label()
				
				current_checkpoint_index = 0 
			else:
				race_finished = true
				
				if current_time_label:
					current_time_label.text = format_laptime(current_race_time)
					
				if speed_label: speed_label.hide()
				if distance_label: distance_label.hide()
				
				camera.target_finished = true
				audio_player.target_finished = true
		else:
			current_checkpoint_index += 1

func format_laptime(t: float) -> String:
	var minutes := int(t / 60)
	var seconds := fmod(t, 60)
	return "%d:%06.3f" % [minutes, seconds]

func update_lap_label() -> void:
	if lap_count_label:
		lap_count_label.text = "%d/%d" % [current_lap, total_laps]

func clear_flash_labels() -> void:
	if sector_label:
		sector_label.hide()
	if race_time_label:
		race_time_label.hide()
