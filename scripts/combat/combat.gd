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

static func has_weather_gauge(shooter: Ship, target: Ship) -> bool:
    if shooter == null or target == null:
        return false
    if shooter.has_meta("admiral_barlovento") and bool(shooter.get_meta("admiral_barlovento")):
        return true
    if shooter.ether == null:
        return false
    var to_target := target.state.position - shooter.state.position
    if to_target.length_squared() < 0.01:
        return false
    return to_target.normalized().dot(shooter.ether.direction.normalized()) > 0.22

static func can_hit(shooter: Ship, target: Ship) -> bool:
    if target == null or target.is_destroyed():
        return false
    return in_range(shooter, target) and in_arc(shooter, target)

static func hit_chance(shooter: Ship, target: Ship) -> float:
    if shooter != null and shooter.is_player and DevManager.god_mode:
        return 1.0
    if target != null and target.is_player and DevManager.god_mode:
        return 0.0
    if not can_hit(shooter, target):
        return 0.0
    var chance := 0.92
    if shooter.has_meta("tutorial_enemy") and bool(shooter.get_meta("tutorial_enemy")):
        chance = 0.70  # Forgiving baseline for tutorial training opponents
    if target.is_evading or target.stance == Ship.Stance.EVASIVE or (target.has_meta("evasive_boost") and bool(target.get_meta("evasive_boost"))):
        chance -= 0.35
    if target.has_meta("flak_screen_active") and bool(target.get_meta("flak_screen_active")):
        chance -= 0.25
    var dist := shooter.state.position.distance_to(target.state.position)
    var ratio := dist / maxf(shooter.weapon_range, 1.0)
    if ratio > 0.72:
        chance -= (ratio - 0.72) * 0.45
    if has_weather_gauge(shooter, target):
        chance += 0.12
    if shooter.has_meta("precision_boost") and bool(shooter.get_meta("precision_boost")):
        chance += 0.25
    return clampf(chance, 0.15, 0.99)

static func resolve_shot(shooter: Ship, target: Ship) -> Dictionary:
    var quadrant := get_hit_quadrant(shooter, target)
    var barlovento := has_weather_gauge(shooter, target)
    var result := {
        "hit": false,
        "damage": 0.0,
        "destroyed": false,
        "shooter_name": shooter.ship_name if shooter != null else "Unknown",
        "target_name": target.ship_name if target != null else "Unknown",
        "critical": false,
        "evaded": false,
        "quadrant": quadrant,
        "weather_gauge": barlovento
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
        if shooter != null and shooter.is_player and DevManager.god_mode:
            dmg *= 3.5
            result["critical"] = true

        # Barlovento (Weather-Gauge) Upwind Tactical Bonus (+15% Damage)
        if barlovento:
            dmg *= 1.15

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

        if quadrant != "BOW" and shooter.has_meta("formation_flank_mult"):
            dmg *= float(shooter.get_meta("formation_flank_mult"))
        if target.has_meta("formation_armor_mult"):
            dmg /= maxf(float(target.get_meta("formation_armor_mult")), 0.1)

        # Tactical ability damage modifiers
        if shooter.has_meta("broadside_active") and bool(shooter.get_meta("broadside_active")):
            dmg *= 1.25
        if shooter.has_meta("resonance_pierce") and bool(shooter.get_meta("resonance_pierce")):
            dmg *= 1.30
        if target.has_meta("prow_angle_active") and bool(target.get_meta("prow_angle_active")) and quadrant == "BOW":
            dmg *= 0.60

        # Directional Armor mitigation: intact heavy plate absorbs kinetic & thermal impact
        var armor_val := target.get_quadrant_armor(quadrant)
        if shooter.has_meta("resonance_pierce") and bool(shooter.get_meta("resonance_pierce")):
            armor_val *= 0.5
        var armor_factor := clampf(1.0 - (armor_val / 280.0), 0.58, 1.0)
        dmg *= armor_factor

        if shooter.has_meta("chain_shot_active") and bool(shooter.get_meta("chain_shot_active")):
            target.order.target_speed = maxf(target.order.target_speed - 3.5, 0.0)

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

static func predict_fire_solution(shooter: Ship, target: Ship) -> Dictionary:
    var result := {
        "can_fire": false,
        "in_range": false,
        "in_arc": false,
        "hit_chance": 0.0,
        "quadrant": "BOW",
        "weather_gauge": false,
        "critical": false,
        "projected_damage": 0.0,
        "status_text": "NO TARGET"
    }
    if shooter == null or target == null or target.is_destroyed():
        return result

    result["in_range"] = in_range(shooter, target)
    result["in_arc"] = in_arc(shooter, target)
    result["can_fire"] = result["in_range"] and result["in_arc"]
    result["quadrant"] = get_hit_quadrant(shooter, target)
    result["weather_gauge"] = has_weather_gauge(shooter, target)
    result["critical"] = (result["quadrant"] == "STERN")

    if not result["can_fire"]:
        if not result["in_range"]:
            var dist := shooter.state.position.distance_to(target.state.position)
            result["status_text"] = "OUT OF RANGE (%.0fm / %.0fm)" % [dist, shooter.weapon_range]
        elif not result["in_arc"]:
            result["status_text"] = "BEARING MISALIGNED [OUT OF ARC]"
        return result

    var chance := hit_chance(shooter, target)
    result["hit_chance"] = chance

    var dmg := shooter.weapon_damage
    if result["weather_gauge"]:
        dmg *= 1.15

    match result["quadrant"]:
        "BOW":
            var bow_mult := 0.65 if target.faction == "acero" else 0.78
            dmg *= bow_mult
        "STERN":
            dmg *= 1.40
        "PORT", "STARBOARD":
            if shooter.faction == "marea_libre":
                dmg *= 1.18

    if shooter.has_meta("resonance_pierce") and bool(shooter.get_meta("resonance_pierce")):
        var armor_val := target.get_quadrant_armor(result["quadrant"]) * 0.5
        var armor_factor := clampf(1.0 - (armor_val / 280.0), 0.75, 1.0)
        dmg *= armor_factor * 1.30
    else:
        var armor_val := target.get_quadrant_armor(result["quadrant"])
        var armor_factor := clampf(1.0 - (armor_val / 280.0), 0.58, 1.0)
        dmg *= armor_factor

    result["projected_damage"] = maxf(roundf(dmg), 4.0)
    result["status_text"] = "FIRING SOLUTION LOCKED"
    return result

