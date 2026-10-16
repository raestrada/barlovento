"""
BARLOVENTO — AAA 3D Cinematic Prologue Renderer (v7 Seamless & Articulated Gundam Edition)
1920x1080 Full HD | Hierarchical Articulated Space Gundam Rig | Unbroken Continuous Shot Transitions | Mastered Real Audio
"""

import os
import sys
import math
import random
import bpy
import bmesh
import mathutils

# -------------------------------------------------------------------------
# ADVANCED PROCEDURAL PBR & SHADER MATERIALS
# -------------------------------------------------------------------------
def create_pbr_hull_material(name, base_color, metallic=0.80, roughness=0.32, texture_path=None, tex_scale=0.4, bump_strength=0.35, coat=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = base_color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat

    if texture_path and os.path.exists(texture_path):
        coord = nodes.new("ShaderNodeTexCoord")
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (tex_scale, tex_scale, tex_scale)

        tex = nodes.new("ShaderNodeTexImage")
        tex.projection = 'BOX'
        tex.projection_blend = 0.25
        tex.image = bpy.data.images.load(texture_path)

        mix = nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.inputs["Factor"].default_value = 0.25
        mix.inputs[6].default_value = base_color

        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = bump_strength
        bump.inputs["Distance"].default_value = 0.04

        links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
        links.new(tex.outputs["Color"], mix.inputs[7])
        links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        links.new(tex.outputs["Color"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    return mat

def create_ribbed_sinew_material(name):
    """Dark biomechanical carbon-muscle shader with procedural striated sinew bump (matches suit_concept.png)."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.035, 0.042, 0.065, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.72
    bsdf.inputs["Roughness"].default_value = 0.36

    coord = nodes.new("ShaderNodeTexCoord")
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'Z'
    wave.inputs["Scale"].default_value = 18.0
    wave.inputs["Distortion"].default_value = 1.5

    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.45
    bump.inputs["Distance"].default_value = 0.02

    links.new(coord.outputs["Object"], wave.inputs["Vector"])
    links.new(wave.outputs["Color"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat

def create_asteroid_rock_material(name):
    """Dark carbonaceous asteroid shader with 3D Voronoi + Noise micro-bump."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Metallic"].default_value = 0.08
    bsdf.inputs["Roughness"].default_value = 0.92

    coord = nodes.new("ShaderNodeTexCoord")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 4.5
    noise.inputs["Detail"].default_value = 12.0
    noise.inputs["Roughness"].default_value = 0.78

    vor = nodes.new("ShaderNodeTexVoronoi")
    vor.feature = 'DISTANCE_TO_EDGE'
    vor.inputs["Scale"].default_value = 7.5

    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.2
    ramp.color_ramp.elements[0].color = (0.025, 0.030, 0.038, 1.0)
    ramp.color_ramp.elements[1].position = 0.85
    ramp.color_ramp.elements[1].color = (0.10, 0.11, 0.13, 1.0)

    bump1 = nodes.new("ShaderNodeBump")
    bump1.inputs["Strength"].default_value = 0.90
    bump1.inputs["Distance"].default_value = 0.12

    bump2 = nodes.new("ShaderNodeBump")
    bump2.inputs["Strength"].default_value = 0.50
    bump2.inputs["Distance"].default_value = 0.06

    links.new(coord.outputs["Object"], noise.inputs["Vector"])
    links.new(coord.outputs["Object"], vor.inputs["Vector"])
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(noise.outputs["Fac"], bump1.inputs["Height"])
    links.new(vor.outputs["Distance"], bump2.inputs["Height"])
    links.new(bump1.outputs["Normal"], bump2.inputs["Normal"])
    links.new(bump2.outputs["Normal"], bsdf.inputs["Normal"])

    return mat

def create_emissive_material(name, color, strength=4.0, alpha=1.0):
    """Rich non-clipping emissive shader so colors stay saturated instead of blowing out to white."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")

    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Emission Color"].default_value = color
    bsdf.inputs["Emission Strength"].default_value = strength

    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(mat, "blend_method"):
            mat.blend_method = 'BLEND'

    return mat

# -------------------------------------------------------------------------
# GEOMETRY PRIMITIVE & LOFTING HELPERS
# -------------------------------------------------------------------------
def add_subsurf(obj, levels=1):
    mod = obj.modifiers.new("Subsurf", 'SUBSURF')
    mod.levels = levels
    mod.render_levels = levels
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj

def make_pivot(name, parent, collection, loc=(0,0,0), rot=(0,0,0)):
    piv = bpy.data.objects.new(name, None)
    piv.location = loc
    piv.rotation_euler = rot
    collection.objects.link(piv)
    piv.parent = parent
    return piv

def make_part(name, bm, parent, collection, material=None, loc=(0,0,0), rot=(0,0,0), scale=(1,1,1), subsurf=0, smooth=False):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    if smooth or subsurf > 0:
        for p in mesh.polygons:
            p.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    obj.location = loc
    obj.rotation_euler = rot
    obj.scale = scale
    if material:
        obj.data.materials.append(material)
    collection.objects.link(obj)
    obj.parent = parent
    if subsurf > 0:
        add_subsurf(obj, subsurf)
    return obj

def part_box(name, size, parent, col, mat, loc=(0,0,0), rot=(0,0,0), scale=(1,1,1), subsurf=0, bevel=0.0, smooth=False):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges, offset=bevel, segments=2, profile=0.5)
    return make_part(name, bm, parent, col, mat, loc, rot, scale=scale, subsurf=subsurf, smooth=(smooth or subsurf > 0))

def part_taper_box(name, size_bot, size_top, height, parent, col, mat, loc=(0,0,0), rot=(0,0,0), bevel=0.02, smooth=False):
    bm = bmesh.new()
    bx, by = size_bot[0] * 0.5, size_bot[1] * 0.5
    tx, ty = size_top[0] * 0.5, size_top[1] * 0.5
    hz = height * 0.5
    v0 = bm.verts.new((-bx, -by, -hz))
    v1 = bm.verts.new(( bx, -by, -hz))
    v2 = bm.verts.new(( bx,  by, -hz))
    v3 = bm.verts.new((-bx,  by, -hz))
    v4 = bm.verts.new((-tx, -ty,  hz))
    v5 = bm.verts.new(( tx, -ty,  hz))
    v6 = bm.verts.new(( tx,  ty,  hz))
    v7 = bm.verts.new((-tx,  ty,  hz))
    bm.faces.new((v0, v3, v2, v1))
    bm.faces.new((v4, v5, v6, v7))
    bm.faces.new((v0, v1, v5, v4))
    bm.faces.new((v1, v2, v6, v5))
    bm.faces.new((v2, v3, v7, v6))
    bm.faces.new((v3, v0, v4, v7))
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges, offset=bevel, segments=2, profile=0.5)
    return make_part(name, bm, parent, col, mat, loc, rot, smooth=smooth)

def part_cyl(name, r1, r2, depth, parent, col, mat, loc=(0,0,0), rot=(0,0,0), scale=(1,1,1), segs=20, subsurf=0, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=depth)
    return make_part(name, bm, parent, col, mat, loc, rot, scale=scale, subsurf=subsurf, smooth=smooth)

def part_sphere(name, radius, parent, col, mat, loc=(0,0,0), scale=(1,1,1), rot=(0,0,0), subdiv=3):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    return make_part(name, bm, parent, col, mat, loc, rot, scale=scale, smooth=True)

def build_lofted_mesh(name, profile_pts, stations, parent, col, mat, loc=(0,0,0), rot=(0,0,0), subsurf=0, smooth=False):
    bm = bmesh.new()
    rings = []
    for y_pos, sx, sz, oz in stations:
        ring = []
        for px, pz in profile_pts:
            v = bm.verts.new((px * sx, y_pos, pz * sz + oz))
            ring.append(v)
        rings.append(ring)

    n = len(profile_pts)
    for i in range(len(rings) - 1):
        r1, r2 = rings[i], rings[i + 1]
        for j in range(n):
            jn = (j + 1) % n
            bm.faces.new((r1[j], r1[jn], r2[jn], r2[j]))

    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    return make_part(name, bm, parent, col, mat, loc, rot, subsurf=subsurf, smooth=smooth)

def build_vertical_loft(name, profile_xy, z_stations, parent, col, mat, loc=(0,0,0), rot=(0,0,0), subsurf=0, smooth=False, bevel=0.0, sharp_caps=True):
    bm = bmesh.new()
    expanded_stations = []
    if sharp_caps and len(z_stations) >= 2 and subsurf > 0:
        z0, sx0, sy0, ox0, oy0 = z_stations[0]
        z1, sx1, sy1, ox1, oy1 = z_stations[1]
        expanded_stations.append((z0, sx0 * 0.96, sy0 * 0.96, ox0, oy0))
        expanded_stations.append((z0 + (z1 - z0) * 0.08, sx0, sy0, ox0, oy0))
        for st in z_stations[1:-1]:
            expanded_stations.append(st)
        zn1, sxn1, syn1, oxn1, oyn1 = z_stations[-2]
        zn, sxn, syn, oxn, oyn = z_stations[-1]
        expanded_stations.append((zn - (zn - zn1) * 0.08, sxn, syn, oxn, oyn))
        expanded_stations.append((zn, sxn * 0.96, syn * 0.96, oxn, oyn))
    else:
        expanded_stations = list(z_stations)

    rings = []
    for z_pos, sx, sy, ox, oy in expanded_stations:
        ring = []
        for px, py in profile_xy:
            v = bm.verts.new((px * sx + ox, py * sy + oy, z_pos))
            ring.append(v)
        rings.append(ring)

    n = len(profile_xy)
    for i in range(len(rings) - 1):
        r1, r2 = rings[i], rings[i + 1]
        for j in range(n):
            jn = (j + 1) % n
            bm.faces.new((r1[j], r1[jn], r2[jn], r2[j]))

    bm.faces.new(rings[0][::-1])
    bm.faces.new(rings[-1])
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges, offset=bevel, segments=2, profile=0.5)
    return make_part(name, bm, parent, col, mat, loc, rot, subsurf=subsurf, smooth=smooth)

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

def rads(deg_tuple):
    return (math.radians(deg_tuple[0]), math.radians(deg_tuple[1]), math.radians(deg_tuple[2]))

def key_gundam_pose(rig, frame, loc=None, rot_deg=None, torso_deg=None, head_deg=None,
                    binder_l_deg=None, binder_r_deg=None,
                    sh_l_deg=None, el_l_deg=None, sh_r_deg=None, el_r_deg=None,
                    hip_l_deg=None, kn_l_deg=None, ank_l_deg=None,
                    hip_r_deg=None, kn_r_deg=None, ank_r_deg=None):
    """Animates the full hierarchical Space Gundam skeleton (zero mannequin stiffness!)."""
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
    """
    Ensures off-screen teleports (|co| >= 400) use CONSTANT interpolation so nothing drifts across the screen,
    laser bolts use LINEAR interpolation, and all articulated Gundam joints & camera moves use smooth AUTO_CLAMPED Bezier!
    """
    for action in bpy.data.actions:
        is_laser = "BattleLaser" in action.name
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

# -------------------------------------------------------------------------
# 1. HIGH-DETAIL ASTEROID FIELD (Parented to Root so it ONLY appears in Shot 1!)
# -------------------------------------------------------------------------
def build_asteroid_field(collection, count=24):
    ast_root = bpy.data.objects.new("Asteroid_Field_Root", None)
    collection.objects.link(ast_root)

    mat_rock = create_asteroid_rock_material("Asteroid_Basalt")
    rng = random.Random(2028)

    for i in range(count):
        x = rng.uniform(-16, 16)
        if abs(x) < 2.5:
            x += 4.5 if x >= 0 else -4.5
        y = rng.uniform(-24, 18)
        z = rng.uniform(-7, 7)

        r = rng.uniform(0.45, 1.75)
        rot = (rng.uniform(0, 6.28), rng.uniform(0, 6.28), rng.uniform(0, 6.28))

        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=3, radius=r)
        craters = []
        for _ in range(4):
            cdir = mathutils.Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized()
            craters.append((cdir, rng.uniform(0.30, 0.55), rng.uniform(0.22, 0.40)))

        sx, sy, sz = rng.uniform(0.8, 1.35), rng.uniform(0.65, 1.15), rng.uniform(0.75, 1.25)
        ph = rng.uniform(0, 10)
        for v in bm.verts:
            v.co.x *= sx
            v.co.y *= sy
            v.co.z *= sz
            n = v.co.normalized()
            d_noise = (math.sin(v.co.x * 1.9 + ph) * math.cos(v.co.y * 2.2) * math.sin(v.co.z * 2.1)) * 0.22 * r
            d_noise += (math.cos(v.co.x * 4.8) * math.sin(v.co.y * 5.3 + ph)) * 0.08 * r
            v.co += n * d_noise
            for cdir, crad, cdepth in craters:
                d = (n - cdir).length
                if d < crad:
                    f = 1.0 - (d / crad)
                    v.co -= n * (math.sin(f * math.pi * 0.5) * cdepth * r)
                    if f < 0.28:
                        v.co += n * (f * 0.22 * r)

        mesh = bpy.data.meshes.new(f"Ast_{i}_Mesh")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        for p in mesh.polygons:
            p.use_smooth = True

        obj = bpy.data.objects.new(f"Asteroid_{i}", mesh)
        obj.location = (x, y, z)
        obj.rotation_euler = rot
        obj.data.materials.append(mat_rock)
        collection.objects.link(obj)
        obj.parent = ast_root

        key_transform(obj, 1, loc=(x, y, z), rot=rot)
        key_transform(obj, 118, loc=(x, y, z), rot=(rot[0] + 0.35, rot[1] - 0.28, rot[2] + 0.42))

    return ast_root

# -------------------------------------------------------------------------
# 2. THE ARMADA OF ACERO — HEAVY INDUSTRIAL DREADNOUGHT (Matches dreadnought_concept.png)
# -------------------------------------------------------------------------
def build_acero_dreadnought(collection, texture_path, name_prefix="Acero_Dreadnought", scale_factor=1.0, is_escort=False):
    root = bpy.data.objects.new(name_prefix, None)
    collection.objects.link(root)

    mat_hull = create_pbr_hull_material(f"{name_prefix}_Steel", (0.20, 0.24, 0.29, 1.0), metallic=0.88, roughness=0.32, texture_path=texture_path, tex_scale=0.32, bump_strength=0.48)
    mat_dark = create_pbr_hull_material(f"{name_prefix}_DarkArmor", (0.08, 0.10, 0.13, 1.0), metallic=0.92, roughness=0.40, texture_path=texture_path, tex_scale=0.5, bump_strength=0.38)
    mat_amber = create_emissive_material(f"{name_prefix}_AmberConduit", (1.0, 0.62, 0.08, 1.0), strength=6.5)
    mat_engine = create_emissive_material(f"{name_prefix}_EngineCore", (1.0, 0.48, 0.05, 1.0), strength=18.0)
    mat_plume = create_emissive_material(f"{name_prefix}_EnginePlume", (1.0, 0.35, 0.02, 0.72), strength=10.0, alpha=0.72)

    prof = [
        (-0.55, -1.0), (0.55, -1.0),
        (1.18, -0.45), (1.28, 0.35),
        (0.75, 1.0), (-0.75, 1.0),
        (-1.28, 0.35), (-1.18, -0.45)
    ]
    stations = [
        (8.6,  0.16, 0.48, -0.10),
        (7.4,  0.48, 0.75, -0.05),
        (4.8,  0.88, 0.94,  0.0),
        (1.5,  1.15, 1.08,  0.0),
        (-3.5, 1.24, 1.12,  0.0),
        (-7.4, 1.04, 1.00,  0.0),
    ]
    build_lofted_mesh(f"{name_prefix}_MainHull", prof, stations, root, collection, mat_hull, smooth=False)

    for side in [-1.0, 1.0]:
        part_taper_box(f"{name_prefix}_BowCheek_{side}", (0.35, 2.8), (0.22, 1.8), 1.1, root, collection, mat_dark,
                       loc=(side * 0.42, 7.2, -0.08), rot=(0, math.radians(side * 12), 0), bevel=0.03)
        part_box(f"{name_prefix}_BowConduit_{side}", (0.04, 4.2, 0.05), root, collection, mat_amber,
                 loc=(side * 0.96, 4.4, 0.18), rot=(0, 0, math.radians(side * -7)))

    sponson_prof = [(-0.45, -0.60), (0.45, -0.48), (0.55, 0.48), (-0.45, 0.60)]
    for side in [-1.0, 1.0]:
        sp_stations = [
            (6.0,  0.25, 0.45, -0.12),
            (3.2,  0.85, 0.78, -0.08),
            (0.8,  1.50, 1.10, -0.04),
            (-4.2, 1.50, 1.10, -0.04),
            (-6.8, 0.85, 0.82, -0.08),
        ]
        build_lofted_mesh(f"{name_prefix}_Sponson_{side}", sponson_prof, sp_stations, root, collection, mat_hull,
                          loc=(side * 1.48, 0, 0), rot=(0, 0, 0 if side > 0 else math.pi))

        part_box(f"{name_prefix}_IntakeGlowTop_{side}", (0.55, 0.08, 0.06), root, collection, mat_amber,
                 loc=(side * 1.75, 0.95, 0.55), rot=(0, math.radians(side * -15), math.radians(side * -25)))
        part_box(f"{name_prefix}_IntakeGlowMid_{side}", (0.08, 0.12, 0.95), root, collection, mat_amber,
                 loc=(side * 2.15, 0.85, -0.04))
        part_box(f"{name_prefix}_IntakeGlowBot_{side}", (0.55, 0.08, 0.06), root, collection, mat_amber,
                 loc=(side * 1.75, 0.95, -0.62), rot=(0, math.radians(side * 15), math.radians(side * -25)))

        for gy in [-3.4, -2.2, -1.0, 0.2]:
            part_box(f"{name_prefix}_GreebleTop_{side}_{gy}", (0.48, 0.75, 0.26), root, collection, mat_dark,
                     loc=(side * 1.72, gy, 0.58), bevel=0.02)
            part_box(f"{name_prefix}_Casemate_{side}_{gy}", (0.35, 0.82, 0.38), root, collection, mat_dark,
                     loc=(side * 2.18, gy, -0.05), bevel=0.02)
            part_cyl(f"{name_prefix}_BroadGun_{side}_{gy}", 0.035, 0.025, 0.85, root, collection, mat_hull,
                     loc=(side * 2.42, gy + 0.25, -0.05), rot=(math.radians(-75), math.radians(side * 20), 0), segs=10)

        for wy in range(-5, 6):
            if wy not in [0, 1]:
                part_box(f"{name_prefix}_Port_{side}_{wy}", (0.04, 0.16, 0.04), root, collection, mat_amber,
                         loc=(side * 2.16 if wy < 1 else side * 1.52, wy * 0.75, 0.22))

    part_taper_box(f"{name_prefix}_SpineDeck", (1.65, 9.6), (1.35, 8.8), 0.55, root, collection, mat_dark,
                   loc=(0, -0.4, 1.25), bevel=0.03)

    if not is_escort:
        part_taper_box(f"{name_prefix}_Citadel_L1", (2.1, 3.6), (1.7, 3.0), 0.95, root, collection, mat_hull,
                       loc=(0, -2.1, 1.85), bevel=0.03)
        part_taper_box(f"{name_prefix}_Citadel_L2", (1.5, 2.4), (1.2, 1.9), 1.05, root, collection, mat_hull,
                       loc=(0, -2.3, 2.75), bevel=0.03)
        part_taper_box(f"{name_prefix}_Citadel_L3", (1.05, 1.5), (0.85, 1.2), 0.85, root, collection, mat_dark,
                       loc=(0, -2.4, 3.60), bevel=0.02)
        for bz in [2.15, 2.95, 3.72]:
            part_box(f"{name_prefix}_BridgeGlow_{bz}", (0.78, 0.06, 0.05), root, collection, mat_amber,
                     loc=(0, -1.32 if bz < 3.0 else -1.68, bz))
        for mx in [-0.32, 0.0, 0.32]:
            part_cyl(f"{name_prefix}_Mast_{mx}", 0.025, 0.01, 1.5, root, collection, mat_hull,
                     loc=(mx, -2.5, 4.55), segs=8)

        fin_prof = [(-0.18, 0.0), (0.18, 0.0), (0.09, 1.0), (-0.09, 1.0)]
        fin_st = [(-3.6, 1.0, 0.2, 1.45), (-4.4, 1.0, 2.6, 1.45), (-5.6, 0.8, 2.6, 1.45), (-6.4, 0.5, 0.2, 1.45)]
        build_lofted_mesh(f"{name_prefix}_DorsalFin", fin_prof, fin_st, root, collection, mat_hull)

        vfin_st = [(-2.2, 1.0, -0.2, -1.05), (-3.2, 1.0, -1.7, -1.05), (-4.8, 0.8, -1.6, -1.05), (-5.5, 0.5, -0.2, -1.05)]
        build_lofted_mesh(f"{name_prefix}_VentralFin", fin_prof, vfin_st, root, collection, mat_dark)

    t_positions = [(4.6, 1.48), (2.5, 1.68), (0.4, 1.88)] if not is_escort else [(3.4, 1.48), (0.8, 1.65)]
    for idx, (ty, tz) in enumerate(t_positions):
        part_cyl(f"{name_prefix}_Barbette_{idx}", 0.52, 0.58, 0.35, root, collection, mat_dark, loc=(0, ty, tz - 0.12), segs=12, smooth=False)
        part_taper_box(f"{name_prefix}_TurretHouse_{idx}", (1.05, 1.35), (0.78, 1.05), 0.38, root, collection, mat_hull,
                       loc=(0, ty, tz + 0.14), bevel=0.03)
        for bx in [-0.24, 0.0, 0.24]:
            part_cyl(f"{name_prefix}_Barrel_{idx}_{bx}", 0.055, 0.04, 1.75, root, collection, mat_dark,
                     loc=(bx, ty + 1.15, tz + 0.18), rot=(math.radians(-84), 0, 0), segs=12)

    eng_coords = [(-1.15, 0.48), (1.15, 0.48), (-1.15, -0.48), (1.15, -0.48)] if not is_escort else [(-0.85, 0.0), (0.85, 0.0)]
    for idx, (ex, ez) in enumerate(eng_coords):
        part_cyl(f"{name_prefix}_Shroud_{idx}", 0.68, 0.60, 2.6, root, collection, mat_dark,
                 loc=(ex, -7.8, ez), rot=(math.radians(90), 0, 0), segs=20)
        part_cyl(f"{name_prefix}_Rim_{idx}", 0.62, 0.56, 0.45, root, collection, mat_hull,
                 loc=(ex, -9.0, ez), rot=(math.radians(90), 0, 0), segs=20)
        part_cyl(f"{name_prefix}_Core_{idx}", 0.48, 0.42, 0.25, root, collection, mat_engine,
                 loc=(ex, -9.18, ez), rot=(math.radians(90), 0, 0), segs=20)
        part_cyl(f"{name_prefix}_Plume_{idx}", 0.44, 0.04, 2.8, root, collection, mat_plume,
                 loc=(ex, -10.6, ez), rot=(math.radians(90), 0, 0), segs=16)

    root.scale = (scale_factor, scale_factor, scale_factor)
    return root

# -------------------------------------------------------------------------
# 3. THE VINCULADOS — HIERARCHICAL ARTICULATED SPACE GUNDAM RIG (Matches suit_concept.png!)
# -------------------------------------------------------------------------
def build_vinculados_suit(collection, texture_path, name_prefix="Vinculados_Suit", scale_factor=1.0, subsurf_lvl=2):
    """
    Constructs a fully articulated Space Gundam (Mobile Suit) with hierarchical joint pivots:
    - root -> pelvis & waist
    - torso (pivots at waist z=1.58) -> chest cuirass, Soul Core, dorsal vernier backpack
      - head (pivots at neck z=1.40 on torso) -> 3-piece helmet, recessed cyan V-visor, Gundam V-Fin crest
      - binder_L / binder_R (pivot on dorsal backpack) -> swept articulated thruster wing-binders + cyan plasma plumes
      - sh_L / sh_R (pivot at shoulders) -> aerodynamic wing-pauldrons, bicep armor
        - el_L / el_R (pivot at elbows) -> flared vambraces, articulated hands, Forearm Energy Shield (L) & Resonance Beam Lance (R)
    - hip_L / hip_R (pivot at hips z=1.18 on root) -> sculpted thigh cuirass & inner sinew
      - kn_L / kn_R (pivot at knees z=-0.98 on hips) -> knee guard, shin greaves, calf vernier thrusters
        - ank_L / ank_R (pivot at ankles z=-1.04 on knees) -> high-mobility mecha boots
    """
    root = bpy.data.objects.new(name_prefix, None)
    collection.objects.link(root)

    torso = make_pivot(f"{name_prefix}_TorsoPiv", root, collection, loc=(0.0, 0.0, 1.58))
    head = make_pivot(f"{name_prefix}_HeadPiv", torso, collection, loc=(0.0, 0.0, 1.40))
    binder_L = make_pivot(f"{name_prefix}_BinderPiv_L", torso, collection, loc=(-0.34, 0.44, 1.05))
    binder_R = make_pivot(f"{name_prefix}_BinderPiv_R", torso, collection, loc=( 0.34, 0.44, 1.05))
    sh_L = make_pivot(f"{name_prefix}_ShoulderPiv_L", torso, collection, loc=(-0.70, 0.02, 0.98))
    sh_R = make_pivot(f"{name_prefix}_ShoulderPiv_R", torso, collection, loc=( 0.70, 0.02, 0.98))
    el_L = make_pivot(f"{name_prefix}_ElbowPiv_L", sh_L, collection, loc=(-0.18, 0.02, -0.66))
    el_R = make_pivot(f"{name_prefix}_ElbowPiv_R", sh_R, collection, loc=( 0.18, 0.02, -0.66))
    hip_L = make_pivot(f"{name_prefix}_HipPiv_L", root, collection, loc=(-0.40, 0.0, 1.18))
    hip_R = make_pivot(f"{name_prefix}_HipPiv_R", root, collection, loc=( 0.40, 0.0, 1.18))
    kn_L = make_pivot(f"{name_prefix}_KneePiv_L", hip_L, collection, loc=(-0.02, 0.0, -0.98))
    kn_R = make_pivot(f"{name_prefix}_KneePiv_R", hip_R, collection, loc=( 0.02, 0.0, -0.98))
    ank_L = make_pivot(f"{name_prefix}_AnklePiv_L", kn_L, collection, loc=(-0.04, 0.02, -1.04))
    ank_R = make_pivot(f"{name_prefix}_AnklePiv_R", kn_R, collection, loc=( 0.04, 0.02, -1.04))

    mat_ceramic = create_pbr_hull_material(f"{name_prefix}_Ceramic", (0.88, 0.91, 0.96, 1.0), metallic=0.28, roughness=0.18, texture_path=texture_path, tex_scale=0.65, bump_strength=0.18, coat=0.90)
    mat_silver = create_pbr_hull_material(f"{name_prefix}_SilverTrim", (0.55, 0.60, 0.70, 1.0), metallic=0.68, roughness=0.24)
    mat_sinew = create_ribbed_sinew_material(f"{name_prefix}_Sinew")
    mat_core = create_emissive_material(f"{name_prefix}_SoulCore", (1.0, 0.16, 0.88, 1.0), strength=15.0)
    mat_core_ring = create_emissive_material(f"{name_prefix}_CoreRing", (0.78, 0.15, 1.0, 1.0), strength=6.0)
    mat_cyan = create_emissive_material(f"{name_prefix}_CyanVisor", (0.06, 0.92, 1.0, 1.0), strength=13.0)
    mat_plume = create_emissive_material(f"{name_prefix}_CyanPlume", (0.08, 0.88, 1.0, 0.78), strength=14.0, alpha=0.78)
    mat_shield_glow = create_emissive_material(f"{name_prefix}_ShieldEdge", (0.08, 0.88, 1.0, 0.86), strength=9.0, alpha=0.86)

    oct_prof = [
        (0.0, -1.0), (0.52, -0.90), (0.90, -0.52), (1.0, 0.0),
        (0.88, 0.58), (0.45, 0.95), (0.0, 1.0), (-0.45, 0.95),
        (-0.88, 0.58), (-1.0, 0.0), (-0.90, -0.52), (-0.52, -0.90)
    ]
    cuirass_prof = [
        (0.0,  -0.86), (0.44, -1.04), (0.84, -0.80), (1.02, -0.30),
        (0.95,  0.28), (0.62,  0.88), (0.0,   1.02), (-0.62, 0.88),
        (-0.95, 0.28), (-1.02,-0.30), (-0.84,-0.80), (-0.44,-1.04),
    ]

    # 1. PELVIS & LOWER WAIST (on root, z = 1.00 to 1.56)
    pelvis_stations = [
        (1.00, 0.14, 0.20, 0.0, -0.02),
        (1.20, 0.34, 0.30, 0.0, -0.03),
        (1.42, 0.49, 0.35, 0.0, -0.01),
        (1.56, 0.36, 0.28, 0.0,  0.00),
    ]
    build_vertical_loft(f"{name_prefix}_PelvisArmor", cuirass_prof, pelvis_stations, root, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

    # Sleek Side Hip Thruster Pods
    for side in [-1.0, 1.0]:
        part_taper_box(f"{name_prefix}_SideSkirt_{side}", (0.12, 0.34), (0.08, 0.26), 0.34, root, collection, mat_ceramic,
                       loc=(side * 0.48, 0.0, 1.30), rot=rads((0, side * -16, 0)), bevel=0.015, smooth=True)

    # 2. ARTICULATED TORSO (local z = 0.0 to 1.58 relative to torso at z=1.58)
    sinew_stations = [
        (-0.18, 0.30, 0.23, 0.0, 0.0),
        ( 0.14, 0.35, 0.25, 0.0, 0.02),
        ( 0.50, 0.44, 0.31, 0.0, 0.0),
        ( 0.90, 0.54, 0.35, 0.0, 0.0),
        ( 1.24, 0.38, 0.27, 0.0, 0.02),
        ( 1.38, 0.21, 0.21, 0.0, 0.01),
        ( 1.56, 0.17, 0.17, 0.0, 0.01),
    ]
    build_vertical_loft(f"{name_prefix}_BioTorso", oct_prof, sinew_stations, torso, collection, mat_sinew, subsurf=subsurf_lvl, smooth=True, sharp_caps=False)

    ab_configs = [
        (0.44, 0.60, 0.38, 0.44, 0.31, 0.34),
        (0.24, 0.40, 0.31, 0.36, 0.28, 0.30),
        (0.04, 0.20, 0.24, 0.29, 0.25, 0.27),
    ]
    for idx, (z_bot, z_top, sx_b, sx_t, sy_b, sy_t) in enumerate(ab_configs):
        ab_st = [
            (z_bot, sx_b, sy_b, 0.0, -0.05),
            (0.5 * (z_bot + z_top), 0.5 * (sx_b + sx_t) * 1.03, 0.5 * (sy_b + sy_t) * 1.03, 0.0, -0.06),
            (z_top, sx_t, sy_t, 0.0, -0.05),
        ]
        build_vertical_loft(f"{name_prefix}_AbPlate_{idx}", cuirass_prof, ab_st, torso, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

    chest_stations = [
        (0.64, 0.48, 0.36, 0.0, -0.04),
        (0.80, 0.65, 0.44, 0.0, -0.05),
        (1.06, 0.67, 0.43, 0.0, -0.04),
        (1.24, 0.46, 0.32, 0.0,  0.01),
        (1.30, 0.28, 0.24, 0.0,  0.03),
    ]
    build_vertical_loft(f"{name_prefix}_UpperChest", cuirass_prof, chest_stations, torso, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

    # Flush 360-Degree Octagonal Sternum Soul Core on Torso (local z = 0.86)
    part_cyl(f"{name_prefix}_CoreFrame", 0.20, 0.17, 0.08, torso, collection, mat_sinew,
             loc=(0, -0.41, 0.86), rot=(math.radians(90), 0, 0), segs=8, smooth=False)
    part_cyl(f"{name_prefix}_CoreTechRing", 0.15, 0.13, 0.09, torso, collection, mat_core_ring,
             loc=(0, -0.42, 0.86), rot=(math.radians(90), 0, 0), segs=16)
    part_sphere(f"{name_prefix}_SoulCoreOrb", 0.095, torso, collection, mat_core, loc=(0, -0.44, 0.86), subdiv=3)

    core_light = bpy.data.lights.new(f"{name_prefix}_CoreLight", type='POINT')
    core_light.color = (1.0, 0.20, 0.90)
    core_light.energy = 14.0
    core_light_obj = bpy.data.objects.new(f"{name_prefix}_CoreLight", core_light)
    core_light_obj.location = (0, -0.58, 0.86)
    collection.objects.link(core_light_obj)
    core_light_obj.parent = torso

    # 3. DORSAL VERNIER BACKPACK & 4 ARTICULATED GUNDAM WING-BINDERS
    part_taper_box(f"{name_prefix}_BackpackMain", (0.68, 0.38), (0.54, 0.30), 0.72, torso, collection, mat_sinew,
                   loc=(0.0, 0.38, 0.88), bevel=0.02, smooth=True)
    part_taper_box(f"{name_prefix}_BackpackCowl", (0.58, 0.32), (0.44, 0.24), 0.56, torso, collection, mat_ceramic,
                   loc=(0.0, 0.44, 0.92), bevel=0.02, smooth=True)

    for side, b_piv in [(-1.0, binder_L), (1.0, binder_R)]:
        # Upper Main Aerodynamic Wing-Binder Blade + Cyan Resonance Vein
        part_taper_box(f"{name_prefix}_BinderUpper_{side}", (0.18, 0.34), (0.08, 0.16), 1.68, b_piv, collection, mat_ceramic,
                       loc=(side * 0.44, 0.22, 0.52), rot=rads((-18, side * 38, side * -10)), bevel=0.015, smooth=True)
        part_box(f"{name_prefix}_BinderVeinU_{side}", (0.035, 0.06, 1.44), b_piv, collection, mat_cyan,
                 loc=(side * 0.45, 0.14, 0.52), rot=rads((-18, side * 38, side * -10)))
        # Lower Sub-Wing Stabilizer Fin + Cyan Trim
        part_taper_box(f"{name_prefix}_BinderLower_{side}", (0.14, 0.26), (0.06, 0.12), 1.15, b_piv, collection, mat_silver,
                       loc=(side * 0.38, 0.26, -0.34), rot=rads((22, side * 52, side * 12)), bevel=0.015, smooth=True)
        part_box(f"{name_prefix}_BinderVeinL_{side}", (0.025, 0.04, 0.95), b_piv, collection, mat_cyan,
                 loc=(side * 0.39, 0.19, -0.34), rot=rads((22, side * 52, side * 12)))
        # Recessed Vernier Thruster Bell & Glowing Cyan Plasma Core (no spiky solid cones!)
        part_cyl(f"{name_prefix}_VernierBell_{side}", 0.12, 0.08, 0.22, b_piv, collection, mat_sinew,
                 loc=(side * 0.18, 0.18, -0.10), rot=rads((55, side * 18, 0)), segs=16)
        part_sphere(f"{name_prefix}_VernierCore_{side}", 0.085, b_piv, collection, mat_cyan,
                    loc=(side * 0.22, 0.26, -0.16), subdiv=2)

    # 4. ARTICULATED HEAD WITH RECESSED V-VISOR & ICONIC GUNDAM V-FIN CREST (local to head at z=1.40 on torso)
    helm_prof = [
        (0.0, -1.18), (0.42, -0.96), (0.80, -0.46), (0.88, 0.12),
        (0.78, 0.70), (0.40, 1.04), (0.0, 1.12), (-0.40, 1.04),
        (-0.78, 0.70), (-0.88, 0.12), (-0.80, -0.46), (-0.42, -0.96)
    ]
    inner_helm_st = [
        (0.06, 0.10, 0.13, 0.0, -0.10),
        (0.28, 0.22, 0.26, 0.0, -0.03),
        (0.50, 0.21, 0.26, 0.0,  0.01),
    ]
    build_vertical_loft(f"{name_prefix}_HelmetInner", helm_prof, inner_helm_st, head, collection, mat_sinew, subsurf=subsurf_lvl, smooth=True, sharp_caps=False)

    jaw_helm_st = [
        (0.02, 0.09, 0.12, 0.0, -0.14),
        (0.14, 0.19, 0.24, 0.0, -0.08),
        (0.26, 0.24, 0.28, 0.0, -0.03),
    ]
    build_vertical_loft(f"{name_prefix}_HelmetJaw", helm_prof, jaw_helm_st, head, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

    dome_helm_st = [
        (0.32, 0.26, 0.31, 0.0, -0.04),
        (0.46, 0.25, 0.32, 0.0,  0.01),
        (0.57, 0.15, 0.22, 0.0,  0.05),
        (0.62, 0.05, 0.08, 0.0,  0.07),
    ]
    build_vertical_loft(f"{name_prefix}_HelmetDome", helm_prof, dome_helm_st, head, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

    # Iconic Gundam Forehead V-Fin Crest + Central Sensor Jewel
    part_taper_box(f"{name_prefix}_VFinJewel", (0.06, 0.08), (0.04, 0.06), 0.10, head, collection, mat_cyan,
                   loc=(0.0, -0.31, 0.38), rot=rads((18, 0, 0)), bevel=0.005)
    for side in [-1.0, 1.0]:
        part_taper_box(f"{name_prefix}_VFinBlade_{side}", (0.04, 0.05), (0.012, 0.02), 0.42, head, collection, mat_ceramic,
                       loc=(side * 0.16, -0.32, 0.49), rot=rads((16, side * 44, side * -12)), bevel=0.004)
        part_box(f"{name_prefix}_Visor_{side}", (0.16, 0.04, 0.028), head, collection, mat_cyan,
                 loc=(side * 0.075, -0.29, 0.29), rot=(0, math.radians(side * -14), math.radians(side * 22)))
        part_cyl(f"{name_prefix}_EarPod_{side}", 0.075, 0.06, 0.05, head, collection, mat_sinew,
                 loc=(side * 0.24, 0.01, 0.30), rot=(0, math.radians(90), 0), segs=16)

    # 5. ARTICULATED SHOULDERS, ELBOWS, ENERGY SHIELD (LEFT) & RESONANCE BEAM LANCE (RIGHT)
    for side, sh_piv, el_piv in [(-1.0, sh_L, el_L), (1.0, sh_R, el_R)]:
        wing_prof = [(-0.42, -0.08), (0.42, -0.08), (0.30, 0.13), (-0.30, 0.13)]
        wing_stations = [
            (0.00, 0.65, 0.85, -0.02),
            (0.28, 1.05, 1.25,  0.08),
            (0.64, 0.82, 0.95,  0.05),
            (0.96, 0.24, 0.28, -0.03),
            (1.10, 0.04, 0.05, -0.07),
        ]
        build_lofted_mesh(f"{name_prefix}_WingPauldron_{side}", wing_prof, wing_stations, sh_piv, collection, mat_ceramic,
                          loc=(side * -0.26, 0.0, 0.15), rot=(0, 0, math.radians(-90 if side > 0 else 90)), subsurf=subsurf_lvl, smooth=True)

        part_cyl(f"{name_prefix}_ShNozzle_{side}", 0.07, 0.055, 0.16, sh_piv, collection, mat_sinew,
                 loc=(side * 0.26, 0.06, -0.01), rot=(math.radians(-12), math.radians(side * 26), 0), segs=14)
        part_sphere(f"{name_prefix}_ShGlow_{side}", 0.045, sh_piv, collection, mat_cyan, loc=(side * 0.30, 0.07, -0.08))

        part_sphere(f"{name_prefix}_ShoulderJoint_{side}", 0.15, sh_piv, collection, mat_sinew, loc=(0.0, 0.0, 0.0))
        part_cyl(f"{name_prefix}_ArmSinew_{side}", 0.11, 0.09, 0.68, sh_piv, collection, mat_sinew,
                 loc=(side * 0.09, 0.01, -0.34), rot=(0, math.radians(side * -14), 0), segs=14)
        bicep_stations = [
            (-0.54, 0.13, 0.14, side * 0.14, 0.01),
            (-0.30, 0.16, 0.17, side * 0.09, 0.00),
            (-0.08, 0.15, 0.16, side * 0.04, 0.00),
        ]
        build_vertical_loft(f"{name_prefix}_BicepCuff_{side}", oct_prof, bicep_stations, sh_piv, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

        # Elbow & Forearm Vambrace (local to el_piv)
        part_sphere(f"{name_prefix}_ElbowJoint_{side}", 0.12, el_piv, collection, mat_sinew, loc=(0.0, 0.0, 0.0))
        vambrace_stations = [
            (-0.74, 0.10, 0.11, side * 0.10, -0.14),
            (-0.50, 0.15, 0.17, side * 0.07, -0.09),
            (-0.22, 0.18, 0.20, side * 0.03, -0.02),
            (-0.08, 0.13, 0.14, 0.0,          0.00),
        ]
        build_vertical_loft(f"{name_prefix}_Vambrace_{side}", oct_prof, vambrace_stations, el_piv, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

        part_box(f"{name_prefix}_HandPalm_{side}", (0.08, 0.14, 0.16), el_piv, collection, mat_sinew,
                 loc=(side * 0.11, -0.18, -0.84), rot=(math.radians(15), 0, 0), subsurf=1)
        for fi in range(4):
            fy = -0.22 + fi * 0.032
            part_cyl(f"{name_prefix}_Finger_{side}_{fi}", 0.016, 0.012, 0.13, el_piv, collection, mat_ceramic,
                     loc=(side * 0.10, fy, -0.96), rot=(math.radians(20), math.radians(side * -10), 0), segs=8)

    # Left Forearm Angular Gundam Resonance Shield (on el_L)
    part_taper_box(f"{name_prefix}_ShieldBody", (0.12, 0.56), (0.06, 0.34), 1.48, el_L, collection, mat_ceramic,
                   loc=(-0.26, -0.10, -0.45), rot=rads((10, -14, 15)), bevel=0.018, smooth=True)
    part_taper_box(f"{name_prefix}_ShieldRim", (0.06, 0.62), (0.03, 0.38), 1.56, el_L, collection, mat_shield_glow,
                   loc=(-0.29, -0.10, -0.45), rot=rads((10, -14, 15)), bevel=0.01)

    # Right Hand High-Energy Resonance Beam Lance (aligned along forearm -Z axis so raising the forearm aims the lance forward!)
    part_cyl(f"{name_prefix}_LanceShaft", 0.038, 0.035, 2.4, el_R, collection, mat_sinew,
             loc=(0.12, -0.18, -1.10), rot=rads((-18, 0, 0)), segs=14)
    part_cyl(f"{name_prefix}_LanceGuard", 0.16, 0.05, 0.36, el_R, collection, mat_ceramic,
             loc=(0.12, -0.52, -2.12), rot=rads((162, 0, 0)), segs=16)
    part_cyl(f"{name_prefix}_LanceRing", 0.19, 0.19, 0.06, el_R, collection, mat_core,
             loc=(0.12, -0.57, -2.26), rot=rads((-18, 0, 0)), segs=16)
    part_cyl(f"{name_prefix}_LanceBeamBlade", 0.10, 0.008, 2.25, el_R, collection, mat_cyan,
             loc=(0.12, -0.94, -3.36), rot=rads((162, 0, 0)), segs=16)

    # 6. ARTICULATED HIPS, KNEES, CALF VERNIERS & BOOTS
    for side, hip_piv, kn_piv, ank_piv in [(-1.0, hip_L, kn_L, ank_L), (1.0, hip_R, kn_R, ank_R)]:
        part_cyl(f"{name_prefix}_InnerThigh_{side}", 0.20, 0.14, 0.96, hip_piv, collection, mat_sinew,
                 loc=(side * -0.04, -0.01, -0.44), rot=(0, math.radians(side * -3), 0), segs=16)

        thigh_stations = [
            (-0.92, 0.16, 0.19, side * 0.02, -0.03),
            (-0.58, 0.23, 0.28, side * 0.03, -0.04),
            (-0.22, 0.26, 0.32, side * 0.02, -0.02),
            ( 0.06, 0.19, 0.24, 0.0,          0.00),
            ( 0.18, 0.12, 0.16, side * -0.02, 0.02),
        ]
        build_vertical_loft(f"{name_prefix}_ThighArmor_{side}", oct_prof, thigh_stations, hip_piv, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

        part_cyl(f"{name_prefix}_HipRingOuter_{side}", 0.105, 0.105, 0.05, hip_piv, collection, mat_sinew,
                 loc=(side * 0.16, -0.02, -0.16), rot=(0, math.radians(85), 0), segs=18)
        part_cyl(f"{name_prefix}_HipRingInner_{side}", 0.065, 0.065, 0.06, hip_piv, collection, mat_silver,
                 loc=(side * 0.16, -0.02, -0.16), rot=(0, math.radians(85), 0), segs=16)

        # Knee & Shin Greave (local to kn_piv at z=-0.98 on hip_piv)
        part_sphere(f"{name_prefix}_KneeJoint_{side}", 0.15, kn_piv, collection, mat_sinew, loc=(0.0, -0.01, 0.0))
        knee_st = [
            (-0.14, 0.09, 0.09, 0.0, -0.15),
            ( 0.02, 0.12, 0.11, 0.0, -0.17),
            ( 0.18, 0.08, 0.08, 0.0, -0.14),
        ]
        build_vertical_loft(f"{name_prefix}_KneeCap_{side}", oct_prof, knee_st, kn_piv, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

        shin_stations = [
            (-1.02, 0.13, 0.16, side * 0.04,  0.03),
            (-0.68, 0.18, 0.23, side * 0.03,  0.03),
            (-0.26, 0.23, 0.28, side * 0.02,  0.02),
            (-0.02, 0.16, 0.20, 0.0,         -0.02),
        ]
        build_vertical_loft(f"{name_prefix}_ShinGreave_{side}", oct_prof, shin_stations, kn_piv, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

        # Recessed Rear Calf Vernier Thruster Bell & Glowing Cyan Core (no spiky cones!)
        part_cyl(f"{name_prefix}_CalfNozzle_{side}", 0.075, 0.055, 0.16, kn_piv, collection, mat_sinew,
                 loc=(side * 0.03, 0.25, -0.45), rot=rads((42, 0, 0)), segs=12)
        part_sphere(f"{name_prefix}_CalfCore_{side}", 0.05, kn_piv, collection, mat_cyan,
                    loc=(side * 0.03, 0.30, -0.50), subdiv=2)

        # Articulated Foot (local to ank_piv at z=-1.04 on kn_piv)
        foot_stations = [
            ( 0.04, 0.14, 0.18, 0.0,  0.00),
            (-0.10, 0.18, 0.32, 0.0, -0.10),
            (-0.18, 0.15, 0.36, 0.0, -0.14),
        ]
        build_vertical_loft(f"{name_prefix}_Foot_{side}", oct_prof, foot_stations, ank_piv, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

    root.scale = (scale_factor, scale_factor, scale_factor)
    return {
        "root": root,
        "torso": torso,
        "head": head,
        "binder_L": binder_L,
        "binder_R": binder_R,
        "sh_L": sh_L,
        "sh_R": sh_R,
        "el_L": el_L,
        "el_R": el_R,
        "hip_L": hip_L,
        "hip_R": hip_R,
        "kn_L": kn_L,
        "kn_R": kn_R,
        "ank_L": ank_L,
        "ank_R": ank_R,
    }

# -------------------------------------------------------------------------
# 4. THE FREE TIDE — ORNATE VOID GALLEON (Matches galleon_concept.png)
# -------------------------------------------------------------------------
def create_billowing_sail(name, width, height, billow_depth, parent, col, mat, loc=(0,0,0), rot=(0,0,0)):
    bm = bmesh.new()
    nx, nz = 14, 14
    grid = []
    for iz in range(nz + 1):
        v_frac = iz / nz
        taper = 1.0 - 0.18 * v_frac
        row = []
        for ix in range(nx + 1):
            u_frac = ix / nx
            x = (u_frac - 0.5) * width * taper
            z = (v_frac - 0.5) * height
            billow = math.sin(u_frac * math.pi) * math.sin(v_frac * math.pi) * billow_depth
            z_arch = math.sin(u_frac * math.pi) * 0.22 * (1.0 - v_frac)
            v = bm.verts.new((x, billow, z + z_arch))
            row.append(v)
        grid.append(row)

    for iz in range(nz):
        for ix in range(nx):
            bm.faces.new((grid[iz][ix], grid[iz][ix+1], grid[iz+1][ix+1], grid[iz+1][ix]))

    return make_part(name, bm, parent, col, mat, loc, rot, smooth=True)

def build_free_tide_galleon(collection, texture_path, name_prefix="FreeTide_Galleon", scale_factor=1.0, is_raider=False):
    root = bpy.data.objects.new(name_prefix, None)
    collection.objects.link(root)

    mat_wood = create_pbr_hull_material(f"{name_prefix}_Wood", (0.22, 0.11, 0.05, 1.0), metallic=0.08, roughness=0.48, texture_path=texture_path, tex_scale=0.35, bump_strength=0.42)
    mat_brass = create_pbr_hull_material(f"{name_prefix}_Brass", (0.90, 0.62, 0.18, 1.0), metallic=0.92, roughness=0.22)
    mat_sail = create_emissive_material(f"{name_prefix}_Sail", (0.02, 0.72, 1.0, 0.82), strength=2.6, alpha=0.82)
    mat_oar_blade = create_emissive_material(f"{name_prefix}_OarBlade", (0.05, 0.85, 1.0, 0.90), strength=4.5, alpha=0.90)
    mat_lantern = create_emissive_material(f"{name_prefix}_Lantern", (1.0, 0.55, 0.05, 1.0), strength=8.5)

    prof = [
        (0.0, -1.25), (0.55, -1.10), (1.05, -0.70), (1.35, -0.15),
        (1.42, 0.45), (1.25, 0.95), (0.0, 0.85),
        (-1.25, 0.95), (-1.42, 0.45), (-1.35, -0.15), (-1.05, -0.70), (-0.55, -1.10)
    ]
    stations = [
        (6.8,  0.08, 0.35, 0.65),
        (5.4,  0.48, 0.72, 0.32),
        (3.2,  0.88, 0.92, 0.08),
        (0.0,  1.08, 1.00, 0.0),
        (-3.2, 1.02, 1.05, 0.15),
        (-5.6, 0.78, 1.15, 0.48),
        (-6.6, 0.58, 1.10, 0.68),
    ]
    build_lofted_mesh(f"{name_prefix}_CaravelHull", prof, stations, root, collection, mat_wood, smooth=True)

    for idx, (y_r, sc_x, sc_z, oz) in enumerate([(4.6, 0.65, 0.80, 0.22), (2.4, 0.96, 0.96, 0.05), (0.0, 1.11, 1.03, 0.0), (-2.4, 1.06, 1.06, 0.12), (-4.6, 0.88, 1.12, 0.34)]):
        rib_st = [(y_r + 0.10, sc_x, sc_z, oz), (y_r - 0.10, sc_x, sc_z, oz)]
        build_lofted_mesh(f"{name_prefix}_BrassRib_{idx}", prof, rib_st, root, collection, mat_brass, smooth=True)

    strake_top_prof = [(1.28, 0.82), (1.34, 0.82), (1.28, 0.96), (-1.28, 0.96), (-1.34, 0.82), (-1.28, 0.82)]
    strake_mid_prof = [(1.38, -0.08), (1.45, -0.08), (1.45, 0.06), (-1.45, 0.06), (-1.45, -0.08), (-1.38, -0.08)]
    build_lofted_mesh(f"{name_prefix}_BrassStrakeTop", strake_top_prof, stations, root, collection, mat_brass, smooth=True)
    build_lofted_mesh(f"{name_prefix}_BrassStrakeMid", strake_mid_prof, stations, root, collection, mat_brass, smooth=True)

    castle_prof = [(-0.95, 0.0), (0.95, 0.0), (0.85, 1.0), (-0.85, 1.0)]
    stern_st = [(-3.2, 1.05, 1.1, 0.85), (-5.2, 0.88, 1.35, 0.95), (-6.6, 0.68, 1.45, 1.05)]
    build_lofted_mesh(f"{name_prefix}_Sterncastle", castle_prof, stern_st, root, collection, mat_wood)
    fore_st = [(6.2, 0.25, 0.65, 0.85), (4.6, 0.72, 0.75, 0.82), (3.2, 0.95, 0.65, 0.80)]
    build_lofted_mesh(f"{name_prefix}_Forecastle", castle_prof, fore_st, root, collection, mat_wood)

    part_cyl(f"{name_prefix}_BowspritMain", 0.14, 0.05, 5.4, root, collection, mat_brass,
             loc=(0, 8.2, 1.45), rot=(math.radians(-72), 0, 0), segs=16)
    part_cyl(f"{name_prefix}_BowspritSub", 0.10, 0.04, 4.2, root, collection, mat_brass,
             loc=(0, 7.6, 1.05), rot=(math.radians(-78), 0, 0), segs=14)

    for side in [-1.0, 1.0]:
        for i in range(6):
            py = -3.0 + i * 1.15
            hull_w = 1.44 * (1.0 - 0.015 * py * py)
            part_cyl(f"{name_prefix}_PortRim_{side}_{i}", 0.21, 0.21, 0.14, root, collection, mat_brass,
                     loc=(side * hull_w, py, 0.38), rot=(0, math.radians(90), 0), segs=16)
            part_sphere(f"{name_prefix}_PortGlow_{side}_{i}", 0.15, root, collection, mat_lantern,
                        loc=(side * (hull_w + 0.04), py, 0.38))

        for i in range(6 if not is_raider else 4):
            oy = -2.6 + i * 1.05
            oar_piv = bpy.data.objects.new(f"{name_prefix}_OarPiv_{side}_{i}", None)
            oar_piv.location = (side * 1.25, oy, -0.05)
            oar_piv.rotation_euler = (math.radians(-18), math.radians(side * 54), 0)
            collection.objects.link(oar_piv)
            oar_piv.parent = root

            part_cyl(f"{name_prefix}_OarShaft_{side}_{i}", 0.05, 0.04, 2.6, oar_piv, collection, mat_brass,
                     loc=(0, 0, -1.3), segs=12)
            part_box(f"{name_prefix}_OarVane_{side}_{i}", (0.28, 0.04, 1.45), oar_piv, collection, mat_oar_blade,
                     loc=(0, 0, -2.9), bevel=0.01)

        wing_piv = bpy.data.objects.new(f"{name_prefix}_WingPiv_{side}", None)
        wing_piv.location = (side * 1.35, 0.2, 0.95)
        wing_piv.rotation_euler = (0, math.radians(side * -14), 0)
        collection.objects.link(wing_piv)
        wing_piv.parent = root

        for sy in [-1.8, -0.2, 1.4]:
            part_cyl(f"{name_prefix}_Outrigger_{side}_{sy}", 0.08, 0.03, 4.6, wing_piv, collection, mat_brass,
                     loc=(side * 2.3, sy, 0.0), rot=(0, math.radians(90), 0), segs=14)
        create_billowing_sail(f"{name_prefix}_WingSail_{side}", 3.2, 4.0, 0.45, wing_piv, collection, mat_sail,
                              loc=(side * 2.4, -0.2, 0.0), rot=(math.radians(90), 0, math.radians(side * 90)))

    for sx in [-0.45, 0.0, 0.45]:
        part_sphere(f"{name_prefix}_SternWin_{sx}", 0.16, root, collection, mat_lantern, loc=(sx, -6.55, 1.65))

    mast_configs = [(2.6, 6.8, 4.6, 4.2), (-0.4, 8.4, 5.6, 5.2), (-3.4, 6.4, 4.2, 3.8)] if not is_raider else [(0.8, 6.8, 4.6, 4.2), (-2.4, 5.8, 3.8, 3.5)]
    for idx, (my, mh, sw, sh) in enumerate(mast_configs):
        part_cyl(f"{name_prefix}_Mast_{idx}", 0.16, 0.09, mh, root, collection, mat_brass,
                 loc=(0, my, mh * 0.5 + 0.6), rot=(math.radians(-5), 0, 0), segs=16)
        part_cyl(f"{name_prefix}_YardTop_{idx}", 0.09, 0.05, sw * 1.05, root, collection, mat_brass,
                 loc=(0, my - 0.15, mh * 0.88), rot=(0, math.radians(90), 0), segs=14)
        part_cyl(f"{name_prefix}_YardBot_{idx}", 0.08, 0.05, sw * 1.12, root, collection, mat_brass,
                 loc=(0, my + 0.1, mh * 0.25), rot=(0, math.radians(90), 0), segs=14)
        create_billowing_sail(f"{name_prefix}_MainSail_{idx}", sw, sh, 1.15, root, collection, mat_sail,
                              loc=(0, my + 0.45, mh * 0.56))

    root.scale = (scale_factor, scale_factor, scale_factor)
    return root

# -------------------------------------------------------------------------
# 5. WIDE PANORAMIC BATTLE ELEMENTS (Crisp Tracer Beams & Controlled Fireballs)
# -------------------------------------------------------------------------
def build_wide_battle_vfx(collection):
    mat_orange = create_emissive_material("Beam_Acero_Orange", (1.0, 0.48, 0.04, 1.0), strength=14.0)
    mat_red = create_emissive_material("Beam_Acero_Red", (1.0, 0.16, 0.06, 1.0), strength=14.0)
    mat_cyan = create_emissive_material("Beam_Marea_Cyan", (0.05, 0.88, 1.0, 1.0), strength=14.0)
    mat_violet = create_emissive_material("Beam_Vinc_Violet", (1.0, 0.15, 0.90, 1.0), strength=16.0)

    rng = random.Random(909)
    lasers = []
    for i in range(30):
        if i % 3 == 0:
            sp = (rng.uniform(-16, -8), rng.uniform(-2, 12), rng.uniform(-2, 4))
            ep = (rng.uniform(7, 16), rng.uniform(-2, 12), rng.uniform(-2, 4))
            mat = mat_orange if i % 2 == 0 else mat_red
            length = 3.8
        elif i % 3 == 1:
            sp = (rng.uniform(8, 16), rng.uniform(-3, 11), rng.uniform(-2, 3))
            ep = (rng.uniform(-16, -7), rng.uniform(-2, 12), rng.uniform(-2, 4))
            mat = mat_cyan
            length = 3.8
        else:
            sp = (rng.uniform(-4, 4), rng.uniform(-4, 6), rng.uniform(-1, 4))
            ep = (rng.uniform(-13, 13), rng.uniform(2, 14), rng.uniform(-2, 4))
            mat = mat_violet
            length = 3.2

        vec = mathutils.Vector(ep) - mathutils.Vector(sp)
        rot_quat = vec.normalized().to_track_quat('Z', 'Y')
        dummy = bpy.data.objects.new(f"LD_{i}", None)
        collection.objects.link(dummy)
        l_obj = part_cyl(f"BattleLaser_{i}", 0.065, 0.065, length, dummy, collection, mat,
                         loc=(0, 0, 500), rot=rot_quat.to_euler(), segs=10)
        f_base = 524 + (i * 3) % 32
        lasers.append({"obj": l_obj, "sp": sp, "ep": ep, "f_base": f_base})

    mat_core_exp = create_emissive_material("Exp_InnerCore", (1.0, 0.78, 0.25, 1.0), strength=14.0)
    mat_fire_exp = create_emissive_material("Exp_FireShell", (1.0, 0.28, 0.02, 0.72), strength=7.5, alpha=0.72)
    mat_ring_exp = create_emissive_material("Exp_ShockRing", (0.12, 0.82, 1.0, 0.60), strength=6.5, alpha=0.60)

    exp_configs = [
        {"name": "Exp1", "pos": (-7.5, 5.0, 1.2),  "fs": 528, "fp": 546, "fe": 570, "max_s": 1.65},
        {"name": "Exp2", "pos": (8.5, 3.5, -0.5),  "fs": 544, "fp": 564, "fe": 588, "max_s": 1.65},
        {"name": "Exp3", "pos": (-2.0, 8.0, 2.2),  "fs": 558, "fp": 578, "fe": 602, "max_s": 1.70},
        {"name": "Exp4", "pos": (6.5, -1.5, 1.0),  "fs": 572, "fp": 592, "fe": 616, "max_s": 1.65},
        {"name": "Exp5", "pos": (-5.5, 1.5, -1.2), "fs": 586, "fp": 606, "fe": 630, "max_s": 1.75},
        {"name": "Exp6", "pos": (2.5, 6.5, 0.8),   "fs": 600, "fp": 618, "fe": 640, "max_s": 1.85},
        # Climax Resonance Shockwave Detonation at Frame 624 -> 642 that drives the upward camera pan into the Logo!
        {"name": "Exp_Climax", "pos": (0.0, 4.0, 3.5), "fs": 622, "fp": 640, "fe": 652, "max_s": 4.20},
    ]

    explosions = []
    for ec in exp_configs:
        dummy = bpy.data.objects.new(ec["name"] + "_Root", None)
        collection.objects.link(dummy)
        part_sphere(ec["name"] + "_Core", 0.35, dummy, collection, mat_core_exp, subdiv=2)
        part_sphere(ec["name"] + "_Fire", 0.68, dummy, collection, mat_fire_exp, subdiv=3)
        part_cyl(ec["name"] + "_Ring", 1.15, 1.15, 0.05, dummy, collection, mat_ring_exp,
                 rot=(math.radians(15), math.radians(10), 0), segs=28)

        light_data = bpy.data.lights.new(ec["name"] + "_Light", type='POINT')
        light_data.color = (0.35, 0.88, 1.0) if ec["name"] == "Exp_Climax" else (1.0, 0.55, 0.12)
        light_obj = bpy.data.objects.new(ec["name"] + "_Light", light_data)
        collection.objects.link(light_obj)
        light_obj.parent = dummy

        dummy.location = (0, 0, 500)
        explosions.append({"root": dummy, "light": light_obj, "cfg": ec})

    return lasers, explosions

# -------------------------------------------------------------------------
# MAIN SCENE ASSEMBLY & SEAMLESS CHOREOGRAPHY
# -------------------------------------------------------------------------
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

    col = scene_3d.collection

    # Deep High-Contrast Star Sea World Shader
    world = bpy.data.worlds.new("StarSea_World")
    scene_3d.world = world
    world.use_nodes = True
    w_nodes = world.node_tree.nodes
    w_links = world.node_tree.links
    bg = w_nodes.get("Background")
    bg.inputs["Strength"].default_value = 1.0

    coord = w_nodes.new("ShaderNodeTexCoord")
    w_map = w_nodes.new("ShaderNodeMapping")
    w_map.inputs["Rotation"].default_value = (math.radians(38), math.radians(44), math.radians(22))

    neb_noise = w_nodes.new("ShaderNodeTexNoise")
    neb_noise.inputs["Scale"].default_value = 5.5
    neb_noise.inputs["Detail"].default_value = 10.0
    neb_noise.inputs["Roughness"].default_value = 0.68
    neb_noise.inputs["Distortion"].default_value = 0.85

    ramp_neb = w_nodes.new("ShaderNodeValToRGB")
    ramp_neb.color_ramp.elements[0].position = 0.35
    ramp_neb.color_ramp.elements[0].color = (0.001, 0.002, 0.006, 1.0)
    ramp_neb.color_ramp.elements[1].position = 0.82
    ramp_neb.color_ramp.elements[1].color = (0.007, 0.028, 0.052, 1.0)

    vor_stars = w_nodes.new("ShaderNodeTexVoronoi")
    vor_stars.inputs["Scale"].default_value = 480.0

    ramp_stars = w_nodes.new("ShaderNodeValToRGB")
    ramp_stars.color_ramp.elements[0].position = 0.0
    ramp_stars.color_ramp.elements[0].color = (0.95, 0.98, 1.0, 1.0)
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
    w_links.new(ramp_neb.outputs["Color"], add_col.inputs[6])
    w_links.new(ramp_stars.outputs["Color"], add_col.inputs[7])
    w_links.new(add_col.outputs[2], bg.inputs["Color"])

    # Three-Point Cinematic Space Lighting
    sun_key = bpy.data.lights.new("Sun_Key", type='SUN')
    sun_key.energy = 3.8
    sun_key.color = (0.98, 0.96, 0.92)
    sun_key_obj = bpy.data.objects.new("Sun_Key", sun_key)
    sun_key_obj.rotation_euler = (math.radians(52), math.radians(24), math.radians(28))
    col.objects.link(sun_key_obj)

    sun_rim = bpy.data.lights.new("Sun_Rim", type='SUN')
    sun_rim.energy = 2.6
    sun_rim.color = (0.18, 0.85, 1.0)
    sun_rim_obj = bpy.data.objects.new("Sun_Rim", sun_rim)
    sun_rim_obj.rotation_euler = (math.radians(-42), math.radians(-55), math.radians(130))
    col.objects.link(sun_rim_obj)

    sun_fill = bpy.data.lights.new("Sun_Fill", type='SUN')
    sun_fill.energy = 1.1
    sun_fill.color = (0.50, 0.62, 0.85)
    sun_fill_obj = bpy.data.objects.new("Sun_Fill", sun_fill)
    sun_fill_obj.rotation_euler = (math.radians(78), 0, math.radians(-12))
    col.objects.link(sun_fill_obj)

    ast_root = build_asteroid_field(col, 24)

    tex_acero = asset_p("assets/ships/acero/acero_hull.png")
    tex_vinc = asset_p("assets/ships/vinculados/vinculados_hull.png")
    tex_marea = asset_p("assets/ships/marea-libre/marea_hull.png")

    dreadnought = build_acero_dreadnought(col, tex_acero, "Acero_Dreadnought", 1.0, is_escort=False)
    cruiser1 = build_acero_dreadnought(col, tex_acero, "Acero_Cruiser1", 0.52, is_escort=True)
    cruiser2 = build_acero_dreadnought(col, tex_acero, "Acero_Cruiser2", 0.48, is_escort=True)
    cruiser3 = build_acero_dreadnought(col, tex_acero, "Acero_Cruiser3", 0.45, is_escort=True)

    # Gundam Scale in wide battle: agile mobile-suit scale (0.46) relative to massive dreadnought (1.0) & galleon (1.0)
    hero_suit = build_vinculados_suit(col, tex_vinc, "Vinculados_HeroSuit", 1.0, subsurf_lvl=2)
    vinc_ace1 = build_vinculados_suit(col, tex_vinc, "Vinculados_Ace1", 0.46, subsurf_lvl=1)
    vinc_ace2 = build_vinculados_suit(col, tex_vinc, "Vinculados_Ace2", 0.44, subsurf_lvl=1)
    vinc_ace3 = build_vinculados_suit(col, tex_vinc, "Vinculados_Ace3", 0.44, subsurf_lvl=1)

    galleon = build_free_tide_galleon(col, tex_marea, "FreeTide_Flagship", 1.0, is_raider=False)
    raider1 = build_free_tide_galleon(col, tex_marea, "FreeTide_Raider1", 0.58, is_raider=True)
    raider2 = build_free_tide_galleon(col, tex_marea, "FreeTide_Raider2", 0.55, is_raider=True)

    lasers, explosions = build_wide_battle_vfx(col)

    cam_data = bpy.data.cameras.new("Cinematic_Cam")
    cam_data.lens = 35
    cam_data.clip_end = 500.0
    cam_obj = bpy.data.objects.new("Cinematic_Cam", cam_data)
    col.objects.link(cam_obj)
    scene_3d.camera = cam_obj

    all_ship_roots = [
        dreadnought, cruiser1, cruiser2, cruiser3,
        hero_suit["root"], vinc_ace1["root"], vinc_ace2["root"], vinc_ace3["root"],
        galleon, raider1, raider2
    ]
    for s in all_ship_roots:
        key_transform(s, 1, loc=(0, 0, 500))

    # -------------------------------------------------------------------------
    # SHOT 1: THE STAR SEA (Frames 1 - 110)
    # -------------------------------------------------------------------------
    key_transform(ast_root, 1, loc=(0, 0, 0))
    key_transform(ast_root, 110, loc=(0, 0, 0))
    key_transform(ast_root, 111, loc=(0, 0, 500))

    key_transform(cam_obj, 1, loc=(0, -28, 3.8), rot=(math.radians(83), 0, 0))
    key_transform(cam_obj, 110, loc=(0, -8, 2.2), rot=(math.radians(85), 0, math.radians(8)))

    # -------------------------------------------------------------------------
    # SHOT 2: THE ARMADA OF ACERO (Frames 111 - 220)
    # -------------------------------------------------------------------------
    key_transform(dreadnought, 110, loc=(0, 0, 500))
    key_transform(dreadnought, 111, loc=(1.5, 4.0, 0.5), rot=(math.radians(5), math.radians(-8), math.radians(-125)))
    key_transform(dreadnought, 220, loc=(-1.0, 1.5, 0.8), rot=(math.radians(5), math.radians(-8), math.radians(-135)))
    key_transform(dreadnought, 221, loc=(0, 0, 500))

    key_transform(cruiser1, 110, loc=(0, 0, 500))
    key_transform(cruiser1, 111, loc=(9.5, 12.0, -1.8), rot=(math.radians(5), math.radians(-8), math.radians(-125)))
    key_transform(cruiser1, 220, loc=(6.5, 9.0, -1.5), rot=(math.radians(5), math.radians(-8), math.radians(-135)))
    key_transform(cruiser1, 221, loc=(0, 0, 500))

    key_transform(cam_obj, 111, loc=(-11.5, -11.5, 3.4), rot=(math.radians(79), 0, math.radians(-42)))
    key_transform(cam_obj, 220, loc=(-9.2, -13.5, 4.2), rot=(math.radians(76), 0, math.radians(-34)))

    # -------------------------------------------------------------------------
    # SHOT 3: THE VINCULADOS SPACE GUNDAM ACE (Frames 221 - 330)
    # High-Agility Gundam Zero-G Flight & Combat Stance:
    # (Negative rot_x lifts thighs/arms forward, Positive rot_x bends knees backward!)
    # -------------------------------------------------------------------------
    key_transform(hero_suit["root"], 220, loc=(0, 0, 500))

    # Pose A (Frame 221): High-speed zero-G arrival braking.
    # Left knee tucked high forward (-55°), left shin bent down/back (+75°). Right leg swept back (+22°).
    # Shield arm raised to guard, Lance arm cocked back.
    key_gundam_pose(
        hero_suit, 221,
        loc=(1.25, 1.80, 0.25), rot_deg=(-12, 14, 28),
        torso_deg=(-10, -6, -8), head_deg=(8, -4, 12),
        binder_l_deg=(14, -28, 16), binder_r_deg=(14, 28, -16),
        sh_l_deg=(-38, 24, -18), el_l_deg=(-58, 0, 16),
        sh_r_deg=(18, -22, 12), el_r_deg=(-34, 0, -12),
        hip_l_deg=(-54, 8, -6), kn_l_deg=(78, 0, 0), ank_l_deg=(-18, 0, 0),
        hip_r_deg=(24, -8, 8), kn_r_deg=(22, 0, 0), ank_r_deg=(-18, 0, 0),
    )

    # Pose B (Frame 256): Zero-G Vernier Flare & Torso Alignment toward camera
    key_gundam_pose(
        hero_suit, 256,
        loc=(0.10, 0.15, -0.22), rot_deg=(-4, 4, 18),
        torso_deg=(-4, 2, -10), head_deg=(4, -2, 10),
        binder_l_deg=(22, -38, 22), binder_r_deg=(22, 38, -22),
        sh_l_deg=(-44, 32, -24), el_l_deg=(-68, 0, 20),
        sh_r_deg=(-16, -26, -8), el_r_deg=(-48, 0, -14),
        hip_l_deg=(-46, 8, -8), kn_l_deg=(64, 0, 0), ank_l_deg=(-14, 0, 0),
        hip_r_deg=(18, -6, 6), kn_r_deg=(18, 0, 0), ank_r_deg=(-14, 0, 0),
    )

    # Pose C (Frame 296): Heroic Combat Stance:
    # Right arm raises to level the glowing Beam Lance toward the Star Sea, Left arm braces the Shield
    key_gundam_pose(
        hero_suit, 296,
        loc=(-0.10, -0.10, -0.10), rot_deg=(-2, -2, 10),
        torso_deg=(2, -4, 8), head_deg=(2, 4, -10),
        binder_l_deg=(26, -42, 26), binder_r_deg=(26, 42, -26),
        sh_l_deg=(-48, 36, -26), el_l_deg=(-72, 0, 22),
        sh_r_deg=(-52, -18, -14), el_r_deg=(-54, 0, -12),
        hip_l_deg=(-38, 10, -6), kn_l_deg=(52, 0, 0), ank_l_deg=(-12, 0, 0),
        hip_r_deg=(22, -8, 8), kn_r_deg=(24, 0, 0), ank_r_deg=(-16, 0, 0),
    )

    # Pose D (Frame 330): Forward High-G Dash
    key_gundam_pose(
        hero_suit, 330,
        loc=(-0.45, -1.20, 0.14), rot_deg=(-14, -8, 6),
        torso_deg=(-8, -2, 6), head_deg=(10, 2, -6),
        binder_l_deg=(30, -46, 28), binder_r_deg=(30, 46, -28),
        sh_l_deg=(-42, 32, -22), el_l_deg=(-64, 0, 18),
        sh_r_deg=(-58, -14, -12), el_r_deg=(-46, 0, -10),
        hip_l_deg=(-48, 8, -6), kn_l_deg=(68, 0, 0), ank_l_deg=(-16, 0, 0),
        hip_r_deg=(28, -8, 8), kn_r_deg=(20, 0, 0), ank_r_deg=(-20, 0, 0),
    )
    key_transform(hero_suit["root"], 331, loc=(0, 0, 500))

    key_transform(cam_obj, 221, loc=(-1.2, -8.5, 1.55), rot=(math.radians(89.2), 0, math.radians(-8)))
    key_transform(cam_obj, 330, loc=(0.9, -7.8, 1.70), rot=(math.radians(89.0), 0, math.radians(7)))

    # -------------------------------------------------------------------------
    # SHOT 4: THE FREE TIDE VOID GALLEON (Frames 331 - 440)
    # -------------------------------------------------------------------------
    key_transform(galleon, 330, loc=(0, 0, 500))
    key_transform(galleon, 331, loc=(1.5, 4.0, -0.8), rot=(math.radians(-4), math.radians(8), math.radians(-138)))
    key_transform(galleon, 440, loc=(-1.0, 1.5, -0.2), rot=(math.radians(-4), math.radians(8), math.radians(-145)))

    key_transform(cam_obj, 331, loc=(-10.8, -11.8, 1.8), rot=(math.radians(84), 0, math.radians(-42)))
    key_transform(cam_obj, 440, loc=(-9.0, -13.8, 3.0), rot=(math.radians(79), 0, math.radians(-34)))

    # =========================================================================
    # SEAMLESS UNBROKEN SEQUENCE:
    # SHOT 5 (THE CALM / STANDOFF, 441-505) -> GUNDAM INTERCEPTOR FLYBY (502-535)
    # -> SHOT 6 (WIDE FLEET BATTLE, 530-642) -> UPWARD TILT INTO TITLE (622-760)
    # ZERO CAMERA CUTS OR TELEPORTS ACROSS FRAMES 441 - 760!
    # =========================================================================

    # 1. Left Flank: Acero Battleline continuously in position
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

    # 2. Right Flank: Free Tide Flotilla continuously in position
    key_transform(galleon, 441, loc=(7.5, 3.0, 0.4), rot=rads((-6, -10, 110)))
    key_transform(galleon, 515, loc=(10.5, 4.2, 0.3), rot=rads((4, -10, 82)))
    key_transform(galleon, 575, loc=(12.2, 5.4, 0.3), rot=rads((5, -10, 76)))
    key_transform(galleon, 650, loc=(10.0, 7.0, 0.5), rot=rads((5, -10, 78)))

    key_transform(raider1, 440, loc=(0, 0, 500))
    key_transform(raider1, 441, loc=(15.2, -2.6, -1.8), rot=rads((8, -12, 70)))
    key_transform(raider1, 535, loc=(16.2, -0.8, -1.7), rot=rads((8, -12, 68)))
    key_transform(raider1, 650, loc=(13.5, 1.5, -1.4), rot=rads((8, -12, 72)))

    key_transform(raider2, 440, loc=(0, 0, 500))
    key_transform(raider2, 441, loc=(13.8, 10.4, 2.0), rot=rads((4, -8, 84)))
    key_transform(raider2, 535, loc=(15.0, 12.0, 2.2), rot=rads((4, -8, 82)))
    key_transform(raider2, 650, loc=(12.0, 13.5, 2.5), rot=rads((4, -8, 85)))

    # 3. AGILE GUNDAM ACE SQUADRON (Frames 500 -> 650):
    # Flying fast between the two capital battlelines
    for ace in [vinc_ace1, vinc_ace2, vinc_ace3]:
        key_transform(ace["root"], 499, loc=(0, 0, 500))

    # --- ACE 1 (Lead Interceptor) ---
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
    key_gundam_pose(
        vinc_ace2, 620,
        loc=(-1.6, 5.0, 0.5), rot_deg=(12, -14, 28),
    )
    key_gundam_pose(
        vinc_ace2, 650,
        loc=(1.2, 6.8, 1.2), rot_deg=(-12, 12, -18),
    )

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
    key_gundam_pose(
        vinc_ace3, 588,
        loc=(-2.4, 5.2, 2.2), rot_deg=(14, -16, 32),
    )
    key_gundam_pose(
        vinc_ace3, 650,
        loc=(-3.5, 7.5, 1.6), rot_deg=(-10, 16, -38),
    )

    # 4. UNBROKEN MASTER CAMERA SHOT:
    # From low glide between fleets (Shot 5) smoothly pulling back to reveal wide battle,
    # then tilting upward into the starfield zenith as the Climax Detonation hits!
    key_transform(cam_obj, 441, loc=(0.0, -13.0, 3.2), rot=rads((83, 0, 0)))
    key_transform(cam_obj, 502, loc=(0.0, -18.0, 5.0), rot=rads((79, 0, 0)))
    key_transform(cam_obj, 538, loc=(0.0, -25.0, 8.0), rot=rads((74, 0, 0)))
    key_transform(cam_obj, 620, loc=(0.0, -48.5, 18.2), rot=rads((69, 0, 0)))
    key_transform(cam_obj, 654, loc=(0.0, -51.0, 22.5), rot=rads((106, 0, 0)))
    key_transform(cam_obj, 760, loc=(0.0, -46.0, 24.5), rot=rads((108, 0, 0)))

    # Hide battle ships only after camera has tilted up to the sky above
    for s in all_ship_roots:
        if s != hero_suit["root"]:
            key_transform(s, 655, loc=(0, 0, 500))

    # Animate 30 Repeatable Battle Lasers
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

    # Animate Controlled Overlapping Explosions + Climax Detonation
    for exp_item in explosions:
        r_obj = exp_item["root"]
        l_obj = exp_item["light"]
        ec = exp_item["cfg"]
        fs, fp, fe, max_s = ec["fs"], ec["fp"], ec["fe"], ec["max_s"]

        key_transform(r_obj, 1, loc=(0, 0, 500), scale=(0.01, 0.01, 0.01))
        key_transform(r_obj, fs - 1, loc=(0, 0, 500), scale=(0.01, 0.01, 0.01))

        key_transform(r_obj, fs, loc=ec["pos"], scale=(0.25, 0.25, 0.25))
        l_obj.data.energy = 10.0
        l_obj.data.keyframe_insert("energy", frame=fs)

        key_transform(r_obj, fp, loc=ec["pos"], scale=(max_s * 0.72, max_s * 0.72, max_s * 0.72))
        l_obj.data.energy = 45.0 if ec["name"] == "Exp_Climax" else 28.0
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

    # Channel 1: 3D Scene Layer
    strip_3d = se_strips.new_scene(name="3D_Layer", scene=scene_3d, channel=1, frame_start=1)
    strip_3d.frame_final_duration = total_frames
    strip_3d.scene_input = 'CAMERA'
    strip_3d.scene_camera = cam_obj

    # Smooth Optical Dip-to-Dark-Éther Transitions between Faction Introductions (Frames 110, 220, 330)
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

    # Narrative Titles (Acts 1-6)
    titles = [
        {"start": 10, "end": 104, "h": "PROLOGUE", "sub": "In the beginning, the void was not empty.\nIt was the Star Sea... an ocean of dark energy called the Éther."},
        {"start": 118, "end": 214, "h": "THE ARMADA OF ACERO", "sub": "An empire of steel that burned the wind as fuel,\nforging colossal battle lines to tame the deep."},
        {"start": 228, "end": 324, "h": "THE VINCULADOS", "sub": "Mystic pilots bonded to the vacuum by neural resonance,\nsinging in harmony with the soul of the void."},
        {"start": 338, "end": 434, "h": "THE FREE TIDE", "sub": "Nomad corsairs who unfurled quantum sails on wooden hulls,\nriding the living breath of creation."},
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
    # Starts at full frame (scale 1.00) so there are ZERO border boxes, pushes smoothly in to 1.06!
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

    # Climax Resonance Shockwave Flash (Channel 6, placed OVER the 3D scene & logo)
    # Flashes at frame 640-644 on the orchestral title braam peak, washing smoothly into the clean logo
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

    # Full-screen black fade-out at the very end (frames 730 - 760)
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

def build_3d_cinematic(output_video_path: str):
    scene_3d, scene_seq = setup_cinematic_scene()
    if hasattr(scene_seq.render.image_settings, "media_type"):
        scene_seq.render.image_settings.media_type = 'VIDEO'
    if "FFMPEG" in [e.identifier for e in scene_seq.render.image_settings.bl_rna.properties['file_format'].enum_items]:
        scene_seq.render.image_settings.file_format = 'FFMPEG'
    scene_seq.render.ffmpeg.format = 'OGG'
    scene_seq.render.ffmpeg.codec = 'THEORA'
    scene_seq.render.ffmpeg.audio_codec = 'VORBIS'
    scene_seq.render.ffmpeg.video_bitrate = 10000
    scene_seq.render.filepath = os.path.abspath(output_video_path)

    print(f"==> Rendering 1080p AAA 3D cinematic to {scene_seq.render.filepath}...")
    bpy.ops.render.render(animation=True)
    print("==> 1080p AAA 3D Cinematic Render Complete!")

if __name__ == "__main__":
    if "--preview-shots" in sys.argv:
        scene_3d, scene_seq = setup_cinematic_scene()
        bpy.context.window.scene = scene_seq
        scene_seq.render.image_settings.file_format = 'PNG'
        preview_list = [
            ("shot3_gundam_arrive", 232),
            ("shot3_gundam_ready", 285),
            ("shot5_to_6_bridge", 522),
            ("shot6_battle_wide", 572),
            ("shot6_to_7_bridge", 644),
        ]
        for name, f_num in preview_list:
            scene_seq.frame_set(f_num)
            scene_seq.render.filepath = os.path.abspath(f"assets/preview_{name}.png")
            bpy.ops.render.render(write_still=True)
    else:
        out_rel = os.path.join("assets", "video", "intro.ogv")
        build_3d_cinematic(out_rel)
