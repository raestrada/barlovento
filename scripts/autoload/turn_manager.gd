extends Node

enum Phase { ADMIRAL_PLAN, ADMIRAL_RESOLVE, ACE_PLAN, ACE_RESOLVE }

signal phase_changed(phase: Phase)
signal admiral_resolve_finished
signal ace_resolve_finished
signal ace_fire_moment

var phase: Phase = Phase.ADMIRAL_PLAN
var turn_number: int = 1
var ace_round: int = 1
var turbo_mode: bool = false

signal turbo_mode_changed(is_turbo: bool)

@export var admiral_resolution_window: float = 6.0
@export var admiral_time_scale: float = 3.0
@export var ace_resolution_window: float = 2.2
@export var ace_time_scale: float = 1.0

var _resolve_time_left: float = 0.0
var _fire_moment_triggered: bool = false

func _ready() -> void:
    PhysicsSim.time_scale = 1.0

func toggle_turbo_mode() -> bool:
    turbo_mode = not turbo_mode
    if phase == Phase.ACE_RESOLVE:
        PhysicsSim.time_scale = 2.0 if turbo_mode else ace_time_scale
    turbo_mode_changed.emit(turbo_mode)
    return turbo_mode

func _process(delta: float) -> void:
    match phase:
        Phase.ADMIRAL_RESOLVE:
            _resolve_time_left -= delta * PhysicsSim.time_scale
            if _resolve_time_left <= 0.0:
                PhysicsSim.time_scale = 1.0
                turn_number += 1
                _set_phase(Phase.ADMIRAL_PLAN)
                admiral_resolve_finished.emit()

        Phase.ACE_RESOLVE:
            _resolve_time_left -= delta * PhysicsSim.time_scale

            # Trigger simultaneous weapon broadside / laser fire early at 0.8s into maneuver
            if not _fire_moment_triggered and _resolve_time_left <= (ace_resolution_window - 0.8):
                _fire_moment_triggered = true
                ace_fire_moment.emit()

            if _resolve_time_left <= 0.0:
                PhysicsSim.time_scale = 1.0
                ace_round += 1
                _set_phase(Phase.ACE_PLAN)
                ace_resolve_finished.emit()

func start_resolve() -> void:
    if phase == Phase.ADMIRAL_PLAN:
        _resolve_time_left = admiral_resolution_window
        PhysicsSim.time_scale = admiral_time_scale
        _set_phase(Phase.ADMIRAL_RESOLVE)
    elif phase == Phase.ACE_PLAN:
        start_ace_resolve()

func start_ace_resolve() -> void:
    if phase != Phase.ACE_PLAN:
        return
    _resolve_time_left = ace_resolution_window
    _fire_moment_triggered = false
    PhysicsSim.time_scale = 2.0 if turbo_mode else ace_time_scale
    _set_phase(Phase.ACE_RESOLVE)

func start_ace_mode() -> void:
    ace_round = 1
    _resolve_time_left = 0.0
    PhysicsSim.time_scale = 1.0
    _set_phase(Phase.ACE_PLAN)

func exit_ace_mode() -> void:
    _resolve_time_left = 0.0
    PhysicsSim.time_scale = 1.0
    _set_phase(Phase.ADMIRAL_PLAN)

func reset() -> void:
    _resolve_time_left = 0.0
    turn_number = 1
    ace_round = 1
    _fire_moment_triggered = false
    PhysicsSim.time_scale = 1.0
    _set_phase(Phase.ADMIRAL_PLAN)

func remaining_resolve_time() -> float:
    return maxf(_resolve_time_left, 0.0)

func phase_name() -> String:
    return Phase.keys()[phase]

func is_in_ace() -> bool:
    return phase == Phase.ACE_PLAN or phase == Phase.ACE_RESOLVE

func is_resolving() -> bool:
    return phase == Phase.ADMIRAL_RESOLVE or phase == Phase.ACE_RESOLVE

func _set_phase(new_phase: Phase) -> void:
    phase = new_phase
    phase_changed.emit(phase)
