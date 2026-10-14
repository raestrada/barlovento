extends Node3D

const ETHER_GRID_SPAN := 100.0
const ETHER_GRID_STEP := 25.0

const TURN_SPEED := 1.5
const SPEED_STEP := 8.0
const ACE_AI_DELAY := 0.6
const ENGAGEMENT_RANGE := 60.0
const PITCH_LIMIT := 1.45

var _player_ships: Array[Ship] = []
var _enemy_ships: Array[Ship] = []
var _selected_ship: Ship
var _selected_index: int = 0

var _phase_label: Label
var _resolve_label: Label
var _resolve_bar: ProgressBar
var _status_label: Label
var _order_panel: OrderPanel
var _ace_panel: AcePanel
var _action_row: HBoxContainer
var _trajectory: TrajectoryPreview
var _tactical_plane: Node3D
var _hud_theme: Theme
var _help_overlay: Control

var _ace_target: Ship
var _ace_ai_timer: float = 0.0

func _ready() -> void:
    TurnManager.reset()
    _setup_input_actions()
    _build_environment()
    _build_starfield()

    AudioManager.play_music(-22.0)
    AudioManager.start_ambient(-28.0)

    var ether := EtherField.new()
    ether.direction = Vector3(1.0, 0.25, 0.3).normalized()
    ether.strength = 1.5
    ether.wavelength = 60.0
    _build_ether_visual(ether)

    _build_tactical_plane()

    _spawn_ships(ether)
    _build_trajectory_preview(ether)
    _build_camera()
    _build_hud()

    TurnManager.phase_changed.connect(_on_phase_changed)
    TurnManager.ace_activated.connect(_on_ace_activated)
    TurnManager.admiral_resolve_finished.connect(_on_admiral_resolve_finished)

func _physics_process(delta: float) -> void:
    match TurnManager.phase:
        TurnManager.Phase.ADMIRAL_PLAN:
            _handle_admiral_plan(delta)
        TurnManager.Phase.ACE:
            _handle_ace(delta)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.echo:
        return
    if not event.is_pressed():
        return

    if event.is_action_pressed("help"):
        _toggle_help()
        return
    if event.is_action_pressed("toggle_grid"):
        if _tactical_plane != null:
            _tactical_plane.visible = not _tactical_plane.visible
        return

    match TurnManager.phase:
        TurnManager.Phase.ADMIRAL_PLAN:
            if event.is_action_pressed("cycle"):
                _cycle_selection()
            elif event.is_action_pressed("stop"):
                _selected_ship.order.target_speed = 0.0
            elif event.is_action_pressed("resolve"):
                _plan_ai_orders()
                AudioManager.play_sfx("ui_click", -14.0)
                TurnManager.start_resolve()
        TurnManager.Phase.ACE:
            var active := TurnManager.ace_active()
            if active == null or active.team != 0:
                return
            if event.is_action_pressed("ace_move"):
                _ace_move(active)
            elif event.is_action_pressed("ace_cycle"):
                _ace_cycle_target(active)
            elif event.is_action_pressed("ace_shoot"):
                _ace_shoot(active)
            elif event.is_action_pressed("ace_end"):
                TurnManager.ace_skip_ship()

func _handle_admiral_plan(delta: float) -> void:
    _edit_selected_order(delta)

func _handle_ace(delta: float) -> void:
    var active := TurnManager.ace_active()
    if active == null:
        return
    if active.team == 1:
        _run_enemy_ace(active, delta)
    else:
        _handle_player_ace(active, delta)

func _handle_player_ace(active: Ship, delta: float) -> void:
    var order := active.order
    if Input.is_action_pressed("yaw_left"):
        order.yaw += TURN_SPEED * delta
    if Input.is_action_pressed("yaw_right"):
        order.yaw -= TURN_SPEED * delta
    if Input.is_action_pressed("pitch_up"):
        order.pitch = clampf(order.pitch + TURN_SPEED * delta, -PITCH_LIMIT, PITCH_LIMIT)
    if Input.is_action_pressed("pitch_down"):
        order.pitch = clampf(order.pitch - TURN_SPEED * delta, -PITCH_LIMIT, PITCH_LIMIT)
    if Input.is_action_pressed("move_forward"):
        order.target_speed = clampf(order.target_speed + SPEED_STEP * delta, 0.0, active.state.max_speed)
    if Input.is_action_pressed("move_back"):
        order.target_speed = clampf(order.target_speed - SPEED_STEP * delta, 0.0, active.state.max_speed)

func _run_enemy_ace(active: Ship, delta: float) -> void:
    _ace_ai_timer -= delta
    if _ace_ai_timer > 0.0:
        return
    _ace_ai_timer = ACE_AI_DELAY

    if TurnManager.ace_actions_left() <= 0:
        return

    var target := _pick_default_target(active)
    if target != null and Combat.can_hit(active, target):
        Combat.resolve_shot(active, target)
        TurnManager.ace_spend_action()
        return

    if target != null:
        var to_target := target.state.position - active.state.position
        if to_target.length() > 0.01:
            _set_order_heading(active, to_target.normalized())
        active.order.target_speed = active.state.max_speed * 0.6
    active.advance(TurnManager.ACE_MOVE_DURATION)
    TurnManager.ace_spend_action()

func _edit_selected_order(delta: float) -> void:
    var order := _selected_ship.order
    if Input.is_action_pressed("yaw_left"):
        order.yaw += TURN_SPEED * delta
    if Input.is_action_pressed("yaw_right"):
        order.yaw -= TURN_SPEED * delta
    if Input.is_action_pressed("pitch_up"):
        order.pitch = clampf(order.pitch + TURN_SPEED * delta, -PITCH_LIMIT, PITCH_LIMIT)
    if Input.is_action_pressed("pitch_down"):
        order.pitch = clampf(order.pitch - TURN_SPEED * delta, -PITCH_LIMIT, PITCH_LIMIT)
    if Input.is_action_pressed("move_forward"):
        order.target_speed = clampf(order.target_speed + SPEED_STEP * delta, 0.0, _selected_ship.state.max_speed)
    if Input.is_action_pressed("move_back"):
        order.target_speed = clampf(order.target_speed - SPEED_STEP * delta, 0.0, _selected_ship.state.max_speed)

func _cycle_selection() -> void:
    if _player_ships.is_empty():
        return
    for _attempt in range(_player_ships.size()):
        _selected_index = (_selected_index + 1) % _player_ships.size()
        if not _player_ships[_selected_index].is_destroyed():
            _set_selected(_player_ships[_selected_index])
            return

func _set_selected(ship: Ship) -> void:
    for candidate in _player_ships:
        candidate.selected = candidate == ship
    _selected_ship = ship
    if _order_panel != null:
        _order_panel.ship = ship

func _plan_ai_orders() -> void:
    for ship in _enemy_ships:
        if ship.is_destroyed():
            continue
        var target := _nearest_player_ship(ship)
        var to_target := target.state.position - ship.state.position
        if to_target.length() > 0.01:
            _set_order_heading(ship, to_target.normalized())
        ship.order.target_speed = ship.state.max_speed * 0.5

func _set_order_heading(ship: Ship, direction: Vector3) -> void:
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() < 0.0001:
        flat = Vector3.FORWARD
    flat = flat.normalized()
    ship.order.yaw = Vector3.FORWARD.signed_angle_to(flat, Vector3.UP)
    ship.order.pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT)

func _nearest_player_ship(ship: Ship) -> Ship:
    var best := _player_ships[0]
    var best_distance := INF
    for candidate in _player_ships:
        if candidate.is_destroyed():
            continue
        var distance := ship.state.position.distance_to(candidate.state.position)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    return best

func _pick_default_target(shooter: Ship) -> Ship:
    var enemies := _enemy_ships if shooter.team == 0 else _player_ships
    var best: Ship = null
    var best_distance := INF
    for candidate in enemies:
        if candidate.is_destroyed():
            continue
        var distance := shooter.state.position.distance_to(candidate.state.position)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    return best

func _ace_move(shooter: Ship) -> void:
    shooter.advance(TurnManager.ACE_MOVE_DURATION)
    TurnManager.ace_spend_action()

func _ace_shoot(shooter: Ship) -> void:
    if _ace_target != null and Combat.can_hit(shooter, _ace_target):
        Combat.resolve_shot(shooter, _ace_target)
    TurnManager.ace_spend_action()

func _ace_cycle_target(shooter: Ship) -> void:
    var enemies := _enemy_ships if shooter.team == 0 else _player_ships
    var alive: Array[Ship] = []
    for candidate in enemies:
        if not candidate.is_destroyed():
            alive.append(candidate)
    if alive.is_empty():
        _ace_target = null
    else:
        var index := alive.find(_ace_target)
        _ace_target = alive[(index + 1) % alive.size()]
    _ace_panel.target = _ace_target

func _setup_input_actions() -> void:
    _add_action("move_forward", [KEY_W, KEY_UP])
    _add_action("move_back", [KEY_S, KEY_DOWN])
    _add_action("yaw_left", [KEY_A, KEY_LEFT])
    _add_action("yaw_right", [KEY_D, KEY_RIGHT])
    _add_action("pitch_up", [KEY_Q])
    _add_action("pitch_down", [KEY_E])
    _add_action("resolve", [KEY_SPACE])
    _add_action("cycle", [KEY_TAB])
    _add_action("stop", [KEY_X])
    _add_action("ace_move", [KEY_M])
    _add_action("ace_shoot", [KEY_F])
    _add_action("ace_cycle", [KEY_C])
    _add_action("ace_end", [KEY_N])
    _add_action("help", [KEY_ESCAPE])
    _add_action("toggle_grid", [KEY_G])

func _add_action(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for key in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key
        InputMap.action_add_event(action, event)

func _build_environment() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
    sun.light_energy = 1.2
    sun.light_color = Color(1.0, 0.95, 0.85)
    add_child(sun)

    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.012, 0.018, 0.045)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.25, 0.30, 0.45)
    environment.ambient_light_energy = 1.0
    environment.glow_enabled = true
    environment.glow_intensity = 0.5
    environment.glow_bloom = 0.15
    world.environment = environment
    add_child(world)

func _build_starfield() -> void:
    _add_star_layer(1200, 400.0, 700.0, Color(0.9, 0.95, 1.0), 0.15, 0.5)
    _add_star_layer(220, 400.0, 700.0, Color(0.45, 0.9, 1.0), 0.3, 0.7)
    _add_star_layer(70, 400.0, 700.0, Color(1.0, 0.7, 0.4), 0.4, 0.9)

func _add_star_layer(count: int, min_radius: float, max_radius: float, color: Color, min_scale: float, max_scale: float) -> void:
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 4
    mesh.rings = 2
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.5
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material = material

    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = mesh
    multimesh.instance_count = count

    var rng := RandomNumberGenerator.new()
    rng.seed = 1337
    for i in range(count):
        var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
        var position := direction * rng.randf_range(min_radius, max_radius)
        var scale := rng.randf_range(min_scale, max_scale)
        var transform := Transform3D(Basis().scaled(Vector3.ONE * scale), position)
        multimesh.set_instance_transform(i, transform)

    var instance := MultiMeshInstance3D.new()
    instance.multimesh = multimesh
    add_child(instance)

func _build_ether_visual(ether: EtherField) -> void:
    var cone := CylinderMesh.new()
    cone.height = 2.0
    cone.top_radius = 0.0
    cone.bottom_radius = 0.5
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.3, 0.9, 0.9)
    material.emission_enabled = true
    material.emission = Color(0.1, 0.5, 0.5)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cone.material = material

    var steps := int(ETHER_GRID_SPAN / ETHER_GRID_STEP)
    var height_steps := 2
    for ix in range(-steps, steps + 1):
        for iz in range(-steps, steps + 1):
            for iy in range(-height_steps, height_steps + 1):
                var position := Vector3(ix * ETHER_GRID_STEP, iy * ETHER_GRID_STEP, iz * ETHER_GRID_STEP)
                var current := ether.current_at(position)
                if current.length() < 0.05:
                    continue
                var arrow := MeshInstance3D.new()
                arrow.mesh = cone
                arrow.position = position
                arrow.scale = Vector3.ONE * clamp(current.length(), 0.25, 1.0)
                arrow.quaternion = Quaternion(Vector3.UP, current.normalized())
                add_child(arrow)

func _build_tactical_plane() -> void:
    _tactical_plane = Node3D.new()
    _tactical_plane.name = "TacticalPlane"
    add_child(_tactical_plane)

    var half := 200.0
    var step := 20.0
    var vertices := PackedVector3Array()
    var steps := int(half / step)
    for i in range(-steps, steps + 1):
        var offset := i * step
        vertices.push_back(Vector3(offset, 0.0, -half))
        vertices.push_back(Vector3(offset, 0.0, half))
        vertices.push_back(Vector3(-half, 0.0, offset))
        vertices.push_back(Vector3(half, 0.0, offset))

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

    var lines := MeshInstance3D.new()
    lines.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.2, 0.5, 0.65, 0.35)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    lines.material_override = material
    _tactical_plane.add_child(lines)

func _spawn_ships(ether: EtherField) -> void:
    _player_ships.append(_spawn("vinculados_suit", Vector3(0.0, 12.0, 30.0), Vector3.ZERO, ether, 0))
    _player_ships.append(_spawn("vinculados_anima", Vector3(8.0, -8.0, 38.0), Vector3.ZERO, ether, 0))
    _enemy_ships.append(_spawn("acero_dreadnought", Vector3(-20.0, 20.0, -30.0), Vector3(8.0, 0.0, 4.0), ether, 1))
    _enemy_ships.append(_spawn("acero_corvette", Vector3(25.0, -14.0, -40.0), Vector3(-5.0, 0.0, 6.0), ether, 1))
    _set_selected(_player_ships[0])

func _spawn(id: String, position: Vector3, velocity: Vector3, ether: EtherField, team: int) -> Ship:
    var def := LoreDB.get_ship(id)
    var ship := Ship.new()
    ship.apply_def(def)
    ship.initial_velocity = velocity
    ship.position = position
    ship.team = team
    add_child(ship)
    ship.ether = ether
    return ship

func _build_trajectory_preview(ether: EtherField) -> void:
    _trajectory = TrajectoryPreview.new()
    _trajectory.ships = _player_ships
    _trajectory.ether = ether
    add_child(_trajectory)

func _build_camera() -> void:
    var rig := CameraRig.new()
    rig.target = Vector3(0.0, 0.0, 0.0)
    rig.distance = 60.0
    add_child(rig)

func _build_hud() -> void:
    _hud_theme = _make_theme()
    var layer := CanvasLayer.new()
    add_child(layer)

    var top := PanelContainer.new()
    top.theme = _hud_theme
    top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 8)
    layer.add_child(top)

    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 16)
    top.add_child(top_row)

    _phase_label = Label.new()
    _phase_label.add_theme_font_size_override("font_size", 20)
    _phase_label.add_theme_color_override("font_color", Color(0.65, 0.95, 1.0))
    top_row.add_child(_phase_label)

    var top_spacer := Control.new()
    top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(top_spacer)

    _status_label = Label.new()
    _status_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
    top_row.add_child(_status_label)

    var reset_button := Button.new()
    reset_button.text = "Reset"
    reset_button.pressed.connect(_on_reset_pressed)
    top_row.add_child(reset_button)

    var bottom := PanelContainer.new()
    bottom.theme = _hud_theme
    bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 8)
    layer.add_child(bottom)

    var bottom_box := VBoxContainer.new()
    bottom_box.add_theme_constant_override("separation", 8)
    bottom.add_child(bottom_box)

    _order_panel = OrderPanel.new()
    bottom_box.add_child(_order_panel)

    _ace_panel = AcePanel.new()
    _ace_panel.visible = false
    _ace_panel.move_pressed.connect(_on_ace_move_pressed)
    _ace_panel.shoot_pressed.connect(_on_ace_shoot_pressed)
    _ace_panel.cycle_pressed.connect(_on_ace_cycle_pressed)
    _ace_panel.end_pressed.connect(_on_ace_end_pressed)
    _ace_panel.exit_pressed.connect(_on_ace_exit_pressed)
    bottom_box.add_child(_ace_panel)

    _resolve_label = Label.new()
    _resolve_label.visible = false
    _resolve_label.add_theme_font_size_override("font_size", 18)
    _resolve_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
    bottom_box.add_child(_resolve_label)

    _resolve_bar = ProgressBar.new()
    _resolve_bar.visible = false
    _resolve_bar.max_value = TurnManager.resolution_window
    _resolve_bar.value = TurnManager.resolution_window
    bottom_box.add_child(_resolve_bar)

    _action_row = HBoxContainer.new()
    _action_row.add_theme_constant_override("separation", 6)
    bottom_box.add_child(_action_row)

    var engage_button := Button.new()
    engage_button.text = "Engage Now"
    engage_button.pressed.connect(_on_engage_pressed)
    _action_row.add_child(engage_button)

    var resolve_button := Button.new()
    resolve_button.text = "End Turn (Space)"
    resolve_button.pressed.connect(_on_end_turn_pressed)
    _action_row.add_child(resolve_button)

    _build_help_overlay(layer)
    _disable_button_focus(layer)

func _build_help_overlay(layer: CanvasLayer) -> void:
    _help_overlay = Control.new()
    _help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _help_overlay.visible = false
    layer.add_child(_help_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.0, 0.0, 0.0, 0.6)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _help_overlay.add_child(dim)

    var panel := PanelContainer.new()
    panel.theme = _hud_theme
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    _help_overlay.add_child(panel)

    var label := Label.new()
    label.text = _help_text()
    label.add_theme_font_size_override("font_size", 16)
    panel.add_child(label)

func _toggle_help() -> void:
    if _help_overlay != null:
        _help_overlay.visible = not _help_overlay.visible

func _help_text() -> String:
    return """CAMERA
  Right-drag   orbit
  Middle-drag  pan
  Wheel        zoom

ADMIRAL PHASE
  A / D   yaw (heading)
  Q / E   pitch
  W / S   target speed
  X       stop
  Tab     next ship
  Space   end turn
  G       toggle tactical plane

ACE PHASE
  M   move
  F   shoot
  C   cycle target
  N   end turn

ESC   close help"""

func _make_theme() -> Theme:
    var theme := Theme.new()
    theme.default_font_size = 15

    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.03, 0.05, 0.10, 0.88)
    panel_style.border_color = Color(0.30, 0.80, 0.90, 0.35)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(6)
    panel_style.set_content_margin_all(14)
    theme.set_stylebox("panel", "PanelContainer", panel_style)

    var button_normal := StyleBoxFlat.new()
    button_normal.bg_color = Color(0.06, 0.10, 0.18, 0.92)
    button_normal.border_color = Color(0.30, 0.80, 0.90, 0.40)
    button_normal.set_border_width_all(1)
    button_normal.set_corner_radius_all(4)
    button_normal.set_content_margin_all(7)
    theme.set_stylebox("normal", "Button", button_normal)

    var button_hover := StyleBoxFlat.new()
    button_hover.bg_color = Color(0.10, 0.18, 0.28, 0.96)
    button_hover.border_color = Color(0.55, 1.0, 1.0, 0.75)
    button_hover.set_border_width_all(1)
    button_hover.set_corner_radius_all(4)
    button_hover.set_content_margin_all(7)
    theme.set_stylebox("hover", "Button", button_hover)

    var button_pressed := StyleBoxFlat.new()
    button_pressed.bg_color = Color(0.18, 0.32, 0.32, 1.0)
    button_pressed.border_color = Color(1.0, 0.7, 0.3, 0.8)
    button_pressed.set_border_width_all(1)
    button_pressed.set_corner_radius_all(4)
    button_pressed.set_content_margin_all(7)
    theme.set_stylebox("pressed", "Button", button_pressed)

    theme.set_color("font_color", "Button", Color(0.82, 0.94, 1.0))
    theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
    theme.set_color("font_color", "Label", Color(0.80, 0.88, 0.96))

    return theme

func _disable_button_focus(node: Node) -> void:
    for child in node.get_children():
        if child is Button:
            child.focus_mode = Control.FOCUS_NONE
        _disable_button_focus(child)

func _process(_delta: float) -> void:
    if TurnManager.phase == TurnManager.Phase.ADMIRAL_RESOLVE:
        var remaining := TurnManager.remaining_resolve_time()
        _resolve_label.text = "RESOLVING… %.1f s" % remaining
        _resolve_bar.value = remaining
    else:
        _status_label.text = "Range: %.0f m" % _nearest_enemy_distance()

func _on_phase_changed(phase: int) -> void:
    _phase_label.text = _phase_text(phase)
    var in_ace := phase == TurnManager.Phase.ACE
    var resolving := phase == TurnManager.Phase.ADMIRAL_RESOLVE
    _order_panel.visible = not in_ace and not resolving
    _ace_panel.visible = in_ace
    _action_row.visible = not in_ace and not resolving
    _resolve_label.visible = resolving
    _resolve_bar.visible = resolving

func _on_admiral_resolve_finished() -> void:
    if _fleets_in_range():
        _engage()

func _engage() -> void:
    AudioManager.play_sfx("ui_hover", -10.0)
    TurnManager.start_ace(_player_ships + _enemy_ships)

func _fleets_in_range() -> bool:
    for player in _player_ships:
        if player.is_destroyed():
            continue
        for enemy in _enemy_ships:
            if enemy.is_destroyed():
                continue
            if player.state.position.distance_to(enemy.state.position) <= ENGAGEMENT_RANGE:
                return true
    return false

func _nearest_enemy_distance() -> float:
    var best := INF
    for player in _player_ships:
        if player.is_destroyed():
            continue
        for enemy in _enemy_ships:
            if enemy.is_destroyed():
                continue
            best = minf(best, player.state.position.distance_to(enemy.state.position))
    return best

func _phase_text(phase: int) -> String:
    match phase:
        TurnManager.Phase.ADMIRAL_RESOLVE:
            return "TURN %d — ADMIRAL — RESOLVE" % TurnManager.turn_number
        TurnManager.Phase.ACE:
            return "ACE — ROUND %d" % TurnManager.ace_round
        _:
            return "TURN %d — ADMIRAL — PLAN" % TurnManager.turn_number

func _on_ace_activated(ship: Ship) -> void:
    _ace_ai_timer = ACE_AI_DELAY
    _ace_panel.active_ship = ship
    for candidate in _player_ships:
        candidate.selected = candidate == ship and ship.team == 0
    _ace_target = _pick_default_target(ship)
    _ace_panel.target = _ace_target
    _ace_panel.refresh()

func _on_ace_move_pressed() -> void:
    var active := TurnManager.ace_active()
    if active != null and active.team == 0:
        _ace_move(active)

func _on_ace_shoot_pressed() -> void:
    var active := TurnManager.ace_active()
    if active != null and active.team == 0:
        _ace_shoot(active)

func _on_ace_cycle_pressed() -> void:
    var active := TurnManager.ace_active()
    if active != null and active.team == 0:
        _ace_cycle_target(active)

func _on_ace_end_pressed() -> void:
    var active := TurnManager.ace_active()
    if active != null and active.team == 0:
        TurnManager.ace_skip_ship()

func _on_ace_exit_pressed() -> void:
    TurnManager.exit_ace()

func _on_engage_pressed() -> void:
    if TurnManager.phase == TurnManager.Phase.ADMIRAL_PLAN:
        _engage()

func _on_end_turn_pressed() -> void:
    if TurnManager.phase == TurnManager.Phase.ADMIRAL_PLAN:
        _plan_ai_orders()
        AudioManager.play_sfx("ui_click", -14.0)
        TurnManager.start_resolve()

func _on_reset_pressed() -> void:
    get_tree().reload_current_scene()
