extends Node

signal god_mode_toggled(enabled: bool)
signal stage_jumped(stage_id: String)

var god_mode: bool = false
var infinite_ap: bool = false
var speed_multiplier: float = 1.0

var _canvas_layer: CanvasLayer
var _panel: PanelContainer
var _god_btn: Button
var _speed_btn: Button
var _ap_btn: Button
var _status_hud_badge: Label
var _stage_container: VBoxContainer
var _tab_bar: TabBar
var _current_tab: int = 0

const STAGES: Dictionary = {
	"acero": [
		{"id": "acero_stage_1", "name": "01: Defense of Sluice Station Well-09"},
		{"id": "acero_stage_2", "name": "02: Resonance Spire Defense"},
		{"id": "acero_stage_3", "name": "03: The Calm Threshold (Act I Finale)"},
		{"id": "acero_stage_4", "name": "04: Obsidian Trench Picket"},
		{"id": "acero_stage_5", "name": "05: Foundry Fortress Vulcan-3"},
		{"id": "acero_stage_6", "name": "06: The Great Iron Dam (Act II Finale)"},
		{"id": "acero_stage_7", "name": "07: Crucible Breach & Counter-Attack"},
		{"id": "acero_stage_8", "name": "08: Iron Citadel Deep Siege"},
		{"id": "acero_stage_9", "name": "09: Heavy Escort Convoy Vanguard"},
		{"id": "acero_stage_10", "name": "10: Event Horizon Bastion"},
		{"id": "acero_stage_11", "name": "11: Juggernaut Imperator Stand"},
		{"id": "acero_stage_12", "name": "12: Calm Singularity Supreme Climax"},
	],
	"vinculados": [
		{"id": "vinculados_stage_1", "name": "01: Sanctuary Spire Psalm-4"},
		{"id": "vinculados_stage_2", "name": "02: Basalt Chasm Dive Maneuver"},
		{"id": "vinculados_stage_3", "name": "03: Choir Resonance Trial (Act I Finale)"},
		{"id": "vinculados_stage_4", "name": "04: Requiem of Outer Shrines"},
		{"id": "vinculados_stage_5", "name": "05: The Ancient Genesis Ring"},
		{"id": "vinculados_stage_6", "name": "06: The Transcendence Gate (Act II Finale)"},
		{"id": "vinculados_stage_7", "name": "07: Seraph-Prime Awakening"},
		{"id": "vinculados_stage_8", "name": "08: Psycho-Frame Synchrony Drill"},
		{"id": "vinculados_stage_9", "name": "09: Radiant Spire Perimeter Defense"},
		{"id": "vinculados_stage_10", "name": "10: Harmonizer Singularity Breakthrough"},
		{"id": "vinculados_stage_11", "name": "11: Celestial Ascension Gate"},
		{"id": "vinculados_stage_12", "name": "12: Apex Transcendence Supreme Climax"},
	],
	"marea_libre": [
		{"id": "marea_stage_1", "name": "01: The Basalt Narrows Rapids"},
		{"id": "marea_stage_2", "name": "02: Vulcan Foundry Smelter Ambush"},
		{"id": "marea_stage_3", "name": "03: Maelstrom of Barlovento (Act I Finale)"},
		{"id": "marea_stage_4", "name": "04: Privateer Raid Run"},
		{"id": "marea_stage_5", "name": "05: Prize of the Soberano"},
		{"id": "marea_stage_6", "name": "06: Weather-Gauge Storm Surfing (Act II Finale)"},
		{"id": "marea_stage_7", "name": "07: Grand Corsair Fleet Rally"},
		{"id": "marea_stage_8", "name": "08: Solar Corona Gauntlet"},
		{"id": "marea_stage_9", "name": "09: Imperial Picket Hunt"},
		{"id": "marea_stage_10", "name": "10: Tidal Rapids Escape Run"},
		{"id": "marea_stage_11", "name": "11: Leviathan Grand Broadside"},
		{"id": "marea_stage_12", "name": "12: King of Barlovento Supreme Climax"},
	]
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Shift + Ctrl + D (or Ctrl + Shift + D)
		if event.keycode == KEY_D and event.ctrl_pressed and event.shift_pressed:
			toggle_dev_panel()
			get_viewport().set_input_as_handled()

func toggle_dev_panel() -> void:
	if _panel == null:
		return
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh_ui_state()

func set_god_mode(enabled: bool) -> void:
	god_mode = enabled
	god_mode_toggled.emit(god_mode)
	_refresh_ui_state()
	if _status_hud_badge != null:
		_status_hud_badge.visible = god_mode

func toggle_god_mode() -> void:
	set_god_mode(not god_mode)

func toggle_speed() -> void:
	if Engine.time_scale < 1.5:
		Engine.time_scale = 2.0
		speed_multiplier = 2.0
	elif Engine.time_scale < 3.5:
		Engine.time_scale = 4.0
		speed_multiplier = 4.0
	else:
		Engine.time_scale = 1.0
		speed_multiplier = 1.0
	_refresh_ui_state()

func toggle_infinite_ap() -> void:
	infinite_ap = not infinite_ap
	_refresh_ui_state()

func instant_victory() -> void:
	_panel.visible = false
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		if tree.current_scene.has_method("_show_mission_victory"):
			tree.current_scene._show_mission_victory()
		elif tree.current_scene.has_method("instant_victory"):
			tree.current_scene.instant_victory()

func kill_all_enemies() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene = tree.current_scene
	if "_enemy_ships" in scene:
		var enemies: Array = scene._enemy_ships
		for enemy in enemies:
			if enemy != null and is_instance_valid(enemy) and not enemy.is_destroyed():
				enemy.take_directional_damage(99999.0, "STERN")

func repair_fleet() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene = tree.current_scene
	if "_player_ships" in scene:
		var allies: Array = scene._player_ships
		for ally in allies:
			if ally != null and is_instance_valid(ally) and not ally.is_destroyed():
				ally.hp = ally.max_hp
				ally.shield_hp = ally.max_shield_hp
				ally.armor_bow = 100.0
				ally.armor_port = 100.0
				ally.armor_stbd = 100.0
				ally.armor_stern = 100.0
				if ally.has_method("_update_overhead_hp"):
					ally._update_overhead_hp()

func unlock_all_stages() -> void:
	for fac in STAGES.keys():
		for st in STAGES[fac]:
			SaveManager.unlocked_stages[st["id"]] = true
	SaveManager.save_campaign()
	_refresh_ui_state()

func jump_to_stage(stage_id: String, faction: String) -> void:
	LoreDB.selected_faction = faction
	LoreDB.current_stage_id = stage_id
	SaveManager.unlock_stage(stage_id)
	_panel.visible = false
	stage_jumped.emit(stage_id)
	var scene_trans = get_node_or_null("/root/SceneTransition")
	if scene_trans != null:
		scene_trans.load_scene("res://scenes/sandbox/sandbox.tscn", faction)
	else:
		get_tree().change_scene_to_file("res://scenes/sandbox/sandbox.tscn")

func _refresh_ui_state() -> void:
	if _god_btn != null:
		_god_btn.text = "⚡ GOD MODE: ON (IMMUNE + AUTO-WIN)" if god_mode else "⚡ GOD MODE: OFF"
		_god_btn.modulate = Color(0.3, 1.0, 0.45) if god_mode else Color(0.75, 0.75, 0.75)
	if _speed_btn != null:
		_speed_btn.text = "⏩ SPEED: %.0fx" % Engine.time_scale
		_speed_btn.modulate = Color(1.0, 0.85, 0.3) if Engine.time_scale > 1.0 else Color(0.85, 0.85, 0.85)
	if _ap_btn != null:
		_ap_btn.text = "♾️ INFINITE AP: ON" if infinite_ap else "♾️ INFINITE AP: OFF"
		_ap_btn.modulate = Color(0.4, 0.9, 1.0) if infinite_ap else Color(0.75, 0.75, 0.75)
	if _status_hud_badge != null:
		_status_hud_badge.visible = god_mode

func _build_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 999
	add_child(_canvas_layer)

	# Global HUD badge shown when God Mode is active
	_status_hud_badge = Label.new()
	_status_hud_badge.text = "⚡ DEV GOD MODE ACTIVE (IMMUNE // AUTO-WIN)"
	_status_hud_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status_hud_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_hud_badge.position = Vector2(0, 4)
	_status_hud_badge.add_theme_font_size_override("font_size", 11)
	_status_hud_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_status_hud_badge.visible = false
	_status_hud_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_status_hud_badge)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(720, 520)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	_canvas_layer.add_child(_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.12, 0.96)
	sb.border_color = Color(0.2, 0.8, 1.0, 0.85)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(root_vbox)

	# --- Title Bar ---
	var title_row := HBoxContainer.new()
	root_vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "⚡ BARLOVENTO // DEVELOPER CONSOLE & INTEGRAL TEST SUITE"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕ CLOSE [Ctrl+Shift+D]"
	close_btn.pressed.connect(func() -> void: _panel.visible = false)
	title_row.add_child(close_btn)

	var sep1 := HSeparator.new()
	root_vbox.add_child(sep1)

	# --- Quick Dev Controls ---
	var controls_grid := GridContainer.new()
	controls_grid.columns = 3
	controls_grid.add_theme_constant_override("h_separation", 8)
	controls_grid.add_theme_constant_override("v_separation", 8)
	root_vbox.add_child(controls_grid)

	_god_btn = Button.new()
	_god_btn.text = "⚡ GOD MODE: OFF"
	_god_btn.custom_minimum_size = Vector2(220, 36)
	_god_btn.pressed.connect(toggle_god_mode)
	controls_grid.add_child(_god_btn)

	_speed_btn = Button.new()
	_speed_btn.text = "⏩ SPEED: 1x"
	_speed_btn.custom_minimum_size = Vector2(220, 36)
	_speed_btn.pressed.connect(toggle_speed)
	controls_grid.add_child(_speed_btn)

	_ap_btn = Button.new()
	_ap_btn.text = "♾️ INFINITE AP: OFF"
	_ap_btn.custom_minimum_size = Vector2(220, 36)
	_ap_btn.pressed.connect(toggle_infinite_ap)
	controls_grid.add_child(_ap_btn)

	var vic_btn := Button.new()
	vic_btn.text = "🏆 INSTANT VICTORY"
	vic_btn.custom_minimum_size = Vector2(220, 36)
	vic_btn.pressed.connect(instant_victory)
	controls_grid.add_child(vic_btn)

	var kill_btn := Button.new()
	kill_btn.text = "💀 KILL ALL ENEMIES"
	kill_btn.custom_minimum_size = Vector2(220, 36)
	kill_btn.pressed.connect(kill_all_enemies)
	controls_grid.add_child(kill_btn)

	var heal_btn := Button.new()
	heal_btn.text = "🛡️ REPAIR & SHIELDS"
	heal_btn.custom_minimum_size = Vector2(220, 36)
	heal_btn.pressed.connect(repair_fleet)
	controls_grid.add_child(heal_btn)

	var unlock_btn := Button.new()
	unlock_btn.text = "🔓 UNLOCK ALL 36 STAGES"
	unlock_btn.custom_minimum_size = Vector2(220, 36)
	unlock_btn.pressed.connect(unlock_all_stages)
	controls_grid.add_child(unlock_btn)

	var music_btn := Button.new()
	music_btn.text = "🎵 NEXT MUSIC TRACK"
	music_btn.custom_minimum_size = Vector2(220, 36)
	music_btn.pressed.connect(func() -> void: AudioManager.next_battle_track())
	controls_grid.add_child(music_btn)

	var sep2 := HSeparator.new()
	root_vbox.add_child(sep2)

	# --- Stage Jump Section ---
	var stage_header := Label.new()
	stage_header.text = "🚀 DIRECT STAGE JUMP (SELECT ANY OF 36 CAMPAIGN STAGES):"
	stage_header.add_theme_font_size_override("font_size", 12)
	stage_header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	root_vbox.add_child(stage_header)

	_tab_bar = TabBar.new()
	_tab_bar.add_tab("ARMADA OF ACERO (12)")
	_tab_bar.add_tab("THE VINCULADOS (12)")
	_tab_bar.add_tab("THE FREE TIDE (12)")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	root_vbox.add_child(_tab_bar)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	_stage_container = VBoxContainer.new()
	_stage_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_stage_container)

	_populate_stage_buttons("acero")

func _on_tab_changed(tab: int) -> void:
	_current_tab = tab
	var faction := "acero"
	if tab == 1:
		faction = "vinculados"
	elif tab == 2:
		faction = "marea_libre"
	_populate_stage_buttons(faction)

func _populate_stage_buttons(faction: String) -> void:
	for child in _stage_container.get_children():
		child.queue_free()

	var stage_list: Array = STAGES.get(faction, [])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_container.add_child(grid)

	for stage_info in stage_list:
		var btn := Button.new()
		btn.text = stage_info["name"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(330, 30)
		var sid: String = stage_info["id"]
		var fac: String = faction
		btn.pressed.connect(func() -> void: jump_to_stage(sid, fac))
		grid.add_child(btn)
