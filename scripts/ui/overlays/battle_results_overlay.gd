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
			next_btn.visible = true
			if next_id != "":
				var num_str := next_id.get_slice("_", 2)
				next_btn.text = "▶ PROCEED TO STAGE %s BRIEFING" % num_str.to_upper()
			else:
				next_btn.text = "★ VIEW CAMPAIGN CREDITS ▶"

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
		"acero_stage_4":
			victory_title_label.text = "STAGE 04 ACCOMPLISHED // GATE TERTIUS SECURED"
		"acero_stage_8":
			victory_title_label.text = "ACT II VICTORY // INDUSTRIAL FORGE VULCAN-3 SECURED"
		"acero_stage_11":
			victory_title_label.text = "STAGE 11 ACCOMPLISHED // THE EVENT HORIZON HELD"
		"acero_stage_12":
			victory_title_label.text = "🏆 CAMPAIGN CONQUERED // THE IRON DAM SEALED"
		"vinculados_stage_1":
			victory_title_label.text = "TUTORIAL ACCOMPLISHED // RESONANCE DOCTRINE MASTERED"
		"vinculados_stage_3":
			victory_title_label.text = "ACT I VICTORY // GENESIS RING SYNCHRONIZED"
		"vinculados_stage_8":
			victory_title_label.text = "ACT II VICTORY // SANCTUARY CATHEDRAL AWAKENED"
		"vinculados_stage_12":
			victory_title_label.text = "🏆 CAMPAIGN CONQUERED // THE GREAT ASCENSION"
		"marea_stage_1":
			victory_title_label.text = "TUTORIAL ACCOMPLISHED // ETHER SAILING MASTERED"
		"marea_stage_3":
			victory_title_label.text = "ACT I VICTORY // CORSAIR HAVEN LIBERATED"
		"marea_stage_8":
			victory_title_label.text = "ACT II VICTORY // IMPERIAL SIEGE LINE BROKEN"
		"marea_stage_9":
			victory_title_label.text = "STAGE 09 ACCOMPLISHED // EYE OF THE MAELSTROM SURFED"
		"marea_stage_12":
			victory_title_label.text = "🏆 CAMPAIGN CONQUERED // SOVEREIGN OF THE STAR SEA"
		_:
			victory_title_label.text = "MISSION ACCOMPLISHED"
	victory_title_label.add_theme_font_size_override("font_size", 20)
	victory_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25) if stage_id.ends_with("_stage_12") else Color(0.3, 1.0, 0.65))
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
		"acero_stage_4":
			victory_sub_label.text = "Iron Gate Tertius Secured // Act I Climax\nThe canal locks have been fortified against corsair raids. Torpedo batteries repelled all fast-skiff incursions."
		"acero_stage_8":
			victory_sub_label.text = "Smelter Complex Vulcan-3 Secured // Act II Climax\nHeavy siege bombardment from CNS Crucible cracked the volcanic fortress. Imperial supply lines to the Iron Dam are secure."
		"acero_stage_11":
			victory_sub_label.text = "Calm Fracture Rift Secured // Eve of the Final Stand\nAgainst the absolute zero of the void rift, the battle line held fast. Only the final bastion remains to be sealed."
		"acero_stage_12":
			victory_sub_label.text = "THE ARMADA OF ACERO HAS WON THE STAR SEA!\nThe great Iron Dam stands unbroken across the galactic rift. The creeping frost of The Calm is permanently halted by human will, steel, and nuclear discipline. The fires of Anvil will burn forever."
		"vinculados_stage_1":
			victory_sub_label.text = "Sanctuary Spire Psalm-4 Defended // The Vinculados\nYou have mastered high-agility vector maneuvers, neural barrier defense, and focused resonance beam tactics alongside the Carrier Cradle."
		"vinculados_stage_3":
			victory_sub_label.text = "The Genesis Ring Synchronized // Act I Climax\nThe celestial ring's resonance pulse has stabilized the surrounding choir sectors against imperial interference."
		"vinculados_stage_8":
			victory_sub_label.text = "Sanctuary Cathedral Awakened // Act II Climax\nThe neural harmonics of the grand choir resonated through the crystal canyons, paving the way for the ultimate ascension."
		"vinculados_stage_12":
			victory_sub_label.text = "THE VINCULADOS HAVE TRANSCENDED THE MORTAL SEA!\nThe Seraph-Prime Colossus Mobile Armor and the entire neural chorus have crossed beyond the dying material void into eternal, infinite harmonic resonance. The hymn of souls sings across eternity."
		"marea_stage_1":
			victory_sub_label.text = "The Basalt Narrows Cleared // The Free Tide\nYou have navigated the treacherous asteroid gorge, harnessed the Ether rush of El Rio del Viento, and shattered the Acero picket line!"
		"marea_stage_3":
			victory_sub_label.text = "Corsair Haven Redoubt Liberated // Act I Climax\nThe imperial blockade of the pirate sanctuary has been broken! Rum, repairs, and fresh quantum sails await the fleet."
		"marea_stage_8":
			victory_sub_label.text = "Imperial Fortress Redoubt Shattered // Act II Climax\nHeavy siege bombards dismantled the imperial bastion sluices. The Grand Corsair Armada now controls the approaches to Barlovento."
		"marea_stage_9":
			victory_sub_label.text = "Eye of the Maelstrom Claimed // Act III Apex\nSurfing the central vortex currents with 6-sail rigging, the Free Tide seized the ultimate weather gauge over the imperial dreadnoughts."
		"marea_stage_12":
			victory_sub_label.text = "THE STAR SEA IS LIBERATED! THE WEATHER GAUGE IS OURS FOREVER!\nThe Grand Corsair Fleet of the Free Tide has broken all chains! The wind howls unbounded through every canal and rift. As long as stars shine in the black, we sail free!"
		_:
			victory_sub_label.text = "Sector Secured // Combat Victory\nThe hostile combatants have been neutralized or forced to retreat. Your squadron commands the sector."
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
	victory_next_btn.text = "▶ PROCEED TO NEXT BRIEFING" if has_next_stage else "★ VIEW CAMPAIGN CREDITS ▶"
	victory_next_btn.custom_minimum_size = Vector2(240, 38)
	victory_next_btn.visible = true
	if on_return.is_valid():
		victory_next_btn.pressed.connect(on_return)
	btn_row.add_child(victory_next_btn)
	dialog.next_btn = victory_next_btn

	var menu_btn := Button.new()
	menu_btn.text = "◀ CAMPAIGN BRIEFING" if has_next_stage else "◀ MAIN MENU"
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
