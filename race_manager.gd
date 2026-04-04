extends Node

@export_category("References")
@export var car: RigidBody3D
@export var audio_player: AudioStreamPlayer
@export var camera: Camera3D

@export_category("UI References")
@export var current_time_label: Label
@export var race_time_label: Label
@export var sector_label: Label
@export var speed_label: Label
@export var distance_label: Label
@export var lap_count_label: Label
@export var countdown: Label
@export var controls: BoxContainer
@export var medal_result: TextureRect

@export_category("Race Settings")
@export var total_laps: int = 3
@export var start_transform: Transform3D = Transform3D(
	Basis.from_euler(Vector3(0, deg_to_rad(-90), 0)), 
	Vector3(6, 0.25, 0)
)

const MEDAL_TIMES = {
	"AUTHOR": 172.342,
	"GOLD": 177.5,
	"SILVER": 181.0,
	"BRONZE": 184.4
}

enum RaceState { COUNTDOWN, RACING, FINISHED }
var current_state: RaceState = RaceState.COUNTDOWN
var race_id: int = 0
var race_start_time: float

const EXPECTED_CHECKPOINTS: Array[String] = [
	"Sector 1", "Sector 2", "Sector 3", "Sector 4", "Sector 5", "Finish Line"
]
var sector_times: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var current_checkpoint_index: int = 0
var current_lap: int = 1
var last_checkpoint_time: float

var distance_traveled: float = 0.0

var flash_tween: Tween

func _ready() -> void:
	var node_names = ["Sector1", "Sector2", "Sector3", "Sector4", "Sector5", "Finish"]
	for node_name in node_names:
		var node = get_node_or_null("../SectorLines/" + node_name)
		if node:
			node.sector_entered.connect(_on_sector_entered)
	
	reset_race()

func reset_race() -> void:
	race_id += 1 # Invalidate running countdowns
	current_state = RaceState.COUNTDOWN
	
	sector_times.fill(0.0)
	current_checkpoint_index = 0
	current_lap = 1
	distance_traveled = 0.0
	
	audio_player.target_finished = false
	camera.target_finished = false
	camera.global_position = Vector3.ZERO
	# Reset car
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, start_transform)
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(car.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	
	# Reset UI
	current_time_label.text = format_laptime(0.0)
	speed_label.text = "0"
	speed_label.show()
	distance_label.text = "0 m"
	distance_label.show()
	lap_count_label.show()
	medal_result.hide()
	lap_count_label.text = "%d/%d" % [current_lap, total_laps]
	sector_label.hide()
	race_time_label.hide()
	
	var current_race_id = race_id
	car.freeze = true
	countdown.show()
	
	var countdown_steps = [
		{"text": "3", "color": Color(0.0, 0.1, 1.0)},
		{"text": "2", "color": Color(0.0, 0.3, 1.0)},
		{"text": "1", "color": Color(0.0, 0.5, 1.0)},
		{"text": "Go!", "color": Color(0.0, 0.7, 1.0)}
	]
	
	for step in countdown_steps:
		countdown.text = step["text"]
		countdown.add_theme_color_override("font_color", step["color"])
		var countdown_finished = step == countdown_steps[-1]
		if !countdown_finished:
			await get_tree().create_timer(1.0).timeout
		if current_race_id != race_id: return # Abort if reset
	
	current_state = RaceState.RACING
	var current_time = Time.get_ticks_msec()
	race_start_time = current_time
	last_checkpoint_time = current_time
	
	controls.hide()
	car.freeze = false
	
	await get_tree().create_timer(1.0).timeout
	countdown.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		reset_race()

func _physics_process(delta: float) -> void:	
	if current_state == RaceState.RACING:
		var running_time = (Time.get_ticks_msec() - race_start_time) / 1000.0
		current_time_label.text = format_laptime(running_time)
		var speed := car.linear_velocity.length()
		speed_label.text = str(int(speed * 3.6))
		distance_traveled += speed * delta
		distance_label.text = "%d m" % int(distance_traveled)

func _on_sector_entered(sector_name: String) -> void:
	if current_state != RaceState.RACING: return

	if sector_name == EXPECTED_CHECKPOINTS[current_checkpoint_index]:
		var current_time = Time.get_ticks_msec()
		var sector_duration = (current_time - last_checkpoint_time) / 1000.0
		
		sector_times[current_checkpoint_index] = sector_duration
		last_checkpoint_time = current_time
		
		## Flash sector UI
		sector_label.text = format_laptime(sector_duration)
		race_time_label.text = format_laptime(get_current_race_time())
		flash_sector_ui() # Don't inline, to create separate coroutine
		
		if sector_name != "Finish Line":
			current_checkpoint_index += 1
			return
		
		if current_lap < total_laps:
			current_lap += 1
			lap_count_label.text = "%d/%d" % [current_lap, total_laps]
			current_checkpoint_index = 0
			return
		
		# Race finished
		current_state = RaceState.FINISHED
	
		var final_time = get_current_race_time()
		current_time_label.text = format_laptime(final_time)
		
		camera.target_finished = true
		audio_player.target_finished = true
		
		# Determine medal
		if final_time <= MEDAL_TIMES.AUTHOR:
			medal_result.modulate = Color(0.0, 0.502, 0.0)
		elif final_time <= MEDAL_TIMES.GOLD:
			medal_result.modulate = Color(1.0, 0.843, 0.0)
		elif final_time <= MEDAL_TIMES.SILVER:
			medal_result.modulate = Color(0.812, 0.812, 0.922)
		elif final_time <= MEDAL_TIMES.BRONZE:
			medal_result.modulate = Color(0.961, 0.478, 0.133)
		else:
			medal_result.hide()
			return
			
		medal_result.show()
		speed_label.hide()
		distance_label.hide()
		lap_count_label.hide()

func flash_sector_ui():
	sector_label.show()
	race_time_label.show()
	await get_tree().create_timer(2.0).timeout
	sector_label.hide()
	race_time_label.hide()

func get_current_race_time() -> float:
	return (Time.get_ticks_msec() - race_start_time) / 1000.0

func format_laptime(t: float) -> String:
	var minutes := int(t / 60)
	var seconds := fmod(t, 60)
	return "%d:%06.3f" % [minutes, seconds]
