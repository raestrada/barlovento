class_name Combat

static func in_range(shooter: Ship, target: Ship) -> bool:
    return shooter.state.position.distance_to(target.state.position) <= shooter.weapon_range

static func in_arc(shooter: Ship, target: Ship) -> bool:
    var to_target := target.state.position - shooter.state.position
    to_target.y = 0.0
    if to_target.length_squared() < 0.0001:
        return true
    var angle := shooter.state.forward.signed_angle_to(to_target.normalized(), Vector3.UP)
    return absf(angle) <= deg_to_rad(shooter.weapon_arc_degrees) * 0.5

static func can_hit(shooter: Ship, target: Ship) -> bool:
    if target == null or target.is_destroyed():
        return false
    return in_range(shooter, target) and in_arc(shooter, target)

static func resolve_shot(shooter: Ship, target: Ship) -> void:
    target.take_damage(shooter.weapon_damage)
    AudioManager.play_sfx("laser", -8.0)
    if target.is_destroyed():
        AudioManager.play_sfx("explosion", -4.0)
