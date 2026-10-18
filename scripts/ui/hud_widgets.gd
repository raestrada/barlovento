class_name HudWidgets
extends RefCounted

# Shared AAA Palette from promotional mockups (admiral-phase.png, ace-phase.png, roster.png)
const COL_BG_DARK := Color(0.02, 0.055, 0.10, 0.84)
const COL_BG_PANEL := Color(0.03, 0.08, 0.14, 0.78)
const COL_BG_CARD := Color(0.04, 0.11, 0.19, 0.86)
const COL_CYAN := Color(0.22, 0.78, 0.98, 1.0)
const COL_CYAN_BRIGHT := Color(0.45, 0.94, 1.0, 1.0)
const COL_CYAN_DIM := Color(0.18, 0.55, 0.75, 0.42)
const COL_GREEN := Color(0.18, 0.88, 0.48, 1.0)
const COL_AMBER := Color(0.96, 0.62, 0.14, 1.0)
const COL_RED := Color(0.94, 0.28, 0.24, 1.0)
const COL_MAGENTA := Color(0.88, 0.32, 0.78, 1.0)
const COL_TEXT_MAIN := Color(0.94, 0.97, 1.0, 1.0)
const COL_TEXT_MUTED := Color(0.58, 0.70, 0.82, 0.92)


# ==============================================================================
# 1. TOP-LEFT WEATHER-GAUGE & INITIATIVE ORDER WIDGET (from admiral-phase.png)
# ==============================================================================
class WeatherInitiativePanel extends Control:
    var ether_intensity: int = 4
    var max_intensity: int = 5
    var flow_label: String = "CYAN"
    var active_faction_idx: int = 0

    func _init() -> void:
        custom_minimum_size = Vector2(215, 220)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        var w := size.x

        # Subtle dark glass backing for Weather-Gauge
        draw_rect(Rect2(0, 0, w, 96), Color(0.02, 0.06, 0.11, 0.65), true)
        draw_line(Vector2(0, 0), Vector2(w, 0), COL_CYAN_DIM, 1.0)

        # Header: WEATHER-GAUGE
        draw_string(font, Vector2(6, 15), "WEATHER-GAUGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_TEXT_MAIN)
        draw_line(Vector2(6, 20), Vector2(w - 6, 20), Color(0.3, 0.65, 0.85, 0.35), 1.0)

        # Row: ÉTHER FLOW DIRECTION ... CYAN
        draw_string(font, Vector2(6, 36), "ÉTHER FLOW DIRECTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_TEXT_MUTED)
        draw_string(font, Vector2(w - 38, 36), flow_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_CYAN_BRIGHT)

        # 5-Segment Glowing Cyan Bar (admiral-phase.png exact style)
        var seg_y := 44.0
        var seg_h := 12.0
        var gap := 3.0
        var total_w := w - 12.0
        var seg_w := (total_w - gap * float(max_intensity - 1)) / float(max_intensity)

        draw_rect(Rect2(5, seg_y - 1, total_w + 2, seg_h + 2), Color(0.01, 0.03, 0.06, 0.9), true)
        draw_rect(Rect2(5, seg_y - 1, total_w + 2, seg_h + 2), COL_CYAN_DIM, false, 1.0)

        for i in range(max_intensity):
            var sx := 6.0 + float(i) * (seg_w + gap)
            var r := Rect2(sx, seg_y, seg_w, seg_h)
            if i < ether_intensity:
                draw_rect(r, COL_CYAN, true)
                draw_rect(Rect2(sx + 1, seg_y + 1, seg_w - 2, 3), COL_CYAN_BRIGHT, true)
            else:
                draw_rect(r, Color(0.05, 0.12, 0.18, 0.85), true)

        # Pointer triangle ▲ under active intensity segment
        var marker_x := 6.0 + (float(clampi(ether_intensity, 1, max_intensity)) - 0.5) * (seg_w + gap)
        var tri := PackedVector2Array([
            Vector2(marker_x, seg_y + seg_h + 2),
            Vector2(marker_x - 4.5, seg_y + seg_h + 8),
            Vector2(marker_x + 4.5, seg_y + seg_h + 8)
        ])
        draw_colored_polygon(tri, COL_CYAN_BRIGHT)

        # Row: INTENSITY ... 4/5
        draw_string(font, Vector2(6, 76), "INTENSITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_TEXT_MUTED)
        draw_string(font, Vector2(w - 28, 76), "%d/%d" % [ether_intensity, max_intensity], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_CYAN_BRIGHT)

        # Section 2: INITIATIVE ORDER
        var init_y := 102.0
        draw_rect(Rect2(0, init_y, w, 108), Color(0.02, 0.06, 0.11, 0.65), true)
        draw_string(font, Vector2(6, init_y + 15), "INITIATIVE ORDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_TEXT_MAIN)
        draw_line(Vector2(6, init_y + 20), Vector2(w - 6, init_y + 20), Color(0.3, 0.65, 0.85, 0.35), 1.0)

        var factions := [
            {"name": "ACERO", "color": COL_CYAN_BRIGHT, "crest": 0},
            {"name": "MAREA LIBRE", "color": COL_AMBER, "crest": 1},
            {"name": "VINCULADOS", "color": COL_MAGENTA, "crest": 2}
        ]

        for idx in range(factions.size()):
            var fy := init_y + 24.0 + float(idx) * 26.0
            var f_data: Dictionary = factions[idx]
            var is_act := idx == active_faction_idx
            if is_act:
                draw_rect(Rect2(2, fy, w - 4, 24), Color(0.10, 0.38, 0.52, 0.55), true)
                draw_rect(Rect2(2, fy, 3, 24), COL_CYAN_BRIGHT, true)
            else:
                draw_rect(Rect2(2, fy, w - 4, 24), Color(0.03, 0.07, 0.12, 0.45), true)

            # Draw mini faction crest
            var cx := 16.0
            var cy := fy + 12.0
            var c_col: Color = f_data["color"]
            if f_data["crest"] == 0:
                # Shield crest
                var sh := PackedVector2Array([
                    Vector2(cx, cy - 6), Vector2(cx + 5, cy - 4),
                    Vector2(cx + 4, cy + 3), Vector2(cx, cy + 6),
                    Vector2(cx - 4, cy + 3), Vector2(cx - 5, cy - 4)
                ])
                draw_colored_polygon(sh, Color(c_col.r, c_col.g, c_col.b, 0.35))
                sh.append(sh[0])
                draw_polyline(sh, c_col, 1.2)
            elif f_data["crest"] == 1:
                # Golden Wing/Sail crest
                var wg := PackedVector2Array([
                    Vector2(cx - 5, cy - 4), Vector2(cx + 5, cy - 4),
                    Vector2(cx + 3, cy + 5), Vector2(cx, cy + 2), Vector2(cx - 3, cy + 5)
                ])
                draw_colored_polygon(wg, Color(c_col.r, c_col.g, c_col.b, 0.4))
                wg.append(wg[0])
                draw_polyline(wg, c_col, 1.2)
            else:
                # Violet Soul Triangle/Diamond crest
                var dm := PackedVector2Array([
                    Vector2(cx, cy - 6), Vector2(cx + 5, cy + 4), Vector2(cx - 5, cy + 4)
                ])
                draw_colored_polygon(dm, Color(c_col.r, c_col.g, c_col.b, 0.35))
                dm.append(dm[0])
                draw_polyline(dm, c_col, 1.2)

            var txt_col := COL_TEXT_MAIN if is_act else COL_TEXT_MUTED
            draw_string(font, Vector2(30, fy + 16), f_data["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, txt_col)


# ==============================================================================
# 2. WORLD-SPACE PROJECTED 2D SHIP CALLOUT BADGES (from admiral-phase.png)
#    Hexagon icon + Dark plate + Green Health Bar + "SHLD 100% | HULL 100% | MOVING"
# ==============================================================================
class ShipCalloutOverlay extends Control:
    signal ship_badge_clicked(ship: Ship)
    signal ship_badge_right_clicked(ship: Ship)

    var ships: Array[Ship] = []
    var selected_ship: Ship = null
    var target_ship: Ship = null
    var camera: Camera3D = null
    var _badge_rects: Dictionary = {}

    func _init() -> void:
        set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_PASS

    func _process(_delta: float) -> void:
        queue_redraw()

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed:
            var mpos: Vector2 = event.position
            for s in _badge_rects.keys():
                var rect: Rect2 = _badge_rects[s]
                if rect.has_point(mpos):
                    if event.button_index == MOUSE_BUTTON_LEFT:
                        ship_badge_clicked.emit(s)
                        accept_event()
                        return
                    elif event.button_index == MOUSE_BUTTON_RIGHT:
                        ship_badge_right_clicked.emit(s)
                        accept_event()
                        return

    func _draw() -> void:
        _badge_rects.clear()
        if camera == null or not is_instance_valid(camera):
            return

        var font := ThemeDB.fallback_font
        var vp_size := get_viewport_rect().size

        for ship in ships:
            if ship == null or not is_instance_valid(ship) or ship.is_destroyed():
                continue

            var world_anchor := ship.global_position + Vector3(0.0, ship.body_size.y * 1.4 + 2.6, 0.0)
            if camera.is_position_behind(world_anchor):
                continue

            var screen_pos := camera.unproject_position(world_anchor)
            if screen_pos.x < -100 or screen_pos.x > vp_size.x + 100 or screen_pos.y < -60 or screen_pos.y > vp_size.y + 60:
                continue

            var is_sel := ship == selected_ship
            var is_tgt := ship == target_ship
            var is_ally := ship.team == 0

            var badge_w := 196.0
            var badge_h := 38.0
            var bx := clampf(screen_pos.x - badge_w * 0.42, 12.0, vp_size.x - badge_w - 12.0)
            var by := clampf(screen_pos.y - badge_h - 8.0, 52.0, vp_size.y - 180.0)

            var full_rect := Rect2(bx - 18.0, by, badge_w + 18.0, badge_h)
            _badge_rects[ship] = full_rect

            # Leader line from badge to ship
            var hex_center := Vector2(bx, by + badge_h * 0.5)
            var accent_col := COL_CYAN_BRIGHT if is_ally else Color(1.0, 0.48, 0.25, 1.0)
            if is_sel:
                accent_col = Color(0.45, 0.98, 1.0, 1.0)
            elif is_tgt:
                accent_col = Color(1.0, 0.35, 0.22, 1.0)

            # Main dark rectangular callout plate (to the right of the hexagon)
            var plate_rect := Rect2(bx + 10.0, by, badge_w - 10.0, badge_h)
            var bg_col := Color(0.02, 0.06, 0.11, 0.86) if not is_sel else Color(0.04, 0.13, 0.22, 0.92)
            draw_rect(plate_rect, bg_col, true)
            draw_rect(plate_rect, Color(accent_col.r, accent_col.g, accent_col.b, 0.65 if (is_sel or is_tgt) else 0.32), false, 1.5 if (is_sel or is_tgt) else 1.0)

            # Hexagon Icon on Left (exact admiral-phase.png silhouette)
            var hex_r := 19.0
            var hex_pts := PackedVector2Array()
            for i in range(6):
                var ang := deg_to_rad(60.0 * float(i) - 30.0)
                hex_pts.append(hex_center + Vector2(cos(ang) * hex_r, sin(ang) * hex_r))
            draw_colored_polygon(hex_pts, Color(0.03, 0.10, 0.18, 0.96))
            var hex_outline := hex_pts.duplicate()
            hex_outline.append(hex_pts[0])
            draw_polyline(hex_outline, accent_col, 1.8 if (is_sel or is_tgt) else 1.3)

            # Ship class mini-icon inside Hexagon
            _draw_ship_class_icon(hex_center, ship.ship_id, accent_col)

            # Top text: UNIT_CODE (e.g. ACER_ANS_01 / VINC_ACE_01) + Short Name
            var title_str := "%s // %s" % [ship.unit_code, ship.ship_name.to_upper()]
            if title_str.length() > 23:
                title_str = title_str.substr(0, 23)
            var title_col := Color(1.0, 0.95, 0.55) if is_sel else COL_TEXT_MAIN
            draw_string(font, Vector2(bx + 24.0, by + 14.0), title_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, title_col)

            # Crisp Horizontal Health Bar right under the name (admiral-phase.png signature green bar)
            var bar_x := bx + 24.0
            var bar_y := by + 18.0
            var bar_w := badge_w - 32.0
            var bar_h := 3.5
            draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.08, 0.15, 0.20, 0.95), true)
            var hp_ratio := clampf(ship.hp / maxf(ship.max_hp, 1.0), 0.0, 1.0)
            var bar_col := COL_GREEN if hp_ratio > 0.5 else (COL_AMBER if hp_ratio > 0.25 else COL_RED)
            draw_rect(Rect2(bar_x, bar_y, bar_w * hp_ratio, bar_h), bar_col, true)

            # Bottom telemetry row: SHLD 100% | HULL 100% | MOVING
            var state_word := "MOVING"
            if is_tgt:
                state_word = "LOCKED"
            elif ship.stance == Ship.Stance.EVASIVE:
                state_word = "EVASIVE"
            elif ship.speed() < 0.4 and ship.order.target_speed < 0.4:
                state_word = "HOLDING"

            var sub_y := by + 33.0
            var shld_str := "SHLD %d%%" % ship.shield_pct()
            var hull_str := "HULL %d%%" % ship.hull_pct()
            draw_string(font, Vector2(bar_x, sub_y), shld_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_GREEN)
            draw_string(font, Vector2(bar_x + 52.0, sub_y), "| " + hull_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, bar_col)
            draw_string(font, Vector2(bar_x + 110.0, sub_y), "| " + state_word, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_TEXT_MUTED)

    func _draw_ship_class_icon(c: Vector2, ship_id: String, col: Color) -> void:
        if ship_id.begins_with("vinculados"):
            # Mecha / Gundam silhouette icon
            draw_rect(Rect2(c.x - 3, c.y - 6, 6, 12), col, true)
            draw_rect(Rect2(c.x - 7, c.y - 4, 3, 8), col, true)
            draw_rect(Rect2(c.x + 4, c.y - 4, 3, 8), col, true)
        elif ship_id.begins_with("marea"):
            # Billowing Sail Galleon icon
            var sail := PackedVector2Array([
                Vector2(c.x - 2, c.y - 7), Vector2(c.x + 6, c.y - 1), Vector2(c.x - 2, c.y + 4)
            ])
            draw_colored_polygon(sail, col)
            draw_rect(Rect2(c.x - 7, c.y + 4, 14, 3), col, true)
        elif ship_id == "acero_dreadnought":
            # Heavy Shield / Anvil icon
            var sh := PackedVector2Array([
                Vector2(c.x, c.y - 7), Vector2(c.x + 6, c.y - 4),
                Vector2(c.x + 5, c.y + 3), Vector2(c.x, c.y + 7),
                Vector2(c.x - 5, c.y + 3), Vector2(c.x - 6, c.y - 4)
            ])
            draw_colored_polygon(sh, col)
        else:
            # Sleek Frigate / Cruiser silhouette
            var fr := PackedVector2Array([
                Vector2(c.x - 8, c.y), Vector2(c.x + 4, c.y - 4),
                Vector2(c.x + 8, c.y), Vector2(c.x + 4, c.y + 4)
            ])
            draw_colored_polygon(fr, col)


# ==============================================================================
# 3. TOP-CENTER "ACE PHASE" TRAPEZOID BANNER (from ace-phase.png)
# ==============================================================================
class AceTopBanner extends Control:
    var round_number: int = 1
    var subtitle: String = ""

    func _init() -> void:
        custom_minimum_size = Vector2(560, 54)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        var w := size.x
        var cx := w * 0.5
        var top_w := 300.0
        var bot_w := 230.0
        var h := 44.0

        # Chamfered trapezoid polygon at top center
        var trap := PackedVector2Array([
            Vector2(cx - top_w * 0.5, 0),
            Vector2(cx + top_w * 0.5, 0),
            Vector2(cx + bot_w * 0.5, h),
            Vector2(cx - bot_w * 0.5, h)
        ])
        draw_colored_polygon(trap, Color(0.02, 0.06, 0.12, 0.88))

        # Glowing cyan border lines extending outward along the top edge (exact ace-phase.png look)
        var border_pts := PackedVector2Array([
            Vector2(0, 1),
            Vector2(cx - top_w * 0.5, 1),
            Vector2(cx - bot_w * 0.5, h),
            Vector2(cx + bot_w * 0.5, h),
            Vector2(cx + top_w * 0.5, 1),
            Vector2(w, 1)
        ])
        draw_polyline(border_pts, COL_CYAN_BRIGHT, 2.0)

        draw_string(font, Vector2(cx - 72, 29), "ACE PHASE", HORIZONTAL_ALIGNMENT_CENTER, 144, 22, COL_TEXT_MAIN)


# ==============================================================================
# 4. DIRECTIONAL ARMOR & SHIELD QUADRANT DIAGRAM (from ace-phase.png bottom-left)
# ==============================================================================
class DirectionalArmorWidget extends Control:
    var ship: Ship = null

    func _init() -> void:
        custom_minimum_size = Vector2(260, 152)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        var w := size.x
        var h := size.y

        # Outer dark glass box with thin cyan border (matches "Free Tide" box in ace-phase.png)
        draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.06, 0.11, 0.84), true)
        draw_rect(Rect2(0, 0, w, h), Color(0.22, 0.72, 0.92, 0.48), false, 1.2)

        var faction_title := "Free Tide"
        var unit_sub := ""
        var bow_pct := 100.0
        var stern_pct := 70.0
        var port_pct := 88.0
        var stbd_pct := 88.0

        if ship != null and is_instance_valid(ship):
            match ship.faction:
                "marea_libre":
                    faction_title = "Free Tide"
                "vinculados":
                    faction_title = "The Vinculados"
                "acero":
                    faction_title = "Armada of Acero"
                _:
                    faction_title = ship.faction.capitalize()
            unit_sub = ship.ship_name
            bow_pct = ship.armor_bow
            stern_pct = ship.armor_stern
            port_pct = ship.armor_port
            stbd_pct = ship.armor_stbd

        # Header Title + Subtle horizontal rule
        draw_string(font, Vector2(12, 22), faction_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_TEXT_MAIN)
        draw_string(font, Vector2(w - 120, 21), unit_sub, HORIZONTAL_ALIGNMENT_RIGHT, 108, 11, COL_CYAN_BRIGHT)
        draw_line(Vector2(10, 30), Vector2(w - 10, 30), Color(0.25, 0.65, 0.85, 0.35), 1.0)

        # Center of the 4-way curved armor diagram
        var cx := w * 0.5
        var cy := 90.0

        # Central ship hull top-down silhouette (horizontal orientation matching ace-phase.png: BOW left, PORT right, STERN top, STARBOARD bottom)
        var hull_pts := PackedVector2Array([
            Vector2(cx - 26, cy),
            Vector2(cx - 12, cy - 8),
            Vector2(cx + 20, cy - 7),
            Vector2(cx + 26, cy),
            Vector2(cx + 20, cy + 7),
            Vector2(cx - 12, cy + 8)
        ])
        draw_colored_polygon(hull_pts, Color(0.12, 0.28, 0.38, 0.65))
        hull_pts.append(hull_pts[0])
        draw_polyline(hull_pts, Color(0.35, 0.78, 0.95, 0.75), 1.2)

        # Draw 3 concentric curved arc layers on BOW (Left: PI - 0.55 .. PI + 0.55) and PORT (Right: -0.55 .. +0.55)
        _draw_sector_layers(Vector2(cx, cy), PI, 0.52, bow_pct, 3, 34.0, 8.0)
        _draw_sector_layers(Vector2(cx, cy), 0.0, 0.52, port_pct, 3, 34.0, 8.0)

        # Draw 2 concentric curved arc layers on STERN (Top: -PI/2) and STARBOARD (Bottom: PI/2)
        _draw_sector_layers(Vector2(cx, cy), -PI * 0.5, 0.48, stern_pct, 2, 18.0, 7.0)
        _draw_sector_layers(Vector2(cx, cy), PI * 0.5, 0.48, stbd_pct, 2, 18.0, 7.0)

        # Quadrant Labels (exact positions from ace-phase.png)
        draw_string(font, Vector2(cx - 20, 46), "STERN", HORIZONTAL_ALIGNMENT_CENTER, 40, 9, COL_TEXT_MAIN)
        draw_string(font, Vector2(cx - 30, h - 8), "STARBOARD", HORIZONTAL_ALIGNMENT_CENTER, 60, 9, COL_TEXT_MAIN)
        draw_string(font, Vector2(12, cy + 4), "BOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_TEXT_MAIN)
        draw_string(font, Vector2(w - 38, cy + 4), "PORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_TEXT_MAIN)

    func _draw_sector_layers(center: Vector2, mid_angle: float, half_span: float, pct: float, layers: int, start_r: float, step_r: float) -> void:
        for layer in range(layers):
            var r_in := start_r + float(layer) * step_r
            var r_out := r_in + (step_r - 2.2)
            var threshold := float(layer) * (100.0 / float(layers))
            var col: Color
            if pct < threshold + 15.0:
                col = Color(0.12, 0.22, 0.28, 0.45)
            elif layer == 0:
                col = COL_AMBER if pct < 90.0 else COL_GREEN
            elif layer == 1:
                col = COL_GREEN if pct >= 55.0 else COL_AMBER
            else:
                col = COL_GREEN if pct >= 75.0 else Color(0.18, 0.55, 0.72, 0.65)

            _draw_arc_band(center, r_in, r_out, mid_angle - half_span, mid_angle + half_span, col)

    func _draw_arc_band(c: Vector2, r_in: float, r_out: float, a_start: float, a_end: float, col: Color) -> void:
        var segs := 14
        var pts := PackedVector2Array()
        for i in range(segs + 1):
            var a := a_start + (float(i) / float(segs)) * (a_end - a_start)
            pts.append(c + Vector2(cos(a) * r_out, sin(a) * r_out))
        for i in range(segs, -1, -1):
            var a := a_start + (float(i) / float(segs)) * (a_end - a_start)
            pts.append(c + Vector2(cos(a) * r_in, sin(a) * r_in))
        draw_colored_polygon(pts, col)
        var outline := pts.duplicate()
        outline.append(pts[0])
        draw_polyline(outline, Color(col.r, col.g, col.b, 0.95).lightened(0.25), 1.0)


# ==============================================================================
# 5. 12-PIP GLOWING ACTION POINT BAR (from ace-phase.png bottom-center)
# ==============================================================================
class ActionPointBar extends Control:
    var current_ap: int = 7
    var max_ap: int = 12
    var salvo_text: String = "1/7"
    var drift_text: String = "/ 0"

    func _init() -> void:
        custom_minimum_size = Vector2(540, 28)
        mouse_filter = Control.MOUSE_FILTER_IGNORE

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        draw_string(font, Vector2(4, 19), "ACTION POINTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_TEXT_MAIN)

        var start_x := 112.0
        var pip_w := 18.0
        var pip_h := 16.0
        var gap := 4.0
        var py := 6.0

        for i in range(max_ap):
            var px := start_x + float(i) * (pip_w + gap)
            var rect := Rect2(px, py, pip_w, pip_h)
            if i < current_ap:
                # Outer cyan glow
                draw_rect(Rect2(px - 1.5, py - 1.5, pip_w + 3, pip_h + 3), Color(0.22, 0.85, 1.0, 0.35), true)
                draw_rect(rect, COL_CYAN, true)
                draw_rect(Rect2(px + 2, py + 2, pip_w - 4, pip_h * 0.4), COL_CYAN_BRIGHT, true)
                draw_rect(rect, Color(0.75, 0.98, 1.0, 0.95), false, 1.2)
            else:
                draw_rect(rect, Color(0.03, 0.08, 0.14, 0.75), true)
                draw_rect(rect, Color(0.22, 0.55, 0.72, 0.45), false, 1.0)

        var right_x := start_x + float(max_ap) * (pip_w + gap) + 14.0
        draw_string(font, Vector2(right_x, 19), "✸ " + salvo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_TEXT_MAIN)
        draw_string(font, Vector2(right_x + 56.0, 19), "◆ " + drift_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_CYAN_BRIGHT)


# ==============================================================================
# 6. SQUARE TACTICAL FLEET ORDER TILE (from admiral-phase.png bottom-right)
#    [ MOVE ] [ FACE ] [ ENGAGE ] [ TARGET ] [ FORMATION ] [ EXECUTE ]
# ==============================================================================
class FleetOrderTile extends Button:
    var icon_kind: String = "move"
    var tile_label: String = "MOVE"
    var is_primary: bool = false

    func _init(kind: String = "move", label_txt: String = "MOVE", primary: bool = false) -> void:
        icon_kind = kind
        tile_label = label_txt
        is_primary = primary
        custom_minimum_size = Vector2(68, 66)
        focus_mode = Control.FOCUS_NONE
        flat = true

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        var w := size.x
        var h := size.y
        var hovered := is_hovered()
        var pressed := is_pressed()

        var bg := Color(0.03, 0.09, 0.16, 0.86)
        var border := Color(0.22, 0.72, 0.92, 0.55)
        var icon_col := Color(0.42, 0.84, 0.98, 0.95)

        if is_primary:
            bg = Color(0.05, 0.22, 0.28, 0.92)
            border = COL_GREEN
            icon_col = COL_GREEN

        if hovered:
            bg = bg.lightened(0.14)
            border = COL_CYAN_BRIGHT
            icon_col = COL_CYAN_BRIGHT
        if pressed:
            bg = bg.lightened(0.25)
            border = COL_AMBER

        draw_rect(Rect2(0, 0, w, h), bg, true)
        draw_rect(Rect2(0, 0, w, h), border, false, 1.6 if (hovered or is_primary) else 1.1)

        var cx := w * 0.5
        var cy := h * 0.40

        match icon_kind:
            "move":
                # Thick right-pointing arrow (exact admiral-phase.png MOVE icon)
                var arr := PackedVector2Array([
                    Vector2(cx - 13, cy - 5), Vector2(cx + 1, cy - 5),
                    Vector2(cx + 1, cy - 11), Vector2(cx + 14, cy),
                    Vector2(cx + 1, cy + 11), Vector2(cx + 1, cy + 5),
                    Vector2(cx - 13, cy + 5)
                ])
                draw_colored_polygon(arr, icon_col)
            "face":
                # Heraldic shield with top notch (exact admiral-phase.png FACE icon)
                var sh := PackedVector2Array([
                    Vector2(cx - 10, cy - 11), Vector2(cx + 10, cy - 11),
                    Vector2(cx + 10, cy - 1), Vector2(cx, cy + 12),
                    Vector2(cx - 10, cy - 1)
                ])
                draw_colored_polygon(sh, icon_col)
                draw_circle(Vector2(cx, cy - 11), 3.2, bg)
            "engage":
                # Twin sleek vector darts (exact admiral-phase.png ENGAGE icon)
                var d1 := PackedVector2Array([
                    Vector2(cx - 14, cy), Vector2(cx + 4, cy - 8), Vector2(cx + 1, cy), Vector2(cx + 4, cy + 8)
                ])
                draw_colored_polygon(d1, icon_col)
                draw_rect(Rect2(cx + 6, cy - 6, 7, 3), icon_col, true)
                draw_rect(Rect2(cx + 6, cy + 3, 7, 3), icon_col, true)
            "target":
                # Crosshair reticle (exact admiral-phase.png TARGET icon)
                draw_arc(Vector2(cx, cy), 9.0, 0.0, TAU, 24, icon_col, 2.0)
                draw_circle(Vector2(cx, cy), 2.5, icon_col)
                draw_line(Vector2(cx - 14, cy), Vector2(cx - 5, cy), icon_col, 2.0)
                draw_line(Vector2(cx + 5, cy), Vector2(cx + 14, cy), icon_col, 2.0)
                draw_line(Vector2(cx, cy - 14), Vector2(cx, cy - 5), icon_col, 2.0)
                draw_line(Vector2(cx, cy + 5), Vector2(cx, cy + 14), icon_col, 2.0)
            "formation":
                # 3x3 tactical formation grid (exact admiral-phase.png FORMATION icon)
                for r in range(3):
                    for c in range(3):
                        var gx := cx - 10.0 + float(c) * 7.5
                        var gy := cy - 10.0 + float(r) * 7.5
                        draw_rect(Rect2(gx, gy, 5.0, 5.0), icon_col, true)
            "execute":
                # Double play chevron for EXECUTE TURN [SPACE]
                var p1 := PackedVector2Array([
                    Vector2(cx - 10, cy - 10), Vector2(cx + 2, cy), Vector2(cx - 10, cy + 10)
                ])
                var p2 := PackedVector2Array([
                    Vector2(cx, cy - 10), Vector2(cx + 12, cy), Vector2(cx, cy + 10)
                ])
                draw_colored_polygon(p1, icon_col)
                draw_colored_polygon(p2, icon_col)

        var lbl_col := COL_TEXT_MAIN if (hovered or is_primary) else COL_TEXT_MUTED
        draw_string(font, Vector2(0, h - 8), tile_label, HORIZONTAL_ALIGNMENT_CENTER, int(w), 10, lbl_col)


# ==============================================================================
# 7. HORIZONTAL FLEET DOCK UNIT CARD (from admiral-phase.png bottom bar)
#    [Icon] ACER_ANS_01  [Role]
#    SHLD [==========] 100%
#    HULL [==========] 100%
# ==============================================================================
class AdmiralUnitCard extends Button:
    var ship: Ship = null
    var is_selected_unit: bool = false
    var is_target_unit: bool = false

    func _init(s: Ship = null) -> void:
        ship = s
        custom_minimum_size = Vector2(168, 64)
        focus_mode = Control.FOCUS_NONE
        flat = true

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        var w := size.x
        var h := size.y
        var hovered := is_hovered()

        if ship == null or not is_instance_valid(ship):
            return

        var is_ally := ship.team == 0
        var destroyed := ship.is_destroyed()

        var bg := Color(0.03, 0.08, 0.14, 0.88)
        var border := Color(0.18, 0.55, 0.75, 0.45) if is_ally else Color(0.85, 0.38, 0.22, 0.45)

        if is_selected_unit:
            bg = Color(0.06, 0.18, 0.28, 0.95)
            border = COL_CYAN_BRIGHT
        elif is_target_unit:
            bg = Color(0.18, 0.07, 0.06, 0.92)
            border = Color(1.0, 0.45, 0.25, 0.95)
        elif hovered:
            bg = bg.lightened(0.10)
            border = COL_CYAN if is_ally else COL_AMBER

        draw_rect(Rect2(0, 0, w, h), bg, true)
        draw_rect(Rect2(0, 0, w, h), border, false, 1.8 if (is_selected_unit or is_target_unit) else 1.0)

        # Top strip highlight
        if is_selected_unit or is_target_unit:
            draw_rect(Rect2(1, 1, w - 2, 2), border, true)

        # Row 1: Unit Code / Name + Role icon
        var code_txt := "%s (%s)" % [ship.unit_code, ship.ship_name]
        if code_txt.length() > 20:
            code_txt = code_txt.substr(0, 20)
        var name_col := COL_TEXT_MAIN if not destroyed else Color(0.5, 0.5, 0.5, 0.5)
        if is_target_unit:
            name_col = Color(1.0, 0.65, 0.4)
        draw_string(font, Vector2(8, 16), code_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, name_col)

        # Small diagonal sword/lance icon on top-right of card (exact admiral-phase.png detail)
        var rx := w - 12.0
        var ry := 11.0
        var role_col := COL_AMBER if not is_ally else COL_CYAN_BRIGHT
        draw_line(Vector2(rx - 4, ry + 4), Vector2(rx + 4, ry - 4), role_col, 1.6)

        if destroyed:
            draw_string(font, Vector2(8, 42), "[ VESSEL DESTROYED ]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_RED)
            return

        # Row 2: Shield icon + Green/Cyan Bar + Percentage
        var sh_pct := ship.shield_pct()
        var sh_ratio := float(sh_pct) / 100.0
        draw_string(font, Vector2(8, 35), "🛡", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_GREEN)
        var bar_x := 36.0
        var bar_w := w - 76.0
        draw_rect(Rect2(bar_x, 26, bar_w, 8), Color(0.02, 0.05, 0.09, 0.95), true)
        draw_rect(Rect2(bar_x, 26, bar_w * sh_ratio, 8), COL_GREEN, true)
        draw_string(font, Vector2(w - 36, 34), "%d%%" % sh_pct, HORIZONTAL_ALIGNMENT_RIGHT, 32, 9, COL_TEXT_MAIN)

        # Row 3: HULL label + Emerald/Cyan Bar + Percentage
        var hl_pct := ship.hull_pct()
        var hl_ratio := float(hl_pct) / 100.0
        var hl_col := COL_CYAN if hl_pct > 50 else (COL_AMBER if hl_pct > 25 else COL_RED)
        draw_string(font, Vector2(8, 53), "HULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_TEXT_MUTED)
        draw_rect(Rect2(bar_x, 44, bar_w, 8), Color(0.02, 0.05, 0.09, 0.95), true)
        draw_rect(Rect2(bar_x, 44, bar_w * hl_ratio, 8), hl_col, true)
        draw_string(font, Vector2(w - 36, 52), "%d%%" % hl_pct, HORIZONTAL_ALIGNMENT_RIGHT, 32, 9, COL_TEXT_MAIN)


# ==============================================================================
# 8. HERO ROSTER SCREEN MODAL OVERLAY (from assets/mockups/roster.png)
# ==============================================================================
class HeroRosterModal extends Control:
    signal closed

    var _hero_textures: Array[Texture2D] = []

    func _ensure_textures() -> void:
        if not _hero_textures.is_empty():
            return
        var paths := [
            "res://assets/factions/acero_commander.png",
            "res://assets/ships/vinculados/suit_concept.png",
            "res://assets/ships/marea-libre/galleon_concept.png",
            "res://assets/ships/marea-libre/galleon.png"
        ]
        for p in paths:
            _hero_textures.append(load(p))

    func _draw_portrait_in_rect(idx: int, port_r: Rect2, col: Color) -> void:
        _ensure_textures()
        draw_rect(port_r, Color(0.03, 0.04, 0.08, 0.98), true)
        if idx >= 0 and idx < _hero_textures.size() and _hero_textures[idx] != null:
            draw_texture_rect(_hero_textures[idx], port_r.grow(-2.0), false, Color(0.95, 0.96, 1.0, 0.92))
        else:
            var pc := port_r.get_center()
            draw_circle(pc + Vector2(0, -14), 16.0, Color(0.75, 0.68, 0.62, 0.85))
        draw_rect(port_r, Color(col.r, col.g, col.b, 0.55), false, 1.2)

    func _init() -> void:
        set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        visible = false

    func _ready() -> void:
        var close_btn := Button.new()
        close_btn.text = "PROCEED TO ADMIRAL PHASE >"
        close_btn.custom_minimum_size = Vector2(240, 42)
        close_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
        close_btn.position -= Vector2(24, 18)
        close_btn.focus_mode = Control.FOCUS_NONE
        close_btn.pressed.connect(func() -> void:
            visible = false
            closed.emit()
        )
        add_child(close_btn)

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            visible = false
            closed.emit()
            accept_event()

    func _draw() -> void:
        var font := ThemeDB.fallback_font
        var w := size.x
        var h := size.y

        # Full dark space backdrop matching roster.png
        draw_rect(Rect2(0, 0, w, h), Color(0.015, 0.035, 0.065, 0.96), true)

        # Header Left
        draw_string(font, Vector2(32, 32), "COMMAND DECK // SQUAD MANAGEMENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_CYAN_BRIGHT)
        draw_string(font, Vector2(32, 54), "HERO ROSTER — 4 ACES EMBARKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, COL_TEXT_MAIN)
        draw_circle(Vector2(37, 68), 4.0, COL_GREEN)
        draw_string(font, Vector2(48, 72), "STATUS: SQUAD COMBAT-READY FOR ADMIRAL PHASE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_TEXT_MUTED)

        # Header Right
        draw_string(font, Vector2(w - 290, 32), "SECTOR 07: STAR-SEA THRESHOLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_TEXT_MUTED)
        draw_string(font, Vector2(w - 290, 52), "ÉTHER WIND: 18.2 kt [WINDWARD]", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_CYAN_BRIGHT)
        draw_circle(Vector2(w - 285, 66), 4.0, COL_RED)
        draw_string(font, Vector2(w - 275, 70), "CALM FRONT ADVANCE: -12.4 AU (CRITICAL)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.45, 0.45))

        # 4 Hero Cards across the center (matching roster.png 1:1)
        var heroes := [
            {
                "faction": "ARMADA OF ACERO", "sub": "ADMIRAL OF THE LINE", "tag": "STEEL",
                "color": COL_AMBER, "name": "ADMIRAL VANE", "role": "FLEET COMMANDER",
                "hull": "HULL: CNS IRON BASTION", "agi": 28, "arm": 98, "lnk": 22,
                "tactic": "TACTIC: BOW BULWARK", "desc": "Absorbs 35% frontal kinetic impact. Interlocking broadsides.",
                "slot": "SLOT 01 // ACERO COMMAND"
            },
            {
                "faction": "THE VINCULADOS", "sub": "FIRST HARMONIC ACE", "tag": "SOUL",
                "color": COL_MAGENTA, "name": "KAELEN-7 // EIDOLON", "role": "LINKED PILOT",
                "hull": "FRAME: EIDOLON PRIME", "agi": 92, "arm": 42, "lnk": 98,
                "tactic": "TACTIC: NEURAL RESONANCE", "desc": "Instant vector snap. +35% crit during mecha duels.",
                "slot": "SLOT 02 // VINCULADOS CORE"
            },
            {
                "faction": "THE FREE TIDE", "sub": "CORSAIR COMMODORE", "tag": "WIND",
                "color": Color(0.95, 0.72, 0.25), "name": "CAPTAIN SOLANO", "role": "CORSAIR CAPTAIN",
                "hull": "HULL: VIENTO ROJO GALLEON", "agi": 78, "arm": 68, "lnk": 45,
                "tactic": "TACTIC: WINDWARD DASH", "desc": "+18% Broadside Lance damage. Quantum sail tailwind boost.",
                "slot": "SLOT 03 // FREE TIDE HELM"
            },
            {
                "faction": "THE VINCULADOS", "sub": "RESONANCE OUTRIDER", "tag": "SOUL",
                "color": COL_CYAN_BRIGHT, "name": "MIREI // ANIMA-01", "role": "INTERCEPTOR ACE",
                "hull": "FRAME: ANIMA-01 ARIA", "agi": 96, "arm": 36, "lnk": 94,
                "tactic": "TACTIC: STERN RAKE", "desc": "High-speed flanker. +40% critical damage on enemy stern.",
                "slot": "SLOT 04 // OUTRIDER WING"
            }
        ]

        var margin_x := 32.0
        var gap := 16.0
        var card_w := (w - margin_x * 2.0 - gap * 3.0) / 4.0
        var card_y := 105.0
        var card_h := h - 185.0

        for i in range(4):
            var hd: Dictionary = heroes[i]
            var cx := margin_x + float(i) * (card_w + gap)
            var col: Color = hd["color"]
            var r := Rect2(cx, card_y, card_w, card_h)

            draw_rect(r, Color(0.02, 0.05, 0.09, 0.94), true)
            draw_rect(r, col, false, 1.4)

            # Top faction bar
            draw_rect(Rect2(cx + 10, card_y + 12, 6, 16), col, true)
            draw_string(font, Vector2(cx + 22, card_y + 20), hd["faction"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
            draw_string(font, Vector2(cx + 22, card_y + 32), hd["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_TEXT_MUTED)

            # Tag pill
            var tag_r := Rect2(cx + card_w - 64, card_y + 12, 54, 18)
            draw_rect(tag_r, col, false, 1.0)
            draw_string(font, Vector2(tag_r.position.x, tag_r.position.y + 13), hd["tag"], HORIZONTAL_ALIGNMENT_CENTER, 54, 9, col)

            # Portrait Box with AAA Texture
            var port_r := Rect2(cx + 10, card_y + 42, card_w - 20, card_h * 0.36)
            _draw_portrait_in_rect(i, port_r, col)

            var info_y := port_r.end.y + 22.0
            draw_string(font, Vector2(cx + 12, info_y), hd["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COL_TEXT_MAIN)
            draw_string(font, Vector2(cx + 12, info_y + 16), hd["role"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
            draw_string(font, Vector2(cx + 12, info_y + 30), hd["hull"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_TEXT_MUTED)

            # Stat bars: AGILITY, ARMOR, LINK
            _draw_stat_row(font, cx + 12, info_y + 52, card_w - 24, "AGILITY", hd["agi"], col)
            _draw_stat_row(font, cx + 12, info_y + 72, card_w - 24, "ARMOR", hd["arm"], col)
            _draw_stat_row(font, cx + 12, info_y + 92, card_w - 24, "LINK", hd["lnk"], col)

            # Tactic Box
            var tac_r := Rect2(cx + 12, info_y + 108, card_w - 24, 48)
            draw_rect(tac_r, Color(0.04, 0.08, 0.14, 0.8), true)
            draw_rect(tac_r, Color(col.r, col.g, col.b, 0.3), false, 1.0)
            draw_rect(Rect2(tac_r.position.x + 4, tac_r.position.y + 6, 4, 12), col, true)
            draw_string(font, Vector2(tac_r.position.x + 14, tac_r.position.y + 16), hd["tactic"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_TEXT_MAIN)
            draw_string(font, Vector2(tac_r.position.x + 8, tac_r.position.y + 34), hd["desc"], HORIZONTAL_ALIGNMENT_LEFT, int(tac_r.size.x - 14), 9, COL_TEXT_MUTED)

            # Footer
            draw_string(font, Vector2(cx + 12, card_y + card_h - 12), "◆ " + hd["slot"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_TEXT_MUTED)
            draw_string(font, Vector2(cx + card_w - 62, card_y + card_h - 12), "[ READY ]", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_GREEN)

        # Bottom bar text
        draw_string(font, Vector2(32, h - 28), "[ESC / R] RETURN TO BRIDGE   |   [TAB] CYCLE HERO   |   [SPACE] INSPECT ACE LOADOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_TEXT_MUTED)
        draw_string(font, Vector2(w * 0.5 - 140, h - 28), "HERO SQUAD FULLY ASSEMBLED (4 / 4 ACES)", HORIZONTAL_ALIGNMENT_CENTER, 280, 12, COL_CYAN_BRIGHT)

    func _draw_stat_row(font: Font, x: float, y: float, w: float, label_txt: String, val: int, col: Color) -> void:
        draw_string(font, Vector2(x, y), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COL_TEXT_MAIN)
        var bar_x := x + 58.0
        var bar_w := w - 84.0
        var segs := 14
        var gap := 2.0
        var sw := (bar_w - gap * float(segs - 1)) / float(segs)
        var filled := roundi((float(val) / 100.0) * float(segs))
        for s in range(segs):
            var sx := bar_x + float(s) * (sw + gap)
            var sr := Rect2(sx, y - 8, sw, 8)
            if s < filled:
                draw_rect(sr, col, true)
            else:
                draw_rect(sr, Color(0.08, 0.14, 0.22, 0.7), true)
        draw_string(font, Vector2(x + w - 20, y), "%d" % val, HORIZONTAL_ALIGNMENT_RIGHT, 20, 9, COL_TEXT_MAIN)
