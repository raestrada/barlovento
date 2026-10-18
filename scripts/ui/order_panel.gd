class_name OrderPanel
extends PanelContainer

signal order_changed
signal intercept_pressed

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

    # Row 1: Identity, Speed, Heading, Drift, Thrust
    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 10)
    vbox.add_child(top_row)

    _name_label = Label.new()
    _name_label.add_theme_font_size_override("font_size", 14)
    _name_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
    top_row.add_child(_name_label)

    _faction_badge = Label.new()
    _faction_badge.add_theme_font_size_override("font_size", 11)
    _faction_badge.add_theme_color_override("font_color", Color(0.35, 0.85, 0.95))
    top_row.add_child(_faction_badge)

    var sep1 := VSeparator.new()
    top_row.add_child(sep1)

    var spd_lbl := Label.new()
    spd_lbl.text = "SPD:"
    spd_lbl.add_theme_font_size_override("font_size", 11)
    spd_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
    top_row.add_child(spd_lbl)

    _speed_gauge = ProgressBar.new()
    _speed_gauge.custom_minimum_size = Vector2(90, 12)
    _speed_gauge.show_percentage = false
    top_row.add_child(_speed_gauge)

    _speed_val_label = Label.new()
    _speed_val_label.add_theme_font_size_override("font_size", 11)
    _speed_val_label.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
    top_row.add_child(_speed_val_label)

    var sep2 := VSeparator.new()
    top_row.add_child(sep2)

    _heading_label = Label.new()
    _heading_label.add_theme_font_size_override("font_size", 11)
    _heading_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    top_row.add_child(_heading_label)

    _pitch_label = Label.new()
    _pitch_label.add_theme_font_size_override("font_size", 11)
    _pitch_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
    top_row.add_child(_pitch_label)

    _drift_label = Label.new()
    _drift_label.add_theme_font_size_override("font_size", 11)
    _drift_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.95))
    top_row.add_child(_drift_label)

    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(spacer)

    _thrust_status = Label.new()
    _thrust_status.add_theme_font_size_override("font_size", 11)
    top_row.add_child(_thrust_status)

    # Row 2: Steering & Throttle Controls
    var bottom_row := HBoxContainer.new()
    bottom_row.add_theme_constant_override("separation", 6)
    vbox.add_child(bottom_row)

    var stop_btn := _create_btn("STOP [X]", _on_stop)
    bottom_row.add_child(stop_btn)

    var spd_down := _create_btn("- SPD [S]", _on_speed_down)
    bottom_row.add_child(spd_down)

    var spd_up := _create_btn("+ SPD [W]", _on_speed_up)
    bottom_row.add_child(spd_up)

    var flank_btn := _create_btn("FLANK", _on_flank)
    bottom_row.add_child(flank_btn)

    var sep3 := VSeparator.new()
    bottom_row.add_child(sep3)

    var port_btn := _create_btn("◀ PORT [A]", _on_yaw_left)
    bottom_row.add_child(port_btn)

    var stbd_btn := _create_btn("STBD [D] ▶", _on_yaw_right)
    bottom_row.add_child(stbd_btn)

    var climb_btn := _create_btn("▲ CLIMB [Q]", _on_pitch_up)
    bottom_row.add_child(climb_btn)

    var dive_btn := _create_btn("▼ DIVE [E]", _on_pitch_down)
    bottom_row.add_child(dive_btn)

    var sep4 := VSeparator.new()
    bottom_row.add_child(sep4)

    var intercept_btn := _create_btn("🎯 INTERCEPT [T]", func() -> void: intercept_pressed.emit())
    intercept_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
    bottom_row.add_child(intercept_btn)

func _process(_delta: float) -> void:
    refresh()

func refresh() -> void:
    if ship == null:
        visible = false
        return
    visible = true

    _name_label.text = "%s [%s]" % [ship.ship_name, ship.pilot_name] if ship.pilot_name != "" else ship.ship_name
    _faction_badge.text = "[%s]" % ship.faction.to_upper()

    var cur_speed := ship.speed()
    var max_spd := ship.state.max_speed
    _speed_gauge.max_value = max_spd
    _speed_gauge.value = cur_speed
    _speed_val_label.text = "%.1f/%.1f m/s (Cmd: %.1f)" % [cur_speed, max_spd, ship.order.target_speed]

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
        _thrust_status.text = "● BRAKING TO STOP"
        _thrust_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
    elif cur_speed < ship.order.target_speed - 0.2:
        _thrust_status.text = "▲ ACCELERATING"
        _thrust_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
    elif cur_speed > ship.order.target_speed + 0.2:
        _thrust_status.text = "▼ RETROGRADE BRAKE"
        _thrust_status.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
    else:
        _thrust_status.text = "◆ STEADY CRUISE"
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
        ship.order.pitch = clampf(ship.order.pitch + deg_to_rad(10.0), -1.45, 1.45)
        order_changed.emit()

func _on_pitch_down() -> void:
    if ship != null:
        ship.order.pitch = clampf(ship.order.pitch - deg_to_rad(10.0), -1.45, 1.45)
        order_changed.emit()
