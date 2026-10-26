extends Control

const RpgHangarModal = preload("res://scripts/ui/rpg/rpg_hangar_modal.gd")

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
var _load_modal: Control
var _settings_modal: Control
var _codex_modal: Control
var _roster_modal: HudWidgets.HeroRosterModal
var _hangar_modal: RpgHangarModal
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
	_build_load_game_modal()
	_build_settings_modal()
	_build_codex_modal()

	_roster_modal = HudWidgets.HeroRosterModal.new()
	_roster_modal.theme = _theme
	add_child(_roster_modal)

	_hangar_modal = RpgHangarModal.new()
	_hangar_modal.theme = _theme
	_hangar_modal.proceed_to_briefing_requested.connect(_on_hangar_proceed)
	add_child(_hangar_modal)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.01, 0.02, 0.04, 1.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, 0.65)

	var settings := SaveManager.load_settings()
	var menu_track: String = String(settings.get("preferred_menu_music", "res://assets/audio/music/out_there.ogg"))
	if not ResourceLoader.exists(menu_track):
		menu_track = "res://assets/audio/music_prologue.ogg"
	AudioManager.crossfade_to(menu_track, -11.0, 1.2)
	AudioManager.start_ambient(-24.0)

	if LoreDB.open_hangar_on_load:
		LoreDB.open_hangar_on_load = false
		var spoils := LoreDB.last_battle_spoils
		var target_stage := LoreDB.return_to_briefing_stage_id
		var fac := _selected_faction
		if target_stage.begins_with("vinculados"):
			fac = "vinculados"
		elif target_stage.begins_with("marea"):
			fac = "marea_libre"
		elif target_stage.begins_with("acero"):
			fac = "acero"
		_selected_faction = fac
		_focused_faction = fac
		LoreDB.selected_faction = fac
		_switch_view(MenuView.TITLE)
		_hangar_modal.setup_hangar(fac, spoils, target_stage)
		_hangar_modal.visible = true
	elif LoreDB.return_to_briefing_stage_id != "":
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _load_modal != null and _load_modal.visible:
			_load_modal.visible = false
			AudioManager.play_sfx("ui_click", -8.0)
			get_viewport().set_input_as_handled()
			return
		if _settings_modal != null and _settings_modal.visible:
			_settings_modal.visible = false
			AudioManager.play_sfx("ui_click", -8.0)
			get_viewport().set_input_as_handled()
			return
		if _codex_modal != null and _codex_modal.visible:
			_codex_modal.visible = false
			AudioManager.play_sfx("ui_click", -8.0)
			get_viewport().set_input_as_handled()
			return
		if _roster_modal != null and _roster_modal.visible:
			_roster_modal.visible = false
			AudioManager.play_sfx("ui_click", -8.0)
			get_viewport().set_input_as_handled()
			return
		if _hangar_modal != null and _hangar_modal.visible:
			_hangar_modal.visible = false
			AudioManager.play_sfx("ui_click", -8.0)
			get_viewport().set_input_as_handled()
			return
		if _current_view == MenuView.FACTION_SELECT:
			_switch_view(MenuView.TITLE)
			AudioManager.play_sfx("ui_click", -8.0)
			get_viewport().set_input_as_handled()
			return
		elif _current_view == MenuView.BRIEFING:
			_switch_view(MenuView.FACTION_SELECT)
			AudioManager.play_sfx("ui_click", -8.0)
			get_viewport().set_input_as_handled()
			return

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

	var btn_campaign := _make_menu_button(
		"▶  NUEVA CAMPAÑA",
		"Elige tu civilización y entra en la Guerra por el Mar Estelar",
		true
	)
	btn_campaign.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_switch_view(MenuView.FACTION_SELECT)
	)
	menu_vbox.add_child(btn_campaign)

	var btn_load := _make_menu_button(
		"📂  CARGAR PARTIDA",
		"Reanuda campañas guardadas por facción o batallas tácticas",
		false
	)
	btn_load.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_open_load_modal()
	)
	menu_vbox.add_child(btn_load)

	var btn_settings := _make_menu_button(
		"⚙  CONFIGURACIÓN",
		"Ajustes de Audio (volumen y música) y Gráficos (pantalla, FPS)",
		false
	)
	btn_settings.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_open_settings_modal()
	)
	menu_vbox.add_child(btn_settings)

	var btn_hangar := _make_menu_button(
		"⚡  HANGAR DE FLOTA & ASES (RPG)",
		"Mejora cascos, propulsores, armas y asigna SP a los pilotos héroes",
		false
	)
	btn_hangar.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		if _hangar_modal != null:
			_hangar_modal.setup_hangar(_selected_faction, {}, "")
			_hangar_modal.visible = true
	)
	menu_vbox.add_child(btn_hangar)

	var btn_codex := _make_menu_button(
		"📖  MANUAL TÁCTICO & AYUDA",
		"Aprende las 2 Fases, Viento/Éter, Inercia, Blindaje y Combos",
		false
	)
	btn_codex.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_open_codex_modal()
	)
	menu_vbox.add_child(btn_codex)

	var btn_roster := _make_menu_button(
		"★  ARCHIVO DE HÉROES & FLOTAS",
		"Inspecciona pilotos Ases, Almirantes y navíos de guerra",
		false
	)
	btn_roster.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		if _roster_modal != null:
			_roster_modal.visible = true
	)
	menu_vbox.add_child(btn_roster)

	var btn_credits := _make_menu_button(
		"🎬  CRÉDITOS CINEMATOGRÁFICOS",
		"Secuencia de créditos finales con Dvořák y epílogos",
		false
	)
	btn_credits.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_transition_to_scene("res://scenes/credits/credits.tscn")
	)
	menu_vbox.add_child(btn_credits)

	var btn_intro := _make_menu_button(
		"🎥  VER PRÓLOGO CINEMÁTICO",
		"Revive la introducción cinematográfica en 3D",
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
	btn_quit.text = "✕  SALIR AL ESCRITORIO"
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
	act_badge.text = "[CAMPAÑA SAGA // 36 ETAPAS]"
	act_badge.add_theme_font_size_override("font_size", 12)
	act_badge.add_theme_color_override("font_color", Color(1.0, 0.62, 0.22))
	badge_row.add_child(act_badge)

	var act_title := Label.new()
	act_title.text = "LA GUERRA POR EL MAR ESTELAR — \"EL ÚLTIMO VIENTO\""
	act_title.add_theme_font_size_override("font_size", 15)
	act_title.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	badge_row.add_child(act_title)

	var art_holder := PanelContainer.new()
	art_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc_vbox.add_child(art_holder)

	var stage_art := TextureRect.new()
	var st_tex: Texture2D = load("res://assets/splash/cover.png")
	if st_tex == null:
		st_tex = load("res://assets/splash/cover.png")
	stage_art.texture = st_tex
	stage_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stage_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art_holder.add_child(stage_art)

	# Stats banner overlay
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 24)
	sc_vbox.add_child(stats_row)

	var stat_vic := Label.new()
	stat_vic.text = "🏆 Victorias: %d" % SaveManager.total_victories
	stat_vic.add_theme_font_size_override("font_size", 11)
	stat_vic.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	stats_row.add_child(stat_vic)

	var stat_kills := Label.new()
	stat_kills.text = "💥 Naves Derrotadas: %d" % SaveManager.total_kills
	stat_kills.add_theme_font_size_override("font_size", 11)
	stat_kills.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	stats_row.add_child(stat_kills)

	var completed_total := SaveManager.completed_stages.size()
	var stat_comp := Label.new()
	stat_comp.text = "✦ Etapas Conquistadas: %d / 36" % completed_total
	stat_comp.add_theme_font_size_override("font_size", 11)
	stat_comp.add_theme_color_override("font_color", Color(0.40, 1.0, 0.65))
	stats_row.add_child(stat_comp)

	var sc_desc := Label.new()
	sc_desc.text = "El Mar Estelar se apaga bajo el avance implacable de La Calma. Comanda las tres civilizaciones asimétricas en 36 batallas monumentales. Domina la inercia newtoniana, el blindaje direccional, y los héroes Ases estilo Gundam en combate táctico espacial 3D."
	sc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sc_desc.add_theme_font_size_override("font_size", 12)
	sc_desc.add_theme_color_override("font_color", Color(0.82, 0.90, 0.98))
	sc_vbox.add_child(sc_desc)

	var sc_footer := HBoxContainer.new()
	sc_footer.alignment = BoxContainer.ALIGNMENT_END
	sc_footer.add_theme_constant_override("separation", 12)
	sc_vbox.add_child(sc_footer)

	if SaveManager.has_tactical_save():
		var quick_resume_btn := Button.new()
		quick_resume_btn.text = "📂  REANUDAR BATALLA EN CURSO"
		quick_resume_btn.custom_minimum_size = Vector2(250, 42)
		quick_resume_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click", -8.0)
			var st := SaveManager.load_tactical_state()
			LoreDB.current_stage_id = String(st.get("stage_id", "acero_stage_1"))
			SaveManager.pending_load_battle = true
			_transition_to_scene("res://scenes/sandbox/sandbox.tscn")
		)
		sc_footer.add_child(quick_resume_btn)

	var choose_fac_btn := _make_primary_cta_button("▶  ELEGIR FACCIÓN Y COMENZAR")
	choose_fac_btn.custom_minimum_size = Vector2(280, 42)
	choose_fac_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_switch_view(MenuView.FACTION_SELECT)
	)
	sc_footer.add_child(choose_fac_btn)

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
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.016, 0.038, 0.078, 0.85) if is_featured else Color(0.012, 0.028, 0.060, 0.80)
	style.border_color = accent_col if is_featured else Color(accent_col.r, accent_col.g, accent_col.b, 0.50)
	style.set_border_width_all(2 if is_featured else 1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
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
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			AudioManager.play_sfx("ui_click", -8.0)
			_select_faction_and_open_briefing(fac_id)
	)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(top_row)

	var prin_lbl := Label.new()
	prin_lbl.text = principle_str
	prin_lbl.add_theme_font_size_override("font_size", 10)
	prin_lbl.add_theme_color_override("font_color", accent_col)
	prin_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	top_row.add_child(prin_lbl)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_PASS
	top_row.add_child(sp)

	if SaveManager.is_stage_completed(fac_id + "_stage_12"):
		var won_lbl := Label.new()
		won_lbl.text = "🏆 CAMPAIGN CONQUERED"
		won_lbl.add_theme_font_size_override("font_size", 10)
		won_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
		won_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		top_row.add_child(won_lbl)
	elif is_featured:
		var feat := Label.new()
		feat.text = "★ RECOMMENDED ACT I"
		feat.add_theme_font_size_override("font_size", 10)
		feat.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
		feat.mouse_filter = Control.MOUSE_FILTER_PASS
		top_row.add_child(feat)

	var title := Label.new()
	title.text = title_str
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(title)

	var motto := Label.new()
	motto.text = motto_str
	motto.add_theme_font_size_override("font_size", 10)
	motto.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	motto.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(motto)

	var art_frame := PanelContainer.new()
	var frame_st := StyleBoxFlat.new()
	frame_st.bg_color = Color(0.01, 0.02, 0.04, 0.95)
	frame_st.border_color = Color(accent_col.r, accent_col.g, accent_col.b, 0.65)
	frame_st.set_border_width_all(1)
	frame_st.set_corner_radius_all(4)
	frame_st.set_content_margin_all(2)
	art_frame.add_theme_stylebox_override("panel", frame_st)
	art_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(art_frame)

	var art_rect := TextureRect.new()
	var tex: Texture2D = load(art_path)
	if tex != null:
		art_rect.texture = tex
	art_rect.custom_minimum_size = Vector2(0, 145)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	art_frame.add_child(art_rect)

	var lore_lbl := Label.new()
	lore_lbl.text = lore_str
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lore_lbl.custom_minimum_size = Vector2(240, 42)
	lore_lbl.add_theme_font_size_override("font_size", 10)
	lore_lbl.add_theme_color_override("font_color", Color(0.75, 0.84, 0.94))
	lore_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(lore_lbl)

	vbox.add_child(HSeparator.new())

	var sq_hdr := Label.new()
	sq_hdr.text = "STARTING TASK FORCE & HEROES:"
	sq_hdr.add_theme_font_size_override("font_size", 10)
	sq_hdr.add_theme_color_override("font_color", accent_col)
	sq_hdr.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(sq_hdr)

	for line in roster_lines:
		var rl := Label.new()
		rl.text = String(line)
		rl.add_theme_font_size_override("font_size", 9)
		rl.add_theme_color_override("font_color", Color(0.86, 0.92, 0.98))
		rl.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(rl)

	var v_spacer := Control.new()
	v_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v_spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(v_spacer)

	var stg_lbl := Label.new()
	stg_lbl.text = "▶ " + stage_label
	stg_lbl.add_theme_font_size_override("font_size", 10)
	stg_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.72))
	stg_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(stg_lbl)

	var select_btn := Button.new()
	select_btn.text = "COMMAND " + title_str + " ▶"
	select_btn.custom_minimum_size = Vector2(0, 40)
	select_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_st := StyleBoxFlat.new()
	btn_st.bg_color = Color(accent_col.r * 0.75, accent_col.g * 0.75, accent_col.b * 0.75, 0.92)
	btn_st.border_color = accent_col
	btn_st.set_border_width_all(2)
	btn_st.set_corner_radius_all(6)
	btn_st.set_content_margin_all(8)
	select_btn.add_theme_stylebox_override("normal", btn_st)
	var btn_hov := StyleBoxFlat.new()
	btn_hov.bg_color = accent_col
	btn_hov.border_color = Color.WHITE
	btn_hov.set_border_width_all(2)
	btn_hov.set_corner_radius_all(6)
	btn_hov.set_content_margin_all(8)
	select_btn.add_theme_stylebox_override("hover", btn_hov)
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
	LoreDB.player_faction = fac_id
	SaveManager.last_selected_faction = fac_id

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

func _on_hangar_proceed(target_stage: String) -> void:
	if target_stage != "":
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
	if SceneTransition != null:
		SceneTransition.load_scene(scene_path, _selected_faction)
	else:
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

# ==============================================================================
# LOAD GAME MODAL (BY FACTION + TACTICAL SAVE)
# ==============================================================================
var _load_tab_container: PanelContainer
var _load_active_tab: String = "acero"
var _load_tab_buttons: Dictionary = {}

func _build_load_game_modal() -> void:
	_load_modal = Control.new()
	_load_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_modal.visible = false
	add_child(_load_modal)

	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0.008, 0.02, 0.04, 0.88)
	bg_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_modal.add_child(bg_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load_modal.add_child(center)

	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(980, 620)
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.018, 0.045, 0.088, 0.96)
	win_style.border_color = Color(0.28, 0.78, 0.98, 0.85)
	win_style.set_border_width_all(2)
	win_style.set_corner_radius_all(8)
	win_style.set_content_margin_all(20)
	window.add_theme_stylebox_override("panel", win_style)
	center.add_child(window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	window.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var hdr_titles := VBoxContainer.new()
	hdr_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hdr_titles)

	var title_lbl := Label.new()
	title_lbl.text = "CARGAR PARTIDA // ARCHIVO DE OPERACIONES NAVALES"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	hdr_titles.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Selecciona tu facción para reanudar la campaña o retoma una batalla táctica guardada"
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.82, 0.94))
	hdr_titles.add_child(sub_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕ CERRAR"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_load_modal.visible = false
	)
	hdr.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 10)
	vbox.add_child(tab_bar)

	var tabs_def := [
		{"id": "acero", "label": "⚡ ARMADA DE ACERO"},
		{"id": "vinculados", "label": "✦ LOS VINCULADOS"},
		{"id": "marea_libre", "label": "⚓ LA MAREA LIBRE"},
		{"id": "tactical", "label": "💾 QUICK / TACTICAL SAVE"},
	]

	for t_info in tabs_def:
		var tab_btn := Button.new()
		tab_btn.text = t_info["label"]
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.custom_minimum_size = Vector2(0, 38)
		var tid: String = t_info["id"]
		tab_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click", -8.0)
			_set_load_tab(tid)
		)
		tab_bar.add_child(tab_btn)
		_load_tab_buttons[tid] = tab_btn

	_load_tab_container = PanelContainer.new()
	_load_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cont_style := StyleBoxFlat.new()
	cont_style.bg_color = Color(0.012, 0.028, 0.060, 0.75)
	cont_style.border_color = Color(0.20, 0.55, 0.75, 0.45)
	cont_style.set_border_width_all(1)
	cont_style.set_corner_radius_all(6)
	cont_style.set_content_margin_all(14)
	_load_tab_container.add_theme_stylebox_override("panel", cont_style)
	vbox.add_child(_load_tab_container)

	_set_load_tab("acero")

func _open_load_modal() -> void:
	if _load_modal == null:
		return
	_load_modal.visible = true
	_set_load_tab(_load_active_tab)

func _set_load_tab(tab_id: String) -> void:
	_load_active_tab = tab_id
	for tid in _load_tab_buttons.keys():
		var btn: Button = _load_tab_buttons[tid]
		if tid == tab_id:
			var active_st := StyleBoxFlat.new()
			active_st.bg_color = Color(0.08, 0.22, 0.38, 0.95)
			active_st.border_color = Color(0.35, 0.95, 1.0)
			active_st.set_border_width_all(2)
			active_st.set_corner_radius_all(5)
			btn.add_theme_stylebox_override("normal", active_st)
		else:
			btn.remove_theme_stylebox_override("normal")

	for child in _load_tab_container.get_children():
		child.queue_free()

	if tab_id == "tactical":
		_populate_load_tactical_tab()
	else:
		_populate_load_faction_tab(tab_id)

func _populate_load_faction_tab(fac_id: String) -> void:
	var summary := SaveManager.get_faction_summary(fac_id)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_tab_container.add_child(hbox)

	# Left Column: Faction Banner, Motto, Progress
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(320, 0)
	left_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(left_vbox)

	var art_rect := TextureRect.new()
	var tex: Texture2D = load(summary.get("art_path", ""))
	if tex != null:
		art_rect.texture = tex
	art_rect.custom_minimum_size = Vector2(320, 180)
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	left_vbox.add_child(art_rect)

	var fac_name_lbl := Label.new()
	fac_name_lbl.text = summary.get("faction_name", "")
	fac_name_lbl.add_theme_font_size_override("font_size", 16)
	fac_name_lbl.add_theme_color_override("font_color", summary.get("emblem_color", Color.WHITE))
	left_vbox.add_child(fac_name_lbl)

	var motto_lbl := Label.new()
	motto_lbl.text = "\"%s\"" % summary.get("motto", "")
	motto_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	motto_lbl.add_theme_font_size_override("font_size", 11)
	motto_lbl.add_theme_color_override("font_color", Color(0.70, 0.82, 0.94))
	left_vbox.add_child(motto_lbl)

	left_vbox.add_child(HSeparator.new())

	var prog_title := Label.new()
	prog_title.text = "PROGRESO DE CAMPAÑA: %d / %d ETAPAS" % [summary.get("stages_completed", 0), summary.get("total_stages", 12)]
	prog_title.add_theme_font_size_override("font_size", 12)
	prog_title.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	left_vbox.add_child(prog_title)

	var pbar := ProgressBar.new()
	pbar.min_value = 0
	pbar.max_value = float(summary.get("total_stages", 12))
	pbar.value = float(summary.get("stages_completed", 0))
	pbar.custom_minimum_size = Vector2(0, 18)
	left_vbox.add_child(pbar)

	var status_lbl := Label.new()
	if bool(summary.get("is_conquered", false)):
		status_lbl.text = "★ VICTORIA TOTAL // CAMPAÑA CONQUISTADA"
		status_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
	else:
		status_lbl.text = "EN CURSO // ÚLTIMA ETAPA ALCANZADA: %d" % summary.get("stage_number", 1)
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	status_lbl.add_theme_font_size_override("font_size", 11)
	left_vbox.add_child(status_lbl)

	var left_spacer := Control.new()
	left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(left_spacer)

	var reset_btn := Button.new()
	reset_btn.text = "↺ REINICIAR PROGRESO DE FACCIÓN"
	reset_btn.custom_minimum_size = Vector2(0, 32)
	reset_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		SaveManager.reset_faction_progress(fac_id)
		_set_load_tab(fac_id)
	)
	left_vbox.add_child(reset_btn)

	# Right Column: Stage Showcase and Launch Buttons
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(right_vbox)

	var stage_badge := Label.new()
	stage_badge.text = "[FICHA DE ETAPA GUARDADA // REGISTRO #%02d]" % summary.get("stage_number", 1)
	stage_badge.add_theme_font_size_override("font_size", 11)
	stage_badge.add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
	right_vbox.add_child(stage_badge)

	var stage_title_lbl := Label.new()
	stage_title_lbl.text = summary.get("stage_title", "")
	stage_title_lbl.add_theme_font_size_override("font_size", 16)
	stage_title_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	right_vbox.add_child(stage_title_lbl)

	var st_data: Dictionary = StoryDB.get_story_data(summary.get("latest_stage_id", ""))
	var paras: Array = st_data.get("story_paragraphs", [])
	var desc_text: String = paras[0] if paras.size() > 0 else "Sin datos adicionales de telemetría."
	var desc_lbl := Label.new()
	desc_lbl.text = desc_text
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.86, 0.95))
	right_vbox.add_child(desc_lbl)

	right_vbox.add_child(HSeparator.new())

	var squad_hdr := Label.new()
	squad_hdr.text = "ESCUADRÓN ASIGNADO EN ESTA ETAPA:"
	squad_hdr.add_theme_font_size_override("font_size", 12)
	squad_hdr.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	right_vbox.add_child(squad_hdr)

	var ship_ids: Array = ["acero_dreadnought", "acero_battlecruiser", "acero_corvette"]
	if fac_id == "vinculados":
		ship_ids = ["vinculados_cradle", "vinculados_suit", "vinculados_anima"]
	elif fac_id == "marea_libre":
		ship_ids = ["marea_galleon", "marea_raider", "marea_brigantine"]

	for sid in ship_ids:
		var sdef: ShipDef = LoreDB.get_ship(sid)
		if sdef == null:
			continue
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 10)
		var s_lbl := Label.new()
		s_lbl.text = "✦ %s — %s (%s)" % [sdef.display_name, sdef.pilot_name, sdef.class_label]
		s_lbl.add_theme_font_size_override("font_size", 11)
		s_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
		srow.add_child(s_lbl)
		right_vbox.add_child(srow)

	var r_spacer := Control.new()
	r_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(r_spacer)

	# Action Row
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 14)
	right_vbox.add_child(actions_row)

	var resume_brief_btn := _make_primary_cta_button("📋  REANUDAR EN BRIEFING TÁCTICO")
	resume_brief_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_brief_btn.custom_minimum_size = Vector2(0, 44)
	resume_brief_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_load_modal.visible = false
		_selected_faction = fac_id
		_focused_faction = fac_id
		LoreDB.selected_faction = fac_id
		LoreDB.player_faction = fac_id
		SaveManager.last_selected_faction = fac_id
		for child in _squadron_vbox.get_children():
			child.queue_free()
		for child in _stage_selector_row.get_children():
			child.queue_free()
		var stage_to_load: String = summary.get("latest_stage_id", fac_id + "_stage_1")
		if fac_id == "acero":
			_populate_acero_stage_briefing(stage_to_load)
		elif fac_id == "vinculados":
			_populate_vinculados_stage_briefing(stage_to_load)
		elif fac_id == "marea_libre":
			_populate_marea_stage_briefing(stage_to_load)
		_switch_view(MenuView.BRIEFING)
	)
	actions_row.add_child(resume_brief_btn)

	var direct_launch_btn := Button.new()
	direct_launch_btn.text = "⚔  INICIAR COMBATE DIRECTO"
	direct_launch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direct_launch_btn.custom_minimum_size = Vector2(0, 44)
	direct_launch_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_load_modal.visible = false
		LoreDB.selected_faction = fac_id
		LoreDB.player_faction = fac_id
		LoreDB.current_stage_id = summary.get("latest_stage_id", fac_id + "_stage_1")
		SaveManager.pending_load_battle = false
		_transition_to_scene("res://scenes/sandbox/sandbox.tscn")
	)
	actions_row.add_child(direct_launch_btn)

func _populate_load_tactical_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_tab_container.add_child(vbox)

	if not SaveManager.has_tactical_save():
		var empty_lbl := Label.new()
		empty_lbl.text = "NO HAY BATALLA TÁCTICA GUARDADA"
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.95, 0.65, 0.25))
		vbox.add_child(empty_lbl)

		var empty_desc := Label.new()
		empty_desc.text = "Durante cualquier enfrentamiento (en Fase Almirante o Fase As), puedes guardar tu progreso con 'F5 (Guardado Rápido)' o mediante el menú de pausa (ESC).\n\nEl sistema guarda las posiciones exactas de cada navío en el espacio 3D, su vector de aceleración e inercia, integridad de blindaje direccional (Proa, Popa, Babor, Estribor), estado de escudos y rondas de combate."
		empty_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_desc.add_theme_font_size_override("font_size", 12)
		empty_desc.add_theme_color_override("font_color", Color(0.70, 0.82, 0.94))
		vbox.add_child(empty_desc)
		return

	var tac := SaveManager.load_tactical_state()
	var st_id: String = String(tac.get("stage_id", "Desconocido"))
	var fac: String = String(tac.get("faction", "acero"))
	var turn: int = int(tac.get("turn_number", 1))
	var ace_rnd: int = int(tac.get("ace_round", 1))
	var phase_val: int = int(tac.get("phase", 0))
	var time_str: String = String(tac.get("timestamp", "Sin registro"))
	var allies: Array = tac.get("player_ships", [])
	var enemies: Array = tac.get("enemy_ships", [])

	var title_lbl := Label.new()
	title_lbl.text = "BATALLA EN CURSO // ESTADO TÁCTICO REGISTRADO"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.40, 1.0, 0.65))
	vbox.add_child(title_lbl)

	var info_grid := GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 24)
	info_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(info_grid)

	_add_stat_row(info_grid, "Etapa de Combate:", "%s" % st_id)
	_add_stat_row(info_grid, "Facción Activa:", "%s" % fac.to_upper())
	_add_stat_row(info_grid, "Fase Guardada:", "Fase As (Ronda %d)" % ace_rnd if phase_val == 1 else "Fase Almirante (Turno %d)" % turn)
	_add_stat_row(info_grid, "Fecha / Hora:", "%s" % time_str)
	_add_stat_row(info_grid, "Navíos Aliados Restantes:", "%d" % allies.size())
	_add_stat_row(info_grid, "Navíos Enemigos Restantes:", "%d" % enemies.size())

	vbox.add_child(HSeparator.new())

	var desc_lbl := Label.new()
	desc_lbl.text = "Al reanudar, la simulación 3D restaura exactamente la inercia newtoniana, el rumbo actual, el estado del reactor de Éter y las órdenes de combate activas."
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.70, 0.82, 0.94))
	vbox.add_child(desc_lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var resume_btn := _make_primary_cta_button("⚔  REANUDAR ESTA BATALLA TÁCTICA")
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.custom_minimum_size = Vector2(0, 44)
	resume_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_load_modal.visible = false
		LoreDB.current_stage_id = st_id
		SaveManager.pending_load_battle = true
		_transition_to_scene("res://scenes/sandbox/sandbox.tscn")
	)
	btn_row.add_child(resume_btn)

	var delete_btn := Button.new()
	delete_btn.text = "🗑  DESCARTAR GUARDADO TÁCTICO"
	delete_btn.custom_minimum_size = Vector2(260, 44)
	delete_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		if FileAccess.file_exists(SaveManager.TACTICAL_SAVE_PATH):
			DirAccess.remove_absolute(SaveManager.TACTICAL_SAVE_PATH)
		_set_load_tab("tactical")
	)
	btn_row.add_child(delete_btn)

func _add_stat_row(container: Container, label_txt: String, val_txt: String) -> void:
	var l := Label.new()
	l.text = label_txt
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.65, 0.82, 0.94))
	container.add_child(l)

	var v := Label.new()
	v.text = val_txt
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	container.add_child(v)

# ==============================================================================
# SETTINGS MODAL (AUDIO & GRAPHICS)
# ==============================================================================
var _settings_active_tab: String = "audio"
var _settings_tab_container: PanelContainer
var _settings_tab_buttons: Dictionary = {}
var _temp_settings: Dictionary = {}

func _build_settings_modal() -> void:
	_settings_modal = Control.new()
	_settings_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_modal.visible = false
	add_child(_settings_modal)

	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0.008, 0.02, 0.04, 0.88)
	bg_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_modal.add_child(bg_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_modal.add_child(center)

	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(880, 580)
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.018, 0.045, 0.088, 0.96)
	win_style.border_color = Color(0.28, 0.78, 0.98, 0.85)
	win_style.set_border_width_all(2)
	win_style.set_corner_radius_all(8)
	win_style.set_content_margin_all(20)
	window.add_theme_stylebox_override("panel", win_style)
	center.add_child(window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	window.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var hdr_titles := VBoxContainer.new()
	hdr_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hdr_titles)

	var title_lbl := Label.new()
	title_lbl.text = "CONFIGURACIÓN DEL SISTEMA // FLEET SYSTEM SETTINGS"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	hdr_titles.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Ajustes de Telemetría Acústica, Rendimiento Visual y Parámetros del Motor Forward+"
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.82, 0.94))
	hdr_titles.add_child(sub_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕ CERRAR"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_settings_modal.visible = false
	)
	hdr.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 10)
	vbox.add_child(tab_bar)

	var tabs_def := [
		{"id": "audio", "label": "🔊 AUDIO Y MÚSICA DE COMBATE"},
		{"id": "graphics", "label": "🖥 PANTALLA Y GRÁFICOS 3D"}
	]

	for t_info in tabs_def:
		var tab_btn := Button.new()
		tab_btn.text = t_info["label"]
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.custom_minimum_size = Vector2(0, 38)
		var tid: String = t_info["id"]
		tab_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click", -8.0)
			_set_settings_tab(tid)
		)
		tab_bar.add_child(tab_btn)
		_settings_tab_buttons[tid] = tab_btn

	_settings_tab_container = PanelContainer.new()
	_settings_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cont_style := StyleBoxFlat.new()
	cont_style.bg_color = Color(0.012, 0.028, 0.060, 0.75)
	cont_style.border_color = Color(0.20, 0.55, 0.75, 0.45)
	cont_style.set_border_width_all(1)
	cont_style.set_corner_radius_all(6)
	cont_style.set_content_margin_all(16)
	_settings_tab_container.add_theme_stylebox_override("panel", cont_style)
	vbox.add_child(_settings_tab_container)

	# Footer buttons
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 14)
	vbox.add_child(footer_row)

	var reset_btn := Button.new()
	reset_btn.text = "↺ RESTAURAR POR DEFECTO"
	reset_btn.custom_minimum_size = Vector2(210, 38)
	reset_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_temp_settings = SaveManager.get_default_settings()
		SaveManager.save_settings(_temp_settings)
		_set_settings_tab(_settings_active_tab)
	)
	footer_row.add_child(reset_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(spacer)

	var save_btn := _make_primary_cta_button("✓ GUARDAR Y APLICAR CAMBIOS")
	save_btn.custom_minimum_size = Vector2(240, 38)
	save_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		SaveManager.save_settings(_temp_settings)
		_settings_modal.visible = false
	)
	footer_row.add_child(save_btn)

	_set_settings_tab("audio")

func _open_settings_modal() -> void:
	if _settings_modal == null:
		return
	_temp_settings = SaveManager.load_settings()
	_settings_modal.visible = true
	_set_settings_tab(_settings_active_tab)

func _set_settings_tab(tab_id: String) -> void:
	_settings_active_tab = tab_id
	for tid in _settings_tab_buttons.keys():
		var btn: Button = _settings_tab_buttons[tid]
		if tid == tab_id:
			var active_st := StyleBoxFlat.new()
			active_st.bg_color = Color(0.08, 0.22, 0.38, 0.95)
			active_st.border_color = Color(0.35, 0.95, 1.0)
			active_st.set_border_width_all(2)
			active_st.set_corner_radius_all(5)
			btn.add_theme_stylebox_override("normal", active_st)
		else:
			btn.remove_theme_stylebox_override("normal")

	for child in _settings_tab_container.get_children():
		child.queue_free()

	if _temp_settings.is_empty():
		_temp_settings = SaveManager.load_settings()

	if tab_id == "audio":
		_populate_settings_audio_tab()
	else:
		_populate_settings_graphics_tab()

func _populate_settings_audio_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_tab_container.add_child(vbox)

	_create_volume_slider_row(vbox, "Volumen Maestro (Master):", "master_volume", func(v: float) -> void:
		_temp_settings["master_volume"] = v
		AudioManager.set_master_volume(v)
	)

	_create_volume_slider_row(vbox, "Música de Fondo & Sinfónica:", "music_volume", func(v: float) -> void:
		_temp_settings["music_volume"] = v
		AudioManager.set_music_volume(v)
	)

	_create_volume_slider_row(vbox, "Efectos de Sonido & Cañones (SFX):", "sfx_volume", func(v: float) -> void:
		_temp_settings["sfx_volume"] = v
		AudioManager.set_sfx_volume(v)
		AudioManager.play_sfx("ui_click", -6.0)
	)

	_create_volume_slider_row(vbox, "Zumbido Ambiental del Éter (Ambient):", "ambient_volume", func(v: float) -> void:
		_temp_settings["ambient_volume"] = v
		AudioManager.set_ambient_volume(v)
	)

	vbox.add_child(HSeparator.new())

	var track_header := Label.new()
	track_header.text = "SELECTOR DE MÚSICA PRINCIPAL // BANCO ORQUESTAL DEL MAR ESTELAR"
	track_header.add_theme_font_size_override("font_size", 12)
	track_header.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	vbox.add_child(track_header)

	var track_row := HBoxContainer.new()
	track_row.add_theme_constant_override("separation", 12)
	vbox.add_child(track_row)

	var track_opt := OptionButton.new()
	track_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_opt.custom_minimum_size = Vector2(0, 36)

	var tracks_list := [
		"res://assets/audio/music/out_there.ogg",
		"res://assets/audio/music_prologue.ogg",
		"res://assets/audio/music_battle_march.ogg",
		"res://assets/audio/music/music_marea.ogg",
		"res://assets/audio/music/music_vinculados.ogg",
		"res://assets/audio/music/music_climax.ogg",
		"res://assets/audio/music/music_ace_tactical.ogg"
	]

	var cur_preferred: String = String(_temp_settings.get("preferred_menu_music", "res://assets/audio/music/out_there.ogg"))
	var selected_idx := 0
	for i in range(tracks_list.size()):
		var p: String = tracks_list[i]
		var title: String = String(AudioManager.TRACK_TITLES.get(p, p.get_file()))
		track_opt.add_item(title, i)
		if p == cur_preferred:
			selected_idx = i
	track_opt.selected = selected_idx
	track_row.add_child(track_opt)

	var preview_btn := Button.new()
	preview_btn.text = "▶ PROBAR TEMA"
	preview_btn.custom_minimum_size = Vector2(140, 36)
	preview_btn.pressed.connect(func() -> void:
		var chosen: String = tracks_list[track_opt.selected]
		AudioManager.crossfade_to(chosen, -11.0, 1.0)
	)
	track_row.add_child(preview_btn)

	var assign_btn := Button.new()
	assign_btn.text = "✓ FIJAR PARA EL MENÚ"
	assign_btn.custom_minimum_size = Vector2(170, 36)
	assign_btn.pressed.connect(func() -> void:
		var chosen: String = tracks_list[track_opt.selected]
		_temp_settings["preferred_menu_music"] = chosen
		AudioManager.play_sfx("ui_click", -8.0)
	)
	track_row.add_child(assign_btn)

func _create_volume_slider_row(parent: VBoxContainer, label_str: String, key_str: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_str
	lbl.custom_minimum_size = Vector2(260, 0)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(_temp_settings.get(key_str, 1.0))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 24)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(slider.value * 100.0)
	val_lbl.custom_minimum_size = Vector2(50, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%d%%" % int(v * 100.0)
		callback.call(v)
	)

func _populate_settings_graphics_tab() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_tab_container.add_child(vbox)

	# Fullscreen
	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 16)
	vbox.add_child(fs_row)

	var fs_lbl := Label.new()
	fs_lbl.text = "Modo de Pantalla Completa (Fullscreen):"
	fs_lbl.custom_minimum_size = Vector2(300, 0)
	fs_lbl.add_theme_font_size_override("font_size", 12)
	fs_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	fs_row.add_child(fs_lbl)

	var fs_check := CheckBox.new()
	fs_check.text = "Activar Pantalla Completa Exclusiva"
	fs_check.button_pressed = bool(_temp_settings.get("fullscreen", false))
	fs_check.toggled.connect(func(pressed: bool) -> void:
		_temp_settings["fullscreen"] = pressed
	)
	fs_row.add_child(fs_check)

	# MSAA 3D
	var msaa_row := HBoxContainer.new()
	msaa_row.add_theme_constant_override("separation", 16)
	vbox.add_child(msaa_row)

	var msaa_lbl := Label.new()
	msaa_lbl.text = "Suavizado de Bordes 3D (MSAA Antialiasing):"
	msaa_lbl.custom_minimum_size = Vector2(300, 0)
	msaa_lbl.add_theme_font_size_override("font_size", 12)
	msaa_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	msaa_row.add_child(msaa_lbl)

	var msaa_opt := OptionButton.new()
	msaa_opt.custom_minimum_size = Vector2(220, 32)
	msaa_opt.add_item("Desactivado", 0)
	msaa_opt.add_item("2X MSAA (Rápido)", 1)
	msaa_opt.add_item("4X MSAA (Equilibrado)", 2)
	msaa_opt.add_item("8X MSAA (Alta Definición)", 3)
	var cur_msaa: int = int(_temp_settings.get("msaa_3d", 2))
	msaa_opt.selected = clampi(cur_msaa, 0, 3)
	msaa_opt.item_selected.connect(func(idx: int) -> void:
		_temp_settings["msaa_3d"] = idx
	)
	msaa_row.add_child(msaa_opt)

	# Glow
	var glow_row := HBoxContainer.new()
	glow_row.add_theme_constant_override("separation", 16)
	vbox.add_child(glow_row)

	var glow_lbl := Label.new()
	glow_lbl.text = "Luminiscencia del Éter & Motores (Bloom/Glow):"
	glow_lbl.custom_minimum_size = Vector2(300, 0)
	glow_lbl.add_theme_font_size_override("font_size", 12)
	glow_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	glow_row.add_child(glow_lbl)

	var glow_check := CheckBox.new()
	glow_check.text = "Efectos de Brillo Cósmico y Resonancia Activos"
	glow_check.button_pressed = bool(_temp_settings.get("glow_enabled", true))
	glow_check.toggled.connect(func(pressed: bool) -> void:
		_temp_settings["glow_enabled"] = pressed
	)
	glow_row.add_child(glow_check)

	# SSAO
	var ssao_row := HBoxContainer.new()
	ssao_row.add_theme_constant_override("separation", 16)
	vbox.add_child(ssao_row)

	var ssao_lbl := Label.new()
	ssao_lbl.text = "Oclusión Ambiental de Cascos (SSAO):"
	ssao_lbl.custom_minimum_size = Vector2(300, 0)
	ssao_lbl.add_theme_font_size_override("font_size", 12)
	ssao_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	ssao_row.add_child(ssao_lbl)

	var ssao_check := CheckBox.new()
	ssao_check.text = "Sombras de Contacto en Hangar y Blindajes"
	ssao_check.button_pressed = bool(_temp_settings.get("ssao_enabled", true))
	ssao_check.toggled.connect(func(pressed: bool) -> void:
		_temp_settings["ssao_enabled"] = pressed
	)
	ssao_row.add_child(ssao_check)

	# FPS limit
	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 16)
	vbox.add_child(fps_row)

	var fps_lbl := Label.new()
	fps_lbl.text = "Límite de Fotogramas por Segundo (Max FPS):"
	fps_lbl.custom_minimum_size = Vector2(300, 0)
	fps_lbl.add_theme_font_size_override("font_size", 12)
	fps_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	fps_row.add_child(fps_lbl)

	var fps_opt := OptionButton.new()
	fps_opt.custom_minimum_size = Vector2(220, 32)
	var fps_values := [0, 30, 60, 120, 144]
	var fps_labels := ["Sin Límite (Máximo Rendimiento)", "30 FPS (Ahorro de Energía)", "60 FPS (Estándar Suave)", "120 FPS (Tasa de Refresco Alta)", "144 FPS (Ultra Competitivo)"]
	var cur_fps: int = int(_temp_settings.get("max_fps", 0))
	var fps_sel := 0
	for i in range(fps_values.size()):
		fps_opt.add_item(fps_labels[i], i)
		if fps_values[i] == cur_fps:
			fps_sel = i
	fps_opt.selected = fps_sel
	fps_opt.item_selected.connect(func(idx: int) -> void:
		_temp_settings["max_fps"] = fps_values[idx]
	)
	fps_row.add_child(fps_opt)

# ==============================================================================
# TACTICAL MANUAL & CODEX MODAL
# ==============================================================================
var _codex_active_topic: int = 0
var _codex_content_vbox: VBoxContainer
var _codex_topic_buttons: Array[Button] = []

func _build_codex_modal() -> void:
	_codex_modal = Control.new()
	_codex_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_codex_modal.visible = false
	add_child(_codex_modal)

	var bg_dim := ColorRect.new()
	bg_dim.color = Color(0.008, 0.02, 0.04, 0.88)
	bg_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_codex_modal.add_child(bg_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_codex_modal.add_child(center)

	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(980, 620)
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.018, 0.045, 0.088, 0.96)
	win_style.border_color = Color(0.28, 0.78, 0.98, 0.85)
	win_style.set_border_width_all(2)
	win_style.set_corner_radius_all(8)
	win_style.set_content_margin_all(20)
	window.add_theme_stylebox_override("panel", win_style)
	center.add_child(window)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	window.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)

	var hdr_titles := VBoxContainer.new()
	hdr_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hdr_titles)

	var title_lbl := Label.new()
	title_lbl.text = "MANUAL TÁCTICO DEL MAR ESTELAR // FLEET CODEX"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	hdr_titles.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Fundamentos de Combate Naval Espacial en 3D: Fases, Inercia Newtoniana, Viento y Héroes Ases"
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.82, 0.94))
	hdr_titles.add_child(sub_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕ CERRAR"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("ui_click", -8.0)
		_codex_modal.visible = false
	)
	hdr.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	var body_row := HBoxContainer.new()
	body_row.add_theme_constant_override("separation", 16)
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_row)

	# Left Column: Topics List
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	var lp_style := StyleBoxFlat.new()
	lp_style.bg_color = Color(0.012, 0.028, 0.060, 0.75)
	lp_style.border_color = Color(0.20, 0.55, 0.75, 0.45)
	lp_style.set_border_width_all(1)
	lp_style.set_corner_radius_all(6)
	lp_style.set_content_margin_all(10)
	left_panel.add_theme_stylebox_override("panel", lp_style)
	body_row.add_child(left_panel)

	var topics_vbox := VBoxContainer.new()
	topics_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(topics_vbox)

	var topics := [
		"1. LAS DOS FASES DE COMBATE",
		"2. EL VIENTO Y EL ÉTER (BARLOVENTO)",
		"3. DINÁMICA NEWTONIANA Y DERAPE",
		"4. BLINDAJE DIRECCIONAL Y SINERGIAS",
		"5. CONTROLES Y COMBOS TÁCTICOS"
	]

	_codex_topic_buttons.clear()
	for i in range(topics.size()):
		var t_idx := i
		var btn := Button.new()
		btn.text = topics[i]
		btn.custom_minimum_size = Vector2(0, 42)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click", -8.0)
			_set_codex_topic(t_idx)
		)
		topics_vbox.add_child(btn)
		_codex_topic_buttons.append(btn)

	var tp_spacer := Control.new()
	tp_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	topics_vbox.add_child(tp_spacer)

	# Right Column: Content Scroll
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rp_style := StyleBoxFlat.new()
	rp_style.bg_color = Color(0.012, 0.028, 0.060, 0.75)
	rp_style.border_color = Color(0.20, 0.55, 0.75, 0.45)
	rp_style.set_border_width_all(1)
	rp_style.set_corner_radius_all(6)
	rp_style.set_content_margin_all(18)
	right_panel.add_theme_stylebox_override("panel", rp_style)
	body_row.add_child(right_panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_panel.add_child(scroll)

	_codex_content_vbox = VBoxContainer.new()
	_codex_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_content_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_codex_content_vbox)

	_set_codex_topic(0)

func _open_codex_modal() -> void:
	if _codex_modal == null:
		return
	_codex_modal.visible = true
	_set_codex_topic(_codex_active_topic)

func _set_codex_topic(topic_idx: int) -> void:
	_codex_active_topic = topic_idx
	for i in range(_codex_topic_buttons.size()):
		var b := _codex_topic_buttons[i]
		if i == topic_idx:
			var act_st := StyleBoxFlat.new()
			act_st.bg_color = Color(0.08, 0.22, 0.38, 0.95)
			act_st.border_color = Color(0.35, 0.95, 1.0)
			act_st.set_border_width_all(2)
			act_st.set_corner_radius_all(5)
			b.add_theme_stylebox_override("normal", act_st)
		else:
			b.remove_theme_stylebox_override("normal")

	for child in _codex_content_vbox.get_children():
		child.queue_free()

	match topic_idx:
		0:
			_add_codex_section("1. LAS DOS FASES DE COMBATE", "El núcleo táctico de BARLOVENTO equilibra estrategia a nivel de flota con el combate de cazas/mechas Ases.")
			_add_codex_paragraph("FASE 1: ALMIRANTE (SIMULTÁNEA Y ESTRATÉGICA)\nEn esta fase no disparas armas directamente. Asignas vectores de desplazamiento a tu flota completa y ajustas cuadrantes de combate en 3D (Vanguardia, Babor, Estribor, Retaguardia). Ambos bandos comprometen sus órdenes a la vez y la simulación avanza simultáneamente.")
			_add_codex_paragraph("FASE 2: ASES (TÁCTICA POR TURNOS Y DUELOS)\nCuando las naves entran en alcance de fuego, la batalla pasa al control de los pilotos Ases y comandantes de línea. Cada navío recibe Puntos de Acción (AP) individuales según su clase. Puedes maniobrar, disparar cañones primarios, orientar el blindaje hacia el enemigo o desatar habilidades exclusivas de facción.")
			_add_codex_tip("CONSEJO DE GUERRA: El 50% de la batalla se gana en la colocación de la Fase Almirante; un mal posicionamiento no puede salvarse fácilmente solo con potencia de fuego en la Fase As.")

		1:
			_add_codex_section("2. EL VIENTO Y EL ÉTER (BARLOVENTO)", "El espacio no está vacío; es el Mar Estelar surcado por corrientes de Éter.")
			_add_codex_paragraph("LA VENTAJA DE BARLOVENTO (WEATHER GAUGE)\nEn la era de la navegación a vela, la flota 'a barlovento' tenía la iniciativa y el viento a favor. En BARLOVENTO ocurre lo mismo con las corrientes de Éter:")
			_add_codex_paragraph("✦ Naves que avanzan CON la corriente (+Éter): Ganan +25% de aceleración máxima, menor fricción térmica y recuperan +1 AP al inicio de su turno.")
			_add_codex_paragraph("✦ Naves forzadas a virar CONTRA la corriente (-Éter): Sufren mayor calentamiento en los disipadores y sus giros requieren más potencia de maniobra.")
			_add_codex_tip("TELEMETRÍA: Consulta siempre el indicador 'WEATHER-GAUGE' en la esquina superior izquierda para conocer el vector y la intensidad activa del Éter (1 a 5).")

		2:
			_add_codex_section("3. DINÁMICA NEWTONIANA Y DERRAPE", "Las naves espaciales no se detienen instantáneamente: tienen masa, inercia y momento.")
			_add_codex_paragraph("VECTORES DE RUMBO VS. VECTOR DE VELOCIDAD\nCuando ordenas a tu nave cambiar de rumbo (orientación de morro), los propulsores de maniobra giran el casco, pero el vector de velocidad acumulado continúa empujando la nave en su dirección previa. Esto produce un derrape táctico (drift) que puedes aprovechar para disparar andanadas laterales mientras te desplazas lateralmente.")
			_add_codex_paragraph("HIGH-G BURN (QUEMADO DE ALTO G)\nPermite a las unidades más ágiles gastar AP o combustible de éteron para contrarrestar la inercia bruscamente y cambiar su vector de escape de inmediato.")
			_add_codex_tip("CUIDADO CON LA INERCIA: Un acorazado de Acero de 12.000 toneladas tardará varios turnos en frenar una vez que adquiera velocidad crucero hacia un asteroide o estación.")

		3:
			_add_codex_section("4. BLINDAJE DIRECCIONAL Y SINERGIAS", "Cada navío posee 4 sectores independientes de blindaje: Proa, Babor, Estribor y Popa.")
			_add_codex_paragraph("PROTECCIÓN POR SECTORES\nEl blindaje absorbe el daño de los proyectiles antes de que afecte la integridad del casco interno:")
			_add_codex_paragraph("✦ ARMADA DE ACERO: Posee el blindaje de proa más grueso de la galaxia. Su táctica es avanzar en punta de lanza y desatar baterías de andanada.")
			_add_codex_paragraph("✦ LOS VINCULADOS: Blindaje cerámico ligero con escudos resonantes. Esquivan ataques mediante saltos de vector y sus lanzas de resonancia perforan escudos al impactar flancos.")
			_add_codex_paragraph("✦ LA MAREA LIBRE: Cascos reforzados de madera presurizada y aleaciones de bronce. Utilizan arpones y abordajes corsarios de corto alcance.")
			_add_codex_tip("FOCO DE DISPARO: Ataca continuamente el flanco cuyo blindaje ya haya caído para infligir daño crítico directo a los módulos del casco enemigo.")

		4:
			_add_codex_section("5. CONTROLES Y COMBOS TÁCTICOS", "Guía rápida de teclas y atajos para el mando táctico.")
			_add_codex_paragraph("CÁMARA TÁCTICA 3D:\n✦ Clic Derecho + Arrastrar: Rotar cámara orbital 3D alrededor de la flota.\n✦ Rueda del Ratón: Zoom de acercamiento / alejamiento táctico.\n✦ Teclas W, A, S, D: Desplazamiento panorámico de cámara sobre el Mar Estelar.\n✦ Tecla R: Restablecer cámara al centro del combate.")
			_add_codex_paragraph("GESTIÓN DE FASES Y ACCIONES:\n✦ Clic Izquierdo en Nave: Seleccionar nave aliada u objetivo hostil.\n✦ Barra Espaciadora / ENTER: Confirmar orden / Finalizar Fase activa.\n✦ Tecla F5: Guardado Rápido (Crea estado táctico en tiempo real).\n✦ Tecla F9: Carga Rápida de última batalla guardada.\n✦ Tecla ESC: Menú de Pausa / Descartar selección / Cerrar modales.")
			_add_codex_tip("COMBOS DE HÉROE: Activa 'Puntería de Precisión' en el Almirante Vane antes de disparar el cañón de riel para garantizar impactos en la popa del objetivo.")

func _add_codex_section(title_text: String, subtitle_text: String) -> void:
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	_codex_content_vbox.add_child(t)

	var st := Label.new()
	st.text = subtitle_text
	st.add_theme_font_size_override("font_size", 11)
	st.add_theme_color_override("font_color", Color(0.65, 0.82, 0.94))
	_codex_content_vbox.add_child(st)

	_codex_content_vbox.add_child(HSeparator.new())

func _add_codex_paragraph(text_content: String) -> void:
	var p := Label.new()
	p.text = text_content
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_theme_font_size_override("font_size", 12)
	p.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_codex_content_vbox.add_child(p)

func _add_codex_tip(tip_content: String) -> void:
	var tip_panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.12, 0.18, 0.85)
	st.border_color = Color(1.0, 0.78, 0.35, 0.85)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.set_content_margin_all(10)
	tip_panel.add_theme_stylebox_override("panel", st)

	var l := Label.new()
	l.text = tip_content
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	tip_panel.add_child(l)

	_codex_content_vbox.add_child(tip_panel)
