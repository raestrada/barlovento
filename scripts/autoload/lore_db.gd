extends Node

const FACTIONS := ["acero", "vinculados", "marea_libre"]

var _ships: Dictionary = {}

func _ready() -> void:
    _register_ships()

func get_ship(id: String) -> ShipDef:
    return _ships.get(id)

func _register_ships() -> void:
    _add_ship(_make_def(
        "acero_dreadnought", "Acero Dreadnought", "acero",
        800.0, 6000.0, 4500.0, 400.0, 12.0,
        400.0, 60.0, 40.0, 60.0,
        Color(0.7, 0.68, 0.62), Vector3(3.0, 2.0, 10.0)
    ))
    _add_ship(_make_def(
        "acero_corvette", "Acero Corvette", "acero",
        250.0, 3200.0, 3000.0, 550.0, 18.0,
        160.0, 40.0, 18.0, 60.0,
        Color(0.55, 0.58, 0.66), Vector3(1.8, 1.0, 6.5)
    ))
    _add_ship(_make_def(
        "vinculados_suit", "Vinculados Suit", "vinculados",
        60.0, 2000.0, 2200.0, 900.0, 30.0,
        120.0, 30.0, 25.0, 90.0,
        Color(0.35, 0.7, 0.95), Vector3(1.5, 0.8, 5.0)
    ))
    _add_ship(_make_def(
        "vinculados_anima", "Vinculados Anima", "vinculados",
        45.0, 2400.0, 2600.0, 1100.0, 36.0,
        90.0, 25.0, 20.0, 90.0,
        Color(0.5, 0.85, 0.85), Vector3(1.4, 0.7, 4.5)
    ))
    _add_ship(_make_def(
        "marea_galleon", "Marea Libre Galleon", "marea_libre",
        500.0, 1800.0, 1500.0, 300.0, 10.0,
        300.0, 45.0, 35.0, 45.0,
        Color(0.85, 0.55, 0.25), Vector3(2.5, 3.0, 9.0)
    ))

func _make_def(
    id: String,
    display_name: String,
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
    body_size: Vector3
) -> ShipDef:
    var def := ShipDef.new()
    def.id = id
    def.display_name = display_name
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
    return def

func _add_ship(def: ShipDef) -> void:
    _ships[def.id] = def
