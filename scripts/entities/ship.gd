class_name Ship
extends Node3D

signal clicked(ship: Ship)
signal right_clicked(ship: Ship)

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
var pilot_name: String = ""
var ship_id: String = ""
var faction: String = "acero"
var max_hp: float = 100.0
var shield_hp: float = 100.0
var max_shield_hp: float = 100.0
var armor_bow: float = 100.0
var armor_port: float = 88.0
var armor_stbd: float = 88.0
var armor_stern: float = 65.0
var unit_code: String = "UNIT_01"
var use_2d_callout: bool = true

var is_evading: bool = false
var is_animating_burn: bool = false
var _burn_time_left: float = 0.0
var _burn_total_time: float = 0.0
var _burn_sim_duration: float = 0.0
var _burn_callback: Callable = Callable()
var state: ShipState
var order: ShipOrder
var ether: EtherField = null

var _model_root: Node3D
var _velocity_arrow: Node3D
var _velocity_label: Label3D
var _order_arrow: Node3D
var _order_label: Label3D
var _firing_arc_instance: MeshInstance3D
var _firing_arc_lines: MeshInstance3D
var _firing_arc_material: StandardMaterial3D
var _overhead_hud: Node3D
var _overhead_hp_bar: MeshInstance3D
var _overhead_name: Label3D
var _selection_ring: Node3D
var _broadside_brackets: MeshInstance3D
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
    max_shield_hp = hp * 0.8
    shield_hp = max_shield_hp
    order = ShipOrder.new()

    _build_detailed_ship_model()
    _build_tactical_indicators()
    _build_overhead_hud()
    _build_click_detection()

func apply_def(def: ShipDef) -> void:
    ship_id = def.id
    ship_name = def.display_name
    pilot_name = def.pilot_name
    faction = def.faction
    mass = def.mass
    max_thrust = def.max_thrust
    brake_thrust = def.brake_thrust
    turn_power = def.turn_power
    max_speed = def.max_speed
    hp = def.hp
    max_hp = def.hp
    max_shield_hp = def.hp * 0.8
    shield_hp = max_shield_hp
    weapon_range = def.weapon_range
    weapon_damage = def.weapon_damage
    weapon_arc_degrees = def.weapon_arc_degrees
    ship_color = def.color
    body_size = def.body_size

    match ship_id:
        "vinculados_suit":
            unit_code = "VINC_ACE_01"
            armor_bow = 92.0
            armor_port = 78.0
            armor_stbd = 78.0
            armor_stern = 64.0
        "vinculados_anima":
            unit_code = "VINC_ANM_02"
            armor_bow = 86.0
            armor_port = 74.0
            armor_stbd = 74.0
            armor_stern = 60.0
        "marea_galleon":
            unit_code = "MAREA_GAL_03"
            armor_bow = 95.0
            armor_port = 92.0
            armor_stbd = 92.0
            armor_stern = 70.0
        "acero_dreadnought":
            unit_code = "ACER_ANS_01"
            armor_bow = 100.0
            armor_port = 88.0
            armor_stbd = 88.0
            armor_stern = 65.0
        "acero_corvette":
            unit_code = "DIRK_CRU_04"
            armor_bow = 85.0
            armor_port = 72.0
            armor_stbd = 72.0
            armor_stern = 55.0
        _:
            unit_code = ship_id.to_upper()

    if is_inside_tree():
        _build_detailed_ship_model()
        _rebuild_firing_arc()
        if _overhead_name != null:
            if pilot_name != "":
                _overhead_name.text = "%s\n[%s]" % [ship_name, pilot_name]
            else:
                _overhead_name.text = ship_name

func speed() -> float:
    return state.speed()

func shield_pct() -> int:
    if max_shield_hp <= 0.0:
        return 0
    return clampi(roundi((shield_hp / max_shield_hp) * 100.0), 0, 100)

func hull_pct() -> int:
    if max_hp <= 0.0:
        return 0
    return clampi(roundi((hp / max_hp) * 100.0), 0, 100)

func take_damage(amount: float) -> void:
    take_directional_damage(amount, "BOW")

func take_directional_damage(amount: float, quadrant: String) -> void:
    var shield_absorb := minf(shield_hp, amount * 0.50)
    shield_hp = maxf(shield_hp - shield_absorb, 0.0)
    var hull_dmg := amount - shield_absorb * 0.45
    hp = maxf(hp - hull_dmg, 0.0)

    var sector_drop := clampf((amount / maxf(max_hp, 1.0)) * 95.0, 6.0, 42.0)
    match quadrant:
        "BOW":
            armor_bow = maxf(armor_bow - sector_drop * 0.75, 5.0)
        "PORT":
            armor_port = maxf(armor_port - sector_drop, 5.0)
        "STARBOARD":
            armor_stbd = maxf(armor_stbd - sector_drop, 5.0)
        "STERN":
            armor_stern = maxf(armor_stern - sector_drop * 1.25, 0.0)

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

func start_smooth_burn(sim_duration: float, anim_time: float = 0.65, on_complete: Callable = Callable()) -> void:
    is_animating_burn = true
    _burn_sim_duration = sim_duration
    _burn_total_time = maxf(anim_time, 0.05)
    _burn_time_left = _burn_total_time
    _burn_callback = on_complete
    AudioManager.play_sfx("engine", -10.0)

func _process(delta: float) -> void:
    if is_animating_burn:
        var dt := delta * (_burn_sim_duration / _burn_total_time)
        PhysicsSim.step_state(state, order, dt, ether)
        _sync_transform()
        _burn_time_left -= delta
        if _burn_time_left <= 0.0:
            is_animating_burn = false
            var cb := _burn_callback
            _burn_callback = Callable()
            if cb.is_valid():
                cb.call()

enum Stance { FIRE, EVASIVE, FLANK }
var stance: Stance = Stance.FIRE
var target_ship: Ship = null

func _physics_process(delta: float) -> void:
    if is_destroyed():
        return
    if TurnManager.is_resolving():
        var sim_delta := delta * PhysicsSim.time_scale
        PhysicsSim.apply_order(state, order, sim_delta, ether)
        _sync_transform()
    update_indicators()

func _sync_transform() -> void:
    global_position = state.position
    if state.forward.length_squared() > 0.0001:
        var up := Vector3.UP
        if absf(state.forward.dot(Vector3.UP)) > 0.90:
            up = Vector3.BACK if state.forward.y > 0.0 else Vector3.FORWARD
        look_at(global_position + state.forward, up)

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
    var is_vis := cur_speed > 0.35 and (TurnManager.is_in_ace() or selected)
    _velocity_arrow.visible = is_vis
    if is_vis:
        _velocity_arrow.global_position = global_position
        var vel_norm := state.velocity.normalized()
        var arrow_len := clampf(cur_speed * 1.15, 4.5, 22.0)
        var up := Vector3.UP if absf(vel_norm.dot(Vector3.UP)) < 0.90 else Vector3.RIGHT
        _velocity_arrow.look_at(global_position + vel_norm, up)
        _velocity_arrow.scale = Vector3(1.15, 1.0, arrow_len)
        if _velocity_label != null:
            _velocity_label.visible = selected
            _velocity_label.text = "DRIFT %.1f m/s" % cur_speed

func _update_order_arrow() -> void:
    if _order_arrow == null:
        return
    var planning := not TurnManager.is_resolving()
    # In Admiral Phase, show golden-yellow vector arrows on ALL allied ships (just like admiral-phase.png!)
    var is_vis := planning and (selected or (team == 0 and not TurnManager.is_in_ace()))
    _order_arrow.visible = is_vis
    if is_vis:
        _order_arrow.global_position = global_position
        var heading := order.heading()
        var base_len := maxf(order.target_speed * 1.35, 4.5)
        var arrow_len := clampf(base_len, 4.5, 26.0)
        var up := Vector3.UP if absf(heading.dot(Vector3.UP)) < 0.90 else Vector3.RIGHT
        _order_arrow.look_at(global_position + heading, up)
        var width_scale := 1.35 if selected else 0.95
        _order_arrow.scale = Vector3(width_scale, 1.0, arrow_len)
        if _order_label != null:
            _order_label.visible = selected
            if order.target_speed < 0.1:
                _order_label.text = "STOPPED [0 m/s]"
            else:
                _order_label.text = "VEC %.1f m/s" % order.target_speed

func _update_firing_arc() -> void:
    if _firing_arc_instance == null:
        return
    var planning := not TurnManager.is_resolving()
    _firing_arc_instance.visible = selected and planning

func _update_selection_visuals() -> void:
    if _selection_ring != null:
        _selection_ring.visible = selected and not is_destroyed()
        if _selection_ring.visible:
            _selection_ring.rotate_y(0.008)
    if _broadside_brackets != null:
        _broadside_brackets.visible = not is_destroyed()
    if _overhead_hud != null:
        _overhead_hud.visible = (not use_2d_callout) and (not is_destroyed())

func _update_overhead_hp() -> void:
    if _overhead_hp_bar == null:
        return
    var ratio := clampf(hp / max_hp, 0.0, 1.0)
    _overhead_hp_bar.scale = Vector3(ratio, 1.0, 1.0)

func _update_thruster_fx() -> void:
    var resolving := TurnManager.is_resolving()
    var cur_speed := state.speed()
    var accelerating := (resolving and cur_speed < order.target_speed - 0.2) or is_animating_burn
    for fx in _thruster_lights:
        fx.visible = accelerating or (resolving and cur_speed > 1.0) or (not resolving and order.target_speed > 1.0)

func _build_detailed_ship_model() -> void:
    if _model_root != null:
        _model_root.queue_free()
    _model_root = Node3D.new()
    _model_root.name = "ShipVisual"
    add_child(_model_root)
    _thruster_lights.clear()

    ShipModelBuilder.build(self, _model_root, _thruster_lights)

func _build_tactical_indicators() -> void:
    # 1. Velocity / Drift Arrow (Glowing Cyan like ace-phase.png)
    _velocity_arrow = _create_arrow_mesh(
        Color(0.22, 0.88, 1.0, 0.72),
        Color(0.55, 0.96, 1.0, 0.98),
        "VelArrow"
    )
    add_child(_velocity_arrow)
    _velocity_label = _create_billboard_label(_velocity_arrow, Color(0.4, 0.95, 1.0))

    # 2. Plotted Command Vector Arrow (Golden-Yellow with bright border like admiral-phase.png)
    _order_arrow = _create_arrow_mesh(
        Color(0.96, 0.78, 0.18, 0.68),
        Color(1.0, 0.92, 0.45, 0.98),
        "OrderArrow"
    )
    add_child(_order_arrow)
    _order_label = _create_billboard_label(_order_arrow, Color(1.0, 0.90, 0.35))

    _rebuild_firing_arc()
    _build_selection_ring()

func _create_arrow_mesh(fill_color: Color, rim_color: Color, node_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = node_name
    root.top_level = true

    # Flat wide tactical ribbon shaft + chevron head along -Z (from 0.0 to -1.0)
    var verts := PackedVector3Array([
        # Shaft quad (z from -0.08 to -0.78, width +/- 0.18)
        Vector3(-0.18, 0.02, -0.08), Vector3(0.18, 0.02, -0.08), Vector3(0.18, 0.02, -0.78),
        Vector3(-0.18, 0.02, -0.08), Vector3(0.18, 0.02, -0.78), Vector3(-0.18, 0.02, -0.78),
        # Arrowhead triangle (z from -0.76 to -1.0, width +/- 0.44)
        Vector3(-0.44, 0.02, -0.76), Vector3(0.44, 0.02, -0.76), Vector3(0.0, 0.02, -1.0)
    ])
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = verts
    var fill_mesh := ArrayMesh.new()
    fill_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

    var fill_inst := MeshInstance3D.new()
    fill_inst.mesh = fill_mesh
    var fill_mat := StandardMaterial3D.new()
    fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    fill_mat.albedo_color = fill_color
    fill_mat.emission_enabled = true
    fill_mat.emission = Color(fill_color.r, fill_color.g, fill_color.b) * 1.1
    fill_inst.material_override = fill_mat
    root.add_child(fill_inst)

    # Glowing crisp outline around the tactical arrow (matches admiral-phase.png vector arrows)
    var line_verts := PackedVector3Array([
        Vector3(-0.18, 0.03, -0.08), Vector3(-0.18, 0.03, -0.76),
        Vector3(-0.18, 0.03, -0.76), Vector3(-0.44, 0.03, -0.76),
        Vector3(-0.44, 0.03, -0.76), Vector3(0.0, 0.03, -1.0),
        Vector3(0.0, 0.03, -1.0), Vector3(0.44, 0.03, -0.76),
        Vector3(0.44, 0.03, -0.76), Vector3(0.18, 0.03, -0.76),
        Vector3(0.18, 0.03, -0.76), Vector3(0.18, 0.03, -0.08),
        Vector3(0.18, 0.03, -0.08), Vector3(-0.18, 0.03, -0.08)
    ])
    var line_arr := []
    line_arr.resize(Mesh.ARRAY_MAX)
    line_arr[Mesh.ARRAY_VERTEX] = line_verts
    var rim_mesh := ArrayMesh.new()
    rim_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arr)

    var rim_inst := MeshInstance3D.new()
    rim_inst.mesh = rim_mesh
    var rim_mat := StandardMaterial3D.new()
    rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    rim_mat.albedo_color = rim_color
    rim_mat.emission_enabled = true
    rim_mat.emission = Color(rim_color.r, rim_color.g, rim_color.b) * 1.8
    rim_inst.material_override = rim_mat
    root.add_child(rim_inst)

    root.visible = false
    return root

func _create_billboard_label(parent: Node3D, color: Color) -> Label3D:
    var label := Label3D.new()
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 12
    label.position = Vector3(0.0, 0.55, -1.05)
    label.modulate = color
    label.outline_modulate = Color(0.02, 0.04, 0.08, 0.95)
    label.outline_size = 2
    parent.add_child(label)
    return label

func _rebuild_firing_arc() -> void:
    if _firing_arc_instance != null:
        _firing_arc_instance.queue_free()

    # Cone-shaped firing-arc overlay matching ace-phase.png:
    # 1. Translucent cyan cone surface
    # 2. Inner range arc (58% range) + outer range arc (100% range) + side boundary lines
    # 3. Central bearing arrow inside the cone
    var half_angle := deg_to_rad(weapon_arc_degrees * 0.5)
    var segments := 32
    var vertices := PackedVector3Array()
    var line_verts := PackedVector3Array()

    var inner_r := weapon_range * 0.58

    # Left & Right boundary rays
    var left_end := Vector3(sin(-half_angle) * weapon_range, 0.02, -cos(-half_angle) * weapon_range)
    var right_end := Vector3(sin(half_angle) * weapon_range, 0.02, -cos(half_angle) * weapon_range)
    line_verts.push_back(Vector3(0.0, 0.02, 0.0))
    line_verts.push_back(left_end)
    line_verts.push_back(Vector3(0.0, 0.02, 0.0))
    line_verts.push_back(right_end)

    # Central bearing arrow inside firing cone (like ace-phase.png)
    var center_end := Vector3(0.0, 0.03, -weapon_range * 0.96)
    line_verts.push_back(Vector3(0.0, 0.03, 0.0))
    line_verts.push_back(center_end)
    line_verts.push_back(center_end)
    line_verts.push_back(center_end + Vector3(-1.1, 0.0, 2.2))
    line_verts.push_back(center_end)
    line_verts.push_back(center_end + Vector3(1.1, 0.0, 2.2))

    for i in range(segments):
        var a1 := -half_angle + (float(i) / float(segments)) * (half_angle * 2.0)
        var a2 := -half_angle + (float(i + 1) / float(segments)) * (half_angle * 2.0)
        var p1 := Vector3(sin(a1) * weapon_range, 0.0, -cos(a1) * weapon_range)
        var p2 := Vector3(sin(a2) * weapon_range, 0.0, -cos(a2) * weapon_range)
        vertices.push_back(Vector3.ZERO)
        vertices.push_back(p1)
        vertices.push_back(p2)

        # Outer arc line segment
        line_verts.push_back(p1 + Vector3(0.0, 0.02, 0.0))
        line_verts.push_back(p2 + Vector3(0.0, 0.02, 0.0))

        # Inner mid-range arc line segment (like ace-phase.png)
        var ip1 := Vector3(sin(a1) * inner_r, 0.02, -cos(a1) * inner_r)
        var ip2 := Vector3(sin(a2) * inner_r, 0.02, -cos(a2) * inner_r)
        line_verts.push_back(ip1)
        line_verts.push_back(ip2)

    # For Free Tide Galleon & Acero Dreadnought, also draw the Port & Starboard Broadside Firing Cones (exact ace-phase.png broadside fan!)
    if faction == "marea_libre" or ship_id == "acero_dreadnought":
        var bs_range := weapon_range * 0.88
        var bs_inner := bs_range * 0.56
        for side in [-1.0, 1.0]:
            var mid_ang := deg_to_rad(side * 90.0)
            var bs_half := deg_to_rad(36.0)
            var b_left := Vector3(sin(mid_ang - bs_half) * bs_range, 0.02, -cos(mid_ang - bs_half) * bs_range)
            var b_right := Vector3(sin(mid_ang + bs_half) * bs_range, 0.02, -cos(mid_ang + bs_half) * bs_range)
            var b_center := Vector3(sin(mid_ang) * bs_range * 0.96, 0.03, -cos(mid_ang) * bs_range * 0.96)
            line_verts.push_back(Vector3(0.0, 0.02, 0.0))
            line_verts.push_back(b_left)
            line_verts.push_back(Vector3(0.0, 0.02, 0.0))
            line_verts.push_back(b_right)
            line_verts.push_back(Vector3(0.0, 0.03, 0.0))
            line_verts.push_back(b_center)

            for j in range(16):
                var ba1 := (mid_ang - bs_half) + (float(j) / 16.0) * (bs_half * 2.0)
                var ba2 := (mid_ang - bs_half) + (float(j + 1) / 16.0) * (bs_half * 2.0)
                var bp1 := Vector3(sin(ba1) * bs_range, 0.0, -cos(ba1) * bs_range)
                var bp2 := Vector3(sin(ba2) * bs_range, 0.0, -cos(ba2) * bs_range)
                vertices.push_back(Vector3.ZERO)
                vertices.push_back(bp1)
                vertices.push_back(bp2)

                line_verts.push_back(bp1 + Vector3(0.0, 0.02, 0.0))
                line_verts.push_back(bp2 + Vector3(0.0, 0.02, 0.0))
                var bip1 := Vector3(sin(ba1) * bs_inner, 0.02, -cos(ba1) * bs_inner)
                var bip2 := Vector3(sin(ba2) * bs_inner, 0.02, -cos(ba2) * bs_inner)
                line_verts.push_back(bip1)
                line_verts.push_back(bip2)


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
    _firing_arc_material.albedo_color = Color(0.22, 0.82, 0.98, 0.16) if team == 0 else Color(1.0, 0.42, 0.22, 0.16)
    _firing_arc_instance.material_override = _firing_arc_material
    _firing_arc_instance.visible = false
    add_child(_firing_arc_instance)

    var line_arrays := []
    line_arrays.resize(Mesh.ARRAY_MAX)
    line_arrays[Mesh.ARRAY_VERTEX] = line_verts
    var line_mesh := ArrayMesh.new()
    line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)

    _firing_arc_lines = MeshInstance3D.new()
    _firing_arc_lines.mesh = line_mesh
    var line_mat := StandardMaterial3D.new()
    line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    line_mat.albedo_color = Color(0.35, 0.92, 1.0, 0.72) if team == 0 else Color(1.0, 0.55, 0.3, 0.72)
    line_mat.emission_enabled = true
    line_mat.emission = Color(0.25, 0.85, 1.0) if team == 0 else Color(1.0, 0.4, 0.2)
    _firing_arc_lines.material_override = line_mat
    _firing_arc_instance.add_child(_firing_arc_lines)

func _build_selection_ring() -> void:
    if _selection_ring != null:
        _selection_ring.queue_free()
    if _broadside_brackets != null:
        _broadside_brackets.queue_free()

    var base_r := maxf(body_size.length() * 0.62, 3.2)

    # 1. Broadside Sector Arc Brackets around EVERY ship (matches the red/orange curved brackets in admiral-phase.png!)
    _broadside_brackets = MeshInstance3D.new()
    var br_verts := PackedVector3Array()
    var br_lines := PackedVector3Array()
    var r_in := base_r * 1.02
    var r_out := base_r * 1.18
    var segs := 16

    # Port bracket (angles 35° to 145°) & Starboard bracket (angles -145° to -35°)
    for side in [-1.0, 1.0]:
        for i in range(segs):
            var a1 := deg_to_rad(side * (35.0 + (float(i) / float(segs)) * 110.0))
            var a2 := deg_to_rad(side * (35.0 + (float(i + 1) / float(segs)) * 110.0))
            var p1_in := Vector3(sin(a1) * r_in, -0.2, -cos(a1) * r_in)
            var p2_in := Vector3(sin(a2) * r_in, -0.2, -cos(a2) * r_in)
            var p1_out := Vector3(sin(a1) * r_out, -0.2, -cos(a1) * r_out)
            var p2_out := Vector3(sin(a2) * r_out, -0.2, -cos(a2) * r_out)

            br_verts.push_back(p1_in)
            br_verts.push_back(p1_out)
            br_verts.push_back(p2_out)
            br_verts.push_back(p1_in)
            br_verts.push_back(p2_out)
            br_verts.push_back(p2_in)

            br_lines.push_back(p1_in)
            br_lines.push_back(p2_in)
            br_lines.push_back(p1_out)
            br_lines.push_back(p2_out)
            if i == 0:
                br_lines.push_back(p1_in)
                br_lines.push_back(p1_out)
            if i == segs - 1:
                br_lines.push_back(p2_in)
                br_lines.push_back(p2_out)

    var br_mesh := ArrayMesh.new()
    var br_arr := []
    br_arr.resize(Mesh.ARRAY_MAX)
    br_arr[Mesh.ARRAY_VERTEX] = br_verts
    br_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, br_arr)

    var br_mat := StandardMaterial3D.new()
    br_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    br_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    br_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    br_mat.albedo_color = Color(0.95, 0.32, 0.24, 0.22) if team == 0 else Color(1.0, 0.25, 0.18, 0.30)
    br_mesh.surface_set_material(0, br_mat)

    var br_line_arr := []
    br_line_arr.resize(Mesh.ARRAY_MAX)
    br_line_arr[Mesh.ARRAY_VERTEX] = br_lines
    br_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, br_line_arr)
    var br_line_mat := StandardMaterial3D.new()
    br_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    br_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    br_line_mat.albedo_color = Color(0.98, 0.42, 0.32, 0.72)
    br_line_mat.emission_enabled = true
    br_line_mat.emission = Color(0.95, 0.3, 0.2) * 0.9
    br_mesh.surface_set_material(1, br_line_mat)

    _broadside_brackets.mesh = br_mesh
    add_child(_broadside_brackets)

    # 2. Concentric Glowing Cyan Command Ring on Selected Ship (matches ACER_ANS_01 in admiral-phase.png)
    _selection_ring = Node3D.new()
    _selection_ring.visible = false
    add_child(_selection_ring)

    var ring1 := MeshInstance3D.new()
    var torus1 := TorusMesh.new()
    torus1.inner_radius = base_r * 0.82
    torus1.outer_radius = base_r * 0.92
    torus1.rings = 40
    ring1.mesh = torus1

    var ring2 := MeshInstance3D.new()
    var torus2 := TorusMesh.new()
    torus2.inner_radius = base_r * 1.24
    torus2.outer_radius = base_r * 1.32
    torus2.rings = 40
    ring2.mesh = torus2

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.25, 0.90, 1.0, 0.82)
    mat.emission_enabled = true
    mat.emission = Color(0.2, 0.8, 1.0) * 1.4
    ring1.material_override = mat
    ring2.material_override = mat
    _selection_ring.add_child(ring1)
    _selection_ring.add_child(ring2)

func _build_overhead_hud() -> void:
    _overhead_hud = Node3D.new()
    _overhead_hud.position = Vector3(0.0, body_size.y * 1.8 + 1.0, 0.0)
    _overhead_hud.visible = not use_2d_callout
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
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            clicked.emit(self)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            right_clicked.emit(self)

