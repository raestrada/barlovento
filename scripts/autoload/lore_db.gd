extends Node

const FACTIONS := ["acero", "vinculados", "marea_libre"]

var selected_faction: String = "acero"
var current_stage_id: String = "acero_stage_1"

var _ships: Dictionary = {}

func _ready() -> void:
    _register_ships()

func get_ship(id: String) -> ShipDef:
    return _ships.get(id)

func get_portrait_for_ship(id: String) -> String:
    var def: ShipDef = _ships.get(id)
    if def != null and def.portrait_path != "":
        return def.portrait_path
    return "res://assets/heroes/ace_vane.png"

func _register_ships() -> void:
    # --- THE ARMADA OF ACERO (Principle: Body / Steel — 100% Pure Acero Navy) ---
    _add_ship(_make_def(
        "acero_dreadnought", "CNS Iron Bastion", "Adm. Vane", "acero",
        800.0, 6200.0, 4800.0, 420.0, 14.0,
        380.0, 58.0, 38.0, 65.0,
        Color(0.72, 0.68, 0.62), Vector3(3.0, 2.0, 10.0),
        "res://assets/heroes/ace_vane.png", "Anvil-Class Dreadnought"
    ))
    _add_ship(_make_def(
        "acero_battlecruiser", "CNS Hammer of Anvil", "Capt. Korr", "acero",
        520.0, 5200.0, 4200.0, 520.0, 18.0,
        260.0, 52.0, 32.0, 70.0,
        Color(0.66, 0.64, 0.58), Vector3(2.4, 1.5, 8.2),
        "res://assets/heroes/ace_korr.png", "Hammer-Class Battlecruiser"
    ))
    _add_ship(_make_def(
        "acero_corvette", "CNS Vanguard-03", "Lt. Drake", "acero",
        240.0, 3600.0, 3200.0, 640.0, 22.0,
        150.0, 44.0, 22.0, 75.0,
        Color(0.55, 0.58, 0.66), Vector3(1.8, 1.0, 6.5),
        "res://assets/heroes/ace_drake.png", "Chisel-Class Escort Corvette"
    ))

    # --- THE VINCULADOS (Principle: Soul / Resonance — 100% Pure Vinculados Choir) ---
    _add_ship(_make_def(
        "vinculados_suit", "Eidolon Prime", "Ace Kaelen-7", "vinculados",
        60.0, 2000.0, 2200.0, 900.0, 30.0,
        160.0, 38.0, 26.0, 90.0,
        Color(0.35, 0.7, 0.95), Vector3(1.5, 0.8, 5.0),
        "res://assets/heroes/ace_kaelen.png", "Eidolon Command Frame"
    ))
    _add_ship(_make_def(
        "vinculados_anima", "Anima-01 (Aria)", "Ace Mirei-4", "vinculados",
        45.0, 2400.0, 2600.0, 1100.0, 36.0,
        115.0, 34.0, 20.0, 90.0,
        Color(0.5, 0.85, 0.85), Vector3(1.4, 0.7, 4.5),
        "res://assets/heroes/ace_mirei.png", "Anima Strike Frame"
    ))
    _add_ship(_make_def(
        "vinculados_nous", "Nous-04 (Cantor)", "Conductor Seraph-2", "vinculados",
        78.0, 1950.0, 2100.0, 820.0, 27.0,
        195.0, 42.0, 29.0, 85.0,
        Color(0.68, 0.45, 0.96), Vector3(1.65, 0.9, 5.4),
        "res://assets/heroes/ace_kaelen.png", "Nous Heavy Resonance Frame"
    ))

    # --- THE FREE TIDE / MAREA LIBRE (Principle: Wind / Liberty — 100% Pure Corsair Fleet) ---
    _add_ship(_make_def(
        "marea_galleon", "Viento Rojo", "Capt. Solano", "marea_libre",
        380.0, 3400.0, 2800.0, 520.0, 22.0,
        300.0, 50.0, 36.0, 140.0,
        Color(0.85, 0.55, 0.25), Vector3(2.5, 3.0, 9.0),
        "res://assets/heroes/ace_solano.png", "Corsair Void-Galleon"
    ))
    _add_ship(_make_def(
        "marea_raider", "La Descarada", "Quartermaster Vael", "marea_libre",
        290.0, 3200.0, 2700.0, 580.0, 24.0,
        210.0, 46.0, 28.0, 135.0,
        Color(0.80, 0.48, 0.22), Vector3(2.1, 2.5, 7.6),
        "res://assets/heroes/ace_vael.png", "Corsair Raider Galleon"
    ))
    _add_ship(_make_def(
        "marea_brigantine", "Brisa Negra", "Capt. Moreau", "marea_libre",
        245.0, 3500.0, 2900.0, 630.0, 26.0,
        180.0, 44.0, 24.0, 130.0,
        Color(0.75, 0.44, 0.20), Vector3(1.9, 2.2, 6.8),
        "res://assets/heroes/ace_moreau.png", "Corsair Void-Brigantine"
    ))

func _make_def(
    id: String,
    display_name: String,
    pilot_name: String,
    faction: String,
    mass: float,
    max_thrust: float,
    brake_thrust: float,
    turn_power: float,
    max_speed: float,
    hp: float,
    weapon_range: float,
    weapon_damage: float,
    weapon_arc_degrees: float,
    color: Color,
    body_size: Vector3,
    portrait_path: String = "",
    class_label: String = ""
) -> ShipDef:
    var def := ShipDef.new()
    def.id = id
    def.display_name = display_name
    def.pilot_name = pilot_name
    def.faction = faction
    def.mass = mass
    def.max_thrust = max_thrust
    def.brake_thrust = brake_thrust
    def.turn_power = turn_power
    def.max_speed = max_speed
    def.hp = hp
    def.weapon_range = weapon_range
    def.weapon_damage = weapon_damage
    def.weapon_arc_degrees = weapon_arc_degrees
    def.color = color
    def.body_size = body_size
    def.portrait_path = portrait_path
    def.class_label = class_label
    return def

func _add_ship(def: ShipDef) -> void:
    _ships[def.id] = def
