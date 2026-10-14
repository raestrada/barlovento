class_name TrajectoryPreview
extends Node3D

var ships: Array[Ship] = []
var ether: EtherField

var _lines: Dictionary = {}
var _markers: Dictionary = {}

func _process(_delta: float) -> void:
    match TurnManager.phase:
        TurnManager.Phase.ADMIRAL_PLAN:
            _rebuild_all(TurnManager.resolution_window)
        TurnManager.Phase.ACE:
            var active := TurnManager.ace_active()
            if active != null and active.team == 0 and not active.is_destroyed():
                _rebuild_single(active, TurnManager.ACE_MOVE_DURATION)
            else:
                _hide_all()
        _:
            _hide_all()

func _rebuild_all(duration: float) -> void:
    for ship in ships:
        if ship.is_destroyed():
            _set_line_visible(ship, false)
            continue
        var points := PhysicsSim.simulate(ship.state, ship.order, ether, duration, 0.1, 64)
        _set_line(ship, points, true)

func _rebuild_single(ship: Ship, duration: float) -> void:
    for other in ships:
        _set_line_visible(other, false)
    var points := PhysicsSim.simulate(ship.state, ship.order, ether, duration, 0.1, 32)
    _set_line(ship, points, true)

func _set_line(ship: Ship, points: PackedVector3Array, visible_state: bool) -> void:
    var line := _ensure_line(ship)
    line.visible = visible_state
    line.mesh = _build_line_mesh(points)
    var marker := _ensure_marker(ship)
    marker.visible = visible_state
    marker.global_position = points[points.size() - 1]

func _set_line_visible(ship: Ship, visible_state: bool) -> void:
    if _lines.has(ship):
        _lines[ship].visible = visible_state
    if _markers.has(ship):
        _markers[ship].visible = visible_state

func _hide_all() -> void:
    for line in _lines.values():
        line.visible = false
    for marker in _markers.values():
        marker.visible = false

func _ensure_line(ship: Ship) -> MeshInstance3D:
    if _lines.has(ship):
        return _lines[ship]
    var line := MeshInstance3D.new()
    line.material_override = _line_material(ship.team)
    add_child(line)
    _lines[ship] = line
    return line

func _ensure_marker(ship: Ship) -> MeshInstance3D:
    if _markers.has(ship):
        return _markers[ship]
    var sphere := SphereMesh.new()
    sphere.radius = 0.6
    sphere.height = 1.2
    sphere.material = _line_material(ship.team)
    var marker := MeshInstance3D.new()
    marker.mesh = sphere
    add_child(marker)
    _markers[ship] = marker
    return marker

func _build_line_mesh(points: PackedVector3Array) -> ArrayMesh:
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = points
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
    return mesh

func _line_material(team: int) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.3, 1.0, 0.4) if team == 0 else Color(1.0, 0.35, 0.3)
    material.emission_enabled = true
    material.emission = Color(0.15, 0.5, 0.2) if team == 0 else Color(0.5, 0.15, 0.12)
    return material
