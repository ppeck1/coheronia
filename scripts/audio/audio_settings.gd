extends RefCounted
## FQ-09U3: user audio preferences — Music and SFX volume, stored as
## profile-level values in user://shell.json (a user preference, like the
## player name; never part of world or character saves). Static helpers so
## the shell title screen and the AdaptiveMusicDirector share one
## application path. The director layers its temporary stinger duck ON TOP
## of the user's music volume; this file owns only the base levels.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

## Authored music calibration trim (dB), applied to the Music bus ONLY, on top
## of the user's Music Volume and any temporary stinger duck. The rendered
## assets and the user's stored Music Volume are untouched; this constant is the
## single authority for "how loud is 100% music" so a Music Volume of 1.0 means
## the intended, calibrated game-music level rather than raw asset amplitude.
## Resolved Music-bus dB = _to_db(music_volume) + MUSIC_TRIM_DB + music_duck_db.
## SFX is deliberately NOT trimmed. See docs/VARIABLE_MATRIX.md.
const MUSIC_TRIM_DB := -12.0


static func music_volume(profile: Dictionary) -> float:
	return clampf(float(profile.get("music_volume", 1.0)), 0.0, 1.0)


static func sfx_volume(profile: Dictionary) -> float:
	return clampf(float(profile.get("sfx_volume", 1.0)), 0.0, 1.0)


static func set_music_volume(profile: Dictionary, value: float) -> void:
	profile["music_volume"] = clampf(value, 0.0, 1.0)


static func set_sfx_volume(profile: Dictionary, value: float) -> void:
	profile["sfx_volume"] = clampf(value, 0.0, 1.0)


## Ensures both buses exist and applies the profile volumes (plus an
## optional duck offset on the Music bus, owned by the music director).
## Safe to call from any scene at any time.
static func apply(profile: Dictionary, music_duck_db: float = 0.0) -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS),
		_to_db(music_volume(profile)) + MUSIC_TRIM_DB + music_duck_db)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS),
		_to_db(sfx_volume(profile)))


static func _to_db(linear: float) -> float:
	return linear_to_db(linear) if linear > 0.0 else -80.0


static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
