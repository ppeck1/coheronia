extends Control
## FQ-09C opening cinematic controller ("Coheronia DOS Vector Cinematic").
## Eight data-driven scenes authored at 640x360 and integer-scaled 2x with
## nearest-neighbor filtering into the 1280x720 viewport. All imagery is
## plotted per tick by prologue_canvas.gd (deterministic, stepped, hard
## palette); this script owns narrative data, timing, text overlays, input,
## audio cue hooks, and the finished/skip contract.
##
## Every word is engine-rendered — nothing textual is ever baked into
## imagery (authorship lock: `By Paul Peck` is a live Label on the title
## card and the persistent title screen).
##
## Interaction: any key or primary click advances one scene, Escape skips,
## scenes auto-advance on their storyboard timing when `autoplay` is on.
## `finished(completed)` fires exactly once (completed=false on skip); a
## skip also stops processing and any playing audio. The prologue never
## writes state itself; the shell owns the profile-level prologue_seen flag.

signal finished(completed: bool)

const TITLE_TEXT := "COHERONIA"
const AUTHORSHIP_TEXT := "By Paul Peck"
const TAGLINE_TEXT := "Where civilization pushes back."

const CanvasScript := preload("res://scripts/shell/prologue_canvas.gd")
const TICK_HZ := 10                      # visual updates per second
const AUDIO_DIR := "res://audio/opening" # placeholder-safe cue lookup
const DIM_COLOR := Color(0.62, 0.65, 0.75)
const PARCHMENT := Color(0.87, 0.82, 0.7)
const AMBER_UI := Color(0.89, 0.61, 0.24)

## Narrative data: exact scene order, phase, timing, overlay copy, audio cue
## id, and the animation cues each scene must realize (checked by smoke).
## Total duration 42.0s. The title card renders TITLE_TEXT / AUTHORSHIP_TEXT
## / TAGLINE_TEXT as separate engine labels instead of overlay text.
const SCENES := [
	{"id": "opening_01_first_star", "phase": "Orientation", "duration": 4.0,
		"text": "Before the first hall, the world was held together by names, roads, oaths, and light.",
		"audio": "cue_opening_01_drone_bell",
		"cues": ["plot_contour", "star_pulse"]},
	{"id": "opening_02_unraveling_roads", "phase": "Deviation", "duration": 5.0,
		"text": "Then the old compacts failed. Roads forgot their ends. Borders became dust.",
		"audio": "cue_opening_02_paper_wind",
		"cues": ["plot_map", "segmented_dissolve", "river_detach", "stepped_pan"]},
	{"id": "opening_03_scattered_peoples", "phase": "Propagation", "duration": 6.0,
		"text": "The scattered peoples carried what they could: craft, seed, iron, memory, anger, and hope.",
		"audio": "cue_opening_03_fire_steps",
		"cues": ["silhouette_reveal", "fire_cycle", "pose_shift", "ridge_parallax"]},
	{"id": "opening_04_darkness_measures_light", "phase": "Instability", "duration": 5.0,
		"text": "Hunger tested every storehouse. Storms tested every roof. The dark measured every light.",
		"audio": "cue_opening_04_thunder",
		"cues": ["torch_palette_cycle", "eyes_for_frames", "storm_steps", "lightning_frames"]},
	{"id": "opening_05_first_hall_raised", "phase": "Collapse Edge", "duration": 6.0,
		"text": "So they raised a hall—not a throne, not a temple, but a promise with a roof.",
		"audio": "cue_opening_05_hammer_chord",
		"cues": ["assemble_structure", "builder_poses", "dawn_steps", "camera_rise"]},
	{"id": "opening_06_attunement_pulse", "phase": "Insight", "duration": 5.0,
		"text": "Where shelter, food, work, and courage aligned, the world answered.",
		"audio": "cue_opening_06_chime_pulse",
		"cues": ["step_pulse", "contour_illumination", "constellation_join"]},
	{"id": "opening_07_civilization_pushes_back", "phase": "Reintegration", "duration": 6.0,
		"text": "Dig. Build. Feed. Govern. Endure.",
		"audio": "cue_opening_07_theme",
		"cues": ["parallax_layers", "boundary_steps", "tunnel_progress", "threat_frames"]},
	{"id": "opening_08_title_card", "phase": "Reintegration", "duration": 5.0,
		"text": "",
		"audio": "cue_opening_08_title_chord",
		"cues": ["star_settle_steps", "constellation_join", "title_steps"]},
]

var autoplay := true   ## tests disable this and drive advance()/skip() directly

var _index := -1
var _finished := false
var _time := 0.0
var _tick := -1
var _debug := false
var _canvas: Control
var _viewport: SubViewport
var _display: TextureRect
var _cel_rect: TextureRect
var _cel_frames: Array = []
var _overlay_label: Label
var _overlay_back: ColorRect
var _title_box: VBoxContainer
var _title_label: Label
var _author_label: Label
var _tagline_label: Label
var _debug_label: Label
var _audio: AudioStreamPlayer


func _ready() -> void:
	name = "Prologue"
	_debug = OS.get_environment("COHERONIA_PROLOGUE_DEBUG") == "1"
	# The root consumes every click over the overlay (via _gui_input) so the
	# title buttons underneath can never be pressed through the prologue.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.03)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 640x360 authored surface -> 2x nearest into the 1280x720 viewport.
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(CanvasScript.W, CanvasScript.H)
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_canvas = CanvasScript.new()
	_canvas.custom_minimum_size = Vector2(CanvasScript.W, CanvasScript.H)
	_canvas.size = Vector2(CanvasScript.W, CanvasScript.H)
	_viewport.add_child(_canvas)
	_display = TextureRect.new()
	_display.texture = _viewport.get_texture()
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_display)

	# Cel-shot hook (future art path): a scene id resolving a frame pool via
	# BlockRegistry.visual_variant_textures("opening", id) — the FQ-09V
	# `<id>_01.png` … convention or an explicit array entry — plays those
	# frames at 8 fps in place of the code-plotted shot. No frames shipped;
	# every scene falls back to the puppet/plotted rendering.
	_cel_rect = TextureRect.new()
	_cel_rect.visible = false
	_cel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cel_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cel_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cel_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_cel_rect)

	# Stable lower-quarter text region with a hard dark backing band.
	_overlay_back = ColorRect.new()
	_overlay_back.color = Color(0.01, 0.015, 0.03, 0.85)
	_overlay_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_back.anchor_left = 0.0
	_overlay_back.anchor_right = 1.0
	_overlay_back.anchor_top = 0.78
	_overlay_back.anchor_bottom = 0.94
	add_child(_overlay_back)
	_overlay_label = Label.new()
	_overlay_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_label.add_theme_font_size_override("font_size", 16)
	_overlay_label.add_theme_color_override("font_color", PARCHMENT)
	_overlay_label.anchor_left = 0.12
	_overlay_label.anchor_right = 0.88
	_overlay_label.anchor_top = 0.78
	_overlay_label.anchor_bottom = 0.94
	add_child(_overlay_label)

	# Title card: COHERONIA / By Paul Peck / Where civilization pushes back.
	# — three separate engine-rendered lines, never baked into imagery.
	_title_box = VBoxContainer.new()
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_box.add_theme_constant_override("separation", 10)
	_title_box.anchor_left = 0.2
	_title_box.anchor_right = 0.8
	_title_box.anchor_top = 0.36
	_title_box.anchor_bottom = 0.68
	add_child(_title_box)
	_title_label = _card_line(TITLE_TEXT, 34, PARCHMENT)
	_author_label = _card_line(AUTHORSHIP_TEXT, 20, AMBER_UI)
	_tagline_label = _card_line(TAGLINE_TEXT, 15, DIM_COLOR)

	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "Any key or click: continue · Esc: skip"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(DIM_COLOR, 0.7))
	hint.anchor_left = 0.0
	hint.anchor_right = 0.98
	hint.anchor_top = 0.95
	hint.anchor_bottom = 1.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	if _debug:
		_debug_label = Label.new()
		_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_debug_label.add_theme_font_size_override("font_size", 12)
		_debug_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		_debug_label.position = Vector2(8, 4)
		add_child(_debug_label)

	_show_scene(0)


func _card_line(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_title_box.add_child(label)
	return label


# ---------- deterministic tick clock ----------

func _process(delta: float) -> void:
	if _finished or not autoplay:
		return
	_time += delta
	var new_tick := int(_time * TICK_HZ)
	if new_tick != _tick:
		_tick = new_tick
		_on_tick()
	if _time >= _scene_duration(_index):
		advance()


func _scene_duration(index: int) -> float:
	if _debug:
		return 1.2   # debug mode: shortened scenes, same tick logic
	return float(SCENES[index]["duration"])


## One visual update: the canvas replots for this tick, text steps in hard
## quarter-alpha increments (no smooth tween), the title card lines stagger.
func _on_tick() -> void:
	if _cel_frames.is_empty():
		_canvas.set_state(_index, _tick)
	else:
		_cel_rect.texture = _cel_frames[cel_frame_index()]
	_overlay_label.modulate.a = clampf(0.25 * float(_tick + 1), 0.0, 1.0)
	_overlay_back.modulate.a = _overlay_label.modulate.a
	if _index == SCENES.size() - 1:
		_title_label.modulate.a = clampf(0.25 * float(_tick - 3), 0.0, 1.0)
		_author_label.modulate.a = clampf(0.25 * float(_tick - 9), 0.0, 1.0)
		_tagline_label.modulate.a = clampf(0.25 * float(_tick - 15), 0.0, 1.0)
	if _debug:
		_debug_label.text = "%s (%d/8)  phase=%s  tick=%d" % [
			str(SCENES[_index]["id"]), _index + 1,
			str(SCENES[_index]["phase"]), _tick]


# ---------- input ----------

## Keyboard: any key advances, Escape skips. Keys arrive here exactly once
## (no _gui_input duplication for keys), so a press can never double-advance.
func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()
	elif event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		advance()


## Mouse: the primary click advances. Handled only here (the root STOP filter
## routes clicks to _gui_input and never to _unhandled_input), so one click
## advances exactly one scene.
func _gui_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


# ---------- sequence ----------

func advance() -> void:
	if _finished:
		return
	if _index >= SCENES.size() - 1:
		_finish(true)
		return
	_show_scene(_index + 1)


func skip() -> void:
	if _finished:
		return
	_finish(false)


## Finishing (completion or skip) stops the clock and any playing audio so
## nothing keeps running behind the menu. Emits exactly once.
func _finish(completed: bool) -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	if _audio != null and _audio.playing:
		_audio.stop()
	finished.emit(completed)


func _show_scene(index: int) -> void:
	_index = index
	_time = 0.0
	_tick = 0
	var scene: Dictionary = SCENES[index]
	var is_title_card: bool = index == SCENES.size() - 1
	_overlay_label.text = str(scene.get("text", ""))
	_overlay_label.visible = not is_title_card and _overlay_label.text != ""
	_overlay_back.visible = _overlay_label.visible
	_overlay_label.modulate.a = 0.25
	_overlay_back.modulate.a = 0.25
	_title_box.visible = is_title_card
	if is_title_card:
		_title_label.modulate.a = 0.0
		_author_label.modulate.a = 0.0
		_tagline_label.modulate.a = 0.0
	_cel_frames = BlockRegistry.visual_variant_textures("opening", str(scene["id"]))
	_cel_rect.visible = not _cel_frames.is_empty()
	_display.visible = _cel_frames.is_empty()
	_canvas.set_state(index, 0)
	_play_cue(str(scene.get("audio", "")))
	_on_tick()


## Placeholder-safe audio hook: plays res://audio/opening/<cue>.ogg when the
## asset exists, silently does nothing when it does not. No cue is required.
func _play_cue(cue_id: String) -> void:
	if _audio == null or cue_id == "":
		return
	_audio.stop()
	var path := "%s/%s.ogg" % [AUDIO_DIR, cue_id]
	if ResourceLoader.exists(path):
		_audio.stream = load(path)
		_audio.play()


# ---------- test / integration hooks ----------

func panel_ids() -> Array:
	var out: Array = []
	for scene in SCENES:
		out.append(str(scene["id"]))
	return out


func panel_count() -> int:
	return SCENES.size()


func current_index() -> int:
	return _index


func is_finished() -> bool:
	return _finished


func current_overlay_text() -> String:
	return _overlay_label.text if _overlay_label.visible else ""


func title_card_visible() -> bool:
	return _title_box.visible


func title_card_lines() -> Array:
	return [_title_label.text, _author_label.text, _tagline_label.text]


## The deterministic pixel canvas (fingerprintable pure renderer).
func canvas() -> Control:
	return _canvas


func scene_durations() -> Array:
	var out: Array = []
	for scene in SCENES:
		out.append(float(scene["duration"]))
	return out


func scene_cues(index: int) -> Array:
	return SCENES[index].get("cues", [])


func audio_playing() -> bool:
	return _audio != null and _audio.playing


## True when the current scene plays authored cel frames instead of the
## code-plotted shot (no frames ship yet; fallback is always available).
func current_uses_cel() -> bool:
	return not _cel_frames.is_empty()


func cel_frame_index() -> int:
	if _cel_frames.is_empty():
		return -1
	return (_tick * 8 / TICK_HZ) % _cel_frames.size()


## Debug helper (COHERONIA_PROLOGUE_DEBUG=1 sessions and tests): jump straight
## to a scene without touching the finished/seen contract.
func debug_jump(index: int) -> void:
	if _finished or index < 0 or index >= SCENES.size():
		return
	_show_scene(index)
