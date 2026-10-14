class_name CameraRig
extends Node3D

@export var target: Vector3 = Vector3.ZERO
@export var distance: float = 65.0
@export var min_distance: float = 12.0
@export var max_distance: float = 350.0
@export var yaw_speed: float = 0.005
@export var pitch_speed: float = 0.005
@export var zoom_speed: float = 1.15
@export var pan_speed: float = 0.0018
@export var min_pitch: float = -1.52
@export var max_pitch: float = 1.52

var _yaw: float = 0.0
var _pitch: float = PI * 0.22
var _target_yaw: float = 0.0
var _target_pitch: float = PI * 0.22
var _target_distance: float = 65.0
var _target_position: Vector3 = Vector3.ZERO

var _camera: Camera3D

func _ready() -> void:
    _camera = Camera3D.new()
    _camera.name = "Camera3D"
    _camera.current = true
    _camera.fov = 55.0
    add_child(_camera)

    _target_position = target
    _target_distance = distance
    _target_yaw = _yaw
    _target_pitch = _pitch

func focus_on(pos: Vector3) -> void:
    _target_position = pos

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            _target_yaw -= event.relative.x * yaw_speed
            _target_pitch -= event.relative.y * pitch_speed
            _target_pitch = clamp(_target_pitch, min_pitch, max_pitch)
        elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            _pan(event.relative)
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _target_distance = clamp(_target_distance / zoom_speed, min_distance, max_distance)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _target_distance = clamp(_target_distance * zoom_speed, min_distance, max_distance)

func _pan(relative: Vector2) -> void:
    var basis := _camera.global_transform.basis
    var pan := _target_distance * pan_speed
    _target_position -= basis.x * relative.x * pan
    _target_position += basis.y * relative.y * pan

func _process(delta: float) -> void:
    var smooth := clampf(delta * 10.0, 0.01, 1.0)
    target = target.lerp(_target_position, smooth)
    distance = lerpf(distance, _target_distance, smooth)
    _yaw = lerpf(_yaw, _target_yaw, smooth)
    _pitch = lerpf(_pitch, _target_pitch, smooth)

    var offset := Vector3(
        distance * cos(_pitch) * sin(_yaw),
        distance * sin(_pitch),
        distance * cos(_pitch) * cos(_yaw)
    )
    var cam_pos := target + offset
    _camera.global_position = cam_pos

    var forward := target - cam_pos
    if forward.length_squared() > 0.0001:
        forward = forward.normalized()
    else:
        forward = Vector3.FORWARD

    var right := forward.cross(Vector3.UP)
    if right.length_squared() < 0.0001:
        right = Vector3.RIGHT
    else:
        right = right.normalized()
    var up := right.cross(forward).normalized()

    _camera.global_transform.basis = Basis(right, up, -forward)
