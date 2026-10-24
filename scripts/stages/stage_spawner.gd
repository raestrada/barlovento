class_name StageSpawner
extends RefCounted

var world: Node3D
var ether: EtherField
var click_cb: Callable
var right_click_cb: Callable
var stage_id: String = ""
var _player_ships: Array[Ship] = []
var _enemy_ships: Array[Ship] = []
const PITCH_LIMIT := 1.15

static func spawn_stage(stage_id: String, world_node: Node3D, ether_field: EtherField, clicked_handler: Callable, right_clicked_handler: Callable) -> Dictionary:
	var spawner := StageSpawner.new()
	spawner.world = world_node
	spawner.ether = ether_field
	spawner.click_cb = clicked_handler
	spawner.right_click_cb = right_clicked_handler
	spawner.stage_id = stage_id
	LoreDB.current_stage_id = stage_id
	spawner._spawn_fleets()
	return {
		"player_ships": spawner._player_ships,
		"enemy_ships": spawner._enemy_ships
	}

func _apply_tutorial_handicap(s: Ship, hp_mult: float = 0.65, dmg_mult: float = 0.70) -> void:
	s.hp = roundf(s.hp * hp_mult)
	s.max_hp = s.hp
	s.max_shield_hp = roundf(s.max_shield_hp * hp_mult)
	s.shield_hp = s.max_shield_hp
	s.weapon_damage = roundf(s.weapon_damage * dmg_mult)
	s.set_meta("tutorial_enemy", true)

func _spawn_fleets() -> void:
	var sid := stage_id if stage_id != "" else LoreDB.current_stage_id
	match sid:
		"acero_stage_1":
			# ACT I // STAGE 01 [TUTORIAL]: Defense of Sluice Station Well-09
			# ACERO DOCTRINE: Fortified V-Wedge Line holding the rear Sluice against fast flanking raiders
			# Dreadnought center anchor, Battlecruiser starboard wedge, Corvette port screen
			_player_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 4.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, 0.0, 0.0), 3.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(14.0, 3.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, -15.0, 0.0), 4.0))
			_player_ships.append(_spawn("acero_corvette", Vector3(-14.0, 5.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, 15.0, 0.0), 5.0))

			# Hostiles: Fast corsairs attacking from two distinct flanking vectors (not head-on!)
			# West Reef Flanker:
			var e1 := _spawn("marea_raider", Vector3(-42.0, 4.0, -38.0), Vector3(1.8, 0.0, 3.8), 1, Vector3(0.0, 155.0, 0.0))
			_apply_tutorial_handicap(e1, 0.65, 0.70)
			_enemy_ships.append(e1)
			var e2 := _spawn("marea_brigantine", Vector3(-50.0, 6.0, -44.0), Vector3(1.6, 0.0, 4.0), 1, Vector3(0.0, 155.0, 0.0))
			_apply_tutorial_handicap(e2, 0.65, 0.70)
			_enemy_ships.append(e2)
			# East Ambush Cutter darting in from asteroid shadow:
			var e3 := _spawn("marea_cutter", Vector3(38.0, 2.0, -32.0), Vector3(-2.2, 0.0, 4.8), 1, Vector3(0.0, -150.0, 0.0))
			_apply_tutorial_handicap(e3, 0.65, 0.70)
			_enemy_ships.append(e3)

		"acero_stage_2":
			# ACT I // STAGE 02: Ambush at the Resonance Spire
			# ACERO DOCTRINE: Methodical Line Abreast advancing toward the Spire against elusive mechas
			_player_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 4.0, 52.0), Vector3.ZERO, 0, Vector3.ZERO, 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(16.0, 5.0, 52.0), Vector3.ZERO, 0, Vector3.ZERO, 5.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-16.0, 5.0, 52.0), Vector3.ZERO, 0, Vector3.ZERO, 5.5))
			_player_ships.append(_spawn("acero_lancer", Vector3(30.0, 3.0, 56.0), Vector3.ZERO, 0, Vector3(0.0, -10.0, 0.0), 7.0))

			# Hostiles: Vinculados choir dropping from high crystal canopy in dynamic weave
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(25.0, 8.0, -55.0), Vector3(-0.8, 0.0, 3.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(10.0, 14.0, -48.0), Vector3(-1.4, -0.5, 4.2), 1, Vector3(-10.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(-15.0, 12.0, -48.0), Vector3(1.2, -0.5, 4.5), 1, Vector3(-10.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(-32.0, 16.0, -42.0), Vector3(2.2, -0.8, 5.0), 1, Vector3(-15.0, 150.0, 0.0)))

		"acero_stage_3":
			# ACT I // STAGE 03: The Calm Threshold
			# ACERO DOCTRINE: Fortified perimeter holding the void edge against desperate fleeing corsairs
			_player_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 5.0, 56.0), Vector3.ZERO, 0, Vector3.ZERO, 4.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-14.0, 3.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, 10.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(14.0, 7.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, -10.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_corvette", Vector3(26.0, 4.0, 50.0), Vector3.ZERO, 0, Vector3(0.0, -20.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(-26.0, 2.0, 50.0), Vector3.ZERO, 0, Vector3(0.0, 20.0, 0.0), 7.0))

			var boss_gal := _spawn("marea_galleon", Vector3(0.0, 6.0, -56.0), Vector3(0.0, 0.0, 3.8), 1, Vector3(0.0, 180.0, 0.0))
			boss_gal.hp = roundf(boss_gal.hp * 1.20)
			boss_gal.max_hp = boss_gal.hp
			_enemy_ships.append(boss_gal)
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(-18.0, 8.0, -52.0), Vector3(0.8, 0.0, 4.2), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(18.0, 3.0, -52.0), Vector3(-0.8, 0.0, 4.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(-35.0, 2.0, -46.0), Vector3(1.8, 0.0, 4.6), 1, Vector3(0.0, 155.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(35.0, 6.0, -46.0), Vector3(-1.8, 0.0, 5.0), 1, Vector3(0.0, -155.0, 0.0)))

		"acero_stage_4":
			# ACT I // STAGE 04: Crucible of Fire
			# ACERO DOCTRINE: Siege Monitor artillery deployment in narrow basalt gorge
			_player_ships.append(_spawn("acero_monitor", Vector3(0.0, 8.0, 58.0), Vector3.ZERO, 0, Vector3.ZERO, 3.0))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-12.0, 4.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, 10.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(12.0, 4.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, -10.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_corvette", Vector3(-24.0, 2.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, 25.0, 0.0), 6.5))
			_player_ships.append(_spawn("acero_lancer", Vector3(24.0, 6.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, -25.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(34.0, 2.0, 44.0), Vector3.ZERO, 0, Vector3(0.0, -30.0, 0.0), 7.0))

			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 6.0, -60.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_aegis", Vector3(-16.0, 3.0, -55.0), Vector3(0.5, 0.0, 3.2), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(16.0, 8.0, -52.0), Vector3(-0.8, 0.0, 4.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(-30.0, 6.0, -46.0), Vector3(1.5, 0.0, 4.5), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(30.0, 2.0, -46.0), Vector3(-1.5, 0.0, 4.8), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_psyche", Vector3(0.0, 14.0, -48.0), Vector3(0.0, 0.0, 4.2), 1, Vector3(0.0, 180.0, 0.0)))

		"acero_stage_5":
			# ACT II // STAGE 05: Corsair Haven Fortress Assault
			# Center Siege Division + Starboard Flank Screening Wing
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-4.0, 4.0, 58.0), Vector3.ZERO, 0, Vector3.ZERO, 4.0))
			_player_ships.append(_spawn("acero_monitor", Vector3(8.0, 6.0, 56.0), Vector3.ZERO, 0, Vector3.ZERO, 3.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-18.0, 2.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, 12.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_corvette", Vector3(-28.0, 5.0, 50.0), Vector3.ZERO, 0, Vector3(0.0, 20.0, 0.0), 6.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(26.0, 3.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, -15.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(38.0, 7.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, -25.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_corvette", Vector3(46.0, 1.0, 46.0), Vector3.ZERO, 0, Vector3(0.0, -25.0, 0.0), 7.0))

			_enemy_ships.append(_spawn("marea_galleon", Vector3(0.0, 6.0, -62.0), Vector3(0.0, 0.0, 3.2), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(-14.0, 4.0, -64.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(14.0, 8.0, -60.0), Vector3(0.0, 0.0, 3.6), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(-28.0, 2.0, -54.0), Vector3(0.8, 0.0, 4.2), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(28.0, 5.0, -54.0), Vector3(-0.8, 0.0, 4.5), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(-42.0, 7.0, -48.0), Vector3(1.5, 0.0, 4.6), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(38.0, 1.0, -48.0), Vector3(-1.2, 0.0, 5.0), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(48.0, 6.0, -44.0), Vector3(-1.8, 0.0, 5.2), 1, Vector3(0.0, -155.0, 0.0)))

		"acero_stage_6":
			# ACT II // STAGE 06: Bastion Wall Defense (Open Void Dogfight)
			# Carrier Forge-01 deploying flak screen with 8 ships in twin battle echelons
			_player_ships.append(_spawn("acero_carrier", Vector3(0.0, 2.0, 64.0), Vector3.ZERO, 0, Vector3.ZERO, 3.0))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-12.0, 6.0, 56.0), Vector3.ZERO, 0, Vector3(0.0, 8.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(12.0, 4.0, 56.0), Vector3.ZERO, 0, Vector3(0.0, -8.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-24.0, 2.0, 50.0), Vector3.ZERO, 0, Vector3(0.0, 15.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_monitor", Vector3(24.0, 8.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, -10.0, 0.0), 4.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(-36.0, 5.0, 46.0), Vector3.ZERO, 0, Vector3(0.0, 25.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(36.0, 3.0, 46.0), Vector3.ZERO, 0, Vector3(0.0, -25.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_corvette", Vector3(0.0, 10.0, 48.0), Vector3.ZERO, 0, Vector3.ZERO, 6.5))

			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 6.0, -66.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(18.0, 3.0, -62.0), Vector3(0.0, 0.0, 3.2), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(-18.0, 8.0, -56.0), Vector3(0.8, 0.0, 4.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(30.0, 5.0, -52.0), Vector3(-1.0, 0.0, 4.0), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(-30.0, 2.0, -50.0), Vector3(1.2, 0.0, 4.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(40.0, 7.0, -46.0), Vector3(-1.6, 0.0, 4.8), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_psyche", Vector3(-42.0, 4.0, -46.0), Vector3(1.6, 0.0, 4.2), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_chorus", Vector3(0.0, 12.0, -50.0), Vector3(0.0, 0.0, 4.4), 1, Vector3(0.0, 180.0, 0.0)))

		"acero_stage_7":
			# ACT II // STAGE 07: Iron Dam Bastion Defense
			# Rear Garrison defending Dam foundations + Forward Battleline meeting 2 Pincer Wings
			_player_ships.append(_spawn("acero_monitor", Vector3(0.0, 8.0, 70.0), Vector3.ZERO, 0, Vector3.ZERO, 2.5))
			_player_ships.append(_spawn("acero_corvette", Vector3(-14.0, 6.0, 68.0), Vector3.ZERO, 0, Vector3(0.0, 15.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_corvette", Vector3(14.0, 6.0, 68.0), Vector3.ZERO, 0, Vector3(0.0, -15.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-8.0, 4.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, 5.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_carrier", Vector3(8.0, 2.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, -5.0, 0.0), 3.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-24.0, 5.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, 18.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(24.0, 3.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, -18.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(-38.0, 7.0, 44.0), Vector3.ZERO, 0, Vector3(0.0, 30.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(38.0, 1.0, 44.0), Vector3.ZERO, 0, Vector3(0.0, -30.0, 0.0), 7.0))

			_enemy_ships.append(_spawn("marea_galleon", Vector3(-25.0, 5.0, -58.0), Vector3(1.0, 0.0, 3.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(-38.0, 3.0, -52.0), Vector3(1.2, 0.0, 3.8), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(-50.0, 7.0, -46.0), Vector3(1.8, 0.0, 4.5), 1, Vector3(0.0, 150.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(-15.0, 1.0, -50.0), Vector3(0.8, 0.0, 4.8), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(22.0, 6.0, -64.0), Vector3(-1.0, 0.0, 3.2), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(12.0, 4.0, -66.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(36.0, 8.0, -54.0), Vector3(-1.2, 0.0, 4.0), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(48.0, 2.0, -48.0), Vector3(-1.6, 0.0, 4.2), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(30.0, 9.0, -44.0), Vector3(-1.2, 0.0, 5.0), 1, Vector3(0.0, -165.0, 0.0)))

		"acero_stage_8":
			# ACT II // STAGE 08: Smelter Vulcan-3 Retaking
			# Juggernaut Imperator leading industrial assault
			_player_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, 60.0), Vector3.ZERO, 0, Vector3.ZERO, 3.5))
			_player_ships.append(_spawn("acero_carrier", Vector3(-15.0, 2.0, 58.0), Vector3.ZERO, 0, Vector3(0.0, 8.0, 0.0), 3.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(16.0, 4.0, 56.0), Vector3.ZERO, 0, Vector3(0.0, -8.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-30.0, 8.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, 15.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(30.0, 3.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, -15.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_monitor", Vector3(0.0, 12.0, 50.0), Vector3.ZERO, 0, Vector3.ZERO, 3.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(-40.0, 5.0, 46.0), Vector3.ZERO, 0, Vector3(0.0, 25.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(40.0, 7.0, 46.0), Vector3.ZERO, 0, Vector3(0.0, -25.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_corvette", Vector3(0.0, -4.0, 48.0), Vector3.ZERO, 0, Vector3.ZERO, 6.5))

			_enemy_ships.append(_spawn("marea_leviathan", Vector3(35.0, 4.0, -66.0), Vector3(-0.8, 0.0, 3.0), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(20.0, 6.0, -60.0), Vector3(-0.5, 0.0, 3.5), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(45.0, 2.0, -62.0), Vector3(-1.0, 0.0, 3.2), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(10.0, 8.0, -56.0), Vector3(0.0, 0.0, 3.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(28.0, 5.0, -52.0), Vector3(-0.8, 0.0, 4.2), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(-30.0, 6.0, -64.0), Vector3(0.8, 0.0, 3.2), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(-18.0, 3.0, -58.0), Vector3(0.5, 0.0, 3.4), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(-42.0, 8.0, -52.0), Vector3(1.2, 0.0, 4.0), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(-25.0, 2.0, -48.0), Vector3(0.8, 0.0, 4.5), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(0.0, 10.0, -50.0), Vector3(0.0, 0.0, 5.0), 1, Vector3(0.0, 180.0, 0.0)))

		"acero_stage_9":
			# ACT III // STAGE 09: The Grand Iron Wall
			# 11 Acero heavy ships in 3 divisions: Center Wall, Port Strike, Starboard Screen
			_player_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, 64.0), Vector3.ZERO, 0, Vector3.ZERO, 3.5))
			_player_ships.append(_spawn("acero_carrier", Vector3(-14.0, 2.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, 6.0, 0.0), 3.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(14.0, 4.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, -6.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_monitor", Vector3(0.0, 12.0, 58.0), Vector3.ZERO, 0, Vector3.ZERO, 3.0))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-32.0, 5.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, 12.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-44.0, 3.0, 50.0), Vector3.ZERO, 0, Vector3(0.0, 18.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(-54.0, 7.0, 46.0), Vector3.ZERO, 0, Vector3(0.0, 28.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_corvette", Vector3(-38.0, -2.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, 15.0, 0.0), 6.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(32.0, 5.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, -12.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(44.0, 2.0, 50.0), Vector3.ZERO, 0, Vector3(0.0, -18.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(54.0, 6.0, 46.0), Vector3.ZERO, 0, Vector3(0.0, -28.0, 0.0), 7.0))

			_enemy_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, -66.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(-16.0, 4.0, -62.0), Vector3(0.5, 0.0, 3.4), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(16.0, 5.0, -62.0), Vector3(-0.5, 0.0, 3.4), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(0.0, 14.0, -60.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(-30.0, 2.0, -56.0), Vector3(1.0, 0.0, 3.8), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(30.0, 7.0, -56.0), Vector3(-1.0, 0.0, 3.8), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(-40.0, 6.0, -52.0), Vector3(1.2, 0.0, 4.2), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(40.0, 3.0, -52.0), Vector3(-1.2, 0.0, 4.2), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(-50.0, 4.0, -48.0), Vector3(1.5, 0.0, 4.5), 1, Vector3(0.0, 155.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(50.0, 8.0, -48.0), Vector3(-1.5, 0.0, 4.5), 1, Vector3(0.0, -155.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(-20.0, 10.0, -46.0), Vector3(0.8, 0.0, 5.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(20.0, 1.0, -46.0), Vector3(-0.8, 0.0, 5.0), 1, Vector3(0.0, -170.0, 0.0)))

		"acero_stage_10":
			# ACT III // STAGE 10: Duel with the Seraph (12 Acero vs 13 Vinculados)
			_player_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, 65.0), Vector3.ZERO, 0, Vector3.ZERO, 3.5))
			_player_ships.append(_spawn("acero_carrier", Vector3(-14.0, 2.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, 6.0, 0.0), 3.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(14.0, 4.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, -6.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-28.0, 6.0, 58.0), Vector3.ZERO, 0, Vector3(0.0, 12.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_monitor", Vector3(28.0, 8.0, 58.0), Vector3.ZERO, 0, Vector3(0.0, -12.0, 0.0), 3.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-40.0, 3.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, 18.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(40.0, 5.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, -18.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(-50.0, 7.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, 25.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(-58.0, 2.0, 46.0), Vector3.ZERO, 0, Vector3(0.0, 30.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(50.0, 6.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, -25.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_corvette", Vector3(0.0, 12.0, 52.0), Vector3.ZERO, 0, Vector3.ZERO, 6.5))
			_player_ships.append(_spawn("acero_corvette", Vector3(58.0, 1.0, 46.0), Vector3.ZERO, 0, Vector3(0.0, -30.0, 0.0), 6.5))

			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 8.0, -68.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_aegis", Vector3(-18.0, 4.0, -64.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(18.0, 6.0, -64.0), Vector3(-0.5, 0.0, 3.2), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(-32.0, 2.0, -60.0), Vector3(0.8, 0.0, 3.2), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(32.0, 8.0, -56.0), Vector3(-1.0, 0.0, 4.0), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(-44.0, 5.0, -52.0), Vector3(1.2, 0.0, 4.0), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(44.0, 3.0, -52.0), Vector3(-1.2, 0.0, 4.0), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(-10.0, 12.0, -50.0), Vector3(0.0, 0.0, 4.5), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(10.0, 12.0, -50.0), Vector3(0.0, 0.0, 4.5), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(-55.0, 4.0, -46.0), Vector3(1.8, 0.0, 4.8), 1, Vector3(0.0, 150.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(55.0, 7.0, -46.0), Vector3(-1.8, 0.0, 4.8), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_psyche", Vector3(-25.0, 10.0, -48.0), Vector3(0.8, 0.0, 4.2), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_chorus", Vector3(25.0, 10.0, -48.0), Vector3(-0.8, 0.0, 4.4), 1, Vector3(0.0, -170.0, 0.0)))

		"acero_stage_11":
			# ACT III // STAGE 11: Juggernaut Imperator Stand (13 Acero vs 14 Grand Corsair Line)
			_player_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, 66.0), Vector3.ZERO, 0, Vector3.ZERO, 3.5))
			_player_ships.append(_spawn("acero_carrier", Vector3(-15.0, 2.0, 64.0), Vector3.ZERO, 0, Vector3(0.0, 6.0, 0.0), 3.5))
			_player_ships.append(_spawn("acero_carrier", Vector3(15.0, 4.0, 64.0), Vector3.ZERO, 0, Vector3(0.0, -6.0, 0.0), 3.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-30.0, 6.0, 60.0), Vector3.ZERO, 0, Vector3(0.0, 12.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(30.0, 6.0, 60.0), Vector3.ZERO, 0, Vector3(0.0, -12.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 14.0, 58.0), Vector3.ZERO, 0, Vector3.ZERO, 4.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-42.0, 3.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, 18.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(42.0, 5.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, -18.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-18.0, -2.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, 8.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_monitor", Vector3(18.0, 10.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, -8.0, 0.0), 3.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(-52.0, 7.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, 28.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(52.0, 2.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, -28.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_corvette", Vector3(0.0, -4.0, 50.0), Vector3.ZERO, 0, Vector3.ZERO, 6.5))

			_enemy_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, -68.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(-20.0, 4.0, -65.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(20.0, 8.0, -64.0), Vector3(-0.5, 0.0, 3.4), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(-36.0, 3.0, -60.0), Vector3(1.0, 0.0, 3.4), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(36.0, 6.0, -60.0), Vector3(-1.0, 0.0, 3.0), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(-12.0, 12.0, -56.0), Vector3(0.0, 0.0, 3.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(12.0, 2.0, -56.0), Vector3(0.0, 0.0, 3.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(-48.0, 7.0, -52.0), Vector3(1.4, 0.0, 4.2), 1, Vector3(0.0, 155.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(48.0, 3.0, -52.0), Vector3(-1.4, 0.0, 4.2), 1, Vector3(0.0, -155.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(-58.0, 4.0, -48.0), Vector3(1.8, 0.0, 4.5), 1, Vector3(0.0, 150.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(58.0, 8.0, -48.0), Vector3(-1.8, 0.0, 4.5), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(-25.0, 9.0, -46.0), Vector3(0.8, 0.0, 5.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(25.0, 1.0, -46.0), Vector3(-0.8, 0.0, 5.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(0.0, 14.0, -44.0), Vector3(0.0, 0.0, 5.2), 1, Vector3(0.0, 180.0, 0.0)))

		"acero_stage_12":
			# ACT III // STAGE 12: Apex of Steel // Calm Citadel Climax (15 Acero vs 16 Supreme Armada)
			_player_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, 68.0), Vector3.ZERO, 0, Vector3.ZERO, 3.5))
			_player_ships.append(_spawn("acero_carrier", Vector3(-14.0, 2.0, 66.0), Vector3.ZERO, 0, Vector3(0.0, 5.0, 0.0), 3.5))
			_player_ships.append(_spawn("acero_carrier", Vector3(14.0, 4.0, 66.0), Vector3.ZERO, 0, Vector3(0.0, -5.0, 0.0), 3.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-26.0, 6.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, 10.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(26.0, 6.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, -10.0, 0.0), 4.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 14.0, 60.0), Vector3.ZERO, 0, Vector3.ZERO, 4.5))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(0.0, -4.0, 60.0), Vector3.ZERO, 0, Vector3.ZERO, 4.5))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-40.0, 4.0, 56.0), Vector3.ZERO, 0, Vector3(0.0, 15.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(40.0, 4.0, 56.0), Vector3.ZERO, 0, Vector3(0.0, -15.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-50.0, 2.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, 22.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(50.0, 8.0, 52.0), Vector3.ZERO, 0, Vector3(0.0, -22.0, 0.0), 5.0))
			_player_ships.append(_spawn("acero_monitor", Vector3(-18.0, 10.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, 8.0, 0.0), 3.0))
			_player_ships.append(_spawn("acero_monitor", Vector3(18.0, 10.0, 54.0), Vector3.ZERO, 0, Vector3(0.0, -8.0, 0.0), 3.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(-60.0, 6.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, 30.0, 0.0), 7.0))
			_player_ships.append(_spawn("acero_lancer", Vector3(60.0, 4.0, 48.0), Vector3.ZERO, 0, Vector3(0.0, -30.0, 0.0), 7.0))

			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 8.0, -72.0), Vector3(0.0, 0.0, 2.6), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(-20.0, 4.0, -68.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(20.0, 6.0, -68.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_aegis", Vector3(-35.0, 2.0, -64.0), Vector3(0.8, 0.0, 3.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_aegis", Vector3(35.0, 7.0, -64.0), Vector3(-0.8, 0.0, 3.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 16.0, -64.0), Vector3(0.0, 0.0, 3.2), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(-48.0, 5.0, -60.0), Vector3(1.2, 0.0, 3.4), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(48.0, 3.0, -60.0), Vector3(-1.2, 0.0, 3.4), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(-12.0, 12.0, -58.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(12.0, -2.0, -58.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(-26.0, 8.0, -54.0), Vector3(0.8, 0.0, 4.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(26.0, 4.0, -54.0), Vector3(-0.8, 0.0, 4.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(-58.0, 6.0, -50.0), Vector3(1.8, 0.0, 4.8), 1, Vector3(0.0, 150.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(58.0, 2.0, -50.0), Vector3(-1.8, 0.0, 4.8), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(-38.0, 10.0, -48.0), Vector3(1.2, 0.0, 5.0), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(38.0, 0.0, -48.0), Vector3(-1.2, 0.0, 5.0), 1, Vector3(0.0, -165.0, 0.0)))

		"vinculados_stage_1":
			# ACT II // STAGE 01 [TUTORIAL]: Sanctuary Spire Psalm-4 -- First Catapult Sortie!
			# VINCULADOS DOCTRINE: 3D High Celestial Altitude & Catapult Dive Sortie
			# Carrier Ark elevated at Y=+20m; Mecha Platoons launched with downward dive pitch (-18 deg)
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 20.0, 58.0), Vector3.ZERO, 0, Vector3(-5.0, 0.0, 0.0), 5.0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(-12.0, 16.0, 46.0), Vector3(0.0, -4.5, -14.0), 0, Vector3(-18.0, 8.0, 0.0), 15.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(12.0, 16.0, 46.0), Vector3(0.0, -4.5, -16.0), 0, Vector3(-18.0, -8.0, 0.0), 18.0))

			# Hostiles: Heavy Acero column crawling low below at Y=-10m, vulnerable to vertical plunge fire!
			var ve1 := _spawn("acero_battlecruiser", Vector3(-6.0, -10.0, -48.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0))
			_apply_tutorial_handicap(ve1, 0.65, 0.70)
			_enemy_ships.append(ve1)
			var ve2 := _spawn("acero_corvette", Vector3(12.0, -8.0, -44.0), Vector3(0.0, 0.0, 3.2), 1, Vector3(0.0, 180.0, 0.0))
			_apply_tutorial_handicap(ve2, 0.65, 0.70)
			_enemy_ships.append(ve2)
			var ve3 := _spawn("acero_corvette", Vector3(-18.0, -12.0, -42.0), Vector3(0.0, 0.0, 3.2), 1, Vector3(0.0, 180.0, 0.0))
			_apply_tutorial_handicap(ve3, 0.65, 0.70)
			_enemy_ships.append(ve3)

		"vinculados_stage_2":
			# ACT II // STAGE 02: Dive into the Crystal Chasm
			# Extreme vertical dive: Player starts at celestial ledge Y=+24m diving down into basalt chasm Y=-18m
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 22.0, 56.0), Vector3.ZERO, 0, Vector3(-8.0, 0.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-14.0, 20.0, 46.0), Vector3(0.0, -6.0, -15.0), 0, Vector3(-24.0, 10.0, 0.0), 16.0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(14.0, 20.0, 46.0), Vector3(0.0, -6.0, -15.0), 0, Vector3(-24.0, -10.0, 0.0), 16.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(0.0, 24.0, 42.0), Vector3(0.0, -7.0, -18.0), 0, Vector3(-26.0, 0.0, 0.0), 20.0))

			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-8.0, -16.0, -52.0), Vector3(0.0, 0.0, 2.5), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(12.0, -14.0, -48.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-20.0, -12.0, -44.0), Vector3(0.0, 0.0, 3.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(20.0, -15.0, -44.0), Vector3(0.0, 0.0, 3.8), 1, Vector3(0.0, 180.0, 0.0)))

		"vinculados_stage_3":
			# ACT II // STAGE 03: Resonance of the Genesis Ring
			# High-agility dogfight weaving through the Genesis Ring gimbals with Nous Transcendent Frame
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 6.0, 60.0), Vector3.ZERO, 0, Vector3.ZERO, 6.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-12.0, 10.0, 52.0), Vector3(0.0, 0.0, -10.0), 0, Vector3(0.0, 12.0, 0.0), 14.0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(12.0, 8.0, 52.0), Vector3(0.0, 0.0, -10.0), 0, Vector3(0.0, -12.0, 0.0), 14.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(-24.0, 4.0, 48.0), Vector3(1.2, 0.0, -12.0), 0, Vector3(0.0, 20.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(24.0, 14.0, 48.0), Vector3(-1.2, 0.0, -12.0), 0, Vector3(0.0, -20.0, 0.0), 16.0))

			var acero_flag := _spawn("acero_dreadnought", Vector3(0.0, 5.0, -58.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0))
			acero_flag.hp = roundf(acero_flag.hp * 1.25)
			acero_flag.max_hp = acero_flag.hp
			_enemy_ships.append(acero_flag)
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-18.0, 3.0, -52.0), Vector3(0.6, 0.0, 3.5), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(18.0, 7.0, -54.0), Vector3(-0.6, 0.0, 3.8), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-28.0, 5.0, -48.0), Vector3(1.0, 0.0, 4.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(28.0, 2.0, -48.0), Vector3(-1.0, 0.0, 4.6), 1, Vector3(0.0, -165.0, 0.0)))

		"vinculados_stage_4":
			# ACT II // STAGE 04: The Harmonic Bastion
			# Aegis mobile armor anchor and Carrier Ark forming a psychic resonance screen
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 6.0, 62.0), Vector3.ZERO, 0, Vector3.ZERO, 6.0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(-15.0, 8.0, 58.0), Vector3.ZERO, 0, Vector3(0.0, 10.0, 0.0), 6.5))
			_player_ships.append(_spawn("vinculados_nous", Vector3(15.0, 10.0, 56.0), Vector3(0.0, 0.0, -8.0), 0, Vector3(0.0, -10.0, 0.0), 12.0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(-28.0, 4.0, 50.0), Vector3(1.5, 0.0, -10.0), 0, Vector3(0.0, 20.0, 0.0), 14.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(28.0, 12.0, 50.0), Vector3(-1.5, 0.0, -12.0), 0, Vector3(0.0, -20.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(0.0, 16.0, 48.0), Vector3(0.0, 0.0, -10.0), 0, Vector3.ZERO, 15.0))

			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 5.0, -60.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-18.0, 3.0, -56.0), Vector3(0.5, 0.0, 3.5), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(18.0, 7.0, -56.0), Vector3(-0.5, 0.0, 3.5), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(0.0, 12.0, -54.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-30.0, 4.0, -50.0), Vector3(1.2, 0.0, 4.2), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(30.0, 2.0, -50.0), Vector3(-1.2, 0.0, 4.5), 1, Vector3(0.0, -165.0, 0.0)))

		"vinculados_stage_5":
			# ACT II // STAGE 05: Colossus Awakens -- First Sortie of Seraph-Prime!
			# Mobile Armor Seraph-Prime leads the assault with sweeping wings and funnels
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 10.0, 60.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 10.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-16.0, 5.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, 8.0, 0.0), 5.5))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(16.0, 8.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, -8.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-30.0, 12.0, 54.0), Vector3(1.2, 0.0, -10.0), 0, Vector3(0.0, 18.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(30.0, 6.0, 54.0), Vector3(-1.2, 0.0, -10.0), 0, Vector3(0.0, -18.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(-42.0, 4.0, 48.0), Vector3(2.0, 0.0, -12.0), 0, Vector3(0.0, 25.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(42.0, 14.0, 48.0), Vector3(-2.0, 0.0, -12.0), 0, Vector3(0.0, -25.0, 0.0), 16.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -68.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-18.0, 4.0, -62.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(18.0, 6.0, -62.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-32.0, 2.0, -58.0), Vector3(1.0, 0.0, 3.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(32.0, 8.0, -58.0), Vector3(-1.0, 0.0, 3.5), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(0.0, 12.0, -56.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-42.0, 5.0, -52.0), Vector3(1.4, 0.0, 4.2), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(42.0, 3.0, -52.0), Vector3(-1.4, 0.0, 4.5), 1, Vector3(0.0, -160.0, 0.0)))

		"vinculados_stage_6":
			# ACT II // STAGE 06: Open Celestial Exosphere Dogfight
			# 8 Vinculados units in high-speed orbital flight in completely open void
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 10.0, 64.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 10.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-15.0, 4.0, 60.0), Vector3.ZERO, 0, Vector3(0.0, 10.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(15.0, 8.0, 58.0), Vector3(0.0, 0.0, -9.0), 0, Vector3(0.0, -10.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-28.0, 10.0, 52.0), Vector3(1.2, 0.0, -10.0), 0, Vector3(0.0, 18.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(28.0, 6.0, 52.0), Vector3(-1.2, 0.0, -10.0), 0, Vector3(0.0, -18.0, 0.0), 14.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(-40.0, 12.0, 46.0), Vector3(2.0, 0.0, -14.0), 0, Vector3(0.0, 25.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(40.0, 3.0, 46.0), Vector3(-2.0, 0.0, -14.0), 0, Vector3(0.0, -25.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_chorus", Vector3(0.0, 16.0, 50.0), Vector3(0.0, 0.0, -11.0), 0, Vector3.ZERO, 15.0))

			_enemy_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, -65.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(-18.0, 4.0, -60.0), Vector3(0.6, 0.0, 3.4), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(18.0, 8.0, -60.0), Vector3(-0.6, 0.0, 3.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(-30.0, 2.0, -56.0), Vector3(1.0, 0.0, 3.8), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(30.0, 6.0, -56.0), Vector3(-1.0, 0.0, 4.2), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_raider", Vector3(-42.0, 5.0, -50.0), Vector3(1.5, 0.0, 4.5), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(42.0, 3.0, -50.0), Vector3(-1.5, 0.0, 5.0), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(0.0, 12.0, -48.0), Vector3(0.0, 0.0, 5.0), 1, Vector3(0.0, 180.0, 0.0)))

		"vinculados_stage_7":
			# ACT II // STAGE 07: Defense of the Chasm Sanctuary
			# Sacred Spire in the rear: Aegis Anchor + Cradles guarding the well; Forward mechas sortie
			_player_ships.append(_spawn("vinculados_aegis", Vector3(0.0, 10.0, 68.0), Vector3.ZERO, 0, Vector3.ZERO, 5.0))
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 10.0, 56.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 9.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-16.0, 5.0, 64.0), Vector3.ZERO, 0, Vector3(0.0, 10.0, 0.0), 5.5))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(16.0, 5.0, 64.0), Vector3.ZERO, 0, Vector3(0.0, -10.0, 0.0), 5.5))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-30.0, 8.0, 52.0), Vector3(1.2, 0.0, -9.0), 0, Vector3(0.0, 18.0, 0.0), 12.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(30.0, 8.0, 52.0), Vector3(-1.2, 0.0, -9.0), 0, Vector3(0.0, -18.0, 0.0), 12.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(-42.0, 3.0, 46.0), Vector3(1.8, 0.0, -12.0), 0, Vector3(0.0, 25.0, 0.0), 17.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(42.0, 12.0, 46.0), Vector3(-1.8, 0.0, -12.0), 0, Vector3(0.0, -25.0, 0.0), 17.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(0.0, 16.0, 50.0), Vector3(0.0, 0.0, -10.0), 0, Vector3.ZERO, 15.0))

			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-10.0, 5.0, -64.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(10.0, 5.0, -64.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(0.0, 2.0, -68.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-26.0, 3.0, -58.0), Vector3(0.8, 0.0, 3.5), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(26.0, 7.0, -58.0), Vector3(-0.8, 0.0, 3.5), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(0.0, 12.0, -56.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-40.0, 6.0, -52.0), Vector3(1.2, 0.0, 4.2), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(40.0, 2.0, -52.0), Vector3(-1.2, 0.0, 4.2), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(0.0, -4.0, -50.0), Vector3(0.0, 0.0, 4.5), 1, Vector3(0.0, 180.0, 0.0)))

		"vinculados_stage_8":
			# ACT II // STAGE 08: Raid on Corsair Pirate Haven
			# High-mobility infiltration from high celestial perch
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 10.0, 62.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 9.0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(-15.0, 6.0, 60.0), Vector3.ZERO, 0, Vector3(0.0, 10.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(15.0, 7.0, 60.0), Vector3.ZERO, 0, Vector3(0.0, -10.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-28.0, 3.0, 56.0), Vector3.ZERO, 0, Vector3(0.0, 15.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(28.0, 10.0, 56.0), Vector3(-1.0, 0.0, -9.0), 0, Vector3(0.0, -15.0, 0.0), 12.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-40.0, 8.0, 50.0), Vector3(1.5, 0.0, -10.0), 0, Vector3(0.0, 22.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(40.0, 5.0, 50.0), Vector3(-1.5, 0.0, -12.0), 0, Vector3(0.0, -22.0, 0.0), 17.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(-50.0, 12.0, 46.0), Vector3(2.0, 0.0, -12.0), 0, Vector3(0.0, 28.0, 0.0), 16.0))
			_player_ships.append(_spawn("vinculados_chorus", Vector3(50.0, 3.0, 46.0), Vector3(-2.0, 0.0, -12.0), 0, Vector3(0.0, -28.0, 0.0), 15.0))

			_enemy_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, -68.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(-18.0, 4.0, -62.0), Vector3(0.5, 0.0, 3.4), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(18.0, 6.0, -62.0), Vector3(-0.5, 0.0, 3.4), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(0.0, 14.0, -60.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(-32.0, 3.0, -56.0), Vector3(1.0, 0.0, 3.8), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(32.0, 7.0, -56.0), Vector3(-1.0, 0.0, 3.8), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(-44.0, 5.0, -52.0), Vector3(1.4, 0.0, 4.2), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(44.0, 2.0, -52.0), Vector3(-1.4, 0.0, 4.2), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(-22.0, 10.0, -48.0), Vector3(0.8, 0.0, 5.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(22.0, 1.0, -48.0), Vector3(-0.8, 0.0, 5.0), 1, Vector3(0.0, -170.0, 0.0)))

		"vinculados_stage_9":
			# ACT III // STAGE 09: The Harmonic Wall (3-Tier Altitude Grand Mecha Formation)
			# Tier 1 High Archangel (+16m), Tier 2 Mid Assault (+4m), Tier 3 Low Skirmish (-6m)
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 10.0, 66.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 9.0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(-14.0, 5.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, 8.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(14.0, 5.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, -8.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-26.0, 8.0, 58.0), Vector3.ZERO, 0, Vector3(0.0, 12.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(26.0, 8.0, 58.0), Vector3.ZERO, 0, Vector3(0.0, -12.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-38.0, 12.0, 52.0), Vector3(1.2, 0.0, -9.0), 0, Vector3(0.0, 18.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(38.0, 12.0, 52.0), Vector3(-1.2, 0.0, -9.0), 0, Vector3(0.0, -18.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(0.0, 18.0, 54.0), Vector3(0.0, -2.0, -10.0), 0, Vector3(-10.0, 0.0, 0.0), 14.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(-50.0, 4.0, 48.0), Vector3(2.0, 0.0, -12.0), 0, Vector3(0.0, 25.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(50.0, 14.0, 48.0), Vector3(-2.0, 0.0, -12.0), 0, Vector3(0.0, -25.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(0.0, -4.0, 50.0), Vector3(0.0, 2.0, -10.0), 0, Vector3(10.0, 0.0, 0.0), 15.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -70.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(-15.0, 2.0, -66.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(15.0, 4.0, -66.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-30.0, 6.0, -62.0), Vector3(0.8, 0.0, 3.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(30.0, 6.0, -62.0), Vector3(-0.8, 0.0, 3.5), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-42.0, 3.0, -56.0), Vector3(1.2, 0.0, 3.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(42.0, 5.0, -56.0), Vector3(-1.2, 0.0, 3.5), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(0.0, 12.0, -58.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-52.0, 7.0, -50.0), Vector3(1.6, 0.0, 4.2), 1, Vector3(0.0, 155.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(52.0, 2.0, -50.0), Vector3(-1.6, 0.0, 4.2), 1, Vector3(0.0, -155.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-20.0, 8.0, -48.0), Vector3(0.8, 0.0, 4.5), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(20.0, 1.0, -48.0), Vector3(-0.8, 0.0, 4.5), 1, Vector3(0.0, -170.0, 0.0)))

		"vinculados_stage_10":
			# ACT III // STAGE 10: Assault on the Imperial Sluice Network (12 Vinculados vs 13 Mixed Enemy Titans)
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 10.0, 66.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 9.0))
			_player_ships.append(_spawn("vinculados_colossus", Vector3(-22.0, 10.0, 64.0), Vector3(0.0, 0.0, -8.0), 0, Vector3(0.0, 8.0, 0.0), 9.0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(22.0, 7.0, 64.0), Vector3.ZERO, 0, Vector3(0.0, -8.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-34.0, 4.0, 60.0), Vector3.ZERO, 0, Vector3(0.0, 12.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(34.0, 4.0, 60.0), Vector3.ZERO, 0, Vector3(0.0, -12.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-12.0, 16.0, 56.0), Vector3(0.0, -2.0, -10.0), 0, Vector3(-10.0, 6.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(12.0, 16.0, 56.0), Vector3(0.0, -2.0, -10.0), 0, Vector3(-10.0, -6.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(0.0, -2.0, 54.0), Vector3(0.0, 1.0, -9.0), 0, Vector3(8.0, 0.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(-46.0, 8.0, 50.0), Vector3(1.8, 0.0, -12.0), 0, Vector3(0.0, 22.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(46.0, 8.0, 50.0), Vector3(-1.8, 0.0, -12.0), 0, Vector3(0.0, -22.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(-56.0, 3.0, 46.0), Vector3(2.2, 0.0, -12.0), 0, Vector3(0.0, 28.0, 0.0), 16.0))
			_player_ships.append(_spawn("vinculados_chorus", Vector3(56.0, 12.0, 46.0), Vector3(-2.2, 0.0, -12.0), 0, Vector3(0.0, -28.0, 0.0), 16.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -70.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(-22.0, 4.0, -66.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(22.0, 6.0, -66.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-38.0, 3.0, -60.0), Vector3(1.0, 0.0, 3.0), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(38.0, 7.0, -60.0), Vector3(-1.0, 0.0, 3.4), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-50.0, 5.0, -56.0), Vector3(1.5, 0.0, 3.5), 1, Vector3(0.0, 155.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(50.0, 2.0, -56.0), Vector3(-1.5, 0.0, 3.5), 1, Vector3(0.0, -155.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(0.0, 12.0, -58.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(-14.0, 10.0, -54.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(14.0, -2.0, -54.0), Vector3(0.0, 0.0, 3.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(-30.0, 8.0, -48.0), Vector3(1.0, 0.0, 5.0), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(30.0, 2.0, -48.0), Vector3(-1.0, 0.0, 5.0), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(0.0, -6.0, -50.0), Vector3(0.0, 0.0, 4.5), 1, Vector3(0.0, 180.0, 0.0)))

		"vinculados_stage_11":
			# ACT III // STAGE 11: The Calm Horizon Incursion (13 Vinculados vs 14 Acero Dreadnought Bastion)
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 10.0, 68.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 9.0))
			_player_ships.append(_spawn("vinculados_colossus", Vector3(-24.0, 10.0, 66.0), Vector3(0.0, 0.0, -8.0), 0, Vector3(0.0, 8.0, 0.0), 9.0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(24.0, 7.0, 66.0), Vector3.ZERO, 0, Vector3(0.0, -8.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(0.0, 18.0, 62.0), Vector3.ZERO, 0, Vector3.ZERO, 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-38.0, 4.0, 60.0), Vector3.ZERO, 0, Vector3(0.0, 14.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(38.0, 4.0, 60.0), Vector3.ZERO, 0, Vector3(0.0, -14.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-16.0, 14.0, 56.0), Vector3(0.0, -2.0, -10.0), 0, Vector3(-8.0, 6.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(16.0, 14.0, 56.0), Vector3(0.0, -2.0, -10.0), 0, Vector3(-8.0, -6.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-48.0, 7.0, 52.0), Vector3(1.8, 0.0, -10.0), 0, Vector3(0.0, 22.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(48.0, 7.0, 52.0), Vector3(-1.8, 0.0, -12.0), 0, Vector3(0.0, -22.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(-58.0, 2.0, 48.0), Vector3(2.2, 0.0, -14.0), 0, Vector3(0.0, 28.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(58.0, 10.0, 48.0), Vector3(-2.2, 0.0, -12.0), 0, Vector3(0.0, -28.0, 0.0), 16.0))
			_player_ships.append(_spawn("vinculados_chorus", Vector3(0.0, -4.0, 52.0), Vector3(0.0, 2.0, -11.0), 0, Vector3(8.0, 0.0, 0.0), 15.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -72.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(-18.0, 2.0, -68.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(18.0, 4.0, -68.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-34.0, 6.0, -62.0), Vector3(0.8, 0.0, 3.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(34.0, 6.0, -62.0), Vector3(-0.8, 0.0, 3.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 14.0, -60.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-48.0, 3.0, -56.0), Vector3(1.2, 0.0, 3.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(48.0, 5.0, -56.0), Vector3(-1.2, 0.0, 3.5), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(-20.0, 10.0, -54.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(20.0, 10.0, -54.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-58.0, 7.0, -50.0), Vector3(1.8, 0.0, 4.2), 1, Vector3(0.0, 150.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(58.0, 2.0, -50.0), Vector3(-1.8, 0.0, 4.2), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-26.0, -2.0, -48.0), Vector3(0.8, 0.0, 4.5), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(26.0, -2.0, -48.0), Vector3(-0.8, 0.0, 4.5), 1, Vector3(0.0, -170.0, 0.0)))

		"vinculados_stage_12":
			# ACT III // STAGE 12: The Transcendence Choir -- Climax at the Genesis Ring (15 Sacred Units vs 16 Titans)
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 12.0, 68.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 9.0))
			_player_ships.append(_spawn("vinculados_colossus", Vector3(-22.0, 10.0, 66.0), Vector3(0.0, 0.0, -8.0), 0, Vector3(0.0, 8.0, 0.0), 9.0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(22.0, 8.0, 66.0), Vector3.ZERO, 0, Vector3(0.0, -8.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(0.0, 18.0, 62.0), Vector3.ZERO, 0, Vector3.ZERO, 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-38.0, 4.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, 12.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(38.0, 4.0, 62.0), Vector3.ZERO, 0, Vector3(0.0, -12.0, 0.0), 6.0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, -4.0, 60.0), Vector3.ZERO, 0, Vector3.ZERO, 6.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-16.0, 14.0, 56.0), Vector3(0.0, -2.0, -10.0), 0, Vector3(-8.0, 6.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(16.0, 14.0, 56.0), Vector3(0.0, -2.0, -10.0), 0, Vector3(-8.0, -6.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-50.0, 7.0, 52.0), Vector3(1.8, 0.0, -10.0), 0, Vector3(0.0, 22.0, 0.0), 13.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(50.0, 7.0, 52.0), Vector3(-1.8, 0.0, -12.0), 0, Vector3(0.0, -22.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(-60.0, 2.0, 48.0), Vector3(2.2, 0.0, -14.0), 0, Vector3(0.0, 28.0, 0.0), 18.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(60.0, 10.0, 48.0), Vector3(-2.2, 0.0, -12.0), 0, Vector3(0.0, -28.0, 0.0), 16.0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(-30.0, -2.0, 50.0), Vector3(1.2, 0.0, -10.0), 0, Vector3(0.0, 15.0, 0.0), 15.0))
			_player_ships.append(_spawn("vinculados_chorus", Vector3(30.0, -2.0, 50.0), Vector3(-1.2, 0.0, -10.0), 0, Vector3(0.0, -15.0, 0.0), 15.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -74.0), Vector3(0.0, 0.0, 2.6), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(-22.0, 4.0, -68.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(22.0, 6.0, -68.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(0.0, 16.0, -66.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-36.0, 4.0, -64.0), Vector3(0.8, 0.0, 3.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(36.0, 4.0, -64.0), Vector3(-0.8, 0.0, 3.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(-50.0, 5.0, -60.0), Vector3(1.2, 0.0, 3.4), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(50.0, 3.0, -60.0), Vector3(-1.2, 0.0, 3.4), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-16.0, -3.0, -58.0), Vector3(0.5, 0.0, 3.5), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(16.0, -3.0, -58.0), Vector3(-0.5, 0.0, 3.5), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(0.0, -6.0, -56.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(-30.0, 10.0, -54.0), Vector3(0.8, 0.0, 3.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(30.0, 10.0, -54.0), Vector3(-0.8, 0.0, 3.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(-60.0, 6.0, -50.0), Vector3(1.8, 0.0, 5.0), 1, Vector3(0.0, 150.0, 0.0)))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(60.0, 2.0, -50.0), Vector3(-1.8, 0.0, 5.0), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(0.0, 18.0, -52.0), Vector3(0.0, 0.0, 4.2), 1, Vector3(0.0, 180.0, 0.0)))

		"marea_stage_1":
			# ACT III // STAGE 01 [TUTORIAL]: Running the Basalt Narrows -- Run the Blockade!
			# FREE TIDE DOCTRINE: Surfing El Rio del Viento at high cruising momentum with quantum sails full!
			# Ships start with high forward speed (14-16 m/s) and angled broadside headings (yaw: +/-22 deg)
			_player_ships.append(_spawn("marea_galleon", Vector3(0.0, 4.0, 52.0), Vector3(0.0, 0.0, -14.0), 0, Vector3(0.0, 20.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_raider", Vector3(-16.0, 3.0, 56.0), Vector3(1.0, 0.0, -16.0), 0, Vector3(0.0, -25.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(16.0, 6.0, 56.0), Vector3(-1.0, 0.0, -16.0), 0, Vector3(0.0, 25.0, 0.0), 16.0))

			# Hostiles: Imperial Blockade Picket holding stationary gun lines at Z=-32m to bottle up the canyon
			var me1 := _spawn("acero_battlecruiser", Vector3(0.0, 4.0, -32.0), Vector3(0.0, 0.0, 1.5), 1, Vector3(0.0, 180.0, 0.0))
			_apply_tutorial_handicap(me1, 0.65, 0.70)
			_enemy_ships.append(me1)
			var me2 := _spawn("acero_corvette", Vector3(-18.0, 5.0, -30.0), Vector3(0.0, 0.0, 2.0), 1, Vector3(0.0, 170.0, 0.0))
			_apply_tutorial_handicap(me2, 0.65, 0.70)
			_enemy_ships.append(me2)
			var me3 := _spawn("acero_corvette", Vector3(18.0, 3.0, -30.0), Vector3(0.0, 0.0, 2.0), 1, Vector3(0.0, -170.0, 0.0))
			_apply_tutorial_handicap(me3, 0.65, 0.70)
			_enemy_ships.append(me3)

		"marea_stage_2":
			# ACT III // STAGE 02: Raid on Foundry Vulcan-3
			# Ambush from industrial cover: Emerging from smelter funnels with angled port broadsides
			_player_ships.append(_spawn("marea_galleon", Vector3(30.0, 4.0, 52.0), Vector3(-2.0, 0.0, -12.0), 0, Vector3(0.0, -30.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(44.0, 7.0, 50.0), Vector3(-2.5, 0.0, -14.0), 0, Vector3(0.0, -35.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_raider", Vector3(20.0, 2.0, 48.0), Vector3(-1.5, 0.0, -15.0), 0, Vector3(0.0, -25.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(10.0, 6.0, 54.0), Vector3(0.0, 0.0, -12.0), 0, Vector3.ZERO, 13.0))

			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-10.0, 5.0, -54.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(10.0, 3.0, -50.0), Vector3(0.0, 0.0, 3.5), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-22.0, 7.0, -48.0), Vector3(0.0, 0.0, 3.5), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(24.0, 4.0, -48.0), Vector3(0.0, 0.0, 3.8), 1, Vector3(0.0, 180.0, 0.0)))

		"marea_stage_3":
			# ACT III // STAGE 03: The Maelstrom of Barlovento
			# Extreme vortex surfing: Tangential starting momentum circling Grand Sol's corona!
			var pg := _spawn("marea_galleon", Vector3(0.0, 6.0, 60.0), Vector3(10.0, 0.0, -10.0), 0, Vector3(0.0, 45.0, 0.0), 15.0)
			pg.hp = roundf(pg.hp * 1.20)
			pg.max_hp = pg.hp
			_player_ships.append(pg)
			_player_ships.append(_spawn("marea_brigantine", Vector3(-16.0, 3.0, 54.0), Vector3(12.0, 0.0, -10.0), 0, Vector3(0.0, 40.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_raider", Vector3(16.0, 9.0, 54.0), Vector3(8.0, 0.0, -12.0), 0, Vector3(0.0, 50.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-28.0, 4.0, 50.0), Vector3(12.0, 0.0, -8.0), 0, Vector3(0.0, 35.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(28.0, 2.0, 50.0), Vector3(6.0, 0.0, -14.0), 0, Vector3(0.0, 55.0, 0.0), 18.0))

			var boss_acero := _spawn("acero_dreadnought", Vector3(0.0, 4.0, -60.0), Vector3(-2.0, 0.0, 3.0), 1, Vector3(0.0, -160.0, 0.0))
			boss_acero.hp = roundf(boss_acero.hp * 1.30)
			boss_acero.max_hp = boss_acero.hp
			_enemy_ships.append(boss_acero)
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-18.0, 7.0, -54.0), Vector3(-1.0, 0.0, 3.5), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(18.0, 10.0, -50.0), Vector3(-2.5, 0.0, 4.0), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-30.0, 2.0, -48.0), Vector3(0.0, 0.0, 4.2), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(30.0, 4.0, -48.0), Vector3(-3.0, 0.0, 4.5), 1, Vector3(0.0, -140.0, 0.0)))

		"marea_stage_4":
			# ACT III // STAGE 04: The Weather-Gauge Ambush
			# Corsair wolfpack claiming the upwind position; Bombards firing over reefs
			_player_ships.append(_spawn("marea_galleon", Vector3(0.0, 5.0, 58.0), Vector3(0.0, 0.0, -12.0), 0, Vector3(0.0, 15.0, 0.0), 12.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-16.0, 4.0, 54.0), Vector3(1.0, 0.0, -13.0), 0, Vector3(0.0, -20.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(16.0, 6.0, 54.0), Vector3(-1.0, 0.0, -13.0), 0, Vector3(0.0, 20.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, 12.0, 50.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_raider", Vector3(-30.0, 2.0, 48.0), Vector3(2.5, 0.0, -14.0), 0, Vector3(0.0, -35.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(30.0, 8.0, 48.0), Vector3(-2.5, 0.0, -16.0), 0, Vector3(0.0, 35.0, 0.0), 18.0))

			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 4.0, -60.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-18.0, 6.0, -56.0), Vector3(0.5, 0.0, 3.5), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(18.0, 2.0, -56.0), Vector3(-0.5, 0.0, 3.5), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(0.0, 10.0, -54.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-30.0, 4.0, -50.0), Vector3(1.0, 0.0, 4.2), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(30.0, 7.0, -50.0), Vector3(-1.0, 0.0, 4.5), 1, Vector3(0.0, -165.0, 0.0)))

		"marea_stage_5":
			# ACT III // STAGE 05: Awakening of the Soberano del Mar
			# 6-Deck Mega-Galleon awakening with 6 quantum sails; fleet forms screening escort
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, 60.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 9.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-16.0, 4.0, 56.0), Vector3(1.0, 0.0, -12.0), 0, Vector3(0.0, -18.0, 0.0), 12.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(16.0, 6.0, 56.0), Vector3(-1.0, 0.0, -12.0), 0, Vector3(0.0, 18.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(-30.0, 2.0, 50.0), Vector3(2.0, 0.0, -14.0), 0, Vector3(0.0, -30.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, 12.0, 52.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_raider", Vector3(30.0, 8.0, 50.0), Vector3(-2.0, 0.0, -14.0), 0, Vector3(0.0, 30.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(40.0, 1.0, 44.0), Vector3(-3.0, 0.0, -16.0), 0, Vector3(0.0, 40.0, 0.0), 18.0))

			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 8.0, -66.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(-16.0, 3.0, -62.0), Vector3(0.5, 0.0, 3.2), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_aegis", Vector3(16.0, 5.0, -62.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(-30.0, 7.0, -56.0), Vector3(1.0, 0.0, 4.0), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(30.0, 3.0, -56.0), Vector3(-1.0, 0.0, 4.0), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(-40.0, 2.0, -50.0), Vector3(1.5, 0.0, 4.5), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(40.0, 9.0, -50.0), Vector3(-1.5, 0.0, 4.8), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_psyche", Vector3(0.0, 14.0, -52.0), Vector3(0.0, 0.0, 4.2), 1, Vector3(0.0, 180.0, 0.0)))

		"marea_stage_6":
			# ACT III // STAGE 06: Maelstrom Rapids Dogfight
			# Open rapids dogfight with 8 corsair voidships surfing turbulent currents
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, 62.0), Vector3(0.0, 0.0, -10.0), 0, Vector3.ZERO, 10.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-16.0, 4.0, 58.0), Vector3(1.2, 0.0, -12.0), 0, Vector3(0.0, -18.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(16.0, 6.0, 58.0), Vector3(-1.2, 0.0, -12.0), 0, Vector3(0.0, 18.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-28.0, 8.0, 52.0), Vector3(2.0, 0.0, -14.0), 0, Vector3(0.0, -25.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(28.0, 2.0, 52.0), Vector3(-2.0, 0.0, -14.0), 0, Vector3(0.0, 25.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, 14.0, 50.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(-40.0, 5.0, 46.0), Vector3(3.0, 0.0, -16.0), 0, Vector3(0.0, -35.0, 0.0), 18.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(40.0, 7.0, 46.0), Vector3(-3.0, 0.0, -16.0), 0, Vector3(0.0, 35.0, 0.0), 18.0))

			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 5.0, -64.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(-16.0, 2.0, -60.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(16.0, 7.0, -60.0), Vector3(-0.5, 0.0, 3.5), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-30.0, 4.0, -55.0), Vector3(1.0, 0.0, 3.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(30.0, 4.0, -55.0), Vector3(-1.0, 0.0, 3.0), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-40.0, 6.0, -50.0), Vector3(1.4, 0.0, 4.2), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(40.0, 2.0, -50.0), Vector3(-1.4, 0.0, 4.2), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(0.0, 10.0, -48.0), Vector3(0.0, 0.0, 4.5), 1, Vector3(0.0, 180.0, 0.0)))

		"marea_stage_7":
			# ACT III // STAGE 07: Defense of the Free Haven
			# Bombards anchored on haven platforms; fast fleet sorts to outflank imperial siege line
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, 10.0, 70.0), Vector3.ZERO, 0, Vector3.ZERO, 3.0))
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, 58.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 10.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-16.0, 4.0, 54.0), Vector3(1.0, 0.0, -12.0), 0, Vector3(0.0, -18.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(16.0, 6.0, 54.0), Vector3(-1.0, 0.0, -12.0), 0, Vector3(0.0, 18.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-32.0, 2.0, 48.0), Vector3(2.0, 0.0, -14.0), 0, Vector3(0.0, -28.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(32.0, 8.0, 48.0), Vector3(-2.0, 0.0, -14.0), 0, Vector3(0.0, 28.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(-44.0, 6.0, 44.0), Vector3(2.5, 0.0, -15.0), 0, Vector3(0.0, -35.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(44.0, 3.0, 44.0), Vector3(-2.5, 0.0, -15.0), 0, Vector3(0.0, 35.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(0.0, -4.0, 46.0), Vector3(0.0, 0.0, -16.0), 0, Vector3.ZERO, 18.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -68.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-18.0, 4.0, -64.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(18.0, 6.0, -64.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-32.0, 2.0, -58.0), Vector3(1.0, 0.0, 3.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(32.0, 8.0, -58.0), Vector3(-1.0, 0.0, 3.5), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(0.0, 12.0, -58.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-44.0, 5.0, -50.0), Vector3(1.5, 0.0, 4.2), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(44.0, 3.0, -50.0), Vector3(-1.5, 0.0, 4.2), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(0.0, -4.0, -48.0), Vector3(0.0, 0.0, 4.5), 1, Vector3(0.0, 180.0, 0.0)))

		"marea_stage_8":
			# ACT III // STAGE 08: Interception at the Spire Apex
			# Wolfpack of corsair boarding cutters swarming around celestial convoy
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, 62.0), Vector3(0.0, 0.0, -9.0), 0, Vector3.ZERO, 10.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-16.0, 4.0, 58.0), Vector3(1.0, 0.0, -12.0), 0, Vector3(0.0, -18.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(16.0, 6.0, 58.0), Vector3(-1.0, 0.0, -12.0), 0, Vector3(0.0, 18.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-30.0, 8.0, 52.0), Vector3(1.8, 0.0, -14.0), 0, Vector3(0.0, -25.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(30.0, 2.0, 52.0), Vector3(-1.8, 0.0, -14.0), 0, Vector3(0.0, 25.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(-42.0, 4.0, 48.0), Vector3(2.2, 0.0, -15.0), 0, Vector3(0.0, -32.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(42.0, 8.0, 48.0), Vector3(-2.2, 0.0, -15.0), 0, Vector3(0.0, 32.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, 14.0, 52.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(0.0, -2.0, 46.0), Vector3(0.0, 0.0, -17.0), 0, Vector3.ZERO, 18.0))

			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 8.0, -68.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_aegis", Vector3(-18.0, 4.0, -64.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(18.0, 6.0, -64.0), Vector3(-0.5, 0.0, 3.2), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(-32.0, 2.0, -60.0), Vector3(0.8, 0.0, 3.2), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(32.0, 8.0, -56.0), Vector3(-1.0, 0.0, 4.0), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(-44.0, 5.0, -52.0), Vector3(1.2, 0.0, 4.0), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(44.0, 3.0, -52.0), Vector3(-1.2, 0.0, 4.8), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_psyche", Vector3(-22.0, 10.0, -48.0), Vector3(0.8, 0.0, 4.2), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_chorus", Vector3(22.0, 10.0, -48.0), Vector3(-0.8, 0.0, 4.4), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(0.0, 14.0, -50.0), Vector3(0.0, 0.0, 4.5), 1, Vector3(0.0, 180.0, 0.0)))

		"marea_stage_9":
			# ACT III // STAGE 09: The Weather-Gauge Grand Armada
			# 11 Corsair voidships sailing in full windward battlelines across the storm
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, 66.0), Vector3(0.0, 0.0, -10.0), 0, Vector3.ZERO, 11.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-16.0, 4.0, 62.0), Vector3(1.2, 0.0, -13.0), 0, Vector3(0.0, -18.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(16.0, 4.0, 62.0), Vector3(-1.2, 0.0, -13.0), 0, Vector3(0.0, 18.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(0.0, 14.0, 58.0), Vector3(0.0, 0.0, -12.0), 0, Vector3.ZERO, 13.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, -4.0, 58.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-30.0, 6.0, 54.0), Vector3(1.8, 0.0, -14.0), 0, Vector3(0.0, -25.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(30.0, 6.0, 54.0), Vector3(-1.8, 0.0, -14.0), 0, Vector3(0.0, 25.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(-44.0, 3.0, 50.0), Vector3(2.5, 0.0, -15.0), 0, Vector3(0.0, -32.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(44.0, 5.0, 50.0), Vector3(-2.5, 0.0, -15.0), 0, Vector3(0.0, 32.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(-55.0, 8.0, 46.0), Vector3(3.2, 0.0, -18.0), 0, Vector3(0.0, -40.0, 0.0), 19.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(55.0, 1.0, 46.0), Vector3(-3.2, 0.0, -18.0), 0, Vector3(0.0, 40.0, 0.0), 19.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -70.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(-16.0, 2.0, -66.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(16.0, 4.0, -66.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-30.0, 6.0, -62.0), Vector3(0.8, 0.0, 3.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(30.0, 6.0, -62.0), Vector3(-0.8, 0.0, 3.5), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-44.0, 3.0, -56.0), Vector3(1.2, 0.0, 3.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(44.0, 5.0, -56.0), Vector3(-1.2, 0.0, 3.5), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(0.0, 12.0, -58.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-54.0, 7.0, -50.0), Vector3(1.6, 0.0, 4.2), 1, Vector3(0.0, 155.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(54.0, 2.0, -50.0), Vector3(-1.6, 0.0, 4.2), 1, Vector3(0.0, -155.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-22.0, 8.0, -48.0), Vector3(0.8, 0.0, 4.5), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(22.0, 0.0, -48.0), Vector3(-0.8, 0.0, 4.5), 1, Vector3(0.0, -170.0, 0.0)))

		"marea_stage_10":
			# ACT III // STAGE 10: Storming the Imperial Smelter Network (12 Corsair Ships vs 13 Heavy Defenders)
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, 66.0), Vector3(0.0, 0.0, -10.0), 0, Vector3.ZERO, 10.0))
			_player_ships.append(_spawn("marea_leviathan", Vector3(-20.0, 4.0, 64.0), Vector3(1.0, 0.0, -10.0), 0, Vector3(0.0, -15.0, 0.0), 10.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(20.0, 6.0, 64.0), Vector3(-1.0, 0.0, -12.0), 0, Vector3(0.0, 15.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-34.0, 3.0, 60.0), Vector3(1.5, 0.0, -13.0), 0, Vector3(0.0, -22.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(34.0, 3.0, 60.0), Vector3(-1.5, 0.0, -13.0), 0, Vector3(0.0, 22.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, 14.0, 56.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, -4.0, 56.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-46.0, 7.0, 52.0), Vector3(2.0, 0.0, -14.0), 0, Vector3(0.0, -30.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(46.0, 7.0, 52.0), Vector3(-2.0, 0.0, -14.0), 0, Vector3(0.0, 30.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(-56.0, 2.0, 48.0), Vector3(2.8, 0.0, -16.0), 0, Vector3(0.0, -38.0, 0.0), 17.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(56.0, 8.0, 48.0), Vector3(-2.8, 0.0, -16.0), 0, Vector3(0.0, 38.0, 0.0), 17.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(0.0, 10.0, 48.0), Vector3(0.0, 0.0, -18.0), 0, Vector3.ZERO, 19.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -72.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(-22.0, 8.0, -68.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(22.0, 4.0, -68.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-38.0, 6.0, -62.0), Vector3(1.0, 0.0, 3.0), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(38.0, 6.0, -62.0), Vector3(-1.0, 0.0, 3.5), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 14.0, -64.0), Vector3(0.0, 0.0, 3.2), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_aegis", Vector3(-16.0, -3.0, -60.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(16.0, 10.0, -60.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(-50.0, 5.0, -54.0), Vector3(1.5, 0.0, 4.0), 1, Vector3(0.0, 155.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(50.0, 3.0, -54.0), Vector3(-1.5, 0.0, 4.0), 1, Vector3(0.0, -155.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-60.0, 7.0, -50.0), Vector3(2.0, 0.0, 4.2), 1, Vector3(0.0, 150.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(60.0, 1.0, -50.0), Vector3(-2.0, 0.0, 4.5), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(0.0, -5.0, -52.0), Vector3(0.0, 0.0, 4.8), 1, Vector3(0.0, 180.0, 0.0)))

		"marea_stage_11":
			# ACT III // STAGE 11: Breaching the Singularity Iron Wall (13 Corsair Ships vs 14 Acero Titans)
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, 68.0), Vector3(0.0, 0.0, -10.0), 0, Vector3.ZERO, 10.0))
			_player_ships.append(_spawn("marea_leviathan", Vector3(-22.0, 4.0, 65.0), Vector3(1.0, 0.0, -10.0), 0, Vector3(0.0, -14.0, 0.0), 10.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(22.0, 6.0, 65.0), Vector3(-1.0, 0.0, -13.0), 0, Vector3(0.0, 14.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-38.0, 3.0, 60.0), Vector3(1.8, 0.0, -14.0), 0, Vector3(0.0, -24.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(38.0, 5.0, 60.0), Vector3(-1.8, 0.0, -14.0), 0, Vector3(0.0, 24.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, 14.0, 58.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, -4.0, 58.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-16.0, 10.0, 54.0), Vector3(0.8, 0.0, -14.0), 0, Vector3(0.0, -12.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(16.0, 10.0, 54.0), Vector3(-0.8, 0.0, -14.0), 0, Vector3(0.0, 12.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(-50.0, 7.0, 50.0), Vector3(2.5, 0.0, -16.0), 0, Vector3(0.0, -32.0, 0.0), 17.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(50.0, 2.0, 50.0), Vector3(-2.5, 0.0, -16.0), 0, Vector3(0.0, 32.0, 0.0), 17.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(-60.0, 4.0, 46.0), Vector3(3.5, 0.0, -18.0), 0, Vector3(0.0, -42.0, 0.0), 19.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(60.0, 8.0, 46.0), Vector3(-3.5, 0.0, -18.0), 0, Vector3(0.0, 42.0, 0.0), 19.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -72.0), Vector3(0.0, 0.0, 2.8), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(-24.0, 4.0, -70.0), Vector3(0.5, 0.0, 2.8), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(24.0, 4.0, -70.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-38.0, 6.0, -64.0), Vector3(0.8, 0.0, 3.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(38.0, 6.0, -64.0), Vector3(-0.8, 0.0, 3.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 14.0, -62.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-50.0, 3.0, -58.0), Vector3(1.2, 0.0, 3.5), 1, Vector3(0.0, 165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(50.0, 5.0, -58.0), Vector3(-1.2, 0.0, 3.5), 1, Vector3(0.0, -165.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(-16.0, 10.0, -56.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(16.0, 10.0, -56.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-60.0, 7.0, -50.0), Vector3(1.8, 0.0, 4.2), 1, Vector3(0.0, 150.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(60.0, 2.0, -50.0), Vector3(-1.8, 0.0, 4.2), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-26.0, -2.0, -48.0), Vector3(0.8, 0.0, 4.5), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(26.0, -2.0, -48.0), Vector3(-0.8, 0.0, 4.5), 1, Vector3(0.0, -170.0, 0.0)))

		"marea_stage_12":
			# ACT III // STAGE 12: The Grand Sovereign Armada -- Barlovento Ascendant (15 Corsair Ships vs 16 Supreme Enemies)
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, 70.0), Vector3(0.0, 0.0, -10.0), 0, Vector3.ZERO, 10.0))
			_player_ships.append(_spawn("marea_leviathan", Vector3(-22.0, 4.0, 68.0), Vector3(1.0, 0.0, -10.0), 0, Vector3(0.0, -14.0, 0.0), 10.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(22.0, 6.0, 68.0), Vector3(-1.0, 0.0, -13.0), 0, Vector3(0.0, 14.0, 0.0), 13.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-38.0, 4.0, 64.0), Vector3(1.8, 0.0, -14.0), 0, Vector3(0.0, -24.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_galleon", Vector3(38.0, 4.0, 64.0), Vector3(-1.8, 0.0, -14.0), 0, Vector3(0.0, 24.0, 0.0), 14.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, 14.0, 62.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, -4.0, 62.0), Vector3(0.0, 0.0, -8.0), 0, Vector3.ZERO, 8.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-15.0, 10.0, 58.0), Vector3(0.8, 0.0, -14.0), 0, Vector3(0.0, -12.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(15.0, 10.0, 58.0), Vector3(-0.8, 0.0, -14.0), 0, Vector3(0.0, 12.0, 0.0), 15.0))
			_player_ships.append(_spawn("marea_frigate", Vector3(0.0, 20.0, 56.0), Vector3(0.0, 0.0, -13.0), 0, Vector3.ZERO, 14.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(-50.0, 7.0, 52.0), Vector3(2.5, 0.0, -16.0), 0, Vector3(0.0, -32.0, 0.0), 17.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(50.0, 3.0, 52.0), Vector3(-2.5, 0.0, -16.0), 0, Vector3(0.0, 32.0, 0.0), 17.0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(-28.0, -2.0, 52.0), Vector3(1.2, 0.0, -15.0), 0, Vector3(0.0, -18.0, 0.0), 16.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(-60.0, 5.0, 48.0), Vector3(3.5, 0.0, -18.0), 0, Vector3(0.0, -42.0, 0.0), 19.0))
			_player_ships.append(_spawn("marea_cutter", Vector3(60.0, 7.0, 48.0), Vector3(-3.5, 0.0, -18.0), 0, Vector3(0.0, 42.0, 0.0), 19.0))

			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 6.0, -74.0), Vector3(0.0, 0.0, 2.6), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(-22.0, 8.0, -70.0), Vector3(0.5, 0.0, 2.8), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(22.0, 8.0, -70.0), Vector3(-0.5, 0.0, 2.8), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(0.0, 16.0, -68.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-38.0, 4.0, -66.0), Vector3(0.8, 0.0, 3.0), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(38.0, 4.0, -66.0), Vector3(-0.8, 0.0, 3.0), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_aegis", Vector3(-16.0, -3.0, -62.0), Vector3(0.5, 0.0, 3.0), 1, Vector3(0.0, 175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_aegis", Vector3(16.0, -3.0, -62.0), Vector3(-0.5, 0.0, 3.0), 1, Vector3(0.0, -175.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(-50.0, 3.0, -60.0), Vector3(1.2, 0.0, 3.2), 1, Vector3(0.0, 160.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(50.0, 3.0, -60.0), Vector3(-1.2, 0.0, 3.2), 1, Vector3(0.0, -160.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-30.0, 10.0, -56.0), Vector3(0.8, 0.0, 3.5), 1, Vector3(0.0, 170.0, 0.0)))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(30.0, 10.0, -56.0), Vector3(-0.8, 0.0, 3.5), 1, Vector3(0.0, -170.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(-60.0, 6.0, -52.0), Vector3(1.8, 0.0, 4.0), 1, Vector3(0.0, 150.0, 0.0)))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(60.0, 2.0, -52.0), Vector3(-1.8, 0.0, 4.0), 1, Vector3(0.0, -150.0, 0.0)))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(0.0, -6.0, -54.0), Vector3(0.0, 0.0, 3.0), 1, Vector3(0.0, 180.0, 0.0)))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(0.0, 18.0, -52.0), Vector3(0.0, 0.0, 4.2), 1, Vector3(0.0, 180.0, 0.0)))
		_:
			# Default fallback
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-6.0, 5.0, 55.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(6.0, 2.0, 54.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("marea_raider", Vector3(-6.0, 4.0, -55.0), Vector3(0.0, 0.0, 4.0), 1))

func _spawn(id: String, pos: Vector3, vel: Vector3, team: int, rot: Vector3 = Vector3.ZERO, target_spd: float = -1.0) -> Ship:
	var def := LoreDB.get_ship(id)
	var ship := Ship.new()
	ship.team = team
	ship.apply_def(def)
	ship.initial_velocity = vel
	ship.position = pos
	ship.rotation_degrees = rot
	ship.ether = ether
	if click_cb.is_valid():
		ship.clicked.connect(click_cb)
	if right_click_cb.is_valid():
		ship.right_clicked.connect(right_click_cb)
	world.add_child(ship)

	var forward_dir := -ship.global_transform.basis.z.normalized()
	var flat := Vector3(forward_dir.x, 0.0, forward_dir.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	ship.order.yaw = Vector3.FORWARD.signed_angle_to(flat, Vector3.UP)
	ship.order.pitch = clampf(asin(clampf(forward_dir.y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT)

	if target_spd >= 0.0:
		ship.order.target_speed = target_spd
	elif vel.length() > 0.5:
		ship.order.target_speed = vel.length()
	else:
		ship.order.target_speed = minf(10.0, ship.state.max_speed * 0.75)

	return ship

