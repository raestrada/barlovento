class_name ProceduralMeshPrimitives
extends RefCounted

const ACERO_HULL := "res://assets/ships/acero/acero_hull.png"
const VINCULADOS_HULL := "res://assets/ships/vinculados/vinculados_hull.png"
const MAREA_HULL := "res://assets/ships/marea-libre/marea_hull.png"

static var _quantum_sail_shader: Shader = null
static var _soul_core_shader: Shader = null

static func _get_quantum_sail_material() -> ShaderMaterial:
    if _quantum_sail_shader == null:
        _quantum_sail_shader = Shader.new()
        _quantum_sail_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

void fragment() {
    vec2 uv = UV;
    float rib_v = smoothstep(0.93, 0.99, abs(sin(uv.x * 3.14159 * 6.0)));
    float rib_h = smoothstep(0.95, 0.99, abs(sin(uv.y * 3.14159 * 4.0)));
    float edge = max(
        smoothstep(0.44, 0.50, abs(uv.x - 0.5)),
        smoothstep(0.45, 0.50, abs(uv.y - 0.5))
    );
    float pulse = 0.5 + 0.5 * sin(TIME * 2.0 - uv.y * 5.0);
    vec3 base_col = vec3(0.10, 0.58, 0.76);
    vec3 vein_col = vec3(0.55, 0.88, 0.96);
    vec3 brass_edge = vec3(0.78, 0.62, 0.28);
    vec3 col = mix(base_col, vein_col, clamp(rib_v * 0.55 + rib_h * 0.35 + pulse * 0.12, 0.0, 1.0));
    col = mix(col, brass_edge, edge * 0.65);
    ALBEDO = col * 0.92;
    ALPHA = clamp(0.54 + edge * 0.32 + rib_v * 0.18, 0.0, 0.90);
}
"""
    var sm := ShaderMaterial.new()
    sm.shader = _quantum_sail_shader
    return sm

static func _get_soul_core_material() -> ShaderMaterial:
    if _soul_core_shader == null:
        _soul_core_shader = Shader.new()
        _soul_core_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
    float pulse = 0.55 + 0.45 * sin(TIME * 3.8);
    vec3 col = mix(vec3(0.86, 0.18, 0.74), vec3(0.42, 0.85, 0.96), pulse * 0.35);
    ALBEDO = col * (1.25 + pulse * 0.45);
}
"""
    var sm := ShaderMaterial.new()
    sm.shader = _soul_core_shader
    return sm

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

static func _marea_profile(s: Vector3) -> PackedVector2Array:
    var hw := s.x * 0.5
    var hh := s.y * 0.4
    return PackedVector2Array([
        Vector2(0.0, -0.6 * hh),
        Vector2(0.3 * hw, -0.55 * hh),
        Vector2(0.55 * hw, -0.4 * hh),
        Vector2(0.75 * hw, -0.18 * hh),
        Vector2(0.88 * hw, 0.05 * hh),
        Vector2(0.9 * hw, 0.28 * hh),
        Vector2(0.78 * hw, 0.45 * hh),
        Vector2(0.55 * hw, 0.55 * hh),
        Vector2(0.0, 0.6 * hh),
        Vector2(-0.55 * hw, 0.55 * hh),
        Vector2(-0.78 * hw, 0.45 * hh),
        Vector2(-0.9 * hw, 0.28 * hh),
        Vector2(-0.88 * hw, 0.05 * hh),
        Vector2(-0.75 * hw, -0.18 * hh),
        Vector2(-0.55 * hw, -0.4 * hh),
        Vector2(-0.3 * hw, -0.55 * hh),
    ])

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

static var _hull_normal_tex: NoiseTexture2D = null

static func _get_hull_normal_map() -> NoiseTexture2D:
    if _hull_normal_tex == null:
        var n := FastNoiseLite.new()
        n.seed = 901
        n.noise_type = FastNoiseLite.TYPE_CELLULAR
        n.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
        n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
        n.frequency = 0.085
        _hull_normal_tex = NoiseTexture2D.new()
        _hull_normal_tex.width = 256
        _hull_normal_tex.height = 256
        _hull_normal_tex.seamless = true
        _hull_normal_tex.as_normal_map = true
        _hull_normal_tex.bump_strength = 3.2
        _hull_normal_tex.noise = n
    return _hull_normal_tex

static func _textured(tex: Texture2D, metallic: float, roughness: float, uv: Vector3) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.WHITE
    mat.albedo_texture = tex
    mat.uv1_scale = uv
    mat.uv1_triplanar = true
    mat.uv1_triplanar_sharpness = 4.0
    mat.metallic = metallic
    mat.roughness = roughness
    mat.normal_enabled = true
    mat.normal_texture = _get_hull_normal_map()
    mat.normal_scale = 0.45
    return mat

static func _colored(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = roughness
    mat.uv1_triplanar = true
    mat.normal_enabled = true
    mat.normal_texture = _get_hull_normal_map()
    mat.normal_scale = 0.25
    return mat

static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
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

