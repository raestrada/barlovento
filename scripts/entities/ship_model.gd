class_name ShipModelBuilder

const ACERO_HULL := "res://assets/ships/acero/acero_hull.png"
const VINCULADOS_HULL := "res://assets/ships/vinculados/vinculados_hull.png"
const MAREA_HULL := "res://assets/ships/marea-libre/marea_hull.png"

static func build(ship: Ship, root: Node3D, thruster_lights: Array[Node3D]) -> void:
    match ship.faction:
        "acero":
            _build_acero(ship, root, thruster_lights)
        "vinculados":
            _build_vinculados(ship, root, thruster_lights)
        "marea_libre":
            _build_marea(ship, root, thruster_lights)
        _:
            _build_acero(ship, root, thruster_lights)

# ---------------------------------------------------------------------------
# Armada of Acero — angular, brutalist slab hull, wedge bow, engine nacelles.
# ---------------------------------------------------------------------------

static func _build_acero(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
    var s := ship.body_size
    var hull := _textured(load(ACERO_HULL), 0.85, 0.35, Vector3(2.0, 2.0, 1.0))
    hull.cull_mode = BaseMaterial3D.CULL_DISABLED
    var armor := _textured(load(ACERO_HULL), 0.9, 0.28, Vector3(2.5, 2.5, 1.0))
    armor.cull_mode = BaseMaterial3D.CULL_DISABLED
    var steel := _colored(Color(0.18, 0.2, 0.24), 0.85, 0.35)
    var engine := _emissive(Color(1.0, 0.45, 0.08), 4.0)

    # Lofted tapered hull: wide slab amidships narrowing to a pointed bow.
    var half_len := s.z * 0.5
    var hull_mesh := build_loft(_acero_profile(s), [
        {"z": -half_len, "scale": Vector2(0.06, 0.08), "offset_y": 0.0},
        {"z": -half_len * 0.84, "scale": Vector2(0.35, 0.5), "offset_y": 0.0},
        {"z": -half_len * 0.6, "scale": Vector2(0.55, 0.75), "offset_y": 0.0},
        {"z": -half_len * 0.3, "scale": Vector2(0.75, 0.9), "offset_y": 0.0},
        {"z": half_len * 0.1, "scale": Vector2(0.95, 1.0), "offset_y": 0.0},
        {"z": half_len * 0.5, "scale": Vector2(1.0, 1.0), "offset_y": 0.0},
        {"z": half_len * 0.84, "scale": Vector2(1.0, 1.0), "offset_y": 0.0},
        {"z": half_len, "scale": Vector2(0.85, 0.95), "offset_y": 0.0},
    ])
    var hull_inst := MeshInstance3D.new()
    hull_inst.mesh = hull_mesh
    hull_inst.material_override = hull
    root.add_child(hull_inst)

    # Raised citadel / bridge (tiered).
    root.add_child(_box(
        Vector3(s.x * 0.5, s.y * 0.7, s.z * 0.34), steel,
        Vector3(0.0, s.y * 0.55, s.z * 0.12)
    ))
    root.add_child(_box(
        Vector3(s.x * 0.3, s.y * 0.45, s.z * 0.22), armor,
        Vector3(0.0, s.y * 0.9, s.z * 0.14)
    ))

    # Dorsal fin.
    root.add_child(_prism(
        Vector3(0.1, s.y * 0.9, s.z * 0.3), armor,
        Vector3(0.0, s.y * 0.6, s.z * 0.28), Vector3(0.0, 0.0, 90.0)
    ))

    # Twin engine nacelles at the stern.
    for side in [-1.0, 1.0]:
        var nacelle := _cyl(
            s.x * 0.18, s.x * 0.18, s.z * 0.4, 10, steel,
            Vector3(side * s.x * 0.42, 0.0, s.z * 0.5), Vector3(-90.0, 0.0, 0.0)
        )
        root.add_child(nacelle)
        var nozzle := _cyl(
            s.x * 0.16, s.x * 0.22, 0.5, 12, engine,
            Vector3(side * s.x * 0.42, 0.0, s.z * 0.62), Vector3(-90.0, 0.0, 0.0)
        )
        root.add_child(nozzle)
        thrusters.append(nozzle)

    # Side turret batteries.
    for side in [-1.0, 1.0]:
        for i in range(3):
            var z := -s.z * 0.15 + i * s.z * 0.22
            var turret := _cyl(
                s.x * 0.1, s.x * 0.14, s.y * 0.3, 8, steel,
                Vector3(side * (s.x * 0.52), s.y * 0.25, z)
            )
            root.add_child(turret)
            var barrel := _cyl(
                s.x * 0.05, s.x * 0.05, s.z * 0.16, 8, steel,
                Vector3(side * (s.x * 0.52 + s.x * 0.1), s.y * 0.25, z), Vector3(0.0, 0.0, 90.0)
            )
            root.add_child(barrel)

# ---------------------------------------------------------------------------
# Vinculados — upright humanoid mecha, white ceramic, glowing magenta core.
# ---------------------------------------------------------------------------

static func _build_vinculados(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
    var s := ship.body_size
    var h := s.z          # mecha height mapped to body length
    var w := s.x
    var d := s.y

    var ceramic := _textured(load(VINCULADOS_HULL), 0.15, 0.2, Vector3(2.0, 2.0, 1.0))
    var sinew := _colored(Color(0.12, 0.14, 0.18), 0.8, 0.4)
    var core := _emissive(Color(0.95, 0.2, 0.85), 4.0)

    # Torso (tapered, smooth).
    root.add_child(_cyl(
        w * 0.22, w * 0.34, h * 0.3, 12, ceramic,
        Vector3(0.0, h * 0.18, 0.0)
    ))

    # Pelvis block.
    root.add_child(_box(
        Vector3(w * 0.5, h * 0.06, d * 0.6), ceramic,
        Vector3(0.0, h * 0.06, 0.0)
    ))

    # Chest core (glowing).
    root.add_child(_sphere(
        w * 0.16, w * 0.32, core, Vector3(0.0, h * 0.26, -d * 0.4)
    ))

    # Head with visor.
    root.add_child(_box(
        Vector3(w * 0.3, w * 0.28, w * 0.3), ceramic,
        Vector3(0.0, h * 0.36, 0.0)
    ))
    root.add_child(_box(
        Vector3(w * 0.24, w * 0.08, w * 0.05), _emissive(Color(0.4, 0.9, 1.0), 3.0),
        Vector3(0.0, h * 0.36, -w * 0.16)
    ))

    # Shoulder pauldrons.
    for side in [-1.0, 1.0]:
        root.add_child(_sphere(
            w * 0.18, w * 0.36, ceramic,
            Vector3(side * w * 0.4, h * 0.3, 0.0)
        ))
        # Arms (upper + forearm).
        var arm := _capsule(
            w * 0.09, h * 0.16, sinew,
            Vector3(side * w * 0.4, h * 0.2, -d * 0.1), Vector3(0.0, 0.0, 20.0 * side)
        )
        root.add_child(arm)
        var forearm := _capsule(
            w * 0.07, h * 0.15, ceramic,
            Vector3(side * w * 0.42, h * 0.08, -d * 0.3), Vector3(0.0, 0.0, 15.0 * side)
        )
        root.add_child(forearm)

    # Legs.
    for side in [-1.0, 1.0]:
        var thigh := _capsule(
            w * 0.1, h * 0.16, sinew,
            Vector3(side * w * 0.16, -h * 0.04, 0.0)
        )
        root.add_child(thigh)
        var shin := _capsule(
            w * 0.08, h * 0.16, ceramic,
            Vector3(side * w * 0.16, -h * 0.16, d * 0.1)
        )
        root.add_child(shin)
        var vernier := _cyl(
            w * 0.06, w * 0.1, 0.4, 8, core,
            Vector3(side * w * 0.16, -h * 0.26, d * 0.15), Vector3(90.0, 0.0, 0.0)
        )
        root.add_child(vernier)
        thrusters.append(vernier)

# ---------------------------------------------------------------------------
# Free Tide — sealed timber hull, spar booms, large éther sails, oar vanes.
# ---------------------------------------------------------------------------

static func _build_marea(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
    var s := ship.body_size
    var wood := _textured(load(MAREA_HULL), 0.0, 0.7, Vector3(2.0, 2.0, 1.0))
    var brass := _colored(Color(0.85, 0.7, 0.25), 0.9, 0.3)
    var sail := _translucent(Color(0.2, 0.85, 0.95, 0.55), Color(0.1, 0.5, 0.6), 1.6)
    var hab := _emissive(Color(1.0, 0.65, 0.25), 3.0)
    var oar := _emissive(Color(0.3, 0.9, 0.95), 2.0)

    # Rounded, tapered sealed hull.
    root.add_child(_cyl(
        s.x * 0.3, s.x * 0.55, s.z * 0.85, 10, wood,
        Vector3(0.0, 0.0, 0.0), Vector3(-90.0, 0.0, 0.0)
    ))

    # Bowsprit.
    root.add_child(_cyl(
        0.05, 0.05, s.z * 0.35, 6, brass,
        Vector3(0.0, 0.0, -s.z * 0.5), Vector3(-90.0, 0.0, 0.0)
    ))

    # Brass stern lantern.
    root.add_child(_sphere(0.12, 0.24, hab, Vector3(0.0, s.y * 0.4, s.z * 0.45)))

    # Masts and large éther sails.
    for i in range(3):
        var mast_z := -s.z * 0.25 + i * s.z * 0.3
        var mast := _cyl(
            0.04, 0.05, s.y * 1.6, 6, brass,
            Vector3(0.0, s.y * 0.6, mast_z)
        )
        root.add_child(mast)

        var boom := _cyl(
            0.03, 0.03, s.x * 2.6, 6, brass,
            Vector3(0.0, s.y * 1.1, mast_z), Vector3(0.0, 0.0, 90.0)
        )
        root.add_child(boom)

        var sail_w := s.x * 2.4
        var sail_h := s.y * 1.5
        var sail_plane := _quad(
            Vector2(sail_w, sail_h), sail,
            Vector3(0.0, s.y * 0.7, mast_z)
        )
        root.add_child(sail_plane)

    # Éther-oar vanes along the flanks.
    for side in [-1.0, 1.0]:
        for i in range(4):
            var z := -s.z * 0.3 + i * s.z * 0.2
            var vane := _quad(
                Vector2(s.x * 0.3, s.x * 0.5), oar,
                Vector3(side * s.x * 0.6, 0.0, z), Vector3(0.0, side * 55.0, 90.0)
            )
            root.add_child(vane)

    # Amber hab-light viewports.
    for side in [-1.0, 1.0]:
        for i in range(4):
            var z := -s.z * 0.28 + i * s.z * 0.2
            root.add_child(_sphere(
                0.06, 0.12, hab, Vector3(side * s.x * 0.42, 0.0, z)
            ))

    # Stern thrusters.
    for side in [-1.0, 1.0]:
        var nozzle := _cyl(
            0.08, 0.14, 0.4, 8, hab,
            Vector3(side * s.x * 0.3, 0.0, s.z * 0.5), Vector3(-90.0, 0.0, 0.0)
        )
        root.add_child(nozzle)
        thrusters.append(nozzle)

static func _acero_profile(s: Vector3) -> PackedVector2Array:
    var hw := s.x * 0.5
    var hh := s.y * 0.5
    return PackedVector2Array([
        Vector2(0.0, -0.55 * hh),
        Vector2(0.85 * hw, -0.55 * hh),
        Vector2(hw, -0.15 * hh),
        Vector2(hw, 0.35 * hh),
        Vector2(0.85 * hw, 0.55 * hh),
        Vector2(0.0, 0.6 * hh),
        Vector2(-0.85 * hw, 0.55 * hh),
        Vector2(-hw, 0.35 * hh),
        Vector2(-hw, -0.15 * hh),
        Vector2(-0.85 * hw, -0.55 * hh),
    ])

# Loft a closed 2D profile through a series of stations into a hull mesh.
# stations: Array of {"z": float, "scale": Vector2, "offset_y": float}.
static func build_loft(profile: PackedVector2Array, stations: Array) -> ArrayMesh:
    var n := profile.size()
    var m := stations.size()

    var verts := PackedVector3Array()
    var uvs := PackedVector2Array()

    for i in range(m):
        var s: Dictionary = stations[i]
        var z: float = s["z"]
        var sc: Vector2 = s["scale"]
        var oy: float = s["offset_y"]
        for j in range(n):
            var p := profile[j]
            verts.append(Vector3(p.x * sc.x, p.y * sc.y + oy, z))
            uvs.append(Vector2(float(j) / float(n), float(i) / float(m - 1)))

    var front_center := m * n
    verts.append(Vector3(0.0, stations[0]["offset_y"], stations[0]["z"]))
    uvs.append(Vector2(0.5, 0.0))

    var back_center := m * n + 1
    verts.append(Vector3(0.0, stations[m - 1]["offset_y"], stations[m - 1]["z"]))
    uvs.append(Vector2(0.5, 1.0))

    var indices := PackedInt32Array()
    for i in range(m - 1):
        for j in range(n):
            var a := i * n + j
            var b := i * n + ((j + 1) % n)
            var c := (i + 1) * n + j
            var d := (i + 1) * n + ((j + 1) % n)
            indices.append(a)
            indices.append(c)
            indices.append(b)
            indices.append(b)
            indices.append(c)
            indices.append(d)

    for j in range(n):
        var a := j
        var b := (j + 1) % n
        indices.append(front_center)
        indices.append(b)
        indices.append(a)

    for j in range(n):
        var a := (m - 1) * n + j
        var b := (m - 1) * n + ((j + 1) % n)
        indices.append(back_center)
        indices.append(a)
        indices.append(b)

    var normals := PackedVector3Array()
    normals.resize(verts.size())
    for k in range(verts.size()):
        normals[k] = Vector3.ZERO

    var tri_count := indices.size() / 3
    for t in range(tri_count):
        var ia := indices[t * 3]
        var ib := indices[t * 3 + 1]
        var ic := indices[t * 3 + 2]
        var face_normal := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
        normals[ia] += face_normal
        normals[ib] += face_normal
        normals[ic] += face_normal

    for k in range(normals.size()):
        normals[k] = normals[k].normalized()

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _box(size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return _instance(mesh, mat, pos, rot)

static func _cyl(top_r: float, bottom_r: float, height: float, radial: int, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = top_r
    mesh.bottom_radius = bottom_r
    mesh.height = height
    mesh.radial_segments = radial
    return _instance(mesh, mat, pos, rot)

static func _sphere(radius: float, height: float, mat: Material, pos: Vector3) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = height
    return _instance(mesh, mat, pos)

static func _capsule(radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    return _instance(mesh, mat, pos, rot)

static func _prism(size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := PrismMesh.new()
    mesh.size = size
    return _instance(mesh, mat, pos, rot)

static func _quad(size: Vector2, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := QuadMesh.new()
    mesh.size = size
    return _instance(mesh, mat, pos, rot)

static func _instance(mesh: PrimitiveMesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    if rot != Vector3.ZERO:
        mi.rotation_degrees = rot
    return mi

static func _textured(tex: Texture2D, metallic: float, roughness: float, uv: Vector3) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.WHITE
    mat.albedo_texture = tex
    mat.uv1_scale = uv
    mat.metallic = metallic
    mat.roughness = roughness
    return mat

static func _colored(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = roughness
    return mat

static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color * energy
    mat.emission_energy_multiplier = energy
    return mat

static func _translucent(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.emission_enabled = true
    mat.emission = emission
    mat.emission_energy_multiplier = energy
    return mat
