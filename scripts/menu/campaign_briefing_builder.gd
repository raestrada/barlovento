class_name CampaignBriefingBuilder
extends RefCounted

static func add_squadron_row(container: Control, ship_id: String, unit_name: String, role_str: String, stats_str: String) -> void:
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
	var rank_stars := ""
	if rank > 0:
		rank_stars = " " + "".join(["★" for _i in range(rank)])

	var name_lbl := Label.new()
	name_lbl.text = "◆ %s%s // %s" % [unit_name.to_upper(), rank_stars, role_str]
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.75) if rank > 0 else Color(0.9, 0.95, 1.0))
	vb.add_child(name_lbl)

	var stats_lbl := Label.new()
	var rank_tag := ""
	if rank > 0:
		rank_tag = " [VET +%d%% HP/DMG]" % (rank * 10)
	stats_lbl.text = stats_str + rank_tag
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 0.8))
	vb.add_child(stats_lbl)

	container.add_child(panel)

static func populate_acero(menu: Control, stage_id: String) -> void:
    LoreDB.current_stage_id = stage_id

    for child in menu._stage_selector_row.get_children():
        child.queue_free()
    for child in menu._squadron_vbox.get_children():
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
            menu._populate_acero_stage_briefing(sid)
        )
        menu._stage_selector_row.add_child(btn)

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
    menu._briefing_art_rect.texture = art_tex

    menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_vane.png")
    menu._commander_name_lbl.text = "FLEET ADMIRAL VANE"
    menu._commander_role_lbl.text = "Flagship Command // CNS Iron Bastion (Anvil-Class)" 

    match stage_id:
        "acero_stage_1":
            menu._briefing_title_lbl.text = "ACT I // STAGE 01 [TUTORIAL]: DEFENSE OF SLUICE STATION WELL-09"
            menu._briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // NAVAL ACADEMY & BATTLE DRILL"
            menu._commander_quote_lbl.text = "\"Officers and Cadets, welcome to the tactical line. Sluice Station Well-09 is under raid by corsair scouts. Today you master the foundation of Acero warfare: heavy armor angling, simultaneous WEGO maneuvering, and interlocking broadside fire. Form a wall of steel. Steel endures.\""
            _objectives_lbl.text = "◆ TUTORIAL DRILL 1 (FLEET COMMAND): Learn simultaneous Admiral WEGO movement, ship selection, and vector steering.\n◆ TUTORIAL DRILL 2 (ACERO DOCTRINE): Heavy Bow/Flank armor, broadsides (42°–138°), and Action Points (AP).\n◆ PRIMARY OBJECTIVE: Destroy all 3 hostile Free Tide corsair warships threatening Sluice Station Well-09.\n◆ SECONDARY OBJECTIVE: Ensure Flagship CNS Iron Bastion survives the engagement."
            add_squadron_row(menu._squadron_vbox, "acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            add_squadron_row(menu._squadron_vbox, "acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH TUTORIAL STAGE 01"

        "acero_stage_2":
            menu._briefing_title_lbl.text = "ACT I // STAGE 02: AMBUSH AT THE RESONANCE SPIRE"
            menu._briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // HOSTILES: THE VINCULADOS CHOIR WING"
            menu._commander_quote_lbl.text = "\"With Well-09 secured, our convoy pushes toward the Resonance Spire. Commander Kaelen's Vinculados Choir Wing is riding a violent crosswind current to ambush our flank. Hold formation, claim the upwind Weather-Gauge [BARLOVENTO], and crush their nimble frames with concentrated railgun salvos!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Destroy all 3 hostile Vinculados combat frames in the Resonance Spire sector.\n◆ SECONDARY OBJECTIVE: Ensure Flagship CNS Iron Bastion survives.\n◆ WEATHER-GAUGE DOCTRINE: Attacking from upwind along the Éther current grants [BARLOVENTO] (+12% Hit & +15% Damage)."
            add_squadron_row(menu._squadron_vbox, "acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            add_squadron_row(menu._squadron_vbox, "acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 02"

        "acero_stage_3":
            menu._briefing_title_lbl.text = "ACT I // STAGE 03: BASTION OF THE CALM THRESHOLD"
            menu._briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // HOSTILES: GRAND CORSAIR FLAGSHIP ARMADA"
            menu._commander_quote_lbl.text = "\"The Calm wavefront has reached the inner sluice wall. A reinforced Free Tide armada led by a heavily armored flagship Galleon is making a final desperate charge to breach the dam. Our Veteran Aces stand ready—anchor the line and prove that Steel Endures!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Defeat the reinforced 3-ship Veteran Corsair Armada at the Calm Threshold.\n◆ SECONDARY OBJECTIVE: Ensure Flagship CNS Iron Bastion survives the final stand.\n◆ VETERAN ACES: Your surviving ships carry over their Veteran Rank bonuses into this decisive battle!"
            add_squadron_row(menu._squadron_vbox, "acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            add_squadron_row(menu._squadron_vbox, "acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 03"

        "acero_stage_4":
            menu._briefing_title_lbl.text = "ACT I // STAGE 04: THE CRUCIBLE OF FIRE"
            menu._briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // HEAVY REINFORCEMENTS ENGAGEMENT"
            menu._commander_quote_lbl.text = "\"Hostile incursions threaten the foundry furnaces. Heavy monitor fire and cruiser salvos must suppress enemy advances across the inner line.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Eliminate enemy vanguard forces threatening the smelting ring.\n◆ SECONDARY OBJECTIVE: Maintain line integrity without losing capital escorts.\n◆ TACTICAL TIP: Focus heavy railguns on high-threat targets at extreme range."
            add_squadron_row(menu._squadron_vbox, "acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            add_squadron_row(menu._squadron_vbox, "acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 04"

        "acero_stage_5", "acero_stage_6", "acero_stage_7", "acero_stage_8":
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_tarek.png")
            menu._commander_name_lbl.text = "FLEET ADMIRAL TAREK"
            menu._commander_role_lbl.text = "Siege Line Command // CNS Crucible (Heavy Monitor)"
            menu._briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            menu._briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // HEAVY SIEGE MONITOR DEPLOYMENT"
            menu._commander_quote_lbl.text = "\"The Siege Line is mobilized. With the Crucible-Class Heavy Siege Monitor on station, our plasma mortars will pulverize enemy hulls at extreme distance before they ever close the vector.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Break through hostile defensive lines and annihilate enemy capital squadrons.\n◆ SECONDARY OBJECTIVE: Protect CNS Crucible during long-range mortar bombardment cycles.\n◆ SIEGE DOCTRINE: Heavy Mortars deliver massive kinetic impact with long reload cycles."
            add_squadron_row(menu._squadron_vbox, "acero_monitor", "CNS Crucible", "Crucible-Class Heavy Siege Monitor • Adm. Tarek", "HP 310 | RNG 64m | Heavy Plasma Mortar")
            add_squadron_row(menu._squadron_vbox, "acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            add_squadron_row(menu._squadron_vbox, "acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "acero_stage_9", "acero_stage_10", "acero_stage_11":
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_tarek.png")
            menu._commander_name_lbl.text = "FLEET ADMIRAL TAREK"
            menu._commander_role_lbl.text = "Combined Arms Armada // Fortress Battlefleet"
            menu._briefing_title_lbl.text = "ACT III // STAGE %02d: %s" % [cur_num, stage_titles[cur_num - 1]]
            menu._briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // FULL TASK FORCE BATTLE BASTION"
            menu._commander_quote_lbl.text = "\"All strike groups converge. The Calm approaches maximum expansion. Deploy the Arsenal Carrier Forge-01 and heavy escorts. We dictate the terms of this engagement.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Destroy enemy elite vanguard and flagship forces.\n◆ SECONDARY OBJECTIVE: Maintain the defensive perimeter around Arsenal-Class Carrier Forge-01.\n◆ TASK FORCE DOCTRINE: Interlocking flak fields and concentrated railgun fire neutralize enemy flanking vectors."
            add_squadron_row(menu._squadron_vbox, "acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "acero_monitor", "CNS Crucible", "Crucible-Class Heavy Siege Monitor • Adm. Tarek", "HP 310 | RNG 64m | Heavy Plasma Mortar")
            add_squadron_row(menu._squadron_vbox, "acero_carrier", "CNS Forge-01", "Arsenal-Class Mobile Fleet Bastion • Cmdr. Vance", "HP 420 | RNG 48m | Fleet Defense & Flak Bastion")
            add_squadron_row(menu._squadron_vbox, "acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "acero_stage_12":
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_vane.png")
            menu._commander_name_lbl.text = "MARSHALL KURTZ & FLEET ADMIRAL VANE"
            menu._commander_role_lbl.text = "Supreme Command // CNS Imperator (Colossus Juggernaut)"
            menu._briefing_title_lbl.text = "ACT III // STAGE 12: APEX OF THE CALM // THE FINAL DAM"
            menu._briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // DECISIVE CLIMAX OF THE STAR SEA"
            menu._commander_quote_lbl.text = "\"This is the end of retreat. The Calm Singularity opens before us. Marshall Kurtz has brought the Colossus Juggernaut Imperator to anchor the final dam. Obliterate all remaining hostiles. Steel triumphs!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Obliterate the unified alien and corsair armada at the Calm Singularity core.\n◆ SECONDARY OBJECTIVE: Ensure Supreme Flagship CNS Imperator remains combat operational.\n◆ FINAL DOCTRINE: The Colossus-Class Juggernaut boasts 600 HP, quad spinal heavy railguns, and impervious all-aspect armor!"
            add_squadron_row(menu._squadron_vbox, "acero_juggernaut", "CNS Imperator", "Colossus-Class Supreme Fortress • Marshall Kurtz", "HP 600 | RNG 68m | Quad Heavy Spinal Rail-Batteries")
            add_squadron_row(menu._squadron_vbox, "acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "acero_monitor", "CNS Crucible", "Crucible-Class Heavy Siege Monitor • Adm. Tarek", "HP 310 | RNG 64m | Heavy Plasma Mortar")
            add_squadron_row(menu._squadron_vbox, "acero_carrier", "CNS Forge-01", "Arsenal-Class Mobile Fleet Bastion • Cmdr. Vance", "HP 420 | RNG 48m | Fleet Defense & Flak Bastion")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH FINAL STAGE 12"

        _:
            menu._briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            menu._briefing_sub_lbl.text = "FACTION: THE ARMADA OF ACERO // SECTOR %02d" % cur_num
            menu._commander_quote_lbl.text = "\"All battle groups maintain disciplined vector formation. Angle heavy bow armor into incoming vector fire and execute synchronized broadsides.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Neutralize all hostile combatants in the assigned tactical sector.\n◆ SECONDARY OBJECTIVE: Maintain flagship integrity and achieve naval superiority."
            add_squadron_row(menu._squadron_vbox, "acero_dreadnought", "CNS Iron Bastion", "Anvil-Class Dreadnought • Adm. Vane", "HP 380 | RNG 58m | Forward & Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "acero_battlecruiser", "CNS Hammer of Anvil", "Hammer-Class Battlecruiser • Capt. Korr", "HP 260 | RNG 52m | Twin Spinal Railguns")
            add_squadron_row(menu._squadron_vbox, "acero_corvette", "CNS Vanguard-03", "Chisel-Class Escort Corvette • Lt. Drake", "HP 150 | RNG 44m | High-Speed Flank Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

static func populate_vinculados(menu: Control, stage_id: String) -> void:
    LoreDB.current_stage_id = stage_id

    for child in menu._stage_selector_row.get_children():
        child.queue_free()
    for child in menu._squadron_vbox.get_children():
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
            menu._populate_vinculados_stage_briefing(sid)
        )
        menu._stage_selector_row.add_child(btn)

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
    menu._briefing_art_rect.texture = art_tex

    menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_kaelen.png")
    menu._commander_name_lbl.text = "ACE PILOT KAELEN-7"
    menu._commander_role_lbl.text = "Lead Resonance Choir // Eidolon Ace Platoon" 

    match stage_id:
        "vinculados_stage_1":
            menu._briefing_title_lbl.text = "ACT II // STAGE 01 [TUTORIAL]: DEFENSE OF SANCTUARY SPIRE PSALM-4"
            menu._briefing_sub_lbl.text = "FACTION: THE VINCULADOS // HARMONIC DEFENSE & STERN RAKE TUTORIAL"
            menu._commander_quote_lbl.text = "\"Welcome to the Choir Wing, pilot. The Acero extraction force is encroaching upon Sanctuary Spire Psalm-4. Synchronize your neural frame with the Éther: our mobile suit platoons dance around their clumsy broadsides. Shield the Carrier Cradle, out-pivot their bulk, and strike their unarmored thrusters with critical Stern Rakes!\""
            _objectives_lbl.text = "◆ TUTORIAL DRILL 1 (SANCTUARY DEFENSE): Protect the levitating resonance crystals of Sanctuary Spire Psalm-4.\n◆ TUTORIAL DRILL 2 (MECHA MOBILITY & STERN RAKE): Use agile vector turns to slip behind Acero hulls (+40% critical damage).\n◆ PRIMARY OBJECTIVE: Intercept and neutralize the Acero strike force.\n◆ SECONDARY OBJECTIVE: Keep Carrier Ark Sanktuario Albor operational."
            add_squadron_row(menu._squadron_vbox, "vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam & PD Lasers")
            add_squadron_row(menu._squadron_vbox, "vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            add_squadron_row(menu._squadron_vbox, "vinculados_anima", "Anima-01 Interceptor Wing", "Anima Strike Platoon • Ace Mirei-4", "HP 115 | SPD 36 m/s | High-Speed Echelon Trio & Flank Intercept")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH TUTORIAL STAGE 01"

        "vinculados_stage_2":
            menu._briefing_title_lbl.text = "ACT II // STAGE 02: DIVE INTO THE CRYSTAL CHASM"
            menu._briefing_sub_lbl.text = "FACTION: THE VINCULADOS // VERTICAL ADVANTAGE & DIVE BOMBER TACTICS"
            menu._commander_quote_lbl.text = "\"Imperial dreadnoughts are crawling through the deep basalt canyon below to sever our crystal conduits. We hold the high celestial ground (+16m altitude advantage). Dive upon their top decks where their armor is weakest!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Dive from upper celestial ledge (+16m) and destroy all 3 Acero warships traversing the chasm trench below.\n◆ SECONDARY OBJECTIVE: Ensure Cradle Carrier Sanktuario Albor survives.\n◆ VERTICAL ADVANTAGE DOCTRINE: Firing down on lower altitude targets bypasses heavy belt armor (+20% Critical Hit)."
            add_squadron_row(menu._squadron_vbox, "vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam & PD Lasers")
            add_squadron_row(menu._squadron_vbox, "vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            add_squadron_row(menu._squadron_vbox, "vinculados_anima", "Anima-01 Interceptor Wing", "Anima Strike Platoon • Ace Mirei-4", "HP 115 | SPD 36 m/s | High-Speed Echelon Trio & Flank Intercept")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 02"

        "vinculados_stage_3":
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_vael.png")
            menu._commander_name_lbl.text = "ACE PILOT VAEL-09"
            menu._commander_role_lbl.text = "Nous Frame Synchronizer // Transcendence Gate"
            menu._briefing_title_lbl.text = "ACT II // STAGE 03: THE GENESIS RING // TRANSCENDENCE"
            menu._briefing_sub_lbl.text = "FACTION: THE VINCULADOS // NOUS FRAME ACTIVATION & GATE DEFENSE"
            menu._commander_quote_lbl.text = "\"The Calm has reached the outer perimeter of the Star Sea. Ace Vael has synchronized with the legendary Nous-09 frame. Hold the gate ring against the combined Acero and renegade corsair assault!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Defeat the reinforced Acero-Corsair assault fleet at the Genesis Ring.\n◆ SECONDARY OBJECTIVE: Ensure Carrier Sanktuario Albor and the Genesis Ring are protected.\n◆ PINNACLE ACE FRAME: Deploy the legendary Nous frame wielding autonomous resonance funnels and the Transcendent Mega-Buster!"
            add_squadron_row(menu._squadron_vbox, "vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam & PD Lasers")
            add_squadron_row(menu._squadron_vbox, "vinculados_nous", "Nous Transcendent Frame", "Prototype Transcendent Ace Frame • Ace Vael-09", "HP 220 | SPD 32 m/s | Autonomous Fin Funnels & Mega-Buster Beam")
            add_squadron_row(menu._squadron_vbox, "vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 03"

        "vinculados_stage_4", "vinculados_stage_5", "vinculados_stage_6", "vinculados_stage_7":
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_vael.png")
            menu._commander_name_lbl.text = "ACE PILOT VAEL-09"
            menu._commander_role_lbl.text = "Heavy Frame Vanguard // Nous & Psyche Wings"
            menu._briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            menu._briefing_sub_lbl.text = "FACTION: THE VINCULADOS // NEURAL RESONANCE INFILTRATION"
            menu._commander_quote_lbl.text = "\"The Choir expands. Deploy the Psyche Heavy Frame and Eidolon platoons in synchronized vector patterns. Let no intruder interrupt the song.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Clear all enemy interdictors from the resonance conduit.\n◆ SECONDARY OBJECTIVE: Maintain Carrier Ark Sanktuario Albor above 50% hull integrity.\n◆ TACTICAL TIP: Use fin funnels and resonance beams to bypass armored shields."
            add_squadron_row(menu._squadron_vbox, "vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam & PD Lasers")
            add_squadron_row(menu._squadron_vbox, "vinculados_psyche", "Psyche Heavy Frame", "Psycho-Resonance Frame • Ace Vael-09", "HP 240 | SPD 28 m/s | Heavy Resonance Beam Lance")
            add_squadron_row(menu._squadron_vbox, "vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            add_squadron_row(menu._squadron_vbox, "vinculados_anima", "Anima-01 Interceptor Wing", "Anima Strike Platoon • Ace Mirei-4", "HP 115 | SPD 36 m/s | High-Speed Echelon Trio")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "vinculados_stage_8", "vinculados_stage_9", "vinculados_stage_10", "vinculados_stage_11":
            menu._briefing_art_rect.texture = load("res://assets/ships/vinculados/mobile_armor_colossus.png")
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_orin.png")
            menu._commander_name_lbl.text = "ACE PILOT ORIN-9"
            menu._commander_role_lbl.text = "Seraph Mobile Armor Commander // High Choir"
            menu._briefing_title_lbl.text = "ACT III // STAGE %02d: %s" % [cur_num, stage_titles[cur_num - 1]]
            menu._briefing_sub_lbl.text = "FACTION: THE VINCULADOS // MOBILE ARMOR SYSTEM AWAKENING"
            menu._commander_quote_lbl.text = "\"The psychic resonance is reaching critical amplitude! The Mobile Armor Seraph awakens. We will pierce through the Calm with pure harmonic will.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Annihilate the hostile fleet guarding the harmonic siphon.\n◆ SECONDARY OBJECTIVE: Keep the Mobile Armor and Carrier Ark synchronized.\n◆ MOBILE ARMOR DOCTRINE: Colossus Seraph-Prime unleashes twin mega-particle beams and autonomous funnel barrages."
            add_squadron_row(menu._squadron_vbox, "vinculados_colossus", "Seraph-Prime", "Colossus Mobile Armor • Ace Orin-9", "HP 500 | SPD 26 m/s | Twin Spinal Mega-Beams & Funnel Array")
            add_squadron_row(menu._squadron_vbox, "vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam")
            add_squadron_row(menu._squadron_vbox, "vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            add_squadron_row(menu._squadron_vbox, "vinculados_chorus", "Chorus Screen Wing", "Light Mecha Flotilla • Ace Vael-09", "HP 130 | SPD 34 m/s | Quad Light Drone Formation")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "vinculados_stage_12":
            menu._briefing_art_rect.texture = load("res://assets/ships/vinculados/mobile_armor_colossus.png")
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_orin.png")
            menu._commander_name_lbl.text = "HIGH CONDUCTOR & ACE ORIN-9"
            menu._commander_role_lbl.text = "Transcendence Choir // The Apex Harmonizer"
            menu._briefing_title_lbl.text = "ACT III // STAGE 12: TRANSCENDENCE NEXUS // THE FINAL HYMN"
            menu._briefing_sub_lbl.text = "FACTION: THE VINCULADOS // SOUL ASCENSION BEYOND THE CALM"
            menu._commander_quote_lbl.text = "\"This is the final threshold of physical space. Our minds are one with the Éther. Awaken every resonance funnel, open the mega-beam manifolds, and transcend the dying sea!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Neutralize the supreme imperial siege fleet at the Transcendence Nexus.\n◆ SECONDARY OBJECTIVE: Protect Mobile Armor Seraph-Prime through the ascension climax.\n◆ FINAL TRANSCENDENCE: Coordinate high-speed mecha platoons and colossal mobile armor funnels for maximum synchronization!"
            add_squadron_row(menu._squadron_vbox, "vinculados_colossus", "Seraph-Prime", "Colossus Mobile Armor • Ace Orin-9", "HP 500 | SPD 26 m/s | Twin Spinal Mega-Beams & Funnel Array")
            add_squadron_row(menu._squadron_vbox, "vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Resonance Mega-Beam")
            add_squadron_row(menu._squadron_vbox, "vinculados_psyche", "Psyche Heavy Frame", "Psycho-Resonance Frame • Ace Vael-09", "HP 240 | SPD 28 m/s | Heavy Resonance Beam Lance")
            add_squadron_row(menu._squadron_vbox, "vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation, Beam Carbine & Shield")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH FINAL STAGE 12"

        _:
            menu._briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            menu._briefing_sub_lbl.text = "FACTION: THE VINCULADOS // SECTOR %02d" % cur_num
            menu._commander_quote_lbl.text = "\"Synchronize neural telemetry. Out-pivot the enemy, ride the upwind vector, and strike from unexpected angles.\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Clear all hostile warships from the operational grid.\n◆ SECONDARY OBJECTIVE: Protect the Carrier Cradle and maintain flight cohesion."
            add_squadron_row(menu._squadron_vbox, "vinculados_cradle", "Sanktuario Albor", "Cradle-Class Carrier Ark • Conductor Seraph-2", "HP 250 | SPD 19 m/s | Spinal Mega-Beam")
            add_squadron_row(menu._squadron_vbox, "vinculados_suit", "Eidolon Ace Wing", "Eidolon Mobile Suit Platoon • Ace Kaelen-7", "HP 160 | SPD 30 m/s | Trio Formation")
            add_squadron_row(menu._squadron_vbox, "vinculados_anima", "Anima-01 Interceptor Wing", "Anima Strike Platoon • Ace Mirei-4", "HP 115 | SPD 36 m/s | Echelon Trio")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

static func populate_marea(menu: Control, stage_id: String) -> void:
    LoreDB.current_stage_id = stage_id

    for child in menu._stage_selector_row.get_children():
        child.queue_free()
    for child in menu._squadron_vbox.get_children():
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
            menu._populate_marea_stage_briefing(sid)
        )
        menu._stage_selector_row.add_child(btn)

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
    menu._briefing_art_rect.texture = art_tex

    menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_solano.png")
    menu._commander_name_lbl.text = "CAPTAIN SOLANO"
    menu._commander_role_lbl.text = "Corsair Flagship // Viento Rojo" 

    match stage_id:
        "marea_stage_1":
            menu._briefing_title_lbl.text = "ACT III // STAGE 01 [TUTORIAL]: RUNNING THE BASALT NARROWS"
            menu._briefing_sub_lbl.text = "FACTION: THE FREE TIDE // CANYON GORGE RUN & BARLOVENTO TUTORIAL"
            menu._commander_quote_lbl.text = "\"Listen up, sea dogs! We're navigating the Basalt Narrows—a treacherous asteroid gorge where Acero pickets try to box us in. Ride the raging cyan rush of El Río del Viento, claim the Weather-Gauge [BARLOVENTO], and smash their blockade with crushing broadside volleys!\""
            _objectives_lbl.text = "◆ TUTORIAL DRILL 1 (THE BASALT NARROWS): Navigate the dense canyon gorge; don't collide with basalt spires.\n◆ TUTORIAL DRILL 2 (EL RÍO DEL VIENTO): Catch the high-velocity Éther stream for massive forward speed boosts.\n◆ TUTORIAL DRILL 3 (WEATHER-GAUGE [BARLOVENTO]): Attack from upwind for +12% Hit accuracy, unleashing +18% port/starboard broadsides.\n◆ PRIMARY OBJECTIVE: Break through the Acero blockade picket and secure the Corsair Haven.\n◆ SECONDARY OBJECTIVE: Keep Corsair Flagship Viento Rojo afloat."
            add_squadron_row(menu._squadron_vbox, "marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 300 | RNG 50m | Quantum Sails & Broadsides")
            add_squadron_row(menu._squadron_vbox, "marea_raider", "La Descarada", "Corsair Raider Galleon • Quartermaster Vael", "HP 210 | RNG 46m | Fast Broadside Raider")
            add_squadron_row(menu._squadron_vbox, "marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH TUTORIAL STAGE 01"

        "marea_stage_2":
            menu._briefing_title_lbl.text = "ACT III // STAGE 02: RAID ON FOUNDRY COMPLEX VULCAN-3"
            menu._briefing_sub_lbl.text = "FACTION: THE FREE TIDE // INDUSTRIAL RAID & CHOKEPOINT AMBUSH"
            menu._commander_quote_lbl.text = "\"Well done through the narrows! Now we strike the Imperial heart. The Acero smelter refinery Vulcan-3 is pumping stolen Éther into heavy battlecruisers. Slip behind the smelter platforms, use the industrial pylons as cover against their long-range railguns, and board their supply silos!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Destroy the Acero defense garrison guarding Smelter Vulcan-3.\n◆ SECONDARY OBJECTIVE: Ensure Corsair Flagship Viento Rojo survives the raid.\n◆ TERRAIN ADVANTAGE: Industrial refinery gantries and slag funnels block direct railgun lines-of-fire."
            add_squadron_row(menu._squadron_vbox, "marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 300 | RNG 50m | Quantum Sails & Broadsides")
            add_squadron_row(menu._squadron_vbox, "marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            add_squadron_row(menu._squadron_vbox, "marea_raider", "La Descarada", "Corsair Raider Galleon • Quartermaster Vael", "HP 210 | RNG 46m | Fast Broadside Raider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 02"

        "marea_stage_3":
            menu._briefing_title_lbl.text = "ACT III // STAGE 03: THE MAELSTROM OF BARLOVENTO"
            menu._briefing_sub_lbl.text = "FACTION: THE FREE TIDE // THE GREAT SOL CORONA & STORM SURFING"
            menu._commander_quote_lbl.text = "\"Look at the sky, corsairs! The Great Sol Corona is whipping the Éther into the mother of all storms—the Maelstrom of Barlovento! Unfurl every quantum sail! Catch the vortex, claim the Weather-Gauge, and blast them into cosmic dust!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Annihilate the Imperial Supreme Suppression Battlegroup.\n◆ SECONDARY OBJECTIVE: Ensure Flagship Viento Rojo survives the final storm engagement.\n◆ MAELSTROM WINDS: High-velocity orbital currents grant unmatched drift speed and maximum Barlovento broadside modifiers!"
            add_squadron_row(menu._squadron_vbox, "marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 360 | RNG 50m | Quantum Sails & Heavy Broadsides")
            add_squadron_row(menu._squadron_vbox, "marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            add_squadron_row(menu._squadron_vbox, "marea_raider", "La Descarada", "Corsair Raider Galleon • Quartermaster Vael", "HP 210 | RNG 46m | Fast Broadside Raider")
            add_squadron_row(menu._squadron_vbox, "marea_raider", "Viento Furioso", "Corsair Strike Raider • Bosun Drake", "HP 210 | RNG 46m | High-Velocity Skirmisher")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE 03"

        "marea_stage_4", "marea_stage_5", "marea_stage_6", "marea_stage_7":
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_marina.png")
            menu._commander_name_lbl.text = "COMMODORE MARINA \"LA TORMENTA\""
            menu._commander_role_lbl.text = "Corsair Flotilla Commander // Tormenta Negra"
            menu._briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            menu._briefing_sub_lbl.text = "FACTION: THE FREE TIDE // CORSAIR GUERRILLA CAMPAIGN"
            menu._commander_quote_lbl.text = "\"Catch the wind and don't give the Armada an inch to aim! Slip through the reefs, unleash broadside chain-shot, and bleed their heavy lines dry!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Ambush and eliminate the imperial patrol vanguard.\n◆ SECONDARY OBJECTIVE: Keep all corsair vessels moving at high momentum to evade return broadsides.\n◆ SAIL TECHNIQUE: Quantum sails generate free momentum when running before the Éther gale."
            add_squadron_row(menu._squadron_vbox, "marea_galleon", "Tormenta Negra", "Armored Void-Galleon • Cmdr. Marina", "HP 340 | RNG 52m | Heavy Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "marea_frigate", "Sirena Libre", "Quantum Frigate • Capt. Moreau", "HP 220 | RNG 48m | High-Velocity Broadside Frigate")
            add_squadron_row(menu._squadron_vbox, "marea_cutter", "Flecha Veloz", "Corsair Cutter • Bosun Drake", "HP 140 | RNG 40m | Agile Flank Skirmisher")
            add_squadron_row(menu._squadron_vbox, "marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "marea_stage_8", "marea_stage_9", "marea_stage_10", "marea_stage_11":
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_marina.png")
            menu._commander_name_lbl.text = "COMMODORE MARINA & CAPTAIN SOLANO"
            menu._commander_role_lbl.text = "United Corsair Fleet // Grand Armada"
            menu._briefing_title_lbl.text = "ACT III // STAGE %02d: %s" % [cur_num, stage_titles[cur_num - 1]]
            menu._briefing_sub_lbl.text = "FACTION: THE FREE TIDE // ASSAULT ON THE IMPERIAL REDOUBTS"
            menu._commander_quote_lbl.text = "\"Every free captain in the Star Sea answers the call! We've brought the heavy Bombards and the dread Galleons. Shatter their sluices and drown their dreadnoughts in the gale!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Breach the imperial heavy citadel defense perimeter.\n◆ SECONDARY OBJECTIVE: Keep the siege bombard in position to dismantle enemy fortifications.\n◆ BOMBARD TACTICS: The Corsair Bombard launches devastating plasma mortars across the storm sea."
            add_squadron_row(menu._squadron_vbox, "marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 360 | RNG 50m | Quantum Sails & Heavy Broadsides")
            add_squadron_row(menu._squadron_vbox, "marea_bombard", "Voz del Trueno", "Heavy Corsair Bombard • Quartermaster Vael", "HP 290 | RNG 62m | Long-Range Plasma Siege Mortar")
            add_squadron_row(menu._squadron_vbox, "marea_frigate", "Sirena Libre", "Quantum Frigate • Cmdr. Marina", "HP 220 | RNG 48m | Broadside Batteries")
            add_squadron_row(menu._squadron_vbox, "marea_cutter", "Flecha Veloz", "Corsair Cutter • Bosun Drake", "HP 140 | RNG 40m | Fast Screen")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

        "marea_stage_12":
            menu._commander_portrait_rect.texture = load("res://assets/heroes/ace_solano.png")
            menu._commander_name_lbl.text = "ADMIRAL OF THE FREE TIDE SOLANO"
            menu._commander_role_lbl.text = "Flagship Commander // The Void Leviathan"
            menu._briefing_title_lbl.text = "ACT III // STAGE 12: LIBERATION OF THE STAR SEA // THE FINAL GALE"
            menu._briefing_sub_lbl.text = "FACTION: THE FREE TIDE // THE FINAL BATTLE FOR THE WEATHER GAUGE"
            menu._commander_quote_lbl.text = "\"Brothers and sisters of the Free Tide! Beyond this fleet lies the eternal gale. The Armada has anchored their greatest iron titans to strangle the sea, but the wind cannot be chained! With the Void Leviathan leading the line, unfurl all quantum sails! Ride the apex storm and claim BARLOVENTO!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Annihilate the Supreme Imperial Flagship and liberate the Star Sea.\n◆ SECONDARY OBJECTIVE: Ensure Corsair Leviathan and Viento Rojo survive the final battle.\n◆ ULTIMATE CORSAIR POWER: The Void Leviathan brings 520 HP, 6-sail quantum rigging, and dual heavy bombard broadsides!"
            add_squadron_row(menu._squadron_vbox, "marea_leviathan", "El Gran Leviatán", "Colossal Corsair Void Leviathan • Adm. Solano", "HP 520 | RNG 60m | 6-Sail Rigging, Dual Bombards & Broadsides")
            add_squadron_row(menu._squadron_vbox, "marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Cmdr. Marina", "HP 360 | RNG 50m | Quantum Sails & Broadsides")
            add_squadron_row(menu._squadron_vbox, "marea_bombard", "Voz del Trueno", "Heavy Corsair Bombard • Quartermaster Vael", "HP 290 | RNG 62m | Heavy Siege Mortar")
            add_squadron_row(menu._squadron_vbox, "marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH FINAL STAGE 12"

        _:
            menu._briefing_title_lbl.text = "%s // STAGE %02d: %s" % [act_str, cur_num, stage_titles[cur_num - 1]]
            menu._briefing_sub_lbl.text = "FACTION: THE FREE TIDE // SECTOR %02d" % cur_num
            menu._commander_quote_lbl.text = "\"Unfurl sails, ride the current, and bring our broadsides to bear!\""
            _objectives_lbl.text = "◆ PRIMARY OBJECTIVE: Defeat all hostile combatants in this sector.\n◆ SECONDARY OBJECTIVE: Protect the fleet and maintain high momentum."
            add_squadron_row(menu._squadron_vbox, "marea_galleon", "Viento Rojo", "Corsair Void-Galleon • Capt. Solano", "HP 300 | RNG 50m | Quantum Sails & Broadsides")
            add_squadron_row(menu._squadron_vbox, "marea_raider", "La Descarada", "Corsair Raider Galleon • Quartermaster Vael", "HP 210 | RNG 46m | Fast Broadside Raider")
            add_squadron_row(menu._squadron_vbox, "marea_brigantine", "Brisa Negra", "Corsair Void-Brigantine • Capt. Moreau", "HP 180 | RNG 44m | Harpoon Outrider")
            if _launch_stage_btn != null: _launch_stage_btn.text = "⚔  SOUND BATTLE STATIONS // LAUNCH STAGE %02d" % cur_num

