class_name TutorialBanner
extends RefCounted

var root: Control
var current_step: int = 0
var steps: Array[Dictionary] = []
var step_label: Label
var title_label: Label
var body_label: Label
var prev_btn: Button
var next_btn: Button
var on_log: Callable

static func get_tutorial_steps(stage_id: String) -> Array[Dictionary]:
	var faction_title := ""
	var faction_body := ""
	match stage_id:
		"vinculados_stage_1":
			faction_title = "VINCULADOS DOCTRINE: HIGH AGILE VECTORS & STERN RAKE"
			faction_body = "Your mecha frames have unmatched turn rates and heavy resonance barriers. Slip behind enemy warships to attack their unarmored rear: attacking the aft quadrant scores a STERN RAKE (+40% CRITICAL DAMAGE)! Deploy Barrier to absorb incoming fire."
		"marea_stage_1":
			faction_title = "FREE TIDE DOCTRINE: SURFING THE ETHER & BARLOVENTO"
			faction_body = "Sail directly along the cyan currents to gain tailwind velocity. Attacking from upwind secures the Weather-Gauge [BARLOVENTO] (+12% Hit accuracy). Align your flanks to unleash devastating Port & Starboard broadsides (+18% DMG)!"
		_:
			faction_title = "ACERO DOCTRINE: WALL OF STEEL & BROADSIDES"
			faction_body = "Your warships boast impenetrable Bow and Flank armor. Angle your prow toward hostiles to deflect salvos, and Cross the T to unleash heavy Port & Starboard broadsides. Keep Flagship CNS Iron Bastion operational!"

	return [
		{
			"header": "PHASE 1: STRATEGIC NAVAL CHART (ADMIRAL ORDERS)",
			"body": "Before visual combat, you command the fleet on the 10x8 Strategic Chart. Click adjacent quadrants to order ship moves. Capture Ether Conduits (+1 AP / +15% Speed) and ride the Barlovento Stream (+15% Acc / +12% DMG). When ready, press [ENTER] or close to engage in 3D!",
			"tag": "STEP 1/5 • STRATEGIC CHART"
		},
		{
			"header": "PHASE 2: 3D MANEUVERS & NEWTONIAN INERTIA",
			"body": "Click any ship directly or press [TAB] to select it. Drag or use [A/D] (yaw) and [W/S] (throttle speed). Ships possess real mass and inertia -- your heading determines which armor quadrant faces enemy guns!",
			"tag": "STEP 2/5 • FLEET MOVEMENT"
		},
		{
			"header": "PHASE 3: ACE TACTICAL COMBAT & AP SYSTEM",
			"body": "When within weapon range, tactical Ace mode activates. Each ship has Action Points (AP). Click ability pills (Broadside, Boost, Shields) at the bottom. Press [Z] to refund AP at any time. Press [SPACE] to resolve the tactical round!",
			"tag": "STEP 3/5 • TACTICAL COMBAT & AP"
		},
		{
			"header": faction_title,
			"body": faction_body,
			"tag": "STEP 4/5 • FACTION SPECIALTY"
		},
		{
			"header": "PHASE 4: THE ENCROACHING CALM (TACTICAL HAZARD)",
			"body": "Violet dimensional fluid pools are seeping from the perimeter. Entering The Calm drains propulsion and damages shields (-15 SHLD / -10 HULL). Push and herd hostile ships into the fluid to destroy them without firing!",
			"tag": "STEP 5/5 • STAR SEA HAZARDS"
		}
	]

func set_step(idx: int) -> void:
	if steps.is_empty():
		return
	current_step = clampi(idx, 0, steps.size() - 1)
	var s: Dictionary = steps[current_step]
	if step_label != null:
		step_label.text = String(s.get("tag", ""))
	if title_label != null:
		title_label.text = String(s.get("header", ""))
	if body_label != null:
		body_label.text = String(s.get("body", ""))
	if prev_btn != null:
		prev_btn.disabled = (current_step == 0)

func next_step() -> void:
	if current_step >= steps.size() - 1:
		if root != null:
			root.visible = false
		if on_log.is_valid():
			on_log.call("Tutorial guide dismissed. Press [T] at any time to re-open.", Color(0.4, 0.9, 1.0))
	else:
		set_step(current_step + 1)

func prev_step() -> void:
	set_step(current_step - 1)

func toggle() -> void:
	if root != null:
		root.visible = not root.visible

static func build(layer: CanvasLayer, hud_theme: Theme, stage_id: String, log_cb: Callable) -> TutorialBanner:
	var tb := TutorialBanner.new()
	tb.on_log = log_cb
	tb.steps = get_tutorial_steps(stage_id)

	var panel := PanelContainer.new()
	panel.name = "TutorialGuideBanner"
	panel.theme = hud_theme
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = 10
	panel.offset_bottom = 120
	panel.custom_minimum_size = Vector2(560, 105)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.02, 0.05, 0.11, 0.94)
	st.border_color = Color(0.35, 0.90, 1.0, 0.88)
	st.set_border_width_all(1)
	st.border_width_top = 3
	st.set_corner_radius_all(4)
	st.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", st)
	layer.add_child(panel)
	tb.root = panel

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	panel.add_child(vb)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	vb.add_child(top_row)

	var icon_lbl := Label.new()
	icon_lbl.text = "TACTICAL ACADEMY //"
	icon_lbl.add_theme_font_size_override("font_size", 11)
	icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	top_row.add_child(icon_lbl)

	var step_lbl := Label.new()
	step_lbl.text = "STEP 1/5 • STRATEGIC CHART"
	step_lbl.add_theme_font_size_override("font_size", 11)
	step_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.75))
	step_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(step_lbl)
	tb.step_label = step_lbl

	var p_btn := Button.new()
	p_btn.text = "◀ PREV [B]"
	p_btn.theme = hud_theme
	p_btn.custom_minimum_size = Vector2(85, 24)
	p_btn.pressed.connect(tb.prev_step)
	top_row.add_child(p_btn)
	tb.prev_btn = p_btn

	var n_btn := Button.new()
	n_btn.text = "NEXT ▶ [N]"
	n_btn.theme = hud_theme
	n_btn.custom_minimum_size = Vector2(85, 24)
	n_btn.pressed.connect(tb.next_step)
	top_row.add_child(n_btn)
	tb.next_btn = n_btn

	var close_btn := Button.new()
	close_btn.text = "✕ [X]"
	close_btn.theme = hud_theme
	close_btn.custom_minimum_size = Vector2(32, 24)
	close_btn.pressed.connect(func() -> void:
		panel.visible = false
		if log_cb.is_valid():
			log_cb.call("Tutorial guide dismissed. Press [T] to re-open.", Color(0.4, 0.9, 1.0))
	)
	top_row.add_child(close_btn)

	var title_lbl := Label.new()
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	vb.add_child(title_lbl)
	tb.title_label = title_lbl

	var body_lbl := Label.new()
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 11)
	body_lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	vb.add_child(body_lbl)
	tb.body_label = body_lbl

	tb.set_step(0)
	return tb
