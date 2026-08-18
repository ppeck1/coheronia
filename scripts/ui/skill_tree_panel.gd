extends PanelContainer
## FQ-06: visual skill tree navigator (preloaded by hud.gd — no class_name,
## matching the registry pattern, so plain runs never depend on the editor's
## global class cache). The panel shows the character's Calling; each Path is a
## constellation of star skills the player clicks to inspect/learn. The inspector
## shows the selected star; the learn button spends real level-derived perk
## points. Locked / available / purchased states come from game_root.perk_state.
##
## FQ-09S / S-07-CONSTELLATION: presentation-only "star map" treatment. The
## panel renders each Path as a CONSTELLATION on a dark starfield: every skill is
## a STAR laid out by tier (Tier I at the top down to the Capstone), joined by
## faint constellation lines into a shape you can read as one Path. Clicking a
## star selects it (name / tier / status / description / cost) and, when eligible,
## learns it. Purchased stars glow bright, the next-available stars twinkle to
## draw the eye, and locked / unaffordable stars stay dim. ALL mechanics — perk
## data, point economy, tier gates, purchase path, save ownership, and the
## inspector text format — are untouched from FQ-06, and every public
## method/signal the HUD and smoke suite depend on is preserved.

signal purchase_requested(perk_id: String)

## Calling system: the panel shows the character's Calling as two Path
## CONSTELLATIONS side by side. Each constellation is its own cluster of stars,
## arranged tier-by-tier (I / II / III / Capstone) top-to-bottom, so no
## horizontal scrolling is needed and nothing is truncated. Tier/Calling gating
## come from game_root.perk_state.

## Layout constants. Stars are hit-tested by a small transparent Button placed at
## the star centre; the star glyph, glow, label and links are drawn on the canvas.
const STAR_HIT := Vector2(26, 26)  # click target size for one star
const STAR_R := 5.0                # base star-glyph radius (drawn)
const TIER_ROW_STEP := 62.0        # vertical step between tier rows
const TIER_TOP_PAD := 34.0         # room for the Path header above the first row
const COLUMN_GAP := 26.0           # gap between the two Path constellations
const CANVAS_MARGIN := Vector2(16, 14)
const LABEL_DY := 11.0             # star-name offset below the star centre
## Tier rows top-to-bottom.
const TIER_ORDER := ["1", "2", "3", "capstone"]
const TIER_LABELS := {"1": "TIER I", "2": "TIER II", "3": "TIER III", "capstone": "CAPSTONE"}

## PR-08: the panel is sized as a fraction of the logical viewport (clamped)
## and re-centred whenever the viewport resizes, so it stays roomy at 1280x720
## and fits cleanly when the same-aspect layout scales down to 640x360. The
## constellation lives in a ScrollContainer that expands to fill, so the star map
## stays usable as Paths grow. VIEWPORT_FRACTION leaves a margin; MIN/MAX bound it
## for tiny/huge views.
const VIEWPORT_FRACTION := Vector2(0.9, 0.9)
const MIN_PANEL := Vector2(480, 300)
const MAX_PANEL := Vector2(1100, 660)
const VIEWPORT_MARGIN := 16.0
const MIN_GRAPH_HEIGHT := 110.0

const STATE_COLORS := {
	"purchased": Color(0.55, 0.95, 0.55),
	"available": Color(1.0, 1.0, 1.0),
	"locked": Color(0.55, 0.55, 0.62),
	"coming_soon": Color(0.70, 0.60, 0.90),
}

## Star-map palette: deep night sky, parchment-ish text, faint links.
const SKY_COLOR := Color(0.035, 0.045, 0.10, 0.98)
const SKY_BORDER := Color(0.35, 0.40, 0.58)
const TEXT_WARM := Color(0.92, 0.90, 0.80)
const TEXT_DIM := Color(0.58, 0.62, 0.75)
## Constellation link colours, keyed to the connection's "strongest" endpoint so
## an owned constellation reads brighter than a locked one.
const LINK_OWNED := Color(0.62, 0.92, 0.62, 0.55)
const LINK_OPEN := Color(0.85, 0.88, 1.0, 0.32)
const LINK_LOCKED := Color(0.55, 0.58, 0.70, 0.16)
const STARFIELD_SEED := 20260709
const STARFIELD_COUNT := 150
const LAYOUT_SEED := 733991      # deterministic per-star jitter -> organic shapes

var game_root: Node
var _selected_id := ""
var _title_label: Label
var _points_label: Label
var _info_label: Label
var _buy_button: Button
var _planned_label: Label
var _canvas: Control
var _scroll: ScrollContainer          # S-07.1b hook: the card scroll (h disabled)
var _node_buttons: Dictionary = {}   # perk_id -> Button (transparent star hit target)
var _aux_labels: Array = []          # Path header labels (freed on rebuild)
var _node_states: Dictionary = {}    # perk_id -> "purchased"/"available"/"locked"/...
var _node_pos: Dictionary = {}       # perk_id -> Vector2 star centre on the canvas
var _node_names: Dictionary = {}     # perk_id -> display name (drawn under the star)
var _links: Array = []               # [id_a, id_b] constellation line pairs
var _twinkle := 0.0                  # bounded animation phase for available stars


func _ready() -> void:
	# PR-08: centre-anchored; the size is computed from the viewport in
	# _apply_layout and refreshed on every viewport resize.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	# Draw above sibling HUD modules (events banner, crest) so nothing obscures it.
	z_index = 60
	visible = false
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	var sky := StyleBoxFlat.new()
	sky.bg_color = SKY_COLOR
	sky.border_color = SKY_BORDER
	sky.set_border_width_all(1)
	sky.set_content_margin_all(10)
	add_theme_stylebox_override("panel", sky)
	var box := VBoxContainer.new()
	add_child(box)
	_title_label = Label.new()
	_title_label.text = "CALLING"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", TEXT_WARM)
	box.add_child(_title_label)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 13)
	_points_label.add_theme_color_override("font_color", TEXT_WARM)
	box.add_child(_points_label)
	var scroll := ScrollContainer.new()
	# PR-08: the star map fills the panel width and expands to take the space left
	# after the fixed header/inspector rows, so it grows with the viewport and
	# stays usable as Paths are added; the ScrollContainer pans the larger canvas.
	# S-07.1b (F7): the two constellations are sized to fit the width, so the
	# panel must never show a horizontal scrollbar — disable it (vertical stays for
	# tall Paths). Removes the h-scrollbar that appeared at 640x360.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, MIN_GRAPH_HEIGHT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_scroll = scroll
	_canvas = Control.new()
	_canvas.draw.connect(_draw_canvas)
	scroll.add_child(_canvas)
	_info_label = Label.new()
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(0, 52)
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.add_theme_color_override("font_color", TEXT_WARM)
	box.add_child(_info_label)
	_buy_button = Button.new()
	_buy_button.text = "Learn perk"
	_buy_button.disabled = true
	_buy_button.pressed.connect(_on_buy_pressed)
	box.add_child(_buy_button)
	_planned_label = Label.new()
	_planned_label.add_theme_font_size_override("font_size", 12)
	_planned_label.add_theme_color_override("font_color", TEXT_DIM)
	_planned_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_planned_label)
	var hint := Label.new()
	hint.text = "Click a star to inspect · Press K to close"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	box.add_child(hint)


## PR-08: size the panel to a fraction of the logical viewport, clamped to a
## sane min/max and never past the viewport edges, and re-centre it. Runs at
## _ready and on every viewport resize so the panel is roomy at 1280x720 and
## fits cleanly when the same-aspect layout scales down to 640x360. Centre
## anchors keep it centred; only the offsets change.
func _apply_layout() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var s := panel_size_for(vp)
	offset_left = -s.x / 2.0
	offset_right = s.x / 2.0
	offset_top = -s.y / 2.0
	offset_bottom = s.y / 2.0
	# The constellation coordinates are derived from the panel width, so rebuild
	# star positions when the viewport (and thus the panel) resizes.
	if game_root != null:
		_build_nodes()
		refresh()


## The panel size for a given logical viewport: a clamped fraction that never
## exceeds the viewport minus a margin, so it is roomy on large views and fits
## cleanly on small ones. Pure and side-effect free so the smoke can pin it at
## the target sizes (640x360 and 1280x720).
func panel_size_for(vp: Vector2) -> Vector2:
	var w := clampf(vp.x * VIEWPORT_FRACTION.x, MIN_PANEL.x, MAX_PANEL.x)
	var h := clampf(vp.y * VIEWPORT_FRACTION.y, MIN_PANEL.y, MAX_PANEL.y)
	w = minf(w, vp.x - VIEWPORT_MARGIN)
	h = minf(h, vp.y - VIEWPORT_MARGIN)
	return Vector2(w, h)


## The current panel size in logical viewport pixels (PR-08 smoke hook).
func panel_size() -> Vector2:
	return Vector2(offset_right - offset_left, offset_bottom - offset_top)


## Called once by game_root._wire_references via hud.setup_skill_panel.
func setup(root: Node) -> void:
	game_root = root
	_build_nodes()
	refresh()


## Calling system: lay out the character's Calling as two Path CONSTELLATIONS
## side by side. Each Path is a vertical cluster of star hit-targets: a header,
## then each tier's stars placed on that tier's row with a deterministic
## horizontal jitter (so the shape reads as a constellation, not a grid). The
## drawn glyphs, labels, and constellation links come from _node_pos / _links.
## No horizontal scroll, no truncation. Path/tier gating comes from
## game_root.perk_state.
func _build_nodes() -> void:
	for existing in _node_buttons.values():
		existing.queue_free()
	_node_buttons.clear()
	for lbl in _aux_labels:
		lbl.queue_free()
	_aux_labels.clear()
	_links.clear()
	_node_pos.clear()
	_node_names.clear()
	var calling := str(game_root.current_calling())
	var my_lanes: Array = []
	var other: Array[String] = []
	for lane: Dictionary in game_root.perk_lanes():
		if str(lane.get("calling", "")) == calling:
			my_lanes.append(lane)
		else:
			other.append(str(lane.get("display_name", "?")))
	_planned_label.text = "Other Callings' Paths: %s" % ", ".join(other)
	# Two constellations fill the panel width (not a narrow pair against an empty
	# half). Column width is derived from the live panel width minus margins, the
	# gap between constellations, and room for the scrollbar; floored for tiny
	# views. Keeping the laid-out canvas within the panel width is the F7 contract
	# (content_h_scroll_disabled + canvas_min_width <= panel width).
	var lanes_n: int = maxi(1, my_lanes.size())
	var avail := maxf(panel_size().x - 2.0 * CANVAS_MARGIN.x - 22.0, MIN_PANEL.x - 40.0)
	var col_w := maxf(190.0, (avail - float(lanes_n - 1) * COLUMN_GAP) / float(lanes_n))
	var rng := RandomNumberGenerator.new()
	var max_y := 0.0
	for li in range(my_lanes.size()):
		var lane: Dictionary = my_lanes[li]
		var lane_id := str(lane.get("id", "lane%d" % li))
		var x0 := CANVAS_MARGIN.x + float(li) * (col_w + COLUMN_GAP)
		var header := _make_label(str(lane.get("display_name", "?")).to_upper(), 14, TEXT_WARM)
		header.position = Vector2(x0, CANVAS_MARGIN.y)
		header.custom_minimum_size = Vector2(col_w, 0)
		# Bucket this Path's skills by tier so each tier gets its own row.
		var tiered: Dictionary = {}
		for perk: Dictionary in lane.get("perks", []):
			var tk: String = game_root.tier_key_of(perk)
			if not tiered.has(tk):
				tiered[tk] = []
			tiered[tk].append(perk)
		var y := CANVAS_MARGIN.y + TIER_TOP_PAD
		# Track the previous tier's star ids so we can chain constellation links
		# down the Path (a purely presentational "spine" for the shape).
		var prev_row_ids: Array[String] = []
		for tier_key: String in TIER_ORDER:
			var perks: Array = tiered.get(tier_key, [])
			if perks.is_empty():
				continue
			var row_ids: Array[String] = []
			var n: int = perks.size()
			# Spread this tier's stars across the column width; deterministic jitter
			# keeps the layout organic yet stable across rebuilds and runs.
			for i in range(n):
				var perk: Dictionary = perks[i]
				var perk_id := str(perk.get("id", ""))
				# Even horizontal slots inside the column, inset from the edges.
				var t := (float(i) + 0.5) / float(n)
				var cx := x0 + 14.0 + t * (col_w - 28.0)
				rng.seed = hash(perk_id) ^ LAYOUT_SEED
				var jx := (rng.randf() - 0.5) * (col_w / float(maxi(n, 2))) * 0.55
				var jy := (rng.randf() - 0.5) * (TIER_ROW_STEP * 0.30)
				var pos := Vector2(cx + jx, y + jy)
				_node_pos[perk_id] = pos
				_node_names[perk_id] = str(perk.get("display_name", perk_id))
				var btn := Button.new()
				btn.flat = true
				btn.focus_mode = Control.FOCUS_NONE
				btn.custom_minimum_size = STAR_HIT
				btn.size = STAR_HIT
				btn.position = pos - STAR_HIT * 0.5
				btn.tooltip_text = str(perk.get("display_name", perk_id))
				# Fully transparent: the star glyph itself is drawn on the canvas,
				# the Button is only the click target.
				var empty := StyleBoxEmpty.new()
				for sn in ["normal", "hover", "pressed", "focus"]:
					btn.add_theme_stylebox_override(sn, empty)
				btn.pressed.connect(_on_node_pressed.bind(perk_id))
				_canvas.add_child(btn)
				_node_buttons[perk_id] = btn
				row_ids.append(perk_id)
			# Constellation "spine": link each star in this tier to the nearest
			# star in the tier above, weaving the Path into one continuous shape.
			for rid: String in row_ids:
				var nearest := _nearest_id(rid, prev_row_ids)
				if nearest != "":
					_links.append([nearest, rid])
			# Also thread neighbours within the same tier row so a wide tier still
			# reads as a connected arc rather than loose points.
			for i in range(1, row_ids.size()):
				_links.append([row_ids[i - 1], row_ids[i]])
			prev_row_ids = row_ids
			y += TIER_ROW_STEP
		max_y = maxf(max_y, y)
	# S-07.1b (F7): exact content extent — N columns + (N-1) gaps + both margins.
	# The canvas never exceeds the panel width, so no horizontal scrollbar appears.
	_canvas.custom_minimum_size = Vector2(
		CANVAS_MARGIN.x * 2.0 + float(lanes_n) * col_w + float(lanes_n - 1) * COLUMN_GAP,
		max_y + CANVAS_MARGIN.y)


## The id in `candidates` whose star is horizontally closest to `from_id`, used to
## draw a tidy constellation spine between tiers. Empty when there is no prior
## row (the first tier).
func _nearest_id(from_id: String, candidates: Array) -> String:
	if candidates.is_empty():
		return ""
	var from_pos: Vector2 = _node_pos.get(from_id, Vector2.ZERO)
	var best := ""
	var best_d := INF
	for cid: String in candidates:
		var cpos: Vector2 = _node_pos.get(cid, Vector2.ZERO)
		var d: float = absf(cpos.x - from_pos.x)
		if d < best_d:
			best_d = d
			best = cid
	return best


## Small helper: a canvas label tracked for cleanup on the next rebuild.
func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	_canvas.add_child(lbl)
	_aux_labels.append(lbl)
	return lbl


func refresh() -> void:
	if game_root == null:
		return
	var calling := str(game_root.current_calling())
	var cdef: Dictionary = BlockRegistry.calling_def(calling)
	var innate: Dictionary = cdef.get("innate", {})
	_title_label.text = "CALLING — %s · Innate: %s" % [
		str(cdef.get("display_name", calling)).to_upper(),
		str(innate.get("name", "—"))]
	_points_label.text = "Perk points: %d available / %d total (1 per level above 1)" % [
		game_root.perk_points_available(), game_root.perk_points_total()]
	for perk_id in _node_buttons:
		_node_states[perk_id] = str(game_root.perk_state(perk_id))
	_maybe_toggle_process()
	_canvas.queue_redraw()
	_refresh_inspector()


## Only animate (twinkle the next-available stars) while the panel is visible and
## at least one star is available — keeps per-frame work bounded and off entirely
## when nothing needs to pulse.
func _maybe_toggle_process() -> void:
	var any_available := false
	for st in _node_states.values():
		if str(st) == "available":
			any_available = true
			break
	set_process(visible and any_available)


func _notification(what: int) -> void:
	# VISIBILITY_CHANGED can fire while the HUD parents this panel, before setup()
	# has built the canvas — guard against the not-yet-constructed node.
	if what == NOTIFICATION_VISIBILITY_CHANGED and _canvas != null:
		_maybe_toggle_process()
		if visible:
			_canvas.queue_redraw()


func _process(delta: float) -> void:
	# Bounded phase in [0, TAU); only the available stars redraw-pulse. Cheap:
	# one queue_redraw per frame while the panel is open with available stars.
	_twinkle = fmod(_twinkle + delta * 3.0, TAU)
	_canvas.queue_redraw()


## The star map: a deterministic background starfield, the constellation links
## for both Paths, then a glowing star glyph + name for every skill, coloured by
## its purchased / available / locked / coming-soon state.
func _draw_canvas() -> void:
	var area: Vector2 = _canvas.custom_minimum_size.max(_canvas.size)
	_draw_starfield(area)
	# Constellation lines first, so stars sit on top of them.
	for pair: Array in _links:
		var a: Vector2 = _node_pos.get(pair[0], Vector2.ZERO)
		var b: Vector2 = _node_pos.get(pair[1], Vector2.ZERO)
		if a == Vector2.ZERO or b == Vector2.ZERO:
			continue
		_canvas.draw_line(a, b, _link_color(pair[0], pair[1]), 1.0, true)
	# Stars on top.
	for perk_id in _node_buttons:
		_draw_star(perk_id)


## A faint deterministic starfield behind the constellations (presentation only).
func _draw_starfield(area: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STARFIELD_SEED
	for _i in range(STARFIELD_COUNT):
		var at := Vector2(rng.randf() * area.x, rng.randf() * area.y)
		var bright := rng.randf()
		var col := Color(0.75, 0.80, 0.95, 0.06 + 0.16 * bright)
		if bright > 0.94:
			# A few brighter background stars with a tiny cross-glow.
			_canvas.draw_circle(at, 1.6, col)
		else:
			_canvas.draw_rect(Rect2(at, Vector2.ONE * (1.0 if bright > 0.5 else 1.0)), col)


## Link colour reflects the "strongest" of its two endpoints so an owned
## constellation reads brighter than a still-locked one.
func _link_color(id_a: String, id_b: String) -> Color:
	var sa := str(_node_states.get(id_a, "locked"))
	var sb := str(_node_states.get(id_b, "locked"))
	if sa == "purchased" and sb == "purchased":
		return LINK_OWNED
	if sa == "purchased" or sb == "purchased" or sa == "available" or sb == "available":
		return LINK_OPEN
	return LINK_LOCKED


## Draw one skill's star: a soft glow halo, the core glyph, a selection ring, and
## the star name beneath it. Purchased stars glow bright; the next-available
## stars twinkle (a pulsing halo) to draw the eye; locked / unaffordable stars
## are dim.
func _draw_star(perk_id: String) -> void:
	var pos: Vector2 = _node_pos.get(perk_id, Vector2.ZERO)
	if pos == Vector2.ZERO:
		return
	var state := str(_node_states.get(perk_id, "locked"))
	var base: Color = STATE_COLORS.get(state, STATE_COLORS["locked"])
	var r := STAR_R
	var glow_a := 0.10
	match state:
		"purchased":
			r = STAR_R + 1.0
			glow_a = 0.32
		"available":
			# Twinkle: the halo pulses so the next stars you can learn stand out.
			var pulse := 0.5 + 0.5 * sin(_twinkle + float(hash(perk_id) % 100) * 0.06)
			glow_a = 0.22 + 0.30 * pulse
			r = STAR_R + 0.8 * pulse
		"coming_soon":
			glow_a = 0.14
		_:
			glow_a = 0.08
			base = base.darkened(0.15)
	# Glow halo (larger, translucent) then the bright core.
	_canvas.draw_circle(pos, r * 2.6, Color(base.r, base.g, base.b, glow_a))
	_canvas.draw_circle(pos, r * 1.7, Color(base.r, base.g, base.b, glow_a * 0.6))
	_canvas.draw_circle(pos, r, base)
	# White-hot centre for owned/available so they read as "lit".
	if state == "purchased" or state == "available":
		_canvas.draw_circle(pos, r * 0.45, Color(1, 1, 1, 0.9))
	# Selection ring.
	if perk_id == _selected_id:
		_canvas.draw_arc(pos, r + 4.0, 0.0, TAU, 28, Color(1.0, 0.92, 0.55, 0.95), 1.5, true)
	# Star name beneath the glyph.
	var font := _canvas.get_theme_default_font()
	var fsize := 11
	var name_str := str(_node_names.get(perk_id, perk_id))
	var tw := font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var name_col := TEXT_WARM if (state == "purchased" or state == "available") else TEXT_DIM
	if perk_id == _selected_id:
		name_col = Color(1.0, 0.95, 0.70)
	_canvas.draw_string(font, pos + Vector2(-tw * 0.5, r + LABEL_DY + fsize),
		name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, name_col)


func _refresh_inspector() -> void:
	if _selected_id == "":
		_info_label.text = "Select a star to inspect it."
		_buy_button.disabled = true
		return
	var perk: Dictionary = game_root.get_perk(_selected_id)
	var state: String = game_root.perk_state(_selected_id)
	var path := str(perk.get("lane", ""))
	var tier_key: String = game_root.tier_key_of(perk)
	var tier_label := str(TIER_LABELS.get(tier_key, tier_key)).capitalize()
	var cost: int = int(perk.get("cost", 1))
	# Player-language status line — no effect keys or support flags.
	var status := ""
	match state:
		"purchased": status = "Learned"
		"available": status = "Ready to learn"
		"coming_soon": status = "Coming soon"
		_:
			var gate: int = game_root.effective_tier_gate(path, tier_key)
			var in_path: int = game_root.skills_purchased_in_path(path)
			if path not in BlockRegistry.calling_paths(game_root.current_calling()):
				status = "Locked — a different Calling's Path"
			elif in_path < gate:
				status = "Locked — learn %d more skill%s in this Path first" % [
					gate - in_path, "" if gate - in_path == 1 else "s"]
			else:
				status = "Locked"
	_info_label.text = "%s  ·  %s  ·  %s\n%s\nCost: %d perk point%s" % [
		str(perk.get("display_name", _selected_id)), tier_label, status,
		str(perk.get("description", "")), cost, "" if cost == 1 else "s"]
	_buy_button.disabled = not (state == "available"
		and cost <= game_root.perk_points_available())
	_buy_button.text = "Learn skill" if state != "coming_soon" else "Coming soon"


## Smoke/test hooks.
func info_text() -> String:
	return _info_label.text


## FQ-09S hook: number of constellation link lines the canvas draws between the
## stars of the character's Paths.
func link_count() -> int:
	return _links.size()


## S-07.1b hooks: the constellation scroll disables horizontal scrolling, and the
## laid-out canvas fits the panel width (so no horizontal scrollbar is ever
## needed — the F7 fix). Pure reads for the smoke contract.
func content_h_scroll_disabled() -> bool:
	return _scroll != null \
		and _scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED


func canvas_min_width() -> float:
	return _canvas.custom_minimum_size.x if _canvas != null else 0.0


## Calling system hooks: how many skill stars the panel currently shows (both
## Paths of the character's Calling), and whether a specific skill has a star.
func node_count() -> int:
	return _node_buttons.size()


func has_skill_node(perk_id: String) -> bool:
	return _node_buttons.has(perk_id)


func select_node(perk_id: String) -> void:
	_on_node_pressed(perk_id)


func _on_node_pressed(perk_id: String) -> void:
	_selected_id = perk_id
	refresh()


func _on_buy_pressed() -> void:
	if _selected_id != "":
		purchase_requested.emit(_selected_id)
