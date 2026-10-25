class_name StrategicGridSolver
extends RefCounted

static func configure_stage_grid(stage_id: String) -> Vector2i:
	var cols := 10
	var rows := 8
	match stage_id:
		# --- ARMADA OF ACERO (12 STAGES) ---
		"acero_stage_1", "acero_stage_2":
			cols = 10
			rows = 8
		"acero_stage_3":
			cols = 12
			rows = 9
		"acero_stage_4":
			cols = 8
			rows = 12
		"acero_stage_5":
			cols = 11
			rows = 9
		"acero_stage_6":
			cols = 10
			rows = 10
		"acero_stage_7":
			cols = 12
			rows = 10
		"acero_stage_8":
			cols = 9
			rows = 9
		"acero_stage_9":
			cols = 12
			rows = 10
		"acero_stage_10":
			cols = 12
			rows = 8
		"acero_stage_11":
			cols = 13
			rows = 9
		"acero_stage_12":
			cols = 14
			rows = 10

		# --- THE VINCULADOS (12 STAGES) ---
		"vinculados_stage_1":
			cols = 10
			rows = 8
		"vinculados_stage_2":
			cols = 8
			rows = 14
		"vinculados_stage_3":
			cols = 11
			rows = 9
		"vinculados_stage_4":
			cols = 9
			rows = 9
		"vinculados_stage_5":
			cols = 12
			rows = 10
		"vinculados_stage_6":
			cols = 10
			rows = 10
		"vinculados_stage_7":
			cols = 8
			rows = 13
		"vinculados_stage_8":
			cols = 11
			rows = 9
		"vinculados_stage_9":
			cols = 12
			rows = 10
		"vinculados_stage_10":
			cols = 12
			rows = 8
		"vinculados_stage_11":
			cols = 13
			rows = 9
		"vinculados_stage_12":
			cols = 14
			rows = 10

		# --- THE FREE TIDE (12 STAGES) ---
		"marea_stage_1":
			cols = 8
			rows = 12
		"marea_stage_2":
			cols = 11
			rows = 9
		"marea_stage_3":
			cols = 12
			rows = 10
		"marea_stage_4":
			cols = 10
			rows = 9
		"marea_stage_5":
			cols = 12
			rows = 8
		"marea_stage_6":
			cols = 9
			rows = 12
		"marea_stage_7":
			cols = 11
			rows = 10
		"marea_stage_8":
			cols = 10
			rows = 10
		"marea_stage_9":
			cols = 13
			rows = 10
		"marea_stage_10":
			cols = 8
			rows = 14
		"marea_stage_11":
			cols = 12
			rows = 10
		"marea_stage_12":
			cols = 14
			rows = 10

		_:
			cols = 10
			rows = 8
	return Vector2i(cols, rows)

const WORLD_HALF_X: float = 65.0
const WORLD_HALF_Z: float = 75.0

static func world_to_cell(pos: Vector3, _is_player: bool, _idx: int, grid_cols: int, grid_rows: int) -> Vector2i:
	var nx := clampf((pos.x + WORLD_HALF_X) / (WORLD_HALF_X * 2.0), 0.0, 0.999)
	var ny := clampf((pos.z + WORLD_HALF_Z) / (WORLD_HALF_Z * 2.0), 0.0, 0.999)
	return Vector2i(int(nx * float(grid_cols)), int(ny * float(grid_rows)))

static func cell_center_world(cell: Vector2i, grid_cols: int, grid_rows: int) -> Vector3:
	var cx := (float(cell.x) + 0.5) / float(grid_cols) * (WORLD_HALF_X * 2.0) - WORLD_HALF_X
	var cz := (float(cell.y) + 0.5) / float(grid_rows) * (WORLD_HALF_Z * 2.0) - WORLD_HALF_Z
	return Vector3(cx, 0.0, cz)

static func cell_corners_world(cell: Vector2i, grid_cols: int, grid_rows: int, y_plane: float = 0.0) -> Array[Vector3]:
	var x0 := float(cell.x) / float(grid_cols) * (WORLD_HALF_X * 2.0) - WORLD_HALF_X
	var x1 := float(cell.x + 1) / float(grid_cols) * (WORLD_HALF_X * 2.0) - WORLD_HALF_X
	var z0 := float(cell.y) / float(grid_rows) * (WORLD_HALF_Z * 2.0) - WORLD_HALF_Z
	var z1 := float(cell.y + 1) / float(grid_rows) * (WORLD_HALF_Z * 2.0) - WORLD_HALF_Z
	return [
		Vector3(x0, y_plane, z0),
		Vector3(x1, y_plane, z0),
		Vector3(x1, y_plane, z1),
		Vector3(x0, y_plane, z1)
	]

static func get_wingman_offset(ship_idx: int, is_player: bool) -> Vector3:
	@warning_ignore("integer_division")
	var wing_rank: int = ship_idx / 3
	if wing_rank <= 0:
		var div_elev := [1.5, 0.5, 2.5]
		return Vector3(0.0, float(div_elev[ship_idx % 3]), 0.0)
	var wing_offsets := [
		Vector3.ZERO,
		Vector3(-8.5, 2.2, 5.5),
		Vector3(8.5, -1.2, 5.5),
		Vector3(0.0, 3.4, 9.5)
	]
	var off: Vector3 = wing_offsets[clampi(wing_rank, 0, wing_offsets.size() - 1)]
	if not is_player:
		off = Vector3(-off.x, off.y, -off.z)
	return off

static func cell_to_world(cell: Vector2i, facing: Vector2, is_player: bool, idx: int, grid_cols: int, grid_rows: int) -> Dictionary:
	var center := cell_center_world(cell, grid_cols, grid_rows)
	var off := get_wingman_offset(idx, is_player)
	var base_pos := center + off
	var target_fwd := Vector3(facing.x, 0.0, facing.y).normalized()
	if target_fwd.length_squared() < 0.01:
		target_fwd = Vector3.FORWARD if is_player else Vector3.BACK

	var base_speed := 9.0 if is_player else 4.0
	var fwd_dot := target_fwd.dot(Vector3.FORWARD)
	if not is_player:
		fwd_dot = target_fwd.dot(Vector3.BACK)
	if fwd_dot < -0.3:
		base_speed = 4.0
	elif fwd_dot > 0.5:
		base_speed = 11.5

	var out_vel := target_fwd * base_speed
	return {
		"position": base_pos,
		"pos": base_pos,
		"center": center,
		"velocity": out_vel,
		"forward": target_fwd,
		"fwd": target_fwd,
		"speed": base_speed
	}

static func init_sector_terrain(stage_id: String, grid_cols: int, grid_rows: int) -> Dictionary:
	var _sector_types: Dictionary = {}
	match LoreDB.current_stage_id:
		"acero_stage_1":
			# Sluice Well-09 Anchor, lateral ore reefs, diagonal Éther stream
			for p in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 6)]:
				_sector_types[p] = "wind_stream"
			for y in range(2, 6):
				_sector_types[Vector2i(0, y)] = "reef"
				_sector_types[Vector2i(1, y)] = "reef"
				_sector_types[Vector2i(8, y)] = "reef"
				_sector_types[Vector2i(9, y)] = "reef"
			_sector_types[Vector2i(4, 6)] = "sluice"
			_sector_types[Vector2i(5, 6)] = "sluice"
			_sector_types[Vector2i(2, 4)] = "conduit"
			_sector_types[Vector2i(7, 3)] = "conduit"

		"acero_stage_2":
			# Ambush at Resonance Spire: central Sanctuary Spire node, crystal reefs, violent crosswind
			for x in range(1, 9):
				_sector_types[Vector2i(x, 3)] = "wind_stream"
				_sector_types[Vector2i(x, 4)] = "wind_stream"
			_sector_types[Vector2i(4, 3)] = "spire"
			_sector_types[Vector2i(5, 3)] = "spire"
			for y in range(1, 7):
				_sector_types[Vector2i(0, y)] = "reef"
				_sector_types[Vector2i(9, y)] = "reef"
			_sector_types[Vector2i(2, 2)] = "conduit"
			_sector_types[Vector2i(7, 5)] = "conduit"

		"acero_stage_3":
			# Bastion of the Calm Threshold: 12x9 Grand Chart!
			# Top rows 0 and 1 are encroaching Calm dead-zone
			for x in range(grid_cols):
				_sector_types[Vector2i(x, 0)] = "calm"
				_sector_types[Vector2i(x, 1)] = "calm"
			# Strong defensive Sluice Wall at rows 6-7
			_sector_types[Vector2i(5, 7)] = "sluice"
			_sector_types[Vector2i(6, 7)] = "sluice"
			_sector_types[Vector2i(4, 7)] = "sluice"
			_sector_types[Vector2i(7, 7)] = "sluice"
			# Wind stream crossing through center
			for p in [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 6)]:
				_sector_types[p] = "wind_stream"
			_sector_types[Vector2i(2, 5)] = "conduit"
			_sector_types[Vector2i(9, 4)] = "conduit"

		"vinculados_stage_1":
			# Sanctuary Spire Psalm-4: central Spire, 4 levitating resonance crystal beacons, harmonic stream
			_sector_types[Vector2i(4, 4)] = "spire"
			_sector_types[Vector2i(5, 4)] = "spire"
			_sector_types[Vector2i(2, 2)] = "conduit"
			_sector_types[Vector2i(7, 2)] = "conduit"
			_sector_types[Vector2i(2, 6)] = "conduit"
			_sector_types[Vector2i(7, 6)] = "conduit"
			for p in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 5), Vector2i(6, 5)]:
				_sector_types[p] = "wind_stream"

		"vinculados_stage_2":
			# Crystalline Chasm: 8x10 Narrow Deep Trench!
			# Flank columns A-B (0-1) and G-H (6-7) are impassable crystal canyon walls
			for y in range(grid_rows):
				_sector_types[Vector2i(0, y)] = "reef"
				_sector_types[Vector2i(1, y)] = "reef"
				_sector_types[Vector2i(6, y)] = "reef"
				_sector_types[Vector2i(7, y)] = "reef"
			# Central columns D-E (3-4) are Vertical Lift Corridors
			for y in range(1, grid_rows - 1):
				_sector_types[Vector2i(3, y)] = "wind_stream"
				_sector_types[Vector2i(4, y)] = "wind_stream"
			_sector_types[Vector2i(3, 4)] = "spire"
			_sector_types[Vector2i(4, 5)] = "conduit"

		"vinculados_stage_3":
			# Transcendence at the Calm Abyss: 12x8 Grand Arena!
			# Northern rows 0-1 are Calm Void
			for x in range(grid_cols):
				_sector_types[Vector2i(x, 0)] = "calm"
			# Center is the Ancient Genesis Ring Nexus (60m 3-axis ring, +2 AP)
			_sector_types[Vector2i(5, 3)] = "ring"
			_sector_types[Vector2i(6, 3)] = "ring"
			_sector_types[Vector2i(5, 4)] = "ring"
			_sector_types[Vector2i(6, 4)] = "ring"
			# Swirling harmonic streams feeding into the ring
			for p in [Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 3), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 5)]:
				_sector_types[p] = "wind_stream"
			_sector_types[Vector2i(2, 5)] = "conduit"
			_sector_types[Vector2i(9, 2)] = "conduit"

		"marea_stage_1":
			# The Basalt Narrows: 8x10 Canyon Gorge!
			# Dense basalt canyon walls on cols 0-1 and 6-7
			for y in range(grid_rows):
				_sector_types[Vector2i(0, y)] = "reef"
				_sector_types[Vector2i(1, y)] = "reef"
				_sector_types[Vector2i(6, y)] = "reef"
				_sector_types[Vector2i(7, y)] = "reef"
			# El Río del Viento roaring straight down the center (cols 3-4)
			for y in range(grid_rows):
				_sector_types[Vector2i(3, y)] = "wind_stream"
				_sector_types[Vector2i(4, y)] = "wind_stream"
			_sector_types[Vector2i(3, 8)] = "sluice"

		"marea_stage_2":
			# Raid on Foundry Sluice-Gates: 10x8 industrial ore refinery labyrinth
			_sector_types[Vector2i(4, 3)] = "sluice"
			_sector_types[Vector2i(5, 3)] = "sluice"
			_sector_types[Vector2i(4, 4)] = "sluice"
			_sector_types[Vector2i(5, 4)] = "sluice"
			# Twin turbine exhaust jet streams giving massive lateral burst speed
			for x in range(1, 9):
				_sector_types[Vector2i(x, 2)] = "wind_stream"
				_sector_types[Vector2i(x, 5)] = "wind_stream"
			for y in range(2, 6):
				_sector_types[Vector2i(0, y)] = "reef"
				_sector_types[Vector2i(9, y)] = "reef"
			_sector_types[Vector2i(2, 4)] = "conduit"
			_sector_types[Vector2i(7, 3)] = "conduit"

		"marea_stage_3":
			# The Open Star Sea: 12x10 Colossal Oceanic Chart! (120 quadrants)
			# Central Maelstrom Vortex at cols 5-6, rows 4-5
			_sector_types[Vector2i(5, 4)] = "maelstrom"
			_sector_types[Vector2i(6, 4)] = "maelstrom"
			_sector_types[Vector2i(5, 5)] = "maelstrom"
			_sector_types[Vector2i(6, 5)] = "maelstrom"
			# 3 Converging high-speed wind currents
			for p in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)]:
				_sector_types[p] = "wind_stream"
			for p in [Vector2i(10, 1), Vector2i(9, 2), Vector2i(8, 3), Vector2i(7, 4)]:
				_sector_types[p] = "wind_stream"
			for y in range(6, 10):
				_sector_types[Vector2i(5, y)] = "wind_stream"
				_sector_types[Vector2i(6, y)] = "wind_stream"
			# 3 Navigational Beacon Buoys
			_sector_types[Vector2i(2, 7)] = "conduit"
			_sector_types[Vector2i(9, 7)] = "conduit"
			_sector_types[Vector2i(5, 1)] = "conduit"

		# --- ACERO EXPANSION (STAGES 4 - 12) ---
		"acero_stage_4":
			# Iron Gate Tertius: 8x12 narrow canyon, central sluice gate
			for y in range(grid_rows):
				_sector_types[Vector2i(0, y)] = "reef"
				_sector_types[Vector2i(7, y)] = "reef"
			_sector_types[Vector2i(3, 5)] = "sluice"
			_sector_types[Vector2i(4, 5)] = "sluice"
			for y in range(2, 10):
				_sector_types[Vector2i(3, y)] = "wind_stream"
				_sector_types[Vector2i(4, y)] = "wind_stream"
			_sector_types[Vector2i(2, 8)] = "conduit"
			_sector_types[Vector2i(5, 3)] = "conduit"

		"acero_stage_5":
			# Smuggler's Atoll: 11x9 hollow caldera reef
			for x in range(2, 9):
				_sector_types[Vector2i(x, 2)] = "reef"
				_sector_types[Vector2i(x, 6)] = "reef"
			_sector_types[Vector2i(2, 3)] = "reef"
			_sector_types[Vector2i(2, 5)] = "reef"
			_sector_types[Vector2i(8, 3)] = "reef"
			_sector_types[Vector2i(8, 5)] = "reef"
			_sector_types[Vector2i(5, 4)] = "spire"
			_sector_types[Vector2i(2, 4)] = "conduit"
			_sector_types[Vector2i(8, 4)] = "conduit"
			for p in [Vector2i(0, 4), Vector2i(1, 4), Vector2i(9, 4), Vector2i(10, 4)]:
				_sector_types[p] = "wind_stream"

		"acero_stage_6":
			# The Choir Intercept: 10x10 high-speed crosswinds
			for x in range(grid_cols):
				_sector_types[Vector2i(x, 4)] = "wind_stream"
				_sector_types[Vector2i(x, 5)] = "wind_stream"
			_sector_types[Vector2i(4, 4)] = "spire"
			_sector_types[Vector2i(5, 5)] = "spire"
			_sector_types[Vector2i(2, 2)] = "conduit"
			_sector_types[Vector2i(7, 7)] = "conduit"

		"acero_stage_7":
			# Operation Obsidian Anvil: 12x10 calm seeps escort
			for x in range(grid_cols):
				_sector_types[Vector2i(x, 0)] = "calm"
				_sector_types[Vector2i(x, 1)] = "calm"
			for y in range(2, 8):
				_sector_types[Vector2i(5, y)] = "wind_stream"
				_sector_types[Vector2i(6, y)] = "wind_stream"
			_sector_types[Vector2i(5, 8)] = "sluice"
			_sector_types[Vector2i(6, 8)] = "sluice"
			_sector_types[Vector2i(2, 5)] = "conduit"
			_sector_types[Vector2i(9, 5)] = "conduit"

		"acero_stage_8":
			# Ferro-Magnetic Reef: 9x9 sensor anomaly grid
			for p in [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(5, 4), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5)]:
				_sector_types[p] = "reef"
			_sector_types[Vector2i(4, 4)] = "conduit"
			for y in range(grid_rows):
				_sector_types[Vector2i(1, y)] = "wind_stream"
				_sector_types[Vector2i(7, y)] = "wind_stream"

		"acero_stage_9":
			# Assault on Maelstrom Station: 12x10
			_sector_types[Vector2i(5, 4)] = "maelstrom"
			_sector_types[Vector2i(6, 4)] = "maelstrom"
			_sector_types[Vector2i(5, 5)] = "spire"
			_sector_types[Vector2i(6, 5)] = "spire"
			for p in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(8, 6), Vector2i(9, 7)]:
				_sector_types[p] = "wind_stream"
			_sector_types[Vector2i(2, 7)] = "conduit"
			_sector_types[Vector2i(9, 2)] = "conduit"

		"acero_stage_10":
			# Duel with the Colossus: 12x8 open chasm
			_sector_types[Vector2i(3, 3)] = "spire"
			_sector_types[Vector2i(8, 3)] = "spire"
			_sector_types[Vector2i(5, 2)] = "ring"
			_sector_types[Vector2i(6, 2)] = "ring"
			for x in range(3, 9):
				_sector_types[Vector2i(x, 5)] = "wind_stream"

		"acero_stage_11":
			# The Dying Tide: 14x10 Great Sluice Dam
			for x in range(grid_cols):
				_sector_types[Vector2i(x, 0)] = "calm"
				_sector_types[Vector2i(x, 1)] = "calm"
				_sector_types[Vector2i(x, 5)] = "sluice"
			_sector_types[Vector2i(6, 5)] = "conduit"
			_sector_types[Vector2i(7, 5)] = "conduit"
			for y in range(6, 10):
				_sector_types[Vector2i(6, y)] = "wind_stream"
				_sector_types[Vector2i(7, y)] = "wind_stream"

		"acero_stage_12":
			# Apex of Steel: The Calm Citadel (14x12)
			for x in range(grid_cols):
				for y in range(3):
					_sector_types[Vector2i(x, y)] = "calm"
			_sector_types[Vector2i(6, 6)] = "sluice"
			_sector_types[Vector2i(7, 6)] = "sluice"
			_sector_types[Vector2i(6, 7)] = "ring"
			_sector_types[Vector2i(7, 7)] = "ring"
			for y in range(4, 12):
				_sector_types[Vector2i(3, y)] = "wind_stream"
				_sector_types[Vector2i(10, y)] = "wind_stream"
			_sector_types[Vector2i(3, 8)] = "conduit"
			_sector_types[Vector2i(10, 8)] = "conduit"

		# --- VINCULADOS EXPANSION (STAGES 4 - 12) ---
		"vinculados_stage_4":
			# Requiem of Outer Shrines: 10x9
			_sector_types[Vector2i(3, 3)] = "spire"
			_sector_types[Vector2i(6, 3)] = "spire"
			_sector_types[Vector2i(2, 6)] = "conduit"
			_sector_types[Vector2i(7, 6)] = "conduit"
			for p in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
				_sector_types[p] = "wind_stream"

		"vinculados_stage_5":
			# Awakening of Seraph-Prime: 12x9
			for x in range(grid_cols):
				_sector_types[Vector2i(x, 2)] = "calm"
			_sector_types[Vector2i(5, 5)] = "ring"
			_sector_types[Vector2i(6, 5)] = "ring"
			for y in range(3, 8):
				_sector_types[Vector2i(3, y)] = "wind_stream"
				_sector_types[Vector2i(8, y)] = "wind_stream"

		"vinculados_stage_6":
			# Symphony of 5-Voice Choir: 11x10
			for y in range(2, 8):
				_sector_types[Vector2i(2, y)] = "wind_stream"
				_sector_types[Vector2i(4, y)] = "wind_stream"
				_sector_types[Vector2i(6, y)] = "wind_stream"
				_sector_types[Vector2i(8, y)] = "wind_stream"
			_sector_types[Vector2i(5, 4)] = "spire"
			_sector_types[Vector2i(5, 5)] = "conduit"

		"vinculados_stage_7":
			# The Calm Abyss Trench: 8x12
			for y in range(grid_rows):
				_sector_types[Vector2i(0, y)] = "calm"
				_sector_types[Vector2i(1, y)] = "calm"
				_sector_types[Vector2i(6, y)] = "calm"
				_sector_types[Vector2i(7, y)] = "calm"
			for y in range(2, 10):
				_sector_types[Vector2i(3, y)] = "wind_stream"
				_sector_types[Vector2i(4, y)] = "wind_stream"
			_sector_types[Vector2i(3, 6)] = "conduit"
			_sector_types[Vector2i(4, 6)] = "conduit"

		"vinculados_stage_8":
			# Parley at the Astrolabe: 10x10
			_sector_types[Vector2i(4, 4)] = "ring"
			_sector_types[Vector2i(5, 4)] = "ring"
			_sector_types[Vector2i(4, 5)] = "conduit"
			_sector_types[Vector2i(5, 5)] = "conduit"
			for p in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(7, 7), Vector2i(8, 8)]:
				_sector_types[p] = "wind_stream"

		"vinculados_stage_9":
			# Shattering the Sluice Dam: 12x11
			for x in range(grid_cols):
				_sector_types[Vector2i(x, 4)] = "sluice"
			_sector_types[Vector2i(5, 4)] = "wind_stream"
			_sector_types[Vector2i(6, 4)] = "wind_stream"
			_sector_types[Vector2i(3, 7)] = "conduit"
			_sector_types[Vector2i(8, 7)] = "conduit"

		"vinculados_stage_10":
			# Clash of Titans: 12x10
			_sector_types[Vector2i(5, 4)] = "ring"
			_sector_types[Vector2i(6, 4)] = "ring"
			_sector_types[Vector2i(5, 5)] = "spire"
			_sector_types[Vector2i(6, 5)] = "spire"
			for p in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(8, 6), Vector2i(9, 7)]:
				_sector_types[p] = "wind_stream"

		"vinculados_stage_11":
			# The Calm Singularity: 12x12
			for x in range(grid_cols):
				_sector_types[Vector2i(x, 0)] = "calm"
				_sector_types[Vector2i(x, 1)] = "calm"
				_sector_types[Vector2i(x, 10)] = "calm"
				_sector_types[Vector2i(x, 11)] = "calm"
			_sector_types[Vector2i(5, 5)] = "ring"
			_sector_types[Vector2i(6, 5)] = "ring"
			_sector_types[Vector2i(5, 6)] = "conduit"
			_sector_types[Vector2i(6, 6)] = "conduit"

		"vinculados_stage_12":
			# Symphony of the Star Sea: 16x12 Transcendence Gateway
			for x in range(6, 10):
				_sector_types[Vector2i(x, 5)] = "ring"
				_sector_types[Vector2i(x, 6)] = "ring"
			for x in range(grid_cols):
				_sector_types[Vector2i(x, 0)] = "calm"
			for y in range(2, 10):
				_sector_types[Vector2i(3, y)] = "wind_stream"
				_sector_types[Vector2i(12, y)] = "wind_stream"
			_sector_types[Vector2i(3, 8)] = "conduit"
			_sector_types[Vector2i(12, 8)] = "conduit"

		# --- MAREA LIBRE EXPANSION (STAGES 4 - 12) ---
		"marea_stage_4":
			# The Free Trader Convoy: 10x9
			for y in range(2, 7):
				_sector_types[Vector2i(2, y)] = "reef"
				_sector_types[Vector2i(7, y)] = "reef"
			for y in range(1, 8):
				_sector_types[Vector2i(4, y)] = "wind_stream"
				_sector_types[Vector2i(5, y)] = "wind_stream"
			_sector_types[Vector2i(4, 7)] = "conduit"
			_sector_types[Vector2i(5, 7)] = "conduit"

		"marea_stage_5":
			# Prize of the Soberano: 11x9
			_sector_types[Vector2i(5, 4)] = "spire"
			for x in range(3, 8):
				_sector_types[Vector2i(x, 2)] = "reef"
				_sector_types[Vector2i(x, 6)] = "reef"
			for p in [Vector2i(1, 4), Vector2i(2, 4), Vector2i(8, 4), Vector2i(9, 4)]:
				_sector_types[p] = "wind_stream"
			_sector_types[Vector2i(1, 2)] = "conduit"
			_sector_types[Vector2i(9, 6)] = "conduit"

		"marea_stage_6":
			# The Dead Reef Ambush: 9x11
			for y in range(grid_rows):
				if y % 2 == 0:
					_sector_types[Vector2i(2, y)] = "reef"
					_sector_types[Vector2i(6, y)] = "reef"
			for y in range(2, 9):
				_sector_types[Vector2i(4, y)] = "wind_stream"
			_sector_types[Vector2i(4, 5)] = "conduit"

		"marea_stage_7":
			# Siege of Fort Almirante: 10x10
			_sector_types[Vector2i(4, 2)] = "sluice"
			_sector_types[Vector2i(5, 2)] = "sluice"
			for x in range(2, 8):
				_sector_types[Vector2i(x, 3)] = "reef"
			for y in range(4, 9):
				_sector_types[Vector2i(4, y)] = "wind_stream"
				_sector_types[Vector2i(5, y)] = "wind_stream"
			_sector_types[Vector2i(2, 7)] = "conduit"
			_sector_types[Vector2i(7, 7)] = "conduit"

		"marea_stage_8":
			# The Ghost Flotilla: 12x9
			_sector_types[Vector2i(5, 4)] = "spire"
			_sector_types[Vector2i(6, 4)] = "spire"
			for p in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(8, 5), Vector2i(9, 6)]:
				_sector_types[p] = "wind_stream"
			_sector_types[Vector2i(3, 6)] = "conduit"
			_sector_types[Vector2i(8, 2)] = "conduit"

		"marea_stage_9":
			# The Triple Confluence: 13x10
			_sector_types[Vector2i(6, 4)] = "conduit"
			_sector_types[Vector2i(6, 5)] = "conduit"
			for x in range(1, 6):
				_sector_types[Vector2i(x, 2)] = "wind_stream"
			for x in range(7, 12):
				_sector_types[Vector2i(x, 2)] = "wind_stream"
			for y in range(5, 10):
				_sector_types[Vector2i(6, y)] = "wind_stream"

		"marea_stage_10":
			# Breaking the Iron Citadel: 12x11
			for x in range(3, 9):
				_sector_types[Vector2i(x, 2)] = "sluice"
				_sector_types[Vector2i(x, 3)] = "reef"
			_sector_types[Vector2i(5, 3)] = "wind_stream"
			_sector_types[Vector2i(6, 3)] = "wind_stream"
			for y in range(4, 10):
				_sector_types[Vector2i(5, y)] = "wind_stream"
				_sector_types[Vector2i(6, y)] = "wind_stream"

		"marea_stage_11":
			# Eye of Chaos: 14x11 Maelstrom
			_sector_types[Vector2i(6, 5)] = "maelstrom"
			_sector_types[Vector2i(7, 5)] = "maelstrom"
			for p in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(10, 7), Vector2i(11, 8)]:
				_sector_types[p] = "wind_stream"
			_sector_types[Vector2i(3, 8)] = "conduit"
			_sector_types[Vector2i(10, 2)] = "conduit"

		"marea_stage_12":
			# The Sovereign Ocean: 16x12
			_sector_types[Vector2i(7, 5)] = "ring"
			_sector_types[Vector2i(8, 5)] = "ring"
			for y in range(2, 10):
				_sector_types[Vector2i(4, y)] = "wind_stream"
				_sector_types[Vector2i(11, y)] = "wind_stream"
			_sector_types[Vector2i(4, 9)] = "conduit"
			_sector_types[Vector2i(11, 9)] = "conduit"

		_:
			# Fallback default
			for p in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 3), Vector2i(5, 3), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 5), Vector2i(7, 5), Vector2i(8, 6)]:
				_sector_types[p] = "wind_stream"
			for y in range(2, 6):
				_sector_types[Vector2i(0, y)] = "reef"
				_sector_types[Vector2i(9, y)] = "reef"
			_sector_types[Vector2i(4, 6)] = "sluice"
			_sector_types[Vector2i(2, 4)] = "conduit"


	return _sector_types
