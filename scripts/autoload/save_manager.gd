extends Node

const CAMPAIGN_SAVE_PATH := "user://barlovento_campaign.json"
const TACTICAL_SAVE_PATH := "user://barlovento_tactical_save.json"

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

var pending_load_battle: bool = false

func _ready() -> void:
    load_campaign()

func save_campaign() -> void:
    var data := {
        "completed_stages": completed_stages,
        "unlocked_stages": unlocked_stages,
        "veteran_ranks": veteran_ranks,
        "last_selected_faction": last_selected_faction,
        "last_stage_id": last_stage_id,
        "total_victories": total_victories,
        "total_kills": total_kills,
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

func get_next_stage_id(stage_id: String) -> String:
    match stage_id:
        "acero_stage_1":
            return "acero_stage_2"
        "acero_stage_2":
            return "acero_stage_3"
        "acero_stage_3":
            return ""
        "vinculados_stage_1":
            return "vinculados_stage_2"
        "marea_stage_1":
            return "marea_stage_2"
        _:
            return ""

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
        faction = LoreDB.selected_faction
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

func arr_to_vec3(arr: Array) -> Vector3:
    if arr.size() >= 3:
        return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
    return Vector3.ZERO
