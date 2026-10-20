extends Control

const NEXT_SCENE_PATH := "res://scenes/menu/main_menu.tscn"
const LOGO_PATH := "res://assets/brand/logo.png"

# Cinematic Shot Timings (Total sequence: ~21 seconds)
const SHOT_1_END := 4.8    # The Star Sea & Cyan Éther
const SHOT_2_END := 9.8    # The Armada of Acero (Heavy Ironclads)
const SHOT_3_END := 14.8   # The Free Tide & Vinculados
const SEQUENCE_END := 21.0 # Grand Fleet Composition & Title Climax

var _bg_viewport: SubViewport
var _bg_cam: Camera3D
var _bg_backdrop: StarSeaBackdrop

var _time: float = 0.0
var _current_shot: int = 0
var _transitioning: bool = false

# UI Elements
var _letterbox_top: ColorRect
var _letterbox_bottom: ColorRect
var _narrative_box: VBoxContainer
var _eyebrow_lbl: Label
var _title_lbl: Label
var _sub_lbl: Label
var _title_reveal_box: VBoxContainer
var _logo_rect: TextureRect
var _tagline_lbl: Label
var _prompt_lbl: Label
var _skip_hint_lbl: Label
var _fade_rect: ColorRect

# Camera Waypoints for Spline Interpolation
var _cam_start_pos: Vector3
var _cam_end_pos: Vector3
var _look_start_pos: Vector3
var _look_end_pos: Vector3
var _shot_start_time: float = 0.0
var _shot_duration: float = 1.0

func _ready() -> void:
	_build_3d_cinematic_world()
	_build_cinematic_ui()

	AudioManager.play_menu_music(-8.0)
	AudioManager.start_ambient(-18.0)

	_start_shot(1)

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, 1.4)

func _build_3d_cinematic_world() -> void:
	# Deep background base
	var base := ColorRect.new()
	base.color = Color(0.005, 0.009, 0.018, 1.0)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)

	# 3D Viewport with 4x MSAA & Forward+ Renderer
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

	# In-engine StarSeaBackdrop with all diorama capital fleets and celestial forge-world
	_bg_backdrop = StarSeaBackdrop.new()
	_bg_backdrop.name = "StarSeaBackdrop"
	_bg_viewport.add_child(_bg_backdrop)
	_bg_backdrop.setup_environment(true)

	_bg_cam = Camera3D.new()
	_bg_cam.fov = 48.0
	_bg_cam.near = 0.15
	_bg_cam.far = 700.0
	_bg_viewport.add_child(_bg_cam)

func _build_cinematic_ui() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	# 1. Anamorphic Cinematic Letterboxing (2.39:1 widescreen aesthetic)
	_letterbox_top = ColorRect.new()
	_letterbox_top.color = Color(0.005, 0.007, 0.012, 1.0)
	_letterbox_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_letterbox_top.custom_minimum_size = Vector2(0, 58)
	hud.add_child(_letterbox_top)

	_letterbox_bottom = ColorRect.new()
	_letterbox_bottom.color = Color(0.005, 0.007, 0.012, 1.0)
	_letterbox_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_letterbox_bottom.offset_top = -68
	_letterbox_bottom.custom_minimum_size = Vector2(0, 68)
	hud.add_child(_letterbox_bottom)

	# 2. Dynamic Narrative Overlay (Acts 1 to 3)
	_narrative_box = VBoxContainer.new()
	_narrative_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_narrative_box.offset_top = -210
	_narrative_box.offset_bottom = -90
	_narrative_box.offset_left = -460
	_narrative_box.offset_right = 460
	_narrative_box.add_theme_constant_override("separation", 6)
	_narrative_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_narrative_box.modulate.a = 0.0
	hud.add_child(_narrative_box)

	_eyebrow_lbl = Label.new()
	_eyebrow_lbl.text = "PROLOGUE // THE STAR SEA"
	_eyebrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eyebrow_lbl.add_theme_font_size_override("font_size", 11)
	_eyebrow_lbl.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0, 0.9))
	_narrative_box.add_child(_eyebrow_lbl)

	_title_lbl = Label.new()
	_title_lbl.text = "Space is not empty. It is an ocean."
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.95))
	_title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_title_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_narrative_box.add_child(_title_lbl)

	_sub_lbl = Label.new()
	_sub_lbl.text = "A luminescent river of dark energy — the Éther — that carries warships across the stars."
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_lbl.add_theme_font_size_override("font_size", 13)
	_sub_lbl.add_theme_color_override("font_color", Color(0.72, 0.84, 0.96, 0.78))
	_narrative_box.add_child(_sub_lbl)

	# 3. Grand Title Reveal Container (Act 4)
	_title_reveal_box = VBoxContainer.new()
	_title_reveal_box.set_anchors_preset(Control.PRESET_CENTER)
	_title_reveal_box.offset_top = -140
	_title_reveal_box.offset_bottom = 120
	_title_reveal_box.offset_left = -380
	_title_reveal_box.offset_right = 380
	_title_reveal_box.add_theme_constant_override("separation", 14)
	_title_reveal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_reveal_box.modulate.a = 0.0
	hud.add_child(_title_reveal_box)

	_logo_rect = TextureRect.new()
	if ResourceLoader.exists(LOGO_PATH):
		_logo_rect.texture = load(LOGO_PATH)
	_logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_rect.custom_minimum_size = Vector2(580, 110)
	_title_reveal_box.add_child(_logo_rect)

	_tagline_lbl = Label.new()
	_tagline_lbl.text = "A  3 D   T U R N - B A S E D   S P A C E   S T R A T E G Y   G A M E"
	_tagline_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline_lbl.add_theme_font_size_override("font_size", 12)
	_tagline_lbl.add_theme_color_override("font_color", Color(0.40, 0.88, 1.0, 0.9))
	_title_reveal_box.add_child(_tagline_lbl)

	_prompt_lbl = Label.new()
	_prompt_lbl.text = "▶  PRESS SPACE / ENTER / CLICK TO ENGAGE  ◀"
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_size_override("font_size", 13)
	_prompt_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_title_reveal_box.add_child(_prompt_lbl)

	# 4. Subtle Bottom Skip Indicator
	_skip_hint_lbl = Label.new()
	_skip_hint_lbl.text = "[ESC / SPACE TO SKIP]"
	_skip_hint_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint_lbl.offset_left = -210
	_skip_hint_lbl.offset_top = -38
	_skip_hint_lbl.offset_right = -20
	_skip_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint_lbl.add_theme_font_size_override("font_size", 10)
	_skip_hint_lbl.add_theme_color_override("font_color", Color(0.48, 0.65, 0.80, 0.45))
	hud.add_child(_skip_hint_lbl)

	# 5. Fullscreen Fade Rect for cinematic transitions
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.005, 0.008, 0.015, 1.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_fade_rect)

func _process(delta: float) -> void:
	_time += delta

	# Smooth camera dolly/tracking interpolation
	if _bg_cam != null and _shot_duration > 0.0:
		var elapsed := _time - _shot_start_time
		var t := clampf(elapsed / _shot_duration, 0.0, 1.0)
		# Smooth cubic ease
		var ease_t := t * t * (3.0 - 2.0 * t)

		var cur_pos := _cam_start_pos.lerp(_cam_end_pos, ease_t)
		var cur_look := _look_start_pos.lerp(_look_end_pos, ease_t)

		# Subtle cinematic camera float/bobbing
		cur_pos.y += sin(_time * 0.8) * 0.12
		cur_pos.x += cos(_time * 0.5) * 0.10

		_bg_cam.global_position = cur_pos
		_bg_cam.look_at(cur_look, Vector3.UP)

	# Sequence state machine
	if _current_shot == 1 and _time >= SHOT_1_END:
		_start_shot(2)
	elif _current_shot == 2 and _time >= SHOT_2_END:
		_start_shot(3)
	elif _current_shot == 3 and _time >= SHOT_3_END:
		_start_shot(4)
	elif _current_shot == 4 and _time >= SEQUENCE_END:
		if not _transitioning:
			_proceed_to_menu()

	# Pulse prompt in final act
	if _current_shot == 4 and _prompt_lbl != null:
		var pulse := (sin(_time * 3.5) + 1.0) * 0.35 + 0.45
		_prompt_lbl.modulate.a = pulse

func _start_shot(shot_idx: int) -> void:
	_current_shot = shot_idx
	_shot_start_time = _time

	match shot_idx:
		1:
			# SHOT 1: Wide Glide over the Luminescent Cyan Éther River
			_shot_duration = SHOT_1_END
			_cam_start_pos = Vector3(16.0, -1.5, 24.0)
			_cam_end_pos = Vector3(2.0, -0.5, -4.0)
			_look_start_pos = Vector3(-18.0, 3.5, -60.0)
			_look_end_pos = Vector3(-35.0, 5.0, -95.0)

			_eyebrow_lbl.text = "PROLOGUE // THE STAR SEA"
			_title_lbl.text = "Space is not empty. It is an ocean."
			_sub_lbl.text = "A luminescent river of dark energy — the Éther — that carries warships across the stars."
			_fade_narrative_card(true)

		2:
			# SHOT 2: Dramatic Low-Angle Tracking along the Acero Dreadnought
			_shot_duration = SHOT_2_END - SHOT_1_END
			_cam_start_pos = Vector3(-13.5, 0.4, 8.0)
			_cam_end_pos = Vector3(-19.5, 3.8, 12.0)
			_look_start_pos = Vector3(-22.0, 2.0, -2.0)
			_look_end_pos = Vector3(-22.0, 2.4, -4.0)

			AudioManager.play_sfx("laser_heavy", -12.0)

			_eyebrow_lbl.text = "THE ARMADA OF ACERO // BODY & STEEL"
			_title_lbl.text = "\"When the sea dies, we forge dams of steel.\""
			_sub_lbl.text = "Massed capital ironclads, crushing railguns, and line-of-battle discipline."
			_fade_narrative_card(true)

		3:
			# SHOT 3: Sweeping Pan past Free Tide Quantum Sails & Vinculados Mobile Suits
			_shot_duration = SHOT_3_END - SHOT_2_END
			_cam_start_pos = Vector3(26.0, 2.8, 14.0)
			_cam_end_pos = Vector3(8.0, 5.2, 12.0)
			_look_start_pos = Vector3(22.0, 1.8, 2.0)
			_look_end_pos = Vector3(0.0, 3.0, -14.0)

			AudioManager.play_sfx("laser_pulse", -10.0)

			_eyebrow_lbl.text = "THE FREE TIDE & THE VINCULADOS // SPIRIT & SOUL"
			_title_lbl.text = "Corsairs who sail the wind. Pilots tuned to the void."
			_sub_lbl.text = "Three civilizations contest the dying tide as The Calm spreads."
			_fade_narrative_card(true)

		4:
			# SHOT 4: Grand Pull-Back & Title Wordmark Reveal
			_shot_duration = SEQUENCE_END - SHOT_3_END
			_cam_start_pos = Vector3(0.0, 18.0, 58.0)
			_cam_end_pos = Vector3(0.0, 24.0, 78.0)
			_look_start_pos = Vector3(0.0, 2.5, -20.0)
			_look_end_pos = Vector3(0.0, 3.0, -25.0)

			_fade_narrative_card(false)
			_reveal_title_card()

func _fade_narrative_card(show_card: bool) -> void:
	var tw := create_tween()
	if show_card:
		_narrative_box.modulate.a = 0.0
		tw.tween_interval(0.35)
		tw.tween_property(_narrative_box, "modulate:a", 1.0, 0.8)
		tw.tween_interval(_shot_duration - 1.8)
		tw.tween_property(_narrative_box, "modulate:a", 0.0, 0.6)
	else:
		tw.tween_property(_narrative_box, "modulate:a", 0.0, 0.4)

func _reveal_title_card() -> void:
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(_title_reveal_box, "modulate:a", 1.0, 1.2)

func _input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_proceed_to_menu()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		_proceed_to_menu()
	elif event is InputEventMouseButton and event.pressed:
		_proceed_to_menu()

func _proceed_to_menu() -> void:
	if _transitioning:
		return
	_transitioning = true

	AudioManager.play_sfx("ui_click", -6.0)

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.6)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(NEXT_SCENE_PATH)
	)
