class_name TacticalGrid
extends Node3D

const GRID_HALF_SPAN := 220.0
const BOUNDS_HALF_HEIGHT := 40.0
const MAJOR_STEP := 20.0
const MINOR_STEP := 5.0
const RANGE_RINGS := [20.0, 40.0, 60.0, 80.0, 100.0, 140.0, 180.0, 220.0]

var ships: Array[Ship] = []
var selected_ship: Ship = null
var target_ship: Ship = null

var _grid_mesh_instance: MeshInstance3D
var _rings_mesh_instance: MeshInstance3D
var _stem_immediate: ImmediateMesh
var _stem_instance: MeshInstance3D
var _footprints: Dictionary = {}
var _distance_ruler: MeshInstance3D
var _ruler_mesh: ImmediateMesh

func _ready() -> void:
    _build_grid_mesh()
    _build_range_rings()
    _build_bounds()
    _build_stems_system()
    _build_distance_ruler()

func _build_bounds() -> void:
    var half := GRID_HALF_SPAN
    var top := BOUNDS_HALF_HEIGHT
    var bottom := -BOUNDS_HALF_HEIGHT

    var corners := [
        Vector3(-half, 0.0, -half),
        Vector3(half, 0.0, -half),
        Vector3(half, 0.0, half),
        Vector3(-half, 0.0, half),
    ]

    var vertices := PackedVector3Array()

    for i in range(4):
        vertices.push_back(corners[i])
        vertices.push_back(corners[(i + 1) % 4])

    for corner in corners:
        vertices.push_back(Vector3(corner.x, bottom, corner.z))
        vertices.push_back(Vector3(corner.x, top, corner.z))

    for i in range(4):
        vertices.push_back(Vector3(corners[i].x, top, corners[i].z))
        vertices.push_back(Vector3(corners[(i + 1) % 4].x, top, corners[(i + 1) % 4].z))

    for i in range(4):
        vertices.push_back(Vector3(corners[i].x, bottom, corners[i].z))
        vertices.push_back(Vector3(corners[(i + 1) % 4].x, bottom, corners[(i + 1) % 4].z))

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

    var instance := MeshInstance3D.new()
    instance.mesh = mesh

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(1.0, 0.55, 0.2, 0.55)
    mat.emission_enabled = true
    mat.emission = Color(0.8, 0.4, 0.1)
    instance.material_override = mat
    add_child(instance)

func set_ships(fleet: Array[Ship]) -> void:
    ships = fleet
    _rebuild_footprints()

func _rebuild_footprints() -> void:
    for node in _footprints.values():
        if is_instance_valid(node):
            node.queue_free()
    _footprints.clear()

    for ship in ships:
        var fp := _create_footprint_marker(ship)
        add_child(fp)
        _footprints[ship] = fp

func _process(_delta: float) -> void:
    _update_stems_and_footprints()
    _update_distance_ruler()

func _build_grid_mesh() -> void:
    var minor_vertices := PackedVector3Array()
    var major_vertices := PackedVector3Array()

    var steps := int(GRID_HALF_SPAN / MINOR_STEP)
    for i in range(-steps, steps + 1):
        var offset := i * MINOR_STEP
        var is_major := fmod(absf(offset), MAJOR_STEP) < 0.01

        if is_major:
            major_vertices.push_back(Vector3(offset, 0.0, -GRID_HALF_SPAN))
            major_vertices.push_back(Vector3(offset, 0.0, GRID_HALF_SPAN))
            major_vertices.push_back(Vector3(-GRID_HALF_SPAN, 0.0, offset))
            major_vertices.push_back(Vector3(GRID_HALF_SPAN, 0.0, offset))
        else:
            minor_vertices.push_back(Vector3(offset, 0.0, -GRID_HALF_SPAN))
            minor_vertices.push_back(Vector3(offset, 0.0, GRID_HALF_SPAN))
            minor_vertices.push_back(Vector3(-GRID_HALF_SPAN, 0.0, offset))
            minor_vertices.push_back(Vector3(GRID_HALF_SPAN, 0.0, offset))

    var mesh := ArrayMesh.new()

    if not minor_vertices.is_empty():
        var minor_arrays := []
        minor_arrays.resize(Mesh.ARRAY_MAX)
        minor_arrays[Mesh.ARRAY_VERTEX] = minor_vertices
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, minor_arrays)
        var minor_mat := StandardMaterial3D.new()
        minor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        minor_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        minor_mat.albedo_color = Color(0.12, 0.35, 0.50, 0.12)
        mesh.surface_set_material(0, minor_mat)

    if not major_vertices.is_empty():
        var major_arrays := []
        major_arrays.resize(Mesh.ARRAY_MAX)
        major_arrays[Mesh.ARRAY_VERTEX] = major_vertices
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, major_arrays)
        var major_mat := StandardMaterial3D.new()
        major_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        major_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        major_mat.albedo_color = Color(0.20, 0.65, 0.85, 0.32)
        mesh.surface_set_material(mesh.get_surface_count() - 1, major_mat)

    _grid_mesh_instance = MeshInstance3D.new()
    _grid_mesh_instance.mesh = mesh
    add_child(_grid_mesh_instance)

func _build_range_rings() -> void:
    var ring_vertices := PackedVector3Array()
    var segments := 72

    for radius in RANGE_RINGS:
        for i in range(segments):
            var angle1 := (float(i) / float(segments)) * TAU
            var angle2 := (float(i + 1) / float(segments)) * TAU
            var p1 := Vector3(cos(angle1) * radius, 0.0, sin(angle1) * radius)
            var p2 := Vector3(cos(angle2) * radius, 0.0, sin(angle2) * radius)
            ring_vertices.push_back(p1)
            ring_vertices.push_back(p2)

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = ring_vertices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

    _rings_mesh_instance = MeshInstance3D.new()
    _rings_mesh_instance.mesh = mesh

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.25, 0.80, 0.95, 0.35)
    _rings_mesh_instance.material_override = mat
    add_child(_rings_mesh_instance)

    _build_cardinal_markers()

func _build_cardinal_markers() -> void:
    var cardinal_node := Node3D.new()
    add_child(cardinal_node)

    var bearings := [
        {"text": "000° FORE", "pos": Vector3(0.0, 0.0, -102.0)},
        {"text": "090° STBD", "pos": Vector3(102.0, 0.0, 0.0)},
        {"text": "180° AFT", "pos": Vector3(0.0, 0.0, 102.0)},
        {"text": "270° PORT", "pos": Vector3(-102.0, 0.0, 0.0)},
    ]

    for b in bearings:
        var label := Label3D.new()
        label.text = b["text"]
        label.position = b["pos"]
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.font_size = 14
        label.modulate = Color(0.4, 0.85, 1.0, 0.75)
        label.outline_modulate = Color(0.02, 0.05, 0.1, 0.9)
        label.outline_size = 3
        cardinal_node.add_child(label)

func _build_stems_system() -> void:
    _stem_immediate = ImmediateMesh.new()
    _stem_instance = MeshInstance3D.new()
    _stem_instance.mesh = _stem_immediate

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _stem_instance.material_override = mat
    add_child(_stem_instance)

func _create_footprint_marker(ship: Ship) -> Node3D:
    var root := Node3D.new()

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 1.4
    torus.outer_radius = 1.7
    torus.rings = 24
    torus.ring_segments = 4
    ring.mesh = torus

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var color := Color(0.2, 0.9, 0.8, 0.6) if ship.team == 0 else Color(1.0, 0.35, 0.25, 0.6)
    mat.albedo_color = color
    ring.material_override = mat
    root.add_child(ring)

    var label := Label3D.new()
    label.name = "AltLabel"
    label.position = Vector3(2.5, 0.2, 0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 13
    label.modulate = color
    label.outline_modulate = Color(0.01, 0.02, 0.05, 0.9)
    label.outline_size = 2
    root.add_child(label)

    return root

func _update_stems_and_footprints() -> void:
    _stem_immediate.clear_surfaces()
    _stem_immediate.surface_begin(Mesh.PRIMITIVE_LINES)

    for ship in ships:
        if ship.is_destroyed() or not ship.visible:
            if _footprints.has(ship):
                _footprints[ship].visible = false
            continue

        var ship_pos := ship.global_position
        var ground_pos := Vector3(ship_pos.x, 0.0, ship_pos.z)
        var altitude := ship_pos.y
        var is_sel := ship == selected_ship

        if _footprints.has(ship):
            var fp: Node3D = _footprints[ship]
            fp.visible = true
            fp.global_position = ground_pos
            var label: Label3D = fp.get_node_or_null("AltLabel")
            if label != null:
                var sign_str := "+" if altitude >= 0.0 else ""
                label.text = "%s%s: %s%.1fm" % ["> " if is_sel else "", ship.ship_name, sign_str, altitude]
                if is_sel:
                    label.modulate = Color(1.0, 0.85, 0.3, 1.0)
                else:
                    label.modulate = Color(0.3, 0.9, 0.8, 0.7) if ship.team == 0 else Color(1.0, 0.4, 0.3, 0.7)

        var stem_color: Color
        if is_sel:
            stem_color = Color(1.0, 0.85, 0.2, 0.9)
        elif ship.team == 0:
            stem_color = Color(0.2, 0.85, 0.75, 0.45)
        else:
            stem_color = Color(0.95, 0.35, 0.25, 0.45)

        _stem_immediate.surface_set_color(stem_color)
        _stem_immediate.surface_add_vertex(ship_pos)
        _stem_immediate.surface_set_color(stem_color * Color(1.0, 1.0, 1.0, 0.3))
        _stem_immediate.surface_add_vertex(ground_pos)

    _stem_immediate.surface_end()

func _build_distance_ruler() -> void:
    _ruler_mesh = ImmediateMesh.new()
    _distance_ruler = MeshInstance3D.new()
    _distance_ruler.mesh = _ruler_mesh

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _distance_ruler.material_override = mat
    add_child(_distance_ruler)

func _update_distance_ruler() -> void:
    _ruler_mesh.clear_surfaces()
    if selected_ship == null or target_ship == null:
        return
    if selected_ship.is_destroyed() or target_ship.is_destroyed():
        return

    var p1 := selected_ship.global_position
    var p2 := target_ship.global_position
    var dist := p1.distance_to(p2)
    var in_range := dist <= selected_ship.weapon_range

    _ruler_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    var ruler_color := Color(0.2, 1.0, 0.5, 0.8) if in_range else Color(1.0, 0.4, 0.2, 0.6)
    _ruler_mesh.surface_set_color(ruler_color)
    _ruler_mesh.surface_add_vertex(p1)
    _ruler_mesh.surface_set_color(ruler_color)
    _ruler_mesh.surface_add_vertex(p2)
    _ruler_mesh.surface_end()
