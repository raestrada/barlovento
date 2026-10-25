class_name RpgHangarModal
extends Control

const RpgDefs = preload("res://scripts/data/rpg_defs.gd")

signal closed
signal proceed_to_briefing_requested(next_stage_id: String)

enum Tab { SPOILS = 0, ACES = 1, SHIPYARD = 2 }

var _current_tab: Tab = Tab.SPOILS
var _current_faction: String = "acero"
var _selected_pilot_name: String = ""
var _selected_ship_id: String = ""
var _spoils_data: Dictionary = {}
var _next_stage_id: String = ""

# UI Containers
var _tab_container: Control
var _tab_spoils_view: Control
var _tab_aces_view: Control
var _tab_shipyard_view: Control

var _credits_label: Label
var _btn_tab_spoils: Button
var _btn_tab_aces: Button
var _btn_tab_shipyard: Button
var _btn_proceed: Button
var _btn_close: Button

# Ace Tab Components
var _pilots_list_vbox: VBoxContainer
var _pilot_portrait_rect: TextureRect
var _pilot_name_lbl: Label
var _pilot_rank_lbl: Label
var _pilot_xp_lbl: Label
var _pilot_xp_bar: ProgressBar
var _pilot_sp_lbl: Label
var _pilot_respec_btn: Button
var _skill_tree_grid: HBoxContainer

# Shipyard Tab Components
var _ships_list_vbox: VBoxContainer
var _ship_name_lbl: Label
var _ship_class_lbl: Label
var _ship_stats_vbox: VBoxContainer
var _upgrades_vbox: VBoxContainer
var _subsystems_vbox: VBoxContainer

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func _ready() -> void:
	_build_ui()

func setup_hangar(faction: String, spoils: Dictionary = {}, next_stage_id: String = "") -> void:
	_current_faction = faction
	_spoils_data = spoils
	_next_stage_id = next_stage_id

	# Set default selections
	var faction_pilots := _get_faction_pilots(faction)
	if not faction_pilots.is_empty():
		_selected_pilot_name = faction_pilots[0]

	var faction_ships := _get_faction_ships(faction)
	if not faction_ships.is_empty():
		_selected_ship_id = faction_ships[0]

	if not spoils.is_empty():
		_switch_tab(Tab.SPOILS)
	else:
		_switch_tab(Tab.ACES)

	_refresh_all()

func _switch_tab(new_tab: Tab) -> void:
	_current_tab = new_tab
	if _tab_spoils_view != null:
		_tab_spoils_view.visible = (new_tab == Tab.SPOILS)
	if _tab_aces_view != null:
		_tab_aces_view.visible = (new_tab == Tab.ACES)
	if _tab_shipyard_view != null:
		_tab_shipyard_view.visible = (new_tab == Tab.SHIPYARD)

	# Update active tab styling
	_update_tab_button_style(_btn_tab_spoils, new_tab == Tab.SPOILS)
	_update_tab_button_style(_btn_tab_aces, new_tab == Tab.ACES)
	_update_tab_button_style(_btn_tab_shipyard, new_tab == Tab.SHIPYARD)

	_refresh_all()

func _refresh_all() -> void:
	if _credits_label != null:
		_credits_label.text = "◈ ÉTERON: %d SHARDS" % SaveManager.eteron_credits

	if _current_tab == Tab.SPOILS:
		_populate_spoils_tab()
	elif _current_tab == Tab.ACES:
		_populate_aces_tab()
	elif _current_tab == Tab.SHIPYARD:
		_populate_shipyard_tab()

	if _btn_proceed != null:
		if _next_stage_id != "":
			var slice := _next_stage_id.get_slice("_", 2)
			_btn_proceed.text = "▶ PROCEED TO STAGE %s BRIEFING" % slice.to_upper()
			_btn_proceed.visible = true
		else:
			_btn_proceed.text = "▶ RETURN TO BRIEFING"
			_btn_proceed.visible = true

func _build_ui() -> void:
	# 1. Dark Backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.025, 0.048, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 2. Main Layout Container
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# 3. Header Row: Title, Tabs, Credits
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 18)
	root_vbox.add_child(header_hbox)

	var title_vbox := VBoxContainer.new()
	title_vbox.custom_minimum_size = Vector2(340, 0)
	header_hbox.add_child(title_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "FLEET HANGAR & ACES"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	title_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "TACTICAL INTERLUDE // UNIT UPGRADES & PILOT PROGRESSION"
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	title_vbox.add_child(sub_lbl)

	# Tab Buttons
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 8)
	tabs_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(tabs_hbox)

	_btn_tab_spoils = _make_tab_button("🎖 BATTLE DEBRIEF", func() -> void: _switch_tab(Tab.SPOILS))
	tabs_hbox.add_child(_btn_tab_spoils)

	_btn_tab_aces = _make_tab_button("👤 ACE QUARTERS", func() -> void: _switch_tab(Tab.ACES))
	tabs_hbox.add_child(_btn_tab_aces)

	_btn_tab_shipyard = _make_tab_button("⚓ FLEET SHIPYARD", func() -> void: _switch_tab(Tab.SHIPYARD))
	tabs_hbox.add_child(_btn_tab_shipyard)

	# Credits indicator
	_credits_label = Label.new()
	_credits_label.text = "◈ ÉTERON: 1,200 SHARDS"
	_credits_label.add_theme_font_size_override("font_size", 15)
	_credits_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28))
	header_hbox.add_child(_credits_label)

	# Divider line
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.20, 0.55, 0.75, 0.45)
	root_vbox.add_child(sep)

	# 4. Tab Views Container
	_tab_container = Control.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_tab_container)

	_build_spoils_view()
	_build_aces_view()
	_build_shipyard_view()

	# 5. Bottom Navigation Bar
	var bottom_sep := ColorRect.new()
	bottom_sep.custom_minimum_size = Vector2(0, 1)
	bottom_sep.color = Color(0.20, 0.55, 0.75, 0.35)
	root_vbox.add_child(bottom_sep)

	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(bottom_hbox)

	_btn_close = Button.new()
	_btn_close.text = "◀ CLOSE HANGAR"
	_btn_close.custom_minimum_size = Vector2(170, 38)
	_btn_close.pressed.connect(func() -> void:
		visible = false
		closed.emit()
	)
	bottom_hbox.add_child(_btn_close)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	_btn_proceed = Button.new()
	_btn_proceed.text = "▶ PROCEED TO NEXT STAGE BRIEFING"
	_btn_proceed.custom_minimum_size = Vector2(280, 42)
	_btn_proceed.add_theme_font_size_override("font_size", 13)
	_btn_proceed.add_theme_color_override("font_color", Color(0.02, 0.06, 0.12))
	var proceed_style := StyleBoxFlat.new()
	proceed_style.bg_color = Color(0.28, 0.88, 0.65)
	proceed_style.set_corner_radius_all(4)
	_btn_proceed.add_theme_stylebox_override("normal", proceed_style)
	_btn_proceed.pressed.connect(func() -> void:
		visible = false
		proceed_to_briefing_requested.emit(_next_stage_id)
	)
	bottom_hbox.add_child(_btn_proceed)

# =============================================================================
# TAB 1: BATTLE DEBRIEF & SPOILS
# =============================================================================

func _build_spoils_view() -> void:
	_tab_spoils_view = Control.new()
	_tab_spoils_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tab_container.add_child(_tab_spoils_view)

func _populate_spoils_tab() -> void:
	for c in _tab_spoils_view.get_children():
		c.queue_free()

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 18)
	_tab_spoils_view.add_child(vbox)

	var header := Label.new()
	header.text = "MISSION ACCOMPLISHED // TACTICAL EVALUATION"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
	vbox.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	vbox.add_child(grid)

	var earned_et: int = int(_spoils_data.get("eteron_earned", 850))
	var earned_xp: int = int(_spoils_data.get("xp_earned", 300))
	var promos: Array = _spoils_data.get("promotions", [])

	grid.add_child(_make_stat_card("◈ ÉTERON RECOVERED", "+%d SHARDS" % earned_et, Color(1.0, 0.85, 0.3)))
	grid.add_child(_make_stat_card("★ ACE COMBAT EXPERIENCE", "+%d XP TO SQUADRON" % earned_xp, Color(0.35, 0.85, 1.0)))
	grid.add_child(_make_stat_card("🏆 FLEET TACTICAL RATING", "S-RANK VANGUARD", Color(0.4, 1.0, 0.5)))

	var promo_panel := PanelContainer.new()
	promo_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.02, 0.05, 0.10, 0.85)
	p_style.border_color = Color(0.20, 0.55, 0.75, 0.45)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(6)
	promo_panel.add_theme_stylebox_override("panel", p_style)
	vbox.add_child(promo_panel)

	var promo_margin := MarginContainer.new()
	promo_margin.add_theme_constant_override("margin_left", 20)
	promo_margin.add_theme_constant_override("margin_right", 20)
	promo_margin.add_theme_constant_override("margin_top", 16)
	promo_margin.add_theme_constant_override("margin_bottom", 16)
	promo_panel.add_child(promo_margin)

	var promo_vbox := VBoxContainer.new()
	promo_vbox.add_theme_constant_override("separation", 10)
	promo_margin.add_child(promo_vbox)

	var p_title := Label.new()
	p_title.text = "PILOT PROMOTIONS & SKILL POINTS (SP) READY FOR ALLOCATION:"
	p_title.add_theme_font_size_override("font_size", 13)
	p_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	promo_vbox.add_child(p_title)

	if promos.is_empty():
		var no_promo := Label.new()
		no_promo.text = "All squadron aces gained combat experience toward their next rank promotion.\nSelect the 'ACE QUARTERS' tab above to inspect pilots and spend available Skill Points."
		no_promo.add_theme_font_size_override("font_size", 12)
		no_promo.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
		promo_vbox.add_child(no_promo)
	else:
		for p in promos:
			var pr_lbl := Label.new()
			pr_lbl.text = "★ %s promoted to Level %d! (+%d SP Available)" % [p.get("pilot_name", ""), p.get("new_level", 2), p.get("sp_gained", 1)]
			pr_lbl.add_theme_font_size_override("font_size", 13)
			pr_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
			promo_vbox.add_child(pr_lbl)

# =============================================================================
# TAB 2: ACE PILOT QUARTERS (HERO SKILL TREES)
# =============================================================================

func _build_aces_view() -> void:
	_tab_aces_view = Control.new()
	_tab_aces_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tab_aces_view.visible = false
	_tab_container.add_child(_tab_aces_view)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 18)
	_tab_aces_view.add_child(hbox)

	# Left Column: Pilot Roster Selector
	var roster_panel := PanelContainer.new()
	roster_panel.custom_minimum_size = Vector2(260, 0)
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.02, 0.05, 0.09, 0.90)
	r_style.border_color = Color(0.18, 0.45, 0.65, 0.45)
	r_style.set_border_width_all(1)
	r_style.set_corner_radius_all(6)
	roster_panel.add_theme_stylebox_override("panel", r_style)
	hbox.add_child(roster_panel)

	var roster_margin := MarginContainer.new()
	roster_margin.add_theme_constant_override("margin_left", 12)
	roster_margin.add_theme_constant_override("margin_right", 12)
	roster_margin.add_theme_constant_override("margin_top", 14)
	roster_margin.add_theme_constant_override("margin_bottom", 14)
	roster_panel.add_child(roster_margin)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 10)
	roster_margin.add_child(r_vbox)

	var r_hdr := Label.new()
	r_hdr.text = "SQUADRON ACES"
	r_hdr.add_theme_font_size_override("font_size", 12)
	r_hdr.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	r_vbox.add_child(r_hdr)

	_pilots_list_vbox = VBoxContainer.new()
	_pilots_list_vbox.add_theme_constant_override("separation", 6)
	r_vbox.add_child(_pilots_list_vbox)

	# Center/Right Area: Selected Pilot Dossier & Skill Tree
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 14)
	hbox.add_child(main_vbox)

	# Pilot Top Info Card
	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(0, 110)
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.025, 0.06, 0.11, 0.88)
	info_style.border_color = Color(0.25, 0.65, 0.85, 0.50)
	info_style.set_border_width_all(1)
	info_style.set_corner_radius_all(6)
	info_panel.add_theme_stylebox_override("panel", info_style)
	main_vbox.add_child(info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 16)
	info_margin.add_theme_constant_override("margin_right", 16)
	info_margin.add_theme_constant_override("margin_top", 12)
	info_margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(info_margin)

	var info_hbox := HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 16)
	info_margin.add_child(info_hbox)

	_pilot_portrait_rect = TextureRect.new()
	_pilot_portrait_rect.custom_minimum_size = Vector2(80, 80)
	_pilot_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pilot_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	info_hbox.add_child(_pilot_portrait_rect)

	var desc_vbox := VBoxContainer.new()
	desc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_vbox.add_theme_constant_override("separation", 4)
	info_hbox.add_child(desc_vbox)

	_pilot_name_lbl = Label.new()
	_pilot_name_lbl.text = "PILOT NAME"
	_pilot_name_lbl.add_theme_font_size_override("font_size", 16)
	_pilot_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	desc_vbox.add_child(_pilot_name_lbl)

	_pilot_rank_lbl = Label.new()
	_pilot_rank_lbl.text = "LEVEL 1 // REGULAR ACE"
	_pilot_rank_lbl.add_theme_font_size_override("font_size", 11)
	_pilot_rank_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	desc_vbox.add_child(_pilot_rank_lbl)

	_pilot_xp_lbl = Label.new()
	_pilot_xp_lbl.text = "XP: 0 / 250"
	_pilot_xp_lbl.add_theme_font_size_override("font_size", 10)
	_pilot_xp_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	desc_vbox.add_child(_pilot_xp_lbl)

	_pilot_xp_bar = ProgressBar.new()
	_pilot_xp_bar.custom_minimum_size = Vector2(240, 8)
	_pilot_xp_bar.show_percentage = false
	desc_vbox.add_child(_pilot_xp_bar)

	# Right side of info card: Available SP + Respec
	var sp_vbox := VBoxContainer.new()
	sp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sp_vbox.add_theme_constant_override("separation", 6)
	info_hbox.add_child(sp_vbox)

	_pilot_sp_lbl = Label.new()
	_pilot_sp_lbl.text = "★ SP AVAILABLE: 0"
	_pilot_sp_lbl.add_theme_font_size_override("font_size", 14)
	_pilot_sp_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	sp_vbox.add_child(_pilot_sp_lbl)

	_pilot_respec_btn = Button.new()
	_pilot_respec_btn.text = "↺ RESET SKILLS (FREE)"
	_pilot_respec_btn.custom_minimum_size = Vector2(160, 30)
	_pilot_respec_btn.pressed.connect(func() -> void:
		SaveManager.respec_pilot_skills(_selected_pilot_name)
		_populate_aces_tab()
	)
	sp_vbox.add_child(_pilot_respec_btn)

	# Skill Tree 3-Branch Grid
	_skill_tree_grid = HBoxContainer.new()
	_skill_tree_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skill_tree_grid.add_theme_constant_override("separation", 14)
	main_vbox.add_child(_skill_tree_grid)

func _populate_aces_tab() -> void:
	# Populate Pilot Selector Buttons
	for c in _pilots_list_vbox.get_children():
		c.queue_free()

	var pilots := _get_faction_pilots(_current_faction)
	if pilots.is_empty():
		return

	if not pilots.has(_selected_pilot_name):
		_selected_pilot_name = pilots[0]

	for p_name in pilots:
		var p_data := SaveManager.get_pilot_data(p_name)
		var btn := Button.new()
		var sp_tag := (" [★%d]" % p_data["sp_available"]) if p_data["sp_available"] > 0 else ""
		btn.text = "%s (L%d)%s" % [p_name, p_data["level"], sp_tag]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if p_name == _selected_pilot_name:
			var active_s := StyleBoxFlat.new()
			active_s.bg_color = Color(0.08, 0.28, 0.42, 0.95)
			active_s.border_color = Color(0.35, 0.85, 1.0)
			active_s.set_border_width_all(1)
			btn.add_theme_stylebox_override("normal", active_s)
		btn.pressed.connect(func() -> void:
			_selected_pilot_name = p_name
			_populate_aces_tab()
		)
		_pilots_list_vbox.add_child(btn)

	# Update Selected Pilot Card
	var sel_data := SaveManager.get_pilot_data(_selected_pilot_name)
	_pilot_name_lbl.text = _selected_pilot_name.to_upper()
	_pilot_rank_lbl.text = "LEVEL %d // %s" % [sel_data["level"], SaveManager.get_veteran_title(sel_data["level"] - 1)]

	# XP Calculations
	var cur_xp: int = sel_data["xp"]
	var target_xp := 250
	match sel_data["level"]:
		1: target_xp = 250
		2: target_xp = 650
		3: target_xp = 1200
		4: target_xp = 2000
		5: target_xp = 2000
	_pilot_xp_lbl.text = "XP: %d / %d" % [cur_xp, target_xp]
	_pilot_xp_bar.max_value = target_xp
	_pilot_xp_bar.value = cur_xp
	_pilot_sp_lbl.text = "★ SP AVAILABLE: %d" % sel_data["sp_available"]

	var portrait_path := _get_pilot_portrait(_selected_pilot_name)
	if ResourceLoader.exists(portrait_path):
		_pilot_portrait_rect.texture = load(portrait_path)

	# Populate Skill Tree Branches (3 Branches)
	for c in _skill_tree_grid.get_children():
		c.queue_free()

	var branch_names := [
		"TACTICAL DOCTRINE\n(Command & AP)",
		"COMBAT MASTERY\n(Penetration & Damage)",
		"HELMSMANSHIP\n(Vector Maneuver & Drift)"
	]

	for b_idx in range(3):
		var branch_panel := PanelContainer.new()
		branch_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b_style := StyleBoxFlat.new()
		b_style.bg_color = Color(0.02, 0.05, 0.09, 0.85)
		b_style.border_color = Color(0.20, 0.45, 0.65, 0.40)
		b_style.set_border_width_all(1)
		b_style.set_corner_radius_all(6)
		branch_panel.add_theme_stylebox_override("panel", b_style)
		_skill_tree_grid.add_child(branch_panel)

		var b_margin := MarginContainer.new()
		b_margin.add_theme_constant_override("margin_left", 12)
		b_margin.add_theme_constant_override("margin_right", 12)
		b_margin.add_theme_constant_override("margin_top", 12)
		b_margin.add_theme_constant_override("margin_bottom", 12)
		branch_panel.add_child(b_margin)

		var b_vbox := VBoxContainer.new()
		b_vbox.add_theme_constant_override("separation", 10)
		b_margin.add_child(b_vbox)

		var b_hdr := Label.new()
		b_hdr.text = branch_names[b_idx]
		b_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_hdr.add_theme_font_size_override("font_size", 11)
		b_hdr.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
		b_vbox.add_child(b_hdr)

		var b_sep := ColorRect.new()
		b_sep.custom_minimum_size = Vector2(0, 1)
		b_sep.color = Color(0.25, 0.55, 0.75, 0.35)
		b_vbox.add_child(b_sep)

		# Add Nodes for this branch
		for node in RpgDefs.get_all_skills():
			if node.branch != b_idx:
				continue
			var is_unlocked: bool = sel_data["skills"].has(node.id)
			var can_unlock: bool = (not is_unlocked) and (sel_data["sp_available"] >= node.cost_sp)
			if node.requires_id != "" and not sel_data["skills"].has(node.requires_id):
				can_unlock = false

			var node_card := _make_skill_card(node, is_unlocked, can_unlock)
			b_vbox.add_child(node_card)

func _make_skill_card(node: RpgDefs.SkillNode, is_unlocked: bool, can_unlock: bool) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if is_unlocked:
		style.bg_color = Color(0.04, 0.18, 0.28, 0.90)
		style.border_color = Color(0.35, 0.95, 0.75)
	elif can_unlock:
		style.bg_color = Color(0.08, 0.14, 0.22, 0.90)
		style.border_color = Color(1.0, 0.80, 0.25)
	else:
		style.bg_color = Color(0.015, 0.035, 0.065, 0.85)
		style.border_color = Color(0.20, 0.30, 0.40, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "T%d: %s" % [node.tier, node.name]
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.75) if is_unlocked else (Color(1.0, 0.85, 0.35) if can_unlock else Color(0.5, 0.6, 0.7)))
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = node.summary
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 9)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92) if (is_unlocked or can_unlock) else Color(0.45, 0.50, 0.60))
	vbox.add_child(desc_lbl)

	if is_unlocked:
		var status := Label.new()
		status.text = "✓ UNLOCKED"
		status.add_theme_font_size_override("font_size", 10)
		status.add_theme_color_override("font_color", Color(0.35, 0.95, 0.75))
		vbox.add_child(status)
	elif can_unlock:
		var learn_btn := Button.new()
		learn_btn.text = "LEARN (1 SP)"
		learn_btn.custom_minimum_size = Vector2(0, 26)
		learn_btn.pressed.connect(func() -> void:
			SaveManager.unlock_pilot_skill(_selected_pilot_name, node.id)
			_populate_aces_tab()
		)
		vbox.add_child(learn_btn)
	else:
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒 LOCKED (REQ PREVIOUS TIER / SP)"
		lock_lbl.add_theme_font_size_override("font_size", 9)
		lock_lbl.add_theme_color_override("font_color", Color(0.45, 0.50, 0.58))
		vbox.add_child(lock_lbl)

	return panel

# =============================================================================
# TAB 3: FLEET SHIPYARD (UNIT ENGINEERING)
# =============================================================================

func _build_shipyard_view() -> void:
	_tab_shipyard_view = Control.new()
	_tab_shipyard_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tab_shipyard_view.visible = false
	_tab_container.add_child(_tab_shipyard_view)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 18)
	_tab_shipyard_view.add_child(hbox)

	# Left Column: Ship Class Selector
	var ship_panel := PanelContainer.new()
	ship_panel.custom_minimum_size = Vector2(260, 0)
	var s_style := StyleBoxFlat.new()
	s_style.bg_color = Color(0.02, 0.05, 0.09, 0.90)
	s_style.border_color = Color(0.18, 0.45, 0.65, 0.45)
	s_style.set_border_width_all(1)
	s_style.set_corner_radius_all(6)
	ship_panel.add_theme_stylebox_override("panel", s_style)
	hbox.add_child(ship_panel)

	var s_margin := MarginContainer.new()
	s_margin.add_theme_constant_override("margin_left", 12)
	s_margin.add_theme_constant_override("margin_right", 12)
	s_margin.add_theme_constant_override("margin_top", 14)
	s_margin.add_theme_constant_override("margin_bottom", 14)
	ship_panel.add_child(s_margin)

	var s_vbox := VBoxContainer.new()
	s_vbox.add_theme_constant_override("separation", 10)
	s_margin.add_child(s_vbox)

	var s_hdr := Label.new()
	s_hdr.text = "FLEET ROSTER"
	s_hdr.add_theme_font_size_override("font_size", 12)
	s_hdr.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	s_vbox.add_child(s_hdr)

	_ships_list_vbox = VBoxContainer.new()
	_ships_list_vbox.add_theme_constant_override("separation", 6)
	s_vbox.add_child(_ships_list_vbox)

	# Right Area: Shipyard Engineering Tracks
	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 14)
	hbox.add_child(main_vbox)

	# Ship Header Info Card
	var info_panel := PanelContainer.new()
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.025, 0.06, 0.11, 0.88)
	info_style.border_color = Color(0.25, 0.65, 0.85, 0.50)
	info_style.set_border_width_all(1)
	info_style.set_corner_radius_all(6)
	info_panel.add_theme_stylebox_override("panel", info_style)
	main_vbox.add_child(info_panel)

	var info_margin := MarginContainer.new()
	info_margin.add_theme_constant_override("margin_left", 16)
	info_margin.add_theme_constant_override("margin_right", 16)
	info_margin.add_theme_constant_override("margin_top", 12)
	info_margin.add_theme_constant_override("margin_bottom", 12)
	info_panel.add_child(info_margin)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 4)
	info_margin.add_child(info_vbox)

	_ship_name_lbl = Label.new()
	_ship_name_lbl.text = "SHIP NAME"
	_ship_name_lbl.add_theme_font_size_override("font_size", 16)
	_ship_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	info_vbox.add_child(_ship_name_lbl)

	_ship_class_lbl = Label.new()
	_ship_class_lbl.text = "CLASS // ROLE"
	_ship_class_lbl.add_theme_font_size_override("font_size", 11)
	_ship_class_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	info_vbox.add_child(_ship_class_lbl)

	_ship_stats_vbox = VBoxContainer.new()
	_ship_stats_vbox.add_theme_constant_override("separation", 2)
	info_vbox.add_child(_ship_stats_vbox)

	# Upgrade Tracks Split (Armor, Weapons, Thrusters) & Subsystems
	var tracks_scroll := ScrollContainer.new()
	tracks_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tracks_scroll)

	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 14)
	tracks_scroll.add_child(scroll_vbox)

	_upgrades_vbox = VBoxContainer.new()
	_upgrades_vbox.add_theme_constant_override("separation", 10)
	scroll_vbox.add_child(_upgrades_vbox)

	_subsystems_vbox = VBoxContainer.new()
	_subsystems_vbox.add_theme_constant_override("separation", 10)
	scroll_vbox.add_child(_subsystems_vbox)

func _populate_shipyard_tab() -> void:
	for c in _ships_list_vbox.get_children():
		c.queue_free()

	var ships := _get_faction_ships(_current_faction)
	if ships.is_empty():
		return

	if not ships.has(_selected_ship_id):
		_selected_ship_id = ships[0]

	for s_id in ships:
		var def := LoreDB.get_ship(s_id)
		var display_title := def.display_name if def != null else s_id.to_upper()
		var btn := Button.new()
		btn.text = display_title
		btn.custom_minimum_size = Vector2(0, 36)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if s_id == _selected_ship_id:
			var active_s := StyleBoxFlat.new()
			active_s.bg_color = Color(0.08, 0.28, 0.42, 0.95)
			active_s.border_color = Color(0.35, 0.85, 1.0)
			active_s.set_border_width_all(1)
			btn.add_theme_stylebox_override("normal", active_s)
		btn.pressed.connect(func() -> void:
			_selected_ship_id = s_id
			_populate_shipyard_tab()
		)
		_ships_list_vbox.add_child(btn)

	# Populate Selected Ship Details
	var sel_def := LoreDB.get_ship(_selected_ship_id)
	if sel_def != null:
		_ship_name_lbl.text = sel_def.display_name.to_upper()
		_ship_class_lbl.text = "%s // COMMANDED BY %s" % [sel_def.class_label.to_upper(), sel_def.pilot_name.to_upper()]

		# Populate Current Stats
		for c in _ship_stats_vbox.get_children():
			c.queue_free()

		var mults := SaveManager.get_ship_effective_multipliers(_selected_ship_id)
		var stat_lbl := Label.new()
		stat_lbl.text = "HP: %.0f (x%.2f)  |  ARMOR: x%.2f  |  DMG: %.0f (x%.2f)  |  SPEED: %.1f m/s  |  THRUST: %.0f" % [
			sel_def.hp * mults["hp_mult"], mults["hp_mult"],
			mults["armor_mult"],
			sel_def.weapon_damage * mults["dmg_mult"], mults["dmg_mult"],
			sel_def.max_speed * mults["speed_mult"],
			sel_def.max_thrust * mults["thrust_mult"]
		]
		stat_lbl.add_theme_font_size_override("font_size", 10)
		stat_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.7))
		_ship_stats_vbox.add_child(stat_lbl)

	# Populate Upgrade Tracks (Armor, Weapons, Engines)
	for c in _upgrades_vbox.get_children():
		c.queue_free()

	var u_data := SaveManager.get_ship_upgrade_data(_selected_ship_id)
	_upgrades_vbox.add_child(_make_track_row("armor", "🛡 DIRECTIONAL ARMOR PLATING", int(u_data.get("armor_lvl", 0)), "+15% Bow, Flank & Stern absorption per tier"))
	_upgrades_vbox.add_child(_make_track_row("weapons", "⚔ HEAVY WEAPON BATTERIES", int(u_data.get("weapon_lvl", 0)), "+12% Salvo damage and lance focusing per tier"))
	_upgrades_vbox.add_child(_make_track_row("engines", "🚀 ÉTHER VECTOR THRUSTERS", int(u_data.get("engine_lvl", 0)), "+15% Thrust acceleration & +10% max velocity per tier"))

	# Populate Faction Subsystems
	for c in _subsystems_vbox.get_children():
		c.queue_free()

	var sub_hdr := Label.new()
	sub_hdr.text = "SIGNATURE FACTION SUBSYSTEMS (EQUIP 1 MODULE):"
	sub_hdr.add_theme_font_size_override("font_size", 12)
	sub_hdr.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_subsystems_vbox.add_child(sub_hdr)

	var sub_list := RpgDefs.get_subsystems_for_faction(_current_faction)
	var active_sub_id := str(u_data.get("subsystem", ""))

	for sub in sub_list:
		var is_installed := (sub.id == active_sub_id)
		var sub_card := _make_subsystem_card(sub, is_installed)
		_subsystems_vbox.add_child(sub_card)

func _make_track_row(category: String, title: String, current_lvl: int, desc: String) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.88)
	style.border_color = Color(0.20, 0.50, 0.70, 0.40)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(text_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "%s [TIER %d / 3]" % [title, current_lvl]
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	text_vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	text_vbox.add_child(desc_lbl)

	var tiers := RpgDefs.get_shipyard_tiers(category)
	var next_lvl := current_lvl + 1
	if next_lvl < tiers.size():
		var target_tier := tiers[next_lvl]
		var can_afford := SaveManager.eteron_credits >= target_tier.cost_eteron
		var up_btn := Button.new()
		up_btn.text = "UPGRADE TO T%d (%d ◈)" % [next_lvl, target_tier.cost_eteron]
		up_btn.custom_minimum_size = Vector2(180, 36)
		up_btn.disabled = not can_afford
		up_btn.pressed.connect(func() -> void:
			SaveManager.purchase_fleet_upgrade(_selected_ship_id, category)
			_refresh_all()
		)
		hbox.add_child(up_btn)
	else:
		var max_lbl := Label.new()
		max_lbl.text = "★ MAX LEVEL"
		max_lbl.add_theme_font_size_override("font_size", 12)
		max_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		hbox.add_child(max_lbl)

	return panel

func _make_subsystem_card(sub: RpgDefs.SubsystemDef, is_installed: bool) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	if is_installed:
		style.bg_color = Color(0.04, 0.18, 0.28, 0.90)
		style.border_color = Color(0.35, 0.95, 0.75)
	else:
		style.bg_color = Color(0.02, 0.05, 0.09, 0.85)
		style.border_color = Color(0.20, 0.45, 0.65, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	name_lbl.text = sub.name.to_upper()
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.75) if is_installed else Color(1.0, 0.85, 0.35))
	text_vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = sub.summary
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
	text_vbox.add_child(desc_lbl)

	if is_installed:
		var inst_lbl := Label.new()
		inst_lbl.text = "✓ INSTALLED"
		inst_lbl.add_theme_font_size_override("font_size", 11)
		inst_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.75))
		hbox.add_child(inst_lbl)
	else:
		var can_afford := SaveManager.eteron_credits >= sub.cost_eteron
		var inst_btn := Button.new()
		inst_btn.text = "INSTALL (%d ◈)" % sub.cost_eteron
		inst_btn.custom_minimum_size = Vector2(150, 34)
		inst_btn.disabled = not can_afford
		inst_btn.pressed.connect(func() -> void:
			SaveManager.purchase_subsystem(_selected_ship_id, sub.id)
			_refresh_all()
		)
		hbox.add_child(inst_btn)

	return panel

# =============================================================================
# HELPER FACTORY METHODS & DATA QUERIES
# =============================================================================

func _make_tab_button(label_text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(170, 36)
	btn.pressed.connect(on_press)
	return btn

func _update_tab_button_style(btn: Button, is_active: bool) -> void:
	if btn == null:
		return
	var style := StyleBoxFlat.new()
	if is_active:
		style.bg_color = Color(0.08, 0.28, 0.44, 0.95)
		style.border_color = Color(0.35, 0.95, 0.75)
		btn.add_theme_color_override("font_color", Color(0.95, 1.0, 1.0))
	else:
		style.bg_color = Color(0.02, 0.06, 0.11, 0.75)
		style.border_color = Color(0.20, 0.45, 0.65, 0.35)
		btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)

func _make_stat_card(header_text: String, val_text: String, col: Color) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.10, 0.85)
	style.border_color = col.darkened(0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var h_lbl := Label.new()
	h_lbl.text = header_text
	h_lbl.add_theme_font_size_override("font_size", 10)
	h_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	vbox.add_child(h_lbl)

	var v_lbl := Label.new()
	v_lbl.text = val_text
	v_lbl.add_theme_font_size_override("font_size", 16)
	v_lbl.add_theme_color_override("font_color", col)
	vbox.add_child(v_lbl)

	return panel

func _get_faction_pilots(faction: String) -> Array[String]:
	match faction:
		"acero":
			return ["Adm. Vane", "Capt. Korr", "Lt. Drake", "Adm. Tarek", "Cmdr. Vance", "Lt. Silas", "Grand Marshall Kurtz"]
		"vinculados":
			return ["Conductor Seraph-2", "Ace Kaelen-7", "Ace Mirei-4", "Ace Orin-9", "Ace Lyra-3", "Conductor Trio", "Ascendant Mind Core", "Ace Ren-1"]
		"marea_libre":
			return ["Capt. Solano", "Quartermaster Vael", "Capt. Moreau", "Commodore Marina", "Bosun Jax", "Helmsman Diego", "Capt. Barbanegra", "First Mate Cortez"]
		_:
			return ["Adm. Vane"]

func _get_faction_ships(faction: String) -> Array[String]:
	match faction:
		"acero":
			return ["acero_dreadnought", "acero_battlecruiser", "acero_corvette", "acero_monitor", "acero_carrier", "acero_lancer", "acero_juggernaut"]
		"vinculados":
			return ["vinculados_cradle", "vinculados_suit", "vinculados_anima", "vinculados_nous", "vinculados_psyche", "vinculados_chorus", "vinculados_colossus", "vinculados_aegis"]
		"marea_libre":
			return ["marea_galleon", "marea_raider", "marea_brigantine", "marea_frigate", "marea_cutter", "marea_sloop", "marea_flagship", "marea_corsair"]
		_:
			return ["acero_dreadnought"]

func _get_pilot_portrait(pilot_name: String) -> String:
	match pilot_name:
		"Adm. Vane": return "res://assets/heroes/ace_vane.png"
		"Capt. Korr": return "res://assets/heroes/ace_korr.png"
		"Lt. Drake": return "res://assets/heroes/ace_drake.png"
		"Adm. Tarek": return "res://assets/heroes/ace_tarek.png"
		"Cmdr. Vance": return "res://assets/heroes/ace_vance.png"
		"Grand Marshall Kurtz": return "res://assets/heroes/ace_kurtz.png"
		"Conductor Seraph-2": return "res://assets/heroes/ace_seraph.png"
		"Ace Kaelen-7": return "res://assets/heroes/ace_kaelen.png"
		"Ace Mirei-4": return "res://assets/heroes/ace_mirei.png"
		"Ace Orin-9": return "res://assets/heroes/ace_orin.png"
		"Ace Lyra-3": return "res://assets/heroes/ace_lyra.png"
		"Capt. Solano": return "res://assets/heroes/ace_solano.png"
		"Quartermaster Vael": return "res://assets/heroes/ace_vael.png"
		"Capt. Moreau": return "res://assets/heroes/ace_moreau.png"
		"Commodore Marina": return "res://assets/heroes/ace_marina.png"
		"Capt. Barbanegra": return "res://assets/heroes/ace_barbanegra.png"
		_: return "res://assets/heroes/ace_vane.png"
