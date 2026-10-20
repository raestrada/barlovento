class_name AcePanel
extends Control

signal execute_round_pressed
signal cycle_target_pressed
signal stance_changed(new_stance: Ship.Stance)
signal exit_pressed
signal intercept_pressed
signal ability_used(ability_name: String)
signal ship_selected(ship: Ship)
signal enemy_selected(enemy: Ship)

signal yaw_left
signal yaw_right
signal pitch_up
signal pitch_down
signal speed_up
signal toggle_weapon_arcs_pressed
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
var enemy_ships: Array[Ship] = []
var _portrait_cache: Dictionary = {}

var _armor_widget: HudWidgets.DirectionalArmorWidget
var _ap_bar: HudWidgets.ActionPointBar
var _unit_tabs_hbox: HBoxContainer
var _enemy_tabs_hbox: HBoxContainer
var _ally_portrait_rect: TextureRect
var _ally_pilot_label: Label
var _ally_ship_label: Label
var _ally_hp_label: Label
var _enemy_portrait_rect: TextureRect
var _enemy_pilot_label: Label
var _enemy_ship_label: Label
var _enemy_hp_label: Label
var _target_status_label: Label
var _telemetry_label: Label

var _btn_oar_burst: Button
var _btn_trim_sails: Button
var _btn_broadside: Button
var _btn_rcs_burn: Button
var _btn_resolve: Button
var _arcs_btn: Button

var _current_ap: int = 7
var _base_round_ap: int = 7

func set_strategic_bonus_ap(extra_ap: int) -> void:
    _base_round_ap = 7 + extra_ap * 2
    _current_ap = _base_round_ap
    if _ap_bar != null:
        _ap_bar.current_ap = _current_ap
        _ap_bar.queue_redraw()

func _get_portrait(ship_id: String) -> Texture2D:
    var path := LoreDB.get_portrait_for_ship(ship_id)
    if path == "":
        return null
    if not _portrait_cache.has(path):
        if ResourceLoader.exists(path):
            _portrait_cache[path] = load(path)
        else:
            _portrait_cache[path] = null
    return _portrait_cache[path]

func _ready() -> void:
    custom_minimum_size = Vector2(0, 205)
    mouse_filter = Control.MOUSE_FILTER_PASS
    _build_ui()

func _build_ui() -> void:
    # 1. BOTTOM-LEFT: YOUR SQUADRON (ALLIED ACES) — Dedicated Ace Portrait + Directional Armor Widget
    var left_vbox := VBoxContainer.new()
    left_vbox.add_theme_constant_override("separation", 4)
    left_vbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    left_vbox.position = Vector2(14, -202)
    add_child(left_vbox)

    var ally_header := Label.new()
    ally_header.text = "★ YOUR SQUADRON // ALLIED ACES"
    ally_header.add_theme_font_size_override("font_size", 10)
    ally_header.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
    left_vbox.add_child(ally_header)

    _unit_tabs_hbox = HBoxContainer.new()
    _unit_tabs_hbox.add_theme_constant_override("separation", 4)
    left_vbox.add_child(_unit_tabs_hbox)

    var left_row := HBoxContainer.new()
    left_row.add_theme_constant_override("separation", 6)
    left_vbox.add_child(left_row)

    # Active Allied Ace Portrait Card
    var ally_card := PanelContainer.new()
    var ally_style := StyleBoxFlat.new()
    ally_style.bg_color = Color(0.02, 0.08, 0.13, 0.92)
    ally_style.border_color = HudWidgets.COL_GREEN
    ally_style.set_border_width_all(1)
    ally_style.set_corner_radius_all(5)
    ally_style.set_content_margin_all(6)
    ally_card.add_theme_stylebox_override("panel", ally_style)
    left_row.add_child(ally_card)

    var ally_card_vbox := VBoxContainer.new()
    ally_card_vbox.add_theme_constant_override("separation", 3)
    ally_card.add_child(ally_card_vbox)

    _ally_portrait_rect = TextureRect.new()
    _ally_portrait_rect.custom_minimum_size = Vector2(76, 76)
    _ally_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _ally_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    ally_card_vbox.add_child(_ally_portrait_rect)

    _ally_pilot_label = Label.new()
    _ally_pilot_label.add_theme_font_size_override("font_size", 10)
    _ally_pilot_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
    ally_card_vbox.add_child(_ally_pilot_label)

    _ally_ship_label = Label.new()
    _ally_ship_label.add_theme_font_size_override("font_size", 9)
    _ally_ship_label.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
    ally_card_vbox.add_child(_ally_ship_label)

    _ally_hp_label = Label.new()
    _ally_hp_label.add_theme_font_size_override("font_size", 9)
    _ally_hp_label.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
    ally_card_vbox.add_child(_ally_hp_label)

    _armor_widget = HudWidgets.DirectionalArmorWidget.new()
    left_row.add_child(_armor_widget)

    # 2. BOTTOM-CENTER: Action Points & Ability Pill Dock (exact ace-phase.png center dock)
    var center_wrapper := VBoxContainer.new()
    center_wrapper.add_theme_constant_override("separation", 5)
    center_wrapper.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    center_wrapper.position = Vector2(-335, -148)
    center_wrapper.custom_minimum_size = Vector2(670, 138)
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
    _arcs_btn = _make_helm_btn("🎯 ARCS [Y]: OFF", func() -> void: toggle_weapon_arcs())
    helm_row.add_child(_arcs_btn)
    helm_row.add_child(_make_helm_btn("🗺 ADMIRAL CHART", func() -> void: exit_pressed.emit()))

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
    dock_style.content_margin_left = 12
    dock_style.content_margin_right = 12
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

    var btn_shield := _make_pill_btn("🛡 Overcharge", false, func() -> void:
        _spend_ap(2)
        ability_used.emit("shield_pulse")
        refresh()
    )
    pills_row.add_child(btn_shield)

    _btn_resolve = _make_pill_btn("▶ RESOLVE [SPACE]", true, func() -> void:
        _current_ap = _base_round_ap
        execute_round_pressed.emit()
    )
    _btn_resolve.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
    pills_row.add_child(_btn_resolve)

    # 3. BOTTOM-RIGHT: HOSTILE FLEET (ENEMY COMMANDERS) — Dedicated Enemy Ace Portrait & Target Selector
    var right_vbox := VBoxContainer.new()
    right_vbox.add_theme_constant_override("separation", 4)
    right_vbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    right_vbox.position = Vector2(-282, -202)
    right_vbox.custom_minimum_size = Vector2(268, 0)
    add_child(right_vbox)

    var enemy_header := Label.new()
    enemy_header.text = "⚔ HOSTILE FLEET // ENEMY ACES"
    enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    enemy_header.add_theme_font_size_override("font_size", 10)
    enemy_header.add_theme_color_override("font_color", Color(1.0, 0.45, 0.32))
    right_vbox.add_child(enemy_header)

    _enemy_tabs_hbox = HBoxContainer.new()
    _enemy_tabs_hbox.alignment = BoxContainer.ALIGNMENT_END
    _enemy_tabs_hbox.add_theme_constant_override("separation", 4)
    right_vbox.add_child(_enemy_tabs_hbox)

    var enemy_card := PanelContainer.new()
    var enemy_style := StyleBoxFlat.new()
    enemy_style.bg_color = Color(0.11, 0.03, 0.04, 0.92)
    enemy_style.border_color = Color(1.0, 0.40, 0.25, 0.85)
    enemy_style.set_border_width_all(1)
    enemy_style.set_corner_radius_all(5)
    enemy_style.set_content_margin_all(8)
    enemy_card.add_theme_stylebox_override("panel", enemy_style)
    right_vbox.add_child(enemy_card)

    var enemy_card_hbox := HBoxContainer.new()
    enemy_card_hbox.add_theme_constant_override("separation", 10)
    enemy_card.add_child(enemy_card_hbox)

    _enemy_portrait_rect = TextureRect.new()
    _enemy_portrait_rect.custom_minimum_size = Vector2(78, 78)
    _enemy_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _enemy_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    enemy_card_hbox.add_child(_enemy_portrait_rect)

    var enemy_info_vbox := VBoxContainer.new()
    enemy_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    enemy_info_vbox.add_theme_constant_override("separation", 3)
    enemy_card_hbox.add_child(enemy_info_vbox)

    var lock_tag := Label.new()
    lock_tag.text = "⌖ LOCKED HOSTILE ACE"
    lock_tag.add_theme_font_size_override("font_size", 9)
    lock_tag.add_theme_color_override("font_color", Color(1.0, 0.45, 0.32))
    enemy_info_vbox.add_child(lock_tag)

    _enemy_pilot_label = Label.new()
    _enemy_pilot_label.add_theme_font_size_override("font_size", 12)
    _enemy_pilot_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.88))
    enemy_info_vbox.add_child(_enemy_pilot_label)

    _enemy_ship_label = Label.new()
    _enemy_ship_label.add_theme_font_size_override("font_size", 10)
    _enemy_ship_label.add_theme_color_override("font_color", HudWidgets.COL_AMBER)
    enemy_info_vbox.add_child(_enemy_ship_label)

    _enemy_hp_label = Label.new()
    _enemy_hp_label.add_theme_font_size_override("font_size", 10)
    _enemy_hp_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.42))
    enemy_info_vbox.add_child(_enemy_hp_label)

func set_fleet(allies: Array[Ship], selected: Ship, enemies: Array[Ship] = [], locked_enemy: Ship = null) -> void:
    player_ships = allies
    if not enemies.is_empty():
        enemy_ships = enemies
    if locked_enemy != null:
        target = locked_enemy
    ship = selected

    if _unit_tabs_hbox != null:
        for c in _unit_tabs_hbox.get_children():
            c.queue_free()
        for i in range(allies.size()):
            var a := allies[i]
            var b := Button.new()
            var short_pilot := a.pilot_name if a.pilot_name != "" else a.ship_name
            b.text = "★ %d: %s" % [i + 1, short_pilot]
            b.custom_minimum_size = Vector2(86, 22)
            b.add_theme_font_size_override("font_size", 9)
            b.focus_mode = Control.FOCUS_NONE
            if a.is_destroyed():
                b.disabled = true
                b.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
            elif a == selected:
                b.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
            else:
                b.add_theme_color_override("font_color", HudWidgets.COL_TEXT_MAIN)
            b.pressed.connect(func() -> void:
                if not a.is_destroyed():
                    ship_selected.emit(a)
            )
            _unit_tabs_hbox.add_child(b)

    if _enemy_tabs_hbox != null:
        for c in _enemy_tabs_hbox.get_children():
            c.queue_free()
        for i in range(enemy_ships.size()):
            var e := enemy_ships[i]
            var eb := Button.new()
            var short_enemy := e.pilot_name if e.pilot_name != "" else e.ship_name
            eb.text = "⚔ %s" % short_enemy
            eb.custom_minimum_size = Vector2(84, 22)
            eb.add_theme_font_size_override("font_size", 9)
            eb.focus_mode = Control.FOCUS_NONE
            if e.is_destroyed():
                eb.disabled = true
                eb.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
            elif e == target:
                eb.add_theme_color_override("font_color", Color(1.0, 0.45, 0.28))
            else:
                eb.add_theme_color_override("font_color", HudWidgets.COL_AMBER)
            eb.pressed.connect(func() -> void:
                if not e.is_destroyed():
                    enemy_selected.emit(e)
            )
            _enemy_tabs_hbox.add_child(eb)

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

    if _ally_portrait_rect != null:
        _ally_portrait_rect.texture = _get_portrait(ship.ship_id)
    if _ally_pilot_label != null:
        _ally_pilot_label.text = ship.pilot_name if ship.pilot_name != "" else "ALLIED ACE"
    if _ally_ship_label != null:
        _ally_ship_label.text = ship.ship_name
    if _ally_hp_label != null:
        _ally_hp_label.text = "HULL %d%% | SHLD %d%%" % [ship.hull_pct(), ship.shield_pct()]

    if target != null and is_instance_valid(target):
        if _enemy_portrait_rect != null:
            _enemy_portrait_rect.texture = _get_portrait(target.ship_id)
        if _enemy_pilot_label != null:
            _enemy_pilot_label.text = target.pilot_name if target.pilot_name != "" else "HOSTILE ACE"
        if _enemy_ship_label != null:
            _enemy_ship_label.text = target.ship_name
        if _enemy_hp_label != null:
            if target.is_destroyed():
                _enemy_hp_label.text = "[ VESSEL DESTROYED ]"
            else:
                var quad := Combat.get_hit_quadrant(ship, target)
                _enemy_hp_label.text = "HULL %d%% | SHLD %d%%\nEXPOSED: %s ARMOR" % [target.hull_pct(), target.shield_pct(), quad]

    if _ap_bar != null:
        _ap_bar.current_ap = _current_ap
        _ap_bar.salvo_text = "%d/7" % TurnManager.ace_round
        _ap_bar.drift_text = "/ %.0f" % ship.speed()

    if ship.faction == "marea_libre":
        _btn_oar_burst.text = "Oar Burst [+SPD]"
        _btn_trim_sails.text = "Trim Sails [AIM]"
        _btn_broadside.text = "Broadside [FIRE]"
        _btn_rcs_burn.text = "Reef Sails [BRAKE]"
    elif ship.faction == "vinculados":
        _btn_oar_burst.text = "Vernier Boost [+SPD]"
        _btn_trim_sails.text = "Neural Lock [AIM]"
        _btn_broadside.text = "Choir Lance [FIRE]"
        _btn_rcs_burn.text = "Phase Drift [EVADE]"
    else:
        _btn_oar_burst.text = "Furnace Burn [+SPD]"
        _btn_trim_sails.text = "Helm Lock [AIM]"
        _btn_broadside.text = "Rail Salvo [FIRE]"
        _btn_rcs_burn.text = "RCS Brake [EVADE]"

    var yaw_deg := posmod(roundi(rad_to_deg(ship.order.yaw)), 360)
    var pitch_deg := roundi(rad_to_deg(ship.order.pitch))
    if _telemetry_label != null:
        _telemetry_label.text = "★ %s (%s) // SPD %.1f m/s | HDG %03d° | PITCH %+d°" % [
            ship.pilot_name.to_upper(), ship.ship_name.to_upper(), ship.speed(), yaw_deg, pitch_deg
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
            var wg_tag := " 🌬[BARLOVENTO]" if Combat.has_weather_gauge(ship, target) else ""
            if in_rng and in_arc:
                _target_status_label.text = "⚔ VS %s [%.0fm — %d%% HIT]%s" % [target.pilot_name, dist, hit_pct, wg_tag]
                _target_status_label.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
            elif not in_rng:
                _target_status_label.text = "▲ %s OUT OF RANGE [%.0fm / %.0fm]" % [target.pilot_name, dist, ship.weapon_range]
                _target_status_label.add_theme_color_override("font_color", HudWidgets.COL_RED)
            else:
                _target_status_label.text = "◀ %s OUT OF ARC [CLICK AIM]%s" % [target.pilot_name, wg_tag]
                _target_status_label.add_theme_color_override("font_color", HudWidgets.COL_AMBER)

func _make_pill_btn(txt: String, glowing: bool, cb: Callable) -> Button:
    var b := Button.new()
    b.text = txt
    b.custom_minimum_size = Vector2(108, 36)
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

func toggle_weapon_arcs() -> void:
    Ship.show_weapon_arcs = not Ship.show_weapon_arcs
    if _arcs_btn != null:
        _arcs_btn.text = "🎯 ARCS [Y]: ON" if Ship.show_weapon_arcs else "🎯 ARCS [Y]: OFF"
        var col := HudWidgets.COL_CYAN_BRIGHT if Ship.show_weapon_arcs else Color(0.70, 0.85, 0.95, 0.7)
        _arcs_btn.add_theme_color_override("font_color", col)
    toggle_weapon_arcs_pressed.emit()

