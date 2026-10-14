class_name Ship
extends Node3D

const VELOCITY_ARROW_SCALE := 0.6

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

var ship_name: String = ""
var max_hp: float = 100.0
var state: ShipState
var order: ShipOrder
var ether: EtherField = null

var _ghost: MeshInstance3D
var _velocity_arrow: MeshInstance3D

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
    _build_placeholder_mesh()
    _build_ghost()
    _build_velocity_arrow()

func apply_def(def: ShipDef) -> void:
    ship_name = def.display_name
    mass = def.mass
    max_thrust = def.max_thrust
    brake_thrust = def.brake_thrust
    turn_power = def.turn_power
    max_speed = def.max_speed
    hp = def.hp
    weapon_range = def.weapon_range
    weapon_damage = def.weapon_damage
    weapon_arc_degrees = def.weapon_arc_degrees
    ship_color = def.color
    body_size = def.body_size

func speed() -> float:
    return state.speed()

func take_damage(amount: float) -> void:
    hp = maxf(hp - amount, 0.0)
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

func update_indicators() -> void:
    _update_ghost()
    _update_velocity_arrow()

func _update_ghost() -> void:
    if _ghost == null:
        return
    var planning := TurnManager.phase == TurnManager.Phase.ADMIRAL_PLAN or TurnManager.phase == TurnManager.Phase.ACE
    _ghost.visible = selected and planning
    if _ghost.visible:
        var direction := order.heading()
        var length := body_size.z * 1.4
        _ghost.global_position = global_position + direction * (length * 0.5)
        _ghost.quaternion = Quaternion(Vector3.UP, direction)

func _update_velocity_arrow() -> void:
    if _velocity_arrow == null:
        return
    var speed := state.speed()
    _velocity_arrow.visible = speed > 0.5
    if _velocity_arrow.visible:
        var direction := state.velocity.normalized()
        var length := speed * VELOCITY_ARROW_SCALE
        _velocity_arrow.global_position = global_position + direction * (length * 0.5)
        _velocity_arrow.quaternion = Quaternion(Vector3.UP, direction)
        _velocity_arrow.scale = Vector3(1.0, length, 1.0)

func _sync_transform() -> void:
    global_position = state.position
    if state.forward.length_squared() > 0.0:
        look_at(global_position + state.forward, Vector3.UP)

func _build_placeholder_mesh() -> void:
    var body := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = body_size
    box.material = _make_material(ship_color)
    body.mesh = box
    add_child(body)

    var nose := MeshInstance3D.new()
    var nose_mesh := SphereMesh.new()
    nose_mesh.radius = body_size.y * 0.4
    nose_mesh.height = body_size.y * 0.8
    nose_mesh.material = _make_material(ship_color.lightened(0.3))
    nose.mesh = nose_mesh
    nose.position = Vector3(0.0, 0.0, -body_size.z * 0.5)
    add_child(nose)

    var fin := MeshInstance3D.new()
    var fin_mesh := BoxMesh.new()
    fin_mesh.size = Vector3(0.1, body_size.y * 1.4, body_size.z * 0.5)
    fin_mesh.material = _make_material(ship_color.darkened(0.2))
    fin.mesh = fin_mesh
    fin.position = Vector3(0.0, body_size.y * 0.7, body_size.z * 0.25)
    add_child(fin)

func _build_ghost() -> void:
    var length := body_size.z * 1.4
    _ghost = _build_arrow(length, 0.05, Color(1.0, 0.85, 0.2))
    _ghost.visible = false
    add_child(_ghost)

func _build_velocity_arrow() -> void:
    _velocity_arrow = _build_arrow(1.0, 0.04, Color(0.2, 0.9, 0.9))
    _velocity_arrow.visible = false
    add_child(_velocity_arrow)

func _build_arrow(length: float, radius: float, color: Color) -> MeshInstance3D:
    var shaft := CylinderMesh.new()
    shaft.height = length
    shaft.top_radius = radius
    shaft.bottom_radius = radius
    shaft.material = _make_arrow_material(color)
    var arrow := MeshInstance3D.new()
    arrow.mesh = shaft
    return arrow

func _make_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    return material

func _make_arrow_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return material
