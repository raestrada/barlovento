class_name AcePanel
extends Control

signal execute_round_pressed
signal cycle_target_pressed
signal stance_changed(new_stance: Ship.Stance)
signal exit_pressed
signal intercept_pressed
signal ability_used(ability_name: String)
signal ability_toggled(ability_name: String, is_active: bool)
signal reset_ap_pressed
signal ship_selected(ship: Ship)
signal enemy_selected(enemy: Ship)

signal yaw_left
signal yaw_right
signal pitch_up
signal pitch_down
signal speed_up
signal toggle_weapon_arcs_pressed
signal toggle_auto_pilot_pressed
signal speed_down
signal stop_pressed

var ship: Ship:
    set(value):
        ship = value
        if _armor_widget != null:
            _armor_widget.ship = value
        _update_ability_deck_for_ship()
        refresh()

var target: Ship:
    set(value):
        target = value
        refresh()

var player_ships: Array[Ship] = []
var enemy_ships: Array[Ship] = []
var _portrait_cache: Dictionary = {}

var _armor_widget: HudWidgets.DirectionalArmorWidget
var _ap_bar: HudWidgets.ActionPointBar
var _unit_tabs_hbox: HBoxContainer
var _enemy_tabs_hbox: HBoxContainer
var _ally_portrait_rect: TextureRect
var _ally_pilot_label: Label
var _ally_ship_label: Label
var _ally_hp_label: Label
var _enemy_portrait_rect: TextureRect
var _enemy_pilot_label: Label
var _enemy_ship_label: Label
var _enemy_hp_label: Label
var _target_status_label: Label
var _telemetry_label: Label
var _calm_status_label: Label

var _pill_buttons: Array[Button] = []
var _btn_reset_ap: Button
var _btn_resolve: Button
var _arcs_btn: Button
var _auto_btn: Button
var _turbo_btn: Button

# Faction-Tailored 5-Slot Per-Ship Ability Decks (with explicit AP cost, 1-Round duration & effect tags)
var _faction_ability_defs: Dictionary = {
    "acero": [
        {"id": "prow_angle", "slot": 1, "label": "[1] PROW ANGLE [1 AP]", "sub": "+45% Bow Armor · 1 Rnd", "cost": 1, "desc": "Angle heavy bow armor toward target (+45% frontal absorption for 1 full round). Click again to refund."},
        {"id": "flak_screen", "slot": 2, "label": "[2] FLAK SCREEN [1 AP]", "sub": "-25% Enemy Hit · 1 Rnd", "cost": 1, "desc": "Point-defense flak curtain (-25% enemy incoming hit chance for 1 full round). Click again to refund."},
        {"id": "broadside", "slot": 3, "label": "[3] BROADSIDE [2 AP]", "sub": "+45% DMG · +30% Hit · 1R", "cost": 2, "desc": "Lock port/starboard heavy batteries (+45% salvo damage & +30% hit for 1 full round). Combo with [1] or [4]!"},
        {"id": "furnace_burn", "slot": 4, "label": "[4] FURNACE [1 AP]", "sub": "+4.5m/s Surge · 1 Rnd", "cost": 1, "desc": "Emergency furnace thrust (+4.5 m/s speed surge for 1 round). Combo with [3] for Overdrive Salvo!"},
        {"id": "shield_pulse", "slot": 5, "label": "[5] BULKHEADS [2 AP]", "sub": "+40 Shield / +20 Hull", "cost": 2, "desc": "Reinforce armored bulkheads (+40 Shield & +20 Hull immediately; refundable before [SPACE])."}
    ],
    "vinculados": [
        {"id": "snap_pivot", "slot": 1, "label": "[1] SNAP-PIVOT [1 AP]", "sub": "Lock Target Arc · 1 Rnd", "cost": 1, "desc": "Instant vernier torso pivot toward target without altering drift. Combo with [3] for Newtype Blitz!"},
        {"id": "soul_lock", "slot": 2, "label": "[2] SOUL LOCK [1 AP]", "sub": "+30% Hit · +25% Crit · 1R", "cost": 1, "desc": "Neural harmonic lock (+30% accuracy & +25% crit chance for all weapons this round)."},
        {"id": "beam_lance", "slot": 3, "label": "[3] BEAM LANCE [2 AP]", "sub": "+40% DMG · Pierce 65%", "cost": 2, "desc": "Resonance particle lance (+40% damage, pierces 65% target armor for 1 full round)."},
        {"id": "phase_dodge", "slot": 4, "label": "[4] PHASE DODGE [1 AP]", "sub": "+35% Evasion · 1 Rnd", "cost": 1, "desc": "High-G vector dodge (+35% evasion against all incoming fire for 1 full round)."},
        {"id": "shield_pulse", "slot": 5, "label": "[5] I-FIELD [2 AP]", "sub": "+40 Shield / +20 Hull", "cost": 2, "desc": "Harmonic I-Field barrier overcharge (+40 Shield & +20 Hull immediately; refundable before [SPACE])."}
    ],
    "marea_libre": [
        {"id": "trim_sails", "slot": 1, "label": "[1] TRIM SAILS [1 AP]", "sub": "+3.5m/s Wind · 1 Rnd", "cost": 1, "desc": "Catch the Éther wind (+3.5 m/s speed along wind gradient). Combo with [3] for Boarding Surge!"},
        {"id": "oar_sweep", "slot": 2, "label": "[2] OAR SWEEP [1 AP]", "sub": "45° Broadside · 1 Rnd", "cost": 1, "desc": "Flank oars sweep (sharp 45° hull pivot for broadside alignment). Combo with [3] or [4]!"},
        {"id": "chain_shot", "slot": 3, "label": "[3] CHAIN-SHOT [2 AP]", "sub": "+35% DMG · Slow 45%", "cost": 2, "desc": "Plasma chain-shot (+35% damage & cuts target speed by 45% for 1 full round)."},
        {"id": "harpoon", "slot": 4, "label": "[4] HARPOON [1 AP]", "sub": "+30% Hit · Grapple 1R", "cost": 1, "desc": "Boarding grapple (+30% accuracy & intercept vector lock on target for 1 full round)."},
        {"id": "shield_pulse", "slot": 5, "label": "[5] PLATING [2 AP]", "sub": "+40 Shield / +20 Hull", "cost": 2, "desc": "Timber & brass emergency repair (+40 Shield & +20 Hull immediately; refundable before [SPACE])."}
    ]
}

var _current_deck: Array = []
var _strategic_bonus_ap: int = 0

func set_strategic_bonus_ap(extra_ap: int) -> void:
    _strategic_bonus_ap = maxi(extra_ap, 0)
    for p in player_ships:
        if p != null and is_instance_valid(p):
            p.max_action_points = 6
            p.action_points = clampi(4 + _strategic_bonus_ap, 0, p.max_action_points)
    refresh()

func _get_portrait(ship_id: String) -> Texture2D:
    var path := LoreDB.get_portrait_for_ship(ship_id)
    if path == "":
        return null
    if not _portrait_cache.has(path):
        if ResourceLoader.exists(path):
            _portrait_cache[path] = load(path)
        else:
            _portrait_cache[path] = null
    return _portrait_cache[path]

func _ready() -> void:
    custom_minimum_size = Vector2(0, 205)
    mouse_filter = Control.MOUSE_FILTER_PASS
    _build_ui()
    _update_ability_deck_for_ship()

func _unhandled_input(event: InputEvent) -> void:
    if not is_visible_in_tree() or TurnManager.is_resolving():
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1:
                toggle_ability_by_slot(0)
            KEY_2:
                toggle_ability_by_slot(1)
            KEY_3:
                toggle_ability_by_slot(2)
            KEY_4:
                toggle_ability_by_slot(3)
            KEY_5:
                toggle_ability_by_slot(4)
            KEY_Z:
                reset_all_ap()
            KEY_U:
                toggle_auto_pilot_pressed.emit()
            KEY_TAB:
                _toggle_turbo()

func _build_ui() -> void:
    # 1. BOTTOM-LEFT: YOUR SQUADRON (ALLIED ACES)
    var left_vbox := VBoxContainer.new()
    left_vbox.add_theme_constant_override("separation", 3)
    left_vbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    left_vbox.position = Vector2(10, -186)
    left_vbox.custom_minimum_size = Vector2(214, 0)
    add_child(left_vbox)

    var ally_header := Label.new()
    ally_header.text = "★ YOUR SQUADRON // ALLIED ACES"
    ally_header.add_theme_font_size_override("font_size", 9)
    ally_header.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
    left_vbox.add_child(ally_header)

    var ally_tabs_scroll := ScrollContainer.new()
    ally_tabs_scroll.custom_minimum_size = Vector2(214, 24)
    ally_tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    ally_tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    left_vbox.add_child(ally_tabs_scroll)

    _unit_tabs_hbox = HBoxContainer.new()
    _unit_tabs_hbox.add_theme_constant_override("separation", 4)
    ally_tabs_scroll.add_child(_unit_tabs_hbox)

    var left_row := HBoxContainer.new()
    left_row.add_theme_constant_override("separation", 4)
    left_vbox.add_child(left_row)

    var ally_card := PanelContainer.new()
    var ally_style := StyleBoxFlat.new()
    ally_style.bg_color = Color(0.02, 0.08, 0.13, 0.92)
    ally_style.border_color = HudWidgets.COL_GREEN
    ally_style.set_border_width_all(1)
    ally_style.set_corner_radius_all(5)
    ally_style.set_content_margin_all(5)
    ally_card.add_theme_stylebox_override("panel", ally_style)
    left_row.add_child(ally_card)

    var ally_card_vbox := VBoxContainer.new()
    ally_card_vbox.add_theme_constant_override("separation", 2)
    ally_card.add_child(ally_card_vbox)

    _ally_portrait_rect = TextureRect.new()
    _ally_portrait_rect.custom_minimum_size = Vector2(58, 58)
    _ally_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _ally_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    ally_card_vbox.add_child(_ally_portrait_rect)

    _ally_pilot_label = Label.new()
    _ally_pilot_label.add_theme_font_size_override("font_size", 9)
    _ally_pilot_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
    ally_card_vbox.add_child(_ally_pilot_label)

    _ally_ship_label = Label.new()
    _ally_ship_label.add_theme_font_size_override("font_size", 8)
    _ally_ship_label.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
    ally_card_vbox.add_child(_ally_ship_label)

    _ally_hp_label = Label.new()
    _ally_hp_label.add_theme_font_size_override("font_size", 8)
    _ally_hp_label.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
    ally_card_vbox.add_child(_ally_hp_label)

    _armor_widget = HudWidgets.DirectionalArmorWidget.new()
    left_row.add_child(_armor_widget)

    # 2. BOTTOM-CENTER: Action Points & Ability Pill Dock
    var center_wrapper := VBoxContainer.new()
    center_wrapper.add_theme_constant_override("separation", 3)
    add_child(center_wrapper)
    center_wrapper.anchor_left = 0.5
    center_wrapper.anchor_right = 0.5
    center_wrapper.anchor_top = 1.0
    center_wrapper.anchor_bottom = 1.0
    center_wrapper.offset_left = -465
    center_wrapper.offset_right = 465
    center_wrapper.offset_top = -172
    center_wrapper.offset_bottom = -6

    # Micro Helm & Target Telemetry Bar
    var helm_row := HBoxContainer.new()
    helm_row.add_theme_constant_override("separation", 3)
    helm_row.alignment = BoxContainer.ALIGNMENT_CENTER
    center_wrapper.add_child(helm_row)

    helm_row.add_child(_make_helm_btn("◀PORT[A]", func() -> void: yaw_left.emit()))
    helm_row.add_child(_make_helm_btn("STBD[D]▶", func() -> void: yaw_right.emit()))
    helm_row.add_child(_make_helm_btn("▲CLIMB[Q]", func() -> void: pitch_up.emit()))
    helm_row.add_child(_make_helm_btn("▼DIVE[E]", func() -> void: pitch_down.emit()))
    helm_row.add_child(_make_helm_btn("-SPD[S]", func() -> void: speed_down.emit()))
    helm_row.add_child(_make_helm_btn("+SPD[W]", func() -> void: speed_up.emit()))
    helm_row.add_child(_make_helm_btn("TGT[C]", func() -> void: cycle_target_pressed.emit()))
    _auto_btn = _make_helm_btn("🤖AUTO[U]:OFF", func() -> void: toggle_auto_pilot_pressed.emit())
    _auto_btn.custom_minimum_size = Vector2(76, 20)
    helm_row.add_child(_auto_btn)
    _arcs_btn = _make_helm_btn("🎯ARCS[Y]", func() -> void: toggle_weapon_arcs())
    helm_row.add_child(_arcs_btn)
    _turbo_btn = _make_helm_btn("⚡TURBO[TAB]", func() -> void: _toggle_turbo())
    helm_row.add_child(_turbo_btn)
    helm_row.add_child(_make_helm_btn("🗺CHART", func() -> void: exit_pressed.emit()))

    # Target Solution & Telemetry Line
    var status_row := HBoxContainer.new()
    status_row.add_theme_constant_override("separation", 8)
    status_row.alignment = BoxContainer.ALIGNMENT_CENTER
    center_wrapper.add_child(status_row)

    _telemetry_label = Label.new()
    _telemetry_label.custom_minimum_size = Vector2(230, 16)
    _telemetry_label.clip_text = true
    _telemetry_label.add_theme_font_size_override("font_size", 10)
    _telemetry_label.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
    status_row.add_child(_telemetry_label)

    _target_status_label = Label.new()
    _target_status_label.custom_minimum_size = Vector2(400, 16)
    _target_status_label.clip_text = true
    _target_status_label.add_theme_font_size_override("font_size", 10)
    status_row.add_child(_target_status_label)

    _calm_status_label = Label.new()
    _calm_status_label.custom_minimum_size = Vector2(130, 16)
    _calm_status_label.clip_text = true
    _calm_status_label.add_theme_font_size_override("font_size", 10)
    _calm_status_label.add_theme_color_override("font_color", Color(0.85, 0.40, 0.95))
    status_row.add_child(_calm_status_label)

    # Main Chamfered AP & Ability Pill Dock
    var ap_dock := PanelContainer.new()
    var dock_style := StyleBoxFlat.new()
    dock_style.bg_color = Color(0.018, 0.055, 0.10, 0.92)
    dock_style.border_color = Color(0.25, 0.82, 0.98, 0.75)
    dock_style.set_border_width_all(1)
    dock_style.set_corner_radius_all(8)
    dock_style.content_margin_left = 14
    dock_style.content_margin_right = 14
    dock_style.content_margin_top = 8
    dock_style.content_margin_bottom = 8
    ap_dock.add_theme_stylebox_override("panel", dock_style)
    center_wrapper.add_child(ap_dock)

    var dock_vbox := VBoxContainer.new()
    dock_vbox.add_theme_constant_override("separation", 8)
    ap_dock.add_child(dock_vbox)

    # Row 1 inside Dock: Action Point Bar
    _ap_bar = HudWidgets.ActionPointBar.new()
    dock_vbox.add_child(_ap_bar)

    # Row 2 inside Dock: 5 Ability Buttons + Reset Pill + Resolve Turn Pill
    var pills_row := HBoxContainer.new()
    pills_row.add_theme_constant_override("separation", 6)
    pills_row.alignment = BoxContainer.ALIGNMENT_CENTER
    dock_vbox.add_child(pills_row)

    _pill_buttons.clear()
    for slot_idx in range(5):
        var btn := _make_pill_btn("ABILITY", false, func() -> void:
            toggle_ability_by_slot(slot_idx)
        )
        pills_row.add_child(btn)
        _pill_buttons.append(btn)

    _btn_reset_ap = _make_pill_btn("↺ RESET\n[Z] REFUND", false, func() -> void:
        reset_all_ap()
    )
    _btn_reset_ap.custom_minimum_size = Vector2(92, 48)
    _btn_reset_ap.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
    pills_row.add_child(_btn_reset_ap)

    _btn_resolve = _make_pill_btn("▶ RESOLVE\nFASE [SPACE]", true, func() -> void:
        _on_resolve_pressed()
    )
    _btn_resolve.custom_minimum_size = Vector2(118, 48)
    _btn_resolve.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
    pills_row.add_child(_btn_resolve)

    # 3. BOTTOM-RIGHT: HOSTILE FLEET (ENEMY COMMANDERS)
    var right_vbox := VBoxContainer.new()
    right_vbox.add_theme_constant_override("separation", 3)
    right_vbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    right_vbox.position = Vector2(-218, -186)
    right_vbox.custom_minimum_size = Vector2(208, 0)
    add_child(right_vbox)

    var enemy_header := Label.new()
    enemy_header.text = "⚔ HOSTILE FLEET // ENEMY ACES"
    enemy_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    enemy_header.add_theme_font_size_override("font_size", 9)
    enemy_header.add_theme_color_override("font_color", Color(1.0, 0.45, 0.32))
    right_vbox.add_child(enemy_header)

    var enemy_tabs_scroll := ScrollContainer.new()
    enemy_tabs_scroll.custom_minimum_size = Vector2(208, 24)
    enemy_tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    enemy_tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    right_vbox.add_child(enemy_tabs_scroll)

    _enemy_tabs_hbox = HBoxContainer.new()
    _enemy_tabs_hbox.alignment = BoxContainer.ALIGNMENT_END
    _enemy_tabs_hbox.add_theme_constant_override("separation", 4)
    enemy_tabs_scroll.add_child(_enemy_tabs_hbox)

    var enemy_card := PanelContainer.new()
    var enemy_style := StyleBoxFlat.new()
    enemy_style.bg_color = Color(0.11, 0.03, 0.04, 0.92)
    enemy_style.border_color = Color(1.0, 0.40, 0.25, 0.85)
    enemy_style.set_border_width_all(1)
    enemy_style.set_corner_radius_all(5)
    enemy_style.set_content_margin_all(6)
    enemy_card.add_theme_stylebox_override("panel", enemy_style)
    right_vbox.add_child(enemy_card)

    var enemy_card_hbox := HBoxContainer.new()
    enemy_card_hbox.add_theme_constant_override("separation", 8)
    enemy_card.add_child(enemy_card_hbox)

    _enemy_portrait_rect = TextureRect.new()
    _enemy_portrait_rect.custom_minimum_size = Vector2(58, 58)
    _enemy_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _enemy_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    enemy_card_hbox.add_child(_enemy_portrait_rect)

    var enemy_info_vbox := VBoxContainer.new()
    enemy_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    enemy_info_vbox.add_theme_constant_override("separation", 3)
    enemy_card_hbox.add_child(enemy_info_vbox)

    var lock_tag := Label.new()
    lock_tag.text = "⌖ LOCKED HOSTILE ACE [R-CLICK]"
    lock_tag.add_theme_font_size_override("font_size", 9)
    lock_tag.add_theme_color_override("font_color", Color(1.0, 0.45, 0.32))
    enemy_info_vbox.add_child(lock_tag)

    _enemy_pilot_label = Label.new()
    _enemy_pilot_label.add_theme_font_size_override("font_size", 12)
    _enemy_pilot_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.88))
    enemy_info_vbox.add_child(_enemy_pilot_label)

    _enemy_ship_label = Label.new()
    _enemy_ship_label.add_theme_font_size_override("font_size", 10)
    _enemy_ship_label.add_theme_color_override("font_color", HudWidgets.COL_AMBER)
    enemy_info_vbox.add_child(_enemy_ship_label)

    _enemy_hp_label = Label.new()
    _enemy_hp_label.add_theme_font_size_override("font_size", 10)
    _enemy_hp_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.42))
    enemy_info_vbox.add_child(_enemy_hp_label)

func _update_ability_deck_for_ship() -> void:
    var fac := "acero"
    if ship != null and is_instance_valid(ship):
        fac = ship.faction
    _current_deck = _faction_ability_defs.get(fac, _faction_ability_defs["acero"])
    _update_pill_buttons()

func toggle_ability_by_slot(slot_idx: int) -> void:
    if ship == null or not is_instance_valid(ship) or ship.is_destroyed():
        return
    if slot_idx < 0 or slot_idx >= _current_deck.size():
        return
    var ab: Dictionary = _current_deck[slot_idx]
    var aid: String = ab["id"]
    var slot_num: int = int(ab.get("slot", slot_idx + 1))
    var cost: int = int(ab["cost"])
    var is_on: bool = ship.is_ability_active(aid)
    if is_on:
        ship.set_ability_active(aid, false)
        ship.set_ability_active(slot_num, false)
        if not (DevManager.god_mode or DevManager.infinite_ap):
            ship.action_points = clampi(ship.action_points + cost, 0, ship.max_action_points)
        ability_toggled.emit(aid, false)
        AudioManager.play_sfx("ui_click", -10.0)
    else:
        if not (DevManager.god_mode or DevManager.infinite_ap) and ship.action_points < cost:
            AudioManager.play_sfx("error", -6.0)
            return
        ship.set_ability_active(aid, true)
        ship.set_ability_active(slot_num, true)
        if not (DevManager.god_mode or DevManager.infinite_ap):
            ship.action_points = maxi(ship.action_points - cost, 0)
        ability_toggled.emit(aid, true)
        AudioManager.play_sfx("ui_click", -6.0)
    _update_pill_buttons()
    refresh()

func toggle_ability(ab_id: String) -> void:
    for i in range(_current_deck.size()):
        if _current_deck[i]["id"] == ab_id:
            toggle_ability_by_slot(i)
            return

func reset_all_ap() -> void:
    if ship == null or not is_instance_valid(ship):
        return
    for ab in _current_deck:
        var aid: String = ab["id"]
        var slot_num: int = int(ab.get("slot", 1))
        if ship.is_ability_active(aid):
            var cost: int = int(ab["cost"])
            ship.set_ability_active(aid, false)
            ship.set_ability_active(slot_num, false)
            if not (DevManager.god_mode or DevManager.infinite_ap):
                ship.action_points = clampi(ship.action_points + cost, 0, ship.max_action_points)
            ability_toggled.emit(aid, false)
    reset_ap_pressed.emit()
    _update_pill_buttons()
    AudioManager.play_sfx("ui_click", -8.0)
    refresh()

func _on_resolve_pressed() -> void:
    # Keep per-ship active abilities active throughout the 2.2s round resolution!
    # They will be cleared and AP regenerated when ace_resolve_finished fires.
    execute_round_pressed.emit()

func _toggle_turbo() -> void:
    var is_turbo := TurnManager.toggle_turbo_mode()
    if _turbo_btn != null:
        _turbo_btn.text = "⚡ TURBO [TAB]: ON" if is_turbo else "⚡ TURBO [TAB]: OFF"
        _turbo_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25) if is_turbo else Color(0.70, 0.85, 0.95, 0.7))
    AudioManager.play_sfx("ui_click", -8.0)

func _update_pill_buttons() -> void:
    if _current_deck.is_empty():
        return
    for i in range(_pill_buttons.size()):
        var btn := _pill_buttons[i]
        if i < _current_deck.size():
            var ab: Dictionary = _current_deck[i]
            var aid: String = ab["id"]
            var cost: int = int(ab.get("cost", 1))
            var active: bool = ship.is_ability_active(aid) if (ship != null and is_instance_valid(ship)) else false
            var can_afford: bool = (ship != null and is_instance_valid(ship) and (ship.action_points >= cost or active or DevManager.god_mode or DevManager.infinite_ap))
            var raw_label: String = String(ab["label"])
            var line1: String = ("✔ " + raw_label) if active else raw_label
            var line2: String = String(ab.get("sub", ""))
            btn.text = "%s\n%s" % [line1, line2] if line2 != "" else line1
            btn.tooltip_text = "%s\nCoste: %d AP | Duración: 1 Ronda\n%s" % [raw_label, cost, String(ab["desc"])]
            _set_pill_style(btn, active, can_afford)
            btn.visible = true
        else:
            btn.visible = false

func _set_pill_style(btn: Button, active: bool, can_afford: bool = true) -> void:
    if btn == null:
        return
    var st := StyleBoxFlat.new()
    if active:
        st.bg_color = Color(0.12, 0.40, 0.54, 0.98)
        st.border_color = Color(1.0, 0.88, 0.32)
        st.set_border_width_all(2)
        btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45))
    elif can_afford:
        st.bg_color = Color(0.03, 0.11, 0.19, 0.92)
        st.border_color = Color(0.28, 0.78, 0.96, 0.85)
        st.set_border_width_all(1)
        btn.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
    else:
        st.bg_color = Color(0.02, 0.05, 0.09, 0.82)
        st.border_color = Color(0.35, 0.45, 0.55, 0.45)
        st.set_border_width_all(1)
        btn.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 0.65))

    st.set_corner_radius_all(6)
    st.set_content_margin_all(5)
    btn.add_theme_stylebox_override("normal", st)

    var st_hov := st.duplicate()
    st_hov.bg_color = Color(0.14, 0.46, 0.62, 0.98) if active else Color(0.08, 0.24, 0.38, 0.95)
    st_hov.border_color = Color(1.0, 0.95, 0.55) if active else HudWidgets.COL_CYAN_BRIGHT
    st_hov.set_border_width_all(2)
    btn.add_theme_stylebox_override("hover", st_hov)

func _format_ship_tab_text(idx: int, a: Ship, is_sel: bool) -> String:
    var short_pilot := a.pilot_name if a.pilot_name != "" else a.ship_name
    var auto_tag := " [IA]" if a.is_auto_pilot else ""
    var tags := a.get_active_ability_tags()
    var tag_suffix := (" " + "".join(tags)) if not tags.is_empty() else ""
    var prefix := "★" if is_sel else "▶"
    return "%s %d: %s [%dAP]%s%s" % [prefix, idx + 1, short_pilot, a.action_points, auto_tag, tag_suffix]

func set_fleet(allies: Array[Ship], selected: Ship, enemies: Array[Ship] = [], locked_enemy: Ship = null) -> void:
    player_ships = allies
    if not enemies.is_empty():
        enemy_ships = enemies
    if locked_enemy != null:
        target = locked_enemy
    ship = selected
    _update_ability_deck_for_ship()

    if _unit_tabs_hbox != null:
        for c in _unit_tabs_hbox.get_children():
            c.queue_free()
        for i in range(allies.size()):
            var a := allies[i]
            var b := Button.new()
            b.text = _format_ship_tab_text(i, a, a == selected)
            b.custom_minimum_size = Vector2(104, 24)
            b.add_theme_font_size_override("font_size", 9)
            b.focus_mode = Control.FOCUS_NONE
            if a.is_destroyed():
                b.disabled = true
                b.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
            elif a == selected:
                b.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
            else:
                b.add_theme_color_override("font_color", HudWidgets.COL_TEXT_MAIN)
            b.pressed.connect(func() -> void:
                if not a.is_destroyed():
                    ship_selected.emit(a)
            )
            _unit_tabs_hbox.add_child(b)

    if _enemy_tabs_hbox != null:
        for c in _enemy_tabs_hbox.get_children():
            c.queue_free()
        for i in range(enemy_ships.size()):
            var e := enemy_ships[i]
            var eb := Button.new()
            var short_enemy := e.pilot_name if e.pilot_name != "" else e.ship_name
            eb.text = "⚔ %s" % short_enemy
            eb.custom_minimum_size = Vector2(84, 22)
            eb.add_theme_font_size_override("font_size", 9)
            eb.focus_mode = Control.FOCUS_NONE
            if e.is_destroyed():
                eb.disabled = true
                eb.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
            elif e == target:
                eb.add_theme_color_override("font_color", Color(1.0, 0.45, 0.28))
            else:
                eb.add_theme_color_override("font_color", HudWidgets.COL_AMBER)
            eb.pressed.connect(func() -> void:
                if not e.is_destroyed():
                    enemy_selected.emit(e)
            )
            _enemy_tabs_hbox.add_child(eb)

func _process(_delta: float) -> void:
    refresh()
    if _armor_widget != null:
        _armor_widget.queue_redraw()
    if _ap_bar != null:
        _ap_bar.queue_redraw()

func refresh() -> void:
    if ship == null or not is_instance_valid(ship):
        return

    if _armor_widget != null:
        _armor_widget.ship = ship

    _update_pill_buttons()

    if _auto_btn != null:
        var is_auto := ship.is_auto_pilot
        _auto_btn.text = "🤖 AUTO [U]: ON" if is_auto else "🤖 AUTO [U]: OFF"
        var col := HudWidgets.COL_GREEN if is_auto else Color(0.70, 0.85, 0.95, 0.7)
        _auto_btn.add_theme_color_override("font_color", col)

    if _unit_tabs_hbox != null:
        var tabs := _unit_tabs_hbox.get_children()
        for i in range(mini(tabs.size(), player_ships.size())):
            var tb := tabs[i] as Button
            var a := player_ships[i]
            if tb != null and a != null and is_instance_valid(a):
                tb.text = _format_ship_tab_text(i, a, a == ship)
                if a.is_destroyed():
                    tb.disabled = true
                    tb.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.5))
                elif a == ship:
                    tb.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
                else:
                    tb.add_theme_color_override("font_color", HudWidgets.COL_TEXT_MAIN)

    if _ally_portrait_rect != null:
        _ally_portrait_rect.texture = _get_portrait(ship.ship_id)
    if _ally_pilot_label != null:
        _ally_pilot_label.text = ship.pilot_name if ship.pilot_name != "" else "ALLIED ACE"
    if _ally_ship_label != null:
        _ally_ship_label.text = "%s [%d/%d AP]" % [ship.ship_name, ship.action_points, ship.max_action_points]
    if _ally_hp_label != null:
        _ally_hp_label.text = "HULL %d%% | SHLD %d%%" % [ship.hull_pct(), ship.shield_pct()]

    if target != null and is_instance_valid(target):
        if _enemy_portrait_rect != null:
            _enemy_portrait_rect.texture = _get_portrait(target.ship_id)
        if _enemy_pilot_label != null:
            _enemy_pilot_label.text = target.pilot_name if target.pilot_name != "" else "HOSTILE ACE"
        if _enemy_ship_label != null:
            _enemy_ship_label.text = target.ship_name
        if _enemy_hp_label != null:
            if target.is_destroyed():
                _enemy_hp_label.text = "[ VESSEL DESTROYED ]"
            else:
                var quad := Combat.get_hit_quadrant(ship, target)
                _enemy_hp_label.text = "HULL %d%% | SHLD %d%%\nEXPOSED: %s ARMOR" % [target.hull_pct(), target.shield_pct(), quad]

    if _ap_bar != null:
        _ap_bar.current_ap = ship.action_points
        _ap_bar.max_ap = ship.max_action_points
        var short_s := ship.ship_name.to_upper()
        if short_s.length() > 11:
            short_s = short_s.substr(0, 11)
        _ap_bar.ship_label = "%s AP (%d/%d)" % [short_s, ship.action_points, ship.max_action_points]
        var regen_amt := ship.base_ap_regen + _strategic_bonus_ap
        _ap_bar.regen_text = "🔄 +%d AP/RND (MAX %d)" % [regen_amt, ship.max_action_points]
        var syn := ship.get_active_synergy()
        if bool(syn.get("active", false)):
            _ap_bar.synergy_text = "★ COMBO: %s" % String(syn.get("name", ""))
        else:
            var tags := ship.get_active_ability_tags()
            if not tags.is_empty():
                _ap_bar.synergy_text = "⏱ ACTIVE (1 RND): " + " ".join(tags)
            else:
                _ap_bar.synergy_text = "⏱ DURATION: 1 RND | Z=REFUND"
        _ap_bar.salvo_text = "%d/7" % TurnManager.ace_round
        _ap_bar.drift_text = "/ %.0f" % ship.speed()

    var yaw_deg := posmod(roundi(rad_to_deg(ship.order.yaw)), 360)
    var pitch_deg := roundi(rad_to_deg(ship.order.pitch))
    if _telemetry_label != null:
        _telemetry_label.text = "★ %s (%s) // SPD %.1f m/s | HDG %03d° | PITCH %+d°" % [
            ship.pilot_name.to_upper(), ship.ship_name.to_upper(), ship.speed(), yaw_deg, pitch_deg
        ]

    # Pre-Fire Predictive Firing Solution Badge with Live Ability & Synergy Delta
    if _target_status_label != null:
        if target == null or not is_instance_valid(target) or target.is_destroyed():
            _target_status_label.text = "⌖ NO TARGET [R-CLICK HOSTILE OR PRESS C]"
            _target_status_label.add_theme_color_override("font_color", HudWidgets.COL_TEXT_MUTED)
        else:
            var sol := Combat.predict_fire_solution(ship, target)
            var dist := ship.state.position.distance_to(target.state.position)
            var barlo_tag := " 🌬[BARLOVENTO]" if sol.get("weather_gauge", false) else ""
            var syn_name := String(sol.get("synergy_name", ""))
            var syn_tag := (" ★[%s]" % syn_name) if syn_name != "" else ""
            if sol.can_fire:
                var crit_tag := " 💥[STERN 1.4x]" if sol.critical else ""
                var base_d := float(sol.get("base_damage", sol.projected_damage))
                var proj_d := float(sol.projected_damage)
                var dmg_txt := "~%.0f" % proj_d
                if proj_d > base_d + 0.5:
                    dmg_txt = "%.0f→%.0f (+ABILITY)" % [base_d, proj_d]
                _target_status_label.text = "🎯 VS %s [%.0fm] // HIT: %d%%%s | %s%s | DMG: %s%s" % [
                    target.pilot_name.to_upper(), dist, roundi(sol.hit_chance * 100.0), barlo_tag, sol.quadrant, crit_tag, dmg_txt, syn_tag
                ]
                _target_status_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35) if syn_name != "" else HudWidgets.COL_GREEN)
            else:
                _target_status_label.text = "▲ VS %s [%.0fm] // %s%s%s" % [target.pilot_name.to_upper(), dist, sol.status_text, barlo_tag, syn_tag]
                _target_status_label.add_theme_color_override("font_color", HudWidgets.COL_AMBER if sol.in_range else HudWidgets.COL_RED)

func _make_pill_btn(txt: String, glowing: bool, cb: Callable) -> Button:
    var b := Button.new()
    b.text = txt
    b.custom_minimum_size = Vector2(124, 48)
    b.clip_text = false
    b.add_theme_font_size_override("font_size", 10)
    b.focus_mode = Control.FOCUS_NONE

    var st_norm := StyleBoxFlat.new()
    st_norm.bg_color = Color(0.08, 0.28, 0.40, 0.95) if glowing else Color(0.03, 0.11, 0.19, 0.92)
    st_norm.border_color = HudWidgets.COL_CYAN_BRIGHT if glowing else Color(0.28, 0.78, 0.96, 0.75)
    st_norm.set_border_width_all(2 if glowing else 1)
    st_norm.set_corner_radius_all(6)
    st_norm.set_content_margin_all(5)
    b.add_theme_stylebox_override("normal", st_norm)

    var st_hov := st_norm.duplicate()
    st_hov.bg_color = Color(0.12, 0.38, 0.54, 0.98)
    st_hov.border_color = HudWidgets.COL_CYAN_BRIGHT
    st_hov.set_border_width_all(2)
    b.add_theme_stylebox_override("hover", st_hov)

    b.pressed.connect(cb)
    return b

func _make_helm_btn(txt: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = txt
    b.custom_minimum_size = Vector2(58, 20)
    b.add_theme_font_size_override("font_size", 9)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(cb)
    return b

func toggle_weapon_arcs() -> void:
    Ship.show_weapon_arcs = not Ship.show_weapon_arcs
    if _arcs_btn != null:
        _arcs_btn.text = "🎯 ARCS [Y]: ON" if Ship.show_weapon_arcs else "🎯 ARCS [Y]: OFF"
        var col := HudWidgets.COL_CYAN_BRIGHT if Ship.show_weapon_arcs else Color(0.70, 0.85, 0.95, 0.7)
        _arcs_btn.add_theme_color_override("font_color", col)
    toggle_weapon_arcs_pressed.emit()

func set_calm_status(txt: String, is_hazard: bool) -> void:
    if _calm_status_label != null:
        _calm_status_label.text = txt
        var col := Color(1.0, 0.35, 0.45) if is_hazard else Color(0.85, 0.45, 0.95)
        _calm_status_label.add_theme_color_override("font_color", col)
