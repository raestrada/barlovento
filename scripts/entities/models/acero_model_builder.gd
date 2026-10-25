class_name AceroModelBuilder
extends ProceduralMeshPrimitives

static func build(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	_build_acero(ship, root, thrusters)

static func _build_acero(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	var s := ship.body_size
	var hull := _textured(load(ACERO_HULL), 0.56, 0.44, Vector3(2.2, 2.2, 1.0))
	hull.albedo_color = Color(0.72, 0.76, 0.84)
	hull.cull_mode = BaseMaterial3D.CULL_DISABLED

	var armor := _textured(load(ACERO_HULL), 0.62, 0.42, Vector3(2.8, 2.8, 1.0))
	armor.albedo_color = Color(0.78, 0.82, 0.90)
	armor.cull_mode = BaseMaterial3D.CULL_DISABLED

	var dark_steel := _colored(Color(0.20, 0.24, 0.32), 0.58, 0.38)
	var gunmetal := _colored(Color(0.36, 0.42, 0.52), 0.64, 0.34)
	var steel_trim := _colored(Color(0.62, 0.68, 0.78), 0.72, 0.28)
	var brass_accent := _colored(Color(0.86, 0.68, 0.26), 0.80, 0.28)
	var engine_glow := _emissive(Color(1.0, 0.48, 0.10), 1.45)
	var amber_vent := _emissive(Color(1.0, 0.56, 0.12), 1.15)
	var bridge_lit := _emissive(Color(0.28, 0.90, 1.0), 1.25)

	var half_len := s.z * 0.5
	var hull_mesh := build_loft(_acero_profile(s), [
		{"z": -half_len * 1.04, "scale": Vector2(0.05, 0.22), "offset_y": -0.04},
		{"z": -half_len * 0.88, "scale": Vector2(0.36, 0.62), "offset_y": -0.02},
		{"z": -half_len * 0.62, "scale": Vector2(0.62, 0.82), "offset_y": 0.0},
		{"z": -half_len * 0.30, "scale": Vector2(0.84, 0.95), "offset_y": 0.0},
		{"z": half_len * 0.10, "scale": Vector2(1.0, 1.0), "offset_y": 0.0},
		{"z": half_len * 0.52, "scale": Vector2(1.04, 1.02), "offset_y": 0.0},
		{"z": half_len * 0.86, "scale": Vector2(0.96, 0.98), "offset_y": 0.0},
		{"z": half_len, "scale": Vector2(0.82, 0.90), "offset_y": 0.0},
	])
	var hull_inst := MeshInstance3D.new()
	hull_inst.mesh = hull_mesh
	hull_inst.material_override = hull
	root.add_child(hull_inst)

	# Reinforced Chamfered Prow Ram & Brushed Steel Dorsal Spine Strip
	root.add_child(_sculpted_block(
		Vector3(s.x * 0.32, s.y * 0.56, s.z * 0.26), armor,
		Vector3(0.0, -s.y * 0.06, -half_len * 0.86), Vector3.ZERO, 0.84, 0.78
	))
	root.add_child(_box(
		Vector3(s.x * 0.14, s.y * 0.06, s.z * 0.78), steel_trim,
		Vector3(0.0, s.y * 0.30, -s.z * 0.06)
	))

	# Armored Sponsons with Recessed Amber Éther-Furnace Louvers
	for side in [-1.0, 1.0]:
		root.add_child(_sculpted_block(
			Vector3(s.x * 0.19, s.y * 0.40, s.z * 0.62), armor,
			Vector3(side * s.x * 0.52, -s.y * 0.04, s.z * 0.05), Vector3.ZERO, 0.90, 0.88
		))
		root.add_child(_box(
			Vector3(s.x * 0.20, s.y * 0.05, s.z * 0.64), steel_trim,
			Vector3(side * s.x * 0.52, s.y * 0.16, s.z * 0.05)
		))
		root.add_child(_box(
			Vector3(s.x * 0.04, s.y * 0.11, s.z * 0.48), amber_vent,
			Vector3(side * s.x * 0.60, s.y * 0.01, s.z * 0.05)
		))
		root.add_child(_box(
			Vector3(s.x * 0.18, s.y * 0.20, 0.05), amber_vent,
			Vector3(side * s.x * 0.48, -s.y * 0.02, -s.z * 0.18)
		))

	# Tiered Sculpted Command Citadel & Armored Bridge Tower
	root.add_child(_sculpted_block(
		Vector3(s.x * 0.54, s.y * 0.55, s.z * 0.36), dark_steel,
		Vector3(0.0, s.y * 0.48, s.z * 0.10), Vector3.ZERO, 0.88, 0.96
	))
	root.add_child(_sculpted_block(
		Vector3(s.x * 0.38, s.y * 0.48, s.z * 0.22), armor,
		Vector3(0.0, s.y * 0.84, s.z * 0.14), Vector3.ZERO, 0.86, 0.94
	))
	root.add_child(_box(
		Vector3(s.x * 0.42, s.y * 0.06, s.z * 0.24), steel_trim,
		Vector3(0.0, s.y * 1.09, s.z * 0.14)
	))
	# Bridge Command Slit Window
	root.add_child(_box(
		Vector3(s.x * 0.28, s.y * 0.07, 0.05), bridge_lit,
		Vector3(0.0, s.y * 0.94, s.z * 0.025)
	))
	# Dorsal Sensor Mast & Spine Fin
	root.add_child(_cyl(
		0.03, 0.05, s.y * 0.75, 8, steel_trim,
		Vector3(0.0, s.y * 1.32, s.z * 0.16)
	))
	root.add_child(_prism(
		Vector3(0.12, s.y * 0.85, s.z * 0.28), armor,
		Vector3(0.0, s.y * 0.58, s.z * 0.28), Vector3(0.0, 0.0, 90.0)
	))

	# Superfiring Main Turrets & Class-Specific Superstructure
	var is_dread := (ship.ship_id == "acero_dreadnought")
	var is_bc := (ship.ship_id == "acero_battlecruiser")
	var is_corvette := (ship.ship_id == "acero_corvette")

	if is_bc:
		# Hammer-Class Battlecruiser: Twin Axial Spinal Railgun Barrels + Electromagnetic Accelerator Rings
		for side in [-1.0, 1.0]:
			root.add_child(_cyl(
				s.x * 0.04, s.x * 0.055, s.z * 0.58, 10, steel_trim,
				Vector3(side * s.x * 0.14, s.y * 0.36, -s.z * 0.24),
				Vector3(90.0, 0.0, 0.0)
			))
			for ring_i in range(3):
				root.add_child(_cyl(
					s.x * 0.062, s.x * 0.062, 0.04, 10, brass_accent,
					Vector3(side * s.x * 0.14, s.y * 0.36, -s.z * (0.12 + float(ring_i) * 0.14)),
					Vector3(90.0, 0.0, 0.0)
				))
			root.add_child(_sphere(
				s.x * 0.038, s.x * 0.075, bridge_lit,
				Vector3(side * s.x * 0.14, s.y * 0.36, -s.z * 0.54)
			))
			root.add_child(_sculpted_block(
				Vector3(s.x * 0.22, s.y * 0.24, s.z * 0.34), gunmetal,
				Vector3(side * s.x * 0.66, 0.0, s.z * 0.12)
			))
			root.add_child(_box(
				Vector3(s.x * 0.14, s.y * 0.12, 0.06), amber_vent,
				Vector3(side * s.x * 0.66, 0.0, -s.z * 0.06)
			))
	elif is_corvette:
		for side in [-1.0, 1.0]:
			root.add_child(_cyl(
				0.015, 0.035, s.z * 0.28, 8, steel_trim,
				Vector3(side * s.x * 0.24, s.y * 0.12, -s.z * 0.56),
				Vector3(86.0, side * -8.0, 0.0)
			))

	var turret_positions := [
		Vector3(0.0, s.y * 0.34, -s.z * 0.30),
		Vector3(0.0, s.y * 0.48, -s.z * 0.14),
		Vector3(0.0, s.y * 0.36, s.z * 0.34),
	]
	if is_corvette:
		turret_positions = [
			Vector3(0.0, s.y * 0.38, -s.z * 0.20),
			Vector3(0.0, s.y * 0.34, s.z * 0.32),
		]

	for idx in range(turret_positions.size()):
		var tpos: Vector3 = turret_positions[idx]
		var dir_z := 1.0 if (idx == turret_positions.size() - 1) else -1.0
		root.add_child(_cyl(s.x * 0.13, s.x * 0.15, s.y * 0.10, 10, dark_steel, tpos - Vector3(0.0, s.y * 0.08, 0.0)))
		root.add_child(_sculpted_block(Vector3(s.x * 0.29, s.y * 0.18, s.z * 0.11), gunmetal, tpos, Vector3.ZERO, 0.84, 0.96))
		root.add_child(_box(Vector3(s.x * 0.24, s.y * 0.04, s.z * 0.08), steel_trim, tpos + Vector3(0.0, s.y * 0.10, 0.0)))
		var barrels := [-1.0, 0.0, 1.0] if is_dread else [-0.6, 0.6]
		for b_off in barrels:
			root.add_child(_cyl(
				s.x * 0.025, s.x * 0.032, s.z * 0.15, 8, steel_trim,
				tpos + Vector3(float(b_off) * s.x * 0.065, s.y * 0.02, dir_z * s.z * 0.085),
				Vector3(90.0, 0.0, 0.0)
			))

	# Broadside Secondary Casemate Batteries
	var casemate_count := 3 if is_dread else (2 if is_bc else 1)
	for side in [-1.0, 1.0]:
		for i in range(casemate_count):
			var z := -s.z * 0.18 + float(i) * s.z * 0.18
			root.add_child(_cyl(
				s.x * 0.08, s.x * 0.11, s.y * 0.22, 8, gunmetal,
				Vector3(side * s.x * 0.48, s.y * 0.22, z)
			))
			root.add_child(_cyl(
				s.x * 0.025, s.x * 0.025, s.x * 0.22, 6, steel_trim,
				Vector3(side * s.x * 0.58, s.y * 0.22, z), Vector3(0.0, 0.0, 90.0)
			))

	# Quad Stern Engine Nacelles & Plasma Thruster Cones
	var v_offsets := [-0.14, 0.14] if not is_corvette else [0.0]
	for side in [-1.0, 1.0]:
		for v_off in v_offsets:
			var ex: float = float(side) * s.x * 0.36
			var ey: float = float(v_off) * s.y
			root.add_child(_cyl(
				s.x * 0.14, s.x * 0.16, s.z * 0.26, 12, gunmetal,
				Vector3(ex, ey, s.z * 0.48), Vector3(-90.0, 0.0, 0.0)
			))
			root.add_child(_cyl(
				s.x * 0.165, s.x * 0.165, 0.04, 12, brass_accent,
				Vector3(ex, ey, s.z * 0.56), Vector3(-90.0, 0.0, 0.0)
			))
			var nozzle := _cyl(
				s.x * 0.11, s.x * 0.18, 0.55, 12, engine_glow,
				Vector3(ex, ey, s.z * 0.62), Vector3(-90.0, 0.0, 0.0)
			)
			root.add_child(nozzle)
			thrusters.append(nozzle)
