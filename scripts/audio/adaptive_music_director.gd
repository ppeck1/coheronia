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
var _poll_accum := 0.0
var _switch_requests := 0      # smoke hook: proves no re-request churn

@onready var _context_player: AudioStreamPlayer = $ContextPlayer


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


func _on_settlement_updated(_coherence: float, load_value: float, _resilience: float,
		_inputs: Dictionary, _labels: Array) -> void:
	_settlement_load = load_value


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < POLL_SECONDS:
		return
	var dt := _poll_accum
	_poll_accum = 0.0
	evaluate(_gather_state(), dt)
	_settle_pending()


## Reads existing game truth — never a duplicate simulation. The underground
## rule is the cave-spawn rule: the player's cell sits below the generated
## surface of its column.
func _gather_state() -> Dictionary:
	var root := get_parent()
	if root == null or not ("player" in root) or root.player == null or root.world == null:
		return {"is_night": false, "storm": false, "threat": 0.0,
			"health_ratio": 1.0, "underground": false}
	var world: Node2D = root.world
	var pcell: Vector2i = world.cell_of(root.player.global_position)
	var underground: bool = world.surface.has(pcell.x) \
		and pcell.y > int(world.surface[pcell.x])
	return {
		"is_night": root.is_night,
		"storm": root.storm_active,
		"threat": root.current_threat_severity(),
		"health_ratio": root.player.health / maxf(1.0, root.player.max_health),
		"underground": underground,
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


# ---------- debug / smoke hooks ----------

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
