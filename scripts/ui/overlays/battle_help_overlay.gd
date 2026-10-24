class_name BattleHelpOverlay
extends RefCounted

static func build_help_overlay(layer: CanvasLayer, hud_theme: Theme, on_close: Callable, on_menu: Callable) -> Control:
	var help_overlay := Control.new()
	help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_overlay.visible = false
	layer.add_child(help_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.80)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = hud_theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(840, 480)
	help_overlay.add_child(panel)

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
	if on_menu.is_valid():
		to_menu_btn.pressed.connect(on_menu)
	header_row.add_child(to_menu_btn)

	var close_top_btn := Button.new()
	close_top_btn.text = "✕ CLOSE [ESC / H]"
	if on_close.is_valid():
		close_top_btn.pressed.connect(on_close)
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
	if on_close.is_valid():
		footer_btn.pressed.connect(on_close)
	main_vbox.add_child(footer_btn)

	return help_overlay
