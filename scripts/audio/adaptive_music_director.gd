extends Node
## FQ-09U1: the adaptive music director — seamless, state-driven context
## music using full-mix loops only (the hybrid adaptive score's horizontal
## layer). One AudioStreamInteractive holds the four context clips
## (surface_day / surface_night / underground / crisis); transitions are
## bar-quantized, same-position, crossfaded (crisis entry escalates to
## next-beat), exactly as proven by the in-run API/behavior spike.
##
## Every decision derives from existing game truth (day/night, the
## cave-spawn underground rule, storms, threat severity, player health, the
## settlement's 5-second `updated` signal). All thresholds, normalization
## divisors, and fade lengths are data-defined in data/music_manifest.json.
## Hysteresis plus a one-bar minimum hold stop threshold thrashing, and the
## already-current or already-pending context is never re-requested.
##
## Music state is transient: nothing here reads or writes saves, and
## missing/invalid audio assets disable playback silently without touching
## gameplay. LayerPlayer (stems, FQ-09U2) and StingerPlayer (FQ-09U3) are
## reserved children, unused this increment.

const MusicManifest := preload("res://scripts/audio/music_manifest.gd")
const MUSIC_BUS := "Music"
const POLL_SECONDS := 0.5

## Tests may inject a manifest before the node enters the tree.
var manifest_override: Dictionary = {}

var _manifest: Dictionary = {}
var _enabled := false          # audio wired and playing (state machine runs regardless)
var _clip_index: Dictionary = {}   # context name -> clip index
var _current := "surface_day"
var _pending := ""
var _in_crisis := false
var _crisis_above := 0.0       # seconds pressure has held above the enter threshold
var _crisis_below := 0.0       # seconds pressure has held below the exit threshold
var _hold_left := 0.0          # minimum-context-hold seconds remaining
var _pressure := 0.0
var _settlement_load := 0.0    # cached from the settlement `updated` signal
var _settlement_coherence := 0.0
var _settlement_resilience := 0.0
var _poll_accum := 0.0
var _switch_requests := 0      # smoke hook: proves no re-request churn

# FQ-09U2: the shared phase-locked stem bed (AudioStreamSynchronized on the
# LayerPlayer, started in the same frame as the context stream so equal-
# length loops stay aligned by construction). Volumes move smoothly toward
# data-defined targets; layering failures never touch the context music.
var _layer_enabled := false
var _stem_order: Array = []            # stable stem name order = substream index
var _stem_targets: Dictionary = {}     # stem name -> target volume db
var _stem_volumes: Dictionary = {}     # stem name -> current volume db

@onready var _context_player: AudioStreamPlayer = $ContextPlayer
@onready var _layer_player: AudioStreamPlayer = $LayerPlayer


func _ready() -> void:
	_manifest = manifest_override if not manifest_override.is_empty() \
		else MusicManifest.load_manifest()
	var settlement := get_node_or_null("../SettlementModel")
	if settlement != null and settlement.has_signal("updated"):
		settlement.updated.connect(_on_settlement_updated)
	if _manifest.is_empty():
		return
	var streams: Dictionary = MusicManifest.load_context_streams(_manifest)
	if streams.size() != MusicManifest.CONTEXT_ORDER.size():
		# Missing or broken assets: stay silent-safe. The state machine still
		# evaluates (so tests and debug surfaces work) but nothing plays.
		push_warning("AdaptiveMusicDirector: context loops missing (%d/4); music disabled."
			% streams.size())
		return
	_ensure_music_bus()
	_context_player.stream = _build_interactive(streams)
	_context_player.bus = MUSIC_BUS
	_context_player.play()
	_enabled = true
	_setup_layer_bed()


## FQ-09U2: builds the synchronized stem bed. Requires the complete six-stem
## set with every loop matching the manifest grid's exact length — any
## shortfall disables layering with a warning while the context music plays
## on untouched (fail-safe by construction).
func _setup_layer_bed() -> void:
	var mix: Dictionary = _manifest.get("stem_mix", {})
	var layers: Dictionary = mix.get("layers", {})
	if layers.is_empty():
		return
	var stems: Dictionary = MusicManifest.load_stem_streams(_manifest)
	if stems.size() != layers.size():
		push_warning("AdaptiveMusicDirector: stems missing (%d/%d); layering disabled."
			% [stems.size(), layers.size()])
		return
	var expected := MusicManifest.loop_seconds(_manifest)
	for stem_name in stems:
		var length: float = (stems[stem_name] as AudioStream).get_length()
		if absf(length - expected) > 0.05:
			push_warning("AdaptiveMusicDirector: stem '%s' loop length %.3fs != %.3fs; layering disabled."
				% [stem_name, length, expected])
			return
	var floor_db := float(mix.get("floor_db", -60.0))
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = stems.size()
	_stem_order.clear()
	var idx := 0
	for stem_name in layers:   # manifest layer order defines substream index
		if not stems.has(stem_name):
			return
		sync.set_sync_stream(idx, stems[stem_name])
		sync.set_sync_stream_volume(idx, floor_db)
		_stem_order.append(stem_name)
		_stem_targets[stem_name] = floor_db
		_stem_volumes[stem_name] = floor_db
		idx += 1
	_layer_player.stream = sync
	_layer_player.bus = MUSIC_BUS
	# Same-frame start as the context stream: equal-length loops on the same
	# mix clock stay phase-aligned for the whole session.
	_layer_player.play(_context_player.get_playback_position())
	_layer_enabled = true


## One interactive stream, four named clips, transitions from any clip to
## every clip: next-bar + same-position + crossfade normally, next-beat into
## crisis (the sanctioned emergency transition).
func _build_interactive(streams: Dictionary) -> AudioStreamInteractive:
	var interactive := AudioStreamInteractive.new()
	interactive.clip_count = MusicManifest.CONTEXT_ORDER.size()
	var transition: Dictionary = _manifest.get("transition", {})
	var fade_beats := float(transition.get("fade_beats", 4.0))
	for i in range(MusicManifest.CONTEXT_ORDER.size()):
		var ctx: String = MusicManifest.CONTEXT_ORDER[i]
		_clip_index[ctx] = i
		interactive.set_clip_name(i, ctx)
		interactive.set_clip_stream(i, streams[ctx])
		var from_time := AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BAR
		if ctx == "crisis" and str(transition.get("emergency_quantize", "next_beat")) == "next_beat":
			from_time = AudioStreamInteractive.TRANSITION_FROM_TIME_NEXT_BEAT
		interactive.add_transition(AudioStreamInteractive.CLIP_ANY, i,
			from_time, AudioStreamInteractive.TRANSITION_TO_TIME_SAME_POSITION,
			AudioStreamInteractive.FADE_CROSS, fade_beats)
	interactive.set_initial_clip(int(_clip_index.get(_current, 0)))
	return interactive


func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, MUSIC_BUS)
	AudioServer.set_bus_send(idx, "Master")


func _on_settlement_updated(coherence: float, load_value: float, resilience: float,
		_inputs: Dictionary, _labels: Array) -> void:
	_settlement_load = load_value
	_settlement_coherence = coherence
	_settlement_resilience = resilience


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < POLL_SECONDS:
		return
	var dt := _poll_accum
	_poll_accum = 0.0
	evaluate(_gather_state(), dt)
	_settle_pending()
	_step_stem_volumes(dt)


## Reads existing game truth — never a duplicate simulation. The underground
## rule is the cave-spawn rule: the player's cell sits below the generated
## surface of its column.
func _gather_state() -> Dictionary:
	var root := get_parent()
	if root == null or not ("player" in root) or root.player == null or root.world == null:
		return {"is_night": false, "storm": false, "threat": 0.0,
			"health_ratio": 1.0, "underground": false,
			"attunement": 0.0, "activity": 0.0}
	var world: Node2D = root.world
	var player: CharacterBody2D = root.player
	var pcell: Vector2i = world.cell_of(player.global_position)
	var underground: bool = world.surface.has(pcell.x) \
		and pcell.y > int(world.surface[pcell.x])
	return {
		"is_night": root.is_night,
		"storm": root.storm_active,
		"threat": root.current_threat_severity(),
		"health_ratio": player.health / maxf(1.0, player.max_health),
		"underground": underground,
		# FQ-09U2 stem sources: the attunement layer follows the player's
		# pool; the work pulse follows mining or real horizontal movement.
		"attunement": player.attunement / maxf(1.0, player.max_attunement()),
		"activity": 1.0 if (player.mine_required > 0.0
			or absf(player.velocity.x) > 10.0) else 0.0,
	}


## The deterministic core, called by the poll and directly by tests with
## synthetic snapshots and explicit deltas (no wall-clock dependence).
func evaluate(state: Dictionary, delta: float) -> void:
	_pressure = pressure_of(state)
	var thresholds: Dictionary = _manifest.get("thresholds", {})
	if _in_crisis:
		if _pressure < float(thresholds.get("crisis_exit", 0.35)):
			_crisis_below += delta
			if _crisis_below >= float(thresholds.get("crisis_exit_seconds", 6.0)):
				_in_crisis = false
				_crisis_below = 0.0
		else:
			_crisis_below = 0.0
	else:
		if _pressure > float(thresholds.get("crisis_enter", 0.6)):
			_crisis_above += delta
			if _crisis_above >= float(thresholds.get("crisis_enter_seconds", 2.0)):
				_in_crisis = true
				_crisis_above = 0.0
		else:
			_crisis_above = 0.0
	_update_stem_targets(state)
	_hold_left = maxf(0.0, _hold_left - delta)
	var requested := _resolve_context(state)
	if requested == _current or requested == _pending:
		return   # never re-request the current or already-pending clip
	if _hold_left > 0.0:
		return   # minimum context hold; the next poll re-derives the request
	_request(requested)


## Priority: crisis > underground > surface_night > surface_day. Storms
## contribute pressure (see pressure_of) rather than forcing a fifth track.
func _resolve_context(state: Dictionary) -> String:
	if _in_crisis:
		return "crisis"
	if bool(state.get("underground", false)):
		return "underground"
	if bool(state.get("is_night", false)):
		return "surface_night"
	return "surface_day"


## pressure = max(threat/norm, settlement load/norm, inverse health) plus a
## storm bonus; all divisors data-defined and clamped to 0..1.
func pressure_of(state: Dictionary) -> float:
	var norms: Dictionary = _manifest.get("pressure", {})
	var p := maxf(float(state.get("threat", 0.0)) / maxf(1.0, float(norms.get("threat_severity_norm", 40.0))),
		maxf(_settlement_load / maxf(1.0, float(norms.get("load_norm", 100.0))),
			(1.0 - float(state.get("health_ratio", 1.0))) * float(norms.get("health_weight", 1.0))))
	if bool(state.get("storm", false)):
		p += float(norms.get("storm_bonus", 0.15))
	return clampf(p, 0.0, 1.0)


func _request(ctx: String) -> void:
	_pending = ctx
	_switch_requests += 1
	_hold_left = maxf(_hold_left,
		float(_manifest.get("transition", {}).get("min_context_hold_bars", 1))
		* MusicManifest.bar_seconds(_manifest))
	if _enabled and _context_player.playing:
		var playback := _context_player.get_stream_playback() as AudioStreamPlaybackInteractive
		if playback != null:
			playback.switch_to_clip_by_name(ctx)


## Promotes pending -> current once the interactive playback has actually
## reached the requested clip (or immediately when audio is disabled, so the
## state machine stays coherent without assets).
func _settle_pending() -> void:
	if _pending == "":
		return
	if not _enabled:
		_current = _pending
		_pending = ""
		return
	if playback_clip_index() == int(_clip_index.get(_pending, -2)):
		_current = _pending
		_pending = ""


# ---------- FQ-09U2: stem target mixing and smoothing ----------

## Data-defined targets: each stem's volume aims at lerp(min_db, max_db,
## source value 0..1). Sources read the state snapshot and the cached
## settlement values — never a duplicate simulation. Storms raise the
## pressure stem's floor (the storm texture) instead of forcing a fifth
## context track.
func _update_stem_targets(state: Dictionary) -> void:
	if _stem_order.is_empty():
		return
	var mix: Dictionary = _manifest.get("stem_mix", {})
	var layers: Dictionary = mix.get("layers", {})
	for stem_name in _stem_order:
		var layer: Dictionary = layers.get(stem_name, {})
		var value := _source_value(str(layer.get("source", "")), state)
		var target := lerpf(float(layer.get("min_db", -60.0)),
			float(layer.get("max_db", -10.0)), clampf(value, 0.0, 1.0))
		if stem_name == "pressure" and bool(state.get("storm", false)):
			target = maxf(target, float(mix.get("storm_pressure_floor_db", -16.0)))
		_stem_targets[stem_name] = target


func _source_value(source: String, state: Dictionary) -> float:
	match source:
		"resilience":
			return _settlement_resilience / 100.0
		"coherence":
			return _settlement_coherence / 100.0
		"pressure":
			return _pressure
		"attunement":
			return float(state.get("attunement", 0.0))
		"activity":
			return float(state.get("activity", 0.0))
		"collapse_edge":
			# The fracture layer wakes only at the settlement's edge:
			# pressure past 0.7 fades it in, saturating at 1.0.
			return clampf((_pressure - 0.7) / 0.3, 0.0, 1.0)
	return 0.0


## Volumes move gradually toward their targets (data-defined dB/sec), never
## snapping — the smoothing half of the anti-thrash contract. Deterministic:
## driven by the poll's delta and callable directly by tests.
func _step_stem_volumes(dt: float) -> void:
	if not _layer_enabled:
		return
	var rate := float(_manifest.get("stem_mix", {}).get("smoothing_db_per_sec", 6.0))
	var sync := _layer_player.stream as AudioStreamSynchronized
	for i in range(_stem_order.size()):
		var stem_name: String = _stem_order[i]
		var current := float(_stem_volumes[stem_name])
		var target := float(_stem_targets[stem_name])
		var stepped := current + clampf(target - current, -rate * dt, rate * dt)
		if not is_equal_approx(stepped, current):
			_stem_volumes[stem_name] = stepped
			sync.set_sync_stream_volume(i, stepped)


# ---------- debug / smoke hooks ----------

func layering_enabled() -> bool:
	return _layer_enabled


func stem_targets() -> Dictionary:
	return _stem_targets.duplicate()


func stem_volumes() -> Dictionary:
	return _stem_volumes.duplicate()

func enabled() -> bool:
	return _enabled


func current_context() -> String:
	return _current


func requested_context() -> String:
	return _pending if _pending != "" else _current


func pressure_value() -> float:
	return _pressure


func in_crisis() -> bool:
	return _in_crisis


func switch_request_count() -> int:
	return _switch_requests


func clip_index_of(ctx: String) -> int:
	return int(_clip_index.get(ctx, -1))


func playback_clip_index() -> int:
	if not _enabled or not _context_player.playing:
		return -1
	var playback := _context_player.get_stream_playback() as AudioStreamPlaybackInteractive
	return playback.get_current_clip_index() if playback != null else -1


## Test-only hard reset: clears every timer and pending request and (when
## audio is live) jumps the playback to the given context so hysteresis and
## transition checks start from a known state. Never used by gameplay.
func debug_reset(ctx: String) -> void:
	_current = ctx
	_pending = ""
	_in_crisis = ctx == "crisis"
	_crisis_above = 0.0
	_crisis_below = 0.0
	_hold_left = 0.0
	_poll_accum = 0.0
	if _enabled and _context_player.playing:
		var playback := _context_player.get_stream_playback() as AudioStreamPlaybackInteractive
		if playback != null:
			playback.switch_to_clip(int(_clip_index.get(ctx, 0)))
