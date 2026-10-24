class_name BattleResultsOverlay
extends RefCounted

class VictoryDialog:
	var root: Control
	var title_label: Label
	var sub_label: Label
	var next_btn: Button

	func set_promotions(promo_lines: Array[String]) -> void:
		if not promo_lines.is_empty() and sub_label != null:
			sub_label.text += "\n\nVETERAN ACE PROMOTIONS (SAVED TO CAMPAIGN):\n" + "\n".join(promo_lines)

	func update_next_stage(next_id: String) -> void:
		if next_btn != null:
			next_btn.visible = (next_id != "")
			if next_id != "":
				var num_str := next_id.get_slice("_", 2)
				next_btn.text = "▶ PROCEED TO STAGE %s BRIEFING" % num_str.to_upper()
			else:
				next_btn.text = "▶ PROCEED TO BRIEFING"

	func show() -> void:
		if root != null:
			root.visible = true

static func build_victory_overlay(layer: CanvasLayer, hud_theme: Theme, stage_id: String, has_next_stage: bool, on_return: Callable, on_replay: Callable) -> VictoryDialog:
	var dialog := VictoryDialog.new()
	var victory_overlay := Control.new()
	victory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_overlay.visible = false
	layer.add_child(victory_overlay)
	dialog.root = victory_overlay

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.08, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = hud_theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(650, 350)
	victory_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var victory_title_label := Label.new()
	match stage_id:
		"acero_stage_1":
			victory_title_label.text = "TUTORIAL ACCOMPLISHED // STEEL ENDURES"
		"acero_stage_2":
			victory_title_label.text = "STAGE 02 ACCOMPLISHED // THE CHOIR SILENCED"
		"acero_stage_3":
			victory_title_label.text = "ACT I VICTORY // BASTION OF THE CALM"
		"vinculados_stage_1":
			victory_title_label.text = "TUTORIAL ACCOMPLISHED // RESONANCE DOCTRINE MASTERED"
		"marea_stage_1":
			victory_title_label.text = "TUTORIAL ACCOMPLISHED // ETHER SAILING MASTERED"
		_:
			victory_title_label.text = "MISSION ACCOMPLISHED"
	victory_title_label.add_theme_font_size_override("font_size", 20)
	victory_title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.65))
	vbox.add_child(victory_title_label)
	dialog.title_label = victory_title_label

	var victory_sub_label := Label.new()
	match stage_id:
		"acero_stage_1":
			victory_sub_label.text = "Sluice Station Well-09 Secured // The Armada of Acero\nYou have mastered basic vector steering, WEGO simultaneous execution, and broadside combat. Refined eteron continues to flow toward the orbital forges of Anvil."
		"acero_stage_2":
			victory_sub_label.text = "Resonance Spire Secured // The Armada of Acero\nCommander Kaelen's Vinculados Choir Wing was forced to retreat before they could destabilize the sector's Ether currents."
		"acero_stage_3":
			victory_sub_label.text = "The Calm Threshold Held // Act I Campaign Complete\nAgainst the encroaching Calm, Admiral Vane's veteran squadron broke the coalition vanguard and anchored the Sluice Wall."
		"vinculados_stage_1":
			victory_sub_label.text = "Sanctuary Spire Psalm-4 Defended // The Vinculados\nYou have mastered high-agility vector maneuvers, neural barrier defense, and focused resonance beam tactics alongside the Carrier Cradle."
		"marea_stage_1":
			victory_sub_label.text = "The Basalt Narrows Cleared // The Free Tide\nYou have navigated the treacherous asteroid gorge, harnessed the Ether rush of El Rio del Viento, and shattered the Acero picket line!"
		_:
			victory_sub_label.text = "Sector Psalm-4 // Resonance Well Secured\nThe hostile strike group has been repelled. Your squadron holds control of the local Ether currents."
	victory_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	victory_sub_label.add_theme_font_size_override("font_size", 12)
	victory_sub_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	vbox.add_child(victory_sub_label)
	dialog.sub_label = victory_sub_label

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var victory_next_btn := Button.new()
	victory_next_btn.text = "▶ PROCEED TO NEXT BRIEFING"
	victory_next_btn.custom_minimum_size = Vector2(240, 38)
	victory_next_btn.visible = has_next_stage
	if on_return.is_valid():
		victory_next_btn.pressed.connect(on_return)
	btn_row.add_child(victory_next_btn)
	dialog.next_btn = victory_next_btn

	var menu_btn := Button.new()
	menu_btn.text = "◀ CAMPAIGN BRIEFING"
	menu_btn.custom_minimum_size = Vector2(180, 38)
	if on_return.is_valid():
		menu_btn.pressed.connect(on_return)
	btn_row.add_child(menu_btn)

	var replay_btn := Button.new()
	replay_btn.text = "↻ REPLAY STAGE"
	replay_btn.custom_minimum_size = Vector2(150, 38)
	if on_replay.is_valid():
		replay_btn.pressed.connect(on_replay)
	btn_row.add_child(replay_btn)

	return dialog

static func build_defeat_overlay(layer: CanvasLayer, hud_theme: Theme, stage_id: String, on_menu: Callable, on_retry: Callable) -> Control:
	var defeat_overlay := Control.new()
	defeat_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	defeat_overlay.visible = false
	layer.add_child(defeat_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.01, 0.02, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	defeat_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.theme = hud_theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(580, 310)
	defeat_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "MISSION FAILED // LINE OF BATTLE BROKEN"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	vbox.add_child(title)

	var sub := Label.new()
	if stage_id == "acero_stage_1":
		sub.text = "Sluice Station Well-09 Lost // Flagship CNS Iron Bastion Destroyed\n\nWithout the Anvil-class flagship anchoring the line, Free Tide corsairs breached the sluice gates and cut Anvil's eteron supply spine."
	else:
		sub.text = "Flagship Link Severed // The Squadron Falls Silent\n\nYour command vessel was destroyed in combat."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.95, 0.8, 0.8))
	vbox.add_child(sub)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var menu_btn := Button.new()
	menu_btn.text = "◀ RETURN TO BRIEFING"
	menu_btn.custom_minimum_size = Vector2(230, 38)
	if on_menu.is_valid():
		menu_btn.pressed.connect(on_menu)
	btn_row.add_child(menu_btn)

	var retry_btn := Button.new()
	retry_btn.text = "↻ RETRY STAGE"
	retry_btn.custom_minimum_size = Vector2(180, 38)
	if on_retry.is_valid():
		retry_btn.pressed.connect(on_retry)
	btn_row.add_child(retry_btn)

	return defeat_overlay
