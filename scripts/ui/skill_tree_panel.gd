extends PanelContainer
## FQ-06: visual skill tree navigator (preloaded by hud.gd — no class_name,
## matching the registry pattern, so plain runs never depend on the editor's
## global class cache). Node buttons are laid out from the
## data-driven grid positions in data/progression/perks.json inside a
## ScrollContainer; the inspector shows the selected node; the learn button
## spends real level-derived perk points. Locked / available / purchased
## states come from game_root.perk_state. One live lane (Miner) for now;
## the other lanes are listed as planned.
##
## FQ-09S: presentation-only star-map treatment. The canvas draws a
## deterministic night-sky starfield, faint constellation links between
## prerequisite nodes, and a small star glyph above each node plaque; node
## buttons wear dark plaques with state-colored borders. All mechanics —
## perk data, point economy, prerequisites, save ownership, K/Esc behavior,
## and the try_purchase_perk purchase path — are untouched, and the
## inspector text format is byte-identical to FQ-06.

signal purchase_requested(perk_id: String)

## Calling system: the panel shows the character's Calling as two readable Path
## CARDS side by side. Each card is a vertical list of its skills grouped by tier
## (I / II / III / Capstone), one skill per row — no horizontal scrolling, nothing
## truncated. Tier/Calling gating come from game_root.perk_state.
const NODE_SIZE := Vector2(250, 34)
const ROW_STEP := 38.0            # vertical step between skill rows
const TIER_HEADER_H := 22.0       # height of a tier header row
const COLUMN_GAP := 24.0          # gap between the two Path cards
const CANVAS_MARGIN := Vector2(14, 14)
## Tier rows top-to-bottom.
const TIER_ORDER := ["1", "2", "3", "capstone"]
const TIER_LABELS := {"1": "TIER I", "2": "TIER II", "3": "TIER III", "capstone": "CAPSTONE"}

## PR-08: the panel is sized as a fraction of the logical viewport (clamped)
## and re-centred whenever the viewport resizes, so it stays roomy at 1280x720
## and fits cleanly when the same-aspect layout scales down to 640x360, instead
## of the old fixed 540x420 with a cramped 500x180 graph. The graph lives in a
## ScrollContainer that expands to fill, so the star-map stays usable as lanes
## grow. VIEWPORT_FRACTION leaves a margin; MIN/MAX bound it for tiny/huge views.
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

## FQ-09S palette: deep night sky, parchment-ish text, faint links.
const SKY_COLOR := Color(0.045, 0.055, 0.11, 0.97)
const SKY_BORDER := Color(0.35, 0.40, 0.58)
const TEXT_WARM := Color(0.92, 0.90, 0.80)
const TEXT_DIM := Color(0.58, 0.62, 0.75)
const PLAQUE_BG := Color(0.08, 0.09, 0.16, 0.92)
const LINK_OWNED := Color(0.62, 0.92, 0.62, 0.55)
const LINK_OPEN := Color(0.85, 0.88, 1.0, 0.35)
const LINK_LOCKED := Color(0.55, 0.58, 0.70, 0.18)
const STARFIELD_SEED := 20260709
const STARFIELD_COUNT := 110

var game_root: Node
var _selected_id := ""
var _title_label: Label
var _points_label: Label
var _info_label: Label
var _buy_button: Button
var _planned_label: Label
var _canvas: Control
var _node_buttons: Dictionary = {}   # perk_id -> Button
var _aux_labels: Array = []          # Path/tier header labels (freed on rebuild)
var _node_states: Dictionary = {}    # perk_id -> "purchased"/"available"/"locked"
var _links: Array = []               # [prereq_id, perk_id] pairs in the live lane
var _state_styles: Dictionary = {}   # state -> StyleBoxFlat for node plaques


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
	# One StyleBoxFlat per state, intentionally shared by every button in
	# that state (clone before mutating if a per-button tweak is ever needed).
	for state: String in STATE_COLORS:
		var plaque := StyleBoxFlat.new()
		plaque.bg_color = PLAQUE_BG
		plaque.border_color = STATE_COLORS[state]
		plaque.set_border_width_all(1)
		_state_styles[state] = plaque
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
	# PR-08: the graph fills the panel width and expands to take the space left
	# after the fixed header/inspector rows, so it grows with the viewport and
	# stays usable as lanes are added; the ScrollContainer pans the larger canvas.
	scroll.custom_minimum_size = Vector2(0, MIN_GRAPH_HEIGHT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
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
	hint.text = "Press K to close"
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


## Calling system: lay out the character's Calling as two Path CARDS side by
## side. Each card is a vertical list: a Path header, then each tier's header
## followed by that tier's skills one per row. No horizontal scroll, no
## truncation. Path/tier gating comes from game_root.perk_state.
func _build_nodes() -> void:
	for existing in _node_buttons.values():
		existing.queue_free()
	_node_buttons.clear()
	for lbl in _aux_labels:
		lbl.queue_free()
	_aux_labels.clear()
	_links.clear()
	var calling := str(game_root.current_calling())
	var my_lanes: Array = []
	var other: Array[String] = []
	for lane: Dictionary in game_root.perk_lanes():
		if str(lane.get("calling", "")) == calling:
			my_lanes.append(lane)
		else:
			other.append(str(lane.get("display_name", "?")))
	_planned_label.text = "Other Callings' Paths: %s" % ", ".join(other)
	# Widen the two Path cards to fill the panel so they're balanced (not a narrow
	# pair against an empty right half). Derived from the live panel width, minus
	# margins, the column gap, and room for the scrollbar; floored for tiny views.
	var lanes_n: int = maxi(1, my_lanes.size())
	var avail := maxf(panel_size().x - 2.0 * CANVAS_MARGIN.x - 22.0, MIN_PANEL.x - 40.0)
	var col_w := maxf(200.0, (avail - float(lanes_n - 1) * COLUMN_GAP) / float(lanes_n))
	var max_y := 0.0
	for li in range(my_lanes.size()):
		var lane: Dictionary = my_lanes[li]
		var x := CANVAS_MARGIN.x + float(li) * (col_w + COLUMN_GAP)
		var y := CANVAS_MARGIN.y
		var header := _make_label(str(lane.get("display_name", "?")).to_upper(), 14, TEXT_WARM)
		header.position = Vector2(x, y)
		header.custom_minimum_size = Vector2(col_w, 0)
		y += TIER_HEADER_H + 2.0
		var tiered: Dictionary = {}
		for perk: Dictionary in lane.get("perks", []):
			var tk: String = game_root.tier_key_of(perk)
			if not tiered.has(tk):
				tiered[tk] = []
			tiered[tk].append(perk)
		for tier_key: String in TIER_ORDER:
			var perks: Array = tiered.get(tier_key, [])
			if perks.is_empty():
				continue
			var tlabel := _make_label(str(TIER_LABELS.get(tier_key, tier_key)), 11, TEXT_DIM)
			tlabel.position = Vector2(x, y)
			y += TIER_HEADER_H
			for perk: Dictionary in perks:
				var perk_id := str(perk.get("id", ""))
				var btn := Button.new()
				btn.custom_minimum_size = Vector2(col_w, NODE_SIZE.y)
				btn.position = Vector2(x, y)
				btn.clip_text = true
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.add_theme_font_size_override("font_size", 12)
				btn.pressed.connect(_on_node_pressed.bind(perk_id))
				_canvas.add_child(btn)
				_node_buttons[perk_id] = btn
				y += ROW_STEP
			y += 4.0
		max_y = maxf(max_y, y)
	_canvas.custom_minimum_size = Vector2(
		CANVAS_MARGIN.x * 2.0 + float(maxi(1, my_lanes.size())) * (col_w + COLUMN_GAP),
		max_y + CANVAS_MARGIN.y)


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
		var btn: Button = _node_buttons[perk_id]
		var perk: Dictionary = game_root.get_perk(perk_id)
		var state: String = game_root.perk_state(perk_id)
		_node_states[perk_id] = state
		var state_color: Color = STATE_COLORS.get(state, Color.WHITE)
		var plaque: StyleBoxFlat = _state_styles.get(state, _state_styles["locked"])
		for style_name in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(style_name, plaque)
		for color_name in ["font_color", "font_hover_color",
				"font_pressed_color", "font_focus_color"]:
			btn.add_theme_color_override(color_name, state_color)
		var marker := ""
		match state:
			"purchased": marker = "✓ "
			"available": marker = "● "
			"coming_soon": marker = "◇ "
			_: marker = "🔒 "
		btn.text = "%s%s" % [marker, str(perk.get("display_name", perk_id))]
		btn.tooltip_text = str(perk.get("description", ""))
	_canvas.queue_redraw()
	_refresh_inspector()


## A faint deterministic starfield behind the Path cards (presentation only).
func _draw_canvas() -> void:
	var area: Vector2 = _canvas.custom_minimum_size.max(_canvas.size)
	var rng := RandomNumberGenerator.new()
	rng.seed = STARFIELD_SEED
	for _i in range(STARFIELD_COUNT):
		var at := Vector2(rng.randf() * area.x, rng.randf() * area.y)
		var bright := rng.randf()
		var dot := Color(0.75, 0.80, 0.95, 0.08 + 0.18 * bright)
		_canvas.draw_rect(Rect2(at, Vector2.ONE * (2.0 if bright > 0.9 else 1.0)), dot)


func _refresh_inspector() -> void:
	if _selected_id == "":
		_info_label.text = "Select a node to inspect it."
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


## FQ-09S hook: number of constellation link lines (prerequisite pairs in
## the live lane) the canvas draws.
func link_count() -> int:
	return _links.size()


## Calling system hooks: how many skill nodes the panel currently shows (both
## Paths of the character's Calling), and whether a specific skill has a node.
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
