extends Node

var time_scale: float = 1.0
var bounds: AABB = AABB()

func apply_order(ship: ShipState, order: ShipOrder, dt: float, ether: EtherField = null) -> void:
    step_state(ship, order, dt, ether)

func step_state(ship: ShipState, order: ShipOrder, dt: float, ether: EtherField = null) -> void:
    turn_toward(ship, order.heading(), dt)
    _control_speed(ship, order.target_speed, dt)
    if ether != null:
        ship.velocity += ether.current_at(ship.position) * dt
    ship.position += ship.velocity * dt
    _clamp_to_bounds(ship)

func _clamp_to_bounds(ship: ShipState) -> void:
    if bounds.get_volume() <= 0.0:
        return
    var min_pos := bounds.position
    var max_pos := bounds.end
    ship.position = ship.position.clamp(min_pos, max_pos)

    if ship.position.x <= min_pos.x and ship.velocity.x < 0.0:
        ship.velocity.x = 0.0
    if ship.position.x >= max_pos.x and ship.velocity.x > 0.0:
        ship.velocity.x = 0.0
    if ship.position.y <= min_pos.y and ship.velocity.y < 0.0:
        ship.velocity.y = 0.0
    if ship.position.y >= max_pos.y and ship.velocity.y > 0.0:
        ship.velocity.y = 0.0
    if ship.position.z <= min_pos.z and ship.velocity.z < 0.0:
        ship.velocity.z = 0.0
    if ship.position.z >= max_pos.z and ship.velocity.z > 0.0:
        ship.velocity.z = 0.0

func turn_toward(ship: ShipState, target: Vector3, dt: float) -> void:
    var turn_rate := ship.turn_power / ship.mass
    var angle := ship.forward.angle_to(target)
    if angle < 0.0001:
        return
    var step := minf(angle, turn_rate * dt)
    var axis := ship.forward.cross(target)
    if axis.length_squared() < 0.0001:
        axis = ship.forward.cross(Vector3.UP)
        if axis.length_squared() < 0.0001:
            axis = Vector3.RIGHT
    ship.forward = ship.forward.rotated(axis.normalized(), step).normalized()

func _control_speed(ship: ShipState, target_speed: float, dt: float) -> void:
    var target := clampf(target_speed, 0.0, ship.max_speed)
    var speed := ship.speed()

    if speed < target - 0.0001:
        ship.velocity += ship.forward * ((ship.max_thrust / ship.mass) * dt)
    elif speed > target + 0.0001:
        var new_speed: float = maxf(speed - (ship.brake_thrust / ship.mass) * dt, target)
        if speed > 0.0001:
            ship.velocity = ship.velocity.normalized() * new_speed
        else:
            ship.velocity = Vector3.ZERO

    if ship.speed() > ship.max_speed:
        ship.velocity = ship.velocity.normalized() * ship.max_speed

func clone_state(state: ShipState) -> ShipState:
    var copy := ShipState.new()
    copy.position = state.position
    copy.velocity = state.velocity
    copy.forward = state.forward
    copy.mass = state.mass
    copy.max_thrust = state.max_thrust
    copy.brake_thrust = state.brake_thrust
    copy.turn_power = state.turn_power
    copy.max_speed = state.max_speed
    return copy

func simulate(state: ShipState, order: ShipOrder, ether: EtherField, duration: float, dt: float = 0.1, samples: int = 64) -> PackedVector3Array:
    var points := PackedVector3Array()
    var sim := clone_state(state)
    points.append(sim.position)

    var sample_interval := duration / float(samples)
    var next_sample := sample_interval
    var t := 0.0
    while t < duration:
        step_state(sim, order, dt, ether)
        t += dt
        if t >= next_sample:
            points.append(sim.position)
            next_sample += sample_interval

    if points[points.size() - 1].distance_to(sim.position) > 0.001:
        points.append(sim.position)

    return points
