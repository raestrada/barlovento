"""
BARLOVENTO — AAA 3D Cinematic Prologue Renderer (v8 Next-Gen Edition)
1920x1080 Full HD | Authentic In-Game Faction Designs (Seraph-Prime Mobile Armor + 16 Beam Funnels + Pegasus Carrier Cradle,
Anvil Dreadnought + Hammer Spinal Railgun Battlecruisers, El Soberano Galleon + Pressurized Domes & Rowing Éther-Oars)
| Compositor Fog-Glow Bloom | Mastered Symphonic Audio | Outputs intro.ogv & intro.mp4
"""

import os
import sys
import math
import random
import bpy
import mathutils

# Ensure tools directory is in sys.path so we can import intro_models_3d
TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from intro_models_3d import (
    rads,
    create_emissive_material,
    create_pbr_hull_material,
    part_cyl,
    part_sphere,
    part_chamfer_box,
    part_chamfer_wedge,
    build_star_sea_environment,
    build_acero_warship,
    build_vinculados_colossus,
    build_vinculados_carrier_cradle,
    build_free_tide_galleon,
)

def key_transform(obj, frame, loc=None, rot=None, scale=None):
    if loc is not None:
        obj.location = loc
        obj.keyframe_insert("location", frame=frame)
    if rot is not None:
        obj.rotation_euler = rot
        obj.keyframe_insert("rotation_euler", frame=frame)
    if scale is not None:
        obj.scale = scale
        obj.keyframe_insert("scale", frame=frame)

def key_gundam_pose(rig, frame, loc=None, rot_deg=None, torso_deg=None, head_deg=None,
                    binder_l_deg=None, binder_r_deg=None,
                    sh_l_deg=None, el_l_deg=None, sh_r_deg=None, el_r_deg=None,
                    hip_l_deg=None, kn_l_deg=None, ank_l_deg=None,
                    hip_r_deg=None, kn_r_deg=None, ank_r_deg=None):
    if loc is not None or rot_deg is not None:
        key_transform(rig["root"], frame, loc=loc, rot=rads(rot_deg) if rot_deg else None)
    joint_map = [
        ("torso", torso_deg),
        ("head", head_deg),
        ("binder_L", binder_l_deg),
        ("binder_R", binder_r_deg),
        ("sh_L", sh_l_deg),
        ("el_L", el_l_deg),
        ("sh_R", sh_r_deg),
        ("el_R", el_r_deg),
        ("hip_L", hip_l_deg),
        ("kn_L", kn_l_deg),
        ("ank_L", ank_l_deg),
        ("hip_R", hip_r_deg),
        ("kn_R", kn_r_deg),
        ("ank_R", ank_r_deg),
    ]
    for jname, deg in joint_map:
        if deg is not None and jname in rig:
            key_transform(rig[jname], frame, rot=rads(deg))

def sanitize_all_keyframes():
    for action in bpy.data.actions:
        is_laser = ("BattleLaser" in action.name) or ("FunnelBeam" in action.name)
        fcurves = []
        if hasattr(action, "fcurves"):
            fcurves.extend(action.fcurves)
        elif hasattr(action, "layers"):
            for layer in action.layers:
                for strip in getattr(layer, "strips", []):
                    for cbag in getattr(strip, "channelbags", []):
                        fcurves.extend(getattr(cbag, "fcurves", []))
        for fcurve in fcurves:
            pts = fcurve.keyframe_points
            n = len(pts)
            for idx, kp in enumerate(pts):
                prev_far = (idx > 0 and abs(pts[idx - 1].co[1]) >= 400.0)
                next_far = (idx + 1 < n and abs(pts[idx + 1].co[1]) >= 400.0)
                if abs(kp.co[1]) >= 400.0 or prev_far or next_far:
                    kp.interpolation = 'CONSTANT'
                elif is_laser:
                    kp.interpolation = 'LINEAR'
                else:
                    kp.interpolation = 'BEZIER'
                    kp.handle_left_type = 'AUTO_CLAMPED'
                    kp.handle_right_type = 'AUTO_CLAMPED'
            fcurve.update()

def build_deployed_funnels(collection, count=6):
    """Builds autonomous floating angular Gundam Fin-Funnels / Dragoon pods with white ceramic wings, cobalt core, gold clamp, and cyan beam emitter."""
    mat_white = create_pbr_hull_material("Funnel_Ceramic", (0.93, 0.96, 1.0, 1.0), metallic=0.35, roughness=0.22, coat=0.60)
    mat_cobalt = create_pbr_hull_material("Funnel_Cobalt", (0.04, 0.14, 0.48, 1.0), metallic=0.58, roughness=0.24, coat=0.55)
    mat_gold = create_emissive_material("Funnel_GoldRing", (0.98, 0.80, 0.18, 1.0), strength=2.8)
    mat_cyan = create_emissive_material("Funnel_CyanEmitter", (0.10, 0.95, 1.0, 1.0), strength=14.0)
    funnels = []
    for i in range(count):
        f_root = bpy.data.objects.new(f"Floating_Funnel_{i}", None)
        collection.objects.link(f_root)
        # Angular central cobalt housing + two white ceramic fin-funnel blades
        part_chamfer_box(f"FunnelCore_{i}", (0.12, 0.56, 0.14), f_root, collection, mat_cobalt, loc=(0, 0.0, 0), chamfer=0.012)
        for side in [-1.0, 1.0]:
            part_chamfer_wedge(f"FunnelWing_{i}_{side}", (0.06, 0.62), (0.04, 0.42), 0.18, f_root, collection, mat_white,
                               loc=(side * 0.10, 0.02, side * 0.02), rot=rads((0, side * 62, 0)), chamfer=0.010)
        part_chamfer_box(f"FunnelGold_{i}", (0.16, 0.10, 0.18), f_root, collection, mat_gold, loc=(0, -0.14, 0), chamfer=0.008)
        part_chamfer_wedge(f"FunnelTip_{i}", (0.10, 0.12), (0.04, 0.06), 0.22, f_root, collection, mat_cyan,
                           loc=(0, -0.32, 0), rot=rads((90, 0, 0)), chamfer=0.006)
        part_chamfer_wedge(f"FunnelThruster_{i}", (0.08, 0.10), (0.02, 0.02), 0.38, f_root, collection, mat_cyan,
                           loc=(0, 0.44, 0), rot=rads((-90, 0, 0)), chamfer=0.004)
        f_root.location = (0, 0, 500)
        funnels.append(f_root)
    return funnels

def build_wide_battle_vfx(collection):
    mat_orange = create_emissive_material("Beam_Acero_Orange", (1.0, 0.48, 0.04, 1.0), strength=16.0)
    mat_red = create_emissive_material("Beam_Acero_Red", (1.0, 0.16, 0.06, 1.0), strength=16.0)
    mat_cyan = create_emissive_material("Beam_Marea_Cyan", (0.05, 0.90, 1.0, 1.0), strength=16.0)
    mat_violet = create_emissive_material("Beam_Vinc_Violet", (1.0, 0.15, 0.90, 1.0), strength=18.0)

    rng = random.Random(909)
    lasers = []
    for i in range(36):
        if i % 3 == 0:
            sp = (rng.uniform(-16, -8), rng.uniform(-2, 12), rng.uniform(-2, 4))
            ep = (rng.uniform(7, 16), rng.uniform(-2, 12), rng.uniform(-2, 4))
            mat = mat_orange if i % 2 == 0 else mat_red
            length = 4.2
        elif i % 3 == 1:
            sp = (rng.uniform(8, 16), rng.uniform(-3, 11), rng.uniform(-2, 3))
            ep = (rng.uniform(-16, -7), rng.uniform(-2, 12), rng.uniform(-2, 4))
            mat = mat_cyan
            length = 4.2
        else:
            sp = (rng.uniform(-5, 5), rng.uniform(-4, 6), rng.uniform(-1, 4))
            ep = (rng.uniform(-14, 14), rng.uniform(2, 14), rng.uniform(-2, 4))
            mat = mat_violet
            length = 3.6

        vec = mathutils.Vector(ep) - mathutils.Vector(sp)
        rot_quat = vec.normalized().to_track_quat('Z', 'Y')
        dummy = bpy.data.objects.new(f"LD_{i}", None)
        collection.objects.link(dummy)
        l_obj = part_cyl(f"BattleLaser_{i}", 0.07, 0.07, length, dummy, collection, mat,
                         loc=(0, 0, 500), rot=rot_quat.to_euler(), segs=10)
        f_base = 522 + (i * 3) % 34
        lasers.append({"obj": l_obj, "sp": sp, "ep": ep, "f_base": f_base})

    mat_core_exp = create_emissive_material("Exp_InnerCore", (1.0, 0.82, 0.28, 1.0), strength=18.0)
    mat_fire_exp = create_emissive_material("Exp_FireShell", (1.0, 0.30, 0.02, 0.75), strength=9.0, alpha=0.75)
    mat_ring_exp = create_emissive_material("Exp_ShockRing", (0.12, 0.88, 1.0, 0.65), strength=8.0, alpha=0.65)

    exp_configs = [
        {"name": "Exp1", "pos": (-7.5, 5.0, 1.2),  "fs": 528, "fp": 546, "fe": 570, "max_s": 1.75},
        {"name": "Exp2", "pos": (8.5, 3.5, -0.5),  "fs": 544, "fp": 564, "fe": 588, "max_s": 1.75},
        {"name": "Exp3", "pos": (-2.0, 8.0, 2.2),  "fs": 558, "fp": 578, "fe": 602, "max_s": 1.85},
        {"name": "Exp4", "pos": (6.5, -1.5, 1.0),  "fs": 572, "fp": 592, "fe": 616, "max_s": 1.75},
        {"name": "Exp5", "pos": (-5.5, 1.5, -1.2), "fs": 586, "fp": 606, "fe": 630, "max_s": 1.85},
        {"name": "Exp6", "pos": (2.5, 6.5, 0.8),   "fs": 600, "fp": 618, "fe": 640, "max_s": 1.95},
        {"name": "Exp_Climax", "pos": (0.0, 4.0, 3.5), "fs": 622, "fp": 640, "fe": 652, "max_s": 4.50},
    ]

    explosions = []
    for ec in exp_configs:
        dummy = bpy.data.objects.new(ec["name"] + "_Root", None)
        collection.objects.link(dummy)
        part_sphere(ec["name"] + "_Core", 0.38, dummy, collection, mat_core_exp, subdiv=2)
        part_sphere(ec["name"] + "_Fire", 0.72, dummy, collection, mat_fire_exp, subdiv=3)
        part_cyl(ec["name"] + "_Ring", 1.20, 1.20, 0.05, dummy, collection, mat_ring_exp,
                 rot=(math.radians(15), math.radians(10), 0), segs=28)

        light_data = bpy.data.lights.new(ec["name"] + "_Light", type='POINT')
        light_data.color = (0.35, 0.88, 1.0) if ec["name"] == "Exp_Climax" else (1.0, 0.55, 0.12)
        light_obj = bpy.data.objects.new(ec["name"] + "_Light", light_data)
        collection.objects.link(light_obj)
        light_obj.parent = dummy

        dummy.location = (0, 0, 500)
        explosions.append({"root": dummy, "light": light_obj, "cfg": ec})

    return lasers, explosions

def setup_compositor_bloom(scene_3d):
    """Adds real-time cinematic Fog-Glow Bloom in Blender 4.2 Compositor so thrusters, visors, Soul Cores & lasers glow like AAA cinema."""
    scene_3d.use_nodes = True
    tree = scene_3d.node_tree
    nodes = tree.nodes
    links = tree.links
    nodes.clear()

    rl = nodes.new("CompositorNodeRLayers")
    glare = nodes.new("CompositorNodeGlare")
    glare.glare_type = 'FOG_GLOW'
    glare.quality = 'HIGH'
    glare.threshold = 0.85
    glare.size = 7
    glare.mix = 0.0

    comp = nodes.new("CompositorNodeComposite")
    links.new(rl.outputs["Image"], glare.inputs["Image"])
    links.new(glare.outputs["Image"], comp.inputs["Image"])

def setup_cinematic_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    def asset_p(rel: str) -> str:
        return os.path.join(base_dir, rel.replace('/', os.sep))

    total_frames = 760

    # 1. SCENE 3D: VIEWPORT WORLD (1920x1080)
    scene_3d = bpy.data.scenes.new("Scene_3D")
    bpy.context.window.scene = scene_3d
    eevee_enums = [e.identifier for e in scene_3d.render.bl_rna.properties['engine'].enum_items]
    scene_3d.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in eevee_enums else 'BLENDER_EEVEE'
    if hasattr(scene_3d, "eevee") and hasattr(scene_3d.eevee, "taa_render_samples"):
        scene_3d.eevee.taa_render_samples = 16
    scene_3d.render.resolution_x = 1920
    scene_3d.render.resolution_y = 1080
    scene_3d.render.fps = 24
    scene_3d.frame_start = 1
    scene_3d.frame_end = total_frames
    scene_3d.render.use_sequencer = False

    setup_compositor_bloom(scene_3d)
    col = scene_3d.collection

    # Deep Star Sea World Shader with Generated Nebula Texture + Crisp Procedural Starfield
    world = bpy.data.worlds.new("StarSea_World")
    scene_3d.world = world
    world.use_nodes = True
    w_nodes = world.node_tree.nodes
    w_links = world.node_tree.links
    bg = w_nodes.get("Background")
    bg.inputs["Strength"].default_value = 1.05

    coord = w_nodes.new("ShaderNodeTexCoord")
    w_map = w_nodes.new("ShaderNodeMapping")
    w_map.inputs["Rotation"].default_value = (math.radians(38), math.radians(44), math.radians(22))

    neb_noise = w_nodes.new("ShaderNodeTexNoise")
    neb_noise.inputs["Scale"].default_value = 4.5
    neb_noise.inputs["Detail"].default_value = 10.0
    neb_noise.inputs["Roughness"].default_value = 0.68
    neb_noise.inputs["Distortion"].default_value = 0.95

    ramp_neb = w_nodes.new("ShaderNodeValToRGB")
    ramp_neb.color_ramp.elements[0].position = 0.30
    ramp_neb.color_ramp.elements[0].color = (0.002, 0.005, 0.014, 1.0)
    ramp_neb.color_ramp.elements[1].position = 0.84
    ramp_neb.color_ramp.elements[1].color = (0.014, 0.055, 0.105, 1.0)

    vor_stars = w_nodes.new("ShaderNodeTexVoronoi")
    vor_stars.inputs["Scale"].default_value = 480.0

    ramp_stars = w_nodes.new("ShaderNodeValToRGB")
    ramp_stars.color_ramp.elements[0].position = 0.0
    ramp_stars.color_ramp.elements[0].color = (0.96, 0.98, 1.0, 1.0)
    ramp_stars.color_ramp.elements[1].position = 0.042
    ramp_stars.color_ramp.elements[1].color = (0.0, 0.0, 0.0, 1.0)

    add_col = w_nodes.new("ShaderNodeMix")
    add_col.data_type = 'RGBA'
    add_col.blend_type = 'ADD'
    add_col.inputs["Factor"].default_value = 0.95

    w_links.new(coord.outputs["Generated"], w_map.inputs["Vector"])
    w_links.new(w_map.outputs["Vector"], neb_noise.inputs["Vector"])
    w_links.new(neb_noise.outputs["Fac"], ramp_neb.inputs["Fac"])
    w_links.new(w_map.outputs["Vector"], vor_stars.inputs["Vector"])
    w_links.new(vor_stars.outputs["Distance"], ramp_stars.inputs["Fac"])

    tex_neb_path = asset_p("assets/environments/ether_nebula_hdri.png")
    if os.path.exists(tex_neb_path):
        env_tex = w_nodes.new("ShaderNodeTexEnvironment")
        env_tex.image = bpy.data.images.load(tex_neb_path)
        mix_env = w_nodes.new("ShaderNodeMix")
        mix_env.data_type = 'RGBA'
        mix_env.blend_type = 'MIX'
        mix_env.inputs["Factor"].default_value = 0.22
        w_links.new(w_map.outputs["Vector"], env_tex.inputs["Vector"])
        w_links.new(ramp_neb.outputs["Color"], mix_env.inputs[6])
        w_links.new(env_tex.outputs["Color"], mix_env.inputs[7])
        w_links.new(mix_env.outputs[2], add_col.inputs[6])
    else:
        w_links.new(ramp_neb.outputs["Color"], add_col.inputs[6])

    w_links.new(ramp_stars.outputs["Color"], add_col.inputs[7])
    w_links.new(add_col.outputs[2], bg.inputs["Color"])

    # Three-Point Cinematic Space Lighting
    sun_key = bpy.data.lights.new("Sun_Key", type='SUN')
    sun_key.energy = 4.2
    sun_key.color = (0.98, 0.96, 0.92)
    sun_key_obj = bpy.data.objects.new("Sun_Key", sun_key)
    sun_key_obj.rotation_euler = (math.radians(52), math.radians(24), math.radians(28))
    col.objects.link(sun_key_obj)

    sun_rim = bpy.data.lights.new("Sun_Rim", type='SUN')
    sun_rim.energy = 3.0
    sun_rim.color = (0.18, 0.88, 1.0)
    sun_rim_obj = bpy.data.objects.new("Sun_Rim", sun_rim)
    sun_rim_obj.rotation_euler = (math.radians(-42), math.radians(-55), math.radians(130))
    col.objects.link(sun_rim_obj)

    sun_fill = bpy.data.lights.new("Sun_Fill", type='SUN')
    sun_fill.energy = 1.4
    sun_fill.color = (0.55, 0.68, 0.92)
    sun_fill_obj = bpy.data.objects.new("Sun_Fill", sun_fill)
    sun_fill_obj.rotation_euler = (math.radians(78), 0, math.radians(-12))
    col.objects.link(sun_fill_obj)

    # Build Star Sea Environment
    env_root, asteroids = build_star_sea_environment(col, 28)
    for ast_obj, loc, rot in asteroids:
        key_transform(ast_obj, 1, loc=loc, rot=rot)
        key_transform(ast_obj, 118, loc=loc, rot=(rot[0] + 0.35, rot[1] - 0.28, rot[2] + 0.42))

    # Load Newly Generated High-Resolution PBR Textures!
    tex_acero = asset_p("assets/ships/acero/acero_dreadnought_plate.png")
    if not os.path.exists(tex_acero):
        tex_acero = asset_p("assets/ships/acero/acero_hull.png")

    tex_vinc = asset_p("assets/ships/vinculados/vinculados_mecha_armor.png")
    if not os.path.exists(tex_vinc):
        tex_vinc = asset_p("assets/ships/vinculados/vinculados_hull.png")

    tex_marea = asset_p("assets/ships/marea-libre/marea_ornate_timber.png")
    if not os.path.exists(tex_marea):
        tex_marea = asset_p("assets/ships/marea-libre/marea_hull.png")

    # 1. ARMADA OF ACERO FLEET (Anvil Dreadnought + Hammer Spinal-Railgun Battlecruisers)
    dreadnought, dread_turrets = build_acero_warship(col, tex_acero, "Acero_Dreadnought", 1.0, ship_class="dreadnought")
    cruiser1, _ = build_acero_warship(col, tex_acero, "Acero_HammerBC1", 0.56, ship_class="battlecruiser")
    cruiser2, _ = build_acero_warship(col, tex_acero, "Acero_HammerBC2", 0.52, ship_class="battlecruiser")
    cruiser3, _ = build_acero_warship(col, tex_acero, "Acero_HammerBC3", 0.48, ship_class="battlecruiser")

    # 2. THE VINCULADOS FLEET (Seraph-Prime Colossal Mobile Armor + CNS Cradle Pegasus Carrier + Anima/Nous Gundam Suits + Deployed Funnels!)
    seraph_prime = build_vinculados_colossus(col, tex_vinc, "Vinculados_SeraphPrime", 1.0, is_wingman=False)
    cradle_carrier = build_vinculados_carrier_cradle(col, tex_vinc, "Vinculados_CradleCarrier", 0.58)
    vinc_ace1 = build_vinculados_colossus(col, tex_vinc, "Vinculados_Ace1", 0.54, is_wingman=False)
    vinc_ace2 = build_vinculados_colossus(col, tex_vinc, "Vinculados_Ace2", 0.46, is_wingman=True)
    vinc_ace3 = build_vinculados_colossus(col, tex_vinc, "Vinculados_Ace3", 0.46, is_wingman=True)
    floating_funnels = build_deployed_funnels(col, 6)

    # 3. THE FREE TIDE FLEET (El Soberano Galleon + Raider Brigantines with Rowing Oars)
    galleon, galleon_oars = build_free_tide_galleon(col, tex_marea, "FreeTide_ElSoberano", 1.0, is_raider=False)
    raider1, _ = build_free_tide_galleon(col, tex_marea, "FreeTide_Raider1", 0.60, is_raider=True)
    raider2, _ = build_free_tide_galleon(col, tex_marea, "FreeTide_Raider2", 0.56, is_raider=True)

    lasers, explosions = build_wide_battle_vfx(col)

    cam_data = bpy.data.cameras.new("Cinematic_Cam")
    cam_data.lens = 35
    cam_data.clip_end = 500.0
    cam_obj = bpy.data.objects.new("Cinematic_Cam", cam_data)
    col.objects.link(cam_obj)
    scene_3d.camera = cam_obj

    all_ship_roots = [
        dreadnought, cruiser1, cruiser2, cruiser3,
        seraph_prime["root"], cradle_carrier, vinc_ace1["root"], vinc_ace2["root"], vinc_ace3["root"],
        galleon, raider1, raider2
    ] + floating_funnels
    for s in all_ship_roots:
        key_transform(s, 1, loc=(0, 0, 500))

    # -------------------------------------------------------------------------
    # SHOT 1: THE STAR SEA (Frames 1 - 110)
    # -------------------------------------------------------------------------
    key_transform(env_root, 1, loc=(0, 0, 0))
    key_transform(env_root, 110, loc=(0, 0, 0))
    key_transform(env_root, 111, loc=(0, 0, 500))

    key_transform(cam_obj, 1, loc=(0, -28, 3.8), rot=(math.radians(83), 0, 0))
    key_transform(cam_obj, 110, loc=(0, -8, 2.2), rot=(math.radians(85), 0, math.radians(8)))

    # -------------------------------------------------------------------------
    # SHOT 2: THE ARMADA OF ACERO (Frames 111 - 220)
    # Anvil Dreadnought + 2 Hammer Battlecruisers, with tracking main turrets!
    # -------------------------------------------------------------------------
    key_transform(dreadnought, 110, loc=(0, 0, 500))
    key_transform(dreadnought, 111, loc=(1.5, 4.0, 0.5), rot=(math.radians(5), math.radians(-8), math.radians(-125)))
    key_transform(dreadnought, 220, loc=(-1.0, 1.5, 0.8), rot=(math.radians(5), math.radians(-8), math.radians(-135)))
    key_transform(dreadnought, 221, loc=(0, 0, 500))

    # Animate Dreadnought Main Turrets rotating toward the camera port quarter!
    for t_idx, t_piv in enumerate(dread_turrets):
        key_transform(t_piv, 111, rot=rads((0, 0, -10)))
        key_transform(t_piv, 195, rot=rads((0, 0, 38 - t_idx * 5)))
        key_transform(t_piv, 221, rot=rads((0, 0, 0)))

    key_transform(cruiser1, 110, loc=(0, 0, 500))
    key_transform(cruiser1, 111, loc=(9.2, 11.5, -1.6), rot=(math.radians(5), math.radians(-8), math.radians(-125)))
    key_transform(cruiser1, 220, loc=(6.2, 8.5, -1.3), rot=(math.radians(5), math.radians(-8), math.radians(-135)))
    key_transform(cruiser1, 221, loc=(0, 0, 500))

    key_transform(cruiser2, 110, loc=(0, 0, 500))
    key_transform(cruiser2, 111, loc=(-4.8, 12.8, 2.4), rot=(math.radians(5), math.radians(-8), math.radians(-125)))
    key_transform(cruiser2, 220, loc=(-7.5, 9.8, 2.6), rot=(math.radians(5), math.radians(-8), math.radians(-135)))
    key_transform(cruiser2, 221, loc=(0, 0, 500))

    key_transform(cam_obj, 111, loc=(-13.2, -14.2, 3.8), rot=(math.radians(79), 0, math.radians(-42)))
    key_transform(cam_obj, 220, loc=(-10.5, -16.2, 4.6), rot=(math.radians(76), 0, math.radians(-34)))

    # -------------------------------------------------------------------------
    # SHOT 3: THE VINCULADOS — SERAPH-PRIME COLOSSUS, PEGASUS CARRIER CRADLE & BEAM FUNNELS (Frames 221 - 330)
    # -------------------------------------------------------------------------
    key_transform(seraph_prime["root"], 220, loc=(0, 0, 500))
    key_transform(cradle_carrier, 220, loc=(0, 0, 500))
    key_transform(vinc_ace2["root"], 220, loc=(0, 0, 500))
    key_transform(vinc_ace3["root"], 220, loc=(0, 0, 500))

    # Pegasus-class Assault Carrier CNS Cradle cruising majestically in the upper-left background flank!
    key_transform(cradle_carrier, 221, loc=(-9.5, 22.0, 4.8), rot=rads((12, -16, -132)))
    key_transform(cradle_carrier, 330, loc=(-7.2, 18.0, 4.2), rot=rads((12, -16, -138)))
    key_transform(cradle_carrier, 331, loc=(0, 0, 500))

    # Two Nous/Anima Mobile Suit Wingmen escorting Seraph-Prime in echelon formation!
    key_gundam_pose(
        vinc_ace2, 221,
        loc=(-4.2, 6.2, 1.4), rot_deg=(-14, 12, 18),
        sh_l_deg=(-40, 28, -20), el_l_deg=(-60, 0, 16),
        sh_r_deg=(-28, -32, 16), el_r_deg=(-36, 0, -14),
        hip_l_deg=(-44, 8, -6), kn_l_deg=(64, 0, 0),
        hip_r_deg=(24, -8, 8), kn_r_deg=(20, 0, 0),
    )
    key_gundam_pose(
        vinc_ace2, 330,
        loc=(-3.6, 4.0, 1.6), rot_deg=(-10, 6, 12),
    )
    key_transform(vinc_ace2["root"], 331, loc=(0, 0, 500))

    key_gundam_pose(
        vinc_ace3, 221,
        loc=(4.4, 6.8, 1.8), rot_deg=(-14, -12, -14),
        sh_l_deg=(-40, 28, -20), el_l_deg=(-60, 0, 16),
        sh_r_deg=(-28, -32, 16), el_r_deg=(-36, 0, -14),
        hip_l_deg=(-44, 8, -6), kn_l_deg=(64, 0, 0),
        hip_r_deg=(24, -8, 8), kn_r_deg=(20, 0, 0),
    )
    key_gundam_pose(
        vinc_ace3, 330,
        loc=(3.7, 4.6, 1.9), rot_deg=(-10, -6, -8),
    )
    key_transform(vinc_ace3["root"], 331, loc=(0, 0, 500))

    # Orbiting Autonomous Beam Funnels deployed around Seraph-Prime!
    funnel_offsets = [
        (-2.8, 0.8, 2.8, (12, -25, 18)),
        ( 2.8, 0.8, 2.8, (12,  25, -18)),
        (-3.3, -0.4, 1.2, (-8, -32, 24)),
        ( 3.3, -0.4, 1.2, (-8,  32, -24)),
        (-2.2, 1.6, -0.6, (-18, -18, 12)),
        ( 2.2, 1.6, -0.6, (-18,  18, -12)),
    ]
    for f_idx, f_obj in enumerate(floating_funnels):
        fx, fy, fz, frot = funnel_offsets[f_idx]
        key_transform(f_obj, 220, loc=(0, 0, 500))
        key_transform(f_obj, 221, loc=(fx * 0.6, fy + 1.5, fz), rot=rads(frot))
        key_transform(f_obj, 275, loc=(fx, fy, fz + 0.35), rot=rads((frot[0] - 8, frot[1] * 0.6, frot[2])))
        key_transform(f_obj, 330, loc=(fx * 1.08, fy - 0.8, fz + 0.15), rot=rads((frot[0] - 12, frot[1] * 0.4, frot[2])))
        key_transform(f_obj, 331, loc=(0, 0, 500))

    # Seraph-Prime Hero Choreography (Frames 221 - 330)
    # Right arm angles heroically outward so the Resonance Beam Lance frames the right flank without crossing the Gundam face!
    key_gundam_pose(
        seraph_prime, 221,
        loc=(0.95, 1.60, 0.10), rot_deg=(-10, 12, 22),
        torso_deg=(-8, -6, -8), head_deg=(8, -4, 10),
        binder_l_deg=(12, -24, 14), binder_r_deg=(12, 24, -14),
        sh_l_deg=(-38, 24, -18), el_l_deg=(-58, 0, 16),
        sh_r_deg=(14, -30, 16), el_r_deg=(-28, 0, -14),
        hip_l_deg=(-52, 8, -6), kn_l_deg=(74, 0, 0), ank_l_deg=(-18, 0, 0),
        hip_r_deg=(24, -8, 8), kn_r_deg=(22, 0, 0), ank_r_deg=(-18, 0, 0),
    )
    key_gundam_pose(
        seraph_prime, 258,
        loc=(0.08, 0.20, -0.25), rot_deg=(-4, 4, 14),
        torso_deg=(-4, 2, -8), head_deg=(4, -2, 8),
        binder_l_deg=(22, -36, 22), binder_r_deg=(22, 36, -22),
        sh_l_deg=(-44, 32, -24), el_l_deg=(-68, 0, 20),
        sh_r_deg=(-14, -34, 16), el_r_deg=(-34, 0, -16),
        hip_l_deg=(-44, 8, -8), kn_l_deg=(62, 0, 0), ank_l_deg=(-14, 0, 0),
        hip_r_deg=(18, -6, 6), kn_r_deg=(18, 0, 0), ank_r_deg=(-14, 0, 0),
    )
    key_gundam_pose(
        seraph_prime, 298,
        loc=(-0.08, -0.05, -0.15), rot_deg=(-2, -2, 8),
        torso_deg=(2, -4, 6), head_deg=(2, 4, -8),
        binder_l_deg=(28, -44, 26), binder_r_deg=(28, 44, -26),
        sh_l_deg=(-48, 36, -26), el_l_deg=(-72, 0, 22),
        sh_r_deg=(-28, -36, 18), el_r_deg=(-38, 0, -18),
        hip_l_deg=(-38, 10, -6), kn_l_deg=(52, 0, 0), ank_l_deg=(-12, 0, 0),
        hip_r_deg=(22, -8, 8), kn_r_deg=(24, 0, 0), ank_r_deg=(-16, 0, 0),
    )
    key_gundam_pose(
        seraph_prime, 330,
        loc=(-0.35, -0.95, 0.05), rot_deg=(-12, -6, 4),
        torso_deg=(-8, -2, 4), head_deg=(10, 2, -4),
        binder_l_deg=(32, -48, 28), binder_r_deg=(32, 48, -28),
        sh_l_deg=(-42, 32, -22), el_l_deg=(-64, 0, 18),
        sh_r_deg=(-32, -34, 16), el_r_deg=(-36, 0, -16),
        hip_l_deg=(-48, 8, -6), kn_l_deg=(68, 0, 0), ank_l_deg=(-16, 0, 0),
        hip_r_deg=(28, -8, 8), kn_r_deg=(20, 0, 0), ank_r_deg=(-20, 0, 0),
    )
    key_transform(seraph_prime["root"], 331, loc=(0, 0, 500))

    key_transform(cam_obj, 221, loc=(-1.3, -10.5, 1.55), rot=(math.radians(89.2), 0, math.radians(-8)))
    key_transform(cam_obj, 330, loc=(0.95, -9.6, 1.70), rot=(math.radians(89.0), 0, math.radians(7)))

    # -------------------------------------------------------------------------
    # SHOT 4: THE FREE TIDE — EL SOBERANO VOID GALLEON & BRIGANTINES (Frames 331 - 440)
    # With actively rowing mechanical Éther-Oars!
    # -------------------------------------------------------------------------
    key_transform(galleon, 330, loc=(0, 0, 500))
    key_transform(galleon, 331, loc=(1.5, 4.0, -0.8), rot=(math.radians(-4), math.radians(8), math.radians(-138)))
    key_transform(galleon, 440, loc=(-1.0, 1.5, -0.2), rot=(math.radians(-4), math.radians(8), math.radians(-145)))

    # Animate Rowing Mechanical Éther-Oars!
    for oar_piv, side, idx in galleon_oars:
        for f_step in range(331, 441, 18):
            phase = idx * 0.45 + (0 if ((f_step - 331) // 18) % 2 == 0 else math.pi)
            swing = math.sin(phase) * 16.0
            dip = math.cos(phase) * 8.0
            key_transform(oar_piv, f_step, rot=rads((-18 + swing, side * (54 + dip), 0)))

    key_transform(raider1, 330, loc=(0, 0, 500))
    key_transform(raider1, 331, loc=(9.8, 12.0, -2.2), rot=(math.radians(-4), math.radians(8), math.radians(-138)))
    key_transform(raider1, 440, loc=(6.8, 9.0, -1.6), rot=(math.radians(-4), math.radians(8), math.radians(-145)))
    key_transform(raider1, 441, loc=(0, 0, 500))

    key_transform(cam_obj, 331, loc=(-12.8, -14.5, 2.2), rot=(math.radians(84), 0, math.radians(-42)))
    key_transform(cam_obj, 440, loc=(-10.8, -16.5, 3.4), rot=(math.radians(79), 0, math.radians(-34)))

    # =========================================================================
    # SEAMLESS UNBROKEN SEQUENCE:
    # SHOT 5 (THE CALM / STANDOFF, 441-505) -> SERAPH-PRIME & SQUADRON FLYBY (500-535)
    # -> SHOT 6 (WIDE 3-FACTION FLEET BATTLE, 530-642) -> UPWARD TILT INTO TITLE (622-760)
    # =========================================================================

    # 1. Left Flank: Acero Battleline
    key_transform(dreadnought, 441, loc=(-7.5, 2.0, -0.2), rot=rads((8, 12, -64)))
    key_transform(dreadnought, 515, loc=(-10.0, 3.8, 0.4), rot=rads((6, 10, -70)))
    key_transform(dreadnought, 575, loc=(-12.0, 5.2, 0.8), rot=rads((4, 8, -74)))
    key_transform(dreadnought, 650, loc=(-10.2, 6.8, 1.0), rot=rads((4, 8, -71)))

    key_transform(cruiser1, 440, loc=(0, 0, 500))
    key_transform(cruiser1, 441, loc=(-15.5, -2.8, 2.4), rot=rads((6, 10, -68)))
    key_transform(cruiser1, 535, loc=(-17.0, -0.8, 2.8), rot=rads((6, 10, -70)))
    key_transform(cruiser1, 650, loc=(-14.2, 1.6, 3.0), rot=rads((6, 10, -68)))

    key_transform(cruiser2, 440, loc=(0, 0, 500))
    key_transform(cruiser2, 441, loc=(-14.2, 10.2, -1.8), rot=rads((2, 6, -78)))
    key_transform(cruiser2, 535, loc=(-15.2, 11.8, -1.6), rot=rads((2, 6, -80)))
    key_transform(cruiser2, 650, loc=(-12.4, 13.2, -1.4), rot=rads((2, 6, -78)))

    key_transform(cruiser3, 440, loc=(0, 0, 500))
    key_transform(cruiser3, 441, loc=(-19.5, 5.2, -0.8), rot=rads((5, 8, -74)))
    key_transform(cruiser3, 535, loc=(-20.5, 6.8, -0.7), rot=rads((5, 8, -75)))
    key_transform(cruiser3, 650, loc=(-17.8, 8.8, -0.5), rot=rads((5, 8, -72)))

    # 2. Right Flank: Free Tide Flotilla
    key_transform(galleon, 441, loc=(7.5, 3.0, 0.4), rot=rads((-6, -10, 110)))
    key_transform(galleon, 515, loc=(10.5, 4.2, 0.3), rot=rads((4, -10, 82)))
    key_transform(galleon, 575, loc=(12.2, 5.4, 0.3), rot=rads((5, -10, 76)))
    key_transform(galleon, 650, loc=(10.0, 7.0, 0.5), rot=rads((5, -10, 78)))

    key_transform(raider1, 441, loc=(15.2, -2.6, -1.8), rot=rads((8, -12, 70)))
    key_transform(raider1, 535, loc=(16.2, -0.8, -1.7), rot=rads((8, -12, 68)))
    key_transform(raider1, 650, loc=(13.5, 1.5, -1.4), rot=rads((8, -12, 72)))

    key_transform(raider2, 440, loc=(0, 0, 500))
    key_transform(raider2, 441, loc=(13.8, 10.4, 2.0), rot=rads((4, -8, 84)))
    key_transform(raider2, 535, loc=(15.0, 12.0, 2.2), rot=rads((4, -8, 82)))
    key_transform(raider2, 650, loc=(12.0, 13.5, 2.5), rot=rads((4, -8, 85)))

    # 3. Center High Vanguard: Vinculados Carrier CNS Cradle + Seraph-Prime & Mobile Suit Squadron
    key_transform(cradle_carrier, 440, loc=(0, 0, 500))
    key_transform(cradle_carrier, 441, loc=(-1.5, 16.5, 5.2), rot=rads((12, -14, -135)))
    key_transform(cradle_carrier, 540, loc=(-1.0, 14.5, 4.8), rot=rads((10, -12, -138)))
    key_transform(cradle_carrier, 650, loc=(-0.5, 12.5, 4.5), rot=rads((10, -12, -140)))

    for ace in [vinc_ace1, vinc_ace2, vinc_ace3]:
        key_transform(ace["root"], 499, loc=(0, 0, 500))

    # --- ACE 1 (Seraph-Prime Lead Interceptor) ---
    key_gundam_pose(
        vinc_ace1, 500,
        loc=(-1.2, -22.0, 2.0), rot_deg=(-24, 18, -16),
        torso_deg=(-12, 8, -8), head_deg=(12, 0, 8),
        binder_l_deg=(24, -36, 20), binder_r_deg=(24, 36, -20),
        sh_l_deg=(-36, 26, -20), el_l_deg=(-54, 0, 16),
        sh_r_deg=(-42, -18, -14), el_r_deg=(-46, 0, -12),
        hip_l_deg=(-48, 8, -6), kn_l_deg=(68, 0, 0),
        hip_r_deg=(26, -8, 8), kn_r_deg=(20, 0, 0),
    )
    key_gundam_pose(
        vinc_ace1, 532,
        loc=(-2.5, -1.8, 1.4), rot_deg=(12, 22, -36),
        torso_deg=(6, -10, 14), head_deg=(-4, 6, -12),
        sh_l_deg=(-48, 38, -26), el_l_deg=(-68, 0, 20),
        sh_r_deg=(-58, -14, -18), el_r_deg=(-50, 0, -14),
        hip_l_deg=(-42, 8, -8), kn_l_deg=(56, 0, 0),
        hip_r_deg=(28, -8, 8), kn_r_deg=(24, 0, 0),
    )
    key_gundam_pose(
        vinc_ace1, 576,
        loc=(-0.8, 2.5, 2.2), rot_deg=(-12, -18, 24),
        torso_deg=(-8, 8, -16), head_deg=(8, -4, 14),
        sh_l_deg=(-38, 28, -20), el_l_deg=(-56, 0, 18),
        sh_r_deg=(-64, -10, -22), el_r_deg=(-42, 0, -10),
        hip_l_deg=(-54, 10, -8), kn_l_deg=(72, 0, 0),
        hip_r_deg=(24, -8, 8), kn_r_deg=(18, 0, 0),
    )
    key_gundam_pose(
        vinc_ace1, 620,
        loc=(1.8, 4.2, 1.8), rot_deg=(16, 14, -26),
        sh_l_deg=(-44, 34, -24), el_l_deg=(-62, 0, 18),
        sh_r_deg=(-48, -18, -16), el_r_deg=(-48, 0, -12),
    )
    key_gundam_pose(
        vinc_ace1, 650,
        loc=(-0.8, 6.4, 2.8), rot_deg=(-14, -10, 18),
    )

    # --- ACE 2 (Right Dogfighter) ---
    key_gundam_pose(
        vinc_ace2, 502,
        loc=(1.8, -23.0, 1.5), rot_deg=(-22, -20, 18),
        torso_deg=(-12, -8, 10), head_deg=(12, 2, -10),
        binder_l_deg=(22, -34, 18), binder_r_deg=(22, 34, -18),
        sh_l_deg=(-34, 32, -22), el_l_deg=(-52, 0, 14),
        sh_r_deg=(-48, -16, -14), el_r_deg=(-42, 0, -12),
        hip_l_deg=(24, 6, -6), kn_l_deg=(18, 0, 0),
        hip_r_deg=(-48, -8, 8), kn_r_deg=(68, 0, 0),
    )
    key_gundam_pose(
        vinc_ace2, 536,
        loc=(2.8, -0.8, -0.6), rot_deg=(12, -22, 36),
        torso_deg=(8, 10, -14), head_deg=(-6, -4, 12),
        sh_l_deg=(-46, 36, -26), el_l_deg=(-64, 0, 18),
        sh_r_deg=(-54, -18, -16), el_r_deg=(-46, 0, -14),
        hip_l_deg=(28, 8, -6), kn_l_deg=(22, 0, 0),
        hip_r_deg=(-44, -8, 8), kn_r_deg=(60, 0, 0),
    )
    key_gundam_pose(
        vinc_ace2, 580,
        loc=(1.2, 3.4, 0.8), rot_deg=(-14, 18, -22),
        torso_deg=(-8, -8, 16), head_deg=(8, 4, -14),
        sh_l_deg=(-36, 28, -20), el_l_deg=(-54, 0, 16),
        sh_r_deg=(-60, -12, -20), el_r_deg=(-44, 0, -12),
        hip_l_deg=(22, 6, -6), kn_l_deg=(18, 0, 0),
        hip_r_deg=(-52, -10, 10), kn_r_deg=(74, 0, 0),
    )
    key_gundam_pose(vinc_ace2, 620, loc=(-1.6, 5.0, 0.5), rot_deg=(12, -14, 28))
    key_gundam_pose(vinc_ace2, 650, loc=(1.2, 6.8, 1.2), rot_deg=(-12, 12, -18))

    # --- ACE 3 (High-Cover Wingman) ---
    key_gundam_pose(
        vinc_ace3, 504,
        loc=(0.0, -20.5, 4.4), rot_deg=(-26, 12, -22),
        torso_deg=(-12, 6, -10), head_deg=(12, 0, 8),
        sh_l_deg=(-36, 30, -22), el_l_deg=(-52, 0, 16),
        sh_r_deg=(-52, -14, -18), el_r_deg=(-44, 0, -12),
        hip_l_deg=(-46, 8, -8), kn_l_deg=(66, 0, 0),
        hip_r_deg=(26, -8, 8), kn_r_deg=(20, 0, 0),
    )
    key_gundam_pose(
        vinc_ace3, 540,
        loc=(0.4, 2.2, 3.2), rot_deg=(-10, 18, -44),
        torso_deg=(8, -8, 14), head_deg=(-4, 4, -12),
        sh_l_deg=(-44, 34, -24), el_l_deg=(-60, 0, 18),
        sh_r_deg=(-56, -16, -16), el_r_deg=(-46, 0, -12),
    )
    key_gundam_pose(vinc_ace3, 588, loc=(-2.4, 5.2, 2.2), rot_deg=(14, -16, 32))
    key_gundam_pose(vinc_ace3, 650, loc=(-3.5, 7.5, 1.6), rot_deg=(-10, 16, -38))

    # 4. UNBROKEN MASTER CAMERA SHOT
    key_transform(cam_obj, 441, loc=(0.0, -13.0, 3.2), rot=rads((83, 0, 0)))
    key_transform(cam_obj, 502, loc=(0.0, -18.0, 5.0), rot=rads((79, 0, 0)))
    key_transform(cam_obj, 538, loc=(0.0, -25.0, 8.0), rot=rads((74, 0, 0)))
    key_transform(cam_obj, 620, loc=(0.0, -48.5, 18.2), rot=rads((69, 0, 0)))
    key_transform(cam_obj, 654, loc=(0.0, -51.0, 22.5), rot=rads((106, 0, 0)))
    key_transform(cam_obj, 760, loc=(0.0, -46.0, 24.5), rot=rads((108, 0, 0)))

    for s in all_ship_roots:
        if s not in [seraph_prime["root"]] + floating_funnels:
            key_transform(s, 655, loc=(0, 0, 500))

    for l_item in lasers:
        lo = l_item["obj"]
        f_base = l_item["f_base"]
        key_transform(lo, 1, loc=(0, 0, 500))
        for cycle in range(3):
            ff = f_base + cycle * 34
            fh = ff + 14
            if fh <= 644:
                key_transform(lo, ff - 1, loc=(0, 0, 500))
                key_transform(lo, ff, loc=l_item["sp"])
                key_transform(lo, fh, loc=l_item["ep"])
                key_transform(lo, fh + 1, loc=(0, 0, 500))

    for exp_item in explosions:
        r_obj = exp_item["root"]
        l_obj = exp_item["light"]
        ec = exp_item["cfg"]
        fs, fp, fe, max_s = ec["fs"], ec["fp"], ec["fe"], ec["max_s"]

        key_transform(r_obj, 1, loc=(0, 0, 500), scale=(0.01, 0.01, 0.01))
        key_transform(r_obj, fs - 1, loc=(0, 0, 500), scale=(0.01, 0.01, 0.01))

        key_transform(r_obj, fs, loc=ec["pos"], scale=(0.25, 0.25, 0.25))
        l_obj.data.energy = 12.0
        l_obj.data.keyframe_insert("energy", frame=fs)

        key_transform(r_obj, fp, loc=ec["pos"], scale=(max_s * 0.72, max_s * 0.72, max_s * 0.72))
        l_obj.data.energy = 50.0 if ec["name"] == "Exp_Climax" else 32.0
        l_obj.data.keyframe_insert("energy", frame=fp)

        key_transform(r_obj, fe, loc=ec["pos"], scale=(max_s, max_s, max_s))
        l_obj.data.energy = 0.0
        l_obj.data.keyframe_insert("energy", frame=fe)

        key_transform(r_obj, fe + 1, loc=(0, 0, 500), scale=(0.01, 0.01, 0.01))

    sanitize_all_keyframes()

    # -------------------------------------------------------------------------
    # 2. MASTER SEQUENCER SCENE: VSE COMPOSITING, OPTICAL TRANSITIONS & MASTERED AUDIO
    # -------------------------------------------------------------------------
    scene_seq = bpy.data.scenes.new("Scene_Seq")
    bpy.context.window.scene = scene_seq
    scene_seq.render.resolution_x = 1920
    scene_seq.render.resolution_y = 1080
    scene_seq.render.fps = 24
    scene_seq.frame_start = 1
    scene_seq.frame_end = total_frames
    scene_seq.sequence_editor_create()
    se = scene_seq.sequence_editor
    se_strips = getattr(se, "strips", None) if hasattr(se, "strips") else se.sequences

    def add_effect_strip(name, eff_type, channel, f_start, f_end):
        try:
            return se_strips.new_effect(name=name, type=eff_type, channel=channel, frame_start=f_start, length=max(1, f_end - f_start))
        except TypeError:
            return se_strips.new_effect(name=name, type=eff_type, channel=channel, frame_start=f_start, frame_end=f_end)

    strip_3d = se_strips.new_scene(name="3D_Layer", scene=scene_3d, channel=1, frame_start=1)
    strip_3d.frame_final_duration = total_frames
    strip_3d.scene_input = 'CAMERA'
    strip_3d.scene_camera = cam_obj

    for idx, cut_f in enumerate([110, 220, 330]):
        dip = add_effect_strip(f"Optical_Bridge_{idx}", 'COLOR', 4, cut_f - 6, cut_f + 7)
        dip.color = (0.003, 0.008, 0.018)
        dip.blend_type = 'ALPHA_OVER'
        dip.blend_alpha = 0.0
        dip.keyframe_insert("blend_alpha", frame=cut_f - 6)
        dip.blend_alpha = 0.90
        dip.keyframe_insert("blend_alpha", frame=cut_f)
        dip.blend_alpha = 0.90
        dip.keyframe_insert("blend_alpha", frame=cut_f + 1)
        dip.blend_alpha = 0.0
        dip.keyframe_insert("blend_alpha", frame=cut_f + 7)

    titles = [
        {"start": 10, "end": 104, "h": "PROLOGUE", "sub": "In the beginning, the void was not empty.\nIt was the Star Sea... an ocean of dark energy called the Éther."},
        {"start": 118, "end": 214, "h": "THE ARMADA OF ACERO", "sub": "An empire of steel that burned the wind as fuel,\nforging colossal battle lines to tame the deep."},
        {"start": 228, "end": 324, "h": "THE VINCULADOS", "sub": "Awakened pilots coupled to colossal Mobile Armor & neural funnels,\nsinging in harmonic resonance across the void."},
        {"start": 338, "end": 434, "h": "THE FREE TIDE", "sub": "Sovereign corsairs who unfurled quantum sails and mechanical oars,\nriding the untamed breath of creation."},
        {"start": 448, "end": 520, "h": "THE CALM", "sub": "Then came the silence. A creeping frost of dead vacuum.\nWhere the Calm arrives, the wind dies... fleets are becalmed."},
        {"start": 532, "end": 628, "h": "THE LAST CURRENT", "sub": "Three armadas clash for the surviving currents.\nIn the dying sea... to drift is to die."}
    ]

    for t in titles:
        th = add_effect_strip(f"TH_{t['start']}", 'TEXT', 2, t["start"], t["end"])
        th.text = t["h"]
        th.font_size = 52
        if hasattr(th, "alignment_x"):
            th.alignment_x = 'CENTER'
        elif hasattr(th, "align_x"):
            th.align_x = 'CENTER'
        if hasattr(th, "anchor_y"):
            th.anchor_y = 'BOTTOM'
        elif hasattr(th, "align_y"):
            th.align_y = 'BOTTOM'
        th.location = (0.5, 0.16)
        th.color = (0.35, 0.90, 1.0, 1.0)
        th.use_shadow = True
        th.shadow_color = (0.0, 0.0, 0.0, 0.95)

        th.blend_alpha = 0.0
        th.keyframe_insert("blend_alpha", frame=t["start"])
        th.blend_alpha = 1.0
        th.keyframe_insert("blend_alpha", frame=t["start"] + 12)
        th.blend_alpha = 1.0
        th.keyframe_insert("blend_alpha", frame=t["end"] - 12)
        th.blend_alpha = 0.0
        th.keyframe_insert("blend_alpha", frame=t["end"])

        tm = add_effect_strip(f"TM_{t['start']}", 'TEXT', 3, t["start"] + 4, t["end"])
        tm.text = t["sub"]
        tm.font_size = 34
        if hasattr(tm, "alignment_x"):
            tm.alignment_x = 'CENTER'
        elif hasattr(tm, "align_x"):
            tm.align_x = 'CENTER'
        if hasattr(tm, "anchor_y"):
            tm.anchor_y = 'BOTTOM'
        elif hasattr(tm, "align_y"):
            tm.align_y = 'BOTTOM'
        tm.location = (0.5, 0.06)
        tm.color = (0.92, 0.94, 0.98, 1.0)
        tm.use_shadow = True
        tm.shadow_color = (0.0, 0.0, 0.0, 0.95)

        tm.blend_alpha = 0.0
        tm.keyframe_insert("blend_alpha", frame=t["start"] + 4)
        tm.blend_alpha = 1.0
        tm.keyframe_insert("blend_alpha", frame=t["start"] + 16)
        tm.blend_alpha = 1.0
        tm.keyframe_insert("blend_alpha", frame=t["end"] - 16)
        tm.blend_alpha = 0.0
        tm.keyframe_insert("blend_alpha", frame=t["end"])

    # FINALE: Canonical BARLOVENTO Logo (Channel 5)
    logo_path = asset_p("assets/brand/logo.png")
    if os.path.exists(logo_path):
        logo_strip = se_strips.new_image(name="Canonical_Barlovento_Logo", filepath=logo_path, channel=5, frame_start=634)
        logo_strip.frame_final_duration = 126
        logo_strip.blend_type = 'ALPHA_OVER'

        logo_strip.transform.scale_x = 1.42
        logo_strip.transform.scale_y = 1.42
        logo_strip.transform.keyframe_insert("scale_x", frame=634)
        logo_strip.transform.keyframe_insert("scale_y", frame=634)

        logo_strip.transform.scale_x = 1.49
        logo_strip.transform.scale_y = 1.49
        logo_strip.transform.keyframe_insert("scale_x", frame=760)
        logo_strip.transform.keyframe_insert("scale_y", frame=760)

        logo_strip.blend_alpha = 0.0
        logo_strip.keyframe_insert("blend_alpha", frame=634)
        logo_strip.blend_alpha = 1.0
        logo_strip.keyframe_insert("blend_alpha", frame=646)
        logo_strip.blend_alpha = 1.0
        logo_strip.keyframe_insert("blend_alpha", frame=726)
        logo_strip.blend_alpha = 0.0
        logo_strip.keyframe_insert("blend_alpha", frame=756)

    flash_bridge = add_effect_strip("Resonance_Shockwave_Flash", 'COLOR', 6, 634, 654)
    flash_bridge.color = (0.50, 0.94, 1.0)
    flash_bridge.blend_type = 'ADD'
    flash_bridge.blend_alpha = 0.0
    flash_bridge.keyframe_insert("blend_alpha", frame=634)
    flash_bridge.blend_alpha = 0.85
    flash_bridge.keyframe_insert("blend_alpha", frame=642)
    flash_bridge.blend_alpha = 0.0
    flash_bridge.keyframe_insert("blend_alpha", frame=652)

    sub_final = add_effect_strip("Sub_Final", 'TEXT', 7, 654, 755)
    sub_final.text = "EL ÚLTIMO VIENTO\nFight for the weather gauge."
    sub_final.font_size = 36
    if hasattr(sub_final, "alignment_x"):
        sub_final.alignment_x = 'CENTER'
    elif hasattr(sub_final, "align_x"):
        sub_final.align_x = 'CENTER'
    if hasattr(sub_final, "anchor_y"):
        sub_final.anchor_y = 'BOTTOM'
    elif hasattr(sub_final, "align_y"):
        sub_final.align_y = 'BOTTOM'
    sub_final.location = (0.5, 0.14)
    sub_final.color = (0.35, 0.90, 1.0, 1.0)
    sub_final.use_shadow = True
    sub_final.shadow_color = (0.0, 0.0, 0.0, 0.95)

    sub_final.blend_alpha = 0.0
    sub_final.keyframe_insert("blend_alpha", frame=654)
    sub_final.blend_alpha = 1.0
    sub_final.keyframe_insert("blend_alpha", frame=668)
    sub_final.blend_alpha = 1.0
    sub_final.keyframe_insert("blend_alpha", frame=726)
    sub_final.blend_alpha = 0.0
    sub_final.keyframe_insert("blend_alpha", frame=755)

    fade_black = add_effect_strip("Fade_To_Black", 'COLOR', 8, 730, 760)
    fade_black.color = (0.0, 0.0, 0.0)
    fade_black.blend_type = 'ALPHA_OVER'
    fade_black.blend_alpha = 0.0
    fade_black.keyframe_insert("blend_alpha", frame=730)
    fade_black.blend_alpha = 1.0
    fade_black.keyframe_insert("blend_alpha", frame=758)

    master_wav = asset_p("assets/audio/master_intro_mix.wav")
    if os.path.exists(master_wav):
        snd_master = se_strips.new_sound(name="Master_Audio_Mix", filepath=master_wav, channel=8, frame_start=1)
        snd_master.volume = 1.0

    return scene_3d, scene_seq

def build_3d_cinematic(output_ogv_path: str, output_mp4_path: str = None):
    scene_3d, scene_seq = setup_cinematic_scene()
    if hasattr(scene_seq.render.image_settings, "media_type"):
        scene_seq.render.image_settings.media_type = 'VIDEO'
    if "FFMPEG" in [e.identifier for e in scene_seq.render.image_settings.bl_rna.properties['file_format'].enum_items]:
        scene_seq.render.image_settings.file_format = 'FFMPEG'

    # 1. Render OGV (Theora + Vorbis) for Godot 4 VideoStreamPlayer
    scene_seq.render.ffmpeg.format = 'OGG'
    scene_seq.render.ffmpeg.codec = 'THEORA'
    scene_seq.render.ffmpeg.audio_codec = 'VORBIS'
    scene_seq.render.ffmpeg.video_bitrate = 12000
    scene_seq.render.filepath = os.path.abspath(output_ogv_path)

    print(f"==> Rendering 1080p AAA 3D cinematic OGV to {scene_seq.render.filepath}...")
    bpy.ops.render.render(animation=True)
    print("==> OGV Render Complete!")

    # 2. Optionally transcode MP4 (H.264 + AAC) for Web Landing Page without re-rendering 3D!
    if output_mp4_path:
        scene_tc = bpy.data.scenes.new("Scene_Transcode")
        bpy.context.window.scene = scene_tc
        scene_tc.render.resolution_x = 1920
        scene_tc.render.resolution_y = 1080
        scene_tc.render.fps = 24
        scene_tc.frame_start = 1
        scene_tc.frame_end = scene_seq.frame_end
        if hasattr(scene_tc.render.image_settings, "media_type"):
            scene_tc.render.image_settings.media_type = 'VIDEO'
        if "FFMPEG" in [e.identifier for e in scene_tc.render.image_settings.bl_rna.properties['file_format'].enum_items]:
            scene_tc.render.image_settings.file_format = 'FFMPEG'
        scene_tc.render.ffmpeg.format = 'MPEG4'
        scene_tc.render.ffmpeg.codec = 'H264'
        scene_tc.render.ffmpeg.audio_codec = 'AAC'
        scene_tc.render.ffmpeg.video_bitrate = 12000
        scene_tc.render.filepath = os.path.abspath(output_mp4_path)

        scene_tc.sequence_editor_create()
        tc_se = scene_tc.sequence_editor
        tc_strips = getattr(tc_se, "strips", None) if hasattr(tc_se, "strips") else tc_se.sequences
        tc_strips.new_movie(name="Rendered_OGV", filepath=os.path.abspath(output_ogv_path), channel=1, frame_start=1)
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        master_wav = os.path.join(base_dir, "assets", "audio", "master_intro_mix.wav")
        if os.path.exists(master_wav):
            tc_strips.new_sound(name="Master_Audio", filepath=master_wav, channel=2, frame_start=1)

        print(f"==> Transcoding 1080p AAA 3D cinematic MP4 to {scene_tc.render.filepath}...")
        bpy.ops.render.render(animation=True)
        print("==> MP4 Render Complete!")

if __name__ == "__main__":
    if "--preview-shots" in sys.argv:
        scene_3d, scene_seq = setup_cinematic_scene()
        bpy.context.window.scene = scene_seq
        scene_seq.render.image_settings.file_format = 'PNG'
        preview_list = [
            ("shot1_starsea", 55),
            ("shot2_acero", 165),
            ("shot3_vinculados", 285),
            ("shot4_marea", 385),
            ("shot6_battle_wide", 572),
            ("shot7_logo", 685),
        ]
        for name, f_num in preview_list:
            scene_seq.frame_set(f_num)
            scene_seq.render.filepath = os.path.abspath(f"assets/preview_{name}.png")
            bpy.ops.render.render(write_still=True)
        print("==> Preview shots rendered successfully!")
    else:
        out_ogv = os.path.join("assets", "video", "intro.ogv")
        out_mp4 = os.path.join("assets", "video", "intro.mp4") if "--with-mp4" in sys.argv else None
        build_3d_cinematic(out_ogv, out_mp4)
