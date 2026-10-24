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
var _ether_particles: Node3D
var _asteroid_root: Node3D
var _calm_root: Node3D
var _calm_seeps: Array[Dictionary] = []
var _sluice_station_root: Node3D
var _is_vector_dragging: bool = false

var _mission_completed: bool = false
var _victory_title_label: Label
var _victory_sub_label: Label
var _victory_next_btn: Button
var _admiral_chart: AdmiralChart
var _admiral_layer: CanvasLayer
var _strategic_bonuses: Dictionary = {}

var _is_tutorial_stage: bool = false
var _tutorial_layer: CanvasLayer = null
var _tutorial_banner: PanelContainer = null
var _tutorial_step: int = 0
var _tutorial_step_label: Label = null
var _tutorial_title_label: Label = null
var _tutorial_body_label: Label = null
var _tutorial_prev_btn: Button = null
var _tutorial_next_btn: Button = null

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
	_build_ether_flow()
	_build_asteroid_field()
	_build_calm_wavefront()
	_build_stage_landmark()
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
	_update_ether_flow(delta)
	_update_scenery(delta)
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
		_plan_ai_orders()
		AudioManager.play_sfx("ui_click", -12.0)
		_add_combat_log("Executing strategic WEGO fleet resolution (%ds)..." % int(TurnManager.admiral_resolution_window), Color(0.3, 1.0, 0.6))
		TurnManager.start_resolve()
	elif TurnManager.phase == TurnManager.Phase.ACE_PLAN:
		_execute_ace_round()

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
		if ally.is_auto_pilot:
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

	# 1. Target: tunnel vision on closest enemy threat
	var target := _nearest_enemy_for(ship)
	if target == null or target.is_destroyed():
		return
	ship.target_ship = target

	# 2. Heading: center of mass, direct line toward target (no intentional stern rake hunting)
	var to_target := target.global_position - ship.global_position
	if to_target.length_squared() > 0.01:
		_set_order_heading(ship, to_target.normalized())

	# 3. Speed: conservative positioning
	var dist := ship.state.position.distance_to(target.state.position)
	if dist > ship.weapon_range:
		ship.order.target_speed = ship.state.max_speed * 0.60
	elif dist > 16.0:
		ship.order.target_speed = 3.5
	else:
		ship.order.target_speed = 1.5

	# 4. Stance: defensive when battered, fire when healthy
	if ship.hp < ship.max_hp * 0.35:
		ship.stance = Ship.Stance.EVASIVE
	else:
		ship.stance = Ship.Stance.FIRE

	# 5. Conservative AP spending (max 2 AP, 1 support action):
	_clear_round_combat_metas(ship)
	var fac := ship.faction
	if ship.hp < ship.max_hp * 0.35:
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
	return target.state.position + target.state.velocity * lead_time

func _compute_tactical_heading(ship: Ship, target: Ship, lead_time: float) -> Vector3:
	var predicted := _predict_target_pos(target, lead_time)
	var to_target := predicted - ship.state.position
	var dist := to_target.length()
	if dist < 0.1:
		return ship.state.forward
	var dir := to_target / dist

	# Capital warships with broadside batteries angle 52 degrees ("Crossing the T" / angled broadside)
	# when inside optimal firing envelope (22m..46m) to bring both forward & broadside batteries to bear
	if (ship.ship_id == "acero_dreadnought" or ship.ship_id == "marea_galleon") and dist >= 22.0 and dist <= 46.0:
		var port_hp := ship.armor_port
		var stbd_hp := ship.armor_stbd
		# Present the healthier armor flank toward the enemy!
		var angle_sign := 1.0 if port_hp >= stbd_hp else -1.0
		var angled := dir.rotated(Vector3.UP, deg_to_rad(52.0 * angle_sign))
		return angled.normalized()

	return dir

func _plan_ai_orders() -> void:
	var flagship: Ship = null
	for s in _enemy_ships:
		if not s.is_destroyed():
			flagship = s
			break
	if flagship == null:
		return

	var primary_target := _nearest_player_ship(flagship)
	if primary_target == null:
		return

	for i in range(_enemy_ships.size()):
		var enemy := _enemy_ships[i]
		if enemy.is_destroyed():
			continue
		var tgt := _nearest_player_ship(enemy)
		if tgt == null:
			tgt = primary_target
		var dist := enemy.state.position.distance_to(tgt.state.position)
		if i == 0:
			var heading := _compute_tactical_heading(enemy, tgt, 3.5)
			_set_order_heading(enemy, heading)
			if dist > 48.0:
				enemy.order.target_speed = enemy.state.max_speed * 0.65
			elif dist > 22.0:
				enemy.order.target_speed = 3.5
			else:
				enemy.order.target_speed = 0.0
		else:
			var heading := _compute_tactical_heading(enemy, tgt, 2.5)
			_set_order_heading(enemy, heading)
			if dist > 42.0:
				enemy.order.target_speed = enemy.state.max_speed * 0.68
			elif dist > 18.0:
				enemy.order.target_speed = 4.2
			else:
				enemy.order.target_speed = 0.0

func _plan_ai_tactical_orders() -> void:
	if _is_tutorial_stage:
		# TUTORIAL AI: Distribute targets (1v1 duels) so the cadet isn't overwhelmed by 3-on-1 focus fire.
		for i in range(_enemy_ships.size()):
			var enemy := _enemy_ships[i]
			if enemy.is_destroyed():
				continue
			var target: Ship = null
			if i < _player_ships.size() and not _player_ships[i].is_destroyed():
				target = _player_ships[i]
			else:
				target = _nearest_player_ship(enemy)
			enemy.target_ship = target
			if target != null:
				var dist := enemy.state.position.distance_to(target.state.position)
				var heading := _compute_tactical_heading(enemy, target, 1.8)
				_set_order_heading(enemy, heading)
				if enemy.hp < enemy.max_hp * 0.25:
					enemy.stance = Ship.Stance.EVASIVE
				else:
					enemy.stance = Ship.Stance.FIRE
				if dist > enemy.weapon_range:
					enemy.order.target_speed = enemy.state.max_speed * 0.55
				elif dist > 18.0:
					enemy.order.target_speed = 3.2
				else:
					enemy.order.target_speed = 1.0
		return

	# Focus-fire utility scoring: prioritize highest threat / lowest HP player unit in range
	var best_focus_target: Ship = null
	var best_score := -INF
	for p in _player_ships:
		if p.is_destroyed():
			continue
		var hp_ratio := p.hp / maxf(p.max_hp, 1.0)
		var score := (1.0 - hp_ratio) * 45.0
		if not _enemy_ships.is_empty() and not _enemy_ships[0].is_destroyed():
			var d := _enemy_ships[0].state.position.distance_to(p.state.position)
			score -= d * 0.5
		if score > best_score:
			best_score = score
			best_focus_target = p

	for ship in _enemy_ships:
		if ship.is_destroyed():
			continue
		var target := best_focus_target if best_focus_target != null and not best_focus_target.is_destroyed() else _nearest_player_ship(ship)
		ship.target_ship = target
		if target != null:
			var dist := ship.state.position.distance_to(target.state.position)
			var heading := _compute_tactical_heading(ship, target, 1.8)
			_set_order_heading(ship, heading)

			if ship.hp < ship.max_hp * 0.35:
				ship.stance = Ship.Stance.EVASIVE
			else:
				ship.stance = Ship.Stance.FIRE

			if dist > ship.weapon_range:
				ship.order.target_speed = ship.state.max_speed * 0.65
			elif dist > 18.0:
				ship.order.target_speed = 4.2
			else:
				ship.order.target_speed = 1.2

func _set_order_heading(ship: Ship, direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	ship.order.yaw = Vector3.FORWARD.signed_angle_to(flat, Vector3.UP)
	ship.order.pitch = clampf(asin(clampf(direction.y, -1.0, 1.0)), -PITCH_LIMIT, PITCH_LIMIT)

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
	if _calm_seeps.is_empty():
		return
	var tw := create_tween().set_parallel(true)
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
	_add_combat_log("🌊 THE CALM DILATES: Dimensional fluid seeps expand (+%.1fm across flanks)!" % avg_growth, Color(0.85, 0.45, 0.98))
	AudioManager.play_sfx("shield", -10.0)

func _is_point_in_calm(pos: Vector3) -> Dictionary:
	var p2 := Vector2(pos.x, pos.z)
	for seep in _calm_seeps:
		var c2: Vector2 = seep.get("pos2", Vector2.ZERO)
		var rad: float = seep.get("radius", 0.0)
		if p2.distance_to(c2) <= rad:
			return {"in_calm": true, "seep": seep}
	return {"in_calm": false, "seep": {}}

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
	var best: Ship = null
	var best_distance := INF
	for candidate in _player_ships:
		if candidate.is_destroyed():
			continue
		var distance := ship.state.position.distance_to(candidate.state.position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _nearest_enemy_for(ship: Ship) -> Ship:
	var best: Ship = null
	var best_distance := INF
	for candidate in _enemy_ships:
		if candidate.is_destroyed():
			continue
		var distance := ship.state.position.distance_to(candidate.state.position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _fleets_in_range() -> bool:
	for player in _player_ships:
		if player.is_destroyed():
			continue
		for enemy in _enemy_ships:
			if enemy.is_destroyed():
				continue
			if player.state.position.distance_to(enemy.state.position) <= ENGAGEMENT_RANGE:
				return true
	return false

func _nearest_enemy_distance() -> float:
	var best := INF
	for player in _player_ships:
		if player.is_destroyed():
			continue
		for enemy in _enemy_ships:
			if enemy.is_destroyed():
				continue
			best = minf(best, player.state.position.distance_to(enemy.state.position))
	return best

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

func _spawn_impact_flash(pos: Vector3, color: Color) -> void:
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

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3(3.4, 3.4, 3.4), 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.tween_property(ring, "scale", Vector3(4.8, 4.8, 4.8), 0.34)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.34)
	tween.chain().tween_callback(func() -> void:
		flash.queue_free()
		ring.queue_free()
	)

func _spawn_combat_text(pos: Vector3, text: String, color: Color) -> void:
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
	_asteroid_root = Node3D.new()
	_asteroid_root.name = "StarSeaReefs"
	add_child(_asteroid_root)

	var is_marea := (LoreDB.current_stage_id == "marea_stage_1")
	var is_vinc := (LoreDB.current_stage_id in ["vinculados_stage_1", "acero_stage_2"])

	var rock_mat := StandardMaterial3D.new()
	if is_vinc:
		rock_mat.albedo_color = Color(0.24, 0.26, 0.35)
		rock_mat.roughness = 0.65
	elif is_marea:
		rock_mat.albedo_color = Color(0.12, 0.11, 0.14)
		rock_mat.roughness = 0.90
	else:
		rock_mat.albedo_color = Color(0.14, 0.16, 0.22)
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
	if is_marea:
		# "The Basalt Narrows" — two dense flanking asteroid walls on Port and Starboard
		# leaving a central 70m canyon channel where El Río del Viento rushes through!
		for z_step in range(-5, 6):
			var z_val := float(z_step) * 16.0
			reef_positions.append(Vector3(-46.0 + rng.randf_range(-6.0, 4.0), rng.randf_range(-12.0, 14.0), z_val))
			reef_positions.append(Vector3(-62.0 + rng.randf_range(-8.0, 6.0), rng.randf_range(-16.0, 18.0), z_val + 6.0))
			reef_positions.append(Vector3(46.0 + rng.randf_range(-4.0, 6.0), rng.randf_range(-12.0, 14.0), z_val))
			reef_positions.append(Vector3(62.0 + rng.randf_range(-6.0, 8.0), rng.randf_range(-16.0, 18.0), z_val - 6.0))
		# A few tactical mid-canyon obstacles to sail around
		reef_positions.append(Vector3(-18.0, 8.0, -15.0))
		reef_positions.append(Vector3(16.0, -6.0, 25.0))
	elif is_vinc:
		# Floating Sanctuary Crystal Orbitals encircling the sacred well
		for a_i in range(12):
			var ang := float(a_i) * TAU / 12.0
			var dist := rng.randf_range(52.0, 85.0)
			reef_positions.append(Vector3(cos(ang) * dist, rng.randf_range(-18.0, 22.0), sin(ang) * dist))
	else:
		# Acero standard industrial mining reefs
		reef_positions = [
			Vector3(-68.0, -8.0, 12.0),
			Vector3(-56.0, 14.0, -28.0),
			Vector3(64.0, -6.0, 18.0),
			Vector3(58.0, 10.0, -24.0),
			Vector3(-75.0, 4.0, 55.0),
			Vector3(76.0, -12.0, 48.0),
			Vector3(-48.0, -16.0, -68.0),
			Vector3(52.0, 12.0, -72.0),
			Vector3(0.0, -22.0, 5.0),
			Vector3(-32.0, 18.0, 4.0),
		]

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

		# Glowing Éther crystal spire embedded in the basalt reef
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
			_build_acero_sluice_station()
		"acero_stage_2":
			_build_vinculados_sanctuary_spire()
		"acero_stage_3":
			_build_acero_calm_bastion()
		"acero_stage_4":
			_build_acero_sluice_station()
		"acero_stage_5":
			_build_marea_corsair_haven()
		"acero_stage_6":
			_build_vinculados_crystal_chasm()
		"acero_stage_7":
			_build_acero_calm_bastion()
		"acero_stage_8":
			_build_marea_foundry_complex()
		"acero_stage_9":
			_build_marea_wind_maelstrom()
		"acero_stage_10":
			_build_vinculados_genesis_ring()
		"acero_stage_11":
			_build_acero_calm_bastion()
		"acero_stage_12":
			_build_vinculados_genesis_ring()

		"vinculados_stage_1":
			_build_vinculados_sanctuary_spire()
		"vinculados_stage_2":
			_build_vinculados_crystal_chasm()
		"vinculados_stage_3":
			_build_vinculados_genesis_ring()
		"vinculados_stage_4":
			_build_vinculados_sanctuary_spire()
		"vinculados_stage_5":
			_build_vinculados_crystal_chasm()
		"vinculados_stage_6":
			_build_vinculados_sanctuary_spire()
		"vinculados_stage_7":
			_build_vinculados_crystal_chasm()
		"vinculados_stage_8":
			_build_marea_corsair_haven()
		"vinculados_stage_9":
			_build_acero_sluice_station()
		"vinculados_stage_10":
			_build_vinculados_genesis_ring()
		"vinculados_stage_11":
			_build_acero_calm_bastion()
		"vinculados_stage_12":
			_build_vinculados_genesis_ring()

		"marea_stage_1":
			_build_marea_corsair_haven()
		"marea_stage_2":
			_build_marea_foundry_complex()
		"marea_stage_3":
			_build_marea_wind_maelstrom()
		"marea_stage_4":
			_build_marea_corsair_haven()
		"marea_stage_5":
			_build_marea_foundry_complex()
		"marea_stage_6":
			_build_marea_corsair_haven()
		"marea_stage_7":
			_build_acero_sluice_station()
		"marea_stage_8":
			_build_vinculados_sanctuary_spire()
		"marea_stage_9":
			_build_marea_wind_maelstrom()
		"marea_stage_10":
			_build_acero_calm_bastion()
		"marea_stage_11":
			_build_marea_wind_maelstrom()
		"marea_stage_12":
			_build_marea_corsair_haven()

		_:
			_build_acero_sluice_station()

func _build_acero_sluice_station() -> void:
	# Colossal Textured 3D Acero Éteron Sluice-Gate Refinery ("Well-09", matching card_acero.png & acero_stage1_briefing.png)
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "SluiceStationWell09"
	_stage_landmark_root.position = Vector3(-28.0, -1.0, 4.0)
	_stage_landmark_root.rotation_degrees = Vector3(0.0, 24.0, 0.0)
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

func _build_vinculados_sanctuary_spire() -> void:
	# Colossal Pearlescent Ceramic Resonance Sanctuary Spire ("Psalm-4")
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "SanctuarySpirePsalm4"
	_stage_landmark_root.position = Vector3(-24.0, -2.0, 6.0)
	_stage_landmark_root.rotation_degrees = Vector3(0.0, 18.0, 0.0)
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

func _build_marea_corsair_haven() -> void:
	# Sprawling Void-Pirate Haven carved into a colossal hollowed Basalt Asteroid Reef
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "CorsairHavenBarlovento"
	_stage_landmark_root.position = Vector3(-26.0, 0.0, 4.0)
	_stage_landmark_root.rotation_degrees = Vector3(0.0, 20.0, 0.0)
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

func _build_acero_calm_bastion() -> void:
	# Colossal Acero Forward Defense Bastion ("Bastion-7") facing the Calm wavefront
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "CalmThresholdBastion"
	_stage_landmark_root.position = Vector3(-28.0, 0.0, 8.0)
	_stage_landmark_root.rotation_degrees = Vector3(0.0, 30.0, 0.0)
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

func _build_vinculados_crystal_chasm() -> void:
	# Colossal Twin Crystal Monoliths & Levitating Resonance Ring
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "VinculadosCrystalChasm"
	_stage_landmark_root.position = Vector3(-25.0, 0.0, 5.0)
	_stage_landmark_root.rotation_degrees = Vector3(0.0, 20.0, 0.0)
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

func _build_vinculados_genesis_ring() -> void:
	# Colossal Dual-Gimbal Genesis Resonance Ring & Soul Core
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "VinculadosGenesisRing"
	_stage_landmark_root.position = Vector3(-28.0, 4.0, 5.0)
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

func _build_marea_foundry_complex() -> void:
	# Heavy Industrial Smelter Platform Vulcan-3 being raided
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "FoundryVulcan3"
	_stage_landmark_root.position = Vector3(-26.0, 2.0, 6.0)
	_stage_landmark_root.rotation_degrees = Vector3(0.0, 15.0, 0.0)
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

func _build_marea_wind_maelstrom() -> void:
	# Colossal Astrolabe Eye of the Maelstrom Collector Spire
	_stage_landmark_root = Node3D.new()
	_stage_landmark_root.name = "MaelstromEyeSpire"
	_stage_landmark_root.position = Vector3(-28.0, 0.0, 4.0)
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

func _build_tactical_grid() -> void:
	_tactical_grid = TacticalGrid.new()
	add_child(_tactical_grid)

func _apply_tutorial_handicap(s: Ship, hp_mult: float = 0.65, dmg_mult: float = 0.70) -> void:
	s.hp = roundf(s.hp * hp_mult)
	s.max_hp = s.hp
	s.max_shield_hp = roundf(s.max_shield_hp * hp_mult)
	s.shield_hp = s.max_shield_hp
	s.weapon_damage = roundf(s.weapon_damage * dmg_mult)
	s.set_meta("tutorial_enemy", true)

func _spawn_fleets() -> void:
	match LoreDB.current_stage_id:
		"acero_stage_1":
			# ACT I // STAGE 01 [TUTORIAL]: Defense of Sluice Station Well-09 (Acero vs Free Tide Corsair Scouts)
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-6.0, 5.0, 55.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(6.0, 2.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_corvette", Vector3(18.0, 6.0, 56.0), Vector3.ZERO, 0))

			var e1 := _spawn("marea_raider", Vector3(-6.0, 4.0, -55.0), Vector3(0.0, 0.0, 4.0), 1)
			_apply_tutorial_handicap(e1, 0.65, 0.70)
			_enemy_ships.append(e1)
			var e2 := _spawn("marea_brigantine", Vector3(12.0, 6.0, -52.0), Vector3(0.0, 0.0, 4.5), 1)
			_apply_tutorial_handicap(e2, 0.65, 0.70)
			_enemy_ships.append(e2)
		"acero_stage_2":
			# ACT I // STAGE 02: Ambush at the Resonance Spire (Acero vs Vinculados Choir Wing)
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-6.0, 4.0, 55.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(6.0, 7.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_corvette", Vector3(18.0, 2.0, 56.0), Vector3.ZERO, 0))

			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 4.0, -58.0), Vector3(0.0, 0.0, 3.2), 1))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(-14.0, 8.0, -52.0), Vector3(1.5, 0.0, 4.2), 1))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(14.0, 2.0, -50.0), Vector3(-1.2, 0.0, 4.8), 1))
		"acero_stage_3":
			# ACT I // STAGE 03: The Calm Threshold (Acero vs Veteran Free Tide Flagship Squadron)
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-6.0, 5.0, 55.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(6.0, 3.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_corvette", Vector3(18.0, 6.0, 56.0), Vector3.ZERO, 0))

			var boss_gal := _spawn("marea_galleon", Vector3(-10.0, 6.0, -55.0), Vector3(0.0, 0.0, 3.8), 1)
			boss_gal.hp = roundf(boss_gal.hp * 1.20)
			boss_gal.max_hp = boss_gal.hp
			_enemy_ships.append(boss_gal)
			_enemy_ships.append(_spawn("marea_raider", Vector3(6.0, 3.0, -56.0), Vector3(0.0, 0.0, 4.4), 1))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(20.0, 8.0, -54.0), Vector3(0.0, 0.0, 4.8), 1))
		"marea_stage_1":
			# ACT III // STAGE 01 [TUTORIAL]: The Basalt Narrows (Free Tide Corsairs vs Acero Blockade Picket)
			_player_ships.append(_spawn("marea_galleon", Vector3(-6.0, 5.0, 55.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(6.0, 2.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(18.0, 7.0, 54.0), Vector3.ZERO, 0))

			var me1 := _spawn("acero_battlecruiser", Vector3(-4.0, 4.0, -56.0), Vector3(0.0, 0.0, 3.0), 1)
			_apply_tutorial_handicap(me1, 0.65, 0.70)
			_enemy_ships.append(me1)
			var me2 := _spawn("acero_corvette", Vector3(14.0, 5.0, -52.0), Vector3(0.0, 0.0, 3.5), 1)
			_apply_tutorial_handicap(me2, 0.65, 0.70)
			_enemy_ships.append(me2)
		"vinculados_stage_1":
			# ACT II // STAGE 01 [TUTORIAL]: Sanctuary Spire Psalm-4 (Vinculados Choir vs Acero Extraction Force)
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 2.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(-14.0, 6.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(14.0, -2.0, 50.0), Vector3.ZERO, 0))

			var ve1 := _spawn("acero_battlecruiser", Vector3(-4.0, 4.0, -56.0), Vector3(0.0, 0.0, 3.0), 1)
			_apply_tutorial_handicap(ve1, 0.65, 0.70)
			_enemy_ships.append(ve1)
			var ve2 := _spawn("acero_corvette", Vector3(14.0, 5.0, -52.0), Vector3(0.0, 0.0, 3.5), 1)
			_apply_tutorial_handicap(ve2, 0.65, 0.70)
			_enemy_ships.append(ve2)
		"vinculados_stage_2":
			# ACT II // STAGE 02: The Crystal Chasm (Vinculados diving from upper altitude into Acero column)
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 14.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(-12.0, 16.0, 50.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(12.0, 12.0, 48.0), Vector3.ZERO, 0))

			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-6.0, -8.0, -55.0), Vector3(0.0, 0.0, 3.2), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(10.0, -6.0, -50.0), Vector3(0.0, 0.0, 3.8), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-18.0, -4.0, -48.0), Vector3(0.0, 0.0, 4.5), 1))
		"vinculados_stage_3":
			# ACT II // STAGE 03: Genesis Ring // Transcendence (Nous Ace frame + Carrier defending ring)
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 4.0, 60.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-10.0, 8.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(10.0, 6.0, 54.0), Vector3.ZERO, 0))

			var acero_flag := _spawn("acero_dreadnought", Vector3(0.0, 5.0, -58.0), Vector3(0.0, 0.0, 3.0), 1)
			acero_flag.hp = roundf(acero_flag.hp * 1.25)
			acero_flag.max_hp = acero_flag.hp
			_enemy_ships.append(acero_flag)
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-16.0, 3.0, -52.0), Vector3(0.0, 0.0, 3.5), 1))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(16.0, 7.0, -54.0), Vector3(0.0, 0.0, 3.8), 1))
		"marea_stage_2":
			# ACT III // STAGE 02: Raid on Foundry Vulcan-3 (Free Tide corsairs raiding Acero industrial outpost)
			_player_ships.append(_spawn("marea_galleon", Vector3(-8.0, 4.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(6.0, 8.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(18.0, 2.0, 50.0), Vector3.ZERO, 0))

			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-8.0, 5.0, -54.0), Vector3(0.0, 0.0, 3.2), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(12.0, 3.0, -50.0), Vector3(0.0, 0.0, 4.2), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-20.0, 7.0, -48.0), Vector3(0.0, 0.0, 4.0), 1))
		"marea_stage_3":
			# ACT III // STAGE 03: The Maelstrom of Barlovento (Free Tide Grand Armada in storm convergence)
			var pg := _spawn("marea_galleon", Vector3(0.0, 6.0, 62.0), Vector3.ZERO, 0)
			pg.hp = roundf(pg.hp * 1.20)
			pg.max_hp = pg.hp
			_player_ships.append(pg)
			_player_ships.append(_spawn("marea_brigantine", Vector3(-14.0, 3.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(14.0, 9.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(24.0, 2.0, 50.0), Vector3.ZERO, 0))

			var boss_acero := _spawn("acero_dreadnought", Vector3(0.0, 4.0, -60.0), Vector3(0.0, 0.0, 3.5), 1)
			boss_acero.hp = roundf(boss_acero.hp * 1.30)
			boss_acero.max_hp = boss_acero.hp
			_enemy_ships.append(boss_acero)
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-18.0, 7.0, -54.0), Vector3(0.0, 0.0, 4.0), 1))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(18.0, 10.0, -50.0), Vector3.ZERO, 1))

		# --- ACERO EXPANSION (STAGES 4 - 12) ---
		"acero_stage_4":
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-6.0, 5.0, 55.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_lancer", Vector3(8.0, 3.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_corvette", Vector3(18.0, 6.0, 56.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("marea_raider", Vector3(-10.0, 4.0, -52.0), Vector3(0.0, 0.0, 4.2), 1))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(6.0, 7.0, -50.0), Vector3(0.0, 0.0, 5.0), 1))
			_enemy_ships.append(_spawn("marea_brigantine", Vector3(18.0, 2.0, -54.0), Vector3(0.0, 0.0, 4.5), 1))
		"acero_stage_5":
			_player_ships.append(_spawn("acero_monitor", Vector3(0.0, 4.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-12.0, 6.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_corvette", Vector3(14.0, 2.0, 52.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(-8.0, 5.0, -54.0), Vector3(0.0, 0.0, 3.8), 1))
			_enemy_ships.append(_spawn("marea_bombard", Vector3(10.0, 3.0, -56.0), Vector3(0.0, 0.0, 3.2), 1))
		"acero_stage_6":
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-6.0, 4.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(8.0, 6.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_lancer", Vector3(20.0, 2.0, 52.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("vinculados_chorus", Vector3(0.0, 5.0, -52.0), Vector3(0.0, 0.0, 4.5), 1))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(-16.0, 8.0, -50.0), Vector3(0.0, 0.0, 5.2), 1))
		"acero_stage_7":
			_player_ships.append(_spawn("acero_carrier", Vector3(0.0, 3.0, 60.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-12.0, 5.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_corvette", Vector3(14.0, 7.0, 54.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(-10.0, 4.0, -54.0), Vector3(0.0, 0.0, 3.6), 1))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(10.0, 8.0, -50.0), Vector3(0.0, 0.0, 4.6), 1))
		"acero_stage_8":
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-6.0, 5.0, 55.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_monitor", Vector3(8.0, 3.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_lancer", Vector3(18.0, 7.0, 54.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("vinculados_psyche", Vector3(0.0, 6.0, -50.0), Vector3(0.0, 0.0, 4.8), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(-14.0, 2.0, -52.0), Vector3(0.0, 0.0, 4.0), 1))
		"acero_stage_9":
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-8.0, 5.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(6.0, 3.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_carrier", Vector3(20.0, 6.0, 60.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, -58.0), Vector3(0.0, 0.0, 3.5), 1))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(-16.0, 4.0, -52.0), Vector3(0.0, 0.0, 4.0), 1))
			_enemy_ships.append(_spawn("marea_cutter", Vector3(16.0, 8.0, -48.0), Vector3(0.0, 0.0, 5.2), 1))
		"acero_stage_10":
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-6.0, 4.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_monitor", Vector3(8.0, 5.0, 55.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(20.0, 2.0, 52.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 8.0, -56.0), Vector3(0.0, 0.0, 3.8), 1))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(-16.0, 4.0, -50.0), Vector3(0.0, 0.0, 4.2), 1))
		"acero_stage_11":
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-8.0, 5.0, 60.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_carrier", Vector3(8.0, 3.0, 62.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_battlecruiser", Vector3(-20.0, 7.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_lancer", Vector3(22.0, 4.0, 52.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("marea_galleon", Vector3(-10.0, 5.0, -56.0), Vector3(0.0, 0.0, 3.6), 1))
			_enemy_ships.append(_spawn("vinculados_cradle", Vector3(10.0, 6.0, -58.0), Vector3(0.0, 0.0, 3.4), 1))
			_enemy_ships.append(_spawn("marea_frigate", Vector3(22.0, 3.0, -50.0), Vector3(0.0, 0.0, 4.0), 1))
		"acero_stage_12":
			_player_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 5.0, 65.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_dreadnought", Vector3(-16.0, 4.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_monitor", Vector3(16.0, 6.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("acero_carrier", Vector3(30.0, 3.0, 60.0), Vector3.ZERO, 0))
			var boss12 := _spawn("vinculados_colossus", Vector3(0.0, 8.0, -62.0), Vector3(0.0, 0.0, 3.8), 1)
			boss12.hp = roundf(boss12.hp * 1.35)
			boss12.max_hp = boss12.hp
			_enemy_ships.append(boss12)
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(-20.0, 5.0, -58.0), Vector3(0.0, 0.0, 3.4), 1))
			_enemy_ships.append(_spawn("vinculados_nous", Vector3(20.0, 7.0, -52.0), Vector3(0.0, 0.0, 4.2), 1))

		# --- VINCULADOS EXPANSION (STAGES 4 - 12) ---
		"vinculados_stage_4":
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 3.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(-14.0, 6.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(14.0, 2.0, 50.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-8.0, 4.0, -54.0), Vector3(0.0, 0.0, 3.5), 1))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(12.0, 6.0, -50.0), Vector3(0.0, 0.0, 4.5), 1))
		"vinculados_stage_5":
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 7.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-16.0, 3.0, 60.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(16.0, 9.0, 50.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-10.0, 5.0, -56.0), Vector3(0.0, 0.0, 3.2), 1))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(12.0, 4.0, -52.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(22.0, 6.0, -48.0), Vector3(0.0, 0.0, 4.2), 1))
		"vinculados_stage_6":
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 4.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_chorus", Vector3(-14.0, 6.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(14.0, 3.0, 50.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(0.0, 3.0, -58.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-16.0, 5.0, -52.0), Vector3(0.0, 0.0, 3.6), 1))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(16.0, 7.0, -50.0), Vector3(0.0, 0.0, 4.4), 1))
		"vinculados_stage_7":
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 4.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(-12.0, 6.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(12.0, 3.0, 50.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-8.0, 4.0, -54.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(12.0, 5.0, -52.0), Vector3(0.0, 0.0, 3.0), 1))
		"vinculados_stage_8":
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 4.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(-14.0, 7.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_galleon", Vector3(14.0, 3.0, 54.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-10.0, 5.0, -56.0), Vector3(0.0, 0.0, 3.2), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(10.0, 4.0, -52.0), Vector3(0.0, 0.0, 3.8), 1))
		"vinculados_stage_9":
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 4.0, 60.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_colossus", Vector3(-14.0, 8.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_chorus", Vector3(16.0, 3.0, 50.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 4.0, -60.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(-16.0, 6.0, -54.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(18.0, 3.0, -56.0), Vector3(0.0, 0.0, 3.0), 1))
		"vinculados_stage_10":
			_player_ships.append(_spawn("vinculados_colossus", Vector3(0.0, 8.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-16.0, 4.0, 62.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_psyche", Vector3(16.0, 5.0, 52.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_juggernaut", Vector3(0.0, 5.0, -60.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-18.0, 6.0, -54.0), Vector3(0.0, 0.0, 3.8), 1))
		"vinculados_stage_11":
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 5.0, 60.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_aegis", Vector3(-14.0, 7.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(14.0, 3.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(24.0, 9.0, 48.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-10.0, 4.0, -58.0), Vector3(0.0, 0.0, 3.2), 1))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(12.0, 5.0, -56.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-24.0, 6.0, -50.0), Vector3(0.0, 0.0, 4.5), 1))
		"vinculados_stage_12":
			var lead_col := _spawn("vinculados_colossus", Vector3(0.0, 8.0, 62.0), Vector3.ZERO, 0)
			lead_col.hp = roundf(lead_col.hp * 1.30)
			lead_col.max_hp = lead_col.hp
			_player_ships.append(lead_col)
			_player_ships.append(_spawn("vinculados_cradle", Vector3(-18.0, 4.0, 65.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_chorus", Vector3(18.0, 6.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_nous", Vector3(30.0, 2.0, 52.0), Vector3.ZERO, 0))
			var boss_jugg := _spawn("acero_juggernaut", Vector3(0.0, 5.0, -64.0), Vector3(0.0, 0.0, 3.2), 1)
			boss_jugg.hp = roundf(boss_jugg.hp * 1.40)
			boss_jugg.max_hp = boss_jugg.hp
			_enemy_ships.append(boss_jugg)
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-20.0, 4.0, -58.0), Vector3(0.0, 0.0, 3.5), 1))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(20.0, 6.0, -56.0), Vector3(0.0, 0.0, 3.0), 1))

		# --- MAREA LIBRE EXPANSION (STAGES 4 - 12) ---
		"marea_stage_4":
			_player_ships.append(_spawn("marea_galleon", Vector3(-6.0, 5.0, 55.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_cutter", Vector3(8.0, 3.0, 50.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(18.0, 7.0, 52.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-8.0, 4.0, -54.0), Vector3(0.0, 0.0, 3.6), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(12.0, 5.0, -50.0), Vector3(0.0, 0.0, 4.2), 1))
		"marea_stage_5":
			_player_ships.append(_spawn("marea_galleon", Vector3(-8.0, 5.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(6.0, 7.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_cutter", Vector3(18.0, 2.0, 48.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("marea_leviathan", Vector3(0.0, 5.0, -56.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(16.0, 4.0, -50.0), Vector3(0.0, 0.0, 4.0), 1))
		"marea_stage_6":
			_player_ships.append(_spawn("marea_frigate", Vector3(-6.0, 4.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(8.0, 7.0, 50.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_cutter", Vector3(18.0, 2.0, 48.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(0.0, 3.0, -56.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(-14.0, 5.0, -50.0), Vector3(0.0, 0.0, 4.4), 1))
		"marea_stage_7":
			_player_ships.append(_spawn("marea_bombard", Vector3(0.0, 4.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-14.0, 6.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(14.0, 3.0, 50.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-8.0, 4.0, -56.0), Vector3(0.0, 0.0, 3.2), 1))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(12.0, 5.0, -52.0), Vector3(0.0, 0.0, 3.0), 1))
		"marea_stage_8":
			_player_ships.append(_spawn("marea_galleon", Vector3(-6.0, 4.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_frigate", Vector3(8.0, 7.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(20.0, 2.0, 50.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("vinculados_suit", Vector3(0.0, 6.0, -52.0), Vector3(0.0, 0.0, 4.5), 1))
			_enemy_ships.append(_spawn("vinculados_anima", Vector3(-16.0, 8.0, -48.0), Vector3(0.0, 0.0, 5.0), 1))
		"marea_stage_9":
			_player_ships.append(_spawn("marea_galleon", Vector3(0.0, 6.0, 60.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_frigate", Vector3(-14.0, 4.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_cutter", Vector3(14.0, 8.0, 50.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(24.0, 2.0, 48.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-10.0, 4.0, -58.0), Vector3(0.0, 0.0, 3.5), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(10.0, 6.0, -54.0), Vector3(0.0, 0.0, 4.0), 1))
			_enemy_ships.append(_spawn("acero_lancer", Vector3(22.0, 3.0, -50.0), Vector3(0.0, 0.0, 4.8), 1))
		"marea_stage_10":
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 6.0, 62.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_bombard", Vector3(-14.0, 3.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_frigate", Vector3(14.0, 7.0, 54.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(0.0, 4.0, -60.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(-18.0, 5.0, -54.0), Vector3(0.0, 0.0, 3.8), 1))
			_enemy_ships.append(_spawn("acero_monitor", Vector3(18.0, 3.0, -52.0), Vector3(0.0, 0.0, 3.0), 1))
		"marea_stage_11":
			_player_ships.append(_spawn("marea_leviathan", Vector3(0.0, 7.0, 62.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_galleon", Vector3(-16.0, 4.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_brigantine", Vector3(16.0, 8.0, 54.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_cutter", Vector3(28.0, 2.0, 50.0), Vector3.ZERO, 0))
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(0.0, 4.0, -60.0), Vector3(0.0, 0.0, 3.5), 1))
			_enemy_ships.append(_spawn("vinculados_colossus", Vector3(-18.0, 8.0, -56.0), Vector3(0.0, 0.0, 4.0), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(18.0, 5.0, -52.0), Vector3(0.0, 0.0, 4.0), 1))
		"marea_stage_12":
			var flagship_lev := _spawn("marea_leviathan", Vector3(0.0, 7.0, 65.0), Vector3.ZERO, 0)
			flagship_lev.hp = roundf(flagship_lev.hp * 1.35)
			flagship_lev.max_hp = flagship_lev.hp
			_player_ships.append(flagship_lev)
			_player_ships.append(_spawn("marea_galleon", Vector3(-18.0, 4.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_frigate", Vector3(18.0, 8.0, 56.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("marea_raider", Vector3(30.0, 2.0, 50.0), Vector3.ZERO, 0))
			var boss_kurtz := _spawn("acero_juggernaut", Vector3(0.0, 5.0, -64.0), Vector3(0.0, 0.0, 3.2), 1)
			boss_kurtz.hp = roundf(boss_kurtz.hp * 1.45)
			boss_kurtz.max_hp = boss_kurtz.hp
			_enemy_ships.append(boss_kurtz)
			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-20.0, 4.0, -58.0), Vector3(0.0, 0.0, 3.5), 1))
			_enemy_ships.append(_spawn("acero_carrier", Vector3(20.0, 6.0, -60.0), Vector3(0.0, 0.0, 3.0), 1))
		_:
			# Fallback Sandbox
			_player_ships.append(_spawn("vinculados_cradle", Vector3(0.0, 2.0, 58.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_suit", Vector3(-14.0, 6.0, 52.0), Vector3.ZERO, 0))
			_player_ships.append(_spawn("vinculados_anima", Vector3(14.0, -2.0, 50.0), Vector3.ZERO, 0))

			_enemy_ships.append(_spawn("acero_dreadnought", Vector3(-8.0, 6.0, -55.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_battlecruiser", Vector3(8.0, 3.0, -56.0), Vector3(0.0, 0.0, 3.0), 1))
			_enemy_ships.append(_spawn("acero_corvette", Vector3(20.0, 5.0, -54.0), Vector3(0.0, 0.0, 3.5), 1))

	_tactical_grid.set_ships(_player_ships + _enemy_ships)

	for p in _player_ships:
		p.order.target_speed = minf(10.0, p.state.max_speed * 0.75)
		p.order.yaw = 0.0
		p.order.pitch = 0.0

	_set_selected(_player_ships[0])
	_ace_target = _enemy_ships[0]

func _spawn(id: String, pos: Vector3, vel: Vector3, team: int) -> Ship:
	var def := LoreDB.get_ship(id)
	var ship := Ship.new()
	ship.team = team
	ship.apply_def(def)
	ship.initial_velocity = vel
	ship.position = pos
	ship.ether = _ether
	ship.clicked.connect(_on_ship_clicked)
	ship.right_clicked.connect(_on_ship_right_clicked)
	add_child(ship)
	return ship

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
			var min_dist := 9999.0
			var nearest_name := ""
			var p2 := Vector2(_selected_ship.global_position.x, _selected_ship.global_position.z)
			for seep in _calm_seeps:
				var c2: Vector2 = seep.get("pos2", Vector2.ZERO)
				var rad: float = seep.get("radius", 0.0)
				var edge_dist := maxf(p2.distance_to(c2) - rad, 0.0)
				if edge_dist < min_dist:
					min_dist = edge_dist
					nearest_name = seep.get("name", "Calm Seep")
			if nearest_name != "":
				_ace_panel.set_calm_status("CALM SEEP: %.0fm (%s)" % [min_dist, nearest_name], false)
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

	if _victory_sub_label != null and not promo_lines.is_empty():
		_victory_sub_label.text += "\n\nVETERAN ACE PROMOTIONS (SAVED TO CAMPAIGN):\n" + "\n".join(promo_lines)

	var next_id := _get_next_stage_id()
	if next_id != "":
		SaveManager.unlock_stage(next_id)

	if _victory_next_btn != null:
		_victory_next_btn.visible = (next_id != "")
		if next_id != "":
			var num_str := next_id.get_slice("_", 2)
			_victory_next_btn.text = "▶ PROCEED TO STAGE %s BRIEFING" % num_str.to_upper()
		else:
			_victory_next_btn.text = "▶ PROCEED TO BRIEFING"

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
	_victory_overlay = Control.new()
	_victory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_overlay.visible = false
	layer.add_child(_victory_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.08, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = _hud_theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(650, 350)
	_victory_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_victory_title_label = Label.new()
	match LoreDB.current_stage_id:
		"acero_stage_1":
			_victory_title_label.text = "TUTORIAL ACCOMPLISHED // STEEL ENDURES"
		"acero_stage_2":
			_victory_title_label.text = "STAGE 02 ACCOMPLISHED // THE CHOIR SILENCED"
		"acero_stage_3":
			_victory_title_label.text = "ACT I VICTORY // BASTION OF THE CALM"
		"vinculados_stage_1":
			_victory_title_label.text = "TUTORIAL ACCOMPLISHED // RESONANCE DOCTRINE MASTERED"
		"marea_stage_1":
			_victory_title_label.text = "TUTORIAL ACCOMPLISHED // ÉTHER SAILING MASTERED"
		_:
			_victory_title_label.text = "MISSION ACCOMPLISHED"
	_victory_title_label.add_theme_font_size_override("font_size", 20)
	_victory_title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
	vbox.add_child(_victory_title_label)

	_victory_sub_label = Label.new()
	match LoreDB.current_stage_id:
		"acero_stage_1":
			_victory_sub_label.text = "Sluice Station Well-09 Secured // The Armada of Acero\nYou have mastered basic vector steering, WEGO simultaneous execution, and broadside combat. Refined éteron continues to flow toward the orbital forges of Anvil."
		"acero_stage_2":
			_victory_sub_label.text = "Resonance Spire Secured // The Armada of Acero\nCommander Kaelen's Vinculados Choir Wing was forced to retreat before they could destabilize the sector's Éther currents."
		"acero_stage_3":
			_victory_sub_label.text = "The Calm Threshold Held // Act I Campaign Complete\nAgainst the encroaching Calm, Admiral Vane's veteran squadron broke the coalition vanguard and anchored the Sluice Wall."
		"vinculados_stage_1":
			_victory_sub_label.text = "Sanctuary Spire Psalm-4 Defended // The Vinculados\nYou have mastered high-agility vector maneuvers, neural barrier defense, and focused resonance beam tactics alongside the Carrier Cradle."
		"marea_stage_1":
			_victory_sub_label.text = "The Basalt Narrows Cleared // The Free Tide\nYou have navigated the treacherous asteroid gorge, harnessed the Éther rush of El Río del Viento, and shattered the Acero picket line!"
		_:
			_victory_sub_label.text = "Sector Psalm-4 // Resonance Well Secured\nThe hostile strike group has been repelled. Your squadron holds control of the local Éther currents."
	_victory_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_victory_sub_label.add_theme_font_size_override("font_size", 12)
	_victory_sub_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(_victory_sub_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_victory_next_btn = Button.new()
	_victory_next_btn.text = "▶ PROCEED TO NEXT BRIEFING"
	_victory_next_btn.custom_minimum_size = Vector2(240, 38)
	_victory_next_btn.visible = (_get_next_stage_id() != "")
	_victory_next_btn.pressed.connect(func() -> void:
		_return_to_stage_briefing()
	)
	btn_row.add_child(_victory_next_btn)

	var menu_btn := Button.new()
	menu_btn.text = "◀ CAMPAIGN BRIEFING"
	menu_btn.custom_minimum_size = Vector2(180, 38)
	menu_btn.pressed.connect(func() -> void:
		_return_to_stage_briefing()
	)
	btn_row.add_child(menu_btn)

	var replay_btn := Button.new()
	replay_btn.text = "↻ REPLAY STAGE"
	replay_btn.custom_minimum_size = Vector2(150, 38)
	replay_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
	btn_row.add_child(replay_btn)

func _build_defeat_overlay(layer: CanvasLayer) -> void:
	_defeat_overlay = Control.new()
	_defeat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defeat_overlay.visible = false
	layer.add_child(_defeat_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.01, 0.02, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defeat_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = _hud_theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(580, 310)
	_defeat_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "MISSION FAILED // LINE OF BATTLE BROKEN"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	vbox.add_child(title)

	var sub := Label.new()
	if LoreDB.current_stage_id == "acero_stage_1":
		sub.text = "Sluice Station Well-09 Lost // Flagship CNS Iron Bastion Destroyed\n\nWithout the Anvil-class flagship anchoring the line, Free Tide corsairs breached the sluice gates and cut Anvil's éteron supply spine."
	else:
		sub.text = "Flagship Link Severed // The Squadron Falls Silent\n\nYour command vessel was destroyed in combat."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.95, 0.8, 0.8))
	vbox.add_child(sub)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var menu_btn := Button.new()
	menu_btn.text = "◀ RETURN TO BRIEFING"
	menu_btn.custom_minimum_size = Vector2(230, 38)
	menu_btn.pressed.connect(func() -> void:
		LoreDB.return_to_briefing_stage_id = LoreDB.current_stage_id
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	)
	btn_row.add_child(menu_btn)

	var retry_btn := Button.new()
	retry_btn.text = "↻ RETRY STAGE 01"
	retry_btn.custom_minimum_size = Vector2(180, 38)
	retry_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
	btn_row.add_child(retry_btn)

func _build_help_overlay(layer: CanvasLayer) -> void:
	_help_overlay = Control.new()
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.visible = false
	layer.add_child(_help_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.80)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = _hud_theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(840, 480)
	_help_overlay.add_child(panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(main_vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	main_vbox.add_child(header_row)

	var title := Label.new()
	title.text = "BARLOVENTO // TACTICAL DOCTRINE & FLIGHT MANUAL"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	header_row.add_child(title)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_spacer)

	var to_menu_btn := Button.new()
	to_menu_btn.text = "◀ MAIN MENU"
	to_menu_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	header_row.add_child(to_menu_btn)

	var close_top_btn := Button.new()
	close_top_btn.text = "✕ CLOSE [ESC / H]"
	close_top_btn.pressed.connect(_toggle_help)
	header_row.add_child(close_top_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var content_box := VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 10)
	scroll.add_child(content_box)

	var columns_row := HBoxContainer.new()
	columns_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_row.add_theme_constant_override("separation", 16)
	content_box.add_child(columns_row)

	# Column 1: Admiral Phase
	var col1 := VBoxContainer.new()
	col1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col1.add_theme_constant_override("separation", 6)
	columns_row.add_child(col1)

	var col1_title := Label.new()
	col1_title.text = "PHASE 1: ADMIRAL (STRATEGIC APPROACH)"
	col1_title.add_theme_font_size_override("font_size", 13)
	col1_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	col1.add_child(col1_title)

	var col1_text := Label.new()
	col1_text.text = """Simultaneous 12-second movement window to position fleets and fight for the weather gauge:

Shift + Left-Drag  Point heading & set speed directly on 3D plane
A / D / Arrows     Turn Port / Starboard (Yaw)
Q / E / UP / DN    Climb / Dive (Pitch Up / Down)
W / S              Increase / Decrease throttle
X                  Emergency full retrograde brake
Tab / Click        Select fleet unit
Space              Execute simultaneous WEGO turn

• DIRECTIONAL ARMOR: Bow armor mitigates damage; Stern Rakes deal +40% critical damage!
• BROADSIDE ARCS: Galleons and Dreadnoughts can fire both forward and Port/Starboard broadsides."""
	col1_text.add_theme_font_size_override("font_size", 11)
	col1_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col1.add_child(col1_text)

	# Column 2: Ace Tactical Phase
	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.add_theme_constant_override("separation", 6)
	columns_row.add_child(col2)

	var col2_title := Label.new()
	col2_title.text = "PHASE 2: ACE (SIMULTANEOUS COMBAT ROUNDS)"
	col2_title.add_theme_font_size_override("font_size", 13)
	col2_title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
	col2.add_child(col2_title)

	var col2_text := Label.new()
	col2_text.text = """Intense close-range 3.5s tactical rounds where all units move and resolve combat simultaneously:

1. PLAN: Set heading (Yaw), pitch (Climb/Dive), and speed for your Ace and squadron.
2. TARGET: Click any enemy in 3D or press [C] to lock target.
3. STANCE: Choose Attack (fire lasers during round) or Evasive Drift (+35% defense).
4. RESOLVE: Press SPACE to execute the round! All ships burn thrusters, drift, and open fire simultaneously.
U                  Toggle Auto-Pilot AI on/off for selected ship
M                  Cycle Symphonic Soundtrack (Holst / Dvorak)

CAMERA & BATTLEFIELD:
Left/Middle Drag   Pan battlefield plane
Right-Click Drag   Orbit tactical camera
Mouse Wheel        Smooth zoom in / out (close inspection down to 2.8m)
V / F              Zoom in close to unit / toggle tactical overview
Click Selected     Zoom camera directly to unit
G                  Toggle 3D tactical grid & altitude stems"""
	col2_text.add_theme_font_size_override("font_size", 11)
	col2_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col2.add_child(col2_text)

	var footer_btn := Button.new()
	footer_btn.text = "RETURN TO TACTICAL SIMULATION [ESC / H]"
	footer_btn.pressed.connect(_toggle_help)
	main_vbox.add_child(footer_btn)

func _toggle_help() -> void:
	if _help_overlay != null:
		_help_overlay.visible = not _help_overlay.visible

func _get_tutorial_steps() -> Array[Dictionary]:
	var faction_title := ""
	var faction_body := ""
	match LoreDB.current_stage_id:
		"vinculados_stage_1":
			faction_title = "VINCULADOS DOCTRINE: HIGH AGILE VECTORS & STERN RAKE"
			faction_body = "Your mecha frames have unmatched turn rates and heavy resonance barriers. Slip behind enemy warships to attack their unarmored rear: attacking the aft quadrant scores a STERN RAKE (+40% CRITICAL DAMAGE)! Deploy Barrier to absorb incoming fire."
		"marea_stage_1":
			faction_title = "FREE TIDE DOCTRINE: SURFING THE ÉTHER & BARLOVENTO"
			faction_body = "Sail directly along the cyan currents to gain tailwind velocity. Attacking from upwind secures the Weather-Gauge [BARLOVENTO] (+12% Hit accuracy). Align your flanks to unleash devastating Port & Starboard broadsides (+18% DMG)!"
		_:
			faction_title = "ACERO DOCTRINE: WALL OF STEEL & BROADSIDES"
			faction_body = "Your warships boast impenetrable Bow and Flank armor. Angle your prow toward hostiles to deflect salvos, and Cross the T to unleash heavy Port & Starboard broadsides. Keep Flagship CNS Iron Bastion operational!"

	var steps: Array[Dictionary] = [
		{
			"header": "PHASE 1: STRATEGIC NAVAL CHART (ADMIRAL ORDERS)",
			"body": "Before visual combat, you command the fleet on the 10x8 Strategic Chart. Click adjacent quadrants to order ship moves. Capture Éther Conduits (⚡ +1 AP / +15% Speed) and ride the Barlovento Stream (» +15% Acc / +12% DMG). When ready, press [ENTER] or close to engage in 3D!",
			"tag": "STEP 1/5 • STRATEGIC CHART"
		},
		{
			"header": "PHASE 2: 3D MANEUVERS & NEWTONIAN INERTIA",
			"body": "Click any ship directly or press [TAB] to select it. Drag or use [A/D] (yaw) and [W/S] (throttle speed). Ships possess real mass and inertia — your heading determines which armor quadrant faces enemy guns!",
			"tag": "STEP 2/5 • FLEET MOVEMENT"
		},
		{
			"header": "PHASE 3: ACE TACTICAL COMBAT & AP SYSTEM",
			"body": "When within weapon range, tactical Ace mode activates. Each ship has Action Points (AP). Click ability pills (Broadside, Boost, Shields) at the bottom. Press [Z] to refund AP at any time. Press [SPACE] to resolve the tactical round!",
			"tag": "STEP 3/5 • TACTICAL COMBAT & AP"
		},
		{
			"header": faction_title,
			"body": faction_body,
			"tag": "STEP 4/5 • FACTION SPECIALTY"
		},
		{
			"header": "PHASE 4: THE ENCROACHING CALM (TACTICAL HAZARD)",
			"body": "Violet dimensional fluid pools are seeping from the perimeter. Entering The Calm drains propulsion and damages shields (-15 SHLD / -10 HULL). Push and herd hostile ships into the fluid to destroy them without firing!",
			"tag": "STEP 5/5 • STAR SEA HAZARDS"
		}
	]
	return steps

func _build_tutorial_banner() -> void:
	if not _is_tutorial_stage:
		return

	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.name = "TutorialLayer"
	_tutorial_layer.layer = 25
	add_child(_tutorial_layer)

	_tutorial_banner = PanelContainer.new()
	_tutorial_banner.name = "TutorialGuideBanner"
	_tutorial_banner.theme = _hud_theme
	_tutorial_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tutorial_banner.offset_left = -280
	_tutorial_banner.offset_right = 280
	_tutorial_banner.offset_top = 10
	_tutorial_banner.offset_bottom = 120
	_tutorial_banner.custom_minimum_size = Vector2(560, 105)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.02, 0.05, 0.11, 0.94)
	st.border_color = Color(0.35, 0.90, 1.0, 0.88)
	st.set_border_width_all(1)
	st.border_width_top = 3
	st.set_corner_radius_all(4)
	st.set_content_margin_all(8)
	_tutorial_banner.add_theme_stylebox_override("panel", st)
	_tutorial_layer.add_child(_tutorial_banner)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	_tutorial_banner.add_child(vb)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vb.add_child(top_row)

	var icon_lbl := Label.new()
	icon_lbl.text = "🎓 TACTICAL ACADEMY //"
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	top_row.add_child(icon_lbl)

	_tutorial_step_label = Label.new()
	_tutorial_step_label.text = "STEP 1/4 • FLEET MOVEMENT"
	_tutorial_step_label.add_theme_font_size_override("font_size", 11)
	_tutorial_step_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.75))
	_tutorial_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_tutorial_step_label)

	_tutorial_prev_btn = Button.new()
	_tutorial_prev_btn.text = "◀ PREV [B]"
	_tutorial_prev_btn.theme = _hud_theme
	_tutorial_prev_btn.custom_minimum_size = Vector2(85, 24)
	_tutorial_prev_btn.pressed.connect(func() -> void:
		_set_tutorial_step(_tutorial_step - 1)
	)
	top_row.add_child(_tutorial_prev_btn)

	_tutorial_next_btn = Button.new()
	_tutorial_next_btn.text = "NEXT ▶ [N]"
	_tutorial_next_btn.theme = _hud_theme
	_tutorial_next_btn.custom_minimum_size = Vector2(85, 24)
	_tutorial_next_btn.pressed.connect(func() -> void:
		var max_step := _get_tutorial_steps().size() - 1
		if _tutorial_step >= max_step:
			_tutorial_banner.visible = false
			_add_combat_log("🎓 Tutorial guide dismissed. Press [T] at any time to re-open.", Color(0.4, 0.9, 1.0))
		else:
			_set_tutorial_step(_tutorial_step + 1)
	)
	top_row.add_child(_tutorial_next_btn)

	var close_btn := Button.new()
	close_btn.text = "✕ [X]"
	close_btn.theme = _hud_theme
	close_btn.custom_minimum_size = Vector2(32, 24)
	close_btn.pressed.connect(func() -> void:
		_tutorial_banner.visible = false
		_add_combat_log("🎓 Tutorial guide dismissed. Press [T] to re-open.", Color(0.4, 0.9, 1.0))
	)
	top_row.add_child(close_btn)

	_tutorial_title_label = Label.new()
	_tutorial_title_label.text = ""
	_tutorial_title_label.add_theme_font_size_override("font_size", 12)
	_tutorial_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	vb.add_child(_tutorial_title_label)

	_tutorial_body_label = Label.new()
	_tutorial_body_label.text = ""
	_tutorial_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_body_label.add_theme_font_size_override("font_size", 11)
	_tutorial_body_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	vb.add_child(_tutorial_body_label)

	_set_tutorial_step(0)

func _set_tutorial_step(step: int) -> void:
	var steps := _get_tutorial_steps()
	if steps.is_empty():
		return
	_tutorial_step = clampi(step, 0, steps.size() - 1)
	var s: Dictionary = steps[_tutorial_step]
	if _tutorial_step_label != null:
		_tutorial_step_label.text = String(s.get("tag", ""))
	if _tutorial_title_label != null:
		_tutorial_title_label.text = String(s.get("header", ""))
	if _tutorial_body_label != null:
		_tutorial_body_label.text = String(s.get("body", ""))
	if _tutorial_prev_btn != null:
		_tutorial_prev_btn.disabled = (_tutorial_step == 0)
	if _tutorial_next_btn != null:
		_tutorial_next_btn.text = "GOT IT ✓ [N]" if _tutorial_step == steps.size() - 1 else "NEXT ▶ [N]"
	AudioManager.play_sfx("ui_hover", -14.0)

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
