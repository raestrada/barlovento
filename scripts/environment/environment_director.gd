class_name EnvironmentDirector
extends Node3D

var _asteroid_root: Node3D
var _calm_root: Node3D
var _stage_landmark_root: Node3D
var _ether_particles: Node3D
var _calm_seeps: Array[Dictionary] = []
var _landmark_rotators: Array[Dictionary] = []
var _ether: EtherField

func setup(stage_id: String, ether_field: EtherField) -> void:
	_ether = ether_field
	_build_ether_flow()
	_build_asteroid_field()
	_build_calm_wavefront()
	_build_stage_landmark()

func update(delta: float) -> void:
	_update_ether_flow(delta)
	_update_scenery(delta)

func is_point_in_calm(pos: Vector3) -> Dictionary:
	var p2 := Vector2(pos.x, pos.z)
	for seep in _calm_seeps:
		var c2: Vector2 = seep.get("pos2", Vector2.ZERO)
		var rad: float = seep.get("radius", 0.0)
		if p2.distance_to(c2) <= rad:
			return {"in_calm": true, "seep": seep}
	return {"in_calm": false, "seep": {}}

func get_nearest_calm_info(pos: Vector3) -> Dictionary:
	var min_dist := 9999.0
	var nearest_name := ""
	var p2 := Vector2(pos.x, pos.z)
	for seep in _calm_seeps:
		var c2: Vector2 = seep.get("pos2", Vector2.ZERO)
		var rad: float = seep.get("radius", 0.0)
		var edge_dist := maxf(p2.distance_to(c2) - rad, 0.0)
		if edge_dist < min_dist:
			min_dist = edge_dist
			nearest_name = seep.get("name", "Calm Seep")
	return {"distance": min_dist, "name": nearest_name}

func advance_calm_wavefront(tw: Tween) -> float:
	if _calm_seeps.is_empty():
		return 0.0
	var avg_growth := 0.0
	for seep in _calm_seeps:
		var growth: float = seep.get("growth", 2.2)
		avg_growth += growth
		var cur_rad: float = seep.get("radius", 20.0) + growth
		seep["radius"] = cur_rad
		var s_root: Node3D = seep.get("root_node")
		if s_root != null and is_instance_valid(s_root):
			var cur_scale: Vector3 = s_root.scale
			var growth_ratio: float = cur_rad / maxf(cur_rad - growth, 1.0)
			var target_scale := Vector3(cur_scale.x * growth_ratio, cur_scale.y, cur_scale.z * growth_ratio)
			tw.tween_property(s_root, "scale", target_scale, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	avg_growth /= float(_calm_seeps.size())
	return avg_growth

func _build_ether_flow() -> void:
	_ether_particles = Node3D.new()
	_ether_particles.name = "EtherFlowField"
	add_child(_ether_particles)

	var is_marea := (LoreDB.current_stage_id == "marea_stage_1")
	var is_vinc := (LoreDB.current_stage_id in ["vinculados_stage_1", "acero_stage_2"])

	var p_count := 110 if is_marea else (70 if is_vinc else 60)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for i in range(p_count):
		var p := MeshInstance3D.new()
		var stream_mesh := CylinderMesh.new()
		stream_mesh.top_radius = 0.04 if is_marea else 0.03
		stream_mesh.bottom_radius = 0.18 if is_marea else 0.14
		stream_mesh.height = 5.8 if is_marea else 4.2

		var stream_mat := StandardMaterial3D.new()
		stream_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		if is_marea:
			# "El Río del Viento" — vibrant electric cyan rushing torrent
			stream_mat.albedo_color = Color(0.25, 0.96, 1.0, 0.65)
			stream_mat.emission_enabled = true
			stream_mat.emission = Color(0.20, 0.85, 1.0)
		elif is_vinc:
			# Harmonic dual-hue violet & cyan ethereal drift
			var is_violet := (i % 2 == 0)
			stream_mat.albedo_color = Color(0.85, 0.38, 1.0, 0.52) if is_violet else Color(0.30, 0.92, 1.0, 0.52)
			stream_mat.emission_enabled = true
			stream_mat.emission = Color(0.70, 0.25, 0.95) if is_violet else Color(0.18, 0.70, 0.85)
		else:
			# Industrial Éteron flow
			stream_mat.albedo_color = Color(0.3, 0.92, 0.98, 0.48)
			stream_mat.emission_enabled = true
			stream_mat.emission = Color(0.15, 0.65, 0.78)

		stream_mesh.material = stream_mat
		p.mesh = stream_mesh

		var pos: Vector3
		if is_marea:
			# Concentrated rushing torrent through the canyon gorge (between X: -38 and +38)
			pos = Vector3(rng.randf_range(-38.0, 38.0), rng.randf_range(-14.0, 14.0), rng.randf_range(-130.0, 130.0))
		else:
			pos = Vector3(rng.randf_range(-140.0, 140.0), rng.randf_range(-25.0, 25.0), rng.randf_range(-140.0, 140.0))

		var cur := _ether.current_at(pos)
		var norm := cur.normalized() if cur.length_squared() > 0.01 else _ether.direction
		var up := Vector3.UP if absf(norm.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		_ether_particles.add_child(p)
		p.position = pos
		p.look_at(pos + norm, up)

func _build_asteroid_field() -> void:
	if _asteroid_root != null and is_instance_valid(_asteroid_root):
		_asteroid_root.queue_free()

	_asteroid_root = Node3D.new()
	_asteroid_root.name = "AsteroidField"
	add_child(_asteroid_root)

	var is_marea := LoreDB.player_faction == "marea_libre"
	var is_vinc := LoreDB.player_faction == "vinculados"
	var stage_id := LoreDB.current_stage_id

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_texture = load("res://assets/backgrounds/asteroid_rock.png")
	if is_vinc:
		rock_mat.albedo_color = Color(0.42, 0.44, 0.58)
		rock_mat.metallic = 0.35
		rock_mat.roughness = 0.70
	elif is_marea:
		rock_mat.albedo_color = Color(0.68, 0.48, 0.36)
		rock_mat.metallic = 0.18
		rock_mat.roughness = 0.88
	else:
		rock_mat.albedo_color = Color(0.48, 0.50, 0.54)
		rock_mat.metallic = 0.25
		rock_mat.roughness = 0.82

	var crystal_mat := StandardMaterial3D.new()
	if is_vinc:
		crystal_mat.albedo_color = Color(0.85, 0.40, 1.0)
		crystal_mat.emission_enabled = true
		crystal_mat.emission = Color(0.78, 0.30, 0.95)
		crystal_mat.emission_energy_multiplier = 2.6
	elif is_marea:
		crystal_mat.albedo_color = Color(0.98, 0.68, 0.20)
		crystal_mat.emission_enabled = true
		crystal_mat.emission = Color(0.95, 0.60, 0.14)
		crystal_mat.emission_energy_multiplier = 1.8
	else:
		crystal_mat.albedo_color = Color(0.2, 0.85, 0.95)
		crystal_mat.emission_enabled = true
		crystal_mat.emission = Color(0.15, 0.75, 0.92)
		crystal_mat.emission_energy_multiplier = 2.2

	var rng := RandomNumberGenerator.new()
	rng.seed = 108

	var reef_positions: Array[Vector3] = []

	var stage_num := 1
	for s in range(1, 13):
		if stage_id.ends_with("_" + str(s)):
			stage_num = s
			break

	if stage_num in [1, 5]:
		# CANYON / BASALT NARROWS: two dense flanking asteroid walls on Port and Starboard
		for z_step in range(-5, 6):
			var z_val := float(z_step) * 16.0
			reef_positions.append(Vector3(-52.0 + rng.randf_range(-6.0, 4.0), rng.randf_range(-10.0, 12.0), z_val))
			reef_positions.append(Vector3(-68.0 + rng.randf_range(-8.0, 6.0), rng.randf_range(-14.0, 16.0), z_val + 6.0))
			reef_positions.append(Vector3(52.0 + rng.randf_range(-4.0, 6.0), rng.randf_range(-10.0, 12.0), z_val))
			reef_positions.append(Vector3(68.0 + rng.randf_range(-6.0, 8.0), rng.randf_range(-14.0, 16.0), z_val - 6.0))
		reef_positions.append(Vector3(-22.0, 8.0, -15.0))
		reef_positions.append(Vector3(22.0, -6.0, 25.0))
	elif stage_num in [2, 7, 10]:
		# CALDERA / RING: floating orbital reef encircling the battle perimeter
		for a_i in range(16):
			var ang := float(a_i) * TAU / 16.0
			var dist := rng.randf_range(65.0, 92.0)
			reef_positions.append(Vector3(cos(ang) * dist, rng.randf_range(-16.0, 18.0), sin(ang) * dist))
	elif stage_num in [4, 8, 11]:
		# CLUSTERED ARCHIPELAGO: tactical asteroid clusters that divide combat into multiple fronts
		var clusters := [
			Vector3(-45.0, 6.0, 15.0),
			Vector3(-38.0, -8.0, -20.0),
			Vector3(45.0, 4.0, 18.0),
			Vector3(38.0, -10.0, -22.0),
			Vector3(-65.0, 12.0, 50.0),
			Vector3(65.0, -12.0, -50.0),
			Vector3(0.0, 15.0, -10.0),
			Vector3(0.0, -15.0, 20.0)
		]
		for c_pos in clusters:
			for sub_i in range(3):
				reef_positions.append(c_pos + Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(-4.0, 4.0), rng.randf_range(-8.0, 8.0)))
	else:
		# OPEN DEEP SPACE ARENA (Stages 3, 6, 9, 12): sparse perimeter asteroids to keep central void completely clear
		for p_i in range(8):
			var ang := float(p_i) * TAU / 8.0
			reef_positions.append(Vector3(cos(ang) * 98.0, rng.randf_range(-20.0, 20.0), sin(ang) * 98.0))

	for base_pos in reef_positions:
		var cluster := Node3D.new()
		cluster.position = base_pos
		cluster.rotation_degrees = Vector3(rng.randf_range(0, 360), rng.randf_range(0, 360), rng.randf_range(0, 360))
		_asteroid_root.add_child(cluster)

		var main_rock := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var rad := rng.randf_range(2.8, 6.2 if is_marea else 5.2)
		sphere.radius = rad
		sphere.height = rad * 1.65
		sphere.radial_segments = 7
		sphere.rings = 5
		main_rock.mesh = sphere
		main_rock.scale = Vector3(1.2, 0.75, 0.95)
		main_rock.material_override = rock_mat
		cluster.add_child(main_rock)

		var crystal := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(rad * 0.45, rad * 1.35, rad * 0.45)
		crystal.mesh = prism
		crystal.position = Vector3(0.0, rad * 0.65, 0.0)
		crystal.rotation_degrees = Vector3(18.0, 35.0, -12.0)
		crystal.material_override = crystal_mat
		cluster.add_child(crystal)

func _build_calm_wavefront() -> void:
	# Lore Pillar (§9 of DESIGN.md): "The Calm" (La Calma) — cosmological incursion of dead vacuum
	# manifesting as organic, viscous dimensional fluid spilling into the Star Sea from multiple rifts and flanks.
	if _calm_root != null and is_instance_valid(_calm_root):
		_calm_root.queue_free()

	_calm_root = Node3D.new()
	_calm_root.name = "DimensionalCalmFluidRoot"
	add_child(_calm_root)
	_calm_seeps.clear()

	var is_stage_3 := (LoreDB.current_stage_id == "acero_stage_3")

	var seep_configs: Array[Dictionary] = [
		{
			"id": "nw_abyssal_rift",
			"name": "Northwest Abyssal Rift",
			"pos": Vector3(-58.0, 0.0, -42.0 if is_stage_3 else -65.0),
			"radius": 34.0 if is_stage_3 else 26.0,
			"growth": 2.4,
			"color": Color(0.02, 0.005, 0.045, 0.38),
			"glow": Color(0.20, 0.03, 0.30),
			"lobe_count": 5,
		},
		{
			"id": "ne_void_spill",
			"name": "Northeast Void Incursion",
			"pos": Vector3(56.0, 0.0, -46.0 if is_stage_3 else -70.0),
			"radius": 36.0 if is_stage_3 else 28.0,
			"growth": 2.2,
			"color": Color(0.015, 0.004, 0.04, 0.36),
			"glow": Color(0.18, 0.025, 0.26),
			"lobe_count": 5,
		},
		{
			"id": "north_deep_breach",
			"name": "Deep Northern Breach",
			"pos": Vector3(0.0, 0.0, -78.0 if is_stage_3 else -95.0),
			"radius": 46.0 if is_stage_3 else 36.0,
			"growth": 2.8,
			"color": Color(0.025, 0.006, 0.05, 0.42),
			"glow": Color(0.22, 0.04, 0.34),
			"lobe_count": 6,
		},
		{
			"id": "west_flank_seep",
			"name": "Western Flank Incursion",
			"pos": Vector3(-56.0, 0.0, 16.0 if is_stage_3 else 8.0),
			"radius": 24.0 if is_stage_3 else 18.0,
			"growth": 1.8,
			"color": Color(0.018, 0.005, 0.038, 0.34),
			"glow": Color(0.16, 0.02, 0.24),
			"lobe_count": 4,
		},
	]

	if is_stage_3:
		seep_configs.append({
			"id": "east_flank_eddy",
			"name": "Eastern Void Eddy",
			"pos": Vector3(58.0, 0.0, 24.0),
			"radius": 22.0,
			"growth": 1.6,
			"color": Color(0.018, 0.005, 0.038, 0.34),
			"glow": Color(0.16, 0.02, 0.24),
			"lobe_count": 4,
		})

	for cfg in seep_configs:
		var s_root := Node3D.new()
		s_root.name = "CalmSeep_" + String(cfg["id"])
		s_root.position = cfg["pos"]
		_calm_root.add_child(s_root)

		var seep_dict: Dictionary = {
			"id": cfg["id"],
			"name": cfg["name"],
			"center": cfg["pos"],
			"pos2": Vector2(cfg["pos"].x, cfg["pos"].z),
			"radius": cfg["radius"],
			"growth": cfg["growth"],
			"root_node": s_root,
			"lobes": []
		}

		var base_mat := StandardMaterial3D.new()
		base_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		base_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		base_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		base_mat.proximity_fade_enabled = true
		base_mat.proximity_fade_distance = 7.5
		base_mat.albedo_color = cfg["color"]
		base_mat.emission_enabled = true
		base_mat.emission = cfg["glow"]
		base_mat.emission_energy_multiplier = 0.75

		var lobe_mesh := SphereMesh.new()
		lobe_mesh.radial_segments = 24
		lobe_mesh.rings = 12
		lobe_mesh.radius = 1.0
		lobe_mesh.height = 2.0

		var lobe_count: int = cfg["lobe_count"]
		var s_rad: float = cfg["radius"]
		for l in range(lobe_count):
			var lobe := MeshInstance3D.new()
			lobe.mesh = lobe_mesh
			lobe.material_override = base_mat

			var angle := (float(l) / float(lobe_count)) * TAU + randf_range(-0.35, 0.35)
			var offset_dist := randf_range(s_rad * 0.15, s_rad * 0.40)
			var lx := cos(angle) * offset_dist
			var lz := sin(angle) * offset_dist
			var ly := randf_range(-0.6, 0.6)

			lobe.position = Vector3(lx, ly, lz)

			var r_scale_x := s_rad * randf_range(0.70, 0.95)
			var r_scale_z := s_rad * randf_range(0.70, 0.95)
			var r_scale_y := randf_range(1.4, 2.8)
			lobe.scale = Vector3(r_scale_x, r_scale_y, r_scale_z)
			lobe.rotation_degrees.y = randf_range(0.0, 360.0)

			lobe.set_meta("rot_speed", randf_range(-0.04, 0.04))
			lobe.set_meta("pulse_phase", float(l) * 1.3)
			lobe.set_meta("base_scale", lobe.scale)

			s_root.add_child(lobe)
			seep_dict["lobes"].append(lobe)

		# Dense dimensional rift core at center
		var core := MeshInstance3D.new()
		core.mesh = lobe_mesh
		var core_mat := StandardMaterial3D.new()
		core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		core_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		core_mat.proximity_fade_enabled = true
		core_mat.proximity_fade_distance = 4.0
		var c_col: Color = cfg["color"]
		core_mat.albedo_color = Color(c_col.r * 0.7, c_col.g * 0.7, c_col.b * 0.7, 0.55)
		core_mat.emission_enabled = true
		var c_glow: Color = cfg["glow"]
		core_mat.emission = c_glow * 1.2
		core_mat.emission_energy_multiplier = 0.9
		core.material_override = core_mat
		core.scale = Vector3(s_rad * 0.45, 2.0, s_rad * 0.45)
		core.position = Vector3(0.0, 0.1, 0.0)
		core.set_meta("rot_speed", randf_range(0.02, 0.05))
		core.set_meta("pulse_phase", 0.0)
		core.set_meta("base_scale", core.scale)
		s_root.add_child(core)
		seep_dict["lobes"].append(core)

		# Subtle floating dimensional motes
		for m in range(8):
			var mote := MeshInstance3D.new()
			var mm := SphereMesh.new()
			mm.radius = randf_range(0.5, 1.1)
			mm.height = mm.radius * 2.0
			mote.mesh = mm
			var m_mat := StandardMaterial3D.new()
			m_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m_mat.albedo_color = Color(c_glow.r, c_glow.g, c_glow.b, 0.28)
			mote.material_override = m_mat
			var ma := randf_range(0.0, TAU)
			var md := randf_range(s_rad * 0.2, s_rad * 0.9)
			mote.position = Vector3(cos(ma) * md, randf_range(0.5, 4.0), sin(ma) * md)
			mote.set_meta("mote_speed", randf_range(0.6, 1.4))
			mote.set_meta("base_y", mote.position.y)
			s_root.add_child(mote)

		_calm_seeps.append(seep_dict)

var _stage_landmark_root: Node3D = null
var _landmark_rotators: Array[Dictionary] = []

func _register_landmark_rotator(node: Node3D, axis: Vector3, speed: float) -> void:
	_landmark_rotators.append({"node": node, "axis": axis, "speed": speed})

func _build_stage_landmark() -> void:
	if _stage_landmark_root != null and is_instance_valid(_stage_landmark_root):
		_stage_landmark_root.queue_free()
	_landmark_rotators.clear()

	match LoreDB.current_stage_id:
		"acero_stage_1":
			# Sluice Station Well-09 anchored behind player fleet (allied defensive perimeter)
			_build_acero_sluice_station(Vector3(0.0, -2.0, 75.0), Vector3(0.0, 15.0, 0.0))
		"acero_stage_2":
			# Sanctuary Spire on eastern flank
			_build_vinculados_sanctuary_spire(Vector3(48.0, 10.0, -35.0), Vector3(0.0, 25.0, 0.0))
		"acero_stage_3":
			# Calm Bastion Fortified Station on western flank
			_build_acero_calm_bastion(Vector3(-48.0, 6.0, 65.0), Vector3(0.0, 12.0, 0.0))
		"acero_stage_4":
			# Contested Western Sluice Refinery
			_build_acero_sluice_station(Vector3(-52.0, -4.0, -35.0), Vector3(0.0, -20.0, 0.0))
		"acero_stage_5":
			# Corsair Haven deep in enemy stronghold territory
			_build_marea_corsair_haven(Vector3(0.0, 8.0, -82.0), Vector3(0.0, -15.0, 0.0))
		"acero_stage_6":
			# OPEN DEEP SPACE DOGFIGHT: zero central obstruction for high-speed interceptors!
			pass
		"acero_stage_7":
			# Grand Iron Bastion behind player line (defense of the dam foundations)
			_build_acero_calm_bastion(Vector3(0.0, 12.0, 78.0), Vector3(0.0, 0.0, 0.0))
		"acero_stage_8":
			# Ore Smelter Foundry Complex Vulcan-3 deep behind enemy lines
			_build_marea_foundry_complex(Vector3(45.0, -6.0, -80.0), Vector3(0.0, 20.0, 0.0))
		"acero_stage_9":
			# OPEN VOID GRAND FLEET ENGAGEMENT: open 3-vector tactical arena
			pass
		"acero_stage_10":
			# Genesis Ring Megastructure contested on western vector
			_build_vinculados_genesis_ring(Vector3(-50.0, 15.0, -45.0), Vector3(15.0, 30.0, 0.0))
		"acero_stage_11":
			# Supreme Fortified Bastion at the Calm Event Horizon
			_build_acero_calm_bastion(Vector3(0.0, 12.0, -85.0), Vector3(0.0, 12.0, 0.0))
		"acero_stage_12":
			# Transcendence Genesis Ring at cosmic apex
			_build_vinculados_genesis_ring(Vector3(0.0, 18.0, -90.0), Vector3(15.0, 30.0, 0.0))

		"vinculados_stage_1":
			# Sanctuary Spire Psalm-4 behind player fleet
			_build_vinculados_sanctuary_spire(Vector3(0.0, 6.0, 76.0), Vector3(0.0, 18.0, 0.0))
		"vinculados_stage_2":
			# Deep Crystal Chasm floor below (mobile suits dive from high Z-altitude)
			_build_vinculados_crystal_chasm(Vector3(0.0, -18.0, 0.0), Vector3(0.0, -15.0, 0.0))
		"vinculados_stage_3":
			# Genesis Ring in deep reserve behind combat line
			_build_vinculados_genesis_ring(Vector3(0.0, 16.0, -78.0), Vector3(15.0, 30.0, 0.0))
		"vinculados_stage_4":
			# Sacred Spire on rear western terrace
			_build_vinculados_sanctuary_spire(Vector3(-45.0, 8.0, 68.0), Vector3(0.0, 18.0, 0.0))
		"vinculados_stage_5":
			# Acero Fortified Bastion deep in enemy territory
			_build_acero_calm_bastion(Vector3(0.0, 8.0, -82.0), Vector3(0.0, 12.0, 0.0))
		"vinculados_stage_6":
			# OPEN CELESTIAL VOID DOGFIGHT: zero central obstruction
			pass
		"vinculados_stage_7":
			# Flank Crystal Chasm Trench
			_build_vinculados_crystal_chasm(Vector3(48.0, -14.0, -20.0), Vector3(0.0, -15.0, 0.0))
		"vinculados_stage_8":
			# Corsair Haven deep behind enemy lines
			_build_marea_corsair_haven(Vector3(-45.0, 10.0, -78.0), Vector3(0.0, -18.0, 0.0))
		"vinculados_stage_9":
			# OPEN CELESTIAL GRAND FLEET CLASH
			pass
		"vinculados_stage_10":
			# Acero Heavy Sluice Station on eastern flank
			_build_acero_sluice_station(Vector3(48.0, -4.0, -78.0), Vector3(0.0, 24.0, 0.0))
		"vinculados_stage_11":
			# Fortress Bastion guarding the Calm breach
			_build_acero_calm_bastion(Vector3(0.0, 12.0, -85.0), Vector3(0.0, 12.0, 0.0))
		"vinculados_stage_12":
			# Supreme Transcendence Ring Megastructure
			_build_vinculados_genesis_ring(Vector3(0.0, 20.0, -92.0), Vector3(15.0, 30.0, 0.0))

		"marea_stage_1":
			# Corsair Free Haven behind player fleet
			_build_marea_corsair_haven(Vector3(0.0, 8.0, 76.0), Vector3(0.0, -18.0, 0.0))
		"marea_stage_2":
			# Imperial Smelter Foundry Complex Vulcan-3 on eastern flank
			_build_marea_foundry_complex(Vector3(45.0, -6.0, -75.0), Vector3(0.0, 20.0, 0.0))
		"marea_stage_3":
			# Cosmic Storm Maelstrom Vortex on western flank
			_build_marea_wind_maelstrom(Vector3(-38.0, 16.0, -45.0), Vector3(0.0, 0.0, 0.0))
		"marea_stage_4":
			# Corsair Haven rear western anchorage
			_build_marea_corsair_haven(Vector3(-42.0, 8.0, 70.0), Vector3(0.0, -18.0, 0.0))
		"marea_stage_5":
			# Imperial Sluice Station Well-09 deep in enemy territory
			_build_acero_sluice_station(Vector3(0.0, -2.0, -82.0), Vector3(0.0, 24.0, 0.0))
		"marea_stage_6":
			# OPEN MAELSTROM RAPIDS DOGFIGHT: zero central obstruction
			pass
		"marea_stage_7":
			# Imperial Fortified Bastion on eastern flank
			_build_acero_calm_bastion(Vector3(45.0, 10.0, -80.0), Vector3(0.0, 12.0, 0.0))
		"marea_stage_8":
			# Celestial Resonance Spire on western flank
			_build_vinculados_sanctuary_spire(Vector3(-45.0, 12.0, -75.0), Vector3(0.0, 18.0, 0.0))
		"marea_stage_9":
			# OPEN TEMPEST WEATHER-GAUGE GRAND ARMADA CLASH
			pass
		"marea_stage_10":
			# Industrial Foundry Complex Vulcan-3 deep on western flank
			_build_marea_foundry_complex(Vector3(-48.0, -8.0, -80.0), Vector3(0.0, 20.0, 0.0))
		"marea_stage_11":
			# Breaching the Calm Bastion at the Singularity Ridge
			_build_acero_calm_bastion(Vector3(0.0, 12.0, -85.0), Vector3(0.0, 12.0, 0.0))
		"marea_stage_12":
			# Supreme Maelstrom of Barlovento Vortex at the solar core
			_build_marea_wind_maelstrom(Vector3(0.0, 18.0, -92.0), Vector3(0.0, 0.0, 0.0))

		_:
			_build_acero_sluice_station(Vector3(-38.0, 0.0, 25.0), Vector3(0.0, 24.0, 0.0))

func _build_acero_sluice_station(pos: Vector3 = Vector3(-38.0, 0.0, 25.0), rot: Vector3 = Vector3(0.0, 24.0, 0.0)) -> void:
	# Colossal Textured 3D Acero Éteron Sluice-Gate Refinery
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "SluiceStationWell09"
	_stage_landmark_root.position = pos
	_stage_landmark_root.rotation_degrees = rot
	add_child(_stage_landmark_root)

	var hull_tex: Texture2D = load("res://assets/ships/acero/acero_hull.png")

	var armor_tex_mat := StandardMaterial3D.new()
	armor_tex_mat.albedo_texture = hull_tex
	armor_tex_mat.albedo_color = Color(1.65, 1.72, 1.85)
	armor_tex_mat.uv1_scale = Vector3(3.5, 3.5, 1.0)
	armor_tex_mat.metallic = 0.45
	armor_tex_mat.roughness = 0.40
	armor_tex_mat.rim_enabled = true
	armor_tex_mat.rim = 0.50
	armor_tex_mat.emission_enabled = true
	armor_tex_mat.emission = Color(0.09, 0.12, 0.17)
	armor_tex_mat.emission_energy_multiplier = 0.35

	var dark_steel_mat := StandardMaterial3D.new()
	dark_steel_mat.albedo_texture = hull_tex
	dark_steel_mat.albedo_color = Color(1.15, 1.22, 1.34)
	dark_steel_mat.uv1_scale = Vector3(5.0, 5.0, 1.0)
	dark_steel_mat.metallic = 0.52
	dark_steel_mat.roughness = 0.36
	dark_steel_mat.rim_enabled = true
	dark_steel_mat.rim = 0.45

	var trim_steel := StandardMaterial3D.new()
	trim_steel.albedo_color = Color(0.56, 0.62, 0.72)
	trim_steel.metallic = 0.55
	trim_steel.roughness = 0.28

	var furnace_amber := StandardMaterial3D.new()
	furnace_amber.albedo_color = Color(1.0, 0.52, 0.14)
	furnace_amber.emission_enabled = true
	furnace_amber.emission = Color(0.98, 0.45, 0.10)
	furnace_amber.emission_energy_multiplier = 1.65

	var molten_core_mat := StandardMaterial3D.new()
	molten_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	molten_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	molten_core_mat.albedo_color = Color(1.0, 0.58, 0.16, 0.88)
	molten_core_mat.emission_enabled = true
	molten_core_mat.emission = Color(1.0, 0.46, 0.10)
	molten_core_mat.emission_energy_multiplier = 1.85

	var sluice_cyan := StandardMaterial3D.new()
	sluice_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sluice_cyan.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sluice_cyan.albedo_color = Color(0.18, 0.78, 0.95, 0.55)
	sluice_cyan.emission_enabled = true
	sluice_cyan.emission = Color(0.15, 0.68, 0.88)
	sluice_cyan.emission_energy_multiplier = 0.95

	# Dedicated Station Illumination Lights (Warm Forge Light + Cool Collector Light)
	var forge_light := OmniLight3D.new()
	forge_light.position = Vector3(0.0, 8.0, 6.0)
	forge_light.light_color = Color(1.0, 0.62, 0.25)
	forge_light.light_energy = 1.8
	forge_light.omni_range = 36.0
	_stage_landmark_root.add_child(forge_light)

	var ring_light := OmniLight3D.new()
	ring_light.position = Vector3(0.0, 2.0, -14.0)
	ring_light.light_color = Color(0.35, 0.85, 1.0)
	ring_light.light_energy = 1.5
	ring_light.omni_range = 32.0
	_stage_landmark_root.add_child(ring_light)

	# 1. Central Multi-Tiered Octagonal Blast-Furnace Citadel
	var base_drum := MeshInstance3D.new()
	var bd_cyl := CylinderMesh.new()
	bd_cyl.top_radius = 9.2
	bd_cyl.bottom_radius = 7.4
	bd_cyl.height = 7.5
	bd_cyl.radial_segments = 12
	base_drum.mesh = bd_cyl
	base_drum.position = Vector3(0.0, 0.0, 6.0)
	base_drum.material_override = armor_tex_mat
	_stage_landmark_root.add_child(base_drum)

	var upper_citadel := MeshInstance3D.new()
	var uc_cyl := CylinderMesh.new()
	uc_cyl.top_radius = 6.8
	uc_cyl.bottom_radius = 8.4
	uc_cyl.height = 6.0
	uc_cyl.radial_segments = 8
	upper_citadel.mesh = uc_cyl
	upper_citadel.position = Vector3(0.0, 6.2, 6.0)
	upper_citadel.material_override = dark_steel_mat
	_stage_landmark_root.add_child(upper_citadel)

	# Glowing Molten Blast-Furnace Crown & Lower Crucible Vent
	var crown_furnace := MeshInstance3D.new()
	var cf_cyl := CylinderMesh.new()
	cf_cyl.top_radius = 5.2
	cf_cyl.bottom_radius = 5.8
	cf_cyl.height = 2.4
	cf_cyl.radial_segments = 12
	crown_furnace.mesh = cf_cyl
	crown_furnace.position = Vector3(0.0, 9.8, 6.0)
	crown_furnace.material_override = molten_core_mat
	_stage_landmark_root.add_child(crown_furnace)

	var lower_crucible := MeshInstance3D.new()
	var lc_cyl := CylinderMesh.new()
	lc_cyl.top_radius = 4.2
	lc_cyl.bottom_radius = 1.2
	lc_cyl.height = 6.5
	lc_cyl.radial_segments = 10
	lower_crucible.mesh = lc_cyl
	lower_crucible.position = Vector3(0.0, -6.5, 6.0)
	lower_crucible.material_override = dark_steel_mat
	_stage_landmark_root.add_child(lower_crucible)

	# 6 Towering Industrial Smokestacks around the Citadel
	for i in range(6):
		var ang := float(i) * TAU / 6.0
		var sx := cos(ang) * 6.2
		var sz := 6.0 + sin(ang) * 6.2
		var stack := MeshInstance3D.new()
		var st_cyl := CylinderMesh.new()
		st_cyl.top_radius = 0.65
		st_cyl.bottom_radius = 0.95
		st_cyl.height = 9.5 + float(i % 2) * 3.0
		st_cyl.radial_segments = 8
		stack.mesh = st_cyl
		stack.position = Vector3(sx, 8.5 + float(i % 2) * 1.5, sz)
		stack.material_override = armor_tex_mat
		_stage_landmark_root.add_child(stack)

		var stack_glow := MeshInstance3D.new()
		var sg_cyl := CylinderMesh.new()
		sg_cyl.top_radius = 0.55
		sg_cyl.bottom_radius = 0.55
		sg_cyl.height = 0.8
		stack_glow.mesh = sg_cyl
		stack_glow.position = stack.position + Vector3(0.0, st_cyl.height * 0.5, 0.0)
		stack_glow.material_override = furnace_amber
		_stage_landmark_root.add_child(stack_glow)

	# Port & Starboard Heavy Docking Gantries
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var w_box := BoxMesh.new()
		w_box.size = Vector3(8.5, 3.2, 4.4)
		wing.mesh = w_box
		wing.position = Vector3(float(side) * 11.2, 0.5, 6.0)
		wing.material_override = armor_tex_mat
		_stage_landmark_root.add_child(wing)

		var trim_bar := MeshInstance3D.new()
		var tb_box := BoxMesh.new()
		tb_box.size = Vector3(9.0, 0.45, 4.8)
		trim_bar.mesh = tb_box
		trim_bar.position = Vector3(float(side) * 11.2, 2.2, 6.0)
		trim_bar.material_override = trim_steel
		_stage_landmark_root.add_child(trim_bar)

		for w_i in range(3):
			var win := MeshInstance3D.new()
			var win_box := BoxMesh.new()
			win_box.size = Vector3(1.6, 0.9, 4.55)
			win.mesh = win_box
			win.position = Vector3(float(side) * (8.5 + float(w_i) * 2.4), 0.5, 6.0)
			win.material_override = furnace_amber
			_stage_landmark_root.add_child(win)

	# 2. Axial Sluice Conduit Barrel extending forward (-Z)
	var conduit := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 3.2
	c_cyl.bottom_radius = 3.8
	c_cyl.height = 16.0
	c_cyl.radial_segments = 12
	conduit.mesh = c_cyl
	conduit.position = Vector3(0.0, 1.2, -4.5)
	conduit.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	conduit.material_override = dark_steel_mat
	_stage_landmark_root.add_child(conduit)

	for rib_i in range(4):
		var rib := MeshInstance3D.new()
		var r_tor := TorusMesh.new()
		r_tor.inner_radius = 3.4
		r_tor.outer_radius = 4.3
		r_tor.rings = 16
		r_tor.ring_segments = 8
		rib.mesh = r_tor
		rib.position = Vector3(0.0, 1.2, 1.0 - float(rib_i) * 3.6)
		rib.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		rib.material_override = trim_steel
		_stage_landmark_root.add_child(rib)

	# 3. Colossal Forward Collector Rings (Outer & Inner Counter-Rotating)
	var outer_ring_node := Node3D.new()
	outer_ring_node.position = Vector3(0.0, 1.2, -13.5)
	_stage_landmark_root.add_child(outer_ring_node)
	_register_landmark_rotator(outer_ring_node, Vector3.FORWARD, 0.18)

	var main_ring := MeshInstance3D.new()
	var mr_tor := TorusMesh.new()
	mr_tor.inner_radius = 7.2
	mr_tor.outer_radius = 9.4
	mr_tor.rings = 32
	mr_tor.ring_segments = 12
	main_ring.mesh = mr_tor
	main_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	main_ring.material_override = armor_tex_mat
	outer_ring_node.add_child(main_ring)

	for c_i in range(8):
		var c_ang := float(c_i) * TAU / 8.0
		var pylon := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(1.8, 3.6, 2.4)
		pylon.mesh = p_box
		pylon.position = Vector3(cos(c_ang) * 9.2, sin(c_ang) * 9.2, 0.0)
		pylon.rotation = Vector3(0.0, 0.0, c_ang + PI * 0.5)
		pylon.material_override = trim_steel
		outer_ring_node.add_child(pylon)

	var inner_ring_node := Node3D.new()
	inner_ring_node.position = Vector3(0.0, 1.2, -13.5)
	_stage_landmark_root.add_child(inner_ring_node)
	_register_landmark_rotator(inner_ring_node, Vector3.FORWARD, -0.35)

	var inner_ring := MeshInstance3D.new()
	var ir_tor := TorusMesh.new()
	ir_tor.inner_radius = 5.4
	ir_tor.outer_radius = 6.6
	ir_tor.rings = 28
	ir_tor.ring_segments = 10
	inner_ring.mesh = ir_tor
	inner_ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	inner_ring.material_override = furnace_amber
	inner_ring_node.add_child(inner_ring)

	var aperture_core := MeshInstance3D.new()
	var ac_cyl := CylinderMesh.new()
	ac_cyl.top_radius = 4.8
	ac_cyl.bottom_radius = 2.6
	ac_cyl.height = 18.0
	ac_cyl.radial_segments = 16
	aperture_core.mesh = ac_cyl
	aperture_core.position = Vector3(0.0, 1.2, -18.0)
	aperture_core.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	aperture_core.material_override = sluice_cyan
	_stage_landmark_root.add_child(aperture_core)

	var station_lbl := Label3D.new()
	station_lbl.text = "◆ SLUICE STATION WELL-09\n[ACERO ÉTERON REFINERY]"
	station_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_lbl.font_size = 14
	station_lbl.modulate = Color(1.0, 0.78, 0.32)
	station_lbl.outline_modulate = Color(0.01, 0.02, 0.05, 0.95)
	station_lbl.outline_size = 3
	station_lbl.position = Vector3(0.0, 16.5, 6.0)
	_stage_landmark_root.add_child(station_lbl)

func _build_vinculados_sanctuary_spire(pos: Vector3 = Vector3(36.0, 8.0, -35.0), rot: Vector3 = Vector3(0.0, 18.0, 0.0)) -> void:
	# Colossal Pearlescent Ceramic Resonance Sanctuary Spire
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "SanctuarySpirePsalm4"
	_stage_landmark_root.position = pos
	_stage_landmark_root.rotation_degrees = rot
	add_child(_stage_landmark_root)

	var ceramic := StandardMaterial3D.new()
	ceramic.albedo_texture = load("res://assets/ships/vinculados/vinculados_hull.png")
	ceramic.albedo_color = Color(1.0, 1.0, 1.0)
	ceramic.metallic = 0.16
	ceramic.roughness = 0.22
	ceramic.rim_enabled = true
	ceramic.rim = 0.65
	ceramic.rim_tint = 0.40

	var cobalt_blue := StandardMaterial3D.new()
	cobalt_blue.albedo_color = Color(0.12, 0.22, 0.46)
	cobalt_blue.metallic = 0.45
	cobalt_blue.roughness = 0.35

	var frame_dark := StandardMaterial3D.new()
	frame_dark.albedo_color = Color(0.12, 0.14, 0.20)
	frame_dark.metallic = 0.72
	frame_dark.roughness = 0.36

	var soul_core_mat := ShipModelBuilder._get_soul_core_material()

	var cyan_glow := StandardMaterial3D.new()
	cyan_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan_glow.albedo_color = Color(0.30, 0.92, 1.0)
	cyan_glow.emission_enabled = true
	cyan_glow.emission = Color(0.25, 0.88, 1.0)
	cyan_glow.emission_energy_multiplier = 2.4

	var violet_glow := StandardMaterial3D.new()
	violet_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	violet_glow.albedo_color = Color(0.85, 0.40, 1.0)
	violet_glow.emission_enabled = true
	violet_glow.emission = Color(0.78, 0.32, 0.95)
	violet_glow.emission_energy_multiplier = 2.2

	# Dedicated Sanctuary Ethereal Lights
	var core_light := OmniLight3D.new()
	core_light.position = Vector3(0.0, 18.0, 0.0)
	core_light.light_color = Color(0.85, 0.35, 1.0)
	core_light.light_energy = 2.4
	core_light.omni_range = 45.0
	_stage_landmark_root.add_child(core_light)

	var crown_light := OmniLight3D.new()
	crown_light.position = Vector3(0.0, 38.0, 0.0)
	crown_light.light_color = Color(0.25, 0.90, 1.0)
	crown_light.light_energy = 1.8
	crown_light.omni_range = 38.0
	_stage_landmark_root.add_child(crown_light)

	# 1. Tiered Sanctuary Altar Platform
	var base_altar := MeshInstance3D.new()
	var ba_cyl := CylinderMesh.new()
	ba_cyl.top_radius = 13.5
	ba_cyl.bottom_radius = 15.5
	ba_cyl.height = 3.6
	ba_cyl.radial_segments = 8
	base_altar.mesh = ba_cyl
	base_altar.position = Vector3(0.0, 1.8, 0.0)
	base_altar.material_override = ceramic
	_stage_landmark_root.add_child(base_altar)

	var inner_deck := MeshInstance3D.new()
	var id_cyl := CylinderMesh.new()
	id_cyl.top_radius = 10.0
	id_cyl.bottom_radius = 11.5
	id_cyl.height = 2.2
	id_cyl.radial_segments = 8
	inner_deck.mesh = id_cyl
	inner_deck.position = Vector3(0.0, 4.2, 0.0)
	inner_deck.material_override = cobalt_blue
	_stage_landmark_root.add_child(inner_deck)

	# 2. Soaring Cathedral Spire (Tapered 44m Tower)
	var spire_tower := MeshInstance3D.new()
	var st_cyl := CylinderMesh.new()
	st_cyl.top_radius = 1.4
	st_cyl.bottom_radius = 6.8
	st_cyl.height = 38.0
	st_cyl.radial_segments = 8
	spire_tower.mesh = st_cyl
	spire_tower.position = Vector3(0.0, 24.0, 0.0)
	spire_tower.material_override = ceramic
	_stage_landmark_root.add_child(spire_tower)

	var crown_fin := MeshInstance3D.new()
	var cf_prism := PrismMesh.new()
	cf_prism.size = Vector3(2.6, 9.5, 2.6)
	crown_fin.mesh = cf_prism
	crown_fin.position = Vector3(0.0, 47.5, 0.0)
	crown_fin.material_override = cobalt_blue
	_stage_landmark_root.add_child(crown_fin)

	# 4 Flying Cathedral Buttresses around Spire Base
	for i in range(4):
		var ang := float(i) * TAU / 4.0
		var bx := cos(ang) * 9.5
		var bz := sin(ang) * 9.5
		var buttress := MeshInstance3D.new()
		var b_box := BoxMesh.new()
		b_box.size = Vector3(1.6, 18.0, 3.8)
		buttress.mesh = b_box
		buttress.position = Vector3(bx, 12.0, bz)
		buttress.rotation = Vector3(0.0, -ang + PI * 0.5, 0.22)
		buttress.material_override = ceramic
		_stage_landmark_root.add_child(buttress)

	# 3. Colossal Pulsing Magenta Soul Core in Center of Spire
	var core_ring := MeshInstance3D.new()
	var cr_tor := TorusMesh.new()
	cr_tor.inner_radius = 4.8
	cr_tor.outer_radius = 5.8
	core_ring.mesh = cr_tor
	core_ring.position = Vector3(0.0, 18.0, 0.0)
	core_ring.material_override = frame_dark
	_stage_landmark_root.add_child(core_ring)

	var soul_sphere := MeshInstance3D.new()
	var ss_mesh := SphereMesh.new()
	ss_mesh.radius = 4.0
	ss_mesh.height = 8.0
	soul_sphere.mesh = ss_mesh
	soul_sphere.position = Vector3(0.0, 18.0, 0.0)
	soul_sphere.material_override = soul_core_mat
	_stage_landmark_root.add_child(soul_sphere)

	# 4. Three Concentric Levitating Harmonic Tuning Rings (Rotating on Y at different elevations & speeds)
	# Ring 1 (Lower, wide):
	var r1_node := Node3D.new()
	r1_node.position = Vector3(0.0, 12.0, 0.0)
	_stage_landmark_root.add_child(r1_node)
	_register_landmark_rotator(r1_node, Vector3.UP, 0.14)

	var ring1 := MeshInstance3D.new()
	var r1_tor := TorusMesh.new()
	r1_tor.inner_radius = 12.8
	r1_tor.outer_radius = 14.8
	ring1.mesh = r1_tor
	ring1.material_override = ceramic
	r1_node.add_child(ring1)

	for c_i in range(8):
		var c_ang := float(c_i) * TAU / 8.0
		var glyph := MeshInstance3D.new()
		var g_box := BoxMesh.new()
		g_box.size = Vector3(0.8, 0.4, 1.8)
		glyph.mesh = g_box
		glyph.position = Vector3(cos(c_ang) * 13.8, 0.0, sin(c_ang) * 13.8)
		glyph.material_override = cyan_glow
		r1_node.add_child(glyph)

	# Ring 2 (Mid, inclined 22 deg):
	var r2_node := Node3D.new()
	r2_node.position = Vector3(0.0, 26.0, 0.0)
	r2_node.rotation_degrees = Vector3(22.0, 0.0, 0.0)
	_stage_landmark_root.add_child(r2_node)
	_register_landmark_rotator(r2_node, Vector3.UP, -0.22)

	var ring2 := MeshInstance3D.new()
	var r2_tor := TorusMesh.new()
	r2_tor.inner_radius = 8.6
	r2_tor.outer_radius = 10.4
	ring2.mesh = r2_tor
	ring2.material_override = cobalt_blue
	r2_node.add_child(ring2)

	for v_i in range(6):
		var v_ang := float(v_i) * TAU / 6.0
		var v_node := MeshInstance3D.new()
		var v_box := BoxMesh.new()
		v_box.size = Vector3(0.6, 0.5, 1.5)
		v_node.mesh = v_box
		v_node.position = Vector3(cos(v_ang) * 9.5, 0.0, sin(v_ang) * 9.5)
		v_node.material_override = violet_glow
		r2_node.add_child(v_node)

	# Ring 3 (Upper, inclined -18 deg):
	var r3_node := Node3D.new()
	r3_node.position = Vector3(0.0, 36.0, 0.0)
	r3_node.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	_stage_landmark_root.add_child(r3_node)
	_register_landmark_rotator(r3_node, Vector3.UP, 0.32)

	var ring3 := MeshInstance3D.new()
	var r3_tor := TorusMesh.new()
	r3_tor.inner_radius = 5.2
	r3_tor.outer_radius = 6.8
	ring3.mesh = r3_tor
	ring3.material_override = cyan_glow
	r3_node.add_child(ring3)

	# 5. Four Levitating Monoliths with Vertical Cyan Beacons
	for m_i in range(4):
		var m_ang := float(m_i) * TAU / 4.0 + PI * 0.25
		var mx := cos(m_ang) * 23.0
		var mz := sin(m_ang) * 23.0
		var obelisk := MeshInstance3D.new()
		var o_box := BoxMesh.new()
		o_box.size = Vector3(1.6, 9.0, 1.6)
		obelisk.mesh = o_box
		obelisk.position = Vector3(mx, 6.0, mz)
		obelisk.material_override = ceramic
		_stage_landmark_root.add_child(obelisk)

		var beacon := MeshInstance3D.new()
		var b_cyl := CylinderMesh.new()
		b_cyl.top_radius = 0.12
		b_cyl.bottom_radius = 0.12
		b_cyl.height = 35.0
		beacon.mesh = b_cyl
		beacon.position = Vector3(mx, 22.0, mz)
		beacon.material_override = cyan_glow
		_stage_landmark_root.add_child(beacon)

	var station_lbl := Label3D.new()
	station_lbl.text = "✧ SANCTUARY SPIRE PSALM-4\n[VINCULADOS MONASTIC CRADLE]"
	station_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_lbl.font_size = 14
	station_lbl.modulate = Color(0.85, 0.45, 1.0)
	station_lbl.outline_modulate = Color(0.02, 0.01, 0.05, 0.95)
	station_lbl.outline_size = 3
	station_lbl.position = Vector3(0.0, 52.0, 0.0)
	_stage_landmark_root.add_child(station_lbl)

func _build_marea_corsair_haven(pos: Vector3 = Vector3(-26.0, 0.0, 4.0), rot: Vector3 = Vector3(0.0, 20.0, 0.0)) -> void:
	# Sprawling Void-Pirate Haven carved into a colossal hollowed Basalt Asteroid Reef
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "CorsairHavenBarlovento"
	_stage_landmark_root.position = pos
	_stage_landmark_root.rotation_degrees = rot
	add_child(_stage_landmark_root)

	var timber_mat := StandardMaterial3D.new()
	timber_mat.albedo_texture = load("res://assets/ships/marea-libre/marea_hull.png")
	timber_mat.albedo_color = Color(1.15, 1.08, 1.0)
	timber_mat.metallic = 0.10
	timber_mat.roughness = 0.58

	var dark_timber := StandardMaterial3D.new()
	dark_timber.albedo_color = Color(0.20, 0.13, 0.08)
	dark_timber.metallic = 0.15
	dark_timber.roughness = 0.60

	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.84, 0.66, 0.28)
	brass_mat.metallic = 0.75
	brass_mat.roughness = 0.28

	var basalt_mat := StandardMaterial3D.new()
	basalt_mat.albedo_color = Color(0.12, 0.13, 0.16)
	basalt_mat.metallic = 0.15
	basalt_mat.roughness = 0.88

	var amber_lantern := StandardMaterial3D.new()
	amber_lantern.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	amber_lantern.albedo_color = Color(1.0, 0.68, 0.18)
	amber_lantern.emission_enabled = true
	amber_lantern.emission = Color(0.98, 0.62, 0.12)
	amber_lantern.emission_energy_multiplier = 2.4

	var glass_dome := StandardMaterial3D.new()
	glass_dome.albedo_color = Color(0.95, 0.68, 0.28, 0.45)
	glass_dome.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_dome.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass_dome.emission_enabled = true
	glass_dome.emission = Color(0.92, 0.56, 0.18)
	glass_dome.emission_energy_multiplier = 0.75

	var sail_mat := ShipModelBuilder._get_quantum_sail_material()

	# Dedicated Haven Illumination Lights (Warm Tavern Glow + Azure River Refraction)
	var tavern_light := OmniLight3D.new()
	tavern_light.position = Vector3(0.0, 12.0, 2.0)
	tavern_light.light_color = Color(1.0, 0.68, 0.25)
	tavern_light.light_energy = 2.2
	tavern_light.omni_range = 42.0
	_stage_landmark_root.add_child(tavern_light)

	var river_light := OmniLight3D.new()
	river_light.position = Vector3(12.0, -2.0, 8.0)
	river_light.light_color = Color(0.20, 0.85, 1.0)
	river_light.light_energy = 1.6
	river_light.omni_range = 35.0
	_stage_landmark_root.add_child(river_light)

	# 1. Colossal Hollowed Basalt Asteroid Megareef Base
	var asteroid_base := MeshInstance3D.new()
	var ab_sphere := SphereMesh.new()
	ab_sphere.radius = 16.0
	ab_sphere.height = 24.0
	ab_sphere.radial_segments = 16
	ab_sphere.rings = 10
	asteroid_base.mesh = ab_sphere
	asteroid_base.scale = Vector3(1.4, 0.85, 1.15)
	asteroid_base.material_override = basalt_mat
	_stage_landmark_root.add_child(asteroid_base)

	# 2. Pressurized Timber-and-Brass Harbormaster Cupola / Void Tavern
	var cupola := MeshInstance3D.new()
	var cp_cyl := CylinderMesh.new()
	cp_cyl.top_radius = 6.2
	cp_cyl.bottom_radius = 7.5
	cp_cyl.height = 4.8
	cp_cyl.radial_segments = 8
	cupola.mesh = cp_cyl
	cupola.position = Vector3(0.0, 10.5, -2.0)
	cupola.material_override = timber_mat
	_stage_landmark_root.add_child(cupola)

	var cupola_dome := MeshInstance3D.new()
	var cd_sphere := SphereMesh.new()
	cd_sphere.radius = 4.8
	cd_sphere.height = 5.2
	cupola_dome.mesh = cd_sphere
	cupola_dome.position = Vector3(0.0, 13.5, -2.0)
	cupola_dome.material_override = glass_dome
	_stage_landmark_root.add_child(cupola_dome)

	# 3. Cantilevered Mooring Piers jutting out toward El Río del Viento
	for p_i in [-1.0, 0.0, 1.0]:
		var pier := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(3.4, 0.8, 16.0)
		pier.mesh = p_box
		pier.position = Vector3(float(p_i) * 6.5, 4.0, 11.0)
		pier.material_override = dark_timber
		_stage_landmark_root.add_child(pier)

		# Pier brass bollards & support struts
		var bollard := MeshInstance3D.new()
		var bl_cyl := CylinderMesh.new()
		bl_cyl.top_radius = 0.25
		bl_cyl.bottom_radius = 0.35
		bl_cyl.height = 1.4
		bollard.mesh = bl_cyl
		bollard.position = Vector3(float(p_i) * 6.5, 4.8, 18.2)
		bollard.material_override = brass_mat
		_stage_landmark_root.add_child(bollard)

		# Amber cabin lantern at pier tip
		var lantern := MeshInstance3D.new()
		var l_sphere := SphereMesh.new()
		l_sphere.radius = 0.45
		l_sphere.height = 0.9
		lantern.mesh = l_sphere
		lantern.position = Vector3(float(p_i) * 6.5, 5.8, 18.2)
		lantern.material_override = amber_lantern
		_stage_landmark_root.add_child(lantern)

	# 4. Docked Yardarms with Billowing Quantum Sails (Corsair Dockyard)
	for side in [-1.0, 1.0]:
		var yardarm := MeshInstance3D.new()
		var y_cyl := CylinderMesh.new()
		y_cyl.top_radius = 0.22
		y_cyl.bottom_radius = 0.32
		y_cyl.height = 18.0
		yardarm.mesh = y_cyl
		yardarm.position = Vector3(float(side) * 12.0, 14.0, 6.0)
		yardarm.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		yardarm.material_override = brass_mat
		_stage_landmark_root.add_child(yardarm)

		# Billowing translucent quantum sail suspended below yardarm
		var sail := MeshInstance3D.new()
		var s_quad := QuadMesh.new()
		s_quad.size = Vector2(16.0, 8.5)
		sail.mesh = s_quad
		sail.position = Vector3(float(side) * 12.0, 9.8, 6.0)
		sail.material_override = sail_mat
		_stage_landmark_root.add_child(sail)

	# 5. Grand Rotating Brass Armillary Astrolabe (Tracking the Star Sea Currents)
	var astrolabe_root := Node3D.new()
	astrolabe_root.position = Vector3(2.5, 17.5, -3.5)
	_stage_landmark_root.add_child(astrolabe_root)
	_register_landmark_rotator(astrolabe_root, Vector3(0.2, 1.0, 0.1).normalized(), 0.16)

	# Astrolabe brass gimbals
	var astro_axis := MeshInstance3D.new()
	var a_cyl := CylinderMesh.new()
	a_cyl.top_radius = 0.18
	a_cyl.bottom_radius = 0.18
	a_cyl.height = 9.8
	astro_axis.mesh = a_cyl
	astro_axis.material_override = brass_mat
	astrolabe_root.add_child(astro_axis)

	var ring_configs: Array[Dictionary] = [
		{"r_in": 4.0, "r_out": 4.6, "rot": Vector3(0.0, 0.0, 0.0)},
		{"r_in": 3.0, "r_out": 3.5, "rot": Vector3(45.0, 0.0, 30.0)},
		{"r_in": 2.0, "r_out": 2.4, "rot": Vector3(-45.0, 30.0, 0.0)},
	]
	for rc in ring_configs:
		var a_ring := MeshInstance3D.new()
		var ar_tor := TorusMesh.new()
		ar_tor.inner_radius = rc["r_in"]
		ar_tor.outer_radius = rc["r_out"]
		a_ring.mesh = ar_tor
		a_ring.rotation_degrees = rc["rot"]
		a_ring.material_override = brass_mat
		astrolabe_root.add_child(a_ring)

	var chrono_core := MeshInstance3D.new()
	var cc_sphere := SphereMesh.new()
	cc_sphere.radius = 1.2
	cc_sphere.height = 2.4
	chrono_core.mesh = cc_sphere
	chrono_core.material_override = amber_lantern
	astrolabe_root.add_child(chrono_core)

	var station_lbl := Label3D.new()
	station_lbl.text = "⚓ CORSAIR FREE HAVEN\n[MAREA LIBRE ASTROLABE REEF]"
	station_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_lbl.font_size = 14
	station_lbl.modulate = Color(1.0, 0.85, 0.35)
	station_lbl.outline_modulate = Color(0.02, 0.01, 0.04, 0.95)
	station_lbl.outline_size = 3
	station_lbl.position = Vector3(0.0, 24.5, 0.0)
	_stage_landmark_root.add_child(station_lbl)

func _build_acero_calm_bastion(pos: Vector3 = Vector3(-28.0, 0.0, 8.0), rot: Vector3 = Vector3(0.0, 30.0, 0.0)) -> void:
	# Colossal Acero Forward Defense Bastion ("Bastion-7") facing the Calm wavefront
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "CalmThresholdBastion"
	_stage_landmark_root.position = pos
	_stage_landmark_root.rotation_degrees = rot
	add_child(_stage_landmark_root)

	var hull_tex: Texture2D = load("res://assets/ships/acero/acero_hull.png")

	var armor_mat := StandardMaterial3D.new()
	armor_mat.albedo_texture = hull_tex
	armor_mat.albedo_color = Color(1.5, 1.55, 1.65)
	armor_mat.uv1_scale = Vector3(4.0, 4.0, 1.0)
	armor_mat.metallic = 0.55
	armor_mat.roughness = 0.38
	armor_mat.rim_enabled = true
	armor_mat.rim = 0.5

	var dark_steel := StandardMaterial3D.new()
	dark_steel.albedo_texture = hull_tex
	dark_steel.albedo_color = Color(1.1, 1.15, 1.25)
	dark_steel.uv1_scale = Vector3(5.0, 5.0, 1.0)
	dark_steel.metallic = 0.65
	dark_steel.roughness = 0.30

	var furnace_amber := StandardMaterial3D.new()
	furnace_amber.albedo_color = Color(1.0, 0.55, 0.15)
	furnace_amber.emission_enabled = true
	furnace_amber.emission = Color(1.0, 0.50, 0.12)
	furnace_amber.emission_energy_multiplier = 2.0

	var warning_red := StandardMaterial3D.new()
	warning_red.albedo_color = Color(1.0, 0.18, 0.12)
	warning_red.emission_enabled = true
	warning_red.emission = Color(1.0, 0.15, 0.10)
	warning_red.emission_energy_multiplier = 2.5

	var forge_light := OmniLight3D.new()
	forge_light.position = Vector3(0.0, 6.0, 4.0)
	forge_light.light_color = Color(1.0, 0.58, 0.22)
	forge_light.light_energy = 2.0
	forge_light.omni_range = 38.0
	_stage_landmark_root.add_child(forge_light)

	var beacon_light := OmniLight3D.new()
	beacon_light.position = Vector3(0.0, 12.0, 0.0)
	beacon_light.light_color = Color(1.0, 0.25, 0.20)
	beacon_light.light_energy = 1.8
	beacon_light.omni_range = 30.0
	_stage_landmark_root.add_child(beacon_light)

	var hub := MeshInstance3D.new()
	var hub_cyl := CylinderMesh.new()
	hub_cyl.top_radius = 8.5
	hub_cyl.bottom_radius = 10.0
	hub_cyl.height = 7.0
	hub_cyl.radial_segments = 6
	hub.mesh = hub_cyl
	hub.material_override = armor_mat
	_stage_landmark_root.add_child(hub)

	var barbette := MeshInstance3D.new()
	var b_cyl := CylinderMesh.new()
	b_cyl.top_radius = 5.5
	b_cyl.bottom_radius = 7.0
	b_cyl.height = 4.5
	b_cyl.radial_segments = 6
	barbette.mesh = b_cyl
	barbette.position = Vector3(0.0, 5.5, 0.0)
	barbette.material_override = dark_steel
	_stage_landmark_root.add_child(barbette)

	var dish_root := Node3D.new()
	dish_root.position = Vector3(0.0, 8.5, 0.0)
	_stage_landmark_root.add_child(dish_root)
	_register_landmark_rotator(dish_root, Vector3.UP, 0.35)

	var dish := MeshInstance3D.new()
	var d_cyl := CylinderMesh.new()
	d_cyl.top_radius = 4.2
	d_cyl.bottom_radius = 0.5
	d_cyl.height = 1.5
	d_cyl.radial_segments = 12
	dish.mesh = d_cyl
	dish.rotation_degrees = Vector3(45.0, 0.0, 0.0)
	dish.material_override = armor_mat
	dish_root.add_child(dish)

	for i in 4:
		var ang: float = float(i) * (PI * 0.5) + (PI * 0.25)
		var turret := MeshInstance3D.new()
		var t_box := BoxMesh.new()
		t_box.size = Vector3(1.6, 1.4, 6.0)
		turret.mesh = t_box
		turret.position = Vector3(cos(ang) * 7.5, 1.0, sin(ang) * 7.5)
		turret.look_at(_stage_landmark_root.global_position + Vector3(cos(ang) * 20.0, 1.0, sin(ang) * 20.0))
		turret.material_override = dark_steel
		_stage_landmark_root.add_child(turret)

		var glow_tip := MeshInstance3D.new()
		var gt_sph := SphereMesh.new()
		gt_sph.radius = 0.45
		gt_sph.height = 0.9
		glow_tip.mesh = gt_sph
		glow_tip.position = Vector3(0.0, 0.0, -3.1)
		glow_tip.material_override = warning_red
		turret.add_child(glow_tip)

	var station_lbl := Label3D.new()
	station_lbl.text = "⚓ FORWARD BASTION-7\n[THE CALM THRESHOLD FORTRESS]"
	station_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_lbl.font_size = 14
	station_lbl.modulate = Color(1.0, 0.65, 0.25)
	station_lbl.outline_modulate = Color(0.02, 0.01, 0.04, 0.95)
	station_lbl.outline_size = 3
	station_lbl.position = Vector3(0.0, 13.0, 0.0)
	_stage_landmark_root.add_child(station_lbl)

func _build_vinculados_crystal_chasm(pos: Vector3 = Vector3(-25.0, 0.0, 5.0), rot: Vector3 = Vector3(0.0, 20.0, 0.0)) -> void:
	# Colossal Twin Crystal Monoliths & Levitating Resonance Ring
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "VinculadosCrystalChasm"
	_stage_landmark_root.position = pos
	_stage_landmark_root.rotation_degrees = rot
	add_child(_stage_landmark_root)

	var ceramic := StandardMaterial3D.new()
	ceramic.albedo_texture = load("res://assets/ships/vinculados/vinculados_hull.png")
	ceramic.albedo_color = Color(1.0, 1.0, 1.0)
	ceramic.metallic = 0.15
	ceramic.roughness = 0.20
	ceramic.rim_enabled = true
	ceramic.rim = 0.6

	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crystal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal_mat.albedo_color = Color(0.85, 0.35, 1.0, 0.75)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.80, 0.30, 0.95)
	crystal_mat.emission_energy_multiplier = 2.0

	var cyan_mat := StandardMaterial3D.new()
	cyan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan_mat.albedo_color = Color(0.30, 0.90, 1.0)
	cyan_mat.emission_enabled = true
	cyan_mat.emission = Color(0.25, 0.85, 1.0)
	cyan_mat.emission_energy_multiplier = 2.2

	var chasm_light := OmniLight3D.new()
	chasm_light.position = Vector3(0.0, 2.0, 0.0)
	chasm_light.light_color = Color(0.85, 0.45, 1.0)
	chasm_light.light_energy = 2.4
	chasm_light.omni_range = 42.0
	_stage_landmark_root.add_child(chasm_light)

	var cyan_light := OmniLight3D.new()
	cyan_light.position = Vector3(0.0, -12.0, 0.0)
	cyan_light.light_color = Color(0.35, 0.88, 1.0)
	cyan_light.light_energy = 2.0
	cyan_light.omni_range = 38.0
	_stage_landmark_root.add_child(cyan_light)

	for offset_x in [-8.0, 8.0]:
		var spire := MeshInstance3D.new()
		var sp_cyl := CylinderMesh.new()
		sp_cyl.top_radius = 1.0
		sp_cyl.bottom_radius = 3.8
		sp_cyl.height = 36.0
		sp_cyl.radial_segments = 6
		spire.mesh = sp_cyl
		spire.position = Vector3(offset_x, 0.0, 0.0)
		spire.material_override = ceramic
		_stage_landmark_root.add_child(spire)

		var tip := MeshInstance3D.new()
		var tip_mesh := PrismMesh.new()
		tip_mesh.size = Vector3(2.2, 8.0, 2.2)
		tip.mesh = tip_mesh
		tip.position = Vector3(offset_x, 22.0, 0.0)
		tip.material_override = crystal_mat
		_stage_landmark_root.add_child(tip)

	var halo_root := Node3D.new()
	halo_root.position = Vector3(0.0, 4.0, 0.0)
	_stage_landmark_root.add_child(halo_root)
	_register_landmark_rotator(halo_root, Vector3(0.2, 1.0, 0.1).normalized(), 0.3)

	var halo := MeshInstance3D.new()
	var h_tor := TorusMesh.new()
	h_tor.inner_radius = 5.5
	h_tor.outer_radius = 6.2
	halo.mesh = h_tor
	halo.material_override = cyan_mat
	halo_root.add_child(halo)

	var core := MeshInstance3D.new()
	var c_sph := SphereMesh.new()
	c_sph.radius = 2.4
	c_sph.height = 4.8
	core.mesh = c_sph
	core.position = Vector3(0.0, 4.0, 0.0)
	core.material_override = crystal_mat
	_stage_landmark_root.add_child(core)

	var station_lbl := Label3D.new()
	station_lbl.text = "✦ THE CRYSTAL CHASM\n[SECTOR PSALM-12 DEEP TRENCH]"
	station_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_lbl.font_size = 14
	station_lbl.modulate = Color(0.85, 0.50, 1.0)
	station_lbl.outline_modulate = Color(0.02, 0.01, 0.04, 0.95)
	station_lbl.outline_size = 3
	station_lbl.position = Vector3(0.0, 26.0, 0.0)
	_stage_landmark_root.add_child(station_lbl)

func _build_vinculados_genesis_ring(pos: Vector3 = Vector3(-28.0, 4.0, 5.0), rot: Vector3 = Vector3(0.0, 0.0, 0.0)) -> void:
	# Colossal Dual-Gimbal Genesis Resonance Ring & Soul Core
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "VinculadosGenesisRing"
	_stage_landmark_root.position = pos
	_stage_landmark_root.rotation_degrees = rot
	add_child(_stage_landmark_root)

	var ceramic := StandardMaterial3D.new()
	ceramic.albedo_texture = load("res://assets/ships/vinculados/vinculados_hull.png")
	ceramic.albedo_color = Color(1.0, 1.0, 1.0)
	ceramic.metallic = 0.15
	ceramic.roughness = 0.22
	ceramic.rim_enabled = true
	ceramic.rim = 0.7

	var soul_mat := ShipModelBuilder._get_soul_core_material()

	var cyan_mat := StandardMaterial3D.new()
	cyan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan_mat.albedo_color = Color(0.35, 0.92, 1.0)
	cyan_mat.emission_enabled = true
	cyan_mat.emission = Color(0.30, 0.90, 1.0)
	cyan_mat.emission_energy_multiplier = 2.5

	var genesis_light := OmniLight3D.new()
	genesis_light.position = Vector3.ZERO
	genesis_light.light_color = Color(0.65, 0.45, 1.0)
	genesis_light.light_energy = 2.8
	genesis_light.omni_range = 50.0
	_stage_landmark_root.add_child(genesis_light)

	var outer_root := Node3D.new()
	_stage_landmark_root.add_child(outer_root)
	_register_landmark_rotator(outer_root, Vector3.UP, 0.15)

	var outer_ring := MeshInstance3D.new()
	var o_tor := TorusMesh.new()
	o_tor.inner_radius = 14.5
	o_tor.outer_radius = 16.5
	outer_ring.mesh = o_tor
	outer_ring.material_override = ceramic
	outer_root.add_child(outer_ring)

	var inner_root := Node3D.new()
	_stage_landmark_root.add_child(inner_root)
	_register_landmark_rotator(inner_root, Vector3(0.6, 0.8, 0.0).normalized(), -0.25)

	var inner_ring := MeshInstance3D.new()
	var i_tor := TorusMesh.new()
	i_tor.inner_radius = 10.0
	i_tor.outer_radius = 11.8
	inner_ring.mesh = i_tor
	inner_ring.material_override = cyan_mat
	inner_root.add_child(inner_ring)

	var core := MeshInstance3D.new()
	var c_sph := SphereMesh.new()
	c_sph.radius = 4.2
	c_sph.height = 8.4
	core.mesh = c_sph
	core.material_override = soul_mat
	_stage_landmark_root.add_child(core)

	for i in 4:
		var ang: float = float(i) * (PI * 0.5)
		var pylon := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(1.2, 0.8, 8.0)
		pylon.mesh = p_box
		pylon.position = Vector3(cos(ang) * 12.0, 0.0, sin(ang) * 12.0)
		pylon.look_at(_stage_landmark_root.global_position)
		pylon.material_override = ceramic
		outer_root.add_child(pylon)

	var station_lbl := Label3D.new()
	station_lbl.text = "✦ THE GENESIS RING\n[TRANSCENDENCE THRESHOLD GATE]"
	station_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_lbl.font_size = 14
	station_lbl.modulate = Color(0.75, 0.88, 1.0)
	station_lbl.outline_modulate = Color(0.02, 0.01, 0.04, 0.95)
	station_lbl.outline_size = 3
	station_lbl.position = Vector3(0.0, 20.0, 0.0)
	_stage_landmark_root.add_child(station_lbl)

func _build_marea_foundry_complex(pos: Vector3 = Vector3(-26.0, 2.0, 6.0), rot: Vector3 = Vector3(0.0, 15.0, 0.0)) -> void:
	# Heavy Industrial Smelter Platform Vulcan-3 being raided
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "FoundryVulcan3"
	_stage_landmark_root.position = pos
	_stage_landmark_root.rotation_degrees = rot
	add_child(_stage_landmark_root)

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.20, 0.24)
	iron_mat.metallic = 0.65
	iron_mat.roughness = 0.40

	var molten_mat := StandardMaterial3D.new()
	molten_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	molten_mat.albedo_color = Color(1.0, 0.45, 0.10)
	molten_mat.emission_enabled = true
	molten_mat.emission = Color(1.0, 0.42, 0.08)
	molten_mat.emission_energy_multiplier = 2.2

	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.85, 0.65, 0.25)
	brass_mat.metallic = 0.75
	brass_mat.roughness = 0.25

	var forge_light := OmniLight3D.new()
	forge_light.position = Vector3(0.0, 5.0, 0.0)
	forge_light.light_color = Color(1.0, 0.52, 0.15)
	forge_light.light_energy = 2.5
	forge_light.omni_range = 40.0
	_stage_landmark_root.add_child(forge_light)

	var cauldron := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 8.0
	c_cyl.bottom_radius = 6.0
	c_cyl.height = 6.5
	c_cyl.radial_segments = 12
	cauldron.mesh = c_cyl
	cauldron.material_override = iron_mat
	_stage_landmark_root.add_child(cauldron)

	var pool := MeshInstance3D.new()
	var p_cyl := CylinderMesh.new()
	p_cyl.top_radius = 7.2
	p_cyl.bottom_radius = 7.2
	p_cyl.height = 0.5
	pool.mesh = p_cyl
	pool.position = Vector3(0.0, 3.2, 0.0)
	pool.material_override = molten_mat
	_stage_landmark_root.add_child(pool)

	var crane_root := Node3D.new()
	crane_root.position = Vector3(0.0, 4.0, 0.0)
	_stage_landmark_root.add_child(crane_root)
	_register_landmark_rotator(crane_root, Vector3.UP, 0.25)

	var arm := MeshInstance3D.new()
	var a_box := BoxMesh.new()
	a_box.size = Vector3(1.2, 1.2, 16.0)
	arm.mesh = a_box
	arm.position = Vector3(0.0, 4.0, 6.0)
	arm.material_override = brass_mat
	crane_root.add_child(arm)

	for offset_x in [-10.0, 10.0]:
		var silo := MeshInstance3D.new()
		var s_cyl := CylinderMesh.new()
		s_cyl.top_radius = 3.2
		s_cyl.bottom_radius = 3.2
		s_cyl.height = 9.0
		s_cyl.radial_segments = 8
		silo.mesh = s_cyl
		silo.position = Vector3(offset_x, 1.0, 0.0)
		silo.material_override = iron_mat
		_stage_landmark_root.add_child(silo)

	var station_lbl := Label3D.new()
	station_lbl.text = "⚙ SMELTER REFINERY VULCAN-3\n[IMPERIAL ORE FOUNDRY]"
	station_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_lbl.font_size = 14
	station_lbl.modulate = Color(1.0, 0.72, 0.25)
	station_lbl.outline_modulate = Color(0.02, 0.01, 0.04, 0.95)
	station_lbl.outline_size = 3
	station_lbl.position = Vector3(0.0, 14.0, 0.0)
	_stage_landmark_root.add_child(station_lbl)

func _build_marea_wind_maelstrom(pos: Vector3 = Vector3(-28.0, 0.0, 4.0), rot: Vector3 = Vector3(0.0, 0.0, 0.0)) -> void:
	# Colossal Astrolabe Eye of the Maelstrom Collector Spire
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "MaelstromEyeSpire"
	_stage_landmark_root.position = pos
	_stage_landmark_root.rotation_degrees = rot
	add_child(_stage_landmark_root)

	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.88, 0.68, 0.26)
	brass_mat.metallic = 0.78
	brass_mat.roughness = 0.24

	var ether_cyan := StandardMaterial3D.new()
	ether_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ether_cyan.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ether_cyan.albedo_color = Color(0.20, 0.88, 1.0, 0.80)
	ether_cyan.emission_enabled = true
	ether_cyan.emission = Color(0.18, 0.85, 1.0)
	ether_cyan.emission_energy_multiplier = 2.4

	var storm_light := OmniLight3D.new()
	storm_light.position = Vector3(0.0, 6.0, 0.0)
	storm_light.light_color = Color(0.35, 0.90, 1.0)
	storm_light.light_energy = 3.0
	storm_light.omni_range = 48.0
	_stage_landmark_root.add_child(storm_light)

	var mast := MeshInstance3D.new()
	var m_cyl := CylinderMesh.new()
	m_cyl.top_radius = 1.2
	m_cyl.bottom_radius = 2.8
	m_cyl.height = 32.0
	m_cyl.radial_segments = 8
	mast.mesh = m_cyl
	mast.material_override = brass_mat
	_stage_landmark_root.add_child(mast)

	var turbine_root := Node3D.new()
	turbine_root.position = Vector3(0.0, 4.0, 0.0)
	_stage_landmark_root.add_child(turbine_root)
	_register_landmark_rotator(turbine_root, Vector3.UP, 0.75)

	for i in 6:
		var ang: float = float(i) * (PI / 3.0)
		var fin := MeshInstance3D.new()
		var f_box := BoxMesh.new()
		f_box.size = Vector3(0.4, 6.0, 11.0)
		fin.mesh = f_box
		fin.position = Vector3(cos(ang) * 6.0, 0.0, sin(ang) * 6.0)
		fin.rotation = Vector3(0.0, -ang + 0.35, 0.2)
		fin.material_override = ether_cyan
		turbine_root.add_child(fin)

	var ring_root := Node3D.new()
	ring_root.position = Vector3(0.0, 12.0, 0.0)
	_stage_landmark_root.add_child(ring_root)
	_register_landmark_rotator(ring_root, Vector3(0.8, 0.5, 0.3).normalized(), -0.45)

	var ring := MeshInstance3D.new()
	var r_tor := TorusMesh.new()
	r_tor.inner_radius = 7.5
	r_tor.outer_radius = 8.5
	ring.mesh = r_tor
	ring.material_override = brass_mat
	ring_root.add_child(ring)

	var station_lbl := Label3D.new()
	station_lbl.text = "⚡ EYE OF THE MAELSTROM\n[BARLOVENTO OCEANIC CONVERGENCE]"
	station_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	station_lbl.font_size = 14
	station_lbl.modulate = Color(0.45, 0.95, 1.0)
	station_lbl.outline_modulate = Color(0.02, 0.01, 0.04, 0.95)
	station_lbl.outline_size = 3
	station_lbl.position = Vector3(0.0, 20.0, 0.0)
	_stage_landmark_root.add_child(station_lbl)

func _update_scenery(delta: float) -> void:
	if _asteroid_root != null:
		for cluster in _asteroid_root.get_children():
			if cluster is Node3D:
				cluster.rotate_y(delta * 0.06)

	for rot in _landmark_rotators:
		var n: Node3D = rot.get("node")
		if n != null and is_instance_valid(n):
			var axis: Vector3 = rot.get("axis", Vector3.UP)
			var spd: float = rot.get("speed", 0.2)
			n.rotate(axis, spd * delta)

	if _calm_root != null:
		var t := Time.get_ticks_msec() * 0.001
		for seep in _calm_seeps:
			var s_root: Node3D = seep.get("root_node")
			if s_root == null or not is_instance_valid(s_root):
				continue
			for child in s_root.get_children():
				if child.has_meta("rot_speed"):
					var r_spd: float = child.get_meta("rot_speed")
					child.rotate_y(delta * r_spd)
				if child.has_meta("pulse_phase") and child.has_meta("base_scale"):
					var phase: float = child.get_meta("pulse_phase")
					var b_scale: Vector3 = child.get_meta("base_scale")
					var pulse: float = 1.0 + sin(t * 1.5 + phase) * 0.08
					child.scale = Vector3(b_scale.x * pulse, b_scale.y, b_scale.z * pulse)
				if child.has_meta("mote_speed") and child.has_meta("base_y"):
					var m_spd: float = child.get_meta("mote_speed")
					var base_y: float = child.get_meta("base_y")
					child.position.y = base_y + sin(t * m_spd) * 0.6

	if _calm_root != null:
		var t := Time.get_ticks_msec() * 0.001
		for seep in _calm_seeps:
			var s_root: Node3D = seep.get("root_node")
			if s_root == null or not is_instance_valid(s_root):
				continue
			for child in s_root.get_children():
				if child.has_meta("rot_speed"):
					var r_spd: float = child.get_meta("rot_speed")
					child.rotate_y(delta * r_spd)
				if child.has_meta("pulse_phase") and child.has_meta("base_scale"):
					var phase: float = child.get_meta("pulse_phase")
					var b_scale: Vector3 = child.get_meta("base_scale")
					var pulse := 1.0 + sin(t * 0.6 + phase) * 0.045
					child.scale = Vector3(b_scale.x * pulse, b_scale.y, b_scale.z * pulse)
				elif child.has_meta("mote_speed"):
					var m_spd: float = child.get_meta("mote_speed")
					var by: float = child.get_meta("base_y")
					child.position.y = by + sin(t * m_spd) * 1.2

func _update_ether_flow(delta: float) -> void:
	if _ether_particles == null:
		return
	for child in _ether_particles.get_children():
		if child is Node3D:
			var cur := _ether.current_at(child.position)
			child.position += cur * (delta * 6.0)
			if child.position.x > 150.0:
				child.position.x = -150.0
			elif child.position.x < -150.0:
				child.position.x = 150.0
			if child.position.z > 150.0:
				child.position.z = -150.0
			elif child.position.z < -150.0:
				child.position.z = 150.0

