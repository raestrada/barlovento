class_name StarSeaBackdrop
extends Node3D

var _planet_node: Node3D
var _planet_ring: MeshInstance3D
var _moon_pivot: Node3D
var _ether_ribbons: Array[MeshInstance3D] = []
var _dust_motes: MultiMeshInstance3D
var _diorama_ships: Dictionary = {}
var _time: float = 0.0

static var _sky_shader: Shader = null
static var _planet_shader: Shader = null
static var _ring_shader: Shader = null
static var _ribbon_shader: Shader = null
static var _nebula_tex: Texture2D = null

func setup_environment(include_diorama_fleets: bool = false) -> WorldEnvironment:
	var stage := LoreDB.current_stage_id if not include_diorama_fleets else ""

	var sun := DirectionalLight3D.new()
	sun.name = "KeyStarLight"
	sun.rotation_degrees = Vector3(-38.0, -35.0, 0.0)

	var rim_light := DirectionalLight3D.new()
	rim_light.name = "EtherRimLight"
	rim_light.rotation_degrees = Vector3(42.0, 145.0, 0.0)

	var zenith_fill := DirectionalLight3D.new()
	zenith_fill.name = "ZenithHullFillLight"
	zenith_fill.rotation_degrees = Vector3(-72.0, 110.0, 0.0)

	var env := Environment.new()
	var sky_tint := Vector3(1.0, 1.0, 1.0)

	match stage:
		# VINCULADOS CAMPAIGN (Stages 1 - 12): Harmonic Sanctuary, Crystal Chasms, & Transcendence
		"vinculados_stage_1", "vinculados_stage_4", "vinculados_stage_6":
			sun.light_energy = 1.18
			sun.light_color = Color(0.94, 0.95, 1.0)
			rim_light.light_energy = 0.68
			rim_light.light_color = Color(0.76, 0.36, 1.0)
			zenith_fill.light_energy = 0.45
			zenith_fill.light_color = Color(0.38, 0.84, 1.0)
			env.ambient_light_color = Color(0.24, 0.30, 0.52)
			env.ambient_light_energy = 0.88
			sky_tint = Vector3(1.02, 0.96, 1.16)
		"vinculados_stage_2", "vinculados_stage_5", "vinculados_stage_7":
			sun.light_energy = 1.15
			sun.light_color = Color(0.88, 0.94, 1.0)
			rim_light.light_energy = 0.72
			rim_light.light_color = Color(0.28, 0.92, 1.0)
			zenith_fill.light_energy = 0.46
			zenith_fill.light_color = Color(0.68, 0.42, 1.0)
			env.ambient_light_color = Color(0.20, 0.28, 0.54)
			env.ambient_light_energy = 0.90
			sky_tint = Vector3(0.90, 1.06, 1.18)
		"vinculados_stage_3", "vinculados_stage_8", "vinculados_stage_9", "vinculados_stage_10":
			sun.light_energy = 1.24
			sun.light_color = Color(0.98, 0.94, 1.0)
			rim_light.light_energy = 0.75
			rim_light.light_color = Color(0.92, 0.24, 0.96)
			zenith_fill.light_energy = 0.44
			zenith_fill.light_color = Color(0.32, 0.88, 1.0)
			env.ambient_light_color = Color(0.22, 0.18, 0.42)
			env.ambient_light_energy = 0.86
			sky_tint = Vector3(1.10, 0.90, 1.18)
		"vinculados_stage_11", "vinculados_stage_12":
			sun.light_energy = 1.30
			sun.light_color = Color(0.98, 0.95, 1.0)
			rim_light.light_energy = 0.80
			rim_light.light_color = Color(0.98, 0.28, 0.92)
			zenith_fill.light_energy = 0.48
			zenith_fill.light_color = Color(0.25, 0.95, 1.0)
			env.ambient_light_color = Color(0.25, 0.20, 0.48)
			env.ambient_light_energy = 0.92
			sky_tint = Vector3(1.14, 0.94, 1.22)

		# MAREA LIBRE CAMPAIGN (Stages 1 - 12): Golden Solar Corona, Emerald Currents, & Maelstrom
		"marea_stage_1", "marea_stage_4", "marea_stage_6":
			sun.light_energy = 1.28
			sun.light_color = Color(1.0, 0.90, 0.68)
			rim_light.light_energy = 0.70
			rim_light.light_color = Color(0.18, 0.94, 1.0)
			zenith_fill.light_energy = 0.46
			zenith_fill.light_color = Color(0.98, 0.84, 0.62)
			env.ambient_light_color = Color(0.28, 0.40, 0.46)
			env.ambient_light_energy = 0.90
			sky_tint = Vector3(1.06, 1.08, 0.94)
		"marea_stage_2", "marea_stage_5", "marea_stage_7", "marea_stage_10":
			sun.light_energy = 1.24
			sun.light_color = Color(1.0, 0.76, 0.42)
			rim_light.light_energy = 0.68
			rim_light.light_color = Color(0.24, 0.88, 0.98)
			zenith_fill.light_energy = 0.48
			zenith_fill.light_color = Color(1.0, 0.66, 0.28)
			env.ambient_light_color = Color(0.32, 0.30, 0.36)
			env.ambient_light_energy = 0.88
			sky_tint = Vector3(1.14, 0.96, 0.86)
		"marea_stage_3", "marea_stage_8", "marea_stage_9", "marea_stage_11", "marea_stage_12":
			sun.light_energy = 1.34
			sun.light_color = Color(1.0, 0.92, 0.76)
			rim_light.light_energy = 0.76
			rim_light.light_color = Color(0.14, 0.96, 1.0)
			zenith_fill.light_energy = 0.48
			zenith_fill.light_color = Color(0.82, 0.92, 1.0)
			env.ambient_light_color = Color(0.26, 0.42, 0.54)
			env.ambient_light_energy = 0.94
			sky_tint = Vector3(1.04, 1.12, 1.10)

		# ARMADA OF ACERO CAMPAIGN (Stages 1 - 12): Forge Crucibles, Sluice Gates, & Calm Threshold
		"acero_stage_1", "acero_stage_4", "acero_stage_7":
			sun.light_energy = 1.22
			sun.light_color = Color(0.98, 0.92, 0.84)
			rim_light.light_energy = 0.66
			rim_light.light_color = Color(0.28, 0.86, 1.0)
			zenith_fill.light_energy = 0.45
			zenith_fill.light_color = Color(0.78, 0.86, 0.98)
			env.ambient_light_color = Color(0.26, 0.36, 0.50)
			env.ambient_light_energy = 0.88
			sky_tint = Vector3(1.00, 1.04, 1.10)
		"acero_stage_2", "acero_stage_5", "acero_stage_6", "acero_stage_8", "acero_stage_9":
			sun.light_energy = 1.25
			sun.light_color = Color(1.0, 0.84, 0.66)
			rim_light.light_energy = 0.70
			rim_light.light_color = Color(0.32, 0.88, 1.0)
			zenith_fill.light_energy = 0.46
			zenith_fill.light_color = Color(0.96, 0.74, 0.52)
			env.ambient_light_color = Color(0.30, 0.34, 0.44)
			env.ambient_light_energy = 0.88
			sky_tint = Vector3(1.10, 1.00, 1.02)
		"acero_stage_3", "acero_stage_10", "acero_stage_11", "acero_stage_12":
			sun.light_energy = 1.20
			sun.light_color = Color(0.98, 0.90, 0.84)
			rim_light.light_energy = 0.74
			rim_light.light_color = Color(0.84, 0.22, 0.96)
			zenith_fill.light_energy = 0.42
			zenith_fill.light_color = Color(0.58, 0.78, 0.96)
			env.ambient_light_color = Color(0.20, 0.22, 0.38)
			env.ambient_light_energy = 0.85
			sky_tint = Vector3(1.08, 0.88, 1.16)
		_:
			sun.light_energy = 1.20
			sun.light_color = Color(0.98, 0.94, 0.88)
			rim_light.light_energy = 0.66
			rim_light.light_color = Color(0.32, 0.86, 1.0)
			zenith_fill.light_energy = 0.45
			zenith_fill.light_color = Color(0.80, 0.88, 0.98)
			env.ambient_light_color = Color(0.26, 0.36, 0.50)
			env.ambient_light_energy = 0.88
			sky_tint = Vector3(1.02, 1.04, 1.08)

	add_child(sun)
	add_child(rim_light)
	add_child(zenith_fill)

	var world := WorldEnvironment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := _create_star_sea_sky_material()
	sky_mat.set_shader_parameter("stage_tint", sky_tint)
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.96
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.08
	env.ssao_enabled = true
	env.ssao_radius = 1.20
	env.ssao_intensity = 1.75
	env.glow_enabled = true
	env.glow_intensity = 0.36
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.45
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	world.environment = env
	add_child(world)

	_build_celestial_planetoid()
	_build_volumetric_ether_ribbons()
	_build_star_dust_multimesh()

	if include_diorama_fleets:
		_build_menu_diorama_fleets()

	return world

func _process(delta: float) -> void:
	_time += delta
	if _planet_node != null:
		_planet_node.rotate_y(delta * 0.025)
	if _planet_ring != null:
		_planet_ring.rotate_y(-delta * 0.015)
	if _moon_pivot != null:
		_moon_pivot.rotate_y(delta * 0.08)

	for fac_key in _diorama_ships.keys():
		var group: Node3D = _diorama_ships[fac_key]
		if group != null:
			var phase := float(fac_key.hash() % 100) * 0.1
			group.position.y = sin(_time * 1.1 + phase) * 0.45
			group.rotation.z = sin(_time * 0.8 + phase) * 0.04

func get_faction_focus_transform(faction_id: String, t: float) -> Dictionary:
	match faction_id:
		"acero":
			var center := Vector3(-22.0, 2.0, 0.0)
			var cam_pos := center + Vector3(cos(t * 0.18) * 14.0 + 6.0, 4.5 + sin(t * 0.25) * 1.2, 16.0)
			var look_t := center + Vector3(0.0, 0.5, -2.0)
			return {"cam_pos": cam_pos, "look_at": look_t, "look_target": look_t}
		"vinculados":
			var center := Vector3(0.0, 3.0, -14.0)
			var cam_pos := center + Vector3(sin(t * 0.22) * 11.0, 2.8 + cos(t * 0.3) * 1.0, 12.0)
			var look_t := center + Vector3(0.0, 0.6, 0.0)
			return {"cam_pos": cam_pos, "look_at": look_t, "look_target": look_t}
		"marea_libre":
			var center := Vector3(22.0, 1.5, 2.0)
			var cam_pos := center + Vector3(-12.0 + cos(t * 0.16) * 8.0, 4.2 + sin(t * 0.2) * 1.1, 15.0)
			var look_t := center + Vector3(0.0, 1.5, -1.0)
			return {"cam_pos": cam_pos, "look_at": look_t, "look_target": look_t}
		_:
			var cam_pos := Vector3(sin(t * 0.10) * 26.0, 11.0 + sin(t * 0.15) * 2.5, 32.0 + cos(t * 0.10) * 8.0)
			var look_target := Vector3(sin(t * 0.08) * 8.0, 2.0, -8.0)
			return {"cam_pos": cam_pos, "look_at": look_target, "look_target": look_target}

func _build_celestial_planetoid() -> void:
	match LoreDB.current_stage_id:
		"vinculados_stage_1", "vinculados_stage_4", "vinculados_stage_6", "vinculados_stage_8", "marea_stage_8":
			_build_salmo_planetoid()
		"vinculados_stage_2", "vinculados_stage_5", "acero_stage_6", "acero_stage_10":
			_build_crystal_moon_planetoid()
		"vinculados_stage_3", "vinculados_stage_7", "vinculados_stage_10", "vinculados_stage_11", "vinculados_stage_12", "acero_stage_3", "acero_stage_11", "acero_stage_12":
			_build_calm_abyss_planetoid()
		"marea_stage_1", "marea_stage_4", "marea_stage_6":
			_build_sol_dorado()
		"marea_stage_2", "marea_stage_5", "marea_stage_7", "marea_stage_10", "acero_stage_5", "acero_stage_8":
			_build_smelter_forge_planetoid()
		"marea_stage_3", "marea_stage_9", "marea_stage_11", "marea_stage_12", "acero_stage_9":
			_build_grand_sol_corona()
		_:
			_build_anvil_planetoid()

func _build_anvil_planetoid() -> void:
	var planet_root := Node3D.new()
	planet_root.name = "ForgeWorldAnvil"
	planet_root.position = Vector3(-95.0, 34.0, -185.0)
	add_child(planet_root)

	_planet_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 28.0
	sphere.height = 56.0
	sphere.radial_segments = 48
	sphere.rings = 24
	(_planet_node as MeshInstance3D).mesh = sphere
	(_planet_node as MeshInstance3D).material_override = _create_planet_material()
	planet_root.add_child(_planet_node)

	_planet_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 36.0
	torus.outer_radius = 52.0
	torus.rings = 48
	torus.ring_segments = 12
	_planet_ring.mesh = torus
	_planet_ring.scale = Vector3(1.0, 0.05, 1.0)
	_planet_ring.rotation_degrees = Vector3(24.0, -15.0, 18.0)
	_planet_ring.material_override = _create_ring_material()
	planet_root.add_child(_planet_ring)

	_moon_pivot = Node3D.new()
	_moon_pivot.rotation_degrees = Vector3(12.0, 0.0, -16.0)
	planet_root.add_child(_moon_pivot)

	var moon := MeshInstance3D.new()
	var m_sphere := SphereMesh.new()
	m_sphere.radius = 4.2
	m_sphere.height = 8.4
	m_sphere.radial_segments = 24
	m_sphere.rings = 12
	moon.mesh = m_sphere
	moon.position = Vector3(64.0, 0.0, 0.0)
	var m_mat := StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.22, 0.26, 0.34)
	m_mat.roughness = 0.85
	m_mat.emission_enabled = true
	m_mat.emission = Color(0.12, 0.55, 0.75)
	m_mat.emission_energy_multiplier = 0.45
	moon.material_override = m_mat
	_moon_pivot.add_child(moon)

func _build_salmo_planetoid() -> void:
	var salmo_root := Node3D.new()
	salmo_root.name = "SanctuaryMoonSalmo"
	salmo_root.position = Vector3(-80.0, 38.0, -175.0)
	add_child(salmo_root)

	_planet_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 25.0
	sphere.height = 50.0
	sphere.radial_segments = 48
	sphere.rings = 24
	(_planet_node as MeshInstance3D).mesh = sphere
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.88, 0.92, 0.98)
	s_mat.roughness = 0.35
	s_mat.metallic = 0.15
	s_mat.emission_enabled = true
	s_mat.emission = Color(0.35, 0.65, 0.98)
	s_mat.emission_energy_multiplier = 0.65
	s_mat.rim_enabled = true
	s_mat.rim = 0.85
	s_mat.rim_tint = 0.7
	(_planet_node as MeshInstance3D).material_override = s_mat
	salmo_root.add_child(_planet_node)

	_planet_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 34.0
	torus.outer_radius = 48.0
	torus.rings = 48
	torus.ring_segments = 12
	_planet_ring.mesh = torus
	_planet_ring.scale = Vector3(1.0, 0.03, 1.0)
	_planet_ring.rotation_degrees = Vector3(18.0, 32.0, -12.0)
	var r_mat := StandardMaterial3D.new()
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.albedo_color = Color(0.65, 0.45, 0.95, 0.38)
	_planet_ring.material_override = r_mat
	salmo_root.add_child(_planet_ring)

	_moon_pivot = Node3D.new()
	_moon_pivot.rotation_degrees = Vector3(-15.0, 0.0, 22.0)
	salmo_root.add_child(_moon_pivot)

	for i in range(3):
		var shard := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(2.5, 6.0, 2.5)
		shard.mesh = prism
		var angle := float(i) * (TAU / 3.0)
		shard.position = Vector3(cos(angle) * 56.0, sin(angle) * 8.0, sin(angle) * 56.0)
		shard.rotation_degrees = Vector3(30.0 * float(i), 45.0, 15.0)
		var shard_mat := StandardMaterial3D.new()
		shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shard_mat.albedo_color = Color(0.40, 0.90, 1.0)
		shard.material_override = shard_mat
		_moon_pivot.add_child(shard)

func _build_sol_dorado() -> void:
	var sun_root := Node3D.new()
	sun_root.name = "SolDorado"
	sun_root.position = Vector3(88.0, 46.0, -170.0)
	add_child(sun_root)

	_planet_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 32.0
	sphere.height = 64.0
	sphere.radial_segments = 48
	sphere.rings = 24
	(_planet_node as MeshInstance3D).mesh = sphere
	var sun_mat := StandardMaterial3D.new()
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mat.albedo_color = Color(1.15, 0.88, 0.42)
	(_planet_node as MeshInstance3D).material_override = sun_mat
	sun_root.add_child(_planet_node)

	_planet_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 42.0
	torus.outer_radius = 62.0
	torus.rings = 48
	torus.ring_segments = 12
	_planet_ring.mesh = torus
	_planet_ring.scale = Vector3(1.0, 0.04, 1.0)
	_planet_ring.rotation_degrees = Vector3(-28.0, 45.0, 10.0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.72, 0.25, 0.42)
	_planet_ring.material_override = ring_mat
	sun_root.add_child(_planet_ring)

	_moon_pivot = Node3D.new()
	_moon_pivot.rotation_degrees = Vector3(35.0, 15.0, -20.0)
	sun_root.add_child(_moon_pivot)

	for i in range(5):
		var rock := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.2, 3.2, 3.2)
		rock.mesh = box
		var angle := float(i) * (TAU / 5.0) + 0.3
		rock.position = Vector3(cos(angle) * 78.0, sin(angle) * 12.0, sin(angle) * 78.0)
		var r_mat := StandardMaterial3D.new()
		r_mat.albedo_color = Color(0.20, 0.16, 0.12)
		r_mat.roughness = 0.95
		rock.material_override = r_mat
		_moon_pivot.add_child(rock)

func _build_crystal_moon_planetoid() -> void:
	var c_root := Node3D.new()
	c_root.name = "CrystalMoonPsalm7"
	c_root.position = Vector3(-75.0, 42.0, -170.0)
	add_child(c_root)

	_planet_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 24.0
	sphere.height = 48.0
	sphere.radial_segments = 36
	sphere.rings = 18
	(_planet_node as MeshInstance3D).mesh = sphere
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.82, 0.88, 1.0)
	c_mat.roughness = 0.25
	c_mat.metallic = 0.35
	c_mat.emission_enabled = true
	c_mat.emission = Color(0.40, 0.70, 1.0)
	c_mat.emission_energy_multiplier = 0.85
	(_planet_node as MeshInstance3D).material_override = c_mat
	c_root.add_child(_planet_node)

	_planet_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 32.0
	torus.outer_radius = 46.0
	torus.rings = 36
	torus.ring_segments = 8
	_planet_ring.mesh = torus
	_planet_ring.scale = Vector3(1.0, 0.02, 1.0)
	_planet_ring.rotation_degrees = Vector3(32.0, -25.0, 10.0)
	var r_mat := StandardMaterial3D.new()
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.albedo_color = Color(0.50, 0.85, 1.0, 0.40)
	_planet_ring.material_override = r_mat
	c_root.add_child(_planet_ring)

	_moon_pivot = Node3D.new()
	c_root.add_child(_moon_pivot)
	for i in range(6):
		var p_mesh := PrismMesh.new()
		p_mesh.size = Vector3(2.0, 5.0, 2.0)
		var p_inst := MeshInstance3D.new()
		p_inst.mesh = p_mesh
		var a := float(i) * (TAU / 6.0)
		p_inst.position = Vector3(cos(a) * 52.0, sin(a) * 6.0, sin(a) * 52.0)
		var p_mat := StandardMaterial3D.new()
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.albedo_color = Color(0.70, 0.45, 1.0)
		p_inst.material_override = p_mat
		_moon_pivot.add_child(p_inst)

func _build_calm_abyss_planetoid() -> void:
	var abyss_root := Node3D.new()
	abyss_root.name = "CalmAbyssNexus"
	abyss_root.position = Vector3(0.0, 32.0, -185.0)
	add_child(abyss_root)

	_planet_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 22.0
	sphere.height = 44.0
	sphere.radial_segments = 36
	sphere.rings = 18
	(_planet_node as MeshInstance3D).mesh = sphere
	var abyss_mat := StandardMaterial3D.new()
	abyss_mat.albedo_color = Color(0.02, 0.01, 0.04)
	abyss_mat.roughness = 0.90
	abyss_mat.rim_enabled = true
	abyss_mat.rim = 1.0
	abyss_mat.rim_tint = 0.95
	abyss_mat.emission_enabled = true
	abyss_mat.emission = Color(0.65, 0.15, 0.85)
	abyss_mat.emission_energy_multiplier = 0.75
	(_planet_node as MeshInstance3D).material_override = abyss_mat
	abyss_root.add_child(_planet_node)

	_planet_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 35.0
	torus.outer_radius = 48.0
	torus.rings = 48
	torus.ring_segments = 12
	_planet_ring.mesh = torus
	_planet_ring.scale = Vector3(1.0, 0.04, 1.0)
	_planet_ring.rotation_degrees = Vector3(15.0, 45.0, -20.0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.35, 0.90, 1.0, 0.45)
	_planet_ring.material_override = ring_mat
	abyss_root.add_child(_planet_ring)

func _build_smelter_forge_planetoid() -> void:
	var forge_root := Node3D.new()
	forge_root.name = "SmelterWorld"
	forge_root.position = Vector3(-85.0, 36.0, -180.0)
	add_child(forge_root)

	_planet_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 26.0
	sphere.height = 52.0
	sphere.radial_segments = 48
	sphere.rings = 24
	(_planet_node as MeshInstance3D).mesh = sphere
	(_planet_node as MeshInstance3D).material_override = _create_planet_material()
	forge_root.add_child(_planet_node)

	_planet_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 34.0
	torus.outer_radius = 46.0
	torus.rings = 36
	torus.ring_segments = 8
	_planet_ring.mesh = torus
	_planet_ring.scale = Vector3(1.0, 0.03, 1.0)
	_planet_ring.rotation_degrees = Vector3(-18.0, 30.0, 12.0)
	var r_mat := StandardMaterial3D.new()
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.albedo_color = Color(1.0, 0.45, 0.12, 0.35)
	_planet_ring.material_override = r_mat
	forge_root.add_child(_planet_ring)

func _build_grand_sol_corona() -> void:
	var sol_root := Node3D.new()
	sol_root.name = "GrandSolCorona"
	sol_root.position = Vector3(82.0, 50.0, -165.0)
	add_child(sol_root)

	_planet_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 36.0
	sphere.height = 72.0
	sphere.radial_segments = 48
	sphere.rings = 24
	(_planet_node as MeshInstance3D).mesh = sphere
	var sun_mat := StandardMaterial3D.new()
	sun_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mat.albedo_color = Color(1.25, 0.95, 0.55)
	(_planet_node as MeshInstance3D).material_override = sun_mat
	sol_root.add_child(_planet_node)

	_planet_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 46.0
	torus.outer_radius = 70.0
	torus.rings = 48
	torus.ring_segments = 12
	_planet_ring.mesh = torus
	_planet_ring.scale = Vector3(1.0, 0.05, 1.0)
	_planet_ring.rotation_degrees = Vector3(-24.0, 35.0, 15.0)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.80, 0.32, 0.50)
	_planet_ring.material_override = ring_mat
	sol_root.add_child(_planet_ring)

func _build_volumetric_ether_ribbons() -> void:
	var configs := [
		{"pos": Vector3(0.0, -6.5, -10.0), "rot": Vector3(0.0, -22.0, 0.0), "w": 18.0, "len": 260.0},
		{"pos": Vector3(-35.0, -11.0, -30.0), "rot": Vector3(4.0, -18.0, -6.0), "w": 12.0, "len": 240.0},
		{"pos": Vector3(38.0, -4.0, -25.0), "rot": Vector3(-3.0, -26.0, 5.0), "w": 14.0, "len": 240.0},
	]
	if LoreDB.current_stage_id == "marea_stage_1":
		configs.append({"pos": Vector3(0.0, -2.0, 0.0), "rot": Vector3(0.0, 0.0, 0.0), "w": 26.0, "len": 320.0})
	elif LoreDB.current_stage_id == "marea_stage_3":
		configs.append({"pos": Vector3(-20.0, 0.0, 0.0), "rot": Vector3(0.0, 35.0, 0.0), "w": 24.0, "len": 340.0})
		configs.append({"pos": Vector3(20.0, 0.0, 0.0), "rot": Vector3(0.0, -35.0, 0.0), "w": 24.0, "len": 340.0})
	elif LoreDB.current_stage_id == "vinculados_stage_2":
		configs.append({"pos": Vector3(0.0, 4.0, 0.0), "rot": Vector3(15.0, 0.0, 0.0), "w": 22.0, "len": 300.0})

	var mat := _create_ribbon_material()
	for cfg in configs:
		var mi := MeshInstance3D.new()
		mi.mesh = _create_ribbon_mesh(cfg["w"], cfg["len"], 48, 8)
		mi.position = cfg["pos"]
		mi.rotation_degrees = cfg["rot"]
		mi.material_override = mat
		add_child(mi)
		_ether_ribbons.append(mi)

func _create_ribbon_mesh(width: float, length: float, segs_z: int, segs_x: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for iz in range(segs_z + 1):
		var v := float(iz) / float(segs_z)
		var z := (v - 0.5) * length
		var curve_x := sin(v * PI * 2.0) * 14.0
		for ix in range(segs_x + 1):
			var u := float(ix) / float(segs_x)
			var x := (u - 0.5) * width + curve_x
			verts.append(Vector3(x, 0.0, z))
			uvs.append(Vector2(u, v))

	var stride := segs_x + 1
	for iz in range(segs_z):
		for ix in range(segs_x):
			var i0 := iz * stride + ix
			var i1 := i0 + 1
			var i2 := (iz + 1) * stride + ix
			var i3 := i2 + 1
			indices.append(i0)
			indices.append(i2)
			indices.append(i1)
			indices.append(i1)
			indices.append(i2)
			indices.append(i3)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _build_star_dust_multimesh() -> void:
	_dust_motes = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true

	var quad := SphereMesh.new()
	quad.radius = 0.16
	quad.height = 0.32
	quad.radial_segments = 6
	quad.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.90, 1.0)
	mat.emission_energy_multiplier = 2.5
	quad.material = mat

	mm.mesh = quad
	mm.instance_count = 180

	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(mm.instance_count):
		var pos := Vector3(
			rng.randf_range(-110.0, 110.0),
			rng.randf_range(-28.0, 35.0),
			rng.randf_range(-110.0, 60.0)
		)
		var sc := rng.randf_range(0.5, 2.2)
		var basis := Basis().scaled(Vector3(sc, sc, sc))
		mm.set_instance_transform(i, Transform3D(basis, pos))
		var is_warm := rng.randf() < 0.25
		var col := Color(1.0, 0.68, 0.28, 0.75) if is_warm else Color(0.32, 0.92, 1.0, 0.75)
		mm.set_instance_color(i, col)

	_dust_motes.multimesh = mm
	add_child(_dust_motes)

func _build_menu_diorama_fleets() -> void:
	# 1. Armada of Acero Formation (Left-Center)
	var acero_group := Node3D.new()
	acero_group.name = "DioramaAcero"
	acero_group.position = Vector3(-22.0, 2.0, 0.0)
	acero_group.rotation_degrees = Vector3(0.0, -25.0, 0.0)
	add_child(acero_group)
	_diorama_ships["acero"] = acero_group

	_spawn_diorama_hull("acero_dreadnought", acero_group, Vector3.ZERO)
	_spawn_diorama_hull("acero_battlecruiser", acero_group, Vector3(-6.5, -1.5, 5.5))
	_spawn_diorama_hull("acero_corvette", acero_group, Vector3(6.0, 1.8, 4.0))

	# 2. The Vinculados Choir Wing (Center-Forward: Seraph-Prime Colossus + CNS Cradle + Anima)
	var vinc_group := Node3D.new()
	vinc_group.name = "DioramaVinculados"
	vinc_group.position = Vector3(0.0, 3.0, -14.0)
	vinc_group.rotation_degrees = Vector3(0.0, 10.0, 0.0)
	add_child(vinc_group)
	_diorama_ships["vinculados"] = vinc_group

	_spawn_diorama_hull("vinculados_colossus", vinc_group, Vector3(0.0, 0.4, 2.2))
	_spawn_diorama_hull("vinculados_cradle", vinc_group, Vector3(-3.2, 2.4, -5.5))
	_spawn_diorama_hull("vinculados_anima", vinc_group, Vector3(5.8, -0.8, 2.8))

	# 3. The Free Tide Corsair Squadron (Right-Center)
	var marea_group := Node3D.new()
	marea_group.name = "DioramaMarea"
	marea_group.position = Vector3(22.0, 1.5, 2.0)
	marea_group.rotation_degrees = Vector3(0.0, 28.0, 0.0)
	add_child(marea_group)
	_diorama_ships["marea_libre"] = marea_group

	_spawn_diorama_hull("marea_galleon", marea_group, Vector3.ZERO)
	_spawn_diorama_hull("marea_raider", marea_group, Vector3(6.5, -1.2, 5.0))

func _spawn_diorama_hull(ship_id: String, parent: Node3D, local_pos: Vector3) -> void:
	var def := LoreDB.get_ship(ship_id)
	if def == null:
		return
	var dummy := Ship.new()
	dummy.ship_id = def.id
	dummy.faction = def.faction
	dummy.body_size = def.body_size
	dummy.ship_color = def.color

	var model_holder := Node3D.new()
	model_holder.position = local_pos
	parent.add_child(model_holder)

	var thrusters: Array[Node3D] = []
	ShipModelBuilder.build(dummy, model_holder, thrusters)
	for t in thrusters:
		t.visible = true
	dummy.free()

static func _create_star_sea_sky_material() -> ShaderMaterial:
	if _sky_shader == null:
		_sky_shader = Shader.new()
		_sky_shader.code = """
shader_type sky;

uniform sampler2D nebula_pano : filter_linear, repeat_enable;
uniform vec3 stage_tint = vec3(1.0, 1.0, 1.0);

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
			mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
			mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y),
		f.z
	);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(13.7, 29.1, 7.3);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float t = TIME * 0.04;

	// 1. Deep Star Sea Base Gradient + High-Resolution Bioluminescent Nebula Panorama
	vec3 col = mix(vec3(0.008, 0.016, 0.038), vec3(0.022, 0.052, 0.105), clamp(1.0 - abs(dir.y), 0.0, 1.0));
	vec2 eq_uv = vec2(atan(dir.z, dir.x) * 0.1591549 + 0.5 + t * 0.015, asin(clamp(dir.y, -1.0, 1.0)) * 0.3183099 + 0.5);
	vec3 pano_col = texture(nebula_pano, eq_uv).rgb;
	col = mix(col, pano_col * 0.42, 0.45);

	// 2. Volumetric Multi-Octave Nebula Clouds
	float n1 = fbm(dir * 3.2 + vec3(t * 0.4, -t * 0.2, t * 0.3));
	float n2 = fbm(dir * 6.5 - vec3(t * 0.3, t * 0.5, -t * 0.2));
	float neb_mask = smoothstep(0.42, 0.84, n1 * 0.65 + n2 * 0.35);
	vec3 neb_cyan = vec3(0.08, 0.46, 0.72) * neb_mask * 0.44;
	vec3 neb_ember = vec3(0.62, 0.28, 0.10) * smoothstep(0.56, 0.88, n2) * smoothstep(-0.2, 0.6, dir.x) * 0.32;
	col += (neb_cyan + neb_ember) * stage_tint;

	// 3. Dynamic Undulating Éther Aurora Currents across the ecliptic plane
	float wave = sin(dir.x * 5.0 + dir.z * 3.0 + TIME * 0.25) * 0.14;
	float band = exp(-pow((dir.y - wave) * 5.2, 2.0));
	float aurora_noise = fbm(vec3(dir.xz * 8.0, TIME * 0.18));
	vec3 ether_aurora = mix(vec3(0.08, 0.58, 0.82), vec3(0.36, 0.88, 0.98), aurora_noise) * band * smoothstep(0.36, 0.80, aurora_noise) * 0.48;
	col += ether_aurora * stage_tint;

	// 4. The Calm (La Calma) — Encroaching dark decay front on the northern horizon (-Z)
	float calm_front = smoothstep(-0.25, -0.85, dir.z) * exp(-abs(dir.y) * 2.2);
	float calm_vein = smoothstep(0.68, 0.76, fbm(dir * 10.0 + vec3(0.0, 0.0, TIME * 0.35)));
	col = mix(col, vec3(0.012, 0.004, 0.022), calm_front * 0.72);
	col += vec3(0.58, 0.12, 0.46) * calm_front * calm_vein * (0.6 + 0.4 * sin(TIME * 2.5));

	// 5. Multi-Layered Twinkling Starfield
	vec3 star_grid = floor(dir * 260.0);
	float star_val = hash(star_grid);
	if (star_val > 0.992) {
		vec3 star_pos = normalize(star_grid + 0.5);
		float d = length(dir - star_pos) * 260.0;
		float twinkle = 0.65 + 0.35 * sin(TIME * (3.0 + fract(star_val * 91.3) * 6.0) + star_val * 100.0);
		float spark = exp(-d * d * 14.0) * twinkle;
		vec3 s_col = mix(vec3(0.68, 0.88, 1.0), vec3(1.0, 0.84, 0.60), fract(star_val * 37.0));
		col += s_col * spark * 1.75;
	}

	// 6. Distant Key Star Corona & Bloom
	vec3 sun_dir = normalize(vec3(0.45, 0.52, -0.72));
	float sun_dot = max(dot(dir, sun_dir), 0.0);
	col += vec3(1.0, 0.88, 0.65) * pow(sun_dot, 180.0) * 2.5;
	col += vec3(0.28, 0.68, 0.92) * pow(sun_dot, 16.0) * 0.25;

	COLOR = col;
}
"""
	if _nebula_tex == null and ResourceLoader.exists("res://assets/environments/ether_nebula_hdri.png"):
		_nebula_tex = load("res://assets/environments/ether_nebula_hdri.png")
	var sm := ShaderMaterial.new()
	sm.shader = _sky_shader
	if _nebula_tex != null:
		sm.set_shader_parameter("nebula_pano", _nebula_tex)
	return sm

static func _create_planet_material() -> ShaderMaterial:
	if _planet_shader == null:
		_planet_shader = Shader.new()
		_planet_shader.code = """
shader_type spatial;

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
			mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
			mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y),
		f.z
	);
}

void fragment() {
	vec3 p = vec3(UV * 12.0, 1.0);
	float n = noise(p) * 0.6 + noise(p * 2.5) * 0.3 + noise(p * 6.0) * 0.1;
	vec3 basalt = mix(vec3(0.06, 0.08, 0.13), vec3(0.16, 0.21, 0.28), n);

	float forge_veins = smoothstep(0.67, 0.75, noise(p * 3.5 + vec3(TIME * 0.05, 0.0, 0.0)));
	float pulse = 0.78 + 0.22 * sin(TIME * 2.2 + UV.x * 18.0);
	vec3 ember_glow = vec3(0.95, 0.42, 0.10) * forge_veins * pulse * 1.45;

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.4);
	vec3 atmo = vec3(0.18, 0.68, 0.88) * fresnel * 1.15;

	ALBEDO = basalt;
	ROUGHNESS = 0.72;
	METALLIC = 0.35;
	EMISSION = ember_glow + atmo;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _planet_shader
	return sm

static func _create_ring_material() -> ShaderMaterial:
	if _ring_shader == null:
		_ring_shader = Shader.new()
		_ring_shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

void fragment() {
	float bands = 0.5 + 0.5 * sin(UV.y * 62.83 + TIME * 0.4);
	float fine = 0.5 + 0.5 * cos(UV.y * 180.0 - UV.x * 12.0);
	vec3 col = mix(vec3(0.16, 0.62, 0.82), vec3(0.85, 0.52, 0.20), smoothstep(0.6, 0.9, fine));
	ALBEDO = col * 0.95;
	ALPHA = clamp(bands * 0.28 + fine * 0.14, 0.04, 0.42);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _ring_shader
	return sm

static func _create_ribbon_material() -> ShaderMaterial:
	if _ribbon_shader == null:
		_ribbon_shader = Shader.new()
		_ribbon_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

void vertex() {
	VERTEX.y += sin(VERTEX.z * 0.08 + TIME * 1.4 + VERTEX.x * 0.2) * 1.15;
}

void fragment() {
	float edge_fade = sin(UV.x * 3.14159);
	float end_fade = sin(UV.y * 3.14159);
	float stream1 = 0.5 + 0.5 * sin(UV.x * 24.0 + UV.y * 18.0 - TIME * 2.2);
	float stream2 = 0.5 + 0.5 * cos(UV.x * 14.0 - UV.y * 32.0 + TIME * 1.5);
	float filament = smoothstep(0.58, 0.95, stream1 * 0.6 + stream2 * 0.4);
	vec3 col = mix(vec3(0.08, 0.54, 0.78), vec3(0.42, 0.90, 1.0), filament);
	ALBEDO = col * (0.75 + filament * 0.95);
	ALPHA = edge_fade * end_fade * (0.08 + filament * 0.22);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = _ribbon_shader
	return sm
