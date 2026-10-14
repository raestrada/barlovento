class_name OrderPanel
extends VBoxContainer

const SPEED_STEP := 2.0

var ship: Ship

var _info_label: Label
var _order_label: Label

func _ready() -> void:
    _info_label = Label.new()
    _info_label.add_theme_font_size_override("font_size", 18)
    add_child(_info_label)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    add_child(row)

    var speed_down := Button.new()
    speed_down.text = "Speed -"
    speed_down.pressed.connect(_on_speed_down)
    row.add_child(speed_down)

    var speed_up := Button.new()
    speed_up.text = "Speed +"
    speed_up.pressed.connect(_on_speed_up)
    row.add_child(speed_up)

    var stop := Button.new()
    stop.text = "Stop"
    stop.pressed.connect(_on_stop)
    row.add_child(stop)

    _order_label = Label.new()
    _order_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    add_child(_order_label)

func _process(_delta: float) -> void:
    refresh()

func refresh() -> void:
    if ship == null:
        _info_label.text = "No ship selected"
        _order_label.text = ""
        return
    _info_label.text = "%s\nSpeed %.1f / %.1f" % [ship.ship_name, ship.speed(), ship.state.max_speed]
    _order_label.text = "Target: %.1f   Heading: %+d°   Pitch: %+d°" % [
        ship.order.target_speed,
        roundi(rad_to_deg(ship.order.yaw)),
        roundi(rad_to_deg(ship.order.pitch))
    ]

func _on_speed_down() -> void:
    if ship == null:
        return
    ship.order.target_speed = clampf(ship.order.target_speed - SPEED_STEP, 0.0, ship.state.max_speed)

func _on_speed_up() -> void:
    if ship == null:
        return
    ship.order.target_speed = clampf(ship.order.target_speed + SPEED_STEP, 0.0, ship.state.max_speed)

func _on_stop() -> void:
    if ship == null:
        return
    ship.order.target_speed = 0.0
