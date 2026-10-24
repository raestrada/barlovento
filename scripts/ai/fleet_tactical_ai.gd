class_name FleetTacticalAI
extends RefCounted

const PITCH_LIMIT := 1.15
const ENGAGEMENT_RANGE := 65.0

static func predict_target_pos(target: Ship, lead_time: float) -> Vector3:
	if target == null:
		return Vector3.ZERO
	return target.state.position + target.state.velocity * lead_time

static func compute_tactical_heading(ship: Ship, target: Ship, lead_time: float) -> Vector3:
	if ship == null or target == null:
		return Vector3.FORWARD
	var predicted := predict_target_pos(target, lead_time)
	var to_target := predicted - ship.state.position
	var dist := to_target.length()
	if dist < 0.1:
		return ship.state.forward
	var dir := to_target / dist

	# Capital warships with broadside batteries angle 52 degrees ("Crossing the T" / angled broadside)
	# when inside optimal firing envelope (22m..46m) to bring both forward & broadside batteries to bear
	if (ship.ship_id == "acero_dreadnought" or ship.ship_id == "marea_galleon") and dist >= 22.0 and dist <= 46.0:
		var port_hp := ship.armor_port
		var stbd_hp := ship.armor_stbd
		var angle_sign := 1.0 if port_hp >= stbd_hp else -1.0
		var angled := dir.rotated(Vector3.UP, deg_to_rad(52.0 * angle_sign))
		return angled.normalized()

	return dir

static func set_order_heading(ship: Ship, direction: Vector3) -> void:
	if ship == null:
		return
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	ship.order.yaw = Vector3.FORWARD.signed_angle_to(flat, Vector3.UP)
	ship.order.pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT)

static func nearest_player_ship(ship: Ship, player_ships: Array[Ship]) -> Ship:
	if ship == null:
		return null
	var best: Ship = null
	var best_distance := INF
	for candidate in player_ships:
		if candidate == null or candidate.is_destroyed():
			continue
		var distance := ship.state.position.distance_to(candidate.state.position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

static func nearest_enemy_for(ship: Ship, enemy_ships: Array[Ship]) -> Ship:
	if ship == null:
		return null
	var best: Ship = null
	var best_distance := INF
	for candidate in enemy_ships:
		if candidate == null or candidate.is_destroyed():
			continue
		var distance := ship.state.position.distance_to(candidate.state.position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

static func fleets_in_range(player_ships: Array[Ship], enemy_ships: Array[Ship], range_threshold: float = ENGAGEMENT_RANGE) -> bool:
	for player in player_ships:
		if player == null or player.is_destroyed():
			continue
		for enemy in enemy_ships:
			if enemy == null or enemy.is_destroyed():
				continue
			if player.state.position.distance_to(enemy.state.position) <= range_threshold:
				return true
	return false

static func nearest_enemy_distance(player_ships: Array[Ship], enemy_ships: Array[Ship]) -> float:
	var best := INF
	for player in player_ships:
		if player == null or player.is_destroyed():
			continue
		for enemy in enemy_ships:
			if enemy == null or enemy.is_destroyed():
				continue
			best = minf(best, player.state.position.distance_to(enemy.state.position))
	return best

static func plan_god_mode_admiral(player_ships: Array[Ship], enemy_ships: Array[Ship]) -> void:
	for ship in player_ships:
		if ship == null or ship.is_destroyed():
			continue
		var target := nearest_enemy_for(ship, enemy_ships)
		if target != null:
			var to_t := (target.global_position - ship.global_position).normalized()
			if to_t.length_squared() > 0.01:
				set_order_heading(ship, to_t)
			ship.order.target_speed = ship.state.max_speed * 0.85
			ship.target_ship = target

static func plan_ai_orders(enemy_ships: Array[Ship], player_ships: Array[Ship]) -> void:
	var flagship: Ship = null
	for s in enemy_ships:
		if s != null and not s.is_destroyed():
			flagship = s
			break
	if flagship == null:
		return

	var primary_target := nearest_player_ship(flagship, player_ships)
	if primary_target == null:
		return

	for i in range(enemy_ships.size()):
		var enemy := enemy_ships[i]
		if enemy == null or enemy.is_destroyed():
			continue
		var tgt := nearest_player_ship(enemy, player_ships)
		if tgt == null:
			tgt = primary_target
		var dist := enemy.state.position.distance_to(tgt.state.position)
		if i == 0:
			var heading := compute_tactical_heading(enemy, tgt, 3.5)
			set_order_heading(enemy, heading)
			if dist > 48.0:
				enemy.order.target_speed = enemy.state.max_speed * 0.65
			elif dist > 22.0:
				enemy.order.target_speed = 3.5
			else:
				enemy.order.target_speed = 0.0
		else:
			var heading := compute_tactical_heading(enemy, tgt, 2.5)
			set_order_heading(enemy, heading)
			if dist > 42.0:
				enemy.order.target_speed = enemy.state.max_speed * 0.68
			elif dist > 18.0:
				enemy.order.target_speed = 4.2
			else:
				enemy.order.target_speed = 0.0

static func plan_ai_tactical_orders(enemy_ships: Array[Ship], player_ships: Array[Ship], is_tutorial: bool) -> void:
	if is_tutorial:
		for i in range(enemy_ships.size()):
			var enemy := enemy_ships[i]
			if enemy == null or enemy.is_destroyed():
				continue
			var target: Ship = null
			if i < player_ships.size() and not player_ships[i].is_destroyed():
				target = player_ships[i]
			else:
				target = nearest_player_ship(enemy, player_ships)
			enemy.target_ship = target
			if target != null:
				var dist := enemy.state.position.distance_to(target.state.position)
				var heading := compute_tactical_heading(enemy, target, 1.8)
				set_order_heading(enemy, heading)
				if enemy.hp < enemy.max_hp * 0.25:
					enemy.stance = Ship.Stance.EVASIVE
				else:
					enemy.stance = Ship.Stance.FIRE
				if dist > enemy.weapon_range:
					enemy.order.target_speed = enemy.state.max_speed * 0.55
				elif dist > 18.0:
					enemy.order.target_speed = 3.2
				else:
					enemy.order.target_speed = 1.0
		return

	# Focus-fire utility scoring: prioritize highest threat / lowest HP player unit in range
	var best_focus_target: Ship = null
	var best_score := -INF
	for p in player_ships:
		if p == null or p.is_destroyed():
			continue
		var hp_ratio := p.hp / maxf(p.max_hp, 1.0)
		var score := (1.0 - hp_ratio) * 45.0
		if not enemy_ships.is_empty() and not enemy_ships[0].is_destroyed():
			var d := enemy_ships[0].state.position.distance_to(p.state.position)
			score -= d * 0.5
		if score > best_score:
			best_score = score
			best_focus_target = p

	for ship in enemy_ships:
		if ship == null or ship.is_destroyed():
			continue
		var target := best_focus_target if best_focus_target != null and not best_focus_target.is_destroyed() else nearest_player_ship(ship, player_ships)
		ship.target_ship = target
		if target != null:
			var dist := ship.state.position.distance_to(target.state.position)
			var heading := compute_tactical_heading(ship, target, 1.8)
			set_order_heading(ship, heading)

			if ship.hp < ship.max_hp * 0.35:
				ship.stance = Ship.Stance.EVASIVE
			else:
				ship.stance = Ship.Stance.FIRE

			if dist > ship.weapon_range:
				ship.order.target_speed = ship.state.max_speed * 0.65
			elif dist > 18.0:
				ship.order.target_speed = 4.2
			else:
				ship.order.target_speed = 1.2
