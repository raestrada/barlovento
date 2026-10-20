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
var _cmd_port: TextureRect
var _phase_badge: Label
var _turn_label_prefix: Label
var _turn_label_phase: Label
var _weather_panel: HudWidgets.WeatherInitiativePanel
var _callout_overlay: HudWidgets.ShipCalloutOverlay
var _ace_top_banner: HudWidgets.AceTopBanner
var _roster_modal: HudWidgets.HeroRosterModal
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
var _help_overlay: Control
var _victory_overlay: Control
var _defeat_overlay: Control
var _hud_theme: Theme
var _ether_particles: Node3D
var _asteroid_root: Node3D
var _calm_wall_root: Node3D
var _sluice_station_root: Node3D
var _is_vector_dragging: bool = false

var _mission_completed: bool = false
var _victory_title_label: Label
var _victory_sub_label: Label
var _victory_next_btn: Button
var _admiral_chart: AdmiralChart
var _admiral_layer: CanvasLayer
var _strategic_bonuses: Dictionary = {}

func _ready() -> void:
	TurnManager.reset()
	_setup_input_actions()

	PhysicsSim.bounds = AABB(
		Vector3(-TacticalGrid.GRID_HALF_SPAN, -TacticalGrid.BOUNDS_HALF_HEIGHT, -TacticalGrid.GRID_HALF_SPAN),
		Vector3(TacticalGrid.GRID_HALF_SPAN * 2.0, TacticalGrid.BOUNDS_HALF_HEIGHT * 2.0, TacticalGrid.GRID_HALF_SPAN * 2.0)
	)

	_ether = EtherField.new()
	if LoreDB.current_stage_id == "acero_stage_2":
		_ether.direction = Vector3(0.85, 0.25, -0.45).normalized()
		_ether.strength = 2.1
		_ether.wavelength = 55.0
	elif LoreDB.current_stage_id == "acero_stage_3":
		_ether.direction = Vector3(-0.75, 0.18, 0.62).normalized()
		_ether.strength = 2.4
		_ether.wavelength = 50.0
	else:
		_ether.direction = Vector3(1.0, 0.2, 0.35).normalized()
		_ether.strength = 1.6
		_ether.wavelength = 65.0

	_build_environment()
	_build_camera()
	_build_ether_flow()
	_build_asteroid_field()
	_build_calm_wavefront()
	_build_sluice_station()
	_build_tactical_grid()
	_spawn_fleets()
	_build_trajectory_preview()
	_build_3d_targeting_hud()
	_build_hud()
	_set_selected(_player_ships[0])

	AudioManager.play_battle_music(-10.0)
	AudioManager.start_ambient(-26.0)

	TurnManager.phase_changed.connect(_on_phase_changed)
	TurnManager.admiral_resolve_finished.connect(_on_admiral_resolve_finished)
	TurnManager.ace_resolve_finished.connect(_on_ace_resolve_finished)
	TurnManager.ace_fire_moment.connect(_on_ace_fire_moment)

	_on_phase_changed(TurnManager.phase)
	if SaveManager.pending_load_battle and SaveManager.has_tactical_save():
		SaveManager.pending_load_battle = false
		_load_battle_state()
		return

	match LoreDB.current_stage_id:
		"acero_stage_1":
			_add_combat_log("ACT I // STAGE 01: Sluice Station Well-09 under Corsair raid!", Color(1.0, 0.72, 0.28))
			_add_combat_log("Adm. Vane: \"Hold the Line of Battle. Present bow armor and cross their T!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_2":
			_add_combat_log("ACT I // STAGE 02: Resonance Spire — Vinculados Choir Wing detected!", Color(0.85, 0.45, 1.0))
			_add_combat_log("Adm. Vane: \"Their mobile suits ride the crosswind. Use Weather-Gauge [BARLOVENTO] & broadsides!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_3":
			_add_combat_log("ACT I // STAGE 03: The Calm Threshold — Grand Coalition Fleet ahead!", Color(1.0, 0.45, 0.30))
			_add_combat_log("Adm. Vane: \"The Calm is behind us. Anchor the Anvil line — Steel Endures!\"", Color(0.4, 0.92, 1.0))
		_:
			_add_combat_log("Tactical link established. Outer Veil // Sector Psalm-4.", Color(0.4, 0.9, 1.0))
			_add_combat_log("Tip: Hold [SHIFT + Left-Click/Drag] on the 3D plane to aim vector & speed.", Color(1.0, 0.85, 0.3))

	# Auto-save initial tactical state at start of stage
	_save_battle_state(true)
	_open_admiral_chart()

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
	_update_scenery(delta)
	_update_hud_telemetry()
	_update_3d_targeting_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _admiral_chart != null and _admiral_chart.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.is_action_pressed("resolve"):
				_admiral_chart.execute_strategic_turn()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_admiral_chart._trigger_3d_engagement()
			elif event.is_action_pressed("toggle_roster") and _roster_modal != null:
				_roster_modal.visible = not _roster_modal.visible
		return
	# Direct 3D Plane Vector Steering via Shift + Left-Click / Drag
	if not TurnManager.is_resolving():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and Input.is_key_pressed(KEY_SHIFT):
				_is_vector_dragging = true
				_apply_mouse_vector_steering(event.position, true)
				return
			elif not event.pressed and _is_vector_dragging:
				_is_vector_dragging = false
				return
		elif event is InputEventMouseMotion and _is_vector_dragging:
			if Input.is_key_pressed(KEY_SHIFT):
				_apply_mouse_vector_steering(event.position, false)
				return
			else:
				_is_vector_dragging = false

	if event is InputEventKey and event.echo:
		return
	if not event.is_pressed():
		return

	if event.is_action_pressed("quick_save"):
		_save_battle_state(false)
		return
	if event.is_action_pressed("quick_load"):
		_load_battle_state()
		return
	if event.is_action_pressed("help"):
		if _roster_modal != null and _roster_modal.visible:
			_roster_modal.visible = false
			return
		_toggle_help()
		return
	if event.is_action_pressed("toggle_roster"):
		if _roster_modal != null:
			_roster_modal.visible = not _roster_modal.visible
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
		elif event is InputEventKey and event.keycode == KEY_Y:
			if _ace_panel != null:
				_ace_panel.toggle_weapon_arcs()

func _apply_mouse_vector_steering(screen_pos: Vector2, play_feedback: bool) -> void:
	if _selected_ship == null or _selected_ship.is_destroyed():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var ray_origin := cam.project_ray_origin(screen_pos)
	var ray_dir := cam.project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 0.001:
		return
	var plane_y := _selected_ship.global_position.y
	var t := (plane_y - ray_origin.y) / ray_dir.y
	if t <= 0.0:
		return
	var hit_pos := ray_origin + ray_dir * t
	var delta_vec := hit_pos - _selected_ship.global_position
	delta_vec.y = 0.0
	var dist := delta_vec.length()
	if dist < 1.0:
		return

	_set_order_heading(_selected_ship, delta_vec.normalized())
	var max_drag_dist := 55.0 if not TurnManager.is_in_ace() else 28.0
	var speed_ratio := clampf(dist / max_drag_dist, 0.15, 1.0)
	_selected_ship.order.target_speed = roundf(speed_ratio * _selected_ship.state.max_speed * 2.0) * 0.5

	if play_feedback:
		AudioManager.play_sfx("ui_hover", -10.0)
		_spawn_impact_flash(hit_pos, Color(0.3, 0.95, 1.0, 0.6))

func _handle_flight_controls(delta: float) -> void:
	if _selected_ship == null or (_admiral_chart != null and _admiral_chart.visible):
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

func _predict_target_pos(target: Ship, lead_time: float) -> Vector3:
	return target.state.position + target.state.velocity * lead_time

func _compute_tactical_heading(ship: Ship, target: Ship, lead_time: float) -> Vector3:
	var predicted := _predict_target_pos(target, lead_time)
	var to_target := predicted - ship.state.position
	var dist := to_target.length()
	if dist < 0.1:
		return ship.state.forward
	var dir := to_target / dist

	# Capital warships with broadside batteries angle 52 degrees ("Crossing the T" / angled broadside)
	# when inside optimal firing envelope (22m..46m) to bring both forward & broadside batteries to bear
	if (ship.ship_id == "acero_dreadnought" or ship.ship_id == "marea_galleon") and dist >= 22.0 and dist <= 46.0:
		var port_hp := ship.armor_port
		var stbd_hp := ship.armor_stbd
		# Present the healthier armor flank toward the enemy!
		var angle_sign := 1.0 if port_hp >= stbd_hp else -1.0
		var angled := dir.rotated(Vector3.UP, deg_to_rad(52.0 * angle_sign))
		return angled.normalized()

	return dir

func _plan_ai_orders() -> void:
	var flagship: Ship = null
	for s in _enemy_ships:
		if not s.is_destroyed():
			flagship = s
			break
	if flagship == null:
		return

	var primary_target := _nearest_player_ship(flagship)
	if primary_target == null:
		return

	for i in range(_enemy_ships.size()):
		var enemy := _enemy_ships[i]
		if enemy.is_destroyed():
			continue
		var tgt := _nearest_player_ship(enemy)
		if tgt == null:
			tgt = primary_target
		var dist := enemy.state.position.distance_to(tgt.state.position)
		if i == 0:
			var heading := _compute_tactical_heading(enemy, tgt, 3.5)
			_set_order_heading(enemy, heading)
			if dist > 48.0:
				enemy.order.target_speed = enemy.state.max_speed * 0.65
			elif dist > 22.0:
				enemy.order.target_speed = 3.5
			else:
				enemy.order.target_speed = 0.0
		else:
			var heading := _compute_tactical_heading(enemy, tgt, 2.5)
			_set_order_heading(enemy, heading)
			if dist > 42.0:
				enemy.order.target_speed = enemy.state.max_speed * 0.68
			elif dist > 18.0:
				enemy.order.target_speed = 4.2
			else:
				enemy.order.target_speed = 0.0

func _plan_ai_tactical_orders() -> void:
	# Focus-fire utility scoring: prioritize highest threat / lowest HP player unit in range
	var best_focus_target: Ship = null
	var best_score := -INF
	for p in _player_ships:
		if p.is_destroyed():
			continue
		var hp_ratio := p.hp / maxf(p.max_hp, 1.0)
		var score := (1.0 - hp_ratio) * 45.0
		if not _enemy_ships.is_empty() and not _enemy_ships[0].is_destroyed():
			var d := _enemy_ships[0].state.position.distance_to(p.state.position)
			score -= d * 0.5
		if score > best_score:
			best_score = score
			best_focus_target = p

	for ship in _enemy_ships:
		if ship.is_destroyed():
			continue
		var target := best_focus_target if best_focus_target != null and not best_focus_target.is_destroyed() else _nearest_player_ship(ship)
		ship.target_ship = target
		if target != null:
			var dist := ship.state.position.distance_to(target.state.position)
			var heading := _compute_tactical_heading(ship, target, 1.8)
			_set_order_heading(ship, heading)

			if ship.hp < ship.max_hp * 0.35:
				ship.stance = Ship.Stance.EVASIVE
			else:
				ship.stance = Ship.Stance.FIRE

			if dist > ship.weapon_range:
				ship.order.target_speed = ship.state.max_speed * 0.65
			elif dist > 18.0:
				ship.order.target_speed = 4.2
			else:
				ship.order.target_speed = 1.2

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
					var quad_tag := " [%s]" % result.quadrant
					if result.quadrant == "STERN":
						quad_tag = " 💥 [STERN RAKE!]"
					elif result.critical:
						quad_tag = " 💥 [CRIT %s!]" % result.quadrant
					if result.get("weather_gauge", false):
						quad_tag += " 🌬[BARLOVENTO]"
					_spawn_combat_text(target.global_position, "-%.0f HP%s" % [result.damage, quad_tag], Color(1.0, 0.85, 0.2) if result.critical else Color(0.3, 1.0, 0.55))
					_add_combat_log("%s hit %s%s for %.0f DMG" % [player.ship_name, target.ship_name, quad_tag, result.damage], Color(0.3, 1.0, 0.55))
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
					var quad_tag := " [%s]" % result.quadrant
					if result.get("weather_gauge", false):
						quad_tag += " 🌬[UPWIND]"
					_spawn_combat_text(target.global_position, "-%.0f HP%s" % [result.damage, quad_tag], Color(1.0, 0.35, 0.2))
					_add_combat_log("[ENEMY] %s hit %s%s for %.0f DMG" % [enemy.ship_name, target.ship_name, quad_tag, result.damage], Color(1.0, 0.45, 0.35))
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
		_tick_strategic_barlovento()
		_save_battle_state(true)

func _on_admiral_resolve_finished() -> void:
	_refresh_fleet_panel()
	_add_combat_log("Strategic WEGO movement cycle complete.", Color(0.35, 0.9, 1.0))
	if _fleets_in_range():
		_add_combat_log("Combat envelope reached! Transitioning to Ace tactical phase.", Color(1.0, 0.8, 0.3))
		_engage_ace_mode()
	if not _mission_completed:
		_save_battle_state(true)

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

	if _cmd_port != null and ship != null:
		var p_path := LoreDB.get_portrait_for_ship(ship.ship_id)
		if p_path != "" and ResourceLoader.exists(p_path):
			_cmd_port.texture = load(p_path)

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
		if _admiral_chart != null and _admiral_chart.visible:
			var s_idx := _player_ships.find(clicked_ship)
			if s_idx != -1:
				_admiral_chart.set_selected_unit(s_idx)

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
		"oar_burst":
			AudioManager.play_sfx("engine", -8.0)
			_add_combat_log("⚡ %s: Thruster / Oar Burst engaged! (Target SPD %.1f m/s)" % [_selected_ship.ship_name, _selected_ship.order.target_speed], Color(0.35, 0.95, 1.0))
		"precision":
			_selected_ship.set_meta("precision_boost", true)
			AudioManager.play_sfx("ui_hover", -6.0)
			_add_combat_log("🎯 %s: Fire control calibrated (+25%% Hit Accuracy & +15%% Salvo DMG)" % _selected_ship.ship_name, Color(0.35, 1.0, 0.85))
		"retro_brake":
			_selected_ship.order.target_speed = maxf(_selected_ship.order.target_speed - 8.0, 0.0)
			_selected_ship.state.velocity *= 0.4
			AudioManager.play_sfx("engine", -8.0)
			_add_combat_log("💨 %s: RCS Retro-Burn fired! (Drift arrested to %.1f m/s, +35%% Evasion)" % [_selected_ship.ship_name, _selected_ship.speed()], Color(0.4, 0.9, 1.0))
		"shield_pulse":
			_selected_ship.shield_hp = minf(_selected_ship.shield_hp + 40.0, _selected_ship.max_shield_hp)
			_selected_ship.hp = minf(_selected_ship.hp + 20.0, _selected_ship.max_hp)
			_selected_ship.refresh_after_load()
			AudioManager.play_sfx("shield", -8.0)
			_add_combat_log("🛡 %s: Deflector barriers overcharged (+40 SHLD / +20 HULL)" % _selected_ship.ship_name, Color(0.3, 1.0, 0.6))
			_refresh_fleet_panel()

func _save_battle_state(silent: bool = false) -> void:
	SaveManager.save_tactical_state(
		LoreDB.current_stage_id,
		TurnManager.turn_number,
		int(TurnManager.phase),
		TurnManager.ace_round,
		_player_ships,
		_enemy_ships
	)
	if not silent:
		AudioManager.play_sfx("ui_click", -8.0)
		_add_combat_log("💾 Tactical battle state saved [F5].", Color(0.35, 1.0, 0.70))

func _load_battle_state() -> void:
	var state := SaveManager.load_tactical_state()
	if state.is_empty():
		_add_combat_log("⚠ No saved tactical battle found [F9].", Color(1.0, 0.65, 0.30))
		return
	var saved_stage := String(state.get("stage_id", "acero_stage_1"))
	if saved_stage != LoreDB.current_stage_id:
		LoreDB.current_stage_id = saved_stage
		SaveManager.pending_load_battle = true
		get_tree().reload_current_scene()
		return

	TurnManager.turn_number = int(state.get("turn_number", 1))
	TurnManager.ace_round = int(state.get("ace_round", 1))
	var saved_phase := int(state.get("phase", 0))
	if saved_phase == int(TurnManager.Phase.ADMIRAL_RESOLVE):
		saved_phase = int(TurnManager.Phase.ADMIRAL_PLAN)
	elif saved_phase == int(TurnManager.Phase.ACE_RESOLVE):
		saved_phase = int(TurnManager.Phase.ACE_PLAN)
	TurnManager.phase = saved_phase as TurnManager.Phase

	var p_arr: Array = state.get("player_ships", [])
	for i in range(mini(_player_ships.size(), p_arr.size())):
		_apply_ship_save_dict(_player_ships[i], p_arr[i])

	var e_arr: Array = state.get("enemy_ships", [])
	for i in range(mini(_enemy_ships.size(), e_arr.size())):
		_apply_ship_save_dict(_enemy_ships[i], e_arr[i])

	_mission_completed = false
	if _victory_overlay != null:
		_victory_overlay.visible = false
	if _defeat_overlay != null:
		_defeat_overlay.visible = false

	_on_phase_changed(TurnManager.phase)
	_refresh_fleet_panel()
	AudioManager.play_sfx("ui_hover", -6.0)
	_add_combat_log("📂 Tactical battle restored (Turn %d, Round %d) [F9]." % [TurnManager.turn_number, TurnManager.ace_round], Color(0.40, 0.95, 1.0))

func _apply_ship_save_dict(s: Ship, sd: Dictionary) -> void:
	s.hp = float(sd.get("hp", s.hp))
	s.max_hp = float(sd.get("max_hp", s.max_hp))
	s.shield_hp = float(sd.get("shield_hp", s.shield_hp))
	s.max_shield_hp = float(sd.get("max_shield_hp", s.max_shield_hp))
	s.armor_bow = float(sd.get("armor_bow", s.armor_bow))
	s.armor_port = float(sd.get("armor_port", s.armor_port))
	s.armor_stbd = float(sd.get("armor_stbd", s.armor_stbd))
	s.armor_stern = float(sd.get("armor_stern", s.armor_stern))
	s.stance = int(sd.get("stance", 0)) as Ship.Stance
	s.is_evading = bool(sd.get("is_evading", false))
	s.state.position = SaveManager.arr_to_vec3(sd.get("pos", []))
	s.state.velocity = SaveManager.arr_to_vec3(sd.get("vel", []))
	var fwd := SaveManager.arr_to_vec3(sd.get("fwd", [0.0, 0.0, -1.0]))
	if fwd.length_squared() > 0.001:
		s.state.forward = fwd.normalized()
	s.order.yaw = float(sd.get("order_yaw", 0.0))
	s.order.pitch = float(sd.get("order_pitch", 0.0))
	s.order.target_speed = float(sd.get("order_speed", 0.0))
	s.refresh_after_load()

func _align_fleet_formation() -> void:
	if _selected_ship == null or _selected_ship.is_destroyed():
		return
	var ref_yaw := _selected_ship.order.yaw
	var ref_pitch := _selected_ship.order.pitch
	var ref_spd := maxf(_selected_ship.order.target_speed, 8.0)
	_selected_ship.order.target_speed = ref_spd
	for p in _player_ships:
		if not p.is_destroyed():
			p.order.yaw = ref_yaw
			p.order.pitch = ref_pitch
			p.order.target_speed = ref_spd
	AudioManager.play_sfx("ui_click", -8.0)
	_add_combat_log("⊞ Fleet aligned to %s Line-of-Battle bearing (SPD %.1f m/s)" % [_selected_ship.ship_name, ref_spd], Color(0.35, 0.95, 1.0))

func _update_ai_tactical_behavior(_delta: float) -> void:
	for i in range(_enemy_ships.size()):
		var enemy := _enemy_ships[i]
		if enemy.is_destroyed():
			continue
		var tgt := _nearest_player_ship(enemy)
		if tgt == null:
			continue
		var dist := enemy.state.position.distance_to(tgt.state.position)
		var heading := _compute_tactical_heading(enemy, tgt, 1.6)
		_set_order_heading(enemy, heading)
		if dist > 45.0:
			enemy.order.target_speed = 6.5
		elif dist > 20.0:
			enemy.order.target_speed = 3.5
		else:
			enemy.order.target_speed = 0.0

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
		var exposed_quad := Combat.get_hit_quadrant(active, _ace_target)

		var line_color := Color(0.25, 1.0, 0.6, 0.85)
		if not in_range:
			line_color = Color(1.0, 0.35, 0.3, 0.5)
			_target_3d_label.text = "▲ OUT OF RANGE: %.0fm / %.0fm" % [dist, active.weapon_range]
			_target_3d_label.modulate = Color(1.0, 0.45, 0.35)
		elif not in_arc:
			line_color = Color(1.0, 0.75, 0.25, 0.65)
			_target_3d_label.text = "◀ ALIGN FIRING ARC / BROADSIDE (YAW SHIP)"
			_target_3d_label.modulate = Color(1.0, 0.8, 0.3)
		else:
			line_color = Color(0.25, 1.0, 0.6, 0.85)
			_target_3d_label.text = "⌖ LOCKED [%s ARMOR] // READY TO FIRE" % exposed_quad
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
	var dir := to_pos - from_pos
	var dist := dir.length()
	if dist < 0.1:
		return
	var norm := dir / dist
	var right := norm.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT

	# Multi-salvo volumetric 3D beam cylinders + muzzle flash
	var offsets := [Vector3.ZERO, right * 0.45 + Vector3.UP * 0.15, -right * 0.45 - Vector3.UP * 0.15]
	for i in range(offsets.size()):
		var off: Vector3 = offsets[i]
		var start_p := from_pos + off
		var end_p := to_pos + off * 0.35
		var beam_vec := end_p - start_p
		var beam_len := beam_vec.length()

		var beam_node := Node3D.new()
		add_child(beam_node)
		beam_node.global_position = (start_p + end_p) * 0.5
		var up := Vector3.UP if absf(norm.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		beam_node.look_at(end_p, up)

		var cyl_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var radius := 0.16 if i == 0 else 0.09
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = beam_len
		cyl_inst.mesh = cyl
		cyl_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95) if i == 0 else color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 5.5 if i == 0 else 3.8
		cyl_inst.material_override = mat
		beam_node.add_child(cyl_inst)

		var tween := create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.32 + float(i) * 0.05)
		tween.parallel().tween_property(cyl_inst, "scale:x", 0.1, 0.32 + float(i) * 0.05)
		tween.parallel().tween_property(cyl_inst, "scale:z", 0.1, 0.32 + float(i) * 0.05)
		tween.chain().tween_callback(beam_node.queue_free)

func _spawn_impact_flash(pos: Vector3, color: Color) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.1
	sphere.height = 2.2
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	flash.material_override = mat
	flash.position = pos
	add_child(flash)

	# Expanding 3D Shockwave Torus Ring
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.15
	torus.rings = 24
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.92, 0.7, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 3.5
	ring.material_override = ring_mat
	ring.position = pos
	add_child(ring)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(3.4, 3.4, 3.4), 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.tween_property(ring, "scale", Vector3(4.8, 4.8, 4.8), 0.34)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.34)
	tween.chain().tween_callback(func() -> void:
		flash.queue_free()
		ring.queue_free()
	)

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
	var backdrop := StarSeaBackdrop.new()
	backdrop.name = "StarSeaBackdrop"
	add_child(backdrop)
	backdrop.setup_environment(false)

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
	stream_mesh.bottom_radius = 0.14
	stream_mesh.height = 4.2

	var stream_mat := StandardMaterial3D.new()
	stream_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stream_mat.albedo_color = Color(0.3, 0.92, 0.98, 0.48)
	stream_mat.emission_enabled = true
	stream_mat.emission = Color(0.15, 0.65, 0.78)
	stream_mesh.material = stream_mat

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(60):
		var p := MeshInstance3D.new()
		p.mesh = stream_mesh
		var pos := Vector3(rng.randf_range(-140.0, 140.0), rng.randf_range(-25.0, 25.0), rng.randf_range(-140.0, 140.0))
		var cur := _ether.current_at(pos)
		var norm := cur.normalized() if cur.length_squared() > 0.01 else _ether.direction
		var up := Vector3.UP if absf(norm.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		_ether_particles.add_child(p)
		p.position = pos
		p.look_at(pos + norm, up)

func _build_asteroid_field() -> void:
	_asteroid_root = Node3D.new()
	_asteroid_root.name = "StarSeaReefs"
	add_child(_asteroid_root)

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.14, 0.16, 0.22)
	rock_mat.metallic = 0.25
	rock_mat.roughness = 0.82

	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.2, 0.85, 0.95)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.15, 0.75, 0.92)
	crystal_mat.emission_energy_multiplier = 2.2

	var rng := RandomNumberGenerator.new()
	rng.seed = 108
	var reef_positions := [
		Vector3(-68.0, -8.0, 12.0),
		Vector3(-56.0, 14.0, -28.0),
		Vector3(64.0, -6.0, 18.0),
		Vector3(58.0, 10.0, -24.0),
		Vector3(-75.0, 4.0, 55.0),
		Vector3(76.0, -12.0, 48.0),
		Vector3(-48.0, -16.0, -68.0),
		Vector3(52.0, 12.0, -72.0),
		Vector3(0.0, -22.0, 5.0),
		Vector3(-32.0, 18.0, 4.0),
	]

	for base_pos in reef_positions:
		var cluster := Node3D.new()
		cluster.position = base_pos
		cluster.rotation_degrees = Vector3(rng.randf_range(0, 360), rng.randf_range(0, 360), rng.randf_range(0, 360))
		_asteroid_root.add_child(cluster)

		var main_rock := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var rad := rng.randf_range(2.6, 5.2)
		sphere.radius = rad
		sphere.height = rad * 1.65
		sphere.radial_segments = 7
		sphere.rings = 5
		main_rock.mesh = sphere
		main_rock.scale = Vector3(1.2, 0.75, 0.95)
		main_rock.material_override = rock_mat
		cluster.add_child(main_rock)

		# Glowing Éther crystal spire embedded in the basalt reef
		var crystal := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(rad * 0.45, rad * 1.35, rad * 0.45)
		crystal.mesh = prism
		crystal.position = Vector3(0.0, rad * 0.65, 0.0)
		crystal.rotation_degrees = Vector3(18.0, 35.0, -12.0)
		crystal.material_override = crystal_mat
		cluster.add_child(crystal)

func _build_calm_wavefront() -> void:
	# Lore Pillar: The encroaching wall of "The Calm" (La Calma) along the northern abyssal boundary
	_calm_wall_root = Node3D.new()
	_calm_wall_root.name = "TheCalmWavefront"
	_calm_wall_root.position = Vector3(0.0, 0.0, -155.0)
	add_child(_calm_wall_root)

	var calm_mat := StandardMaterial3D.new()
	calm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	calm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	calm_mat.albedo_color = Color(0.05, 0.02, 0.09, 0.68)
	calm_mat.emission_enabled = true
	calm_mat.emission = Color(0.22, 0.06, 0.28)
	calm_mat.emission_energy_multiplier = 1.2

	for i in range(-5, 6):
		var pillar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 12.0
		cyl.bottom_radius = 18.0
		cyl.height = 95.0
		cyl.radial_segments = 10
		pillar.mesh = cyl
		pillar.position = Vector3(float(i) * 26.0, 0.0, absf(float(i)) * 2.5)
		pillar.material_override = calm_mat
		_calm_wall_root.add_child(pillar)

var _sluice_ring_outer: Node3D = null
var _sluice_ring_inner: Node3D = null

func _build_sluice_station() -> void:
	# Colossal Textured 3D Acero Éteron Sluice-Gate Refinery ("Well-09", matching card_acero.png & acero_stage1_briefing.png)
	_sluice_station_root = Node3D.new()
	_sluice_station_root.name = "SluiceStationWell09"
	_sluice_station_root.position = Vector3(-28.0, -1.0, 4.0)
	_sluice_station_root.rotation_degrees = Vector3(0.0, 24.0, 0.0)
	add_child(_sluice_station_root)

	var hull_tex: Texture2D = load("res://assets/ships/acero/acero_hull.png")

	var armor_tex_mat := StandardMaterial3D.new()
	armor_tex_mat.albedo_texture = hull_tex
	armor_tex_mat.albedo_color = Color(1.65, 1.72, 1.85)
	armor_tex_mat.uv1_scale = Vector3(3.5, 3.5, 1.0)
	armor_tex_mat.metallic = 0.45
	armor_tex_mat.roughness = 0.40
	armor_tex_mat.rim_enabled = true
	armor_tex_mat.rim = 0.50
	armor_tex_mat.emission_enabled = true
	armor_tex_mat.emission = Color(0.09, 0.12, 0.17)
	armor_tex_mat.emission_energy_multiplier = 0.35

	var dark_steel_mat := StandardMaterial3D.new()
	dark_steel_mat.albedo_texture = hull_tex
	dark_steel_mat.albedo_color = Color(1.15, 1.22, 1.34)
	dark_steel_mat.uv1_scale = Vector3(5.0, 5.0, 1.0)
	dark_steel_mat.metallic = 0.52
	dark_steel_mat.roughness = 0.36
	dark_steel_mat.rim_enabled = true
	dark_steel_mat.rim = 0.45

	var trim_steel := StandardMaterial3D.new()
	trim_steel.albedo_color = Color(0.56, 0.62, 0.72)
	trim_steel.metallic = 0.55
	trim_steel.roughness = 0.28

	var furnace_amber := StandardMaterial3D.new()
	furnace_amber.albedo_color = Color(1.0, 0.52, 0.14)
	furnace_amber.emission_enabled = true
	furnace_amber.emission = Color(0.98, 0.45, 0.10)
	furnace_amber.emission_energy_multiplier = 1.65

	var molten_core_mat := StandardMaterial3D.new()
	molten_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	molten_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	molten_core_mat.albedo_color = Color(1.0, 0.58, 0.16, 0.88)
	molten_core_mat.emission_enabled = true
	molten_core_mat.emission = Color(1.0, 0.46, 0.10)
	molten_core_mat.emission_energy_multiplier = 1.85

	var sluice_cyan := StandardMaterial3D.new()
	sluice_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sluice_cyan.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sluice_cyan.albedo_color = Color(0.18, 0.78, 0.95, 0.55)
	sluice_cyan.emission_enabled = true
	sluice_cyan.emission = Color(0.15, 0.68, 0.88)
	sluice_cyan.emission_energy_multiplier = 0.95

	# Dedicated Station Illumination Lights (Warm Forge Light + Cool Collector Light)
	var forge_light := OmniLight3D.new()
	forge_light.position = Vector3(0.0, 8.0, 6.0)
	forge_light.light_color = Color(1.0, 0.62, 0.25)
	forge_light.light_energy = 1.8
	forge_light.omni_range = 36.0
	_sluice_station_root.add_child(forge_light)

	var ring_light := OmniLight3D.new()
	ring_light.position = Vector3(0.0, 2.0, -14.0)
	ring_light.light_color = Color(0.35, 0.85, 1.0)
	ring_light.light_energy = 1.5
	ring_light.omni_range = 32.0
	_sluice_station_root.add_child(ring_light)

	# 1. Central Multi-Tiered Octagonal Blast-Furnace Citadel (like card_acero.png!)
	var base_drum := MeshInstance3D.new()
	var bd_cyl := CylinderMesh.new()
	bd_cyl.top_radius = 9.2
	bd_cyl.bottom_radius = 7.4
	bd_cyl.height = 7.5
	bd_cyl.radial_segments = 12
	base_drum.mesh = bd_cyl
	base_drum.position = Vector3(0.0, 0.0, 6.0)
	base_drum.material_override = armor_tex_mat
	_sluice_station_root.add_child(base_drum)

	var upper_citadel := MeshInstance3D.new()
	var uc_cyl := CylinderMesh.new()
	uc_cyl.top_radius = 6.8
	uc_cyl.bottom_radius = 8.4
	uc_cyl.height = 6.0
	uc_cyl.radial_segments = 8
	upper_citadel.mesh = uc_cyl
	upper_citadel.position = Vector3(0.0, 6.2, 6.0)
	upper_citadel.material_override = dark_steel_mat
	_sluice_station_root.add_child(upper_citadel)

	# Glowing Molten Blast-Furnace Crown & Lower Crucible Vent
	var crown_furnace := MeshInstance3D.new()
	var cf_cyl := CylinderMesh.new()
	cf_cyl.top_radius = 5.2
	cf_cyl.bottom_radius = 5.8
	cf_cyl.height = 2.4
	cf_cyl.radial_segments = 12
	crown_furnace.mesh = cf_cyl
	crown_furnace.position = Vector3(0.0, 9.8, 6.0)
	crown_furnace.material_override = molten_core_mat
	_sluice_station_root.add_child(crown_furnace)

	var lower_crucible := MeshInstance3D.new()
	var lc_cyl := CylinderMesh.new()
	lc_cyl.top_radius = 4.2
	lc_cyl.bottom_radius = 1.2
	lc_cyl.height = 6.5
	lc_cyl.radial_segments = 10
	lower_crucible.mesh = lc_cyl
	lower_crucible.position = Vector3(0.0, -6.5, 6.0)
	lower_crucible.material_override = dark_steel_mat
	_sluice_station_root.add_child(lower_crucible)

	# 6 Towering Industrial Smokestacks & Heat-Sink Towers around the Citadel
	for i in range(6):
		var ang := float(i) * TAU / 6.0
		var sx := cos(ang) * 6.2
		var sz := 6.0 + sin(ang) * 6.2
		var stack := MeshInstance3D.new()
		var st_cyl := CylinderMesh.new()
		st_cyl.top_radius = 0.65
		st_cyl.bottom_radius = 0.95
		st_cyl.height = 9.5 + float(i % 2) * 3.0
		st_cyl.radial_segments = 8
		stack.mesh = st_cyl
		stack.position = Vector3(sx, 8.5 + float(i % 2) * 1.5, sz)
		stack.material_override = armor_tex_mat
		_sluice_station_root.add_child(stack)

		var stack_glow := MeshInstance3D.new()
		var sg_cyl := CylinderMesh.new()
		sg_cyl.top_radius = 0.55
		sg_cyl.bottom_radius = 0.55
		sg_cyl.height = 0.8
		stack_glow.mesh = sg_cyl
		stack_glow.position = stack.position + Vector3(0.0, st_cyl.height * 0.5, 0.0)
		stack_glow.material_override = furnace_amber
		_sluice_station_root.add_child(stack_glow)

	# Port & Starboard Heavy Docking Gantries and Furnace Windows
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var w_box := BoxMesh.new()
		w_box.size = Vector3(8.5, 3.2, 4.4)
		wing.mesh = w_box
		wing.position = Vector3(float(side) * 11.2, 0.5, 6.0)
		wing.material_override = armor_tex_mat
		_sluice_station_root.add_child(wing)

		var trim_bar := MeshInstance3D.new()
		var tb_box := BoxMesh.new()
		tb_box.size = Vector3(9.0, 0.45, 4.8)
		trim_bar.mesh = tb_box
		trim_bar.position = Vector3(float(side) * 11.2, 2.2, 6.0)
		trim_bar.material_override = trim_steel
		_sluice_station_root.add_child(trim_bar)

		for w_i in range(3):
			var win := MeshInstance3D.new()
			var win_box := BoxMesh.new()
			win_box.size = Vector3(1.6, 0.9, 4.55)
			win.mesh = win_box
			win.position = Vector3(float(side) * (8.5 + float(w_i) * 2.4), 0.5, 6.0)
			win.material_override = furnace_amber
			_sluice_station_root.add_child(win)

	# 2. Axial Sluice Conduit Barrel extending forward (-Z) to the Collector Ring
	var conduit := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 3.2
	c_cyl.bottom_radius = 3.8
	c_cyl.height = 16.0
	c_cyl.radial_segments = 12
	conduit.mesh = c_cyl
	conduit.position = Vector3(0.0, 1.2, -4.5)
	conduit.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	conduit.material_override = dark_steel_mat
	_sluice_station_root.add_child(conduit)

	for rib_i in range(4):
		var rib := MeshInstance3D.new()
		var r_tor := TorusMesh.new()
		r_tor.inner_radius = 3.4
		r_tor.outer_radius = 4.3
		r_tor.rings = 16
		r_tor.ring_segments = 8
		rib.mesh = r_tor
		rib.position = Vector3(0.0, 1.2, 1.0 - float(rib_i) * 3.6)
		rib.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		rib.material_override = trim_steel
		_sluice_station_root.add_child(rib)

	# 3. Colossal Forward Éteron Collector Ring Assembly (Counter-Rotating Outer & Inner Rings!)
	_sluice_ring_outer = Node3D.new()
	_sluice_ring_outer.position = Vector3(0.0, 1.2, -13.5)
	_sluice_station_root.add_child(_sluice_ring_outer)

	var main_ring := MeshInstance3D.new()
	var mr_tor := TorusMesh.new()
	mr_tor.inner_radius = 7.2
	mr_tor.outer_radius = 9.4
	mr_tor.rings = 32
	mr_tor.ring_segments = 12
	main_ring.mesh = mr_tor
	main_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	main_ring.material_override = armor_tex_mat
	_sluice_ring_outer.add_child(main_ring)

	# 8 Radial Magnetic Clamp Pylons around the Collector Ring (matching card_acero.png!)
	for c_i in range(8):
		var c_ang := float(c_i) * TAU / 8.0
		var pylon := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(1.8, 3.6, 2.4)
		pylon.mesh = p_box
		pylon.position = Vector3(cos(c_ang) * 9.2, sin(c_ang) * 9.2, 0.0)
		pylon.rotation = Vector3(0.0, 0.0, c_ang + PI * 0.5)
		pylon.material_override = trim_steel
		_sluice_ring_outer.add_child(pylon)

	_sluice_ring_inner = Node3D.new()
	_sluice_ring_inner.position = Vector3(0.0, 1.2, -13.5)
	_sluice_station_root.add_child(_sluice_ring_inner)

	var inner_ring := MeshInstance3D.new()
	var ir_tor := TorusMesh.new()
	ir_tor.inner_radius = 5.4
	ir_tor.outer_radius = 6.6
	ir_tor.rings = 28
	ir_tor.ring_segments = 10
	inner_ring.mesh = ir_tor
	inner_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	inner_ring.material_override = furnace_amber
	_sluice_ring_inner.add_child(inner_ring)

	# Central Siphon Aperture Core & Éther Capture Stream
	var aperture_core := MeshInstance3D.new()
	var ac_cyl := CylinderMesh.new()
	ac_cyl.top_radius = 4.8
	ac_cyl.bottom_radius = 2.6
	ac_cyl.height = 18.0
	ac_cyl.radial_segments = 16
	aperture_core.mesh = ac_cyl
	aperture_core.position = Vector3(0.0, 1.2, -18.0)
	aperture_core.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	aperture_core.material_override = sluice_cyan
	_sluice_station_root.add_child(aperture_core)

	var station_lbl := Label3D.new()
	station_lbl.text = "◆ SLUICE STATION WELL-09\n[ACERO ÉTERON REFINERY]"
	station_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_lbl.font_size = 14
	station_lbl.modulate = Color(1.0, 0.78, 0.32)
	station_lbl.outline_modulate = Color(0.01, 0.02, 0.05, 0.95)
	station_lbl.outline_size = 3
	station_lbl.position = Vector3(0.0, 16.5, 6.0)
	_sluice_station_root.add_child(station_lbl)

func _update_scenery(delta: float) -> void:
	if _asteroid_root != null:
		for cluster in _asteroid_root.get_children():
			if cluster is Node3D:
				cluster.rotate_y(delta * 0.06)
	if _sluice_ring_outer != null:
		_sluice_ring_outer.rotate_z(delta * 0.18)
	if _sluice_ring_inner != null:
		_sluice_ring_inner.rotate_z(-delta * 0.35)

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
	match LoreDB.current_stage_id:
		"acero_stage_1":
			# ACT I // STAGE 01: Defense of Sluice Station Well-09 (Acero vs Free Tide Corsairs)
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-12.0, 5.0, 36.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(4.0, 2.0, 34.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_corvette", Vector3(18.0, 6.0, 38.0), Vector3.ZERO, 0))

			_enemy_ships.append(_spawn("marea_galleon", Vector3(-10.0, 6.0, -40.0), Vector3(0.0, 0.0, 3.5), 1))
			_enemy_ships.append(_spawn("marea_raider", Vector3(8.0, 3.0, -44.0), Vector3(0.0, 0.0, 4.0), 1))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(20.0, 8.0, -38.0), Vector3(0.0, 0.0, 4.5), 1))
		"acero_stage_2":
			# ACT I // STAGE 02: Ambush at the Resonance Spire (Acero vs Vinculados Choir Wing)
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-10.0, 4.0, 36.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(6.0, 7.0, 34.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_corvette", Vector3(20.0, 2.0, 38.0), Vector3.ZERO, 0))

			_enemy_ships.append(_spawn("vinculados_suit", Vector3(-12.0, 8.0, -42.0), Vector3(1.5, 0.0, 4.2), 1))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(6.0, 2.0, -44.0), Vector3(-1.2, 0.0, 4.8), 1))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(20.0, 6.0, -38.0), Vector3(0.0, 0.0, 3.8), 1))
		"acero_stage_3":
			# ACT I // STAGE 03: The Calm Threshold (Acero vs Veteran Free Tide Flagship Squadron)
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-12.0, 5.0, 36.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(4.0, 3.0, 34.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_corvette", Vector3(18.0, 6.0, 38.0), Vector3.ZERO, 0))

			var boss_gal := _spawn("marea_galleon", Vector3(-14.0, 6.0, -42.0), Vector3(0.0, 0.0, 3.8), 1)
			boss_gal.hp = roundf(boss_gal.hp * 1.20)
			boss_gal.max_hp = boss_gal.hp
			_enemy_ships.append(boss_gal)
			_enemy_ships.append(_spawn("marea_raider", Vector3(4.0, 3.0, -45.0), Vector3(0.0, 0.0, 4.4), 1))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(20.0, 8.0, -40.0), Vector3(0.0, 0.0, 4.8), 1))
		"marea_stage_1":
			# ACT III // STAGE 01: 100% Pure Free Tide Corsairs vs 100% Pure Armada of Acero
			_player_ships.append(_spawn("marea_galleon", Vector3(-10.0, 5.0, 36.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(6.0, 2.0, 38.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(18.0, 7.0, 34.0), Vector3.ZERO, 0))

			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-10.0, 6.0, -42.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(6.0, 3.0, -44.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(18.0, 5.0, -40.0), Vector3(0.0, 0.0, 3.5), 1))
		_:
			# ACT II // STAGE 01: 100% Pure Vinculados Choir vs 100% Pure Armada of Acero
			_player_ships.append(_spawn("vinculados_suit", Vector3(-12.0, 7.0, 38.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(12.0, -4.0, 40.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(0.0, 2.0, 35.0), Vector3.ZERO, 0))

			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-10.0, 6.0, -42.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(6.0, 3.0, -44.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(18.0, 5.0, -40.0), Vector3(0.0, 0.0, 3.5), 1))

	_tactical_grid.set_ships(_player_ships + _enemy_ships)

	for p in _player_ships:
		p.order.target_speed = minf(10.0, p.state.max_speed * 0.75)
		p.order.yaw = 0.0
		p.order.pitch = 0.0

	_set_selected(_player_ships[0])
	_ace_target = _enemy_ships[0]

func _spawn(id: String, pos: Vector3, vel: Vector3, team: int) -> Ship:
	var def := LoreDB.get_ship(id)
	var ship := Ship.new()
	ship.team = team
	ship.apply_def(def)
	ship.initial_velocity = vel
	ship.position = pos
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

	# 0. World-Space Projected 2D Ship Callout Badges (Hexagon + Green Bar + SHLD/HULL/MOVING from admiral-phase.png)
	_callout_overlay = HudWidgets.ShipCalloutOverlay.new()
	_callout_overlay.ships = _player_ships + _enemy_ships
	_callout_overlay.selected_ship = _selected_ship
	_callout_overlay.target_ship = _ace_target
	_callout_overlay.camera = get_viewport().get_camera_3d()
	_callout_overlay.ship_badge_clicked.connect(_on_ship_clicked)
	_callout_overlay.ship_badge_right_clicked.connect(_on_ship_right_clicked)
	layer.add_child(_callout_overlay)

	# 1. TOP-LEFT: Canonical BARLOVENTO Logo + "TURN X | ADMIRAL PHASE" + WEATHER-GAUGE + INITIATIVE ORDER
	var top_left_vbox := VBoxContainer.new()
	top_left_vbox.position = Vector2(18, 12)
	top_left_vbox.add_theme_constant_override("separation", 4)
	top_left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top_left_vbox)

	var logo_tex: Texture2D = load("res://assets/brand/logo.png")
	if logo_tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = logo_tex
		atlas.region = Rect2(80, 220, 1216, 280)
		var logo_rect := TextureRect.new()
		logo_rect.texture = atlas
		logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo_rect.custom_minimum_size = Vector2(215, 44)
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_left_vbox.add_child(logo_rect)

	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 6)
	top_left_vbox.add_child(turn_row)

	_turn_label_prefix = Label.new()
	_turn_label_prefix.text = "TURN 1 |"
	_turn_label_prefix.add_theme_font_size_override("font_size", 12)
	_turn_label_prefix.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	turn_row.add_child(_turn_label_prefix)

	_turn_label_phase = Label.new()
	_turn_label_phase.text = "ADMIRAL PHASE"
	_turn_label_phase.add_theme_font_size_override("font_size", 12)
	_turn_label_phase.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
	turn_row.add_child(_turn_label_phase)

	var spacer_tl := Control.new()
	spacer_tl.custom_minimum_size = Vector2(0, 6)
	top_left_vbox.add_child(spacer_tl)

	_weather_panel = HudWidgets.WeatherInitiativePanel.new()
	top_left_vbox.add_child(_weather_panel)

	# 2. TOP-CENTER: "ACE PHASE" Chamfered Trapezoid Banner (from ace-phase.png)
	_ace_top_banner = HudWidgets.AceTopBanner.new()
	_ace_top_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_ace_top_banner.position = Vector2(-280, 0)
	_ace_top_banner.visible = false
	layer.add_child(_ace_top_banner)

	# 3. TOP-RIGHT: Menu [◀ MENU], Roster [★], Save [💾], Load [📂], Reset [↻], Help [≡], Commander Bridge Card & Sensor Feed
	var top_right_vbox := VBoxContainer.new()
	top_right_vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right_vbox.position = Vector2(-330, 12)
	top_right_vbox.custom_minimum_size = Vector2(316, 0)
	top_right_vbox.add_theme_constant_override("separation", 6)
	layer.add_child(top_right_vbox)

	var tr_btn_row := HBoxContainer.new()
	tr_btn_row.alignment = BoxContainer.ALIGNMENT_END
	tr_btn_row.add_theme_constant_override("separation", 4)
	top_right_vbox.add_child(tr_btn_row)

	var menu_btn := Button.new()
	menu_btn.text = "◀ MENU"
	menu_btn.tooltip_text = "Return to Main Menu / Faction Select"
	menu_btn.theme = _hud_theme
	menu_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)
	tr_btn_row.add_child(menu_btn)

	var roster_btn := Button.new()
	roster_btn.text = "★ ROSTER"
	roster_btn.tooltip_text = "Hero & Ace Roster [R]"
	roster_btn.theme = _hud_theme
	roster_btn.pressed.connect(func() -> void:
		if _roster_modal != null:
			_roster_modal.visible = not _roster_modal.visible
	)
	tr_btn_row.add_child(roster_btn)

	var save_btn := Button.new()
	save_btn.text = "💾"
	save_btn.tooltip_text = "Quick Save Tactical Battle [F5]"
	save_btn.theme = _hud_theme
	save_btn.custom_minimum_size = Vector2(28, 28)
	save_btn.pressed.connect(func() -> void: _save_battle_state(false))
	tr_btn_row.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "📂"
	load_btn.tooltip_text = "Quick Load Tactical Battle [F9]"
	load_btn.theme = _hud_theme
	load_btn.custom_minimum_size = Vector2(28, 28)
	load_btn.pressed.connect(func() -> void: _load_battle_state())
	tr_btn_row.add_child(load_btn)

	var reset_btn := Button.new()
	reset_btn.text = "↻"
	reset_btn.tooltip_text = "Restart Stage"
	reset_btn.theme = _hud_theme
	reset_btn.custom_minimum_size = Vector2(28, 28)
	reset_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
	tr_btn_row.add_child(reset_btn)

	var help_btn := Button.new()
	help_btn.text = "≡"
	help_btn.tooltip_text = "Tactical Manual [H / ESC]"
	help_btn.theme = _hud_theme
	help_btn.custom_minimum_size = Vector2(30, 28)
	help_btn.pressed.connect(_toggle_help)
	tr_btn_row.add_child(help_btn)

	# Commander Bridge Comms & Stage Objective Card
	var cmd_card := PanelContainer.new()
	cmd_card.theme = _hud_theme
	top_right_vbox.add_child(cmd_card)

	var cmd_hbox := HBoxContainer.new()
	cmd_hbox.add_theme_constant_override("separation", 8)
	cmd_card.add_child(cmd_hbox)

	_cmd_port = TextureRect.new()
	var port_path := "res://assets/heroes/ace_vane.png"
	if not _player_ships.is_empty() and _player_ships[0] != null:
		port_path = LoreDB.get_portrait_for_ship(_player_ships[0].ship_id)
	var port_tex: Texture2D = load(port_path)
	if port_tex != null:
		_cmd_port.texture = port_tex
	_cmd_port.custom_minimum_size = Vector2(44, 44)
	_cmd_port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cmd_port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cmd_hbox.add_child(_cmd_port)

	var cmd_vbox := VBoxContainer.new()
	cmd_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_vbox.add_theme_constant_override("separation", 1)
	cmd_hbox.add_child(cmd_vbox)

	_stage_title_label = Label.new()
	match LoreDB.current_stage_id:
		"acero_stage_1":
			_stage_title_label.text = "ACT I // STAGE 01: SLUICE WELL-09"
		"acero_stage_2":
			_stage_title_label.text = "ACT I // STAGE 02: RESONANCE SPIRE"
		"acero_stage_3":
			_stage_title_label.text = "ACT I // STAGE 03: THE CALM THRESHOLD"
		"marea_stage_1":
			_stage_title_label.text = "ACT III // STAGE 01: ANVIL BLOCKADE"
		_:
			_stage_title_label.text = "SECTOR PSALM-4 // RESONANCE WELL"
	_stage_title_label.add_theme_font_size_override("font_size", 10)
	_stage_title_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	cmd_vbox.add_child(_stage_title_label)

	_objective_label = Label.new()
	_objective_label.text = "[0/3 RAIDERS NEUTRALIZED]"
	_objective_label.add_theme_font_size_override("font_size", 10)
	_objective_label.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
	cmd_vbox.add_child(_objective_label)

	# Compact Translucent Sensor Feed
	var log_panel := PanelContainer.new()
	log_panel.theme = _hud_theme
	log_panel.custom_minimum_size = Vector2(316, 86)
	top_right_vbox.add_child(log_panel)

	var log_outer := VBoxContainer.new()
	log_outer.add_theme_constant_override("separation", 2)
	log_panel.add_child(log_outer)

	var log_title := Label.new()
	log_title.text = "BRIDGE TELEMETRY // TACTICAL FEED"
	log_title.add_theme_font_size_override("font_size", 9)
	log_title.add_theme_color_override("font_color", Color(0.50, 0.78, 0.95))
	log_outer.add_child(log_title)

	_combat_log_vbox = VBoxContainer.new()
	_combat_log_vbox.add_theme_constant_override("separation", 1)
	log_outer.add_child(_combat_log_vbox)

	# 4. BOTTOM HUD DOCKS: OrderPanel (admiral-phase.png) & AcePanel (ace-phase.png)
	_order_panel = OrderPanel.new()
	_order_panel.theme = _hud_theme
	_order_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_order_panel.offset_top = -128
	_order_panel.offset_bottom = 0
	_order_panel.intercept_pressed.connect(_intercept_target)
	_order_panel.engage_ace_pressed.connect(_engage_ace_mode)
	_order_panel.execute_turn_pressed.connect(_execute_current_phase)
	_order_panel.formation_pressed.connect(_align_fleet_formation)
	_order_panel.focus_camera_pressed.connect(func() -> void:
		if _selected_ship != null and _camera_rig != null:
			_camera_rig.focus_on(_selected_ship.global_position)
	)
	_order_panel.toggle_grid_pressed.connect(func() -> void:
		if _tactical_grid != null:
			_tactical_grid.visible = not _tactical_grid.visible
	)
	_order_panel.open_roster_pressed.connect(func() -> void:
		if _roster_modal != null:
			_roster_modal.set_battle_rosters(_player_ships, _enemy_ships)
			_roster_modal.visible = true
	)
	_order_panel.ship_selected.connect(func(s: Ship) -> void:
		_set_selected(s)
		AudioManager.play_sfx("ui_click", -10.0)
	)
	_order_panel.enemy_targeted.connect(func(e: Ship, auto_intercept: bool) -> void:
		_ace_target = e
		if _tactical_grid != null:
			_tactical_grid.target_ship = e
		if _ace_panel != null:
			_ace_panel.target = e
		if _selected_ship != null:
			_selected_ship.target_ship = e
		if auto_intercept:
			_intercept_target()
		else:
			AudioManager.play_sfx("ui_hover", -8.0)
		_refresh_fleet_panel()
	)
	layer.add_child(_order_panel)

	_ace_panel = AcePanel.new()
	_ace_panel.theme = _hud_theme
	_ace_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_ace_panel.offset_top = -205
	_ace_panel.offset_bottom = 0
	_ace_panel.visible = false
	_ace_panel.execute_round_pressed.connect(_execute_ace_round)
	_ace_panel.cycle_target_pressed.connect(_cycle_hostile_target)
	_ace_panel.intercept_pressed.connect(_intercept_target)
	_ace_panel.ability_used.connect(_on_ace_ability_used)
	_ace_panel.ship_selected.connect(func(s: Ship) -> void:
		_set_selected(s)
		AudioManager.play_sfx("ui_click", -10.0)
	)
	_ace_panel.enemy_selected.connect(func(e: Ship) -> void:
		_ace_target = e
		if _tactical_grid != null:
			_tactical_grid.target_ship = e
		if _ace_panel != null:
			_ace_panel.target = e
		if _selected_ship != null:
			_selected_ship.target_ship = e
		AudioManager.play_sfx("ui_hover", -6.0)
		_refresh_fleet_panel()
		_add_combat_log("Hostile Ace locked: %s [%s]" % [e.pilot_name, e.ship_name], Color(1.0, 0.55, 0.35))
	)
	_ace_panel.exit_pressed.connect(func() -> void:
		_add_combat_log("Disengaging to the Admiral strategic chart for repositioning.", Color(0.4, 0.9, 1.0))
		TurnManager.exit_ace_mode()
		_open_admiral_chart()
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
	_ace_panel.toggle_weapon_arcs_pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
	)
	layer.add_child(_ace_panel)

	# 5. Resolution Progress Bar Overlay (centered at bottom during movement execution)
	_resolve_panel = PanelContainer.new()
	_resolve_panel.theme = _hud_theme
	_resolve_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_resolve_panel.position = Vector2(-240, -72)
	_resolve_panel.custom_minimum_size = Vector2(480, 54)
	_resolve_panel.visible = false
	layer.add_child(_resolve_panel)

	var res_vbox := VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 4)
	_resolve_panel.add_child(res_vbox)

	_resolve_label = Label.new()
	_resolve_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resolve_label.add_theme_font_size_override("font_size", 13)
	_resolve_label.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
	res_vbox.add_child(_resolve_label)

	_resolve_bar = ProgressBar.new()
	_resolve_bar.custom_minimum_size = Vector2(0, 12)
	res_vbox.add_child(_resolve_bar)

	# 6. Hero Roster Modal (Allied Aces vs. Hostile Commanders) + Help / Victory / Defeat Overlays
	_roster_modal = HudWidgets.HeroRosterModal.new()
	_roster_modal.theme = _hud_theme
	var roster_layer := CanvasLayer.new()
	roster_layer.layer = 20
	add_child(roster_layer)
	roster_layer.add_child(_roster_modal)

	_refresh_fleet_panel()
	_build_help_overlay(layer)
	_build_victory_overlay(layer)
	_build_defeat_overlay(layer)
	_disable_button_focus(layer)

func _refresh_fleet_panel() -> void:
	if _order_panel != null:
		_order_panel.rebuild_unit_cards(_player_ships, _enemy_ships, _selected_ship, _ace_target)
	if _ace_panel != null:
		_ace_panel.set_fleet(_player_ships, _selected_ship, _enemy_ships, _ace_target)
		_ace_panel.target = _ace_target
	if _roster_modal != null:
		_roster_modal.set_battle_rosters(_player_ships, _enemy_ships)
	if _callout_overlay != null:
		_callout_overlay.ships = _player_ships + _enemy_ships
		_callout_overlay.selected_ship = _selected_ship
		_callout_overlay.target_ship = _ace_target
	_check_stage_objectives()

func _update_hud_telemetry() -> void:
	if _callout_overlay != null and _callout_overlay.camera == null:
		_callout_overlay.camera = get_viewport().get_camera_3d()

	if TurnManager.is_resolving():
		var remaining := TurnManager.remaining_resolve_time()
		if TurnManager.phase == TurnManager.Phase.ACE_RESOLVE:
			_resolve_label.text = "ACE PHASE // ROUND %d RESOLUTION — %.1fs" % [TurnManager.ace_round, remaining]
			_resolve_bar.max_value = TurnManager.ace_resolution_window
		else:
			_resolve_label.text = "ADMIRAL PHASE // SIMULTANEOUS EXECUTION — %.1fs" % remaining
			_resolve_bar.max_value = TurnManager.admiral_resolution_window
		_resolve_bar.value = remaining

	if _turn_label_prefix != null:
		_turn_label_prefix.text = "TURN %d |" % TurnManager.turn_number

	if _weather_panel != null and _selected_ship != null and not _selected_ship.is_destroyed():
		match _selected_ship.faction:
			"acero":
				_weather_panel.active_faction_idx = 0
			"marea_libre":
				_weather_panel.active_faction_idx = 1
			_:
				_weather_panel.active_faction_idx = 2
		_weather_panel.queue_redraw()

func _on_phase_changed(_phase: int) -> void:
	var in_ace := TurnManager.is_in_ace()
	var resolving := TurnManager.is_resolving()

	if _turn_label_phase != null:
		_turn_label_phase.text = "ACE PHASE" if in_ace else "ADMIRAL PHASE"

	if _ace_top_banner != null:
		_ace_top_banner.visible = in_ace
		_ace_top_banner.round_number = TurnManager.ace_round
		_ace_top_banner.queue_redraw()

	if _weather_panel != null:
		_weather_panel.visible = not in_ace

	if _order_panel != null:
		_order_panel.visible = not in_ace and not resolving
	if _ace_panel != null:
		_ace_panel.visible = in_ace and not resolving
	if _resolve_panel != null:
		_resolve_panel.visible = resolving

	_refresh_fleet_panel()

func _update_round_banner() -> void:
	if _ace_top_banner != null:
		_ace_top_banner.round_number = TurnManager.ace_round
		_ace_top_banner.queue_redraw()

func _check_stage_objectives() -> void:
	if _mission_completed:
		return

	var total_enemies := _enemy_ships.size()
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
		_objective_label.text = "[HOSTILES: %d/%d DESTROYED | FLAGSHIP: %d%% HP]" % [
			total_enemies - enemies_alive, total_enemies, flagship_hp_pct
		]

	if enemies_alive == 0:
		_mission_completed = true
		_show_mission_victory()
	elif players_alive == 0 or not flagship_alive:
		_mission_completed = true
		_show_mission_defeat()

func _get_next_stage_id() -> String:
	match LoreDB.current_stage_id:
		"acero_stage_1":
			return "acero_stage_2"
		"acero_stage_2":
			return "acero_stage_3"
		_:
			return ""

func _show_mission_victory() -> void:
	AudioManager.play_sfx("shockwave", 0.0)
	AudioManager.play_sfx("explosion_big", 0.0)

	var surviving_ids: Array[String] = []
	var promo_lines: Array[String] = []
	for p in _player_ships:
		if not p.is_destroyed():
			surviving_ids.append(p.ship_id)
			var new_rank := mini(SaveManager.get_veteran_rank(p.ship_id) + 1, 5)
			promo_lines.append("★ %s (%s) promoted to %s [Rank %d: +%d%% HP / +%d%% DMG]" % [
				p.pilot_name, p.ship_name, SaveManager.get_veteran_title(new_rank), new_rank, new_rank * 6, new_rank * 5
			])

	SaveManager.record_stage_victory(LoreDB.current_stage_id, surviving_ids)

	if LoreDB.current_stage_id == "acero_stage_1":
		_add_combat_log("STAGE 01 COMPLETE: SLUICE STATION WELL-09 SECURED! STEEL ENDURES!", Color(0.3, 1.0, 0.6))
	elif LoreDB.current_stage_id == "acero_stage_2":
		_add_combat_log("STAGE 02 COMPLETE: RESONANCE SPIRE SECURED!", Color(0.3, 1.0, 0.6))
	elif LoreDB.current_stage_id == "acero_stage_3":
		_add_combat_log("ACT I CAMPAIGN COMPLETE: THE CALM THRESHOLD HELD!", Color(0.3, 1.0, 0.6))
	else:
		_add_combat_log("MISSION ACCOMPLISHED: SECTOR SECURED!", Color(0.3, 1.0, 0.6))

	if _victory_sub_label != null and not promo_lines.is_empty():
		_victory_sub_label.text += "\n\nVETERAN ACE PROMOTIONS (SAVED TO CAMPAIGN):\n" + "\n".join(promo_lines)

	var next_id := _get_next_stage_id()
	if _victory_next_btn != null:
		_victory_next_btn.visible = (next_id != "")
		if next_id == "acero_stage_2":
			_victory_next_btn.text = "▶ DEPLOY STAGE 02: RESONANCE SPIRE"
		elif next_id == "acero_stage_3":
			_victory_next_btn.text = "▶ DEPLOY STAGE 03: CALM THRESHOLD"

	if _victory_overlay != null:
		_victory_overlay.visible = true

func _show_mission_defeat() -> void:
	AudioManager.play_sfx("shockwave", 0.0)
	AudioManager.play_sfx("explosion_big", 0.0)
	_add_combat_log("MISSION FAILED: FLAGSHIP DESTROYED", Color(1.0, 0.3, 0.3))
	if _defeat_overlay != null:
		_defeat_overlay.visible = true

func _build_victory_overlay(layer: CanvasLayer) -> void:
	_victory_overlay = Control.new()
	_victory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_overlay.visible = false
	layer.add_child(_victory_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.08, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = _hud_theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(650, 350)
	_victory_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_victory_title_label = Label.new()
	match LoreDB.current_stage_id:
		"acero_stage_1":
			_victory_title_label.text = "STAGE 01 ACCOMPLISHED // STEEL ENDURES"
		"acero_stage_2":
			_victory_title_label.text = "STAGE 02 ACCOMPLISHED // THE CHOIR SILENCED"
		"acero_stage_3":
			_victory_title_label.text = "ACT I VICTORY // BASTION OF THE CALM"
		_:
			_victory_title_label.text = "MISSION ACCOMPLISHED"
	_victory_title_label.add_theme_font_size_override("font_size", 20)
	_victory_title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
	vbox.add_child(_victory_title_label)

	_victory_sub_label = Label.new()
	match LoreDB.current_stage_id:
		"acero_stage_1":
			_victory_sub_label.text = "Sluice Station Well-09 Secured // The Armada of Acero\nFleet Admiral Vane's line of battle shattered Captain Solano's corsair raid. Refined éteron continues to flow toward the orbital forges of Anvil."
		"acero_stage_2":
			_victory_sub_label.text = "Resonance Spire Secured // The Armada of Acero\nCommander Kaelen's Vinculados Choir Wing was forced to retreat before they could destabilize the sector's Éther currents."
		"acero_stage_3":
			_victory_sub_label.text = "The Calm Threshold Held // Act I Campaign Complete\nAgainst the encroaching Calm, Admiral Vane's veteran squadron broke the coalition vanguard and anchored the Sluice Wall."
		_:
			_victory_sub_label.text = "Sector Psalm-4 // Resonance Well Secured\nThe hostile strike group has been repelled. Your squadron holds control of the local Éther currents."
	_victory_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_victory_sub_label.add_theme_font_size_override("font_size", 12)
	_victory_sub_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(_victory_sub_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_victory_next_btn = Button.new()
	_victory_next_btn.text = "▶ DEPLOY NEXT STAGE"
	_victory_next_btn.custom_minimum_size = Vector2(240, 38)
	_victory_next_btn.visible = (_get_next_stage_id() != "")
	_victory_next_btn.pressed.connect(func() -> void:
		var nxt := _get_next_stage_id()
		if nxt != "":
			LoreDB.current_stage_id = nxt
			get_tree().reload_current_scene()
	)
	btn_row.add_child(_victory_next_btn)

	var menu_btn := Button.new()
	menu_btn.text = "◀ CAMPAIGN MENU"
	menu_btn.custom_minimum_size = Vector2(180, 38)
	menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	btn_row.add_child(menu_btn)

	var replay_btn := Button.new()
	replay_btn.text = "↻ REPLAY STAGE"
	replay_btn.custom_minimum_size = Vector2(150, 38)
	replay_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
	btn_row.add_child(replay_btn)

func _build_defeat_overlay(layer: CanvasLayer) -> void:
	_defeat_overlay = Control.new()
	_defeat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defeat_overlay.visible = false
	layer.add_child(_defeat_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.01, 0.02, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defeat_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = _hud_theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(580, 310)
	_defeat_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "MISSION FAILED // LINE OF BATTLE BROKEN"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	vbox.add_child(title)

	var sub := Label.new()
	if LoreDB.current_stage_id == "acero_stage_1":
		sub.text = "Sluice Station Well-09 Lost // Flagship CNS Iron Bastion Destroyed\n\nWithout the Anvil-class flagship anchoring the line, Free Tide corsairs breached the sluice gates and cut Anvil's éteron supply spine."
	else:
		sub.text = "Flagship Link Severed // The Squadron Falls Silent\n\nYour command vessel was destroyed in combat."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.95, 0.8, 0.8))
	vbox.add_child(sub)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var menu_btn := Button.new()
	menu_btn.text = "◀ RETURN TO CAMPAIGN MENU"
	menu_btn.custom_minimum_size = Vector2(230, 38)
	menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	btn_row.add_child(menu_btn)

	var retry_btn := Button.new()
	retry_btn.text = "↻ RETRY STAGE 01"
	retry_btn.custom_minimum_size = Vector2(180, 38)
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
	header_row.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header_row)

	var title := Label.new()
	title.text = "BARLOVENTO // TACTICAL DOCTRINE & FLIGHT MANUAL"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	header_row.add_child(title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_spacer)

	var to_menu_btn := Button.new()
	to_menu_btn.text = "◀ MAIN MENU"
	to_menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	header_row.add_child(to_menu_btn)

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

Shift + Left-Drag  Point heading & set speed directly on 3D plane
A / D / Arrows     Turn Port / Starboard (Yaw)
Q / E / UP / DN    Climb / Dive (Pitch Up / Down)
W / S              Increase / Decrease throttle
X                  Emergency full retrograde brake
Tab / Click        Select fleet unit
Space              Execute simultaneous WEGO turn

• DIRECTIONAL ARMOR: Bow armor mitigates damage; Stern Rakes deal +40% critical damage!
• BROADSIDE ARCS: Galleons and Dreadnoughts can fire both forward and Port/Starboard broadsides."""
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
	_add_action("toggle_roster", [KEY_R])
	_add_action("ace_cycle", [KEY_C])
	_add_action("intercept_target", [KEY_T])
	_add_action("quick_save", [KEY_F5])
	_add_action("quick_load", [KEY_F9])

func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _open_admiral_chart() -> void:
	if _camera_rig != null:
		_camera_rig.set_admiral_zenith_view()

	if _admiral_chart == null:
		_admiral_layer = CanvasLayer.new()
		_admiral_layer.layer = 15
		add_child(_admiral_layer)

		_admiral_chart = AdmiralChart.new()
		_admiral_chart.stage_title = _stage_title_label.text if _stage_title_label != null else "SECTOR OPERATION"
		_admiral_chart.turn_executed.connect(_on_chart_turn_executed)
		_admiral_chart.engage_3d_requested.connect(_on_chart_engage_3d)
		_admiral_chart.ship_selected_on_chart.connect(func(idx: int) -> void:
			if idx >= 0 and idx < _player_ships.size() and not _player_ships[idx].is_destroyed():
				_set_selected(_player_ships[idx])
		)
		_admiral_chart.open_roster_requested.connect(func() -> void:
			if _roster_modal != null:
				_roster_modal.set_battle_rosters(_player_ships, _enemy_ships)
				_roster_modal.visible = not _roster_modal.visible
		)
		_admiral_chart.return_menu_requested.connect(func() -> void:
			AudioManager.play_sfx("ui_click", -8.0)
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
		)
		_admiral_layer.add_child(_admiral_chart)

	_admiral_chart.modulate.a = 1.0
	_admiral_chart.sync_from_3d_ships(_player_ships, _enemy_ships, _ether)
	_admiral_chart.visible = true
	AudioManager.play_sfx("ui_hover", -8.0)

func _on_chart_turn_executed(summary_log: String, contact_reached: bool, p_spawns: Array = [], e_spawns: Array = []) -> void:
	_add_combat_log(summary_log, Color(0.35, 0.95, 1.0))
	if contact_reached:
		_add_combat_log(">>> FLEET CONTACT! ENGAGING 3D ACE TACTICAL COMBAT <<<", Color(1.0, 0.82, 0.35))

	# Animate real 3D ships simultaneously gliding to their new quadrant positions!
	for i in range(mini(_player_ships.size(), p_spawns.size())):
		var s := _player_ships[i]
		if s != null and not s.is_destroyed():
			var p_info: Dictionary = p_spawns[i]
			var target_pos: Vector3 = p_info.get("pos", s.state.position)
			var target_fwd: Vector3 = p_info.get("fwd", s.state.forward)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(s, "position", target_pos, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(s.state, "position", target_pos, 0.85)
			s.state.forward = target_fwd
			s.order.yaw = Vector3.FORWARD.signed_angle_to(target_fwd, Vector3.UP)
			s.refresh_after_load()

	for i in range(mini(_enemy_ships.size(), e_spawns.size())):
		var e := _enemy_ships[i]
		if e != null and not e.is_destroyed():
			var e_info: Dictionary = e_spawns[i]
			var target_pos: Vector3 = e_info.get("pos", e.state.position)
			var target_fwd: Vector3 = e_info.get("fwd", e.state.forward)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(e, "position", target_pos, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(e.state, "position", target_pos, 0.85)
			e.state.forward = target_fwd
			e.order.yaw = Vector3.FORWARD.signed_angle_to(target_fwd, Vector3.UP)
			e.refresh_after_load()

func _on_chart_engage_3d(bonuses: Dictionary) -> void:
	_strategic_bonuses = bonuses
	if _admiral_chart != null:
		_admiral_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. Apply 3D Spawns & Vectors computed from strategic chart
	var p_spawns: Array = bonuses.get("player_spawns", [])
	for i in range(mini(_player_ships.size(), p_spawns.size())):
		var s := _player_ships[i]
		if s.is_destroyed():
			continue
		var info: Dictionary = p_spawns[i]
		s.state.position = info.get("pos", s.state.position)
		s.position = s.state.position
		s.state.forward = info.get("fwd", s.state.forward)
		s.order.yaw = Vector3.FORWARD.signed_angle_to(s.state.forward, Vector3.UP)
		var spd_mult: float = bonuses.get("speed_mult", 1.0)
		s.order.target_speed = minf(s.state.max_speed * 0.70 * spd_mult, s.state.max_speed)
		s.initial_velocity = s.state.forward * s.order.target_speed
		s.state.velocity = s.initial_velocity
		s.refresh_after_load()

	var e_spawns: Array = bonuses.get("enemy_spawns", [])
	for i in range(mini(_enemy_ships.size(), e_spawns.size())):
		var e := _enemy_ships[i]
		if e.is_destroyed():
			continue
		var info: Dictionary = e_spawns[i]
		e.state.position = info.get("pos", e.state.position)
		e.position = e.state.position
		e.state.forward = info.get("fwd", e.state.forward)
		e.order.yaw = Vector3.FORWARD.signed_angle_to(e.state.forward, Vector3.UP)
		e.initial_velocity = e.state.forward * 4.0
		e.state.velocity = e.initial_velocity
		e.refresh_after_load()

	# 2. Smooth cinematic camera swoop into 3D follow perspective!
	if _camera_rig != null and _selected_ship != null:
		_camera_rig.set_ace_combat_view(_selected_ship.state.position, _selected_ship.order.yaw)

	# 3. Apply Doctrine Buffs to Ships
	var has_barlovento: bool = bonuses.get("has_barlovento", false)
	var is_crossing_t: bool = bonuses.get("is_crossing_t", false)
	var is_flanking: bool = bonuses.get("is_flanking", false)
	var armor_mult: float = bonuses.get("armor_mult", 1.0)
	var turn_mult: float = bonuses.get("turn_mult", 1.0)

	for s in _player_ships:
		s.set_meta("admiral_barlovento", has_barlovento)
		s.set_meta("admiral_barlovento_rounds", 3 if has_barlovento else 0)
		s.set_meta("formation_armor_mult", armor_mult)
		if bonuses.get("formation", 0) == AdmiralChart.Formation.FLANKING_PINCER:
			s.set_meta("formation_flank_mult", 1.35)
		s.state.turn_power *= turn_mult

	# 4. Apply Ace Panel Bonus AP
	var bonus_ap: int = bonuses.get("bonus_ap", 0)
	if _ace_panel != null:
		_ace_panel.set_strategic_bonus_ap(bonus_ap)

	# 5. Announce Strategic Results in Combat Log
	if has_barlovento:
		_add_combat_log("🌬 [BARLOVENTO SECURED] Fleet claims the weather gauge! (+1 AP, +15% Hit, +15% Damage for 3 rounds)", Color(0.35, 1.0, 0.72))
	elif bonuses.get("enemy_barlovento", false):
		_add_combat_log("🌬 [BARLOVENTO ENEMY] Hostile fleet holds the upwind current! (+15% Enemy Hit & Damage)", Color(1.0, 0.45, 0.35))
	else:
		_add_combat_log("🌬 [BARLOVENTO CONTESTED] Neutral Éther alignment across both battle groups.", Color(0.75, 0.85, 0.95))

	if is_crossing_t:
		_add_combat_log("🎯 [CROSSING THE 'T'] Enemy fleet flanked! Hostiles deployed with vulnerable port/starboard exposed!", Color(0.40, 0.96, 1.0))
	elif is_flanking:
		_add_combat_log("🎯 [PINCER AMBUSH] Flanking envelopment achieved! Allied wing deployed with stern firing angles!", Color(0.40, 0.96, 1.0))

	if bonuses.get("sluice_held", false):
		_add_combat_log("⚙ [SLUICE STATION HELD] Continuous power flow shields allied squadron (+20 SHLD regen)!", Color(1.0, 0.82, 0.35))

	_engage_ace_mode()

func _tick_strategic_barlovento() -> void:
	for s in _player_ships:
		if s.has_meta("admiral_barlovento_rounds"):
			var r := int(s.get_meta("admiral_barlovento_rounds")) - 1
			if r <= 0:
				s.set_meta("admiral_barlovento", false)
				s.set_meta("admiral_barlovento_rounds", 0)
			else:
				s.set_meta("admiral_barlovento_rounds", r)
