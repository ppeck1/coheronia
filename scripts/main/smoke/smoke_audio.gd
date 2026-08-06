extends Node
## S-07.3 smoke domain module - adaptive music (FQ-09U1/2/3).
## Order-preserving extraction from smoke_test.gd _run(): the harness
## (smoke_test) owns _check() and the results ledger; this module holds only
## the section body and is called in place by the coordinator. Kept as ONE
## method because the AdaptiveMusicDirector handle and its
## set_process(false)/(true) toggle span all three sub-sections.


func run(harness, root, player) -> void:
	# --- FQ-09U1: adaptive context music foundation ---
	# The state machine is asserted deterministically (direct evaluate calls
	# with synthetic snapshots and explicit deltas — no wall-clock waits);
	# the one live-audio check proves the interactive stream actually
	# switches clips (the in-run behavior half of the FQ-09U spike).

	var _fq09u_dir: Node = root.get_node("AdaptiveMusicDirector")
	_fq09u_dir.set_process(false)   # keep the live poll out of synthetic checks
	_fq09u_dir._settlement_load = 0.0
	var _fq09u_day := {"is_night": false, "storm": false, "threat": 0.0,
		"health_ratio": 1.0, "underground": false}
	var _fq09u_night := {"is_night": true, "storm": false, "threat": 0.0,
		"health_ratio": 1.0, "underground": false}
	var _fq09u_under := {"is_night": false, "storm": false, "threat": 0.0,
		"health_ratio": 1.0, "underground": true}
	var _fq09u_high := {"is_night": false, "storm": false, "threat": 40.0,
		"health_ratio": 1.0, "underground": false}

	# (a) manifest + streams: the machine contract loads, all four context
	# loops decode, and the musical grid is stamped onto every stream.
	var _fq09u_mm: GDScript = load("res://scripts/audio/music_manifest.gd")
	var _fq09u_manifest: Dictionary = _fq09u_mm.load_manifest()
	var _fq09u_streams: Dictionary = _fq09u_mm.load_context_streams(_fq09u_manifest)
	var _fq09u_meta_ok := _fq09u_streams.size() == 4
	for _fq09u_ctx in _fq09u_streams:
		var _fq09u_s: AudioStream = _fq09u_streams[_fq09u_ctx]
		if not (_fq09u_s.loop and is_equal_approx(_fq09u_s.bpm, 72.0)
				and _fq09u_s.bar_beats == 4 and _fq09u_s.beat_count == 64):
			_fq09u_meta_ok = false
	harness._check("fq09u1_manifest_and_streams",
		int(_fq09u_manifest.get("bpm", 0)) == 72 and _fq09u_meta_ok,
		"streams=%d bpm=%s" % [_fq09u_streams.size(), str(_fq09u_manifest.get("bpm"))])

	# (b) the director is live: Music bus exists, the context player plays an
	# interactive stream with the four named clips.
	var _fq09u_stream: AudioStream = _fq09u_dir.get_node("ContextPlayer").stream
	harness._check("fq09u1_director_live",
		_fq09u_dir.enabled()
		and AudioServer.get_bus_index("Music") != -1
		and _fq09u_dir.get_node("ContextPlayer").playing
		and _fq09u_dir.get_node("ContextPlayer").bus == "Music"
		and _fq09u_stream is AudioStreamInteractive
		and (_fq09u_stream as AudioStreamInteractive).clip_count == 4,
		"enabled=%s playing=%s" % [str(_fq09u_dir.enabled()),
			str(_fq09u_dir.get_node("ContextPlayer").playing)])

	# (c) context resolution: night, dawn, and underground each request the
	# right clip from a clean baseline.
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir.evaluate(_fq09u_night, 1.0)
	var _fq09u_night_req: String = _fq09u_dir.requested_context()
	_fq09u_dir.debug_reset("surface_night")
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	var _fq09u_dawn_req: String = _fq09u_dir.requested_context()
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir.evaluate(_fq09u_under, 1.0)
	var _fq09u_under_req: String = _fq09u_dir.requested_context()
	harness._check("fq09u1_context_resolution",
		_fq09u_night_req == "surface_night" and _fq09u_dawn_req == "surface_day"
		and _fq09u_under_req == "underground",
		"night=%s dawn=%s underground=%s" % [_fq09u_night_req, _fq09u_dawn_req, _fq09u_under_req])

	# (d) crisis hysteresis: a brief spike never enters; sustained pressure
	# does (0.60 for 2 s, data-defined).
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	var _fq09u_brief_crisis: bool = _fq09u_dir.in_crisis()
	_fq09u_dir.evaluate(_fq09u_day, 0.5)   # spike over: accumulator resets
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	_fq09u_dir.evaluate(_fq09u_high, 0.5)
	harness._check("fq09u1_crisis_enter_hysteresis",
		not _fq09u_brief_crisis and _fq09u_dir.in_crisis()
		and _fq09u_dir.requested_context() == "crisis"
		and _fq09u_dir.pressure_value() > 0.9,
		"brief=%s sustained=%s pressure=%.2f" % [str(_fq09u_brief_crisis),
			str(_fq09u_dir.in_crisis()), _fq09u_dir.pressure_value()])

	# (e) crisis exits only after the exit threshold AND delay (0.35 / 6 s).
	_fq09u_dir._current = "crisis"
	_fq09u_dir._pending = ""
	_fq09u_dir.evaluate(_fq09u_day, 3.0)
	var _fq09u_still: bool = _fq09u_dir.in_crisis()
	_fq09u_dir.evaluate(_fq09u_day, 3.5)
	harness._check("fq09u1_crisis_exit_delay",
		_fq09u_still and not _fq09u_dir.in_crisis()
		and _fq09u_dir.requested_context() == "surface_day",
		"at3s=%s at6.5s=%s requested=%s" % [str(_fq09u_still),
			str(_fq09u_dir.in_crisis()), _fq09u_dir.requested_context()])

	# (f) identical state never re-requests the current or pending clip.
	_fq09u_dir.debug_reset("surface_day")
	var _fq09u_reqs: int = _fq09u_dir.switch_request_count()
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	harness._check("fq09u1_no_rerequest",
		_fq09u_dir.switch_request_count() == _fq09u_reqs,
		"requests %d -> %d" % [_fq09u_reqs, _fq09u_dir.switch_request_count()])

	# (g) LIVE spike proof: the interactive playback really reaches the
	# requested clip via the registered next-bar same-position transition
	# (one bar = 3.33 s at 72 BPM). This is a REAL-TIME transition driven by the
	# audio playback position, so a cold/slow host (Linux CI) can need well over
	# the old fixed 8 s / 480-frame budget for the position to cross the next bar.
	# Poll on a wall-clock deadline (not a frame count, which under-counts real
	# time when rendering is slow) and re-arm once before failing. A warm run
	# still lands in ~4 s and exits the loop immediately.
	var _fq09u_target: int = _fq09u_dir.clip_index_of("underground")
	var _fq09u_reached := false
	for _fq09u_attempt in range(2):
		_fq09u_dir.debug_reset("surface_day")
		_fq09u_dir.evaluate(_fq09u_under, 1.0)
		var _fq09u_deadline: int = Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < _fq09u_deadline:
			_fq09u_dir._settle_pending()
			if _fq09u_dir.playback_clip_index() == _fq09u_target \
					and _fq09u_dir.current_context() == "underground":
				_fq09u_reached = true
				break
			await get_tree().process_frame
		if _fq09u_reached:
			break
	harness._check("fq09u1_live_clip_switch", _fq09u_reached,
		"reached=%s clip=%d target=%d" % [str(_fq09u_reached),
			_fq09u_dir.playback_clip_index(), _fq09u_target])

	# (h) missing assets are silent-safe: a director with a manifest pointing
	# at nonexistent files disables audio, still evaluates, never crashes.
	var _fq09u_scene: PackedScene = load("res://scenes/audio/AdaptiveMusicDirector.tscn")
	var _fq09u_bad: Node = _fq09u_scene.instantiate()
	_fq09u_bad.manifest_override = {
		"bpm": 72, "beats_per_bar": 4, "bars_per_loop": 16,
		"contexts": {
			"surface_day": {"stream": "res://audio/music/rendered/contexts/missing_a.ogg"},
			"surface_night": {"stream": "res://audio/music/rendered/contexts/missing_b.ogg"},
			"underground": {"stream": "res://audio/music/rendered/contexts/missing_c.ogg"},
			"crisis": {"stream": "res://audio/music/rendered/contexts/missing_d.ogg"},
		},
		"transition": {}, "thresholds": {}, "pressure": {},
	}
	add_child(_fq09u_bad)
	_fq09u_bad.evaluate(_fq09u_night, 1.0)
	_fq09u_bad._settle_pending()
	harness._check("fq09u1_missing_assets_silent_safe",
		not _fq09u_bad.enabled()
		and not _fq09u_bad.get_node("ContextPlayer").playing
		and _fq09u_bad.requested_context() == "surface_night",
		"enabled=%s playing=%s state=%s" % [str(_fq09u_bad.enabled()),
			str(_fq09u_bad.get_node("ContextPlayer").playing),
			_fq09u_bad.requested_context()])
	_fq09u_bad.queue_free()
	await get_tree().process_frame

	# (i) music state is transient: a save round-trip carries no music keys
	# and the director keeps playing across the load untouched.
	root.save_manager.save_game()
	var _fq09u_state: Dictionary = GameState.get_current_state()
	var _fq09u_music_keys := ""
	for _fq09u_k in _fq09u_state:
		if "music" in str(_fq09u_k).to_lower():
			_fq09u_music_keys += str(_fq09u_k) + " "
	harness._check("fq09u1_state_not_saved",
		_fq09u_music_keys == "" and root.load_game() and _fq09u_dir.enabled(),
		("music keys: " + _fq09u_music_keys) if _fq09u_music_keys != ""
		else "no music keys in the world save; director survives load")

	# --- FQ-09U2: settlement-responsive stem layering ---
	# (the director's _process is still disabled from the fq09u1 section, so
	# every state/volume assertion below is deterministic)

	# (a) the mandated nesting spike, recorded: can an AudioStreamSynchronized
	# serve as a clip inside an AudioStreamInteractive? Built from two tiny
	# generated WAV tones and played live; the finding (either way) is
	# captured in the check detail and the run ledger — U2's shipped design
	# uses the parallel LayerPlayer regardless, since the suite has ONE
	# shared stem set, not per-context sets.
	var _fq09u2_wav := AudioStreamWAV.new()
	_fq09u2_wav.format = AudioStreamWAV.FORMAT_16_BITS
	_fq09u2_wav.mix_rate = 22050
	var _fq09u2_pcm := PackedByteArray()
	_fq09u2_pcm.resize(22050)   # 0.5s of quiet buzz
	for _fq09u2_i in range(0, 22050, 2):
		var _fq09u2_v: int = 800 if (_fq09u2_i / 50) % 2 == 0 else -800
		_fq09u2_pcm.encode_s16(_fq09u2_i, _fq09u2_v)
	_fq09u2_wav.data = _fq09u2_pcm
	var _fq09u2_nested_sync := AudioStreamSynchronized.new()
	_fq09u2_nested_sync.stream_count = 2
	_fq09u2_nested_sync.set_sync_stream(0, _fq09u2_wav)
	_fq09u2_nested_sync.set_sync_stream(1, _fq09u2_wav)
	var _fq09u2_nested := AudioStreamInteractive.new()
	_fq09u2_nested.clip_count = 2
	_fq09u2_nested.set_clip_name(0, "a")
	_fq09u2_nested.set_clip_stream(0, _fq09u2_nested_sync)
	_fq09u2_nested.set_clip_name(1, "b")
	_fq09u2_nested.set_clip_stream(1, _fq09u2_nested_sync)
	var _fq09u2_probe := AudioStreamPlayer.new()
	_fq09u2_probe.stream = _fq09u2_nested
	_fq09u2_probe.volume_db = -60.0
	add_child(_fq09u2_probe)
	_fq09u2_probe.play()
	await get_tree().process_frame
	await get_tree().process_frame
	var _fq09u2_nests: bool = _fq09u2_probe.playing \
		and _fq09u2_probe.get_stream_playback() != null
	_fq09u2_probe.queue_free()
	await get_tree().process_frame
	harness._check("fq09u2_nesting_spike_recorded", true,
		"synchronized_inside_interactive_plays=%s (finding recorded; U2 ships the parallel LayerPlayer design either way)" % str(_fq09u2_nests))

	# (b) the stem bed is live: six loops loaded, every length matching the
	# manifest grid, playing on the Music bus alongside the context stream.
	var _fq09u2_expected: float = _fq09u_mm.loop_seconds(_fq09u_manifest)
	var _fq09u2_stems: Dictionary = _fq09u_mm.load_stem_streams(_fq09u_manifest)
	var _fq09u2_lengths_ok := _fq09u2_stems.size() == 6
	for _fq09u2_sn in _fq09u2_stems:
		if absf((_fq09u2_stems[_fq09u2_sn] as AudioStream).get_length() - _fq09u2_expected) > 0.05:
			_fq09u2_lengths_ok = false
	harness._check("fq09u2_stem_bed_live",
		_fq09u2_lengths_ok and _fq09u_dir.layering_enabled()
		and _fq09u_dir.get_node("LayerPlayer").playing
		and _fq09u_dir.get_node("LayerPlayer").bus == "Music"
		and (_fq09u_dir.get_node("LayerPlayer").stream is AudioStreamSynchronized),
		"stems=%d lengths_ok=%s layering=%s playing=%s" % [_fq09u2_stems.size(),
			str(_fq09u2_lengths_ok), str(_fq09u_dir.layering_enabled()),
			str(_fq09u_dir.get_node("LayerPlayer").playing)])

	# (c) targets follow settlement truth: coherence drives the hearth layer,
	# resilience steadies the foundation (deterministic evaluate calls).
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir._settlement_coherence = 90.0
	_fq09u_dir._settlement_resilience = 80.0
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	var _fq09u2_hearth_high: float = float(_fq09u_dir.stem_targets()["hearth"])
	var _fq09u2_found_high: float = float(_fq09u_dir.stem_targets()["foundation"])
	_fq09u_dir._settlement_coherence = 10.0
	_fq09u_dir._settlement_resilience = 10.0
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	harness._check("fq09u2_targets_follow_settlement",
		_fq09u2_hearth_high > float(_fq09u_dir.stem_targets()["hearth"]) + 6.0
		and _fq09u2_found_high > float(_fq09u_dir.stem_targets()["foundation"]) + 3.0,
		"hearth %.1f -> %.1f, foundation %.1f -> %.1f" % [_fq09u2_hearth_high,
			float(_fq09u_dir.stem_targets()["hearth"]), _fq09u2_found_high,
			float(_fq09u_dir.stem_targets()["foundation"])])

	# (d) pressure raises its layer and the fracture layer wakes only at the
	# collapse edge.
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir.evaluate(_fq09u_day, 1.0)
	var _fq09u2_pressure_low: float = float(_fq09u_dir.stem_targets()["pressure"])
	var _fq09u2_fracture_low: float = float(_fq09u_dir.stem_targets()["fracture"])
	_fq09u_dir.evaluate(_fq09u_high, 1.0)
	harness._check("fq09u2_pressure_and_fracture_layers",
		float(_fq09u_dir.stem_targets()["pressure"]) > _fq09u2_pressure_low + 10.0
		and float(_fq09u_dir.stem_targets()["fracture"]) > _fq09u2_fracture_low + 10.0
		and _fq09u2_fracture_low <= -59.0,
		"pressure %.1f -> %.1f, fracture %.1f -> %.1f" % [_fq09u2_pressure_low,
			float(_fq09u_dir.stem_targets()["pressure"]), _fq09u2_fracture_low,
			float(_fq09u_dir.stem_targets()["fracture"])])

	# (e) the storm texture: a storm lifts the pressure stem to at least its
	# data-defined floor even at low pressure.
	_fq09u_dir.debug_reset("surface_day")
	var _fq09u2_storm := {"is_night": false, "storm": true, "threat": 0.0,
		"health_ratio": 1.0, "underground": false}
	_fq09u_dir.evaluate(_fq09u2_storm, 1.0)
	harness._check("fq09u2_storm_texture",
		float(_fq09u_dir.stem_targets()["pressure"]) >= -16.0,
		"pressure target %.1f (floor -16)" % float(_fq09u_dir.stem_targets()["pressure"]))

	# (f) volumes move smoothly toward targets — one 0.5 s step moves at most
	# rate*dt dB and never snaps to the target.
	_fq09u_dir.debug_reset("surface_day")
	_fq09u_dir._settlement_coherence = 100.0
	_fq09u_dir._stem_volumes["hearth"] = -40.0
	_fq09u_dir.evaluate(_fq09u_day, 0.5)
	_fq09u_dir._step_stem_volumes(0.5)
	var _fq09u2_after_step: float = float(_fq09u_dir.stem_volumes()["hearth"])
	harness._check("fq09u2_volume_smoothing",
		is_equal_approx(_fq09u2_after_step, -37.0)
		and _fq09u2_after_step < float(_fq09u_dir.stem_targets()["hearth"]),
		"hearth -40.0 -> %.2f (target %.1f, rate 6 dB/s * 0.5 s)" % [
			_fq09u2_after_step, float(_fq09u_dir.stem_targets()["hearth"])])

	# (g) a length-mismatched stem set disables layering while context music
	# plays on (a stinger is deliberately the wrong length).
	var _fq09u2_bad_manifest: Dictionary = _fq09u_manifest.duplicate(true)
	_fq09u2_bad_manifest["stems"]["motion"] = "res://audio/music/rendered/stingers/stinger_dawn.ogg"
	var _fq09u2_bad: Node = _fq09u_scene.instantiate()
	_fq09u2_bad.manifest_override = _fq09u2_bad_manifest
	add_child(_fq09u2_bad)
	harness._check("fq09u2_length_mismatch_fail_safe",
		_fq09u2_bad.enabled() and not _fq09u2_bad.layering_enabled()
		and not _fq09u2_bad.get_node("LayerPlayer").playing,
		"context=%s layering=%s" % [str(_fq09u2_bad.enabled()),
			str(_fq09u2_bad.layering_enabled())])
	_fq09u2_bad.queue_free()
	await get_tree().process_frame

	# (h) layering state is transient too: save round-trip carries no stem
	# keys and the live layer bed survives the load untouched.
	root.save_manager.save_game()
	var _fq09u2_state: Dictionary = GameState.get_current_state()
	var _fq09u2_keys := ""
	for _fq09u2_k in _fq09u2_state:
		if "stem" in str(_fq09u2_k).to_lower() or "music" in str(_fq09u2_k).to_lower():
			_fq09u2_keys += str(_fq09u2_k) + " "
	harness._check("fq09u2_state_not_saved",
		_fq09u2_keys == "" and root.load_game()
		and _fq09u_dir.layering_enabled()
		and _fq09u_dir.get_node("LayerPlayer").playing,
		("keys: " + _fq09u2_keys) if _fq09u2_keys != ""
		else "no stem/music keys; layer bed survives load")

	# --- FQ-09U3: stingers, ducking, and audio settings ---
	# (director _process still disabled: duck/cooldown envelopes are stepped
	# directly via _tick_audio(dt) for deterministic assertions)

	# (a) all five stinger one-shots load, none loops, every one under 8 s;
	# pause behavior configured (the score survives any future pause).
	var _fq09u3_stingers: Dictionary = _fq09u_mm.load_stinger_streams(_fq09u_manifest)
	var _fq09u3_assets_ok := _fq09u3_stingers.size() == 5
	for _fq09u3_k in _fq09u3_stingers:
		var _fq09u3_s: AudioStream = _fq09u3_stingers[_fq09u3_k]
		if _fq09u3_s.loop or _fq09u3_s.get_length() >= 8.0 or _fq09u3_s.get_length() <= 0.1:
			_fq09u3_assets_ok = false
	harness._check("fq09u3_stinger_assets",
		_fq09u3_assets_ok and _fq09u_dir.stinger_kinds_loaded() == 5
		and _fq09u_dir.process_mode == Node.PROCESS_MODE_ALWAYS
		and _fq09u_dir.get_node("StingerPlayer").bus == "SFX",
		"loaded=%d director=%d always=%s" % [_fq09u3_stingers.size(),
			_fq09u_dir.stinger_kinds_loaded(),
			str(_fq09u_dir.process_mode == Node.PROCESS_MODE_ALWAYS)])

	# (b) a stinger plays over ducking while the music NEVER stops: the duck
	# attacks toward duck_db while the one-shot plays, and the context and
	# layer players keep playing throughout. (Real gameplay events earlier in
	# the run may have fired stingers — settle cooldowns and the duck first.)
	_fq09u_dir.get_node("StingerPlayer").stop()
	_fq09u_dir._stinger_cooldowns.clear()
	_fq09u_dir._tick_audio(2.0)
	var _fq09u3_fired: bool = _fq09u_dir.play_stinger("dawn")
	_fq09u_dir._tick_audio(0.1)
	var _fq09u3_duck_attacking: float = _fq09u_dir.duck_db()
	harness._check("fq09u3_stinger_ducks_music",
		_fq09u3_fired and _fq09u_dir.stinger_playing()
		and _fq09u3_duck_attacking < -3.0
		and _fq09u_dir.get_node("ContextPlayer").playing
		and _fq09u_dir.get_node("LayerPlayer").playing,
		"fired=%s duck=%.1f context_playing=%s" % [str(_fq09u3_fired),
			_fq09u3_duck_attacking, str(_fq09u_dir.get_node("ContextPlayer").playing)])

	# (c) the duck releases back to zero once the stinger ends (release rate
	# 12 dB/s, data-defined), and Music-bus volume returns to the user base.
	_fq09u_dir.get_node("StingerPlayer").stop()
	_fq09u_dir._tick_audio(0.5)
	var _fq09u3_mid_release: float = _fq09u_dir.duck_db()
	_fq09u_dir._tick_audio(2.0)
	harness._check("fq09u3_duck_releases",
		_fq09u3_mid_release > _fq09u3_duck_attacking
		and is_equal_approx(_fq09u_dir.duck_db(), 0.0)
		and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
			- linear_to_db(1.0)) < 0.01,
		"attack=%.1f mid=%.1f final=%.2f" % [_fq09u3_duck_attacking,
			_fq09u3_mid_release, _fq09u_dir.duck_db()])

	# (d) per-kind cooldown: an immediate repeat is refused, another kind is
	# not, and after the cooldown elapses the kind fires again.
	var _fq09u3_plays: int = _fq09u_dir.stinger_play_count()
	var _fq09u3_repeat: bool = _fq09u_dir.play_stinger("dawn")
	var _fq09u3_other: bool = _fq09u_dir.play_stinger("raid_warning")
	_fq09u_dir._tick_audio(9.0)
	var _fq09u3_after_cd: bool = _fq09u_dir.play_stinger("dawn")
	harness._check("fq09u3_stinger_cooldown",
		not _fq09u3_repeat and _fq09u3_other and _fq09u3_after_cd
		and _fq09u_dir.stinger_play_count() == _fq09u3_plays + 2,
		"repeat=%s other=%s after_cd=%s" % [str(_fq09u3_repeat),
			str(_fq09u3_other), str(_fq09u3_after_cd)])
	_fq09u_dir.get_node("StingerPlayer").stop()
	_fq09u_dir._tick_audio(2.0)

	# (e) game events reach the director: the narrow music_event surface and
	# the player's cast signal each fire their stinger.
	_fq09u_dir._stinger_cooldowns.clear()
	var _fq09u3_p0: int = _fq09u_dir.stinger_play_count()
	root.music_event.emit("nightfall")
	player.attunement = player.max_attunement()
	player._pulse_cooldown = 0.0
	player._try_attune_pulse()
	harness._check("fq09u3_events_fire_stingers",
		_fq09u_dir.stinger_play_count() == _fq09u3_p0 + 2,
		"plays %d -> %d (nightfall + attunement)" % [_fq09u3_p0,
			_fq09u_dir.stinger_play_count()])
	_fq09u_dir.get_node("StingerPlayer").stop()
	_fq09u_dir._tick_audio(2.0)

	# (f) volume settings: profile-level, applied to the buses through the
	# shared helper, restored afterwards.
	var _fq09u3_as: GDScript = load("res://scripts/audio/audio_settings.gd")
	var _fq09u3_prev_music: float = _fq09u3_as.music_volume(GameState.profile)
	var _fq09u3_prev_sfx: float = _fq09u3_as.sfx_volume(GameState.profile)
	_fq09u3_as.set_music_volume(GameState.profile, 0.5)
	_fq09u3_as.set_sfx_volume(GameState.profile, 0.25)
	_fq09u3_as.apply(GameState.profile)
	var _fq09u3_music_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var _fq09u3_sfx_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	var _fq09u3_vol_ok: bool = absf(_fq09u3_music_db - linear_to_db(0.5)) < 0.01 \
		and absf(_fq09u3_sfx_db - linear_to_db(0.25)) < 0.01 \
		and is_equal_approx(float(GameState.profile.get("music_volume", -1.0)), 0.5)
	_fq09u3_as.set_music_volume(GameState.profile, _fq09u3_prev_music)
	_fq09u3_as.set_sfx_volume(GameState.profile, _fq09u3_prev_sfx)
	_fq09u3_as.apply(GameState.profile)
	harness._check("fq09u3_volume_settings",
		_fq09u3_vol_ok,
		"music_db=%.2f sfx_db=%.2f profile_key=%s" % [_fq09u3_music_db,
			_fq09u3_sfx_db, str(GameState.profile.has("music_volume"))])

	# (g) audio settings live at the profile level only — the WORLD save
	# still carries zero audio keys.
	root.save_manager.save_game()
	var _fq09u3_state: Dictionary = GameState.get_current_state()
	var _fq09u3_keys := ""
	for _fq09u3_sk in _fq09u3_state:
		var _fq09u3_low := str(_fq09u3_sk).to_lower()
		if "music" in _fq09u3_low or "volume" in _fq09u3_low or "stinger" in _fq09u3_low:
			_fq09u3_keys += str(_fq09u3_sk) + " "
	harness._check("fq09u3_world_save_clean",
		_fq09u3_keys == "" and root.load_game(),
		("keys: " + _fq09u3_keys) if _fq09u3_keys != "" else "no audio keys in the world save")
	_fq09u_dir.set_process(true)
