"""
BARLOVENTO — Professional Cinema Audio Mastering Pipeline (v2 Seamless Edition)
Eliminates abrupt audio cuts between Part 1 (Factions/Calm), Part 2 (Battle), and Part 3 (Logo Finale)
by weaving a 3.5-second orchestral crossfade + Gundam thruster flyby into the battle, and a continuous
symphonic & resonance shockwave riser into the Frame 642 Title Impact.
"""

import os
import shutil
import numpy as np
from scipy.io import wavfile
from scipy import signal

SR = 48000
FPS = 24
TOTAL_FRAMES = 760
TOTAL_SEC = TOTAL_FRAMES / FPS
TOTAL_SAMPLES = int(TOTAL_SEC * SR)

def load_wav_stereo(path, target_sr=SR):
    sr, data = wavfile.read(path)
    if data.dtype == np.int16:
        fl = data.astype(np.float32) / 32768.0
    elif data.dtype == np.int32:
        fl = data.astype(np.float32) / 2147483648.0
    else:
        fl = data.astype(np.float32)
    if fl.ndim == 1:
        fl = np.column_stack((fl, fl))
    elif fl.shape[1] > 2:
        fl = fl[:, :2]
    if sr != target_sr:
        new_len = int(len(fl) * target_sr / sr)
        fl = signal.resample(fl, new_len, axis=0)
    return fl

def make_fade_env(length, fade_in_sec, fade_out_sec):
    env = np.ones(length, dtype=np.float32)
    fi = min(length, int(fade_in_sec * SR))
    fo = min(length, int(fade_out_sec * SR))
    if fi > 0:
        env[:fi] = 0.5 * (1.0 - np.cos(np.pi * np.linspace(0, 1, fi)))
    if fo > 0:
        env[-fo:] *= 0.5 * (1.0 + np.cos(np.pi * np.linspace(0, 1, fo)))
    return env[:, None]

def add_clip(master, clip, start_sec, gain_l=1.0, gain_r=1.0):
    start_idx = int(start_sec * SR)
    if start_idx >= len(master) or start_idx < 0:
        return
    end_idx = min(len(master), start_idx + len(clip))
    seg_len = end_idx - start_idx
    master[start_idx:end_idx, 0] += clip[:seg_len, 0] * gain_l
    master[start_idx:end_idx, 1] += clip[:seg_len, 1] * gain_r

def norm(x):
    if len(x) == 0:
        return x
    m = np.max(np.abs(x))
    return x / m if m > 1e-6 else x

def upgrade_master_audio_transitions():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    audio_dir = os.path.join(base_dir, "assets", "audio")
    master_path = os.path.join(audio_dir, "master_intro_mix.wav")
    backup_path = os.path.join(audio_dir, "master_intro_mix_v1_backup.wav")

    if not os.path.exists(backup_path):
        shutil.copyfile(master_path, backup_path)

    existing = load_wav_stereo(backup_path)
    master = existing.copy()

    # Extract clean Holst Venus orchestral phrase (13.5s..18.0s) and Mars phrase (22.3s..26.3s)
    venus_tail = norm(existing[int(13.8 * SR):int(18.0 * SR)].copy())
    mars_lead = norm(existing[int(22.2 * SR):int(26.4 * SR)].copy())

    # Gently duck the abrupt hard-cut transition region (19.8s..22.4s) so the crossfade takes over seamlessly
    idx_a1, idx_a2 = int(19.8 * SR), int(22.4 * SR)
    t_a = np.linspace(0, 1, idx_a2 - idx_a1)
    duck_a = 1.0 - 0.58 * (np.sin(np.pi * t_a) ** 2)
    master[idx_a1:idx_a2] *= duck_a[:, None]

    # 1. SEAMLESS BRIDGE 1 (18.8s -> 23.2s, Frames 451 -> 556):
    # Crossfade Holst's Venus strings into the rising Mars brass & timpani
    venus_tail_env = make_fade_env(len(venus_tail), 0.9, 2.3)
    add_clip(master, venus_tail * venus_tail_env * 0.48, 18.8)

    mars_lead_env = make_fade_env(len(mars_lead), 2.3, 0.9)
    add_clip(master, mars_lead * mars_lead_env * 0.56, 19.2)

    # Agile Gundam Squadron High-G Vernier Flyby Whoosh (Frames 502 -> 542, 20.9s -> 22.6s)
    shock_wav = os.path.join(audio_dir, "sfx", "explosion_cinematic_shockwave.wav")
    if os.path.exists(shock_wav):
        air_rush = load_wav_stereo(shock_wav)
        flyby = norm(air_rush[:int(1.8 * SR)].copy())
        # Bandpass filter (180Hz - 3200Hz) for sleek plasma vernier thruster rush
        sos = signal.butter(3, [180, 3200], btype='bandpass', fs=SR, output='sos')
        flyby = norm(signal.sosfilt(sos, flyby, axis=0))
        flyby_env = make_fade_env(len(flyby), 0.55, 0.65)
        pan = np.linspace(0.15, 0.88, len(flyby))[:, None]
        flyby_st = np.column_stack((flyby[:, 0] * (1.2 - 0.6 * pan[:, 0]), flyby[:, 1] * (0.4 + 0.8 * pan[:, 0])))
        add_clip(master, flyby_st * flyby_env * 0.46, 20.85)

    # 2. SEAMLESS BRIDGE 2 (25.0s -> 28.0s, Frames 600 -> 672):
    # Eliminate the unnatural 0.25s silence hole at 26.45s-26.75s!
    # Build a continuous 1.8s orchestral & resonance shockwave crescendo peaking directly into Frame 642 (26.75s)
    mars_crescendo = norm(existing[int(23.2 * SR):int(26.2 * SR)].copy())
    cresc_env = make_fade_env(len(mars_crescendo), 1.35, 1.05)
    add_clip(master, mars_crescendo * cresc_env * 0.64, 24.85)

    if os.path.exists(shock_wav):
        shock = norm(load_wav_stereo(shock_wav))
        riser_len = int(1.45 * SR)
        riser = shock[:riser_len][::-1].copy()
        riser *= make_fade_env(riser_len, 0.85, 0.02)
        add_clip(master, riser * 0.56, 26.75 - 1.45)

        bloom = shock[:int(2.2 * SR)].copy()
        bloom *= make_fade_env(len(bloom), 0.02, 1.45)
        add_clip(master, bloom * 0.48, 26.68)

    # Soft-knee mastering limiter & normalization
    master = np.tanh(master * 1.06)
    peak = np.max(np.abs(master))
    if peak > 0:
        master = (master / peak) * 0.94

    wavfile.write(master_path, SR, (master * 32767).astype(np.int16))
    print(f"==> Seamless Master Audio written to {master_path} ({len(master)/SR:.2f}s)")

if __name__ == "__main__":
    upgrade_master_audio_transitions()
