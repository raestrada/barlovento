"""
BARLOVENTO — AAA 3D Ship & Mecha Model Builders for Blender 4.2 Opening Cinematic (v9 Sculpted & Subdivided Edition)
Combines high-poly subdivided lofted mecha & naval geometry with 100% authentic in-game faction designs:
1. Armada of Acero: Anvil-class Dreadnought & Hammer-class Spinal Railgun Battlecruisers
2. The Vinculados: Seraph-Prime Colossal Mobile Armor (Sculpted Subsurf-2 Gundam Anatomy, Cobalt Blue Chest, Dual Amber Intake Louvers, Crimson Cockpit & Chin, Golden V-Fin Crest, Magenta Soul Core, 4 Swept Seraph Wing-Binders + Funnels, Hip Mega-Buster Cannons) & CNS Cradle Pegasus Carrier
3. The Free Tide: El Soberano Void Galleon (Mahogany & Brass Ribs, Translucent Pressurized Amber-Glass Deck Domes, Radial Spar Booms, Billowing Cyan Quantum Sails, Articulated Mechanical Éther-Oars)
"""

import os
import math
import random
import bpy
import bmesh
import mathutils

def rads(deg_tuple):
    return (math.radians(deg_tuple[0]), math.radians(deg_tuple[1]), math.radians(deg_tuple[2]))

def enable_alpha_blend(mat):
    if hasattr(mat, "surface_render_method"):
        mat.surface_render_method = 'BLENDED'
    elif hasattr(mat, "blend_method"):
        mat.blend_method = 'BLEND'

# -------------------------------------------------------------------------
# ADVANCED PBR & PROCEDURAL SHADER MATERIALS
# -------------------------------------------------------------------------
def create_pbr_hull_material(name, base_color, metallic=0.80, roughness=0.30, texture_path=None, tex_scale=0.45, bump_strength=0.40, coat=0.0, tex_color_mix=0.22, emission_col=None, emission_str=0.0):
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
    if emission_col and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = emission_col
        bsdf.inputs["Emission Strength"].default_value = emission_str

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
        mix.inputs["Factor"].default_value = tex_color_mix
        mix.inputs[6].default_value = base_color

        bump = nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = bump_strength
        bump.inputs["Distance"].default_value = 0.035

        links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
        links.new(tex.outputs["Color"], mix.inputs[7])
        links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        links.new(tex.outputs["Color"], bump.inputs["Height"])
        links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    return mat

def create_ribbed_sinew_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.045, 0.055, 0.085, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.76
    bsdf.inputs["Roughness"].default_value = 0.34

    coord = nodes.new("ShaderNodeTexCoord")
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = 'BANDS'
    wave.bands_direction = 'Z'
    wave.inputs["Scale"].default_value = 18.0
    wave.inputs["Distortion"].default_value = 1.5

    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.42
    bump.inputs["Distance"].default_value = 0.02

    links.new(coord.outputs["Object"], wave.inputs["Vector"])
    links.new(wave.outputs["Color"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat

def create_emissive_material(name, color, strength=5.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")

    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.20
    bsdf.inputs["Emission Color"].default_value = color
    bsdf.inputs["Emission Strength"].default_value = strength

    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        enable_alpha_blend(mat)

    return mat

def create_quantum_sail_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")

    coord = nodes.new("ShaderNodeTexCoord")
    wave1 = nodes.new("ShaderNodeTexWave")
    wave1.wave_type = 'BANDS'
    wave1.bands_direction = 'X'
    wave1.inputs["Scale"].default_value = 10.0
    wave1.inputs["Distortion"].default_value = 0.5

    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[0].color = (0.02, 0.62, 0.95, 1.0)
    ramp.color_ramp.elements[1].position = 0.88
    ramp.color_ramp.elements[1].color = (0.28, 0.92, 1.0, 1.0)

    links.new(coord.outputs["Generated"], wave1.inputs["Vector"])
    links.new(wave1.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 2.6
    bsdf.inputs["Roughness"].default_value = 0.18
    bsdf.inputs["Alpha"].default_value = 0.82
    enable_alpha_blend(mat)
    return mat

def create_asteroid_rock_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Metallic"].default_value = 0.10
    bsdf.inputs["Roughness"].default_value = 0.90

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
    ramp.color_ramp.elements[0].color = (0.022, 0.028, 0.038, 1.0)
    ramp.color_ramp.elements[1].position = 0.85
    ramp.color_ramp.elements[1].color = (0.09, 0.10, 0.13, 1.0)

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

# -------------------------------------------------------------------------
# GEOMETRY PRIMITIVES & LOFTING HELPERS
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

def part_box(name, size, parent, col, mat, loc=(0,0,0), rot=(0,0,0), scale=(1,1,1), subsurf=0, bevel=0.02, smooth=False):
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

# -------------------------------------------------------------------------
# 1. STAR SEA ASTEROID GORGE & BIOLUMINESCENT ÉTHER MOTES
# -------------------------------------------------------------------------
def build_star_sea_environment(collection, count=26):
    env_root = bpy.data.objects.new("StarSea_Environment_Root", None)
    collection.objects.link(env_root)

    mat_rock = create_asteroid_rock_material("Asteroid_Basalt")
    mat_crystal = create_emissive_material("Asteroid_EtherCrystal", (0.10, 0.90, 1.0, 1.0), strength=7.5)
    mat_mote_cyan = create_emissive_material("Ether_Mote_Cyan", (0.12, 0.92, 1.0, 1.0), strength=9.0)
    mat_mote_violet = create_emissive_material("Ether_Mote_Violet", (0.85, 0.22, 1.0, 1.0), strength=9.0)

    rng = random.Random(2028)
    asteroids = []
    for i in range(count):
        x = rng.uniform(-16, 16)
        if abs(x) < 2.8:
            x += 4.8 if x >= 0 else -4.8
        y = rng.uniform(-24, 18)
        z = rng.uniform(-7.0, 7.0)
        r = rng.uniform(0.50, 1.85)
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

        obj = make_part(f"Asteroid_{i}", bm, env_root, collection, mat_rock, loc=(x, y, z), rot=rot, smooth=True)
        if i % 3 == 0:
            part_taper_box(f"Crystal_{i}", (r * 0.28, r * 0.22), (0.03, 0.03), r * 1.25, obj, collection, mat_crystal,
                           loc=(0, 0, r * 0.55), rot=rads((22, -18, 35)), bevel=0.01)
        asteroids.append((obj, (x, y, z), rot))

    # Bioluminescent Éther Current Motes & Streamers drifting along the Star Sea
    for m_idx in range(42):
        mx = rng.uniform(-14.0, 14.0)
        my = rng.uniform(-25.0, 18.0)
        mz = rng.uniform(-5.5, 5.5)
        mr = rng.uniform(0.035, 0.085)
        m_mat = mat_mote_cyan if m_idx % 2 == 0 else mat_mote_violet
        part_sphere(f"EtherMote_{m_idx}", mr, env_root, collection, m_mat, loc=(mx, my, mz), scale=(0.6, 3.8, 0.6), subdiv=2)

    return env_root, asteroids

# -------------------------------------------------------------------------
# 2. THE ARMADA OF ACERO — ANVIL-CLASS DREADNOUGHT & HAMMER-CLASS BATTLECRUISER
# -------------------------------------------------------------------------
def build_acero_warship(collection, texture_path, name_prefix="Acero_Dreadnought", scale_factor=1.0, ship_class="dreadnought"):
    is_bc = (ship_class == "battlecruiser")
    root = bpy.data.objects.new(name_prefix, None)
    collection.objects.link(root)

    mat_hull = create_pbr_hull_material(
        f"{name_prefix}_Titanium", (0.28, 0.34, 0.42, 1.0),
        metallic=0.88, roughness=0.28, texture_path=texture_path, tex_scale=0.36, bump_strength=0.50, tex_color_mix=0.24,
        emission_col=(0.03, 0.05, 0.08, 1.0), emission_str=0.14
    )
    mat_armor = create_pbr_hull_material(
        f"{name_prefix}_HeavyArmor", (0.42, 0.48, 0.56, 1.0),
        metallic=0.90, roughness=0.24, texture_path=texture_path, tex_scale=0.48, bump_strength=0.44, tex_color_mix=0.20
    )
    mat_dark = create_pbr_hull_material(
        f"{name_prefix}_DarkSteel", (0.10, 0.13, 0.18, 1.0),
        metallic=0.92, roughness=0.36, texture_path=texture_path, tex_scale=0.55, bump_strength=0.38, tex_color_mix=0.15
    )
    mat_amber = create_emissive_material(f"{name_prefix}_AmberFurnace", (1.0, 0.58, 0.08, 1.0), strength=7.5)
    mat_bridge = create_emissive_material(f"{name_prefix}_BridgeViewport", (0.30, 0.92, 1.0, 1.0), strength=8.5)
    mat_engine = create_emissive_material(f"{name_prefix}_EngineCore", (1.0, 0.48, 0.06, 1.0), strength=20.0)
    mat_plume = create_emissive_material(f"{name_prefix}_EnginePlume", (1.0, 0.36, 0.02, 0.76), strength=11.0, alpha=0.76)

    prof = [
        (-0.55, -1.0), (0.55, -1.0),
        (1.18, -0.45), (1.28, 0.35),
        (0.75, 1.0), (-0.75, 1.0),
        (-1.28, 0.35), (-1.18, -0.45)
    ]
    stations = [
        (8.8,  0.14, 0.46, -0.08),
        (7.4,  0.48, 0.76, -0.04),
        (4.8,  0.88, 0.95,  0.0),
        (1.5,  1.16, 1.08,  0.0),
        (-3.5, 1.24, 1.12,  0.0),
        (-7.4, 1.04, 1.00,  0.0),
    ]
    build_lofted_mesh(f"{name_prefix}_MainHull", prof, stations, root, collection, mat_hull, smooth=False)

    part_taper_box(f"{name_prefix}_ProwRam", (0.95, 3.2), (0.55, 2.2), 1.35, root, collection, mat_armor,
                   loc=(0.0, 7.6, -0.12), bevel=0.03)
    part_box(f"{name_prefix}_DorsalSpine", (0.55, 12.2, 0.18), root, collection, mat_armor,
             loc=(0.0, 0.6, 1.08), bevel=0.02)

    for side in [-1.0, 1.0]:
        part_taper_box(f"{name_prefix}_BowCheek_{side}", (0.38, 3.0), (0.24, 1.9), 1.15, root, collection, mat_dark,
                       loc=(side * 0.46, 7.2, -0.06), rot=(0, math.radians(side * 12), 0), bevel=0.03)
        part_box(f"{name_prefix}_BowConduit_{side}", (0.05, 4.4, 0.06), root, collection, mat_amber,
                 loc=(side * 0.98, 4.4, 0.20), rot=(0, 0, math.radians(side * -7)))

    sponson_prof = [(-0.45, -0.60), (0.45, -0.48), (0.55, 0.48), (-0.45, 0.60)]
    for side in [-1.0, 1.0]:
        sp_stations = [
            (6.0,  0.25, 0.45, -0.12),
            (3.2,  0.85, 0.78, -0.08),
            (0.8,  1.52, 1.12, -0.04),
            (-4.2, 1.52, 1.12, -0.04),
            (-6.8, 0.85, 0.82, -0.08),
        ]
        build_lofted_mesh(f"{name_prefix}_Sponson_{side}", sponson_prof, sp_stations, root, collection, mat_armor,
                          loc=(side * 1.48, 0, 0), rot=(0, 0, 0 if side > 0 else math.pi))

        part_box(f"{name_prefix}_FurnaceGlowF_{side}", (0.58, 0.12, 0.48), root, collection, mat_amber,
                 loc=(side * 1.78, 3.25, -0.04))
        part_box(f"{name_prefix}_FurnaceSlit_{side}", (0.08, 6.2, 0.18), root, collection, mat_amber,
                 loc=(side * 2.18, -1.2, 0.02))

        for gy in [-3.6, -2.2, -0.8, 0.6]:
            part_box(f"{name_prefix}_GreebleTop_{side}_{gy}", (0.50, 0.78, 0.28), root, collection, mat_dark,
                     loc=(side * 1.72, gy, 0.58), bevel=0.02)
            part_box(f"{name_prefix}_Casemate_{side}_{gy}", (0.38, 0.85, 0.40), root, collection, mat_dark,
                     loc=(side * 2.18, gy, -0.05), bevel=0.02)
            part_cyl(f"{name_prefix}_BroadGun_{side}_{gy}", 0.04, 0.03, 0.92, root, collection, mat_armor,
                     loc=(side * 2.45, gy + 0.25, -0.05), rot=(math.radians(-75), math.radians(side * 20), 0), segs=10)

    part_taper_box(f"{name_prefix}_SpineDeck", (1.72, 10.2), (1.38, 9.2), 0.58, root, collection, mat_dark,
                   loc=(0, -0.4, 1.25), bevel=0.03)

    part_taper_box(f"{name_prefix}_Citadel_L1", (2.15, 3.8), (1.75, 3.1), 0.98, root, collection, mat_hull,
                   loc=(0, -2.1, 1.85), bevel=0.03)
    part_taper_box(f"{name_prefix}_Citadel_L2", (1.55, 2.5), (1.25, 1.95), 1.08, root, collection, mat_armor,
                   loc=(0, -2.3, 2.78), bevel=0.03)
    part_taper_box(f"{name_prefix}_Citadel_L3", (1.10, 1.55), (0.88, 1.25), 0.88, root, collection, mat_dark,
                   loc=(0, -2.4, 3.65), bevel=0.02)
    part_box(f"{name_prefix}_BridgeCyanSlit", (0.92, 0.08, 0.14), root, collection, mat_bridge,
             loc=(0, -1.30, 2.98))
    for bz in [2.15, 3.75]:
        part_box(f"{name_prefix}_BridgeAmber_{bz}", (0.78, 0.06, 0.06), root, collection, mat_amber,
                 loc=(0, -1.32 if bz < 3.0 else -1.68, bz))
    for mx in [-0.35, 0.0, 0.35]:
        part_cyl(f"{name_prefix}_Mast_{mx}", 0.03, 0.012, 1.65, root, collection, mat_armor,
                 loc=(mx, -2.5, 4.65), segs=8)

    fin_prof = [(-0.18, 0.0), (0.18, 0.0), (0.09, 1.0), (-0.09, 1.0)]
    fin_st = [(-3.6, 1.0, 0.2, 1.45), (-4.4, 1.0, 2.7, 1.45), (-5.6, 0.8, 2.7, 1.45), (-6.4, 0.5, 0.2, 1.45)]
    build_lofted_mesh(f"{name_prefix}_DorsalFin", fin_prof, fin_st, root, collection, mat_armor)

    if is_bc:
        for side in [-1.0, 1.0]:
            part_cyl(f"{name_prefix}_SpinalRailgun_{side}", 0.14, 0.11, 8.8, root, collection, mat_armor,
                     loc=(side * 0.45, 3.8, 1.52), rot=(math.radians(-90), 0, 0), segs=12)
            part_box(f"{name_prefix}_OutriggerPod_{side}", (0.75, 4.8, 0.68), root, collection, mat_dark,
                     loc=(side * 2.55, -1.6, 0.0), bevel=0.03)
            part_box(f"{name_prefix}_OutriggerVent_{side}", (0.48, 0.12, 0.38), root, collection, mat_amber,
                     loc=(side * 2.55, 0.85, 0.0))

    t_positions = [(4.7, 1.48), (2.5, 1.70), (0.3, 1.92)] if not is_bc else [(3.5, 1.65), (0.8, 1.85)]
    turret_pivots = []
    for idx, (ty, tz) in enumerate(t_positions):
        part_cyl(f"{name_prefix}_Barbette_{idx}", 0.55, 0.62, 0.38, root, collection, mat_dark, loc=(0, ty, tz - 0.12), segs=14, smooth=False)
        t_piv = make_pivot(f"{name_prefix}_TurretPiv_{idx}", root, collection, loc=(0, ty, tz + 0.14))
        part_taper_box(f"{name_prefix}_TurretHouse_{idx}", (1.12, 1.42), (0.82, 1.10), 0.40, t_piv, collection, mat_armor,
                       loc=(0, 0, 0), bevel=0.03)
        for bx in [-0.26, 0.0, 0.26]:
            part_cyl(f"{name_prefix}_Barrel_{idx}_{bx}", 0.06, 0.045, 1.90, t_piv, collection, mat_dark,
                     loc=(bx, 1.18, 0.05), rot=(math.radians(-83), 0, 0), segs=12)
        turret_pivots.append(t_piv)

    eng_coords = [(-1.18, 0.48), (1.18, 0.48), (-1.18, -0.48), (1.18, -0.48)]
    for idx, (ex, ez) in enumerate(eng_coords):
        part_cyl(f"{name_prefix}_Shroud_{idx}", 0.70, 0.62, 2.7, root, collection, mat_dark,
                 loc=(ex, -7.8, ez), rot=(math.radians(90), 0, 0), segs=20)
        part_cyl(f"{name_prefix}_Rim_{idx}", 0.64, 0.58, 0.48, root, collection, mat_armor,
                 loc=(ex, -9.0, ez), rot=(math.radians(90), 0, 0), segs=20)
        part_cyl(f"{name_prefix}_Core_{idx}", 0.50, 0.44, 0.28, root, collection, mat_engine,
                 loc=(ex, -9.18, ez), rot=(math.radians(90), 0, 0), segs=20)
        part_cyl(f"{name_prefix}_Plume_{idx}", 0.46, 0.04, 3.2, root, collection, mat_plume,
                 loc=(ex, -10.8, ez), rot=(math.radians(90), 0, 0), segs=16)

    root.scale = (scale_factor, scale_factor, scale_factor)
    return root, turret_pivots

def part_chamfer_box(name, size, parent, col, mat, loc=(0,0,0), rot=(0,0,0), scale=(1,1,1), chamfer=0.022):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if chamfer > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges, offset=chamfer, segments=1, profile=0.5)
    return make_part(name, bm, parent, col, mat, loc, rot, scale=scale, subsurf=0, smooth=False)

def part_chamfer_wedge(name, size_bot, size_top, height, parent, col, mat, loc=(0,0,0), rot=(0,0,0), chamfer=0.018, top_offset=(0.0, 0.0)):
    bm = bmesh.new()
    bx, by = size_bot[0] * 0.5, size_bot[1] * 0.5
    tx, ty = size_top[0] * 0.5, size_top[1] * 0.5
    ox, oy = top_offset
    hz = height * 0.5
    v0 = bm.verts.new((-bx, -by, -hz))
    v1 = bm.verts.new(( bx, -by, -hz))
    v2 = bm.verts.new(( bx,  by, -hz))
    v3 = bm.verts.new((-bx,  by, -hz))
    v4 = bm.verts.new((-tx + ox, -ty + oy,  hz))
    v5 = bm.verts.new(( tx + ox, -ty + oy,  hz))
    v6 = bm.verts.new(( tx + ox,  ty + oy,  hz))
    v7 = bm.verts.new((-tx + ox,  ty + oy,  hz))
    bm.faces.new((v0, v3, v2, v1))
    bm.faces.new((v4, v5, v6, v7))
    bm.faces.new((v0, v1, v5, v4))
    bm.faces.new((v1, v2, v6, v5))
    bm.faces.new((v2, v3, v7, v6))
    bm.faces.new((v3, v0, v4, v7))
    if chamfer > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges, offset=chamfer, segments=1, profile=0.5)
    return make_part(name, bm, parent, col, mat, loc, rot, subsurf=0, smooth=False)

# -------------------------------------------------------------------------
# 3. THE VINCULADOS — HARD-SURFACE ANGULAR GUNDAM MECHA (SERAPH-PRIME & ESCORT WING)
# -------------------------------------------------------------------------
def build_vinculados_colossus(collection, texture_path, name_prefix="Seraph_Prime", scale_factor=1.0, is_wingman=False):
    root = bpy.data.objects.new(name_prefix, None)
    collection.objects.link(root)

    torso = make_pivot(f"{name_prefix}_TorsoPiv", root, collection, loc=(0.0, 0.0, 1.56))
    head = make_pivot(f"{name_prefix}_HeadPiv", torso, collection, loc=(0.0, 0.0, 1.24))
    binder_L = make_pivot(f"{name_prefix}_BinderPiv_L", torso, collection, loc=(-0.38, 0.44, 1.05))
    binder_R = make_pivot(f"{name_prefix}_BinderPiv_R", torso, collection, loc=( 0.38, 0.44, 1.05))
    sh_L = make_pivot(f"{name_prefix}_ShoulderPiv_L", torso, collection, loc=(-0.78, 0.02, 1.00))
    sh_R = make_pivot(f"{name_prefix}_ShoulderPiv_R", torso, collection, loc=( 0.78, 0.02, 1.00))
    el_L = make_pivot(f"{name_prefix}_ElbowPiv_L", sh_L, collection, loc=(-0.16, 0.02, -0.68))
    el_R = make_pivot(f"{name_prefix}_ElbowPiv_R", sh_R, collection, loc=( 0.16, 0.02, -0.68))
    hip_L = make_pivot(f"{name_prefix}_HipPiv_L", root, collection, loc=(-0.42, 0.0, 1.18))
    hip_R = make_pivot(f"{name_prefix}_HipPiv_R", root, collection, loc=( 0.42, 0.0, 1.18))
    kn_L = make_pivot(f"{name_prefix}_KneePiv_L", hip_L, collection, loc=(-0.02, 0.0, -0.98))
    kn_R = make_pivot(f"{name_prefix}_KneePiv_R", hip_R, collection, loc=( 0.02, 0.0, -0.98))
    ank_L = make_pivot(f"{name_prefix}_AnklePiv_L", kn_L, collection, loc=(-0.04, 0.02, -1.04))
    ank_R = make_pivot(f"{name_prefix}_AnklePiv_R", kn_R, collection, loc=( 0.04, 0.02, -1.04))

    # Canonical Vinculados Gundam Materials (Hard-Surface Matte/Semi-Gloss Ceramic White, Deep Cobalt Blue, Crimson, Gold & Psycho-Frame)
    mat_ceramic = create_pbr_hull_material(
        f"{name_prefix}_CeramicWhite", (0.93, 0.96, 1.0, 1.0),
        metallic=0.32, roughness=0.22, texture_path=texture_path, tex_scale=0.68, bump_strength=0.36, coat=0.65, tex_color_mix=0.24
    )
    mat_cobalt = create_pbr_hull_material(
        f"{name_prefix}_CobaltBlue", (0.04, 0.14, 0.48, 1.0),
        metallic=0.58, roughness=0.24, texture_path=texture_path, tex_scale=0.68, bump_strength=0.34, coat=0.55, tex_color_mix=0.10
    )
    mat_crimson = create_pbr_hull_material(
        f"{name_prefix}_CrimsonRed", (0.86, 0.10, 0.14, 1.0),
        metallic=0.45, roughness=0.25, coat=0.55, tex_color_mix=0.0
    )
    mat_gold = create_pbr_hull_material(
        f"{name_prefix}_GoldCrest", (0.98, 0.78, 0.16, 1.0),
        metallic=0.94, roughness=0.18, emission_col=(0.95, 0.70, 0.10, 1.0), emission_str=0.60
    )
    mat_frame = create_pbr_hull_material(
        f"{name_prefix}_DarkMechaFrame", (0.10, 0.12, 0.17, 1.0),
        metallic=0.84, roughness=0.32, texture_path=texture_path, tex_scale=0.85, bump_strength=0.38, tex_color_mix=0.12
    )
    mat_amber = create_emissive_material(f"{name_prefix}_AmberIntake", (1.0, 0.68, 0.06, 1.0), strength=10.5)
    mat_core = create_emissive_material(f"{name_prefix}_SoulCore", (1.0, 0.16, 0.88, 1.0), strength=16.0)
    mat_cyan = create_emissive_material(f"{name_prefix}_CyanVisor", (0.06, 0.94, 1.0, 1.0), strength=14.0)

    # 1. ANGULAR GUNDAM WAIST, CROTCH THRUSTER V-BLOCK, SPLIT SKIRT ARMOR & RECTANGULAR HIP RAIL-CANNONS
    part_chamfer_box(f"{name_prefix}_PelvisCoreFrame", (0.64, 0.46, 0.34), root, collection, mat_frame,
                     loc=(0.0, 0.0, 1.34), chamfer=0.02)
    # Central forward-jutting angular crotch block (RX-93 / Freedom style)
    part_chamfer_wedge(f"{name_prefix}_CrotchCenterBlock", (0.24, 0.32), (0.30, 0.42), 0.52, root, collection, mat_ceramic,
                       loc=(0.0, -0.18, 1.26), rot=rads((10, 0, 0)), chamfer=0.018, top_offset=(0.0, -0.04))
    part_chamfer_wedge(f"{name_prefix}_CrotchCobaltCap", (0.18, 0.16), (0.24, 0.20), 0.26, root, collection, mat_cobalt,
                       loc=(0.0, -0.34, 1.38), rot=rads((12, 0, 0)), chamfer=0.012)
    part_chamfer_box(f"{name_prefix}_CrotchCrimsonVane", (0.12, 0.12, 0.18), root, collection, mat_crimson,
                     loc=(0.0, -0.36, 1.12), rot=rads((-12, 0, 0)), chamfer=0.01)
    # Golden V-Emblem on Crotch Block
    for side in [-1.0, 1.0]:
        part_chamfer_box(f"{name_prefix}_CrotchGoldV_{side}", (0.035, 0.04, 0.14), root, collection, mat_gold,
                         loc=(side * 0.045, -0.43, 1.38), rot=rads((12, side * 28, 0)), chamfer=0.004)

        # Angular Split Front Skirt Armor Plates (Layered White + Cobalt Vent + Gold Lower Lip)
        part_chamfer_wedge(f"{name_prefix}_FrontSkirt_{side}", (0.28, 0.10), (0.34, 0.12), 0.48, root, collection, mat_ceramic,
                           loc=(side * 0.29, -0.29, 1.20), rot=rads((-14, side * 6, side * -4)), chamfer=0.016)
        part_chamfer_box(f"{name_prefix}_FrontSkirtCobalt_{side}", (0.20, 0.07, 0.22), root, collection, mat_cobalt,
                         loc=(side * 0.29, -0.33, 1.24), rot=rads((-14, side * 6, side * -4)), chamfer=0.012)
        part_chamfer_box(f"{name_prefix}_FrontSkirtVent_{side}", (0.14, 0.05, 0.06), root, collection, mat_amber,
                         loc=(side * 0.29, -0.36, 1.10), rot=rads((-14, side * 6, side * -4)), chamfer=0.005)

        # Angular Rear Skirt Armor & Verniers
        part_chamfer_wedge(f"{name_prefix}_RearSkirt_{side}", (0.30, 0.10), (0.34, 0.12), 0.44, root, collection, mat_ceramic,
                           loc=(side * 0.26, 0.28, 1.22), rot=rads((16, side * -5, 0)), chamfer=0.016)
        part_chamfer_box(f"{name_prefix}_RearSkirtCobalt_{side}", (0.20, 0.08, 0.20), root, collection, mat_cobalt,
                         loc=(side * 0.26, 0.33, 1.26), rot=rads((16, side * -5, 0)), chamfer=0.012)

        # Boxy Side Skirt Binders
        part_chamfer_wedge(f"{name_prefix}_SideSkirt_{side}", (0.14, 0.44), (0.18, 0.50), 0.44, root, collection, mat_ceramic,
                           loc=(side * 0.54, 0.0, 1.26), rot=rads((0, side * -14, 0)), chamfer=0.016)
        part_chamfer_box(f"{name_prefix}_SideSkirtCrimson_{side}", (0.10, 0.28, 0.16), root, collection, mat_crimson,
                         loc=(side * 0.60, 0.0, 1.32), rot=rads((0, side * -14, 0)), chamfer=0.01)

        # Rectangular Hard-Surface Xiphias Hip Mega-Buster Rail-Cannons (Blocky Mecha Barrels, NOT round tubes!)
        if not is_wingman:
            cx = side * 0.68
            part_chamfer_box(f"{name_prefix}_BusterHousing_{side}", (0.18, 1.05, 0.28), root, collection, mat_cobalt,
                             loc=(cx, -0.10, 1.26), rot=rads((14, 0, side * -4)), chamfer=0.018)
            part_chamfer_box(f"{name_prefix}_BusterUpperShroud_{side}", (0.14, 1.85, 0.12), root, collection, mat_ceramic,
                             loc=(cx + side * 0.04, -0.95, 1.14), rot=rads((14, 0, side * -4)), chamfer=0.014)
            part_chamfer_box(f"{name_prefix}_BusterLowerRail_{side}", (0.12, 1.95, 0.10), root, collection, mat_frame,
                             loc=(cx + side * 0.04, -1.00, 0.99), rot=rads((14, 0, side * -4)), chamfer=0.012)
            part_chamfer_box(f"{name_prefix}_BusterPlasmaCore_{side}", (0.06, 1.75, 0.05), root, collection, mat_cyan,
                             loc=(cx + side * 0.05, -1.02, 1.06), rot=rads((14, 0, side * -4)), chamfer=0.005)
            for r_i in range(3):
                d_step = 0.55 + r_i * 0.42
                part_chamfer_box(f"{name_prefix}_BusterGoldClamp_{side}_{r_i}", (0.17, 0.08, 0.24), root, collection, mat_gold,
                                 loc=(cx + side * 0.04, -0.25 - d_step, 1.22 - d_step * 0.25), rot=rads((14, 0, side * -4)), chamfer=0.008)

    # 2. ANGULAR GUNDAM TORSO: STEPPED ABDOMEN, CRIMSON COCKPIT BLOCK, FACETED COBALT CHEST & YELLOW LOUVER VENTS
    # Mechanical inner spine & stepped abdominal armor blocks
    part_chamfer_box(f"{name_prefix}_InnerSpineFrame", (0.56, 0.44, 1.24), torso, collection, mat_frame,
                     loc=(0.0, 0.02, 0.48), chamfer=0.02)
    part_chamfer_wedge(f"{name_prefix}_WaistBeltCobalt", (0.64, 0.50), (0.60, 0.48), 0.22, torso, collection, mat_cobalt,
                       loc=(0.0, -0.02, -0.04), chamfer=0.016)
    part_chamfer_wedge(f"{name_prefix}_AbLowerWhite", (0.58, 0.48), (0.68, 0.54), 0.34, torso, collection, mat_ceramic,
                       loc=(0.0, -0.04, 0.16), chamfer=0.018)
    part_chamfer_wedge(f"{name_prefix}_AbUpperWhite", (0.66, 0.52), (0.78, 0.60), 0.36, torso, collection, mat_ceramic,
                       loc=(0.0, -0.05, 0.46), chamfer=0.018)
    # Side hydraulic waist pistons
    for side in [-1.0, 1.0]:
        part_cyl(f"{name_prefix}_WaistPiston_{side}", 0.04, 0.04, 0.52, torso, collection, mat_gold,
                 loc=(side * 0.36, -0.10, 0.28), rot=rads((0, side * -8, 0)), segs=8, smooth=False)

    # Angular Forward-Jutting Crimson Cockpit Block & Upper Hatch
    part_chamfer_wedge(f"{name_prefix}_CockpitCrimsonLower", (0.28, 0.24), (0.34, 0.32), 0.38, torso, collection, mat_crimson,
                       loc=(0.0, -0.32, 0.34), rot=rads((-8, 0, 0)), chamfer=0.016, top_offset=(0.0, -0.04))
    part_chamfer_wedge(f"{name_prefix}_CockpitCrimsonUpper", (0.32, 0.28), (0.26, 0.20), 0.32, torso, collection, mat_crimson,
                       loc=(0.0, -0.36, 0.64), rot=rads((14, 0, 0)), chamfer=0.015)

    # Multi-Planar Cobalt Blue Pectoral Chest Armor (Left, Right & Center Sternum Blocks)
    part_chamfer_wedge(f"{name_prefix}_ChestCenterBlock", (0.44, 0.56), (0.52, 0.64), 0.62, torso, collection, mat_cobalt,
                       loc=(0.0, -0.04, 0.94), chamfer=0.022, top_offset=(0.0, -0.04))
    for side in [-1.0, 1.0]:
        part_chamfer_wedge(f"{name_prefix}_ChestPectoral_{side}", (0.42, 0.58), (0.54, 0.72), 0.58, torso, collection, mat_cobalt,
                           loc=(side * 0.40, -0.06, 0.94), rot=rads((0, side * -10, side * -8)), chamfer=0.022, top_offset=(0.0, -0.06))
        # White Upper Shoulder-Collar Armor Plates
        part_chamfer_wedge(f"{name_prefix}_CollarPlate_{side}", (0.32, 0.46), (0.24, 0.36), 0.18, torso, collection, mat_ceramic,
                           loc=(side * 0.36, 0.02, 1.28), rot=rads((0, side * -12, 0)), chamfer=0.014)
        # Classic Gundam Recessed Trapezoidal Chest Vent Housing + 3 Angled Amber Louver Slats!
        part_chamfer_wedge(f"{name_prefix}_ChestVentFrame_{side}", (0.28, 0.14), (0.24, 0.14), 0.22, torso, collection, mat_frame,
                           loc=(side * 0.38, -0.42, 0.88), rot=rads((-14, side * 14, side * -10)), chamfer=0.010)
        for slat_i in range(3):
            sz_off = -0.055 + slat_i * 0.055
            part_chamfer_box(f"{name_prefix}_ChestLouverSlat_{side}_{slat_i}", (0.21, 0.06, 0.032), torso, collection, mat_amber,
                             loc=(side * 0.38, -0.46, 0.88 + sz_off), rot=rads((-28, side * 14, side * -10)), chamfer=0.004)
        # Chest Vulcan Ports above Vents
        part_chamfer_box(f"{name_prefix}_ChestSensorCyan_{side}", (0.12, 0.06, 0.05), torso, collection, mat_cyan,
                         loc=(side * 0.36, -0.38, 1.16), rot=rads((12, side * 10, 0)), chamfer=0.004)

    # Central Octagonal Resonance Soul Core Chamber (Faceted 8-Sided Frame + Crystalline Core)
    part_cyl(f"{name_prefix}_CoreOctCollar", 0.22, 0.19, 0.12, torso, collection, mat_frame,
             loc=(0, -0.40, 0.94), rot=(math.radians(90), 0, math.radians(22.5)), segs=8, smooth=False)
    part_cyl(f"{name_prefix}_CoreGoldOct", 0.18, 0.16, 0.14, torso, collection, mat_gold,
             loc=(0, -0.42, 0.94), rot=(math.radians(90), 0, math.radians(22.5)), segs=8, smooth=False)
    part_sphere(f"{name_prefix}_SoulCoreCrystal", 0.12, torso, collection, mat_core, loc=(0, -0.45, 0.94), subdiv=1)

    # Neck Collar & Mechanical Neck Block
    part_chamfer_box(f"{name_prefix}_NeckCollarBase", (0.42, 0.42, 0.14), torso, collection, mat_frame,
                     loc=(0.0, 0.0, 1.30), chamfer=0.015)
    part_cyl(f"{name_prefix}_NeckPost", 0.13, 0.11, 0.24, torso, collection, mat_frame,
             loc=(0.0, 0.0, 1.40), segs=8, smooth=False)

    # 3. ANGULAR DORSAL BACKPACK & 4 SHARP MECHANICAL SERAPH WING-BINDERS + DOCKED FUNNELS
    part_chamfer_wedge(f"{name_prefix}_BackpackMain", (0.76, 0.42), (0.64, 0.34), 0.78, torso, collection, mat_frame,
                       loc=(0.0, 0.36, 0.88), chamfer=0.022)
    part_chamfer_wedge(f"{name_prefix}_BackpackCobaltCowl", (0.64, 0.36), (0.50, 0.28), 0.64, torso, collection, mat_cobalt,
                       loc=(0.0, 0.44, 0.92), chamfer=0.020)
    part_chamfer_box(f"{name_prefix}_BackpackCenterSpine", (0.22, 0.28, 0.72), torso, collection, mat_ceramic,
                     loc=(0.0, 0.52, 0.92), chamfer=0.016)

    for side, b_piv in [(-1.0, binder_L), (1.0, binder_R)]:
        # Angular Beam Saber Racks & Hexagonal Hilts
        part_chamfer_box(f"{name_prefix}_SaberRack_{side}", (0.12, 0.16, 0.24), torso, collection, mat_frame,
                         loc=(side * 0.30, 0.42, 1.24), rot=rads((22, side * 16, 0)), chamfer=0.01)
        part_cyl(f"{name_prefix}_SaberHilt_{side}", 0.04, 0.04, 0.58, torso, collection, mat_ceramic,
                 loc=(side * 0.34, 0.48, 1.48), rot=rads((22, side * 16, 0)), segs=8, smooth=False)
        part_cyl(f"{name_prefix}_SaberGoldCap_{side}", 0.048, 0.048, 0.08, torso, collection, mat_gold,
                 loc=(side * 0.38, 0.56, 1.72), rot=rads((22, side * 16, 0)), segs=8, smooth=False)

        # Upper Hard-Surface Mechanical Wing-Binder Blade (Sharp Flat Planes, Zero Subsurf!)
        part_chamfer_wedge(f"{name_prefix}_BinderUpper_{side}", (0.22, 0.48), (0.08, 0.20), 2.25, b_piv, collection, mat_ceramic,
                           loc=(side * 0.62, 0.26, 0.68), rot=rads((-18, side * 42, side * -12)), chamfer=0.016)
        part_chamfer_wedge(f"{name_prefix}_BinderUpperBlue_{side}", (0.16, 0.36), (0.06, 0.14), 1.75, b_piv, collection, mat_cobalt,
                           loc=(side * 0.58, 0.22, 0.64), rot=rads((-18, side * 42, side * -12)), chamfer=0.014)
        part_chamfer_wedge(f"{name_prefix}_BinderGoldBlade_{side}", (0.08, 0.22), (0.02, 0.08), 0.95, b_piv, collection, mat_gold,
                           loc=(side * 0.96, 0.32, 1.20), rot=rads((-18, side * 48, side * -14)), chamfer=0.008)
        part_chamfer_box(f"{name_prefix}_BinderVeinU_{side}", (0.04, 0.07, 1.85), b_piv, collection, mat_cyan,
                         loc=(side * 0.60, 0.13, 0.66), rot=rads((-18, side * 42, side * -12)), chamfer=0.004)

        # Docked Rectangular Fin-Funnels along Upper Wing Trailing Edge (Nu Gundam / Strike Freedom style!)
        for f_i in range(3):
            f_off = -0.38 + f_i * 0.44
            part_chamfer_box(f"{name_prefix}_DockedFunnelBody_{side}_{f_i}", (0.08, 0.14, 0.46), b_piv, collection, mat_ceramic,
                             loc=(side * (0.50 + f_i * 0.22), 0.44, 0.36 + f_off), rot=rads((-18, side * 42, 0)), chamfer=0.008)
            part_chamfer_box(f"{name_prefix}_DockedFunnelGold_{side}_{f_i}", (0.09, 0.15, 0.10), b_piv, collection, mat_gold,
                             loc=(side * (0.50 + f_i * 0.22), 0.44, 0.36 + f_off), rot=rads((-18, side * 42, 0)), chamfer=0.006)
            part_chamfer_box(f"{name_prefix}_DockedFunnelTip_{side}_{f_i}", (0.06, 0.10, 0.08), b_piv, collection, mat_cyan,
                             loc=(side * (0.50 + f_i * 0.22), 0.44, 0.12 + f_off), rot=rads((-18, side * 42, 0)), chamfer=0.004)

        # Lower Sub-Wing Stabilizer Blade (Sharp Angular Wedge)
        part_chamfer_wedge(f"{name_prefix}_BinderLower_{side}", (0.18, 0.36), (0.06, 0.14), 1.55, b_piv, collection, mat_cobalt,
                           loc=(side * 0.48, 0.28, -0.40), rot=rads((22, side * 54, side * 12)), chamfer=0.014)
        part_chamfer_box(f"{name_prefix}_BinderVeinL_{side}", (0.03, 0.05, 1.25), b_piv, collection, mat_cyan,
                         loc=(side * 0.48, 0.18, -0.40), rot=rads((22, side * 54, side * 12)), chamfer=0.004)
        # Octagonal Vernier Thruster Bell & Cyan Core
        part_cyl(f"{name_prefix}_VernierBell_{side}", 0.14, 0.09, 0.26, b_piv, collection, mat_frame,
                 loc=(side * 0.18, 0.18, -0.10), rot=rads((55, side * 18, 0)), segs=8, smooth=False)
        part_cyl(f"{name_prefix}_VernierCore_{side}", 0.09, 0.05, 0.12, b_piv, collection, mat_cyan,
                 loc=(side * 0.22, 0.26, -0.16), rot=rads((55, side * 18, 0)), segs=8, smooth=False)

    # 4. ANGULAR GUNDAM HEAD: FACETED HELMET, CHEEK GUARDS, FACEPLATE VENTS, CRIMSON CHIN, CAMERA CREST & 4-BLADE V-FIN
    # Inner Dark Mechanical Head Core & Eye Socket Block
    part_chamfer_box(f"{name_prefix}_HeadInnerBlock", (0.34, 0.38, 0.36), head, collection, mat_frame,
                     loc=(0.0, -0.02, 0.28), chamfer=0.015)
    # Angular White Faceplate Mask + Crimson Chin Goatee
    part_chamfer_wedge(f"{name_prefix}_FaceMaskWhite", (0.20, 0.18), (0.24, 0.22), 0.18, head, collection, mat_ceramic,
                       loc=(0.0, -0.20, 0.17), rot=rads((8, 0, 0)), chamfer=0.010)
    part_chamfer_wedge(f"{name_prefix}_CrimsonChin", (0.08, 0.10), (0.11, 0.12), 0.10, head, collection, mat_crimson,
                       loc=(0.0, -0.26, 0.07), rot=rads((6, 0, 0)), chamfer=0.006)
    # Angular Main Helmet Sides, Crown & Rear Overhang (Hard-Surface Faceted Wedges!)
    part_chamfer_wedge(f"{name_prefix}_HelmetMainCrown", (0.46, 0.54), (0.38, 0.48), 0.32, head, collection, mat_ceramic,
                       loc=(0.0, 0.02, 0.38), chamfer=0.018, top_offset=(0.0, 0.04))
    part_chamfer_wedge(f"{name_prefix}_HelmetRearSkirt", (0.48, 0.26), (0.42, 0.22), 0.22, head, collection, mat_ceramic,
                       loc=(0.0, 0.18, 0.18), rot=rads((-16, 0, 0)), chamfer=0.014)
    # Raised Central Forehead/Crown Camera Ridge + Glowing Cyan Front/Rear Main Cameras
    part_chamfer_wedge(f"{name_prefix}_HelmetCameraCrest", (0.14, 0.56), (0.10, 0.46), 0.16, head, collection, mat_ceramic,
                       loc=(0.0, 0.02, 0.56), chamfer=0.012)
    part_chamfer_box(f"{name_prefix}_MainCamFrontCyan", (0.08, 0.06, 0.09), head, collection, mat_cyan,
                     loc=(0.0, -0.23, 0.56), rot=rads((14, 0, 0)), chamfer=0.004)
    part_chamfer_box(f"{name_prefix}_MainCamRearCyan", (0.08, 0.06, 0.07), head, collection, mat_cyan,
                     loc=(0.0, 0.26, 0.55), rot=rads((-14, 0, 0)), chamfer=0.004)

    # Crimson Pentagonal V-Fin Forehead Crest Mount + Cyan Sensor Jewel
    part_chamfer_wedge(f"{name_prefix}_VFinMountCrimson", (0.10, 0.10), (0.07, 0.08), 0.14, head, collection, mat_crimson,
                       loc=(0.0, -0.28, 0.40), rot=rads((18, 0, 0)), chamfer=0.006)
    part_chamfer_box(f"{name_prefix}_VFinJewelCyan", (0.05, 0.05, 0.06), head, collection, mat_cyan,
                     loc=(0.0, -0.31, 0.42), rot=rads((18, 0, 0)), chamfer=0.004)

    for side in [-1.0, 1.0]:
        # Sharp Angular Cheek Guards & Side Vulcan Pods
        part_chamfer_wedge(f"{name_prefix}_CheekGuard_{side}", (0.10, 0.28), (0.08, 0.24), 0.24, head, collection, mat_ceramic,
                           loc=(side * 0.21, -0.10, 0.18), rot=rads((10, side * -12, side * 14)), chamfer=0.010)
        part_chamfer_box(f"{name_prefix}_CheekVentGray_{side}", (0.04, 0.12, 0.10), head, collection, mat_frame,
                         loc=(side * 0.24, -0.14, 0.18), rot=rads((10, side * -12, side * 14)), chamfer=0.005)
        part_cyl(f"{name_prefix}_HeadVulcan_{side}", 0.022, 0.018, 0.10, head, collection, mat_gold,
                 loc=(side * 0.19, -0.16, 0.42), rot=rads((90, 0, 0)), segs=8, smooth=False)
        # Dual Angular Glowing Cyan Gundam Eyes
        part_chamfer_box(f"{name_prefix}_VisorEye_{side}", (0.13, 0.05, 0.042), head, collection, mat_cyan,
                         loc=(side * 0.075, -0.23, 0.29), rot=rads((6, side * -14, side * 18)), chamfer=0.004)
        # Primary Razor-Sharp Golden V-Fin Blade + Tip Flag
        part_chamfer_wedge(f"{name_prefix}_GoldVFinBlade_{side}", (0.05, 0.06), (0.014, 0.022), 0.62, head, collection, mat_gold,
                           loc=(side * 0.23, -0.30, 0.56), rot=rads((16, side * 46, side * -12)), chamfer=0.004)
        # Secondary Swept White V-Fin Blade
        part_chamfer_wedge(f"{name_prefix}_WhiteSubVFin_{side}", (0.038, 0.048), (0.012, 0.018), 0.44, head, collection, mat_ceramic,
                           loc=(side * 0.16, -0.25, 0.54), rot=rads((12, side * 30, side * -8)), chamfer=0.004)

    # 5. BOXY LAYERED GUNDAM SHOULDER PAULDRONS, MECHANICAL ARMS, HEX SHIELD (L) & BEAM LANCE (R)
    for side, sh_piv, el_piv in [(-1.0, sh_L, el_L), (1.0, sh_R, el_R)]:
        # Massive Layered Angular Shoulder Pauldron Armor (Freedom / Nu Gundam style!)
        part_chamfer_wedge(f"{name_prefix}_PauldronCore_{side}", (0.58, 0.62), (0.48, 0.52), 0.46, sh_piv, collection, mat_ceramic,
                           loc=(side * 0.14, 0.0, 0.08), rot=rads((0, side * -16, 0)), chamfer=0.020)
        # Sloped Cobalt Blue Upper Shoulder Cap + Sensor Fin
        part_chamfer_wedge(f"{name_prefix}_PauldronCobaltTop_{side}", (0.46, 0.52), (0.32, 0.40), 0.20, sh_piv, collection, mat_cobalt,
                           loc=(side * 0.10, 0.0, 0.32), rot=rads((0, side * -20, 0)), chamfer=0.016)
        part_chamfer_wedge(f"{name_prefix}_PauldronTopFin_{side}", (0.08, 0.34), (0.04, 0.20), 0.24, sh_piv, collection, mat_ceramic,
                           loc=(side * 0.04, 0.02, 0.46), rot=rads((0, side * -28, 0)), chamfer=0.008)
        # Swept Outer Winglet Armor Flap + Crimson Inner Trim + Rectangular Vernier Thruster Pod
        part_chamfer_wedge(f"{name_prefix}_PauldronOuterWing_{side}", (0.48, 0.56), (0.16, 0.28), 0.68, sh_piv, collection, mat_ceramic,
                           loc=(side * 0.48, 0.02, 0.14), rot=rads((0, side * -58, 0)), chamfer=0.016)
        part_chamfer_wedge(f"{name_prefix}_PauldronCrimsonTrim_{side}", (0.38, 0.46), (0.14, 0.24), 0.52, sh_piv, collection, mat_crimson,
                           loc=(side * 0.45, 0.02, 0.06), rot=rads((0, side * -58, 0)), chamfer=0.012)
        part_chamfer_box(f"{name_prefix}_PauldronVernierBox_{side}", (0.16, 0.28, 0.18), sh_piv, collection, mat_frame,
                         loc=(side * 0.36, 0.02, -0.08), rot=rads((0, side * -32, 0)), chamfer=0.010)
        part_chamfer_box(f"{name_prefix}_PauldronGlowCyan_{side}", (0.08, 0.18, 0.08), sh_piv, collection, mat_cyan,
                         loc=(side * 0.42, 0.02, -0.14), rot=rads((0, side * -32, 0)), chamfer=0.004)

        # Mechanical Shoulder Block, Boxy Bicep Armor & Double-Jointed Elbow Frame
        part_chamfer_box(f"{name_prefix}_ShoulderJointBlock_{side}", (0.26, 0.28, 0.26), sh_piv, collection, mat_frame,
                         loc=(0.0, 0.0, -0.04), chamfer=0.016)
        part_chamfer_wedge(f"{name_prefix}_BicepArmor_{side}", (0.28, 0.30), (0.32, 0.34), 0.48, sh_piv, collection, mat_ceramic,
                           loc=(side * 0.08, 0.0, -0.36), rot=rads((0, side * -8, 0)), chamfer=0.016)
        part_chamfer_box(f"{name_prefix}_BicepGoldBand_{side}", (0.31, 0.33, 0.06), sh_piv, collection, mat_gold,
                         loc=(side * 0.10, 0.0, -0.52), rot=rads((0, side * -8, 0)), chamfer=0.006)

        # Mechanical Elbow Hinge Block + Side Drum Capacitors
        part_chamfer_box(f"{name_prefix}_ElbowJointBlock_{side}", (0.22, 0.28, 0.24), el_piv, collection, mat_frame,
                         loc=(0.0, 0.0, 0.0), chamfer=0.014)
        part_cyl(f"{name_prefix}_ElbowDrum_{side}", 0.11, 0.11, 0.26, el_piv, collection, mat_frame,
                 loc=(0.0, 0.0, 0.0), rot=rads((0, 90, 0)), segs=8, smooth=False)

        # Heavy Boxy Gundam Forearm Vambrace + Cobalt Blue Outer Guard + Wrist Cuff
        part_chamfer_wedge(f"{name_prefix}_ForearmMain_{side}", (0.24, 0.28), (0.34, 0.38), 0.66, el_piv, collection, mat_ceramic,
                           loc=(side * 0.06, -0.06, -0.42), rot=rads((8, side * -4, 0)), chamfer=0.018)
        part_chamfer_wedge(f"{name_prefix}_ForearmCobaltGuard_{side}", (0.12, 0.22), (0.16, 0.30), 0.52, el_piv, collection, mat_cobalt,
                           loc=(side * 0.18, -0.06, -0.40), rot=rads((8, side * -4, 0)), chamfer=0.012)
        part_chamfer_box(f"{name_prefix}_WristCuffCrimson_{side}", (0.26, 0.28, 0.10), el_piv, collection, mat_crimson,
                         loc=(side * 0.08, -0.10, -0.74), rot=rads((8, 0, 0)), chamfer=0.010)
        # Angular Mechanical Manipulator Hand + White Backhand Plate
        part_chamfer_box(f"{name_prefix}_HandBlock_{side}", (0.16, 0.20, 0.20), el_piv, collection, mat_frame,
                         loc=(side * 0.09, -0.14, -0.88), rot=rads((14, 0, 0)), chamfer=0.012)
        part_chamfer_box(f"{name_prefix}_HandArmorWhite_{side}", (0.17, 0.10, 0.16), el_piv, collection, mat_ceramic,
                         loc=(side * 0.12, -0.14, -0.87), rot=rads((14, 0, 0)), chamfer=0.008)

    # Left Forearm Angular Hexagonal Gundam Shield (Multi-Layered Faceted Armor)
    part_chamfer_wedge(f"{name_prefix}_ShieldOuterWhite", (0.12, 0.68), (0.08, 0.44), 1.68, el_L, collection, mat_ceramic,
                       loc=(-0.28, -0.10, -0.44), rot=rads((10, -14, 15)), chamfer=0.018)
    part_chamfer_wedge(f"{name_prefix}_ShieldInnerCobalt", (0.10, 0.52), (0.06, 0.34), 1.32, el_L, collection, mat_cobalt,
                       loc=(-0.32, -0.10, -0.42), rot=rads((10, -14, 15)), chamfer=0.014)
    part_chamfer_wedge(f"{name_prefix}_ShieldTopCrownCrimson", (0.12, 0.56), (0.10, 0.42), 0.34, el_L, collection, mat_crimson,
                       loc=(-0.31, -0.04, 0.22), rot=rads((10, -14, 15)), chamfer=0.012)
    part_chamfer_box(f"{name_prefix}_ShieldGoldCrossV", (0.06, 0.10, 0.68), el_L, collection, mat_gold,
                     loc=(-0.35, -0.12, -0.34), rot=rads((10, -14, 15)), chamfer=0.006)
    part_chamfer_box(f"{name_prefix}_ShieldGoldCrossH", (0.06, 0.36, 0.12), el_L, collection, mat_gold,
                     loc=(-0.35, -0.12, -0.24), rot=rads((10, -14, 15)), chamfer=0.006)
    part_chamfer_box(f"{name_prefix}_ShieldCyanSensor", (0.06, 0.16, 0.16), el_L, collection, mat_cyan,
                     loc=(-0.37, -0.12, -0.24), rot=rads((10, -14, 15)), chamfer=0.006)

    # Right Hand Hard-Surface Mechanical Beam Lance / Halberd (Angular Housing + Diamond Beam Blade)
    part_cyl(f"{name_prefix}_LanceShaft", 0.042, 0.040, 2.45, el_R, collection, mat_frame,
             loc=(0.12, -0.18, -1.10), rot=rads((-18, 0, 0)), segs=8, smooth=False)
    part_chamfer_wedge(f"{name_prefix}_LanceAcceleratorHousing", (0.22, 0.34), (0.14, 0.22), 0.52, el_R, collection, mat_cobalt,
                       loc=(0.12, -0.52, -2.10), rot=rads((162, 0, 0)), chamfer=0.014)
    part_chamfer_box(f"{name_prefix}_LanceWhiteCollar", (0.26, 0.38, 0.18), el_R, collection, mat_ceramic,
                     loc=(0.12, -0.46, -1.94), rot=rads((-18, 0, 0)), chamfer=0.012)
    part_chamfer_box(f"{name_prefix}_LanceGoldRing", (0.28, 0.42, 0.08), el_R, collection, mat_gold,
                     loc=(0.12, -0.58, -2.28), rot=rads((-18, 0, 0)), chamfer=0.008)
    part_chamfer_wedge(f"{name_prefix}_LanceBeamBlade", (0.06, 0.28), (0.01, 0.02), 2.35, el_R, collection, mat_cyan,
                       loc=(0.12, -0.96, -3.42), rot=rads((162, 0, 0)), chamfer=0.004)

    # 6. BLOCKY GUNDAM LEGS: LAYERED THIGH PLATES, PROTRUDING KNEE SPIKE BLOCK, FLARED SHIN GREAVES, ANKLE GUARD & BLOCKY FEET
    for side, hip_piv, kn_piv, ank_piv in [(-1.0, hip_L, kn_L, ank_L), (1.0, hip_R, kn_R, ank_R)]:
        # Mechanical Hip Joint & Inner Thigh Frame
        part_chamfer_box(f"{name_prefix}_ThighInnerFrame_{side}", (0.28, 0.34, 0.96), hip_piv, collection, mat_frame,
                         loc=(0.0, 0.0, -0.46), chamfer=0.018)
        # Layered Rectangular/Wedge White Thigh Armor Plates + Psycho-Frame Slits
        part_chamfer_wedge(f"{name_prefix}_ThighMainArmor_{side}", (0.34, 0.42), (0.42, 0.52), 0.84, hip_piv, collection, mat_ceramic,
                           loc=(side * 0.02, -0.02, -0.44), chamfer=0.020)
        part_chamfer_wedge(f"{name_prefix}_ThighFrontPlate_{side}", (0.24, 0.16), (0.30, 0.20), 0.72, hip_piv, collection, mat_ceramic,
                           loc=(side * 0.02, -0.22, -0.44), chamfer=0.014)
        part_chamfer_box(f"{name_prefix}_ThighSidePlate_{side}", (0.12, 0.34, 0.68), hip_piv, collection, mat_ceramic,
                         loc=(side * 0.22, 0.0, -0.42), chamfer=0.014)
        part_chamfer_box(f"{name_prefix}_ThighCyanSlit_{side}", (0.18, 0.06, 0.58), hip_piv, collection, mat_cyan,
                         loc=(side * 0.02, -0.26, -0.44), chamfer=0.004)

        # Mechanical Double-Jointed Knee Block + Tall Protruding Gundam Knee Armor Spike!
        part_chamfer_box(f"{name_prefix}_KneeJointFrame_{side}", (0.28, 0.34, 0.30), kn_piv, collection, mat_frame,
                         loc=(0.0, 0.0, 0.0), chamfer=0.016)
        part_chamfer_wedge(f"{name_prefix}_KneeArmorCobalt_{side}", (0.26, 0.26), (0.32, 0.32), 0.46, kn_piv, collection, mat_cobalt,
                           loc=(0.0, -0.22, -0.04), rot=rads((-10, 0, 0)), chamfer=0.016)
        part_chamfer_wedge(f"{name_prefix}_KneeSpikeTopWhite_{side}", (0.22, 0.22), (0.14, 0.14), 0.28, kn_piv, collection, mat_ceramic,
                           loc=(0.0, -0.26, 0.22), rot=rads((14, 0, 0)), chamfer=0.012)
        part_chamfer_box(f"{name_prefix}_KneeVentGold_{side}", (0.16, 0.08, 0.10), kn_piv, collection, mat_gold,
                         loc=(0.0, -0.34, 0.08), rot=rads((-10, 0, 0)), chamfer=0.006)

        # Flared Angular Gundam Shin Greaves, Side Flare Plates & Rear Calf Thruster Pods
        part_chamfer_wedge(f"{name_prefix}_ShinMainBlock_{side}", (0.38, 0.48), (0.34, 0.42), 0.92, kn_piv, collection, mat_ceramic,
                           loc=(side * 0.02, 0.02, -0.52), chamfer=0.020)
        part_chamfer_wedge(f"{name_prefix}_ShinFrontRidge_{side}", (0.24, 0.24), (0.28, 0.22), 0.80, kn_piv, collection, mat_ceramic,
                           loc=(side * 0.02, -0.18, -0.54), rot=rads((-4, 0, 0)), chamfer=0.016)
        part_chamfer_wedge(f"{name_prefix}_ShinOuterFlare_{side}", (0.18, 0.44), (0.12, 0.34), 0.78, kn_piv, collection, mat_ceramic,
                           loc=(side * 0.22, 0.02, -0.56), rot=rads((0, side * 8, 0)), chamfer=0.016)
        # Rear Calf Vernier Thruster Pod
        part_chamfer_wedge(f"{name_prefix}_CalfPodCobalt_{side}", (0.26, 0.28), (0.32, 0.34), 0.56, kn_piv, collection, mat_cobalt,
                           loc=(side * 0.02, 0.24, -0.44), rot=rads((18, 0, 0)), chamfer=0.014)
        part_cyl(f"{name_prefix}_CalfNozzle_{side}", 0.08, 0.055, 0.18, kn_piv, collection, mat_frame,
                 loc=(side * 0.02, 0.34, -0.68), rot=rads((38, 0, 0)), segs=8, smooth=False)
        part_cyl(f"{name_prefix}_CalfCore_{side}", 0.055, 0.035, 0.08, kn_piv, collection, mat_cyan,
                 loc=(side * 0.02, 0.38, -0.74), rot=rads((38, 0, 0)), segs=8, smooth=False)

        # Floating Angular Gundam Ankle Guard Armor + Side Ankle Pistons
        part_chamfer_wedge(f"{name_prefix}_AnkleGuardWhite_{side}", (0.38, 0.36), (0.32, 0.28), 0.24, ank_piv, collection, mat_ceramic,
                           loc=(0.0, -0.08, 0.08), rot=rads((14, 0, 0)), chamfer=0.014)
        part_chamfer_box(f"{name_prefix}_AnkleGuardCobalt_{side}", (0.24, 0.14, 0.14), ank_piv, collection, mat_cobalt,
                         loc=(0.0, -0.22, 0.08), rot=rads((14, 0, 0)), chamfer=0.010)
        # Classic Blocky Gundam Foot: Angular Cobalt Blue Toe Box + Crimson Platform Sole & Heel Block
        part_chamfer_wedge(f"{name_prefix}_FootInstepCobalt_{side}", (0.34, 0.52), (0.26, 0.34), 0.18, ank_piv, collection, mat_cobalt,
                           loc=(0.0, -0.14, -0.09), rot=rads((8, 0, 0)), chamfer=0.014, top_offset=(0.0, 0.06))
        part_chamfer_wedge(f"{name_prefix}_FootToeCobalt_{side}", (0.30, 0.36), (0.24, 0.26), 0.14, ank_piv, collection, mat_cobalt,
                           loc=(0.0, -0.34, -0.12), chamfer=0.012, top_offset=(0.0, 0.04))
        part_chamfer_wedge(f"{name_prefix}_BootSoleCrimson_{side}", (0.36, 0.64), (0.32, 0.58), 0.08, ank_piv, collection, mat_crimson,
                           loc=(0.0, -0.18, -0.20), chamfer=0.010)
        part_chamfer_box(f"{name_prefix}_BootHeelCrimson_{side}", (0.32, 0.24, 0.14), ank_piv, collection, mat_crimson,
                         loc=(0.0, 0.18, -0.17), chamfer=0.010)

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

def build_vinculados_carrier_cradle(collection, texture_path, name_prefix="Vinculados_Cradle", scale_factor=1.0):
    root = bpy.data.objects.new(name_prefix, None)
    collection.objects.link(root)

    mat_ceramic = create_pbr_hull_material(f"{name_prefix}_Ceramic", (0.92, 0.95, 1.0, 1.0), metallic=0.25, roughness=0.20, texture_path=texture_path, tex_scale=0.45, bump_strength=0.35, coat=0.75)
    mat_cobalt = create_pbr_hull_material(f"{name_prefix}_Cobalt", (0.04, 0.13, 0.44, 1.0), metallic=0.52, roughness=0.24, texture_path=texture_path, tex_scale=0.50, bump_strength=0.25, tex_color_mix=0.06)
    mat_frame = create_pbr_hull_material(f"{name_prefix}_Frame", (0.10, 0.12, 0.18, 1.0), metallic=0.78, roughness=0.34)
    mat_gold = create_pbr_hull_material(f"{name_prefix}_Gold", (0.98, 0.78, 0.15, 1.0), metallic=0.92, roughness=0.18)
    mat_amber = create_emissive_material(f"{name_prefix}_Amber", (1.0, 0.65, 0.10, 1.0), strength=8.5)
    mat_cyan = create_emissive_material(f"{name_prefix}_Cyan", (0.10, 0.92, 1.0, 1.0), strength=11.0)
    mat_soul = create_emissive_material(f"{name_prefix}_SoulCore", (1.0, 0.14, 0.86, 1.0), strength=15.0)
    mat_plume = create_emissive_material(f"{name_prefix}_Plume", (0.12, 0.90, 1.0, 0.82), strength=12.0, alpha=0.82)

    part_box(f"{name_prefix}_CentralHull", (3.2, 10.5, 1.35), root, collection, mat_ceramic, loc=(0, -0.3, 0.12), bevel=0.05)
    part_box(f"{name_prefix}_CobaltKeel", (1.8, 12.6, 0.85), root, collection, mat_cobalt, loc=(0, 0.0, -0.55), bevel=0.04)

    part_cyl(f"{name_prefix}_CoreCollar", 1.05, 1.15, 0.45, root, collection, mat_frame, loc=(0, 0.6, 0.85), segs=16)
    part_cyl(f"{name_prefix}_CoreGoldRing", 1.22, 1.22, 0.12, root, collection, mat_gold, loc=(0, 0.6, 1.02), segs=18)
    part_sphere(f"{name_prefix}_SoulCoreOrb", 0.82, root, collection, mat_soul, loc=(0, 0.6, 0.92), subdiv=3)

    part_taper_box(f"{name_prefix}_BridgePylon", (1.45, 3.8), (1.15, 3.0), 1.75, root, collection, mat_ceramic,
                   loc=(0, -1.2, 1.55), rot=rads((6, 0, 0)), bevel=0.04)
    part_taper_box(f"{name_prefix}_BridgeCupola", (1.85, 3.2), (1.55, 2.6), 0.82, root, collection, mat_cobalt,
                   loc=(0, -0.9, 2.52), bevel=0.03)
    part_box(f"{name_prefix}_BridgeVisor", (1.58, 2.05, 0.22), root, collection, mat_cyan, loc=(0, -0.25, 2.58))
    for side in [-1.0, 1.0]:
        part_box(f"{name_prefix}_BridgeAmber_{side}", (0.38, 0.12, 0.26), root, collection, mat_amber,
                 loc=(side * 0.60, 0.65, 2.52))
        part_taper_box(f"{name_prefix}_BridgeVFin_{side}", (0.14, 0.75), (0.04, 0.30), 2.05, root, collection, mat_gold,
                       loc=(side * 0.78, -1.1, 3.65), rot=rads((22, side * 28, side * -14)), bevel=0.01)

    for side in [-1.0, 1.0]:
        hx = side * 2.45
        part_box(f"{name_prefix}_CatDeck_{side}", (1.95, 8.8, 1.32), root, collection, mat_ceramic, loc=(hx, 2.8, 0.0), bevel=0.05)
        part_taper_box(f"{name_prefix}_CatProw_{side}", (1.95, 1.30), (1.15, 0.35), 2.8, root, collection, mat_ceramic,
                       loc=(hx, 8.4, -0.02), rot=rads((-90, 0, 0)), bevel=0.04)
        part_box(f"{name_prefix}_CatTrack_{side}", (0.48, 8.0, 0.08), root, collection, mat_cyan, loc=(hx, 3.1, 0.68))
        part_taper_box(f"{name_prefix}_SponWing_{side}", (2.4, 5.2), (0.85, 2.8), 0.20, root, collection, mat_ceramic,
                       loc=(side * 4.35, 1.6, -0.12), rot=rads((0, side * -15, 0)), bevel=0.02)
        part_taper_box(f"{name_prefix}_SponBlue_{side}", (1.8, 4.2), (0.65, 2.2), 0.24, root, collection, mat_cobalt,
                       loc=(side * 4.05, 1.6, -0.10), rot=rads((0, side * -15, 0)), bevel=0.02)
        part_box(f"{name_prefix}_AftNacelle_{side}", (1.95, 5.8, 1.25), root, collection, mat_ceramic, loc=(hx, -4.8, 0.0), bevel=0.04)
        part_box(f"{name_prefix}_AftTopBlue_{side}", (1.65, 5.0, 0.28), root, collection, mat_cobalt, loc=(hx, -4.8, 0.66), bevel=0.02)
        for vz in [-0.28, 0.28]:
            part_cyl(f"{name_prefix}_AftBell_{side}_{vz}", 0.54, 0.44, 1.4, root, collection, mat_frame,
                     loc=(hx, -7.8, vz), rot=(math.radians(90), 0, 0), segs=16)
            part_cyl(f"{name_prefix}_AftPlume_{side}_{vz}", 0.46, 0.05, 3.2, root, collection, mat_plume,
                     loc=(hx, -9.6, vz), rot=(math.radians(90), 0, 0), segs=14)

    root.scale = (scale_factor, scale_factor, scale_factor)
    return root

# -------------------------------------------------------------------------
# 4. THE FREE TIDE — EL SOBERANO VOID GALLEON (Mahogany, Brass, Domes & Oars)
# -------------------------------------------------------------------------
def create_billowing_sail(name, width, height, billow_depth, parent, col, mat, loc=(0,0,0), rot=(0,0,0)):
    bm = bmesh.new()
    nx, nz = 16, 16
    grid = []
    for iz in range(nz + 1):
        v_frac = iz / nz
        taper = 1.0 - 0.16 * v_frac
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

    mat_wood = create_pbr_hull_material(
        f"{name_prefix}_Mahogany", (0.20, 0.09, 0.04, 1.0),
        metallic=0.10, roughness=0.44, texture_path=texture_path, tex_scale=0.36, bump_strength=0.46, tex_color_mix=0.22
    )
    mat_brass = create_pbr_hull_material(f"{name_prefix}_PolishedBrass", (0.95, 0.68, 0.20, 1.0), metallic=0.92, roughness=0.20, tex_color_mix=0.0)
    mat_dome = create_emissive_material(f"{name_prefix}_AmberDome", (0.98, 0.56, 0.14, 0.52), strength=1.4, alpha=0.52)
    mat_sail = create_quantum_sail_material(f"{name_prefix}_QuantumSail")
    mat_oar_blade = create_emissive_material(f"{name_prefix}_OarBlade", (0.06, 0.86, 1.0, 0.85), strength=4.8, alpha=0.85)
    mat_lantern = create_emissive_material(f"{name_prefix}_Lantern", (1.0, 0.58, 0.06, 1.0), strength=9.0)

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
        rib_st = [(y_r + 0.11, sc_x, sc_z, oz), (y_r - 0.11, sc_x, sc_z, oz)]
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

    # Translucent Pressurized Amber-Glass & Brass Greenhouse Deck Domes
    part_sphere(f"{name_prefix}_ForeDeckDome", 0.72, root, collection, mat_dome, loc=(0, 1.8, 0.92), scale=(0.95, 1.45, 0.48), subdiv=2)
    part_sphere(f"{name_prefix}_AftBridgeDome", 0.64, root, collection, mat_dome, loc=(0, -4.6, 2.08), scale=(0.95, 1.25, 0.46), subdiv=2)

    part_cyl(f"{name_prefix}_BowspritMain", 0.15, 0.05, 5.6, root, collection, mat_brass,
             loc=(0, 8.2, 1.45), rot=(math.radians(-72), 0, 0), segs=16)
    part_cyl(f"{name_prefix}_BowspritSub", 0.10, 0.04, 4.4, root, collection, mat_brass,
             loc=(0, 7.6, 1.05), rot=(math.radians(-78), 0, 0), segs=14)

    oar_pivots = []
    for side in [-1.0, 1.0]:
        for i in range(6):
            py = -3.0 + i * 1.15
            hull_w = 1.44 * (1.0 - 0.015 * py * py)
            part_cyl(f"{name_prefix}_PortRim_{side}_{i}", 0.22, 0.22, 0.15, root, collection, mat_brass,
                     loc=(side * hull_w, py, 0.38), rot=(0, math.radians(90), 0), segs=16)
            part_sphere(f"{name_prefix}_PortGlow_{side}_{i}", 0.15, root, collection, mat_lantern,
                        loc=(side * (hull_w + 0.04), py, 0.38))

        for i in range(5 if not is_raider else 4):
            oy = -2.4 + i * 1.15
            oar_piv = make_pivot(f"{name_prefix}_OarPiv_{side}_{i}", root, collection,
                                 loc=(side * 1.25, oy, -0.05), rot=(math.radians(-18), math.radians(side * 54), 0))
            part_cyl(f"{name_prefix}_OarShaft_{side}_{i}", 0.055, 0.042, 2.6, oar_piv, collection, mat_brass,
                     loc=(0, 0, -1.3), segs=12)
            part_cyl(f"{name_prefix}_OarKnuckle_{side}_{i}", 0.08, 0.08, 0.16, oar_piv, collection, mat_brass,
                     loc=(0, 0, -1.4), segs=12)
            part_box(f"{name_prefix}_OarVane_{side}_{i}", (0.30, 0.04, 1.50), oar_piv, collection, mat_oar_blade,
                     loc=(0, 0, -2.95), bevel=0.01)
            oar_pivots.append((oar_piv, side, i))

        wing_piv = make_pivot(f"{name_prefix}_WingPiv_{side}", root, collection,
                              loc=(side * 1.35, 0.2, 0.95), rot=(0, math.radians(side * -14), 0))
        for sy in [-1.8, -0.2, 1.4]:
            part_cyl(f"{name_prefix}_Outrigger_{side}_{sy}", 0.08, 0.03, 4.6, wing_piv, collection, mat_brass,
                     loc=(side * 2.3, sy, 0.0), rot=(0, math.radians(90), 0), segs=14)
        create_billowing_sail(f"{name_prefix}_WingSail_{side}", 3.2, 4.0, 0.45, wing_piv, collection, mat_sail,
                              loc=(side * 2.4, -0.2, 0.0), rot=(math.radians(90), 0, math.radians(side * 90)))

    for sx in [-0.45, 0.0, 0.45]:
        part_sphere(f"{name_prefix}_SternWin_{sx}", 0.17, root, collection, mat_lantern, loc=(sx, -6.55, 1.65))

    mast_configs = [(2.6, 6.6, 4.6, 4.1), (-0.4, 8.0, 5.4, 4.9), (-3.4, 6.2, 4.2, 3.7)] if not is_raider else [(0.8, 6.4, 4.4, 4.0), (-2.4, 5.6, 3.8, 3.4)]
    for idx, (my, mh, sw, sh) in enumerate(mast_configs):
        part_cyl(f"{name_prefix}_Mast_{idx}", 0.17, 0.09, mh, root, collection, mat_brass,
                 loc=(0, my, mh * 0.5 + 0.6), rot=(math.radians(-5), 0, 0), segs=16)
        part_cyl(f"{name_prefix}_YardTop_{idx}", 0.09, 0.05, sw * 1.05, root, collection, mat_brass,
                 loc=(0, my - 0.15, mh * 0.88), rot=(0, math.radians(90), 0), segs=14)
        part_cyl(f"{name_prefix}_YardBot_{idx}", 0.08, 0.05, sw * 1.12, root, collection, mat_brass,
                 loc=(0, my + 0.1, mh * 0.25), rot=(0, math.radians(90), 0), segs=14)
        for side in [-1.0, 1.0]:
            part_cyl(f"{name_prefix}_DiagSpar_{idx}_{side}", 0.05, 0.03, sw * 0.65, root, collection, mat_brass,
                     loc=(side * sw * 0.24, my + 0.15, mh * 0.56), rot=rads((0, side * 48, 0)), segs=10)
        create_billowing_sail(f"{name_prefix}_MainSail_{idx}", sw, sh, 1.15, root, collection, mat_sail,
                              loc=(0, my + 0.48, mh * 0.56))

    root.scale = (scale_factor, scale_factor, scale_factor)
    return root, oar_pivots
