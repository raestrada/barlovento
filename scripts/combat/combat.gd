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
    if shooter.is_ability_active(4) or (shooter.has_meta("precision_boost") and bool(shooter.get_meta("precision_boost"))):
        chance += 0.30
    if shooter.overwatch_anchored:
        chance += 0.15
    if shooter.has_meta("crossfire_bonus"):
        chance += float(shooter.get_meta("crossfire_bonus"))
    if target.has_meta("evasion_boost"):
        chance -= float(target.get_meta("evasion_boost"))
    var syn := shooter.get_active_synergy()
    if bool(syn.get("active", false)):
        chance += float(syn.get("acc_bonus", 0.0))
    return clampf(chance, 0.15, 0.99)

static func resolve_shot(shooter: Ship, target: Ship) -> Dictionary:
    var quadrant := get_hit_quadrant(shooter, target)
    var barlovento := has_weather_gauge(shooter, target)
    var syn := shooter.get_active_synergy() if shooter != null else {"active": false}
    var result := {
        "hit": false,
        "damage": 0.0,
        "destroyed": false,
        "shooter_name": shooter.ship_name if shooter != null else "Unknown",
        "target_name": target.ship_name if target != null else "Unknown",
        "critical": false,
        "evaded": false,
        "quadrant": quadrant,
        "weather_gauge": barlovento,
        "synergy_name": String(syn.get("name", ""))
    }

    if not can_hit(shooter, target):
        return result

    var chance := hit_chance(shooter, target)

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
                var bow_mult := 0.65 if target.faction == "acero" else 0.78
                dmg *= bow_mult
            "STERN":
                dmg *= 1.40
                result["critical"] = true
            "PORT", "STARBOARD":
                if shooter.faction == "marea_libre":
                    dmg *= 1.18

        var crit_chance := 0.15
        if shooter.is_ability_active(4) or (shooter.has_meta("precision_boost") and bool(shooter.get_meta("precision_boost"))):
            crit_chance += 0.25
        if shooter.has_meta("admiral_crit_bonus"):
            crit_chance += float(shooter.get_meta("admiral_crit_bonus"))
        if not result["critical"] and randf() < crit_chance:
            dmg *= 1.35
            result["critical"] = true

        if quadrant != "BOW" and shooter.has_meta("formation_flank_mult"):
            dmg *= float(shooter.get_meta("formation_flank_mult"))
        if target.has_meta("formation_armor_mult"):
            dmg /= maxf(float(target.get_meta("formation_armor_mult")), 0.1)

        # Tactical ability damage modifiers (Per-Ship Slot 3 Signature Strike & Slot 2 Defense)
        var salvo_type: String = String(shooter.get_meta("special_salvo", ""))
        var slot3_on := shooter.is_ability_active(3) or salvo_type != ""
        if slot3_on:
            match shooter.faction:
                "vinculados":
                    dmg *= 1.40
                "marea_libre":
                    dmg *= 1.35
                _:
                    dmg *= 1.45

        if bool(syn.get("active", false)):
            dmg *= float(syn.get("dmg_mult", 1.0))
            var shred := float(syn.get("armor_shred", 0.0))
            if shred > 0.0:
                target.armor_port = maxf(target.armor_port - shred, 5.0)
                target.armor_stbd = maxf(target.armor_stbd - shred, 5.0)

        if (target.is_ability_active(2) and target.faction == "acero") or (target.has_meta("prow_angle_active") and bool(target.get_meta("prow_angle_active"))):
            if quadrant == "BOW":
                dmg *= 0.55
            else:
                dmg *= 0.72
        if target.has_meta("armor_stance"):
            dmg *= clampf(float(target.get_meta("armor_stance")), 0.45, 1.0)
        if (target.is_ability_active(2) and target.faction == "vinculados") or (target.has_meta("i_field_active") and bool(target.get_meta("i_field_active"))):
            dmg *= 0.62

        # Directional Armor mitigation
        var armor_val := target.get_quadrant_armor(quadrant)
        if (slot3_on and shooter.faction == "vinculados") or (shooter.has_meta("resonance_pierce") and bool(shooter.get_meta("resonance_pierce"))):
            armor_val *= 0.35
        if bool(syn.get("active", false)) and float(syn.get("armor_pierce", 0.0)) > 0.0:
            armor_val *= (1.0 - clampf(float(syn.get("armor_pierce", 0.0)), 0.0, 1.0))
        var armor_factor := clampf(1.0 - (armor_val / 280.0), 0.58, 1.0)
        dmg *= armor_factor

        if (slot3_on and shooter.faction == "marea_libre") or (shooter.has_meta("chain_shot_active") and bool(shooter.get_meta("chain_shot_active"))):
            target.order.target_speed = maxf(target.order.target_speed - 4.0, 0.0)
            target.state.velocity *= 0.55

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

    var base_dmg := dmg
    var salvo_type: String = String(shooter.get_meta("special_salvo", ""))
    var slot3_on := shooter.is_ability_active(3) or salvo_type != ""
    if slot3_on:
        match shooter.faction:
            "vinculados":
                dmg *= 1.40
            "marea_libre":
                dmg *= 1.35
            _:
                dmg *= 1.45

    var syn := shooter.get_active_synergy()
    if bool(syn.get("active", false)):
        dmg *= float(syn.get("dmg_mult", 1.0))

    var armor_val := target.get_quadrant_armor(result["quadrant"])
    var base_armor_factor := clampf(1.0 - (armor_val / 280.0), 0.58, 1.0)
    base_dmg *= base_armor_factor

    if (slot3_on and shooter.faction == "vinculados") or (shooter.has_meta("resonance_pierce") and bool(shooter.get_meta("resonance_pierce"))):
        armor_val *= 0.35
    if bool(syn.get("active", false)) and float(syn.get("armor_pierce", 0.0)) > 0.0:
        armor_val *= (1.0 - clampf(float(syn.get("armor_pierce", 0.0)), 0.0, 1.0))
    var armor_factor := clampf(1.0 - (armor_val / 280.0), 0.58, 1.0)
    dmg *= armor_factor

    result["base_damage"] = maxf(roundf(base_dmg), 4.0)
    result["projected_damage"] = maxf(roundf(dmg), 4.0)
    result["synergy_name"] = String(syn.get("name", ""))
    result["status_text"] = "FIRING SOLUTION LOCKED"
    return result

