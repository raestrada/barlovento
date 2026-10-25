class_name StoryTransitionOverlay
extends Control

signal story_completed

enum Mode { INTRO, OUTRO }

var _current_mode: Mode = Mode.INTRO
var _stage_id: String = ""
var _story_data: Dictionary = {}
var _dialogue_beats: Array = []
var _current_beat_index: int = 0

# UI Nodes
var _backdrop_rect: TextureRect
var _summary_panel: PanelContainer
var _chapter_badge_lbl: Label
var _summary_title_lbl: Label
var _summary_body_lbl: Label

var _left_panel: PanelContainer
var _left_char_container: VBoxContainer
var _left_portrait_rect: TextureRect
var _left_name_lbl: Label
var _left_role_lbl: Label

var _right_panel: PanelContainer
var _right_char_container: VBoxContainer
var _right_portrait_rect: TextureRect
var _right_name_lbl: Label
var _right_role_lbl: Label

var _dialogue_box: PanelContainer
var _nameplate_lbl: Label
var _dialogue_text_lbl: Label
var _advance_prompt_lbl: Label
var _skip_btn: Button
var _proceed_btn: Button

# Typewriter state
var _full_line_text: String = ""
var _visible_chars: int = 0
var _is_typing: bool = false
var _type_timer: float = 0.0
const CHARS_PER_SEC: float = 45.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false

func _build_ui() -> void:
	# 1. Opaque Deep Cinema Backdrop (prevents Admiral Chart & HUD from bleeding through stage art & dialogues)
	var dim_rect := ColorRect.new()
	add_child(dim_rect)
	dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim_rect.color = Color(0.01, 0.02, 0.04, 0.98)

	# 2. Full-Clarity Cinematic Stage Key Art Backdrop
	_backdrop_rect = TextureRect.new()
	add_child(_backdrop_rect)
	_backdrop_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop_rect.modulate = Color(1.0, 1.0, 1.0, 0.88)

	# 3. Top & Bottom Cinematic Letterbox Bars
	var top_bar := ColorRect.new()
	add_child(top_bar)
	top_bar.custom_minimum_size = Vector2(0, 48)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.color = Color(0.0, 0.0, 0.0, 0.90)

	var bottom_bar := ColorRect.new()
	add_child(bottom_bar)
	bottom_bar.custom_minimum_size = Vector2(0, 48)
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.color = Color(0.0, 0.0, 0.0, 0.90)

	# 4. Top Story Recap Card (Manga Synopsis Box - Centered)
	_summary_panel = PanelContainer.new()
	var sum_style := StyleBoxFlat.new()
	sum_style.bg_color = Color(0.015, 0.045, 0.09, 0.96)
	sum_style.border_color = HudWidgets.COL_CYAN_BRIGHT
	sum_style.set_border_width_all(1)
	sum_style.set_corner_radius_all(6)
	sum_style.set_content_margin_all(10)
	_summary_panel.add_theme_stylebox_override("panel", sum_style)
	add_child(_summary_panel)
	_summary_panel.anchor_left = 0.5
	_summary_panel.anchor_right = 0.5
	_summary_panel.anchor_top = 0.0
	_summary_panel.anchor_bottom = 0.0
	_summary_panel.offset_left = -420
	_summary_panel.offset_right = 420
	_summary_panel.offset_top = 54
	_summary_panel.offset_bottom = 158

	var sum_vbox := VBoxContainer.new()
	sum_vbox.add_theme_constant_override("separation", 3)
	_summary_panel.add_child(sum_vbox)

	_chapter_badge_lbl = Label.new()
	_chapter_badge_lbl.text = "✦ THE ARMADA OF ACERO // ACT I // STAGE 01"
	_chapter_badge_lbl.add_theme_font_size_override("font_size", 12)
	_chapter_badge_lbl.add_theme_color_override("font_color", HudWidgets.COL_AMBER)
	sum_vbox.add_child(_chapter_badge_lbl)

	_summary_title_lbl = Label.new()
	_summary_title_lbl.text = "THE SITUATION // WAR SYNOPSIS:"
	_summary_title_lbl.add_theme_font_size_override("font_size", 10)
	_summary_title_lbl.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
	sum_vbox.add_child(_summary_title_lbl)

	_summary_body_lbl = Label.new()
	_summary_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_body_lbl.add_theme_font_size_override("font_size", 11)
	_summary_body_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	sum_vbox.add_child(_summary_body_lbl)

	# 5. Character Portraits (Left Protagonist / Squadron Lead, Right Wingman / Adversary)
	var left_card_style := StyleBoxFlat.new()
	left_card_style.bg_color = Color(0.015, 0.045, 0.09, 0.92)
	left_card_style.border_color = Color(0.25, 0.85, 1.0, 0.75)
	left_card_style.set_border_width_all(1)
	left_card_style.set_corner_radius_all(6)
	left_card_style.set_content_margin_all(8)

	_left_panel = PanelContainer.new()
	_left_panel.add_theme_stylebox_override("panel", left_card_style)
	add_child(_left_panel)
	_left_panel.anchor_left = 0.0
	_left_panel.anchor_right = 0.0
	_left_panel.anchor_top = 1.0
	_left_panel.anchor_bottom = 1.0
	_left_panel.offset_left = 24
	_left_panel.offset_right = 204
	_left_panel.offset_top = -376
	_left_panel.offset_bottom = -164

	_left_char_container = VBoxContainer.new()
	_left_char_container.alignment = BoxContainer.ALIGNMENT_END
	_left_panel.add_child(_left_char_container)

	_left_portrait_rect = TextureRect.new()
	_left_portrait_rect.custom_minimum_size = Vector2(160, 152)
	_left_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_left_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_left_char_container.add_child(_left_portrait_rect)

	_left_name_lbl = Label.new()
	_left_name_lbl.add_theme_font_size_override("font_size", 12)
	_left_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82))
	_left_char_container.add_child(_left_name_lbl)

	_left_role_lbl = Label.new()
	_left_role_lbl.add_theme_font_size_override("font_size", 10)
	_left_role_lbl.add_theme_color_override("font_color", HudWidgets.COL_CYAN_BRIGHT)
	_left_char_container.add_child(_left_role_lbl)

	var right_card_style := left_card_style.duplicate()
	right_card_style.border_color = Color(1.0, 0.72, 0.28, 0.75)

	_right_panel = PanelContainer.new()
	_right_panel.add_theme_stylebox_override("panel", right_card_style)
	add_child(_right_panel)
	_right_panel.anchor_left = 1.0
	_right_panel.anchor_right = 1.0
	_right_panel.anchor_top = 1.0
	_right_panel.anchor_bottom = 1.0
	_right_panel.offset_left = -204
	_right_panel.offset_right = -24
	_right_panel.offset_top = -376
	_right_panel.offset_bottom = -164

	_right_char_container = VBoxContainer.new()
	_right_char_container.alignment = BoxContainer.ALIGNMENT_END
	_right_panel.add_child(_right_char_container)

	_right_portrait_rect = TextureRect.new()
	_right_portrait_rect.custom_minimum_size = Vector2(160, 152)
	_right_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_right_char_container.add_child(_right_portrait_rect)

	_right_name_lbl = Label.new()
	_right_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_right_name_lbl.add_theme_font_size_override("font_size", 12)
	_right_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.82))
	_right_char_container.add_child(_right_name_lbl)

	_right_role_lbl = Label.new()
	_right_role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_right_role_lbl.add_theme_font_size_override("font_size", 10)
	_right_role_lbl.add_theme_color_override("font_color", HudWidgets.COL_AMBER)
	_right_char_container.add_child(_right_role_lbl)

	# 6. Bottom Anime Visual Novel Dialogue Box (Centered)
	_dialogue_box = PanelContainer.new()
	var diag_style := StyleBoxFlat.new()
	diag_style.bg_color = Color(0.015, 0.05, 0.10, 0.97)
	diag_style.border_color = HudWidgets.COL_CYAN_BRIGHT
	diag_style.set_border_width_all(2)
	diag_style.set_corner_radius_all(8)
	diag_style.set_content_margin_all(14)
	_dialogue_box.add_theme_stylebox_override("panel", diag_style)
	add_child(_dialogue_box)
	_dialogue_box.anchor_left = 0.5
	_dialogue_box.anchor_right = 0.5
	_dialogue_box.anchor_top = 1.0
	_dialogue_box.anchor_bottom = 1.0
	_dialogue_box.offset_left = -460
	_dialogue_box.offset_right = 460
	_dialogue_box.offset_top = -154
	_dialogue_box.offset_bottom = -26

	var diag_vbox := VBoxContainer.new()
	diag_vbox.add_theme_constant_override("separation", 6)
	_dialogue_box.add_child(diag_vbox)

	var diag_header_row := HBoxContainer.new()
	diag_vbox.add_child(diag_header_row)

	_nameplate_lbl = Label.new()
	_nameplate_lbl.text = "ADM. VANE [FLEET ADMIRAL]"
	_nameplate_lbl.add_theme_font_size_override("font_size", 13)
	_nameplate_lbl.add_theme_color_override("font_color", HudWidgets.COL_AMBER)
	diag_header_row.add_child(_nameplate_lbl)

	_advance_prompt_lbl = Label.new()
	_advance_prompt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_advance_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_advance_prompt_lbl.text = "[SPACE] / CLICK TO ADVANCE ▶"
	_advance_prompt_lbl.add_theme_font_size_override("font_size", 10)
	_advance_prompt_lbl.add_theme_color_override("font_color", HudWidgets.COL_TEXT_MUTED)
	diag_header_row.add_child(_advance_prompt_lbl)

	_dialogue_text_lbl = Label.new()
	_dialogue_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text_lbl.add_theme_font_size_override("font_size", 13)
	_dialogue_text_lbl.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	_dialogue_text_lbl.custom_minimum_size = Vector2(0, 56)
	diag_vbox.add_child(_dialogue_text_lbl)

	# 7. Action / Proceed Button (for Outro completion)
	_proceed_btn = Button.new()
	_proceed_btn.text = "▶ PROCEED TO NEXT STAGE BRIEFING"
	_proceed_btn.custom_minimum_size = Vector2(340, 42)
	_proceed_btn.add_theme_font_size_override("font_size", 13)
	_proceed_btn.add_theme_color_override("font_color", HudWidgets.COL_GREEN)
	_proceed_btn.visible = false
	_proceed_btn.pressed.connect(_on_proceed_pressed)
	add_child(_proceed_btn)
	_proceed_btn.anchor_left = 0.5
	_proceed_btn.anchor_right = 0.5
	_proceed_btn.anchor_top = 1.0
	_proceed_btn.anchor_bottom = 1.0
	_proceed_btn.offset_left = -170
	_proceed_btn.offset_right = 170
	_proceed_btn.offset_top = -90
	_proceed_btn.offset_bottom = -48

	# 8. Skip Story Button (top-right corner)
	_skip_btn = Button.new()
	_skip_btn.text = "⏭ SKIP STORY [ESC]"
	_skip_btn.custom_minimum_size = Vector2(160, 30)
	_skip_btn.add_theme_font_size_override("font_size", 10)
	_skip_btn.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_skip_btn.pressed.connect(_finish_story)
	add_child(_skip_btn)
	_skip_btn.anchor_left = 1.0
	_skip_btn.anchor_right = 1.0
	_skip_btn.anchor_top = 0.0
	_skip_btn.anchor_bottom = 0.0
	_skip_btn.offset_left = -176
	_skip_btn.offset_right = -16
	_skip_btn.offset_top = 9
	_skip_btn.offset_bottom = 39

func show_intro(stage_id: String) -> void:
	_current_mode = Mode.INTRO
	_stage_id = stage_id
	_story_data = StoryDB.get_story_data(stage_id)
	_dialogue_beats = _story_data.get("intro_dialogue", [])
	_current_beat_index = 0

	_setup_view()
	visible = true

func show_outro(stage_id: String) -> void:
	_current_mode = Mode.OUTRO
	_stage_id = stage_id
	_story_data = StoryDB.get_story_data(stage_id)
	_dialogue_beats = _story_data.get("outro_dialogue", [])
	_current_beat_index = 0

	_setup_view()
	visible = true

func _setup_view() -> void:
	var bg_path: String = _story_data.get("backdrop", "")
	if bg_path != "" and ResourceLoader.exists(bg_path):
		_backdrop_rect.texture = load(bg_path)

	var is_final: bool = _stage_id.ends_with("_stage_12") or _story_data.get("is_final_stage", false)
	if _current_mode == Mode.OUTRO and is_final:
		_backdrop_rect.modulate = Color(1.0, 1.0, 1.0, 0.96)
		_chapter_badge_lbl.text = "★ GRAND FINALE // %s" % _story_data.get("title", _stage_id.to_upper())
		_chapter_badge_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	else:
		_backdrop_rect.modulate = Color(1.0, 1.0, 1.0, 0.88)
		_chapter_badge_lbl.text = "✦ %s" % _story_data.get("title", _stage_id.to_upper())
		_chapter_badge_lbl.add_theme_color_override("font_color", HudWidgets.COL_AMBER)

	if _current_mode == Mode.INTRO:
		_summary_title_lbl.text = "THE SITUATION // WAR SYNOPSIS:"
		_summary_body_lbl.text = _story_data.get("intro_summary", "")
		_proceed_btn.visible = false
		_dialogue_box.visible = true
		_skip_btn.visible = true
	else:
		_summary_title_lbl.text = "MISSION ACCOMPLISHED // COMBAT AFTERMATH:" if not is_final else "★ THE GRAND CLIMAX // VICTORY EPILOGUE:"
		_summary_body_lbl.text = _story_data.get("outro_summary", "")
		_proceed_btn.visible = false
		_dialogue_box.visible = true
		_skip_btn.visible = true

	# Pre-populate left/right character cards from dialogue beats so both interlocutors are framed cleanly
	_left_portrait_rect.texture = null
	_right_portrait_rect.texture = null
	for b in _dialogue_beats:
		var b_side: String = b.get("side", "left")
		var b_port: String = b.get("portrait", "")
		if b_side == "left" and _left_portrait_rect.texture == null and b_port != "" and ResourceLoader.exists(b_port):
			_left_portrait_rect.texture = load(b_port)
			_left_name_lbl.text = b.get("speaker", "")
			_left_role_lbl.text = b.get("role", "")
		elif b_side == "right" and _right_portrait_rect.texture == null and b_port != "" and ResourceLoader.exists(b_port):
			_right_portrait_rect.texture = load(b_port)
			_right_name_lbl.text = b.get("speaker", "")
			_right_role_lbl.text = b.get("role", "")

	_show_beat(_current_beat_index)

func _show_beat(index: int) -> void:
	if index >= _dialogue_beats.size():
		if _current_mode == Mode.OUTRO:
			_dialogue_box.visible = false
			_proceed_btn.visible = true
			_skip_btn.visible = false
			var is_final: bool = _stage_id.ends_with("_stage_12") or _story_data.get("is_final_stage", false)
			if is_final:
				_proceed_btn.text = "🏆 CLAIM TOTAL VICTORY // GRAND FLEET HEADQUARTERS"
				_proceed_btn.custom_minimum_size = Vector2(460, 48)
				_proceed_btn.position = Vector2(-230, -80)
				_proceed_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
				_backdrop_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
				_summary_panel.visible = true
				_summary_title_lbl.text = "★ GRAND CAMPAIGN ACCOMPLISHED // THE STAR SEA IS WON ★"
				_summary_body_lbl.text = _story_data.get("outro_summary", "")
				AudioManager.play_victory_fanfare(0.0)
			else:
				_proceed_btn.text = "▶ PROCEED TO NEXT STAGE BRIEFING"
		else:
			_finish_story()
		return

	var beat: Dictionary = _dialogue_beats[index]
	var speaker: String = beat.get("speaker", "Commander")
	var role: String = beat.get("role", "")
	var portrait_path: String = beat.get("portrait", "")
	var side: String = beat.get("side", "left")
	var full_text: String = beat.get("text", "")

	_nameplate_lbl.text = "%s // %s" % [speaker.to_upper(), role]

	var port_tex: Texture2D = null
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		port_tex = load(portrait_path)

	if side == "left":
		if port_tex != null:
			_left_portrait_rect.texture = port_tex
		_left_name_lbl.text = speaker
		_left_role_lbl.text = role
		_left_panel.visible = (_left_portrait_rect.texture != null)
		_right_panel.visible = (_right_portrait_rect.texture != null)
		_left_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_right_panel.modulate = Color(0.42, 0.45, 0.54, 0.78)
	else:
		if port_tex != null:
			_right_portrait_rect.texture = port_tex
		_right_name_lbl.text = speaker
		_right_role_lbl.text = role
		_left_panel.visible = (_left_portrait_rect.texture != null)
		_right_panel.visible = (_right_portrait_rect.texture != null)
		_right_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_left_panel.modulate = Color(0.42, 0.45, 0.54, 0.78)

	# Start typewriter effect
	_full_line_text = full_text
	_visible_chars = 0
	_is_typing = true
	_type_timer = 0.0
	_dialogue_text_lbl.text = ""

func _process(delta: float) -> void:
	if not visible:
		return

	if _is_typing:
		_type_timer += delta
		var target_count := int(_type_timer * CHARS_PER_SEC)
		if target_count > _visible_chars:
			_visible_chars = mini(target_count, _full_line_text.length())
			_dialogue_text_lbl.text = _full_line_text.substr(0, _visible_chars)
			if _visible_chars % 3 == 0:
				AudioManager.play_sfx("ui_hover", -18.0)
			if _visible_chars >= _full_line_text.length():
				_is_typing = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not is_inside_tree():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			_finish_story()
		elif event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			var vp := get_viewport()
			if vp != null:
				vp.set_input_as_handled()
			_advance_dialogue()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		_advance_dialogue()

func _advance_dialogue() -> void:
	if _is_typing:
		# Fast-forward typewriter
		_is_typing = false
		_dialogue_text_lbl.text = _full_line_text
		return

	if _proceed_btn.visible:
		_on_proceed_pressed()
		return

	_current_beat_index += 1
	AudioManager.play_sfx("ui_click", -10.0)
	_show_beat(_current_beat_index)

func _finish_story() -> void:
	visible = false
	story_completed.emit()

func _on_proceed_pressed() -> void:
	_finish_story()
