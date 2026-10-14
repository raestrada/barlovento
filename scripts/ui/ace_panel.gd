class_name AcePanel
extends VBoxContainer

signal move_pressed
signal shoot_pressed
signal cycle_pressed
signal end_pressed
signal exit_pressed

var active_ship: Ship
var target: Ship

var _title: Label
var _status: Label
var _target: Label
var _move_button: Button
var _cycle_button: Button
var _shoot_button: Button
var _end_button: Button

func _ready() -> void:
    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 18)
    add_child(_title)

    _status = Label.new()
    add_child(_status)

    _target = Label.new()
    _target.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
    add_child(_target)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    add_child(row)

    _move_button = Button.new()
    _move_button.text = "Move (M)"
    _move_button.pressed.connect(func() -> void: move_pressed.emit())
    row.add_child(_move_button)

    _cycle_button = Button.new()
    _cycle_button.text = "Cycle (C)"
    _cycle_button.pressed.connect(func() -> void: cycle_pressed.emit())
    row.add_child(_cycle_button)

    _shoot_button = Button.new()
    _shoot_button.text = "Shoot (F)"
    _shoot_button.pressed.connect(func() -> void: shoot_pressed.emit())
    row.add_child(_shoot_button)

    _end_button = Button.new()
    _end_button.text = "End (E)"
    _end_button.pressed.connect(func() -> void: end_pressed.emit())
    row.add_child(_end_button)

    var exit_button := Button.new()
    exit_button.text = "Exit"
    exit_button.pressed.connect(func() -> void: exit_pressed.emit())
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
        _title.text = ""
        _status.text = ""
        _target.text = ""
        return

    _title.text = "%s  [%d AP]" % [active_ship.ship_name, TurnManager.ace_actions_left()]
    _status.text = "HP %.0f/%.0f   Speed %.1f" % [active_ship.hp, active_ship.max_hp, active_ship.speed()]

    if target == null:
        _target.text = "No target"
    else:
        var can_hit := Combat.can_hit(active_ship, target)
        _target.text = "Target: %s  %s" % [target.ship_name, "IN RANGE/ARC" if can_hit else "OUT OF RANGE/ARC"]
