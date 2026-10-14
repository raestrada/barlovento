class_name ShipOrder
extends RefCounted

var target_speed: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0

func heading() -> Vector3:
    var horizontal := Vector3.FORWARD.rotated(Vector3.UP, yaw)
    var right := horizontal.cross(Vector3.UP).normalized()
    if right.length_squared() < 0.001:
        right = Vector3.RIGHT
    return horizontal.rotated(right, pitch)
