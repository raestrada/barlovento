class_name ShipModelBuilder

const ACERO_HULL := "res://assets/ships/acero/acero_hull.png"
const VINCULADOS_HULL := "res://assets/ships/vinculados/vinculados_hull.png"
const MAREA_HULL := "res://assets/ships/marea-libre/marea_hull.png"

static var _quantum_sail_shader: Shader = null
static var _soul_core_shader: Shader = null

static func build(ship: Ship, root: Node3D, thruster_lights: Array[Node3D]) -> void:
    match ship.faction:
        "acero":
            _build_acero(ship, root, thruster_lights)
        "vinculados":
            _build_vinculados(ship, root, thruster_lights)
        "marea_libre":
            _build_marea(ship, root, thruster_lights)
        _:
            _build_acero(ship, root, thruster_lights)

# ---------------------------------------------------------------------------
# Armada of Acero — Brutalist steel warship, prow ram, glowing amber intake
# trenches, superfiring triple-barrel turrets, tiered citadel, quad engines.
# ---------------------------------------------------------------------------

static func _build_acero(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
    var s := ship.body_size
    var hull := _textured(load(ACERO_HULL), 0.42, 0.42, Vector3(2.2, 2.2, 1.0))
    hull.albedo_color = Color(1.65, 1.72, 1.85)
    hull.rim_enabled = true
    hull.rim = 0.48
    hull.rim_tint = 0.25
    hull.emission_enabled = true
    hull.emission = Color(0.09, 0.12, 0.17)
    hull.emission_energy_multiplier = 0.38
    hull.cull_mode = BaseMaterial3D.CULL_DISABLED

    var armor := _textured(load(ACERO_HULL), 0.48, 0.35, Vector3(2.8, 2.8, 1.0))
    armor.albedo_color = Color(1.90, 1.98, 2.12)
    armor.rim_enabled = true
    armor.rim = 0.58
    armor.rim_tint = 0.20
    armor.emission_enabled = true
    armor.emission = Color(0.12, 0.15, 0.21)
    armor.emission_energy_multiplier = 0.42
    armor.cull_mode = BaseMaterial3D.CULL_DISABLED

    var dark_steel := _colored(Color(0.28, 0.32, 0.40), 0.45, 0.40)
    dark_steel.rim_enabled = true
    dark_steel.rim = 0.42
    var gunmetal := _colored(Color(0.44, 0.49, 0.58), 0.50, 0.32)
    gunmetal.rim_enabled = true
    gunmetal.rim = 0.52
    var steel_trim := _colored(Color(0.60, 0.66, 0.75), 0.55, 0.28)
    var engine_glow := _emissive(Color(1.0, 0.48, 0.12), 2.2)
    var amber_vent := _emissive(Color(0.98, 0.54, 0.14), 1.35)
    var bridge_lit := _emissive(Color(0.45, 0.88, 1.0), 1.25)

    # Dedicated Hull Fill Light so dark steel armor plates and turrets are always readable
    var hull_light := OmniLight3D.new()
    hull_light.position = Vector3(0.0, s.y * 1.45, -s.z * 0.05)
    hull_light.light_color = Color(0.78, 0.86, 0.98)
    hull_light.light_energy = 1.15
    hull_light.omni_range = maxf(s.z * 1.6, 12.0)
    hull_light.omni_attenuation = 1.2
    root.add_child(hull_light)

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
    root.add_child(_box(
        Vector3(s.x * 0.30, s.y * 0.54, s.z * 0.26), armor,
        Vector3(0.0, -s.y * 0.06, -half_len * 0.86)
    ))
    root.add_child(_box(
        Vector3(s.x * 0.14, s.y * 0.06, s.z * 0.78), steel_trim,
        Vector3(0.0, s.y * 0.30, -s.z * 0.06)
    ))

    # Armored Sponsons with Recessed Amber Éther-Furnace Louvers
    for side in [-1.0, 1.0]:
        root.add_child(_box(
            Vector3(s.x * 0.18, s.y * 0.38, s.z * 0.62), armor,
            Vector3(side * s.x * 0.52, -s.y * 0.04, s.z * 0.05)
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

    # Tiered Command Citadel & Armored Bridge Tower
    root.add_child(_box(
        Vector3(s.x * 0.54, s.y * 0.55, s.z * 0.36), dark_steel,
        Vector3(0.0, s.y * 0.48, s.z * 0.10)
    ))
    root.add_child(_box(
        Vector3(s.x * 0.38, s.y * 0.48, s.z * 0.22), armor,
        Vector3(0.0, s.y * 0.84, s.z * 0.14)
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
        0.03, 0.05, s.y * 0.75, 6, steel_trim,
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
        # Hammer-Class Battlecruiser: Twin Axial Spinal Railgun Barrels along the Dorsal Bow + Outrigger Pods
        for side in [-1.0, 1.0]:
            root.add_child(_cyl(
                s.x * 0.04, s.x * 0.055, s.z * 0.58, 10, steel_trim,
                Vector3(side * s.x * 0.14, s.y * 0.36, -s.z * 0.24),
                Vector3(90.0, 0.0, 0.0)
            ))
            root.add_child(_box(
                Vector3(s.x * 0.22, s.y * 0.24, s.z * 0.34), gunmetal,
                Vector3(side * s.x * 0.66, 0.0, s.z * 0.12)
            ))
            root.add_child(_box(
                Vector3(s.x * 0.14, s.y * 0.12, 0.06), amber_vent,
                Vector3(side * s.x * 0.66, 0.0, -s.z * 0.06)
            ))
    elif is_corvette:
        # Chisel-Class Escort Corvette: Forward Swept Sensor Spines & Agile Dorsal Rotary Turret
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
        root.add_child(_box(Vector3(s.x * 0.28, s.y * 0.18, s.z * 0.10), gunmetal, tpos))
        root.add_child(_box(Vector3(s.x * 0.24, s.y * 0.04, s.z * 0.08), steel_trim, tpos + Vector3(0.0, s.y * 0.10, 0.0)))
        var barrels := [-1.0, 0.0, 1.0] if is_dread else [-0.6, 0.6]
        for b_off in barrels:
            root.add_child(_cyl(
                s.x * 0.025, s.x * 0.032, s.z * 0.14, 8, steel_trim,
                tpos + Vector3(float(b_off) * s.x * 0.065, s.y * 0.02, dir_z * s.z * 0.08),
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
            var nozzle := _cyl(
                s.x * 0.11, s.x * 0.18, 0.55, 12, engine_glow,
                Vector3(ex, ey, s.z * 0.62), Vector3(-90.0, 0.0, 0.0)
            )
            root.add_child(nozzle)
            thrusters.append(nozzle)

# ---------------------------------------------------------------------------
# The Vinculados — Biomechanical Neural-Linked Frames (Eidolon, Anima, Nous)
# ---------------------------------------------------------------------------

static func _build_vinculados(ship: Ship, root: Node3D, thrusters: Array[Node3D]) -> void:
    var s := ship.body_size
    var h := s.z
    var w := s.x
    var d := s.y

    var is_anima := (ship.ship_id == "vinculados_anima")
    var is_nous := (ship.ship_id == "vinculados_nous")

    var ceramic := _textured(load(VINCULADOS_HULL), 0.18, 0.22, Vector3(2.0, 2.0, 1.0))
    if is_anima:
        ceramic.albedo_color = Color(0.88, 0.98, 1.0)
    elif is_nous:
        ceramic.albedo_color = Color(0.95, 0.90, 1.0)
    var frame_dark := _colored(Color(0.10, 0.11, 0.15), 0.68, 0.38)
    var cyan_visor := _emissive(Color(0.25, 0.88, 1.0), 1.8)
    var core_mat := _get_soul_core_material()
    var lance_beam := _emissive(Color(0.30, 0.88, 1.0), 2.0)
    var shield_mat := _translucent(Color(0.85, 0.25, 0.95, 0.38), Color(0.75, 0.20, 0.85), 1.1)

    # Dark Biomechanical Sinew Core & Spine
    var spine := _capsule(w * 0.20, h * 0.34, frame_dark, Vector3(0.0, h * 0.14, 0.0))
    root.add_child(spine)

    # Sculpted Organic White Ceramic Chest & Abdomen Plates
    var chest := _sphere(w * 0.32, h * 0.24, ceramic, Vector3(0.0, h * 0.23, -d * 0.04))
    chest.scale = Vector3(1.22, 0.95, 0.82)
    root.add_child(chest)

    var abdomen := _cyl(w * 0.22, w * 0.17, h * 0.16, 12, ceramic, Vector3(0.0, h * 0.08, 0.0))
    root.add_child(abdomen)

    # Hip & Pelvis Ceramic Armor Plates over Sinew
    for side in [-1.0, 1.0]:
        var hip_plate := _sphere(w * 0.16, h * 0.14, ceramic, Vector3(side * w * 0.20, -h * 0.01, -d * 0.04))
        hip_plate.scale = Vector3(0.75, 1.15, 0.90)
        hip_plate.rotation_degrees = Vector3(8.0, 0.0, side * -14.0)
        root.add_child(hip_plate)

    # Exposed Circular Pulsing Magenta Soul Core in Chest Center
    var core_ring := _cyl(w * 0.16, w * 0.18, d * 0.14, 14, frame_dark, Vector3(0.0, h * 0.22, -d * 0.32), Vector3(90.0, 0.0, 0.0))
    root.add_child(core_ring)
    root.add_child(_sphere(
        w * 0.14, w * 0.28, core_mat, Vector3(0.0, h * 0.22, -d * 0.36)
    ))

    # Biomechanical Neck Sinew + Smooth Aerodynamic Dome Helmet + Thin Cyan Slit Visor
    root.add_child(_cyl(w * 0.09, w * 0.11, h * 0.09, 10, frame_dark, Vector3(0.0, h * 0.33, 0.0)))
    var helmet := _sphere(w * 0.16, h * 0.19, ceramic, Vector3(0.0, h * 0.40, -d * 0.02))
    helmet.scale = Vector3(0.92, 1.08, 1.12)
    root.add_child(helmet)
    root.add_child(_box(
        Vector3(w * 0.22, w * 0.032, w * 0.06), cyan_visor,
        Vector3(0.0, h * 0.39, -w * 0.16)
    ))

    # Sleek Dorsal Thruster Pods + Class-Specific Dorsal Equipment
    for side in [-1.0, 1.0]:
        var pod := _capsule(
            w * 0.08, h * 0.22, ceramic,
            Vector3(side * w * 0.18, h * 0.24, d * 0.28),
            Vector3(-16.0, side * 10.0, side * -12.0)
        )
        root.add_child(pod)
        var pod_rcs := _cyl(
            w * 0.04, w * 0.08, 0.28, 10, cyan_visor,
            Vector3(side * w * 0.22, h * 0.14, d * 0.38),
            Vector3(65.0, 0.0, side * -12.0)
        )
        root.add_child(pod_rcs)
        thrusters.append(pod_rcs)

        if is_nous:
            # Nous-04 Heavy Frame: Over-the-Shoulder Long-Barrel Harmonic Choir Cannons
            root.add_child(_cyl(
                w * 0.045, w * 0.06, h * 0.48, 10, ceramic,
                Vector3(side * w * 0.28, h * 0.38, -d * 0.24),
                Vector3(82.0, 0.0, 0.0)
            ))
            root.add_child(_cyl(
                w * 0.025, w * 0.035, h * 0.16, 8, lance_beam,
                Vector3(side * w * 0.28, h * 0.41, -d * 0.62),
                Vector3(82.0, 0.0, 0.0)
            ))
        elif is_anima:
            # Anima-01 Interceptor: High-Speed Swept Stabilizer Vanes
            root.add_child(_box(
                Vector3(w * 0.03, h * 0.28, d * 0.16), lance_beam,
                Vector3(side * w * 0.36, h * 0.28, d * 0.36),
                Vector3(-24.0, side * 22.0, side * -32.0)
            ))

    # Swept-Outward Curved White Ceramic Shoulder Pauldrons + Under-Shoulder Cyan RCS Jets
    for side in [-1.0, 1.0]:
        var pauldron := _sphere(
            w * 0.26, h * 0.11, ceramic,
            Vector3(side * w * 0.44, h * 0.30, 0.0)
        )
        pauldron.scale = Vector3(1.35, 0.55, 0.95)
        pauldron.rotation_degrees = Vector3(0.0, 0.0, side * -12.0)
        root.add_child(pauldron)

        var sh_rcs := _cyl(
            w * 0.035, w * 0.07, 0.24, 8, cyan_visor,
            Vector3(side * w * 0.48, h * 0.25, d * 0.08),
            Vector3(25.0, 0.0, side * -28.0)
        )
        root.add_child(sh_rcs)
        thrusters.append(sh_rcs)

        # Dark Sinew Upper Arm + Sculpted Ceramic Forearm
        root.add_child(_capsule(
            w * 0.085, h * 0.16, frame_dark,
            Vector3(side * w * 0.40, h * 0.18, -d * 0.06), Vector3(15.0, 0.0, 14.0 * side)
        ))
        root.add_child(_capsule(
            w * 0.08, h * 0.17, ceramic,
            Vector3(side * w * 0.43, h * 0.07, -d * 0.24), Vector3(32.0, 0.0, 8.0 * side)
        ))

    # Right Arm: Slender Resonance Lance (extending forward along -Z)
    root.add_child(_cyl(
        w * 0.03, w * 0.04, h * 0.50, 8, frame_dark,
        Vector3(w * 0.45, h * 0.06, -d * 0.52), Vector3(90.0, 0.0, 0.0)
    ))
    root.add_child(_cyl(
        0.005, w * 0.075, h * 0.44, 10, lance_beam,
        Vector3(w * 0.45, h * 0.06, -d * 1.08), Vector3(-90.0, 0.0, 0.0)
    ))

    # Left Forearm: Translucent Harmonic Barrier Projector
    root.add_child(_box(
        Vector3(w * 0.025, h * 0.34, d * 0.38), shield_mat,
        Vector3(-w * 0.54, h * 0.10, -d * 0.30), Vector3(12.0, 18.0, 10.0)
    ))

    # Articulated Legs & Vernier Thruster Nozzles
    for side in [-1.0, 1.0]:
        root.add_child(_capsule(
            w * 0.11, h * 0.18, frame_dark,
            Vector3(side * w * 0.18, -h * 0.05, 0.0), Vector3(-10.0, 0.0, 0.0)
        ))
        root.add_child(_capsule(
            w * 0.09, h * 0.20, ceramic,
            Vector3(side * w * 0.18, -h * 0.18, d * 0.12), Vector3(18.0, 0.0, 0.0)
        ))
        var vernier := _cyl(
            w * 0.06, w * 0.12, 0.45, 10, core_mat,
            Vector3(side * w * 0.18, -h * 0.28, d * 0.22), Vector3(90.0, 0.0, 0.0)
        )
        root.add_child(vernier)
        thrusters.append(vernier)

# ---------------------------------------------------------------------------
# The Free Tide — Steampunk Void Galleons & Brigantines with curved mahogany
# hull, pressurized deck domes, 3D billowed Quantum Sails, and Éther-Oars.
# ---------------------------------------------------------------------------

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

static func _get_quantum_sail_material() -> ShaderMaterial:
    if _quantum_sail_shader == null:
        _quantum_sail_shader = Shader.new()
        _quantum_sail_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

void fragment() {
    vec2 uv = UV;
    float rib_v = smoothstep(0.93, 0.99, abs(sin(uv.x * 3.14159 * 6.0)));
    float rib_h = smoothstep(0.95, 0.99, abs(sin(uv.y * 3.14159 * 4.0)));
    float edge = max(
        smoothstep(0.44, 0.50, abs(uv.x - 0.5)),
        smoothstep(0.45, 0.50, abs(uv.y - 0.5))
    );
    float pulse = 0.5 + 0.5 * sin(TIME * 2.0 - uv.y * 5.0);
    vec3 base_col = vec3(0.10, 0.58, 0.76);
    vec3 vein_col = vec3(0.55, 0.88, 0.96);
    vec3 brass_edge = vec3(0.78, 0.62, 0.28);
    vec3 col = mix(base_col, vein_col, clamp(rib_v * 0.55 + rib_h * 0.35 + pulse * 0.12, 0.0, 1.0));
    col = mix(col, brass_edge, edge * 0.65);
    ALBEDO = col * 0.92;
    ALPHA = clamp(0.54 + edge * 0.32 + rib_v * 0.18, 0.0, 0.90);
}
"""
    var sm := ShaderMaterial.new()
    sm.shader = _quantum_sail_shader
    return sm

static func _get_soul_core_material() -> ShaderMaterial:
    if _soul_core_shader == null:
        _soul_core_shader = Shader.new()
        _soul_core_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
    float pulse = 0.55 + 0.45 * sin(TIME * 3.8);
    vec3 col = mix(vec3(0.86, 0.18, 0.74), vec3(0.42, 0.85, 0.96), pulse * 0.35);
    ALBEDO = col * (1.25 + pulse * 0.45);
}
"""
    var sm := ShaderMaterial.new()
    sm.shader = _soul_core_shader
    return sm

static func _acero_profile(s: Vector3) -> PackedVector2Array:
    var hw := s.x * 0.5
    var hh := s.y * 0.5
    return PackedVector2Array([
        Vector2(0.0, -0.55 * hh),
        Vector2(0.85 * hw, -0.55 * hh),
        Vector2(hw, -0.15 * hh),
        Vector2(hw, 0.35 * hh),
        Vector2(0.85 * hw, 0.55 * hh),
        Vector2(0.0, 0.6 * hh),
        Vector2(-0.85 * hw, 0.55 * hh),
        Vector2(-hw, 0.35 * hh),
        Vector2(-hw, -0.15 * hh),
        Vector2(-0.85 * hw, -0.55 * hh),
    ])

static func _marea_profile(s: Vector3) -> PackedVector2Array:
    var hw := s.x * 0.5
    var hh := s.y * 0.4
    return PackedVector2Array([
        Vector2(0.0, -0.6 * hh),
        Vector2(0.3 * hw, -0.55 * hh),
        Vector2(0.55 * hw, -0.4 * hh),
        Vector2(0.75 * hw, -0.18 * hh),
        Vector2(0.88 * hw, 0.05 * hh),
        Vector2(0.9 * hw, 0.28 * hh),
        Vector2(0.78 * hw, 0.45 * hh),
        Vector2(0.55 * hw, 0.55 * hh),
        Vector2(0.0, 0.6 * hh),
        Vector2(-0.55 * hw, 0.55 * hh),
        Vector2(-0.78 * hw, 0.45 * hh),
        Vector2(-0.9 * hw, 0.28 * hh),
        Vector2(-0.88 * hw, 0.05 * hh),
        Vector2(-0.75 * hw, -0.18 * hh),
        Vector2(-0.55 * hw, -0.4 * hh),
        Vector2(-0.3 * hw, -0.55 * hh),
    ])

static func build_loft(profile: PackedVector2Array, stations: Array) -> ArrayMesh:
    var n := profile.size()
    var m := stations.size()

    var verts := PackedVector3Array()
    var uvs := PackedVector2Array()

    for i in range(m):
        var s: Dictionary = stations[i]
        var z: float = s["z"]
        var sc: Vector2 = s["scale"]
        var oy: float = s["offset_y"]
        for j in range(n):
            var p := profile[j]
            verts.append(Vector3(p.x * sc.x, p.y * sc.y + oy, z))
            uvs.append(Vector2(float(j) / float(n), float(i) / float(m - 1)))

    var front_center := m * n
    verts.append(Vector3(0.0, stations[0]["offset_y"], stations[0]["z"]))
    uvs.append(Vector2(0.5, 0.0))

    var back_center := m * n + 1
    verts.append(Vector3(0.0, stations[m - 1]["offset_y"], stations[m - 1]["z"]))
    uvs.append(Vector2(0.5, 1.0))

    var indices := PackedInt32Array()
    for i in range(m - 1):
        for j in range(n):
            var a := i * n + j
            var b := i * n + ((j + 1) % n)
            var c := (i + 1) * n + j
            var d := (i + 1) * n + ((j + 1) % n)
            indices.append(a)
            indices.append(c)
            indices.append(b)
            indices.append(b)
            indices.append(c)
            indices.append(d)

    for j in range(n):
        var a := j
        var b := (j + 1) % n
        indices.append(front_center)
        indices.append(b)
        indices.append(a)

    for j in range(n):
        var a := (m - 1) * n + j
        var b := (m - 1) * n + ((j + 1) % n)
        indices.append(back_center)
        indices.append(a)
        indices.append(b)

    var normals := PackedVector3Array()
    normals.resize(verts.size())
    for k in range(verts.size()):
        normals[k] = Vector3.ZERO

    var tri_count := indices.size() / 3
    for t in range(tri_count):
        var ia := indices[t * 3]
        var ib := indices[t * 3 + 1]
        var ic := indices[t * 3 + 2]
        var face_normal := (verts[ib] - verts[ia]).cross(verts[ic] - verts[ia])
        normals[ia] += face_normal
        normals[ib] += face_normal
        normals[ic] += face_normal

    for k in range(normals.size()):
        normals[k] = normals[k].normalized()

    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

static func _box(size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return _instance(mesh, mat, pos, rot)

static func _cyl(top_r: float, bottom_r: float, height: float, radial: int, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = top_r
    mesh.bottom_radius = bottom_r
    mesh.height = height
    mesh.radial_segments = radial
    return _instance(mesh, mat, pos, rot)

static func _sphere(radius: float, height: float, mat: Material, pos: Vector3) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = height
    return _instance(mesh, mat, pos)

static func _capsule(radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    return _instance(mesh, mat, pos, rot)

static func _prism(size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := PrismMesh.new()
    mesh.size = size
    return _instance(mesh, mat, pos, rot)

static func _quad(size: Vector2, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := QuadMesh.new()
    mesh.size = size
    return _instance(mesh, mat, pos, rot)

static func _instance(mesh: PrimitiveMesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    if rot != Vector3.ZERO:
        mi.rotation_degrees = rot
    return mi

static var _hull_normal_tex: NoiseTexture2D = null

static func _get_hull_normal_map() -> NoiseTexture2D:
    if _hull_normal_tex == null:
        var n := FastNoiseLite.new()
        n.seed = 901
        n.noise_type = FastNoiseLite.TYPE_CELLULAR
        n.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
        n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
        n.frequency = 0.085
        _hull_normal_tex = NoiseTexture2D.new()
        _hull_normal_tex.width = 256
        _hull_normal_tex.height = 256
        _hull_normal_tex.seamless = true
        _hull_normal_tex.as_normal_map = true
        _hull_normal_tex.bump_strength = 3.2
        _hull_normal_tex.noise = n
    return _hull_normal_tex

static func _textured(tex: Texture2D, metallic: float, roughness: float, uv: Vector3) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.WHITE
    mat.albedo_texture = tex
    mat.uv1_scale = uv
    mat.uv1_triplanar = true
    mat.uv1_triplanar_sharpness = 4.0
    mat.metallic = metallic
    mat.roughness = roughness
    mat.normal_enabled = true
    mat.normal_texture = _get_hull_normal_map()
    mat.normal_scale = 0.45
    return mat

static func _colored(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = roughness
    mat.uv1_triplanar = true
    mat.normal_enabled = true
    mat.normal_texture = _get_hull_normal_map()
    mat.normal_scale = 0.25
    return mat

static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = energy
    return mat

static func _translucent(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.emission_enabled = true
    mat.emission = emission
    mat.emission_energy_multiplier = energy
    return mat

