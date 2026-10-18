class_name AcePanel
extends PanelContainer

signal execute_round_pressed
signal cycle_target_pressed
signal stance_changed(new_stance: Ship.Stance)
signal exit_pressed
signal intercept_pressed
signal ability_used(ability_name: String)

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
        refresh()

var target: Ship:
    set(value):
        target = value
        refresh()

var _title: Label
var _pilot_label: Label
var _hp_bar: ProgressBar
var _hp_val: Label
var _telemetry_label: Label

var _target_banner: Label
var _target_solution_pill: Label

var _fire_stance_btn: Button
var _evasive_stance_btn: Button
var _cycle_button: Button
var _execute_button: Button
var _exit_button: Button

var _nav_buttons: Array[Button] = []

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var root_vbox := VBoxContainer.new()
    root_vbox.add_theme_constant_override("separation", 6)
    add_child(root_vbox)

    # ROW 1: Identity, HP, Telemetry, and Target Solution
    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 12)
    root_vbox.add_child(top_row)

    # Unit & Pilot Identity
    var unit_box := HBoxContainer.new()
    unit_box.add_theme_constant_override("separation", 6)
    top_row.add_child(unit_box)

    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 14)
    _title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
    unit_box.add_child(_title)

    _pilot_label = Label.new()
    _pilot_label.add_theme_font_size_override("font_size", 12)
    _pilot_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
    unit_box.add_child(_pilot_label)

    # HP Bar
    var hp_box := HBoxContainer.new()
    hp_box.add_theme_constant_override("separation", 4)
    top_row.add_child(hp_box)

    var hp_lbl := Label.new()
    hp_lbl.text = "HULL:"
    hp_lbl.add_theme_font_size_override("font_size", 11)
    hp_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
    hp_box.add_child(hp_lbl)

    _hp_bar = ProgressBar.new()
    _hp_bar.custom_minimum_size = Vector2(85, 12)
    _hp_bar.show_percentage = false
    hp_box.add_child(_hp_bar)

    _hp_val = Label.new()
    _hp_val.add_theme_font_size_override("font_size", 11)
    _hp_val.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
    hp_box.add_child(_hp_val)

    # Telemetry
    _telemetry_label = Label.new()
    _telemetry_label.add_theme_font_size_override("font_size", 11)
    _telemetry_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
    top_row.add_child(_telemetry_label)

    # Facing Armor Diagram Pill (Bow, Flanks, Stern)
    var armor_pill := Label.new()
    armor_pill.text = "ARMOR [BOW: 100% | PORT: 85% | STBD: 85% | STERN: 60%]"
    armor_pill.add_theme_font_size_override("font_size", 10)
    armor_pill.add_theme_color_override("font_color", Color(0.35, 0.95, 0.85))
    top_row.add_child(armor_pill)

    var spacer_top := Control.new()
    spacer_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(spacer_top)

    # Target Solution Info
    var target_pill_box := HBoxContainer.new()
    target_pill_box.add_theme_constant_override("separation", 6)
    top_row.add_child(target_pill_box)

    _target_banner = Label.new()
    _target_banner.add_theme_font_size_override("font_size", 12)
    _target_banner.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
    target_pill_box.add_child(_target_banner)

    _target_solution_pill = Label.new()
    _target_solution_pill.add_theme_font_size_override("font_size", 12)
    target_pill_box.add_child(_target_solution_pill)

    # ROW 2: Tactical Steering, Combat Stance, and Execute Round
    var bottom_row := HBoxContainer.new()
    bottom_row.add_theme_constant_override("separation", 8)
    root_vbox.add_child(bottom_row)

    # 1. Fine Steering Group (Yaw, Pitch, Throttle)
    var steer_group := HBoxContainer.new()
    steer_group.add_theme_constant_override("separation", 4)
    bottom_row.add_child(steer_group)

    var climb_btn := _create_btn("▲ CLIMB [Q/UP]", func() -> void: pitch_up.emit())
    steer_group.add_child(climb_btn)
    _nav_buttons.append(climb_btn)

    var dive_btn := _create_btn("▼ DIVE [E/DN]", func() -> void: pitch_down.emit())
    steer_group.add_child(dive_btn)
    _nav_buttons.append(dive_btn)

    var port_btn := _create_btn("◀ PORT [A]", func() -> void: yaw_left.emit())
    steer_group.add_child(port_btn)
    _nav_buttons.append(port_btn)

    var stbd_btn := _create_btn("STBD [D] ▶", func() -> void: yaw_right.emit())
    steer_group.add_child(stbd_btn)
    _nav_buttons.append(stbd_btn)

    var spd_down := _create_btn("- SPD [S]", func() -> void: speed_down.emit())
    steer_group.add_child(spd_down)
    _nav_buttons.append(spd_down)

    var spd_up := _create_btn("+ SPD [W]", func() -> void: speed_up.emit())
    steer_group.add_child(spd_up)
    _nav_buttons.append(spd_up)

    var stop_btn := _create_btn("STOP [X]", func() -> void: stop_pressed.emit())
    steer_group.add_child(stop_btn)
    _nav_buttons.append(stop_btn)

    var sep_actions := VSeparator.new()
    bottom_row.add_child(sep_actions)

    # 2. Combat Stance Toggle
    _fire_stance_btn = _create_btn("⌖ STANCE: ATTACK", func() -> void:
        if ship != null:
            ship.stance = Ship.Stance.FIRE
            stance_changed.emit(ship.stance)
            refresh()
    )
    bottom_row.add_child(_fire_stance_btn)

    _evasive_stance_btn = _create_btn("🛡 STANCE: EVASION (+35%)", func() -> void:
        if ship != null:
            ship.stance = Ship.Stance.EVASIVE
            stance_changed.emit(ship.stance)
            refresh()
    )
    bottom_row.add_child(_evasive_stance_btn)

    _cycle_button = _create_btn("CYCLE TARGET [C]", func() -> void: cycle_target_pressed.emit())
    bottom_row.add_child(_cycle_button)

    var intercept_btn := _create_btn("🎯 INTERCEPT [T]", func() -> void: intercept_pressed.emit())
    intercept_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    bottom_row.add_child(intercept_btn)

    var spacer_act := Control.new()
    spacer_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom_row.add_child(spacer_act)

    # 3. Main Execute Button
    _execute_button = _create_btn("▶ EXECUTE TACTICAL ROUND [SPACE]", func() -> void: execute_round_pressed.emit())
    _execute_button.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
    bottom_row.add_child(_execute_button)

    _exit_button = _create_btn("EXIT ACE", func() -> void: exit_pressed.emit())
    bottom_row.add_child(_exit_button)

    # ROW 3: Tactical Abilities & Action Points (from promotional mockup)
    var ability_row := HBoxContainer.new()
    ability_row.add_theme_constant_override("separation", 6)
    root_vbox.add_child(ability_row)

    var ap_lbl := Label.new()
    ap_lbl.text = "ACTION POINTS: [■ ■ ■ ■] 4/4"
    ap_lbl.add_theme_font_size_override("font_size", 10)
    ap_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
    ability_row.add_child(ap_lbl)

    var sep_ab := VSeparator.new()
    ability_row.add_child(sep_ab)

    var precision_btn := _create_btn("🎯 PRECISION VOLLEY (+25% HIT)", func() -> void:
        ability_used.emit("precision")
    )
    precision_btn.add_theme_font_size_override("font_size", 10)
    ability_row.add_child(precision_btn)

    var retro_btn := _create_btn("💨 RETRO-BRAKE (ARREST VELOCITY)", func() -> void:
        ability_used.emit("retro_brake")
    )
    retro_btn.add_theme_font_size_override("font_size", 10)
    ability_row.add_child(retro_btn)

    var shield_btn := _create_btn("🛡 SHIELD PULSE (+30 ABSORB)", func() -> void:
        ability_used.emit("shield_pulse")
    )
    shield_btn.add_theme_font_size_override("font_size", 10)
    ability_row.add_child(shield_btn)

func _process(_delta: float) -> void:
    refresh()

func refresh() -> void:
    var has_ship := ship != null
    var is_planning := TurnManager.phase == TurnManager.Phase.ACE_PLAN

    for btn in _nav_buttons:
        btn.disabled = not has_ship or not is_planning

    _fire_stance_btn.disabled = not has_ship or not is_planning
    _evasive_stance_btn.disabled = not has_ship or not is_planning
    _cycle_button.disabled = not has_ship or not is_planning
    _execute_button.disabled = not is_planning

    if not has_ship:
        _title.text = "NO SHIP SELECTED"
        _pilot_label.text = ""
        _telemetry_label.text = ""
        _target_banner.text = "TARGET: NONE"
        _target_solution_pill.text = "Select hostile by clicking in 3D or pressing [C]"
        return

    _title.text = "%s" % ship.ship_name
    _pilot_label.text = "[%s]" % (ship.pilot_name if ship.pilot_name != "" else ship.faction.to_upper())

    _hp_bar.max_value = ship.max_hp
    _hp_bar.value = ship.hp
    _hp_val.text = "%.0f/%.0f" % [ship.hp, ship.max_hp]

    var yaw_deg := roundi(rad_to_deg(ship.order.yaw))
    var pitch_deg := roundi(rad_to_deg(ship.order.pitch))
    _telemetry_label.text = "SPD: %.1f m/s (Cmd: %.1f) | HDG: %03d° | PITCH: %+d°" % [
        ship.speed(), ship.order.target_speed,
        posmod(yaw_deg, 360), pitch_deg
    ]

    # Stance button styling
    if ship.stance == Ship.Stance.FIRE:
        _fire_stance_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
        _evasive_stance_btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
    else:
        _fire_stance_btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
        _evasive_stance_btn.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))

    if target == null or target.is_destroyed():
        _target_banner.text = "TARGET: NONE"
        _target_solution_pill.text = "[CLICK HOSTILE IN 3D OR PRESS C]"
        _target_solution_pill.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
    else:
        var dist := ship.state.position.distance_to(target.state.position)
        var in_range := dist <= ship.weapon_range
        var in_arc := Combat.in_arc(ship, target)
        var can_hit := in_range and in_arc
        var hit_pct := roundi(Combat.hit_chance(ship, target) * 100.0)

        _target_banner.text = "LOCKED: %s [%.0fm]" % [target.ship_name, dist]

        if can_hit:
            _target_solution_pill.text = "● IN ARC & RANGE [%d%% HIT — %.0f DMG]" % [hit_pct, ship.weapon_damage]
            _target_solution_pill.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
        elif not in_range:
            _target_solution_pill.text = "▲ OUT OF RANGE (Need <= %.0fm)" % ship.weapon_range
            _target_solution_pill.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
        else:
            _target_solution_pill.text = "◀ OUT OF CONE (Align with [A/D])"
            _target_solution_pill.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

func _create_btn(text: String, callback: Callable) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.pressed.connect(callback)
    btn.focus_mode = Control.FOCUS_NONE
    return btn
