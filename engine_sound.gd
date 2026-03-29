extends Node

var playback: AudioStreamGeneratorPlayback
var base_hz = 30.0
var harmonics = [
	{"multiple": 0.5, "weight": 0.1},
	{"multiple": 1.0, "weight": 0.18},
	{"multiple": 1.5, "weight": 0.16},
	{"multiple": 2.0, "weight": 0.42},
	{"multiple": 2.5, "weight": 0.12},
	{"multiple": 3.0, "weight": 0.08},
	{"multiple": 4.0, "weight": 0.22},
]
var phases = []
var mix_rate = 44100.0
var drive = 4.0
var player: AudioStreamPlayer

# Gears
var current_gear: int = 1
var shift_duration: float = 0.2
var shift_timer: float = 0.0
var pitch_before_shift: float = 1.0

func _ready():
	phases.resize(harmonics.size())
	for i in range(phases.size()):
		phases[i] = 0.0
	
	player = $"."
	
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = mix_rate
	stream.buffer_length = 0.1
	
	player.stream = stream
	player.play()
	
	playback = player.get_stream_playback()

func _process(delta):
	var throttle = Input.get_action_strength("throttle")
	var car = $"../../CarBody"
	var speed_kmh = abs(car.car_velocity * 3.6)
	
	var raw_current_gear = int(speed_kmh / 100.0) + 1
	var gear_fraction = fmod(speed_kmh, 100.0) / 100.0
	
	var target_pitch = 0.0
	if raw_current_gear == 1:
		target_pitch = lerp(1.0, 4.0, gear_fraction) # 1st gear range
	else:
		target_pitch = lerp(2.0, 4.0, gear_fraction) # 2nd+ gear range
		
	if raw_current_gear != current_gear:
		current_gear = raw_current_gear
		shift_timer = shift_duration
		pitch_before_shift = player.pitch_scale
	
	if shift_timer > 0.0:
		shift_timer -= delta
		# t goes from 0.0 to 1.0 over the [shift_duration=0.2] seconds
		var t = clamp(1.0 - (shift_timer / shift_duration), 0.0, 1.0) 
		player.pitch_scale = lerp(pitch_before_shift, target_pitch, t)
	else:
		player.pitch_scale = target_pitch
	
	_fill_buffer()

func _tanh_shaper(x: float, k_in: float) -> float:
	var k = max(0.0001, k_in)
	var norm = tanh(k)
	return tanh(k * x) / norm

func _fill_buffer():
	var frames_available = playback.get_frames_available()
	
	var total_weight = 0.0
	for harmonic in harmonics:
		total_weight += harmonic.weight
	
	for i in range(frames_available):
		var mixed_sample = 0.0
		
		for h in range(harmonics.size()):
			var harmonic = harmonics[h]
			var frequency = base_hz * harmonic.multiple
			var increment = frequency / mix_rate
			
			var sample = sin(phases[h] * TAU) * harmonic.weight
			mixed_sample += sample
			
			phases[h] = fmod(phases[h] + increment, 1.0)
		
		mixed_sample /= total_weight
		var shaped = _tanh_shaper(mixed_sample, drive)
		
		playback.push_frame(Vector2(shaped, shaped))
