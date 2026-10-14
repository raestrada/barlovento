extends Node3D

const TURN_SPEED := 1.8
const SPEED_STEP := 8.0
const ACE_AI_DELAY := 0.6
const ENGAGEMENT_RANGE := 60.0
const PITCH_LIMIT := 1.45

var _player_ships: Array[Ship] = []
var _enemy_ships: Array[Ship] = []
var _selected_ship: Ship
var _selected_index: int = 0
var _ace_target: Ship
var _ace_ai_timer: float = 0.0
var _ether: EtherField

var _camera_rig: CameraRig
var _tactical_grid: TacticalGrid
var _trajectory: TrajectoryPreview

var _phase_badge: Label
var _initiative_label: Label
var _range_label: Label
var _resolve_panel: PanelContainer
var _resolve_label: Label
var _resolve_bar: ProgressBar
var _order_panel: OrderPanel
var _ace_panel: AcePanel
var _action_bar: HBoxContainer
var _fleet_bar: HBoxContainer
var _help_overlay: Control
var _hud_theme: Theme
var _ether_particles: Node3D

func _ready() -> void:
    TurnManager.reset()
    _setup_input_actions()

    _ether = EtherField.new()
    _ether.direction = Vector3(1.0, 0.2, 0.35).normalized()
    _ether.strength = 1.6
    _ether.wavelength = 65.0

    _build_environment()
    _build_camera()
    _build_ether_flow()
    _build_tactical_grid()
    _spawn_fleets()
    _build_trajectory_preview()
    _build_hud()
    _set_selected(_selected_ship)

    AudioManager.play_music(-20.0)
    AudioManager.start_ambient(-26.0)

    TurnManager.phase_changed.connect(_on_phase_changed)
    TurnManager.ace_activated.connect(_on_ace_activated)
    TurnManager.admiral_resolve_finished.connect(_on_admiral_resolve_finished)

    _on_phase_changed(TurnManager.phase)

func _physics_process(delta: float) -> void:
    match TurnManager.phase:
        TurnManager.Phase.ADMIRAL_PLAN:
            _handle_admiral_plan(delta)
        TurnManager.Phase.ACE:
            _handle_ace(delta)

func _process(delta: float) -> void:
    _update_ether_flow(delta)
    _update_hud_telemetry()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.echo:
        return
    if not event.is_pressed():
        return

    if event.is_action_pressed("help"):
        _toggle_help()
        return
    if event.is_action_pressed("toggle_grid"):
        if _tactical_grid != null:
            _tactical_grid.visible = not _tactical_grid.visible
        return
    if event.is_action_pressed("focus_ship"):
        if _selected_ship != null and _camera_rig != null:
            _camera_rig.focus_on(_selected_ship.global_position)
        return

    match TurnManager.phase:
        TurnManager.Phase.ADMIRAL_PLAN:
            if event.is_action_pressed("cycle"):
                _cycle_selection()
            elif event.is_action_pressed("stop"):
                if _selected_ship != null:
                    _selected_ship.order.target_speed = 0.0
            elif event.is_action_pressed("resolve"):
                _execute_admiral_resolve()
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
    if _selected_ship == null:
        return
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

func _handle_ace(delta: float) -> void:
    var active := TurnManager.ace_active()
    if active == null:
        return
    if active.team == 1:
        _run_enemy_ace(active, delta)
    else:
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
        active.order.target_speed = active.state.max_speed * 0.65
    active.advance(TurnManager.ACE_MOVE_DURATION)
    TurnManager.ace_spend_action()

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

    if _tactical_grid != null:
        _tactical_grid.selected_ship = ship

    if _order_panel != null:
        _order_panel.ship = ship

    _refresh_fleet_bar()

func _on_ship_clicked(clicked_ship: Ship) -> void:
    AudioManager.play_sfx("ui_click", -12.0)
    if clicked_ship.team == 0:
        _set_selected(clicked_ship)
    else:
        _ace_target = clicked_ship
        if _tactical_grid != null:
            _tactical_grid.target_ship = clicked_ship
        if _ace_panel != null:
            _ace_panel.target = clicked_ship

func _execute_admiral_resolve() -> void:
    _plan_ai_orders()
    AudioManager.play_sfx("ui_click", -12.0)
    TurnManager.start_resolve()

func _plan_ai_orders() -> void:
    for ship in _enemy_ships:
        if ship.is_destroyed():
            continue
        var target := _nearest_player_ship(ship)
        if target != null:
            var to_target := target.state.position - ship.state.position
            if to_target.length() > 0.01:
                _set_order_heading(ship, to_target.normalized())
            ship.order.target_speed = ship.state.max_speed * 0.6

func _set_order_heading(ship: Ship, direction: Vector3) -> void:
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() < 0.0001:
        flat = Vector3.FORWARD
    flat = flat.normalized()
    ship.order.yaw = Vector3.FORWARD.signed_angle_to(flat, Vector3.UP)
    ship.order.pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT)

func _nearest_player_ship(ship: Ship) -> Ship:
    var best: Ship = null
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
    if _tactical_grid != null:
        _tactical_grid.target_ship = _ace_target
    if _ace_panel != null:
        _ace_panel.target = _ace_target

func _build_environment() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
    sun.light_energy = 1.3
    sun.light_color = Color(1.0, 0.96, 0.90)
    add_child(sun)

    var rim_light := DirectionalLight3D.new()
    rim_light.rotation_degrees = Vector3(50.0, 145.0, 0.0)
    rim_light.light_energy = 0.45
    rim_light.light_color = Color(0.3, 0.6, 0.85)
    add_child(rim_light)

    var world := WorldEnvironment.new()
    var env := Environment.new()

    var sky_tex: Texture2D = load("res://assets/environments/star_sea_skybox.jpg")
    if sky_tex != null:
        env.background_mode = Environment.BG_SKY
        var sky := Sky.new()
        var sky_mat := PanoramaSkyMaterial.new()
        sky_mat.panorama = sky_tex
        sky.sky_material = sky_mat
        env.sky = sky
        env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        env.ambient_light_sky_contribution = 0.35
    else:
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.012, 0.016, 0.035)

    env.ambient_light_color = Color(0.2, 0.3, 0.45)
    env.ambient_light_energy = 1.1
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.glow_enabled = true
    env.glow_intensity = 0.65
    env.glow_bloom = 0.22
    env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

    world.environment = env
    add_child(world)

func _build_camera() -> void:
    _camera_rig = CameraRig.new()
    _camera_rig.target = Vector3(0.0, 0.0, 0.0)
    _camera_rig.distance = 70.0
    add_child(_camera_rig)

func _build_ether_flow() -> void:
    _ether_particles = Node3D.new()
    _ether_particles.name = "EtherFlowField"
    add_child(_ether_particles)

    var stream_mesh := CylinderMesh.new()
    stream_mesh.top_radius = 0.03
    stream_mesh.bottom_radius = 0.12
    stream_mesh.height = 3.5

    var stream_mat := StandardMaterial3D.new()
    stream_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    stream_mat.albedo_color = Color(0.3, 0.9, 0.95, 0.45)
    stream_mat.emission_enabled = true
    stream_mat.emission = Color(0.15, 0.6, 0.7)
    stream_mesh.material = stream_mat

    var rng := RandomNumberGenerator.new()
    rng.seed = 42
    for i in range(48):
        var p := MeshInstance3D.new()
        p.mesh = stream_mesh
        var pos := Vector3(rng.randf_range(-140.0, 140.0), rng.randf_range(-25.0, 25.0), rng.randf_range(-140.0, 140.0))
        var cur := _ether.current_at(pos)
        var norm := cur.normalized() if cur.length_squared() > 0.01 else _ether.direction
        var up := Vector3.UP if absf(norm.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
        _ether_particles.add_child(p)
        p.position = pos
        p.look_at(pos + norm, up)

func _update_ether_flow(delta: float) -> void:
    if _ether_particles == null:
        return
    for child in _ether_particles.get_children():
        if child is Node3D:
            var cur := _ether.current_at(child.position)
            child.position += cur * (delta * 6.0)
            if child.position.x > 150.0:
                child.position.x = -150.0
            elif child.position.x < -150.0:
                child.position.x = 150.0
            if child.position.z > 150.0:
                child.position.z = -150.0
            elif child.position.z < -150.0:
                child.position.z = 150.0

func _build_tactical_grid() -> void:
    _tactical_grid = TacticalGrid.new()
    add_child(_tactical_grid)

func _spawn_fleets() -> void:
    _player_ships.append(_spawn("vinculados_suit", Vector3(-12.0, 14.0, 36.0), Vector3.ZERO, 0))
    _player_ships.append(_spawn("vinculados_anima", Vector3(14.0, -10.0, 42.0), Vector3.ZERO, 0))
    _player_ships.append(_spawn("marea_galleon", Vector3(0.0, 2.0, 55.0), Vector3.ZERO, 0))

    _enemy_ships.append(_spawn("acero_dreadnought", Vector3(-25.0, 18.0, -42.0), Vector3(6.0, 0.0, 2.0), 1))
    _enemy_ships.append(_spawn("acero_corvette", Vector3(22.0, -12.0, -48.0), Vector3(-4.0, 0.0, 5.0), 1))

    _tactical_grid.set_ships(_player_ships + _enemy_ships)
    _set_selected(_player_ships[0])

func _spawn(id: String, pos: Vector3, vel: Vector3, team: int) -> Ship:
    var def := LoreDB.get_ship(id)
    var ship := Ship.new()
    ship.apply_def(def)
    ship.initial_velocity = vel
    ship.position = pos
    ship.team = team
    ship.ether = _ether
    ship.clicked.connect(_on_ship_clicked)
    add_child(ship)
    return ship

func _build_trajectory_preview() -> void:
    _trajectory = TrajectoryPreview.new()
    _trajectory.player_ships = _player_ships
    _trajectory.enemy_ships = _enemy_ships
    _trajectory.ether = _ether
    add_child(_trajectory)

func _build_hud() -> void:
    _hud_theme = _make_theme()
    var layer := CanvasLayer.new()
    layer.name = "TacticalHUD"
    add_child(layer)

    var top_panel := PanelContainer.new()
    top_panel.theme = _hud_theme
    top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 10)
    layer.add_child(top_panel)

    var top_vbox := VBoxContainer.new()
    top_vbox.add_theme_constant_override("separation", 6)
    top_panel.add_child(top_vbox)

    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 16)
    top_vbox.add_child(top_row)

    var logo_tex: Texture2D = load("res://assets/brand/logo.png")
    if logo_tex != null:
        var logo_rect := TextureRect.new()
        logo_rect.texture = logo_tex
        logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
        logo_rect.custom_minimum_size = Vector2(160, 36)
        logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        top_row.add_child(logo_rect)

    _phase_badge = Label.new()
    _phase_badge.add_theme_font_size_override("font_size", 17)
    _phase_badge.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
    top_row.add_child(_phase_badge)

    var top_spacer := Control.new()
    top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(top_spacer)

    _initiative_label = Label.new()
    _initiative_label.add_theme_font_size_override("font_size", 13)
    _initiative_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    top_row.add_child(_initiative_label)

    _range_label = Label.new()
    _range_label.add_theme_font_size_override("font_size", 13)
    _range_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
    top_row.add_child(_range_label)

    var help_btn := Button.new()
    help_btn.text = "MANUAL [H]"
    help_btn.pressed.connect(_toggle_help)
    top_row.add_child(help_btn)

    var reset_btn := Button.new()
    reset_btn.text = "RESET SIM"
    reset_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
    top_row.add_child(reset_btn)

    _fleet_bar = HBoxContainer.new()
    _fleet_bar.add_theme_constant_override("separation", 8)
    top_vbox.add_child(_fleet_bar)
    _refresh_fleet_bar()

    var bottom_container := VBoxContainer.new()
    bottom_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 10)
    bottom_container.add_theme_constant_override("separation", 8)
    layer.add_child(bottom_container)

    var panels_row := HBoxContainer.new()
    panels_row.add_theme_constant_override("separation", 12)
    bottom_container.add_child(panels_row)

    _order_panel = OrderPanel.new()
    _order_panel.theme = _hud_theme
    _order_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panels_row.add_child(_order_panel)

    _ace_panel = AcePanel.new()
    _ace_panel.theme = _hud_theme
    _ace_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _ace_panel.visible = false
    _ace_panel.move_pressed.connect(_on_ace_move_pressed)
    _ace_panel.shoot_pressed.connect(_on_ace_shoot_pressed)
    _ace_panel.cycle_pressed.connect(_on_ace_cycle_pressed)
    _ace_panel.end_pressed.connect(_on_ace_end_pressed)
    _ace_panel.exit_pressed.connect(_on_ace_exit_pressed)
    panels_row.add_child(_ace_panel)

    _resolve_panel = PanelContainer.new()
    _resolve_panel.theme = _hud_theme
    _resolve_panel.visible = false
    bottom_container.add_child(_resolve_panel)

    var res_vbox := VBoxContainer.new()
    res_vbox.add_theme_constant_override("separation", 4)
    _resolve_panel.add_child(res_vbox)

    _resolve_label = Label.new()
    _resolve_label.add_theme_font_size_override("font_size", 16)
    _resolve_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
    res_vbox.add_child(_resolve_label)

    _resolve_bar = ProgressBar.new()
    _resolve_bar.custom_minimum_size = Vector2(0, 18)
    _resolve_bar.max_value = TurnManager.resolution_window
    res_vbox.add_child(_resolve_bar)

    _action_bar = HBoxContainer.new()
    _action_bar.add_theme_constant_override("separation", 8)
    bottom_container.add_child(_action_bar)

    var focus_btn := Button.new()
    focus_btn.text = "FOCUS CAMERA [V]"
    focus_btn.pressed.connect(func() -> void:
        if _selected_ship != null and _camera_rig != null:
            _camera_rig.focus_on(_selected_ship.global_position)
    )
    _action_bar.add_child(focus_btn)

    var grid_btn := Button.new()
    grid_btn.text = "TOGGLE GRID [G]"
    grid_btn.pressed.connect(func() -> void:
        if _tactical_grid != null:
            _tactical_grid.visible = not _tactical_grid.visible
    )
    _action_bar.add_child(grid_btn)

    var spacer_act := Control.new()
    spacer_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _action_bar.add_child(spacer_act)

    var engage_btn := Button.new()
    engage_btn.text = "ENGAGE TACTICAL COMBAT [E]"
    engage_btn.pressed.connect(_on_engage_pressed)
    _action_bar.add_child(engage_btn)

    var resolve_btn := Button.new()
    resolve_btn.text = "EXECUTE WEGO TURN [SPACE]"
    resolve_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
    resolve_btn.pressed.connect(_on_end_turn_pressed)
    _action_bar.add_child(resolve_btn)

    _build_help_overlay(layer)
    _disable_button_focus(layer)

func _refresh_fleet_bar() -> void:
    if _fleet_bar == null:
        return
    for child in _fleet_bar.get_children():
        child.queue_free()

    for ship in _player_ships:
        if ship.is_destroyed():
            continue
        var btn := Button.new()
        var sel := "> " if ship == _selected_ship else ""
        btn.text = "%s%s [%.0f HP]" % [sel, ship.ship_name, ship.hp]
        if ship == _selected_ship:
            btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
        else:
            btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
        btn.pressed.connect(func() -> void: _set_selected(ship))
        _fleet_bar.add_child(btn)

    var sep := VSeparator.new()
    _fleet_bar.add_child(sep)

    for enemy in _enemy_ships:
        if enemy.is_destroyed():
            continue
        var btn := Button.new()
        var sel := "* " if enemy == _ace_target else ""
        btn.text = "%sHOSTILE: %s [%.0f HP]" % [sel, enemy.ship_name, enemy.hp]
        btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
        btn.pressed.connect(func() -> void:
            _ace_target = enemy
            if _tactical_grid != null:
                _tactical_grid.target_ship = enemy
            if _ace_panel != null:
                _ace_panel.target = enemy
            _refresh_fleet_bar()
        )
        _fleet_bar.add_child(btn)

    _disable_button_focus(_fleet_bar)

func _update_hud_telemetry() -> void:
    if TurnManager.phase == TurnManager.Phase.ADMIRAL_RESOLVE:
        var remaining := TurnManager.remaining_resolve_time()
        _resolve_label.text = "SIMULTANEOUS WEGO RESOLUTION: %.1f s REMAINING" % remaining
        _resolve_bar.value = remaining
    else:
        var dist := _nearest_enemy_distance()
        if dist < INF:
            _range_label.text = "CLOSEST CONTACT: %.0f m" % dist
        else:
            _range_label.text = "ALL HOSTILES NEUTRALIZED"

    var initiative := _calculate_initiative()
    _initiative_label.text = "WEATHER GAUGE: %s" % initiative

func _calculate_initiative() -> String:
    var player_advantage := 0
    for p in _player_ships:
        if p.is_destroyed():
            continue
        var to_wind := _ether.direction.dot(p.state.velocity)
        if to_wind > 0.5:
            player_advantage += 1
    if player_advantage >= 2:
        return "FAVORABLE (RIDING ÉTHER CURRENT)"
    elif player_advantage == 1:
        return "NEUTRAL"
    else:
        return "ADVERSE (SAILING INTO CALM)"

func _on_phase_changed(phase: int) -> void:
    _phase_badge.text = _phase_text(phase)
    var in_ace := phase == TurnManager.Phase.ACE
    var resolving := phase == TurnManager.Phase.ADMIRAL_RESOLVE

    _order_panel.visible = not in_ace and not resolving
    _ace_panel.visible = in_ace
    _action_bar.visible = not in_ace and not resolving
    _resolve_panel.visible = resolving
    _refresh_fleet_bar()

func _on_admiral_resolve_finished() -> void:
    _refresh_fleet_bar()
    if _fleets_in_range():
        _engage()

func _engage() -> void:
    AudioManager.play_sfx("ui_hover", -8.0)
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
            return "TURN %d // ADMIRAL PHASE — WEGO RESOLVING" % TurnManager.turn_number
        TurnManager.Phase.ACE:
            return "ACE TACTICAL COMBAT // ROUND %d" % TurnManager.ace_round
        _:
            return "TURN %d // ADMIRAL PHASE — SIMULTANEOUS PLANNING" % TurnManager.turn_number

func _on_ace_activated(ship: Ship) -> void:
    _ace_ai_timer = ACE_AI_DELAY
    _ace_panel.active_ship = ship
    for candidate in _player_ships:
        candidate.selected = candidate == ship and ship.team == 0
    _ace_target = _pick_default_target(ship)
    if _tactical_grid != null:
        _tactical_grid.selected_ship = ship
        _tactical_grid.target_ship = _ace_target
    _ace_panel.target = _ace_target
    _ace_panel.refresh()
    _refresh_fleet_bar()

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
        _execute_admiral_resolve()

func _build_help_overlay(layer: CanvasLayer) -> void:
    _help_overlay = Control.new()
    _help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _help_overlay.visible = false
    layer.add_child(_help_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.01, 0.02, 0.04, 0.75)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _help_overlay.add_child(dim)

    var panel := PanelContainer.new()
    panel.theme = _hud_theme
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    _help_overlay.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    panel.add_child(vbox)

    var title := Label.new()
    title.text = "TACTICAL COMMAND MANUAL"
    title.add_theme_font_size_override("font_size", 18)
    title.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
    vbox.add_child(title)

    var label := Label.new()
    label.text = _help_text()
    label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(label)

    var close_btn := Button.new()
    close_btn.text = "RETURN TO TACTICAL SIMULATION [ESC / H]"
    close_btn.pressed.connect(_toggle_help)
    vbox.add_child(close_btn)

func _toggle_help() -> void:
    if _help_overlay != null:
        _help_overlay.visible = not _help_overlay.visible

func _help_text() -> String:
    return """TACTICAL NAVIGATION & CAMERA
  Right-Click Drag   Orbit tactical camera
  Middle-Click Drag  Pan battlefield plane
  Mouse Wheel        Zoom in / out
  Click on Ship      Direct selection of friendly or hostile target
  V                  Focus camera on selected ship

ADMIRAL PHASE (SIMULTANEOUS WEGO MOVEMENT)
  A / D              Turn Port / Starboard (Yaw)
  Q / E              Climb / Dive (Pitch)
  W / S              Increase / Decrease commanded speed
  X                  Emergency stop (Full retrograde burn)
  Tab                Cycle fleet units
  G                  Toggle 3D tactical grid & altitude stems
  Space              Execute simultaneous turn resolution

ACE PHASE (HERO TACTICAL ENGAGEMENT)
  M                  Burn engines (Execute 3s tactical vector move)
  F                  Fire forward battery (Resolves shot if target in arc & range)
  C                  Cycle hostile target lock
  N                  Pass turn to next unit in sequence

ESC / H              Toggle this tactical manual"""

func _make_theme() -> Theme:
    var theme := Theme.new()
    theme.default_font_size = 14

    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.04, 0.07, 0.12, 0.90)
    panel_style.border_color = Color(0.25, 0.75, 0.90, 0.45)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(6)
    panel_style.set_content_margin_all(12)
    theme.set_stylebox("panel", "PanelContainer", panel_style)

    var btn_normal := StyleBoxFlat.new()
    btn_normal.bg_color = Color(0.08, 0.13, 0.22, 0.92)
    btn_normal.border_color = Color(0.30, 0.75, 0.90, 0.40)
    btn_normal.set_border_width_all(1)
    btn_normal.set_corner_radius_all(4)
    btn_normal.set_content_margin_all(7)
    theme.set_stylebox("normal", "Button", btn_normal)

    var btn_hover := StyleBoxFlat.new()
    btn_hover.bg_color = Color(0.12, 0.22, 0.35, 0.96)
    btn_hover.border_color = Color(0.45, 0.95, 1.0, 0.85)
    btn_hover.set_border_width_all(1)
    btn_hover.set_corner_radius_all(4)
    btn_hover.set_content_margin_all(7)
    theme.set_stylebox("hover", "Button", btn_hover)

    var btn_pressed := StyleBoxFlat.new()
    btn_pressed.bg_color = Color(0.18, 0.35, 0.42, 1.0)
    btn_pressed.border_color = Color(1.0, 0.75, 0.3, 0.9)
    btn_pressed.set_border_width_all(1)
    btn_pressed.set_corner_radius_all(4)
    btn_pressed.set_content_margin_all(7)
    theme.set_stylebox("pressed", "Button", btn_pressed)

    theme.set_color("font_color", "Button", Color(0.85, 0.95, 1.0))
    theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
    theme.set_color("font_color", "Label", Color(0.82, 0.90, 0.98))

    return theme

func _disable_button_focus(node: Node) -> void:
    for child in node.get_children():
        if child is Button:
            child.focus_mode = Control.FOCUS_NONE
        _disable_button_focus(child)

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
    _add_action("focus_ship", [KEY_V])
    _add_action("toggle_grid", [KEY_G])
    _add_action("help", [KEY_H, KEY_ESCAPE])
    _add_action("ace_move", [KEY_M])
    _add_action("ace_shoot", [KEY_F])
    _add_action("ace_cycle", [KEY_C])
    _add_action("ace_end", [KEY_N])

func _add_action(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for key in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key
        InputMap.action_add_event(action, event)
