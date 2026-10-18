class_name ShipDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var pilot_name: String = ""
@export var faction: String = ""
@export var mass: float = 100.0
@export var max_thrust: float = 500.0
@export var brake_thrust: float = 500.0
@export var turn_power: float = 200.0
@export var max_speed: float = 20.0
@export var hp: float = 100.0
@export var weapon_range: float = 40.0
@export var weapon_damage: float = 15.0
@export var weapon_arc_degrees: float = 60.0
@export var color: Color = Color(0.7, 0.7, 0.75)
@export var body_size: Vector3 = Vector3(2.0, 1.0, 6.0)
