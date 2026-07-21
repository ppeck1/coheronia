extends Node2D
## Image-first player presentation. The parent Player remains authoritative for
## movement, collision, mining timing, equipment, and saves; this child only
## resolves and draws the current body, facing, action pose, and visible gear.

const BODY_RECT := Rect2(-8.0, -16.0, 16.0, 32.0)
const RIGHT := 1
const LEFT := -1
const DEFAULT_APPEARANCE_BODY := Color(0.92156863, 0.83137255, 0.54901961)

## The character compositing order, back to front. `_draw` paints these layers
## in exactly this sequence; any consumer that reproduces the character
## (creation preview, Character panel) must honor it. Documented in
## docs/CHARACTER_RENDERING_CONTRACT.md and pinned by the smoke contract check.
## `weapon_or_swing` is the swing overlay while a mining swing is active,
## otherwise the idle weapon.
const CHARACTER_LAYER_ORDER: Array[String] = [
	"accessory", "body", "feet", "torso", "weapon_or_swing", "helmet"]

## The equipment slots that draw as figure gear (the pickaxe/axe tool slots are
## not worn overlays). Shared by the live and preview gear paths.
const DRAWN_GEAR_SLOTS: Array[String] = [
	"weapon", "helmet", "torso", "feet", "accessory"]

## PR-04: the mining swing cycles once per this many seconds (matches the FQ-09M
## 6-pose/second cadence: three poses per 0.5 s cycle). Presentation only.
const SWING_CYCLE_SEC := 0.5

var _player
var _species_id := "human"
var _body_variant := "masculine"
## FQ-13P3: character-owned cosmetic index. 0 = canonical body; k>0 selects the
## k-th full-body pool entry (art/generated/players/<body_id>_NN.png).
var _visual_variant := 0
var _resolved_body_id := ""
var _body_texture: Texture2D = null
var _body_color := Color(0.92, 0.83, 0.55)
var _trim_color := Color(0.35, 0.25, 0.18)
var _facing_sign := RIGHT
var _appearance_recolored := false
## PR-05: gear the parentless preview path draws, in place of a live Player's
## equipped_dict(). Empty for a live PlayerVisual (which reads _player); filled
## by apply_preview_character() so the creation/select previews compose the same
## figure the world does. Keys are the drawn slots only.
var _preview_gear: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player = get_parent() as CharacterBody2D
	if _player != null:
		sync_from_player()
	set_process(true)


func _process(_delta: float) -> void:
	refresh_facing()
	queue_redraw()


## Called by Player after character application and available to focused smoke
## tests. Missing/invalid variants are normalized before body resolution.
func set_character_visual(species_id: String, body_variant: String,
		body_color: Color, trim_color: Color, visual_variant: int = 0) -> void:
	_species_id = species_id
	_body_variant = BlockRegistry.normalize_body_variant(body_variant)
	_visual_variant = maxi(0, visual_variant)
	_body_color = body_color
	_trim_color = trim_color
	_resolve_body_texture()
	queue_redraw()


func sync_from_player() -> void:
	if _player == null:
		return
	set_character_visual(str(_player.species_id), str(_player.body_variant),
		_player.body_color, _player.trim_color, int(_player.visual_variant))
	refresh_facing()


## PR-05: drive the shared render path from a stored/edited character dict with
## no live Player parent, so the character-creation preview and character-select
## rows compose the identical figure the world draws (what you pick == what you
## get). Presentation only: it reuses set_character_visual() and the same _draw
## path; gear comes from the character's own equipment slots (normalized exactly
## like the live equipped_dict()) instead of a live Player. The appearance ->
## body/trim colour derivation mirrors Player.apply_character so identical inputs
## resolve to identical colours.
func apply_preview_character(character: Dictionary) -> void:
	var appearance: Dictionary = BlockRegistry.appearance_def(
		str(character.get("appearance", "tan")))
	var body := Color.from_string(
		"#" + str(appearance.get("body", "ebd48c")), DEFAULT_APPEARANCE_BODY)
	var trim := Color.from_string(
		"#" + str(appearance.get("trim", "59402e")), _trim_color)
	var normalized: Dictionary = BlockRegistry.normalize_equipment(
		character.get("equipment", {}))
	_preview_gear = {}
	for slot_id in DRAWN_GEAR_SLOTS:
		var item_id := str(normalized.get(slot_id, ""))
		if item_id != "":
			_preview_gear[slot_id] = item_id
	set_character_visual(str(character.get("species", "human")),
		str(character.get("body_variant", "masculine")), body, trim,
		int(character.get("visual_variant", 0)))


func visual_variant() -> int:
	return _visual_variant


## Active mining target wins, then horizontal movement; idle retains the last
## direction. Only this child is mirrored, leaving collision/camera/world UI
## in their original coordinate system.
func refresh_facing() -> void:
	if _player == null:
		return
	var next_facing := _facing_sign
	if _player.world != null and _player.mine_required > 0.0:
		var target_center: Vector2 = _player.world.cell_center(_player.mine_target)
		next_facing = RIGHT if _player.to_local(target_center).x >= 0.0 else LEFT
	elif absf(_player.velocity.x) > 0.01:
		next_facing = RIGHT if _player.velocity.x > 0.0 else LEFT
	_facing_sign = next_facing
	scale = Vector2(float(_facing_sign), 1.0)


func facing_sign() -> int:
	return _facing_sign


func requested_body_id() -> String:
	return BlockRegistry.player_body_id(_species_id, _body_variant)


func resolved_body_id() -> String:
	return _resolved_body_id


## The body id that gear and swing overlays resolve against: the resolved body
## when one loaded, otherwise the character's intended body id. This keeps
## authored body-specific gear visible for a valid character whose body texture
## is momentarily unresolved (a cleared cache or a once-missing load during a
## character/load/world-transition/forge refresh), instead of silently dropping
## to the procedural fallback. An unknown species has no body id, so its gear
## stays procedural.
func effective_body_id() -> String:
	return _resolved_body_id if _resolved_body_id != "" else requested_body_id()


func using_body_art() -> bool:
	return _body_texture != null


## Re-resolve the body from the current character fields and repaint. Call at
## presentation refresh boundaries (world entry, load, forge/equip) so a cleared
## visual cache or a texture that was missing at first resolve is picked up.
## Presentation only: never touches equipment state, effects, or saves.
func refresh_presentation() -> void:
	_resolve_body_texture()
	queue_redraw()


func appearance_recolored() -> bool:
	return _appearance_recolored


func visible_gear_ids() -> Dictionary:
	# PR-05: with no live Player, the parentless preview path supplies the gear
	# (already filtered to the drawn slots by apply_preview_character).
	if _player == null:
		return _preview_gear.duplicate()
	var equipped: Dictionary = _player.equipped_dict()
	var out := {}
	for slot_id in DRAWN_GEAR_SLOTS:
		var item_id := str(equipped.get(slot_id, ""))
		if item_id != "":
			out[slot_id] = item_id
	return out


func active_tool_id() -> String:
	if _player == null or _player.mine_required <= 0.0:
		return ""
	if _player.world != null:
		var block_id: String = _player.world.block_at(_player.mine_target)
		if _player.axe_tier > 0 and BlockRegistry.preferred_tool(block_id) == "axe":
			return BlockRegistry.axe_item_for_tier(_player.axe_tier)
	return BlockRegistry.pick_item_for_tier(_player.tool_tier)


func gear_uses_procedural_fallback(item_id: String) -> bool:
	return item_id != "" and _gear_texture(item_id) == null


# ---------------------------------------------------------------------------
# PR-04: directional windup -> impact -> recovery action presentation. The
# active action is a mining swing (pick/axe, continuous) or a weapon swing
# (attack, one-shot). Each is timed by the item's data-owned action_profile and
# aimed at the target vector, so up/down/diagonal targets read directionally.
# Presentation only: it reads mining/attack state and never writes it.
# ---------------------------------------------------------------------------

## "mine" while a mining target is active, "attack" during a weapon swing, else
## "" (idle). Attack takes priority: a hit interrupts mining input by design.
func action_kind() -> String:
	if _player == null:
		return ""
	if _player.has_method("attack_swing_active") and _player.attack_swing_active():
		return "attack"
	if _player.mine_required > 0.0:
		return "mine"
	return ""


func is_action_swinging() -> bool:
	return action_kind() != ""


## The item whose action_profile and swing art drive the current action: the
## equipped weapon for an attack, the mining tool (pick/axe) for a mine.
func active_action_item() -> String:
	match action_kind():
		"attack":
			return str(_player.equipped_dict().get("weapon", ""))
		"mine":
			return active_tool_id()
	return ""


func active_action_profile() -> Dictionary:
	return BlockRegistry.action_profile(active_action_item())


## World-space direction from the player toward the current action target.
func _action_world_dir() -> Vector2:
	match action_kind():
		"attack":
			return _player.attack_dir
		"mine":
			if _player.world != null:
				return _player.world.cell_center(_player.mine_target) \
					- _player.global_position
	return Vector2(float(_facing_sign), 0.0)


## The swing direction in the visual's own (mirror-aware) space: the target
## vector mapped through the facing flip so the arc points the right way whether
## the body faces left or right. Falls back to the facing direction.
func swing_direction() -> Vector2:
	var world_dir := _action_world_dir()
	if world_dir.length() < 0.001:
		world_dir = Vector2(float(_facing_sign), 0.0)
	var local := Vector2(world_dir.x * float(_facing_sign), world_dir.y)
	if local.length() < 0.001:
		return Vector2.RIGHT
	return local.normalized()


## [0, 1) progress through the current swing: a repeating cycle while mining,
## a single windup -> impact -> recovery pass while attacking.
func swing_progress() -> float:
	match action_kind():
		"attack":
			return _player.attack_swing_progress()
		"mine":
			return fposmod(_player.mine_progress / SWING_CYCLE_SEC, 1.0)
	return 0.0


## The action profile segment the swing is in: "windup", "impact", "recovery",
## or "" when idle. Segment lengths are the item's profile fractions.
func swing_phase_kind() -> String:
	if action_kind() == "":
		return ""
	var profile := active_action_profile()
	var progress := swing_progress()
	var windup := float(profile.get("windup", 0.35))
	var impact := float(profile.get("impact", 0.15))
	if progress < windup:
		return "windup"
	if progress < windup + impact:
		return "impact"
	return "recovery"


## The tool arc angle offset (radians) added to the aim direction: raise back
## through windup, snap through the target on impact, ease home on recovery.
func _swing_angle_offset() -> float:
	var profile := active_action_profile()
	var arc := deg_to_rad(float(profile.get("arc_deg", 55.0)))
	var windup := float(profile.get("windup", 0.35))
	var impact := float(profile.get("impact", 0.15))
	var progress := swing_progress()
	if progress < windup:
		var t := progress / maxf(windup, 0.001)
		return lerpf(0.0, arc * 0.5, smoothstep(0.0, 1.0, t))
	if progress < windup + impact:
		var t := (progress - windup) / maxf(impact, 0.001)
		return lerpf(arc * 0.5, -arc * 0.5, t)
	var t := (progress - windup - impact) / maxf(1.0 - windup - impact, 0.001)
	return lerpf(-arc * 0.5, 0.0, smoothstep(0.0, 1.0, t))


## The authored swing frame (0 raise, 1 mid, 2 strike) for the current segment.
func _swing_frame_for_kind(kind: String) -> int:
	match kind:
		"windup":
			return 0
		"impact":
			return 2
	return 1


func tool_swing_uses_procedural_fallback() -> bool:
	var item := active_action_item()
	return item != "" and _tool_swing_texture(
		item, _swing_frame_for_kind(swing_phase_kind())) == null


## The machine-readable character-rendering contract surface. Any consumer that
## must reproduce this character reads these fields rather than the private draw
## state. See docs/CHARACTER_RENDERING_CONTRACT.md; the smoke contract check
## pins the key set and the layer order.
func presentation_snapshot() -> Dictionary:
	return {
		"species": _species_id,
		"body_variant": _body_variant,
		"visual_variant": _visual_variant,
		"requested_body_id": requested_body_id(),
		"resolved_body_id": _resolved_body_id,
		"using_body_art": using_body_art(),
		"appearance_recolored": _appearance_recolored,
		"facing_sign": _facing_sign,
		"swing_phase": _player.swing_phase() if _player != null else -1,
		"active_tool_id": active_tool_id(),
		"visible_gear": visible_gear_ids(),
		"effective_body_id": effective_body_id(),
		"action_kind": action_kind(),
		"action_item": active_action_item(),
		"swing_phase_kind": swing_phase_kind(),
		"swing_direction": swing_direction(),
		"layer_order": CHARACTER_LAYER_ORDER,
	}


func _resolve_body_texture() -> void:
	_resolved_body_id = ""
	_body_texture = null
	_appearance_recolored = false
	var requested := requested_body_id()
	if requested != "":
		var requested_texture := _select_body_texture(requested)
		if requested_texture != null:
			_set_resolved_body(requested, requested_texture)
			return
	# A missing variant may fall back only to the same species' default body.
	var species_default := BlockRegistry.player_body_id(
		_species_id, BlockRegistry.default_body_variant())
	if species_default != "" and species_default != requested:
		var default_texture := _select_body_texture(species_default)
		if default_texture != null:
			_set_resolved_body(species_default, default_texture)


## FQ-13P3: pick the character's cosmetic body variant. visual_variant 0 (or an
## empty pool) uses the canonical <body_id>.png; variant k>0 uses the k-th
## full-body pool entry, wrapping by pool size so any stored index resolves.
## Presentation-only; the appearance recolor is applied later in _set_resolved_body.
func _select_body_texture(body_id: String) -> Texture2D:
	if _visual_variant > 0:
		var pool: Array = BlockRegistry.visual_variant_textures("players", body_id)
		if not pool.is_empty():
			return pool[(_visual_variant - 1) % pool.size()]
	return BlockRegistry.visual_texture("players", body_id)


func _set_resolved_body(body_id: String, source: Texture2D) -> void:
	_resolved_body_id = body_id
	_body_texture = _texture_with_appearance(source)


## Until authored mask images arrive, exact palette entries mark the skin
## pixels. Tan preserves source art byte-for-byte; Pale/Umber/Ash remap only
## those entries while retaining their relative light and shadow values.
func _texture_with_appearance(source: Texture2D) -> Texture2D:
	if _body_color.is_equal_approx(DEFAULT_APPEARANCE_BODY):
		return source
	var palette: Array = _rig().get("skin_palette", [])
	if palette.is_empty():
		return source
	var base := Color.from_string("#" + str(palette[0]), DEFAULT_APPEARANCE_BODY)
	var base_luminance := maxf(base.get_luminance(), 0.001)
	var replacements := {}
	for raw_color in palette:
		var source_color := Color.from_string("#" + str(raw_color), base)
		replacements[source_color.to_rgba32()] = \
			source_color.get_luminance() / base_luminance
	var source_image := source.get_image()
	if source_image == null or source_image.is_empty():
		return source
	# get_image() may share backing storage with an ImageTexture; copy the byte
	# payload so one appearance can never poison the registry's cached source.
	var image := Image.create_from_data(source_image.get_width(), source_image.get_height(),
		source_image.has_mipmaps(), source_image.get_format(), source_image.get_data())
	var changed := false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			var key := pixel.to_rgba32()
			if replacements.has(key) and _skin_region_contains(x, y):
				var ratio := float(replacements[key])
				image.set_pixel(x, y, Color(
					clampf(_body_color.r * ratio, 0.0, 1.0),
					clampf(_body_color.g * ratio, 0.0, 1.0),
					clampf(_body_color.b * ratio, 0.0, 1.0), pixel.a))
				changed = true
	if not changed:
		return source
	_appearance_recolored = true
	return ImageTexture.create_from_image(image)


func _skin_region_contains(x: int, y: int) -> bool:
	for raw_region in _rig().get("skin_regions", []):
		if raw_region is Array and raw_region.size() == 4:
			var region := Rect2i(int(raw_region[0]), int(raw_region[1]),
				int(raw_region[2]), int(raw_region[3]))
			if region.has_point(Vector2i(x, y)):
				return true
	return false


## Paints the character back to front in CHARACTER_LAYER_ORDER
## (accessory, body, feet, torso, weapon_or_swing, helmet). Keep this sequence
## and CHARACTER_LAYER_ORDER in lockstep — the rendering contract and the smoke
## contract check depend on them agreeing.
func _draw() -> void:
	var gear := visible_gear_ids()
	_draw_optional_overlay(str(gear.get("accessory", "")))
	if _body_texture != null:
		# Authored palette masks preserve clothing while applying the selected
		# appearance to skin. Dedicated mask images can replace this exact-color
		# bridge later without changing character saves.
		draw_texture_rect(_body_texture, BODY_RECT, false)
	else:
		_draw_procedural_body()
	_draw_feet(str(gear.get("feet", "")))
	_draw_torso(str(gear.get("torso", "")))
	if is_action_swinging():
		_draw_action_swing()
	else:
		_draw_idle_weapon(str(gear.get("weapon", "")))
	_draw_helmet(str(gear.get("helmet", "")))


func _draw_procedural_body() -> void:
	draw_rect(Rect2(-6, -14, 12, 28), _body_color)
	draw_rect(Rect2(-4, -12, 8, 6), _trim_color)


func _draw_optional_overlay(item_id: String) -> void:
	if item_id == "":
		return
	var tex := _gear_texture(item_id)
	if tex != null:
		draw_texture_rect(tex, _gear_rect("accessory"), false)
	else:
		# A small back bundle is the safe generic accessory fallback.
		draw_rect(Rect2(-7, -3, 4, 9), Color(0.31, 0.20, 0.12))


func _draw_feet(item_id: String) -> void:
	if item_id == "":
		return
	var tex := _gear_texture(item_id)
	if tex != null:
		draw_texture_rect(tex, _gear_rect("feet"), false)
		return
	var rig := _rig()
	var width := float(rig.get("feet_width", 4))
	var y := float(rig.get("feet_y", 11))
	var boot := Color(0.25, 0.20, 0.16)
	draw_rect(Rect2(-width - 1.0, y, width, 3), boot)
	draw_rect(Rect2(1.0, y, width, 3), boot)


func _draw_torso(item_id: String) -> void:
	if item_id == "":
		return
	var tex := _gear_texture(item_id)
	if tex != null:
		draw_texture_rect(tex, _gear_rect("torso"), false)
		return
	var center := _rig_point("torso", Vector2(0, -4))
	var size := _rig_point("torso_size", Vector2(10, 8))
	var rect := Rect2(center - size * 0.5, size)
	draw_rect(rect, Color(0.38, 0.30, 0.21, 0.92))
	draw_rect(rect.grow(-1.0), Color(0.50, 0.43, 0.31, 0.75), false, 1.0)


func _draw_helmet(item_id: String) -> void:
	if item_id == "":
		return
	var tex := _gear_texture(item_id)
	if tex != null:
		draw_texture_rect(tex, _gear_rect("helmet"), false)
		return
	var center := _rig_point("helmet", Vector2(0, -12))
	var size := _rig_point("helmet_size", Vector2(8, 4))
	var rect := Rect2(center - size * 0.5, size)
	draw_rect(rect, Color(0.40, 0.33, 0.24))
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end,
		Color(0.65, 0.58, 0.43), 1.0)


func _draw_idle_weapon(item_id: String) -> void:
	if item_id == "":
		return
	var tex := _gear_texture(item_id)
	if tex != null:
		draw_texture_rect(tex, _gear_rect("weapon"), false)
		return
	# Sheathed at the right hip; this mirrors naturally with the visual root.
	draw_line(Vector2(4, 2), Vector2(7, 12), Color(0.72, 0.74, 0.77), 2.0)
	draw_line(Vector2(2, 3), Vector2(6, 2), Color(0.42, 0.29, 0.17), 2.0)


## PR-04: draw the current action's swing. Authored pick/axe swing art is drawn
## rotated toward the aim direction; anything without swing art (the sword)
## falls back to a directional windup -> impact -> recovery arc through the same
## profile, so every tool/weapon uses one action-presentation contract.
func _draw_action_swing() -> void:
	var item := active_action_item()
	var frame := _swing_frame_for_kind(swing_phase_kind())
	var overlay := _tool_swing_texture(item, frame)
	if overlay != null:
		_draw_swing_overlay(overlay)
	else:
		_draw_procedural_swing(item)


## Rotate the authored swing overlay around the shoulder to aim at the target,
## so up/down/diagonal targets read directionally. The overlay is authored as a
## rightward pose (angle 0); swing_direction() is already mirror-aware.
func _draw_swing_overlay(overlay: Texture2D) -> void:
	var shoulder := _rig_point("shoulder", Vector2(5, -8))
	var angle := swing_direction().angle()
	draw_set_transform(shoulder, angle, Vector2.ONE)
	draw_texture_rect(overlay,
		Rect2(BODY_RECT.position - shoulder, BODY_RECT.size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Code-drawn arm + tool arc aimed at the target and posed by the swing profile.
func _draw_procedural_swing(item: String) -> void:
	var shoulder := _rig_point("shoulder", Vector2(5, -8))
	var aim := swing_direction().angle()
	var tool_angle := aim + _swing_angle_offset()
	var tool_dir := Vector2(cos(tool_angle), sin(tool_angle))
	# Reach extends toward the target on impact, shorter on windup/recovery.
	var reach := 7.0 if swing_phase_kind() != "impact" else 9.0
	var hand: Vector2 = shoulder + tool_dir * reach
	draw_line(shoulder, hand, _body_color.darkened(0.25), 2.0)
	var tip := hand + tool_dir * 6.0
	draw_line(hand, tip, Color(0.45, 0.30, 0.15), 2.0)
	if item.begins_with("axe_"):
		draw_rect(Rect2(tip - Vector2(2, 2), Vector2(4, 4)),
			Color(0.75, 0.78, 0.82))
	else:
		var head_side := Vector2(-tool_dir.y, tool_dir.x)
		draw_line(tip - head_side * 3.0, tip + head_side * 3.0,
			Color(0.75, 0.78, 0.82), 2.0)


func _rig() -> Dictionary:
	var rigs: Dictionary = BlockRegistry.player_visuals.get("rigs", {})
	return rigs.get(_species_id,
		BlockRegistry.player_visuals.get("default_rig", {}))


func _rig_point(key: String, fallback: Vector2) -> Vector2:
	var raw: Variant = _rig().get(key, [])
	if raw is Array and raw.size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return fallback


## Per-rig, per-slot pixel shift for authored gear overlays (data-owned
## rig.gear_offset). It aligns an overlay baked for a generic head/body height
## to a shorter rig — e.g. the goblin/dwarf crude helmet, whose art sits high in
## the 16x32 frame, is nudged down onto the head. Absent/unlisted slots return
## [0,0], so already-aligned bodies never move. Presentation only.
func gear_overlay_offset(slot: String) -> Vector2:
	var offsets: Dictionary = _rig().get("gear_offset", {})
	var raw: Variant = offsets.get(slot, [])
	if raw is Array and raw.size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO


## The draw rect for a gear slot's overlay: the body rect shifted by the slot's
## alignment offset. Consumers must draw authored overlays through this.
func _gear_rect(slot: String) -> Rect2:
	return Rect2(BODY_RECT.position + gear_overlay_offset(slot), BODY_RECT.size)


func _gear_texture(item_id: String) -> Texture2D:
	if item_id == "":
		return null
	var body_id := effective_body_id()
	if body_id != "":
		var body_specific := BlockRegistry.visual_texture(
			"player_gear", "%s_%s" % [item_id, body_id])
		if body_specific != null:
			return body_specific
	return BlockRegistry.visual_texture("player_gear", item_id)


func _tool_swing_texture(tool_id: String, phase: int) -> Texture2D:
	if tool_id == "" or phase < 0:
		return null
	var body_id := effective_body_id()
	if body_id != "":
		var body_specific := BlockRegistry.visual_texture("player_gear",
			"%s_%s_swing_%d" % [tool_id, body_id, phase])
		if body_specific != null:
			return body_specific
	return BlockRegistry.visual_texture("player_gear",
		"%s_swing_%d" % [tool_id, phase])
