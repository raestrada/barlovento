class_name ShipState
extends RefCounted

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var forward: Vector3 = Vector3.FORWARD
var mass: float = 1.0
var max_thrust: float = 0.0
var brake_thrust: float = 0.0
var turn_power: float = 0.0
var max_speed: float = 0.0

func speed() -> float:
    return velocity.length()
