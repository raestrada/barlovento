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

# -------------------------------------------------------------------------
# 3. THE VINCULADOS — SCULPTED SUBSURF-2 SERAPH-PRIME COLOSSAL MOBILE ARMOR & CARRIER CRADLE
# -------------------------------------------------------------------------
def build_vinculados_colossus(collection, texture_path, name_prefix="Seraph_Prime", scale_factor=1.0, is_wingman=False):
    subsurf_lvl = 1 if is_wingman else 2
    root = bpy.data.objects.new(name_prefix, None)
    collection.objects.link(root)

    torso = make_pivot(f"{name_prefix}_TorsoPiv", root, collection, loc=(0.0, 0.0, 1.58))
    head = make_pivot(f"{name_prefix}_HeadPiv", torso, collection, loc=(0.0, 0.0, 1.40))
    binder_L = make_pivot(f"{name_prefix}_BinderPiv_L", torso, collection, loc=(-0.38, 0.44, 1.05))
    binder_R = make_pivot(f"{name_prefix}_BinderPiv_R", torso, collection, loc=( 0.38, 0.44, 1.05))
    sh_L = make_pivot(f"{name_prefix}_ShoulderPiv_L", torso, collection, loc=(-0.74, 0.02, 0.98))
    sh_R = make_pivot(f"{name_prefix}_ShoulderPiv_R", torso, collection, loc=( 0.74, 0.02, 0.98))
    el_L = make_pivot(f"{name_prefix}_ElbowPiv_L", sh_L, collection, loc=(-0.18, 0.02, -0.66))
    el_R = make_pivot(f"{name_prefix}_ElbowPiv_R", sh_R, collection, loc=( 0.18, 0.02, -0.66))
    hip_L = make_pivot(f"{name_prefix}_HipPiv_L", root, collection, loc=(-0.40, 0.0, 1.18))
    hip_R = make_pivot(f"{name_prefix}_HipPiv_R", root, collection, loc=( 0.40, 0.0, 1.18))
    kn_L = make_pivot(f"{name_prefix}_KneePiv_L", hip_L, collection, loc=(-0.02, 0.0, -0.98))
    kn_R = make_pivot(f"{name_prefix}_KneePiv_R", hip_R, collection, loc=( 0.02, 0.0, -0.98))
    ank_L = make_pivot(f"{name_prefix}_AnklePiv_L", kn_L, collection, loc=(-0.04, 0.02, -1.04))
    ank_R = make_pivot(f"{name_prefix}_AnklePiv_R", kn_R, collection, loc=( 0.04, 0.02, -1.04))

    # Canonical Vinculados Gundam Materials (High-Contrast Cobalt Blue, Pearl White, Crimson, Gold & Magenta Soul Core!)
    mat_ceramic = create_pbr_hull_material(
        f"{name_prefix}_CeramicWhite", (0.92, 0.95, 1.0, 1.0),
        metallic=0.24, roughness=0.18, texture_path=texture_path, tex_scale=0.65, bump_strength=0.22, coat=0.88, tex_color_mix=0.22
    )
    mat_cobalt = create_pbr_hull_material(
        f"{name_prefix}_CobaltBlue", (0.04, 0.13, 0.44, 1.0),
        metallic=0.52, roughness=0.22, texture_path=texture_path, tex_scale=0.65, bump_strength=0.22, coat=0.75, tex_color_mix=0.06
    )
    mat_crimson = create_pbr_hull_material(
        f"{name_prefix}_CrimsonRed", (0.82, 0.10, 0.14, 1.0),
        metallic=0.38, roughness=0.24, coat=0.65, tex_color_mix=0.0
    )
    mat_gold = create_pbr_hull_material(
        f"{name_prefix}_GoldCrest", (0.98, 0.78, 0.15, 1.0),
        metallic=0.92, roughness=0.16, emission_col=(0.95, 0.70, 0.10, 1.0), emission_str=0.65
    )
    mat_sinew = create_ribbed_sinew_material(f"{name_prefix}_DarkFrame")
    mat_amber = create_emissive_material(f"{name_prefix}_AmberIntake", (1.0, 0.65, 0.06, 1.0), strength=10.5)
    mat_core = create_emissive_material(f"{name_prefix}_SoulCore", (1.0, 0.15, 0.88, 1.0), strength=16.0)
    mat_cyan = create_emissive_material(f"{name_prefix}_CyanVisor", (0.06, 0.94, 1.0, 1.0), strength=14.0)
    mat_plume = create_emissive_material(f"{name_prefix}_CyanPlume", (0.08, 0.88, 1.0, 0.80), strength=14.0, alpha=0.80)

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

    # 1. SCULPTED PELVIS, SKIRT ARMOR & SLEEK HIP-MOUNTED MEGA-BUSTER RAIL-CANNONS
    pelvis_stations = [
        (1.00, 0.14, 0.20, 0.0, -0.02),
        (1.20, 0.34, 0.30, 0.0, -0.03),
        (1.42, 0.49, 0.35, 0.0, -0.01),
        (1.56, 0.36, 0.28, 0.0,  0.00),
    ]
    build_vertical_loft(f"{name_prefix}_PelvisArmor", cuirass_prof, pelvis_stations, root, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

    for side in [-1.0, 1.0]:
        part_taper_box(f"{name_prefix}_FrontSkirt_{side}", (0.24, 0.08), (0.20, 0.06), 0.36, root, collection, mat_ceramic,
                       loc=(side * 0.22, -0.30, 1.24), rot=rads((-14, side * 6, 0)), bevel=0.015, smooth=True)
        part_box(f"{name_prefix}_FrontSkirtBlue_{side}", (0.14, 0.04, 0.16), root, collection, mat_cobalt,
                 loc=(side * 0.22, -0.33, 1.25), rot=rads((-14, side * 6, 0)), bevel=0.01)
        part_taper_box(f"{name_prefix}_SideSkirt_{side}", (0.14, 0.36), (0.10, 0.28), 0.38, root, collection, mat_ceramic,
                       loc=(side * 0.50, 0.0, 1.28), rot=rads((0, side * -16, 0)), bevel=0.015, smooth=True)

        # Sleek Hip-Mounted Mega-Buster Rail-Cannons (Strike Freedom style: tucked cleanly along the side hips!)
        if not is_wingman:
            cx = side * 0.64
            part_box(f"{name_prefix}_BusterHousing_{side}", (0.16, 0.95, 0.22), root, collection, mat_cobalt,
                     loc=(cx, -0.15, 1.26), rot=rads((14, 0, side * -5)), bevel=0.015)
            part_cyl(f"{name_prefix}_BusterBarrel_{side}", 0.065, 0.055, 1.95, root, collection, mat_sinew,
                     loc=(cx + side * 0.06, -1.15, 1.02), rot=rads((104, 0, side * -5)), segs=14)
            for r_i in range(3):
                d_step = 0.65 + r_i * 0.38
                part_cyl(f"{name_prefix}_BusterGoldRing_{side}_{r_i}", 0.085, 0.085, 0.06, root, collection, mat_gold,
                         loc=(cx + side * 0.05, -0.35 - d_step, 1.22 - d_step * 0.24), rot=rads((104, 0, side * -5)), segs=14)
            part_cyl(f"{name_prefix}_BusterEmitter_{side}", 0.055, 0.075, 0.24, root, collection, mat_cyan,
                     loc=(cx + side * 0.09, -2.10, 0.78), rot=rads((104, 0, side * -5)), segs=12)

    # 2. SCULPTED TORSO, COBALT BLUE CHEST CUIRASS, DUAL AMBER LOUVERS, CRIMSON COCKPIT & SOUL CORE
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

    # Crimson Cockpit Hatch Block on Center Abdomen
    part_taper_box(f"{name_prefix}_CockpitCrimson", (0.20, 0.16), (0.16, 0.14), 0.34, torso, collection, mat_crimson,
                   loc=(0, -0.35, 0.44), rot=rads((-10, 0, 0)), bevel=0.015, smooth=True)

    # Sculpted Cobalt Blue Upper Pectoral Chest Cuirass!
    chest_stations = [
        (0.64, 0.48, 0.36, 0.0, -0.04),
        (0.80, 0.66, 0.45, 0.0, -0.05),
        (1.06, 0.68, 0.44, 0.0, -0.04),
        (1.24, 0.46, 0.32, 0.0,  0.01),
        (1.30, 0.28, 0.24, 0.0,  0.03),
    ]
    build_vertical_loft(f"{name_prefix}_UpperChestCobalt", cuirass_prof, chest_stations, torso, collection, mat_cobalt, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

    # Dual Classic Gundam Amber Cooling Intake Louvers on Left & Right Pectorals!
    for side in [-1.0, 1.0]:
        part_taper_box(f"{name_prefix}_LouverFrame_{side}", (0.22, 0.08), (0.19, 0.08), 0.16, torso, collection, mat_sinew,
                       loc=(side * 0.34, -0.44, 0.88), rot=rads((-10, side * 14, side * -12)), bevel=0.01)
        part_box(f"{name_prefix}_AmberLouver_{side}", (0.18, 0.06, 0.12), torso, collection, mat_amber,
                 loc=(side * 0.34, -0.47, 0.88), rot=rads((-10, side * 14, side * -12)))

    # Central Exposed Pulsing Magenta Soul Core + Golden Magnetic Accelerator Ring!
    part_cyl(f"{name_prefix}_CoreFrame", 0.21, 0.18, 0.08, torso, collection, mat_sinew,
             loc=(0, -0.43, 0.88), rot=(math.radians(90), 0, 0), segs=12, smooth=False)
    part_cyl(f"{name_prefix}_CoreGoldRing", 0.17, 0.15, 0.09, torso, collection, mat_gold,
             loc=(0, -0.45, 0.88), rot=(math.radians(90), 0, 0), segs=18)
    part_sphere(f"{name_prefix}_SoulCoreOrb", 0.11, torso, collection, mat_core, loc=(0, -0.47, 0.88), subdiv=3)

    # 3. DORSAL VERNIER BACKPACK & 4 SWEPT AERODYNAMIC SERAPH WING-BINDERS + DOCKED FUNNELS
    part_taper_box(f"{name_prefix}_BackpackMain", (0.68, 0.38), (0.54, 0.30), 0.72, torso, collection, mat_sinew,
                   loc=(0.0, 0.38, 0.88), bevel=0.02, smooth=True)
    part_taper_box(f"{name_prefix}_BackpackCowl", (0.58, 0.32), (0.44, 0.24), 0.56, torso, collection, mat_cobalt,
                   loc=(0.0, 0.44, 0.92), bevel=0.02, smooth=True)

    for side, b_piv in [(-1.0, binder_L), (1.0, binder_R)]:
        # Docked Beam Saber Hilts
        part_cyl(f"{name_prefix}_SaberHilt_{side}", 0.032, 0.036, 0.55, torso, collection, mat_ceramic,
                 loc=(side * 0.32, 0.42, 1.38), rot=rads((26, side * 14, 0)), segs=10)
        # Upper Swept Seraph Wing-Binder Blade (White Ceramic + Cobalt Inlay + Gold Crest Tip + Cyan Resonance Vein)
        part_taper_box(f"{name_prefix}_BinderUpper_{side}", (0.22, 0.42), (0.08, 0.18), 2.15, b_piv, collection, mat_ceramic,
                       loc=(side * 0.58, 0.26, 0.64), rot=rads((-18, side * 42, side * -12)), bevel=0.018, smooth=True)
        part_taper_box(f"{name_prefix}_BinderUpperBlue_{side}", (0.16, 0.32), (0.06, 0.14), 1.65, b_piv, collection, mat_cobalt,
                       loc=(side * 0.56, 0.22, 0.62), rot=rads((-18, side * 42, side * -12)), bevel=0.015, smooth=True)
        part_taper_box(f"{name_prefix}_BinderGoldFin_{side}", (0.06, 0.18), (0.02, 0.08), 0.85, b_piv, collection, mat_gold,
                       loc=(side * 0.92, 0.32, 1.15), rot=rads((-18, side * 48, side * -14)), bevel=0.008)
        part_box(f"{name_prefix}_BinderVeinU_{side}", (0.035, 0.06, 1.75), b_piv, collection, mat_cyan,
                 loc=(side * 0.59, 0.14, 0.64), rot=rads((-18, side * 42, side * -12)))
        # Docked Autonomous Beam Funnels along Upper Wing Trailing Edge!
        for f_i in range(3):
            f_off = -0.35 + f_i * 0.42
            part_cyl(f"{name_prefix}_DockedFunnel_{side}_{f_i}", 0.045, 0.035, 0.38, b_piv, collection, mat_gold,
                     loc=(side * (0.48 + f_i * 0.22), 0.42, 0.35 + f_off), rot=rads((-18, side * 42, 0)), segs=10)
            part_sphere(f"{name_prefix}_DockedFunnelTip_{side}_{f_i}", 0.035, b_piv, collection, mat_cyan,
                        loc=(side * (0.48 + f_i * 0.22), 0.42, 0.14 + f_off), subdiv=2)

        # Lower Sub-Wing Stabilizer Fin (Cobalt Blue + White Ceramic + Cyan Vein)
        part_taper_box(f"{name_prefix}_BinderLower_{side}", (0.16, 0.32), (0.06, 0.14), 1.45, b_piv, collection, mat_cobalt,
                       loc=(side * 0.46, 0.28, -0.38), rot=rads((22, side * 54, side * 12)), bevel=0.015, smooth=True)
        part_box(f"{name_prefix}_BinderVeinL_{side}", (0.025, 0.04, 1.18), b_piv, collection, mat_cyan,
                 loc=(side * 0.47, 0.19, -0.38), rot=rads((22, side * 54, side * 12)))
        # Recessed Vernier Thruster Bell & Glowing Cyan Plasma Core
        part_cyl(f"{name_prefix}_VernierBell_{side}", 0.13, 0.09, 0.24, b_piv, collection, mat_sinew,
                 loc=(side * 0.18, 0.18, -0.10), rot=rads((55, side * 18, 0)), segs=16)
        part_sphere(f"{name_prefix}_VernierCore_{side}", 0.09, b_piv, collection, mat_cyan,
                    loc=(side * 0.22, 0.26, -0.16), subdiv=2)

    # 4. SCULPTED GUNDAM HEAD WITH RECESSED CYAN V-VISOR, CRIMSON CHIN & MAGNIFICENT GOLDEN V-FIN CREST
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

    # Crimson Chin Goatee & Forehead Crest Mount + Magnificent Spreading Golden V-Fin Blades!
    part_taper_box(f"{name_prefix}_CrimsonChin", (0.07, 0.08), (0.04, 0.05), 0.09, head, collection, mat_crimson,
                   loc=(0.0, -0.27, 0.08), bevel=0.005)
    part_taper_box(f"{name_prefix}_VFinMountCrimson", (0.08, 0.09), (0.06, 0.07), 0.12, head, collection, mat_crimson,
                   loc=(0.0, -0.31, 0.38), rot=rads((18, 0, 0)), bevel=0.005)
    part_taper_box(f"{name_prefix}_VFinJewelCyan", (0.05, 0.06), (0.03, 0.04), 0.08, head, collection, mat_cyan,
                   loc=(0.0, -0.33, 0.40), rot=rads((18, 0, 0)), bevel=0.004)
    for side in [-1.0, 1.0]:
        # Primary Spreading Golden V-Fin Blade!
        part_taper_box(f"{name_prefix}_GoldVFinBlade_{side}", (0.045, 0.055), (0.012, 0.02), 0.56, head, collection, mat_gold,
                       loc=(side * 0.21, -0.32, 0.53), rot=rads((16, side * 45, side * -12)), bevel=0.004)
        # Auxiliary Swept White Antenna Blade
        part_taper_box(f"{name_prefix}_WhiteSubVFin_{side}", (0.032, 0.042), (0.010, 0.016), 0.38, head, collection, mat_ceramic,
                       loc=(side * 0.14, -0.26, 0.51), rot=rads((12, side * 28, side * -8)), bevel=0.004)
        # Glowing Cyan Dual-Optic Visor Eyes
        part_box(f"{name_prefix}_Visor_{side}", (0.16, 0.04, 0.032), head, collection, mat_cyan,
                 loc=(side * 0.075, -0.29, 0.29), rot=(0, math.radians(side * -14), math.radians(side * 22)))

    # 5. SCULPTED WING-PAULDRONS, ARMS, SERAPH AEGIS SHIELD (L) & RESONANCE BEAM LANCE (R)
    for side, sh_piv, el_piv in [(-1.0, sh_L, el_L), (1.0, sh_R, el_R)]:
        wing_prof = [(-0.42, -0.08), (0.42, -0.08), (0.30, 0.13), (-0.30, 0.13)]
        wing_stations = [
            (0.00, 0.65, 0.85, -0.02),
            (0.28, 1.08, 1.28,  0.08),
            (0.64, 0.84, 0.98,  0.05),
            (0.96, 0.24, 0.28, -0.03),
            (1.12, 0.04, 0.05, -0.07),
        ]
        build_lofted_mesh(f"{name_prefix}_WingPauldron_{side}", wing_prof, wing_stations, sh_piv, collection, mat_ceramic,
                          loc=(side * -0.26, 0.0, 0.15), rot=(0, 0, math.radians(-90 if side > 0 else 90)), subsurf=subsurf_lvl, smooth=True)
        # Cobalt Blue Upper Pauldron Trim Cap
        part_taper_box(f"{name_prefix}_PauldronBlueCap_{side}", (0.38, 0.52), (0.22, 0.36), 0.14, sh_piv, collection, mat_cobalt,
                       loc=(side * 0.12, 0.0, 0.28), rot=rads((0, side * -18, 0)), bevel=0.015, smooth=True)

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

    # Left Forearm Seraph Aegis Shield (White Ceramic + Cobalt Inner Plate + Crimson Emblem + Cyan Edge)
    part_taper_box(f"{name_prefix}_ShieldBody", (0.12, 0.58), (0.06, 0.36), 1.54, el_L, collection, mat_ceramic,
                   loc=(-0.26, -0.10, -0.45), rot=rads((10, -14, 15)), bevel=0.018, smooth=True)
    part_taper_box(f"{name_prefix}_ShieldCobalt", (0.08, 0.44), (0.04, 0.28), 1.18, el_L, collection, mat_cobalt,
                   loc=(-0.30, -0.10, -0.42), rot=rads((10, -14, 15)), bevel=0.015, smooth=True)
    part_box(f"{name_prefix}_ShieldCrimsonCross", (0.06, 0.18, 0.18), el_L, collection, mat_crimson,
             loc=(-0.33, -0.14, -0.15), rot=rads((10, -14, 15)), bevel=0.01)
    part_sphere(f"{name_prefix}_ShieldCyanOrb", 0.065, el_L, collection, mat_cyan, loc=(-0.36, -0.15, -0.15), subdiv=2)

    # Right Hand High-Energy Resonance Beam Lance (with Gold Magnetic Ring & Cyan Plasma Blade)
    part_cyl(f"{name_prefix}_LanceShaft", 0.038, 0.035, 2.4, el_R, collection, mat_sinew,
             loc=(0.12, -0.18, -1.10), rot=rads((-18, 0, 0)), segs=14)
    part_cyl(f"{name_prefix}_LanceGuard", 0.16, 0.05, 0.36, el_R, collection, mat_cobalt,
             loc=(0.12, -0.52, -2.12), rot=rads((162, 0, 0)), segs=16)
    part_cyl(f"{name_prefix}_LanceGoldRing", 0.19, 0.19, 0.06, el_R, collection, mat_gold,
             loc=(0.12, -0.57, -2.26), rot=rads((-18, 0, 0)), segs=18)
    part_cyl(f"{name_prefix}_LanceBeamBlade", 0.10, 0.008, 2.25, el_R, collection, mat_cyan,
             loc=(0.12, -0.94, -3.36), rot=rads((162, 0, 0)), segs=16)

    # 6. SCULPTED HIPS, KNEES (COBALT BLUE), SHIN GREAVES & BOOTS (COBALT & CRIMSON)
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

        part_sphere(f"{name_prefix}_KneeJoint_{side}", 0.15, kn_piv, collection, mat_sinew, loc=(0.0, -0.01, 0.0))
        knee_st = [
            (-0.14, 0.10, 0.10, 0.0, -0.15),
            ( 0.02, 0.13, 0.12, 0.0, -0.18),
            ( 0.18, 0.09, 0.09, 0.0, -0.14),
        ]
        build_vertical_loft(f"{name_prefix}_KneeCapCobalt_{side}", oct_prof, knee_st, kn_piv, collection, mat_cobalt, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

        shin_stations = [
            (-1.02, 0.13, 0.16, side * 0.04,  0.03),
            (-0.68, 0.18, 0.23, side * 0.03,  0.03),
            (-0.26, 0.23, 0.28, side * 0.02,  0.02),
            (-0.02, 0.16, 0.20, 0.0,         -0.02),
        ]
        build_vertical_loft(f"{name_prefix}_ShinGreave_{side}", oct_prof, shin_stations, kn_piv, collection, mat_ceramic, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)

        part_cyl(f"{name_prefix}_CalfNozzle_{side}", 0.075, 0.055, 0.16, kn_piv, collection, mat_sinew,
                 loc=(side * 0.03, 0.25, -0.45), rot=rads((42, 0, 0)), segs=12)
        part_sphere(f"{name_prefix}_CalfCore_{side}", 0.05, kn_piv, collection, mat_cyan,
                    loc=(side * 0.03, 0.30, -0.50), subdiv=2)

        foot_stations = [
            ( 0.04, 0.14, 0.18, 0.0,  0.00),
            (-0.10, 0.18, 0.32, 0.0, -0.10),
            (-0.18, 0.15, 0.36, 0.0, -0.14),
        ]
        build_vertical_loft(f"{name_prefix}_FootCobalt_{side}", oct_prof, foot_stations, ank_piv, collection, mat_cobalt, subsurf=subsurf_lvl, smooth=True, sharp_caps=True)
        part_taper_box(f"{name_prefix}_BootSoleCrimson_{side}", (0.28, 0.56), (0.24, 0.50), 0.06, ank_piv, collection, mat_crimson,
                       loc=(0.0, -0.10, -0.20), bevel=0.01)

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
