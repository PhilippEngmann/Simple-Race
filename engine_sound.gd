extends Node

var player: AudioStreamPlayer
var current_gear: int = 1
var shift_duration: float = 0.2
var shift_timer: float = 0.0
var pitch_before_shift: float = 1.0

var target_finished: bool = false

func _ready():
	player = $"."
	player.play()

func _process(delta):
	player.stream_paused = true if target_finished else false
	var car = $"../../CarBody"
	var speed_kmh = abs(car.car_velocity * 3.6)
	
	var raw_current_gear = int(speed_kmh / 100.0) + 1
	var gear_fraction = fmod(speed_kmh, 100.0) / 100.0
	
	var target_pitch = 0.0
	if raw_current_gear == 1:
		target_pitch = lerp(1.0, 4.0, gear_fraction)
	else:
		target_pitch = lerp(2.0, 4.0, gear_fraction)
		
	if raw_current_gear != current_gear:
		current_gear = raw_current_gear
		shift_timer = shift_duration
		pitch_before_shift = player.pitch_scale
	
	if shift_timer > 0.0:
		shift_timer -= delta
		var t = clamp(1.0 - (shift_timer / shift_duration), 0.0, 1.0) 
		player.pitch_scale = lerp(pitch_before_shift, target_pitch, t)
	else:
		player.pitch_scale = target_pitch
