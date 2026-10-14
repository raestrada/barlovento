class_name AcePanel
extends PanelContainer

signal move_pressed
signal shoot_pressed
signal cycle_pressed
signal end_pressed
signal exit_pressed

var active_ship: Ship
var target: Ship

var _title: Label
var _ap_label: Label
var _hp_bar: ProgressBar
var _hp_val: Label
var _target_name: Label
var _target_range: Label
var _target_solution: Label
var _move_button: Button
var _cycle_button: Button
var _shoot_button: Button
var _end_button: Button

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 6)
    add_child(vbox)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 8)
    vbox.add_child(header)

    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 16)
    _title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    header.add_child(_title)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)

    _ap_label = Label.new()
    _ap_label.add_theme_font_size_override("font_size", 16)
    _ap_label.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
    header.add_child(_ap_label)

    var hp_row := HBoxContainer.new()
    hp_row.add_theme_constant_override("separation", 8)
    vbox.add_child(hp_row)

    var hp_title := Label.new()
    hp_title.text = "HULL:"
    hp_title.add_theme_font_size_override("font_size", 12)
    hp_title.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
    hp_row.add_child(hp_title)

    _hp_bar = ProgressBar.new()
    _hp_bar.custom_minimum_size = Vector2(120, 14)
    _hp_bar.show_percentage = false
    hp_row.add_child(_hp_bar)

    _hp_val = Label.new()
    _hp_val.add_theme_font_size_override("font_size", 12)
    hp_row.add_child(_hp_val)

    var tgt_box := VBoxContainer.new()
    tgt_box.add_theme_constant_override("separation", 2)
    vbox.add_child(tgt_box)

    var tgt_row := HBoxContainer.new()
    tgt_row.add_theme_constant_override("separation", 10)
    tgt_box.add_child(tgt_row)

    _target_name = Label.new()
    _target_name.add_theme_font_size_override("font_size", 14)
    _target_name.add_theme_color_override("font_color", Color(1.0, 0.5, 0.35))
    tgt_row.add_child(_target_name)

    _target_range = Label.new()
    _target_range.add_theme_font_size_override("font_size", 13)
    _target_range.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
    tgt_row.add_child(_target_range)

    _target_solution = Label.new()
    _target_solution.add_theme_font_size_override("font_size", 12)
    tgt_box.add_child(_target_solution)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    vbox.add_child(row)

    _move_button = _create_btn("BURN ENGINES [M]", func() -> void: move_pressed.emit())
    row.add_child(_move_button)

    _cycle_button = _create_btn("CYCLE TARGET [C]", func() -> void: cycle_pressed.emit())
    row.add_child(_cycle_button)

    _shoot_button = _create_btn("FIRE WEAPONS [F]", func() -> void: shoot_pressed.emit())
    row.add_child(_shoot_button)

    _end_button = _create_btn("END TURN [N]", func() -> void: end_pressed.emit())
    row.add_child(_end_button)

    var exit_button := _create_btn("EXIT TO FLEET", func() -> void: exit_pressed.emit())
    row.add_child(exit_button)

func _process(_delta: float) -> void:
    refresh()

func refresh() -> void:
    var has_ship := active_ship != null
    _move_button.disabled = not has_ship
    _cycle_button.disabled = not has_ship
    _shoot_button.disabled = not has_ship
    _end_button.disabled = not has_ship

    if not has_ship:
        _title.text = "NO ACE ACTIVE"
        _ap_label.text = ""
        _target_name.text = "No Target"
        _target_range.text = ""
        _target_solution.text = ""
        return

    _title.text = "ACE: %s" % active_ship.ship_name
    var ap := TurnManager.ace_actions_left()
    _ap_label.text = "ACTION POINTS: %s (%d)" % ["● ".repeat(ap), ap]

    _hp_bar.max_value = active_ship.max_hp
    _hp_bar.value = active_ship.hp
    _hp_val.text = "%.0f / %.0f" % [active_ship.hp, active_ship.max_hp]

    if target == null:
        _target_name.text = "TARGET: NONE"
        _target_range.text = ""
        _target_solution.text = "Cycle target with [C] or click an enemy"
        _shoot_button.disabled = true
    else:
        var dist := active_ship.state.position.distance_to(target.state.position)
        var in_range := dist <= active_ship.weapon_range
        var in_arc := Combat.in_arc(active_ship, target)
        var can_hit := in_range and in_arc

        _target_name.text = "LOCKED: %s" % target.ship_name
        _target_range.text = "RANGE: %.1f m  (Max: %.1f m)" % [dist, active_ship.weapon_range]

        if can_hit:
            _target_solution.text = "FIRING SOLUTION: OPTIMAL [READY TO FIRE]"
            _target_solution.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
            _shoot_button.disabled = false
        elif not in_range:
            _target_solution.text = "FIRING SOLUTION: OUT OF RANGE"
            _target_solution.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
            _shoot_button.disabled = true
        else:
            _target_solution.text = "FIRING SOLUTION: OUT OF WEAPON ARC (BEARING MISMATCH)"
            _target_solution.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
            _shoot_button.disabled = true

func _create_btn(text: String, callback: Callable) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.pressed.connect(callback)
    btn.focus_mode = Control.FOCUS_NONE
    return btn
