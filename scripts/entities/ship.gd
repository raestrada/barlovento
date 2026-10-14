class_name Ship
extends Node3D

signal clicked(ship: Ship)

const VELOCITY_ARROW_SCALE := 0.75
const ORDER_ARROW_SCALE := 0.75

@export var mass: float = 100.0
@export var max_thrust: float = 500.0
@export var brake_thrust: float = 500.0
@export var turn_power: float = 200.0
@export var max_speed: float = 20.0
@export var hp: float = 100.0
@export var weapon_range: float = 40.0
@export var weapon_damage: float = 15.0
@export var weapon_arc_degrees: float = 60.0
@export var initial_velocity: Vector3 = Vector3.ZERO
@export var ship_color: Color = Color(0.7, 0.7, 0.75)
@export var body_size: Vector3 = Vector3(2.0, 1.0, 6.0)
@export var team: int = 0
@export var selected: bool = false

var ship_name: String = "Ship"
var ship_id: String = ""
var faction: String = "acero"
var max_hp: float = 100.0
var state: ShipState
var order: ShipOrder
var ether: EtherField = null

var _model_root: Node3D
var _velocity_arrow: Node3D
var _velocity_label: Label3D
var _order_arrow: Node3D
var _order_label: Label3D
var _firing_arc_instance: MeshInstance3D
var _firing_arc_material: StandardMaterial3D
var _overhead_hud: Node3D
var _overhead_hp_bar: MeshInstance3D
var _overhead_name: Label3D
var _selection_ring: MeshInstance3D
var _target_ring: MeshInstance3D
var _thruster_lights: Array[Node3D] = []

func _ready() -> void:
    state = ShipState.new()
    state.position = global_position
    state.forward = -global_transform.basis.z
    state.mass = mass
    state.max_thrust = max_thrust
    state.brake_thrust = brake_thrust
    state.turn_power = turn_power
    state.max_speed = max_speed
    state.velocity = initial_velocity
    max_hp = hp
    order = ShipOrder.new()

    _build_detailed_ship_model()
    _build_tactical_indicators()
    _build_overhead_hud()
    _build_click_detection()

func apply_def(def: ShipDef) -> void:
    ship_id = def.id
    ship_name = def.display_name
    faction = def.faction
    mass = def.mass
    max_thrust = def.max_thrust
    brake_thrust = def.brake_thrust
    turn_power = def.turn_power
    max_speed = def.max_speed
    hp = def.hp
    max_hp = def.hp
    weapon_range = def.weapon_range
    weapon_damage = def.weapon_damage
    weapon_arc_degrees = def.weapon_arc_degrees
    ship_color = def.color
    body_size = def.body_size

    if is_inside_tree():
        _build_detailed_ship_model()
        _rebuild_firing_arc()
        if _overhead_name != null:
            _overhead_name.text = ship_name

func speed() -> float:
    return state.speed()

func take_damage(amount: float) -> void:
    hp = maxf(hp - amount, 0.0)
    _update_overhead_hp()
    if is_destroyed():
        visible = false

func is_destroyed() -> bool:
    return hp <= 0.0

func advance(duration: float, dt: float = 0.1) -> void:
    var t := 0.0
    while t < duration:
        PhysicsSim.step_state(state, order, dt, ether)
        t += dt
    _sync_transform()

func _physics_process(delta: float) -> void:
    if is_destroyed():
        return
    if TurnManager.phase == TurnManager.Phase.ADMIRAL_RESOLVE:
        var sim_delta := delta * PhysicsSim.time_scale
        PhysicsSim.apply_order(state, order, sim_delta, ether)
        _sync_transform()
    update_indicators()

func _sync_transform() -> void:
    global_position = state.position
    if state.forward.length_squared() > 0.0001:
        look_at(global_position + state.forward, Vector3.UP)

func update_indicators() -> void:
    _update_velocity_arrow()
    _update_order_arrow()
    _update_firing_arc()
    _update_selection_visuals()
    _update_thruster_fx()
    _update_overhead_hp()

func _update_velocity_arrow() -> void:
    if _velocity_arrow == null:
        return
    var cur_speed := state.speed()
    var is_vis := cur_speed > 0.35
    _velocity_arrow.visible = is_vis
    if is_vis:
        var vel_norm := state.velocity.normalized()
        var arrow_len := maxf(cur_speed * VELOCITY_ARROW_SCALE, 1.5)
        var up := Vector3.UP if absf(vel_norm.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
        _velocity_arrow.look_at(global_position + vel_norm, up)
        _velocity_arrow.scale = Vector3(1.0, 1.0, arrow_len)
        if _velocity_label != null:
            _velocity_label.text = "VEL: %.1f m/s" % cur_speed

func _update_order_arrow() -> void:
    if _order_arrow == null:
        return
    var planning := TurnManager.phase == TurnManager.Phase.ADMIRAL_PLAN or TurnManager.phase == TurnManager.Phase.ACE
    var is_vis := selected and planning and order.target_speed > 0.1
    _order_arrow.visible = is_vis
    if is_vis:
        var heading := order.heading()
        var arrow_len := maxf(order.target_speed * ORDER_ARROW_SCALE, 1.5)
        var up := Vector3.UP if absf(heading.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
        _order_arrow.look_at(global_position + heading, up)
        _order_arrow.scale = Vector3(1.0, 1.0, arrow_len)
        if _order_label != null:
            _order_label.text = "CMD: %.1f m/s" % order.target_speed

func _update_firing_arc() -> void:
    if _firing_arc_instance == null:
        return
    var planning := TurnManager.phase == TurnManager.Phase.ADMIRAL_PLAN or TurnManager.phase == TurnManager.Phase.ACE
    _firing_arc_instance.visible = selected and planning

func _update_selection_visuals() -> void:
    if _selection_ring != null:
        _selection_ring.visible = selected
    if _overhead_hud != null:
        _overhead_hud.visible = not is_destroyed()

func _update_overhead_hp() -> void:
    if _overhead_hp_bar == null:
        return
    var ratio := clampf(hp / max_hp, 0.0, 1.0)
    _overhead_hp_bar.scale = Vector3(ratio, 1.0, 1.0)
    var mat: StandardMaterial3D = _overhead_hp_bar.material_override
    if mat != null:
        if ratio > 0.5:
            mat.albedo_color = Color(0.2, 0.9, 0.4)
        elif ratio > 0.25:
            mat.albedo_color = Color(1.0, 0.8, 0.2)
        else:
            mat.albedo_color = Color(1.0, 0.3, 0.2)

func _update_thruster_fx() -> void:
    var resolving := TurnManager.phase == TurnManager.Phase.ADMIRAL_RESOLVE
    var cur_speed := state.speed()
    var accelerating := resolving and cur_speed < order.target_speed - 0.2
    for fx in _thruster_lights:
        fx.visible = accelerating or (resolving and cur_speed > 1.0)

func _build_detailed_ship_model() -> void:
    if _model_root != null:
        _model_root.queue_free()
    _model_root = Node3D.new()
    _model_root.name = "ShipVisual"
    add_child(_model_root)
    _thruster_lights.clear()

    match faction:
        "acero":
            _build_acero_model()
        "vinculados":
            _build_vinculados_model()
        "marea_libre":
            _build_marea_model()
        _:
            _build_acero_model()

func _build_acero_model() -> void:
    var hull_mat := StandardMaterial3D.new()
    hull_mat.albedo_color = Color(0.22, 0.24, 0.28)
    hull_mat.metallic = 0.85
    hull_mat.roughness = 0.32

    var armor_mat := StandardMaterial3D.new()
    armor_mat.albedo_color = Color(0.35, 0.38, 0.42)
    armor_mat.metallic = 0.9
    armor_mat.roughness = 0.25

    var engine_mat := StandardMaterial3D.new()
    engine_mat.albedo_color = Color(1.0, 0.5, 0.1)
    engine_mat.emission_enabled = true
    engine_mat.emission = Color(1.0, 0.45, 0.08) * 3.5

    var main_hull := MeshInstance3D.new()
    var hull_box := BoxMesh.new()
    hull_box.size = body_size
    main_hull.mesh = hull_box
    main_hull.material_override = hull_mat
    _model_root.add_child(main_hull)

    var citadel := MeshInstance3D.new()
    var citadel_box := BoxMesh.new()
    citadel_box.size = Vector3(body_size.x * 0.55, body_size.y * 0.9, body_size.z * 0.4)
    citadel.mesh = citadel_box
    citadel.position = Vector3(0.0, body_size.y * 0.8, body_size.z * 0.1)
    citadel.material_override = armor_mat
    _model_root.add_child(citadel)

    var prow := MeshInstance3D.new()
    var prow_prism := PrismMesh.new()
    prow_prism.size = Vector3(body_size.x * 0.95, body_size.y * 0.85, body_size.z * 0.45)
    prow.mesh = prow_prism
    prow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    prow.position = Vector3(0.0, 0.0, -body_size.z * 0.65)
    prow.material_override = armor_mat
    _model_root.add_child(prow)

    for side in [-1.0, 1.0]:
        var cannon := MeshInstance3D.new()
        var barrel := CylinderMesh.new()
        barrel.top_radius = 0.15
        barrel.bottom_radius = 0.18
        barrel.height = body_size.z * 0.5
        cannon.mesh = barrel
        cannon.rotation_degrees = Vector3(90.0, 0.0, 0.0)
        cannon.position = Vector3(side * (body_size.x * 0.4), body_size.y * 0.2, -body_size.z * 0.5)
        cannon.material_override = hull_mat
        _model_root.add_child(cannon)

        var nozzle := MeshInstance3D.new()
        var nozzle_mesh := CylinderMesh.new()
        nozzle_mesh.top_radius = 0.35
        nozzle_mesh.bottom_radius = 0.45
        nozzle_mesh.height = 0.8
        nozzle.mesh = nozzle_mesh
        nozzle.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
        nozzle.position = Vector3(side * (body_size.x * 0.35), 0.0, body_size.z * 0.52)
        nozzle.material_override = engine_mat
        _model_root.add_child(nozzle)
        _thruster_lights.append(nozzle)

func _build_vinculados_model() -> void:
    var ceramic_mat := StandardMaterial3D.new()
    ceramic_mat.albedo_color = Color(0.92, 0.95, 0.98)
    ceramic_mat.metallic = 0.15
    ceramic_mat.roughness = 0.15

    var core_mat := StandardMaterial3D.new()
    core_mat.albedo_color = Color(0.95, 0.25, 0.9)
    core_mat.emission_enabled = true
    core_mat.emission = Color(0.95, 0.20, 0.85) * 4.0

    var joint_mat := StandardMaterial3D.new()
    joint_mat.albedo_color = Color(0.12, 0.14, 0.18)
    joint_mat.metallic = 0.8
    joint_mat.roughness = 0.4

    var torso := MeshInstance3D.new()
    var torso_mesh := BoxMesh.new()
    torso_mesh.size = Vector3(body_size.x * 0.7, body_size.y * 0.9, body_size.z * 0.6)
    torso.mesh = torso_mesh
    torso.material_override = ceramic_mat
    _model_root.add_child(torso)

    var core := MeshInstance3D.new()
    var core_sphere := SphereMesh.new()
    core_sphere.radius = 0.45
    core_sphere.height = 0.9
    core.mesh = core_sphere
    core.position = Vector3(0.0, body_size.y * 0.15, -body_size.z * 0.05)
    core.material_override = core_mat
    _model_root.add_child(core)

    var head := MeshInstance3D.new()
    var head_mesh := BoxMesh.new()
    head_mesh.size = Vector3(0.6, 0.6, 0.9)
    head.mesh = head_mesh
    head.position = Vector3(0.0, body_size.y * 0.6, -body_size.z * 0.35)
    head.material_override = ceramic_mat
    _model_root.add_child(head)

    for side in [-1.0, 1.0]:
        var wing := MeshInstance3D.new()
        var wing_mesh := PrismMesh.new()
        wing_mesh.size = Vector3(body_size.x * 0.8, body_size.y * 1.5, 0.15)
        wing.mesh = wing_mesh
        wing.rotation_degrees = Vector3(0.0, side * 15.0, side * -35.0)
        wing.position = Vector3(side * (body_size.x * 0.8), body_size.y * 0.3, body_size.z * 0.1)
        wing.material_override = ceramic_mat
        _model_root.add_child(wing)

        var vernier := MeshInstance3D.new()
        var vernier_mesh := CylinderMesh.new()
        vernier_mesh.top_radius = 0.2
        vernier_mesh.bottom_radius = 0.3
        vernier_mesh.height = 0.6
        vernier.mesh = vernier_mesh
        vernier.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
        vernier.position = Vector3(side * (body_size.x * 0.3), -body_size.y * 0.2, body_size.z * 0.4)
        vernier.material_override = core_mat
        _model_root.add_child(vernier)
        _thruster_lights.append(vernier)

func _build_marea_model() -> void:
    var wood_mat := StandardMaterial3D.new()
    wood_mat.albedo_color = Color(0.42, 0.25, 0.14)
    wood_mat.roughness = 0.7

    var brass_mat := StandardMaterial3D.new()
    brass_mat.albedo_color = Color(0.85, 0.70, 0.25)
    brass_mat.metallic = 0.9
    brass_mat.roughness = 0.3

    var sail_mat := StandardMaterial3D.new()
    sail_mat.albedo_color = Color(0.2, 0.85, 0.95, 0.65)
    sail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sail_mat.emission_enabled = true
    sail_mat.emission = Color(0.1, 0.5, 0.6)

    var hull := MeshInstance3D.new()
    var hull_box := BoxMesh.new()
    hull_box.size = Vector3(body_size.x * 0.8, body_size.y * 0.9, body_size.z)
    hull.mesh = hull_box
    hull.material_override = wood_mat
    _model_root.add_child(hull)

    for side in [-1.0, 1.0]:
        var sail := MeshInstance3D.new()
        var sail_plane := QuadMesh.new()
        sail_plane.size = Vector2(body_size.x * 1.8, body_size.y * 2.2)
        sail.mesh = sail_plane
        sail.rotation_degrees = Vector3(0.0, side * 30.0, 0.0)
        sail.position = Vector3(side * (body_size.x * 1.4), body_size.y * 0.6, 0.0)
        sail.material_override = sail_mat
        _model_root.add_child(sail)

func _build_tactical_indicators() -> void:
    _velocity_arrow = _create_arrow_mesh(Color(0.2, 0.95, 1.0), "VelArrow")
    add_child(_velocity_arrow)
    _velocity_label = _create_billboard_label(_velocity_arrow, Color(0.25, 0.95, 1.0))

    _order_arrow = _create_arrow_mesh(Color(1.0, 0.80, 0.2), "OrderArrow")
    add_child(_order_arrow)
    _order_label = _create_billboard_label(_order_arrow, Color(1.0, 0.85, 0.25))

    _rebuild_firing_arc()
    _build_selection_ring()

func _create_arrow_mesh(color: Color, node_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = node_name
    root.top_level = true

    var shaft := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.08
    cyl.bottom_radius = 0.08
    cyl.height = 1.0
    shaft.mesh = cyl
    shaft.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    shaft.position = Vector3(0.0, 0.0, -0.5)

    var head := MeshInstance3D.new()
    var cone := CylinderMesh.new()
    cone.top_radius = 0.0
    cone.bottom_radius = 0.28
    cone.height = 0.65
    head.mesh = cone
    head.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
    head.position = Vector3(0.0, 0.0, -1.0)

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color * 1.5

    shaft.material_override = mat
    head.material_override = mat

    root.add_child(shaft)
    root.add_child(head)
    root.visible = false
    return root

func _create_billboard_label(parent: Node3D, color: Color) -> Label3D:
    var label := Label3D.new()
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 13
    label.position = Vector3(0.0, 0.6, -1.2)
    label.modulate = color
    label.outline_modulate = Color(0.02, 0.04, 0.08, 0.95)
    label.outline_size = 2
    parent.add_child(label)
    return label

func _rebuild_firing_arc() -> void:
    if _firing_arc_instance != null:
        _firing_arc_instance.queue_free()

    var half_angle := deg_to_rad(weapon_arc_degrees * 0.5)
    var segments := 24
    var vertices := PackedVector3Array()

    for i in range(segments):
        var a1 := -half_angle + (float(i) / float(segments)) * (half_angle * 2.0)
        var a2 := -half_angle + (float(i + 1) / float(segments)) * (half_angle * 2.0)
        var p1 := Vector3(sin(a1) * weapon_range, 0.0, -cos(a1) * weapon_range)
        var p2 := Vector3(sin(a2) * weapon_range, 0.0, -cos(a2) * weapon_range)
        vertices.push_back(Vector3.ZERO)
        vertices.push_back(p1)
        vertices.push_back(p2)

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

    _firing_arc_instance = MeshInstance3D.new()
    _firing_arc_instance.mesh = mesh

    _firing_arc_material = StandardMaterial3D.new()
    _firing_arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _firing_arc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _firing_arc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _firing_arc_material.albedo_color = Color(0.2, 0.7, 0.9, 0.18) if team == 0 else Color(1.0, 0.4, 0.2, 0.18)
    _firing_arc_instance.material_override = _firing_arc_material
    _firing_arc_instance.visible = false
    add_child(_firing_arc_instance)

func _build_selection_ring() -> void:
    _selection_ring = MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = body_size.length() * 0.7
    torus.outer_radius = body_size.length() * 0.8
    torus.rings = 32
    _selection_ring.mesh = torus

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.3, 0.9, 1.0, 0.85)
    _selection_ring.material_override = mat
    _selection_ring.visible = false
    add_child(_selection_ring)

func _build_overhead_hud() -> void:
    _overhead_hud = Node3D.new()
    _overhead_hud.position = Vector3(0.0, body_size.y * 1.8 + 1.0, 0.0)
    add_child(_overhead_hud)

    _overhead_name = Label3D.new()
    _overhead_name.text = ship_name
    _overhead_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _overhead_name.font_size = 14
    _overhead_name.modulate = Color(0.35, 0.85, 1.0) if team == 0 else Color(1.0, 0.45, 0.35)
    _overhead_name.outline_modulate = Color(0.01, 0.02, 0.06, 0.95)
    _overhead_name.outline_size = 2
    _overhead_name.position = Vector3(0.0, 0.4, 0.0)
    _overhead_hud.add_child(_overhead_name)

    var hp_bg := MeshInstance3D.new()
    var bg_mesh := BoxMesh.new()
    bg_mesh.size = Vector3(2.6, 0.15, 0.05)
    hp_bg.mesh = bg_mesh
    var bg_mat := StandardMaterial3D.new()
    bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bg_mat.albedo_color = Color(0.05, 0.08, 0.12, 0.85)
    hp_bg.material_override = bg_mat
    _overhead_hud.add_child(hp_bg)

    _overhead_hp_bar = MeshInstance3D.new()
    var bar_mesh := BoxMesh.new()
    bar_mesh.size = Vector3(2.5, 0.12, 0.06)
    _overhead_hp_bar.mesh = bar_mesh
    var bar_mat := StandardMaterial3D.new()
    bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bar_mat.albedo_color = Color(0.2, 0.9, 0.4)
    _overhead_hp_bar.material_override = bar_mat
    _overhead_hud.add_child(_overhead_hp_bar)

func _build_click_detection() -> void:
    var area := Area3D.new()
    area.name = "ClickArea"
    var coll := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(body_size.x * 2.5, body_size.y * 3.0, body_size.z * 1.8)
    coll.shape = box
    area.add_child(coll)
    area.input_event.connect(_on_area_input_event)
    add_child(area)

func _on_area_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        clicked.emit(self)
