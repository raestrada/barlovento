"""
BARLOVENTO — AAA Introductory Cinematic Video Renderer
Uses Blender (headless) to composite and render the official opening cinematic prologue.
Outputs an Ogg Theora video (assets/video/intro.ogv) ready for Godot 4 VideoStreamPlayer.
"""

import os
import sys
import bpy

def build_intro_cinematic(output_path: str):
    scene = bpy.context.scene
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.fps = 24

    total_frames = 800
    scene.frame_start = 1
    scene.frame_end = total_frames

    scene.render.image_settings.file_format = 'FFMPEG'
    scene.render.ffmpeg.format = 'OGG'
    scene.render.ffmpeg.codec = 'THEORA'
    scene.render.ffmpeg.audio_codec = 'VORBIS'
    scene.render.ffmpeg.video_bitrate = 6000
    scene.render.filepath = os.path.abspath(output_path)

    # Ensure sequence editor exists and clear existing strips
    if not scene.sequence_editor:
        scene.sequence_editor_create()
    se = scene.sequence_editor
    for s in list(se.sequences):
        se.sequences.remove(s)

    # Base black strip across full duration
    black = se.sequences.new_effect(
        name="BlackBase",
        type='COLOR',
        channel=1,
        frame_start=1,
        frame_end=total_frames + 1
    )
    black.color = (0.005, 0.008, 0.015)

    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    def asset_p(rel: str) -> str:
        return os.path.join(base_dir, rel.replace('/', os.sep))

    shots = [
        {
            "id": "StarSea",
            "file": asset_p("assets/environments/star_sea_skybox.jpg"),
            "start": 1,
            "end": 120,
            "fade_in": 20,
            "fade_out": 20,
            "zoom_start": 1.0,
            "zoom_end": 1.08,
            "text_header": "PROLOGUE",
            "text_main": "In the beginning, the void was not empty.\nIt was the Star Sea... an ocean of dark energy called the Éther."
        },
        {
            "id": "Acero",
            "file": asset_p("assets/ships/acero/dreadnought_concept.png"),
            "start": 110,
            "end": 230,
            "fade_in": 20,
            "fade_out": 20,
            "zoom_start": 1.0,
            "zoom_end": 1.07,
            "text_header": "THE ARMADA OF ACERO",
            "text_main": "An empire of steel that burned the wind as fuel,\nforging colossal battle lines to tame the deep."
        },
        {
            "id": "Vinculados",
            "file": asset_p("assets/ships/vinculados/suit_concept.png"),
            "start": 220,
            "end": 340,
            "fade_in": 20,
            "fade_out": 20,
            "zoom_start": 1.0,
            "zoom_end": 1.08,
            "text_header": "THE VINCULADOS",
            "text_main": "Mystic pilots bonded to the vacuum by neural resonance,\nsinging in harmony with the soul of the void."
        },
        {
            "id": "FreeTide",
            "file": asset_p("assets/ships/marea-libre/galleon_concept.png"),
            "start": 330,
            "end": 450,
            "fade_in": 20,
            "fade_out": 20,
            "zoom_start": 1.0,
            "zoom_end": 1.08,
            "text_header": "THE FREE TIDE",
            "text_main": "Nomad corsairs who unfurled quantum sails on wooden hulls,\nriding the living breath of creation."
        },
        {
            "id": "TheCalm",
            "file": asset_p("assets/environments/space_backdrop.png"),
            "start": 440,
            "end": 560,
            "fade_in": 20,
            "fade_out": 20,
            "zoom_start": 1.02,
            "zoom_end": 1.10,
            "text_header": "THE CALM",
            "text_main": "Then came the silence. A creeping frost of dead vacuum.\nWhere the Calm arrives, the wind dies... fleets are becalmed."
        },
        {
            "id": "Battle",
            "file": asset_p("assets/splash/cover.png"),
            "start": 550,
            "end": 670,
            "fade_in": 20,
            "fade_out": 20,
            "zoom_start": 1.0,
            "zoom_end": 1.08,
            "text_header": "THE LAST CURRENT",
            "text_main": "Three armadas clash for the surviving currents.\nIn the dying sea... to drift is to die."
        },
        {
            "id": "TitleLogo",
            "file": asset_p("assets/brand/logo.png"),
            "start": 660,
            "end": 800,
            "fade_in": 25,
            "fade_out": 30,
            "zoom_start": 0.94,
            "zoom_end": 1.02,
            "text_header": "BARLOVENTO",
            "text_main": "EL ÚLTIMO VIENTO\nTake the helm... and fight for the weather gauge."
        }
    ]

    channel_layer = 2
    for shot in shots:
        if not os.path.exists(shot["file"]):
            print(f"Warning: File not found: {shot['file']}")
            continue

        start_f = shot["start"]
        end_f = shot["end"]
        duration = end_f - start_f + 1

        img_strip = se.sequences.new_image(
            name=f"Img_{shot['id']}",
            filepath=shot["file"],
            channel=channel_layer,
            frame_start=start_f
        )
        img_strip.frame_final_duration = duration
        img_strip.blend_type = 'ALPHA_OVER'

        # Fade in & out
        img_strip.blend_alpha = 0.0
        img_strip.keyframe_insert("blend_alpha", frame=start_f)
        img_strip.blend_alpha = 1.0
        img_strip.keyframe_insert("blend_alpha", frame=start_f + shot["fade_in"])
        img_strip.blend_alpha = 1.0
        img_strip.keyframe_insert("blend_alpha", frame=end_f - shot["fade_out"])
        img_strip.blend_alpha = 0.0
        img_strip.keyframe_insert("blend_alpha", frame=end_f)

        # Subtle Ken Burns zoom
        if hasattr(img_strip, "transform"):
            img_strip.transform.scale_x = shot["zoom_start"]
            img_strip.transform.scale_y = shot["zoom_start"]
            img_strip.transform.keyframe_insert("scale_x", frame=start_f)
            img_strip.transform.keyframe_insert("scale_y", frame=start_f)

            img_strip.transform.scale_x = shot["zoom_end"]
            img_strip.transform.scale_y = shot["zoom_end"]
            img_strip.transform.keyframe_insert("scale_x", frame=end_f)
            img_strip.transform.keyframe_insert("scale_y", frame=end_f)

        # Header Title
        txt_header = se.sequences.new_effect(
            name=f"TxtH_{shot['id']}",
            type='TEXT',
            channel=channel_layer + 1,
            frame_start=start_f + 10,
            frame_end=end_f - 10
        )
        txt_header.text = shot["text_header"]
        txt_header.font_size = 38
        txt_header.align_x = 'CENTER'
        txt_header.align_y = 'BOTTOM'
        txt_header.location = (0.5, 0.22)
        txt_header.color = (0.35, 0.90, 1.0, 1.0)
        txt_header.use_shadow = True
        txt_header.shadow_color = (0.0, 0.0, 0.0, 0.95)
        txt_header.blend_alpha = 0.0
        txt_header.keyframe_insert("blend_alpha", frame=start_f + 10)
        txt_header.blend_alpha = 1.0
        txt_header.keyframe_insert("blend_alpha", frame=start_f + 25)
        txt_header.blend_alpha = 1.0
        txt_header.keyframe_insert("blend_alpha", frame=end_f - 25)
        txt_header.blend_alpha = 0.0
        txt_header.keyframe_insert("blend_alpha", frame=end_f - 10)

        # Main Subtitle / Narrative sentence
        txt_main = se.sequences.new_effect(
            name=f"TxtM_{shot['id']}",
            type='TEXT',
            channel=channel_layer + 2,
            frame_start=start_f + 15,
            frame_end=end_f - 15
        )
        txt_main.text = shot["text_main"]
        txt_main.font_size = 26
        txt_main.align_x = 'CENTER'
        txt_main.align_y = 'BOTTOM'
        txt_main.location = (0.5, 0.10)
        txt_main.color = (0.92, 0.94, 0.98, 1.0)
        txt_main.use_shadow = True
        txt_main.shadow_color = (0.0, 0.0, 0.0, 0.95)
        txt_main.blend_alpha = 0.0
        txt_main.keyframe_insert("blend_alpha", frame=start_f + 15)
        txt_main.blend_alpha = 1.0
        txt_main.keyframe_insert("blend_alpha", frame=start_f + 30)
        txt_main.blend_alpha = 1.0
        txt_main.keyframe_insert("blend_alpha", frame=end_f - 30)
        txt_main.blend_alpha = 0.0
        txt_main.keyframe_insert("blend_alpha", frame=end_f - 15)

        # Alternate channel layers to avoid overlap collisions
        channel_layer = 5 if channel_layer == 2 else 2

    # Audio track: Loop ambient hum across the timeline
    audio_path = asset_p("assets/audio/ambient_hum.ogg")
    if os.path.exists(audio_path):
        for audio_start in [1, 385]:
            snd = se.sequences.new_sound(
                name=f"AmbientHum_{audio_start}",
                filepath=audio_path,
                channel=9,
                frame_start=audio_start
            )

    print(f"==> Rendering cinematic to {scene.render.filepath} ({total_frames} frames)...")
    bpy.ops.render.render(animation=True)
    print("==> Cinematic render complete!")

if __name__ == "__main__":
    out_rel = os.path.join("assets", "video", "intro.ogv")
    build_intro_cinematic(out_rel)
