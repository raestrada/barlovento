extends Control

const MAIN_MENU_PATH := "res://scenes/menu/main_menu.tscn"
const LOGO_PATH := "res://assets/brand/logo.png"

const BASE_SCROLL_SPEED := 44.0
const FAST_SCROLL_SPEED := 140.0
const REWIND_SCROLL_SPEED := -60.0
const SLIDE_DURATION := 7.0
const SLIDE_CROSSFADE := 1.5

class SlideData:
	var path: String
	var title: String
	var caption: String

var _slides: Array[Dictionary] = []
var _current_slide_idx: int = 0
var _slide_timer: float = 0.0

var _slide_rect_a: TextureRect
var _slide_rect_b: TextureRect
var _slide_container: Control
var _active_rect_is_a: bool = true
var _slide_title_lbl: Label
var _slide_caption_lbl: Label

var _scroll_container: Control
var _credits_content: VBoxContainer
var _scroll_pos_y: float = 0.0
var _is_fast_forward: bool = false
var _is_rewind: bool = false
var _transitioning: bool = false
var _ended_hold_timer: float = 0.0

var _fade_rect: ColorRect
var _skip_btn: Button
var _faction_theme_color: Color = Color(0.3, 0.85, 1.0)
var _faction_key: String = "acero"

func _ready() -> void:
	_resolve_faction()
	_setup_slides_for_faction()
	_build_ui()
	_start_music()
	_display_slide(0, false)

func _resolve_faction() -> void:
	var cur_stage := LoreDB.current_stage_id
	if cur_stage.begins_with("vinculados"):
		_faction_key = "vinculados"
	elif cur_stage.begins_with("marea"):
		_faction_key = "marea_libre"
	elif cur_stage.begins_with("acero"):
		_faction_key = "acero"
	elif LoreDB.selected_faction != "":
		_faction_key = LoreDB.selected_faction
	else:
		_faction_key = "acero"

	match _faction_key:
		"acero":
			_faction_theme_color = Color(1.0, 0.78, 0.28) # Imperial Gold
		"vinculados":
			_faction_theme_color = Color(0.4, 0.95, 0.85) # Resonant Cyan
		"marea_libre":
			_faction_theme_color = Color(0.35, 0.82, 1.0) # Sovereign Ether Azure

func _setup_slides_for_faction() -> void:
	_slides.clear()
	match _faction_key:
		"vinculados":
			_slides.append({
				"path": "res://assets/epilogue/vinculados_ending.png",
				"title": "THE GREAT ASCENSION // CAMPAIGN EPILOGUE",
				"caption": "The mortal boundary dissolves. Consciousness merges with the infinite choir of the Star Sea."
			})
			_slides.append({
				"path": "res://assets/briefings/vinculados_ascension.png",
				"title": "CATHEDRAL OF HARMONICS // SANCTUARY PRIME",
				"caption": "Resonance spires sing across the void, stabilizing the dying Ether with living thought."
			})
			_slides.append({
				"path": "res://assets/cinematics/act3_climax.png",
				"title": "THE FINAL CONCORD // HARMONIC OVERLOAD",
				"caption": "Seraph Prime unleashed the synchronized will of ten thousand awakened pilots."
			})
			_slides.append({
				"path": "res://assets/briefings/vinculados_genesis.png",
				"title": "THE GENESIS RING // CRADLE OF SOULS",
				"caption": "Where the first mobile frames learned to navigate the songs of the stellar winds."
			})
			_slides.append({
				"path": "res://assets/heroes/ace_kaelen.png",
				"title": "FIRST CHOIR COMMANDER // ACE KAELEN",
				"caption": "Veteran pilot of Seraph Prime, whose mind held the nexus together until ascension."
			})
			_slides.append({
				"path": "res://assets/ships/vinculados/mobile_armor_colossus.png",
				"title": "SUPREME MOBILE SUIT // SERAPH COLOSSUS",
				"caption": "A neural-coupled titan of light, undefeated across twelve tactical engagements."
			})
		"marea_libre":
			_slides.append({
				"path": "res://assets/epilogue/marea_ending.png",
				"title": "SOVEREIGN OF THE STAR SEA // CAMPAIGN EPILOGUE",
				"caption": "The imperial chains are broken. The Star Sea belongs to those daring enough to sail her."
			})
			_slides.append({
				"path": "res://assets/briefings/marea_soberano.png",
				"title": "FLAGSHIP EL SOBERANO // QUEEN OF WINDS",
				"caption": "Triple-deck solar broadsides and full quantum rig that humbled imperial dreadnoughts."
			})
			_slides.append({
				"path": "res://assets/cinematics/act3_climax.png",
				"title": "THE MAELSTROM BROADSIDE // FLEET LIBERATION",
				"caption": "Carving through the eye of the storm with the weather gauge firmly held."
			})
			_slides.append({
				"path": "res://assets/briefings/marea_maelstrom.png",
				"title": "EYE OF THE MAELSTROM // UNTAMED ETHER",
				"caption": "The roaring heart of the Star Sea where corsair kings are crowned in fire."
			})
			_slides.append({
				"path": "res://assets/heroes/ace_solano.png",
				"title": "CORSAIR CAPTAIN // SOLANO DEL MAR",
				"caption": "Master tactician of the Free Tide, who navigated the impossible vector currents."
			})
			_slides.append({
				"path": "res://assets/ships/marea-libre/galleon_concept.png",
				"title": "CORSAIR BATTLE GALLEON // TIDE RUNNER",
				"caption": "Agile, heavily armed, and bound to no flag but the freedom of the stellar wind."
			})
		_: # Acero
			_slides.append({
				"path": "res://assets/epilogue/acero_ending.png",
				"title": "THE IRON DAM SEALED // CAMPAIGN EPILOGUE",
				"caption": "The creeping frost of The Calm is permanently halted by discipline, order, and steel."
			})
			_slides.append({
				"path": "res://assets/briefings/acero_dam.png",
				"title": "THE CITADEL DAM // BASTION OF ORDER",
				"caption": "A megastructure anchoring galactic ether sluices to fuel the orbital foundries."
			})
			_slides.append({
				"path": "res://assets/cinematics/act3_climax.png",
				"title": "THE FINAL STAND // APEX OF STEEL",
				"caption": "CNS Crucible and the Imperial 1st Battlefleet holding the event horizon."
			})
			_slides.append({
				"path": "res://assets/briefings/acero_forge.png",
				"title": "SMELTER VULCAN-3 // FIRES OF ANVIL",
				"caption": "Where dreadnought armor plates are forged in continuous fusion crucibles."
			})
			_slides.append({
				"path": "res://assets/heroes/ace_vane.png",
				"title": "FLEET ADMIRAL // ARTHUR VANE",
				"caption": "Supreme commander whose iron doctrine steered the Armada to absolute victory."
			})
			_slides.append({
				"path": "res://assets/ships/acero/dreadnought_concept.png",
				"title": "DREADNOUGHT CLASS // CNS ANVIL",
				"caption": "Two kilometers of composite tungsten armor and spinal mass-accelerators."
			})

func _build_ui() -> void:
	# 1. Base dark cosmic background
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.008, 0.012, 0.022, 1.0)
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)

	# Optional backdrop texture
	if ResourceLoader.exists("res://assets/splash/cover.png"):
		var bg_tex := TextureRect.new()
		bg_tex.texture = load("res://assets/splash/cover.png")
		bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_tex.modulate = Color(0.12, 0.16, 0.22, 0.35)
		add_child(bg_tex)

	# 2. Main split screen container
	var main_split := HBoxContainer.new()
	main_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_split.add_theme_constant_override("separation", 24)
	add_child(main_split)

	# Left: Cinematic Visuals Showcase (54% width)
	_build_cinematic_showcase(main_split)

	# Right: Scrolling Movie Credits Roll (46% width)
	_build_credits_roll(main_split)

	# 3. Top and bottom cinematic letterbox bars
	var top_bar := ColorRect.new()
	top_bar.color = Color(0.005, 0.008, 0.014, 0.95)
	top_bar.custom_minimum_size = Vector2(0, 36)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top_bar)

	var top_hdr := Label.new()
	top_hdr.text = "★ BARLOVENTO // OFFICIAL CAMPAIGN CHRONICLES & CREDITS ★"
	top_hdr.add_theme_font_size_override("font_size", 11)
	top_hdr.add_theme_color_override("font_color", _faction_theme_color)
	top_hdr.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	top_bar.add_child(top_hdr)

	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0.005, 0.008, 0.014, 0.95)
	bottom_bar.custom_minimum_size = Vector2(0, 48)
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(bottom_bar)

	var controls_hint := Label.new()
	controls_hint.text = "CONTROLS: [W / UP] REWIND  |  [S / DOWN] FAST-FORWARD  |  [ESC / SPACE] SKIP"
	controls_hint.add_theme_font_size_override("font_size", 11)
	controls_hint.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	controls_hint.position = Vector2(24, 16)
	bottom_bar.add_child(controls_hint)

	_skip_btn = Button.new()
	_skip_btn.text = "RETURN TO FLEET COMMAND ▶"
	_skip_btn.custom_minimum_size = Vector2(230, 34)
	_skip_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_btn.position = Vector2(-250, -41)
	_skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_skip_btn.pressed.connect(_on_skip_pressed)
	bottom_bar.add_child(_skip_btn)

	# Style skip button
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.06, 0.12, 0.22, 0.9)
	btn_sb.border_color = _faction_theme_color
	btn_sb.set_border_width_all(1)
	btn_sb.set_corner_radius_all(4)
	btn_sb.set_content_margin_all(6)
	_skip_btn.add_theme_stylebox_override("normal", btn_sb)

	var btn_hover_sb := StyleBoxFlat.new()
	btn_hover_sb.bg_color = Color(0.12, 0.24, 0.42, 0.95)
	btn_hover_sb.border_color = Color(1.0, 1.0, 1.0, 0.95)
	btn_hover_sb.set_border_width_all(1)
	btn_hover_sb.set_corner_radius_all(4)
	btn_hover_sb.set_content_margin_all(6)
	_skip_btn.add_theme_stylebox_override("hover", btn_hover_sb)

	# 4. Fade transition overlay
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	var t := create_tween()
	t.tween_property(_fade_rect, "modulate:a", 0.0, 1.2)

func _build_cinematic_showcase(parent: HBoxContainer) -> void:
	var left_wrap := MarginContainer.new()
	left_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_wrap.size_flags_stretch_ratio = 1.15
	left_wrap.add_theme_constant_override("margin_left", 36)
	left_wrap.add_theme_constant_override("margin_top", 50)
	left_wrap.add_theme_constant_override("margin_bottom", 56)
	left_wrap.add_theme_constant_override("margin_right", 12)
	parent.add_child(left_wrap)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	left_wrap.add_child(vbox)

	# Framed image container with clipping
	_slide_container = PanelContainer.new()
	_slide_container.clip_contents = true
	_slide_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.02, 0.03, 0.05, 1.0)
	panel_sb.border_color = _faction_theme_color * 0.7
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(6)
	_slide_container.add_theme_stylebox_override("panel", panel_sb)
	vbox.add_child(_slide_container)

	# Stacked slides for crossfade
	_slide_rect_a = TextureRect.new()
	_slide_rect_a.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slide_rect_a.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_slide_rect_a.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_slide_rect_a.pivot_offset = Vector2(300, 200)
	_slide_container.add_child(_slide_rect_a)

	_slide_rect_b = TextureRect.new()
	_slide_rect_b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slide_rect_b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_slide_rect_b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_slide_rect_b.modulate.a = 0.0
	_slide_rect_b.pivot_offset = Vector2(300, 200)
	_slide_container.add_child(_slide_rect_b)

	# Inner cinematic vignette shadow
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0.01, 0.02, 0.04, 0.25)
	_slide_container.add_child(vignette)

	# Caption banner below art
	var caption_box := VBoxContainer.new()
	caption_box.add_theme_constant_override("separation", 4)
	vbox.add_child(caption_box)

	_slide_title_lbl = Label.new()
	_slide_title_lbl.text = "CAMPAIGN CONQUERED"
	_slide_title_lbl.add_theme_font_size_override("font_size", 14)
	_slide_title_lbl.add_theme_color_override("font_color", _faction_theme_color)
	caption_box.add_child(_slide_title_lbl)

	_slide_caption_lbl = Label.new()
	_slide_caption_lbl.text = "..."
	_slide_caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slide_caption_lbl.add_theme_font_size_override("font_size", 12)
	_slide_caption_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.96))
	caption_box.add_child(_slide_caption_lbl)

func _build_credits_roll(parent: HBoxContainer) -> void:
	var right_wrap := MarginContainer.new()
	right_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_wrap.size_flags_stretch_ratio = 1.0
	right_wrap.add_theme_constant_override("margin_left", 12)
	right_wrap.add_theme_constant_override("margin_top", 44)
	right_wrap.add_theme_constant_override("margin_bottom", 54)
	right_wrap.add_theme_constant_override("margin_right", 36)
	parent.add_child(right_wrap)

	# Scroll viewport with clipping
	_scroll_container = Control.new()
	_scroll_container.clip_contents = true
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_wrap.add_child(_scroll_container)

	_credits_content = VBoxContainer.new()
	_credits_content.custom_minimum_size = Vector2(440, 0)
	_credits_content.add_theme_constant_override("separation", 22)
	_scroll_container.add_child(_credits_content)

	# Fill content
	_populate_credits_text()

	# Initial scroll position below the bottom of the screen
	_scroll_pos_y = 650.0
	_credits_content.position.y = _scroll_pos_y

func _populate_credits_text() -> void:
	# 1. Canonical Logo Image
	if ResourceLoader.exists(LOGO_PATH):
		var logo_rect := TextureRect.new()
		logo_rect.texture = load(LOGO_PATH)
		logo_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.custom_minimum_size = Vector2(360, 90)
		_credits_content.add_child(logo_rect)

	_add_credit_header("A 3D TURN-BASED NAVAL SPACE STRATEGY ODYSSEY", Color(0.7, 0.85, 1.0), 13)
	_add_credit_divider()

	# 2. Grand Campaign Victory Declaration
	var fac_name := ""
	var fac_sub := ""
	var epilogue_story := ""
	match _faction_key:
		"vinculados":
			fac_name = "THE VINCULADOS"
			fac_sub = "VICTORY OF TRANSCENDENCE & SOUL"
			epilogue_story = "The mortal horizon has shattered into ten thousand radiant chords.\n\nThrough twelve trials of fire and faith, the neural chorus held unison against imperial iron and corsair fury. Seraph Prime crossed the dying threshold of the material void, pulling the entire civilization into the infinite Ether sea.\n\nHere, beyond the frost of The Calm, every mind sings in eternal harmony. The hymn of the Vinculados shall never be silenced."
		"marea_libre":
			fac_name = "THE FREE TIDE // MAREA LIBRE"
			fac_sub = "SOVEREIGNTY OF THE STAR SEA"
			epilogue_story = "The weather gauge is claimed for eternity!\n\nFrom the Basalt Narrows to the Eye of the Maelstrom, the corsair squadrons of the Free Tide shattered every imperial sluice lock and blockade. The Star Sea roars with unbounded wind once more.\n\nNo emperor, no dam, and no false peace shall bind the tides. So long as ships have sails and captains have courage, we fly the black banner in the roaring light."
		_:
			fac_name = "THE ARMADA OF ACERO"
			fac_sub = "TRIUMPH OF HUMAN WILL & ENDURING STEEL"
			epilogue_story = "The great Iron Dam stands sealed against the edge of nothingness.\n\nThrough vector discipline, broadside mass-drivers, and unyielding order, Admiral Vane and the Imperial 1st Fleet held the Calm Rift. The spreading decay of the void is halted.\n\nThe orbital foundries of Anvil burn with unquenchable fire, forging a thousand-year peace built upon titanium, law, and steel."

	_add_credit_header("🏆 CAMPAIGN CONQUERED 🏆", Color(1.0, 0.85, 0.3), 16)
	_add_credit_header(fac_name, _faction_theme_color, 20)
	_add_credit_header(fac_sub, Color(0.9, 0.95, 1.0), 12)
	_add_credit_body(epilogue_story)
	_add_credit_divider()

	# 3. Legendary Ace Roster
	_add_credit_header("LEGENDARY ACE SQUADRON", _faction_theme_color, 16)
	match _faction_key:
		"vinculados":
			_add_credit_pair("Ace Commander Kaelen", "Flagship: Seraph Prime // Neural Harmony Link")
			_add_credit_pair("Navigator Lyra", "Support Cruiser: Psalm-9 // Kinetic Aegis Weaver")
			_add_credit_pair("Chorus Mirei", "Resonance Carrier: Genesis Ring // Choir Synchronizer")
			_add_credit_pair("Pilot Vance", "Colossus Escort: Vanguard Echo // Lance of Dawn")
		"marea_libre":
			_add_credit_pair("Captain Solano del Mar", "Flagship: El Soberano // Three-Deck Dreadnought")
			_add_credit_pair("Corsair Jax", "Fast Skiff: Viento Bravo // Torpedo Broadside Ace")
			_add_credit_pair("Quartermaster Marina", "Boarding Frigate: Sirena // Storm Sail Master")
			_add_credit_pair("Old Man Barbanegra", "Heavy Galleon: El Vengador // Kinetic Siege Cannon")
		_:
			_add_credit_pair("Fleet Admiral Arthur Vane", "Flagship: CNS Anvil // Heavy Dreadnought")
			_add_credit_pair("Commander Kurtz", "Battlecruiser: CNS Crucible // High-Density Railgun")
			_add_credit_pair("Lieutenant Moreau", "Picket Destroyer: CNS Ironwatch // Point Defense Grid")
			_add_credit_pair("Chief Engineer Drake", "Repair Tender: Vulcan Sluice // Reactor Overcharger")

	_add_credit_divider()

	# 4. Campaign Conquest Ledger
	_add_credit_header("THE TWELVE THEATERS OF WAR", _faction_theme_color, 15)
	_add_credit_pair("Act I: The Gathering Storm", "Stages 01 - 04 // Sector Pickets Secured")
	_add_credit_pair("Act II: The Crucible of War", "Stages 05 - 08 // Smelters & Sanctuaries Held")
	_add_credit_pair("Act III: The Event Horizon", "Stages 09 - 12 // The Final Rift Conquered")
	_add_credit_body("All 12 strategic sectors successfully pacified under your command.")
	_add_credit_divider()

	# 5. Technology & Architecture
	_add_credit_header("DEVELOPMENT & ARCHITECTURE", _faction_theme_color, 15)
	_add_credit_pair("Game Design & Programming", "Google DeepMind Antigravity")
	_add_credit_pair("Project Lead & Director", "Rodrigo Estrada")
	_add_credit_pair("Simulation Engine", "Godot Engine 4.7.2 Forward+")
	_add_credit_pair("Tactical Ballistics", "WEGO Simultaneous Vector Simulation")
	_add_credit_pair("Procedural Graphics", "Custom Forward+ PBR & Star Sea Shaders")
	_add_credit_divider()

	# 6. Symphonic Score
	_add_credit_header("ORCHESTRAL SOUNDTRACK", _faction_theme_color, 15)
	_add_credit_pair("Campaign Climax", "Antonín Dvořák — Symphony No. 9 'From the New World' IV. Allegro con fuoco")
	_add_credit_pair("Armada of Acero March", "Gustav Holst — Mars, the Bringer of War")
	_add_credit_pair("The Free Tide Anthem", "Gustav Holst — Jupiter, the Bringer of Jollity")
	_add_credit_pair("The Vinculados Choir", "Gustav Holst — Uranus, the Magician")
	_add_credit_pair("Ace Tactical Dogfight", "Gustav Holst — Mercury, the Winged Messenger")
	_add_credit_pair("Stellar Ambience", "Gustav Holst — Venus, the Bringer of Peace")
	_add_credit_divider()

	# 7. Special Thanks
	_add_credit_header("SPECIAL THANKS", _faction_theme_color, 16)
	_add_credit_body("To every player who stood on the bridge, adjusted the vector headings, and navigated the uncharted currents of the Star Sea.")
	_add_credit_body("Your fleet endures across the stars.")
	_add_credit_divider()

	# 8. Final canonical wordmark closing
	if ResourceLoader.exists(LOGO_PATH):
		var end_logo := TextureRect.new()
		end_logo.texture = load(LOGO_PATH)
		end_logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		end_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		end_logo.custom_minimum_size = Vector2(300, 75)
		_credits_content.add_child(end_logo)

	_add_credit_header("THANK YOU FOR PLAYING", Color(1.0, 0.88, 0.35), 18)
	_add_credit_body("A production of Antigravity & Rodrigo Estrada\n2026")

	# Extra bottom padding
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 160)
	_credits_content.add_child(pad)

func _add_credit_header(text: String, col: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	_credits_content.add_child(l)

func _add_credit_body(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.85, 0.90, 0.96))
	_credits_content.add_child(l)

func _add_credit_pair(role: String, name_txt: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var r := Label.new()
	r.text = role.to_upper()
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_theme_font_size_override("font_size", 11)
	r.add_theme_color_override("font_color", _faction_theme_color * 0.9)
	box.add_child(r)

	var n := Label.new()
	n.text = name_txt
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.add_theme_font_size_override("font_size", 13)
	n.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(n)

	_credits_content.add_child(box)

func _add_credit_divider() -> void:
	var d := Label.new()
	d.text = "✦   ───   ❖   ───   ✦"
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.add_theme_font_size_override("font_size", 10)
	d.add_theme_color_override("font_color", _faction_theme_color * 0.5)
	_credits_content.add_child(d)

func _start_music() -> void:
	AudioManager.crossfade_to(AudioManager.BATTLE_CLIMAX_PATH, -6.0, 1.2)

func _process(delta: float) -> void:
	if _transitioning:
		return

	# 1. Slide timer & crossfade
	_slide_timer += delta
	if _slide_timer >= SLIDE_DURATION:
		_slide_timer = 0.0
		_advance_slide()

	# 2. Scrolling movie credits
	var speed := BASE_SCROLL_SPEED
	if _is_fast_forward:
		speed = FAST_SCROLL_SPEED
	elif _is_rewind:
		speed = REWIND_SCROLL_SPEED

	_scroll_pos_y -= speed * delta
	_credits_content.position.y = _scroll_pos_y

	# Check end of credits
	var total_h := _credits_content.size.y
	if _scroll_pos_y < -total_h + 300.0:
		_ended_hold_timer += delta
		if _ended_hold_timer >= 4.0:
			_return_to_main_menu()

func _input(event: InputEvent) -> void:
	if _transitioning:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_return_to_main_menu()
		return

	if event is InputEventKey:
		if event.keycode == KEY_DOWN or event.keycode == KEY_S or (event.keycode == KEY_SHIFT and event.pressed):
			_is_fast_forward = event.pressed
		elif event.keycode == KEY_UP or event.keycode == KEY_W:
			_is_rewind = event.pressed

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_pos_y -= 45.0
			_credits_content.position.y = _scroll_pos_y
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_pos_y += 45.0
			_credits_content.position.y = _scroll_pos_y

func _advance_slide() -> void:
	if _slides.is_empty():
		return
	_current_slide_idx = (_current_slide_idx + 1) % _slides.size()
	_display_slide(_current_slide_idx, true)

func _display_slide(idx: int, crossfade: bool) -> void:
	if idx < 0 or idx >= _slides.size():
		return
	var slide: Dictionary = _slides[idx]
	var tex_path: String = slide.get("path", "")
	if not ResourceLoader.exists(tex_path):
		return
	var tex = load(tex_path)
	if tex == null:
		return

	var incoming: TextureRect = _slide_rect_b if _active_rect_is_a else _slide_rect_a
	var outgoing: TextureRect = _slide_rect_a if _active_rect_is_a else _slide_rect_b

	incoming.texture = tex
	_slide_title_lbl.text = slide.get("title", "")
	_slide_caption_lbl.text = slide.get("caption", "")

	if crossfade:
		incoming.scale = Vector2(1.0, 1.0)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(incoming, "modulate:a", 1.0, SLIDE_CROSSFADE)
		t.tween_property(outgoing, "modulate:a", 0.0, SLIDE_CROSSFADE)
		t.tween_property(incoming, "scale", Vector2(1.05, 1.05), SLIDE_DURATION)
		_active_rect_is_a = not _active_rect_is_a
	else:
		outgoing.modulate.a = 1.0
		outgoing.texture = tex
		outgoing.scale = Vector2(1.0, 1.0)
		incoming.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(outgoing, "scale", Vector2(1.05, 1.05), SLIDE_DURATION)

func _on_skip_pressed() -> void:
	_return_to_main_menu()

func _return_to_main_menu() -> void:
	if _transitioning:
		return
	_transitioning = true

	LoreDB.return_to_briefing_stage_id = ""

	var t := create_tween()
	t.tween_property(_fade_rect, "modulate:a", 1.0, 0.9)
	t.tween_callback(func() -> void:
		AudioManager.crossfade_to(AudioManager.MENU_MUSIC_PATH, -11.0, 1.2)
		get_tree().change_scene_to_file(MAIN_MENU_PATH)
	)
