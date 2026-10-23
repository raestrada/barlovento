"""
BARLOVENTO — Symphonic Soundtrack Pipeline
Downloads public domain / free orchestral music matching the existing Holst suite
directly into assets/audio/music/ and extracts victory & defeat orchestral cues.
"""

import os
import sys
import urllib.request
import numpy as np
import soundfile as sf

sys.stdout.reconfigure(line_buffering=True)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC_DIR = os.path.join(BASE_DIR, "assets", "audio", "music")
os.makedirs(MUSIC_DIR, exist_ok=True)

TRACKS = [
    {
        "id": "marea",
        "url": "https://upload.wikimedia.org/wikipedia/commons/3/3f/Gustav_Holst_-_the_planets%2C_op._32_-_iv._jupiter%2C_the_bringer_of_jollity.ogg",
        "filename": "music_marea.ogg",
        "desc": "Holst - Jupiter, the Bringer of Jollity (The Free Tide / Marea Libre)",
    },
    {
        "id": "vinculados",
        "url": "https://upload.wikimedia.org/wikipedia/commons/9/97/Holst-_uranus.ogg",
        "filename": "music_vinculados.ogg",
        "desc": "Holst - Uranus, the Magician (The Vinculados / Soul & Resonance)",
    },
    {
        "id": "ace_tactical",
        "url": "https://upload.wikimedia.org/wikipedia/commons/8/89/Holst_The_Planets_Mercury.ogg",
        "filename": "music_ace_tactical.ogg",
        "desc": "Holst - Mercury, the Winged Messenger (Ace Tactical Phase)",
    },
    {
        "id": "climax",
        "url": "https://upload.wikimedia.org/wikipedia/commons/1/17/Antonin_Dvorak_-_symphony_no._9_in_e_minor_%27from_the_new_world%27%2C_op._95_-_iv._allegro_con_fuoco.ogg",
        "filename": "music_climax.ogg",
        "desc": "Dvorak - New World Symphony IV Allegro con fuoco (Climax / Act 3)",
    },
]

def apply_fade(audio: np.ndarray, sr: int, fade_in_s: float, fade_out_s: float) -> np.ndarray:
    n = len(audio)
    out = audio.copy()
    fi = int(fade_in_s * sr)
    fo = int(fade_out_s * sr)
    if fi > 0 and fi <= n:
        curve = 0.5 * (1.0 - np.cos(np.pi * np.linspace(0, 1, fi)))
        out[:fi] *= curve[:, None]
    if fo > 0 and fo <= n:
        curve = 0.5 * (1.0 + np.cos(np.pi * np.linspace(0, 1, fo)))
        out[-fo:] *= curve[:, None]
    return out

def process_all():
    print("=== BARLOVENTO Soundtrack Download & Integration ===")

    for t in TRACKS:
        dest_path = os.path.join(MUSIC_DIR, t["filename"])
        print(f"--> Downloading {t['desc']}...")
        req = urllib.request.Request(
            t["url"],
            headers={"User-Agent": "BarloventoMusicDownloader/1.0 (contact@barlovento.game)"}
        )
        with urllib.request.urlopen(req) as resp, open(dest_path, "wb") as f_out:
            f_out.write(resp.read())
        
        info = sf.info(dest_path)
        print(f"    Saved: {t['filename']} ({os.path.getsize(dest_path)} bytes, {info.duration:.1f}s, {info.samplerate}Hz, {info.channels}ch)")

    # 1. Generate Victory Fanfare WAV (from Jupiter's majestic brass climax)
    marea_path = os.path.join(MUSIC_DIR, "music_marea.ogg")
    if os.path.exists(marea_path):
        print("--> Generating music_victory.wav (Triumphant Brass Fanfare)...")
        j_audio, j_sr = sf.read(marea_path)
        end_idx = len(j_audio)
        start_idx = max(0, end_idx - int(18.0 * j_sr))
        fanfare = j_audio[start_idx:end_idx].copy()
        fanfare = apply_fade(fanfare, j_sr, 0.3, 3.0)
        v_peak = np.max(np.abs(fanfare))
        if v_peak > 1e-4:
            fanfare = (fanfare / v_peak) * 0.92
        vic_path = os.path.join(MUSIC_DIR, "music_victory.wav")
        sf.write(vic_path, (fanfare * 32767).astype(np.int16), j_sr, format="WAV")
        print(f"    Saved victory fanfare: {vic_path} ({len(fanfare)/j_sr:.1f}s, {os.path.getsize(vic_path)} bytes)")

    # 2. Generate Defeat Cue WAV (Solemn brass lament from Dvorak opening)
    climax_path = os.path.join(MUSIC_DIR, "music_climax.ogg")
    if os.path.exists(climax_path):
        print("--> Generating music_defeat.wav (Solemn Flagship Down Cue)...")
        d_audio, d_sr = sf.read(climax_path)
        defeat_len = int(11.5 * d_sr)
        defeat_clip = d_audio[:defeat_len].copy()
        defeat_clip = apply_fade(defeat_clip, d_sr, 0.1, 3.2)
        d_peak = np.max(np.abs(defeat_clip))
        if d_peak > 1e-4:
            defeat_clip = (defeat_clip / d_peak) * 0.88
        def_path = os.path.join(MUSIC_DIR, "music_defeat.wav")
        sf.write(def_path, (defeat_clip * 32767).astype(np.int16), d_sr, format="WAV")
        print(f"    Saved defeat stinger: {def_path} ({len(defeat_clip)/d_sr:.1f}s, {os.path.getsize(def_path)} bytes)")

    print("\n[SUCCESS] Entire BARLOVENTO Symphonic Soundtrack Suite is ready on disk!")

if __name__ == "__main__":
    process_all()
