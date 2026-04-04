extends AudioStreamPlayer

@export var target : RigidBody3D
var target_finished: bool = false

@export var shift_duration: float = 0.2

var current_gear := 1
var shift_timer := 0.0
var pitch_before_shift := 1.0
var target_pitch: float

func _process(delta):
	stream_paused = true if target_finished else false
	var speed_kph = abs(target.car_speed_kph)
	
	var raw_current_gear = int(speed_kph / 100.0) + 1
	var gear_fraction = fmod(speed_kph, 100.0) / 100.0
	
	if raw_current_gear == 1:
		target_pitch = lerp(1.0, 4.0, gear_fraction)
	else:
		target_pitch = lerp(2.0, 4.0, gear_fraction)
		
	if raw_current_gear != current_gear:
		pitch_before_shift = pitch_scale
		current_gear = raw_current_gear
		shift_timer = 0
	
	if shift_timer < shift_duration:
		shift_timer += delta
		pitch_scale = lerp(pitch_before_shift, target_pitch, shift_timer * (1.0 / shift_duration))
	else:
		pitch_scale = target_pitch
