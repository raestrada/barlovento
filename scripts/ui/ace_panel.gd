class_name AcePanel
extends Control

signal execute_round_pressed
signal cycle_target_pressed
signal stance_changed(new_stance: Ship.Stance)
signal exit_pressed
signal intercept_pressed
signal ability_used(ability_name: String)
signal ship_selected(ship: Ship)

signal yaw_left
signal yaw_right
signal pitch_up
signal pitch_down
signal speed_up
signal speed_down
signal stop_pressed

var ship: Ship:
    set(value):
        ship = value
        if _armor_widget != null:
            _armor_widget.ship = value
        refresh()

var target: Ship:
    set(value):
        target = value
        refresh()

var player_ships: Array[Ship] = []

var _armor_widget: HudWidgets.DirectionalArmorWidget
var _ap_bar: HudWidgets.ActionPointBar
var _unit_tabs_hbox: HBoxContainer
var _target_status_label: Label
var _telemetry_label: Label

var _btn_oar_burst: Button
var _btn_trim_sails: Button
var _btn_broadside: Button
var _btn_rcs_burn: Button
var _btn_resolve: Button

var _current_ap: int = 7

func _ready() -> void:
    custom_minimum_size = Vector2(0, 195)
    mouse_filter = Control.MOUSE_FILTER_PASS
    _build_ui()

func _build_ui() -> void:
    # 1. BOTTOM-LEFT: Directional Armor & Hull Quadrant Widget (exact ace-phase.png left box)
    var left_vbox := VBoxContainer.new()
    left_vbox.add_theme_constant_override("separation", 4)
    left_vbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    left_vbox.position = Vector2(16, -190)
    add_child(left_vbox)

    _unit_tabs_hbox = HBoxContainer.new()
    _unit_tabs_hbox.add_theme_constant_override("separation", 4)
    left_vbox.add_child(_unit_tabs_hbox)

    _armor_widget = HudWidgets.DirectionalArmorWidget.new()
    left_vbox.add_child(_armor_widget)

    # 2. BOTTOM-CENTER: Action Points & Ability Pill Dock (exact ace-phase.png center dock)
    var center_wrapper := VBoxContainer.new()
    center_wrapper.add_theme_constant_override("separation", 5)
    center_wrapper.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    center_wrapper.position = Vector2(-345, -148)
    center_wrapper.custom_minimum_size = Vector2(690, 138)
    add_child(center_wrapper)

    # Micro Helm & Target Telemetry Bar above the AP Dock
    var helm_row := HBoxContainer.new()
    helm_row.add_theme_constant_override("separation", 4)
    helm_row.alignment = BoxContainer.ALIGNMENT_CENTER
    center_wrapper.add_child(helm_row)

    helm_row.add_child(_make_helm_btn("◀ PORT [A]", func() -> void: yaw_left.emit()))
    helm_row.add_child(_make_helm_btn("STBD [D] ▶", func() -> void: yaw_right.emit()))
    helm_row.add_child(_make_helm_btn("▲ CLIMB [Q]", func() -> void: pitch_up.emit()))
    helm_row.add_child(_make_helm_btn("▼ DIVE [E]", func() -> void: pitch_down.emit()))
    helm_row.add_child(_make_helm_btn("-SPD [S]", func() -> void: speed_down.emit()))
    helm_row.add_child(_make_helm_btn("+SPD [W]", func() -> void: speed_up.emit()))
    helm_row.add_child(_make_helm_btn("TARGET [C]", func() -> void: cycle_target_pressed.emit()))
    helm_row.add_child(_make_helm_btn("ADMIRAL VIEW", func() -> void: exit_pressed.emit()))

    # Target Solution & Telemetry Line
    var status_row := HBoxContainer.new()
    status_row.add_theme_constant_override("separation", 14)
    status_row.alignment = BoxContainer.ALIGNMENT_CENTER
    center_wrapper.add_child(status_row)

    _telemetry_label = Label.new()
    _telemetry_label.add_theme_font_size_override("font_size", 11)
    _telemetry_label.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
    status_row.add_child(_telemetry_label)

    _target_status_label = Label.new()
    _target_status_label.add_theme_font_size_override("font_size", 11)
    status_row.add_child(_target_status_label)

    # Main Chamfered AP & Ability Pill Dock (matches ace-phase.png bottom dock)
    var ap_dock := PanelContainer.new()
    var dock_style := StyleBoxFlat.new()
    dock_style.bg_color = Color(0.02, 0.06, 0.11, 0.88)
    dock_style.border_color = Color(0.22, 0.78, 0.96, 0.65)
    dock_style.set_border_width_all(1)
    dock_style.set_corner_radius_all(8)
    dock_style.content_margin_left = 14
    dock_style.content_margin_right = 14
    dock_style.content_margin_top = 8
    dock_style.content_margin_bottom = 10
    ap_dock.add_theme_stylebox_override("panel", dock_style)
    center_wrapper.add_child(ap_dock)

    var dock_vbox := VBoxContainer.new()
    dock_vbox.add_theme_constant_override("separation", 8)
    ap_dock.add_child(dock_vbox)

    # Row 1 inside Dock: 12-pip Action Point Bar
    _ap_bar = HudWidgets.ActionPointBar.new()
    dock_vbox.add_child(_ap_bar)

    # Row 2 inside Dock: The 4 Pill Ability Buttons + Resolve Turn Pill
    var pills_row := HBoxContainer.new()
    pills_row.add_theme_constant_override("separation", 8)
    pills_row.alignment = BoxContainer.ALIGNMENT_CENTER
    dock_vbox.add_child(pills_row)

    _btn_oar_burst = _make_pill_btn("Oar Burst", true, func() -> void:
        _spend_ap(1)
        speed_up.emit()
        ability_used.emit("oar_burst")
    )
    pills_row.add_child(_btn_oar_burst)

    _btn_trim_sails = _make_pill_btn("Trim Sails", false, func() -> void:
        _spend_ap(1)
        intercept_pressed.emit()
    )
    pills_row.add_child(_btn_trim_sails)

    _btn_broadside = _make_pill_btn("Broadside", false, func() -> void:
        _spend_ap(2)
        if ship != null:
            ship.stance = Ship.Stance.FIRE
            stance_changed.emit(ship.stance)
        ability_used.emit("precision")
        refresh()
    )
    pills_row.add_child(_btn_broadside)

    _btn_rcs_burn = _make_pill_btn("RCS Burn", false, func() -> void:
        _spend_ap(1)
        if ship != null:
            ship.stance = Ship.Stance.EVASIVE
            stance_changed.emit(ship.stance)
        ability_used.emit("retro_brake")
        refresh()
    )
    pills_row.add_child(_btn_rcs_burn)

    _btn_resolve = _make_pill_btn("▶ RESOLVE [SPACE]", true, func() -> void:
        _current_ap = 7
        execute_round_pressed.emit()
    )
    _btn_resolve.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
    pills_row.add_child(_btn_resolve)

func set_fleet(allies: Array[Ship], selected: Ship) -> void:
    player_ships = allies
    ship = selected
    if _unit_tabs_hbox == null:
        return
    for c in _unit_tabs_hbox.get_children():
        c.queue_free()

    for i in range(allies.size()):
        var a := allies[i]
        var b := Button.new()
        b.text = "%d: %s" % [i + 1, a.ship_name]
        b.custom_minimum_size = Vector2(82, 22)
        b.add_theme_font_size_override("font_size", 10)
        b.focus_mode = Control.FOCUS_NONE
        if a == selected:
            b.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
        else:
            b.add_theme_color_override("font_color", HudWidgets.COL_TEXT_MUTED)
        b.pressed.connect(func() -> void:
            if not a.is_destroyed():
                ship_selected.emit(a)
        )
        _unit_tabs_hbox.add_child(b)

func _spend_ap(cost: int) -> void:
    _current_ap = maxi(_current_ap - cost, 1)
    if _ap_bar != null:
        _ap_bar.current_ap = _current_ap
        _ap_bar.queue_redraw()

func _process(_delta: float) -> void:
    refresh()
    if _armor_widget != null:
        _armor_widget.queue_redraw()
    if _ap_bar != null:
        _ap_bar.queue_redraw()

func refresh() -> void:
    if ship == null or not is_instance_valid(ship):
        return

    if _armor_widget != null:
        _armor_widget.ship = ship

    if _ap_bar != null:
        _ap_bar.current_ap = _current_ap
        _ap_bar.salvo_text = "%d/7" % TurnManager.ace_round
        _ap_bar.drift_text = "/ %.0f" % ship.speed()

    # Keep the iconic ability labels from ace-phase.png while making their function clear
    if ship.faction == "marea_libre":
        _btn_oar_burst.text = "Oar Burst [+SPD]"
        _btn_trim_sails.text = "Trim Sails [AIM]"
        _btn_broadside.text = "Broadside [FIRE]"
        _btn_rcs_burn.text = "RCS Burn [BRAKE]"
    else:
        _btn_oar_burst.text = "Oar Burst [+SPD]"
        _btn_trim_sails.text = "Trim Sails [AIM]"
        _btn_broadside.text = "Broadside [FIRE]"
        _btn_rcs_burn.text = "RCS Burn [BRAKE]"

    var yaw_deg := posmod(roundi(rad_to_deg(ship.order.yaw)), 360)
    var pitch_deg := roundi(rad_to_deg(ship.order.pitch))
    if _telemetry_label != null:
        _telemetry_label.text = "%s // SPD %.1f m/s (CMD %.1f) | HDG %03d° | PITCH %+d°" % [
            ship.ship_name.to_upper(), ship.speed(), ship.order.target_speed, yaw_deg, pitch_deg
        ]

    if _target_status_label != null:
        if target == null or not is_instance_valid(target) or target.is_destroyed():
            _target_status_label.text = "⌖ NO TARGET [PRESS C]"
            _target_status_label.add_theme_color_override("font_color", HudWidgets.COL_TEXT_MUTED)
        else:
            var dist := ship.state.position.distance_to(target.state.position)
            var in_rng := dist <= ship.weapon_range
            var in_arc := Combat.in_arc(ship, target)
            var hit_pct := roundi(Combat.hit_chance(ship, target) * 100.0)
            if in_rng and in_arc:
                _target_status_label.text = "● LOCKED: %s [%.0fm — %d%% HIT]" % [target.ship_name, dist, hit_pct]
                _target_status_label.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
            elif not in_rng:
                _target_status_label.text = "▲ %s OUT OF RANGE [%.0fm / %.0fm]" % [target.ship_name, dist, ship.weapon_range]
                _target_status_label.add_theme_color_override("font_color", HudWidgets.COL_RED)
            else:
                _target_status_label.text = "◀ %s OUT OF CONE [CLICK TRIM SAILS]" % target.ship_name
                _target_status_label.add_theme_color_override("font_color", HudWidgets.COL_AMBER)

func _make_pill_btn(txt: String, glowing: bool, cb: Callable) -> Button:
    var b := Button.new()
    b.text = txt
    b.custom_minimum_size = Vector2(126, 36)
    b.add_theme_font_size_override("font_size", 11)
    b.focus_mode = Control.FOCUS_NONE

    var st_norm := StyleBoxFlat.new()
    st_norm.bg_color = Color(0.06, 0.24, 0.34, 0.92) if glowing else Color(0.03, 0.10, 0.17, 0.88)
    st_norm.border_color = HudWidgets.COL_CYAN_BRIGHT if glowing else Color(0.22, 0.68, 0.88, 0.65)
    st_norm.set_border_width_all(2 if glowing else 1)
    st_norm.set_corner_radius_all(6)
    st_norm.set_content_margin_all(6)
    b.add_theme_stylebox_override("normal", st_norm)

    var st_hov := st_norm.duplicate()
    st_hov.bg_color = Color(0.10, 0.34, 0.48, 0.96)
    st_hov.border_color = HudWidgets.COL_CYAN_BRIGHT
    st_hov.set_border_width_all(2)
    b.add_theme_stylebox_override("hover", st_hov)

    b.pressed.connect(cb)
    return b

func _make_helm_btn(txt: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = txt
    b.custom_minimum_size = Vector2(68, 22)
    b.add_theme_font_size_override("font_size", 10)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(cb)
    return b
