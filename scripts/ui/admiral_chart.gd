class_name AdmiralChart
extends Control

signal turn_executed(summary_log: String, contact_reached: bool, p_spawns: Array, e_spawns: Array)
signal engage_3d_requested(strategic_result: Dictionary)
signal ship_selected_on_chart(ship_index: int)
signal open_roster_requested
signal return_menu_requested

const GRID_COLS := 8
const GRID_ROWS := 6
const MAX_STRATEGIC_TURNS := 5

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

# 8x6 Grid Coordinates (Vector2i) and continuous animated positions (Vector2)
var _p_cells: Array[Vector2i] = [Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]
var _p_targets: Array[Vector2i] = [Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4)]
var _p_anim_pos: Array[Vector2] = [Vector2(3, 5), Vector2(4, 5), Vector2(5, 5)]
var _p_facing: Array[Vector2] = [Vector2(0, -1), Vector2(0, -1), Vector2(0, -1)]

var _e_cells: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(2, 0)]
var _e_targets: Array[Vector2i] = [Vector2i(3, 1), Vector2i(4, 1), Vector2i(2, 1)]
var _e_anim_pos: Array[Vector2] = [Vector2(3, 0), Vector2(4, 0), Vector2(2, 0)]
var _e_facing: Array[Vector2] = [Vector2(0, 1), Vector2(0, 1), Vector2(0, 1)]

# Special terrain sectors on the 8x6 naval chart
# "wind_stream" = Upwind Ether Current (+Barlovento), "reef" = Basalt Reef (+Cover), "sluice" = Sluice Station / Objective
# "conduit" = Éther Booster Node
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
	_init_sector_terrain()
	_build_ui()
	_plan_initial_orders()
	_refresh_ui()

func _process(delta: float) -> void:
	_anim_t += delta
	if _board_canvas != null and visible:
		_board_canvas.queue_redraw()

func sync_from_3d_ships(p_ships: Array[Ship], e_ships: Array[Ship], ether_field: EtherField) -> void:
	player_ships = p_ships
	enemy_ships = e_ships
	if ether_field != null:
		var d3 := ether_field.direction
		var w2 := Vector2(d3.x, d3.z)
		if w2.length_squared() > 0.01:
			wind_dir = w2.normalized()

	for i in range(mini(3, player_ships.size())):
		var c := _world_to_cell(player_ships[i].state.position, true, i)
		_p_cells[i] = c
		_p_anim_pos[i] = Vector2(c.x, c.y)
		_p_facing[i] = Vector2(0, -1)
	for i in range(mini(3, enemy_ships.size())):
		var c := _world_to_cell(enemy_ships[i].state.position, false, i)
		_e_cells[i] = c
		_e_anim_pos[i] = Vector2(c.x, c.y)
		_e_facing[i] = Vector2(0, 1)

	_plan_initial_orders()
	_refresh_ui()

func set_selected_unit(idx: int) -> void:
	if idx >= 0 and idx < 3:
		selected_unit_idx = idx
		_refresh_ui()

func _world_to_cell(pos: Vector3, _is_player: bool, _idx: int) -> Vector2i:
	var cx := clampi(roundi(remap(pos.x, -45.0, 45.0, 0.0, float(GRID_COLS - 1))), 0, GRID_COLS - 1)
	var cy := clampi(roundi(remap(pos.z, -42.0, 42.0, 0.0, float(GRID_ROWS - 1))), 0, GRID_ROWS - 1)
	return Vector2i(cx, cy)

func _cell_to_world(cell: Vector2i, facing: Vector2, is_player: bool, idx: int) -> Dictionary:
	var wx := remap(float(cell.x), 0.0, float(GRID_COLS - 1), -45.0, 45.0)
	var wz := remap(float(cell.y), 0.0, float(GRID_ROWS - 1), -42.0, 42.0)
	var wy := 5.0 if idx == 0 else (2.0 if idx == 1 else 7.5)

	if is_player:
		match current_formation:
			Formation.LINE_OF_BATTLE:
				wx += float(idx - 1) * 4.0
			Formation.SPEARHEAD_WEDGE:
				if idx == 0:
					wz -= 4.5
				else:
					wz += 3.0
			Formation.FLANKING_PINCER:
				if idx == 1:
					wx -= 7.5
				elif idx == 2:
					wx += 7.5

	var fwd3 := Vector3(facing.x, 0.0, facing.y)
	if fwd3.length_squared() < 0.01:
		fwd3 = Vector3(0, 0, -1) if is_player else Vector3(0, 0, 1)
	else:
		fwd3 = fwd3.normalized()

	return {
		"pos": Vector3(wx, wy, wz),
		"fwd": fwd3
	}

func _init_sector_terrain() -> void:
	_sector_types.clear()
	# Upwind Ether Stream corridor (grants Barlovento Weather-Gauge across central rows 2 & 3)
	for x in range(1, 7):
		_sector_types[Vector2i(x, 2)] = "wind_stream"
		_sector_types[Vector2i(x, 3)] = "wind_stream"

	# Basalt Asteroid Reefs along flank lanes (grants Flank Cover & Ambush)
	for y in range(1, 5):
		_sector_types[Vector2i(0, y)] = "reef"
		_sector_types[Vector2i(7, y)] = "reef"

	# Sluice Station Well-09 Anchor & Defense Node (Rows 4, Cols 3 & 4)
	_sector_types[Vector2i(3, 4)] = "sluice"
	_sector_types[Vector2i(4, 4)] = "sluice"

	# Éther Conduit Relays (Capture nodes for speed boost)
	_sector_types[Vector2i(2, 2)] = "conduit"
	_sector_types[Vector2i(5, 3)] = "conduit"

	# The encroaching Calm front along northern row 0 (Dead zone hazard: -50% SPD & Shield decay)
	for x in range(GRID_COLS):
		_sector_types[Vector2i(x, 0)] = "calm"

func _plan_initial_orders() -> void:
	for i in range(3):
		var cur := _p_cells[i]
		var next_y := maxi(cur.y - 1, 0)
		var next_x := cur.x
		if current_formation == Formation.FLANKING_PINCER:
			if i == 1:
				next_x = maxi(cur.x - 1, 0)
			elif i == 2:
				next_x = mini(cur.x + 1, GRID_COLS - 1)
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
			for oy in range(0, 2):
				var cand := Vector2i(clampi(cur.x + ox, 0, GRID_COLS - 1), clampi(cur.y + oy, 0, GRID_ROWS - 1))
				if claimed.has(cand):
					continue
				var score := -Vector2(cand - target_p).length()
				if _sector_types.get(cand, "") == "wind_stream":
					score += 3.2
				if _sector_types.get(cand, "") == "reef":
					score += 0.8
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
			var target_row := maxi(center_c.y - 1, 1)
			_p_targets[0] = Vector2i(3, target_row)
			_p_targets[1] = Vector2i(2, target_row)
			_p_targets[2] = Vector2i(4, target_row)
		Formation.SPEARHEAD_WEDGE:
			var lead_row := maxi(center_c.y - 2, 1)
			_p_targets[0] = Vector2i(3, lead_row)
			_p_targets[1] = Vector2i(2, mini(lead_row + 1, GRID_ROWS - 1))
			_p_targets[2] = Vector2i(4, mini(lead_row + 1, GRID_ROWS - 1))
		Formation.FLANKING_PINCER:
			var pincer_row := maxi(center_c.y - 1, 1)
			_p_targets[0] = Vector2i(3, pincer_row)
			_p_targets[1] = Vector2i(1, maxi(pincer_row - 1, 0))
			_p_targets[2] = Vector2i(6, maxi(pincer_row - 1, 0))

	for i in range(3):
		var dv := Vector2(_p_targets[i] - _p_cells[i])
		if dv.length_squared() > 0.01:
			_p_facing[i] = dv.normalized()

func compute_strategic_bonuses() -> Dictionary:
	var wind_cells_held := 0
	var sluice_held := 0
	var conduit_held := 0
	for i in range(3):
		var c := _p_targets[i] if not is_animating_turn else _p_cells[i]
		var stype: String = _sector_types.get(c, "")
		if stype == "wind_stream":
			wind_cells_held += 1
		elif stype == "sluice":
			sluice_held += 1
		elif stype == "conduit":
			conduit_held += 1

	var enemy_wind_cells := 0
	for i in range(3):
		if i < enemy_ships.size() and enemy_ships[i] != null and enemy_ships[i].is_destroyed():
			continue
		if _sector_types.get(_e_cells[i], "") == "wind_stream":
			enemy_wind_cells += 1

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

	return {
		"has_barlovento": has_barlovento,
		"enemy_barlovento": enemy_barlovento,
		"enemy_wind_cells": enemy_wind_cells,
		"wind_cells_held": wind_cells_held,
		"sluice_held": sluice_held > 0,
		"conduit_held": conduit_held > 0,
		"calm_hazard_count": calm_hazard_count,
		"is_flanking": is_flanking,
		"is_crossing_t": is_crossing_t,
		"formation": current_formation,
		"bonus_ap": 1 if has_barlovento else 0,
		"accuracy_bonus": 0.15 if has_barlovento else 0.0,
		"damage_bonus": 0.15 if (has_barlovento or is_crossing_t) else 0.0,
		"armor_mult": 1.20 if current_formation == Formation.LINE_OF_BATTLE else 1.0,
		"speed_mult": 1.25 if current_formation == Formation.SPEARHEAD_WEDGE else (1.12 if has_barlovento else 1.0),
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
		var alert_tag := " [DECISIVE ENGAGEMENT]" if dist_meters <= 36.0 else (" [MID THEATER]" if dist_meters <= 60.0 else " [OUTER APPROACH]")
		_range_telemetry_lbl.text = "FLEET SEPARATION: %.1fm%s" % [dist_meters, alert_tag]
		_range_telemetry_lbl.modulate = Color(1.0, 0.45, 0.35) if dist_meters <= 36.0 else Color(1.0, 0.85, 0.35)

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
		btn.text = "%s%s: %s\n   [%s → %s]" % [sel_mark, u_name, p_name, _cell_name(c), _cell_name(t)]
		btn.modulate = u_col if is_sel else u_col * Color(1.0, 1.0, 1.0, 0.60)

	for i in range(_form_btns.size()):
		var active := (int(current_formation) == i)
		_form_btns[i].modulate = Color(1.0, 0.92, 0.45) if active else Color(0.80, 0.86, 0.95)

	var b := compute_strategic_bonuses()
	if _adv_weather_lbl != null:
		if b["has_barlovento"]:
			_adv_weather_lbl.text = "🌬 BARLOVENTO: SECURED (%d Stream Sectors)\n   → +1 Bonus AP, +15%% Hit & +15%% DMG in Ace Phase!" % b["wind_cells_held"]
			_adv_weather_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72))
		elif b["enemy_barlovento"]:
			_adv_weather_lbl.text = "🌬 BARLOVENTO: HELD BY HOSTILES (%d vs %d Sectors)\n   → Enemy holds the upwind current! Contest the stream!" % [b["enemy_wind_cells"], b["wind_cells_held"]]
			_adv_weather_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
		else:
			_adv_weather_lbl.text = "🌬 BARLOVENTO: CONTESTED ZONE\n   → Hold more central Éther sectors than hostiles to claim +1 AP."
			_adv_weather_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))

	if _adv_flank_lbl != null:
		if b["is_crossing_t"]:
			_adv_flank_lbl.text = "🎯 VECTOR: CROSSING THE 'T' (+30% Broadside Salvo DMG)!"
			_adv_flank_lbl.add_theme_color_override("font_color", Color(0.40, 0.96, 1.0))
		elif b["is_flanking"]:
			_adv_flank_lbl.text = "🎯 VECTOR: ENVELOPING PINCER (+35% Ambush Crit Chance)!"
			_adv_flank_lbl.add_theme_color_override("font_color", Color(0.40, 0.96, 1.0))
		else:
			_adv_flank_lbl.text = "🎯 VECTOR: FRONTAL APPROACH (Standard arcs)"
			_adv_flank_lbl.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95))

	if _adv_nodes_lbl != null:
		var n_txt := ""
		if b["calm_hazard_count"] > 0:
			n_txt += "⚠ CALM HAZARD: %d ship(s) target dead zone (-50%% SPD, Shield decay)!\n" % b["calm_hazard_count"]
		if b["sluice_held"]:
			n_txt += "⚙ SLUICE REFINERY: DEFENDED (+20 Shield HP Regen)\n"
		if b["conduit_held"]:
			n_txt += "⚡ ÉTHER CONDUIT: SECURED (+25% Engine Speed)\n"
		if n_txt == "":
			n_txt = "⚙ STRATEGIC NODES: UNCONTESTED (Approach D5/E5 or C3)"
		_adv_nodes_lbl.text = n_txt
		_adv_nodes_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.85) if b["calm_hazard_count"] > 0 else Color(0.45, 0.95, 0.75))

	if _adv_form_lbl != null:
		match current_formation:
			Formation.LINE_OF_BATTLE:
				_adv_form_lbl.text = "🛡 DOCTRINE: LINE OF BATTLE (+20% Fleet Armor)"
			Formation.SPEARHEAD_WEDGE:
				_adv_form_lbl.text = "⚡ DOCTRINE: SPEARHEAD WEDGE (+25% Speed & Range)"
			Formation.FLANKING_PINCER:
				_adv_form_lbl.text = "🎯 DOCTRINE: FLANKING PINCER (+15% Turn & Ambush)"
		_adv_form_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))

	if _board_canvas != null:
		_board_canvas.queue_redraw()

func _cell_name(c: Vector2i) -> String:
	var cols := ["A", "B", "C", "D", "E", "F", "G", "H"]
	var col_s: String = cols[clampi(c.x, 0, cols.size() - 1)]
	return "%s%d" % [col_s, c.y + 1]

func _get_board_rect() -> Rect2:
	var sz := _board_canvas.size
	var pad_x := 18.0
	var pad_y := 12.0
	return Rect2(Vector2(pad_x, pad_y), Vector2(maxf(sz.x - pad_x * 2.0, 100.0), maxf(sz.y - pad_y * 2.0, 100.0)))

func _cell_rect(c: Vector2i) -> Rect2:
	var br := _get_board_rect()
	var cw := br.size.x / float(GRID_COLS)
	var ch := br.size.y / float(GRID_ROWS)
	return Rect2(br.position + Vector2(float(c.x) * cw, float(c.y) * ch), Vector2(cw, ch))

func _cell_center(pos_grid: Vector2) -> Vector2:
	var br := _get_board_rect()
	var cw := br.size.x / float(GRID_COLS)
	var ch := br.size.y / float(GRID_ROWS)
	return br.position + Vector2((pos_grid.x + 0.5) * cw, (pos_grid.y + 0.5) * ch)

func _on_board_gui_input(event: InputEvent) -> void:
	if is_animating_turn:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos: Vector2 = event.position
		var br := _get_board_rect()
		if not br.has_point(mpos):
			return
		var cw := br.size.x / float(GRID_COLS)
		var ch := br.size.y / float(GRID_ROWS)
		var clicked_cell := Vector2i(
			clampi(int((mpos.x - br.position.x) / cw), 0, GRID_COLS - 1),
			clampi(int((mpos.y - br.position.y) / ch), 0, GRID_ROWS - 1)
		)

		# 1. DIRECT SHIP SELECTION:
		# Check if the click is directly on any allied ship (3D model in space, current quadrant, or destination quadrant)
		var clicked_ship_idx := -1
		var cam := get_viewport().get_camera_3d()
		var global_mouse := get_viewport().get_mouse_position()

		# A. Direct click on the 3D ship model in space via camera projection
		if cam != null:
			for i in range(mini(3, player_ships.size())):
				var s := player_ships[i]
				if s == null or s.is_destroyed():
					continue
				var s_screen := cam.unproject_position(s.global_position)
				if global_mouse.distance_to(s_screen) <= 55.0:
					clicked_ship_idx = i
					break

		# B. Direct click on any ship's current grid cell
		if clicked_ship_idx == -1:
			for i in range(3):
				if clicked_cell == _p_cells[i]:
					clicked_ship_idx = i
					break

		# C. Direct click on any ship's selected destination quadrant
		if clicked_ship_idx == -1:
			for i in range(3):
				if i != selected_unit_idx and clicked_cell == _p_targets[i]:
					clicked_ship_idx = i
					break

		# D. Direct click on 2D animated ship token
		if clicked_ship_idx == -1:
			for i in range(3):
				var ship_2d := _cell_center(_p_anim_pos[i])
				if mpos.distance_to(ship_2d) <= minf(cw, ch) * 0.45:
					clicked_ship_idx = i
					break

		# If an allied ship was clicked, SELECT IT DIRECTLY!
		if clicked_ship_idx != -1:
			AudioManager.play_sfx("ui_click", -8.0)
			selected_unit_idx = clicked_ship_idx
			ship_selected_on_chart.emit(clicked_ship_idx)
			_refresh_ui()
			return

		# 2. MOVEMENT WAYPOINT PLANNING (only for empty or neutral quadrants)
		var cur := _p_cells[selected_unit_idx]
		var delta_c := clicked_cell - cur
		# Max 2 sectors move, or 3 if in the Éther Stream
		var max_step := 3 if _sector_types.get(cur, "") == "wind_stream" else 2
		var clamped_target := Vector2i(
			clampi(cur.x + clampi(delta_c.x, -max_step, max_step), 0, GRID_COLS - 1),
			clampi(cur.y + clampi(delta_c.y, -max_step, max_step), 0, GRID_ROWS - 1)
		)

		if move_whole_fleet:
			var step := clamped_target - cur
			for i in range(3):
				var t := Vector2i(
					clampi(_p_cells[i].x + step.x, 0, GRID_COLS - 1),
					clampi(_p_cells[i].y + step.y, 0, GRID_ROWS - 1)
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
		tw.tween_method(func(v: Vector2) -> void: _p_anim_pos[idx] = v, _p_anim_pos[i], p_dest, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: Vector2) -> void: _e_anim_pos[idx] = v, _e_anim_pos[i], e_dest, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(_on_strategic_turn_anim_done)

func _on_strategic_turn_anim_done() -> void:
	is_animating_turn = false
	for i in range(3):
		_p_cells[i] = _p_targets[i]
		_e_cells[i] = _e_targets[i]

	var min_cell_dist := 99.0
	for p in _p_cells:
		for e in _e_cells:
			min_cell_dist = minf(min_cell_dist, Vector2(p - e).length())

	var contact := (min_cell_dist <= 2.2) or (strategic_turn >= MAX_STRATEGIC_TURNS)
	var b := compute_strategic_bonuses()

	var p_spawns: Array[Dictionary] = []
	for i in range(3):
		p_spawns.append(_cell_to_world(_p_cells[i], _p_facing[i], true, i))
	var e_spawns: Array[Dictionary] = []
	for i in range(3):
		e_spawns.append(_cell_to_world(_e_cells[i], _e_facing[i], false, i))

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
			for x in range(GRID_COLS):
				_sector_types[Vector2i(x, 1)] = "calm"
		_plan_initial_orders()
		_refresh_ui()

func _trigger_3d_engagement() -> void:
	if is_animating_turn:
		return
	AudioManager.play_sfx("ui_click", -6.0)
	for i in range(3):
		_p_targets[i] = _p_cells[i]
	var bonuses := compute_strategic_bonuses()

	var p_spawns: Array[Dictionary] = []
	for i in range(3):
		p_spawns.append(_cell_to_world(_p_cells[i], _p_facing[i], true, i))

	var e_spawns: Array[Dictionary] = []
	for i in range(3):
		var ef := _e_facing[i]
		if bonuses["is_crossing_t"] or bonuses["is_flanking"]:
			ef = Vector2(1.0, 0.25).normalized()
		e_spawns.append(_cell_to_world(_e_cells[i], ef, false, i))

	bonuses["player_spawns"] = p_spawns
	bonuses["enemy_spawns"] = e_spawns

	# Immediate signal to initiate camera swoop and ace transition simultaneously with overlay fade
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

func _draw_naval_chart() -> void:
	var c := _board_canvas
	var font := ThemeDB.fallback_font
	var br := _get_board_rect()
	var cw := br.size.x / float(GRID_COLS)
	var ch := br.size.y / float(GRID_ROWS)

	var cur_sel_cell := _p_cells[selected_unit_idx]

	# 1. Draw 8x6 Strategic Quadrants (Clean, unsaturated, non-intrusive)
	var cols_lbl := ["A", "B", "C", "D", "E", "F", "G", "H"]
	for gx in range(GRID_COLS):
		for gy in range(GRID_ROWS):
			var cell := Vector2i(gx, gy)
			var r := _cell_rect(cell).grow(-2.0)
			var stype: String = _sector_types.get(cell, "open")

			var fill_col := Color(0.012, 0.028, 0.055, 0.12)
			var border_col := Color(0.22, 0.60, 0.85, 0.15)
			var icon_txt := ""
			var icon_col := Color(0.45, 0.75, 0.95, 0.60)

			if stype == "wind_stream":
				fill_col = Color(0.02, 0.14, 0.25, 0.18)
				border_col = Color(0.25, 0.85, 1.0, 0.28)
				icon_txt = "ÉTHER"
				icon_col = Color(0.35, 0.95, 1.0, 0.75)
			elif stype == "reef":
				fill_col = Color(0.06, 0.04, 0.02, 0.18)
				border_col = Color(0.85, 0.58, 0.22, 0.24)
				icon_txt = "REEF"
				icon_col = Color(0.95, 0.72, 0.35, 0.75)
			elif stype == "sluice":
				fill_col = Color(0.10, 0.07, 0.02, 0.25)
				border_col = Color(1.0, 0.75, 0.22, 0.45)
				icon_txt = "SLUICE"
				icon_col = Color(1.0, 0.82, 0.30, 0.88)
			elif stype == "conduit":
				fill_col = Color(0.04, 0.12, 0.16, 0.20)
				border_col = Color(0.35, 0.95, 0.72, 0.35)
				icon_txt = "NODE"
				icon_col = Color(0.40, 1.0, 0.80, 0.80)
			elif stype == "calm":
				fill_col = Color(0.12, 0.02, 0.16, 0.45)
				border_col = Color(0.85, 0.25, 0.95, 0.65)
				icon_txt = "CALMA"
				icon_col = Color(0.95, 0.40, 1.0, 0.90)

			# Reachable Quadrants for Selected Ship (subtle highlight)
			var max_step := 3 if _sector_types.get(cur_sel_cell, "") == "wind_stream" else 2
			var is_reachable := (absi(gx - cur_sel_cell.x) <= max_step and absi(gy - cur_sel_cell.y) <= max_step)
			if is_reachable and not is_animating_turn:
				fill_col = fill_col.blend(Color(0.20, 0.80, 1.0, 0.06))
				border_col = Color(0.30, 0.85, 1.0, 0.38)

			c.draw_rect(r, fill_col, true)
			c.draw_rect(r, border_col, false, 1.0)

			# Clean coordinate label in corner (A1..H6)
			var coord_str := "%s%d" % [cols_lbl[gx], gy + 1]
			c.draw_string(font, r.position + Vector2(6, 13), coord_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.78, 0.95, 0.55))

			# Clean subtle terrain tag in top-right corner
			if icon_txt != "":
				c.draw_string(font, r.position + Vector2(r.size.x - 38, 13), icon_txt, HORIZONTAL_ALIGNMENT_RIGHT, 32, 8, icon_col)

	# 2. ALL ALLIED SHIPS' TARGET & START QUADRANTS (Persistent for all ships at all times)
	for i in range(3):
		if i < player_ships.size() and player_ships[i] != null and player_ships[i].is_destroyed():
			continue

		var u_col: Color = UNIT_COLORS[i]
		var p_cur := _p_cells[i]
		var p_tgt := _p_targets[i]
		var is_selected := (i == selected_unit_idx)

		# A. START QUADRANT (Where unit is right now)
		if p_cur != p_tgt:
			var cur_r := _cell_rect(p_cur).grow(-3.0)
			var cur_border := u_col * Color(1.0, 1.0, 1.0, 0.60 if is_selected else 0.35)
			c.draw_rect(cur_r, cur_border, false, 1.2)
			_draw_corner_brackets(c, cur_r, cur_border, 5.0, 1.0)
			c.draw_string(font, cur_r.position + Vector2(6, 13 + i * 11), "U%d START" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, cur_border)

		# B. SELECTED DESTINATION QUADRANT (ALWAYS VISIBLE for all 3 ships!)
		var tgt_r := _cell_rect(p_tgt).grow(-2.0)
		var fill_alpha := 0.22 if is_selected else 0.12
		var line_w := 2.5 if is_selected else 1.8
		var brk_len := 11.0 if is_selected else 7.0

		c.draw_rect(tgt_r, Color(u_col.r, u_col.g, u_col.b, fill_alpha), true)
		c.draw_rect(tgt_r, u_col if is_selected else u_col * Color(1.0, 1.0, 1.0, 0.85), false, line_w)
		_draw_corner_brackets(c, tgt_r, u_col if is_selected else u_col * Color(1.0, 1.0, 1.0, 0.90), brk_len, line_w)

		var s_name := "U%d" % (i + 1)
		if i < player_ships.size() and player_ships[i] != null:
			s_name = player_ships[i].ship_name
		var action_txt := ("★ U%d: %s" % [i + 1, s_name]) if is_selected else ("▶ U%d: %s" % [i + 1, s_name])
		if p_tgt == p_cur:
			action_txt += " [HOLD]"
		else:
			action_txt += " [TARGET]"

		c.draw_string(font, tgt_r.position + Vector2(6, tgt_r.size.y - 6 - i * 11), action_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9 if is_selected else 8, u_col if is_selected else u_col * Color(1.0, 1.0, 1.0, 0.95))

	# 3. DRAW FLEET ARRIVAL FORMATION GEOMETRY (Line connecting all 3 arrival points)
	var t0 := _cell_center(Vector2(_p_targets[0]))
	var t1 := _cell_center(Vector2(_p_targets[1]))
	var t2 := _cell_center(Vector2(_p_targets[2]))
	var form_line_col := Color(0.35, 0.92, 1.0, 0.45)
	c.draw_line(t1, t0, form_line_col, 1.8, true)
	c.draw_line(t0, t2, form_line_col, 1.8, true)

	# 4. Draw Planned Movement Vectors for all units (NO CIRCLES!)
	for i in range(3):
		var p_from := _cell_center(_p_anim_pos[i])
		var p_to := _cell_center(Vector2(_p_targets[i]))
		var is_selected := (i == selected_unit_idx)
		var u_col: Color = UNIT_COLORS[i]
		var vec_col := u_col if is_selected else u_col * Color(1.0, 1.0, 1.0, 0.65)
		c.draw_line(p_from, p_to, vec_col, 2.2 if is_selected else 1.4)
		# Clean crosshair tick at destination (NO circles!)
		var cross_sz := 5.0 if is_selected else 3.5
		c.draw_line(p_to - Vector2(cross_sz, 0), p_to + Vector2(cross_sz, 0), vec_col, 1.5)
		c.draw_line(p_to - Vector2(0, cross_sz), p_to + Vector2(0, cross_sz), vec_col, 1.5)

	# 5. Draw Hostile Ships (Minimalist, sharp tactical markers)
	for i in range(3):
		if i < enemy_ships.size() and enemy_ships[i] != null and enemy_ships[i].is_destroyed():
			continue
		var e_pos := _cell_center(_e_anim_pos[i])
		var ef := _e_facing[i].normalized()
		var e_col := Color(1.0, 0.38, 0.30, 0.90)

		# Hostile Bracket Diamond
		var pts: PackedVector2Array = [
			e_pos + Vector2(0, -9),
			e_pos + Vector2(9, 0),
			e_pos + Vector2(0, 9),
			e_pos + Vector2(-9, 0)
		]
		c.draw_polyline(pts, e_col, 1.5)
		c.draw_line(pts[3], pts[0], e_col, 1.5)
		# Small heading pip
		c.draw_line(e_pos, e_pos + ef * 12.0, Color(1.0, 0.65, 0.35), 1.8)

		var e_name := "HOSTILE"
		if i < enemy_ships.size() and enemy_ships[i] != null:
			e_name = enemy_ships[i].ship_name
		c.draw_string(font, e_pos + Vector2(-36, -12), e_name, HORIZONTAL_ALIGNMENT_CENTER, 72, 8, Color(1.0, 0.75, 0.75))

	# 6. Draw Allied Ships (Overlaid directly over 3D ships: NO CIRCLES, NO ARROWS!)
	for i in range(3):
		if i < player_ships.size() and player_ships[i] != null and player_ships[i].is_destroyed():
			continue
		var p_pos := _cell_center(_p_anim_pos[i])
		var is_sel := (i == selected_unit_idx)
		var u_col: Color = UNIT_COLORS[i]

		# NO circles! NO arrows!
		# Only a sleek rectangular bracket around the ship's footprint when selected:
		if is_sel:
			var sel_box := Rect2(p_pos - Vector2(16, 12), Vector2(32, 24))
			_draw_corner_brackets(c, sel_box, u_col, 5.0, 1.5)

		# Unit Name label underneath
		var u_lbl := "U%d: %s" % [i + 1, player_ships[i].ship_name if i < player_ships.size() else ""]
		c.draw_string(font, p_pos + Vector2(-45, 17), u_lbl, HORIZONTAL_ALIGNMENT_CENTER, 90, 9, u_col if is_sel else Color(0.85, 0.92, 1.0, 0.85))
