class_name OrderPanel
extends Control

signal order_changed
signal intercept_pressed
signal engage_ace_pressed
signal execute_turn_pressed
signal formation_pressed
signal focus_camera_pressed
signal toggle_grid_pressed
signal open_roster_pressed
signal ship_selected(ship: Ship)
signal enemy_targeted(enemy: Ship, auto_intercept: bool)

const SPEED_STEP := 2.5
const ANGLE_STEP_DEG := 15.0

var ship: Ship:
    set(value):
        ship = value
        refresh()

var player_ships: Array[Ship] = []
var enemy_ships: Array[Ship] = []
var target_ship: Ship = null

var _cards_hbox: HBoxContainer
var _unit_cards: Array[HudWidgets.AdmiralUnitCard] = []
var _step_buttons: Array[Button] = []
var _telemetry_label: Label

func _ready() -> void:
    custom_minimum_size = Vector2(0, 128)
    mouse_filter = Control.MOUSE_FILTER_PASS
    _build_ui()

func _draw() -> void:
    var font := ThemeDB.fallback_font
    var w := size.x
    var h := size.y
    var dock_y := 52.0
    var dock_h := h - dock_y

    # 1. Bottom full-width dark naval command dock
    draw_rect(Rect2(0, dock_y, w, dock_h), Color(0.015, 0.045, 0.085, 0.90), true)
    draw_line(Vector2(0, dock_y), Vector2(w, dock_y), Color(0.22, 0.75, 0.96, 0.55), 1.5)

    # 2. Left Angled Fleet Tab ("ARMADA / TASK FORCE" trapezoid from admiral-phase.png)
    var left_tab := PackedVector2Array([
        Vector2(0, dock_y - 26),
        Vector2(215, dock_y - 26),
        Vector2(235, dock_y),
        Vector2(0, dock_y)
    ])
    draw_colored_polygon(left_tab, Color(0.02, 0.06, 0.11, 0.92))
    draw_polyline(PackedVector2Array([
        Vector2(0, dock_y - 26), Vector2(215, dock_y - 26), Vector2(235, dock_y)
    ]), Color(0.25, 0.78, 0.98, 0.65), 1.5)

    # Mini shield crest inside left tab
    var sc := Vector2(18, dock_y - 13)
    var sh := PackedVector2Array([
        Vector2(sc.x, sc.y - 7), Vector2(sc.x + 6, sc.y - 4),
        Vector2(sc.x + 5, sc.y + 3), Vector2(sc.x, sc.y + 7),
        Vector2(sc.x - 5, sc.y + 3), Vector2(sc.x - 6, sc.y - 4)
    ])
    draw_colored_polygon(sh, Color(0.22, 0.78, 0.98, 0.4))
    sh.append(sh[0])
    draw_polyline(sh, HudWidgets.COL_CYAN_BRIGHT, 1.3)

    var f_name := "TASK FORCE // CHOIR & TIDE"
    if ship != null and is_instance_valid(ship):
        match ship.faction:
            "marea_libre":
                f_name = "THE FREE TIDE // FLOTILLA"
            "vinculados":
                f_name = "THE VINCULADOS // CHOIR"
            "acero":
                f_name = "ARMADA OF ACERO"
    draw_string(font, Vector2(32, dock_y - 8), f_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HudWidgets.COL_TEXT_MAIN)

    # 3. Center Angled Trapezoid Header ("ADMIRAL PHASE - SIMULTANEOUS PLANNING" from admiral-phase.png)
    var cx := w * 0.48
    var top_w := 320.0
    var bot_w := 380.0
    var trap_top := 2.0
    var trap := PackedVector2Array([
        Vector2(cx - bot_w * 0.5, dock_y),
        Vector2(cx - top_w * 0.5, trap_top),
        Vector2(cx + top_w * 0.5, trap_top),
        Vector2(cx + bot_w * 0.5, dock_y)
    ])
    draw_colored_polygon(trap, Color(0.02, 0.06, 0.12, 0.90))
    draw_polyline(PackedVector2Array([
        Vector2(cx - bot_w * 0.5, dock_y),
        Vector2(cx - top_w * 0.5, trap_top),
        Vector2(cx + top_w * 0.5, trap_top),
        Vector2(cx + bot_w * 0.5, dock_y)
    ]), Color(0.28, 0.82, 0.98, 0.75), 1.6)

    draw_string(font, Vector2(cx - 150, trap_top + 17), "ADMIRAL PHASE - SIMULTANEOUS PLANNING", HORIZONTAL_ALIGNMENT_CENTER, 300, 11, HudWidgets.COL_TEXT_MAIN)

    # Horizontal rule lines flanking the [1]-[2]-[3]-[4] selector boxes inside trapezoid
    draw_line(Vector2(cx - 145, trap_top + 34), Vector2(cx - 72, trap_top + 34), HudWidgets.COL_CYAN_DIM, 1.0)
    draw_line(Vector2(cx + 72, trap_top + 34), Vector2(cx + 145, trap_top + 34), HudWidgets.COL_CYAN_DIM, 1.0)

    # 4. Right Header ("FLEET ORDER" above the square tiles)
    draw_string(font, Vector2(w - 110, dock_y - 8), "FLEET ORDER", HORIZONTAL_ALIGNMENT_RIGHT, 98, 12, HudWidgets.COL_TEXT_MAIN)

func _build_ui() -> void:
    # A. Center Step/Unit Selector Boxes [1] - [2] - [3] - [4] inside the center trapezoid
    var center_steps := HBoxContainer.new()
    center_steps.add_theme_constant_override("separation", 6)
    center_steps.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    center_steps.position = Vector2(-82, 23)
    add_child(center_steps)

    for i in range(4):
        var b := Button.new()
        b.text = "%d" % (i + 1)
        b.custom_minimum_size = Vector2(24, 22)
        b.focus_mode = Control.FOCUS_NONE
        var idx := i
        b.pressed.connect(func() -> void:
            if idx < player_ships.size() and not player_ships[idx].is_destroyed():
                ship_selected.emit(player_ships[idx])
            elif not enemy_ships.is_empty():
                for e in enemy_ships:
                    if not e.is_destroyed():
                        enemy_targeted.emit(e, false)
                        break
        )
        center_steps.add_child(b)
        _step_buttons.append(b)

    # B. Fine Flight Helm Micro-Strip (Port/Stbd/Climb/Dive/Throttle + Live Vector Telemetry)
    var helm_bar := HBoxContainer.new()
    helm_bar.add_theme_constant_override("separation", 4)
    helm_bar.position = Vector2(242, 24)
    add_child(helm_bar)

    helm_bar.add_child(_make_mini_btn("◀ PORT [A]", _on_yaw_left))
    helm_bar.add_child(_make_mini_btn("STBD [D] ▶", _on_yaw_right))
    helm_bar.add_child(_make_mini_btn("▲ CLIMB [Q]", _on_pitch_up))
    helm_bar.add_child(_make_mini_btn("▼ DIVE [E]", _on_pitch_down))
    helm_bar.add_child(_make_mini_btn("-SPD [S]", _on_speed_down))
    helm_bar.add_child(_make_mini_btn("+SPD [W]", _on_speed_up))
    helm_bar.add_child(_make_mini_btn("STOP [X]", _on_stop))

    _telemetry_label = Label.new()
    _telemetry_label.add_theme_font_size_override("font_size", 10)
    _telemetry_label.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
    helm_bar.add_child(_telemetry_label)

    # C. Bottom Dock Main Row (Left Utility Stack + Unit Cards Strip + Right FLEET ORDER Square Tiles)
    var dock_row := HBoxContainer.new()
    dock_row.add_theme_constant_override("separation", 6)
    dock_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 6)
    dock_row.offset_top = -70
    dock_row.offset_bottom = -4
    add_child(dock_row)

    # 1. Left Vertical Stack of 3 Utility Icon Buttons (exact admiral-phase.png left stack)
    var util_vbox := VBoxContainer.new()
    util_vbox.add_theme_constant_override("separation", 2)
    dock_row.add_child(util_vbox)

    var btn_focus := _make_util_btn("⌖", "Focus Camera on Active Ship [V]", func() -> void: focus_camera_pressed.emit())
    var btn_grid := _make_util_btn("⊞", "Toggle 3D Tactical Grid [G]", func() -> void: toggle_grid_pressed.emit())
    var btn_roster := _make_util_btn("★", "Open Hero Ace Roster [R]", func() -> void: open_roster_pressed.emit())
    util_vbox.add_child(btn_focus)
    util_vbox.add_child(btn_grid)
    util_vbox.add_child(btn_roster)

    # 2. Horizontal Unit Cards Strip
    _cards_hbox = HBoxContainer.new()
    _cards_hbox.add_theme_constant_override("separation", 6)
    _cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    dock_row.add_child(_cards_hbox)

    # 3. Right "FLEET ORDER" Square Action Tiles (exact admiral-phase.png 68x66 square icon tiles)
    var tiles_hbox := HBoxContainer.new()
    tiles_hbox.add_theme_constant_override("separation", 5)
    dock_row.add_child(tiles_hbox)

    var t_move := HudWidgets.FleetOrderTile.new("move", "MOVE", false)
    t_move.tooltip_text = "Boost Cruise Speed (+SPD [W])"
    t_move.pressed.connect(_on_speed_up)
    tiles_hbox.add_child(t_move)

    var t_face := HudWidgets.FleetOrderTile.new("face", "FACE", false)
    t_face.tooltip_text = "Turn Ship Heading Toward Target ([A/D])"
    t_face.pressed.connect(func() -> void: intercept_pressed.emit())
    tiles_hbox.add_child(t_face)

    var t_engage := HudWidgets.FleetOrderTile.new("engage", "ENGAGE", false)
    t_engage.tooltip_text = "Transition to Ace Tactical Phase"
    t_engage.pressed.connect(func() -> void: engage_ace_pressed.emit())
    tiles_hbox.add_child(t_engage)

    var t_target := HudWidgets.FleetOrderTile.new("target", "TARGET", false)
    t_target.tooltip_text = "Lock & Plot Intercept Course to Hostile [T]"
    t_target.pressed.connect(func() -> void: intercept_pressed.emit())
    tiles_hbox.add_child(t_target)

    var t_form := HudWidgets.FleetOrderTile.new("formation", "FORMATION", false)
    t_form.tooltip_text = "Align All Allied Ships to Flagship Course & Speed"
    t_form.pressed.connect(func() -> void: formation_pressed.emit())
    tiles_hbox.add_child(t_form)

    var t_exec := HudWidgets.FleetOrderTile.new("execute", "EXECUTE", true)
    t_exec.tooltip_text = "Execute Simultaneous Fleet Turn [SPACE]"
    t_exec.pressed.connect(func() -> void: execute_turn_pressed.emit())
    tiles_hbox.add_child(t_exec)

func rebuild_unit_cards(allies: Array[Ship], enemies: Array[Ship], selected: Ship, locked_target: Ship) -> void:
    player_ships = allies
    enemy_ships = enemies
    ship = selected
    target_ship = locked_target

    if _cards_hbox == null:
        return
    for child in _cards_hbox.get_children():
        child.queue_free()
    _unit_cards.clear()

    for a in allies:
        var card := HudWidgets.AdmiralUnitCard.new(a)
        card.is_selected_unit = (a == selected)
        card.pressed.connect(func() -> void:
            if not a.is_destroyed():
                ship_selected.emit(a)
        )
        _cards_hbox.add_child(card)
        _unit_cards.append(card)

    for e in enemies:
        var card := HudWidgets.AdmiralUnitCard.new(e)
        card.is_target_unit = (e == locked_target)
        card.gui_input.connect(func(ev: InputEvent) -> void:
            if ev is InputEventMouseButton and ev.pressed and not e.is_destroyed():
                if ev.button_index == MOUSE_BUTTON_LEFT:
                    enemy_targeted.emit(e, false)
                elif ev.button_index == MOUSE_BUTTON_RIGHT:
                    enemy_targeted.emit(e, true)
        )
        _cards_hbox.add_child(card)
        _unit_cards.append(card)

func _process(_delta: float) -> void:
    refresh()
    queue_redraw()
    for c in _unit_cards:
        if is_instance_valid(c):
            c.queue_redraw()

func refresh() -> void:
    if ship == null or not is_instance_valid(ship):
        if _telemetry_label != null:
            _telemetry_label.text = ""
        return

    var yaw_deg := posmod(roundi(rad_to_deg(ship.order.yaw)), 360)
    var pitch_deg := roundi(rad_to_deg(ship.order.pitch))
    if _telemetry_label != null:
        _telemetry_label.text = "  %s | SPD %.1f/%.0f m/s (CMD %.1f) | HDG %03d° | PITCH %+d°" % [
            ship.unit_code, ship.speed(), ship.state.max_speed, ship.order.target_speed, yaw_deg, pitch_deg
        ]

    for i in range(_step_buttons.size()):
        var b := _step_buttons[i]
        if i < player_ships.size() and player_ships[i] == ship:
            b.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
        else:
            b.add_theme_color_override("font_color", HudWidgets.COL_TEXT_MUTED)

func _make_mini_btn(txt: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = txt
    b.add_theme_font_size_override("font_size", 10)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(cb)
    return b

func _make_util_btn(icon_txt: String, tip: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = icon_txt
    b.tooltip_text = tip
    b.custom_minimum_size = Vector2(26, 20)
    b.add_theme_font_size_override("font_size", 10)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(cb)
    return b

func _on_stop() -> void:
    if ship != null:
        ship.order.target_speed = 0.0
        order_changed.emit()

func _on_speed_down() -> void:
    if ship != null:
        ship.order.target_speed = clampf(ship.order.target_speed - SPEED_STEP, 0.0, ship.state.max_speed)
        order_changed.emit()

func _on_speed_up() -> void:
    if ship != null:
        ship.order.target_speed = clampf(ship.order.target_speed + SPEED_STEP, 0.0, ship.state.max_speed)
        order_changed.emit()

func _on_yaw_left() -> void:
    if ship != null:
        ship.order.yaw += deg_to_rad(ANGLE_STEP_DEG)
        order_changed.emit()

func _on_yaw_right() -> void:
    if ship != null:
        ship.order.yaw -= deg_to_rad(ANGLE_STEP_DEG)
        order_changed.emit()

func _on_pitch_up() -> void:
    if ship != null:
        ship.order.pitch = clampf(ship.order.pitch + deg_to_rad(10.0), -1.15, 1.15)
        order_changed.emit()

func _on_pitch_down() -> void:
    if ship != null:
        ship.order.pitch = clampf(ship.order.pitch - deg_to_rad(10.0), -1.15, 1.15)
        order_changed.emit()
