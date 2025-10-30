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

func _ready():
	# Initialize phases array
	phases.resize(harmonics.size())
	for i in range(phases.size()):
		phases[i] = 0.0
	
	# Create and configure the AudioStreamPlayer
	player = $"."
	
	# Create the generator stream
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = mix_rate
	#stream.buffer_length = 0.1
	
	player.stream = stream
	player.play()
	
	# Get the playback object
	playback = player.get_stream_playback()

func _process(_delta):
	var throttle = Input.get_action_strength("throttle")
	var car = $"../../Car"
	player.pitch_scale = lerp(1.0, 4.0, clampf(car.car_speed_ratio, 0.0, 1.0))
	var target_volume = lerp(-45, -40, throttle)
	player.volume_db = lerp(player.volume_db, target_volume, 0.03)
	#print(player.volume_db)
	
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
