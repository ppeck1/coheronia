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

## Calling system: the panel shows the character's Calling and its two Paths,
## laid out as tier rows (I / II / III / Capstone) per Path column. Tier and
## Calling gating come from game_root.perk_state, so locked tiers read as LOCKED.
const NODE_SIZE := Vector2(150, 46)
const SPACING := Vector2(180, 76)
## Horizontal gap between the two Path columns (each Path is a stack of tier rows).
const PATH_GAP := 150.0
const CANVAS_MARGIN := Vector2(20, 26)
## Tier rows top-to-bottom.
const TIER_ORDER := ["1", "2", "3", "capstone"]
const TIER_LABELS := {"1": "I", "2": "II", "3": "III", "capstone": "Capstone"}

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


## Calling system: lay out the character's Calling as two Path columns, each a
## vertical stack of tier rows (I / II / III / Capstone) with the skills of that
## tier spread horizontally. Path/tier gating comes from game_root.perk_state.
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
	var col_width := 0.0
	for lane: Dictionary in my_lanes:
		var tiered: Dictionary = {}
		for perk: Dictionary in lane.get("perks", []):
			var tk: String = game_root.tier_key_of(perk)
			if not tiered.has(tk):
				tiered[tk] = []
			tiered[tk].append(perk)
		var widest := 1
		for tk in tiered:
			widest = maxi(widest, (tiered[tk] as Array).size())
		col_width = maxf(col_width, float(widest) * SPACING.x + PATH_GAP)
	var max_x := 0.0
	var max_y := 0.0
	for li in range(my_lanes.size()):
		var lane: Dictionary = my_lanes[li]
		var base_x := CANVAS_MARGIN.x + float(li) * col_width
		var header := Label.new()
		header.text = str(lane.get("display_name", "?")).to_upper()
		header.position = Vector2(base_x, 0.0)
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", TEXT_WARM)
		_canvas.add_child(header)
		_aux_labels.append(header)
		var tiered: Dictionary = {}
		for perk: Dictionary in lane.get("perks", []):
			var tk: String = game_root.tier_key_of(perk)
			if not tiered.has(tk):
				tiered[tk] = []
			tiered[tk].append(perk)
		for ti in range(TIER_ORDER.size()):
			var tier_key: String = TIER_ORDER[ti]
			var perks: Array = tiered.get(tier_key, [])
			if perks.is_empty():
				continue
			var row_y := CANVAS_MARGIN.y + float(ti) * SPACING.y
			var tlabel := Label.new()
			tlabel.text = str(TIER_LABELS.get(tier_key, tier_key))
			tlabel.position = Vector2(base_x - 4.0, row_y - 2.0)
			tlabel.add_theme_font_size_override("font_size", 11)
			tlabel.add_theme_color_override("font_color", TEXT_DIM)
			_canvas.add_child(tlabel)
			_aux_labels.append(tlabel)
			for pi in range(perks.size()):
				var perk: Dictionary = perks[pi]
				var perk_id := str(perk.get("id", ""))
				var at := Vector2(base_x + float(pi) * SPACING.x, row_y + 14.0)
				var btn := Button.new()
				btn.custom_minimum_size = NODE_SIZE
				btn.position = at
				btn.pressed.connect(_on_node_pressed.bind(perk_id))
				_canvas.add_child(btn)
				_node_buttons[perk_id] = btn
				max_x = maxf(max_x, at.x + NODE_SIZE.x)
				max_y = maxf(max_y, at.y + NODE_SIZE.y)
				for prereq in perk.get("prerequisites", []):
					_links.append([str(prereq), perk_id])
	_canvas.custom_minimum_size = Vector2(max_x + CANVAS_MARGIN.x, max_y + CANVAS_MARGIN.y)


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
		if state == "purchased":
			marker = "[OWNED] "
		elif state == "locked":
			marker = "[LOCKED] "
		btn.text = "%s%s (%d)" % [marker, str(perk.get("display_name", perk_id)),
			int(perk.get("cost", 1))]
	_canvas.queue_redraw()
	_refresh_inspector()


## FQ-09S: night-sky canvas — deterministic starfield, faint constellation
## links between prerequisite nodes, and a star glyph above each plaque.
## Presentation only: everything drawn here derives from the same perk data
## and perk_state the buttons already use.
func _draw_canvas() -> void:
	var area: Vector2 = _canvas.custom_minimum_size.max(_canvas.size)
	var rng := RandomNumberGenerator.new()
	rng.seed = STARFIELD_SEED
	for _i in range(STARFIELD_COUNT):
		var at := Vector2(rng.randf() * area.x, rng.randf() * area.y)
		var bright := rng.randf()
		var dot := Color(0.75, 0.80, 0.95, 0.10 + 0.25 * bright)
		_canvas.draw_rect(Rect2(at, Vector2.ONE * (2.0 if bright > 0.9 else 1.0)), dot)
	for link: Array in _links:
		var from_btn: Button = _node_buttons.get(link[0])
		var to_btn: Button = _node_buttons.get(link[1])
		if from_btn == null or to_btn == null:
			continue
		var from_state: String = _node_states.get(link[0], "locked")
		var to_state: String = _node_states.get(link[1], "locked")
		var color := LINK_LOCKED
		if from_state == "purchased" and to_state == "purchased":
			color = LINK_OWNED
		elif to_state == "available":
			color = LINK_OPEN
		_canvas.draw_line(from_btn.position + NODE_SIZE / 2.0,
			to_btn.position + NODE_SIZE / 2.0, color, 1.0)
	for perk_id in _node_buttons:
		var btn: Button = _node_buttons[perk_id]
		var state: String = _node_states.get(perk_id, "locked")
		var star_color: Color = STATE_COLORS.get(state, Color.WHITE)
		if state == "locked":
			star_color.a = 0.5
		var center: Vector2 = btn.position + Vector2(NODE_SIZE.x / 2.0, -8.0)
		var arm := 4.0 if state == "purchased" else 3.0
		_canvas.draw_line(center + Vector2(-arm, 0), center + Vector2(arm, 0), star_color, 1.0)
		_canvas.draw_line(center + Vector2(0, -arm), center + Vector2(0, arm), star_color, 1.0)
		if state == "purchased":
			var d := arm * 0.5
			_canvas.draw_line(center + Vector2(-d, -d), center + Vector2(d, d), star_color, 1.0)
			_canvas.draw_line(center + Vector2(-d, d), center + Vector2(d, -d), star_color, 1.0)


func _refresh_inspector() -> void:
	if _selected_id == "":
		_info_label.text = "Select a node to inspect it."
		_buy_button.disabled = true
		return
	var perk: Dictionary = game_root.get_perk(_selected_id)
	var state: String = game_root.perk_state(_selected_id)
	var path := str(perk.get("lane", ""))
	var tier_key: String = game_root.tier_key_of(perk)
	var tier_label := str(TIER_LABELS.get(tier_key, tier_key))
	var gate: int = game_root.tier_gate(tier_key)
	var in_path: int = game_root.skills_purchased_in_path(path)
	var gate_note := "open" if in_path >= gate else "needs %d in Path (have %d)" % [gate, in_path]
	var support := str(perk.get("support", "live"))
	_info_label.text = "%s — %s · Tier %s (%s)\nCost: %d point%s · Effect: %s x%.2f · Support: %s\n%s" % [
		str(perk.get("display_name", _selected_id)), state.to_upper(), tier_label, gate_note,
		int(perk.get("cost", 1)), "" if int(perk.get("cost", 1)) == 1 else "s",
		str(perk.get("effect_key", "?")), float(perk.get("effect_value", 0.0)), support,
		str(perk.get("description", ""))]
	_buy_button.disabled = not (state == "available"
		and int(perk.get("cost", 1)) <= game_root.perk_points_available())


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
