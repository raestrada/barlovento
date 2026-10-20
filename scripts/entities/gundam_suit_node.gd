class_name GundamSuitNode
extends Node3D

@export var phase_offset: float = 0.0
@export var sway_amplitude: float = 0.07
@export var bank_amplitude: float = 1.8

var _base_pos: Vector3 = Vector3.ZERO
var _base_rot: Vector3 = Vector3.ZERO
var _time: float = 0.0

func _ready() -> void:
    _base_pos = position
    _base_rot = rotation_degrees
    _time = phase_offset

func _process(delta: float) -> void:
    _time += delta
    # Zero-G micro-hovering in formation
    position.y = _base_pos.y + sin(_time * 1.9) * sway_amplitude
    position.x = _base_pos.x + cos(_time * 1.4) * (sway_amplitude * 0.45)
    # Attitude micro-adjustments & subtle vernier banking
    rotation_degrees.z = _base_rot.z + sin(_time * 1.6) * bank_amplitude
    rotation_degrees.x = _base_rot.x + cos(_time * 2.1) * (bank_amplitude * 0.6)
