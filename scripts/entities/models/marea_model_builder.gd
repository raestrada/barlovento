class_name MareaModelBuilder
extends ProceduralMeshPrimitives

static func build(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
	_build_marea(ship, root, thrusters)

static func _build_marea(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
    var s := ship.body_size
    var is_raider := (ship.ship_id == "marea_raider")
    var is_brig := (ship.ship_id == "marea_brigantine")

    var wood := _textured(load(MAREA_HULL), 0.10, 0.56, Vector3(2.2, 2.2, 1.0))
    wood.albedo_color = Color(1.18, 1.12, 1.05)
    wood.cull_mode = BaseMaterial3D.CULL_DISABLED
    var dark_timber := _colored(Color(0.20, 0.13, 0.08), 0.18, 0.52)
    var brass := _colored(Color(0.84, 0.66, 0.28), 0.72, 0.28)
    var dark_bronze := _colored(Color(0.38, 0.28, 0.14), 0.65, 0.36)
    var glass_dome := _translucent(Color(0.95, 0.68, 0.28, 0.55), Color(0.92, 0.56, 0.18), 0.85)
    var sail_mat := _get_quantum_sail_material()
    var hab := _emissive(Color(0.98, 0.66, 0.22), 1.35)
    # Subtle, crisp translucent cyan vane material so individual oars never blur into a blob of light
    var oar_vane_mat := _translucent(Color(0.16, 0.72, 0.88, 0.74), Color(0.14, 0.64, 0.82), 0.68)

    var half_len := s.z * 0.5
    var hull_mesh := build_loft(_marea_profile(s), [
        {"z": -half_len * 1.02, "scale": Vector2(0.05, 0.25), "offset_y": 0.22},
        {"z": -half_len * 0.82, "scale": Vector2(0.42, 0.55), "offset_y": 0.12},
        {"z": -half_len * 0.50, "scale": Vector2(0.76, 0.82), "offset_y": 0.04},
        {"z": -half_len * 0.15, "scale": Vector2(0.96, 0.96), "offset_y": 0.0},
        {"z": half_len * 0.22, "scale": Vector2(1.02, 1.0), "offset_y": 0.0},
        {"z": half_len * 0.60, "scale": Vector2(0.96, 1.05), "offset_y": 0.06},
        {"z": half_len * 0.86, "scale": Vector2(0.78, 1.18), "offset_y": 0.18},
        {"z": half_len, "scale": Vector2(0.64, 1.24), "offset_y": 0.26},
    ])
    var hull_inst := MeshInstance3D.new()
    hull_inst.mesh = hull_mesh
    hull_inst.material_override = wood
    root.add_child(hull_inst)

    # Riveted Brass Structural Hull Ribs (matching galleon.png)
    for rib_idx in range(-2, 3):
        var rz := float(rib_idx) * s.z * 0.17
        root.add_child(_box(
            Vector3(s.x * 0.96, s.y * 0.52, 0.045), brass,
            Vector3(0.0, 0.02, rz)
        ))

    # Sealed Pressurized Glass-and-Brass Greenhouse Domes on Dorsal Deck (no open air decks!)
    var fore_dome := _sphere(s.x * 0.28, s.y * 0.34, glass_dome, Vector3(0.0, s.y * 0.28, -s.z * 0.20))
    fore_dome.scale = Vector3(1.0, 0.65, 1.45)
    root.add_child(fore_dome)

    # Ornate Raised Stern Castle / Pressurized Bridge Cupola
    root.add_child(_box(
        Vector3(s.x * 0.62, s.y * 0.48, s.z * 0.26), dark_timber,
        Vector3(0.0, s.y * 0.42, s.z * 0.34)
    ))
    root.add_child(_box(
        Vector3(s.x * 0.66, s.y * 0.08, s.z * 0.28), brass,
        Vector3(0.0, s.y * 0.66, s.z * 0.34)
    ))
    var aft_dome := _sphere(s.x * 0.26, s.y * 0.30, glass_dome, Vector3(0.0, s.y * 0.72, s.z * 0.34))
    aft_dome.scale = Vector3(1.05, 0.62, 1.25)
    root.add_child(aft_dome)

    # Warm Amber Stern Gallery Windows
    for w_idx in range(-2, 3):
        root.add_child(_box(
            Vector3(s.x * 0.07, s.y * 0.16, 0.05), hab,
            Vector3(float(w_idx) * s.x * 0.12, s.y * 0.38, s.z * 0.48)
        ))

    # Bowsprit & Brass Keel Fin
    root.add_child(_cyl(
        0.03, 0.06, s.z * 0.42, 8, brass,
        Vector3(0.0, s.y * 0.22, -s.z * 0.62), Vector3(-76.0, 0.0, 0.0)
    ))

    # Class-Specific Mast & Quantum Sail Rigging (3 Masts for Galleon, 2 Masts for Raider/Brigantine)
    var mast_configs := [
        {"z": -s.z * 0.26, "h": s.y * 2.0, "w": s.x * 2.1},
        {"z": s.z * 0.04, "h": s.y * 2.4, "w": s.x * 2.5},
        {"z": s.z * 0.32, "h": s.y * 1.8, "w": s.x * 1.85},
    ]
    if is_raider or is_brig:
        mast_configs = [
            {"z": -s.z * 0.18, "h": s.y * 2.1, "w": s.x * 2.2},
            {"z": s.z * 0.20, "h": s.y * 1.9, "w": s.x * 1.95},
        ]

    for mc in mast_configs:
        var mz: float = mc["z"]
        var mh: float = mc["h"]
        var sw: float = mc["w"]

        # Mast pole & Mechanical Brass Pivot Base
        root.add_child(_cyl(0.08, 0.11, s.y * 0.22, 10, dark_bronze, Vector3(0.0, s.y * 0.28, mz)))
        root.add_child(_cyl(
            0.038, 0.062, mh, 8, brass,
            Vector3(0.0, mh * 0.5, mz)
        ))
        # Upper & Lower Brass Yardarms
        root.add_child(_cyl(
            0.026, 0.026, sw * 0.92, 6, brass,
            Vector3(0.0, mh * 0.92, mz), Vector3(0.0, 0.0, 90.0)
        ))
        root.add_child(_cyl(
            0.030, 0.030, sw * 1.05, 6, brass,
            Vector3(0.0, mh * 0.22, mz), Vector3(0.0, 0.0, 90.0)
        ))
        # Diagonal Radial Brass Spar Booms (matching galleon.png!)
        for side in [-1.0, 1.0]:
            root.add_child(_cyl(
                0.018, 0.028, sw * 0.62, 6, brass,
                Vector3(side * sw * 0.24, mh * 0.54, mz - 0.04),
                Vector3(0.0, 0.0, side * -42.0)
            ))

        # 3D Curved Billowing Sail Mesh
        var sail_inst := MeshInstance3D.new()
        sail_inst.mesh = _build_curved_sail_mesh(sw, mh * 0.72, 0.36)
        sail_inst.material_override = sail_mat
        sail_inst.position = Vector3(0.0, mh * 0.56, mz - 0.08)
        root.add_child(sail_inst)

    # Banks of Articulated Mechanical Éther-Oars per flank (5 for Galleon, 4 for Raider, 3 for Brigantine)
    var oar_count := 5 if not (is_raider or is_brig) else (4 if is_raider else 3)
    for side in [-1.0, 1.0]:
        for i in range(oar_count):
            var z := -s.z * 0.28 + float(i) * (s.z * 0.56 / float(maxi(oar_count - 1, 1)))
            # Armored Bronze Oar-Port Gimbal on the Hull Flank
            root.add_child(_box(
                Vector3(0.09, 0.11, 0.11), dark_bronze,
                Vector3(side * s.x * 0.43, -s.y * 0.05, z)
            ))

            var oar_pivot := Node3D.new()
            oar_pivot.position = Vector3(side * s.x * 0.45, -s.y * 0.05, z)
            # Swept aft and angled downward so each oar is clearly separated
            oar_pivot.rotation_degrees = Vector3(16.0, side * -22.0, side * -56.0)
            root.add_child(oar_pivot)

            var shaft_len := s.x * 0.88
            # Primary Brass Mechanical Oar Shaft
            oar_pivot.add_child(_cyl(
                0.022, 0.032, shaft_len, 8, brass,
                Vector3(0.0, -shaft_len * 0.5, 0.0)
            ))
            # Mid-Shaft Articulated Hydraulic Knuckle Collar
            oar_pivot.add_child(_cyl(
                0.038, 0.038, 0.09, 8, dark_bronze,
                Vector3(0.0, -shaft_len * 0.52, 0.0)
            ))

            # Framed Oar Vane at Tip: Solid Brass Spine & Bracket + Thin Translucent Cyan Vane Blade
            var blade_len := s.x * 0.46
            var blade_w := s.x * 0.12
            var blade_y := -shaft_len - blade_len * 0.48
            # Central Brass Spine running down the vane
            oar_pivot.add_child(_cyl(
                0.014, 0.020, blade_len * 0.95, 6, brass,
                Vector3(0.0, blade_y, -blade_w * 0.35)
            ))
            # Brass Top Collar of the Vane
            oar_pivot.add_child(_box(
                Vector3(0.028, 0.04, blade_w * 1.05), brass,
                Vector3(0.0, -shaft_len - 0.02, 0.0)
            ))
            # Thin Translucent Cyan Vane Membrane (non-blowing-out!)
            oar_pivot.add_child(_box(
                Vector3(0.014, blade_len, blade_w), oar_vane_mat,
                Vector3(0.0, blade_y, 0.0)
            ))

    # Broadside Brass Mass-Driver Turrets & Hab-Lights along the upper flank
    for side in [-1.0, 1.0]:
        for i in range(3):
            var gz := -s.z * 0.22 + float(i) * s.z * 0.18
            root.add_child(_box(
                Vector3(0.10, 0.10, 0.12), dark_bronze,
                Vector3(side * s.x * 0.45, s.y * 0.10, gz)
            ))
            root.add_child(_cyl(
                0.022, 0.026, 0.22, 8, brass,
                Vector3(side * s.x * 0.54, s.y * 0.10, gz), Vector3(0.0, 0.0, 90.0)
            ))
        for i in range(4):
            var wz := -s.z * 0.24 + float(i) * s.z * 0.16
            root.add_child(_sphere(
                0.045, 0.09, hab, Vector3(side * s.x * 0.44, s.y * 0.01, wz)
            ))

    # Stern Quantum Rudder Vanes & Thrusters
    for side in [-1.0, 1.0]:
        var stern_vane := _box(
            Vector3(0.025, s.y * 0.20, s.z * 0.18), oar_vane_mat,
            Vector3(side * s.x * 0.30, -s.y * 0.08, s.z * 0.56),
            Vector3(-12.0, side * 18.0, 0.0)
        )
        root.add_child(stern_vane)
        thrusters.append(stern_vane)

static func _build_curved_sail_mesh(width: float, height: float, belly_depth: float) -> ArrayMesh:
    var cols := 12
    var rows := 10
    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()

    for r in range(rows + 1):
        var v := float(r) / float(rows)
        var y := (0.5 - v) * height
        var row_w := width * lerpf(0.84, 1.0, v)
        var vertical_camber := sin(v * PI)
        for c in range(cols + 1):
            var u := float(c) / float(cols)
            var x := (u - 0.5) * row_w
            var horiz_camber := sin(u * PI)
            var z := -belly_depth * vertical_camber * horiz_camber
            verts.append(Vector3(x, y, z))
            normals.append(Vector3((u - 0.5) * 0.35, 0.0, -1.0).normalized())
            uvs.append(Vector2(u, v))

    var stride := cols + 1
    for r in range(rows):
        for c in range(cols):
            var i0 := r * stride + c
            var i1 := i0 + 1
            var i2 := (r + 1) * stride + c
            var i3 := i2 + 1
            indices.append(i0)
            indices.append(i2)
            indices.append(i1)
            indices.append(i1)
            indices.append(i2)
            indices.append(i3)

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

