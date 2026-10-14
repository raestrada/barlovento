class_name EtherField
extends RefCounted

var direction: Vector3 = Vector3.RIGHT
var strength: float = 0.0
var wavelength: float = 100.0

func current_at(position: Vector3) -> Vector3:
    if strength == 0.0:
        return Vector3.ZERO
    var horizontal := direction * strength * sin(position.x / wavelength) * cos(position.z / wavelength)
    var vertical := Vector3.UP * strength * 0.35 * sin(position.y / (wavelength * 0.4))
    return horizontal + vertical
