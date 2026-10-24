extends Node3D

const TURN_SPEED := 2.2
const SPEED_STEP := 8.0
const PITCH_LIMIT := 1.15
const ENGAGEMENT_RANGE := 42.0

const StoryTransitionOverlay = preload("res://scripts/ui/story_transition_overlay.gd")

var _player_ships: Array[Ship] = []
var _enemy_ships: Array[Ship] = []
var _selected_ship: Ship
var _selected_index: int = 0
var _ace_target: Ship
var _ether: EtherField

var _camera_rig: CameraRig
var _tactical_grid: TacticalGrid
var _trajectory: TrajectoryPreview

var _stage_title_label: Label
var _objective_label: Label
var _cmd_port: TextureRect
var _phase_badge: Label
var _turn_label_prefix: Label
var _turn_label_phase: Label
var _weather_panel: HudWidgets.WeatherInitiativePanel
var _callout_overlay: HudWidgets.ShipCalloutOverlay
var _ace_top_banner: HudWidgets.AceTopBanner
var _roster_modal: HudWidgets.HeroRosterModal
var _combat_log_vbox: VBoxContainer
var _combat_logs: Array[String] = []

var _target_line_mesh: MeshInstance3D
var _target_line_immediate: ImmediateMesh
var _target_3d_reticle: Node3D
var _target_3d_label: Label3D
var _active_3d_beacon: Node3D
var _active_3d_label: Label3D

var _resolve_panel: PanelContainer
var _resolve_label: Label
var _resolve_bar: ProgressBar
var _order_panel: OrderPanel
var _ace_panel: AcePanel
var _help_overlay: Control
var _victory_overlay: Control
var _defeat_overlay: Control
var _story_overlay: Control
var _hud_theme: Theme
var _environment: EnvironmentDirector
var _vfx: CombatVfxManager
var _victory_dialog: BattleResultsOverlay.VictoryDialog
var _tutorial_controller: TutorialBanner
var _sluice_station_root: Node3D
var _is_vector_dragging: bool = false

var _mission_completed: bool = false
var _admiral_chart: AdmiralChart
var _admiral_layer: CanvasLayer
var _strategic_bonuses: Dictionary = {}

var _is_tutorial_stage: bool = false
var _tutorial_layer: CanvasLayer = null
var _tutorial_banner: PanelContainer = null
var _tutorial_step: int:
	get:
		return _tutorial_controller.current_step if _tutorial_controller != null else 0
	set(val):
		if _tutorial_controller != null:
			_tutorial_controller.set_step(val)

func _ready() -> void:
	TurnManager.reset()
	_setup_input_actions()

	_is_tutorial_stage = LoreDB.current_stage_id in ["acero_stage_1", "vinculados_stage_1", "marea_stage_1"]

	PhysicsSim.bounds = AABB(
		Vector3(-TacticalGrid.GRID_HALF_SPAN, -TacticalGrid.BOUNDS_HALF_HEIGHT, -TacticalGrid.GRID_HALF_SPAN),
		Vector3(TacticalGrid.GRID_HALF_SPAN * 2.0, TacticalGrid.BOUNDS_HALF_HEIGHT * 2.0, TacticalGrid.GRID_HALF_SPAN * 2.0)
	)

	_ether = EtherField.new()
	if LoreDB.current_stage_id == "acero_stage_2":
		_ether.direction = Vector3(0.85, 0.25, -0.45).normalized()
		_ether.strength = 2.1
		_ether.wavelength = 55.0
	elif LoreDB.current_stage_id == "acero_stage_3":
		_ether.direction = Vector3(-0.75, 0.18, 0.62).normalized()
		_ether.strength = 2.4
		_ether.wavelength = 50.0
	else:
		_ether.direction = Vector3(1.0, 0.2, 0.35).normalized()
		_ether.strength = 1.6
		_ether.wavelength = 65.0

	_build_environment()
	_build_camera()
	_environment = EnvironmentDirector.new()
	add_child(_environment)
	_environment.setup(LoreDB.current_stage_id, _ether)
	_vfx = CombatVfxManager.new()
	add_child(_vfx)
	_build_tactical_grid()
	_spawn_fleets()
	_build_trajectory_preview()
	_build_3d_targeting_hud()
	_build_hud()
	_set_selected(_player_ships[0])

	AudioManager.play_battle_music(-10.0, LoreDB.selected_faction, LoreDB.current_stage_id)
	AudioManager.start_ambient(-26.0)

	TurnManager.phase_changed.connect(_on_phase_changed)
	TurnManager.admiral_resolve_finished.connect(_on_admiral_resolve_finished)
	TurnManager.ace_resolve_finished.connect(_on_ace_resolve_finished)
	TurnManager.ace_fire_moment.connect(_on_ace_fire_moment)
	DevManager.god_mode_toggled.connect(func(enabled: bool) -> void:
		if enabled:
			_add_combat_log("⚡ DEV GOD MODE ACTIVATED: Damage Immunity + Auto-Targeting + Crushing Firepower!", Color(1.0, 0.85, 0.2))
		else:
			_add_combat_log("⚡ DEV GOD MODE DEACTIVATED: Standard Tactical Simulation Restored.", Color(0.7, 0.85, 1.0))
		_refresh_fleet_panel()
	)

	_on_phase_changed(TurnManager.phase)
	if SaveManager.pending_load_battle and SaveManager.has_tactical_save():
		SaveManager.pending_load_battle = false
		_load_battle_state()
		return

	match LoreDB.current_stage_id:
		# --- ARMADA OF ACERO (STAGES 1 - 12) ---
		"acero_stage_1":
			_add_combat_log("ACT I // STAGE 01 [TUTORIAL]: Sluice Station Well-09 under Corsair raid!", Color(1.0, 0.72, 0.28))
			_add_combat_log("Adm. Vane: \"Cadets, sound battle stations. Present heavy bow armor and cross their T!\"", Color(0.4, 0.92, 1.0))
			_add_combat_log("🎓 TUTORIAL ACTIVE: Follow the guided instructions above. Press [N] for Next Step.", Color(0.35, 1.0, 0.75))
		"acero_stage_2":
			_add_combat_log("ACT I // STAGE 02: Resonance Spire — Vinculados Choir Wing detected!", Color(0.85, 0.45, 1.0))
			_add_combat_log("Adm. Vane: \"Their mobile suits ride the crosswind. Use Weather-Gauge [BARLOVENTO] & broadsides!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_3":
			_add_combat_log("ACT I // STAGE 03: The Calm Threshold — Grand Coalition Fleet ahead!", Color(1.0, 0.45, 0.30))
			_add_combat_log("Adm. Vane: \"The Calm is behind us. Anchor the Anvil line — Steel Endures!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_4":
			_add_combat_log("ACT I // STAGE 04: Iron Gate Tertius — Corsair fast raiders attempting to breach the canal!", Color(1.0, 0.65, 0.25))
			_add_combat_log("Adm. Vane: \"Lock down the canal sluice! Deploy Pike-class torpedo escorts and seal the gorge!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_5":
			_add_combat_log("ACT II // STAGE 05: Siege of the Smuggler's Atoll — Heavy pirate fort detected in hollow caldera!", Color(1.0, 0.55, 0.20))
			_add_combat_log("Adm. Tarek: \"Bring up the Crucible Siege Monitors! Pulverize their outer asteroid parapets!\"", Color(1.0, 0.75, 0.30))
		"acero_stage_6":
			_add_combat_log("ACT II // STAGE 06: The Choir Intercept — Vinculados 5-voice swarm wing engaging at Mach vectors!", Color(0.75, 0.45, 1.0))
			_add_combat_log("Adm. Vane: \"Maintain defensive flak screening. Focus fire on the swarm leader!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_7":
			_add_combat_log("ACT II // STAGE 07: Operation Obsidian Anvil — Escorting Fleet Arsenal Carrier Forge-01 through dead seeps!", Color(0.60, 0.75, 1.0))
			_add_combat_log("Cmdr. Vance: \"Forge-01 engines cycling. Keep those corsair boarding skiffs off our flanks!\"", Color(0.8, 0.85, 0.95))
		"acero_stage_8":
			_add_combat_log("ACT II // STAGE 08: Clash at the Ferro-Magnetic Reef — Sensor telemetry completely scrambled!", Color(0.95, 0.35, 0.25))
			_add_combat_log("Adm. Vane: \"Optical aiming only! Close to point-blank broadside range and blast them with steel!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_9":
			_add_combat_log("ACT III // STAGE 09: Assault on Maelstrom Station — Corsair storm turbine fortress in the eye of the vortex!", Color(0.35, 0.85, 1.0))
			_add_combat_log("Adm. Vane: \"Surge the reaction thrusters! Break their turbine pylons and seize the atmospheric collector!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_10":
			_add_combat_log("ACT III // STAGE 10: Duel with the Colossus — Vinculados Mobile Armor Seraph-Prime detected!", Color(0.95, 0.40, 1.0))
			_add_combat_log("Adm. Vane: \"A colossal mobile armor... All spinal batteries, link fire! Bring down the titan!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_11":
			_add_combat_log("ACT III // STAGE 11: The Dying Tide — Final defense of the Great Sluice Dam!", Color(1.0, 0.40, 0.20))
			_add_combat_log("Adm. Vane: \"The entire coalition fleet charges the dam. If the wall falls, the Star Sea bleeds out! HOLD THE LINE!\"", Color(0.4, 0.92, 1.0))
		"acero_stage_12":
			_add_combat_log("ACT III // STAGE 12: Apex of Steel — Supreme Flagship Imperator deploying into the Calm Singularity!", Color(1.0, 0.85, 0.35))
			_add_combat_log("Grand Marshall Kurtz: \"Behold the pinnacle of Steel. We will dam entropy itself. STEEL ENDURES FOREVER!\"", Color(1.0, 0.70, 0.20))

		# --- LOS VINCULADOS (STAGES 1 - 12) ---
		"vinculados_stage_1":
			_add_combat_log("ACT I // STAGE 01 [TUTORIAL]: Sanctuary Spire Psalm-4 — Imperial extraction incursion!", Color(0.85, 0.45, 1.0))
			_add_combat_log("Conductor Seraph-2: \"Imperial miners have brought heavy cruisers to drill the sacred Choir well. Protect the Sanctuary Spire!\"", Color(0.65, 0.88, 1.0))
			_add_combat_log("Ace Kaelen-7: \"Harmonic link online. Our mobile suit wings out-turn their heavy ironclads. Slip into their rear quadrant for critical Stern Rakes!\"", Color(0.4, 0.92, 1.0))
			_add_combat_log("🎓 TUTORIAL ACTIVE: Follow the guided instructions above. Press [N] for Next Step.", Color(0.35, 1.0, 0.75))
		"vinculados_stage_2":
			_add_combat_log("ACT I // STAGE 02: The Crystal Chasm — Acero armored column descending into the trench!", Color(0.85, 0.45, 1.0))
			_add_combat_log("Conductor Seraph-2: \"We hold the upper celestial heights. Dive from altitude and strike their vulnerable topside deck armor!\"", Color(0.65, 0.88, 1.0))
		"vinculados_stage_3":
			_add_combat_log("ACT I // STAGE 03: Genesis Ring // Transcendence Threshold — Desperate enemy assault!", Color(0.95, 0.40, 1.0))
			_add_combat_log("Conductor Seraph-2: \"The Nous frame awakens! Protect the Genesis Ring until the resonance harmonizes!\"", Color(0.4, 0.92, 1.0))
		"vinculados_stage_4":
			_add_combat_log("ACT I // STAGE 04: Requiem of Outer Shrines — Psyche EW Diamond Wing taking point!", Color(0.55, 0.75, 1.0))
			_add_combat_log("Ace Lyra-3: \"Diamond formation locked. Activating broad-spectrum sensor jamming. Their railguns cannot acquire us!\"", Color(0.65, 0.88, 1.0))
		"vinculados_stage_5":
			_add_combat_log("ACT II // STAGE 05: Awakening of Seraph-Prime — Colossal Mobile Armor awakening across the fracture rift!", Color(0.95, 0.45, 1.0))
			_add_combat_log("Ascendant Mind Core: \"SOUL REACTOR CRITICAL... HARMONIC FUNNELS ACTIVE. ALL THREATS MARKED FOR TRANSCENDENCE.\"", Color(0.85, 0.35, 1.0))
		"vinculados_stage_6":
			_add_combat_log("ACT II // STAGE 06: Symphony of the 5-Voice Choir — Five harmonic vectors singing in unison!", Color(0.65, 0.90, 1.0))
			_add_combat_log("Conductor Trio: \"Five voices, one frequency. Synchronize beam convergence and dissolve their cruiser screens!\"", Color(0.75, 0.95, 1.0))
		"vinculados_stage_7":
			_add_combat_log("ACT II // STAGE 07: The Calm Abyss Trench — Dead Éther void zone!", Color(0.45, 0.50, 0.65))
			_add_combat_log("Ace Kaelen-7: \"The wind is dead here! Rely on internal soul-core reserve power! Don't let momentum stall!\"", Color(0.4, 0.92, 1.0))
		"vinculados_stage_8":
			_add_combat_log("ACT II // STAGE 08: Parley at the Astrolabe — Joint defensive pact with Corsair free captains!", Color(0.90, 0.80, 0.35))
			_add_combat_log("Capt. Solano: \"Good to fight by your wings, mechas! Screen our galleons and we'll shatter their iron with broadsides!\"", Color(1.0, 0.85, 0.35))
		"vinculados_stage_9":
			_add_combat_log("ACT III // STAGE 09: Shattering the Sluice Dam — The Imperial dam choking the Éther must fall!", Color(0.85, 0.45, 1.0))
			_add_combat_log("Ace Orin-9: \"Nous heavy choir cannons charged! Fire upon the dam gate hinges! Free the tide of the Star Sea!\"", Color(0.90, 0.60, 1.0))
		"vinculados_stage_10":
			_add_combat_log("ACT III // STAGE 10: Clash of Titans — Seraph-Prime vs Acero Supreme Juggernaut Imperator!", Color(1.0, 0.35, 0.35))
			_add_combat_log("Ascendant Mind Core: \"COLOSSUS ENGAGED. AUTONOMOUS FUNNELS FORMING CORONA FORMATION.\"", Color(0.95, 0.40, 1.0))
		"vinculados_stage_11":
			_add_combat_log("ACT III // STAGE 11: The Calm Singularity — The edge of total entropy!", Color(0.70, 0.30, 0.90))
			_add_combat_log("Conductor Seraph-2: \"The Calm is collapsing the sector! Channel all residual resonance into the Transcendence Gate!\"", Color(0.65, 0.88, 1.0))
		"vinculados_stage_12":
			_add_combat_log("ACT III // STAGE 12: Symphony of the Star Sea — All Choirs united for the Great Ascension!", Color(1.0, 0.90, 1.0))
			_add_combat_log("Ace Kaelen-7: \"The gateway opens! Sing, pilots of the Choir! We cross beyond the dying wind into eternity!\"", Color(0.4, 0.92, 1.0))

		# --- LA MAREA LIBRE (STAGES 1 - 12) ---
		"marea_stage_1":
			_add_combat_log("ACT I // STAGE 01 [TUTORIAL]: The Basalt Narrows — Imperial blockade bottling up the Haven!", Color(0.45, 0.95, 0.85))
			_add_combat_log("Capt. Solano: \"Unfurl the quantum sails, sea dogs! Catch the rapids of El Río del Viento, claim the Weather-Gauge [BARLOVENTO], and sweep their flanks with full broadsides!\"", Color(1.0, 0.85, 0.35))
			_add_combat_log("🎓 TUTORIAL ACTIVE: Follow the guided instructions above. Press [N] for Next Step.", Color(0.35, 1.0, 0.75))
		"marea_stage_2":
			_add_combat_log("ACT I // STAGE 02: Raid on Foundry Vulcan-3 — Imperial ore bastions ripe for the taking!", Color(1.0, 0.75, 0.25))
			_add_combat_log("Capt. Solano: \"Slip behind the smelter platforms! Use their own defense towers as cover and pillage the ether reserves!\"", Color(1.0, 0.85, 0.35))
		"marea_stage_3":
			_add_combat_log("ACT I // STAGE 03: The Maelstrom of Barlovento — The Great Grand Sol Corona vortex!", Color(0.35, 0.95, 1.0))
			_add_combat_log("Capt. Solano: \"The wind howls like the birth of creation! All hands to the sails! Ride the Maelstrom and break their dreadnoughts!\"", Color(1.0, 0.85, 0.35))
		"marea_stage_4":
			_add_combat_log("ACT I // STAGE 04: The Free Trader Convoy — Imperial pickets hunting merchant void-clippers!", Color(0.85, 0.70, 0.30))
			_add_combat_log("Capt. Solano: \"Form a screening wall! Deploy La Saeta to torpedo their lead corvettes before they open fire!\"", Color(1.0, 0.85, 0.35))
		"marea_stage_5":
			_add_combat_log("ACT II // STAGE 05: Prize of the 'Soberano' — Abandoned imperial super-galleon floating in asteroid graveyard!", Color(1.0, 0.80, 0.40))
			_add_combat_log("Quartermaster Vael: \"There she sits—the grandest hull in the fleet! Grapple her decks and clear out the automated security!\"", Color(0.9, 0.75, 0.35))
		"marea_stage_6":
			_add_combat_log("ACT II // STAGE 06: The Dead Reef Ambush — Dense radar-dead basalt dust!", Color(0.55, 0.85, 0.75))
			_add_combat_log("Capt. Moreau: \"Quiet running, engines cold. When the imperial ore convoy passes the reef gap... FULL BROADSIDE AMBUSH!\"", Color(0.8, 0.9, 0.7))
		"marea_stage_7":
			_add_combat_log("ACT II // STAGE 07: Siege of Fort Almirante — Imperial coastal defense citadel guarding the sea passage!", Color(1.0, 0.55, 0.20))
			_add_combat_log("Commodore Marina: \"Bring El Trueno into firing position! Arc plasma mortar shells over the outer bastion!\"", Color(1.0, 0.75, 0.30))
		"marea_stage_8":
			_add_combat_log("ACT II // STAGE 08: The Ghost Flotilla — Luminous nebula fog and phantom derelicts!", Color(0.40, 0.90, 0.85))
			_add_combat_log("Capt. Solano: \"Eyes sharp! Rogue drones are hiding among the wrecks! Stay in formation and surf the glowing currents!\"", Color(1.0, 0.85, 0.35))
		"marea_stage_9":
			_add_combat_log("ACT III // STAGE 09: The Triple Confluence — Three raging Éther rivers colliding at terminal velocity!", Color(0.35, 0.95, 1.0))
			_add_combat_log("Capt. Solano: \"Maximum speed! Trim the sails for +30 knots! Out-sail their battle line and rake them from stem to stern!\"", Color(1.0, 0.85, 0.35))
		"marea_stage_10":
			_add_combat_log("ACT III // STAGE 10: Breaking the Iron Citadel — Assault on Acero's forward naval base!", Color(1.0, 0.60, 0.25))
			_add_combat_log("Commodore Marina: \"All corsair squadrons converge! Crack their gantry gates and burn their drydocks!\"", Color(1.0, 0.75, 0.30))
		"marea_stage_11":
			_add_combat_log("ACT III // STAGE 11: Eye of Chaos — Maelstrom apex battle against both imperial armadas and the Calm!", Color(0.30, 0.90, 1.0))
			_add_combat_log("Capt. Solano: \"The storm is tearing reality apart! But a true sailor dances with the whirlwind! TO GLORY!\"", Color(1.0, 0.85, 0.35))
		"marea_stage_12":
			_add_combat_log("ACT III // STAGE 12: The Sovereign Ocean — The entire Star Sea reclaimed for freedom!", Color(1.0, 0.90, 0.40))
			_add_combat_log("Barbanegra: \"Unfurl the royal sails of the Soberano! As long as the wind blows, NO MAN OWNS THE SEA!\"", Color(1.0, 0.85, 0.35))
		_:
			_add_combat_log("Tactical link established. Outer Veil // Sector Psalm-4.", Color(0.4, 0.9, 1.0))
			_add_combat_log("Tip: Hold [SHIFT + Left-Click/Drag] on the 3D plane to aim vector & speed.", Color(1.0, 0.85, 0.3))

	# Auto-save initial tactical state at start of stage
	_save_battle_state(true)
	if _story_overlay != null:
		_story_overlay.show_intro(LoreDB.current_stage_id)
	else:
		_open_admiral_chart()

func _physics_process(delta: float) -> void:
	if not TurnManager.is_resolving():
		_handle_flight_controls(delta)
	else:
		var sim_delta := delta * PhysicsSim.time_scale
		_update_ai_tactical_behavior(sim_delta)
		if TurnManager.phase == TurnManager.Phase.ADMIRAL_RESOLVE:
			_check_engagement_transition()

func _process(delta: float) -> void:
	_environment.update(delta)
	_update_hud_telemetry()
	_update_3d_targeting_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _admiral_chart != null and _admiral_chart.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.is_action_pressed("resolve"):
				_admiral_chart.execute_strategic_turn()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_admiral_chart._trigger_3d_engagement()
			elif event.is_action_pressed("toggle_roster") and _roster_modal != null:
				_roster_modal.visible = not _roster_modal.visible
		return
	# Direct 3D Plane Vector Steering via Shift + Left-Click / Drag
	if not TurnManager.is_resolving():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and Input.is_key_pressed(KEY_SHIFT):
				_is_vector_dragging = true
				_apply_mouse_vector_steering(event.position, true)
				return
			elif not event.pressed and _is_vector_dragging:
				_is_vector_dragging = false
				return
		elif event is InputEventMouseMotion and _is_vector_dragging:
			if Input.is_key_pressed(KEY_SHIFT):
				_apply_mouse_vector_steering(event.position, false)
				return
			else:
				_is_vector_dragging = false

	if event is InputEventKey and event.echo:
		return
	if not event.is_pressed():
		return

	if event.is_action_pressed("quick_save"):
		_save_battle_state(false)
		return
	if event.is_action_pressed("quick_load"):
		_load_battle_state()
		return
	if event.is_action_pressed("help"):
		if _roster_modal != null and _roster_modal.visible:
			_roster_modal.visible = false
			return
		_toggle_help()
		return
	if event.is_action_pressed("toggle_roster"):
		if _roster_modal != null:
			_roster_modal.visible = not _roster_modal.visible
		return
	if event.is_action_pressed("toggle_grid"):
		if _tactical_grid != null:
			_tactical_grid.visible = not _tactical_grid.visible
		return
	if event.is_action_pressed("focus_ship"):
		_zoom_to_selected_ship()
		return

	if not TurnManager.is_resolving():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if TurnManager.is_in_ace():
				_handle_right_click_aim(event.position)
		elif event.is_action_pressed("cycle"):
			_cycle_selection()
		elif event.is_action_pressed("stop"):
			if _selected_ship != null:
				_selected_ship.order.target_speed = 0.0
		elif event.is_action_pressed("resolve"):
			_execute_current_phase()
		elif event.is_action_pressed("ace_cycle"):
			_cycle_hostile_target()
		elif event.is_action_pressed("intercept_target"):
			_intercept_target()
		elif event is InputEventKey and event.keycode == KEY_M:
			var track_title := AudioManager.next_battle_track(-10.0)
			_add_combat_log("♪ NOW PLAYING: %s" % track_title, Color(0.65, 0.9, 1.0))
		elif event is InputEventKey and event.keycode == KEY_Y:
			if _ace_panel != null:
				_ace_panel.toggle_weapon_arcs()
		elif event is InputEventKey and event.keycode == KEY_Z:
			if _ace_panel != null and _ace_panel.visible:
				_ace_panel.reset_all_ap()
		elif event is InputEventKey and event.keycode == KEY_U:
			if TurnManager.is_in_ace():
				_on_toggle_auto_pilot()
		elif event is InputEventKey and event.keycode == KEY_T:
			if _is_tutorial_stage and _tutorial_banner != null:
				_tutorial_banner.visible = not _tutorial_banner.visible
				AudioManager.play_sfx("ui_click", -10.0)
		elif _is_tutorial_stage and _tutorial_banner != null and _tutorial_banner.visible:
			if event is InputEventKey and event.keycode == KEY_N:
				if _tutorial_step >= 3:
					_tutorial_banner.visible = false
					_add_combat_log("🎓 Tutorial guide dismissed. Press [T] to re-open.", Color(0.4, 0.9, 1.0))
				else:
					_set_tutorial_step(_tutorial_step + 1)
			elif event is InputEventKey and event.keycode == KEY_B:
				_set_tutorial_step(_tutorial_step - 1)
			elif event is InputEventKey and event.keycode == KEY_X:
				_tutorial_banner.visible = false
				_add_combat_log("🎓 Tutorial guide dismissed. Press [T] to re-open.", Color(0.4, 0.9, 1.0))

func _handle_right_click_aim(screen_pos: Vector2) -> void:
	if _selected_ship == null or _selected_ship.is_destroyed():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var clicked_enemy: Ship = null
	var min_dist_px := 48.0
	for enemy in _enemy_ships:
		if enemy.is_destroyed():
			continue
		var unprojected := cam.unproject_position(enemy.global_position)
		var d := screen_pos.distance_to(unprojected)
		if d < min_dist_px:
			min_dist_px = d
			clicked_enemy = enemy

	if clicked_enemy != null:
		_ace_target = clicked_enemy
		_selected_ship.target_ship = clicked_enemy
		var to_tgt := clicked_enemy.global_position - _selected_ship.global_position
		_set_order_heading(_selected_ship, to_tgt.normalized())
		if _ace_panel != null:
			_ace_panel.target = clicked_enemy
		AudioManager.play_sfx("ui_hover", -6.0)
		_spawn_impact_flash(clicked_enemy.global_position, Color(1.0, 0.45, 0.25, 0.75))
		_add_combat_log("🎯 Target solution locked on %s (%s)!" % [clicked_enemy.pilot_name, clicked_enemy.ship_name], Color(0.35, 1.0, 0.75))
	else:
		var ray_origin := cam.project_ray_origin(screen_pos)
		var ray_dir := cam.project_ray_normal(screen_pos)
		if absf(ray_dir.y) > 0.001:
			var plane_y := _selected_ship.global_position.y
			var t := (plane_y - ray_origin.y) / ray_dir.y
			if t > 0.0:
				var hit_pos := ray_origin + ray_dir * t
				var dir := hit_pos - _selected_ship.global_position
				dir.y = 0.0
				if dir.length_squared() > 1.0:
					_set_order_heading(_selected_ship, dir.normalized())
					AudioManager.play_sfx("ui_click", -10.0)
					_spawn_impact_flash(hit_pos, Color(0.3, 0.85, 1.0, 0.5))

func _zoom_to_selected_ship() -> void:
	if _selected_ship == null or _camera_rig == null:
		return
	var is_mecha: bool = (_selected_ship.faction == "vinculados" and _selected_ship.ship_id != "vinculados_cradle")
	_camera_rig.focus_on_ship(_selected_ship.global_position, is_mecha, true)

func _apply_mouse_vector_steering(screen_pos: Vector2, play_feedback: bool) -> void:
	if _selected_ship == null or _selected_ship.is_destroyed():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var ray_origin := cam.project_ray_origin(screen_pos)
	var ray_dir := cam.project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 0.001:
		return
	var plane_y := _selected_ship.global_position.y
	var t := (plane_y - ray_origin.y) / ray_dir.y
	if t <= 0.0:
		return
	var hit_pos := ray_origin + ray_dir * t
	var delta_vec := hit_pos - _selected_ship.global_position
	delta_vec.y = 0.0
	var dist := delta_vec.length()
	if dist < 1.0:
		return

	_set_order_heading(_selected_ship, delta_vec.normalized())
	var max_drag_dist := 55.0 if not TurnManager.is_in_ace() else 28.0
	var speed_ratio := clampf(dist / max_drag_dist, 0.15, 1.0)
	_selected_ship.order.target_speed = roundf(speed_ratio * _selected_ship.state.max_speed * 2.0) * 0.5

	if play_feedback:
		AudioManager.play_sfx("ui_hover", -10.0)
		_spawn_impact_flash(hit_pos, Color(0.3, 0.95, 1.0, 0.6))

func _handle_flight_controls(delta: float) -> void:
	if _selected_ship == null or (_admiral_chart != null and _admiral_chart.visible):
		return

	var order := _selected_ship.order

	# Yaw (Left / Right)
	if Input.is_action_pressed("yaw_left"):
		order.yaw += TURN_SPEED * delta
	if Input.is_action_pressed("yaw_right"):
		order.yaw -= TURN_SPEED * delta

	# Pitch (Up / Down)
	if Input.is_action_pressed("pitch_up"):
		order.pitch = clampf(order.pitch + TURN_SPEED * delta, -PITCH_LIMIT, PITCH_LIMIT)
	if Input.is_action_pressed("pitch_down"):
		order.pitch = clampf(order.pitch - TURN_SPEED * delta, -PITCH_LIMIT, PITCH_LIMIT)

	# Speed (Forward / Reverse Throttle)
	if Input.is_action_pressed("move_forward"):
		order.target_speed = clampf(order.target_speed + SPEED_STEP * delta, 0.0, _selected_ship.state.max_speed)
	if Input.is_action_pressed("move_back"):
		order.target_speed = clampf(order.target_speed - SPEED_STEP * delta, 0.0, _selected_ship.state.max_speed)

func _execute_current_phase() -> void:
	if TurnManager.phase == TurnManager.Phase.ADMIRAL_PLAN:
		if DevManager.god_mode:
			_plan_god_mode_admiral()
		_plan_ai_orders()
		AudioManager.play_sfx("ui_click", -12.0)
		_add_combat_log("Executing strategic WEGO fleet resolution (%ds)..." % int(TurnManager.admiral_resolution_window), Color(0.3, 1.0, 0.6))
		TurnManager.start_resolve()
	elif TurnManager.phase == TurnManager.Phase.ACE_PLAN:
		_execute_ace_round()

func _plan_god_mode_admiral() -> void:
	FleetTacticalAI.plan_god_mode_admiral(_player_ships, _enemy_ships)

func _execute_ace_round() -> void:
	_plan_friendly_ai_orders()
	_plan_ai_tactical_orders()
	AudioManager.play_sfx("ui_click", -10.0)
	_add_combat_log(">>> EXECUTING TACTICAL ROUND %d (ALL UNITS ENGAGING) <<<" % TurnManager.ace_round, Color(0.35, 1.0, 0.75))
	TurnManager.start_ace_resolve()

func _plan_friendly_ai_orders() -> void:
	for ally in _player_ships:
		if ally.is_destroyed():
			continue
		if ally.is_auto_pilot or DevManager.god_mode:
			_plan_friendly_ship_ai(ally)

func _clear_round_combat_metas(ship: Ship) -> void:
	if ship == null:
		return
	ship.remove_meta("prow_angle_active")
	ship.remove_meta("flak_screen_active")
	ship.remove_meta("precision_boost")
	ship.remove_meta("resonance_pierce")
	ship.remove_meta("evasive_boost")
	ship.remove_meta("chain_shot_active")
	ship.remove_meta("harpoon_active")
	ship.remove_meta("broadside_active")

func _plan_friendly_ship_ai(ship: Ship) -> void:
	if ship == null or ship.is_destroyed():
		return

	if DevManager.god_mode or DevManager.infinite_ap:
		ship.action_points = ship.max_action_points
		if _ace_panel != null:
			_ace_panel.reset_all_ap()

	# 1. Target: tunnel vision on closest enemy threat
	var target := _nearest_enemy_for(ship)
	if target == null or target.is_destroyed():
		return
	ship.target_ship = target

	# 2. Heading: center of mass, direct line toward target (no intentional stern rake hunting)
	var to_target := target.global_position - ship.global_position
	if to_target.length_squared() > 0.01:
		_set_order_heading(ship, to_target.normalized())

	# 3. Speed: aggressive in god mode, conservative otherwise
	var dist := ship.state.position.distance_to(target.state.position)
	if DevManager.god_mode:
		ship.order.target_speed = ship.state.max_speed * 0.85 if dist > 22.0 else 8.0
		ship.stance = Ship.Stance.FIRE
	elif dist > ship.weapon_range:
		ship.order.target_speed = ship.state.max_speed * 0.60
		ship.stance = Ship.Stance.FIRE
	elif dist > 16.0:
		ship.order.target_speed = 3.5
		ship.stance = Ship.Stance.FIRE
	else:
		ship.order.target_speed = 1.5
		ship.stance = Ship.Stance.EVASIVE if ship.hp < ship.max_hp * 0.35 else Ship.Stance.FIRE

	# 4. Tactical Abilities
	_clear_round_combat_metas(ship)
	var fac := ship.faction
	if DevManager.god_mode:
		match fac:
			"acero":
				ship.set_meta("broadside_active", true)
				ship.set_meta("prow_angle_active", true)
			"vinculados":
				ship.set_meta("resonance_pierce", true)
				ship.set_meta("precision_boost", true)
			"marea_libre":
				ship.set_meta("broadside_active", true)
				ship.set_meta("chain_shot_active", true)
	elif ship.hp < ship.max_hp * 0.35:
		match fac:
			"acero":
				ship.set_meta("flak_screen_active", true)
			"vinculados":
				ship.set_meta("evasive_boost", true)
			"marea_libre":
				ship.set_meta("evasive_boost", true)
	else:
		match fac:
			"acero":
				if dist > 25.0:
					ship.set_meta("prow_angle_active", true)
				else:
					ship.set_meta("broadside_active", true)
			"vinculados":
				if dist > 28.0:
					ship.set_meta("precision_boost", true)
				else:
					ship.set_meta("resonance_pierce", true)
			"marea_libre":
				if dist > 25.0:
					ship.set_meta("chain_shot_active", true)
				else:
					ship.set_meta("broadside_active", true)

func _on_toggle_auto_pilot() -> void:
	if _selected_ship == null or _selected_ship.is_destroyed():
		return
	_selected_ship.is_auto_pilot = not _selected_ship.is_auto_pilot
	if _selected_ship.is_auto_pilot:
		_plan_friendly_ship_ai(_selected_ship)
		AudioManager.play_sfx("ui_click", -6.0)
		_add_combat_log("🤖 %s: Tactical Autopilot ENGAGED (Support Mode)." % _selected_ship.ship_name, Color(0.4, 0.95, 0.7))
	else:
		_clear_round_combat_metas(_selected_ship)
		AudioManager.play_sfx("ui_hover", -6.0)
		_add_combat_log("🤖 %s: Tactical Autopilot DISENGAGED (Manual Control)." % _selected_ship.ship_name, Color(0.7, 0.85, 0.95))
	if _ace_panel != null:
		_ace_panel.refresh()
	_refresh_fleet_panel()

func _predict_target_pos(target: Ship, lead_time: float) -> Vector3:
	return FleetTacticalAI.predict_target_pos(target, lead_time)

func _compute_tactical_heading(ship: Ship, target: Ship, lead_time: float) -> Vector3:
	return FleetTacticalAI.compute_tactical_heading(ship, target, lead_time)

func _set_order_heading(ship: Ship, direction: Vector3) -> void:
	FleetTacticalAI.set_order_heading(ship, direction)

func _plan_ai_orders() -> void:
	FleetTacticalAI.plan_ai_orders(_enemy_ships, _player_ships)

func _plan_ai_tactical_orders() -> void:
	FleetTacticalAI.plan_ai_tactical_orders(_enemy_ships, _player_ships, _is_tutorial_stage)

func _on_ace_fire_moment() -> void:
	_add_combat_log("Weapons batteries opening fire across tactical envelope!", Color(1.0, 0.85, 0.3))

	# 1. Player Ace & squadron fire
	for player in _player_ships:
		if player.is_destroyed():
			continue

		var target := player.target_ship if player.target_ship != null else _ace_target
		if target == null or target.is_destroyed():
			target = _nearest_enemy_for(player)

		if target != null and not target.is_destroyed() and player.stance != Ship.Stance.EVASIVE:
			if Combat.can_hit(player, target):
				var result := Combat.resolve_shot(player, target)
				var is_cradle: bool = (player.ship_id == "vinculados_cradle")
				var beam_color := Color(0.88, 0.45, 1.0) if is_cradle else Color(0.35, 0.95, 1.0)
				_spawn_laser_beam(player.global_position, target.global_position, beam_color, is_cradle)
				_spawn_impact_flash(target.global_position, beam_color)

				if _camera_rig != null:
					_camera_rig.shake(1.35 if is_cradle else 0.85, 0.28 if is_cradle else 0.22)

				if result.hit:
					var quad_tag := " [%s]" % result.quadrant
					if result.quadrant == "STERN":
						quad_tag = " 💥 [STERN RAKE!]"
					elif result.critical:
						quad_tag = " 💥 [CRIT %s!]" % result.quadrant
					if result.get("weather_gauge", false):
						quad_tag += " 🌬[BARLOVENTO]"
					_spawn_combat_text(target.global_position, "-%.0f HP%s" % [result.damage, quad_tag], Color(1.0, 0.85, 0.2) if result.critical else Color(0.3, 1.0, 0.55))
					_add_combat_log("%s hit %s%s for %.0f DMG" % [player.ship_name, target.ship_name, quad_tag, result.damage], Color(0.3, 1.0, 0.55))
					if result.destroyed:
						_add_combat_log(">>> %s DESTROYED!" % target.ship_name, Color(1.0, 0.4, 0.2))
				else:
					var reason := "EVADED!" if result.evaded else "MISSED!"
					_spawn_combat_text(target.global_position, reason, Color(0.4, 0.9, 1.0))
					_add_combat_log("%s fired at %s (%s)" % [player.ship_name, target.ship_name, reason.to_lower()], Color(0.7, 0.8, 1.0))

	# 2. Hostile fleet fires back
	for enemy in _enemy_ships:
		if enemy.is_destroyed():
			continue

		var target := enemy.target_ship if enemy.target_ship != null else _nearest_player_ship(enemy)
		if target != null and not target.is_destroyed() and enemy.stance != Ship.Stance.EVASIVE:
			if Combat.can_hit(enemy, target):
				var result := Combat.resolve_shot(enemy, target)
				var enemy_is_cradle: bool = (enemy.ship_id == "vinculados_cradle")
				var beam_color := Color(0.92, 0.40, 1.0) if enemy_is_cradle else Color(1.0, 0.4, 0.2)
				_spawn_laser_beam(enemy.global_position, target.global_position, beam_color, enemy_is_cradle)
				_spawn_impact_flash(target.global_position, beam_color)

				if _camera_rig != null:
					_camera_rig.shake(1.35 if enemy_is_cradle else 0.9, 0.28 if enemy_is_cradle else 0.24)

				if result.hit:
					var quad_tag := " [%s]" % result.quadrant
					if result.get("weather_gauge", false):
						quad_tag += " 🌬[UPWIND]"
					_spawn_combat_text(target.global_position, "-%.0f HP%s" % [result.damage, quad_tag], Color(1.0, 0.35, 0.2))
					_add_combat_log("[ENEMY] %s hit %s%s for %.0f DMG" % [enemy.ship_name, target.ship_name, quad_tag, result.damage], Color(1.0, 0.45, 0.35))
					if result.destroyed:
						_add_combat_log(">>> ALLIED SHIP %s DESTROYED!" % target.ship_name, Color(1.0, 0.2, 0.2))
				else:
					var reason := "EVADED!" if result.evaded else "MISSED!"
					_spawn_combat_text(target.global_position, reason, Color(0.4, 0.9, 1.0))
					_add_combat_log("[ENEMY] %s shot at %s %s" % [enemy.ship_name, target.ship_name, reason.to_lower()], Color(0.7, 0.8, 1.0))

	_refresh_fleet_panel()
	_check_stage_objectives()

func _on_ace_resolve_finished() -> void:
	for p in _player_ships:
		_clear_round_combat_metas(p)
	_refresh_fleet_panel()
	_add_combat_log("Tactical round %d resolved. Re-assessing tactical vectors." % (TurnManager.ace_round - 1), Color(0.35, 0.95, 1.0))
	_advance_calm_wavefront()
	_apply_calm_hazards()
	_check_stage_objectives()
	if not _mission_completed:
		_update_round_banner()
		_tick_strategic_barlovento()
		_save_battle_state(true)

func _advance_calm_wavefront() -> void:
	var tw := create_tween().set_parallel(true)
	var avg_growth: float = _environment.advance_calm_wavefront(tw)
	if avg_growth > 0.0:
		_add_combat_log("🌊 THE CALM DILATES: Dimensional fluid seeps expand (+%.1fm across flanks)!" % avg_growth, Color(0.85, 0.45, 0.98))
		AudioManager.play_sfx("shield", -10.0)

func _is_point_in_calm(pos: Vector3) -> Dictionary:
	return _environment.is_point_in_calm(pos)

func _apply_calm_hazards() -> void:
	var any_becalmed := false

	# 1. Player squadron check
	for p in _player_ships:
		if p == null or p.is_destroyed():
			continue
		var check := _is_point_in_calm(p.global_position)
		if check["in_calm"]:
			any_becalmed = true
			var seep_info: Dictionary = check["seep"]
			var s_name: String = seep_info.get("name", "The Calm")
			# Engines stall without Éther gradient
			p.order.target_speed = minf(p.order.target_speed, p.state.max_speed * 0.45)
			p.state.velocity *= 0.80
			# Shield decay / hull corrosion
			if p.shield_hp > 0.0:
				p.shield_hp = maxf(p.shield_hp - 15.0, 0.0)
				_spawn_combat_text(p.global_position, "⚠ BECALMED (-15 SHLD)", Color(0.85, 0.40, 0.95))
			else:
				p.hp = maxf(p.hp - 10.0, 1.0)
				_spawn_combat_text(p.global_position, "⚠ BECALMED (-10 HULL)", Color(0.95, 0.35, 0.45))
			p.refresh_after_load()
			_add_combat_log("⚠ %s is BECALMED in %s! Propulsion stalled & shields decaying!" % [p.ship_name, s_name], Color(0.95, 0.40, 0.90))

	# 2. Hostile fleet check (tactical reward: pushing hostiles into the Calm)
	for e in _enemy_ships:
		if e == null or e.is_destroyed():
			continue
		var check := _is_point_in_calm(e.global_position)
		if check["in_calm"]:
			any_becalmed = true
			var seep_info: Dictionary = check["seep"]
			var s_name: String = seep_info.get("name", "The Calm")
			e.order.target_speed = minf(e.order.target_speed, e.state.max_speed * 0.40)
			e.state.velocity *= 0.75
			if e.shield_hp > 0.0:
				e.shield_hp = maxf(e.shield_hp - 15.0, 0.0)
				_spawn_combat_text(e.global_position, "⚠ BECALMED (-15 SHLD)", Color(0.85, 0.40, 0.95))
			else:
				e.hp = maxf(e.hp - 10.0, 1.0)
				_spawn_combat_text(e.global_position, "⚠ BECALMED (-10 HULL)", Color(0.95, 0.35, 0.45))
			e.refresh_after_load()
			_add_combat_log("💨 Hostile %s is BECALMED inside %s! Sails slack & shields eroding!" % [e.ship_name, s_name], Color(0.85, 0.55, 0.95))

	if any_becalmed:
		_refresh_fleet_panel()

func _on_admiral_resolve_finished() -> void:
	_refresh_fleet_panel()
	_apply_calm_hazards()
	_add_combat_log("Strategic WEGO movement cycle complete.", Color(0.35, 0.9, 1.0))
	if _fleets_in_range():
		_add_combat_log("Combat envelope reached! Transitioning to Ace tactical phase.", Color(1.0, 0.8, 0.3))
		_engage_ace_mode()
	if not _mission_completed:
		_save_battle_state(true)

func _engage_ace_mode() -> void:
	AudioManager.play_sfx("ui_hover", -8.0)
	TurnManager.start_ace_mode()
	_set_selected(_player_ships[0])
	_ace_target = _enemy_ships[0]
	_update_round_banner()
	if _is_tutorial_stage and _tutorial_banner != null and _tutorial_step == 0:
		_set_tutorial_step(1)
		_tutorial_banner.visible = true

func _cycle_selection() -> void:
	if _player_ships.is_empty():
		return
	for _attempt in range(_player_ships.size()):
		_selected_index = (_selected_index + 1) % _player_ships.size()
		if not _player_ships[_selected_index].is_destroyed():
			_set_selected(_player_ships[_selected_index])
			return

func _set_selected(ship: Ship) -> void:
	for candidate in _player_ships:
		candidate.selected = candidate == ship
	_selected_ship = ship

	if _cmd_port != null and ship != null:
		var p_path := LoreDB.get_portrait_for_ship(ship.ship_id)
		if p_path != "" and ResourceLoader.exists(p_path):
			_cmd_port.texture = load(p_path)

	if _tactical_grid != null:
		_tactical_grid.selected_ship = ship

	if _order_panel != null:
		_order_panel.ship = ship

	if _ace_panel != null:
		_ace_panel.ship = ship
		_ace_panel.target = _ace_target

	_refresh_fleet_panel()

func _cycle_hostile_target() -> void:
	var alive: Array[Ship] = []
	for candidate in _enemy_ships:
		if not candidate.is_destroyed():
			alive.append(candidate)
	if alive.is_empty():
		_ace_target = null
	else:
		var index := alive.find(_ace_target)
		_ace_target = alive[(index + 1) % alive.size()]
	if _tactical_grid != null:
		_tactical_grid.target_ship = _ace_target
	if _ace_panel != null:
		_ace_panel.target = _ace_target
	if _selected_ship != null:
		_selected_ship.target_ship = _ace_target

	_refresh_fleet_panel()
	if _ace_target != null:
		AudioManager.play_sfx("ui_hover", -6.0)
		_add_combat_log("Target locked: %s [%s]" % [_ace_target.ship_name, _ace_target.pilot_name], Color(1.0, 0.75, 0.35))

func _on_ship_clicked(clicked_ship: Ship) -> void:
	AudioManager.play_sfx("ui_click", -10.0)
	if clicked_ship.team == 1:
		_ace_target = clicked_ship
		if _tactical_grid != null:
			_tactical_grid.target_ship = clicked_ship
		if _ace_panel != null:
			_ace_panel.target = clicked_ship
		if _selected_ship != null:
			_selected_ship.target_ship = clicked_ship
		_refresh_fleet_panel()
		_add_combat_log("Hostile targeted: %s [%s]" % [clicked_ship.ship_name, clicked_ship.pilot_name], Color(1.0, 0.65, 0.3))
	else:
		if _selected_ship == clicked_ship:
			_zoom_to_selected_ship()
		else:
			_set_selected(clicked_ship)
			_add_combat_log("Selected unit: %s" % clicked_ship.ship_name, Color(0.35, 1.0, 0.6))
			if _admiral_chart != null and _admiral_chart.visible:
				var s_idx := _player_ships.find(clicked_ship)
				if s_idx != -1:
					_admiral_chart.set_selected_unit(s_idx)

func _on_ship_right_clicked(clicked_ship: Ship) -> void:
	if clicked_ship.team == 1:
		_ace_target = clicked_ship
		if _tactical_grid != null:
			_tactical_grid.target_ship = clicked_ship
		if _ace_panel != null:
			_ace_panel.target = clicked_ship
		if _selected_ship != null:
			_selected_ship.target_ship = clicked_ship
		_intercept_target()
		_refresh_fleet_panel()

func _intercept_target() -> void:
	if _selected_ship == null or _selected_ship.is_destroyed():
		return
	if _ace_target == null or _ace_target.is_destroyed():
		_cycle_hostile_target()
	if _ace_target == null:
		return

	var to_target := _ace_target.state.position - _selected_ship.state.position
	if to_target.length_squared() > 0.01:
		_set_order_heading(_selected_ship, to_target.normalized())
		if _selected_ship.order.target_speed < 4.0:
			_selected_ship.order.target_speed = clampf(_selected_ship.state.max_speed * 0.70, 8.0, _selected_ship.state.max_speed)
		AudioManager.play_sfx("ui_click", -8.0)
		_add_combat_log("🎯 %s: Intercept vector locked on %s (SPD %.1f m/s)" % [
			_selected_ship.ship_name, _ace_target.ship_name, _selected_ship.order.target_speed
		], Color(1.0, 0.85, 0.35))

func _on_ace_ability_toggled(ability_name: String, is_active: bool) -> void:
	if _selected_ship == null or _selected_ship.is_destroyed():
		return
	match ability_name:
		# Acero Abilities
		"prow_angle":
			if is_active:
				_selected_ship.set_meta("prow_angle_active", true)
				if _ace_target != null:
					_set_order_heading(_selected_ship, (_ace_target.global_position - _selected_ship.global_position).normalized())
				AudioManager.play_sfx("ui_hover", -6.0)
				_add_combat_log("🛡 %s: Prow Armor Angled toward target! (+40%% Bow Absorption)" % _selected_ship.ship_name, Color(1.0, 0.85, 0.35))
			else:
				_selected_ship.remove_meta("prow_angle_active")
				_add_combat_log("↩ %s: Prow Angle disarmed" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		"flak_screen":
			if is_active:
				_selected_ship.set_meta("flak_screen_active", true)
				AudioManager.play_sfx("laser_heavy", -10.0)
				_add_combat_log("💥 %s: Point-Defense Flak Screen active! (-25%% Incoming Enemy Hit Chance)" % _selected_ship.ship_name, Color(1.0, 0.70, 0.30))
			else:
				_selected_ship.remove_meta("flak_screen_active")
				_add_combat_log("↩ %s: Flak Screen disarmed" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		"furnace_burn":
			if is_active:
				_selected_ship.order.target_speed = clampf(_selected_ship.order.target_speed + 4.5, 0.0, _selected_ship.state.max_speed)
				AudioManager.play_sfx("engine", -6.0)
				_add_combat_log("🔥 %s: Emergency Furnace Burn! (+4.5 m/s surge)" % _selected_ship.ship_name, Color(1.0, 0.55, 0.20))
			else:
				_selected_ship.order.target_speed = clampf(_selected_ship.order.target_speed - 4.5, 0.0, _selected_ship.state.max_speed)
				_add_combat_log("↩ %s: Furnace Burn disarmed (-4.5 m/s)" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		# Vinculados Abilities
		"snap_pivot":
			if is_active:
				if _ace_target != null:
					_set_order_heading(_selected_ship, (_ace_target.global_position - _selected_ship.global_position).normalized())
				AudioManager.play_sfx("engine", -8.0)
				_add_combat_log("⚡ %s: Vernier Snap-Pivot executed! Torso locked on target." % _selected_ship.ship_name, Color(0.35, 0.95, 1.0))
			else:
				_add_combat_log("↩ %s: Snap-Pivot disarmed" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		"soul_lock":
			if is_active:
				_selected_ship.set_meta("precision_boost", true)
				AudioManager.play_sfx("ui_hover", -6.0)
				_add_combat_log("✨ %s: Neural Soul Lock established! (+25%% Hit Accuracy)" % _selected_ship.ship_name, Color(0.85, 0.45, 1.0))
			else:
				_selected_ship.remove_meta("precision_boost")
				_add_combat_log("↩ %s: Soul Lock disarmed" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		"beam_lance":
			if is_active:
				_selected_ship.set_meta("resonance_pierce", true)
				AudioManager.play_sfx("laser_pulse", -6.0)
				_add_combat_log("⚔ %s: Resonance Beam Lance charged! (Pierces 50%% Target Armor & +30%% DMG)" % _selected_ship.ship_name, Color(0.35, 0.95, 1.0))
			else:
				_selected_ship.remove_meta("resonance_pierce")
				_add_combat_log("↩ %s: Beam Lance disarmed" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		"phase_dodge":
			if is_active:
				_selected_ship.stance = Ship.Stance.EVASIVE
				_selected_ship.set_meta("evasive_boost", true)
				AudioManager.play_sfx("engine", -8.0)
				_add_combat_log("💨 %s: High-G Phase Dodge armed! (+35%% Evasion)" % _selected_ship.ship_name, Color(0.40, 0.95, 1.0))
			else:
				_selected_ship.stance = Ship.Stance.NEUTRAL
				_selected_ship.remove_meta("evasive_boost")
				_add_combat_log("↩ %s: Phase Dodge disarmed" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))
			_refresh_fleet_panel()

		# Marea Libre Abilities
		"trim_sails":
			if is_active:
				if _selected_ship.ether != null:
					var cur := _selected_ship.ether.current_at(_selected_ship.global_position)
					if cur.length_squared() > 0.01:
						_set_order_heading(_selected_ship, cur.normalized())
				_selected_ship.order.target_speed = clampf(_selected_ship.order.target_speed + 3.5, 0.0, _selected_ship.state.max_speed)
				AudioManager.play_sfx("ui_hover", -6.0)
				_add_combat_log("💨 %s: Quantum Sails Trimmed! (+3.5 m/s free speed along wind gradient)" % _selected_ship.ship_name, Color(0.35, 1.0, 0.85))
			else:
				_selected_ship.order.target_speed = clampf(_selected_ship.order.target_speed - 3.5, 0.0, _selected_ship.state.max_speed)
				_add_combat_log("↩ %s: Sails re-centered" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		"oar_sweep":
			if is_active:
				var flat_fwd := Vector3(_selected_ship.state.forward.x, 0.0, _selected_ship.state.forward.z).normalized()
				var swept := flat_fwd.rotated(Vector3.UP, deg_to_rad(45.0))
				_set_order_heading(_selected_ship, swept)
				AudioManager.play_sfx("engine", -8.0)
				_add_combat_log("⚓ %s: Éther Oar Sweep! (Sharp 45° hull pivot for broadside alignment)" % _selected_ship.ship_name, Color(0.95, 0.85, 0.35))
			else:
				_add_combat_log("↩ %s: Oar Sweep finished" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		"chain_shot":
			if is_active:
				_selected_ship.set_meta("chain_shot_active", true)
				AudioManager.play_sfx("laser_cannon", -6.0)
				_add_combat_log("⛓ %s: Plasma Chain-Shot loaded! (Disrupts target propulsion on hit)" % _selected_ship.ship_name, Color(0.95, 0.75, 0.30))
			else:
				_selected_ship.remove_meta("chain_shot_active")
				_add_combat_log("↩ %s: Chain-Shot disarmed" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		"harpoon":
			if is_active:
				_selected_ship.set_meta("harpoon_active", true)
				if _ace_target != null:
					_intercept_target()
				AudioManager.play_sfx("ui_hover", -6.0)
				_add_combat_log("🪝 %s: Boarding Harpoon armed! (Tethers to locked target)" % _selected_ship.ship_name, Color(0.95, 0.65, 0.25))
			else:
				_selected_ship.remove_meta("harpoon_active")
				_add_combat_log("↩ %s: Harpoon disarmed" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))

		# Common Shared Abilities
		"broadside":
			if is_active:
				_selected_ship.stance = Ship.Stance.FIRE
				_selected_ship.set_meta("precision_boost", true)
				_selected_ship.set_meta("broadside_active", true)
				AudioManager.play_sfx("ui_hover", -6.0)
				_add_combat_log("🎯 %s: Heavy Broadside Battery armed (+25%% Kinetic DMG, FIRE Stance)" % _selected_ship.ship_name, Color(0.35, 1.0, 0.85))
			else:
				_selected_ship.stance = Ship.Stance.NEUTRAL
				_selected_ship.remove_meta("precision_boost")
				_selected_ship.remove_meta("broadside_active")
				_add_combat_log("↩ %s: Broadside disarmed (NEUTRAL Stance)" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))
			_refresh_fleet_panel()

		"shield_pulse":
			if is_active:
				_selected_ship.shield_hp = minf(_selected_ship.shield_hp + 40.0, _selected_ship.max_shield_hp)
				_selected_ship.hp = minf(_selected_ship.hp + 20.0, _selected_ship.max_hp)
				_selected_ship.refresh_after_load()
				AudioManager.play_sfx("shield", -8.0)
				_add_combat_log("🛡 %s: Deflector barriers & bulkheads reinforced (+40 SHLD / +20 HULL)" % _selected_ship.ship_name, Color(0.3, 1.0, 0.6))
			else:
				_selected_ship.shield_hp = maxf(_selected_ship.shield_hp - 40.0, 0.0)
				_selected_ship.hp = maxf(_selected_ship.hp - 20.0, 1.0)
				_selected_ship.refresh_after_load()
				_add_combat_log("↩ %s: Barrier reinforcement disarmed" % _selected_ship.ship_name, Color(0.75, 0.85, 0.95))
			_refresh_fleet_panel()

func _on_ace_ability_used(ability_name: String) -> void:
	if _selected_ship == null or _selected_ship.is_destroyed():
		return
	match ability_name:
		"oar_burst":
			AudioManager.play_sfx("engine", -8.0)
			_add_combat_log("⚡ %s: Thruster / Oar Burst engaged! (Target SPD %.1f m/s)" % [_selected_ship.ship_name, _selected_ship.order.target_speed], Color(0.35, 0.95, 1.0))
		"precision":
			_selected_ship.set_meta("precision_boost", true)
			AudioManager.play_sfx("ui_hover", -6.0)
			_add_combat_log("🎯 %s: Fire control calibrated (+25%% Hit Accuracy & +15%% Salvo DMG)" % _selected_ship.ship_name, Color(0.35, 1.0, 0.85))
		"retro_brake":
			_selected_ship.order.target_speed = maxf(_selected_ship.order.target_speed - 8.0, 0.0)
			_selected_ship.state.velocity *= 0.4
			AudioManager.play_sfx("engine", -8.0)
			_add_combat_log("💨 %s: RCS Retro-Burn fired! (Drift arrested to %.1f m/s, +35%% Evasion)" % [_selected_ship.ship_name, _selected_ship.speed()], Color(0.4, 0.9, 1.0))
		"shield_pulse":
			_selected_ship.shield_hp = minf(_selected_ship.shield_hp + 40.0, _selected_ship.max_shield_hp)
			_selected_ship.hp = minf(_selected_ship.hp + 20.0, _selected_ship.max_hp)
			_selected_ship.refresh_after_load()
			AudioManager.play_sfx("shield", -8.0)
			_add_combat_log("🛡 %s: Deflector barriers overcharged (+40 SHLD / +20 HULL)" % _selected_ship.ship_name, Color(0.3, 1.0, 0.6))
			_refresh_fleet_panel()

func _save_battle_state(silent: bool = false) -> void:
	SaveManager.save_tactical_state(
		LoreDB.current_stage_id,
		TurnManager.turn_number,
		int(TurnManager.phase),
		TurnManager.ace_round,
		_player_ships,
		_enemy_ships
	)
	if not silent:
		AudioManager.play_sfx("ui_click", -8.0)
		_add_combat_log("💾 Tactical battle state saved [F5].", Color(0.35, 1.0, 0.70))

func _load_battle_state() -> void:
	var state := SaveManager.load_tactical_state()
	if state.is_empty():
		_add_combat_log("⚠ No saved tactical battle found [F9].", Color(1.0, 0.65, 0.30))
		return
	var saved_stage := String(state.get("stage_id", "acero_stage_1"))
	if saved_stage != LoreDB.current_stage_id:
		LoreDB.current_stage_id = saved_stage
		SaveManager.pending_load_battle = true
		get_tree().reload_current_scene()
		return

	TurnManager.turn_number = int(state.get("turn_number", 1))
	TurnManager.ace_round = int(state.get("ace_round", 1))
	var saved_phase := int(state.get("phase", 0))
	if saved_phase == int(TurnManager.Phase.ADMIRAL_RESOLVE):
		saved_phase = int(TurnManager.Phase.ADMIRAL_PLAN)
	elif saved_phase == int(TurnManager.Phase.ACE_RESOLVE):
		saved_phase = int(TurnManager.Phase.ACE_PLAN)
	TurnManager.phase = saved_phase as TurnManager.Phase

	var p_arr: Array = state.get("player_ships", [])
	for i in range(mini(_player_ships.size(), p_arr.size())):
		_apply_ship_save_dict(_player_ships[i], p_arr[i])

	var e_arr: Array = state.get("enemy_ships", [])
	for i in range(mini(_enemy_ships.size(), e_arr.size())):
		_apply_ship_save_dict(_enemy_ships[i], e_arr[i])

	_mission_completed = false
	if _victory_overlay != null:
		_victory_overlay.visible = false
	if _defeat_overlay != null:
		_defeat_overlay.visible = false

	_on_phase_changed(TurnManager.phase)
	_refresh_fleet_panel()
	AudioManager.play_sfx("ui_hover", -6.0)
	_add_combat_log("📂 Tactical battle restored (Turn %d, Round %d) [F9]." % [TurnManager.turn_number, TurnManager.ace_round], Color(0.40, 0.95, 1.0))

func _apply_ship_save_dict(s: Ship, sd: Dictionary) -> void:
	s.hp = float(sd.get("hp", s.hp))
	s.max_hp = float(sd.get("max_hp", s.max_hp))
	s.shield_hp = float(sd.get("shield_hp", s.shield_hp))
	s.max_shield_hp = float(sd.get("max_shield_hp", s.max_shield_hp))
	s.armor_bow = float(sd.get("armor_bow", s.armor_bow))
	s.armor_port = float(sd.get("armor_port", s.armor_port))
	s.armor_stbd = float(sd.get("armor_stbd", s.armor_stbd))
	s.armor_stern = float(sd.get("armor_stern", s.armor_stern))
	s.stance = int(sd.get("stance", 0)) as Ship.Stance
	s.is_evading = bool(sd.get("is_evading", false))
	s.state.position = SaveManager.arr_to_vec3(sd.get("pos", []))
	s.state.velocity = SaveManager.arr_to_vec3(sd.get("vel", []))
	var fwd := SaveManager.arr_to_vec3(sd.get("fwd", [0.0, 0.0, -1.0]))
	if fwd.length_squared() > 0.001:
		s.state.forward = fwd.normalized()
	s.order.yaw = float(sd.get("order_yaw", 0.0))
	s.order.pitch = float(sd.get("order_pitch", 0.0))
	s.order.target_speed = float(sd.get("order_speed", 0.0))
	s.refresh_after_load()

func _align_fleet_formation() -> void:
	if _selected_ship == null or _selected_ship.is_destroyed():
		return
	var ref_yaw := _selected_ship.order.yaw
	var ref_pitch := _selected_ship.order.pitch
	var ref_spd := maxf(_selected_ship.order.target_speed, 8.0)
	_selected_ship.order.target_speed = ref_spd
	for p in _player_ships:
		if not p.is_destroyed():
			p.order.yaw = ref_yaw
			p.order.pitch = ref_pitch
			p.order.target_speed = ref_spd
	AudioManager.play_sfx("ui_click", -8.0)
	_add_combat_log("⊞ Fleet aligned to %s Line-of-Battle bearing (SPD %.1f m/s)" % [_selected_ship.ship_name, ref_spd], Color(0.35, 0.95, 1.0))

func _update_ai_tactical_behavior(_delta: float) -> void:
	for i in range(_enemy_ships.size()):
		var enemy := _enemy_ships[i]
		if enemy.is_destroyed():
			continue
		var tgt := _nearest_player_ship(enemy)
		if tgt == null:
			continue
		var dist := enemy.state.position.distance_to(tgt.state.position)
		var heading := _compute_tactical_heading(enemy, tgt, 1.6)
		_set_order_heading(enemy, heading)
		if dist > 45.0:
			enemy.order.target_speed = 6.5
		elif dist > 20.0:
			enemy.order.target_speed = 3.5
		else:
			enemy.order.target_speed = 0.0

func _check_engagement_transition() -> void:
	if _fleets_in_range():
		_add_combat_log("Combat envelope reached! Clashing into Ace tactical combat.", Color(1.0, 0.85, 0.35))
		_engage_ace_mode()

func _nearest_player_ship(ship: Ship) -> Ship:
	return FleetTacticalAI.nearest_player_ship(ship, _player_ships)

func _nearest_enemy_for(ship: Ship) -> Ship:
	return FleetTacticalAI.nearest_enemy_for(ship, _enemy_ships)

func _fleets_in_range() -> bool:
	return FleetTacticalAI.fleets_in_range(_player_ships, _enemy_ships, ENGAGEMENT_RANGE)

func _nearest_enemy_distance() -> float:
	return FleetTacticalAI.nearest_enemy_distance(_player_ships, _enemy_ships)

func _build_3d_targeting_hud() -> void:
	_target_line_mesh = MeshInstance3D.new()
	_target_line_immediate = ImmediateMesh.new()
	_target_line_mesh.mesh = _target_line_immediate

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.95, 1.0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.8, 1.0)
	_target_line_mesh.material_override = mat
	_target_line_mesh.visible = false
	add_child(_target_line_mesh)

	_target_3d_reticle = Node3D.new()
	_target_3d_reticle.visible = false
	add_child(_target_3d_reticle)

	var torus := TorusMesh.new()
	torus.inner_radius = 2.4
	torus.outer_radius = 2.7
	torus.rings = 24
	var ret_mesh := MeshInstance3D.new()
	ret_mesh.mesh = torus
	var ret_mat := StandardMaterial3D.new()
	ret_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ret_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ret_mat.albedo_color = Color(1.0, 0.45, 0.25, 0.85)
	ret_mat.emission_enabled = true
	ret_mat.emission = Color(1.0, 0.3, 0.1)
	ret_mesh.material_override = ret_mat
	_target_3d_reticle.add_child(ret_mesh)

	_target_3d_label = Label3D.new()
	_target_3d_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_target_3d_label.font_size = 14
	_target_3d_label.outline_size = 2
	_target_3d_label.outline_modulate = Color.BLACK
	_target_3d_label.position = Vector3(0.0, 3.2, 0.0)
	_target_3d_reticle.add_child(_target_3d_label)

	_active_3d_beacon = Node3D.new()
	_active_3d_beacon.visible = false
	add_child(_active_3d_beacon)

	var beacon_torus := TorusMesh.new()
	beacon_torus.inner_radius = 3.0
	beacon_torus.outer_radius = 3.3
	beacon_torus.rings = 32
	var b_mesh := MeshInstance3D.new()
	b_mesh.mesh = beacon_torus
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.albedo_color = Color(0.2, 1.0, 0.65, 0.85)
	b_mat.emission_enabled = true
	b_mat.emission = Color(0.2, 1.0, 0.5)
	b_mesh.material_override = b_mat
	_active_3d_beacon.add_child(b_mesh)

	_active_3d_label = Label3D.new()
	_active_3d_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_active_3d_label.font_size = 13
	_active_3d_label.modulate = Color(0.3, 1.0, 0.7)
	_active_3d_label.outline_size = 2
	_active_3d_label.outline_modulate = Color.BLACK
	_active_3d_label.position = Vector3(0.0, -2.0, 0.0)
	_active_3d_label.text = "▶ SELECTED ACE"
	_active_3d_beacon.add_child(_active_3d_label)

func _update_3d_targeting_hud() -> void:
	if not TurnManager.is_in_ace():
		if _target_line_mesh != null:
			_target_line_mesh.visible = false
		if _target_3d_reticle != null:
			_target_3d_reticle.visible = false
		if _active_3d_beacon != null:
			_active_3d_beacon.visible = false
		return

	var active := _selected_ship
	if active == null or active.is_destroyed():
		if _target_line_mesh != null:
			_target_line_mesh.visible = false
		if _target_3d_reticle != null:
			_target_3d_reticle.visible = false
		if _active_3d_beacon != null:
			_active_3d_beacon.visible = false
		return

	if _active_3d_beacon != null:
		_active_3d_beacon.visible = true
		_active_3d_beacon.global_position = active.global_position
		_active_3d_beacon.rotate_y(0.02)

	if _ace_target != null and not _ace_target.is_destroyed():
		if _target_3d_reticle != null:
			_target_3d_reticle.visible = true
			_target_3d_reticle.global_position = _ace_target.global_position
			_target_3d_reticle.rotate_y(-0.025)

		var dist := active.state.position.distance_to(_ace_target.state.position)
		var in_range := dist <= active.weapon_range
		var in_arc := Combat.in_arc(active, _ace_target)
		var exposed_quad := Combat.get_hit_quadrant(active, _ace_target)

		var line_color := Color(0.25, 1.0, 0.6, 0.85)
		if not in_range:
			line_color = Color(1.0, 0.35, 0.3, 0.5)
			_target_3d_label.text = "▲ OUT OF RANGE: %.0fm / %.0fm" % [dist, active.weapon_range]
			_target_3d_label.modulate = Color(1.0, 0.45, 0.35)
		elif not in_arc:
			line_color = Color(1.0, 0.75, 0.25, 0.65)
			_target_3d_label.text = "◀ ALIGN FIRING ARC / BROADSIDE (YAW SHIP)"
			_target_3d_label.modulate = Color(1.0, 0.8, 0.3)
		else:
			line_color = Color(0.25, 1.0, 0.6, 0.85)
			_target_3d_label.text = "⌖ LOCKED [%s ARMOR] // READY TO FIRE" % exposed_quad
			_target_3d_label.modulate = Color(0.3, 1.0, 0.65)

		if _target_line_mesh != null and _target_line_immediate != null:
			_target_line_mesh.visible = true
			var mat: StandardMaterial3D = _target_line_mesh.material_override
			if mat != null:
				mat.albedo_color = line_color
				mat.emission = line_color

			_target_line_immediate.clear_surfaces()
			_target_line_immediate.surface_begin(Mesh.PRIMITIVE_LINES)
			_target_line_immediate.surface_set_color(line_color)
			_target_line_immediate.surface_add_vertex(active.global_position)
			_target_line_immediate.surface_add_vertex(_ace_target.global_position)
			_target_line_immediate.surface_end()
	else:
		if _target_3d_reticle != null:
			_target_3d_reticle.visible = false
		if _target_line_mesh != null:
			_target_line_mesh.visible = false

func _spawn_laser_beam(from_pos: Vector3, to_pos: Vector3, color: Color, is_mega_beam: bool = false) -> void:
	_vfx.spawn_laser_beam(from_pos, to_pos, color, is_mega_beam)

func _spawn_impact_flash(pos: Vector3, color: Color) -> void:
	_vfx.spawn_impact_flash(pos, color)

func _spawn_combat_text(pos: Vector3, text: String, color: Color) -> void:
	_vfx.spawn_combat_text(pos, text, color)

func _add_combat_log(text: String, color: Color = Color.WHITE) -> void:
	var timestamp := "[T%d] " % TurnManager.turn_number
	_combat_logs.append(timestamp + text)
	if _combat_logs.size() > 5:
		_combat_logs.remove_at(0)

	if _combat_log_vbox != null:
		for child in _combat_log_vbox.get_children():
			child.queue_free()
		for log_entry in _combat_logs:
			var lbl := Label.new()
			lbl.text = log_entry
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", color)
			_combat_log_vbox.add_child(lbl)

func _build_environment() -> void:
	var backdrop := StarSeaBackdrop.new()
	backdrop.name = "StarSeaBackdrop"
	add_child(backdrop)
	backdrop.setup_environment(false)

func _build_camera() -> void:
	_camera_rig = CameraRig.new()
	_camera_rig.target = Vector3(0.0, 0.0, 0.0)
	_camera_rig.distance = 70.0
	add_child(_camera_rig)

func _build_tactical_grid() -> void:
	_tactical_grid = TacticalGrid.new()
	add_child(_tactical_grid)

func _spawn_fleets() -> void:
	var spawn_res := StageSpawner.spawn_stage(
		LoreDB.current_stage_id,
		self,
		_ether,
		_on_ship_clicked,
		_on_ship_right_clicked
	)
	_player_ships = spawn_res["player_ships"]
	_enemy_ships = spawn_res["enemy_ships"]
	_tactical_grid.set_ships(_player_ships + _enemy_ships)
	_set_selected(_player_ships[0])
	_ace_target = _enemy_ships[0]

func _build_trajectory_preview() -> void:
	_trajectory = TrajectoryPreview.new()
	_trajectory.player_ships = _player_ships
	_trajectory.enemy_ships = _enemy_ships
	_trajectory.ether = _ether
	add_child(_trajectory)

func _build_hud() -> void:
	_hud_theme = _make_theme()
	var layer := CanvasLayer.new()
	layer.name = "TacticalHUD"
	add_child(layer)

	# 0. World-Space Projected 2D Ship Callout Badges (Hexagon + Green Bar + SHLD/HULL/MOVING from admiral-phase.png)
	_callout_overlay = HudWidgets.ShipCalloutOverlay.new()
	_callout_overlay.ships = _player_ships + _enemy_ships
	_callout_overlay.selected_ship = _selected_ship
	_callout_overlay.target_ship = _ace_target
	_callout_overlay.camera = get_viewport().get_camera_3d()
	_callout_overlay.ship_badge_clicked.connect(_on_ship_clicked)
	_callout_overlay.ship_badge_right_clicked.connect(_on_ship_right_clicked)
	layer.add_child(_callout_overlay)

	# 1. TOP-LEFT: Canonical BARLOVENTO Logo + "TURN X | ADMIRAL PHASE" + WEATHER-GAUGE + INITIATIVE ORDER
	var top_left_vbox := VBoxContainer.new()
	top_left_vbox.position = Vector2(18, 12)
	top_left_vbox.add_theme_constant_override("separation", 4)
	top_left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top_left_vbox)

	var logo_tex: Texture2D = load("res://assets/brand/logo.png")
	if logo_tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = logo_tex
		atlas.region = Rect2(80, 220, 1216, 280)
		var logo_rect := TextureRect.new()
		logo_rect.texture = atlas
		logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo_rect.custom_minimum_size = Vector2(215, 44)
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_left_vbox.add_child(logo_rect)

	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 6)
	top_left_vbox.add_child(turn_row)

	_turn_label_prefix = Label.new()
	_turn_label_prefix.text = "TURN 1 |"
	_turn_label_prefix.add_theme_font_size_override("font_size", 12)
	_turn_label_prefix.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	turn_row.add_child(_turn_label_prefix)

	_turn_label_phase = Label.new()
	_turn_label_phase.text = "ADMIRAL PHASE"
	_turn_label_phase.add_theme_font_size_override("font_size", 12)
	_turn_label_phase.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
	turn_row.add_child(_turn_label_phase)

	var spacer_tl := Control.new()
	spacer_tl.custom_minimum_size = Vector2(0, 6)
	top_left_vbox.add_child(spacer_tl)

	_weather_panel = HudWidgets.WeatherInitiativePanel.new()
	top_left_vbox.add_child(_weather_panel)

	# 2. TOP-CENTER: "ACE PHASE" Chamfered Trapezoid Banner (from ace-phase.png)
	_ace_top_banner = HudWidgets.AceTopBanner.new()
	_ace_top_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_ace_top_banner.position = Vector2(-280, 0)
	_ace_top_banner.visible = false
	layer.add_child(_ace_top_banner)

	# 3. TOP-RIGHT: Menu [◀ MENU], Roster [★], Save [💾], Load [📂], Reset [↻], Help [≡], Commander Bridge Card & Sensor Feed
	var top_right_vbox := VBoxContainer.new()
	top_right_vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right_vbox.position = Vector2(-330, 12)
	top_right_vbox.custom_minimum_size = Vector2(316, 0)
	top_right_vbox.add_theme_constant_override("separation", 6)
	layer.add_child(top_right_vbox)

	var tr_btn_row := HBoxContainer.new()
	tr_btn_row.alignment = BoxContainer.ALIGNMENT_END
	tr_btn_row.add_theme_constant_override("separation", 4)
	top_right_vbox.add_child(tr_btn_row)

	var menu_btn := Button.new()
	menu_btn.text = "◀ MENU"
	menu_btn.tooltip_text = "Return to Main Menu / Faction Select"
	menu_btn.theme = _hud_theme
	menu_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)
	tr_btn_row.add_child(menu_btn)

	var roster_btn := Button.new()
	roster_btn.text = "★ ROSTER"
	roster_btn.tooltip_text = "Hero & Ace Roster [R]"
	roster_btn.theme = _hud_theme
	roster_btn.pressed.connect(func() -> void:
		if _roster_modal != null:
			_roster_modal.visible = not _roster_modal.visible
	)
	tr_btn_row.add_child(roster_btn)

	var save_btn := Button.new()
	save_btn.text = "💾"
	save_btn.tooltip_text = "Quick Save Tactical Battle [F5]"
	save_btn.theme = _hud_theme
	save_btn.custom_minimum_size = Vector2(28, 28)
	save_btn.pressed.connect(func() -> void: _save_battle_state(false))
	tr_btn_row.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "📂"
	load_btn.tooltip_text = "Quick Load Tactical Battle [F9]"
	load_btn.theme = _hud_theme
	load_btn.custom_minimum_size = Vector2(28, 28)
	load_btn.pressed.connect(func() -> void: _load_battle_state())
	tr_btn_row.add_child(load_btn)

	var reset_btn := Button.new()
	reset_btn.text = "↻"
	reset_btn.tooltip_text = "Restart Stage"
	reset_btn.theme = _hud_theme
	reset_btn.custom_minimum_size = Vector2(28, 28)
	reset_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
	tr_btn_row.add_child(reset_btn)

	var help_btn := Button.new()
	help_btn.text = "≡"
	help_btn.tooltip_text = "Tactical Manual [H / ESC]"
	help_btn.theme = _hud_theme
	help_btn.custom_minimum_size = Vector2(30, 28)
	help_btn.pressed.connect(_toggle_help)
	tr_btn_row.add_child(help_btn)

	if _is_tutorial_stage:
		var tut_btn := Button.new()
		tut_btn.text = "🎓 TUTORIAL [T]"
		tut_btn.tooltip_text = "Toggle Tactical Academy Guide [T]"
		tut_btn.theme = _hud_theme
		tut_btn.custom_minimum_size = Vector2(110, 28)
		tut_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
		tut_btn.pressed.connect(func() -> void:
			if _tutorial_banner != null:
				_tutorial_banner.visible = not _tutorial_banner.visible
				AudioManager.play_sfx("ui_click", -10.0)
		)
		tr_btn_row.add_child(tut_btn)

	# Commander Bridge Comms & Stage Objective Card
	var cmd_card := PanelContainer.new()
	cmd_card.theme = _hud_theme
	top_right_vbox.add_child(cmd_card)

	var cmd_hbox := HBoxContainer.new()
	cmd_hbox.add_theme_constant_override("separation", 8)
	cmd_card.add_child(cmd_hbox)

	_cmd_port = TextureRect.new()
	var port_path := "res://assets/heroes/ace_vane.png"
	if not _player_ships.is_empty() and _player_ships[0] != null:
		port_path = LoreDB.get_portrait_for_ship(_player_ships[0].ship_id)
	var port_tex: Texture2D = load(port_path)
	if port_tex != null:
		_cmd_port.texture = port_tex
	_cmd_port.custom_minimum_size = Vector2(44, 44)
	_cmd_port.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cmd_port.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cmd_hbox.add_child(_cmd_port)

	var cmd_vbox := VBoxContainer.new()
	cmd_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_vbox.add_theme_constant_override("separation", 1)
	cmd_hbox.add_child(cmd_vbox)

	_stage_title_label = Label.new()
	match LoreDB.current_stage_id:
		# --- ARMADA OF ACERO (12 STAGES) ---
		"acero_stage_1": _stage_title_label.text = "ACT I // STAGE 01 [TUTORIAL]: SLUICE WELL-09"
		"acero_stage_2": _stage_title_label.text = "ACT I // STAGE 02: RESONANCE SPIRE"
		"acero_stage_3": _stage_title_label.text = "ACT I // STAGE 03: THE CALM THRESHOLD"
		"acero_stage_4": _stage_title_label.text = "ACT I // STAGE 04: IRON GATE TERTIUS"
		"acero_stage_5": _stage_title_label.text = "ACT II // STAGE 05: SIEGE OF SMUGGLER'S ATOLL"
		"acero_stage_6": _stage_title_label.text = "ACT II // STAGE 06: THE CHOIR INTERCEPT"
		"acero_stage_7": _stage_title_label.text = "ACT II // STAGE 07: OPERATION OBSIDIAN ANVIL"
		"acero_stage_8": _stage_title_label.text = "ACT II // STAGE 08: FERRO-MAGNETIC REEF"
		"acero_stage_9": _stage_title_label.text = "ACT III // STAGE 09: ASSAULT ON MAELSTROM STATION"
		"acero_stage_10": _stage_title_label.text = "ACT III // STAGE 10: DUEL WITH THE COLOSSUS"
		"acero_stage_11": _stage_title_label.text = "ACT III // STAGE 11: THE DYING TIDE"
		"acero_stage_12": _stage_title_label.text = "ACT III // STAGE 12: APEX OF STEEL // CALM CITADEL"

		# --- LOS VINCULADOS (12 STAGES) ---
		"vinculados_stage_1": _stage_title_label.text = "ACT I // STAGE 01 [TUTORIAL]: SANCTUARY SPIRE PSALM-4"
		"vinculados_stage_2": _stage_title_label.text = "ACT I // STAGE 02: THE CRYSTAL CHASM"
		"vinculados_stage_3": _stage_title_label.text = "ACT I // STAGE 03: GENESIS RING // TRANSCENDENCE"
		"vinculados_stage_4": _stage_title_label.text = "ACT I // STAGE 04: REQUIEM OF OUTER SHRINES"
		"vinculados_stage_5": _stage_title_label.text = "ACT II // STAGE 05: AWAKENING OF SERAPH-PRIME"
		"vinculados_stage_6": _stage_title_label.text = "ACT II // STAGE 06: SYMPHONY OF 5-VOICE CHOIR"
		"vinculados_stage_7": _stage_title_label.text = "ACT II // STAGE 07: THE CALM ABYSS TRENCH"
		"vinculados_stage_8": _stage_title_label.text = "ACT II // STAGE 08: PARLEY AT THE ASTROLABE"
		"vinculados_stage_9": _stage_title_label.text = "ACT III // STAGE 09: SHATTERING THE SLUICE DAM"
		"vinculados_stage_10": _stage_title_label.text = "ACT III // STAGE 10: CLASH OF TITANS"
		"vinculados_stage_11": _stage_title_label.text = "ACT III // STAGE 11: THE CALM SINGULARITY"
		"vinculados_stage_12": _stage_title_label.text = "ACT III // STAGE 12: SYMPHONY OF THE STAR SEA"

		# --- LA MAREA LIBRE (12 STAGES) ---
		"marea_stage_1": _stage_title_label.text = "ACT I // STAGE 01 [TUTORIAL]: THE BASALT NARROWS"
		"marea_stage_2": _stage_title_label.text = "ACT I // STAGE 02: RAID ON FOUNDRY VULCAN-3"
		"marea_stage_3": _stage_title_label.text = "ACT I // STAGE 03: THE MAELSTROM OF BARLOVENTO"
		"marea_stage_4": _stage_title_label.text = "ACT I // STAGE 04: THE FREE TRADER CONVOY"
		"marea_stage_5": _stage_title_label.text = "ACT II // STAGE 05: PRIZE OF THE 'SOBERANO'"
		"marea_stage_6": _stage_title_label.text = "ACT II // STAGE 06: THE DEAD REEF AMBUSH"
		"marea_stage_7": _stage_title_label.text = "ACT II // STAGE 07: SIEGE OF FORT ALMIRANTE"
		"marea_stage_8": _stage_title_label.text = "ACT II // STAGE 08: THE GHOST FLOTILLA"
		"marea_stage_9": _stage_title_label.text = "ACT III // STAGE 09: THE TRIPLE CONFLUENCE"
		"marea_stage_10": _stage_title_label.text = "ACT III // STAGE 10: BREAKING THE IRON CITADEL"
		"marea_stage_11": _stage_title_label.text = "ACT III // STAGE 11: EYE OF CHAOS"
		"marea_stage_12": _stage_title_label.text = "ACT III // STAGE 12: THE SOVEREIGN OCEAN"
		_:
			_stage_title_label.text = "TACTICAL ENGAGEMENT // STAR SEA"
	_stage_title_label.add_theme_font_size_override("font_size", 10)
	_stage_title_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	cmd_vbox.add_child(_stage_title_label)

	_objective_label = Label.new()
	_objective_label.text = "[TACTICAL OBJECTIVE: ENGAGE HOSTILE FORCES]"
	_objective_label.add_theme_font_size_override("font_size", 10)
	_objective_label.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
	cmd_vbox.add_child(_objective_label)

	# Compact Translucent Sensor Feed
	var log_panel := PanelContainer.new()
	log_panel.theme = _hud_theme
	log_panel.custom_minimum_size = Vector2(316, 86)
	top_right_vbox.add_child(log_panel)

	var log_outer := VBoxContainer.new()
	log_outer.add_theme_constant_override("separation", 2)
	log_panel.add_child(log_outer)

	var log_title := Label.new()
	log_title.text = "BRIDGE TELEMETRY // TACTICAL FEED"
	log_title.add_theme_font_size_override("font_size", 9)
	log_title.add_theme_color_override("font_color", Color(0.50, 0.78, 0.95))
	log_outer.add_child(log_title)

	_combat_log_vbox = VBoxContainer.new()
	_combat_log_vbox.add_theme_constant_override("separation", 1)
	log_outer.add_child(_combat_log_vbox)

	# 4. BOTTOM HUD DOCKS: OrderPanel (admiral-phase.png) & AcePanel (ace-phase.png)
	_order_panel = OrderPanel.new()
	_order_panel.theme = _hud_theme
	_order_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_order_panel.offset_top = -128
	_order_panel.offset_bottom = 0
	_order_panel.intercept_pressed.connect(_intercept_target)
	_order_panel.engage_ace_pressed.connect(_engage_ace_mode)
	_order_panel.execute_turn_pressed.connect(_execute_current_phase)
	_order_panel.formation_pressed.connect(_align_fleet_formation)
	_order_panel.focus_camera_pressed.connect(_zoom_to_selected_ship)
	_order_panel.toggle_grid_pressed.connect(func() -> void:
		if _tactical_grid != null:
			_tactical_grid.visible = not _tactical_grid.visible
	)
	_order_panel.open_roster_pressed.connect(func() -> void:
		if _roster_modal != null:
			_roster_modal.set_battle_rosters(_player_ships, _enemy_ships)
			_roster_modal.visible = true
	)
	_order_panel.ship_selected.connect(func(s: Ship) -> void:
		_set_selected(s)
		AudioManager.play_sfx("ui_click", -10.0)
	)
	_order_panel.enemy_targeted.connect(func(e: Ship, auto_intercept: bool) -> void:
		_ace_target = e
		if _tactical_grid != null:
			_tactical_grid.target_ship = e
		if _ace_panel != null:
			_ace_panel.target = e
		if _selected_ship != null:
			_selected_ship.target_ship = e
		if auto_intercept:
			_intercept_target()
		else:
			AudioManager.play_sfx("ui_hover", -8.0)
		_refresh_fleet_panel()
	)
	layer.add_child(_order_panel)

	_ace_panel = AcePanel.new()
	_ace_panel.theme = _hud_theme
	_ace_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_ace_panel.offset_top = -205
	_ace_panel.offset_bottom = 0
	_ace_panel.visible = false
	_ace_panel.execute_round_pressed.connect(_execute_ace_round)
	_ace_panel.cycle_target_pressed.connect(_cycle_hostile_target)
	_ace_panel.intercept_pressed.connect(_intercept_target)
	_ace_panel.toggle_auto_pilot_pressed.connect(_on_toggle_auto_pilot)
	_ace_panel.ability_used.connect(_on_ace_ability_used)
	_ace_panel.ability_toggled.connect(_on_ace_ability_toggled)
	_ace_panel.reset_ap_pressed.connect(func() -> void:
		_add_combat_log("↺ Action Points reset to maximum.", Color(1.0, 0.85, 0.35))
	)
	_ace_panel.ship_selected.connect(func(s: Ship) -> void:
		_set_selected(s)
		AudioManager.play_sfx("ui_click", -10.0)
	)
	_ace_panel.enemy_selected.connect(func(e: Ship) -> void:
		_ace_target = e
		if _tactical_grid != null:
			_tactical_grid.target_ship = e
		if _ace_panel != null:
			_ace_panel.target = e
		if _selected_ship != null:
			_selected_ship.target_ship = e
		AudioManager.play_sfx("ui_hover", -6.0)
		_refresh_fleet_panel()
		_add_combat_log("Hostile Ace locked: %s [%s]" % [e.pilot_name, e.ship_name], Color(1.0, 0.55, 0.35))
	)
	_ace_panel.exit_pressed.connect(func() -> void:
		_add_combat_log("Disengaging to the Admiral strategic chart for repositioning.", Color(0.4, 0.9, 1.0))
		TurnManager.exit_ace_mode()
		_open_admiral_chart()
	)
	_ace_panel.yaw_left.connect(func() -> void:
		if _selected_ship != null:
			_selected_ship.order.yaw += deg_to_rad(15.0)
	)
	_ace_panel.yaw_right.connect(func() -> void:
		if _selected_ship != null:
			_selected_ship.order.yaw -= deg_to_rad(15.0)
	)
	_ace_panel.pitch_up.connect(func() -> void:
		if _selected_ship != null:
			_selected_ship.order.pitch = clampf(_selected_ship.order.pitch + deg_to_rad(15.0), -PITCH_LIMIT, PITCH_LIMIT)
	)
	_ace_panel.pitch_down.connect(func() -> void:
		if _selected_ship != null:
			_selected_ship.order.pitch = clampf(_selected_ship.order.pitch - deg_to_rad(15.0), -PITCH_LIMIT, PITCH_LIMIT)
	)
	_ace_panel.speed_up.connect(func() -> void:
		if _selected_ship != null:
			_selected_ship.order.target_speed = clampf(_selected_ship.order.target_speed + 4.0, 0.0, _selected_ship.state.max_speed)
	)
	_ace_panel.speed_down.connect(func() -> void:
		if _selected_ship != null:
			_selected_ship.order.target_speed = clampf(_selected_ship.order.target_speed - 4.0, 0.0, _selected_ship.state.max_speed)
	)
	_ace_panel.stop_pressed.connect(func() -> void:
		if _selected_ship != null:
			_selected_ship.order.target_speed = 0.0
	)
	_ace_panel.toggle_weapon_arcs_pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
	)
	layer.add_child(_ace_panel)

	# 5. Resolution Progress Bar Overlay (centered at bottom during movement execution)
	_resolve_panel = PanelContainer.new()
	_resolve_panel.theme = _hud_theme
	_resolve_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_resolve_panel.position = Vector2(-240, -72)
	_resolve_panel.custom_minimum_size = Vector2(480, 54)
	_resolve_panel.visible = false
	layer.add_child(_resolve_panel)

	var res_vbox := VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 4)
	_resolve_panel.add_child(res_vbox)

	_resolve_label = Label.new()
	_resolve_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resolve_label.add_theme_font_size_override("font_size", 13)
	_resolve_label.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
	res_vbox.add_child(_resolve_label)

	_resolve_bar = ProgressBar.new()
	_resolve_bar.custom_minimum_size = Vector2(0, 12)
	res_vbox.add_child(_resolve_bar)

	# 6. Hero Roster Modal (Allied Aces vs. Hostile Commanders) + Help / Victory / Defeat Overlays
	_roster_modal = HudWidgets.HeroRosterModal.new()
	_roster_modal.theme = _hud_theme
	var roster_layer := CanvasLayer.new()
	roster_layer.layer = 20
	add_child(roster_layer)
	roster_layer.add_child(_roster_modal)

	# 7. Anime / Mini-Manga Story Transition Overlay
	_story_overlay = StoryTransitionOverlay.new()
	_story_overlay.theme = _hud_theme
	var story_layer := CanvasLayer.new()
	story_layer.layer = 28
	add_child(story_layer)
	story_layer.add_child(_story_overlay)
	_story_overlay.story_completed.connect(_on_story_completed)

	_refresh_fleet_panel()
	_build_help_overlay(layer)
	_build_victory_overlay(layer)
	_build_defeat_overlay(layer)
	_build_tutorial_banner()
	_disable_button_focus(layer)

func _on_story_completed() -> void:
	if not _mission_completed:
		_open_admiral_chart()
	else:
		_return_to_stage_briefing()

func _return_to_stage_briefing() -> void:
	var next_id := _get_next_stage_id()
	if next_id != "":
		LoreDB.return_to_briefing_stage_id = next_id
		LoreDB.current_stage_id = next_id
	else:
		LoreDB.return_to_briefing_stage_id = LoreDB.current_stage_id
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

func _refresh_fleet_panel() -> void:
	if _order_panel != null:
		_order_panel.rebuild_unit_cards(_player_ships, _enemy_ships, _selected_ship, _ace_target)
	if _ace_panel != null:
		_ace_panel.set_fleet(_player_ships, _selected_ship, _enemy_ships, _ace_target)
		_ace_panel.target = _ace_target
	if _roster_modal != null:
		_roster_modal.set_battle_rosters(_player_ships, _enemy_ships)
	if _callout_overlay != null:
		_callout_overlay.ships = _player_ships + _enemy_ships
		_callout_overlay.selected_ship = _selected_ship
		_callout_overlay.target_ship = _ace_target
	_check_stage_objectives()

func _update_hud_telemetry() -> void:
	if _callout_overlay != null and _callout_overlay.camera == null:
		_callout_overlay.camera = get_viewport().get_camera_3d()

	if TurnManager.is_resolving():
		var remaining := TurnManager.remaining_resolve_time()
		if TurnManager.phase == TurnManager.Phase.ACE_RESOLVE:
			_resolve_label.text = "ACE PHASE // ROUND %d RESOLUTION — %.1fs" % [TurnManager.ace_round, remaining]
			_resolve_bar.max_value = TurnManager.ace_resolution_window
		else:
			_resolve_label.text = "ADMIRAL PHASE // SIMULTANEOUS EXECUTION — %.1fs" % remaining
			_resolve_bar.max_value = TurnManager.admiral_resolution_window
		_resolve_bar.value = remaining

	if _turn_label_prefix != null:
		_turn_label_prefix.text = "TURN %d |" % TurnManager.turn_number

	if _weather_panel != null and _selected_ship != null and not _selected_ship.is_destroyed():
		match _selected_ship.faction:
			"acero":
				_weather_panel.active_faction_idx = 0
			"marea_libre":
				_weather_panel.active_faction_idx = 1
			_:
				_weather_panel.active_faction_idx = 2
		_weather_panel.queue_redraw()

	if _ace_panel != null and _selected_ship != null and not _selected_ship.is_destroyed():
		var check := _is_point_in_calm(_selected_ship.global_position)
		if check["in_calm"]:
			_ace_panel.set_calm_status("⚠ BECALMED IN CALM SEEP (-15 SHLD)", true)
		else:
			var info: Dictionary = _environment.get_nearest_calm_info(_selected_ship.global_position)
			if info["name"] != "":
				_ace_panel.set_calm_status("CALM SEEP: %.0fm (%s)" % [info["distance"], info["name"]], false)
			else:
				_ace_panel.set_calm_status("CALM QUIET", false)

func _on_phase_changed(_phase: int) -> void:
	var in_ace := TurnManager.is_in_ace()
	var resolving := TurnManager.is_resolving()

	if in_ace:
		AudioManager.play_ace_tactical_music(-10.0)
	else:
		AudioManager.play_battle_music(-10.0, LoreDB.selected_faction, LoreDB.current_stage_id)

	if _turn_label_phase != null:
		_turn_label_phase.text = "ACE PHASE" if in_ace else "ADMIRAL PHASE"

	if _ace_top_banner != null:
		_ace_top_banner.visible = in_ace
		_ace_top_banner.round_number = TurnManager.ace_round
		_ace_top_banner.queue_redraw()

	if _weather_panel != null:
		_weather_panel.visible = not in_ace

	if _order_panel != null:
		_order_panel.visible = not in_ace and not resolving
	if _ace_panel != null:
		_ace_panel.visible = in_ace and not resolving
	if _resolve_panel != null:
		_resolve_panel.visible = resolving

	_refresh_fleet_panel()

func _update_round_banner() -> void:
	if _ace_top_banner != null:
		_ace_top_banner.round_number = TurnManager.ace_round
		_ace_top_banner.queue_redraw()

func _check_stage_objectives() -> void:
	if _mission_completed:
		return

	var total_enemies := _enemy_ships.size()
	var enemies_alive := 0
	for enemy in _enemy_ships:
		if not enemy.is_destroyed():
			enemies_alive += 1

	var players_alive := 0
	for player in _player_ships:
		if not player.is_destroyed():
			players_alive += 1

	var flagship_alive := not _player_ships[0].is_destroyed()
	var flagship_hp_pct := roundi((_player_ships[0].hp / maxf(_player_ships[0].max_hp, 1.0)) * 100.0)

	if _objective_label != null:
		_objective_label.text = "[HOSTILES: %d/%d DESTROYED | FLAGSHIP: %d%% HP]" % [
			total_enemies - enemies_alive, total_enemies, flagship_hp_pct
		]

	if enemies_alive == 0:
		_mission_completed = true
		_show_mission_victory()
	elif players_alive == 0 or not flagship_alive:
		_mission_completed = true
		_show_mission_defeat()

func _get_next_stage_id() -> String:
	return SaveManager.get_next_stage_id(LoreDB.current_stage_id)

func _show_mission_victory() -> void:
	AudioManager.play_sfx("shockwave", 0.0)
	AudioManager.play_sfx("explosion_big", 0.0)

	var surviving_ids: Array[String] = []
	var promo_lines: Array[String] = []
	for p in _player_ships:
		if not p.is_destroyed():
			surviving_ids.append(p.ship_id)
			var new_rank := mini(SaveManager.get_veteran_rank(p.ship_id) + 1, 5)
			promo_lines.append("★ %s (%s) promoted to %s [Rank %d: +%d%% HP / +%d%% DMG]" % [
				p.pilot_name, p.ship_name, SaveManager.get_veteran_title(new_rank), new_rank, new_rank * 6, new_rank * 5
			])

	SaveManager.record_stage_victory(LoreDB.current_stage_id, surviving_ids)

	if LoreDB.current_stage_id == "acero_stage_1":
		_add_combat_log("TUTORIAL COMPLETE: SLUICE STATION WELL-09 SECURED! STEEL ENDURES!", Color(0.3, 1.0, 0.6))
	elif LoreDB.current_stage_id == "vinculados_stage_1":
		_add_combat_log("TUTORIAL COMPLETE: SANCTUARY SPIRE PSALM-4 DEFENDED!", Color(0.3, 1.0, 0.6))
	elif LoreDB.current_stage_id == "marea_stage_1":
		_add_combat_log("TUTORIAL COMPLETE: THE BASALT NARROWS CLEARED!", Color(0.3, 1.0, 0.6))
	elif LoreDB.current_stage_id == "acero_stage_2":
		_add_combat_log("STAGE 02 COMPLETE: RESONANCE SPIRE SECURED!", Color(0.3, 1.0, 0.6))
	elif LoreDB.current_stage_id == "acero_stage_3":
		_add_combat_log("ACT I CAMPAIGN COMPLETE: THE CALM THRESHOLD HELD!", Color(0.3, 1.0, 0.6))
	else:
		_add_combat_log("MISSION ACCOMPLISHED: SECTOR SECURED!", Color(0.3, 1.0, 0.6))

	AudioManager.play_victory_fanfare(-5.0)

	var next_id := _get_next_stage_id()
	if next_id != "":
		SaveManager.unlock_stage(next_id)

	if _victory_dialog != null:
		_victory_dialog.set_promotions(promo_lines)
		_victory_dialog.update_next_stage(next_id)

	if _story_overlay != null:
		_story_overlay.show_outro(LoreDB.current_stage_id)
	elif _victory_overlay != null:
		_victory_overlay.visible = true

func _show_mission_defeat() -> void:
	AudioManager.play_sfx("shockwave", 0.0)
	AudioManager.play_sfx("explosion_big", 0.0)
	AudioManager.play_defeat_cue(-5.0)
	_add_combat_log("MISSION FAILED: FLAGSHIP DESTROYED", Color(1.0, 0.3, 0.3))
	if _defeat_overlay != null:
		_defeat_overlay.visible = true

func _build_victory_overlay(layer: CanvasLayer) -> void:
	_victory_dialog = BattleResultsOverlay.build_victory_overlay(
		layer,
		_hud_theme,
		LoreDB.current_stage_id,
		_get_next_stage_id() != "",
		_return_to_stage_briefing,
		func() -> void: get_tree().reload_current_scene()
	)
	_victory_overlay = _victory_dialog.root

func _build_defeat_overlay(layer: CanvasLayer) -> void:
	_defeat_overlay = BattleResultsOverlay.build_defeat_overlay(
		layer,
		_hud_theme,
		LoreDB.current_stage_id,
		func() -> void:
			LoreDB.return_to_briefing_stage_id = LoreDB.current_stage_id
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"),
		func() -> void: get_tree().reload_current_scene()
	)

func _build_help_overlay(layer: CanvasLayer) -> void:
	_help_overlay = BattleHelpOverlay.build_help_overlay(
		layer,
		_hud_theme,
		_toggle_help,
		func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)

func _toggle_help() -> void:
	if _help_overlay != null:
		_help_overlay.visible = not _help_overlay.visible

func _build_tutorial_banner() -> void:
	if not _is_tutorial_stage:
		return
	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.name = "TutorialLayer"
	_tutorial_layer.layer = 25
	add_child(_tutorial_layer)
	_tutorial_controller = TutorialBanner.build(
		_tutorial_layer,
		_hud_theme,
		LoreDB.current_stage_id,
		_add_combat_log
	)
	_tutorial_banner = _tutorial_controller.root

func _set_tutorial_step(step: int) -> void:
	if _tutorial_controller != null:
		_tutorial_controller.set_step(step)

func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 12

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.035, 0.07, 0.62)
	panel_style.border_color = Color(0.20, 0.70, 0.90, 0.35)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(8)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.04, 0.09, 0.16, 0.68)
	btn_normal.border_color = Color(0.25, 0.65, 0.85, 0.30)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(5)
	btn_normal.set_content_margin_all(5)
	theme.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.08, 0.18, 0.30, 0.85)
	btn_hover.border_color = Color(0.35, 0.90, 1.0, 0.80)
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(5)
	btn_hover.set_content_margin_all(5)
	theme.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.12, 0.28, 0.40, 0.95)
	btn_pressed.border_color = Color(1.0, 0.85, 0.35, 0.90)
	btn_pressed.set_border_width_all(1)
	btn_pressed.set_corner_radius_all(5)
	btn_pressed.set_content_margin_all(5)
	theme.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.03, 0.05, 0.08, 0.40)
	btn_disabled.border_color = Color(0.15, 0.25, 0.35, 0.20)
	btn_disabled.set_border_width_all(1)
	btn_disabled.set_corner_radius_all(5)
	btn_disabled.set_content_margin_all(5)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.02, 0.04, 0.08, 0.75)
	pb_bg.border_color = Color(0.2, 0.45, 0.65, 0.35)
	pb_bg.set_border_width_all(1)
	pb_bg.set_corner_radius_all(3)
	theme.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.25, 0.88, 0.55, 0.95)
	pb_fill.set_corner_radius_all(3)
	theme.set_stylebox("fill", "ProgressBar", pb_fill)

	theme.set_color("font_color", "Button", Color(0.85, 0.95, 1.0))
	theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.60, 0.68, 0.6))
	theme.set_color("font_color", "Label", Color(0.85, 0.92, 0.98))

	return theme

func _disable_button_focus(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			child.focus_mode = Control.FOCUS_NONE
		_disable_button_focus(child)

func _setup_input_actions() -> void:
	_add_action("move_forward", [KEY_W])
	_add_action("move_back", [KEY_S])
	_add_action("yaw_left", [KEY_A, KEY_LEFT])
	_add_action("yaw_right", [KEY_D, KEY_RIGHT])
	_add_action("pitch_up", [KEY_Q, KEY_UP])
	_add_action("pitch_down", [KEY_E, KEY_DOWN])
	_add_action("resolve", [KEY_SPACE])
	_add_action("cycle", [KEY_TAB])
	_add_action("stop", [KEY_X])
	_add_action("focus_ship", [KEY_V, KEY_F])
	_add_action("toggle_grid", [KEY_G])
	_add_action("help", [KEY_H, KEY_ESCAPE])
	_add_action("toggle_roster", [KEY_R])
	_add_action("ace_cycle", [KEY_C])
	_add_action("intercept_target", [KEY_T])
	_add_action("quick_save", [KEY_F5])
	_add_action("quick_load", [KEY_F9])

func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _open_admiral_chart() -> void:
	if _camera_rig != null:
		_camera_rig.set_admiral_zenith_view()

	if _admiral_chart == null:
		_admiral_layer = CanvasLayer.new()
		_admiral_layer.layer = 15
		add_child(_admiral_layer)

		_admiral_chart = AdmiralChart.new()
		_admiral_chart.stage_title = _stage_title_label.text if _stage_title_label != null else "SECTOR OPERATION"
		_admiral_chart.turn_executed.connect(_on_chart_turn_executed)
		_admiral_chart.engage_3d_requested.connect(_on_chart_engage_3d)
		_admiral_chart.ship_selected_on_chart.connect(func(idx: int) -> void:
			if idx >= 0 and idx < _player_ships.size() and not _player_ships[idx].is_destroyed():
				_set_selected(_player_ships[idx])
		)
		_admiral_chart.open_roster_requested.connect(func() -> void:
			if _roster_modal != null:
				_roster_modal.set_battle_rosters(_player_ships, _enemy_ships)
				_roster_modal.visible = not _roster_modal.visible
		)
		_admiral_chart.return_menu_requested.connect(func() -> void:
			AudioManager.play_sfx("ui_click", -8.0)
			get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
		)
		_admiral_layer.add_child(_admiral_chart)

	_admiral_chart.modulate.a = 1.0
	_admiral_chart.sync_from_3d_ships(_player_ships, _enemy_ships, _ether)
	_admiral_chart.visible = true
	AudioManager.play_sfx("ui_hover", -8.0)

func _on_chart_turn_executed(summary_log: String, contact_reached: bool, p_spawns: Array = [], e_spawns: Array = []) -> void:
	_add_combat_log(summary_log, Color(0.35, 0.95, 1.0))
	if contact_reached:
		_add_combat_log(">>> FLEET CONTACT! ENGAGING 3D ACE TACTICAL COMBAT <<<", Color(1.0, 0.82, 0.35))

	# Animate real 3D ships simultaneously gliding to their new quadrant positions!
	for i in range(mini(_player_ships.size(), p_spawns.size())):
		var s := _player_ships[i]
		if s != null and not s.is_destroyed():
			var p_info: Dictionary = p_spawns[i]
			var target_pos: Vector3 = p_info.get("pos", s.state.position)
			var target_fwd: Vector3 = p_info.get("fwd", s.state.forward)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(s, "position", target_pos, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(s.state, "position", target_pos, 0.85)
			s.state.forward = target_fwd
			s.order.yaw = Vector3.FORWARD.signed_angle_to(target_fwd, Vector3.UP)
			s.refresh_after_load()

	for i in range(mini(_enemy_ships.size(), e_spawns.size())):
		var e := _enemy_ships[i]
		if e != null and not e.is_destroyed():
			var e_info: Dictionary = e_spawns[i]
			var target_pos: Vector3 = e_info.get("pos", e.state.position)
			var target_fwd: Vector3 = e_info.get("fwd", e.state.forward)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(e, "position", target_pos, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(e.state, "position", target_pos, 0.85)
			e.state.forward = target_fwd
			e.order.yaw = Vector3.FORWARD.signed_angle_to(target_fwd, Vector3.UP)
			e.refresh_after_load()

func _on_chart_engage_3d(bonuses: Dictionary) -> void:
	_strategic_bonuses = bonuses
	if _admiral_chart != null:
		_admiral_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. Apply 3D Spawns & Vectors computed from strategic chart
	var p_spawns: Array = bonuses.get("player_spawns", [])
	for i in range(mini(_player_ships.size(), p_spawns.size())):
		var s := _player_ships[i]
		if s.is_destroyed():
			continue
		var info: Dictionary = p_spawns[i]
		s.state.position = info.get("pos", s.state.position)
		s.position = s.state.position
		s.state.forward = info.get("fwd", s.state.forward)
		s.order.yaw = Vector3.FORWARD.signed_angle_to(s.state.forward, Vector3.UP)
		var spd_mult: float = bonuses.get("speed_mult", 1.0)
		s.order.target_speed = minf(s.state.max_speed * 0.70 * spd_mult, s.state.max_speed)
		s.initial_velocity = s.state.forward * s.order.target_speed
		s.state.velocity = s.initial_velocity
		s.refresh_after_load()

	var e_spawns: Array = bonuses.get("enemy_spawns", [])
	for i in range(mini(_enemy_ships.size(), e_spawns.size())):
		var e := _enemy_ships[i]
		if e.is_destroyed():
			continue
		var info: Dictionary = e_spawns[i]
		e.state.position = info.get("pos", e.state.position)
		e.position = e.state.position
		e.state.forward = info.get("fwd", e.state.forward)
		e.order.yaw = Vector3.FORWARD.signed_angle_to(e.state.forward, Vector3.UP)
		e.initial_velocity = e.state.forward * 4.0
		e.state.velocity = e.initial_velocity
		e.refresh_after_load()

	# 2. Smooth cinematic camera swoop into 3D follow perspective!
	if _camera_rig != null and _selected_ship != null:
		_camera_rig.set_ace_combat_view(_selected_ship.state.position, _selected_ship.order.yaw)

	# 3. Apply Doctrine Buffs to Ships
	var has_barlovento: bool = bonuses.get("has_barlovento", false)
	var is_crossing_t: bool = bonuses.get("is_crossing_t", false)
	var is_flanking: bool = bonuses.get("is_flanking", false)
	var armor_mult: float = bonuses.get("armor_mult", 1.0)
	var turn_mult: float = bonuses.get("turn_mult", 1.0)

	for s in _player_ships:
		s.set_meta("admiral_barlovento", has_barlovento)
		s.set_meta("admiral_barlovento_rounds", 3 if has_barlovento else 0)
		s.set_meta("formation_armor_mult", armor_mult)
		if bonuses.get("formation", 0) == AdmiralChart.Formation.FLANKING_PINCER:
			s.set_meta("formation_flank_mult", 1.35)
		s.state.turn_power *= turn_mult

	# 4. Apply Ace Panel Bonus AP
	var bonus_ap: int = bonuses.get("bonus_ap", 0)
	if _ace_panel != null:
		_ace_panel.set_strategic_bonus_ap(bonus_ap)

	# 5. Announce Strategic Results in Combat Log
	if has_barlovento:
		_add_combat_log("🌬 [BARLOVENTO SECURED] Fleet claims the weather gauge! (+1 AP, +15% Hit, +15% Damage for 3 rounds)", Color(0.35, 1.0, 0.72))
	elif bonuses.get("enemy_barlovento", false):
		_add_combat_log("🌬 [BARLOVENTO ENEMY] Hostile fleet holds the upwind current! (+15% Enemy Hit & Damage)", Color(1.0, 0.45, 0.35))
	else:
		_add_combat_log("🌬 [BARLOVENTO CONTESTED] Neutral Éther alignment across both battle groups.", Color(0.75, 0.85, 0.95))

	if is_crossing_t:
		_add_combat_log("🎯 [CROSSING THE 'T'] Enemy fleet flanked! Hostiles deployed with vulnerable port/starboard exposed!", Color(0.40, 0.96, 1.0))
	elif is_flanking:
		_add_combat_log("🎯 [PINCER AMBUSH] Flanking envelopment achieved! Allied wing deployed with stern firing angles!", Color(0.40, 0.96, 1.0))

	if bonuses.get("sluice_held", false):
		_add_combat_log("⚙ [SLUICE STATION HELD] Continuous power flow shields allied squadron (+20 SHLD regen)!", Color(1.0, 0.82, 0.35))
	if bonuses.get("conduit_held", false):
		_add_combat_log("⚡ [CONDUIT RELAYS CAPTURED] Strategic grid online! (+1 AP & +15% Speed to all units)", Color(0.35, 1.0, 0.85))
	if bonuses.get("reef_held", false):
		_add_combat_log("🪨 [BASALT REEF AMBUSH] Flank squadron undetected in asteroid cover! (+25% Crit Damage on opening salvo)", Color(0.95, 0.75, 0.35))

	_engage_ace_mode()

func _tick_strategic_barlovento() -> void:
	for s in _player_ships:
		if s.has_meta("admiral_barlovento_rounds"):
			var r := int(s.get_meta("admiral_barlovento_rounds")) - 1
			if r <= 0:
				s.set_meta("admiral_barlovento", false)
				s.set_meta("admiral_barlovento_rounds", 0)
			else:
				s.set_meta("admiral_barlovento_rounds", r)
