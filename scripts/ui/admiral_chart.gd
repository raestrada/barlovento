class_name AdmiralChart
extends Control

signal turn_executed(summary_log: String, contact_reached: bool, p_spawns: Array, e_spawns: Array)
signal engage_3d_requested(strategic_result: Dictionary)
signal ship_selected_on_chart(ship_index: int)
signal open_roster_requested
signal return_menu_requested

var grid_cols: int = 10
var grid_rows: int = 8
const MAX_STRATEGIC_TURNS := 6

enum Formation { LINE_OF_BATTLE, SPEARHEAD_WEDGE, FLANKING_PINCER }

const UNIT_COLORS: Array[Color] = [
	Color(0.22, 0.88, 1.0),   # Unit 1: Cyan / Electric Blue (Flagship)
	Color(1.0, 0.80, 0.25),   # Unit 2: Amber / Gold (Vanguard)
	Color(0.38, 1.0, 0.65)    # Unit 3: Emerald / Mint (Flanker)
]

var player_ships: Array[Ship] = []
var enemy_ships: Array[Ship] = []
var wind_dir: Vector2 = Vector2(1.0, -0.25).normalized()
var stage_title: String = "ACT I // STAGE 01: SLUICE STATION WELL-09"
var commander_name: String = "FLEET ADMIRAL VANE"
var commander_portrait: Texture2D = null

var strategic_turn: int = 1
var current_formation: Formation = Formation.LINE_OF_BATTLE
var selected_unit_idx: int = 0
var move_whole_fleet: bool = false
var is_animating_turn: bool = false

# 10x8 Grid Coordinates (Vector2i) and continuous animated positions (Vector2)
var _p_cells: Array[Vector2i] = [Vector2i(4, 7), Vector2i(3, 7), Vector2i(5, 7)]
var _p_targets: Array[Vector2i] = [Vector2i(4, 6), Vector2i(3, 6), Vector2i(5, 6)]
var _p_anim_pos: Array[Vector2] = [Vector2(4, 7), Vector2(3, 7), Vector2(5, 7)]
var _p_facing: Array[Vector2] = [Vector2(0, -1), Vector2(0, -1), Vector2(0, -1)]

var _e_cells: Array[Vector2i] = [Vector2i(4, 0), Vector2i(3, 0), Vector2i(5, 0)]
var _e_targets: Array[Vector2i] = [Vector2i(4, 1), Vector2i(3, 1), Vector2i(5, 1)]
var _e_anim_pos: Array[Vector2] = [Vector2(4, 0), Vector2(3, 0), Vector2(5, 0)]
var _e_facing: Array[Vector2] = [Vector2(0, 1), Vector2(0, 1), Vector2(0, 1)]

# Special terrain sectors on the 10x8 naval chart
# "wind_stream" = Upwind Ether Current (+Barlovento), "reef" = Basalt Reef (+Cover), "sluice" = Sluice Station / Objective
# "conduit" = Éther Booster Node, "calm" = Dead Zone Hazard
var _sector_types: Dictionary = {}

var _board_canvas: Control
var _turn_lbl: Label
var _range_telemetry_lbl: Label
var _status_lbl: Label
var _adv_weather_lbl: Label
var _adv_flank_lbl: Label
var _adv_form_lbl: Label
var _adv_nodes_lbl: Label
var _unit_btns: Array[Button] = []
var _form_btns: Array[Button] = []
var _fleet_mode_btn: Button
var _step_turn_btn: Button
var _engage_btn: Button
var _anim_t: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure_stage_grid()
	_init_sector_terrain()
	_build_ui()
	_plan_initial_orders()
	_refresh_ui()

func _process(delta: float) -> void:
	_anim_t += delta
	if _board_canvas != null and visible:
		_board_canvas.queue_redraw()

func _configure_stage_grid() -> void:
	var sz := StrategicGridSolver.configure_stage_grid(LoreDB.current_stage_id)
	grid_cols = sz.x
	grid_rows = sz.y

func sync_from_3d_ships(p_ships: Array[Ship], e_ships: Array[Ship], ether_field: EtherField) -> void:
	player_ships = p_ships
	enemy_ships = e_ships
	_configure_stage_grid()
	_init_sector_terrain()
	if ether_field != null:
		var d3 := ether_field.direction
		var w2 := Vector2(d3.x, d3.z)
		if w2.length_squared() > 0.01:
			wind_dir = w2.normalized()

	var used_p: Array[Vector2i] = []
	var default_p_cols := [clampi(grid_cols / 2, 0, grid_cols - 1), clampi(grid_cols / 2 - 1, 0, grid_cols - 1), clampi(grid_cols / 2 + 1, 0, grid_cols - 1)]
	for i in range(3):
		var c := Vector2i(default_p_cols[i], grid_rows - 1)
		if i < player_ships.size() and player_ships[i] != null:
			c = _world_to_cell(player_ships[i].state.position, true, i)
			c.y = clampi(c.y, maxi(grid_rows - 2, 0), grid_rows - 1)
		if used_p.has(c):
			c = Vector2i(default_p_cols[i], clampi(c.y, maxi(grid_rows - 2, 0), grid_rows - 1))
		used_p.append(c)
		_p_cells[i] = c
		_p_anim_pos[i] = Vector2(c.x, c.y)
		_p_facing[i] = Vector2(0, -1)

	var used_e: Array[Vector2i] = []
	var default_e_cols := [clampi(grid_cols / 2, 0, grid_cols - 1), clampi(grid_cols / 2 - 1, 0, grid_cols - 1), clampi(grid_cols / 2 + 1, 0, grid_cols - 1)]
	for i in range(3):
		var c := Vector2i(default_e_cols[i], 0)
		if i < enemy_ships.size() and enemy_ships[i] != null:
			c = _world_to_cell(enemy_ships[i].state.position, false, i)
			c.y = clampi(c.y, 0, mini(1, grid_rows - 1))
		if used_e.has(c):
			c = Vector2i(default_e_cols[i], clampi(c.y, 0, mini(1, grid_rows - 1)))
		used_e.append(c)
		_e_cells[i] = c
		_e_anim_pos[i] = Vector2(c.x, c.y)
		_e_facing[i] = Vector2(0, 1)

	_plan_initial_orders()
	_sync_3d_ships_to_chart_positions()
	_refresh_ui()

func _sync_3d_ships_to_chart_positions() -> void:
	for idx in range(player_ships.size()):
		var s := player_ships[idx]
		if s == null or s.is_destroyed():
			continue
		var div_idx: int = idx % 3
		s.division_index = div_idx
		var anim_g: Vector2 = _p_anim_pos[div_idx]
		var cx := (anim_g.x + 0.5) / float(grid_cols) * (StrategicGridSolver.WORLD_HALF_X * 2.0) - StrategicGridSolver.WORLD_HALF_X
		var cz := (anim_g.y + 0.5) / float(grid_rows) * (StrategicGridSolver.WORLD_HALF_Z * 2.0) - StrategicGridSolver.WORLD_HALF_Z
		var off := StrategicGridSolver.get_wingman_offset(idx, true)
		var world_pos := Vector3(cx, 0.0, cz) + off
		var f2: Vector2 = _p_facing[div_idx]
		var fwd := Vector3(f2.x, 0.0, f2.y).normalized()
		if fwd.length_squared() < 0.01:
			fwd = Vector3.FORWARD
		s.state.position = world_pos
		s.state.forward = fwd
		s.state.velocity = fwd * 9.0
		var tgt_cell := _p_targets[div_idx]
		var cur_cell := _p_cells[div_idx]
		if tgt_cell == cur_cell:
			s.order.target_speed = 0.0
			s.overwatch_anchored = true
		else:
			var tgt_w := StrategicGridSolver.cell_center_world(tgt_cell, grid_cols, grid_rows) + off
			var dir_to_tgt := (tgt_w - world_pos)
			dir_to_tgt.y = 0.0
			if dir_to_tgt.length_squared() > 0.01:
				var h_norm := dir_to_tgt.normalized()
				s.order.yaw = Vector3.FORWARD.signed_angle_to(h_norm, Vector3.UP)
				s.order.target_speed = clampf(dir_to_tgt.length() * 0.42, 7.0, 16.0)
			s.overwatch_anchored = false
		s.sync_transform_now()

	for idx in range(enemy_ships.size()):
		var s := enemy_ships[idx]
		if s == null or s.is_destroyed():
			continue
		var div_idx: int = idx % 3
		s.division_index = div_idx
		var anim_g: Vector2 = _e_anim_pos[div_idx]
		var cx := (anim_g.x + 0.5) / float(grid_cols) * (StrategicGridSolver.WORLD_HALF_X * 2.0) - StrategicGridSolver.WORLD_HALF_X
		var cz := (anim_g.y + 0.5) / float(grid_rows) * (StrategicGridSolver.WORLD_HALF_Z * 2.0) - StrategicGridSolver.WORLD_HALF_Z
		var off := StrategicGridSolver.get_wingman_offset(idx, false)
		var world_pos := Vector3(cx, 0.0, cz) + off
		var f2: Vector2 = _e_facing[div_idx]
		var fwd := Vector3(f2.x, 0.0, f2.y).normalized()
		if fwd.length_squared() < 0.01:
			fwd = Vector3.BACK
		s.state.position = world_pos
		s.state.forward = fwd
		s.state.velocity = fwd * 4.5
		s.sync_transform_now()

func set_selected_unit(idx: int) -> void:
	if idx >= 0 and idx < 3:
		selected_unit_idx = idx
		_refresh_ui()

func _world_to_cell(pos: Vector3, is_p: bool, idx: int) -> Vector2i:
	return StrategicGridSolver.world_to_cell(pos, is_p, idx, grid_cols, grid_rows)

func _cell_to_world(cell: Vector2i, facing: Vector2, is_p: bool, idx: int) -> Dictionary:
	return StrategicGridSolver.cell_to_world(cell, facing, is_p, idx, grid_cols, grid_rows)

func _init_sector_terrain() -> void:
	_sector_types = StrategicGridSolver.init_sector_terrain(LoreDB.current_stage_id, grid_cols, grid_rows)

func _plan_initial_orders() -> void:
	for i in range(3):
		var cur := _p_cells[i]
		var next_y := maxi(cur.y - 1, 0)
		var next_x := cur.x
		if current_formation == Formation.FLANKING_PINCER:
			if i == 1:
				next_x = maxi(cur.x - 1, 0)
			elif i == 2:
				next_x = mini(cur.x + 1, grid_cols - 1)
		_p_targets[i] = Vector2i(next_x, next_y)
		var dv := Vector2(_p_targets[i] - cur)
		if dv.length_squared() > 0.01:
			_p_facing[i] = dv.normalized()

	_plan_ai_chart_orders()

func _plan_ai_chart_orders() -> void:
	var claimed: Array[Vector2i] = []
	for i in range(3):
		var cur := _e_cells[i]
		var target_p := _p_cells[mini(i, _p_cells.size() - 1)]
		var best := cur
		var best_score := -INF
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var cand := Vector2i(clampi(cur.x + ox, 0, grid_cols - 1), clampi(cur.y + oy, 0, grid_rows - 1))
				if claimed.has(cand):
					continue
				var score := 0.0
				var dist_to_target := Vector2(cand - target_p).length()
				score += (14.0 - dist_to_target) * 1.1

				# Hazard avoidance: stay far out of The Calm!
				if _sector_types.get(cand, "") == "calm":
					score -= 75.0

				# Contest Éther Conduits (+1 AP reward)
				if _sector_types.get(cand, "") == "conduit":
					score += 5.5

				# Contest Barlovento Wind Stream (+Hit & Damage)
				if _sector_types.get(cand, "") == "wind_stream":
					score += 4.0

				# Flanking reefs cover
				if _sector_types.get(cand, "") == "reef":
					score += 2.2

				# Bias against idling unless holding a strategic conduit
				if cand == cur and _sector_types.get(cur, "") != "conduit":
					score -= 3.0

				if score > best_score:
					best_score = score
					best = cand

		claimed.append(best)
		_e_targets[i] = best
		var dv := Vector2(best - cur)
		if dv.length_squared() > 0.01:
			_e_facing[i] = dv.normalized()

func _build_ui() -> void:
	# Subtle, non-blocking cinematic backdrop with vignette: 3D scene is 100% visible through center
	var top_vignette := ColorRect.new()
	top_vignette.color = Color(0.008, 0.015, 0.03, 0.65)
	top_vignette.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_vignette.offset_bottom = 74
	top_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_vignette)

	var btm_vignette := ColorRect.new()
	btm_vignette.color = Color(0.008, 0.015, 0.03, 0.70)
	btm_vignette.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	btm_vignette.offset_top = -80
	btm_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(btm_vignette)

	# Fullscreen root layout
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 20)
	root_margin.add_theme_constant_override("margin_right", 20)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_bottom", 12)
	root_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_margin.add_child(main_vbox)

	# ── 1. TOP COMMAND BAR ──
	var top_panel := PanelContainer.new()
	var top_st := StyleBoxFlat.new()
	top_st.bg_color = Color(0.015, 0.032, 0.065, 0.88)
	top_st.border_color = Color(0.28, 0.82, 1.0, 0.65)
	top_st.set_border_width_all(1)
	top_st.set_corner_radius_all(6)
	top_st.set_content_margin_all(8)
	top_panel.add_theme_stylebox_override("panel", top_st)
	main_vbox.add_child(top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 16)
	top_panel.add_child(top_hbox)

	var logo_tex: Texture2D = load("res://assets/brand/logo.png")
	if logo_tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = logo_tex
		atlas.region = Rect2(80, 220, 1216, 280)
		var logo_rect := TextureRect.new()
		logo_rect.texture = atlas
		logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo_rect.custom_minimum_size = Vector2(170, 36)
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top_hbox.add_child(logo_rect)

	top_hbox.add_child(VSeparator.new())

	var title_vbox := VBoxContainer.new()
	title_vbox.add_theme_constant_override("separation", 1)
	top_hbox.add_child(title_vbox)

	var phase_hdr := Label.new()
	phase_hdr.text = "PHASE 1: ADMIRAL HOLOGRAPHIC STRATEGIC THEATER"
	phase_hdr.add_theme_font_size_override("font_size", 14)
	phase_hdr.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	title_vbox.add_child(phase_hdr)

	_status_lbl = Label.new()
	_status_lbl.text = "Maneuver your task force across 8x6 tactical quadrants. Claim the upwind Éther stream to gain Weather-Gauge [BARLOVENTO]."
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
	title_vbox.add_child(_status_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(sp)

	var turn_box := VBoxContainer.new()
	turn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_child(turn_box)

	_turn_lbl = Label.new()
	_turn_lbl.text = "STRATEGIC MANEUVER TURN 1 / 5"
	_turn_lbl.add_theme_font_size_override("font_size", 13)
	_turn_lbl.add_theme_color_override("font_color", Color(0.35, 0.96, 1.0))
	turn_box.add_child(_turn_lbl)

	_range_telemetry_lbl = Label.new()
	_range_telemetry_lbl.text = "FLEET SEPARATION: 76.0m [OUTER APPROACH]"
	_range_telemetry_lbl.add_theme_font_size_override("font_size", 10)
	_range_telemetry_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	turn_box.add_child(_range_telemetry_lbl)

	var roster_btn := Button.new()
	roster_btn.text = "★ ROSTER [R]"
	roster_btn.custom_minimum_size = Vector2(105, 34)
	roster_btn.pressed.connect(func() -> void: open_roster_requested.emit())
	top_hbox.add_child(roster_btn)

	var menu_btn := Button.new()
	menu_btn.text = "◀ MENU"
	menu_btn.custom_minimum_size = Vector2(85, 34)
	menu_btn.pressed.connect(func() -> void: return_menu_requested.emit())
	top_hbox.add_child(menu_btn)

	# ── 2. CENTER WORKSPACE: LEFT (DOCTRINE) + CENTER (OPEN 3D BOARD) + RIGHT (TELEMETRY) ──
	var center_row := HBoxContainer.new()
	center_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_row.add_theme_constant_override("separation", 14)
	center_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(center_row)

	# Left Sidebar: Fleet Formation & Squadron Controls
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(270, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var side_st := StyleBoxFlat.new()
	side_st.bg_color = Color(0.012, 0.026, 0.052, 0.82)
	side_st.border_color = Color(0.24, 0.70, 0.92, 0.45)
	side_st.set_border_width_all(1)
	side_st.set_corner_radius_all(6)
	side_st.set_content_margin_all(10)
	left_panel.add_theme_stylebox_override("panel", side_st)
	center_row.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	var sq_hdr := Label.new()
	sq_hdr.text = "1. TASK FORCE SQUADRON:"
	sq_hdr.add_theme_font_size_override("font_size", 11)
	sq_hdr.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
	left_vbox.add_child(sq_hdr)

	_unit_btns.clear()
	for i in range(3):
		var ub := Button.new()
		ub.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ub.custom_minimum_size = Vector2(0, 38)
		var idx := i
		ub.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click", -8.0)
			selected_unit_idx = idx
			ship_selected_on_chart.emit(idx)
			_refresh_ui()
		)
		left_vbox.add_child(ub)
		_unit_btns.append(ub)

	_fleet_mode_btn = Button.new()
	_fleet_mode_btn.text = "⊞ MOVE WHOLE FORMATION: OFF"
	_fleet_mode_btn.custom_minimum_size = Vector2(0, 32)
	_fleet_mode_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		move_whole_fleet = not move_whole_fleet
		_refresh_ui()
	)
	left_vbox.add_child(_fleet_mode_btn)

	left_vbox.add_child(HSeparator.new())

	var f_hdr := Label.new()
	f_hdr.text = "2. FLEET DOCTRINE / FORMATION:"
	f_hdr.add_theme_font_size_override("font_size", 11)
	f_hdr.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
	left_vbox.add_child(f_hdr)

	var form_defs := [
		{
			"id": Formation.LINE_OF_BATTLE,
			"title": "🛡 LINE OF BATTLE",
			"desc": "+20% Armor • Broadside synergy"
		},
		{
			"id": Formation.SPEARHEAD_WEDGE,
			"title": "⚡ SPEARHEAD WEDGE",
			"desc": "+25% Forward Speed • +1 Move Range"
		},
		{
			"id": Formation.FLANKING_PINCER,
			"title": "🎯 FLANKING PINCER",
			"desc": "+35% Ambush Crit • Flank envelopment"
		}
	]
	_form_btns.clear()
	for fd in form_defs:
		var fb := Button.new()
		fb.text = "%s\n   %s" % [fd["title"], fd["desc"]]
		fb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		fb.custom_minimum_size = Vector2(0, 44)
		var f_val: Formation = fd["id"]
		fb.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click", -8.0)
			current_formation = f_val
			_apply_formation_preset_to_targets()
			_refresh_ui()
		)
		left_vbox.add_child(fb)
		_form_btns.append(fb)

	var l_spacer := Control.new()
	l_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(l_spacer)

	# Center: High-Tech Holographic Canvas (Transparent background, overlays the 3D scene)
	var canvas_container := Control.new()
	canvas_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_container.mouse_filter = Control.MOUSE_FILTER_PASS
	center_row.add_child(canvas_container)

	_board_canvas = Control.new()
	_board_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_board_canvas.draw.connect(_draw_naval_chart)
	_board_canvas.gui_input.connect(_on_board_gui_input)
	canvas_container.add_child(_board_canvas)

	# Right Sidebar: Telemetry, Weather-Gauge & Strategic Node Status
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(280, 0)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", side_st)
	center_row.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	var telem_hdr := Label.new()
	telem_hdr.text = "3. STRATEGIC COMBAT ADVANTAGES:"
	telem_hdr.add_theme_font_size_override("font_size", 11)
	telem_hdr.add_theme_color_override("font_color", Color(0.35, 0.96, 1.0))
	right_vbox.add_child(telem_hdr)

	var adv_box := PanelContainer.new()
	var adv_st := StyleBoxFlat.new()
	adv_st.bg_color = Color(0.015, 0.045, 0.09, 0.88)
	adv_st.border_color = Color(0.28, 0.78, 0.95, 0.45)
	adv_st.set_border_width_all(1)
	adv_st.set_corner_radius_all(5)
	adv_st.set_content_margin_all(8)
	adv_box.add_theme_stylebox_override("panel", adv_st)
	right_vbox.add_child(adv_box)

	var adv_vbox := VBoxContainer.new()
	adv_vbox.add_theme_constant_override("separation", 6)
	adv_box.add_child(adv_vbox)

	_adv_weather_lbl = Label.new()
	_adv_weather_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_adv_weather_lbl.add_theme_font_size_override("font_size", 10)
	adv_vbox.add_child(_adv_weather_lbl)

	_adv_flank_lbl = Label.new()
	_adv_flank_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_adv_flank_lbl.add_theme_font_size_override("font_size", 10)
	adv_vbox.add_child(_adv_flank_lbl)

	_adv_nodes_lbl = Label.new()
	_adv_nodes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_adv_nodes_lbl.add_theme_font_size_override("font_size", 10)
	adv_vbox.add_child(_adv_nodes_lbl)

	_adv_form_lbl = Label.new()
	_adv_form_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_adv_form_lbl.add_theme_font_size_override("font_size", 10)
	adv_vbox.add_child(_adv_form_lbl)

	var r_spacer := Control.new()
	r_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(r_spacer)

	# ── 3. BOTTOM FLOATING ACTION BAR ──
	var btm_panel := PanelContainer.new()
	var btm_st := StyleBoxFlat.new()
	btm_st.bg_color = Color(0.015, 0.032, 0.065, 0.92)
	btm_st.border_color = Color(0.28, 0.82, 1.0, 0.75)
	btm_st.set_border_width_all(1)
	btm_st.set_corner_radius_all(6)
	btm_st.set_content_margin_all(8)
	btm_panel.add_theme_stylebox_override("panel", btm_st)
	main_vbox.add_child(btm_panel)

	var btm_hbox := HBoxContainer.new()
	btm_hbox.add_theme_constant_override("separation", 16)
	btm_panel.add_child(btm_hbox)

	var guide_lbl := Label.new()
	guide_lbl.text = "💡 Left-Click quadrant to plot waypoint • [SPACE] Execute simultaneous maneuver • [ENTER] Engage 3D Combat"
	guide_lbl.add_theme_font_size_override("font_size", 11)
	guide_lbl.add_theme_color_override("font_color", Color(0.70, 0.88, 1.0))
	guide_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btm_hbox.add_child(guide_lbl)

	_step_turn_btn = Button.new()
	_step_turn_btn.text = "▶ EXECUTE STRATEGIC TURN [SPACE]"
	_step_turn_btn.custom_minimum_size = Vector2(250, 42)
	var cta_st := StyleBoxFlat.new()
	cta_st.bg_color = Color(0.08, 0.32, 0.48, 0.95)
	cta_st.border_color = Color(0.35, 0.95, 1.0, 0.95)
	cta_st.set_border_width_all(2)
	cta_st.set_corner_radius_all(5)
	_step_turn_btn.add_theme_stylebox_override("normal", cta_st)
	_step_turn_btn.pressed.connect(execute_strategic_turn)
	btm_hbox.add_child(_step_turn_btn)

	_engage_btn = Button.new()
	_engage_btn.text = "⚔ COMMENCE ACE COMBAT [ENTER]"
	_engage_btn.custom_minimum_size = Vector2(260, 42)
	var eng_st := StyleBoxFlat.new()
	eng_st.bg_color = Color(0.48, 0.22, 0.06, 0.95)
	eng_st.border_color = Color(1.0, 0.78, 0.28, 0.95)
	eng_st.set_border_width_all(2)
	eng_st.set_corner_radius_all(5)
	_engage_btn.add_theme_stylebox_override("normal", eng_st)
	_engage_btn.pressed.connect(_trigger_3d_engagement)
	btm_hbox.add_child(_engage_btn)

func _apply_formation_preset_to_targets() -> void:
	var center_c := _p_cells[0]
	match current_formation:
		Formation.LINE_OF_BATTLE:
			var target_row := maxi(center_c.y - 1, 0)
			_p_targets[0] = Vector2i(clampi(center_c.x, 1, grid_cols - 2), target_row)
			_p_targets[1] = Vector2i(clampi(_p_targets[0].x - 1, 0, grid_cols - 1), target_row)
			_p_targets[2] = Vector2i(clampi(_p_targets[0].x + 1, 0, grid_cols - 1), target_row)
		Formation.SPEARHEAD_WEDGE:
			var lead_row := maxi(center_c.y - 2, 0)
			_p_targets[0] = Vector2i(clampi(center_c.x, 1, grid_cols - 2), lead_row)
			_p_targets[1] = Vector2i(clampi(_p_targets[0].x - 1, 0, grid_cols - 1), mini(lead_row + 1, grid_rows - 1))
			_p_targets[2] = Vector2i(clampi(_p_targets[0].x + 1, 0, grid_cols - 1), mini(lead_row + 1, grid_rows - 1))
		Formation.FLANKING_PINCER:
			var pincer_row := maxi(center_c.y - 1, 0)
			_p_targets[0] = Vector2i(clampi(center_c.x, 2, grid_cols - 3), pincer_row)
			_p_targets[1] = Vector2i(clampi(_p_targets[0].x - 2, 0, grid_cols - 1), maxi(pincer_row - 1, 0))
			_p_targets[2] = Vector2i(clampi(_p_targets[0].x + 2, 0, grid_cols - 1), maxi(pincer_row - 1, 0))

	for i in range(3):
		var dv := Vector2(_p_targets[i] - _p_cells[i])
		if dv.length_squared() > 0.01:
			_p_facing[i] = dv.normalized()
	_sync_3d_ships_to_chart_positions()

func compute_strategic_bonuses() -> Dictionary:
	var wind_cells_held := 0
	var sluice_held := 0
	var conduit_held := 0
	var reef_held := 0
	var overwatch_divisions: Array[bool] = [false, false, false]
	var overwatch_count := 0
	for i in range(3):
		var c := _p_targets[i] if not is_animating_turn else _p_cells[i]
		if _p_targets[i] == _p_cells[i]:
			overwatch_divisions[i] = true
			overwatch_count += 1
		var stype: String = _sector_types.get(c, "")
		if stype == "wind_stream":
			wind_cells_held += 1
		elif stype == "sluice":
			sluice_held += 1
		elif stype == "conduit":
			conduit_held += 1
		elif stype == "reef":
			reef_held += 1

	var enemy_wind_cells := 0
	var enemy_conduit_held := 0
	for i in range(3):
		if i < enemy_ships.size() and enemy_ships[i] != null and enemy_ships[i].is_destroyed():
			continue
		var est: String = _sector_types.get(_e_cells[i], "")
		if est == "wind_stream":
			enemy_wind_cells += 1
		elif est == "conduit":
			enemy_conduit_held += 1

	var has_barlovento := (wind_cells_held >= 1 and wind_cells_held > enemy_wind_cells)
	var enemy_barlovento := (enemy_wind_cells >= 1 and enemy_wind_cells > wind_cells_held)

	var min_px := 99
	var max_px := -99
	var avg_py := 0.0
	for i in range(3):
		var c := _p_targets[i] if not is_animating_turn else _p_cells[i]
		min_px = mini(min_px, c.x)
		max_px = maxi(max_px, c.x)
		avg_py += float(c.y)
	avg_py /= 3.0

	var avg_ex := 0.0
	var avg_ey := 0.0
	for i in range(3):
		var ec := _e_cells[i]
		avg_ex += float(ec.x)
		avg_ey += float(ec.y)
	avg_ex /= 3.0
	avg_ey /= 3.0

	var spread_span := max_px - min_px
	var is_flanking := (spread_span >= 4) or (avg_py <= avg_ey + 0.5) or (current_formation == Formation.FLANKING_PINCER)
	var is_crossing_t := (current_formation == Formation.LINE_OF_BATTLE and wind_cells_held >= 2)

	var calm_hazard_count := 0
	for i in range(3):
		var c := _p_targets[i] if not is_animating_turn else _p_cells[i]
		if _sector_types.get(c, "") == "calm":
			calm_hazard_count += 1

	var bonus_ap: int = (1 if has_barlovento else 0) + (1 if conduit_held > 0 else 0)

	return {
		"has_barlovento": has_barlovento,
		"enemy_barlovento": enemy_barlovento,
		"enemy_wind_cells": enemy_wind_cells,
		"wind_cells_held": wind_cells_held,
		"sluice_held": sluice_held > 0,
		"conduit_held": conduit_held > 0,
		"reef_held": reef_held > 0,
		"enemy_conduit_held": enemy_conduit_held > 0,
		"calm_hazard_count": calm_hazard_count,
		"is_flanking": is_flanking,
		"is_crossing_t": is_crossing_t,
		"overwatch_divisions": overwatch_divisions,
		"overwatch_count": overwatch_count,
		"formation": current_formation,
		"bonus_ap": bonus_ap,
		"accuracy_bonus": 0.15 if has_barlovento else 0.0,
		"damage_bonus": 0.15 if (has_barlovento or is_crossing_t) else 0.0,
		"crit_bonus": (0.25 if reef_held > 0 else 0.0) + (0.15 if is_flanking else 0.0),
		"armor_mult": 1.20 if current_formation == Formation.LINE_OF_BATTLE else 1.0,
		"speed_mult": (1.25 if current_formation == Formation.SPEARHEAD_WEDGE else 1.0) * (1.15 if conduit_held > 0 else 1.0),
		"turn_mult": 1.15 if current_formation == Formation.FLANKING_PINCER else 1.0
	}

func _refresh_ui() -> void:
	if _turn_lbl != null:
		_turn_lbl.text = "STRATEGIC MANEUVER TURN %d / %d" % [strategic_turn, MAX_STRATEGIC_TURNS]

	var dist_sectors := 99.0
	for p in _p_cells:
		for e in _e_cells:
			dist_sectors = minf(dist_sectors, Vector2(p - e).length())
	var dist_meters := dist_sectors * 15.0
	if _range_telemetry_lbl != null:
		var alert_tag := " [CLOSE ENGAGEMENT ENVELOPE]" if dist_sectors <= 1.5 else (" [SENSOR LOCK — CAN ENGAGE]" if dist_sectors <= 3.6 else " [THEATER MANEUVER PHASE]")
		_range_telemetry_lbl.text = "FLEET SEPARATION: %.1fm (%.1f sectors)%s" % [dist_meters, dist_sectors, alert_tag]
		_range_telemetry_lbl.modulate = Color(1.0, 0.45, 0.35) if dist_sectors <= 1.5 else (Color(1.0, 0.88, 0.35) if dist_sectors <= 3.6 else Color(0.45, 0.95, 0.75))

	if _engage_btn != null:
		var can_engage := (dist_sectors <= 3.8 or strategic_turn >= 2)
		_engage_btn.disabled = not can_engage
		if dist_sectors <= 1.5:
			_engage_btn.text = "⚔ CLOSE CONTACT: COMMENCE ACE COMBAT [ENTER]"
			_engage_btn.modulate = Color(1.0, 0.45, 0.35)
		elif can_engage:
			_engage_btn.text = "⚔ SENSOR LOCK: COMMENCE ACE COMBAT [ENTER]"
			_engage_btn.modulate = Color(1.0, 0.88, 0.35)
		else:
			_engage_btn.text = "⚔ COMMENCE COMBAT (APPROACH TO ≤55m)"
			_engage_btn.modulate = Color(0.65, 0.70, 0.80, 0.6)

	if _fleet_mode_btn != null:
		_fleet_mode_btn.text = "⊞ MOVE WHOLE FORMATION: ON" if move_whole_fleet else "⊞ MOVE WHOLE FORMATION: OFF"
		_fleet_mode_btn.modulate = Color(1.0, 0.90, 0.40) if move_whole_fleet else Color(0.85, 0.92, 1.0)

	for i in range(_unit_btns.size()):
		var btn := _unit_btns[i]
		var u_name := "UNIT %d" % (i + 1)
		var p_name := ""
		if i < player_ships.size() and player_ships[i] != null:
			u_name = player_ships[i].ship_name
			p_name = player_ships[i].pilot_name
		var c := _p_cells[i]
		var t := _p_targets[i]
		var is_sel := (i == selected_unit_idx)
		var sel_mark := "★ " if is_sel else "▶ "
		var u_col: Color = UNIT_COLORS[i]
		var order_tag := "⚓ OVERWATCH [%s]" % _cell_name(c) if c == t else "%s → %s" % [_cell_name(c), _cell_name(t)]
		btn.text = "%s%s: %s\n   [%s]" % [sel_mark, u_name, p_name, order_tag]
		btn.modulate = u_col if is_sel else u_col * Color(1.0, 1.0, 1.0, 0.68)

	for i in range(_form_btns.size()):
		var active := (int(current_formation) == i)
		_form_btns[i].modulate = Color(1.0, 0.92, 0.45) if active else Color(0.80, 0.86, 0.95)

	var b := compute_strategic_bonuses()
	if _adv_weather_lbl != null:
		if b["has_barlovento"]:
			_adv_weather_lbl.text = "🌬 BARLOVENTO: SECURED (%d Stream Sectors)\n   → +1 AP/Round, +15%% Hit & +15%% DMG in Ace Phase!" % b["wind_cells_held"]
			_adv_weather_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72))
		elif b["enemy_barlovento"]:
			_adv_weather_lbl.text = "🌬 BARLOVENTO: HELD BY HOSTILES (%d vs %d Sectors)\n   → Enemy holds the upwind current! Contest the stream!" % [b["enemy_wind_cells"], b["wind_cells_held"]]
			_adv_weather_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		else:
			_adv_weather_lbl.text = "🌬 BARLOVENTO: CONTESTED ZONE\n   → Hold more central Éther sectors than hostiles to claim +1 AP/Round."
			_adv_weather_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))

	if _adv_flank_lbl != null:
		if b["is_crossing_t"]:
			_adv_flank_lbl.text = "🎯 VECTOR: CROSSING THE 'T' (+30% Broadside DMG & +1 Opening AP)!"
			_adv_flank_lbl.add_theme_color_override("font_color", Color(0.40, 0.96, 1.0))
		elif b["is_flanking"]:
			_adv_flank_lbl.text = "🎯 VECTOR: ENVELOPING PINCER (+35% Crit & +1 Opening AP)!"
			_adv_flank_lbl.add_theme_color_override("font_color", Color(0.40, 0.96, 1.0))
		else:
			_adv_flank_lbl.text = "🎯 VECTOR: FRONTAL APPROACH (Click own quadrant for ⚓ Overwatch)"
			_adv_flank_lbl.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95))

	if _adv_nodes_lbl != null:
		var n_txt := ""
		if b["calm_hazard_count"] > 0:
			n_txt += "⚠ CALM HAZARD: %d division(s) in dead zone (-50%% SPD, Shield decay)!\n" % b["calm_hazard_count"]
		if int(b.get("overwatch_count", 0)) > 0:
			n_txt += "⚓ OVERWATCH STANCE: %d division(s) anchored (+15%% Hit & +20 Shield)!\n" % int(b.get("overwatch_count", 0))
		if b["sluice_held"]:
			n_txt += "⚙ SLUICE REFINERY: DEFENDED (+20 Shield HP Regen)\n"
		if b["conduit_held"]:
			n_txt += "⚡ ÉTHER CONDUIT: CAPTURED (+1 AP/Round & +15% Fleet Speed)!\n"
		if b["reef_held"]:
			n_txt += "🪨 REEF AMBUSH: SECURED (+25% Opening Salvo Crit DMG)!\n"
		if n_txt == "":
			n_txt = "⚙ STRATEGIC NODES: UNCONTESTED (Capture Conduit or Reefs)"
		_adv_nodes_lbl.text = n_txt
		_adv_nodes_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.85) if b["calm_hazard_count"] > 0 else Color(0.45, 0.95, 0.75))

	if _adv_form_lbl != null:
		match current_formation:
			Formation.LINE_OF_BATTLE:
				_adv_form_lbl.text = "🛡 DOCTRINE: LINE OF BATTLE (+20% Fleet Armor)"
			Formation.SPEARHEAD_WEDGE:
				_adv_form_lbl.text = "⚡ DOCTRINE: SPEARHEAD WEDGE (+25% Speed & 2-Sector Reach)"
			Formation.FLANKING_PINCER:
				_adv_form_lbl.text = "🎯 DOCTRINE: FLANKING PINCER (+15% Turn & Ambush Crit)"
		_adv_form_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))

	if _board_canvas != null:
		_board_canvas.queue_redraw()

func _cell_name(c: Vector2i) -> String:
	var cols := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P"]
	var col_s: String = cols[clampi(c.x, 0, cols.size() - 1)]
	return "%s%d" % [col_s, c.y + 1]

func _get_board_rect() -> Rect2:
	var sz := _board_canvas.size if _board_canvas != null else Vector2(880, 560)
	var pad_x := 18.0
	var pad_y := 12.0
	return Rect2(Vector2(pad_x, pad_y), Vector2(maxf(sz.x - pad_x * 2.0, 100.0), maxf(sz.y - pad_y * 2.0, 100.0)))

func _has_active_3d_projection() -> bool:
	if not is_inside_tree() or get_viewport() == null or _board_canvas == null:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	return not cam.is_position_behind(Vector3.ZERO)

func _world_to_canvas(wpos: Vector3) -> Vector2:
	if _has_active_3d_projection():
		var cam := get_viewport().get_camera_3d()
		if not cam.is_position_behind(wpos):
			var screen_pt := cam.unproject_position(wpos)
			var canvas_local := _board_canvas.get_global_transform_with_canvas().affine_inverse() * screen_pt
			return canvas_local
	var br := _get_board_rect()
	var nx := (wpos.x + StrategicGridSolver.WORLD_HALF_X) / (StrategicGridSolver.WORLD_HALF_X * 2.0)
	var nz := (wpos.z + StrategicGridSolver.WORLD_HALF_Z) / (StrategicGridSolver.WORLD_HALF_Z * 2.0)
	return br.position + Vector2(nx * br.size.x, nz * br.size.y)

func _cell_quad_canvas(c: Vector2i, inset_ratio: float = 0.94) -> PackedVector2Array:
	var corners_3d := StrategicGridSolver.cell_corners_world(c, grid_cols, grid_rows, 0.0)
	var pts: PackedVector2Array = []
	var center := Vector2.ZERO
	for w in corners_3d:
		var p := _world_to_canvas(w)
		pts.append(p)
		center += p
	center *= 0.25
	for idx in range(pts.size()):
		pts[idx] = center.lerp(pts[idx], inset_ratio)
	return pts

func _cell_rect(c: Vector2i) -> Rect2:
	if _has_active_3d_projection():
		var q := _cell_quad_canvas(c, 0.92)
		var min_v := q[0]
		var max_v := q[0]
		for pt in q:
			min_v.x = minf(min_v.x, pt.x)
			min_v.y = minf(min_v.y, pt.y)
			max_v.x = maxf(max_v.x, pt.x)
			max_v.y = maxf(max_v.y, pt.y)
		return Rect2(min_v, max_v - min_v)
	var br := _get_board_rect()
	var cw := br.size.x / float(grid_cols)
	var ch := br.size.y / float(grid_rows)
	return Rect2(br.position + Vector2(float(c.x) * cw, float(c.y) * ch), Vector2(cw, ch))

func _cell_center(pos_grid: Vector2) -> Vector2:
	var wx := (pos_grid.x + 0.5) / float(grid_cols) * (StrategicGridSolver.WORLD_HALF_X * 2.0) - StrategicGridSolver.WORLD_HALF_X
	var wz := (pos_grid.y + 0.5) / float(grid_rows) * (StrategicGridSolver.WORLD_HALF_Z * 2.0) - StrategicGridSolver.WORLD_HALF_Z
	return _world_to_canvas(Vector3(wx, 0.0, wz))

func _canvas_to_grid_cell(mpos: Vector2) -> Vector2i:
	if _has_active_3d_projection():
		var cam := get_viewport().get_camera_3d()
		var screen_pt := _board_canvas.get_global_transform_with_canvas() * mpos
		var ray_origin := cam.project_ray_origin(screen_pt)
		var ray_dir := cam.project_ray_normal(screen_pt)
		if absf(ray_dir.y) > 0.001:
			var t := -ray_origin.y / ray_dir.y
			if t > 0.0:
				var hit_3d := ray_origin + ray_dir * t
				if absf(hit_3d.x) <= StrategicGridSolver.WORLD_HALF_X * 1.15 and absf(hit_3d.z) <= StrategicGridSolver.WORLD_HALF_Z * 1.15:
					return StrategicGridSolver.world_to_cell(hit_3d, true, 0, grid_cols, grid_rows)
		return Vector2i(-1, -1)

	var br := _get_board_rect()
	if not br.has_point(mpos):
		return Vector2i(-1, -1)
	var cw := br.size.x / float(grid_cols)
	var ch := br.size.y / float(grid_rows)
	return Vector2i(
		clampi(int((mpos.x - br.position.x) / cw), 0, grid_cols - 1),
		clampi(int((mpos.y - br.position.y) / ch), 0, grid_rows - 1)
	)

func _on_board_gui_input(event: InputEvent) -> void:
	if is_animating_turn:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos: Vector2 = event.position
		var clicked_cell := _canvas_to_grid_cell(mpos)
		if clicked_cell.x < 0 or clicked_cell.y < 0:
			return

		# 1. DIRECT SHIP SELECTION (for switching to another allied division):
		var clicked_ship_idx := -1
		var cam := get_viewport().get_camera_3d() if is_inside_tree() and get_viewport() != null else null
		var global_mouse := get_viewport().get_mouse_position() if is_inside_tree() and get_viewport() != null else mpos

		if cam != null:
			for i in range(mini(3, player_ships.size())):
				var s := player_ships[i]
				if s == null or s.is_destroyed():
					continue
				var s_screen := cam.unproject_position(s.global_position)
				if global_mouse.distance_to(s_screen) <= 46.0:
					clicked_ship_idx = i
					break

		if clicked_ship_idx == -1:
			for i in range(3):
				if clicked_cell == _p_cells[i]:
					clicked_ship_idx = i
					break

		if clicked_ship_idx == -1:
			for i in range(3):
				if i != selected_unit_idx and clicked_cell == _p_targets[i]:
					clicked_ship_idx = i
					break

		# If clicking a DIFFERENT allied division, select that division!
		# If clicking the ALREADY selected division's current cell, fall through to set [HOLD / OVERWATCH]!
		if clicked_ship_idx != -1 and clicked_ship_idx != selected_unit_idx:
			AudioManager.play_sfx("ui_click", -8.0)
			selected_unit_idx = clicked_ship_idx
			ship_selected_on_chart.emit(clicked_ship_idx)
			_refresh_ui()
			return

		# 2. MOVEMENT WAYPOINT OR OVERWATCH PLANNING
		var cur := _p_cells[selected_unit_idx]
		var delta_c := clicked_cell - cur
		var in_stream: bool = (_sector_types.get(cur, "") == "wind_stream")
		var is_wedge := (current_formation == Formation.SPEARHEAD_WEDGE)
		var max_step := 2 if (in_stream or is_wedge) else 1
		var clamped_target := Vector2i(
			clampi(cur.x + clampi(delta_c.x, -max_step, max_step), 0, grid_cols - 1),
			clampi(cur.y + clampi(delta_c.y, -max_step, max_step), 0, grid_rows - 1)
		)

		if move_whole_fleet:
			var step := clamped_target - cur
			for i in range(3):
				var t := Vector2i(
					clampi(_p_cells[i].x + step.x, 0, grid_cols - 1),
					clampi(_p_cells[i].y + step.y, 0, grid_rows - 1)
				)
				_p_targets[i] = t
				var dv := Vector2(t - _p_cells[i])
				if dv.length_squared() > 0.01:
					_p_facing[i] = dv.normalized()
		else:
			_p_targets[selected_unit_idx] = clamped_target
			var dv := Vector2(clamped_target - cur)
			if dv.length_squared() > 0.01:
				_p_facing[selected_unit_idx] = dv.normalized()

		_sync_3d_ships_to_chart_positions()
		AudioManager.play_sfx("ui_hover", -6.0)
		_refresh_ui()

func execute_strategic_turn() -> void:
	if is_animating_turn:
		return
	is_animating_turn = true
	AudioManager.play_sfx("engine", -8.0)

	var tw := create_tween()
	tw.set_parallel(true)
	for i in range(3):
		var p_dest := Vector2(_p_targets[i].x, _p_targets[i].y)
		var e_dest := Vector2(_e_targets[i].x, _e_targets[i].y)
		var idx := i
		tw.tween_method(func(v: Vector2) -> void:
			_p_anim_pos[idx] = v
			_sync_3d_ships_to_chart_positions()
		, _p_anim_pos[i], p_dest, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: Vector2) -> void:
			_e_anim_pos[idx] = v
			_sync_3d_ships_to_chart_positions()
		, _e_anim_pos[i], e_dest, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(_on_strategic_turn_anim_done)

func _on_strategic_turn_anim_done() -> void:
	is_animating_turn = false
	for i in range(3):
		_p_cells[i] = _p_targets[i]
		_e_cells[i] = _e_targets[i]
		_p_anim_pos[i] = Vector2(_p_cells[i].x, _p_cells[i].y)
		_e_anim_pos[i] = Vector2(_e_cells[i].x, _e_cells[i].y)

	_sync_3d_ships_to_chart_positions()

	var min_cell_dist := 99.0
	for p in _p_cells:
		for e in _e_cells:
			min_cell_dist = minf(min_cell_dist, Vector2(p - e).length())

	var contact := (min_cell_dist <= 1.2) or (strategic_turn >= MAX_STRATEGIC_TURNS)
	var b := compute_strategic_bonuses()

	var p_spawns: Array[Dictionary] = []
	for idx in range(maxi(3, player_ships.size())):
		var div_idx: int = idx % 3
		p_spawns.append(_cell_to_world(_p_cells[div_idx], _p_facing[div_idx], true, idx))
	var e_spawns: Array[Dictionary] = []
	for idx in range(maxi(3, enemy_ships.size())):
		var div_idx: int = idx % 3
		e_spawns.append(_cell_to_world(_e_cells[div_idx], _e_facing[div_idx], false, idx))

	var log_msg := "Maneuver Turn %d resolved: Fleets closing (Dist %.1fm). Barlovento: %s" % [
		strategic_turn,
		min_cell_dist * 15.0,
		"SECURED (+1 AP)" if b["has_barlovento"] else "CONTESTED"
	]
	turn_executed.emit(log_msg, contact, p_spawns, e_spawns)

	if contact:
		_trigger_3d_engagement()
	else:
		strategic_turn += 1
		if strategic_turn >= 2:
			for p in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(7, 0), Vector2i(7, 1), Vector2i(0, 2), Vector2i(9, 2)]:
				if p.x < grid_cols and p.y < grid_rows:
					_sector_types[p] = "calm"
		if strategic_turn >= 4:
			for p in [Vector2i(3, 0), Vector2i(6, 0), Vector2i(1, 2), Vector2i(8, 2), Vector2i(0, 6), Vector2i(9, 6)]:
				if p.x < grid_cols and p.y < grid_rows:
					_sector_types[p] = "calm"
		_plan_initial_orders()
		_sync_3d_ships_to_chart_positions()
		_refresh_ui()

func _trigger_3d_engagement() -> void:
	if is_animating_turn:
		return
	AudioManager.play_sfx("ui_click", -6.0)
	var bonuses := compute_strategic_bonuses()
	for i in range(3):
		_p_targets[i] = _p_cells[i]
	_sync_3d_ships_to_chart_positions()

	var p_spawns: Array[Dictionary] = []
	for idx in range(maxi(3, player_ships.size())):
		var div_idx: int = idx % 3
		p_spawns.append(_cell_to_world(_p_cells[div_idx], _p_facing[div_idx], true, idx))

	var e_spawns: Array[Dictionary] = []
	for idx in range(maxi(3, enemy_ships.size())):
		var div_idx: int = idx % 3
		var ef := _e_facing[div_idx]
		if bonuses["is_crossing_t"] or bonuses["is_flanking"]:
			ef = Vector2(1.0, 0.25).normalized()
		e_spawns.append(_cell_to_world(_e_cells[div_idx], ef, false, idx))

	bonuses["player_spawns"] = p_spawns
	bonuses["enemy_spawns"] = e_spawns

	engage_3d_requested.emit(bonuses)

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.55)
	tw.tween_callback(func() -> void:
		visible = false
		modulate.a = 1.0
	)

func _draw_corner_brackets(c: Control, r: Rect2, col: Color, b_len: float, width: float) -> void:
	c.draw_line(r.position, r.position + Vector2(b_len, 0), col, width)
	c.draw_line(r.position, r.position + Vector2(0, b_len), col, width)
	c.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - b_len, r.position.y), col, width)
	c.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + b_len), col, width)
	c.draw_line(r.end, r.end - Vector2(b_len, 0), col, width)
	c.draw_line(r.end, r.end - Vector2(0, b_len), col, width)
	c.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x + b_len, r.end.y), col, width)
	c.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - b_len), col, width)

func _draw_quad_outline(c: Control, quad: PackedVector2Array, col: Color, width: float) -> void:
	if quad.size() < 4:
		return
	var closed := PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]])
	c.draw_polyline(closed, col, width, true)

func _draw_naval_chart() -> void:
	var c := _board_canvas
	var font := ThemeDB.fallback_font
	var cur_sel_cell := _p_cells[selected_unit_idx]

	# 1. Draw 3D-Projected Strategic Quadrants Directly on the Star Sea Plane
	var cols_lbl := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P"]
	for gx in range(grid_cols):
		for gy in range(grid_rows):
			var cell := Vector2i(gx, gy)
			var quad := _cell_quad_canvas(cell, 0.95)
			var r := _cell_rect(cell)
			var stype: String = _sector_types.get(cell, "open")

			var fill_col := Color(0.012, 0.028, 0.055, 0.14)
			var border_col := Color(0.22, 0.65, 0.90, 0.22)
			var icon_txt := ""
			var icon_col := Color(0.45, 0.75, 0.95, 0.65)

			if stype == "wind_stream":
				fill_col = Color(0.02, 0.16, 0.28, 0.20)
				border_col = Color(0.25, 0.88, 1.0, 0.36)
				icon_txt = "ÉTHER"
				icon_col = Color(0.35, 0.95, 1.0, 0.80)
			elif stype == "reef":
				fill_col = Color(0.06, 0.04, 0.02, 0.20)
				border_col = Color(0.85, 0.58, 0.22, 0.30)
				icon_txt = "REEF"
				icon_col = Color(0.95, 0.72, 0.35, 0.80)
			elif stype == "sluice":
				fill_col = Color(0.10, 0.07, 0.02, 0.25)
				border_col = Color(1.0, 0.75, 0.22, 0.45)
				icon_txt = "SLUICE"
				icon_col = Color(1.0, 0.82, 0.30, 0.88)
			elif stype == "conduit":
				fill_col = Color(0.04, 0.14, 0.18, 0.22)
				border_col = Color(0.35, 0.95, 0.72, 0.42)
				icon_txt = "NODE"
				icon_col = Color(0.40, 1.0, 0.80, 0.85)
			elif stype == "spire":
				fill_col = Color(0.12, 0.08, 0.22, 0.25)
				border_col = Color(0.75, 0.45, 1.0, 0.45)
				icon_txt = "SPIRE"
				icon_col = Color(0.85, 0.55, 1.0, 0.90)
			elif stype == "ring":
				fill_col = Color(0.08, 0.16, 0.28, 0.35)
				border_col = Color(0.35, 0.95, 1.0, 0.55)
				icon_txt = "GENESIS"
				icon_col = Color(0.45, 1.0, 0.90, 0.95)
			elif stype == "maelstrom":
				fill_col = Color(0.05, 0.20, 0.30, 0.30)
				border_col = Color(0.20, 0.90, 1.0, 0.50)
				icon_txt = "VORTEX"
				icon_col = Color(0.30, 1.0, 0.95, 0.95)
			elif stype == "calm":
				fill_col = Color(0.12, 0.02, 0.16, 0.45)
				border_col = Color(0.85, 0.25, 0.95, 0.65)
				icon_txt = "CALMA"
				icon_col = Color(0.95, 0.40, 1.0, 0.90)

			var in_stream: bool = (_sector_types.get(cur_sel_cell, "") == "wind_stream")
			var is_wedge := (current_formation == Formation.SPEARHEAD_WEDGE)
			var max_step := 2 if (in_stream or is_wedge) else 1
			var is_reachable := (absi(gx - cur_sel_cell.x) <= max_step and absi(gy - cur_sel_cell.y) <= max_step)
			if is_reachable and not is_animating_turn:
				fill_col = fill_col.blend(Color(0.22, 0.85, 1.0, 0.08))
				border_col = Color(0.35, 0.90, 1.0, 0.48)

			c.draw_colored_polygon(quad, fill_col)
			_draw_quad_outline(c, quad, border_col, 1.1)

			var coord_str := "%s%d" % [cols_lbl[gx], gy + 1]
			c.draw_string(font, quad[0] + Vector2(6, 13), coord_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.60, 0.82, 0.98, 0.65))

			if icon_txt != "":
				c.draw_string(font, quad[1] + Vector2(-42, 13), icon_txt, HORIZONTAL_ALIGNMENT_RIGHT, 38, 8, icon_col)

	# 2. ALL ALLIED DIVISIONS' START & TARGET 3D QUADRANTS
	for i in range(3):
		if i < player_ships.size() and player_ships[i] != null and player_ships[i].is_destroyed():
			continue

		var u_col: Color = UNIT_COLORS[i]
		var p_cur := _p_cells[i]
		var p_tgt := _p_targets[i]
		var is_selected := (i == selected_unit_idx)

		if p_cur != p_tgt:
			var cur_quad := _cell_quad_canvas(p_cur, 0.90)
			var cur_border := u_col * Color(1.0, 1.0, 1.0, 0.65 if is_selected else 0.40)
			_draw_quad_outline(c, cur_quad, cur_border, 1.4)
			c.draw_string(font, cur_quad[0] + Vector2(6, 14 + i * 11), "U%d NOW" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cur_border)

		var tgt_quad := _cell_quad_canvas(p_tgt, 0.92)
		var fill_alpha := 0.24 if is_selected else 0.14
		var line_w := 2.6 if is_selected else 1.8
		c.draw_colored_polygon(tgt_quad, Color(u_col.r, u_col.g, u_col.b, fill_alpha))
		_draw_quad_outline(c, tgt_quad, u_col if is_selected else u_col * Color(1.0, 1.0, 1.0, 0.85), line_w)

		var s_name := "U%d" % (i + 1)
		if i < player_ships.size() and player_ships[i] != null:
			s_name = player_ships[i].ship_name
		var action_txt := ("★ U%d: %s" % [i + 1, s_name]) if is_selected else ("▶ U%d: %s" % [i + 1, s_name])
		if p_tgt == p_cur:
			action_txt += " [⚓ OVERWATCH +15% HIT]"
		else:
			action_txt += " [TARGET]"

		c.draw_string(font, tgt_quad[3] + Vector2(6, -6 - i * 11), action_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9 if is_selected else 8, u_col if is_selected else u_col * Color(1.0, 1.0, 1.0, 0.95))

	# 3. DRAW FLEET ARRIVAL FORMATION GEOMETRY
	var t0 := _cell_center(Vector2(_p_targets[0]))
	var t1 := _cell_center(Vector2(_p_targets[1]))
	var t2 := _cell_center(Vector2(_p_targets[2]))
	var form_line_col := Color(0.35, 0.92, 1.0, 0.45)
	c.draw_line(t1, t0, form_line_col, 1.8, true)
	c.draw_line(t0, t2, form_line_col, 1.8, true)

	# 4. Draw Planned Movement Vectors Directly From 3D Ship Position to Target Quadrant
	for i in range(3):
		var p_from := _cell_center(_p_anim_pos[i])
		var p_to := _cell_center(Vector2(_p_targets[i]))
		var is_selected := (i == selected_unit_idx)
		var u_col: Color = UNIT_COLORS[i]
		var vec_col := u_col if is_selected else u_col * Color(1.0, 1.0, 1.0, 0.70)
		c.draw_line(p_from, p_to, vec_col, 2.4 if is_selected else 1.5)
		var cross_sz := 5.5 if is_selected else 3.8
		c.draw_line(p_to - Vector2(cross_sz, 0), p_to + Vector2(cross_sz, 0), vec_col, 1.6)
		c.draw_line(p_to - Vector2(0, cross_sz), p_to + Vector2(0, cross_sz), vec_col, 1.6)

	# 5. Draw Hostile Ships Anchored Over Their 3D Hulls
	for i in range(3):
		if i < enemy_ships.size() and enemy_ships[i] != null and enemy_ships[i].is_destroyed():
			continue
		var e_pos := _cell_center(_e_anim_pos[i])
		var ef := _e_facing[i].normalized()
		var e_col := Color(1.0, 0.38, 0.30, 0.92)
		var e_quad := _cell_quad_canvas(_e_cells[i], 0.90)
		_draw_quad_outline(c, e_quad, Color(1.0, 0.32, 0.25, 0.45), 1.4)

		var pts: PackedVector2Array = [
			e_pos + Vector2(0, -10),
			e_pos + Vector2(10, 0),
			e_pos + Vector2(0, 10),
			e_pos + Vector2(-10, 0)
		]
		c.draw_polyline(pts, e_col, 1.6)
		c.draw_line(pts[3], pts[0], e_col, 1.6)
		c.draw_line(e_pos, e_pos + ef * 13.0, Color(1.0, 0.65, 0.35), 1.8)

		var e_name := "HOSTILE"
		if i < enemy_ships.size() and enemy_ships[i] != null:
			e_name = enemy_ships[i].ship_name
		c.draw_string(font, e_pos + Vector2(-42, -13), e_name, HORIZONTAL_ALIGNMENT_CENTER, 84, 9, Color(1.0, 0.78, 0.78))

	# 6. Draw Allied Ship Brackets Anchored Directly Over Their 3D Hulls
	for i in range(3):
		if i < player_ships.size() and player_ships[i] != null and player_ships[i].is_destroyed():
			continue
		var p_pos := _cell_center(_p_anim_pos[i])
		var is_sel := (i == selected_unit_idx)
		var u_col: Color = UNIT_COLORS[i]

		var sel_box := Rect2(p_pos - Vector2(20, 15), Vector2(40, 30))
		_draw_corner_brackets(c, sel_box, u_col if is_sel else u_col * Color(1.0, 1.0, 1.0, 0.65), 6.0 if is_sel else 4.0, 2.0 if is_sel else 1.3)

		var u_lbl := "U%d: %s" % [i + 1, player_ships[i].ship_name if i < player_ships.size() else ""]
		c.draw_string(font, p_pos + Vector2(-52, 24), u_lbl, HORIZONTAL_ALIGNMENT_CENTER, 104, 9, u_col if is_sel else Color(0.88, 0.94, 1.0, 0.90))
