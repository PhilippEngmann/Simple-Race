import numpy as np
from scipy.io import wavfile

# --- Parameters (Matching your GDScript) ---
base_hz = 30.0
mix_rate = 44100
drive = 4.0

harmonics = [
    {"multiple": 0.5, "weight": 0.1},
    {"multiple": 1.0, "weight": 0.18},
    {"multiple": 1.5, "weight": 0.16},
    {"multiple": 2.0, "weight": 0.42},
    {"multiple": 2.5, "weight": 0.12},
    {"multiple": 3.0, "weight": 0.08},
    {"multiple": 4.0, "weight": 0.22},
]

# --- Duration and Looping Math ---
# To make a seamless loop, the duration MUST contain an exact integer number of wave cycles.
# At 30 Hz, 1 second equals exactly 30 cycles. 
# endpoint=False ensures we don't duplicate the 0-phase sample at the start and end of the loop.
duration_seconds = 1.0 
t = np.linspace(0, duration_seconds, int(mix_rate * duration_seconds), endpoint=False)

# --- 1. Generate the Mixed Sample ---
mixed_sample = np.zeros_like(t)
total_weight = sum(h["weight"] for h in harmonics)

print("Synthesizing harmonics...")
for h in harmonics:
    frequency = base_hz * h["multiple"]
    amplitude = h["weight"] / total_weight
    # np.sin takes radians, so we multiply by 2 * pi (which is TAU)
    mixed_sample += amplitude * np.sin(2 * np.pi * frequency * t)

# --- 2. Apply Tanh Shaper (Distortion/Drive) ---
print(f"Applying Tanh drive ({drive})...")
k = max(0.0001, drive)
tanh_norm = np.tanh(k)
shaped_audio = np.tanh(k * mixed_sample) / tanh_norm

# --- 3. Convert to 16-bit WAV Format ---
# Audio needs to be mapped from floats (-1.0 to 1.0) to 16-bit integers (-32768 to 32767)
print("Converting to 16-bit PCM...")
audio_16bit = np.int16(shaped_audio * 32767)

# --- 4. Save the File ---
filename = "engine_base.wav"
wavfile.write(filename, mix_rate, audio_16bit)
print(f"Success! Saved as {filename}")