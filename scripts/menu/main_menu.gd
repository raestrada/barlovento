extends Control

enum MenuView { TITLE, FACTION_SELECT, BRIEFING }

var _current_view: MenuView = MenuView.TITLE
var _selected_faction: String = "acero"
var _focused_faction: String = "overview"

var _bg_viewport: SubViewport
var _bg_cam: Camera3D
var _bg_backdrop: StarSeaBackdrop
var _cam_pos_cur: Vector3 = Vector3(0.0, 26.0, 72.0)
var _cam_target_cur: Vector3 = Vector3(0.0, 4.0, -30.0)

var _title_container: Control
var _faction_container: Control
var _briefing_container: Control
var _roster_modal: HudWidgets.HeroRosterModal
var _fade_rect: ColorRect
var _theme: Theme
var _anim_time: float = 0.0

var _briefing_title_lbl: Label
var _briefing_sub_lbl: Label
var _briefing_art_rect: TextureRect
var _commander_portrait_rect: TextureRect
var _commander_name_lbl: Label
var _commander_role_lbl: Label
var _commander_quote_lbl: Label
var _objectives_lbl: Label
var _squadron_vbox: VBoxContainer
var _stage_selector_row: HBoxContainer
var _launch_stage_btn: Button

func _ready() -> void:
	_theme = _build_menu_theme()
	theme = _theme

	_build_background()
	_build_top_bar()
	_build_title_view()
	_build_faction_select_view()
	_build_briefing_view()

	_roster_modal = HudWidgets.HeroRosterModal.new()
	_roster_modal.theme = _theme
	add_child(_roster_modal)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.01, 0.02, 0.04, 1.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, 0.65)

	AudioManager.play_menu_music(-11.0)
	AudioManager.start_ambient(-24.0)

	if LoreDB.return_to_briefing_stage_id != "":
		var target_stage := LoreDB.return_to_briefing_stage_id
		LoreDB.return_to_briefing_stage_id = ""
		var fac := "acero"
		if target_stage.begins_with("vinculados"):
			fac = "vinculados"
		elif target_stage.begins_with("marea"):
			fac = "marea_libre"
		_selected_faction = fac
		_focused_faction = fac
		LoreDB.selected_faction = fac
		if fac == "acero":
			_populate_acero_stage_briefing(target_stage)
		elif fac == "vinculados":
			_populate_vinculados_stage_briefing(target_stage)
		elif fac == "marea_libre":
			_populate_marea_stage_briefing(target_stage)
		_switch_view(MenuView.BRIEFING)
	else:
		_switch_view(MenuView.TITLE)

func _process(delta: float) -> void:
	_anim_time += delta
	if _bg_cam != null and _bg_backdrop != null:
		var focus_info: Dictionary = _bg_backdrop.get_faction_focus_transform(_focused_faction, _anim_time)
		var desired_pos: Vector3 = focus_info.get("cam_pos", Vector3(0.0, 26.0, 72.0))
		var desired_target: Vector3 = focus_info.get("look_target", Vector3(0.0, 4.0, -30.0))
		_cam_pos_cur = _cam_pos_cur.lerp(desired_pos, clampf(delta * 2.2, 0.0, 1.0))
		_cam_target_cur = _cam_target_cur.lerp(desired_target, clampf(delta * 2.6, 0.0, 1.0))
		_bg_cam.global_position = _cam_pos_cur
		if _cam_pos_cur.distance_to(_cam_target_cur) > 0.1:
			_bg_cam.look_at(_cam_target_cur, Vector3.UP)

func _build_background() -> void:
	var base_bg := ColorRect.new()
	base_bg.color = Color(0.008, 0.014, 0.032, 1.0)
	base_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base_bg)

	var vp_container := SubViewportContainer.new()
	vp_container.stretch = true
	vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vp_container)

	_bg_viewport = SubViewport.new()
	_bg_viewport.own_world_3d = true
	_bg_viewport.msaa_3d = Viewport.MSAA_4X
	_bg_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(_bg_viewport)

	_bg_backdrop = StarSeaBackdrop.new()
	_bg_backdrop.name = "StarSeaBackdrop"
	_bg_viewport.add_child(_bg_backdrop)
	_bg_backdrop.setup_environment(true)

	_bg_cam = Camera3D.new()
	_bg_cam.fov = 50.0
	_bg_cam.near = 0.2
	_bg_cam.far = 2500.0
	_bg_cam.position = _cam_pos_cur
	_bg_viewport.add_child(_bg_cam)
	_bg_cam.look_at(_cam_target_cur, Vector3.UP)

	var vignette := ColorRect.new()
	vignette.color = Color(0.006, 0.016, 0.038, 0.26)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

func _build_top_bar() -> void:
	var top_bar := PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 68
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.015, 0.03, 0.065, 0.84)
	bar_style.border_color = Color(0.22, 0.72, 0.92, 0.45)
	bar_style.border_width_bottom = 1
	bar_style.content_margin_left = 24
	bar_style.content_margin_right = 24
	bar_style.content_margin_top = 8
	bar_style.content_margin_bottom = 8
	top_bar.add_theme_stylebox_override("panel", bar_style)
	add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	top_bar.add_child(hbox)

	# Canonical BARLOVENTO Wordmark (AGENTS.md Rule 8)
	var logo_tex: Texture2D = load("res://assets/brand/logo.png")
	if logo_tex != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = logo_tex
		atlas.region = Rect2(80, 220, 1216, 280)
		var logo_rect := TextureRect.new()
		logo_rect.texture = atlas
		logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo_rect.custom_minimum_size = Vector2(230, 48)
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(logo_rect)

	var vsep := VSeparator.new()
	hbox.add_child(vsep)

	var subtitle := Label.new()
	subtitle.text = "CHRONICLES OF THE STAR SEA // TACTICAL NAVAL COMMAND"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.85, 0.98))
	hbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var build_lbl := Label.new()
	build_lbl.text = "GODOT 4.7.2 // FORWARD+ // VER 1.0"
	build_lbl.add_theme_font_size_override("font_size", 10)
	build_lbl.add_theme_color_override("font_color", Color(0.45, 0.62, 0.78))
	hbox.add_child(build_lbl)

func _build_title_view() -> void:
	_title_container = Control.new()
	_title_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_container.offset_top = 76
	add_child(_title_container)

	var main_margin := MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 42)
	main_margin.add_theme_constant_override("margin_right", 42)
	main_margin.add_theme_constant_override("margin_top", 28)
	main_margin.add_theme_constant_override("margin_bottom", 32)
	_title_container.add_child(main_margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	main_margin.add_child(row)

	# Left Column: Command Menu Panel
	var menu_panel := PanelContainer.new()
	menu_panel.custom_minimum_size = Vector2(430, 0)
	menu_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(menu_panel)

	var menu_vbox := VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 10)
	menu_panel.add_child(menu_vbox)

	var cmd_hdr := Label.new()
	cmd_hdr.text = "FLEET OPERATIONS COMMAND"
	cmd_hdr.add_theme_font_size_override("font_size", 18)
	cmd_hdr.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	menu_vbox.add_child(cmd_hdr)

	var lore_blurb := Label.new()
	lore_blurb.text = "The Star Sea is dying. An encroaching front of decay — The Calm — extinguishes the Éther currents across the Concord. Three civilizations answer the crisis with steel, soul, and wind."
	lore_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_blurb.add_theme_font_size_override("font_size", 11)
	lore_blurb.add_theme_color_override("font_color", Color(0.76, 0.85, 0.94))
	menu_vbox.add_child(lore_blurb)

	menu_vbox.add_child(HSeparator.new())

	if SaveManager.has_tactical_save():
		var btn_resume := _make_menu_button(
			"📂  RESUME SAVED BATTLE",
			SaveManager.get_tactical_save_summary(),
			true
		)
		btn_resume.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click", -8.0)
			var st := SaveManager.load_tactical_state()
			LoreDB.current_stage_id = String(st.get("stage_id", "acero_stage_1"))
			SaveManager.pending_load_battle = true
			_transition_to_scene("res://scenes/sandbox/sandbox.tscn")
		)
		menu_vbox.add_child(btn_resume)

	var btn_campaign := _make_menu_button(
		"▶  CAMPAIGN // SELECT FACTION",
		"Choose your civilization and enter the War for the Star Sea",
		not SaveManager.has_tactical_save()
	)
	btn_campaign.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_switch_view(MenuView.FACTION_SELECT)
	)
	menu_vbox.add_child(btn_campaign)

	var btn_acero_direct := _make_menu_button(
		"⚡  ACT I: THE ARMADA OF ACERO (3 STAGES)",
		"Operation Anvil Gate — Defend Sluice Station Well-09 & The Calm",
		false
	)
	btn_acero_direct.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_select_faction_and_open_briefing("acero")
	)
	menu_vbox.add_child(btn_acero_direct)

	var btn_sandbox := _make_menu_button(
		"⚔  TACTICAL SKIRMISH SANDBOX",
		"Instant 3D naval engagement in Sector Psalm-4",
		false
	)
	btn_sandbox.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		LoreDB.selected_faction = "vinculados"
		LoreDB.current_stage_id = "sandbox"
		_transition_to_scene("res://scenes/sandbox/sandbox.tscn")
	)
	menu_vbox.add_child(btn_sandbox)

	var btn_roster := _make_menu_button(
		"★  HEROES & FLEET ARCHIVES",
		"Inspect Ace pilots, Admirals, and warship specifications",
		false
	)
	btn_roster.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		if _roster_modal != null:
			_roster_modal.visible = true
	)
	menu_vbox.add_child(btn_roster)

	var btn_intro := _make_menu_button(
		"🎬  REPLAY INTRO CINEMATIC",
		"Watch the Barlovento opening prologue",
		false
	)
	btn_intro.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_transition_to_scene("res://scenes/intro/intro.tscn")
	)
	menu_vbox.add_child(btn_intro)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_vbox.add_child(spacer)

	var btn_quit := Button.new()
	btn_quit.text = "✕  EXIT TO DESKTOP"
	btn_quit.custom_minimum_size = Vector2(0, 38)
	btn_quit.pressed.connect(func() -> void: get_tree().quit())
	menu_vbox.add_child(btn_quit)

	# Right Column: Featured Act I Campaign Showcase Card
	var showcase_panel := PanelContainer.new()
	showcase_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	showcase_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(showcase_panel)

	var sc_vbox := VBoxContainer.new()
	sc_vbox.add_theme_constant_override("separation", 10)
	showcase_panel.add_child(sc_vbox)

	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 10)
	sc_vbox.add_child(badge_row)

	var act_badge := Label.new()
	act_badge.text = "[FEATURED CAMPAIGN // ACT I]"
	act_badge.add_theme_font_size_override("font_size", 12)
	act_badge.add_theme_color_override("font_color", Color(1.0, 0.62, 0.22))
	badge_row.add_child(act_badge)

	var act_title := Label.new()
	act_title.text = "THE ARMADA OF ACERO — \"STEEL ENDURES\""
	act_title.add_theme_font_size_override("font_size", 15)
	act_title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	badge_row.add_child(act_title)

	var art_holder := PanelContainer.new()
	art_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc_vbox.add_child(art_holder)

	var stage_art := TextureRect.new()
	var st_tex: Texture2D = load("res://assets/factions/acero_stage1_briefing.png")
	if st_tex == null:
		st_tex = load("res://assets/ships/acero/dreadnought_concept.png")
	stage_art.texture = st_tex
	stage_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_holder.add_child(stage_art)

	var sc_desc := Label.new()
	sc_desc.text = "STAGE 01: DEFENSE OF SLUICE STATION WELL-09 — Command Fleet Admiral Vane aboard the Anvil-class Dreadnought CNS Iron Bastion. Hold the line of battle above the Éther river and repel Captain Solano's Free Tide corsair raid."
	sc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sc_desc.add_theme_font_size_override("font_size", 12)
	sc_desc.add_theme_color_override("font_color", Color(0.82, 0.90, 0.98))
	sc_vbox.add_child(sc_desc)

	var sc_footer := HBoxContainer.new()
	sc_footer.alignment = BoxContainer.ALIGNMENT_END
	sc_footer.add_theme_constant_override("separation", 12)
	sc_vbox.add_child(sc_footer)

	var choose_fac_btn := Button.new()
	choose_fac_btn.text = "CHOOSE FACTION (3 CIVILIZATIONS)"
	choose_fac_btn.custom_minimum_size = Vector2(260, 42)
	choose_fac_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_switch_view(MenuView.FACTION_SELECT)
	)
	sc_footer.add_child(choose_fac_btn)

	var play_acero_btn := _make_primary_cta_button("▶ DEPLOY AS ARMADA OF ACERO (STAGE 01)")
	play_acero_btn.custom_minimum_size = Vector2(320, 42)
	play_acero_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_select_faction_and_open_briefing("acero")
	)
	sc_footer.add_child(play_acero_btn)

func _build_faction_select_view() -> void:
	_faction_container = Control.new()
	_faction_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_faction_container.offset_top = 74
	_faction_container.visible = false
	add_child(_faction_container)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 22)
	_faction_container.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# Header bar
	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 16)
	main_vbox.add_child(hdr_row)

	var back_btn := Button.new()
	back_btn.text = "◀ BACK TO MAIN MENU"
	back_btn.custom_minimum_size = Vector2(180, 36)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_switch_view(MenuView.TITLE)
	)
	hdr_row.add_child(back_btn)

	var hdr_title := Label.new()
	hdr_title.text = "SELECT YOUR CIVILIZATION // THREE ANSWERS TO A DYING SEA"
	hdr_title.add_theme_font_size_override("font_size", 18)
	hdr_title.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	hdr_row.add_child(hdr_title)

	# 3 Faction Columns
	var cards_row := HBoxContainer.new()
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 18)
	main_vbox.add_child(cards_row)

	# 1. THE ARMADA OF ACERO
	cards_row.add_child(_create_faction_card(
		"acero",
		"THE ARMADA OF ACERO",
		"PRINCIPLE: BODY // STEEL & MASS",
		"\"Steel endures. The sea is not alive; it is fuel.\"",
		"res://assets/factions/card_acero.png",
		Color(1.0, 0.58, 0.22),
		"A militarized industrial navy that runs on refined éteron ('the spice') and fights with Newtonian reaction drives. Heavy bow armor, massive inertia, and devastating interlocking broadsides.",
		[
			"★ Flagship: CNS Iron Bastion (Anvil-class Dreadnought — Adm. Vane)",
			"★ Line Breaker: CNS Hammer of Anvil (Battlecruiser — Capt. Korr)",
            "★ Escort Screen: CNS Vanguard-03 (Chisel Corvette — Lt. Drake)"
		],
		"STAGE 01: DEFENSE OF SLUICE STATION WELL-09",
		true
	))

	# 2. THE VINCULADOS
	cards_row.add_child(_create_faction_card(
		"vinculados",
		"THE VINCULADOS",
		"PRINCIPLE: SOUL // NEURAL RESONANCE",
		"\"We sing across the dying dark before the Calm takes all.\"",
		"res://assets/factions/card_vinculados.png",
		Color(0.35, 0.92, 1.0),
		"Biomechanical humanoid combat frame pilots whose consciousness is coupled directly to the Éther wind. Unmatched agility, surgical resonance lances, and high-speed vector duels.",
		[
			"★ Command Frame: Eidolon Prime (Eidolon Suit — Ace Kaelen-7)",
			"★ Strike Wing: Anima-01 Aria (Anima Frame — Ace Mirei-4)",
            "★ Heavy Frame: Nous-04 Cantor (Nous Frame — Conductor Seraph-2)"
		],
		"STAGE 01: RESONANCE WELL PSALM-4",
		false
	))

	# 3. THE FREE TIDE (MAREA LIBRE)
	cards_row.add_child(_create_faction_card(
		"marea_libre",
		"THE FREE TIDE (MAREA LIBRE)",
		"PRINCIPLE: WIND // CORSAIR LIBERTY",
		"\"Break the Acero dams. Let the Star Sea breathe again!\"",
		"res://assets/factions/card_marea.png",
		Color(0.98, 0.78, 0.28),
		"Steampunk void-corsairs who sail the Éther gradient directly in pressurized timber-and-brass hulls with quantum membrane sails and mechanical Éther-oars.",
		[
			"★ Flagship: Viento Rojo (Void Galleon — Capt. Solano)",
			"★ Raider: La Descarada (Raider Galleon — Quartermaster Vael)",
            "★ Outrider: Brisa Negra (Void Brigantine — Capt. Moreau)"
		],
		"STAGE 01: RAID ON ANVIL SLUICE LANE",
		false
	))

func _create_faction_card(
	fac_id: String,
	title_str: String,
	principle_str: String,
	motto_str: String,
	art_path: String,
	accent_col: Color,
	lore_str: String,
	roster_lines: Array,
	stage_label: String,
	is_featured: bool
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.016, 0.038, 0.078, 0.80) if is_featured else Color(0.012, 0.028, 0.060, 0.74)
	style.border_color = accent_col if is_featured else Color(accent_col.r, accent_col.g, accent_col.b, 0.50)
	style.set_border_width_all(2 if is_featured else 1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)

	card.mouse_entered.connect(func() -> void:
		_focused_faction = fac_id
		style.border_color = accent_col
		style.set_border_width_all(2)
	)
	card.mouse_exited.connect(func() -> void:
		if not is_featured and _selected_faction != fac_id:
			style.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.50)
			style.set_border_width_all(1)
	)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var prin_lbl := Label.new()
	prin_lbl.text = principle_str
	prin_lbl.add_theme_font_size_override("font_size", 10)
	prin_lbl.add_theme_color_override("font_color", accent_col)
	top_row.add_child(prin_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(sp)

	if is_featured:
		var feat := Label.new()
		feat.text = "★ RECOMMENDED ACT I"
		feat.add_theme_font_size_override("font_size", 10)
		feat.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		top_row.add_child(feat)

	var title := Label.new()
	title.text = title_str
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var motto := Label.new()
	motto.text = motto_str
	motto.add_theme_font_size_override("font_size", 11)
	motto.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	vbox.add_child(motto)

	var art_frame := PanelContainer.new()
	var frame_st := StyleBoxFlat.new()
	frame_st.bg_color = Color(0.01, 0.02, 0.04, 0.95)
	frame_st.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.65)
	frame_st.set_border_width_all(1)
	frame_st.set_corner_radius_all(4)
	frame_st.set_content_margin_all(2)
	art_frame.add_theme_stylebox_override("panel", frame_st)
	vbox.add_child(art_frame)

	var art_rect := TextureRect.new()
	var tex: Texture2D = load(art_path)
	if tex != null:
		art_rect.texture = tex
	art_rect.custom_minimum_size = Vector2(0, 195)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_frame.add_child(art_rect)

	var lore_lbl := Label.new()
	lore_lbl.text = lore_str
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_lbl.add_theme_font_size_override("font_size", 11)
	lore_lbl.add_theme_color_override("font_color", Color(0.75, 0.84, 0.94))
	vbox.add_child(lore_lbl)

	vbox.add_child(HSeparator.new())

	var sq_hdr := Label.new()
	sq_hdr.text = "STARTING TASK FORCE & HEROES:"
	sq_hdr.add_theme_font_size_override("font_size", 10)
	sq_hdr.add_theme_color_override("font_color", accent_col)
	vbox.add_child(sq_hdr)

	for line in roster_lines:
		var rl := Label.new()
		rl.text = String(line)
		rl.add_theme_font_size_override("font_size", 10)
		rl.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
		vbox.add_child(rl)

	var v_spacer := Control.new()
	v_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(v_spacer)

	var stg_lbl := Label.new()
	stg_lbl.text = "▶ " + stage_label
	stg_lbl.add_theme_font_size_override("font_size", 10)
	stg_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.72))
	vbox.add_child(stg_lbl)

	var select_btn := _make_primary_cta_button("COMMAND " + title_str + " ▶") if is_featured else Button.new()
	if not is_featured:
		select_btn.text = "COMMAND " + title_str + " ▶"
	select_btn.custom_minimum_size = Vector2(0, 42)
	select_btn.mouse_entered.connect(func() -> void:
		_focused_faction = fac_id
	)
	select_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_select_faction_and_open_briefing(fac_id)
	)
	vbox.add_child(select_btn)

	return card

func _build_briefing_view() -> void:
	_briefing_container = Control.new()
	_briefing_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_briefing_container.offset_top = 74
	_briefing_container.visible = false
	add_child(_briefing_container)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 22)
	_briefing_container.add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)

	# Top briefing bar
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	main_vbox.add_child(top_row)

	var back_btn := Button.new()
	back_btn.text = "◀ CHANGE FACTION"
	back_btn.custom_minimum_size = Vector2(170, 36)
	back_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_switch_view(MenuView.FACTION_SELECT)
	)
	top_row.add_child(back_btn)

	var title_vbox := VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 1)
	top_row.add_child(title_vbox)

	_briefing_title_lbl = Label.new()
	_briefing_title_lbl.text = "ACT I // STAGE 01: DEFENSE OF SLUICE STATION WELL-09"
	_briefing_title_lbl.add_theme_font_size_override("font_size", 18)
	_briefing_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
	title_vbox.add_child(_briefing_title_lbl)

	_briefing_sub_lbl = Label.new()
	_briefing_sub_lbl.text = "SECTOR: ANVIL PERIMETER // ÉTHER RIVER DELTA // THREAT LEVEL: HIGH"
	_briefing_sub_lbl.add_theme_font_size_override("font_size", 11)
	_briefing_sub_lbl.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
	title_vbox.add_child(_briefing_sub_lbl)

	var stage_scroll := ScrollContainer.new()
	stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stage_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage_scroll.custom_minimum_size = Vector2(760, 38)
	stage_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(stage_scroll)

	_stage_selector_row = HBoxContainer.new()
	_stage_selector_row.add_theme_constant_override("separation", 6)
	stage_scroll.add_child(_stage_selector_row)

	# Content split: Left (Key Art + Tactical Objectives) / Right (Commander Portrait + Briefing + Roster + Launch)
	var content_row := HBoxContainer.new()
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 18)
	main_vbox.add_child(content_row)

	# Left Column
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.45
	left_col.add_theme_constant_override("separation", 12)
	content_row.add_child(left_col)

	var art_panel := PanelContainer.new()
	art_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(art_panel)

	_briefing_art_rect = TextureRect.new()
	_briefing_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_briefing_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_briefing_art_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_briefing_art_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_panel.add_child(_briefing_art_rect)

	var obj_panel := PanelContainer.new()
	obj_panel.custom_minimum_size = Vector2(0, 155)
	left_col.add_child(obj_panel)

	var obj_vbox := VBoxContainer.new()
	obj_vbox.add_theme_constant_override("separation", 6)
	obj_panel.add_child(obj_vbox)

	var obj_hdr := Label.new()
	obj_hdr.text = "TACTICAL DIRECTIVES & BATTLEFIELD TELEMETRY"
	obj_hdr.add_theme_font_size_override("font_size", 13)
	obj_hdr.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	obj_vbox.add_child(obj_hdr)

	_objectives_lbl = Label.new()
	_objectives_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objectives_lbl.add_theme_font_size_override("font_size", 11)
	_objectives_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 0.98))
	obj_vbox.add_child(_objectives_lbl)

	# Right Column: Commander Transmission + Task Force + Launch CTA
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	content_row.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(right_vbox)

	var cmd_row := HBoxContainer.new()
	cmd_row.add_theme_constant_override("separation", 14)
	right_vbox.add_child(cmd_row)

	_commander_portrait_rect = TextureRect.new()
	_commander_portrait_rect.custom_minimum_size = Vector2(128, 128)
	_commander_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_commander_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cmd_row.add_child(_commander_portrait_rect)

	var cmd_info_vbox := VBoxContainer.new()
	cmd_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cmd_info_vbox.add_theme_constant_override("separation", 4)
	cmd_row.add_child(cmd_info_vbox)

	var trans_badge := Label.new()
	trans_badge.text = "● ENCRYPTED BRIDGE TRANSMISSION"
	trans_badge.add_theme_font_size_override("font_size", 10)
	trans_badge.add_theme_color_override("font_color", Color(1.0, 0.62, 0.22))
	cmd_info_vbox.add_child(trans_badge)

	_commander_name_lbl = Label.new()
	_commander_name_lbl.add_theme_font_size_override("font_size", 16)
	_commander_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	cmd_info_vbox.add_child(_commander_name_lbl)

	_commander_role_lbl = Label.new()
	_commander_role_lbl.add_theme_font_size_override("font_size", 11)
	_commander_role_lbl.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
	cmd_info_vbox.add_child(_commander_role_lbl)

	_commander_quote_lbl = Label.new()
	_commander_quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_commander_quote_lbl.add_theme_font_size_override("font_size", 11)
	_commander_quote_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	right_vbox.add_child(_commander_quote_lbl)

	right_vbox.add_child(HSeparator.new())

	var tf_hdr := Label.new()
	tf_hdr.text = "ASSIGNED BATTLE GROUP (3 UNITS):"
	tf_hdr.add_theme_font_size_override("font_size", 11)
	tf_hdr.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
	right_vbox.add_child(tf_hdr)

	_squadron_vbox = VBoxContainer.new()
	_squadron_vbox.add_theme_constant_override("separation", 6)
	right_vbox.add_child(_squadron_vbox)

	var r_spacer := Control.new()
	r_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(r_spacer)

	_launch_stage_btn = _make_primary_cta_button("⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 01")
	_launch_stage_btn.custom_minimum_size = Vector2(0, 50)
	_launch_stage_btn.pressed.connect(_launch_campaign_stage)
	right_vbox.add_child(_launch_stage_btn)

func _select_faction_and_open_briefing(fac_id: String) -> void:
	_selected_faction = fac_id
	_focused_faction = fac_id
	LoreDB.selected_faction = fac_id

	for child in _squadron_vbox.get_children():
		child.queue_free()
	for child in _stage_selector_row.get_children():
		child.queue_free()

	match fac_id:
		"acero":
			_populate_acero_stage_briefing("acero_stage_1")

		"vinculados":
			_populate_vinculados_stage_briefing("vinculados_stage_1")

		"marea_libre":
			_populate_marea_stage_briefing("marea_stage_1")

	_switch_view(MenuView.BRIEFING)

func _populate_acero_stage_briefing(stage_id: String) -> void:
	CampaignBriefingBuilder.populate_acero(self, stage_id)

func _populate_vinculados_stage_briefing(stage_id: String) -> void:
	CampaignBriefingBuilder.populate_vinculados(self, stage_id)

func _populate_marea_stage_briefing(stage_id: String) -> void:
	CampaignBriefingBuilder.populate_marea(self, stage_id)

func _add_squadron_row(ship_id: String, unit_name: String, role_str: String, stats_str: String) -> void:
	CampaignBriefingBuilder.add_squadron_row(_squadron_vbox, ship_id, unit_name, role_str, stats_str)

func _launch_campaign_stage() -> void:
	AudioManager.play_sfx("ui_click", -6.0)
	_transition_to_scene("res://scenes/sandbox/sandbox.tscn")

func _switch_view(view: MenuView) -> void:
	_current_view = view
	if view == MenuView.TITLE:
		_focused_faction = "overview"
	elif view == MenuView.FACTION_SELECT:
		_focused_faction = _selected_faction
	elif view == MenuView.BRIEFING:
		_focused_faction = _selected_faction
	if _title_container != null:
		_title_container.visible = (view == MenuView.TITLE)
	if _faction_container != null:
		_faction_container.visible = (view == MenuView.FACTION_SELECT)
	if _briefing_container != null:
		_briefing_container.visible = (view == MenuView.BRIEFING)

func _transition_to_scene(scene_path: String) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.45)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(scene_path)
	)

func _make_menu_button(title: String, subtitle: String, highlighted: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 54)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "%s\n   %s" % [title, subtitle]
	if highlighted:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.08, 0.22, 0.36, 0.92)
		st.border_color = Color(0.35, 0.95, 1.0, 0.95)
		st.set_border_width_all(2)
		st.set_corner_radius_all(6)
		st.set_content_margin_all(10)
		btn.add_theme_stylebox_override("normal", st)
	return btn

func _make_primary_cta_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	var st_norm := StyleBoxFlat.new()
	st_norm.bg_color = Color(0.82, 0.42, 0.12, 0.92)
	st_norm.border_color = Color(1.0, 0.82, 0.38, 0.98)
	st_norm.set_border_width_all(2)
	st_norm.set_corner_radius_all(6)
	st_norm.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", st_norm)

	var st_hov := StyleBoxFlat.new()
	st_hov.bg_color = Color(0.95, 0.54, 0.18, 0.98)
	st_hov.border_color = Color(1.0, 0.95, 0.65, 1.0)
	st_hov.set_border_width_all(2)
	st_hov.set_corner_radius_all(6)
	st_hov.set_content_margin_all(10)
	btn.add_theme_stylebox_override("hover", st_hov)
	return btn

func _build_menu_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.035, 0.075, 0.84)
	panel_style.border_color = Color(0.22, 0.72, 0.92, 0.42)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(16)
	t.set_stylebox("panel", "PanelContainer", panel_style)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.035, 0.085, 0.16, 0.85)
	btn_normal.border_color = Color(0.25, 0.68, 0.88, 0.45)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(5)
	btn_normal.set_content_margin_all(8)
	t.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.08, 0.20, 0.34, 0.95)
	btn_hover.border_color = Color(0.38, 0.92, 1.0, 0.90)
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(5)
	btn_hover.set_content_margin_all(8)
	t.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.14, 0.30, 0.45, 0.98)
	btn_pressed.border_color = Color(1.0, 0.85, 0.35, 0.95)
	btn_pressed.set_border_width_all(1)
	btn_pressed.set_corner_radius_all(5)
	btn_pressed.set_content_margin_all(8)
	t.set_stylebox("pressed", "Button", btn_pressed)

	t.set_color("font_color", "Button", Color(0.90, 0.96, 1.0))
	t.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
	t.set_color("font_color", "Label", Color(0.88, 0.94, 1.0))
	return t
