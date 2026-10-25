class_name CombatVfxManager
extends Node3D

func spawn_laser_beam(from_pos: Vector3, to_pos: Vector3, color: Color, is_mega_beam: bool = false) -> void:
	var dir := to_pos - from_pos
	var dist := dir.length()
	if dist < 0.1:
		return
	var norm := dir / dist
	var right := norm.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT

	# Multi-salvo volumetric 3D beam cylinders + muzzle flash
	var offsets := [Vector3.ZERO, right * 0.45 + Vector3.UP * 0.15, -right * 0.45 - Vector3.UP * 0.15]
	if is_mega_beam:
		offsets = [
			Vector3.ZERO,
			right * 0.75 + Vector3.UP * 0.35, -right * 0.75 - Vector3.UP * 0.35,
			right * 0.40 - Vector3.UP * 0.40, -right * 0.40 + Vector3.UP * 0.40
		]
	# Transient dynamic muzzle + midpoint OmniLight3D so beams illuminate nearby ship armor
	var muzzle_light := OmniLight3D.new()
	muzzle_light.light_color = color.lerp(Color(1.0, 0.96, 0.90), 0.35)
	muzzle_light.light_energy = 8.5 if is_mega_beam else 4.8
	muzzle_light.omni_range = 32.0 if is_mega_beam else 18.0
	muzzle_light.omni_attenuation = 1.35
	muzzle_light.position = from_pos
	add_child(muzzle_light)

	var mid_light := OmniLight3D.new()
	mid_light.light_color = color
	mid_light.light_energy = 6.5 if is_mega_beam else 3.2
	mid_light.omni_range = 36.0 if is_mega_beam else 22.0
	mid_light.omni_attenuation = 1.4
	mid_light.position = (from_pos + to_pos) * 0.5
	add_child(mid_light)

	var light_tween := create_tween()
	var light_dur := 0.52 if is_mega_beam else 0.35
	light_tween.set_parallel(true)
	light_tween.tween_property(muzzle_light, "light_energy", 0.0, light_dur)
	light_tween.tween_property(mid_light, "light_energy", 0.0, light_dur)
	light_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(muzzle_light):
			muzzle_light.queue_free()
		if is_instance_valid(mid_light):
			mid_light.queue_free()
	)

	for i in range(offsets.size()):
		var off: Vector3 = offsets[i]
		var start_p := from_pos + off
		var end_p := to_pos + off * 0.35
		var beam_vec := end_p - start_p
		var beam_len := beam_vec.length()

		var beam_node := Node3D.new()
		add_child(beam_node)
		beam_node.global_position = (start_p + end_p) * 0.5
		var up := Vector3.UP if absf(norm.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		beam_node.look_at(end_p, up)

		var cyl_inst := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var radius := (0.42 if i == 0 else 0.18) if is_mega_beam else (0.16 if i == 0 else 0.09)
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = beam_len
		cyl_inst.mesh = cyl
		cyl_inst.rotation_degrees = Vector3(90.0, 0.0, 0.0)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.98) if i == 0 else color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = (8.5 if i == 0 else 5.5) if is_mega_beam else (5.5 if i == 0 else 3.8)
		cyl_inst.material_override = mat
		beam_node.add_child(cyl_inst)

		var tween := create_tween()
		var fade_dur := 0.48 if is_mega_beam else 0.32
		tween.tween_property(mat, "albedo_color:a", 0.0, fade_dur + float(i) * 0.05)
		tween.parallel().tween_property(cyl_inst, "scale:x", 0.1, fade_dur + float(i) * 0.05)
		tween.parallel().tween_property(cyl_inst, "scale:z", 0.1, fade_dur + float(i) * 0.05)
		tween.chain().tween_callback(beam_node.queue_free)

func spawn_impact_flash(pos: Vector3, color: Color) -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.1
	sphere.height = 2.2
	flash.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	flash.material_override = mat
	flash.position = pos
	add_child(flash)

	# Expanding 3D Shockwave Torus Ring
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.15
	torus.rings = 24
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(1.0, 0.92, 0.7, 0.9)
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 3.5
	ring.material_override = ring_mat
	ring.position = pos
	add_child(ring)

	# Secondary tilted plasma shockwave ring
	var ring2 := MeshInstance3D.new()
	ring2.mesh = torus
	ring2.material_override = ring_mat
	ring2.position = pos
	ring2.rotation_degrees = Vector3(58.0, 24.0, 32.0)
	add_child(ring2)

	# Transient dynamic impact OmniLight3D to cast specular highlights on nearby hulls
	var impact_light := OmniLight3D.new()
	impact_light.light_color = color.lerp(Color(1.0, 0.92, 0.78), 0.30)
	impact_light.light_energy = 7.2
	impact_light.omni_range = 28.0
	impact_light.omni_attenuation = 1.3
	impact_light.position = pos
	add_child(impact_light)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(3.6, 3.6, 3.6), 0.28)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
	tween.tween_property(ring, "scale", Vector3(5.2, 5.2, 5.2), 0.36)
	tween.tween_property(ring2, "scale", Vector3(4.2, 4.2, 4.2), 0.32)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.36)
	tween.tween_property(impact_light, "light_energy", 0.0, 0.38)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free()
		if is_instance_valid(ring):
			ring.queue_free()
		if is_instance_valid(ring2):
			ring2.queue_free()
		if is_instance_valid(impact_light):
			impact_light.queue_free()
	)

func spawn_combat_text(pos: Vector3, text: String, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = color
	lbl.outline_modulate = Color(0.02, 0.02, 0.05, 0.95)
	lbl.outline_size = 3
	lbl.font_size = 20
	lbl.position = pos + Vector3.UP * 2.8
	add_child(lbl)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", lbl.position.y + 3.0, 0.85)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(lbl.queue_free)
