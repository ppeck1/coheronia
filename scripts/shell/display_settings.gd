extends RefCounted
## User display preferences — camera VIEW ZOOM (how much of the world is on screen
## at once) and FULLSCREEN — stored profile-level in user://shell.json, exactly like
## audio volume (a per-player preference, never part of a world or character save).
## Static helpers so the boot path, the pause-menu Settings screen, and the in-game
## wheel/key controls all share one application path.
##
## Camera2D.zoom is a MAGNIFICATION: a higher value shows LESS world at a larger size
## (zoomed in), a lower value shows MORE world at a smaller size (zoomed out). The
## stored `view_zoom` maps straight onto Camera2D.zoom.

const MIN_ZOOM := 1.0       # widest view — most world visible, smallest content
const MAX_ZOOM := 3.0       # closest view — least world, largest content
const DEFAULT_ZOOM := 1.25  # a wider default than the old fixed 2.0 (see more map)
const ZOOM_STEP := 0.125    # one wheel notch / +/- key press

# S-07.1b (F6 taste): how strongly an open modal dims the rest of the HUD. Stored
# as the scrim overlay's alpha; a per-player preference like zoom/volume.
const MIN_SCRIM := 0.30     # light dim — HUD stays fairly visible behind the modal
const MAX_SCRIM := 0.85     # heavy dim — the world/HUD nearly blacked out
const DEFAULT_SCRIM := 0.58 # the shipped S-07.1b default
const SCRIM_STEP := 0.05


static func view_zoom(profile: Dictionary) -> float:
	return clampf(float(profile.get("view_zoom", DEFAULT_ZOOM)), MIN_ZOOM, MAX_ZOOM)


## Store a clamped zoom and return the value actually stored.
static func set_view_zoom(profile: Dictionary, value: float) -> float:
	var z := clampf(value, MIN_ZOOM, MAX_ZOOM)
	profile["view_zoom"] = z
	return z


## Modal dim-scrim strength (overlay alpha), clamped to the sane taste range.
static func scrim_strength(profile: Dictionary) -> float:
	return clampf(float(profile.get("modal_scrim_strength", DEFAULT_SCRIM)),
		MIN_SCRIM, MAX_SCRIM)


## Store a clamped scrim strength and return the value actually stored.
static func set_scrim_strength(profile: Dictionary, value: float) -> float:
	var s := clampf(value, MIN_SCRIM, MAX_SCRIM)
	profile["modal_scrim_strength"] = s
	return s


static func fullscreen(profile: Dictionary) -> bool:
	return bool(profile.get("fullscreen", false))


static func set_fullscreen(profile: Dictionary, on: bool) -> void:
	profile["fullscreen"] = on


## Apply the profile's view zoom to a Camera2D. Safe with a null camera.
static func apply_zoom(profile: Dictionary, camera: Camera2D) -> void:
	if camera == null:
		return
	var z := view_zoom(profile)
	camera.zoom = Vector2(z, z)


## Nudge the zoom by `steps` ZOOM_STEP increments (positive = zoom in / see less),
## store it, apply it to `camera`, and return the new value. Used by wheel/key input.
static func nudge_zoom(profile: Dictionary, camera: Camera2D, steps: float) -> float:
	var z := set_view_zoom(profile, view_zoom(profile) + steps * ZOOM_STEP)
	apply_zoom(profile, camera)
	return z


## Apply the profile's window mode. No-op under the headless display server (so
## smoke/CI runs never poke a non-existent window).
static func apply_window(profile: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen(profile) \
		else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Flip fullscreen, persist the flag on the profile, apply it, and return the new
## state. The caller saves the shell.
static func toggle_fullscreen(profile: Dictionary) -> bool:
	set_fullscreen(profile, not fullscreen(profile))
	apply_window(profile)
	return fullscreen(profile)
