class_name AdmiralChart
extends Control

signal turn_executed(summary_log: String, contact_reached: bool)
signal engage_3d_requested(strategic_result: Dictionary)
signal ship_selected_on_chart(ship_index: int)
signal open_roster_requested
signal return_menu_requested

const GRID_COLS := 6
const GRID_ROWS := 4
const MAX_STRATEGIC_TURNS := 3

enum Formation { LINE_OF_BATTLE, SPEARHEAD_WEDGE, FLANKING_PINCER }

var player_ships: Array[Ship] = []
var enemy_ships: Array[Ship] = []
var wind_dir: Vector2 = Vector2(1.0, -0.35).normalized()
var stage_title: String = "ACT I // STAGE 01: SLUICE STATION WELL-09"
var commander_name: String = "FLEET ADMIRAL VANE"
var commander_portrait: Texture2D = null

var strategic_turn: int = 1
var current_formation: Formation = Formation.LINE_OF_BATTLE
var selected_unit_idx: int = 0
var move_whole_fleet: bool = false
var is_animating_turn: bool = false

# 2D Grid Coordinates (Vector2i) and continuous animated positions (Vector2)
var _p_cells: Array[Vector2i] = [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]
var _p_targets: Array[Vector2i] = [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
var _p_anim_pos: Array[Vector2] = [Vector2(1, 3), Vector2(2, 3), Vector2(3, 3)]
var _p_facing: Array[Vector2] = [Vector2(0, -1), Vector2(0, -1), Vector2(0, -1)]

var _e_cells: Array[Vector2i] = [Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
var _e_targets: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
var _e_anim_pos: Array[Vector2] = [Vector2(2, 0), Vector2(3, 0), Vector2(4, 0)]
var _e_facing: Array[Vector2] = [Vector2(0, 1), Vector2(0, 1), Vector2(0, 1)]

# Special terrain sectors on the 6x4 naval chart
# "wind_stream" = Upwind Ether Current (+Barlovento), "reef" = Basalt Reef (+Cover), "sluice" = Sluice Station / Objective
var _sector_types: Dictionary = {}

var _board_canvas: Control
var _turn_lbl: Label
var _status_lbl: Label
var _adv_weather_lbl: Label
var _adv_flank_lbl: Label
var _adv_form_lbl: Label
var _unit_btns: Array[Button] = []
var _form_btns: Array[Button] = []
var _fleet_mode_btn: Button
var _step_turn_btn: Button
var _engage_btn: Button
var _anim_t: float = 0.0

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
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

func _world_to_cell(pos: Vector3, _is_player: bool, _idx: int) -> Vector2i:
    var cx := clampi(roundi(remap(pos.x, -38.0, 38.0, 0.0, float(GRID_COLS - 1))), 0, GRID_COLS - 1)
    var cy := clampi(roundi(remap(pos.z, -36.0, 36.0, 0.0, float(GRID_ROWS - 1))), 0, GRID_ROWS - 1)
    return Vector2i(cx, cy)

func _cell_to_world(cell: Vector2i, facing: Vector2, is_player: bool, idx: int) -> Dictionary:
    # Map 6x4 tactical chart cells to 3D space so fleets enter Ace Phase in their exact chart formation
    var wx := remap(float(cell.x), 0.0, float(GRID_COLS - 1), -38.0, 38.0)
    var wz := remap(float(cell.y), 0.0, float(GRID_ROWS - 1), -36.0, 36.0)
    # Slight vertical stratification per unit index for 3D visual clarity
    var wy := 5.0 if idx == 0 else (2.0 if idx == 1 else 7.5)

    # Formation offsets in 3D
    if is_player:
        match current_formation:
            Formation.LINE_OF_BATTLE:
                wx += float(idx - 1) * 4.0
            Formation.SPEARHEAD_WEDGE:
                if idx == 0:
                    wz -= 5.0
                else:
                    wz += 3.0
            Formation.FLANKING_PINCER:
                if idx == 1:
                    wx -= 8.0
                elif idx == 2:
                    wx += 8.0

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
    # Upwind Ether Stream corridor (grants Barlovento Weather-Gauge!)
    _sector_types[Vector2i(1, 1)] = "wind_stream"
    _sector_types[Vector2i(2, 1)] = "wind_stream"
    _sector_types[Vector2i(3, 1)] = "wind_stream"
    _sector_types[Vector2i(2, 2)] = "wind_stream"
    _sector_types[Vector2i(3, 2)] = "wind_stream"
    _sector_types[Vector2i(4, 2)] = "wind_stream"
    # Basalt Asteroid Reefs (grants Flank Cover)
    _sector_types[Vector2i(0, 1)] = "reef"
    _sector_types[Vector2i(0, 2)] = "reef"
    _sector_types[Vector2i(5, 1)] = "reef"
    # Sluice Station / Resonance Spire Anchor
    _sector_types[Vector2i(2, 3)] = "sluice"

func _plan_initial_orders() -> void:
    for i in range(3):
        var cur := _p_cells[i]
        var next_y := maxi(cur.y - 1, 0)
        var next_x := cur.x
        if current_formation == Formation.FLANKING_PINCER:
            if i == 0:
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
                    score += 2.5
                if _sector_types.get(cand, "") == "reef":
                    score += 0.6
                if score > best_score:
                    best_score = score
                    best = cand
        claimed.append(best)
        _e_targets[i] = best
        var dv := Vector2(best - cur)
        if dv.length_squared() > 0.01:
            _e_facing[i] = dv.normalized()

func _build_ui() -> void:
    # Fullscreen deep-space naval chart background with subtle transparency so 3D starsea glimmers behind
    var bg := ColorRect.new()
    bg.color = Color(0.008, 0.018, 0.042, 0.94)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    var main_margin := MarginContainer.new()
    main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    main_margin.add_theme_constant_override("margin_left", 24)
    main_margin.add_theme_constant_override("margin_right", 24)
    main_margin.add_theme_constant_override("margin_top", 16)
    main_margin.add_theme_constant_override("margin_bottom", 16)
    add_child(main_margin)

    var root_vbox := VBoxContainer.new()
    root_vbox.add_theme_constant_override("separation", 10)
    main_margin.add_child(root_vbox)

    # ── 1. TOP COMMAND HEADER BAR ──
    var top_panel := PanelContainer.new()
    var top_st := StyleBoxFlat.new()
    top_st.bg_color = Color(0.015, 0.035, 0.075, 0.92)
    top_st.border_color = Color(0.25, 0.78, 0.98, 0.55)
    top_st.set_border_width_all(1)
    top_st.set_corner_radius_all(6)
    top_st.set_content_margin_all(10)
    top_panel.add_theme_stylebox_override("panel", top_st)
    root_vbox.add_child(top_panel)

    var top_hbox := HBoxContainer.new()
    top_hbox.add_theme_constant_override("separation", 16)
    top_panel.add_child(top_hbox)

    # Canonical BARLOVENTO Wordmark (AGENTS.md Rule 8)
    var logo_tex: Texture2D = load("res://assets/brand/logo.png")
    if logo_tex != null:
        var atlas := AtlasTexture.new()
        atlas.atlas = logo_tex
        atlas.region = Rect2(80, 220, 1216, 280)
        var logo_rect := TextureRect.new()
        logo_rect.texture = atlas
        logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        logo_rect.custom_minimum_size = Vector2(185, 38)
        logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        top_hbox.add_child(logo_rect)

    top_hbox.add_child(VSeparator.new())

    var title_vbox := VBoxContainer.new()
    title_vbox.add_theme_constant_override("separation", 2)
    top_hbox.add_child(title_vbox)

    var phase_hdr := Label.new()
    phase_hdr.text = "PHASE 1: ADMIRAL STRATEGIC CHART // FIGHT FOR THE WEATHER-GAUGE"
    phase_hdr.add_theme_font_size_override("font_size", 15)
    phase_hdr.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
    title_vbox.add_child(phase_hdr)

    _status_lbl = Label.new()
    _status_lbl.text = "Click a ship token, then click a highlighted quadrant to plot your fleet's approach before 3D combat."
    _status_lbl.add_theme_font_size_override("font_size", 11)
    _status_lbl.add_theme_color_override("font_color", Color(0.65, 0.90, 1.0))
    title_vbox.add_child(_status_lbl)

    var sp := Control.new()
    sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_hbox.add_child(sp)

    _turn_lbl = Label.new()
    _turn_lbl.text = "MANEUVER TURN 1 / 3"
    _turn_lbl.add_theme_font_size_override("font_size", 14)
    _turn_lbl.add_theme_color_override("font_color", Color(0.35, 0.96, 1.0))
    top_hbox.add_child(_turn_lbl)

    var roster_btn := Button.new()
    roster_btn.text = "★ ROSTER [R]"
    roster_btn.custom_minimum_size = Vector2(110, 34)
    roster_btn.pressed.connect(func() -> void: open_roster_requested.emit())
    top_hbox.add_child(roster_btn)

    var menu_btn := Button.new()
    menu_btn.text = "◀ MENU"
    menu_btn.custom_minimum_size = Vector2(90, 34)
    menu_btn.pressed.connect(func() -> void: return_menu_requested.emit())
    top_hbox.add_child(menu_btn)

    # ── 2. MIDDLE SPLIT: LEFT (2D NAVAL QUADRANT HOLOTABLE) + RIGHT (STRATEGIC ADVANTAGES & DOCTRINE) ──
    var mid_hbox := HBoxContainer.new()
    mid_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    mid_hbox.add_theme_constant_override("separation", 16)
    root_vbox.add_child(mid_hbox)

    # Left: 2D Interactive Quadrant Chart
    var board_panel := PanelContainer.new()
    board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    board_panel.size_flags_stretch_ratio = 1.65
    var bp_st := StyleBoxFlat.new()
    bp_st.bg_color = Color(0.010, 0.024, 0.052, 0.95)
    bp_st.border_color = Color(0.28, 0.80, 1.0, 0.65)
    bp_st.set_border_width_all(2)
    bp_st.set_corner_radius_all(8)
    bp_st.set_content_margin_all(8)
    board_panel.add_theme_stylebox_override("panel", bp_st)
    mid_hbox.add_child(board_panel)

    _board_canvas = Control.new()
    _board_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _board_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _board_canvas.draw.connect(_draw_naval_chart)
    _board_canvas.gui_input.connect(_on_board_gui_input)
    board_panel.add_child(_board_canvas)

    # Right: Strategic Telemetry, Earned Buffs & Fleet Formations
    var right_panel := PanelContainer.new()
    right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_panel.size_flags_stretch_ratio = 1.0
    right_panel.add_theme_stylebox_override("panel", top_st)
    mid_hbox.add_child(right_panel)

    var right_vbox := VBoxContainer.new()
    right_vbox.add_theme_constant_override("separation", 10)
    right_panel.add_child(right_vbox)

    # Section A: Task Force Unit Selector
    var unit_hdr_row := HBoxContainer.new()
    right_vbox.add_child(unit_hdr_row)

    var unit_hdr := Label.new()
    unit_hdr.text = "1. SELECT SHIP OR FLEET TO MANEUVER:"
    unit_hdr.add_theme_font_size_override("font_size", 12)
    unit_hdr.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
    unit_hdr_row.add_child(unit_hdr)

    var u_sp := Control.new()
    u_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    unit_hdr_row.add_child(u_sp)

    _fleet_mode_btn = Button.new()
    _fleet_mode_btn.text = "⊞ MOVE ALL TOGETHER: OFF"
    _fleet_mode_btn.custom_minimum_size = Vector2(175, 26)
    _fleet_mode_btn.pressed.connect(func() -> void:
        AudioManager.play_sfx("ui_click", -8.0)
        move_whole_fleet = not move_whole_fleet
        _refresh_ui()
    )
    unit_hdr_row.add_child(_fleet_mode_btn)

    var units_hbox := HBoxContainer.new()
    units_hbox.add_theme_constant_override("separation", 6)
    right_vbox.add_child(units_hbox)

    _unit_btns.clear()
    for i in range(3):
        var ub := Button.new()
        ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        ub.custom_minimum_size = Vector2(0, 42)
        var idx := i
        ub.pressed.connect(func() -> void:
            AudioManager.play_sfx("ui_click", -8.0)
            selected_unit_idx = idx
            ship_selected_on_chart.emit(idx)
            _refresh_ui()
        )
        units_hbox.add_child(ub)
        _unit_btns.append(ub)

    right_vbox.add_child(HSeparator.new())

    # Section B: 3 Fleet Formations
    var form_hdr := Label.new()
    form_hdr.text = "2. CHOOSE FLEET DOCTRINE / FORMATION:"
    form_hdr.add_theme_font_size_override("font_size", 12)
    form_hdr.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
    right_vbox.add_child(form_hdr)

    var form_defs := [
        {
            "id": Formation.LINE_OF_BATTLE,
            "title": "🛡 LÍNEA DE BATALLA (Line of Battle)",
            "desc": "+20% Bow & Broadside Armor in 3D Ace Phase. Ideal for Crossing the T."
        },
        {
            "id": Formation.SPEARHEAD_WEDGE,
            "title": "⚡ CUÑA DE RUPTURA (Spearhead Wedge)",
            "desc": "+25% Initial Speed & Thrust in 3D Ace Phase. Rapid close-range breach."
        },
        {
            "id": Formation.FLANKING_PINCER,
            "title": "🎯 PINZA ENVOLVENTE (Flanking Pincer)",
            "desc": "+20% Critical Flank/Stern Damage & +15% Turn Rate in 3D Ace Phase."
        }
    ]
    _form_btns.clear()
    for fd in form_defs:
        var fb := Button.new()
        fb.text = "%s\n%s" % [fd["title"], fd["desc"]]
        fb.alignment = HORIZONTAL_ALIGNMENT_LEFT
        fb.custom_minimum_size = Vector2(0, 46)
        var f_val: Formation = fd["id"]
        fb.pressed.connect(func() -> void:
            AudioManager.play_sfx("ui_click", -8.0)
            current_formation = f_val
            _apply_formation_preset_to_targets()
            _refresh_ui()
        )
        right_vbox.add_child(fb)
        _form_btns.append(fb)

    right_vbox.add_child(HSeparator.new())

    # Section C: Live Strategic Advantage Forecast (What you carry into 3D Ace Phase!)
    var adv_hdr := Label.new()
    adv_hdr.text = "3. STRATEGIC ADVANTAGES FOR 3D ACE COMBAT:"
    adv_hdr.add_theme_font_size_override("font_size", 12)
    adv_hdr.add_theme_color_override("font_color", Color(0.35, 0.96, 1.0))
    right_vbox.add_child(adv_hdr)

    var adv_box := PanelContainer.new()
    var adv_st := StyleBoxFlat.new()
    adv_st.bg_color = Color(0.02, 0.055, 0.11, 0.90)
    adv_st.border_color = Color(0.30, 0.88, 0.65, 0.55)
    adv_st.set_border_width_all(1)
    adv_st.set_corner_radius_all(5)
    adv_st.set_content_margin_all(8)
    adv_box.add_theme_stylebox_override("panel", adv_st)
    right_vbox.add_child(adv_box)

    var adv_vbox := VBoxContainer.new()
    adv_vbox.add_theme_constant_override("separation", 5)
    adv_box.add_child(adv_vbox)

    _adv_weather_lbl = Label.new()
    _adv_weather_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _adv_weather_lbl.add_theme_font_size_override("font_size", 11)
    adv_vbox.add_child(_adv_weather_lbl)

    _adv_flank_lbl = Label.new()
    _adv_flank_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _adv_flank_lbl.add_theme_font_size_override("font_size", 11)
    adv_vbox.add_child(_adv_flank_lbl)

    _adv_form_lbl = Label.new()
    _adv_form_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _adv_form_lbl.add_theme_font_size_override("font_size", 11)
    adv_vbox.add_child(_adv_form_lbl)

    var r_sp := Control.new()
    r_sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right_vbox.add_child(r_sp)

    # Bottom Action Buttons
    var action_row := HBoxContainer.new()
    action_row.add_theme_constant_override("separation", 10)
    right_vbox.add_child(action_row)

    _step_turn_btn = Button.new()
    _step_turn_btn.text = "▶ EXECUTE MANEUVER TURN [SPACE]"
    _step_turn_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _step_turn_btn.custom_minimum_size = Vector2(0, 48)
    var cta_st := StyleBoxFlat.new()
    cta_st.bg_color = Color(0.08, 0.34, 0.48, 0.95)
    cta_st.border_color = Color(0.35, 0.95, 1.0, 0.95)
    cta_st.set_border_width_all(2)
    cta_st.set_corner_radius_all(6)
    _step_turn_btn.add_theme_stylebox_override("normal", cta_st)
    _step_turn_btn.pressed.connect(execute_strategic_turn)
    action_row.add_child(_step_turn_btn)

    _engage_btn = Button.new()
    _engage_btn.text = "⚔ LAUNCH 3D ACE BATTLE NOW"
    _engage_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _engage_btn.custom_minimum_size = Vector2(0, 48)
    var eng_st := StyleBoxFlat.new()
    eng_st.bg_color = Color(0.48, 0.22, 0.06, 0.95)
    eng_st.border_color = Color(1.0, 0.78, 0.28, 0.95)
    eng_st.set_border_width_all(2)
    eng_st.set_corner_radius_all(6)
    _engage_btn.add_theme_stylebox_override("normal", eng_st)
    _engage_btn.pressed.connect(_trigger_3d_engagement)
    action_row.add_child(_engage_btn)

func _apply_formation_preset_to_targets() -> void:
    var center_c := _p_cells[0]
    match current_formation:
        Formation.LINE_OF_BATTLE:
            # Abreast horizontal line advancing into the center stream
            var target_row := maxi(center_c.y - 1, 1)
            _p_targets[0] = Vector2i(1, target_row)
            _p_targets[1] = Vector2i(2, target_row)
            _p_targets[2] = Vector2i(3, target_row)
        Formation.SPEARHEAD_WEDGE:
            # Flagship spearheads 2 cells forward into the wind stream; escorts flank behind
            var lead_row := maxi(center_c.y - 2, 1)
            _p_targets[0] = Vector2i(2, lead_row)
            _p_targets[1] = Vector2i(1, mini(lead_row + 1, GRID_ROWS - 1))
            _p_targets[2] = Vector2i(3, mini(lead_row + 1, GRID_ROWS - 1))
        Formation.FLANKING_PINCER:
            # Split wings wide to cols 0 and 4 to catch enemy broadsides ("Crossing the T")
            var pincer_row := maxi(center_c.y - 1, 1)
            _p_targets[0] = Vector2i(2, pincer_row)
            _p_targets[1] = Vector2i(0, maxi(pincer_row - 1, 0))
            _p_targets[2] = Vector2i(4, maxi(pincer_row - 1, 0))

    for i in range(3):
        var dv := Vector2(_p_targets[i] - _p_cells[i])
        if dv.length_squared() > 0.01:
            _p_facing[i] = dv.normalized()

func compute_strategic_bonuses() -> Dictionary:
    # 1. Weather-Gauge (Barlovento): Count how many player ships are in 'wind_stream' cells or upwind of enemies
    var wind_cells_held := 0
    for i in range(3):
        var c := _p_targets[i] if not is_animating_turn else _p_cells[i]
        if _sector_types.get(c, "") == "wind_stream":
            wind_cells_held += 1

    var enemy_wind_cells := 0
    for i in range(3):
        if i < enemy_ships.size() and enemy_ships[i] != null and enemy_ships[i].is_destroyed():
            continue
        if _sector_types.get(_e_cells[i], "") == "wind_stream":
            enemy_wind_cells += 1

    var has_barlovento := (wind_cells_held >= 1 and wind_cells_held > enemy_wind_cells)
    var enemy_barlovento := (enemy_wind_cells >= 1 and enemy_wind_cells > wind_cells_held)

    # 2. Directional Ambush (Crossing the T / Flanking):
    # Check if player ships occupy columns outside enemy spread or approach enemy flanks
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
        var ec := _e_Cells_or_Target(i)
        avg_ex += float(ec.x)
        avg_ey += float(ec.y)
    avg_ex /= 3.0
    avg_ey /= 3.0

    var spread_span := max_px - min_px
    var is_flanking := (spread_span >= 3) or (avg_py <= avg_ey + 0.4) or (current_formation == Formation.FLANKING_PINCER)
    var is_crossing_t := (current_formation == Formation.LINE_OF_BATTLE and wind_cells_held >= 2)

    return {
        "has_barlovento": has_barlovento,
        "enemy_barlovento": enemy_barlovento,
        "enemy_wind_cells": enemy_wind_cells,
        "wind_cells_held": wind_cells_held,
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

func _e_Cells_or_Target(i: int) -> Vector2i:
    return _e_cells[i]

func _refresh_ui() -> void:
    if _turn_lbl != null:
        _turn_lbl.text = "STRATEGIC TURN %d / %d" % [strategic_turn, MAX_STRATEGIC_TURNS]

    if _fleet_mode_btn != null:
        _fleet_mode_btn.text = "⊞ MOVE ALL TOGETHER: ON" if move_whole_fleet else "⊞ MOVE ALL TOGETHER: OFF"
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
        btn.text = "%s\n%s [%s→%s]" % [u_name, p_name, _cell_name(c), _cell_name(t)]
        btn.modulate = Color(0.4, 1.0, 0.85) if i == selected_unit_idx else Color(0.82, 0.88, 0.96)

    for i in range(_form_btns.size()):
        var active := (int(current_formation) == i)
        _form_btns[i].modulate = Color(1.0, 0.92, 0.45) if active else Color(0.80, 0.86, 0.95)

    var b := compute_strategic_bonuses()
    if _adv_weather_lbl != null:
        if b["has_barlovento"]:
            _adv_weather_lbl.text = "🌬 BARLOVENTO (WEATHER-GAUGE): SECURED (%d Éther cells)\n   → +1 Bonus AP in Ace Phase, +15%% Hit Accuracy & +15%% Damage!" % b["wind_cells_held"]
            _adv_weather_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72))
        elif b["enemy_barlovento"]:
            _adv_weather_lbl.text = "🌬 BARLOVENTO: HELD BY THE ENEMY (%d vs %d Éther cells)\n   → They gain +15%% Hit & Damage. Push more ships into the cyan current!" % [b["enemy_wind_cells"], b["wind_cells_held"]]
            _adv_weather_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
        else:
            _adv_weather_lbl.text = "🌬 BARLOVENTO (WEATHER-GAUGE): CONTESTED\n   → Hold more cyan Éther cells than the enemy to claim +1 AP & +15%% Hit!"
            _adv_weather_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))

    if _adv_flank_lbl != null:
        if b["is_crossing_t"]:
            _adv_flank_lbl.text = "🎯 APPROACH VECTOR: CROSSING THE ENEMY'S 'T'!\n   → Enemies spawn in 3D with flanks exposed to your broadsides!"
            _adv_flank_lbl.add_theme_color_override("font_color", Color(0.40, 0.96, 1.0))
        elif b["is_flanking"]:
            _adv_flank_lbl.text = "🎯 APPROACH VECTOR: ENVELOPING PINCER FLANK!\n   → Wing ships deploy in 3D aimed at hostile port/starboard & stern!"
            _adv_flank_lbl.add_theme_color_override("font_color", Color(0.40, 0.96, 1.0))
        else:
            _adv_flank_lbl.text = "🎯 APPROACH VECTOR: HEAD-ON ENGAGEMENT\n   → Spread ships across columns or select Pincer/Line to outflank."
            _adv_flank_lbl.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95))

    if _adv_form_lbl != null:
        match current_formation:
            Formation.LINE_OF_BATTLE:
                _adv_form_lbl.text = "🛡 ACTIVE DOCTRINE: LÍNEA DE BATALLA (+20% Armor on all quadrants)"
            Formation.SPEARHEAD_WEDGE:
                _adv_form_lbl.text = "⚡ ACTIVE DOCTRINE: CUÑA DE RUPTURA (+25% Max Speed & Initial Momentum)"
            Formation.FLANKING_PINCER:
                _adv_form_lbl.text = "🎯 ACTIVE DOCTRINE: PINZA ENVOLVENTE (+15% Turn Rate & Flank Spawn)"
        _adv_form_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38))

    if _board_canvas != null:
        _board_canvas.queue_redraw()

func _cell_name(c: Vector2i) -> String:
    var cols := ["A", "B", "C", "D", "E", "F"]
    var col_s: String = cols[clampi(c.x, 0, cols.size() - 1)]
    return "%s%d" % [col_s, c.y + 1]

func _get_board_rect() -> Rect2:
    var sz := _board_canvas.size
    var pad := 36.0
    return Rect2(Vector2(pad, pad), Vector2(maxf(sz.x - pad * 2.0, 100.0), maxf(sz.y - pad * 2.0, 100.0)))

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

        # Check if user clicked directly on one of their own ship tokens to select it
        for i in range(3):
            if _p_cells[i] == clicked_cell and clicked_cell != _p_targets[selected_unit_idx]:
                AudioManager.play_sfx("ui_click", -8.0)
                selected_unit_idx = i
                ship_selected_on_chart.emit(i)
                _refresh_ui()
                return

        # Otherwise plot movement target for selected unit (or whole fleet)
        var cur := _p_cells[selected_unit_idx]
        var delta_c := clicked_cell - cur
        # Max 2 cells per strategic turn
        var clamped_target := Vector2i(
            clampi(cur.x + clampi(delta_c.x, -2, 2), 0, GRID_COLS - 1),
            clampi(cur.y + clampi(delta_c.y, -2, 2), 0, GRID_ROWS - 1)
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
        tw.tween_method(func(v: Vector2) -> void: _p_anim_pos[idx] = v, _p_anim_pos[i], p_dest, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tw.tween_method(func(v: Vector2) -> void: _e_anim_pos[idx] = v, _e_anim_pos[i], e_dest, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

    tw.chain().tween_callback(_on_strategic_turn_anim_done)

func _on_strategic_turn_anim_done() -> void:
    is_animating_turn = false
    for i in range(3):
        _p_cells[i] = _p_targets[i]
        _e_cells[i] = _e_targets[i]

    # Check if fleets have closed to engagement distance (any pair within <= 1 cell) or max turns reached
    var min_cell_dist := 99.0
    for p in _p_cells:
        for e in _e_cells:
            min_cell_dist = minf(min_cell_dist, Vector2(p - e).length())

    var contact := (min_cell_dist <= 1.45) or (strategic_turn >= MAX_STRATEGIC_TURNS)
    var b := compute_strategic_bonuses()
    var log_msg := "Admiral Turn %d resolved — Formation: %s | Barlovento: %s" % [
        strategic_turn,
        "Line of Battle" if current_formation == Formation.LINE_OF_BATTLE else ("Spearhead" if current_formation == Formation.SPEARHEAD_WEDGE else "Flanking Pincer"),
        "YES (+1 AP)" if b["has_barlovento"] else "NO"
    ]
    turn_executed.emit(log_msg, contact)

    if contact:
        _trigger_3d_engagement()
    else:
        strategic_turn += 1
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
        # If player earned Crossing the T or Flanking, angle enemy ships so their broadside/stern is exposed!
        if bonuses["is_crossing_t"] or bonuses["is_flanking"]:
            ef = Vector2(1.0, 0.25).normalized()
        e_spawns.append(_cell_to_world(_e_cells[i], ef, false, i))

    bonuses["player_spawns"] = p_spawns
    bonuses["enemy_spawns"] = e_spawns
    engage_3d_requested.emit(bonuses)

func _draw_naval_chart() -> void:
    var c := _board_canvas
    var font := ThemeDB.fallback_font
    var br := _get_board_rect()
    var cw := br.size.x / float(GRID_COLS)
    var ch := br.size.y / float(GRID_ROWS)

    # 1. Astrolabe Compass Circles in Background
    var center := br.get_center()
    var max_r := minf(br.size.x, br.size.y) * 0.46
    c.draw_arc(center, max_r, 0.0, TAU, 64, Color(0.22, 0.65, 0.88, 0.16), 1.5)
    c.draw_arc(center, max_r * 0.68, 0.0, TAU, 48, Color(0.85, 0.68, 0.28, 0.14), 1.0)

    # 2. Draw 6x4 Strategic Quadrants & Terrain
    var cols_lbl := ["A", "B", "C", "D", "E", "F"]
    for gx in range(GRID_COLS):
        for gy in range(GRID_ROWS):
            var cell := Vector2i(gx, gy)
            var r := _cell_rect(cell).grow(-2.0)
            var stype: String = _sector_types.get(cell, "open")

            var fill_col := Color(0.018, 0.042, 0.085, 0.65)
            var border_col := Color(0.20, 0.55, 0.78, 0.28)
            var badge_txt := ""
            var badge_col := Color(0.45, 0.75, 0.95, 0.65)

            if stype == "wind_stream":
                fill_col = Color(0.03, 0.16, 0.26, 0.72)
                border_col = Color(0.25, 0.92, 1.0, 0.65)
                badge_txt = "🌬 ÉTHER STREAM [BARLOVENTO +1 AP]"
                badge_col = Color(0.35, 0.96, 1.0, 0.92)
            elif stype == "reef":
                fill_col = Color(0.08, 0.06, 0.05, 0.72)
                border_col = Color(0.75, 0.55, 0.32, 0.45)
                badge_txt = "⛰ BASALT REEF [+COVER]"
                badge_col = Color(0.90, 0.72, 0.42, 0.85)
            elif stype == "sluice":
                fill_col = Color(0.12, 0.08, 0.03, 0.72)
                border_col = Color(1.0, 0.72, 0.25, 0.70)
                badge_txt = "⚙ SLUICE STATION WELL-09"
                badge_col = Color(1.0, 0.82, 0.35, 0.95)

            # Highlight reachable cells for selected unit
            var sel_cur := _p_cells[selected_unit_idx]
            var is_reachable := (absi(gx - sel_cur.x) <= 2 and absi(gy - sel_cur.y) <= 2)
            if is_reachable and not is_animating_turn:
                border_col = border_col.lightened(0.22)

            c.draw_rect(r, fill_col, true)
            c.draw_rect(r, border_col, false, 1.5 if stype != "open" else 1.0)

            # Animated wind streamlines inside wind_stream quadrants
            if stype == "wind_stream":
                for w_i in range(3):
                    var phase := fmod(_anim_t * 28.0 + float(w_i) * 24.0 + float(gx * 15), r.size.x - 16.0)
                    var wy := r.position.y + r.size.y * (0.32 + float(w_i) * 0.22)
                    var wx := r.position.x + 8.0 + phase
                    c.draw_line(Vector2(wx, wy), Vector2(minf(wx + 22.0, r.end.x - 6.0), wy - 3.0), Color(0.35, 0.95, 1.0, 0.40), 2.0)

            # Coordinate label (A1..F4)
            var coord_str := "%s%d" % [cols_lbl[gx], gy + 1]
            c.draw_string(font, r.position + Vector2(7, 15), coord_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.55, 0.78, 0.95, 0.75))

            if badge_txt != "":
                c.draw_string(font, Vector2(r.position.x + 6, r.end.y - 7), badge_txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 9, badge_col)

    # 3. Draw Enemy Planned Vectors & Ship Tokens (Red/Coral)
    for i in range(3):
        if i < enemy_ships.size() and enemy_ships[i] != null and enemy_ships[i].is_destroyed():
            continue
        var e_pos := _cell_center(_e_anim_pos[i])
        var e_tgt := _cell_center(Vector2(_e_targets[i].x, _e_targets[i].y))
        if not is_animating_turn and e_pos.distance_to(e_tgt) > 4.0:
            c.draw_dashed_line(e_pos, e_tgt, Color(1.0, 0.38, 0.28, 0.55), 2.0, 6.0)
            c.draw_circle(e_tgt, 5.0, Color(1.0, 0.38, 0.28, 0.65))

        # Enemy Diamond Token
        var rad := 16.0
        var pts := PackedVector2Array([
            e_pos + Vector2(0, -rad),
            e_pos + Vector2(rad, 0),
            e_pos + Vector2(0, rad),
            e_pos + Vector2(-rad, 0)
        ])
        c.draw_colored_polygon(pts, Color(0.45, 0.08, 0.08, 0.92))
        pts.append(pts[0])
        c.draw_polyline(pts, Color(1.0, 0.40, 0.30, 0.98), 2.2)

        var e_name := enemy_ships[i].ship_name if (i < enemy_ships.size() and enemy_ships[i] != null) else ("HOSTILE %d" % (i + 1))
        c.draw_string(font, e_pos + Vector2(-42, -rad - 6), "⚔ " + e_name, HORIZONTAL_ALIGNMENT_CENTER, 84, 10, Color(1.0, 0.55, 0.45))

    # 4. Draw Player Planned Vectors, Firing Arcs & Ship Tokens (Cyan/Gold)
    for i in range(3):
        if i < player_ships.size() and player_ships[i] != null and player_ships[i].is_destroyed():
            continue
        var p_pos := _cell_center(_p_anim_pos[i])
        var p_tgt := _cell_center(Vector2(_p_targets[i].x, _p_targets[i].y))
        var is_sel := (i == selected_unit_idx)

        if not is_animating_turn:
            # Target cell highlight
            var tr := _cell_rect(_p_targets[i]).grow(-5.0)
            c.draw_rect(tr, Color(0.25, 0.95, 0.65, 0.14 if not is_sel else 0.24), true)
            c.draw_rect(tr, Color(0.35, 1.0, 0.75, 0.75 if is_sel else 0.45), false, 2.0 if is_sel else 1.2)

            if p_pos.distance_to(p_tgt) > 4.0:
                c.draw_line(p_pos, p_tgt, Color(0.35, 0.98, 1.0, 0.92 if is_sel else 0.65), 3.0 if is_sel else 2.0)
                # Arrowhead at destination
                var dir := (p_tgt - p_pos).normalized()
                var perp := Vector2(-dir.y, dir.x)
                var tip := p_tgt
                var a1 := tip - dir * 12.0 + perp * 6.0
                var a2 := tip - dir * 12.0 - perp * 6.0
                c.draw_colored_polygon(PackedVector2Array([tip, a1, a2]), Color(0.35, 1.0, 0.80, 0.95))

        # Selection pulse ring
        if is_sel:
            var pulse_r := 22.0 + sin(_anim_t * 5.0) * 3.0
            c.draw_arc(p_pos, pulse_r, 0.0, TAU, 32, Color(1.0, 0.88, 0.32, 0.95), 2.2)

        # Player Ship Naval Chevron Token
        var fwd := _p_facing[i].normalized()
        var right := Vector2(-fwd.y, fwd.x)
        var r_sz := 16.0
        var ship_pts := PackedVector2Array([
            p_pos + fwd * (r_sz * 1.25),
            p_pos - fwd * r_sz + right * r_sz * 0.85,
            p_pos - fwd * (r_sz * 0.45),
            p_pos - fwd * r_sz - right * r_sz * 0.85
        ])
        c.draw_colored_polygon(ship_pts, Color(0.06, 0.36, 0.52, 0.95))
        ship_pts.append(ship_pts[0])
        c.draw_polyline(ship_pts, Color(0.35, 0.96, 1.0) if not is_sel else Color(1.0, 0.88, 0.35), 2.4)

        var p_name := player_ships[i].ship_name if (i < player_ships.size() and player_ships[i] != null) else ("ALLY %d" % (i + 1))
        c.draw_string(font, p_pos + Vector2(-48, r_sz + 14), "★ " + p_name, HORIZONTAL_ALIGNMENT_CENTER, 96, 10, Color(0.45, 0.96, 1.0) if not is_sel else Color(1.0, 0.92, 0.42))
