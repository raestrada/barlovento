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

static func world_to_cell(pos: Vector3, _is_player: bool, _idx: int, grid_cols: int, grid_rows: int) -> Vector2i:
	var nx := clampf((pos.x + 65.0) / 130.0, 0.0, 0.999)
	var ny := clampf((pos.z + 75.0) / 150.0, 0.0, 0.999)
	return Vector2i(int(nx * float(grid_cols)), int(ny * float(grid_rows)))

static func cell_to_world(cell: Vector2i, facing: Vector2, is_player: bool, idx: int, grid_cols: int, grid_rows: int) -> Dictionary:
	var cx := (float(cell.x) + 0.5) / float(grid_cols) * 130.0 - 65.0
	var cz := (float(cell.y) + 0.5) / float(grid_rows) * 150.0 - 75.0
	var slot_offsets := [
		Vector3(0.0, 4.0, 0.0),
		Vector3(12.0, 2.0, 6.0),
		Vector3(-12.0, 6.0, 6.0)
	]
	var off: Vector3 = slot_offsets[clampi(idx, 0, 2)]
	if not is_player:
		off = Vector3(-off.x, off.y, -off.z)

	var base_pos := Vector3(cx, 0.0, cz) + off
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
		"velocity": out_vel,
		"forward": target_fwd,
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

static func plan_ai_chart_orders(enemy_ships: Array, e_cells: Array, p_cells: Array, grid_cols: int, grid_rows: int, e_targets: Array) -> void:
	var claimed: Array[Vector2i] = []
	for i in range(3):
		var cur := _e_cells[i]
		var target_p := _p_cells[mini(i, _p_cells.size() - 1)]
		var best := cur
		var best_score := -INF
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var cand := Vector2i(clampi(cur.x + ox, 0, grid_cols - 1), clampi(cur.y + oy, 0, grid_rows - 1))
				if claimed.has(cand):
					continue
				var score := 0.0
				var dist_to_target := Vector2(cand - target_p).length()
				score += (14.0 - dist_to_target) * 1.1

				# Hazard avoidance: stay far out of The Calm!
				if _sector_types.get(cand, "") == "calm":
					score -= 75.0

				# Contest Éther Conduits (+1 AP reward)
				if _sector_types.get(cand, "") == "conduit":
					score += 5.5

				# Contest Barlovento Wind Stream (+Hit & Damage)
				if _sector_types.get(cand, "") == "wind_stream":
					score += 4.0

				# Flanking reefs cover
				if _sector_types.get(cand, "") == "reef":
					score += 2.2

				# Bias against idling unless holding a strategic conduit
				if cand == cur and _sector_types.get(cur, "") != "conduit":
					score -= 3.0

				if score > best_score:
					best_score = score
					best = cand

		claimed.append(best)
		_e_targets[i] = best
		var dv := Vector2(best - cur)
		if dv.length_squared() > 0.01:
			_e_facing[i] = dv.normalized()


static func apply_formation_preset(active_formation: int, p_cells: Array, grid_cols: int, grid_rows: int, p_targets: Array) -> void:
	var center_c := _p_cells[0]
	match current_formation:
		Formation.LINE_OF_BATTLE:
			var target_row := maxi(center_c.y - 1, 0)
			_p_targets[0] = Vector2i(clampi(center_c.x, 1, grid_cols - 2), target_row)
			_p_targets[1] = Vector2i(clampi(_p_targets[0].x - 1, 0, grid_cols - 1), target_row)
			_p_targets[2] = Vector2i(clampi(_p_targets[0].x + 1, 0, grid_cols - 1), target_row)
		Formation.SPEARHEAD_WEDGE:
			var lead_row := maxi(center_c.y - 2, 0)
			_p_targets[0] = Vector2i(clampi(center_c.x, 1, grid_cols - 2), lead_row)
			_p_targets[1] = Vector2i(clampi(_p_targets[0].x - 1, 0, grid_cols - 1), mini(lead_row + 1, grid_rows - 1))
			_p_targets[2] = Vector2i(clampi(_p_targets[0].x + 1, 0, grid_cols - 1), mini(lead_row + 1, grid_rows - 1))
		Formation.FLANKING_PINCER:
			var pincer_row := maxi(center_c.y - 1, 0)
			_p_targets[0] = Vector2i(clampi(center_c.x, 2, grid_cols - 3), pincer_row)
			_p_targets[1] = Vector2i(clampi(_p_targets[0].x - 2, 0, grid_cols - 1), maxi(pincer_row - 1, 0))
			_p_targets[2] = Vector2i(clampi(_p_targets[0].x + 2, 0, grid_cols - 1), maxi(pincer_row - 1, 0))

	for i in range(3):
		var dv := Vector2(_p_targets[i] - _p_cells[i])
		if dv.length_squared() > 0.01:
			_p_facing[i] = dv.normalized()


static func compute_strategic_bonuses(p_targets: Array, p_cells: Array, is_animating_turn: bool, _sector_types: Dictionary, enemy_ships: Array, _e_cells: Array) -> Dictionary:
	var wind_cells_held := 0
	var sluice_held := 0
	var conduit_held := 0
	var reef_held := 0
	for i in range(3):
		var c := _p_targets[i] if not is_animating_turn else _p_cells[i]
		var stype: String = _sector_types.get(c, "")
		if stype == "wind_stream":
			wind_cells_held += 1
		elif stype == "sluice":
			sluice_held += 1
		elif stype == "conduit":
			conduit_held += 1
		elif stype == "reef":
			reef_held += 1

	var enemy_wind_cells := 0
	var enemy_conduit_held := 0
	for i in range(3):
		if i < enemy_ships.size() and enemy_ships[i] != null and enemy_ships[i].is_destroyed():
			continue
		var est: String = _sector_types.get(_e_cells[i], "")
		if est == "wind_stream":
			enemy_wind_cells += 1
		elif est == "conduit":
			enemy_conduit_held += 1

	var has_barlovento := (wind_cells_held >= 1 and wind_cells_held > enemy_wind_cells)
	var enemy_barlovento := (enemy_wind_cells >= 1 and enemy_wind_cells > wind_cells_held)

	var min_px := 99
	var max_px := -99
	var avg_py := 0.0
	for i in range(3):
		var c := _p_targets[i] if not is_animating_turn else _p_cells[i]
		min_px = mini(min_px, c.x)
		max_px = maxi(max_px, c.x)
		avg_py += float(c.y)
	avg_py /= 3.0

	var avg_ex := 0.0
	var avg_ey := 0.0
	for i in range(3):
		var ec := _e_cells[i]
		avg_ex += float(ec.x)
		avg_ey += float(ec.y)
	avg_ex /= 3.0
	avg_ey /= 3.0

	var spread_span := max_px - min_px
	var is_flanking := (spread_span >= 4) or (avg_py <= avg_ey + 0.5) or (current_formation == Formation.FLANKING_PINCER)
	var is_crossing_t := (current_formation == Formation.LINE_OF_BATTLE and wind_cells_held >= 2)

	var calm_hazard_count := 0
	for i in range(3):
		var c := _p_targets[i] if not is_animating_turn else _p_cells[i]
		if _sector_types.get(c, "") == "calm":
			calm_hazard_count += 1

	var bonus_ap: int = (1 if has_barlovento else 0) + (1 if conduit_held > 0 else 0)

	return {
		"has_barlovento": has_barlovento,
		"enemy_barlovento": enemy_barlovento,
		"enemy_wind_cells": enemy_wind_cells,
		"wind_cells_held": wind_cells_held,
		"sluice_held": sluice_held > 0,
		"conduit_held": conduit_held > 0,
		"reef_held": reef_held > 0,
		"enemy_conduit_held": enemy_conduit_held > 0,
		"calm_hazard_count": calm_hazard_count,
		"is_flanking": is_flanking,
		"is_crossing_t": is_crossing_t,
		"formation": current_formation,
		"bonus_ap": bonus_ap,
		"accuracy_bonus": 0.15 if has_barlovento else 0.0,
		"damage_bonus": 0.15 if (has_barlovento or is_crossing_t) else 0.0,
		"crit_bonus": 0.25 if reef_held > 0 else 0.0,
		"armor_mult": 1.20 if current_formation == Formation.LINE_OF_BATTLE else 1.0,
		"speed_mult": (1.25 if current_formation == Formation.SPEARHEAD_WEDGE else 1.0) * (1.15 if conduit_held > 0 else 1.0),
		"turn_mult": 1.15 if current_formation == Formation.FLANKING_PINCER else 1.0
	}


