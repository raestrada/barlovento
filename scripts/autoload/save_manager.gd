extends Node

const RpgDefs = preload("res://scripts/data/rpg_defs.gd")
const LoreDBScript = preload("res://scripts/autoload/lore_db.gd")

const CAMPAIGN_SAVE_PATH := "user://barlovento_campaign.json"
const TACTICAL_SAVE_PATH := "user://barlovento_tactical_save.json"
const SETTINGS_PATH := "user://barlovento_settings.json"

signal tactical_saved(summary: String)
signal campaign_updated

var completed_stages: Dictionary = {}
var unlocked_stages: Dictionary = {
    "acero_stage_1": true,
    "vinculados_stage_1": true,
    "marea_stage_1": true,
}
var veteran_ranks: Dictionary = {}
var last_selected_faction: String = "acero"
var last_stage_id: String = "acero_stage_1"
var total_victories: int = 0
var total_kills: int = 0

# --- RPG PROGRESSION & ECONOMY ---
var eteron_credits: int = 1200
var pilot_skills: Dictionary = {} # pilot_name -> Array[String] (unlocked skill IDs)
var pilot_xp: Dictionary = {} # pilot_name -> Dictionary {level: int, xp: int, sp_available: int}
var fleet_upgrades: Dictionary = {} # ship_id -> Dictionary {armor_lvl: int, weapon_lvl: int, engine_lvl: int, subsystem: String}

var pending_load_battle: bool = false

func _ready() -> void:
    load_campaign()
    apply_settings(load_settings())

func save_campaign() -> void:
    var data := {
        "completed_stages": completed_stages,
        "unlocked_stages": unlocked_stages,
        "veteran_ranks": veteran_ranks,
        "last_selected_faction": last_selected_faction,
        "last_stage_id": last_stage_id,
        "total_victories": total_victories,
        "total_kills": total_kills,
        "eteron_credits": eteron_credits,
        "pilot_skills": pilot_skills,
        "pilot_xp": pilot_xp,
        "fleet_upgrades": fleet_upgrades,
        "timestamp": Time.get_datetime_string_from_system()
    }
    var file := FileAccess.open(CAMPAIGN_SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
    campaign_updated.emit()

func load_campaign() -> void:
    if not FileAccess.file_exists(CAMPAIGN_SAVE_PATH):
        return
    var file := FileAccess.open(CAMPAIGN_SAVE_PATH, FileAccess.READ)
    if file == null:
        return
    var txt := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(txt)
    if parsed is Dictionary:
        var d: Dictionary = parsed
        if d.has("completed_stages") and d["completed_stages"] is Dictionary:
            completed_stages = d["completed_stages"]
        if d.has("unlocked_stages") and d["unlocked_stages"] is Dictionary:
            for k in d["unlocked_stages"].keys():
                unlocked_stages[k] = d["unlocked_stages"][k]
        if d.has("veteran_ranks") and d["veteran_ranks"] is Dictionary:
            veteran_ranks = d["veteran_ranks"]
        if d.has("last_selected_faction"):
            last_selected_faction = str(d["last_selected_faction"])
        if d.has("last_stage_id"):
            last_stage_id = str(d["last_stage_id"])
        if d.has("total_victories"):
            total_victories = int(d["total_victories"])
        if d.has("total_kills"):
            total_kills = int(d["total_kills"])
        if d.has("eteron_credits"):
            eteron_credits = int(d["eteron_credits"])
        if d.has("pilot_skills") and d["pilot_skills"] is Dictionary:
            pilot_skills = d["pilot_skills"]
        if d.has("pilot_xp") and d["pilot_xp"] is Dictionary:
            pilot_xp = d["pilot_xp"]
        if d.has("fleet_upgrades") and d["fleet_upgrades"] is Dictionary:
            fleet_upgrades = d["fleet_upgrades"]

func get_veteran_rank(ship_id: String) -> int:
    return int(veteran_ranks.get(ship_id, 0))

func get_veteran_title(rank: int) -> String:
    match rank:
        0:
            return "REGULAR"
        1:
            return "★ VETERAN I"
        2:
            return "★★ VETERAN II"
        3:
            return "★★★ ELITE ACE"
        _:
            return "★★★★ LEGENDARY ACE"

func record_stage_victory(stage_id: String, surviving_ships: Array, enemies_destroyed: int = 3) -> String:
    completed_stages[stage_id] = true
    total_victories += 1
    total_kills += enemies_destroyed

    for s in surviving_ships:
        if s is String:
            var sid: String = s
            var cur_rank := get_veteran_rank(sid)
            veteran_ranks[sid] = mini(cur_rank + 1, 5)
        elif s != null and is_instance_valid(s) and not s.is_destroyed():
            var cur_rank := get_veteran_rank(s.ship_id)
            veteran_ranks[s.ship_id] = mini(cur_rank + 1, 5)

    var next_stage := get_next_stage_id(stage_id)
    if next_stage != "":
        unlocked_stages[next_stage] = true
        last_stage_id = next_stage
    save_campaign()
    return next_stage

# =============================================================================
# RPG ECONOMY & PROGRESSION METHODS
# =============================================================================

func award_battle_spoils(stage_id: String, surviving_ships: Array, enemies_destroyed: int = 3) -> Dictionary:
    var stage_num := 1
    var num_slice := stage_id.get_slice("_", 2)
    if num_slice.is_valid_int():
        stage_num = num_slice.to_int()

    var base_eteron := 450 + stage_num * 60
    var kill_bonus := enemies_destroyed * 80
    var survivor_bonus := surviving_ships.size() * 50
    var earned_eteron := base_eteron + kill_bonus + survivor_bonus
    eteron_credits += earned_eteron

    var earned_xp := 220 + stage_num * 40
    var promotions: Array[Dictionary] = []

    for s in surviving_ships:
        var p_name := ""
        if s is Ship and is_instance_valid(s):
            p_name = s.pilot_name
        elif s is String:
            var lore_node = get_node_or_null("/root/LoreDB")
            if lore_node != null and lore_node.has_method("get_ship"):
                var def = lore_node.get_ship(s)
                if def != null:
                    p_name = def.pilot_name
            else:
                var temp_lore = LoreDBScript.new()
                temp_lore._ready()
                var def = temp_lore.get_ship(s)
                if def != null:
                    p_name = def.pilot_name
        if p_name.is_empty():
            continue

        var p_data := get_pilot_data(p_name)
        var old_lvl: int = p_data["level"]
        var cur_xp: int = p_data["xp"] + earned_xp
        var new_lvl := _calculate_pilot_level(cur_xp)
        var gained_levels := new_lvl - old_lvl

        p_data["xp"] = cur_xp
        p_data["level"] = new_lvl
        p_data["sp_available"] = int(p_data["sp_available"]) + gained_levels
        pilot_xp[p_name] = {
            "level": new_lvl,
            "xp": cur_xp,
            "sp_available": p_data["sp_available"]
        }

        if gained_levels > 0:
            promotions.append({
                "pilot_name": p_name,
                "old_level": old_lvl,
                "new_level": new_lvl,
                "sp_gained": gained_levels
            })

    save_campaign()
    return {
        "eteron_earned": earned_eteron,
        "xp_earned": earned_xp,
        "total_credits": eteron_credits,
        "promotions": promotions
    }

func _calculate_pilot_level(xp: int) -> int:
    if xp >= 2000: return 5
    if xp >= 1200: return 4
    if xp >= 650:  return 3
    if xp >= 250:  return 2
    return 1

func get_pilot_data(pilot_name: String) -> Dictionary:
    if not pilot_xp.has(pilot_name):
        pilot_xp[pilot_name] = {
            "level": 1,
            "xp": 0,
            "sp_available": 0
        }
    var d: Dictionary = pilot_xp[pilot_name]
    var skills: Array = pilot_skills.get(pilot_name, [])
    return {
        "level": int(d.get("level", 1)),
        "xp": int(d.get("xp", 0)),
        "sp_available": int(d.get("sp_available", 0)),
        "skills": skills
    }

func unlock_pilot_skill(pilot_name: String, skill_id: String) -> bool:
    var skill := RpgDefs.get_skill(skill_id)
    if skill == null:
        return false
    var p_data := get_pilot_data(pilot_name)
    var cur_skills: Array = p_data["skills"]
    if cur_skills.has(skill_id):
        return false
    if p_data["sp_available"] < skill.cost_sp:
        return false
    if skill.requires_id != "" and not cur_skills.has(skill.requires_id):
        return false

    p_data["sp_available"] -= skill.cost_sp
    pilot_xp[pilot_name] = {
        "level": p_data["level"],
        "xp": p_data["xp"],
        "sp_available": p_data["sp_available"]
    }
    if not pilot_skills.has(pilot_name):
        pilot_skills[pilot_name] = []
    pilot_skills[pilot_name].append(skill_id)
    save_campaign()
    return true

func respec_pilot_skills(pilot_name: String) -> void:
    var p_data := get_pilot_data(pilot_name)
    var refunded_sp: int = maxi(0, p_data["level"] - 1)
    pilot_skills[pilot_name] = []
    pilot_xp[pilot_name] = {
        "level": p_data["level"],
        "xp": p_data["xp"],
        "sp_available": refunded_sp
    }
    save_campaign()

func get_pilot_perks(pilot_name: String) -> Array:
    return pilot_skills.get(pilot_name, [])

func get_ship_upgrade_data(ship_id: String) -> Dictionary:
    if not fleet_upgrades.has(ship_id):
        fleet_upgrades[ship_id] = {
            "armor_lvl": 0,
            "weapon_lvl": 0,
            "engine_lvl": 0,
            "subsystem": ""
        }
    return fleet_upgrades[ship_id]

func purchase_fleet_upgrade(ship_id: String, category: String) -> bool:
    var u_data := get_ship_upgrade_data(ship_id)
    var cat_clean := category
    if cat_clean == "weapons":
        cat_clean = "weapon"
    elif cat_clean == "engines":
        cat_clean = "engine"
    var key := cat_clean + "_lvl"
    var cur_lvl: int = int(u_data.get(key, 0))
    var next_lvl := cur_lvl + 1
    var tiers := RpgDefs.get_shipyard_tiers(category)
    if next_lvl >= tiers.size():
        return false
    var target_tier: RpgDefs.UpgradeTier = tiers[next_lvl]
    if eteron_credits < target_tier.cost_eteron:
        return false
    eteron_credits -= target_tier.cost_eteron
    u_data[key] = next_lvl
    fleet_upgrades[ship_id] = u_data
    save_campaign()
    return true

func purchase_subsystem(ship_id: String, subsystem_id: String) -> bool:
    var u_data := get_ship_upgrade_data(ship_id)
    if u_data.get("subsystem", "") == subsystem_id:
        return true # Already installed
    var cost := 600
    for faction_key in ["acero", "vinculados", "marea_libre"]:
        for sub in RpgDefs.get_subsystems_for_faction(faction_key):
            if sub.id == subsystem_id:
                cost = sub.cost_eteron
                break
    if eteron_credits < cost:
        return false
    eteron_credits -= cost
    u_data["subsystem"] = subsystem_id
    fleet_upgrades[ship_id] = u_data
    save_campaign()
    return true

func get_ship_effective_multipliers(ship_id: String) -> Dictionary:
    var u_data := get_ship_upgrade_data(ship_id)
    var armor_tiers := RpgDefs.get_shipyard_tiers("armor")
    var weapon_tiers := RpgDefs.get_shipyard_tiers("weapons")
    var engine_tiers := RpgDefs.get_shipyard_tiers("engines")

    var a_lvl: int = clampi(int(u_data.get("armor_lvl", 0)), 0, armor_tiers.size() - 1)
    var w_lvl: int = clampi(int(u_data.get("weapon_lvl", u_data.get("weapons_lvl", 0))), 0, weapon_tiers.size() - 1)
    var e_lvl: int = clampi(int(u_data.get("engine_lvl", u_data.get("engines_lvl", 0))), 0, engine_tiers.size() - 1)

    var a_tier: RpgDefs.UpgradeTier = armor_tiers[a_lvl] if not armor_tiers.is_empty() else null
    var w_tier: RpgDefs.UpgradeTier = weapon_tiers[w_lvl] if not weapon_tiers.is_empty() else null
    var e_tier: RpgDefs.UpgradeTier = engine_tiers[e_lvl] if not engine_tiers.is_empty() else null

    return {
        "hp_mult": a_tier.hp_mult if a_tier else 1.0,
        "armor_mult": a_tier.armor_mult if a_tier else 1.0,
        "dmg_mult": w_tier.dmg_mult if w_tier else 1.0,
        "thrust_mult": e_tier.thrust_mult if e_tier else 1.0,
        "speed_mult": e_tier.speed_mult if e_tier else 1.0,
        "subsystem": str(u_data.get("subsystem", ""))
    }

func get_next_stage_id(stage_id: String) -> String:
    match stage_id:
        # --- THE ARMADA OF ACERO (Stages 01 - 12) ---
        "acero_stage_1": return "acero_stage_2"
        "acero_stage_2": return "acero_stage_3"
        "acero_stage_3": return "acero_stage_4"
        "acero_stage_4": return "acero_stage_5"
        "acero_stage_5": return "acero_stage_6"
        "acero_stage_6": return "acero_stage_7"
        "acero_stage_7": return "acero_stage_8"
        "acero_stage_8": return "acero_stage_9"
        "acero_stage_9": return "acero_stage_10"
        "acero_stage_10": return "acero_stage_11"
        "acero_stage_11": return "acero_stage_12"
        "acero_stage_12": return ""

        # --- THE VINCULADOS (Stages 01 - 12) ---
        "vinculados_stage_1": return "vinculados_stage_2"
        "vinculados_stage_2": return "vinculados_stage_3"
        "vinculados_stage_3": return "vinculados_stage_4"
        "vinculados_stage_4": return "vinculados_stage_5"
        "vinculados_stage_5": return "vinculados_stage_6"
        "vinculados_stage_6": return "vinculados_stage_7"
        "vinculados_stage_7": return "vinculados_stage_8"
        "vinculados_stage_8": return "vinculados_stage_9"
        "vinculados_stage_9": return "vinculados_stage_10"
        "vinculados_stage_10": return "vinculados_stage_11"
        "vinculados_stage_11": return "vinculados_stage_12"
        "vinculados_stage_12": return ""

        # --- THE FREE TIDE / MAREA LIBRE (Stages 01 - 12) ---
        "marea_stage_1": return "marea_stage_2"
        "marea_stage_2": return "marea_stage_3"
        "marea_stage_3": return "marea_stage_4"
        "marea_stage_4": return "marea_stage_5"
        "marea_stage_5": return "marea_stage_6"
        "marea_stage_6": return "marea_stage_7"
        "marea_stage_7": return "marea_stage_8"
        "marea_stage_8": return "marea_stage_9"
        "marea_stage_9": return "marea_stage_10"
        "marea_stage_10": return "marea_stage_11"
        "marea_stage_11": return "marea_stage_12"
        "marea_stage_12": return ""

        _:
            return ""

func unlock_stage(stage_id: String) -> void:
    if stage_id.is_empty():
        return
    unlocked_stages[stage_id] = true
    last_stage_id = stage_id
    save_campaign()

func is_stage_unlocked(stage_id: String) -> bool:
    return bool(unlocked_stages.get(stage_id, false))

func is_stage_completed(stage_id: String) -> bool:
    return bool(completed_stages.get(stage_id, false))

func has_tactical_save() -> bool:
    return FileAccess.file_exists(TACTICAL_SAVE_PATH)

func get_tactical_save_summary() -> String:
    var d := load_tactical_state()
    if d.is_empty():
        return "NO TACTICAL SAVE FOUND"
    var stg := str(d.get("stage_id", "acero_stage_1")).to_upper().replace("_", " ")
    var trn := int(d.get("turn_number", 1))
    var ph := "ACE PHASE" if int(d.get("phase", 0)) >= 2 else "ADMIRAL PHASE"
    var ts := str(d.get("timestamp", ""))
    return "%s // TURN %d (%s) [%s]" % [stg, trn, ph, ts]

func save_tactical_state(
    stage_id: String,
    turn_num: int,
    phase_val: int,
    ace_rnd: int,
    player_ships: Array,
    enemy_ships: Array,
    faction: String = "",
    selected_idx: int = 0,
    target_idx: int = 0
) -> bool:
    if faction == "":
        faction = last_selected_faction
    var allies_data: Array = []
    for s in player_ships:
        if s != null and is_instance_valid(s):
            allies_data.append(_serialize_ship(s))

    var enemies_data: Array = []
    for e in enemy_ships:
        if e != null and is_instance_valid(e):
            enemies_data.append(_serialize_ship(e))

    var save_dict := {
        "stage_id": stage_id,
        "faction": faction,
        "turn_number": turn_num,
        "ace_round": ace_rnd,
        "phase": phase_val,
        "selected_idx": selected_idx,
        "target_idx": target_idx,
        "player_ships": allies_data,
        "enemy_ships": enemies_data,
        "timestamp": Time.get_datetime_string_from_system().replace("T", " ")
    }

    var file := FileAccess.open(TACTICAL_SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(save_dict, "\t"))
    file.close()

    last_selected_faction = faction
    last_stage_id = stage_id
    save_campaign()

    var summary := get_tactical_save_summary()
    tactical_saved.emit(summary)
    return true

func load_tactical_state() -> Dictionary:
    if not FileAccess.file_exists(TACTICAL_SAVE_PATH):
        return {}
    var file := FileAccess.open(TACTICAL_SAVE_PATH, FileAccess.READ)
    if file == null:
        return {}
    var txt := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(txt)
    if parsed is Dictionary:
        return parsed
    return {}

func _serialize_ship(s: Node) -> Dictionary:
    var pos: Vector3 = s.state.position
    var vel: Vector3 = s.state.velocity
    var fwd: Vector3 = s.state.forward
    return {
        "ship_id": s.ship_id,
        "pos": [pos.x, pos.y, pos.z],
        "vel": [vel.x, vel.y, vel.z],
        "fwd": [fwd.x, fwd.y, fwd.z],
        "hp": s.hp,
        "max_hp": s.max_hp,
        "shield_hp": s.shield_hp,
        "max_shield_hp": s.max_shield_hp,
        "armor_bow": s.armor_bow,
        "armor_port": s.armor_port,
        "armor_stbd": s.armor_stbd,
        "armor_stern": s.armor_stern,
        "order_yaw": s.order.yaw,
        "order_pitch": s.order.pitch,
        "order_speed": s.order.target_speed,
        "stance": int(s.stance),
        "is_evading": s.is_evading
    }

func get_faction_summary(fac: String) -> Dictionary:
    var max_stage := 1
    for s in range(1, 13):
        var sid := fac + "_stage_" + str(s)
        if bool(unlocked_stages.get(sid, false)):
            max_stage = s
    var latest_stage_id := fac + "_stage_" + str(max_stage)
    var completed_count := 0
    for s in range(1, 13):
        var sid := fac + "_stage_" + str(s)
        if bool(completed_stages.get(sid, false)):
            completed_count += 1

    var fac_name := "The Armada of Acero"
    var motto := "Steel Endures. The Sea is Fuel."
    var emblem_color := Color(1.0, 0.58, 0.22)
    var art_path := "res://assets/factions/card_acero.png"
    if fac == "vinculados":
        fac_name = "The Vinculados"
        motto = "Soul & Resonance. We Sing Before the Silence."
        emblem_color = Color(0.35, 0.92, 1.0)
        art_path = "res://assets/factions/card_vinculados.png"
    elif fac == "marea_libre":
        fac_name = "The Free Tide (Marea Libre)"
        motto = "Wind & Liberty. Break the Dams, Re-Awaken the Sea."
        emblem_color = Color(0.98, 0.78, 0.28)
        art_path = "res://assets/factions/card_marea.png"

    var st_data := StoryDB.get_story_data(latest_stage_id)
    var st_title := String(st_data.get("title", latest_stage_id.to_upper()))

    var has_tactical := false
    var tactical_summary := ""
    if has_tactical_save():
        var tac := load_tactical_state()
        var tac_fac := String(tac.get("faction", ""))
        var tac_stg := String(tac.get("stage_id", ""))
        if tac_fac == fac or tac_stg.begins_with(fac):
            has_tactical = true
            tactical_summary = get_tactical_save_summary()

    return {
        "faction": fac,
        "faction_name": fac_name,
        "motto": motto,
        "emblem_color": emblem_color,
        "art_path": art_path,
        "latest_stage_id": latest_stage_id,
        "stage_title": st_title,
        "stage_number": max_stage,
        "stages_completed": completed_count,
        "total_stages": 12,
        "is_conquered": completed_count >= 12,
        "has_tactical_save": has_tactical,
        "tactical_summary": tactical_summary
    }

func reset_faction_progress(fac: String) -> void:
    for s in range(1, 13):
        var sid := fac + "_stage_" + str(s)
        if s > 1:
            unlocked_stages.erase(sid)
        else:
            unlocked_stages[sid] = true
        completed_stages.erase(sid)
    save_campaign()

func get_default_settings() -> Dictionary:
    return {
        "master_volume": 1.0,
        "music_volume": 0.85,
        "sfx_volume": 1.0,
        "ambient_volume": 0.80,
        "fullscreen": false,
        "msaa_3d": 2,
        "glow_enabled": true,
        "ssao_enabled": true,
        "max_fps": 0,
        "preferred_menu_music": "res://assets/audio/music_prologue.ogg"
    }

func load_settings() -> Dictionary:
    var settings := get_default_settings()
    if not FileAccess.file_exists(SETTINGS_PATH):
        return settings
    var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
    if f != null:
        var txt := f.get_as_text()
        f.close()
        var parsed: Variant = JSON.parse_string(txt)
        if parsed is Dictionary:
            for k in parsed.keys():
                settings[k] = parsed[k]
    return settings

func save_settings(settings: Dictionary) -> void:
    var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(settings, "\t"))
        f.close()
    apply_settings(settings)

func apply_settings(settings: Dictionary) -> void:
    var audio = get_node_or_null("/root/AudioManager")
    if audio != null:
        audio.set_master_volume(float(settings.get("master_volume", 1.0)))
        audio.set_music_volume(float(settings.get("music_volume", 0.85)))
        audio.set_sfx_volume(float(settings.get("sfx_volume", 1.0)))
        audio.set_ambient_volume(float(settings.get("ambient_volume", 0.80)))

    var is_full: bool = bool(settings.get("fullscreen", false))
    if DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
        DisplayServer.window_set_mode(
            DisplayServer.WINDOW_MODE_FULLSCREEN if is_full else DisplayServer.WINDOW_MODE_WINDOWED
        )

    var max_fps: int = int(settings.get("max_fps", 0))
    Engine.max_fps = max_fps

func arr_to_vec3(arr: Array) -> Vector3:
    if arr.size() >= 3:
        return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
    return Vector3.ZERO
