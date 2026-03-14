extends Node

@export_category("References")
@export var car: RigidBody3D
@export var current_time_label: Label
@export var lap_time_label: Label
@export var sector_label: Label
@export var speed_label: Label
@export var distance_label: Label

var sector_times: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var expected_checkpoints: Array[String] = ["Sector 1", "Sector 2", "Sector 3", "Sector 4", "Sector 5", "Finish Line"]
var current_checkpoint_index: int = 0

var lap_start_time: float = 0.0
var last_checkpoint_time: float = 0.0
var distance_traveled: float = 0.0

func _ready() -> void:
	var node_names = ["sector1", "sector2", "sector3", "sector4", "sector5", "finish"]
	for node_name in node_names:
		var node = get_node_or_null("../" + node_name)
		if node:
			node.sector_entered.connect(_on_sector_entered)
	
	var current_time = Time.get_ticks_msec()
	lap_start_time = current_time
	last_checkpoint_time = current_time
	
	if sector_label:
		sector_label.text = ""

func _physics_process(delta: float) -> void:
	# 1. RUNNING TIME
	var current_time = Time.get_ticks_msec()
	var running_time = (current_time - lap_start_time) / 1000.0
	
	if current_time_label:
		current_time_label.text = "Current Lap: " + format_laptime(running_time)

	# 2. SPEED AND DISTANCE
	if car:
		var speed_mps := car.linear_velocity.length()
		var speed_kmh := speed_mps * 3.6
		
		if speed_label:
			speed_label.text = "Speed: %d km/h" % int(speed_kmh)
			
		distance_traveled += speed_mps * delta
		if distance_label:
			if distance_traveled < 1000.0:
				distance_label.text = "Distance: %d m" % int(distance_traveled)
			else:
				distance_label.text = "Distance: %.2f km" % (distance_traveled / 1000.0)

func _on_sector_entered(sector_name: String) -> void:
	var current_time = Time.get_ticks_msec()

	# If this is the correct next checkpoint
	if sector_name == expected_checkpoints[current_checkpoint_index]:
		# Calculate exact time taken for just this sector
		var sector_duration = (current_time - last_checkpoint_time) / 1000.0
		sector_times[current_checkpoint_index] = sector_duration
		last_checkpoint_time = current_time
		
		# UPDATE UI: Show only the sector we just crossed
		if sector_label:
			sector_label.text = "Sector %d: %s" % [current_checkpoint_index + 1, format_laptime(sector_duration)]
		
		if sector_name == "Finish Line":
			# Lap Completed!
			var lap_time = (current_time - lap_start_time) / 1000.0
			if lap_time_label:
				lap_time_label.text = "Last Lap: " + format_laptime(lap_time)
				
			start_new_lap(current_time)
		else:
			# Advance to the next sector
			current_checkpoint_index += 1

func start_new_lap(current_time: float) -> void:
	lap_start_time = current_time
	last_checkpoint_time = current_time
	current_checkpoint_index = 0

func format_laptime(t: float) -> String:
	var minutes := int(t / 60)
	var seconds := fmod(t, 60)
	return "%d:%06.3f" % [minutes, seconds]
