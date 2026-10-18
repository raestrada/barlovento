class_name Combat

static func in_range(shooter: Ship, target: Ship) -> bool:
    if shooter == null or target == null:
        return false
    return shooter.state.position.distance_to(target.state.position) <= shooter.weapon_range

static func in_arc(shooter: Ship, target: Ship) -> bool:
    if shooter == null or target == null:
        return false
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

static func hit_chance(shooter: Ship, target: Ship) -> float:
    if not can_hit(shooter, target):
        return 0.0
    var chance := 1.0
    if target.is_evading:
        chance -= 0.35
    var dist := shooter.state.position.distance_to(target.state.position)
    var ratio := dist / maxf(shooter.weapon_range, 1.0)
    if ratio > 0.7:
        chance -= (ratio - 0.7) * 0.5
    return clampf(chance, 0.25, 1.0)

static func resolve_shot(shooter: Ship, target: Ship) -> Dictionary:
    var result := {
        "hit": false,
        "damage": 0.0,
        "destroyed": false,
        "shooter_name": shooter.ship_name if shooter != null else "Unknown",
        "target_name": target.ship_name if target != null else "Unknown",
        "critical": false,
        "evaded": false
    }

    if not can_hit(shooter, target):
        return result

    var chance := hit_chance(shooter, target)
    var roll := randf()

    if roll <= chance:
        result["hit"] = true
        var dmg := shooter.weapon_damage
        if randf() < 0.15:
            dmg *= 1.5
            result["critical"] = true
        result["damage"] = roundf(dmg)
        target.take_damage(result["damage"])

        match shooter.faction:
            "acero":
                AudioManager.play_sfx("laser_heavy", -4.0)
            "marea_libre":
                AudioManager.play_sfx("laser_cannon", -4.0)
            "vinculados":
                AudioManager.play_sfx("laser_pulse", -5.0)
            _:
                AudioManager.play_sfx("laser_heavy", -6.0)

        AudioManager.play_sfx("impact", -10.0)

        if target.is_destroyed():
            result["destroyed"] = true
            AudioManager.play_sfx("explosion", -4.0)
            AudioManager.play_sfx("explosion_big", -6.0)
    else:
        result["hit"] = false
        result["evaded"] = target.is_evading
        if shooter.faction == "vinculados":
            AudioManager.play_sfx("laser_pulse", -12.0)
        else:
            AudioManager.play_sfx("laser_heavy", -12.0)

    return result
