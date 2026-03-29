extends Node

@export_category("References")
@export var car: RigidBody3D
@export var current_time_label: Label
@export var race_time_label: Label
@export var sector_label: Label
@export var speed_label: Label
@export var distance_label: Label
@export var lap_count_label: Label

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

func _ready() -> void:
	var node_names = ["sector1", "sector2", "sector3", "sector4", "sector5", "finish"]
	for node_name in node_names:
		var node = get_node_or_null("../" + node_name)
		if node:
			node.sector_entered.connect(_on_sector_entered)
	
	var current_time = Time.get_ticks_msec()
	race_start_time = current_time
	last_checkpoint_time = current_time
	
	update_lap_label()
	clear_flash_labels()

func _physics_process(delta: float) -> void:
	var current_time = Time.get_ticks_msec()
	
	if hide_labels_time > 0.0 and current_time > hide_labels_time:
		clear_flash_labels()
		hide_labels_time = 0.0 
	
	if not race_finished:
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
	# Ignore sectors if the race is already over
	if race_finished:
		return

	var current_time = Time.get_ticks_msec()

	if sector_name == expected_checkpoints[current_checkpoint_index]:
		var sector_duration = (current_time - last_checkpoint_time) / 1000.0
		var current_race_time = (current_time - race_start_time) / 1000.0
		
		sector_times[current_checkpoint_index] = sector_duration
		last_checkpoint_time = current_time
		
		# Flash Sector Time
		if sector_label:
			sector_label.text = format_laptime(sector_duration)
			sector_label.show()
			
		# Flash total Race Time
		if race_time_label:
			race_time_label.text = format_laptime(current_race_time)
			race_time_label.show()
			
		# Set the timer to hide the labels 2 seconds (2000ms) from now
		hide_labels_time = current_time + 2000.0
		
		if sector_name == "Finish Line":
			if current_lap < total_laps:
				current_lap += 1
				update_lap_label()
				
				# Loop checkpoints back to Sector 1 for the next lap
				current_checkpoint_index = 0 
			else:
				# Race is finished!
				race_finished = true
				
				# Freeze the running clock exactly on the finishing time
				if current_time_label:
					current_time_label.text = format_laptime(current_race_time)
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
