extends RefCounted
## R-06.1 (ownership decomposition): the stateless painted-chrome / themed-PNG
## resolver and the slicer-measured geometry parsers, lifted out of hud.gd
## behind a preserved facade. Nothing here owns scene state -- every function
## is a pure transform over the BlockRegistry autoload and the tracked
## `res://art/generated/ui_painted/*` geometry sidecars. hud.gd keeps thin
## delegating wrappers so its public surface (and the fq21 smoke that drives
## `_painted_texture_for_theme` / `_normalize_hud_visual_theme` /
## `_load_hud_kit_layout` / `_json_rect`) is unchanged.
##
## No `class_name` (repo cache-safety rule): consumers `preload` this script.

const HUD_VISUAL_THEME_SEPARATOR := "__"
const HUD_VISUAL_THEME_MAX_LENGTH := 48


## Static painted UI supports optional per-theme siblings named
## `<asset>__<theme>.png`. Every lookup is asset-local: a missing, unreadable,
## wrong-size, or wrong-format themed PNG falls back to the required base PNG.
## Runtime-owned item icons, values, fills, counts, and labels never pass
## through this presentation-only resolver.
static func painted_texture_for_theme(id: String, theme_id: String) -> Texture2D:
	var fallback: Texture2D = BlockRegistry.visual_texture("ui_painted", id)
	if fallback == null:
		return null
	var safe_theme := normalize_hud_visual_theme(theme_id)
	if safe_theme.is_empty():
		return fallback
	var themed: Texture2D = BlockRegistry.visual_texture(
		"ui_painted", "%s%s%s" % [id, HUD_VISUAL_THEME_SEPARATOR, safe_theme])
	if not themed_texture_matches_fallback(themed, fallback):
		return fallback
	return themed


static func themed_texture_matches_fallback(themed: Texture2D,
		fallback: Texture2D) -> bool:
	if themed == null or fallback == null or themed.get_size() != fallback.get_size():
		return false
	var themed_image: Image = themed.get_image()
	var fallback_image: Image = fallback.get_image()
	return themed_image != null and fallback_image != null \
		and not themed_image.is_empty() and not fallback_image.is_empty() \
		and themed_image.get_format() == fallback_image.get_format()


static func normalize_hud_visual_theme(raw_id: String) -> String:
	var raw := raw_id.strip_edges().to_lower()
	var normalized := ""
	for index in range(raw.length()):
		var code := raw.unicode_at(index)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57) \
				or code == 95:
			normalized += raw[index]
		elif code == 32 or code == 45:
			normalized += "_"
		else:
			return ""
	if normalized.length() > HUD_VISUAL_THEME_MAX_LENGTH:
		return ""
	return normalized


## FQ-21: slicer-measured band geometry -- the runtime never hand-syncs mockup
## coordinates again (that was the source of the masking misalignments).
static func load_band_geometry() -> Dictionary:
	var raw := FileAccess.get_file_as_string(
		"res://art/generated/ui_painted/dock_band_geometry.json")
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


static func load_hud_kit_layout() -> Dictionary:
	var raw := FileAccess.get_file_as_string(
		"res://art/generated/ui_painted/hud_dock_layout.json")
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}


static func json_rect(value: Variant) -> Rect2:
	if value is Array and (value as Array).size() >= 4:
		return Rect2(float(value[0]), float(value[1]),
			float(value[2]), float(value[3]))
	return Rect2()


static func json_vec(pair: Variant) -> Vector2:
	if pair is Array and (pair as Array).size() >= 2:
		return Vector2(float(pair[0]), float(pair[1]))
	return Vector2.ZERO


## R-06.3: presentation texture prep (pure CPU image processing). hud.gd keeps
## the per-instance caches and the source-texture lookup; only the build step
## lives here.

# The 32px orb fill mask's disk occupies art px 5..26 (a 22px region).
const ORB_FILL_MASK_DISK := Rect2i(5, 5, 22, 22)


## A texture pre-resized on the CPU (TextureRect STRETCH_TILE tiles at the
## texture's native size, so the tile must be baked at display scale).
static func scaled_texture_from(src: Texture2D, factor: float) -> Texture2D:
	if src == null:
		return null
	var img: Image = src.get_image()
	img.resize(int(round(img.get_width() * factor)),
		int(round(img.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## The orb fill-mask disk cropped to its disk and resized to the exact glass
## diameter, so TextureProgressBar can crop the liquid natively (nine-patch
## stretching SQUASHES the disk instead of draining it -- the "health never
## drops" bug the operator caught).
static func glass_mask_from(src: Texture2D, diameter: int) -> Texture2D:
	if src == null:
		return null
	var disk: Image = src.get_image().get_region(ORB_FILL_MASK_DISK)
	disk.resize(diameter, diameter, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(disk)
