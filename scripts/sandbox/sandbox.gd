extends Node3D

const TURN_SPEED := 2.2
const SPEED_STEP := 8.0
const PITCH_LIMIT := 1.15
const ENGAGEMENT_RANGE := 65.0

var _player_ships: Array[Ship] = []
var _enemy_ships: Array[Ship] = []
var _selected_ship: Ship
var _selected_index: int = 0
var _ace_target: Ship
var _ether: EtherField

var _camera_rig: CameraRig
var _tactical_grid: TacticalGrid
var _trajectory: TrajectoryPreview

var _stage_title_label: Label
var _objective_label: Label
var _phase_badge: Label
var _initiative_label: Label
var _range_label: Label
var _round_banner: PanelContainer
var _round_banner_label: Label
var _combat_log_vbox: VBoxContainer
var _combat_logs: Array[String] = []

var _target_line_mesh: MeshInstance3D
var _target_line_immediate: ImmediateMesh
var _target_3d_reticle: Node3D
var _target_3d_label: Label3D
var _active_3d_beacon: Node3D
var _active_3d_label: Label3D

var _resolve_panel: PanelContainer
var _resolve_label: Label
var _resolve_bar: ProgressBar
var _order_panel: OrderPanel
var _ace_panel: AcePanel
var _action_bar: HBoxContainer
var _fleet_panel: PanelContainer
var _allied_list_vbox: VBoxContainer
var _hostile_list_vbox: VBoxContainer
var _help_overlay: Control
var _victory_overlay: Control
var _defeat_overlay: Control
var _hud_theme: Theme
var _ether_particles: Node3D

var _mission_completed: bool = false

func _ready() -> void:
    TurnManager.reset()
    _setup_input_actions()

    PhysicsSim.bounds = AABB(
        Vector3(-TacticalGrid.GRID_HALF_SPAN, -TacticalGrid.BOUNDS_HALF_HEIGHT, -TacticalGrid.GRID_HALF_SPAN),
        Vector3(TacticalGrid.GRID_HALF_SPAN * 2.0, TacticalGrid.BOUNDS_HALF_HEIGHT * 2.0, TacticalGrid.GRID_HALF_SPAN * 2.0)
    )

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
    _build_3d_targeting_hud()
    _build_hud()
    _set_selected(_player_ships[0])

    AudioManager.play_music(-20.0)
    AudioManager.start_ambient(-26.0)

    TurnManager.phase_changed.connect(_on_phase_changed)
    TurnManager.admiral_resolve_finished.connect(_on_admiral_resolve_finished)
    TurnManager.ace_resolve_finished.connect(_on_ace_resolve_finished)
    TurnManager.ace_fire_moment.connect(_on_ace_fire_moment)

    _on_phase_changed(TurnManager.phase)
    _add_combat_log("Tactical link established. Outer Veil // Sector Psalm-4.", Color(0.4, 0.9, 1.0))
    _add_combat_log("Objective: Intercept and neutralize Acero flotilla.", Color(1.0, 0.85, 0.3))

func _physics_process(delta: float) -> void:
    if not TurnManager.is_resolving():
        _handle_flight_controls(delta)
    else:
        var sim_delta := delta * PhysicsSim.time_scale
        _update_ai_tactical_behavior(sim_delta)
        if TurnManager.phase == TurnManager.Phase.ADMIRAL_RESOLVE:
            _check_engagement_transition()

func _process(delta: float) -> void:
    _update_ether_flow(delta)
    _update_hud_telemetry()
    _update_3d_targeting_hud()

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

    if not TurnManager.is_resolving():
        if event.is_action_pressed("cycle"):
            _cycle_selection()
        elif event.is_action_pressed("stop"):
            if _selected_ship != null:
                _selected_ship.order.target_speed = 0.0
        elif event.is_action_pressed("resolve"):
            _execute_current_phase()
        elif event.is_action_pressed("ace_cycle"):
            _cycle_hostile_target()
        elif event.is_action_pressed("intercept_target"):
            _intercept_target()

func _handle_flight_controls(delta: float) -> void:
    if _selected_ship == null:
        return

    var order := _selected_ship.order

    # Yaw (Left / Right)
    if Input.is_action_pressed("yaw_left"):
        order.yaw += TURN_SPEED * delta
    if Input.is_action_pressed("yaw_right"):
        order.yaw -= TURN_SPEED * delta

    # Pitch (Up / Down)
    if Input.is_action_pressed("pitch_up"):
        order.pitch = clampf(order.pitch + TURN_SPEED * delta, -PITCH_LIMIT, PITCH_LIMIT)
    if Input.is_action_pressed("pitch_down"):
        order.pitch = clampf(order.pitch - TURN_SPEED * delta, -PITCH_LIMIT, PITCH_LIMIT)

    # Speed (Forward / Reverse Throttle)
    if Input.is_action_pressed("move_forward"):
        order.target_speed = clampf(order.target_speed + SPEED_STEP * delta, 0.0, _selected_ship.state.max_speed)
    if Input.is_action_pressed("move_back"):
        order.target_speed = clampf(order.target_speed - SPEED_STEP * delta, 0.0, _selected_ship.state.max_speed)

func _execute_current_phase() -> void:
    if TurnManager.phase == TurnManager.Phase.ADMIRAL_PLAN:
        _plan_ai_orders()
        AudioManager.play_sfx("ui_click", -12.0)
        _add_combat_log("Executing strategic WEGO fleet resolution (%ds)..." % int(TurnManager.admiral_resolution_window), Color(0.3, 1.0, 0.6))
        TurnManager.start_resolve()
    elif TurnManager.phase == TurnManager.Phase.ACE_PLAN:
        _execute_ace_round()

func _execute_ace_round() -> void:
    _plan_ai_tactical_orders()
    AudioManager.play_sfx("ui_click", -10.0)
    _add_combat_log(">>> EXECUTING TACTICAL ROUND %d (ALL UNITS ENGAGING) <<<" % TurnManager.ace_round, Color(0.35, 1.0, 0.75))
    TurnManager.start_ace_resolve()

func _plan_ai_orders() -> void:
    # 1. Identify Flagship (Iron Bastion) and Escort (Vanguard-03)
    var flagship: Ship = null
    var escort: Ship = null
    for s in _enemy_ships:
        if s.is_destroyed():
            continue
        if s.ship_id == "acero_dreadnought":
            flagship = s
        elif s.ship_id == "acero_corvette":
            escort = s
        elif flagship == null:
            flagship = s
        else:
            escort = s

    # 2. Pick primary flotilla target (closest active allied ship)
    var primary_target: Ship = null
    if flagship != null:
        primary_target = _nearest_player_ship(flagship)
    elif escort != null:
        primary_target = _nearest_player_ship(escort)

    if primary_target == null:
        return

    # 3. Flagship tactical doctrine (Command Dreadnought holding battle line)
    if flagship != null:
        var to_target := primary_target.state.position - flagship.state.position
        var dist := to_target.length()
        if dist > 0.1:
            _set_order_heading(flagship, to_target.normalized())

        # Engagement envelope (Range 55m):
        # > 48m: Advance toward intercept
        # 22m - 48m: BRAKE and maintain battle line!
        # < 22m: Stop/reverse to avoid ramming and keep stand-off firing arc
        if dist > 48.0:
            flagship.order.target_speed = flagship.state.max_speed * 0.60
        elif dist > 20.0:
            flagship.order.target_speed = 3.0
        else:
            flagship.order.target_speed = 0.0

    # 4. Escort tactical doctrine (Corvette screening the Flagship flank)
    if escort != null:
        if flagship != null and not flagship.is_destroyed():
            var escort_station := flagship.state.position + Vector3(16.0, 2.0, -4.0)
            var to_station := escort_station - escort.state.position
            var dist_station := to_station.length()

            if dist_station > 18.0:
                # Reposition to rejoin flagship formation screen
                _set_order_heading(escort, to_station.normalized())
                escort.order.target_speed = escort.state.max_speed * 0.70
            else:
                # In formation: Interlock broadside fire on primary target
                var to_target := primary_target.state.position - escort.state.position
                var dist_target := to_target.length()
                if dist_target > 0.1:
                    _set_order_heading(escort, to_target.normalized())
                if dist_target > 40.0:
                    escort.order.target_speed = escort.state.max_speed * 0.55
                elif dist_target > 18.0:
                    escort.order.target_speed = 3.5
                else:
                    escort.order.target_speed = 0.0
        else:
            # Solo engagement doctrine
            var to_target := primary_target.state.position - escort.state.position
            var dist := to_target.length()
            if dist > 0.1:
                _set_order_heading(escort, to_target.normalized())
            if dist > 40.0:
                escort.order.target_speed = escort.state.max_speed * 0.65
            elif dist > 18.0:
                escort.order.target_speed = 3.5
            else:
                escort.order.target_speed = 0.0

func _plan_ai_tactical_orders() -> void:
    # Coordinated target designation for tactical round
    var primary_target: Ship = null
    for s in _enemy_ships:
        if not s.is_destroyed():
            primary_target = _nearest_player_ship(s)
            break

    for ship in _enemy_ships:
        if ship.is_destroyed():
            continue
        var target := primary_target if primary_target != null and not primary_target.is_destroyed() else _nearest_player_ship(ship)
        ship.target_ship = target
        if target != null:
            var to_target := target.state.position - ship.state.position
            var dist := to_target.length()
            if dist > 0.1:
                _set_order_heading(ship, to_target.normalized())

            # Stance selection: Low HP triggers defensive evasion
            if ship.hp < ship.max_hp * 0.40:
                ship.stance = Ship.Stance.EVASIVE
            else:
                ship.stance = Ship.Stance.FIRE

            # Keep speed controlled in tactical dogfight range so units don't overshoot
            if dist > ship.weapon_range:
                ship.order.target_speed = ship.state.max_speed * 0.60
            elif dist > 16.0:
                ship.order.target_speed = 4.0
            else:
                ship.order.target_speed = 1.0

func _set_order_heading(ship: Ship, direction: Vector3) -> void:
    var flat := Vector3(direction.x, 0.0, direction.z)
    if flat.length_squared() < 0.0001:
        flat = Vector3.FORWARD
    flat = flat.normalized()
    ship.order.yaw = Vector3.FORWARD.signed_angle_to(flat, Vector3.UP)
    ship.order.pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT)

func _on_ace_fire_moment() -> void:
    _add_combat_log("Weapons batteries opening fire across tactical envelope!", Color(1.0, 0.85, 0.3))

    # 1. Player Ace & squadron fire
    for player in _player_ships:
        if player.is_destroyed():
            continue

        var target := player.target_ship if player.target_ship != null else _ace_target
        if target == null or target.is_destroyed():
            target = _nearest_enemy_for(player)

        if target != null and not target.is_destroyed() and player.stance != Ship.Stance.EVASIVE:
            if Combat.can_hit(player, target):
                var result := Combat.resolve_shot(player, target)
                var beam_color := Color(0.35, 0.95, 1.0)
                _spawn_laser_beam(player.global_position, target.global_position, beam_color)
                _spawn_impact_flash(target.global_position, beam_color)

                if _camera_rig != null:
                    _camera_rig.shake(0.85, 0.22)

                if result.hit:
                    var crit_str := " 💥 [CRIT!]" if result.critical else ""
                    _spawn_combat_text(target.global_position, "-%.0f HP%s" % [result.damage, crit_str], Color(1.0, 0.85, 0.2) if result.critical else Color(0.3, 1.0, 0.55))
                    _add_combat_log("%s hit %s for %.0f DMG%s" % [player.ship_name, target.ship_name, result.damage, crit_str], Color(0.3, 1.0, 0.55))
                    if result.destroyed:
                        _add_combat_log(">>> %s DESTROYED!" % target.ship_name, Color(1.0, 0.4, 0.2))
                else:
                    var reason := "EVADED!" if result.evaded else "MISSED!"
                    _spawn_combat_text(target.global_position, reason, Color(0.4, 0.9, 1.0))
                    _add_combat_log("%s fired at %s (%s)" % [player.ship_name, target.ship_name, reason.to_lower()], Color(0.7, 0.8, 1.0))

    # 2. Hostile fleet fires back
    for enemy in _enemy_ships:
        if enemy.is_destroyed():
            continue

        var target := enemy.target_ship if enemy.target_ship != null else _nearest_player_ship(enemy)
        if target != null and not target.is_destroyed() and enemy.stance != Ship.Stance.EVASIVE:
            if Combat.can_hit(enemy, target):
                var result := Combat.resolve_shot(enemy, target)
                var beam_color := Color(1.0, 0.4, 0.2)
                _spawn_laser_beam(enemy.global_position, target.global_position, beam_color)
                _spawn_impact_flash(target.global_position, beam_color)

                if _camera_rig != null:
                    _camera_rig.shake(0.9, 0.24)

                if result.hit:
                    _spawn_combat_text(target.global_position, "-%.0f HP" % result.damage, Color(1.0, 0.35, 0.2))
                    _add_combat_log("[ENEMY] %s dealt %.0f damage to %s" % [enemy.ship_name, result.damage, target.ship_name], Color(1.0, 0.45, 0.35))
                    if result.destroyed:
                        _add_combat_log(">>> ALLIED SHIP %s DESTROYED!" % target.ship_name, Color(1.0, 0.2, 0.2))
                else:
                    var reason := "EVADED!" if result.evaded else "MISSED!"
                    _spawn_combat_text(target.global_position, reason, Color(0.4, 0.9, 1.0))
                    _add_combat_log("[ENEMY] %s shot at %s %s" % [enemy.ship_name, target.ship_name, reason.to_lower()], Color(0.7, 0.8, 1.0))

    _refresh_fleet_panel()
    _check_stage_objectives()

func _on_ace_resolve_finished() -> void:
    _refresh_fleet_panel()
    _add_combat_log("Tactical round %d resolved. Re-assessing tactical vectors." % (TurnManager.ace_round - 1), Color(0.35, 0.95, 1.0))
    _check_stage_objectives()
    if not _mission_completed:
        _update_round_banner()

func _on_admiral_resolve_finished() -> void:
    _refresh_fleet_panel()
    _add_combat_log("Strategic WEGO movement cycle complete.", Color(0.35, 0.9, 1.0))
    if _fleets_in_range():
        _add_combat_log("Combat envelope reached! Transitioning to Ace tactical phase.", Color(1.0, 0.8, 0.3))
        _engage_ace_mode()

func _engage_ace_mode() -> void:
    AudioManager.play_sfx("ui_hover", -8.0)
    TurnManager.start_ace_mode()
    _set_selected(_player_ships[0])
    _ace_target = _enemy_ships[0]
    _update_round_banner()

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

    if _ace_panel != null:
        _ace_panel.ship = ship
        _ace_panel.target = _ace_target

    _refresh_fleet_panel()

func _cycle_hostile_target() -> void:
    var alive: Array[Ship] = []
    for candidate in _enemy_ships:
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
    if _selected_ship != null:
        _selected_ship.target_ship = _ace_target

    _refresh_fleet_panel()
    if _ace_target != null:
        AudioManager.play_sfx("ui_hover", -6.0)
        _add_combat_log("Target locked: %s [%s]" % [_ace_target.ship_name, _ace_target.pilot_name], Color(1.0, 0.75, 0.35))

func _on_ship_clicked(clicked_ship: Ship) -> void:
    AudioManager.play_sfx("ui_click", -10.0)
    if clicked_ship.team == 1:
        _ace_target = clicked_ship
        if _tactical_grid != null:
            _tactical_grid.target_ship = clicked_ship
        if _ace_panel != null:
            _ace_panel.target = clicked_ship
        if _selected_ship != null:
            _selected_ship.target_ship = clicked_ship
        _refresh_fleet_panel()
        _add_combat_log("Hostile targeted: %s [%s]" % [clicked_ship.ship_name, clicked_ship.pilot_name], Color(1.0, 0.65, 0.3))
    else:
        _set_selected(clicked_ship)
        _add_combat_log("Selected unit: %s" % clicked_ship.ship_name, Color(0.35, 1.0, 0.6))

func _on_ship_right_clicked(clicked_ship: Ship) -> void:
    if clicked_ship.team == 1:
        _ace_target = clicked_ship
        if _tactical_grid != null:
            _tactical_grid.target_ship = clicked_ship
        if _ace_panel != null:
            _ace_panel.target = clicked_ship
        if _selected_ship != null:
            _selected_ship.target_ship = clicked_ship
        _intercept_target()
        _refresh_fleet_panel()

func _intercept_target() -> void:
    if _selected_ship == null or _selected_ship.is_destroyed():
        return
    if _ace_target == null or _ace_target.is_destroyed():
        _cycle_hostile_target()
    if _ace_target == null:
        return

    var to_target := _ace_target.state.position - _selected_ship.state.position
    if to_target.length_squared() > 0.01:
        _set_order_heading(_selected_ship, to_target.normalized())
        if _selected_ship.order.target_speed < 4.0:
            _selected_ship.order.target_speed = clampf(_selected_ship.state.max_speed * 0.70, 8.0, _selected_ship.state.max_speed)
        AudioManager.play_sfx("ui_click", -8.0)
        _add_combat_log("🎯 %s: Intercept vector locked on %s (SPD %.1f m/s)" % [
            _selected_ship.ship_name, _ace_target.ship_name, _selected_ship.order.target_speed
        ], Color(1.0, 0.85, 0.35))

func _on_ace_ability_used(ability_name: String) -> void:
    if _selected_ship == null or _selected_ship.is_destroyed():
        return
    match ability_name:
        "precision":
            AudioManager.play_sfx("ui_hover", -6.0)
            _add_combat_log("🎯 %s: Fire control radar calibrated (+25%% Hit Accuracy next volley)" % _selected_ship.ship_name, Color(0.35, 1.0, 0.85))
        "retro_brake":
            _selected_ship.order.target_speed = maxf(_selected_ship.order.target_speed - 8.0, 0.0)
            _selected_ship.state.velocity *= 0.4
            AudioManager.play_sfx("engine", -8.0)
            _add_combat_log("💨 %s: Emergency retro-thrusters fired! (Speed arrested to %.1f m/s)" % [_selected_ship.ship_name, _selected_ship.speed()], Color(0.4, 0.9, 1.0))
        "shield_pulse":
            _selected_ship.hp = minf(_selected_ship.hp + 30.0, _selected_ship.max_hp)
            AudioManager.play_sfx("shield", -8.0)
            _add_combat_log("🛡 %s: Deflector shield overcharged (+30 HP absorbed)" % _selected_ship.ship_name, Color(0.3, 1.0, 0.6))
            _refresh_fleet_panel()

func _update_ai_tactical_behavior(_delta: float) -> void:
    var flagship: Ship = null
    var escort: Ship = null
    for s in _enemy_ships:
        if s.is_destroyed():
            continue
        if s.ship_id == "acero_dreadnought":
            flagship = s
        elif s.ship_id == "acero_corvette":
            escort = s
        elif flagship == null:
            flagship = s
        else:
            escort = s

    var primary_target: Ship = null
    if flagship != null:
        primary_target = _nearest_player_ship(flagship)
    elif escort != null:
        primary_target = _nearest_player_ship(escort)

    if primary_target == null:
        return

    # Dynamic Flagship steering: keeps target in arc & controls throttle to hold firing bracket
    if flagship != null:
        var to_target := primary_target.state.position - flagship.state.position
        var dist := to_target.length()
        if dist > 0.1:
            _set_order_heading(flagship, to_target.normalized())
        if dist > 48.0:
            flagship.order.target_speed = 6.5
        elif dist > 20.0:
            flagship.order.target_speed = 3.2
        else:
            flagship.order.target_speed = 0.0

    # Dynamic Escort steering: screens flagship flank and maintains interlocking line
    if escort != null:
        if flagship != null and not flagship.is_destroyed():
            var escort_station := flagship.state.position + Vector3(16.0, 2.0, -4.0)
            var to_station := escort_station - escort.state.position
            if to_station.length() > 18.0:
                _set_order_heading(escort, to_station.normalized())
                escort.order.target_speed = 8.0
            else:
                var to_target := primary_target.state.position - escort.state.position
                if to_target.length() > 0.1:
                    _set_order_heading(escort, to_target.normalized())
                var dist_t := to_target.length()
                if dist_t > 40.0:
                    escort.order.target_speed = 6.0
                elif dist_t > 18.0:
                    escort.order.target_speed = 3.5
                else:
                    escort.order.target_speed = 0.0
        else:
            var to_target := primary_target.state.position - escort.state.position
            if to_target.length() > 0.1:
                _set_order_heading(escort, to_target.normalized())
            if to_target.length() > 35.0:
                escort.order.target_speed = 6.0
            else:
                escort.order.target_speed = 3.0

func _check_engagement_transition() -> void:
    if _fleets_in_range():
        _add_combat_log("Combat envelope reached! Clashing into Ace tactical combat.", Color(1.0, 0.85, 0.35))
        _engage_ace_mode()

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

func _nearest_enemy_for(ship: Ship) -> Ship:
    var best: Ship = null
    var best_distance := INF
    for candidate in _enemy_ships:
        if candidate.is_destroyed():
            continue
        var distance := ship.state.position.distance_to(candidate.state.position)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    return best

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

func _build_3d_targeting_hud() -> void:
    _target_line_mesh = MeshInstance3D.new()
    _target_line_immediate = ImmediateMesh.new()
    _target_line_mesh.mesh = _target_line_immediate

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.3, 0.95, 1.0, 0.8)
    mat.emission_enabled = true
    mat.emission = Color(0.2, 0.8, 1.0)
    _target_line_mesh.material_override = mat
    _target_line_mesh.visible = false
    add_child(_target_line_mesh)

    _target_3d_reticle = Node3D.new()
    _target_3d_reticle.visible = false
    add_child(_target_3d_reticle)

    var torus := TorusMesh.new()
    torus.inner_radius = 2.4
    torus.outer_radius = 2.7
    torus.rings = 24
    var ret_mesh := MeshInstance3D.new()
    ret_mesh.mesh = torus
    var ret_mat := StandardMaterial3D.new()
    ret_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ret_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ret_mat.albedo_color = Color(1.0, 0.45, 0.25, 0.85)
    ret_mat.emission_enabled = true
    ret_mat.emission = Color(1.0, 0.3, 0.1)
    ret_mesh.material_override = ret_mat
    _target_3d_reticle.add_child(ret_mesh)

    _target_3d_label = Label3D.new()
    _target_3d_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _target_3d_label.font_size = 14
    _target_3d_label.outline_size = 2
    _target_3d_label.outline_modulate = Color.BLACK
    _target_3d_label.position = Vector3(0.0, 3.2, 0.0)
    _target_3d_reticle.add_child(_target_3d_label)

    _active_3d_beacon = Node3D.new()
    _active_3d_beacon.visible = false
    add_child(_active_3d_beacon)

    var beacon_torus := TorusMesh.new()
    beacon_torus.inner_radius = 3.0
    beacon_torus.outer_radius = 3.3
    beacon_torus.rings = 32
    var b_mesh := MeshInstance3D.new()
    b_mesh.mesh = beacon_torus
    var b_mat := StandardMaterial3D.new()
    b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    b_mat.albedo_color = Color(0.2, 1.0, 0.65, 0.85)
    b_mat.emission_enabled = true
    b_mat.emission = Color(0.2, 1.0, 0.5)
    b_mesh.material_override = b_mat
    _active_3d_beacon.add_child(b_mesh)

    _active_3d_label = Label3D.new()
    _active_3d_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _active_3d_label.font_size = 13
    _active_3d_label.modulate = Color(0.3, 1.0, 0.7)
    _active_3d_label.outline_size = 2
    _active_3d_label.outline_modulate = Color.BLACK
    _active_3d_label.position = Vector3(0.0, -2.0, 0.0)
    _active_3d_label.text = "▶ SELECTED ACE"
    _active_3d_beacon.add_child(_active_3d_label)

func _update_3d_targeting_hud() -> void:
    if not TurnManager.is_in_ace():
        if _target_line_mesh != null:
            _target_line_mesh.visible = false
        if _target_3d_reticle != null:
            _target_3d_reticle.visible = false
        if _active_3d_beacon != null:
            _active_3d_beacon.visible = false
        return

    var active := _selected_ship
    if active == null or active.is_destroyed():
        if _target_line_mesh != null:
            _target_line_mesh.visible = false
        if _target_3d_reticle != null:
            _target_3d_reticle.visible = false
        if _active_3d_beacon != null:
            _active_3d_beacon.visible = false
        return

    if _active_3d_beacon != null:
        _active_3d_beacon.visible = true
        _active_3d_beacon.global_position = active.global_position
        _active_3d_beacon.rotate_y(0.02)

    if _ace_target != null and not _ace_target.is_destroyed():
        if _target_3d_reticle != null:
            _target_3d_reticle.visible = true
            _target_3d_reticle.global_position = _ace_target.global_position
            _target_3d_reticle.rotate_y(-0.025)

        var dist := active.state.position.distance_to(_ace_target.state.position)
        var in_range := dist <= active.weapon_range
        var in_arc := Combat.in_arc(active, _ace_target)

        var line_color := Color(0.25, 1.0, 0.6, 0.85)
        if not in_range:
            line_color = Color(1.0, 0.35, 0.3, 0.5)
            _target_3d_label.text = "▲ OUT OF RANGE: %.0fm / %.0fm" % [dist, active.weapon_range]
            _target_3d_label.modulate = Color(1.0, 0.45, 0.35)
        elif not in_arc:
            line_color = Color(1.0, 0.75, 0.25, 0.65)
            _target_3d_label.text = "◀ OUT OF FIRING CONE (YAW SHIP)"
            _target_3d_label.modulate = Color(1.0, 0.8, 0.3)
        else:
            line_color = Color(0.25, 1.0, 0.6, 0.85)
            _target_3d_label.text = "⌖ TARGET LOCKED // READY TO FIRE"
            _target_3d_label.modulate = Color(0.3, 1.0, 0.65)

        if _target_line_mesh != null and _target_line_immediate != null:
            _target_line_mesh.visible = true
            var mat: StandardMaterial3D = _target_line_mesh.material_override
            if mat != null:
                mat.albedo_color = line_color
                mat.emission = line_color

            _target_line_immediate.clear_surfaces()
            _target_line_immediate.surface_begin(Mesh.PRIMITIVE_LINES)
            _target_line_immediate.surface_set_color(line_color)
            _target_line_immediate.surface_add_vertex(active.global_position)
            _target_line_immediate.surface_add_vertex(_ace_target.global_position)
            _target_line_immediate.surface_end()
    else:
        if _target_3d_reticle != null:
            _target_3d_reticle.visible = false
        if _target_line_mesh != null:
            _target_line_mesh.visible = false

func _spawn_laser_beam(from_pos: Vector3, to_pos: Vector3, color: Color) -> void:
    var beam := MeshInstance3D.new()
    var imm := ImmediateMesh.new()
    beam.mesh = imm
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 4.5
    beam.material_override = mat
    add_child(beam)

    imm.clear_surfaces()
    imm.surface_begin(Mesh.PRIMITIVE_LINES)
    imm.surface_set_color(color)
    imm.surface_add_vertex(from_pos)
    imm.surface_add_vertex(to_pos)
    imm.surface_end()

    var tween := create_tween()
    tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
    tween.tween_callback(beam.queue_free)

func _spawn_impact_flash(pos: Vector3, color: Color) -> void:
    var flash := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.2
    sphere.height = 2.4
    flash.mesh = sphere
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
    flash.material_override = mat
    flash.position = pos
    add_child(flash)

    var tween := create_tween()
    tween.tween_property(flash, "scale", Vector3(3.2, 3.2, 3.2), 0.22)
    tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
    tween.chain().tween_callback(flash.queue_free)

func _spawn_combat_text(pos: Vector3, text: String, color: Color) -> void:
    var lbl := Label3D.new()
    lbl.text = text
    lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    lbl.modulate = color
    lbl.outline_modulate = Color(0.02, 0.02, 0.05, 0.95)
    lbl.outline_size = 3
    lbl.font_size = 20
    lbl.position = pos + Vector3.UP * 2.8
    add_child(lbl)

    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(lbl, "position:y", lbl.position.y + 3.0, 0.85)
    tween.tween_property(lbl, "modulate:a", 0.0, 0.85)
    tween.chain().tween_callback(lbl.queue_free)

func _add_combat_log(text: String, color: Color = Color.WHITE) -> void:
    var timestamp := "[T%d] " % TurnManager.turn_number
    _combat_logs.append(timestamp + text)
    if _combat_logs.size() > 5:
        _combat_logs.remove_at(0)

    if _combat_log_vbox != null:
        for child in _combat_log_vbox.get_children():
            child.queue_free()
        for log_entry in _combat_logs:
            var lbl := Label.new()
            lbl.text = log_entry
            lbl.add_theme_font_size_override("font_size", 11)
            lbl.add_theme_color_override("font_color", color)
            _combat_log_vbox.add_child(lbl)

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
    _player_ships.append(_spawn("vinculados_suit", Vector3(-14.0, 8.0, 38.0), Vector3.ZERO, 0))
    _player_ships.append(_spawn("vinculados_anima", Vector3(14.0, -6.0, 42.0), Vector3.ZERO, 0))
    _player_ships.append(_spawn("marea_galleon", Vector3(0.0, 2.0, 36.0), Vector3.ZERO, 0))

    _enemy_ships.append(_spawn("acero_dreadnought", Vector3(-8.0, 6.0, -42.0), Vector3(0.0, 0.0, 3.0), 1))
    _enemy_ships.append(_spawn("acero_corvette", Vector3(10.0, 4.0, -45.0), Vector3(0.0, 0.0, 3.0), 1))

    _tactical_grid.set_ships(_player_ships + _enemy_ships)

    for p in _player_ships:
        p.order.target_speed = 10.0
        p.order.yaw = 0.0
        p.order.pitch = 0.0

    _set_selected(_player_ships[0])
    _ace_target = _enemy_ships[0]

func _spawn(id: String, pos: Vector3, vel: Vector3, team: int) -> Ship:
    var def := LoreDB.get_ship(id)
    var ship := Ship.new()
    ship.apply_def(def)
    ship.initial_velocity = vel
    ship.position = pos
    ship.team = team
    ship.ether = _ether
    ship.clicked.connect(_on_ship_clicked)
    ship.right_clicked.connect(_on_ship_right_clicked)
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

    # 1. Top Command Bar (Sleek, transparent header)
    var top_panel := PanelContainer.new()
    top_panel.theme = _hud_theme
    top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 6)
    layer.add_child(top_panel)

    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 12)
    top_panel.add_child(top_row)

    # Canonical Barlovento Logo (Clear, framed AtlasTexture from assets/brand/logo.png)
    var logo_tex: Texture2D = load("res://assets/brand/logo.png")
    if logo_tex != null:
        var atlas := AtlasTexture.new()
        atlas.atlas = logo_tex
        # Crop directly into the centered title wordmark (X: 80..1296, Y: 220..500)
        atlas.region = Rect2(80, 220, 1216, 280)
        var logo_rect := TextureRect.new()
        logo_rect.texture = atlas
        logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        logo_rect.custom_minimum_size = Vector2(185, 38)
        logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        top_row.add_child(logo_rect)

    var sep0 := VSeparator.new()
    top_row.add_child(sep0)

    _stage_title_label = Label.new()
    _stage_title_label.text = "MISSION 01: THE SEVERED CHORD"
    _stage_title_label.add_theme_font_size_override("font_size", 12)
    _stage_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
    top_row.add_child(_stage_title_label)

    _objective_label = Label.new()
    _objective_label.text = "[FLOTILLA: 0/2 NEUTRALIZED]"
    _objective_label.add_theme_font_size_override("font_size", 11)
    _objective_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.85))
    top_row.add_child(_objective_label)

    var top_spacer := Control.new()
    top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(top_spacer)

    _initiative_label = Label.new()
    _initiative_label.add_theme_font_size_override("font_size", 11)
    _initiative_label.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
    top_row.add_child(_initiative_label)

    _range_label = Label.new()
    _range_label.add_theme_font_size_override("font_size", 11)
    _range_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
    top_row.add_child(_range_label)

    _phase_badge = Label.new()
    _phase_badge.add_theme_font_size_override("font_size", 12)
    _phase_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    top_row.add_child(_phase_badge)

    var help_btn := Button.new()
    help_btn.text = "MANUAL [H]"
    help_btn.pressed.connect(_toggle_help)
    top_row.add_child(help_btn)

    var reset_btn := Button.new()
    reset_btn.text = "RESET"
    reset_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
    top_row.add_child(reset_btn)

    # 2. Left Floating Tactical Command Deck (Allied Line-of-Battle & Hostile Contacts)
    _fleet_panel = PanelContainer.new()
    _fleet_panel.theme = _hud_theme
    _fleet_panel.position = Vector2(16, 58)
    _fleet_panel.custom_minimum_size = Vector2(268, 0)
    layer.add_child(_fleet_panel)

    var fleet_vbox := VBoxContainer.new()
    fleet_vbox.add_theme_constant_override("separation", 6)
    _fleet_panel.add_child(fleet_vbox)

    var allied_lbl := Label.new()
    allied_lbl.text = "ALLIED LINE OF BATTLE"
    allied_lbl.add_theme_font_size_override("font_size", 11)
    allied_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
    fleet_vbox.add_child(allied_lbl)

    _allied_list_vbox = VBoxContainer.new()
    _allied_list_vbox.add_theme_constant_override("separation", 4)
    fleet_vbox.add_child(_allied_list_vbox)

    var sep_fl := HSeparator.new()
    fleet_vbox.add_child(sep_fl)

    var hostile_lbl := Label.new()
    hostile_lbl.text = "HOSTILE CONTACTS"
    hostile_lbl.add_theme_font_size_override("font_size", 11)
    hostile_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))
    fleet_vbox.add_child(hostile_lbl)

    _hostile_list_vbox = VBoxContainer.new()
    _hostile_list_vbox.add_theme_constant_override("separation", 4)
    fleet_vbox.add_child(_hostile_list_vbox)

    # 3. Floating Round Notification Banner
    _round_banner = PanelContainer.new()
    _round_banner.theme = _hud_theme
    _round_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)
    _round_banner.position.y = 58
    _round_banner.visible = false
    layer.add_child(_round_banner)

    _round_banner_label = Label.new()
    _round_banner_label.add_theme_font_size_override("font_size", 13)
    _round_banner.add_child(_round_banner_label)

    # 4. Floating Tactical Sensor Feed (Combat Event Log)
    var log_panel := PanelContainer.new()
    log_panel.theme = _hud_theme
    log_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
    log_panel.position = Vector2(-280, 58)
    log_panel.custom_minimum_size = Vector2(268, 120)
    layer.add_child(log_panel)

    var log_outer := VBoxContainer.new()
    log_outer.add_theme_constant_override("separation", 2)
    log_panel.add_child(log_outer)

    var log_title := Label.new()
    log_title.text = "TACTICAL SENSOR FEED // PSALM-4"
    log_title.add_theme_font_size_override("font_size", 10)
    log_title.add_theme_color_override("font_color", Color(0.55, 0.75, 0.95))
    log_outer.add_child(log_title)

    _combat_log_vbox = VBoxContainer.new()
    _combat_log_vbox.add_theme_constant_override("separation", 1)
    log_outer.add_child(_combat_log_vbox)

    # 5. Bottom Command Panels (OrderPanel & AcePanel)
    var bottom_container := VBoxContainer.new()
    bottom_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 6)
    bottom_container.add_theme_constant_override("separation", 4)
    layer.add_child(bottom_container)

    var panels_row := HBoxContainer.new()
    panels_row.add_theme_constant_override("separation", 8)
    bottom_container.add_child(panels_row)

    _order_panel = OrderPanel.new()
    _order_panel.theme = _hud_theme
    _order_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _order_panel.intercept_pressed.connect(_intercept_target)
    panels_row.add_child(_order_panel)

    _ace_panel = AcePanel.new()
    _ace_panel.theme = _hud_theme
    _ace_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _ace_panel.visible = false
    _ace_panel.execute_round_pressed.connect(_execute_ace_round)
    _ace_panel.cycle_target_pressed.connect(_cycle_hostile_target)
    _ace_panel.intercept_pressed.connect(_intercept_target)
    _ace_panel.ability_used.connect(_on_ace_ability_used)
    _ace_panel.exit_pressed.connect(func() -> void:
        _add_combat_log("Disengaging Ace combat. Returning to strategic WEGO planning.", Color(0.4, 0.9, 1.0))
        TurnManager.exit_ace_mode()
    )
    _ace_panel.yaw_left.connect(func() -> void:
        if _selected_ship != null:
            _selected_ship.order.yaw += deg_to_rad(15.0)
    )
    _ace_panel.yaw_right.connect(func() -> void:
        if _selected_ship != null:
            _selected_ship.order.yaw -= deg_to_rad(15.0)
    )
    _ace_panel.pitch_up.connect(func() -> void:
        if _selected_ship != null:
            _selected_ship.order.pitch = clampf(_selected_ship.order.pitch + deg_to_rad(15.0), -PITCH_LIMIT, PITCH_LIMIT)
    )
    _ace_panel.pitch_down.connect(func() -> void:
        if _selected_ship != null:
            _selected_ship.order.pitch = clampf(_selected_ship.order.pitch - deg_to_rad(15.0), -PITCH_LIMIT, PITCH_LIMIT)
    )
    _ace_panel.speed_up.connect(func() -> void:
        if _selected_ship != null:
            _selected_ship.order.target_speed = clampf(_selected_ship.order.target_speed + 4.0, 0.0, _selected_ship.state.max_speed)
    )
    _ace_panel.speed_down.connect(func() -> void:
        if _selected_ship != null:
            _selected_ship.order.target_speed = clampf(_selected_ship.order.target_speed - 4.0, 0.0, _selected_ship.state.max_speed)
    )
    _ace_panel.stop_pressed.connect(func() -> void:
        if _selected_ship != null:
            _selected_ship.order.target_speed = 0.0
    )
    panels_row.add_child(_ace_panel)

    _resolve_panel = PanelContainer.new()
    _resolve_panel.theme = _hud_theme
    _resolve_panel.visible = false
    bottom_container.add_child(_resolve_panel)

    var res_vbox := VBoxContainer.new()
    res_vbox.add_theme_constant_override("separation", 2)
    _resolve_panel.add_child(res_vbox)

    _resolve_label = Label.new()
    _resolve_label.add_theme_font_size_override("font_size", 14)
    _resolve_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
    res_vbox.add_child(_resolve_label)

    _resolve_bar = ProgressBar.new()
    _resolve_bar.custom_minimum_size = Vector2(0, 14)
    res_vbox.add_child(_resolve_bar)

    _action_bar = HBoxContainer.new()
    _action_bar.add_theme_constant_override("separation", 6)
    bottom_container.add_child(_action_bar)

    var focus_btn := Button.new()
    focus_btn.text = "FOCUS [V]"
    focus_btn.pressed.connect(func() -> void:
        if _selected_ship != null and _camera_rig != null:
            _camera_rig.focus_on(_selected_ship.global_position)
    )
    _action_bar.add_child(focus_btn)

    var grid_btn := Button.new()
    grid_btn.text = "GRID [G]"
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
    engage_btn.pressed.connect(_engage_ace_mode)
    _action_bar.add_child(engage_btn)

    var resolve_btn := Button.new()
    resolve_btn.text = "EXECUTE WEGO TURN [SPACE]"
    resolve_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
    resolve_btn.pressed.connect(_execute_current_phase)
    _action_bar.add_child(resolve_btn)

    _refresh_fleet_panel()
    _build_help_overlay(layer)
    _build_victory_overlay(layer)
    _build_defeat_overlay(layer)
    _disable_button_focus(layer)

func _refresh_fleet_panel() -> void:
    if _allied_list_vbox == null or _hostile_list_vbox == null:
        return
    for child in _allied_list_vbox.get_children():
        child.queue_free()
    for child in _hostile_list_vbox.get_children():
        child.queue_free()

    for ship in _player_ships:
        _allied_list_vbox.add_child(_create_ship_roster_card(ship, false))

    for enemy in _enemy_ships:
        _hostile_list_vbox.add_child(_create_ship_roster_card(enemy, true))

    if _fleet_panel != null:
        _disable_button_focus(_fleet_panel)
    _check_stage_objectives()

func _create_ship_roster_card(ship: Ship, is_enemy: bool) -> Control:
    var card := PanelContainer.new()
    card.theme = _hud_theme
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 2)
    card.add_child(vbox)

    var is_selected := not is_enemy and ship == _selected_ship
    var is_locked := is_enemy and ship == _ace_target
    var destroyed := ship.is_destroyed()

    # Header Button
    var btn := Button.new()
    btn.focus_mode = Control.FOCUS_NONE

    var prefix := ""
    if is_enemy:
        prefix = "⌖ LOCKED: " if is_locked else "⌖ CONTACT: "
    else:
        prefix = "▶ ACTIVE: " if is_selected else "  "

    var name_str := "%s%s" % [prefix, ship.ship_name]
    if destroyed:
        name_str = "[DESTROYED] %s" % ship.ship_name
    btn.text = name_str

    if is_enemy:
        if destroyed:
            btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
        elif is_locked:
            btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.25))
        else:
            btn.add_theme_color_override("font_color", Color(1.0, 0.75, 0.65))
        btn.pressed.connect(func() -> void:
            if not destroyed:
                _ace_target = ship
                if _tactical_grid != null:
                    _tactical_grid.target_ship = ship
                if _ace_panel != null:
                    _ace_panel.target = ship
                if _selected_ship != null:
                    _selected_ship.target_ship = ship
                AudioManager.play_sfx("ui_hover", -6.0)
                _refresh_fleet_panel()
                _add_combat_log("Hostile targeted: %s [%s]" % [ship.ship_name, ship.pilot_name], Color(1.0, 0.65, 0.3))
        )
    else:
        if destroyed:
            btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
        elif is_selected:
            btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
        else:
            btn.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
        btn.pressed.connect(func() -> void:
            if not destroyed:
                _set_selected(ship)
        )
    vbox.add_child(btn)

    if not destroyed and is_enemy:
        var intercept_btn := Button.new()
        intercept_btn.text = "🎯 INTERCEPT WITH ACTIVE SHIP"
        intercept_btn.add_theme_font_size_override("font_size", 10)
        intercept_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
        intercept_btn.focus_mode = Control.FOCUS_NONE
        intercept_btn.pressed.connect(func() -> void:
            _ace_target = ship
            if _tactical_grid != null:
                _tactical_grid.target_ship = ship
            if _ace_panel != null:
                _ace_panel.target = ship
            if _selected_ship != null:
                _selected_ship.target_ship = ship
            _intercept_target()
            _refresh_fleet_panel()
        )
        vbox.add_child(intercept_btn)

    if not destroyed:
        # Sub-info Row: Pilot / Role & Speed / Range
        var sub_row := HBoxContainer.new()
        sub_row.add_theme_constant_override("separation", 6)
        vbox.add_child(sub_row)

        var pilot_lbl := Label.new()
        pilot_lbl.text = ship.pilot_name if ship.pilot_name != "" else ship.faction.to_upper()
        pilot_lbl.add_theme_font_size_override("font_size", 10)
        pilot_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
        sub_row.add_child(pilot_lbl)

        var sp_sub := Control.new()
        sp_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        sub_row.add_child(sp_sub)

        var status_lbl := Label.new()
        if is_enemy:
            var dist := _selected_ship.state.position.distance_to(ship.state.position) if _selected_ship != null else 0.0
            status_lbl.text = "RANGE: %.0fm" % dist
            status_lbl.add_theme_color_override("font_color", Color(0.95, 0.65, 0.5))
        else:
            var stance_str := "EVASIVE" if ship.stance == Ship.Stance.EVASIVE else "ATTACK"
            status_lbl.text = "%.1fm/s [%s]" % [ship.speed(), stance_str]
            status_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65) if ship.stance == Ship.Stance.FIRE else Color(0.4, 0.9, 1.0))
        status_lbl.add_theme_font_size_override("font_size", 10)
        sub_row.add_child(status_lbl)

        # Health bar row
        var hp_row := HBoxContainer.new()
        hp_row.add_theme_constant_override("separation", 4)
        vbox.add_child(hp_row)

        var hp_bar := ProgressBar.new()
        hp_bar.custom_minimum_size = Vector2(0, 8)
        hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hp_bar.show_percentage = false
        hp_bar.max_value = ship.max_hp
        hp_bar.value = ship.hp
        hp_row.add_child(hp_bar)

        var hp_txt := Label.new()
        hp_txt.text = "%.0f/%.0f HP" % [ship.hp, ship.max_hp]
        hp_txt.add_theme_font_size_override("font_size", 9)
        hp_txt.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95))
        hp_row.add_child(hp_txt)

    return card

func _update_hud_telemetry() -> void:
    if TurnManager.is_resolving():
        var remaining := TurnManager.remaining_resolve_time()
        if TurnManager.phase == TurnManager.Phase.ACE_RESOLVE:
            _resolve_label.text = "TACTICAL ROUND %d RESOLUTION: %.1f s REMAINING" % [TurnManager.ace_round, remaining]
            _resolve_bar.max_value = TurnManager.ace_resolution_window
        else:
            _resolve_label.text = "SIMULTANEOUS WEGO RESOLUTION: %.1f s REMAINING" % remaining
            _resolve_bar.max_value = TurnManager.admiral_resolution_window
        _resolve_bar.value = remaining
    else:
        var dist := _nearest_enemy_distance()
        if dist < INF:
            _range_label.text = "CLOSEST: %.0fm" % dist
        else:
            _range_label.text = "SECTOR SECURED"

    var initiative := _calculate_initiative()
    _initiative_label.text = initiative

func _calculate_initiative() -> String:
    var player_advantage := 0
    for p in _player_ships:
        if p.is_destroyed():
            continue
        var to_wind := _ether.direction.dot(p.state.velocity)
        if to_wind > 0.5:
            player_advantage += 1
    if player_advantage >= 2:
        return "GAUGE: ↗ +CURRENT (+1.6 kN)"
    elif player_advantage == 1:
        return "GAUGE: → NEUTRAL (1.6 kN)"
    else:
        return "GAUGE: ↙ -CALM (0.0 kN)"

func _on_phase_changed(phase: int) -> void:
    _phase_badge.text = _phase_text(phase)
    var in_ace := TurnManager.is_in_ace()
    var resolving := TurnManager.is_resolving()

    _order_panel.visible = not in_ace and not resolving
    _ace_panel.visible = in_ace and not resolving
    _action_bar.visible = not in_ace and not resolving
    _resolve_panel.visible = resolving
    _round_banner.visible = in_ace

    if in_ace and not resolving:
        _update_round_banner()
    _refresh_fleet_panel()

func _update_round_banner() -> void:
    if _round_banner == null or _round_banner_label == null:
        return
    _round_banner.visible = true
    _round_banner_label.text = "ACE TACTICAL COMBAT // ROUND %d — PLAN ORDERS & PRESS SPACE TO RESOLVE" % TurnManager.ace_round
    _round_banner_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.8))

func _phase_text(phase: int) -> String:
    match phase:
        TurnManager.Phase.ADMIRAL_RESOLVE:
            return "WEGO RESOLUTION // T%d" % TurnManager.turn_number
        TurnManager.Phase.ACE_PLAN:
            return "ACE COMBAT // ROUND %d" % TurnManager.ace_round
        TurnManager.Phase.ACE_RESOLVE:
            return "ACE RESOLUTION // R%d" % TurnManager.ace_round
        _:
            return "ADMIRAL WEGO // T%d" % TurnManager.turn_number

func _check_stage_objectives() -> void:
    if _mission_completed:
        return

    var enemies_alive := 0
    for enemy in _enemy_ships:
        if not enemy.is_destroyed():
            enemies_alive += 1

    var players_alive := 0
    for player in _player_ships:
        if not player.is_destroyed():
            players_alive += 1

    var flagship_alive := not _player_ships[0].is_destroyed()
    var flagship_hp_pct := roundi((_player_ships[0].hp / maxf(_player_ships[0].max_hp, 1.0)) * 100.0)

    if _objective_label != null:
        _objective_label.text = "[FLOTILLA: %d/2 DESTROYED | FLAGSHIP: %d%% HP]" % [
            2 - enemies_alive, flagship_hp_pct
        ]

    if enemies_alive == 0:
        _mission_completed = true
        _show_mission_victory()
    elif players_alive == 0 or not flagship_alive:
        _mission_completed = true
        _show_mission_defeat()

func _show_mission_victory() -> void:
    AudioManager.play_sfx("shockwave", 0.0)
    AudioManager.play_sfx("explosion_big", 0.0)
    _add_combat_log("MISSION ACCOMPLISHED: SECTOR PSALM-4 SECURED!", Color(0.3, 1.0, 0.6))
    if _victory_overlay != null:
        _victory_overlay.visible = true

func _show_mission_defeat() -> void:
    AudioManager.play_sfx("shockwave", 0.0)
    AudioManager.play_sfx("explosion_big", 0.0)
    _add_combat_log("MISSION FAILED: COMMAND FRAME DESTROYED", Color(1.0, 0.3, 0.3))
    if _defeat_overlay != null:
        _defeat_overlay.visible = true

func _build_victory_overlay(layer: CanvasLayer) -> void:
    _victory_overlay = Control.new()
    _victory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _victory_overlay.visible = false
    layer.add_child(_victory_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.01, 0.04, 0.08, 0.80)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _victory_overlay.add_child(dim)

    var panel := PanelContainer.new()
    panel.theme = _hud_theme
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(540, 280)
    _victory_overlay.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 12)
    panel.add_child(vbox)

    var title := Label.new()
    title.text = "MISSION ACCOMPLISHED"
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
    vbox.add_child(title)

    var sub := Label.new()
    sub.text = "Sector Psalm-4 // Resonance Well Secured\n\nThe Acero strike group has been repelled.\nThe Vinculados choir maintains neural resonance with the Éther currents."
    sub.add_theme_font_size_override("font_size", 13)
    sub.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
    vbox.add_child(sub)

    var sep := HSeparator.new()
    vbox.add_child(sep)

    var btn_row := HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 12)
    vbox.add_child(btn_row)

    var replay_btn := Button.new()
    replay_btn.text = "REPLAY STAGE"
    replay_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
    btn_row.add_child(replay_btn)

func _build_defeat_overlay(layer: CanvasLayer) -> void:
    _defeat_overlay = Control.new()
    _defeat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _defeat_overlay.visible = false
    layer.add_child(_defeat_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.08, 0.01, 0.02, 0.82)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _defeat_overlay.add_child(dim)

    var panel := PanelContainer.new()
    panel.theme = _hud_theme
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(540, 280)
    _defeat_overlay.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 12)
    panel.add_child(vbox)

    var title := Label.new()
    title.text = "MISSION FAILED"
    title.add_theme_font_size_override("font_size", 20)
    title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
    vbox.add_child(title)

    var sub := Label.new()
    sub.text = "Flagship Link Severed // The Choir Falls Silent\n\nCommand Frame Eidolon Prime was destroyed or fell Cold.\nThe Acero Armada has occupied the resonance well."
    sub.add_theme_font_size_override("font_size", 13)
    sub.add_theme_color_override("font_color", Color(0.95, 0.8, 0.8))
    vbox.add_child(sub)

    var sep := HSeparator.new()
    vbox.add_child(sep)

    var btn_row := HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 12)
    vbox.add_child(btn_row)

    var retry_btn := Button.new()
    retry_btn.text = "RETRY MISSION"
    retry_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
    btn_row.add_child(retry_btn)

func _build_help_overlay(layer: CanvasLayer) -> void:
    _help_overlay = Control.new()
    _help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _help_overlay.visible = false
    layer.add_child(_help_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0.01, 0.02, 0.05, 0.80)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _help_overlay.add_child(dim)

    var panel := PanelContainer.new()
    panel.theme = _hud_theme
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    panel.custom_minimum_size = Vector2(840, 480)
    _help_overlay.add_child(panel)

    var main_vbox := VBoxContainer.new()
    main_vbox.add_theme_constant_override("separation", 8)
    panel.add_child(main_vbox)

    var header_row := HBoxContainer.new()
    main_vbox.add_child(header_row)

    var title := Label.new()
    title.text = "BARLOVENTO // TACTICAL DOCTRINE & FLIGHT MANUAL"
    title.add_theme_font_size_override("font_size", 15)
    title.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
    header_row.add_child(title)

    var header_spacer := Control.new()
    header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_row.add_child(header_spacer)

    var close_top_btn := Button.new()
    close_top_btn.text = "✕ CLOSE [ESC / H]"
    close_top_btn.pressed.connect(_toggle_help)
    header_row.add_child(close_top_btn)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    main_vbox.add_child(scroll)

    var content_box := VBoxContainer.new()
    content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_box.add_theme_constant_override("separation", 10)
    scroll.add_child(content_box)

    var columns_row := HBoxContainer.new()
    columns_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns_row.add_theme_constant_override("separation", 16)
    content_box.add_child(columns_row)

    # Column 1: Admiral Phase
    var col1 := VBoxContainer.new()
    col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col1.add_theme_constant_override("separation", 6)
    columns_row.add_child(col1)

    var col1_title := Label.new()
    col1_title.text = "PHASE 1: ADMIRAL (STRATEGIC APPROACH)"
    col1_title.add_theme_font_size_override("font_size", 13)
    col1_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    col1.add_child(col1_title)

    var col1_text := Label.new()
    col1_text.text = """Simultaneous 12-second movement window to position fleets and fight for the weather gauge:

A / D / Arrows     Turn Port / Starboard (Yaw)
Q / E / UP / DN    Climb / Dive (Pitch Up / Down)
W / S              Increase / Decrease throttle
X                  Emergency full retrograde brake
Tab / Click        Select fleet unit
Space              Execute simultaneous WEGO turn

• INERTIA & MOMENTUM: Ships drift until counter-thrust is applied.
• ÉTHER WINDS: Sailing along currents provides speed and tactical advantage."""
    col1_text.add_theme_font_size_override("font_size", 11)
    col1_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col1.add_child(col1_text)

    # Column 2: Ace Tactical Phase
    var col2 := VBoxContainer.new()
    col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col2.add_theme_constant_override("separation", 6)
    columns_row.add_child(col2)

    var col2_title := Label.new()
    col2_title.text = "PHASE 2: ACE (SIMULTANEOUS COMBAT ROUNDS)"
    col2_title.add_theme_font_size_override("font_size", 13)
    col2_title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
    col2.add_child(col2_title)

    var col2_text := Label.new()
    col2_text.text = """Intense close-range 3.5s tactical rounds where all units move and resolve combat simultaneously:

1. PLAN: Set heading (Yaw), pitch (Climb/Dive), and speed for your Ace and squadron.
2. TARGET: Click any enemy in 3D or press [C] to lock target.
3. STANCE: Choose Attack (fire lasers during round) or Evasive Drift (+35% defense).
4. RESOLVE: Press SPACE to execute the round! All ships burn thrusters, drift, and open fire simultaneously.

CAMERA & BATTLEFIELD:
Left/Middle Drag   Pan battlefield plane
Right-Click Drag   Orbit tactical camera
Mouse Wheel        Zoom in / out
V                  Focus camera on selected ship
G                  Toggle 3D tactical grid & altitude stems"""
    col2_text.add_theme_font_size_override("font_size", 11)
    col2_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    col2.add_child(col2_text)

    var footer_btn := Button.new()
    footer_btn.text = "RETURN TO TACTICAL SIMULATION [ESC / H]"
    footer_btn.pressed.connect(_toggle_help)
    main_vbox.add_child(footer_btn)

func _toggle_help() -> void:
    if _help_overlay != null:
        _help_overlay.visible = not _help_overlay.visible

func _make_theme() -> Theme:
    var theme := Theme.new()
    theme.default_font_size = 12

    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.015, 0.035, 0.07, 0.62)
    panel_style.border_color = Color(0.20, 0.70, 0.90, 0.35)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(6)
    panel_style.set_content_margin_all(8)
    theme.set_stylebox("panel", "PanelContainer", panel_style)

    var btn_normal := StyleBoxFlat.new()
    btn_normal.bg_color = Color(0.04, 0.09, 0.16, 0.68)
    btn_normal.border_color = Color(0.25, 0.65, 0.85, 0.30)
    btn_normal.set_border_width_all(1)
    btn_normal.set_corner_radius_all(5)
    btn_normal.set_content_margin_all(5)
    theme.set_stylebox("normal", "Button", btn_normal)

    var btn_hover := StyleBoxFlat.new()
    btn_hover.bg_color = Color(0.08, 0.18, 0.30, 0.85)
    btn_hover.border_color = Color(0.35, 0.90, 1.0, 0.80)
    btn_hover.set_border_width_all(1)
    btn_hover.set_corner_radius_all(5)
    btn_hover.set_content_margin_all(5)
    theme.set_stylebox("hover", "Button", btn_hover)

    var btn_pressed := StyleBoxFlat.new()
    btn_pressed.bg_color = Color(0.12, 0.28, 0.40, 0.95)
    btn_pressed.border_color = Color(1.0, 0.85, 0.35, 0.90)
    btn_pressed.set_border_width_all(1)
    btn_pressed.set_corner_radius_all(5)
    btn_pressed.set_content_margin_all(5)
    theme.set_stylebox("pressed", "Button", btn_pressed)

    var btn_disabled := StyleBoxFlat.new()
    btn_disabled.bg_color = Color(0.03, 0.05, 0.08, 0.40)
    btn_disabled.border_color = Color(0.15, 0.25, 0.35, 0.20)
    btn_disabled.set_border_width_all(1)
    btn_disabled.set_corner_radius_all(5)
    btn_disabled.set_content_margin_all(5)
    theme.set_stylebox("disabled", "Button", btn_disabled)

    var pb_bg := StyleBoxFlat.new()
    pb_bg.bg_color = Color(0.02, 0.04, 0.08, 0.75)
    pb_bg.border_color = Color(0.2, 0.45, 0.65, 0.35)
    pb_bg.set_border_width_all(1)
    pb_bg.set_corner_radius_all(3)
    theme.set_stylebox("background", "ProgressBar", pb_bg)

    var pb_fill := StyleBoxFlat.new()
    pb_fill.bg_color = Color(0.25, 0.88, 0.55, 0.95)
    pb_fill.set_corner_radius_all(3)
    theme.set_stylebox("fill", "ProgressBar", pb_fill)

    theme.set_color("font_color", "Button", Color(0.85, 0.95, 1.0))
    theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
    theme.set_color("font_disabled_color", "Button", Color(0.55, 0.60, 0.68, 0.6))
    theme.set_color("font_color", "Label", Color(0.85, 0.92, 0.98))

    return theme

func _disable_button_focus(node: Node) -> void:
    for child in node.get_children():
        if child is Button:
            child.focus_mode = Control.FOCUS_NONE
        _disable_button_focus(child)

func _setup_input_actions() -> void:
    _add_action("move_forward", [KEY_W])
    _add_action("move_back", [KEY_S])
    _add_action("yaw_left", [KEY_A, KEY_LEFT])
    _add_action("yaw_right", [KEY_D, KEY_RIGHT])
    _add_action("pitch_up", [KEY_Q, KEY_UP])
    _add_action("pitch_down", [KEY_E, KEY_DOWN])
    _add_action("resolve", [KEY_SPACE])
    _add_action("cycle", [KEY_TAB])
    _add_action("stop", [KEY_X])
    _add_action("focus_ship", [KEY_V])
    _add_action("toggle_grid", [KEY_G])
    _add_action("help", [KEY_H, KEY_ESCAPE])
    _add_action("ace_cycle", [KEY_C])
    _add_action("intercept_target", [KEY_T])

func _add_action(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for key in keys:
        var event := InputEventKey.new()
        event.physical_keycode = key
        InputMap.action_add_event(action, event)
