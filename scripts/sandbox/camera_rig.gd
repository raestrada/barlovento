class_name CameraRig
extends Node3D

@export var target: Vector3 = Vector3.ZERO
@export var distance: float = 60.0
@export var min_distance: float = 10.0
@export var max_distance: float = 300.0
@export var yaw_speed: float = 0.005
@export var pitch_speed: float = 0.005
@export var zoom_speed: float = 1.1
@export var pan_speed: float = 0.002
@export var min_pitch: float = 0.05
@export var max_pitch: float = PI - 0.05

var _yaw: float = 0.0
var _pitch: float = PI * 0.25

var _camera: Camera3D

func _ready() -> void:
    _camera = Camera3D.new()
    _camera.name = "Camera3D"
    _camera.current = true
    add_child(_camera)
    _build_backdrop()

func _build_backdrop() -> void:
    var backdrop := Sprite3D.new()
    backdrop.texture = load("res://assets/environments/space_backdrop.png")
    backdrop.shaded = false
    backdrop.pixel_size = 3.0
    backdrop.position = Vector3(0.0, 0.0, -1600.0)
    backdrop.modulate = Color(0.85, 0.9, 1.0, 0.9)
    _camera.add_child(backdrop)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            _yaw -= event.relative.x * yaw_speed
            _pitch -= event.relative.y * pitch_speed
            _pitch = clamp(_pitch, min_pitch, max_pitch)
        elif Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
            var basis := _camera.global_transform.basis
            var pan := distance * pan_speed
            target -= basis.x * event.relative.x * pan
            target += basis.y * event.relative.y * pan
    elif event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance = clamp(distance / zoom_speed, min_distance, max_distance)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance = clamp(distance * zoom_speed, min_distance, max_distance)

func _process(_delta: float) -> void:
    var offset := Vector3(
        distance * cos(_pitch) * sin(_yaw),
        distance * sin(_pitch),
        distance * cos(_pitch) * cos(_yaw)
    )
    _camera.global_position = target + offset
    _camera.look_at(target, Vector3.UP)
