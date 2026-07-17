extends Control
## Shell UI: the persistent outer game shell. Title, character
## select/create, and world select/create screens, all built in code.
## Each screen clears and rebuilds a single content container.

enum Screen { TITLE, CHAR_SELECT, CHAR_CREATE, WORLD_SELECT, WORLD_CREATE }

const BG_COLOR := Color(0.08, 0.09, 0.12)
const DIM_COLOR := Color(0.62, 0.65, 0.75)
const AncestryDetailScript := preload("res://scripts/data/ancestry_detail.gd")
# FQ-09C: title/authorship/tagline text lives on the prologue script so the
# title card and the persistent title screen can never drift apart.
const PrologueScript := preload("res://scripts/shell/prologue.gd")
# FQ-09U3: profile-level audio preferences, applied via the shared helper.
const AudioSettings := preload("res://scripts/audio/audio_settings.gd")

const PRESET_ORDER := ["peaceful_builder", "folk_kingdom", "tyrants_burden",
	"dark_frontier", "mythic_survival", "custom"]
const SIZE_ORDER := ["small", "medium", "large"]
const DIFFICULTY_AXES := [
	["enemy", "Enemy Difficulty"],
	["ruler", "Ruler Difficulty"],
	["survival", "Survival Difficulty"],
	["economy", "Economy Difficulty"],
	["social", "Social Difficulty"],
	["impressionability", "Subject Impressionability"],
]
const GEN_ROWS := [
	["terrain_amplitude", "Terrain Amplitude", 0.25, 2.0, 0.05],
	["terrain_frequency", "Terrain Frequency", 0.25, 2.0, 0.05],
	["ore_abundance", "Ore Abundance", 0.0, 2.0, 0.05],
	["tree_density", "Tree Density", 0.0, 2.0, 0.05],
	["bush_density", "Bush Density", 0.0, 2.0, 0.05],
	["dirt_depth", "Dirt Depth", 2.0, 8.0, 1.0],
]
const RULES_MAIN := [
	["subjects_require_food", "Subjects require food"],
	["weather_affects_survival", "Weather affects survival"],
	["lighting_affects_safety", "Lighting affects safety"],
	["darkness_increases_enemies", "Darkness increases enemy activity"],
	["enemies_scale_over_time", "Enemies scale over time"],
]
const RULES_FUTURE := [
	["subjects_require_sleep", "Subjects require sleep"],
	["sickness_enabled", "Sickness enabled"],
	["morale_matters", "Morale matters"],
	["loyalty_decays", "Loyalty decays"],
	["rebellion_enabled", "Rebellion enabled"],
	["ruler_pressure_grows", "Ruler pressure grows"],
	["scarcity_increases", "Scarcity increases"],
]

var _built := false
var _screen: Screen = Screen.TITLE
var _content: VBoxContainer
var _title_backdrop: TextureRect
var _selected_char_id: String = ""
var _prologue: Control = null   # FQ-09C: live prologue overlay, null when idle

# --- character create controls ---
var _name_edit: LineEdit
var _species_option: OptionButton
var _species_ids: Array[String] = []
var _species_detail: Label          # ancestry detail panel (Wave A)
var _ancestry_helper              # lazily created AncestryDetailScript instance
var _body_variant_option: OptionButton
var _body_variant_ids: Array[String] = []
# FQ-13P3: cosmetic body-variant picker (0 = default; up/down = prev/next look).
var _visual_variant_spin: SpinBox
var _appearance_option: OptionButton
var _appearance_ids: Array[String] = []
var _appearance_swatch: ColorRect
var _role_option: OptionButton
var _role_ids: Array[String] = []
var _role_desc: Label
var _trait_checks: Dictionary = {}   # trait id -> CheckBox

# --- world create controls ---
var _config: Dictionary = {}
var _syncing := false
var _world_name_edit: LineEdit
var _seed_edit: LineEdit
var _preset_option: OptionButton
var _preset_desc: Label             # preset description / deviation summary (Wave D)
var _size_option: OptionButton
var _difficulty_sliders: Dictionary = {}   # axis -> HSlider
var _danger_slider: HSlider
var _gen_sliders: Dictionary = {}          # generation key -> HSlider
var _rule_checks: Dictionary = {}          # rule key -> CheckBox


func _ready() -> void:
	if OS.get_environment("COHERONIA_SMOKE") == "1":
		GameState.ensure_play_context()
		get_tree().change_scene_to_file.call_deferred("res://scenes/main/Main.tscn")
		return
	_build_base()
	if OS.get_environment("COHERONIA_SHOTS") == "1":
		# FQ-09C: the shot tour keeps its exact pre-prologue title behavior.
		_show_title()
		_run_shot_tour.call_deferred()
		return
	_show_title()
	if not bool(GameState.profile.get("prologue_seen", false)):
		_show_prologue()   # clean profile: autoplay before the title


## README media tour (COHERONIA_SHOTS=1): captures the shell screens, then
## continues into Main where screenshot_tour.gd takes the gameplay shots.
## Never part of smoke or validation.
func _run_shot_tour() -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	await _tour_shot("06_shell_title")
	_show_char_create()
	await _tour_shot("07_character_create")
	_show_world_create()
	await _tour_shot("08_world_create")
	GameState.ensure_play_context()
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")


func _tour_shot(shot_name: String) -> void:
	for i in range(20):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % shot_name)


# ---------- FQ-09C: opening prologue ----------

## Shows the prologue over the current screen. Used for the clean-profile
## autoplay and the title-menu replay; both run the same sequence and end at
## the title screen. Only the profile-level prologue_seen flag is written.
func _show_prologue() -> void:
	if _prologue != null:
		return
	_prologue = PrologueScript.new()
	_prologue.finished.connect(_on_prologue_finished)
	add_child(_prologue)


func _on_prologue_finished(_completed: bool) -> void:
	GameState.mark_prologue_seen()
	if _prologue != null:
		_prologue.queue_free()
		_prologue = null
	_show_title()


func _unhandled_input(event: InputEvent) -> void:
	if not _built:
		return
	if _prologue != null:
		return   # the prologue consumes advance/skip input itself
	if event.is_action_pressed("ui_cancel"):
		match _screen:
			Screen.CHAR_SELECT:
				_show_title()
			Screen.CHAR_CREATE:
				_show_char_select()
			Screen.WORLD_SELECT:
				_show_char_select()
			Screen.WORLD_CREATE:
				_show_world_select()
		get_viewport().set_input_as_handled()


# ---------- base layout ----------

func _build_base() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_title_backdrop = TextureRect.new()
	_title_backdrop.texture = _title_backdrop_texture()
	_title_backdrop.visible = _title_backdrop.texture != null
	_title_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_title_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_title_backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	margin.add_child(_content)
	_built = true


func _clear_content() -> void:
	_set_title_backdrop_visible(false)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _title_backdrop_texture() -> Texture2D:
	var plates: Array = BlockRegistry.visual_variant_textures(
		"opening", "opening_08_title_card")
	if not plates.is_empty():
		return plates[0] as Texture2D
	return null


func _set_title_backdrop_visible(enabled: bool) -> void:
	if _title_backdrop != null:
		_title_backdrop.visible = enabled and _title_backdrop.texture != null


# ---------- SCREEN 1: title ----------

func _show_title() -> void:
	_screen = Screen.TITLE
	_clear_content()
	_set_title_backdrop_visible(true)
	_spacer(_content)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 10)
	_content.add_child(box)
	var title := _label(box, PrologueScript.TITLE_TEXT, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# FQ-09C authorship lock: `By Paul Peck` stays visible on the normal title.
	var author := _label(box, PrologueScript.AUTHORSHIP_TEXT, 16)
	author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	author.add_theme_color_override("font_color", Color(0.95, 0.72, 0.35))
	var subtitle := _label(box, PrologueScript.TAGLINE_TEXT, 14)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", DIM_COLOR)
	_gap(box, 16)
	if _can_continue():
		var last_world: String = str(GameState.profile.get("last_world", ""))
		var last_char: String = str(GameState.profile.get("last_character", ""))
		var cont := _button(box, "Continue", func() -> void:
			GameState.start_world(last_world, last_char))
		cont.custom_minimum_size = Vector2(220, 0)
	var play := _button(box, "Play", _show_char_select)
	play.custom_minimum_size = Vector2(220, 0)
	var replay := _button(box, "Prologue", _show_prologue)
	replay.custom_minimum_size = Vector2(220, 0)
	var quit := _button(box, "Quit", func() -> void: get_tree().quit())
	quit.custom_minimum_size = Vector2(220, 0)
	# FQ-09U3: Music/Sound volume — profile-level preferences applied live
	# and saved when the drag ends (buses are global, so they carry into
	# gameplay and back).
	_gap(box, 12)
	AudioSettings.apply(GameState.profile)
	_volume_row(box, "Music", AudioSettings.music_volume(GameState.profile),
		func(value: float) -> void: AudioSettings.set_music_volume(GameState.profile, value))
	_volume_row(box, "Sound", AudioSettings.sfx_volume(GameState.profile),
		func(value: float) -> void: AudioSettings.set_sfx_volume(GameState.profile, value))
	_spacer(_content)


func _volume_row(parent: Control, label_text: String, initial: float,
		setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := _label(row, label_text, 12)
	label.custom_minimum_size = Vector2(50, 0)
	label.add_theme_color_override("font_color", DIM_COLOR)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(160, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		setter.call(value)
		AudioSettings.apply(GameState.profile))
	slider.drag_ended.connect(func(changed: bool) -> void:
		if changed:
			GameState.save_shell())


func _can_continue() -> bool:
	var last_world: String = str(GameState.profile.get("last_world", ""))
	var last_char: String = str(GameState.profile.get("last_character", ""))
	if last_world == "" or last_char == "":
		return false
	if GameState.load_world_file(last_world).is_empty():
		return false
	return not GameState.get_character(last_char).is_empty()


# ---------- SCREEN 2: character select ----------

func _show_char_select() -> void:
	_screen = Screen.CHAR_SELECT
	_clear_content()
	_header(_content, "Choose a character")
	var list := _scroll_list(_content)
	if GameState.characters.is_empty():
		var empty := _label(list, "No characters yet — create one below.", 13)
		empty.add_theme_color_override("font_color", DIM_COLOR)
	for character in GameState.characters:
		_add_character_row(list, character)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_content.add_child(buttons)
	_button(buttons, "New Character", _show_char_create)
	_button(buttons, "Back", _show_title)


func _add_character_row(list: VBoxContainer, character: Dictionary) -> void:
	var panel := PanelContainer.new()
	list.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var char_name: String = str(character.get("name", "Nameless"))
	_label(info, char_name, 16)
	var species_name: String = _display_name_of("species", str(character.get("species", "human")))
	var role_name: String = _display_name_of("roles", str(character.get("role", "homesteader")))
	var trait_names: Array[String] = []
	var trait_ids: Array = character.get("traits", [])
	for trait_id in trait_ids:
		trait_names.append(_display_name_of("traits", str(trait_id)))
	var detail: String = "%s · %s" % [species_name, role_name]
	if not trait_names.is_empty():
		detail += " · " + ", ".join(trait_names)
	var detail_label := _label(info, detail, 13)
	detail_label.add_theme_color_override("font_color", DIM_COLOR)
	var char_id: String = str(character.get("id", ""))
	_button(row, "Select", func() -> void:
		_selected_char_id = char_id
		_show_world_select())
	_button(row, "Delete", func() -> void:
		GameState.delete_character(char_id)
		_show_char_select())


# ---------- SCREEN 2b: character create ----------

func _show_char_create() -> void:
	_screen = Screen.CHAR_CREATE
	_clear_content()
	_header(_content, "New character")
	var form := VBoxContainer.new()
	form.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	_content.add_child(form)
	var data: Dictionary = BlockRegistry.character_data

	var name_row := _form_row(form, "Name")
	_name_edit = LineEdit.new()
	_name_edit.text = "Settler"
	_name_edit.custom_minimum_size = Vector2(240, 0)
	name_row.add_child(_name_edit)

	var species_row := _form_row(form, "Species")
	_species_option = OptionButton.new()
	_species_ids.clear()
	var species_list: Array = data.get("species", [])
	for species_def in species_list:
		_species_ids.append(str(species_def.get("id", "")))
		_species_option.add_item(str(species_def.get("display_name", "?")))
	_species_option.item_selected.connect(_update_species_detail)
	species_row.add_child(_species_option)

	# Ancestry detail panel (Wave A)
	_species_detail = Label.new()
	_species_detail.add_theme_font_size_override("font_size", 12)
	_species_detail.add_theme_color_override("font_color", DIM_COLOR)
	_species_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_species_detail.custom_minimum_size = Vector2(0, 0)
	form.add_child(_species_detail)
	_update_species_detail(0)

	var body_variant_row := _form_row(form, "Body")
	_body_variant_option = OptionButton.new()
	_body_variant_ids.clear()
	var body_variant_list: Array = data.get("body_variants", [])
	for body_variant_def in body_variant_list:
		_body_variant_ids.append(str(body_variant_def.get("id", "default")))
		_body_variant_option.add_item(str(body_variant_def.get("display_name", "Default")))
	body_variant_row.add_child(_body_variant_option)

	# FQ-13P3: cosmetic body variant. The SpinBox up/down arrows are the
	# previous/next look controls; 0 is the default body. Alternate looks show
	# only where variant art exists, otherwise the default body is drawn.
	var look_row := _form_row(form, "Look")
	_visual_variant_spin = SpinBox.new()
	_visual_variant_spin.min_value = 0
	_visual_variant_spin.max_value = 0
	_visual_variant_spin.step = 1
	_visual_variant_spin.value = 0
	_visual_variant_spin.tooltip_text = "Cosmetic body variant (0 = default look)."
	look_row.add_child(_visual_variant_spin)
	_species_option.item_selected.connect(_refresh_look_range)
	_body_variant_option.item_selected.connect(_refresh_look_range)
	_refresh_look_range()
	var look_note := _label(form,
		"Cosmetic only — the selector is limited to authored looks for this body.", 12)
	look_note.add_theme_color_override("font_color", DIM_COLOR)

	var carried_note := _label(form,
		"Character rules: backpack, tools, equipment, ancestry, role, and traits follow this character between worlds. Role starter items are granted once. Collapse loses a fraction of carried stacks.",
		12)
	carried_note.add_theme_color_override("font_color", DIM_COLOR)
	carried_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var appearance_row := _form_row(form, "Appearance")
	_appearance_option = OptionButton.new()
	_appearance_ids.clear()
	var appearance_list: Array = data.get("appearances", [])
	for appearance_def in appearance_list:
		_appearance_ids.append(str(appearance_def.get("id", "")))
		_appearance_option.add_item(str(appearance_def.get("display_name", "?")))
	_appearance_option.item_selected.connect(_update_swatch)
	appearance_row.add_child(_appearance_option)
	_appearance_swatch = ColorRect.new()
	_appearance_swatch.custom_minimum_size = Vector2(22, 22)
	_appearance_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	appearance_row.add_child(_appearance_swatch)
	_update_swatch(0)

	var role_row := _form_row(form, "Role")
	_role_option = OptionButton.new()
	_role_ids.clear()
	var role_list: Array = data.get("roles", [])
	for role_def in role_list:
		_role_ids.append(str(role_def.get("id", "")))
		_role_option.add_item(str(role_def.get("display_name", "?")))
	_role_option.item_selected.connect(_update_role_desc)
	role_row.add_child(_role_option)
	_role_desc = _label(form, "", 13)
	_role_desc.add_theme_color_override("font_color", DIM_COLOR)
	_update_role_desc(0)

	_gap(form, 4)
	_label(form, "Traits (choose up to %d)" % _max_traits(), 16)
	_trait_checks.clear()
	var trait_list: Array = data.get("traits", [])
	for trait_def in trait_list:
		var trait_id: String = str(trait_def.get("id", ""))
		var check := CheckBox.new()
		check.text = "%s — %s" % [str(trait_def.get("display_name", trait_id)),
			str(trait_def.get("description", ""))]
		check.add_theme_font_size_override("font_size", 13)
		check.toggled.connect(func(_pressed: bool) -> void: _enforce_trait_limit())
		form.add_child(check)
		_trait_checks[trait_id] = check

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_content.add_child(buttons)
	_button(buttons, "Create", _create_character)
	_button(buttons, "Back", _show_char_select)


func _update_swatch(index: int) -> void:
	var appearance_list: Array = BlockRegistry.character_data.get("appearances", [])
	if index >= 0 and index < appearance_list.size():
		var body_hex: String = str(appearance_list[index].get("body", "ebd48c"))
		_appearance_swatch.color = Color.from_string(body_hex, Color(0.9, 0.83, 0.55))


## FQ-13P3 follow-through: expose only the canonical look plus the authored
## full-body pool for the currently selected species/presentation. This keeps
## the creation UI from offering repeated or no-op values when a pool is short
## or absent.
func _refresh_look_range(_index: int = -1) -> void:
	if _visual_variant_spin == null or _species_option == null \
			or _body_variant_option == null:
		return
	var species_id := _option_id(_species_option, _species_ids, "human")
	var body_variant := _option_id(
		_body_variant_option, _body_variant_ids, "default")
	var body_id := BlockRegistry.player_body_id(species_id, body_variant)
	var pool_size := BlockRegistry.visual_variant_textures("players", body_id).size()
	_visual_variant_spin.max_value = pool_size
	_visual_variant_spin.value = mini(int(_visual_variant_spin.value), pool_size)
	_visual_variant_spin.editable = pool_size > 0
	_visual_variant_spin.tooltip_text = (
		"%d authored look%s plus the default body." % [
			pool_size, "" if pool_size == 1 else "s"]
		if pool_size > 0 else
		"No alternate looks are authored for this body yet."
	)


func _update_role_desc(index: int) -> void:
	var role_list: Array = BlockRegistry.character_data.get("roles", [])
	if index >= 0 and index < role_list.size():
		_role_desc.text = str(role_list[index].get("description", ""))


func _update_species_detail(index: int) -> void:
	if _species_detail == null:
		return
	if index < 0 or index >= _species_ids.size():
		_species_detail.text = ""
		return
	if _ancestry_helper == null:
		_ancestry_helper = AncestryDetailScript.new()
	var species_id: String = _species_ids[index]
	var ancestry: Dictionary = _ancestry_helper.get_ancestry(species_id)
	if ancestry.is_empty():
		_species_detail.text = ""
		return
	var is_live: bool = str(ancestry.get("implementation_phase", "")) == "B"
	_species_detail.text = AncestryDetailScript.build_panel_text(ancestry, is_live)


func _max_traits() -> int:
	return int(BlockRegistry.character_data.get("max_traits", 2))


func _enforce_trait_limit() -> void:
	var checked := 0
	for trait_id in _trait_checks:
		var check: CheckBox = _trait_checks[trait_id]
		if check.button_pressed:
			checked += 1
	var full: bool = checked >= _max_traits()
	for trait_id in _trait_checks:
		var check: CheckBox = _trait_checks[trait_id]
		check.disabled = full and not check.button_pressed


func _create_character() -> void:
	var trait_ids: Array = []
	for trait_id in _trait_checks:
		var check: CheckBox = _trait_checks[trait_id]
		if check.button_pressed:
			trait_ids.append(trait_id)
	var char_name: String = _name_edit.text.strip_edges()
	if char_name == "":
		char_name = "Settler"
	var character: Dictionary = GameState.create_character({
		"name": char_name,
		"species": _option_id(_species_option, _species_ids, "human"),
		"body_variant": _option_id(
			_body_variant_option, _body_variant_ids, "default"),
		"visual_variant": int(_visual_variant_spin.value) if _visual_variant_spin != null else 0,
		"appearance": _option_id(_appearance_option, _appearance_ids, "tan"),
		"role": _option_id(_role_option, _role_ids, "homesteader"),
		"traits": trait_ids,
	})
	_selected_char_id = str(character.get("id", ""))
	_show_world_select()


# ---------- SCREEN 3: world select ----------

func _show_world_select() -> void:
	_screen = Screen.WORLD_SELECT
	_clear_content()
	var character: Dictionary = GameState.get_character(_selected_char_id)
	var char_name: String = str(character.get("name", "Settler"))
	_header(_content, "Choose a world — playing as %s" % char_name)
	var list := _scroll_list(_content)
	var worlds: Array = GameState.list_worlds()
	if worlds.is_empty():
		var empty := _label(list, "No worlds yet — create one below.", 13)
		empty.add_theme_color_override("font_color", DIM_COLOR)
	for entry in worlds:
		_add_world_row(list, entry)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_content.add_child(buttons)
	_button(buttons, "New World", _show_world_create)
	_button(buttons, "Back", _show_char_select)


func _add_world_row(list: VBoxContainer, entry: Dictionary) -> void:
	var config: Dictionary = entry.get("config", {})
	var meta: Dictionary = entry.get("meta", {})
	var world_id: String = str(entry.get("id", ""))
	var panel := PanelContainer.new()
	list.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	_label(info, str(config.get("name", "New World")), 16)
	var sizes: Dictionary = WorldConfig.settings().get("sizes", {})
	var size_id: String = str(config.get("size", "medium"))
	var size_def: Dictionary = sizes.get(size_id, {})
	var presets: Dictionary = WorldConfig.settings().get("presets", {})
	var preset_id: String = str(config.get("preset", "custom"))
	var preset_def: Dictionary = presets.get(preset_id, {})
	var detail := _label(info, "%s · Seed %d · %s" % [
		str(size_def.get("display_name", size_id)),
		int(config.get("seed", 0)),
		str(preset_def.get("display_name", "Custom"))], 13)
	detail.add_theme_color_override("font_color", DIM_COLOR)
	var last_played: String = str(meta.get("last_played", ""))
	var played := _label(info, "Last played: %s" %
		(last_played if last_played != "" else "never"), 13)
	played.add_theme_color_override("font_color", DIM_COLOR)
	var summary: Dictionary = meta.get("summary", {})
	if not summary.is_empty():
		_label(info, "Day %d, %d settlers, Coherence %d%%, damage %d%%" % [
			int(summary.get("day", 1)),
			int(summary.get("population", 0)),
			int(round(float(summary.get("coherence", 0.0)))),
			int(round(float(summary.get("damage", 0.0))))], 13)
	var last_char: String = str(meta.get("last_character", ""))
	if last_char != "" and last_char != _selected_char_id:
		var other: Dictionary = GameState.get_character(last_char)
		var other_name: String = str(other.get("name", ""))
		if other_name == "":
			other_name = "another settler"
		var note := _label(info, "Last played by %s" % other_name, 13)
		note.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	_button(row, "Enter", func() -> void:
		GameState.start_world(world_id, _selected_char_id))
	_button(row, "Delete", func() -> void:
		GameState.delete_world(world_id)
		_show_world_select())


# ---------- SCREEN 3b: world create ----------

func _show_world_create() -> void:
	_screen = Screen.WORLD_CREATE
	_clear_content()
	_config = WorldConfig.defaults()
	_difficulty_sliders.clear()
	_gen_sliders.clear()
	_rule_checks.clear()
	_header(_content, "New world")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 6)
	scroll.add_child(form)

	var name_row := _form_row(form, "Name")
	_world_name_edit = LineEdit.new()
	_world_name_edit.text = "New World"
	_world_name_edit.custom_minimum_size = Vector2(240, 0)
	name_row.add_child(_world_name_edit)

	var preset_row := _form_row(form, "Preset")
	_preset_option = OptionButton.new()
	var presets: Dictionary = WorldConfig.settings().get("presets", {})
	for entry in PRESET_ORDER:
		var preset_id: String = str(entry)
		var preset_def: Dictionary = presets.get(preset_id, {})
		_preset_option.add_item(str(preset_def.get("display_name", preset_id.capitalize())))
	_preset_option.select(PRESET_ORDER.find(str(_config.get("preset", "custom"))))
	_preset_option.item_selected.connect(_on_preset_selected)
	preset_row.add_child(_preset_option)

	# Preset description / deviation summary (Wave D)
	_preset_desc = Label.new()
	_preset_desc.add_theme_font_size_override("font_size", 12)
	_preset_desc.add_theme_color_override("font_color", DIM_COLOR)
	_preset_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_preset_desc)
	_update_preset_desc()

	var world_rule_note := _label(form,
		"World rules: terrain, stockpile, threats, storms, base level, player level, position, and current health belong to the world. Entering with another character uses that character's carried gear and inventory.",
		12)
	world_rule_note.add_theme_color_override("font_color", DIM_COLOR)
	world_rule_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var size_row := _form_row(form, "Size")
	_size_option = OptionButton.new()
	var sizes: Dictionary = WorldConfig.settings().get("sizes", {})
	for entry in SIZE_ORDER:
		var size_id: String = str(entry)
		var size_def: Dictionary = sizes.get(size_id, {})
		var w: int = int(size_def.get("width", 0))
		var h: int = int(size_def.get("height", 0))
		var dim_str: String = (" (%dx%d)" % [w, h]) if w > 0 and h > 0 else ""
		_size_option.add_item(str(size_def.get("display_name", size_id.capitalize())) + dim_str)
	_size_option.select(maxi(0, SIZE_ORDER.find(str(_config.get("size", "medium")))))
	_size_option.item_selected.connect(func(index: int) -> void:
		if _syncing:
			return
		_config["size"] = str(SIZE_ORDER[index])
		_mark_custom())
	size_row.add_child(_size_option)

	var seed_row := _form_row(form, "Seed")
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "0 = random"
	_seed_edit.custom_minimum_size = Vector2(160, 0)
	seed_row.add_child(_seed_edit)
	_button(seed_row, "Random", func() -> void:
		_seed_edit.text = str((randi() % 999983) + 1))

	_gap(form, 4)
	_label(form, "Difficulty", 16)
	var _ui_help: Dictionary = WorldConfig.settings().get("ui_help", {})
	var _axis_help: Dictionary = _ui_help.get("axis_help", {})
	for entry in DIFFICULTY_AXES:
		var axis: String = str(entry[0])
		var axis_label: String = str(entry[1])
		var difficulty: Dictionary = _config.get("difficulty", {})
		_difficulty_sliders[axis] = _slider_row(form, axis_label, 0.0, 2.0, 0.05,
			float(difficulty.get(axis, 1.0)),
			func(value: float) -> void:
				if _syncing:
					return
				_config["difficulty"][axis] = value
				_mark_custom(),
			str(_axis_help.get(axis, "")))
	_danger_slider = _slider_row(form, "Environment Danger", 0.0, 2.0, 0.05,
		float(_config.get("environment_danger", 1.0)),
		func(value: float) -> void:
			if _syncing:
				return
			_config["environment_danger"] = value
			_mark_custom(),
		"Scales ambient hazard: cave-ins, wild animals, and passive threat pressure.")

	_gap(form, 4)
	_label(form, "World Generation", 16)
	var _gen_help: Dictionary = _ui_help.get("gen_help", {})
	for entry in GEN_ROWS:
		var gen_key: String = str(entry[0])
		var gen_label: String = str(entry[1])
		var generation: Dictionary = _config.get("generation", {})
		_gen_sliders[gen_key] = _slider_row(form, gen_label,
			float(entry[2]), float(entry[3]), float(entry[4]),
			float(generation.get(gen_key, 1.0)),
			func(value: float) -> void:
				if _syncing:
					return
				_config["generation"][gen_key] = value
				_mark_custom(),
			str(_gen_help.get(gen_key, "")))

	_gap(form, 4)
	_label(form, "Rules", 16)
	for entry in RULES_MAIN:
		_add_rule_check(form, str(entry[0]), str(entry[1]))
	var caption := _label(form, "Reserved for future systems", 13)
	caption.add_theme_color_override("font_color", DIM_COLOR)
	for entry in RULES_FUTURE:
		_add_rule_check(form, str(entry[0]), str(entry[1]))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	_content.add_child(buttons)
	_button(buttons, "Create & Enter", _create_and_enter_world)
	_button(buttons, "Back", _show_world_select)


func _add_rule_check(parent: Control, rule_id: String, rule_label: String) -> void:
	var check := CheckBox.new()
	check.text = rule_label
	check.add_theme_font_size_override("font_size", 13)
	var rules: Dictionary = _config.get("rules", {})
	check.button_pressed = bool(rules.get(rule_id, false))
	check.toggled.connect(func(pressed: bool) -> void:
		if _syncing:
			return
		_config["rules"][rule_id] = pressed
		_mark_custom())
	parent.add_child(check)
	_rule_checks[rule_id] = check


func _update_preset_desc() -> void:
	if _preset_desc == null:
		return
	var preset_id: String = str(_config.get("preset", "custom"))
	var ui_help: Dictionary = WorldConfig.settings().get("ui_help", {})
	var preset_descs: Dictionary = ui_help.get("preset_descriptions", {})
	var desc_entry: Dictionary = preset_descs.get(preset_id, {})
	var desc: String = str(desc_entry.get("description", ""))
	var devs: String = str(desc_entry.get("deviations", ""))
	var text: String = desc
	if devs != "":
		text += "\n" + devs
	_preset_desc.text = text


func _on_preset_selected(index: int) -> void:
	if _syncing:
		return
	var preset_id: String = str(PRESET_ORDER[clampi(index, 0, PRESET_ORDER.size() - 1)])
	_config = WorldConfig.from_preset(preset_id)
	_refresh_world_form()
	_update_preset_desc()


func _refresh_world_form() -> void:
	_syncing = true
	var size_index: int = SIZE_ORDER.find(str(_config.get("size", "medium")))
	_size_option.select(maxi(0, size_index))
	var difficulty: Dictionary = _config.get("difficulty", {})
	for axis in _difficulty_sliders:
		var slider: HSlider = _difficulty_sliders[axis]
		slider.value = float(difficulty.get(axis, 1.0))
	_danger_slider.value = float(_config.get("environment_danger", 1.0))
	var generation: Dictionary = _config.get("generation", {})
	for gen_key in _gen_sliders:
		var slider: HSlider = _gen_sliders[gen_key]
		slider.value = float(generation.get(gen_key, 1.0))
	var rules: Dictionary = _config.get("rules", {})
	for rule_id in _rule_checks:
		var check: CheckBox = _rule_checks[rule_id]
		check.button_pressed = bool(rules.get(rule_id, false))
	_syncing = false


func _mark_custom() -> void:
	_config["preset"] = "custom"
	var custom_index: int = PRESET_ORDER.find("custom")
	if _preset_option.selected != custom_index:
		_preset_option.select(custom_index)
	_update_preset_desc()


func _create_and_enter_world() -> void:
	var world_name: String = _world_name_edit.text.strip_edges()
	if world_name == "":
		world_name = "New World"
	_config["name"] = world_name
	var seed_text: String = _seed_edit.text.strip_edges()
	_config["seed"] = int(seed_text) if seed_text.is_valid_int() else 0
	var world_id: String = GameState.create_world(_config)
	GameState.start_world(world_id, _selected_char_id)


# ---------- shared helpers ----------

func _display_name_of(list_key: String, entry_id: String) -> String:
	var defs: Array = BlockRegistry.character_data.get(list_key, [])
	for def in defs:
		if str(def.get("id", "")) == entry_id:
			return str(def.get("display_name", entry_id))
	return entry_id


func _option_id(option: OptionButton, ids: Array[String], fallback: String) -> String:
	var index: int = option.selected
	if index >= 0 and index < ids.size():
		return ids[index]
	return fallback


func _header(parent: Control, text: String) -> Label:
	return _label(parent, text, 16)


func _label(parent: Control, text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Control, text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button


func _form_row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := _label(row, label_text, 13)
	label.custom_minimum_size = Vector2(120, 0)
	return row


func _slider_row(parent: Control, label_text: String, min_value: float,
		max_value: float, step: float, initial: float, on_change: Callable,
		help: String = "") -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := _label(row, label_text, 13)
	label.custom_minimum_size = Vector2(200, 0)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(220, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := _label(row, _format_slider(initial, step), 13)
	value_label.custom_minimum_size = Vector2(48, 0)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = _format_slider(value, step)
		on_change.call(value))
	if help != "":
		var help_label := _label(parent, help, 11)
		help_label.add_theme_color_override("font_color", DIM_COLOR)
		help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return slider


func _format_slider(value: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(value))
	return "%.2f" % value


func _scroll_list(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	return list


func _spacer(parent: Control) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)


func _gap(parent: Control, height: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	parent.add_child(gap)
