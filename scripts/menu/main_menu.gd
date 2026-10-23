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
    LoreDB.current_stage_id = stage_id

    for child in _stage_selector_row.get_children():
        child.queue_free()
    for child in _squadron_vbox.get_children():
        child.queue_free()

    var stage_titles := [
        "STAGE 01 [TUTORIAL]: SLUICE WELL-09",
        "STAGE 02: RESONANCE SPIRE",
        "STAGE 03: CALM THRESHOLD",
        "STAGE 04: CRUCIBLE OF FIRE",
        "STAGE 05: IRON SIPHON SLUICES",
        "STAGE 06: BASTION WALL DEFENSE",
        "STAGE 07: SIEGE OF OBSIDIAN REACH",
        "STAGE 08: THE GREAT SLUICE GATE",
        "STAGE 09: IRON FORTRESS LEVIATHAN",
        "STAGE 10: SINGULARITY PERIMETER",
        "STAGE 11: THE DYING LIGHT",
        "STAGE 12: APEX OF THE CALM"
    ]

    for i in range(12):
        var s_num := i + 1
        var sid := "acero_stage_%d" % s_num
        var cleared := SaveManager.is_stage_completed(sid)
        var btn := Button.new()
        btn.text = ("%s ✓" % stage_titles[i]) if cleared else stage_titles[i]
        btn.custom_minimum_size = Vector2(210, 32)
        if sid == stage_id:
            btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
        elif cleared:
            btn.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
        btn.pressed.connect(func() -> void:
            AudioManager.play_sfx("ui_click", -8.0)
            _populate_acero_stage_briefing(sid)
        )
        _stage_selector_row.add_child(btn)

    var cur_num := int(stage_id.get_slice("_", 2))
    var act_str := "ACT I" if cur_num <= 4 else ("ACT II" if cur_num <= 8 else "ACT III")

    var art_path := "res://assets/briefings/acero_act1.png"
    if cur_num == 1:
        art_path = "res://assets/factions/acero_stage1_briefing.png"
    elif cur_num == 6:
        art_path = "res://assets/briefings/acero_forge.png"
    elif cur_num in [11, 12]:
        art_path = "res://assets/briefings/acero_dam.png"
    elif cur_num >= 9:
        art_path = "res://assets/briefings/acero_act3.png"
    elif cur_num >= 5:
        art_path = "res://assets/briefings/acero_act2.png"
    var art_tex: Texture2D = load(art_path)
    if art_tex == null:
        art_tex = load("res://assets/factions/card_acero.png")
    _briefing_art_rect.texture = art_tex

    _commander_portrait_rect.texture = load("res://assets/heroes/ace_vane.png")
    _commander_name_lbl.text = "FLEET ADMIRAL VANE"
    _commander_role_lbl.text = "Flagship Command // CNS Iron Bastion (Anvil-Class)" 

    match stage_id:
        "acero_stage_1":
            _briefing_title_lbl.text = "ACT I // STAGE 01 [TUTORIAL]: DEFENSE OF SLUICE STATION WELL-09"
            _briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // NAVAL ACADEMY & BATTLE DRILL"
            _commander_quote_lbl.text = "\"Officers and Cadets, welcome to the tactical line. Sluice Station Well-09 is under raid by corsair scouts. Today you master the foundation of Acero warfare: heavy armor angling, simultaneous WEGO maneuvering, and interlocking broadside fire. Form a wall of steel. Steel endures.\""
            _objectives_lbl.text = "◆ TUTORIAL DRILL 1 (FLEET COMMAND): Learn simultaneous Admiral WEGO movement, ship selection, and vector steering.\n◆ TUTORIAL DRILL 2 (ACERO DOCTRINE): Heavy Bow/Flank armor, broadsides (42°–138°), and Action Points (AP).\n◆ PRIMARY OBJECTIVE: Destroy all 3 hostile Free Tide corsair warships threatening Sluice Station Well-09.\n◆ SECONDARY OBJECTIVE: Ensure Flagship CNS Iron Bastion survives the engagement."
            _add_squadron_row("acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            _add_squadron_row("acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            _add_squadron_row("acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH TUTORIAL STAGE 01"

        "acero_stage_2":
            _briefing_title_lbl.text = "ACT I // STAGE 02: AMBUSH AT THE RESONANCE SPIRE"
            _briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // HOSTILES: THE VINCULADOS CHOIR WING"
            _commander_quote_lbl.text = "\"With Well-09 secured, our convoy pushes toward the Resonance Spire. Commander Kaelen's Vinculados Choir Wing is riding a violent crosswind current to ambush our flank. Hold formation, claim the upwind Weather-Gauge [BARLOVENTO], and crush their nimble frames with concentrated railgun salvos!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Destroy all 3 hostile Vinculados combat frames in the Resonance Spire sector.\n◆ SECONDARY OBJECTIVE: Ensure Flagship CNS Iron Bastion survives.\n◆ WEATHER-GAUGE DOCTRINE: Attacking from upwind along the Éther current grants [BARLOVENTO] (+12% Hit & +15% Damage)."
            _add_squadron_row("acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            _add_squadron_row("acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            _add_squadron_row("acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 02"

        "acero_stage_3":
            _briefing_title_lbl.text = "ACT I // STAGE 03: BASTION OF THE CALM THRESHOLD"
            _briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // HOSTILES: GRAND CORSAIR FLAGSHIP ARMADA"
            _commander_quote_lbl.text = "\"The Calm wavefront has reached the inner sluice wall. A reinforced Free Tide armada led by a heavily armored flagship Galleon is making a final desperate charge to breach the dam. Our Veteran Aces stand ready—anchor the line and prove that Steel Endures!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Defeat the reinforced 3-ship Veteran Corsair Armada at the Calm Threshold.\n◆ SECONDARY OBJECTIVE: Ensure Flagship CNS Iron Bastion survives the final stand.\n◆ VETERAN ACES: Your surviving ships carry over their Veteran Rank bonuses into this decisive battle!"
            _add_squadron_row("acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            _add_squadron_row("acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            _add_squadron_row("acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 03"

        "acero_stage_4":
            _briefing_title_lbl.text = "ACT I // STAGE 04: THE CRUCIBLE OF FIRE"
            _briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // HEAVY REINFORCEMENTS ENGAGEMENT"
            _commander_quote_lbl.text = "\"Hostile incursions threaten the foundry furnaces. Heavy monitor fire and cruiser salvos must suppress enemy advances across the inner line.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Eliminate enemy vanguard forces threatening the smelting ring.\n◆ SECONDARY OBJECTIVE: Maintain line integrity without losing capital escorts.\n◆ TACTICAL TIP: Focus heavy railguns on high-threat targets at extreme range."
            _add_squadron_row("acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            _add_squadron_row("acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            _add_squadron_row("acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 04"

        "acero_stage_5", "acero_stage_6", "acero_stage_7", "acero_stage_8":
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_tarek.png")
            _commander_name_lbl.text = "FLEET ADMIRAL TAREK"
            _commander_role_lbl.text = "Siege Line Command // CNS Crucible (Heavy Monitor)"
            _briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            _briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // HEAVY SIEGE MONITOR DEPLOYMENT"
            _commander_quote_lbl.text = "\"The Siege Line is mobilized. With the Crucible-Class Heavy Siege Monitor on station, our plasma mortars will pulverize enemy hulls at extreme distance before they ever close the vector.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Break through hostile defensive lines and annihilate enemy capital squadrons.\n◆ SECONDARY OBJECTIVE: Protect CNS Crucible during long-range mortar bombardment cycles.\n◆ SIEGE DOCTRINE: Heavy Mortars deliver massive kinetic impact with long reload cycles."
            _add_squadron_row("acero_monitor", "CNS Crucible", "Crucible-Class Heavy Siege Monitor • Adm. Tarek", "HP 310 | RNG 64m | Heavy Plasma Mortar")
            _add_squadron_row("acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            _add_squadron_row("acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            _add_squadron_row("acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "acero_stage_9", "acero_stage_10", "acero_stage_11":
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_tarek.png")
            _commander_name_lbl.text = "FLEET ADMIRAL TAREK"
            _commander_role_lbl.text = "Combined Arms Armada // Fortress Battlefleet"
            _briefing_title_lbl.text = "ACT III // STAGE %02d: %s" % [cur_num, stage_titles[cur_num - 1]]
            _briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // FULL TASK FORCE BATTLE BASTION"
            _commander_quote_lbl.text = "\"All strike groups converge. The Calm approaches maximum expansion. Deploy the Arsenal Carrier Forge-01 and heavy escorts. We dictate the terms of this engagement.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Destroy enemy elite vanguard and flagship forces.\n◆ SECONDARY OBJECTIVE: Maintain the defensive perimeter around Arsenal-Class Carrier Forge-01.\n◆ TASK FORCE DOCTRINE: Interlocking flak fields and concentrated railgun fire neutralize enemy flanking vectors."
            _add_squadron_row("acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            _add_squadron_row("acero_monitor", "CNS Crucible", "Crucible-Class Heavy Siege Monitor • Adm. Tarek", "HP 310 | RNG 64m | Heavy Plasma Mortar")
            _add_squadron_row("acero_carrier", "CNS Forge-01", "Arsenal-Class Mobile Fleet Bastion • Cmdr. Vance", "HP 420 | RNG 48m | Fleet Defense & Flak Bastion")
            _add_squadron_row("acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "acero_stage_12":
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_vane.png")
            _commander_name_lbl.text = "MARSHALL KURTZ & FLEET ADMIRAL VANE"
            _commander_role_lbl.text = "Supreme Command // CNS Imperator (Colossus Juggernaut)"
            _briefing_title_lbl.text = "ACT III // STAGE 12: APEX OF THE CALM // THE FINAL DAM"
            _briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // DECISIVE CLIMAX OF THE STAR SEA"
            _commander_quote_lbl.text = "\"This is the end of retreat. The Calm Singularity opens before us. Marshall Kurtz has brought the Colossus Juggernaut Imperator to anchor the final dam. Obliterate all remaining hostiles. Steel triumphs!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Obliterate the unified alien and corsair armada at the Calm Singularity core.\n◆ SECONDARY OBJECTIVE: Ensure Supreme Flagship CNS Imperator remains combat operational.\n◆ FINAL DOCTRINE: The Colossus-Class Juggernaut boasts 600 HP, quad spinal heavy railguns, and impervious all-aspect armor!"
            _add_squadron_row("acero_juggernaut", "CNS Imperator", "Colossus-Class Supreme Fortress • Marshall Kurtz", "HP 600 | RNG 68m | Quad Heavy Spinal Rail-Batteries")
            _add_squadron_row("acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            _add_squadron_row("acero_monitor", "CNS Crucible", "Crucible-Class Heavy Siege Monitor • Adm. Tarek", "HP 310 | RNG 64m | Heavy Plasma Mortar")
            _add_squadron_row("acero_carrier", "CNS Forge-01", "Arsenal-Class Mobile Fleet Bastion • Cmdr. Vance", "HP 420 | RNG 48m | Fleet Defense & Flak Bastion")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH FINAL STAGE 12"

        _:
            _briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            _briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // SECTOR %02d" % cur_num
            _commander_quote_lbl.text = "\"All battle groups maintain disciplined vector formation. Angle heavy bow armor into incoming vector fire and execute synchronized broadsides.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Neutralize all hostile combatants in the assigned tactical sector.\n◆ SECONDARY OBJECTIVE: Maintain flagship integrity and achieve naval superiority."
            _add_squadron_row("acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            _add_squadron_row("acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            _add_squadron_row("acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

func _populate_vinculados_stage_briefing(stage_id: String) -> void:
    LoreDB.current_stage_id = stage_id

    for child in _stage_selector_row.get_children():
        child.queue_free()
    for child in _squadron_vbox.get_children():
        child.queue_free()

    var stage_titles := [
        "STAGE 01 [TUTORIAL]: SANCTUARY SPIRE",
        "STAGE 02: CRYSTAL CHASM",
        "STAGE 03: GENESIS RING",
        "STAGE 04: HARMONIC ASSAULT",
        "STAGE 05: THE CHOIR GATE",
        "STAGE 06: RESONANCE TRENCH",
        "STAGE 07: SERAPH'S ASCENT",
        "STAGE 08: SIPHON OF SOULS",
        "STAGE 09: MOBILE ARMOR AWAKENING",
        "STAGE 10: SINGULARITY DIVE",
        "STAGE 11: GREAT HARMONIZATION",
        "STAGE 12: TRANSCENDENCE NEXUS"
    ]

    for i in range(12):
        var s_num := i + 1
        var sid := "vinculados_stage_%d" % s_num
        var cleared := SaveManager.is_stage_completed(sid)
        var btn := Button.new()
        btn.text = ("%s ✓" % stage_titles[i]) if cleared else stage_titles[i]
        btn.custom_minimum_size = Vector2(210, 32)
        if sid == stage_id:
            btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
        elif cleared:
            btn.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
        btn.pressed.connect(func() -> void:
            AudioManager.play_sfx("ui_click", -8.0)
            _populate_vinculados_stage_briefing(sid)
        )
        _stage_selector_row.add_child(btn)

    var cur_num := int(stage_id.get_slice("_", 2))
    var act_str := "ACT I" if cur_num <= 4 else ("ACT II" if cur_num <= 8 else "ACT III")

    var art_path := "res://assets/briefings/vinculados_act1.png"
    if cur_num == 3:
        art_path = "res://assets/briefings/vinculados_genesis.png"
    elif cur_num == 12:
        art_path = "res://assets/briefings/vinculados_ascension.png"
    elif cur_num >= 8:
        art_path = "res://assets/briefings/vinculados_act3.png"
    elif cur_num >= 4:
        art_path = "res://assets/briefings/vinculados_act2.png"
    var art_tex: Texture2D = load(art_path)
    if art_tex == null:
        art_tex = load("res://assets/factions/card_vinculados.png")
    _briefing_art_rect.texture = art_tex

    _commander_portrait_rect.texture = load("res://assets/heroes/ace_kaelen.png")
    _commander_name_lbl.text = "ACE PILOT KAELEN-7"
    _commander_role_lbl.text = "Lead Resonance Choir // Eidolon Ace Platoon" 

    match stage_id:
        "vinculados_stage_1":
            _briefing_title_lbl.text = "ACT II // STAGE 01 [TUTORIAL]: DEFENSE OF SANCTUARY SPIRE PSALM-4"
            _briefing_sub_lbl.text = "FACTION: THE VINCULADOS // HARMONIC DEFENSE & STERN RAKE TUTORIAL"
            _commander_quote_lbl.text = "\"Welcome to the Choir Wing, pilot. The Acero extraction force is encroaching upon Sanctuary Spire Psalm-4. Synchronize your neural frame with the Éther: our mobile suit platoons dance around their clumsy broadsides. Shield the Carrier Cradle, out-pivot their bulk, and strike their unarmored thrusters with critical Stern Rakes!\""
            _objectives_lbl.text = "◆ TUTORIAL DRILL 1 (SANCTUARY DEFENSE): Protect the levitating resonance crystals of Sanctuary Spire Psalm-4.\n◆ TUTORIAL DRILL 2 (MECHA MOBILITY & STERN RAKE): Use agile vector turns to slip behind Acero hulls (+40% critical damage).\n◆ PRIMARY OBJECTIVE: Intercept and neutralize the Acero strike force.\n◆ SECONDARY OBJECTIVE: Keep Carrier Ark Sanktuario Albor operational."
            _add_squadron_row("vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam & PD Lasers")
            _add_squadron_row("vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            _add_squadron_row("vinculados_anima", "Anima-01 Interceptor Wing", "Anima Strike Platoon • Ace Mirei-4", "HP 115 | SPD 36 m/s | High-Speed Echelon Trio & Flank Intercept")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH TUTORIAL STAGE 01"

        "vinculados_stage_2":
            _briefing_title_lbl.text = "ACT II // STAGE 02: DIVE INTO THE CRYSTAL CHASM"
            _briefing_sub_lbl.text = "FACTION: THE VINCULADOS // VERTICAL ADVANTAGE & DIVE BOMBER TACTICS"
            _commander_quote_lbl.text = "\"Imperial dreadnoughts are crawling through the deep basalt canyon below to sever our crystal conduits. We hold the high celestial ground (+16m altitude advantage). Dive upon their top decks where their armor is weakest!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Dive from upper celestial ledge (+16m) and destroy all 3 Acero warships traversing the chasm trench below.\n◆ SECONDARY OBJECTIVE: Ensure Cradle Carrier Sanktuario Albor survives.\n◆ VERTICAL ADVANTAGE DOCTRINE: Firing down on lower altitude targets bypasses heavy belt armor (+20% Critical Hit)."
            _add_squadron_row("vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam & PD Lasers")
            _add_squadron_row("vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            _add_squadron_row("vinculados_anima", "Anima-01 Interceptor Wing", "Anima Strike Platoon • Ace Mirei-4", "HP 115 | SPD 36 m/s | High-Speed Echelon Trio & Flank Intercept")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 02"

        "vinculados_stage_3":
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_vael.png")
            _commander_name_lbl.text = "ACE PILOT VAEL-09"
            _commander_role_lbl.text = "Nous Frame Synchronizer // Transcendence Gate"
            _briefing_title_lbl.text = "ACT II // STAGE 03: THE GENESIS RING // TRANSCENDENCE"
            _briefing_sub_lbl.text = "FACTION: THE VINCULADOS // NOUS FRAME ACTIVATION & GATE DEFENSE"
            _commander_quote_lbl.text = "\"The Calm has reached the outer perimeter of the Star Sea. Ace Vael has synchronized with the legendary Nous-09 frame. Hold the gate ring against the combined Acero and renegade corsair assault!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Defeat the reinforced Acero-Corsair assault fleet at the Genesis Ring.\n◆ SECONDARY OBJECTIVE: Ensure Carrier Sanktuario Albor and the Genesis Ring are protected.\n◆ PINNACLE ACE FRAME: Deploy the legendary Nous frame wielding autonomous resonance funnels and the Transcendent Mega-Buster!"
            _add_squadron_row("vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam & PD Lasers")
            _add_squadron_row("vinculados_nous", "Nous Transcendent Frame", "Prototype Transcendent Ace Frame • Ace Vael-09", "HP 220 | SPD 32 m/s | Autonomous Fin Funnels & Mega-Buster Beam")
            _add_squadron_row("vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 03"

        "vinculados_stage_4", "vinculados_stage_5", "vinculados_stage_6", "vinculados_stage_7":
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_vael.png")
            _commander_name_lbl.text = "ACE PILOT VAEL-09"
            _commander_role_lbl.text = "Heavy Frame Vanguard // Nous & Psyche Wings"
            _briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            _briefing_sub_lbl.text = "FACTION: THE VINCULADOS // NEURAL RESONANCE INFILTRATION"
            _commander_quote_lbl.text = "\"The Choir expands. Deploy the Psyche Heavy Frame and Eidolon platoons in synchronized vector patterns. Let no intruder interrupt the song.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Clear all enemy interdictors from the resonance conduit.\n◆ SECONDARY OBJECTIVE: Maintain Carrier Ark Sanktuario Albor above 50% hull integrity.\n◆ TACTICAL TIP: Use fin funnels and resonance beams to bypass armored shields."
            _add_squadron_row("vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam & PD Lasers")
            _add_squadron_row("vinculados_psyche", "Psyche Heavy Frame", "Psycho-Resonance Frame • Ace Vael-09", "HP 240 | SPD 28 m/s | Heavy Resonance Beam Lance")
            _add_squadron_row("vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            _add_squadron_row("vinculados_anima", "Anima-01 Interceptor Wing", "Anima Strike Platoon • Ace Mirei-4", "HP 115 | SPD 36 m/s | High-Speed Echelon Trio")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "vinculados_stage_8", "vinculados_stage_9", "vinculados_stage_10", "vinculados_stage_11":
            _briefing_art_rect.texture = load("res://assets/ships/vinculados/mobile_armor_colossus.png")
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_orin.png")
            _commander_name_lbl.text = "ACE PILOT ORIN-9"
            _commander_role_lbl.text = "Seraph Mobile Armor Commander // High Choir"
            _briefing_title_lbl.text = "ACT III // STAGE %02d: %s" % [cur_num, stage_titles[cur_num - 1]]
            _briefing_sub_lbl.text = "FACTION: THE VINCULADOS // MOBILE ARMOR SYSTEM AWAKENING"
            _commander_quote_lbl.text = "\"The psychic resonance is reaching critical amplitude! The Mobile Armor Seraph awakens. We will pierce through the Calm with pure harmonic will.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Annihilate the hostile fleet guarding the harmonic siphon.\n◆ SECONDARY OBJECTIVE: Keep the Mobile Armor and Carrier Ark synchronized.\n◆ MOBILE ARMOR DOCTRINE: Colossus Seraph-Prime unleashes twin mega-particle beams and autonomous funnel barrages."
            _add_squadron_row("vinculados_colossus", "Seraph-Prime", "Colossus Mobile Armor • Ace Orin-9", "HP 500 | SPD 26 m/s | Twin Spinal Mega-Beams & Funnel Array")
            _add_squadron_row("vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam")
            _add_squadron_row("vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            _add_squadron_row("vinculados_chorus", "Chorus Screen Wing", "Light Mecha Flotilla • Ace Vael-09", "HP 130 | SPD 34 m/s | Quad Light Drone Formation")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "vinculados_stage_12":
            _briefing_art_rect.texture = load("res://assets/ships/vinculados/mobile_armor_colossus.png")
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_orin.png")
            _commander_name_lbl.text = "HIGH CONDUCTOR & ACE ORIN-9"
            _commander_role_lbl.text = "Transcendence Choir // The Apex Harmonizer"
            _briefing_title_lbl.text = "ACT III // STAGE 12: TRANSCENDENCE NEXUS // THE FINAL HYMN"
            _briefing_sub_lbl.text = "FACTION: THE VINCULADOS // SOUL ASCENSION BEYOND THE CALM"
            _commander_quote_lbl.text = "\"This is the final threshold of physical space. Our minds are one with the Éther. Awaken every resonance funnel, open the mega-beam manifolds, and transcend the dying sea!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Neutralize the supreme imperial siege fleet at the Transcendence Nexus.\n◆ SECONDARY OBJECTIVE: Protect Mobile Armor Seraph-Prime through the ascension climax.\n◆ FINAL TRANSCENDENCE: Coordinate high-speed mecha platoons and colossal mobile armor funnels for maximum synchronization!"
            _add_squadron_row("vinculados_colossus", "Seraph-Prime", "Colossus Mobile Armor • Ace Orin-9", "HP 500 | SPD 26 m/s | Twin Spinal Mega-Beams & Funnel Array")
            _add_squadron_row("vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam")
            _add_squadron_row("vinculados_psyche", "Psyche Heavy Frame", "Psycho-Resonance Frame • Ace Vael-09", "HP 240 | SPD 28 m/s | Heavy Resonance Beam Lance")
            _add_squadron_row("vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH FINAL STAGE 12"

        _:
            _briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            _briefing_sub_lbl.text = "FACTION: THE VINCULADOS // SECTOR %02d" % cur_num
            _commander_quote_lbl.text = "\"Synchronize neural telemetry. Out-pivot the enemy, ride the upwind vector, and strike from unexpected angles.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Clear all hostile warships from the operational grid.\n◆ SECONDARY OBJECTIVE: Protect the Carrier Cradle and maintain flight cohesion."
            _add_squadron_row("vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Mega-Beam")
            _add_squadron_row("vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation")
            _add_squadron_row("vinculados_anima", "Anima-01 Interceptor Wing", "Anima Strike Platoon • Ace Mirei-4", "HP 115 | SPD 36 m/s | Echelon Trio")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

func _populate_marea_stage_briefing(stage_id: String) -> void:
    LoreDB.current_stage_id = stage_id

    for child in _stage_selector_row.get_children():
        child.queue_free()
    for child in _squadron_vbox.get_children():
        child.queue_free()

    var stage_titles := [
        "STAGE 01 [TUTORIAL]: BASALT NARROWS",
        "STAGE 02: FOUNDRY VULCAN-3",
        "STAGE 03: THE MAELSTROM",
        "STAGE 04: CORSAIR FLOTILLA HAVEN",
        "STAGE 05: IRON SIPHON RAID",
        "STAGE 06: SOVEREIGN DRIFT AMBUSH",
        "STAGE 07: LEVIATHAN REEF",
        "STAGE 08: GREAT SLUICE GATE ASSAULT",
        "STAGE 09: STORM CITADEL SIEGE",
        "STAGE 10: EYE OF THE ETHER VORTEX",
        "STAGE 11: BREAKING THE CALM LINE",
        "STAGE 12: LIBERATION OF THE STAR SEA"
    ]

    for i in range(12):
        var s_num := i + 1
        var sid := "marea_stage_%d" % s_num
        var cleared := SaveManager.is_stage_completed(sid)
        var btn := Button.new()
        btn.text = ("%s ✓" % stage_titles[i]) if cleared else stage_titles[i]
        btn.custom_minimum_size = Vector2(210, 32)
        if sid == stage_id:
            btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
        elif cleared:
            btn.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
        btn.pressed.connect(func() -> void:
            AudioManager.play_sfx("ui_click", -8.0)
            _populate_marea_stage_briefing(sid)
        )
        _stage_selector_row.add_child(btn)

    var cur_num := int(stage_id.get_slice("_", 2))
    var act_str := "ACT I" if cur_num <= 4 else ("ACT II" if cur_num <= 8 else "ACT III")

    var art_path := "res://assets/briefings/marea_act1.png"
    if cur_num == 3:
        art_path = "res://assets/briefings/marea_maelstrom.png"
    elif cur_num == 5:
        art_path = "res://assets/briefings/marea_soberano.png"
    elif cur_num >= 8:
        art_path = "res://assets/briefings/marea_act3.png"
    elif cur_num >= 4:
        art_path = "res://assets/briefings/marea_act2.png"
    var art_tex: Texture2D = load(art_path)
    if art_tex == null:
        art_tex = load("res://assets/factions/card_marea.png")
    _briefing_art_rect.texture = art_tex

    _commander_portrait_rect.texture = load("res://assets/heroes/ace_solano.png")
    _commander_name_lbl.text = "CAPTAIN SOLANO"
    _commander_role_lbl.text = "Corsair Flagship // Viento Rojo" 

    match stage_id:
        "marea_stage_1":
            _briefing_title_lbl.text = "ACT III // STAGE 01 [TUTORIAL]: RUNNING THE BASALT NARROWS"
            _briefing_sub_lbl.text = "FACTION: THE FREE TIDE // CANYON GORGE RUN & BARLOVENTO TUTORIAL"
            _commander_quote_lbl.text = "\"Listen up, sea dogs! We're navigating the Basalt Narrows—a treacherous asteroid gorge where Acero pickets try to box us in. Ride the raging cyan rush of El Río del Viento, claim the Weather-Gauge [BARLOVENTO], and smash their blockade with crushing broadside volleys!\""
            _objectives_lbl.text = "◆ TUTORIAL DRILL 1 (THE BASALT NARROWS): Navigate the dense canyon gorge; don't collide with basalt spires.\n◆ TUTORIAL DRILL 2 (EL RÍO DEL VIENTO): Catch the high-velocity Éther stream for massive forward speed boosts.\n◆ TUTORIAL DRILL 3 (WEATHER-GAUGE [BARLOVENTO]): Attack from upwind for +12% Hit accuracy, unleashing +18% port/starboard broadsides.\n◆ PRIMARY OBJECTIVE: Break through the Acero blockade picket and secure the Corsair Haven.\n◆ SECONDARY OBJECTIVE: Keep Corsair Flagship Viento Rojo afloat."
            _add_squadron_row("marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 300 | RNG 50m | Quantum Sails & Broadsides")
            _add_squadron_row("marea_raider", "La Descarada", "Corsair Raider Galleon • Quartermaster Vael", "HP 210 | RNG 46m | Fast Broadside Raider")
            _add_squadron_row("marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH TUTORIAL STAGE 01"

        "marea_stage_2":
            _briefing_title_lbl.text = "ACT III // STAGE 02: RAID ON FOUNDRY COMPLEX VULCAN-3"
            _briefing_sub_lbl.text = "FACTION: THE FREE TIDE // INDUSTRIAL RAID & CHOKEPOINT AMBUSH"
            _commander_quote_lbl.text = "\"Well done through the narrows! Now we strike the Imperial heart. The Acero smelter refinery Vulcan-3 is pumping stolen Éther into heavy battlecruisers. Slip behind the smelter platforms, use the industrial pylons as cover against their long-range railguns, and board their supply silos!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Destroy the Acero defense garrison guarding Smelter Vulcan-3.\n◆ SECONDARY OBJECTIVE: Ensure Corsair Flagship Viento Rojo survives the raid.\n◆ TERRAIN ADVANTAGE: Industrial refinery gantries and slag funnels block direct railgun lines-of-fire."
            _add_squadron_row("marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 300 | RNG 50m | Quantum Sails & Broadsides")
            _add_squadron_row("marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            _add_squadron_row("marea_raider", "La Descarada", "Corsair Raider Galleon • Quartermaster Vael", "HP 210 | RNG 46m | Fast Broadside Raider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 02"

        "marea_stage_3":
            _briefing_title_lbl.text = "ACT III // STAGE 03: THE MAELSTROM OF BARLOVENTO"
            _briefing_sub_lbl.text = "FACTION: THE FREE TIDE // THE GREAT SOL CORONA & STORM SURFING"
            _commander_quote_lbl.text = "\"Look at the sky, corsairs! The Great Sol Corona is whipping the Éther into the mother of all storms—the Maelstrom of Barlovento! Unfurl every quantum sail! Catch the vortex, claim the Weather-Gauge, and blast them into cosmic dust!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Annihilate the Imperial Supreme Suppression Battlegroup.\n◆ SECONDARY OBJECTIVE: Ensure Flagship Viento Rojo survives the final storm engagement.\n◆ MAELSTROM WINDS: High-velocity orbital currents grant unmatched drift speed and maximum Barlovento broadside modifiers!"
            _add_squadron_row("marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 360 | RNG 50m | Quantum Sails & Heavy Broadsides")
            _add_squadron_row("marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            _add_squadron_row("marea_raider", "La Descarada", "Corsair Raider Galleon • Quartermaster Vael", "HP 210 | RNG 46m | Fast Broadside Raider")
            _add_squadron_row("marea_raider", "Viento Furioso", "Corsair Strike Raider • Bosun Drake", "HP 210 | RNG 46m | High-Velocity Skirmisher")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 03"

        "marea_stage_4", "marea_stage_5", "marea_stage_6", "marea_stage_7":
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_marina.png")
            _commander_name_lbl.text = "COMMODORE MARINA \"LA TORMENTA\""
            _commander_role_lbl.text = "Corsair Flotilla Commander // Tormenta Negra"
            _briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            _briefing_sub_lbl.text = "FACTION: THE FREE TIDE // CORSAIR GUERRILLA CAMPAIGN"
            _commander_quote_lbl.text = "\"Catch the wind and don't give the Armada an inch to aim! Slip through the reefs, unleash broadside chain-shot, and bleed their heavy lines dry!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Ambush and eliminate the imperial patrol vanguard.\n◆ SECONDARY OBJECTIVE: Keep all corsair vessels moving at high momentum to evade return broadsides.\n◆ SAIL TECHNIQUE: Quantum sails generate free momentum when running before the Éther gale."
            _add_squadron_row("marea_galleon", "Tormenta Negra", "Armored Void-Galleon • Cmdr. Marina", "HP 340 | RNG 52m | Heavy Broadside Batteries")
            _add_squadron_row("marea_frigate", "Sirena Libre", "Quantum Frigate • Capt. Moreau", "HP 220 | RNG 48m | High-Velocity Broadside Frigate")
            _add_squadron_row("marea_cutter", "Flecha Veloz", "Corsair Cutter • Bosun Drake", "HP 140 | RNG 40m | Agile Flank Skirmisher")
            _add_squadron_row("marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "marea_stage_8", "marea_stage_9", "marea_stage_10", "marea_stage_11":
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_marina.png")
            _commander_name_lbl.text = "COMMODORE MARINA & CAPTAIN SOLANO"
            _commander_role_lbl.text = "United Corsair Fleet // Grand Armada"
            _briefing_title_lbl.text = "ACT III // STAGE %02d: %s" % [cur_num, stage_titles[cur_num - 1]]
            _briefing_sub_lbl.text = "FACTION: THE FREE TIDE // ASSAULT ON THE IMPERIAL REDOUBTS"
            _commander_quote_lbl.text = "\"Every free captain in the Star Sea answers the call! We've brought the heavy Bombards and the dread Galleons. Shatter their sluices and drown their dreadnoughts in the gale!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Breach the imperial heavy citadel defense perimeter.\n◆ SECONDARY OBJECTIVE: Keep the siege bombard in position to dismantle enemy fortifications.\n◆ BOMBARD TACTICS: The Corsair Bombard launches devastating plasma mortars across the storm sea."
            _add_squadron_row("marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 360 | RNG 50m | Quantum Sails & Heavy Broadsides")
            _add_squadron_row("marea_bombard", "Voz del Trueno", "Heavy Corsair Bombard • Quartermaster Vael", "HP 290 | RNG 62m | Long-Range Plasma Siege Mortar")
            _add_squadron_row("marea_frigate", "Sirena Libre", "Quantum Frigate • Cmdr. Marina", "HP 220 | RNG 48m | Broadside Batteries")
            _add_squadron_row("marea_cutter", "Flecha Veloz", "Corsair Cutter • Bosun Drake", "HP 140 | RNG 40m | Fast Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "marea_stage_12":
            _commander_portrait_rect.texture = load("res://assets/heroes/ace_solano.png")
            _commander_name_lbl.text = "ADMIRAL OF THE FREE TIDE SOLANO"
            _commander_role_lbl.text = "Flagship Commander // The Void Leviathan"
            _briefing_title_lbl.text = "ACT III // STAGE 12: LIBERATION OF THE STAR SEA // THE FINAL GALE"
            _briefing_sub_lbl.text = "FACTION: THE FREE TIDE // THE FINAL BATTLE FOR THE WEATHER GAUGE"
            _commander_quote_lbl.text = "\"Brothers and sisters of the Free Tide! Beyond this fleet lies the eternal gale. The Armada has anchored their greatest iron titans to strangle the sea, but the wind cannot be chained! With the Void Leviathan leading the line, unfurl all quantum sails! Ride the apex storm and claim BARLOVENTO!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Annihilate the Supreme Imperial Flagship and liberate the Star Sea.\n◆ SECONDARY OBJECTIVE: Ensure Corsair Leviathan and Viento Rojo survive the final battle.\n◆ ULTIMATE CORSAIR POWER: The Void Leviathan brings 520 HP, 6-sail quantum rigging, and dual heavy bombard broadsides!"
            _add_squadron_row("marea_leviathan", "El Gran Leviatán", "Colossal Corsair Void Leviathan • Adm. Solano", "HP 520 | RNG 60m | 6-Sail Rigging, Dual Bombards & Broadsides")
            _add_squadron_row("marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Cmdr. Marina", "HP 360 | RNG 50m | Quantum Sails & Broadsides")
            _add_squadron_row("marea_bombard", "Voz del Trueno", "Heavy Corsair Bombard • Quartermaster Vael", "HP 290 | RNG 62m | Heavy Siege Mortar")
            _add_squadron_row("marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH FINAL STAGE 12"

        _:
            _briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            _briefing_sub_lbl.text = "FACTION: THE FREE TIDE // SECTOR %02d" % cur_num
            _commander_quote_lbl.text = "\"Unfurl sails, ride the current, and bring our broadsides to bear!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Defeat all hostile combatants in this sector.\n◆ SECONDARY OBJECTIVE: Protect the fleet and maintain high momentum."
            _add_squadron_row("marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 300 | RNG 50m | Quantum Sails & Broadsides")
            _add_squadron_row("marea_raider", "La Descarada", "Corsair Raider Galleon • Quartermaster Vael", "HP 210 | RNG 46m | Fast Broadside Raider")
            _add_squadron_row("marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

func _add_squadron_row(ship_id: String, unit_name: String, role_str: String, stats_str: String) -> void:
    var panel := PanelContainer.new()
    var st := StyleBoxFlat.new()
    st.bg_color = Color(0.03, 0.07, 0.14, 0.85)
    st.border_color = Color(0.25, 0.72, 0.95, 0.40)
    st.set_border_width_all(1)
    st.set_corner_radius_all(4)
    st.set_content_margin_all(6)
    panel.add_theme_stylebox_override("panel", st)

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 1)
    panel.add_child(vb)

    var rank := SaveManager.get_veteran_rank(ship_id)
    var vet_str := ("  [★ %s +%d%% HP]" % [SaveManager.get_veteran_title(rank).to_upper(), rank * 6]) if rank > 0 else ""

    var l1 := Label.new()
    l1.text = "◆ %s — %s%s" % [unit_name, role_str, vet_str]
    l1.add_theme_font_size_override("font_size", 11)
    l1.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55) if rank > 0 else Color.WHITE)
    vb.add_child(l1)

    var l2 := Label.new()
    l2.text = "   " + stats_str
    l2.add_theme_font_size_override("font_size", 10)
    l2.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
    vb.add_child(l2)

    _squadron_vbox.add_child(panel)

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
