extends RefCounted
## FQ-09U1: dedicated loader for data/music_manifest.json — the adaptive
## music program's machine contract (grid, contexts, transition rules,
## pressure normalization, hysteresis thresholds). A deliberate standalone
## loader: the music system must not turn BlockRegistry into a service
## locator. Missing or invalid files are never fatal anywhere in this path —
## callers receive empty results and stay silent-safe.

const MANIFEST_PATH := "res://data/music_manifest.json"
const CONTEXT_ORDER := ["surface_day", "surface_night", "underground", "crisis"]


## Parses the manifest; {} on any failure (missing file, bad JSON).
static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	return parsed if parsed is Dictionary else {}


## Loads the four context loop streams named by the manifest. Returns
## context_name -> AudioStream for every stream that actually loaded; a
## missing/broken file simply leaves its context out (caller decides whether
## a partial set is playable — FQ-09U1 requires all four or none).
## OGGs load import-aware via ResourceLoader (see _load_stream) so adaptive
## audio survives an exported PCK; each stream is duplicated before the musical
## grid (bpm / beats-per-bar / beat count) is stamped onto it, so
## AudioStreamInteractive can quantize transitions to bars without mutating the
## shared cached import resource.
static func load_context_streams(manifest: Dictionary) -> Dictionary:
	var out := {}
	var contexts: Dictionary = manifest.get("contexts", {})
	var bpm := float(manifest.get("bpm", 72.0))
	var beats_per_bar := int(manifest.get("beats_per_bar", 4))
	var total_beats := int(manifest.get("bars_per_loop", 16)) * beats_per_bar
	for ctx in CONTEXT_ORDER:
		var path := str((contexts.get(ctx, {}) as Dictionary).get("stream", ""))
		var stream := _load_stream(path)
		if stream == null:
			continue
		stream.loop = true
		stream.bpm = bpm
		stream.bar_beats = beats_per_bar
		stream.beat_count = total_beats
		out[ctx] = stream
	return out


## R-01: import-aware stream load. ResourceLoader resolves the imported
## AudioStream through the export remap, so adaptive audio loads from a
## packed/exported build as well as a plain editor run — a raw
## AudioStreamOggVorbis.load_from_file on the source res:// path returns nothing
## in an exported PCK. The stream is DUPLICATED before the caller stamps
## loop/BPM/grid, so the shared cached import resource is never mutated (every
## context/stem/stinger gets its own instance). "" or a missing/failed resource
## returns null so the audio system stays silent-safe.
static func _load_stream(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path, "AudioStream"):
		return null
	var loaded: AudioStream = ResourceLoader.load(path, "AudioStream") as AudioStream
	if loaded == null:
		return null
	return loaded.duplicate() as AudioStream


## Seconds per musical bar under the manifest grid (the min-hold unit).
static func bar_seconds(manifest: Dictionary) -> float:
	var bpm := maxf(1.0, float(manifest.get("bpm", 72.0)))
	return float(manifest.get("beats_per_bar", 4)) * 60.0 / bpm


## Exact seconds one full loop must last under the manifest grid.
static func loop_seconds(manifest: Dictionary) -> float:
	return float(manifest.get("bars_per_loop", 16)) * bar_seconds(manifest)


## FQ-09U3: loads the stinger one-shots (runtime OGG load, NO looping, no
## grid — they are events, not loops). Returns kind -> AudioStream for every
## file that loaded; missing files simply leave their kind out.
static func load_stinger_streams(manifest: Dictionary) -> Dictionary:
	var out := {}
	var stingers: Dictionary = manifest.get("stingers", {})
	for kind in stingers:
		if str(kind).begins_with("_"):
			continue
		var path := str(stingers[kind])
		var stream := _load_stream(path)
		if stream == null:
			continue
		stream.loop = false
		out[kind] = stream
	return out


## FQ-09U2: loads the six phase-locked stem streams (same rules as context
## loops — runtime OGG load, loop + grid stamped). Returns stem_name ->
## AudioStream for every file that loaded; the caller enforces the
## complete-set and equal-length contracts.
static func load_stem_streams(manifest: Dictionary) -> Dictionary:
	var out := {}
	var stems: Dictionary = manifest.get("stems", {})
	var bpm := float(manifest.get("bpm", 72.0))
	var beats_per_bar := int(manifest.get("beats_per_bar", 4))
	var total_beats := int(manifest.get("bars_per_loop", 16)) * beats_per_bar
	for stem_name in stems:
		if str(stem_name).begins_with("_"):
			continue
		var path := str(stems[stem_name])
		var stream := _load_stream(path)
		if stream == null:
			continue
		stream.loop = true
		stream.bpm = bpm
		stream.bar_beats = beats_per_bar
		stream.beat_count = total_beats
		out[stem_name] = stream
	return out
