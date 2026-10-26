extends CanvasLayer

signal transition_finished

# -----------------------------------------------------------------------------
# SCENE TRANSITION & FACTION LOADING SPLASH SYSTEM
# -----------------------------------------------------------------------------

const DEFAULT_SPLASH := "res://assets/splash/cover.png"

var _faction_splashes: Dictionary = {
	"acero": [
		"res://assets/splash/loading_acero_1.png",
		"res://assets/splash/loading_acero_2.png",
		"res://assets/factions/card_acero.png",
		"res://assets/briefings/acero_forge.png",
		"res://assets/briefings/acero_dam.png",
	],
	"vinculados": [
		"res://assets/splash/loading_vinculados_1.png",
		"res://assets/splash/loading_vinculados_2.png",
		"res://assets/factions/card_vinculados.png",
		"res://assets/briefings/vinculados_genesis.png",
		"res://assets/ships/vinculados/mobile_armor_colossus.png",
	],
	"marea_libre": [
		"res://assets/splash/loading_marea_1.png",
		"res://assets/splash/loading_marea_2.png",
		"res://assets/factions/card_marea.png",
		"res://assets/briefings/marea_maelstrom.png",
	]
}

var _faction_lore_tips: Dictionary = {
	"acero": [
		"\"Mass cannot be reasoned with; it can only be countered with greater thrust.\" — Adm. Vane",
		"Tactical Tip: In the Admiral Phase, heavy dreadnoughts take several turns to halt. Plan decelerations early.",
		"\"The Sluice Walls will hold. Even the Calm cannot extinguish industrial will.\" — Grand Marshall Kurtz",
		"Tactical Tip: Angle your bow directly toward hostile fire. Acero bow armor absorbs up to 45% more kinetic shock.",
		"\"Steel endures where fragile souls fracture. Prime spinal batteries.\" — Capt. Korr",
		"Tactical Tip: Torpedo autoloader magazines reload between combat phases. Maintain standoff distance while firing salvos.",
	],
	"vinculados": [
		"\"The void is not an empty desert; it is our second nervous system.\" — Conductor Seraph-2",
		"Tactical Tip: Mobile Suit platoons boast minimal inertia. Use Snap-Pivot to orient beam lances without losing vector.",
		"\"Resonance is truth. When the Mind Core awakens, distance becomes an illusion.\" — Ace Kaelen-7",
		"Tactical Tip: Soul Barrier shields recover instantly when riding directly windward through Éteron currents.",
		"\"Every death in the Star Sea is merely a frequency returning to the great harmonic chord.\" — Ace Mirei-4",
		"Tactical Tip: Fin Funnel remote arrays pierce directional armor by attacking from unshielded rear arcs.",
	],
	"marea_libre": [
		"\"A dead wind blows for no one. Fill your sails while the Éther still breathes.\" — Commodore Marina",
		"Tactical Tip: Corsair void-galleons surf crosswinds for +25% speed. Use the weather-gauge to dictate range.",
		"\"The Empire calls it theft; we call it returning the sky to those who dare sail it.\" — Capt. Solano",
		"Tactical Tip: Boarding harpoons lock enemy capital ships into close-quarters broadside duels and drain their AP.",
		"\"Never fight a dreadnought bow-to-bow. Drop into their stern wake and loose double-shot carronades.\" — Capt. Moreau",
		"Tactical Tip: Chain shot slows down fleeing vessels, allowing lighter frigates to encircle capital targets.",
	]
}

var _root_control: Control
var _bg_texture_rect: TextureRect
var _vignette_rect: ColorRect
var _card_panel: PanelContainer
var _faction_badge_lbl: Label
var _tip_lbl: Label
var _status_lbl: Label
var _progress_bar: ProgressBar
var _scanline_effect: ColorRect

var _is_loading: bool = false
var _target_scene_path: String = ""
var _load_progress: Array = []
var _min_display_time: float = 1.1
var _elapsed_display_time: float = 0.0
var _anim_phase: float = 0.0

func _ready() -> void:
	layer = 100
	_build_ui()

func _process(delta: float) -> void:
	if not _is_loading:
		return

	_anim_phase += delta * 4.0
	_elapsed_display_time += delta

	# Animate status readout dots
	var dots := "..."
	var dot_count := (int(_anim_phase) % 4)
	dots = ".".repeat(dot_count)
	if _status_lbl != null:
		var pct := int(_progress_bar.value) if _progress_bar != null else 50
		_status_lbl.text = "ENGAGING ÉTHER STREAM // LOADING SECTOR TELEMETRY %s %d%%" % [dots, pct]

	# Poll ResourceLoader
	var status := ResourceLoader.load_threaded_get_status(_target_scene_path, _load_progress)
	var prog_val: float = 0.0
	if not _load_progress.is_empty():
		prog_val = float(_load_progress[0]) * 100.0

	if _progress_bar != null:
		_progress_bar.value = maxf(_progress_bar.value, prog_val)

	if status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed_display_time >= _min_display_time:
		_finalize_load()
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_fallback_direct_load()

func load_scene(scene_path: String, faction: String = "") -> void:
	if _is_loading:
		return

	if faction.is_empty():
		faction = LoreDB.selected_faction if LoreDB != null else "acero"
	if faction.is_empty():
		faction = "acero"

	_target_scene_path = scene_path
	_is_loading = true
	_elapsed_display_time = 0.0
	_anim_phase = 0.0

	# 1. Select Splash Image
	var splash_path := _pick_random_splash(faction)
	_apply_splash_texture(splash_path)

	# 2. Select Faction Lore Tip
	_apply_lore_tip(faction)

	if _progress_bar != null:
		_progress_bar.value = 5.0

	# 3. Fade In Loading Screen
	_root_control.visible = true
	_root_control.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root_control, "modulate:a", 1.0, 0.35)

	# 4. Initiate Threaded Load
	ResourceLoader.load_threaded_request(scene_path)

func _finalize_load() -> void:
	_is_loading = false
	var res := ResourceLoader.load_threaded_get(_target_scene_path)
	if res is PackedScene:
		get_tree().change_scene_to_packed(res)
	else:
		get_tree().change_scene_to_file(_target_scene_path)

	# Smooth Fade Out
	var tween := create_tween()
	tween.tween_property(_root_control, "modulate:a", 0.0, 0.40)
	tween.tween_callback(func() -> void:
		_root_control.visible = false
		transition_finished.emit()
	)

func _fallback_direct_load() -> void:
	_is_loading = false
	get_tree().change_scene_to_file(_target_scene_path)
	var tween := create_tween()
	tween.tween_property(_root_control, "modulate:a", 0.0, 0.30)
	tween.tween_callback(func() -> void:
		_root_control.visible = false
		transition_finished.emit()
	)

func _pick_random_splash(faction: String) -> String:
	var list: Array = _faction_splashes.get(faction, [])
	var valid_candidates: Array[String] = []

	for p in list:
		if ResourceLoader.exists(str(p)):
			valid_candidates.append(str(p))

	if not valid_candidates.is_empty():
		valid_candidates.shuffle()
		return valid_candidates[0]

	return DEFAULT_SPLASH

func _apply_splash_texture(path: String) -> void:
	if _bg_texture_rect == null:
		return
	if ResourceLoader.exists(path):
		_bg_texture_rect.texture = load(path)
	elif ResourceLoader.exists(DEFAULT_SPLASH):
		_bg_texture_rect.texture = load(DEFAULT_SPLASH)

func _apply_lore_tip(faction: String) -> void:
	var tips: Array = _faction_lore_tips.get(faction, [])
	var chosen_tip := "Naval space combat rewards vector anticipation and directional armor positioning."
	if not tips.is_empty():
		tips.shuffle()
		chosen_tip = str(tips[0])

	if _tip_lbl != null:
		_tip_lbl.text = chosen_tip

	if _faction_badge_lbl != null:
		match faction:
			"acero":
				_faction_badge_lbl.text = "THE ARMADA OF ACERO // NAVAL SUPREMACY"
				_faction_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.22))
			"vinculados":
				_faction_badge_lbl.text = "THE VINCULADOS // HARMONIC CONSCIOUSNESS"
				_faction_badge_lbl.add_theme_color_override("font_color", Color(0.40, 0.92, 1.0))
			"marea_libre":
				_faction_badge_lbl.text = "THE FREE TIDE // CORSAIRS OF THE STAR SEA"
				_faction_badge_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.75))
			_:
				_faction_badge_lbl.text = "BARLOVENTO: EL ÚLTIMO VIENTO"
				_faction_badge_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))

func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root_control.visible = false
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root_control)

	# 1. Fullscreen Splash Artwork
	_bg_texture_rect = TextureRect.new()
	_bg_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_root_control.add_child(_bg_texture_rect)

	# 2. Cinematic Vignette & Deep Chiaroscuro Overlay
	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.color = Color(0.015, 0.035, 0.065, 0.45)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(_vignette_rect)

	# 3. Top Banner
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 32
	top_panel.offset_right = -32
	top_panel.offset_top = 24
	top_panel.offset_bottom = 60
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.02, 0.05, 0.09, 0.80)
	top_style.border_color = Color(0.25, 0.65, 0.85, 0.40)
	top_style.set_border_width_all(1)
	top_style.set_corner_radius_all(4)
	top_panel.add_theme_stylebox_override("panel", top_style)
	_root_control.add_child(top_panel)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 16)
	top_margin.add_theme_constant_override("margin_right", 16)
	top_panel.add_child(top_margin)

	var top_hbox := HBoxContainer.new()
	top_margin.add_child(top_hbox)

	var top_title := Label.new()
	top_title.text = "BARLOVENTO // STELLAR FLEET LOGISTICS"
	top_title.add_theme_font_size_override("font_size", 12)
	top_title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	top_hbox.add_child(top_title)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(top_spacer)

	_faction_badge_lbl = Label.new()
	_faction_badge_lbl.text = "FACTION DEPLOYMENT"
	_faction_badge_lbl.add_theme_font_size_override("font_size", 11)
	top_hbox.add_child(_faction_badge_lbl)

	# 4. Bottom Tactical Card & Progress HUD
	_card_panel = PanelContainer.new()
	_card_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_card_panel.offset_left = 32
	_card_panel.offset_right = -32
	_card_panel.offset_top = -140
	_card_panel.offset_bottom = -28
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.015, 0.035, 0.065, 0.90)
	card_style.border_color = Color(0.30, 0.70, 0.90, 0.55)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	_card_panel.add_theme_stylebox_override("panel", card_style)
	_root_control.add_child(_card_panel)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 24)
	card_margin.add_theme_constant_override("margin_right", 24)
	card_margin.add_theme_constant_override("margin_top", 14)
	card_margin.add_theme_constant_override("margin_bottom", 14)
	_card_panel.add_child(card_margin)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 8)
	card_margin.add_child(card_vbox)

	_tip_lbl = Label.new()
	_tip_lbl.text = "Tactical Tip / Lore Quote"
	_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_lbl.add_theme_font_size_override("font_size", 12)
	_tip_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	card_vbox.add_child(_tip_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 10)
	_progress_bar.show_percentage = false
	var p_bg := StyleBoxFlat.new()
	p_bg.bg_color = Color(0.05, 0.12, 0.18, 0.85)
	p_bg.set_corner_radius_all(3)
	var p_fill := StyleBoxFlat.new()
	p_fill.bg_color = Color(0.25, 0.85, 1.0)
	p_fill.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("background", p_bg)
	_progress_bar.add_theme_stylebox_override("fill", p_fill)
	card_vbox.add_child(_progress_bar)

	_status_lbl = Label.new()
	_status_lbl.text = "ENGAGING ÉTHER STREAM // LOADING SECTOR TELEMETRY..."
	_status_lbl.add_theme_font_size_override("font_size", 10)
	_status_lbl.add_theme_color_override("font_color", Color(0.40, 0.88, 1.0))
	card_vbox.add_child(_status_lbl)
