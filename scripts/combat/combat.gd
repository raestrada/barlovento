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
    var angle_deg := absf(rad_to_deg(shooter.state.forward.signed_angle_to(to_target.normalized(), Vector3.UP)))
    var in_front_cone := angle_deg <= (shooter.weapon_arc_degrees * 0.5)

    # Free Tide Galleons & Acero Capital Warships also mount Port/Starboard Broadside Batteries!
    if shooter.faction == "marea_libre" or shooter.ship_id == "acero_dreadnought" or shooter.ship_id == "acero_battlecruiser":
        var in_broadside := angle_deg >= 42.0 and angle_deg <= 138.0
        return in_front_cone or in_broadside

    return in_front_cone

static func get_hit_quadrant(shooter: Ship, target: Ship) -> String:
    if shooter == null or target == null:
        return "BOW"
    var incoming := shooter.state.position - target.state.position
    incoming.y = 0.0
    if incoming.length_squared() < 0.0001:
        return "BOW"
    var angle_deg := rad_to_deg(target.state.forward.signed_angle_to(incoming.normalized(), Vector3.UP))
    var abs_ang := absf(angle_deg)
    if abs_ang <= 48.0:
        return "BOW"
    elif abs_ang >= 132.0:
        return "STERN"
    elif angle_deg > 0.0:
        return "PORT"
    else:
        return "STARBOARD"

static func can_hit(shooter: Ship, target: Ship) -> bool:
    if target == null or target.is_destroyed():
        return false
    return in_range(shooter, target) and in_arc(shooter, target)

static func hit_chance(shooter: Ship, target: Ship) -> float:
    if not can_hit(shooter, target):
        return 0.0
    var chance := 0.92
    if target.is_evading or target.stance == Ship.Stance.EVASIVE:
        chance -= 0.30
    var dist := shooter.state.position.distance_to(target.state.position)
    var ratio := dist / maxf(shooter.weapon_range, 1.0)
    if ratio > 0.72:
        chance -= (ratio - 0.72) * 0.45
    if shooter.has_meta("precision_boost") and bool(shooter.get_meta("precision_boost")):
        chance += 0.25
    return clampf(chance, 0.25, 0.98)

static func resolve_shot(shooter: Ship, target: Ship) -> Dictionary:
    var quadrant := get_hit_quadrant(shooter, target)
    var result := {
        "hit": false,
        "damage": 0.0,
        "destroyed": false,
        "shooter_name": shooter.ship_name if shooter != null else "Unknown",
        "target_name": target.ship_name if target != null else "Unknown",
        "critical": false,
        "evaded": false,
        "quadrant": quadrant
    }

    if not can_hit(shooter, target):
        return result

    var chance := hit_chance(shooter, target)
    if shooter.has_meta("precision_boost"):
        shooter.set_meta("precision_boost", false)

    var roll := randf()
    if roll <= chance:
        result["hit"] = true
        var dmg := shooter.weapon_damage

        # Directional Armor Quadrant Modifiers (from docs/DESIGN.md)
        match quadrant:
            "BOW":
                # Sloped prow armor absorbs frontal kinetic impact
                var bow_mult := 0.65 if target.faction == "acero" else 0.78
                dmg *= bow_mult
            "STERN":
                # Stern Rake into exposed engine wake deals critical damage!
                dmg *= 1.40
                result["critical"] = true
            "PORT", "STARBOARD":
                # Broadside exchange
                if shooter.faction == "marea_libre":
                    dmg *= 1.18

        if not result["critical"] and randf() < 0.15:
            dmg *= 1.35
            result["critical"] = true

        result["damage"] = maxf(roundf(dmg), 4.0)
        target.take_directional_damage(result["damage"], quadrant)

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
        result["evaded"] = (target.is_evading or target.stance == Ship.Stance.EVASIVE)
        if shooter.faction == "vinculados":
            AudioManager.play_sfx("laser_pulse", -12.0)
        else:
            AudioManager.play_sfx("laser_heavy", -12.0)

    return result
