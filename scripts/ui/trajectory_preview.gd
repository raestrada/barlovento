class_name TrajectoryPreview
extends Node3D

const STEP_DT := 0.1
const MARKER_TIME_STEP := 2.0

var player_ships: Array[Ship] = []
var enemy_ships: Array[Ship] = []
var ether: EtherField

var _lines: Dictionary = {}
var _arrival_markers: Dictionary = {}
var _time_pips: Dictionary = {}

func _process(_delta: float) -> void:
    match TurnManager.phase:
        TurnManager.Phase.ADMIRAL_PLAN:
            _update_all_trajectories(TurnManager.admiral_resolution_window)
        TurnManager.Phase.ACE_PLAN:
            _update_all_trajectories(TurnManager.ace_resolution_window)
        _:
            _hide_all()

func _update_all_trajectories(duration: float) -> void:
    for ship in player_ships:
        if ship.is_destroyed() or not ship.visible:
            _set_ship_track_visible(ship, false)
            continue
        var points := PhysicsSim.simulate(ship.state, ship.order, ether, duration, STEP_DT, 72)
        var final_heading := ship.order.heading()
        _render_track(ship, points, final_heading, duration, true)

    for enemy in enemy_ships:
        if enemy.is_destroyed() or not enemy.visible:
            _set_ship_track_visible(enemy, false)
            continue
        var points := PhysicsSim.simulate(enemy.state, enemy.order, ether, duration, STEP_DT, 48)
        var final_heading := enemy.order.heading()
        _render_track(enemy, points, final_heading, duration, true)

func _update_single_trajectory(ship: Ship, duration: float) -> void:
    for other in player_ships + enemy_ships:
        if other != ship:
            _set_ship_track_visible(other, false)
    var points := PhysicsSim.simulate(ship.state, ship.order, ether, duration, STEP_DT, 36)
    _render_track(ship, points, ship.order.heading(), duration, true)

func _render_track(ship: Ship, points: PackedVector3Array, final_heading: Vector3, duration: float, is_vis: bool) -> void:
    if points.is_empty():
        return

    var line := _ensure_line(ship)
    line.visible = is_vis
    line.mesh = _build_track_mesh(points, ship.team)

    var marker := _ensure_arrival_marker(ship)
    marker.visible = is_vis
    var last_pos := points[points.size() - 1]
    marker.global_position = last_pos

    if final_heading.length_squared() > 0.001:
        var up := Vector3.UP if absf(final_heading.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
        marker.look_at(last_pos + final_heading, up)

    _update_time_pips(ship, points, duration, is_vis)

func _update_time_pips(ship: Ship, points: PackedVector3Array, duration: float, is_vis: bool) -> void:
    var pips: Array[Node3D] = _ensure_pips_pool(ship)
    var total_pts := points.size()
    if total_pts < 2 or not is_vis:
        for pip in pips:
            pip.visible = false
        return

    var pip_interval_seconds := MARKER_TIME_STEP
    var pip_count := int(duration / pip_interval_seconds)

    for i in range(pips.size()):
        var pip := pips[i]
        if i < pip_count:
            var frac := float(i + 1) * pip_interval_seconds / duration
            var idx := clampi(int(round(frac * float(total_pts - 1))), 0, total_pts - 1)
            pip.visible = true
            pip.global_position = points[idx]
            var lbl: Label3D = pip.get_node_or_null("TimeLabel")
            if lbl != null:
                lbl.text = "%.0fs" % ((i + 1) * pip_interval_seconds)
        else:
            pip.visible = false

func _ensure_line(ship: Ship) -> MeshInstance3D:
    if _lines.has(ship):
        return _lines[ship]
    var line := MeshInstance3D.new()
    line.material_override = _line_material(ship.team)
    add_child(line)
    _lines[ship] = line
    return line

func _ensure_arrival_marker(ship: Ship) -> Node3D:
    if _arrival_markers.has(ship):
        return _arrival_markers[ship]

    var root := Node3D.new()

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 1.05
    torus.outer_radius = 1.35
    torus.rings = 24
    ring.mesh = torus
    ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)

    var ring_mat := StandardMaterial3D.new()
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var col := Color(0.3, 0.95, 0.85, 0.8) if ship.team == 0 else Color(1.0, 0.45, 0.3, 0.8)
    ring_mat.albedo_color = col
    ring.material_override = ring_mat
    root.add_child(ring)

    # Holographic Ghost Ship Silhouette at predicted end-of-turn pose
    var ghost_mat := StandardMaterial3D.new()
    ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ghost_mat.albedo_color = Color(col.r, col.g, col.b, 0.35)
    ghost_mat.emission_enabled = true
    ghost_mat.emission = Color(col.r, col.g, col.b)
    ghost_mat.emission_energy_multiplier = 1.4

    var ghost_hull := MeshInstance3D.new()
    var hull_box := BoxMesh.new()
    hull_box.size = Vector3(0.95, 0.45, 2.2)
    ghost_hull.mesh = hull_box
    ghost_hull.material_override = ghost_mat
    root.add_child(ghost_hull)

    var ghost_wing := MeshInstance3D.new()
    var wing_box := BoxMesh.new()
    wing_box.size = Vector3(2.3, 0.14, 0.85)
    ghost_wing.mesh = wing_box
    ghost_wing.position = Vector3(0.0, 0.08, 0.15)
    ghost_wing.material_override = ghost_mat
    root.add_child(ghost_wing)

    var pointer := MeshInstance3D.new()
    var prism := CylinderMesh.new()
    prism.top_radius = 0.0
    prism.bottom_radius = 0.52
    prism.height = 1.45
    pointer.mesh = prism
    pointer.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    pointer.position = Vector3(0.0, 0.0, -1.65)
    pointer.material_override = ring_mat
    root.add_child(pointer)

    add_child(root)
    _arrival_markers[ship] = root
    return root

func _ensure_pips_pool(ship: Ship) -> Array[Node3D]:
    if _time_pips.has(ship):
        return _time_pips[ship]

    var pips: Array[Node3D] = []
    for _i in range(8):
        var pip_node := Node3D.new()

        var dot := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.25
        sphere.height = 0.5
        dot.mesh = sphere

        var mat := StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.albedo_color = Color(0.4, 0.95, 1.0) if ship.team == 0 else Color(1.0, 0.5, 0.35)
        dot.material_override = mat
        pip_node.add_child(dot)

        var lbl := Label3D.new()
        lbl.name = "TimeLabel"
        lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        lbl.font_size = 11
        lbl.position = Vector3(0.0, 0.6, 0.0)
        lbl.modulate = mat.albedo_color
        lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
        lbl.outline_size = 2
        pip_node.add_child(lbl)

        pip_node.visible = false
        add_child(pip_node)
        pips.append(pip_node)

    _time_pips[ship] = pips
    return pips

func _set_ship_track_visible(ship: Ship, is_vis: bool) -> void:
    if _lines.has(ship):
        _lines[ship].visible = is_vis
    if _arrival_markers.has(ship):
        _arrival_markers[ship].visible = is_vis
    if _time_pips.has(ship):
        for pip in _time_pips[ship]:
            pip.visible = false

func _hide_all() -> void:
    for line in _lines.values():
        line.visible = false
    for marker in _arrival_markers.values():
        marker.visible = false
    for pips in _time_pips.values():
        for pip in pips:
            pip.visible = false

func _build_track_mesh(points: PackedVector3Array, team: int) -> ArrayMesh:
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = points

    var colors := PackedColorArray()
    var base_col := Color(0.25, 0.9, 0.85) if team == 0 else Color(1.0, 0.45, 0.35)
    var count := points.size()
    for i in range(count):
        var alpha := lerpf(0.9, 0.35, float(i) / float(count))
        colors.append(Color(base_col.r, base_col.g, base_col.b, alpha))
    arrays[Mesh.ARRAY_COLOR] = colors

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
    return mesh

func _line_material(team: int) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var emission_col := Color(0.15, 0.6, 0.55) if team == 0 else Color(0.6, 0.25, 0.15)
    mat.emission_enabled = true
    mat.emission = emission_col
    return mat
