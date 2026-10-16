"""
BARLOVENTO — Cinematic Sound FX Synthesizer
Generates AAA Hollywood-grade sound design using advanced DSP (SciPy & NumPy):
1. cinematic_title_braam.wav: Dramatic Hollywood trailer brass horn + sub-bass boom + metallic impact.
2. laser_naval_heavy.wav: Massive capital ship spinal cannon / plasma beam discharge.
3. laser_lance_pulse.wav: Vinculados crystalline beam lance / psychic energy pulse.
4. laser_broadside_cannon.wav: Free Tide brass broadside cannon with plasma crackle.
5. explosion_cinematic_shockwave.wav: Deep space hull breach shockwave with sub-bass rumble.
"""

import os
import math
import numpy as np
from scipy.io import wavfile
from scipy import signal

SAMPLE_RATE = 44100

def apply_stereo_reverb(mono_audio, decay_time=2.5, sample_rate=SAMPLE_RATE, wet=0.35):
    """Generates an algorithmic stereo impulse response and convolves with audio."""
    n_samples = int(decay_time * sample_rate)
    t = np.linspace(0, decay_time, n_samples, endpoint=False)
    
    # Left and right diffuse impulse responses
    noise_l = np.random.uniform(-1, 1, n_samples)
    noise_r = np.random.uniform(-1, 1, n_samples)
    
    decay = np.exp(-3.5 * t / decay_time)
    ir_l = noise_l * decay
    ir_r = noise_r * decay
    
    # Early reflections
    early_delays_l = [int(0.015 * sample_rate), int(0.035 * sample_rate), int(0.065 * sample_rate)]
    early_delays_r = [int(0.022 * sample_rate), int(0.048 * sample_rate), int(0.078 * sample_rate)]
    
    for d, g in zip(early_delays_l, [0.4, 0.25, 0.15]):
        if d < n_samples:
            ir_l[d] += g
    for d, g in zip(early_delays_r, [0.4, 0.25, 0.15]):
        if d < n_samples:
            ir_r[d] += g
            
    # Convolve
    rev_l = signal.fftconvolve(mono_audio, ir_l)[:len(mono_audio)]
    rev_r = signal.fftconvolve(mono_audio, ir_r)[:len(mono_audio)]
    
    # Normalize reverb
    rev_max = max(np.max(np.abs(rev_l)), np.max(np.abs(rev_r)), 1e-6)
    rev_l /= rev_max
    rev_r /= rev_max
    
    out_l = (1.0 - wet) * mono_audio + wet * rev_l
    out_r = (1.0 - wet) * mono_audio + wet * rev_r
    
    peak = max(np.max(np.abs(out_l)), np.max(np.abs(out_r)), 1e-6)
    return out_l / peak, out_r / peak

def generate_title_braam():
    """Generates the iconic dramatic movie title BRAAAM trailer hit."""
    duration = 5.2
    n_samples = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n_samples, endpoint=False)
    
    # 1. Anvil / Metallic impact transient at t = 0 (0 to 0.4s)
    metallic = np.zeros(n_samples)
    for freq, weight in [(780, 0.3), (1240, 0.25), (1850, 0.2), (2650, 0.15), (3400, 0.1)]:
        metallic += weight * np.sin(2 * np.pi * freq * t) * np.exp(-22 * t)
    
    # 2. Sub-bass punch: 110 Hz dropping to 36 Hz
    pitch_env = 74.0 * np.exp(-14 * t) + 36.0
    phase_sub = 2 * np.pi * np.cumsum(pitch_env) / SAMPLE_RATE
    sub_bass = np.sin(phase_sub) * np.exp(-1.4 * t)
    sub_bass = np.tanh(2.5 * sub_bass) # Saturation harmonics
    
    # 3. Low Brass Horn Choir ("BRAAAM"):
    # Detuned contrabass trombone & French horns on low D (36.7 Hz / 73.4 Hz)
    f_brass = 36.7
    brass = np.zeros(n_samples)
    detunes = [-0.015, -0.008, 0.0, 0.008, 0.015]
    
    for det in detunes:
        fb = f_brass * (1.0 + det)
        # Sawtooth harmonic series for raspy brass cuivré
        saw = np.zeros(n_samples)
        for h in range(1, 14):
            saw += (1.0 / h) * np.sin(2 * np.pi * (fb * h) * t)
        brass += saw / len(detunes)
        
    # Brass envelope: fast attack (25ms), sustained growl (1.8s), long cinematic decay
    brass_env = np.where(t < 0.025, t / 0.025, np.exp(-0.85 * (t - 0.025)))
    brass = brass * brass_env
    
    # Drive brass into aggressive soft saturation (Zimmer style)
    brass = np.tanh(3.2 * brass)
    
    # Dynamic low-pass filter: sweeps down as horn blast decays
    b, a = signal.butter(4, 1400 / (SAMPLE_RATE / 2), btype='low')
    brass = signal.lfilter(b, a, brass)
    
    # Timpani slam (thump)
    timpani = np.sin(2 * np.pi * (95 * np.exp(-25 * t) + 45) * t) * np.exp(-6 * t)
    
    # Mix components
    mix = 0.45 * metallic + 0.65 * sub_bass + 0.85 * brass + 0.50 * timpani
    mix = np.tanh(1.2 * mix)
    
    # Apply long stereo cinematic hall reverb (4.0s decay)
    out_l, out_r = apply_stereo_reverb(mix, decay_time=4.2, wet=0.42)
    
    # Final smooth envelope
    fade_len = int(0.6 * SAMPLE_RATE)
    fade_curve = np.linspace(1.0, 0.0, fade_len)
    out_l[-fade_len:] *= fade_curve
    out_r[-fade_len:] *= fade_curve
    
    return np.column_stack((out_l, out_r))

def generate_naval_heavy_laser():
    """Heavy capital ship plasma / railgun cannon."""
    duration = 1.6
    n_samples = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n_samples, endpoint=False)
    
    # 1. High-frequency plasma ionization whip (chirp from 2400 Hz down to 140 Hz in 60ms)
    freq_sweep = 2260.0 * np.exp(-38 * t) + 140.0
    phase_sweep = 2 * np.pi * np.cumsum(freq_sweep) / SAMPLE_RATE
    laser_whip = np.sin(phase_sweep) * np.exp(-12 * t)
    
    # 2. Heavy naval sub-bass discharge thump
    sub_thump = np.sin(2 * np.pi * (160 * np.exp(-28 * t) + 48) * t) * np.exp(-5 * t)
    
    # 3. Distorted electrical plasma discharge (FM synth)
    carrier_f = 180.0
    mod_f = 85.0
    mod_index = 4.0 * np.exp(-8 * t)
    plasma_fm = np.sin(2 * np.pi * carrier_f * t + mod_index * np.sin(2 * np.pi * mod_f * t)) * np.exp(-4 * t)
    plasma_fm = np.tanh(2.5 * plasma_fm)
    
    # 4. Ionized gas hiss (bandpassed noise)
    noise = np.random.uniform(-1, 1, n_samples)
    b, a = signal.butter(3, [400 / (SAMPLE_RATE / 2), 3200 / (SAMPLE_RATE / 2)], btype='band')
    hiss = signal.lfilter(b, a, noise) * np.exp(-18 * t)
    
    mix = 0.55 * laser_whip + 0.70 * sub_thump + 0.60 * plasma_fm + 0.35 * hiss
    mix = np.tanh(1.4 * mix)
    
    out_l, out_r = apply_stereo_reverb(mix, decay_time=1.5, wet=0.30)
    return np.column_stack((out_l, out_r))

def generate_pulse_laser():
    """Vinculados rapid energy beam / lance pulse."""
    duration = 1.2
    n_samples = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n_samples, endpoint=False)
    
    # Crystalline high pitch sweep with phase modulation
    freq_sweep = 3600.0 * np.exp(-42 * t) + 320.0
    phase_sweep = 2 * np.pi * np.cumsum(freq_sweep) / SAMPLE_RATE
    pulse = np.sin(phase_sweep + 1.8 * np.sin(2 * np.pi * 180 * t)) * np.exp(-9 * t)
    
    # Punch
    punch = np.sin(2 * np.pi * (240 * np.exp(-32 * t) + 65) * t) * np.exp(-10 * t)
    
    mix = 0.75 * pulse + 0.55 * punch
    mix = np.tanh(1.5 * mix)
    
    out_l, out_r = apply_stereo_reverb(mix, decay_time=1.1, wet=0.28)
    return np.column_stack((out_l, out_r))

def generate_broadside_cannon():
    """Free Tide brass broadside cannon: mechanical clank + hollow boom + plasma sizzle."""
    duration = 1.5
    n_samples = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n_samples, endpoint=False)
    
    # Muzzle blast noise crack
    noise = np.random.uniform(-1, 1, n_samples)
    b, a = signal.butter(2, [250 / (SAMPLE_RATE / 2), 2200 / (SAMPLE_RATE / 2)], btype='band')
    crack = signal.lfilter(b, a, noise) * np.exp(-24 * t)
    
    # Wooden/brass resonant boom
    boom = np.sin(2 * np.pi * (140 * np.exp(-18 * t) + 52) * t) * np.exp(-4.5 * t)
    
    # Plasma whoosh
    whoosh_f = 950 * np.exp(-15 * t) + 200
    whoosh = np.sin(2 * np.pi * np.cumsum(whoosh_f) / SAMPLE_RATE) * np.exp(-7 * t)
    
    mix = 0.65 * crack + 0.70 * boom + 0.40 * whoosh
    mix = np.tanh(1.3 * mix)
    
    out_l, out_r = apply_stereo_reverb(mix, decay_time=1.6, wet=0.32)
    return np.column_stack((out_l, out_r))

def generate_deep_shockwave_explosion():
    """Deep space naval ship explosion with pressure wave."""
    duration = 3.6
    n_samples = int(duration * SAMPLE_RATE)
    t = np.linspace(0, duration, n_samples, endpoint=False)
    
    # 1. Shockwave sub-bass thump (32 - 75 Hz)
    sub = np.sin(2 * np.pi * (85 * np.exp(-8 * t) + 34) * t) * np.exp(-1.5 * t)
    sub = np.tanh(2.2 * sub)
    
    # 2. Violent hull tear / debris burst (fractured noise)
    noise = np.random.uniform(-1, 1, n_samples)
    b, a = signal.butter(3, 850 / (SAMPLE_RATE / 2), btype='low')
    rumble = signal.lfilter(b, a, noise) * np.exp(-1.8 * t)
    
    # 3. Initial explosive detonation crack (0 to 80ms)
    detonation = noise * np.exp(-35 * t)
    
    mix = 0.50 * detonation + 0.75 * sub + 0.65 * rumble
    mix = np.tanh(1.4 * mix)
    
    out_l, out_r = apply_stereo_reverb(mix, decay_time=3.2, wet=0.45)
    return np.column_stack((out_l, out_r))

def save_wav(filename, audio_data):
    # Ensure -1.0 to 1.0 range, scale to 16-bit integer
    peak = np.max(np.abs(audio_data))
    if peak > 0:
        audio_norm = audio_data / peak * 0.95
    else:
        audio_norm = audio_data
    int_data = (audio_norm * 32767).astype(np.int16)
    wavfile.write(filename, SAMPLE_RATE, int_data)
    print(f"Generated: {filename} ({len(int_data) / SAMPLE_RATE:.2f}s, {int_data.shape})")

if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio", "sfx")
    os.makedirs(out_dir, exist_ok=True)
    
    save_wav(os.path.join(out_dir, "cinematic_title_braam.wav"), generate_title_braam())
    save_wav(os.path.join(out_dir, "laser_naval_heavy.wav"), generate_naval_heavy_laser())
    save_wav(os.path.join(out_dir, "laser_lance_pulse.wav"), generate_pulse_laser())
    save_wav(os.path.join(out_dir, "laser_broadside_cannon.wav"), generate_broadside_cannon())
    save_wav(os.path.join(out_dir, "explosion_cinematic_shockwave.wav"), generate_deep_shockwave_explosion())
    print("All cinematic SFX generated successfully!")
