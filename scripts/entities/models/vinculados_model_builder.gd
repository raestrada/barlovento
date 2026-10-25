class_name VinculadosModelBuilder
extends ProceduralMeshPrimitives

static func build(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	_build_vinculados(ship, root, thrusters)

static func _build_vinculados(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	match ship.ship_id:
		"vinculados_cradle":
			_build_vinculados_carrier(ship, root, thrusters)
		"vinculados_colossus":
			_build_vinculados_colossus_mobile_armor(ship, root, thrusters)
		"vinculados_aegis":
			_build_vinculados_aegis_mobile_armor(ship, root, thrusters)
		"vinculados_psyche":
			_build_vinculados_diamond_squad(ship, root, thrusters)
		"vinculados_chorus":
			_build_vinculados_swarm_echelon(ship, root, thrusters)
		_:
			_build_vinculados_platoon(ship, root, thrusters)

static func _build_vinculados_carrier(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	var s := ship.body_size
	var ceramic := _textured(load(VINCULADOS_HULL), 0.14, 0.44, Vector3(2.2, 2.2, 1.0))
	ceramic.albedo_color = Color(0.66, 0.70, 0.78)
	var cobalt_blue := _colored(Color(0.06, 0.18, 0.50), 0.44, 0.36)
	var crimson_accent := _colored(Color(0.86, 0.12, 0.16), 0.34, 0.38)
	var frame_dark := _colored(Color(0.12, 0.14, 0.20), 0.68, 0.38)
	var amber_hab := _emissive(Color(1.0, 0.68, 0.10), 1.15)
	var cyan_energy := _emissive(Color(0.18, 0.92, 1.0), 1.25)
	var gold_crest := _colored(Color(0.92, 0.76, 0.22), 0.80, 0.30)
	var soul_core_mat := _get_soul_core_material()

	# 1. Central Hull & Spanning Keel
	root.add_child(_sculpted_block(
		Vector3(s.x * 0.52, s.y * 0.44, s.z * 0.68), ceramic,
		Vector3(0.0, s.y * 0.04, s.z * 0.02), Vector3.ZERO, 0.92, 0.90
	))
	root.add_child(_sculpted_block(
		Vector3(s.x * 0.28, s.y * 0.28, s.z * 0.82), cobalt_blue,
		Vector3(0.0, -s.y * 0.18, 0.0), Vector3.ZERO, 0.90, 0.84
	))

	# Central Exposed Soul Core Chamber on Dorsal Spine with Magnetic Orbital Rings
	var core_ring := _cyl(s.x * 0.16, s.x * 0.18, s.y * 0.14, 16, frame_dark, Vector3(0.0, s.y * 0.27, -s.z * 0.04), Vector3(90.0, 0.0, 0.0))
	root.add_child(core_ring)
	root.add_child(_sphere(s.x * 0.14, s.x * 0.26, soul_core_mat, Vector3(0.0, s.y * 0.27, -s.z * 0.04)))
	root.add_child(_cyl(s.x * 0.18, s.x * 0.19, 0.04, 16, gold_crest, Vector3(0.0, s.y * 0.27, -s.z * 0.04), Vector3(90.0, 0.0, 0.0)))

	# 2. Elevated Gundam Mecha Command Citadel & Bridge Superstructure
	var bridge_pylon := _sculpted_block(
		Vector3(s.x * 0.22, s.y * 0.52, s.z * 0.26), ceramic,
		Vector3(0.0, s.y * 0.48, s.z * 0.06), Vector3(-6.0, 0.0, 0.0), 0.84, 0.96
	)
	root.add_child(bridge_pylon)
	# Mecha Torso Bridge Cowl with Cobalt Armor & Amber Intake Louvers
	var bridge_cupola := _sculpted_block(
		Vector3(s.x * 0.28, s.y * 0.24, s.z * 0.22), cobalt_blue,
		Vector3(0.0, s.y * 0.74, s.z * 0.03), Vector3.ZERO, 0.88, 0.92
	)
	root.add_child(bridge_cupola)
	for b_side in [-1.0, 1.0]:
		root.add_child(_box(
			Vector3(s.x * 0.06, s.y * 0.08, 0.04), amber_hab,
			Vector3(b_side * s.x * 0.09, s.y * 0.74, -s.z * 0.07), Vector3(6.0, b_side * 8.0, 0.0)
		))

	# Panoramic Command Bridge Viewport / Sensor Visor
	var bridge_view := _box(
		Vector3(s.x * 0.24, s.y * 0.07, s.z * 0.14), cyan_energy,
		Vector3(0.0, s.y * 0.76, -s.z * 0.05)
	)
	root.add_child(bridge_view)

	# Imposing Backward-Swept Gundam V-Fin Harmonic Antenna Crest on Bridge Roof
	root.add_child(_box(Vector3(s.x * 0.04, s.y * 0.10, s.z * 0.04), crimson_accent, Vector3(0.0, s.y * 0.90, s.z * 0.01)))
	for side in [-1.0, 1.0]:
		root.add_child(_box(
			Vector3(0.03, s.y * 0.52, s.z * 0.12), gold_crest,
			Vector3(side * s.x * 0.11, s.y * 1.06, s.z * 0.04),
			Vector3(-22.0, side * 14.0, side * -26.0)
		))
		root.add_child(_box(
			Vector3(0.02, s.y * 0.34, s.z * 0.08), ceramic,
			Vector3(side * 0.06, s.y * 0.98, s.z * 0.08),
			Vector3(-30.0, side * 8.0, side * -14.0)
		))

	# 3. Twin Forward Catamaran Launch Catapult Decks (Mobile Suit Flight Bays)
	for side in [-1.0, 1.0]:
		var hx: float = side * s.x * 0.38
		root.add_child(_sculpted_block(
			Vector3(s.x * 0.32, s.y * 0.44, s.z * 0.58), ceramic,
			Vector3(hx, 0.0, -s.z * 0.18), Vector3.ZERO, 0.92, 0.90
		))
		root.add_child(_prism(
			Vector3(s.x * 0.32, s.y * 0.42, s.z * 0.20), ceramic,
			Vector3(hx, 0.0, -s.z * 0.52), Vector3(-90.0, 0.0, 0.0)
		))
		# Magnetic Catapult Runway with Glowing Cyan Guide Track
		root.add_child(_box(
			Vector3(s.x * 0.08, 0.02, s.z * 0.52), cyan_energy,
			Vector3(hx, s.y * 0.23, -s.z * 0.20)
		))
		root.add_child(_box(
			Vector3(s.x * 0.28, 0.015, s.z * 0.06), cobalt_blue,
			Vector3(hx, s.y * 0.23, -s.z * 0.42)
		))
		root.add_child(_box(
			Vector3(s.x * 0.18, s.y * 0.22, 0.04), frame_dark,
			Vector3(hx, -s.y * 0.04, -s.z * 0.48)
		))
		root.add_child(_box(
			Vector3(s.x * 0.14, s.y * 0.06, 0.05), amber_hab,
			Vector3(hx, s.y * 0.08, -s.z * 0.48)
		))
		root.add_child(_sculpted_block(
			Vector3(s.x * 0.10, s.y * 0.28, s.z * 0.42), cobalt_blue,
			Vector3(side * (s.x * 0.54), s.y * 0.02, -s.z * 0.14)
		))
		var spon_wing := _box(
			Vector3(s.x * 0.22, 0.04, s.z * 0.32), ceramic,
			Vector3(side * (s.x * 0.65), -s.y * 0.04, -s.z * 0.10),
			Vector3(0.0, 0.0, side * 15.0)
		)
		root.add_child(spon_wing)
		var spon_v := _cyl(s.x * 0.04, s.x * 0.06, 0.14, 8, cyan_energy, Vector3(side * (s.x * 0.72), -s.y * 0.04, -s.z * 0.10), Vector3(0.0, 0.0, side * 90.0))
		root.add_child(spon_v)
		thrusters.append(spon_v)

	# 4. Central Heavy Spinal High-Resonance Mega-Beam Cannon ("Rayo de Resonancia")
	root.add_child(_box(
		Vector3(s.x * 0.22, s.y * 0.20, s.z * 0.38), frame_dark,
		Vector3(0.0, s.y * 0.02, -s.z * 0.36)
	))
	for bside in [-1.0, 1.0]:
		root.add_child(_cyl(
			s.x * 0.04, s.x * 0.05, s.z * 0.32, 10, cobalt_blue,
			Vector3(bside * s.x * 0.06, s.y * 0.02, -s.z * 0.48),
			Vector3(90.0, 0.0, 0.0)
		))
		root.add_child(_cyl(
			0.015, s.x * 0.035, 0.10, 8, cyan_energy,
			Vector3(bside * s.x * 0.06, s.y * 0.02, -s.z * 0.64),
			Vector3(90.0, 0.0, 0.0)
		))

	# 5. Defensive Rapid-Fire Point-Defense Laser Casemates
	for side in [-1.0, 1.0]:
		var pd1 := _cyl(s.x * 0.05, s.x * 0.065, s.y * 0.12, 8, cobalt_blue, Vector3(side * s.x * 0.38, s.y * 0.26, 0.02))
		root.add_child(pd1)
		root.add_child(_cyl(0.015, 0.02, s.z * 0.12, 6, frame_dark, Vector3(side * s.x * 0.38, s.y * 0.30, -s.z * 0.05), Vector3(75.0, 0.0, 0.0)))
		var pd2 := _cyl(s.x * 0.045, s.x * 0.06, s.y * 0.10, 8, frame_dark, Vector3(side * s.x * 0.54, -s.y * 0.06, s.z * 0.18))
		root.add_child(pd2)

	# 6. Aft Main Propulsion Engine Nacelles
	for side in [-1.0, 1.0]:
		var hx: float = side * s.x * 0.38
		root.add_child(_sculpted_block(
			Vector3(s.x * 0.30, s.y * 0.38, s.z * 0.38), ceramic,
			Vector3(hx, 0.0, s.z * 0.32), Vector3.ZERO, 0.90, 0.90
		))
		root.add_child(_box(
			Vector3(s.x * 0.26, s.y * 0.08, s.z * 0.32), cobalt_blue,
			Vector3(hx, s.y * 0.20, s.z * 0.32)
		))
		for vy in [-0.08, 0.08]:
			var ez := s.z * 0.51
			root.add_child(_cyl(s.x * 0.08, s.x * 0.11, s.z * 0.16, 12, frame_dark, Vector3(hx, vy * s.y, ez), Vector3(-90.0, 0.0, 0.0)))
			var nozzle := _cyl(s.x * 0.065, s.x * 0.09, 0.35, 10, cyan_energy, Vector3(hx, vy * s.y, ez + 0.10), Vector3(-90.0, 0.0, 0.0))
			root.add_child(nozzle)
			thrusters.append(nozzle)

static func _build_vinculados_platoon(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	# 1. Lead Suit (Commander / Ace)
	_build_mobile_suit(root, 1.25, true, ship.ship_id, thrusters, 0.0, Vector3(0.0, 0.0, -1.35), Vector3.ZERO)
	# 2. Port Wingman (Left Escort)
	_build_mobile_suit(root, 1.05, false, ship.ship_id, thrusters, 1.85, Vector3(-1.85, 0.45, 1.15), Vector3(0.0, -6.0, 4.0))
	# 3. Starboard Wingman (Right Escort)
	_build_mobile_suit(root, 1.05, false, ship.ship_id, thrusters, 3.70, Vector3(1.85, -0.38, 1.35), Vector3(0.0, 6.0, -4.0))

static func _build_vinculados_colossus_mobile_armor(_ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	var ceramic := _textured(load(VINCULADOS_HULL), 0.14, 0.44, Vector3(2.4, 2.4, 1.0))
	ceramic.albedo_color = Color(0.66, 0.70, 0.78)
	var cobalt_blue := _colored(Color(0.05, 0.16, 0.48), 0.44, 0.36)
	var frame_dark := _colored(Color(0.11, 0.13, 0.18), 0.68, 0.36)
	var gold_crest := _colored(Color(0.92, 0.76, 0.22), 0.82, 0.28)
	var amber_intake := _emissive(Color(1.0, 0.68, 0.10), 1.20)
	var cyan_energy := _emissive(Color(0.15, 0.92, 1.0), 1.30)
	var cyan_visor := _emissive(Color(0.20, 0.96, 1.0), 1.40)
	var crimson_accent := _colored(Color(0.86, 0.12, 0.16), 0.36, 0.36)
	var soul_core_mat := _get_soul_core_material()
	var beam_lance_mat := _emissive(Color(0.25, 0.96, 1.0), 1.45)

	var ma_node := GundamSuitNode.new()
	ma_node.phase_offset = 0.0
	ma_node.sway_amplitude = 0.10
	ma_node.bank_amplitude = 1.4
	root.add_child(ma_node)

	var flight := Node3D.new()
	flight.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	ma_node.add_child(flight)

	# =========================================================================
	# 1. CENTRAL SCULPTED HUMANOID GUNDAM MECHA TORSO & PSY-FRAME CORE
	# =========================================================================
	flight.add_child(_sculpted_block(Vector3(1.40, 1.15, 1.12), ceramic, Vector3(0.0, 0.12, 0.20), Vector3.ZERO, 0.94, 0.82))
	flight.add_child(_cyl(0.55, 0.65, 0.95, 12, frame_dark, Vector3(0.0, -0.22, 0.20)))

	# Massive Sculpted Cobalt Blue Pectoral Chest Block
	flight.add_child(_sculpted_block(Vector3(2.42, 1.38, 1.60), cobalt_blue, Vector3(0.0, 1.18, 0.0), Vector3.ZERO, 0.88, 0.86))
	for side in [-1.0, 1.0]:
		flight.add_child(_prism(
			Vector3(0.95, 1.15, 0.48), cobalt_blue,
			Vector3(side * 0.65, 1.18, -0.88), Vector3(90.0, 0.0, side * 14.0)
		))

	# Dual Classic Gundam Amber Cooling Intake Louvers
	for side in [-1.0, 1.0]:
		flight.add_child(_box(
			Vector3(0.46, 0.34, 0.12), amber_intake,
			Vector3(side * 0.68, 1.28, -0.92), Vector3(8.0, side * 12.0, 0.0)
		))
		flight.add_child(_box(
			Vector3(0.52, 0.40, 0.06), frame_dark,
			Vector3(side * 0.68, 1.28, -0.87), Vector3(8.0, side * 12.0, 0.0)
		))

	# Central Exposed Soul-Core Resonance Reactor Sphere
	flight.add_child(_sphere(0.48, 0.72, soul_core_mat, Vector3(0.0, 1.14, -0.96)))
	flight.add_child(_cyl(0.52, 0.58, 0.24, 16, frame_dark, Vector3(0.0, 1.14, -0.90), Vector3(90.0, 0.0, 0.0)))
	flight.add_child(_cyl(0.60, 0.62, 0.07, 16, gold_crest, Vector3(0.0, 1.14, -0.95), Vector3(90.0, 0.0, 0.0)))

	# Cockpit Hatch Armor Plate (Crimson Block with Cyan Sensor)
	flight.add_child(_sculpted_block(Vector3(0.54, 0.54, 0.34), crimson_accent, Vector3(0.0, 0.64, -0.74), Vector3(15.0, 0.0, 0.0), 0.85, 0.90))
	flight.add_child(_box(Vector3(0.16, 0.10, 0.08), cyan_visor, Vector3(0.0, 0.76, -0.90)))

	# Multi-Segmented Sculpted Skirt Armor
	for side in [-1.0, 1.0]:
		flight.add_child(_sculpted_block(
			Vector3(0.64, 0.84, 0.18), ceramic,
			Vector3(side * 0.46, -0.48, -0.54), Vector3(18.0, side * -10.0, 0.0), 0.88, 0.80
		))
		flight.add_child(_box(
			Vector3(0.42, 0.28, 0.06), cobalt_blue,
			Vector3(side * 0.46, -0.44, -0.63), Vector3(18.0, side * -10.0, 0.0)
		))
		flight.add_child(_sculpted_block(
			Vector3(0.26, 0.94, 0.94), ceramic,
			Vector3(side * 0.94, -0.48, 0.18), Vector3(0.0, 0.0, side * -12.0), 0.86, 0.82
		))
		var s_v := _cyl(0.08, 0.13, 0.22, 8, cyan_energy, Vector3(side * 1.04, -0.68, 0.18), Vector3(0.0, 0.0, side * 90.0))
		flight.add_child(s_v)
		thrusters.append(s_v)
	flight.add_child(_sculpted_block(Vector3(1.28, 0.88, 0.18), ceramic, Vector3(0.0, -0.48, 0.78), Vector3(-18.0, 0.0, 0.0), 0.88, 0.80))

	# =========================================================================
	# 2. SCULPTED GUNDAM HEAD & ICONIC GOLDEN V-FIN CREST
	# =========================================================================
	flight.add_child(_cyl(0.26, 0.34, 0.42, 12, frame_dark, Vector3(0.0, 1.95, -0.05)))
	flight.add_child(_sculpted_block(Vector3(0.86, 0.86, 0.96), ceramic, Vector3(0.0, 2.42, -0.05), Vector3.ZERO, 0.84, 0.86))
	flight.add_child(_sculpted_block(Vector3(0.74, 0.34, 0.84), cobalt_blue, Vector3(0.0, 2.82, 0.0), Vector3.ZERO, 0.82, 0.92))
	for side in [-1.0, 1.0]:
		flight.add_child(_sculpted_block(
			Vector3(0.18, 0.54, 0.64), ceramic,
			Vector3(side * 0.44, 2.32, -0.15), Vector3(0.0, side * -8.0, 0.0)
		))
		flight.add_child(_cyl(0.035, 0.035, 0.32, 8, frame_dark, Vector3(side * 0.30, 2.62, -0.54), Vector3(90.0, 0.0, 0.0)))

	# Chin Cowl Guard (Crimson Goatee & Faceplate)
	flight.add_child(_prism(Vector3(0.30, 0.32, 0.20), crimson_accent, Vector3(0.0, 2.02, -0.54), Vector3(180.0, 0.0, 0.0)))
	flight.add_child(_box(Vector3(0.38, 0.24, 0.18), ceramic, Vector3(0.0, 2.22, -0.50)))

	# Glowing Cyan Visor Eyes / Dual Optics
	flight.add_child(_box(Vector3(0.52, 0.11, 0.16), cyan_visor, Vector3(0.0, 2.42, -0.54)))

	# Forehead Camera Sensor & THE MAGNIFICENT GUNDAM GOLDEN V-FIN CREST
	flight.add_child(_box(Vector3(0.22, 0.28, 0.16), crimson_accent, Vector3(0.0, 2.82, -0.54)))
	flight.add_child(_prism(Vector3(0.20, 0.24, 0.10), gold_crest, Vector3(0.0, 2.92, -0.56)))
	for side in [-1.0, 1.0]:
		flight.add_child(_box(
			Vector3(0.075, 1.50, 0.16), gold_crest,
			Vector3(side * 0.76, 3.34, -0.44),
			Vector3(-14.0, side * 15.0, side * -42.0)
		))
		flight.add_child(_box(
			Vector3(0.055, 0.92, 0.12), ceramic,
			Vector3(side * 0.50, 3.16, -0.26),
			Vector3(-22.0, side * 8.0, side * -26.0)
		))

	# =========================================================================
	# 3. COLOSSAL ARTICULATED SHOULDERS, AEGIS SHIELD & RESONANCE BEAM LANCE
	# =========================================================================
	for side in [-1.0, 1.0]:
		var sh_pos := Vector3(side * 1.82, 1.22, 0.0)
		flight.add_child(_sphere(0.42, 0.82, frame_dark, sh_pos))
		flight.add_child(_sculpted_block(Vector3(1.14, 0.94, 1.64), ceramic, sh_pos + Vector3(side * 0.32, 0.14, 0.0), Vector3(0.0, 0.0, side * -10.0), 0.86, 0.88))
		flight.add_child(_sculpted_block(Vector3(0.94, 0.34, 1.42), cobalt_blue, sh_pos + Vector3(side * 0.32, 0.62, 0.0), Vector3(0.0, 0.0, side * -10.0), 0.84, 0.92))
		for v_z in [-0.38, 0.38]:
			var sh_v := _cyl(0.09, 0.15, 0.26, 8, cyan_energy, sh_pos + Vector3(side * 1.02, 0.14, v_z), Vector3(0.0, 0.0, side * 90.0))
			flight.add_child(sh_v)
			thrusters.append(sh_v)

	# Left Arm & Tower Shield (Seraph Aegis)
	flight.add_child(_capsule(0.22, 0.82, frame_dark, Vector3(-1.72, 0.62, -0.32), Vector3(25.0, 0.0, -15.0)))
	flight.add_child(_capsule(0.22, 0.84, ceramic, Vector3(-1.82, 0.14, -0.82), Vector3(45.0, 15.0, 0.0)))
	var shield_root := Node3D.new()
	shield_root.position = Vector3(-2.20, 0.24, -0.92)
	shield_root.rotation_degrees = Vector3(12.0, 22.0, -6.0)
	flight.add_child(shield_root)
	shield_root.add_child(_sculpted_block(Vector3(0.76, 3.16, 0.18), ceramic, Vector3.ZERO, Vector3.ZERO, 0.82, 0.72))
	shield_root.add_child(_sculpted_block(Vector3(0.54, 2.34, 0.22), cobalt_blue, Vector3(0.0, 0.14, 0.04), Vector3.ZERO, 0.84, 0.76))
	shield_root.add_child(_box(Vector3(0.34, 0.34, 0.24), crimson_accent, Vector3(0.0, 0.82, 0.06)))
	shield_root.add_child(_sphere(0.16, 0.30, cyan_visor, Vector3(0.0, 0.82, 0.11)))

	# Right Arm & Colossal Resonance Beam Lance
	flight.add_child(_capsule(0.22, 0.82, frame_dark, Vector3(1.72, 0.62, -0.28), Vector3(20.0, 0.0, 10.0)))
	flight.add_child(_capsule(0.22, 0.84, ceramic, Vector3(1.82, 0.18, -0.78), Vector3(65.0, -10.0, 0.0)))
	flight.add_child(_cyl(0.09, 0.10, 2.40, 10, frame_dark, Vector3(1.82, 0.18, -1.65), Vector3(90.0, 0.0, 0.0)))
	flight.add_child(_cyl(0.26, 0.14, 0.65, 12, cobalt_blue, Vector3(1.82, 0.18, -2.85), Vector3(90.0, 0.0, 0.0)))
	flight.add_child(_cyl(0.32, 0.32, 0.16, 12, gold_crest, Vector3(1.82, 0.18, -3.15), Vector3(90.0, 0.0, 0.0)))
	flight.add_child(_cyl(0.02, 0.20, 3.60, 12, beam_lance_mat, Vector3(1.82, 0.18, -5.00), Vector3(90.0, 0.0, 0.0)))

	# =========================================================================
	# 4. FOUR MASSIVE SWEPT SERAPH SHIELD-BINDER WINGS & FUNNEL BATTERIES
	# =========================================================================
	for side in [-1.0, 1.0]:
		var w_root := Node3D.new()
		w_root.position = Vector3(side * 1.48, 1.75, 0.48)
		w_root.rotation_degrees = Vector3(-10.0, side * -24.0, side * -22.0)
		flight.add_child(w_root)

		w_root.add_child(_cyl(0.16, 0.22, 1.55, 8, frame_dark, Vector3(side * 0.68, 0.28, 0.0), Vector3(0.0, 0.0, side * 75.0)))
		w_root.add_child(_sculpted_block(Vector3(0.84, 2.54, 4.15), ceramic, Vector3(side * 1.75, 0.38, 1.15), Vector3(0.0, side * 8.0, 0.0), 0.80, 0.84))
		w_root.add_child(_sculpted_block(Vector3(0.64, 2.14, 3.35), cobalt_blue, Vector3(side * 1.95, 0.38, 1.05), Vector3.ZERO, 0.82, 0.86))
		w_root.add_child(_box(Vector3(0.08, 1.75, 2.15), gold_crest, Vector3(side * 2.30, 1.15, 1.35), Vector3(0.0, side * 15.0, side * -18.0)))
		for f in 5:
			var f_z: float = lerpf(-0.5, 2.6, float(f) / 4.0)
			w_root.add_child(_cyl(0.13, 0.11, 1.05, 8, frame_dark, Vector3(side * 2.10, 0.24, f_z), Vector3(90.0, 0.0, 0.0)))
			w_root.add_child(_cyl(0.15, 0.15, 0.12, 8, gold_crest, Vector3(side * 2.10, 0.24, f_z - 0.32), Vector3(90.0, 0.0, 0.0)))
			w_root.add_child(_sphere(0.08, 0.15, cyan_energy, Vector3(side * 2.10, 0.24, f_z - 0.62)))
		for vy in [-0.28, 0.58]:
			var w_v := _cyl(0.13, 0.20, 0.52, 10, cyan_energy, Vector3(side * 1.75, vy, 3.30), Vector3(-90.0, 0.0, 0.0))
			w_root.add_child(w_v)
			thrusters.append(w_v)

	# Lower Wing Pair
	for side in [-1.0, 1.0]:
		var lw_root := Node3D.new()
		lw_root.position = Vector3(side * 1.38, -0.18, 0.78)
		lw_root.rotation_degrees = Vector3(8.0, side * -18.0, side * 16.0)
		flight.add_child(lw_root)

		lw_root.add_child(_sculpted_block(Vector3(0.64, 1.78, 3.55), ceramic, Vector3(side * 1.45, -0.28, 1.35), Vector3.ZERO, 0.80, 0.84))
		lw_root.add_child(_sculpted_block(Vector3(0.50, 1.38, 2.75), cobalt_blue, Vector3(side * 1.55, -0.28, 1.25), Vector3.ZERO, 0.82, 0.86))
		for f in 3:
			var f_z: float = lerpf(0.1, 2.4, float(f) / 2.0)
			lw_root.add_child(_cyl(0.11, 0.09, 0.90, 8, frame_dark, Vector3(side * 1.70, -0.18, f_z), Vector3(90.0, 0.0, 0.0)))
			lw_root.add_child(_cyl(0.13, 0.13, 0.10, 8, gold_crest, Vector3(side * 1.70, -0.18, f_z - 0.28), Vector3(90.0, 0.0, 0.0)))
			lw_root.add_child(_sphere(0.07, 0.13, cyan_energy, Vector3(side * 1.70, -0.18, f_z - 0.52)))
		var lw_v := _cyl(0.11, 0.17, 0.48, 8, cyan_energy, Vector3(side * 1.45, -0.28, 3.20), Vector3(-90.0, 0.0, 0.0))
		lw_root.add_child(lw_v)
		thrusters.append(lw_v)

	# =========================================================================
	# 5. TWIN COLOSSAL UNDERSLUNG SPINAL MEGA-BUSTER BEAM CANNONS
	# =========================================================================
	for side in [-1.0, 1.0]:
		var cx: float = side * 1.12
		flight.add_child(_sculpted_block(Vector3(0.64, 0.64, 3.10), frame_dark, Vector3(cx, -0.82, -1.15)))
		flight.add_child(_sculpted_block(Vector3(0.54, 0.54, 2.30), cobalt_blue, Vector3(cx, -0.82, -1.35)))
		flight.add_child(_cyl(0.22, 0.26, 5.40, 12, frame_dark, Vector3(cx, -0.82, -3.75), Vector3(90.0, 0.0, 0.0)))
		for r in 4:
			var rz: float = -2.15 - float(r) * 0.88
			flight.add_child(_cyl(0.30, 0.30, 0.16, 12, gold_crest, Vector3(cx, -0.82, rz), Vector3(90.0, 0.0, 0.0)))
		flight.add_child(_cyl(0.19, 0.25, 0.82, 12, cyan_energy, Vector3(cx, -0.82, -6.65), Vector3(90.0, 0.0, 0.0)))
		flight.add_child(_sphere(0.15, 0.30, beam_lance_mat, Vector3(cx, -0.82, -7.15)))

	# =========================================================================
	# 6. SCULPTED ARTICULATED ZERO-G MECHA LEGS & HEAVY ROCKET BOOTS
	# =========================================================================
	for side in [-1.0, 1.0]:
		var lx: float = side * 0.66
		flight.add_child(_sphere(0.34, 0.62, frame_dark, Vector3(lx, -0.72, 0.24)))
		flight.add_child(_sculpted_block(Vector3(0.66, 1.48, 0.76), ceramic, Vector3(lx, -1.45, 0.62), Vector3(-20.0, 0.0, 0.0), 0.90, 0.82))
		flight.add_child(_sculpted_block(Vector3(0.54, 0.64, 0.44), cobalt_blue, Vector3(lx, -2.05, 0.62), Vector3(30.0, 0.0, 0.0)))
		var leg_pod := _sculpted_block(Vector3(0.86, 2.34, 1.24), ceramic, Vector3(lx, -2.85, 1.75), Vector3(-35.0, 0.0, 0.0), 0.82, 0.94)
		flight.add_child(leg_pod)
		flight.add_child(_sculpted_block(Vector3(0.64, 1.72, 0.92), cobalt_blue, Vector3(lx, -2.85, 1.85), Vector3(-35.0, 0.0, 0.0)))
		flight.add_child(_sculpted_block(Vector3(0.68, 0.42, 1.15), crimson_accent, Vector3(lx, -3.72, 2.35), Vector3(-35.0, 0.0, 0.0)))
		for ty in [-3.75, -3.15]:
			var nozzle := _cyl(0.19, 0.34, 0.72, 12, cyan_energy, Vector3(lx, ty, 3.05), Vector3(-90.0, 0.0, 0.0))
			flight.add_child(nozzle)
			thrusters.append(nozzle)

	# =========================================================================
	# 7. DORSAL HIGH-OUTPUT BACKPACK & MAIN PROPULSION
	# =========================================================================
	flight.add_child(_sculpted_block(Vector3(1.58, 1.78, 1.18), frame_dark, Vector3(0.0, 1.08, 0.88)))
	flight.add_child(_sculpted_block(Vector3(1.38, 0.78, 0.88), cobalt_blue, Vector3(0.0, 1.85, 0.88)))
	for side in [-1.0, 1.0]:
		flight.add_child(_cyl(0.075, 0.085, 1.15, 8, ceramic, Vector3(side * 0.72, 2.25, 0.78), Vector3(30.0, side * 10.0, 0.0)))
	for side in [-1.0, 1.0]:
		for vy in [0.78, 1.45]:
			var b_v := _cyl(0.20, 0.36, 0.82, 12, cyan_energy, Vector3(side * 0.52, vy, 1.55), Vector3(-90.0, 0.0, 0.0))
			flight.add_child(b_v)
			thrusters.append(b_v)

static func _build_vinculados_aegis_mobile_armor(_ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	var ceramic := _textured(load(VINCULADOS_HULL), 0.14, 0.44, Vector3(2.2, 2.2, 1.0))
	ceramic.albedo_color = Color(0.66, 0.70, 0.78)
	var cobalt_blue := _colored(Color(0.05, 0.16, 0.48), 0.44, 0.36)
	var frame_dark := _colored(Color(0.11, 0.13, 0.18), 0.68, 0.36)
	var cyan_energy := _emissive(Color(0.18, 0.92, 1.0), 1.25)
	var cyan_visor := _emissive(Color(0.22, 0.96, 1.0), 1.35)
	var gold_crest := _colored(Color(0.92, 0.76, 0.22), 0.82, 0.28)
	var soul_core_mat := _get_soul_core_material()

	var ma_node := GundamSuitNode.new()
	ma_node.phase_offset = 0.5
	ma_node.sway_amplitude = 0.08
	ma_node.bank_amplitude = 1.2
	root.add_child(ma_node)

	var flight := Node3D.new()
	flight.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	ma_node.add_child(flight)

	flight.add_child(_sculpted_block(Vector3(2.2, 1.6, 2.2), ceramic, Vector3(0.0, 0.2, 0.0)))
	flight.add_child(_sculpted_block(Vector3(2.6, 1.2, 1.6), cobalt_blue, Vector3(0.0, 0.6, -0.4)))
	flight.add_child(_sphere(0.42, 0.65, soul_core_mat, Vector3(0.0, 0.55, -1.2)))

	flight.add_child(_sculpted_block(Vector3(0.88, 0.88, 0.88), ceramic, Vector3(0.0, 1.8, -0.2)))
	flight.add_child(_box(Vector3(0.65, 0.14, 0.20), cyan_visor, Vector3(0.0, 1.8, -0.65)))
	for side in [-1.0, 1.0]:
		flight.add_child(_box(
			Vector3(0.08, 1.2, 0.18), gold_crest,
			Vector3(side * 0.65, 2.6, -0.35), Vector3(-16.0, side * 12.0, side * -35.0)
		))

	for side in [-1.0, 1.0]:
		var sb := _sculpted_block(Vector3(0.88, 2.45, 3.25), ceramic, Vector3(side * 2.2, 0.2, 0.2), Vector3(0.0, side * -8.0, 0.0))
		flight.add_child(sb)
		flight.add_child(_sculpted_block(Vector3(0.68, 1.85, 2.45), cobalt_blue, Vector3(side * 2.4, 0.2, 0.1)))
		var t := _cyl(0.18, 0.28, 0.65, 10, cyan_energy, Vector3(side * 1.6, 0.1, 1.8), Vector3(-90.0, 0.0, 0.0))
		flight.add_child(t)
		thrusters.append(t)

	flight.add_child(_cyl(0.22, 0.28, 4.2, 12, frame_dark, Vector3(0.0, -0.6, -2.6), Vector3(90.0, 0.0, 0.0)))
	flight.add_child(_sphere(0.18, 0.32, cyan_energy, Vector3(0.0, -0.6, -4.8)))

static func _build_vinculados_diamond_squad(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	_build_mobile_suit(root, 1.25, true, ship.ship_id, thrusters, 0.0, Vector3(0.0, 0.0, -2.4), Vector3.ZERO)
	_build_mobile_suit(root, 1.05, false, ship.ship_id, thrusters, 1.5, Vector3(-2.2, 0.35, 0.0), Vector3(0.0, -5.0, 3.0))
	_build_mobile_suit(root, 1.05, false, ship.ship_id, thrusters, 3.0, Vector3(2.2, -0.35, 0.0), Vector3(0.0, 5.0, -3.0))
	_build_mobile_suit(root, 1.05, false, ship.ship_id, thrusters, 4.5, Vector3(0.0, 0.55, 2.4), Vector3(0.0, 0.0, 0.0))

static func _build_vinculados_swarm_echelon(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	_build_mobile_suit(root, 1.20, true, ship.ship_id, thrusters, 0.0, Vector3(0.0, 0.0, -2.2), Vector3.ZERO)
	_build_mobile_suit(root, 1.00, false, ship.ship_id, thrusters, 1.2, Vector3(-1.65, 0.38, 0.0), Vector3(0.0, -4.0, 2.0))
	_build_mobile_suit(root, 1.00, false, ship.ship_id, thrusters, 2.4, Vector3(1.65, -0.32, 0.0), Vector3(0.0, 4.0, -2.0))
	_build_mobile_suit(root, 0.95, false, ship.ship_id, thrusters, 3.6, Vector3(-3.30, 0.72, 2.1), Vector3(0.0, -8.0, 4.0))
	_build_mobile_suit(root, 0.95, false, ship.ship_id, thrusters, 4.8, Vector3(3.30, -0.65, 2.1), Vector3(0.0, 8.0, -4.0))

static func _build_mobile_suit(
	parent: Node3D,
	suit_scale: float,
	is_lead: bool,
	ship_id: String,
	thrusters: Array[Node3D],
	phase_seed: float,
	offset_pos: Vector3,
	base_rot: Vector3
) -> void:
	var suit := GundamSuitNode.new()
	suit.phase_offset = phase_seed
	suit.sway_amplitude = 0.16
	suit.bank_amplitude = 2.4
	suit.position = offset_pos
	suit.rotation_degrees = base_rot
	suit.scale = Vector3(suit_scale, suit_scale, suit_scale)
	parent.add_child(suit)

	var flight_posture := Node3D.new()
	flight_posture.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	suit.add_child(flight_posture)

	var is_anima := (ship_id == "vinculados_anima")
	var is_nous := (ship_id == "vinculados_nous")

	var ceramic_white := _textured(load(VINCULADOS_HULL), 0.14, 0.44, Vector3(2.0, 2.0, 1.0))
	if is_anima:
		ceramic_white.albedo_color = Color(0.65, 0.70, 0.78)
	elif is_nous:
		ceramic_white.albedo_color = Color(0.68, 0.67, 0.78)
	else:
		ceramic_white.albedo_color = Color(0.66, 0.70, 0.78)

	var cobalt_blue := _colored(Color(0.05, 0.16, 0.48), 0.44, 0.36)
	var frame_dark := _colored(Color(0.11, 0.13, 0.18), 0.68, 0.36)
	var gold_crest := _colored(Color(0.92, 0.76, 0.22), 0.82, 0.28)
	var amber_intake := _emissive(Color(1.0, 0.68, 0.10), 1.15)
	var cyan_visor := _emissive(Color(0.20, 0.94, 1.0), 1.30)
	var cyan_thruster := _emissive(Color(0.25, 0.94, 1.0), 1.35)
	var crimson_accent := _colored(Color(0.86, 0.12, 0.16), 0.36, 0.36)
	var soul_core_mat := _get_soul_core_material()
	var beam_lance_mat := _emissive(Color(0.30, 0.96, 1.0), 1.40)

	# 1. Sculpted Torso Assembly (Classic Real-Robot Military Layout)
	flight_posture.add_child(_sculpted_block(Vector3(0.36, 0.34, 0.28), ceramic_white, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, 0.92, 0.82))
	flight_posture.add_child(_sculpted_block(Vector3(0.58, 0.42, 0.40), cobalt_blue, Vector3(0.0, 0.32, -0.02), Vector3.ZERO, 0.88, 0.86))

	# Dual Angled Amber Cooling Intake Vents (Classic Gundam Chest Louvers)
	for side in [-1.0, 1.0]:
		flight_posture.add_child(_box(
			Vector3(0.11, 0.085, 0.045), amber_intake,
			Vector3(side * 0.16, 0.34, -0.21), Vector3(6.0, side * 8.0, 0.0)
		))

	# Central Exposed Pulsing Magenta Soul Core + Gold Ring
	flight_posture.add_child(_sphere(0.085, 0.15, soul_core_mat, Vector3(0.0, 0.30, -0.21)))
	flight_posture.add_child(_cyl(0.095, 0.10, 0.02, 12, gold_crest, Vector3(0.0, 0.30, -0.20), Vector3(90.0, 0.0, 0.0)))

	# Cockpit Hatch Block (Angled Crimson Plate)
	flight_posture.add_child(_sculpted_block(
		Vector3(0.13, 0.15, 0.07), crimson_accent if (is_lead or is_nous) else cobalt_blue,
		Vector3(0.0, 0.18, -0.16)
	))

	# Waist & Segmented Skirt Armor Plates
	for side in [-1.0, 1.0]:
		flight_posture.add_child(_sculpted_block(
			Vector3(0.15, 0.19, 0.05), ceramic_white,
			Vector3(side * 0.10, -0.16, -0.14), Vector3(14.0, 0.0, side * -4.0)
		))
		flight_posture.add_child(_sculpted_block(
			Vector3(0.05, 0.19, 0.21), ceramic_white,
			Vector3(side * 0.21, -0.16, 0.0)
		))
	flight_posture.add_child(_sculpted_block(
		Vector3(0.32, 0.16, 0.05), ceramic_white,
		Vector3(0.0, -0.16, 0.14), Vector3(-12.0, 0.0, 0.0)
	))

	# 2. Sculpted Head Unit & Golden V-Fin Crest
	flight_posture.add_child(_cyl(0.06, 0.08, 0.10, 8, frame_dark, Vector3(0.0, 0.54, 0.0)))
	var helmet := _sculpted_block(Vector3(0.24, 0.25, 0.26), ceramic_white, Vector3(0.0, 0.68, 0.0), Vector3.ZERO, 0.84, 0.86)
	flight_posture.add_child(helmet)
	flight_posture.add_child(_prism(
		Vector3(0.08, 0.08, 0.06), crimson_accent if is_lead else cobalt_blue,
		Vector3(0.0, 0.58, -0.13), Vector3(180.0, 0.0, 0.0)
	))
	flight_posture.add_child(_box(
		Vector3(0.16, 0.036, 0.05), cyan_visor,
		Vector3(0.0, 0.68, -0.13)
	))
	flight_posture.add_child(_box(
		Vector3(0.05, 0.05, 0.06), crimson_accent,
		Vector3(0.0, 0.81, -0.10)
	))
	for side in [-1.0, 1.0]:
		flight_posture.add_child(_box(
			Vector3(0.022, 0.28, 0.06), gold_crest if is_lead else ceramic_white,
			Vector3(side * 0.12, 0.86, -0.08),
			Vector3(-16.0, side * 14.0, side * -38.0)
		))
		if is_lead or is_anima or is_nous:
			flight_posture.add_child(_box(
				Vector3(0.018, 0.20, 0.05), ceramic_white,
				Vector3(side * 0.07, 0.85, -0.04),
				Vector3(-24.0, side * 10.0, side * -22.0)
			))
	flight_posture.add_child(_box(Vector3(0.03, 0.06, 0.04), cyan_visor, Vector3(0.0, 0.82, -0.08)))

	# 3. High-Mobility Backpack Unit & Verniers
	flight_posture.add_child(_sculpted_block(Vector3(0.36, 0.38, 0.24), frame_dark, Vector3(0.0, 0.32, 0.22)))
	flight_posture.add_child(_sculpted_block(Vector3(0.32, 0.14, 0.22), cobalt_blue, Vector3(0.0, 0.48, 0.22)))
	for side in [-1.0, 1.0]:
		flight_posture.add_child(_cyl(
			0.04, 0.075, 0.16, 8, frame_dark,
			Vector3(side * 0.11, 0.24, 0.32), Vector3(-72.0, 0.0, 0.0)
		))
		var vernier := _cyl(
			0.025, 0.055, 0.24, 8, cyan_thruster,
			Vector3(side * 0.11, 0.24, 0.40), Vector3(-72.0, 0.0, 0.0)
		)
		flight_posture.add_child(vernier)
		thrusters.append(vernier)
		flight_posture.add_child(_cyl(
			0.015, 0.02, 0.24, 6, ceramic_white,
			Vector3(side * 0.14, 0.58, 0.20), Vector3(28.0, side * 8.0, 0.0)
		))

	if is_nous:
		for side in [-1.0, 1.0]:
			flight_posture.add_child(_cyl(
				0.045, 0.06, 0.65, 10, ceramic_white,
				Vector3(side * 0.22, 0.55, -0.15), Vector3(82.0, 0.0, 0.0)
			))
			flight_posture.add_child(_cyl(
				0.025, 0.035, 0.18, 8, beam_lance_mat,
				Vector3(side * 0.22, 0.58, -0.52), Vector3(82.0, 0.0, 0.0)
			))
	elif is_anima:
		for side in [-1.0, 1.0]:
			flight_posture.add_child(_sculpted_block(
				Vector3(0.04, 0.40, 0.26), cobalt_blue,
				Vector3(side * 0.32, 0.40, 0.34), Vector3(-30.0, side * 24.0, side * -28.0)
			))

	# 4. Sculpted Shoulders & Arms
	for side in [-1.0, 1.0]:
		var pld := _sculpted_block(Vector3(0.26, 0.24, 0.30), ceramic_white, Vector3(side * 0.42, 0.36, 0.0))
		flight_posture.add_child(pld)
		flight_posture.add_child(_sculpted_block(Vector3(0.24, 0.07, 0.28), cobalt_blue, Vector3(side * 0.42, 0.48, 0.0)))
		var sh_v := _cyl(0.02, 0.04, 0.08, 6, cyan_thruster, Vector3(side * 0.55, 0.36, 0.0), Vector3(0.0, 0.0, side * 90.0))
		flight_posture.add_child(sh_v)
		thrusters.append(sh_v)

	# Left Arm & Shield
	flight_posture.add_child(_capsule(0.06, 0.18, frame_dark, Vector3(-0.38, 0.22, -0.10), Vector3(25.0, 0.0, -15.0)))
	flight_posture.add_child(_capsule(0.06, 0.18, ceramic_white, Vector3(-0.40, 0.10, -0.24), Vector3(45.0, 10.0, 0.0)))
	var shield_node := Node3D.new()
	shield_node.position = Vector3(-0.48, 0.12, -0.26)
	shield_node.rotation_degrees = Vector3(14.0, 26.0, -8.0)
	flight_posture.add_child(shield_node)
	shield_node.add_child(_sculpted_block(Vector3(0.20, 0.74, 0.05), ceramic_white, Vector3.ZERO))
	shield_node.add_child(_sculpted_block(Vector3(0.15, 0.40, 0.06), cobalt_blue, Vector3(0.0, 0.06, 0.01)))
	shield_node.add_child(_box(Vector3(0.08, 0.05, 0.07), crimson_accent, Vector3(0.0, 0.26, 0.01)))

	# Right Arm & Precision Beam Carbine / Rifle
	flight_posture.add_child(_capsule(0.06, 0.18, frame_dark, Vector3(0.38, 0.22, -0.08), Vector3(20.0, 0.0, 10.0)))
	flight_posture.add_child(_capsule(0.06, 0.18, ceramic_white, Vector3(0.38, 0.12, -0.22), Vector3(70.0, 0.0, 0.0)))
	var gun_pos := Vector3(0.38, 0.12, -0.48)
	flight_posture.add_child(_box(Vector3(0.07, 0.14, 0.38), frame_dark, gun_pos))
	flight_posture.add_child(_cyl(0.025, 0.025, 0.12, 8, cobalt_blue, gun_pos + Vector3(0.0, 0.09, 0.02), Vector3(90.0, 0.0, 0.0)))
	flight_posture.add_child(_sphere(0.02, 0.04, cyan_visor, gun_pos + Vector3(0.0, 0.09, -0.05)))
	flight_posture.add_child(_cyl(0.02, 0.028, 0.48, 8, frame_dark, gun_pos + Vector3(0.0, 0.0, -0.36), Vector3(90.0, 0.0, 0.0)))
	flight_posture.add_child(_cyl(0.005, 0.04, 0.16, 8, beam_lance_mat, gun_pos + Vector3(0.0, 0.0, -0.66), Vector3(90.0, 0.0, 0.0)))

	# 5. Sculpted Articulated Legs Trailing Backwards in Slipstream!
	for side in [-1.0, 1.0]:
		var lx: float = side * 0.15
		flight_posture.add_child(_sphere(0.06, 0.12, frame_dark, Vector3(lx, -0.16, 0.0)))
		flight_posture.add_child(_sculpted_block(
			Vector3(0.15, 0.34, 0.19), ceramic_white,
			Vector3(lx, -0.32, 0.08), Vector3(-15.0, 0.0, 0.0), 0.90, 0.82
		))
		flight_posture.add_child(_sculpted_block(
			Vector3(0.13, 0.15, 0.09), cobalt_blue,
			Vector3(lx, -0.44, 0.09), Vector3(32.0, 0.0, 0.0)
		))
		flight_posture.add_child(_sculpted_block(
			Vector3(0.16, 0.44, 0.22), ceramic_white,
			Vector3(lx, -0.65, 0.32), Vector3(-38.0, 0.0, 0.0), 0.82, 0.94
		))
		flight_posture.add_child(_cyl(
			0.035, 0.065, 0.14, 8, frame_dark,
			Vector3(lx, -0.62, 0.44), Vector3(-65.0, 0.0, 0.0)
		))
		var calf_v := _cyl(
			0.02, 0.045, 0.20, 8, cyan_thruster,
			Vector3(lx, -0.62, 0.52), Vector3(-65.0, 0.0, 0.0)
		)
		flight_posture.add_child(calf_v)
		thrusters.append(calf_v)
		flight_posture.add_child(_sculpted_block(
			Vector3(0.15, 0.15, 0.29), crimson_accent if is_lead else cobalt_blue,
			Vector3(lx, -0.86, 0.50), Vector3(-50.0, 0.0, 0.0)
		))
		var foot_v := _cyl(
			0.02, 0.045, 0.16, 8, cyan_thruster,
			Vector3(lx, -0.90, 0.62), Vector3(-50.0, 0.0, 0.0)
		)
		flight_posture.add_child(foot_v)
		thrusters.append(foot_v)
