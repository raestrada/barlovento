extends Node

enum Phase { ADMIRAL_PLAN, ADMIRAL_RESOLVE, ACE }

const ACE_ACTIONS_PER_SHIP := 2
const ACE_MOVE_DURATION := 3.0

signal phase_changed(phase: Phase)
signal ace_activated(ship)
signal admiral_resolve_finished

var phase: Phase = Phase.ADMIRAL_PLAN
var turn_number: int = 1
var ace_round: int = 1

@export var resolution_window: float = 12.0
@export var resolve_time_scale: float = 8.0

var _resolve_time_left: float = 0.0
var _ace_queue: Array[Ship] = []
var _ace_index: int = -1
var _ace_actions: int = 0

func _ready() -> void:
    PhysicsSim.time_scale = 1.0

func _process(delta: float) -> void:
    if phase != Phase.ADMIRAL_RESOLVE:
        return
    _resolve_time_left -= delta * PhysicsSim.time_scale
    if _resolve_time_left <= 0.0:
        PhysicsSim.time_scale = 1.0
        turn_number += 1
        _set_phase(Phase.ADMIRAL_PLAN)
        admiral_resolve_finished.emit()

func start_resolve() -> void:
    if phase != Phase.ADMIRAL_PLAN:
        return
    _resolve_time_left = resolution_window
    PhysicsSim.time_scale = resolve_time_scale
    _set_phase(Phase.ADMIRAL_RESOLVE)

func reset() -> void:
    _resolve_time_left = 0.0
    turn_number = 1
    ace_round = 1
    _ace_queue.clear()
    _ace_index = -1
    _ace_actions = 0
    PhysicsSim.time_scale = 1.0
    _set_phase(Phase.ADMIRAL_PLAN)

func remaining_resolve_time() -> float:
    return maxf(_resolve_time_left, 0.0)

func phase_name() -> String:
    return Phase.keys()[phase]

func start_ace(ships: Array[Ship]) -> void:
    _ace_queue.clear()
    for ship in ships:
        if not ship.is_destroyed():
            _ace_queue.append(ship)
    if _ace_queue.is_empty():
        return
    ace_round = 1
    _ace_index = -1
    _set_phase(Phase.ACE)
    _advance_ace()

func exit_ace() -> void:
    _ace_queue.clear()
    _ace_index = -1
    _ace_actions = 0
    _set_phase(Phase.ADMIRAL_PLAN)

func ace_active() -> Ship:
    if _ace_index < 0 or _ace_index >= _ace_queue.size():
        return null
    return _ace_queue[_ace_index]

func ace_actions_left() -> int:
    return _ace_actions

func ace_spend_action() -> void:
    _ace_actions -= 1
    if _ace_actions <= 0:
        _advance_ace()

func ace_skip_ship() -> void:
    _ace_actions = 0
    _advance_ace()

func _advance_ace() -> void:
    for _attempt in range(_ace_queue.size()):
        _ace_index += 1
        if _ace_index >= _ace_queue.size():
            _ace_index = 0
            ace_round += 1
        var ship := _ace_queue[_ace_index]
        if not ship.is_destroyed():
            _ace_actions = ACE_ACTIONS_PER_SHIP
            ace_activated.emit(ship)
            return

func _set_phase(new_phase: Phase) -> void:
    phase = new_phase
    phase_changed.emit(phase)
