class_name OrderPanel
extends PanelContainer

signal order_changed

const SPEED_STEP := 2.0
const ANGLE_STEP_DEG := 15.0

var ship: Ship:
    set(value):
        ship = value
        refresh()

var _name_label: Label
var _faction_badge: Label
var _speed_gauge: ProgressBar
var _speed_val_label: Label
var _drift_label: Label
var _heading_label: Label
var _pitch_label: Label
var _thrust_status: Label

func _ready() -> void:
    _build_ui()

func _build_ui() -> void:
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 6)
    add_child(vbox)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    vbox.add_child(header)

    _name_label = Label.new()
    _name_label.add_theme_font_size_override("font_size", 16)
    _name_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
    header.add_child(_name_label)

    _faction_badge = Label.new()
    _faction_badge.add_theme_font_size_override("font_size", 12)
    _faction_badge.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95))
    header.add_child(_faction_badge)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)

    _thrust_status = Label.new()
    _thrust_status.add_theme_font_size_override("font_size", 12)
    header.add_child(_thrust_status)

    var speed_row := HBoxContainer.new()
    speed_row.add_theme_constant_override("separation", 8)
    vbox.add_child(speed_row)

    var spd_lbl := Label.new()
    spd_lbl.text = "SPEED:"
    spd_lbl.add_theme_font_size_override("font_size", 13)
    spd_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
    speed_row.add_child(spd_lbl)

    _speed_gauge = ProgressBar.new()
    _speed_gauge.custom_minimum_size = Vector2(140, 16)
    _speed_gauge.show_percentage = false
    speed_row.add_child(_speed_gauge)

    _speed_val_label = Label.new()
    _speed_val_label.add_theme_font_size_override("font_size", 13)
    _speed_val_label.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
    speed_row.add_child(_speed_val_label)

    var btn_row := HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 6)
    vbox.add_child(btn_row)

    var stop_btn := _create_btn("STOP [X]", _on_stop)
    btn_row.add_child(stop_btn)

    var spd_down := _create_btn("- SPD [S]", _on_speed_down)
    btn_row.add_child(spd_down)

    var spd_up := _create_btn("+ SPD [W]", _on_speed_up)
    btn_row.add_child(spd_up)

    var flank_btn := _create_btn("FLANK", _on_flank)
    btn_row.add_child(flank_btn)

    var nav_row := HBoxContainer.new()
    nav_row.add_theme_constant_override("separation", 8)
    vbox.add_child(nav_row)

    var port_btn := _create_btn("◀ PORT [A]", _on_yaw_left)
    nav_row.add_child(port_btn)

    var stbd_btn := _create_btn("STBD [D] ▶", _on_yaw_right)
    nav_row.add_child(stbd_btn)

    var climb_btn := _create_btn("▲ CLIMB [Q]", _on_pitch_up)
    nav_row.add_child(climb_btn)

    var dive_btn := _create_btn("▼ DIVE [E]", _on_pitch_down)
    nav_row.add_child(dive_btn)

    var telemetry_row := HBoxContainer.new()
    telemetry_row.add_theme_constant_override("separation", 14)
    vbox.add_child(telemetry_row)

    _heading_label = Label.new()
    _heading_label.add_theme_font_size_override("font_size", 13)
    _heading_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    telemetry_row.add_child(_heading_label)

    _pitch_label = Label.new()
    _pitch_label.add_theme_font_size_override("font_size", 13)
    _pitch_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    telemetry_row.add_child(_pitch_label)

    _drift_label = Label.new()
    _drift_label.add_theme_font_size_override("font_size", 13)
    _drift_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.95))
    telemetry_row.add_child(_drift_label)

func _process(_delta: float) -> void:
    refresh()

func refresh() -> void:
    if ship == null:
        visible = false
        return
    visible = true

    _name_label.text = ship.ship_name
    _faction_badge.text = "[%s]" % ship.faction.to_upper()

    var cur_speed := ship.speed()
    var max_spd := ship.state.max_speed
    _speed_gauge.max_value = max_spd
    _speed_gauge.value = cur_speed
    _speed_val_label.text = "%.1f / %.1f m/s  (Cmd: %.1f)" % [cur_speed, max_spd, ship.order.target_speed]

    var yaw_deg := roundi(rad_to_deg(ship.order.yaw))
    var pitch_deg := roundi(rad_to_deg(ship.order.pitch))
    _heading_label.text = "HDG: %03d°" % posmod(yaw_deg, 360)
    _pitch_label.text = "PITCH: %+d°" % pitch_deg

    var cur_vel := ship.state.velocity
    if cur_vel.length_squared() > 0.05:
        var heading_flat := Vector3(ship.order.heading().x, 0.0, ship.order.heading().z).normalized()
        var vel_flat := Vector3(cur_vel.x, 0.0, cur_vel.z).normalized()
        var drift_angle := roundi(rad_to_deg(heading_flat.signed_angle_to(vel_flat, Vector3.UP)))
        _drift_label.text = "DRIFT: %+d°" % drift_angle
    else:
        _drift_label.text = "DRIFT: 0°"

    if ship.order.target_speed == 0.0:
        _thrust_status.text = "BRAKING TO STOP"
        _thrust_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
    elif cur_speed < ship.order.target_speed - 0.2:
        _thrust_status.text = "ACCELERATING"
        _thrust_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
    elif cur_speed > ship.order.target_speed + 0.2:
        _thrust_status.text = "RETROGRADE BRAKING"
        _thrust_status.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
    else:
        _thrust_status.text = "STEADY CRUISE"
        _thrust_status.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))

func _create_btn(text: String, callback: Callable) -> Button:
    var btn := Button.new()
    btn.text = text
    btn.pressed.connect(callback)
    btn.focus_mode = Control.FOCUS_NONE
    return btn

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

func _on_flank() -> void:
    if ship != null:
        ship.order.target_speed = ship.state.max_speed
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
        ship.order.pitch = clampf(ship.order.pitch + deg_to_rad(ANGLE_STEP_DEG), -1.45, 1.45)
        order_changed.emit()

func _on_pitch_down() -> void:
    if ship != null:
        ship.order.pitch = clampf(ship.order.pitch - deg_to_rad(ANGLE_STEP_DEG), -1.45, 1.45)
        order_changed.emit()
