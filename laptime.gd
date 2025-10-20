extends Node

var sector1_time: float = 0.0
var sector2_time: float = 0.0
var sector3_time: float = 0.0
var lap_time: float = 0.0

var last_sector: int = 0
var lap_start_time: float = 0.0

func _ready():
	var finish_line = get_node("../finish")
	var sector1 = get_node("../sector1")
	var sector2 = get_node("../sector2")
	
	finish_line.sector_entered.connect(_on_sector_entered)
	sector1.sector_entered.connect(_on_sector_entered)
	sector2.sector_entered.connect(_on_sector_entered)
	
	lap_start_time = Time.get_ticks_msec()

func _physics_process(delta):
	var current_time = Time.get_ticks_msec()
	#$Hud/laps.text = "Current Lap: %s\nLast Lap: %s" % [format_laptime((current_time - lap_start_time) / 1000.0), format_laptime(lap_time)]

func _on_sector_entered(sector_name: String):
	var current_time = Time.get_ticks_msec()

	match sector_name:
		"Sector 1":
			if last_sector == 0 or last_sector == 2:
				sector1_time = (current_time - lap_start_time) / 1000.0
				print("Sector 1 Time: %.3f" % sector1_time)
				last_sector = 1
		"Sector 2":
			if last_sector == 1:
				sector2_time = (current_time - lap_start_time) / 1000.0 - sector1_time
				print("Sector 2 Time: %.3f" % sector2_time)
				last_sector = 2
		"Finish Line":
			if last_sector == 2:
				lap_time = (current_time - lap_start_time) / 1000.0
				print("Lap Time: %.3f" % lap_time)
				
				sector3_time = lap_time - sector1_time - sector2_time
				print("Sector 3 Time: %.3f" % sector3_time)
				lap_start_time = current_time
				last_sector = 0
				
				#$Hud/laps.text = "Last Lap: %s\nCurrent Lap:0:00.000" % format_laptime(lap_time)
			else:
				lap_start_time = current_time
				
	#$Hud/sectors.text = "S1: %s\nS2: %s\nS3: %s" % [format_laptime(sector1_time), format_laptime(sector2_time), format_laptime(sector3_time)]

func format_laptime(t: float) -> String:
	var minutes = int(t / 60)
	var seconds = fmod(t, 60)
	return "%d:%06.3f" % [minutes, seconds]
	
