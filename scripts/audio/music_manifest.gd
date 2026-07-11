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
## OGGs load via AudioStreamOggVorbis.load_from_file so plain runs need no
## editor import pass (the FQ-07 rule, applied to audio); the musical grid
## (bpm / beats-per-bar / beat count) is stamped onto each stream so
## AudioStreamInteractive can quantize transitions to bars.
static func load_context_streams(manifest: Dictionary) -> Dictionary:
	var out := {}
	var contexts: Dictionary = manifest.get("contexts", {})
	var bpm := float(manifest.get("bpm", 72.0))
	var beats_per_bar := int(manifest.get("beats_per_bar", 4))
	var total_beats := int(manifest.get("bars_per_loop", 16)) * beats_per_bar
	for ctx in CONTEXT_ORDER:
		var path := str((contexts.get(ctx, {}) as Dictionary).get("stream", ""))
		if path == "" or not FileAccess.file_exists(path):
			continue
		var stream: AudioStream = AudioStreamOggVorbis.load_from_file(path)
		if stream == null:
			continue
		stream.loop = true
		stream.bpm = bpm
		stream.bar_beats = beats_per_bar
		stream.beat_count = total_beats
		out[ctx] = stream
	return out


## Seconds per musical bar under the manifest grid (the min-hold unit).
static func bar_seconds(manifest: Dictionary) -> float:
	var bpm := maxf(1.0, float(manifest.get("bpm", 72.0)))
	return float(manifest.get("beats_per_bar", 4)) * 60.0 / bpm


## Exact seconds one full loop must last under the manifest grid.
static func loop_seconds(manifest: Dictionary) -> float:
	return float(manifest.get("bars_per_loop", 16)) * bar_seconds(manifest)


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
		if path == "" or not FileAccess.file_exists(path):
			continue
		var stream: AudioStream = AudioStreamOggVorbis.load_from_file(path)
		if stream == null:
			continue
		stream.loop = true
		stream.bpm = bpm
		stream.bar_beats = beats_per_bar
		stream.beat_count = total_beats
		out[stem_name] = stream
	return out
