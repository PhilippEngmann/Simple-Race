extends Node

@export_category("References")
@export var car: RigidBody3D
@export var current_time_label: Label
@export var lap_time_label: Label
@export var sector_label: Label
@export var speed_label: Label
@export var distance_label: Label

var sector1_time: float = 0.0
var sector2_time: float = 0.0
var sector3_time: float = 0.0
var lap_time: float = 0.0

var last_sector: int = 0
var lap_start_time: float = 0.0
var distance_traveled: float = 0.0

func _ready() -> void:
	# Assuming these nodes are structured the same way as your original script
	var finish_line = get_node("../finish")
	var sector1 = get_node("../sector1")
	var sector2 = get_node("../sector2")
	
	finish_line.sector_entered.connect(_on_sector_entered)
	sector1.sector_entered.connect(_on_sector_entered)
	sector2.sector_entered.connect(_on_sector_entered)
	
	lap_start_time = Time.get_ticks_msec()

func _physics_process(delta: float) -> void:
	# 1. RUNNING TIME
	var current_time = Time.get_ticks_msec()
	var running_time = (current_time - lap_start_time) / 1000.0
	
	if current_time_label:
		current_time_label.text = "Current Lap: " + format_laptime(running_time)

	# 2. SPEED AND DISTANCE
	if car:
		# Get speed in meters per second
		var speed_mps := car.linear_velocity.length()
		
		# Convert to km/h
		var speed_kmh := speed_mps * 3.6
		if speed_label:
			speed_label.text = "Speed: %d km/h" % int(speed_kmh)
			
		# Accumulate distance (speed * time = distance)
		distance_traveled += speed_mps * delta
		if distance_label:
			if distance_traveled < 1000.0:
				distance_label.text = "Distance: %d m" % int(distance_traveled)
			else:
				# Show kilometers if over 1000 meters
				distance_label.text = "Distance: %.2f km" % (distance_traveled / 1000.0)

func _on_sector_entered(sector_name: String) -> void:
	var current_time = Time.get_ticks_msec()

	match sector_name:
		"Sector 1":
			if last_sector == 0 or last_sector == 2:
				sector1_time = (current_time - lap_start_time) / 1000.0
				last_sector = 1
		"Sector 2":
			if last_sector == 1:
				sector2_time = (current_time - lap_start_time) / 1000.0 - sector1_time
				last_sector = 2
		"Finish Line":
			if last_sector == 2:
				lap_time = (current_time - lap_start_time) / 1000.0
				sector3_time = lap_time - sector1_time - sector2_time
				lap_start_time = current_time
				last_sector = 0
				
				# Update Lap Time UI
				if lap_time_label:
					lap_time_label.text = "Last Lap: " + format_laptime(lap_time)
			else:
				# Crossed finish line without hitting all sectors (restarted lap)
				lap_start_time = current_time
				
	# Update Sector Times UI
	if sector_label:
		sector_label.text = "S1: %s\nS2: %s\nS3: %s" % [
			format_laptime(sector1_time), 
			format_laptime(sector2_time), 
			format_laptime(sector3_time)
		]

func format_laptime(t: float) -> String:
	var minutes := int(t / 60)
	var seconds := fmod(t, 60)
	return "%d:%06.3f" % [minutes, seconds]
