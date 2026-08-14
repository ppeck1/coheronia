extends Node
## S-07.3 smoke domain module - persistence & export integrity
## (R-01 export-safe resources, R-02 save integrity, R-03 isolated verification).
## Order-preserving extraction from smoke_test.gd _run(): the harness owns the
## assertion API + ledger (_check/_suite_for/_start_ms/_suites); this module holds
## only the R-01/R-02/R-03 section bodies, run in place by the coordinator. The
## trailing progression/Calling restore stays in the coordinator (it reads
## _cal_prev_role/_fq06_saved_* declared in earlier sections).


func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): this cluster uses only the harness helpers.
	var harness = ctx.harness
	# --- R-01: export-safe runtime resources ---
	# Every authored art category and every music stream must load through the
	# runtime loaders (BlockRegistry / MusicManifest), which are now import-aware
	# (ResourceLoader) so they resolve from a packed/exported build, not just a
	# plain editor run. These go through the REAL runtime loaders (not direct
	# ResourceLoader), so the packed --main-pack smoke exercises the same path.
	BlockRegistry.clear_visual_cache()
	var _r01_vis := {
		"body": BlockRegistry.visual_texture("players", "human"),
		"gear": BlockRegistry.visual_texture("player_gear", "helmet_crude_human"),
		"block": BlockRegistry.visual_texture("blocks", "dirt"),
		"item": BlockRegistry.visual_texture("items", "antlers"),
		"ui": BlockRegistry.visual_texture("ui", "button_character"),
		"hud_painted": BlockRegistry.visual_texture("ui_painted", "attunement_frame"),
		"backdrop": BlockRegistry.visual_texture("backgrounds", "surface_sky"),
	}
	var _r01_missing: Array[String] = []
	for _r01_k in _r01_vis:
		if _r01_vis[_r01_k] == null:
			_r01_missing.append(str(_r01_k))
	# prologue cels resolve through the variant-pool convention loader
	var _r01_prologue: Array = BlockRegistry.visual_variant_textures(
		"opening", "opening_01_first_star")
	# recoloring still works: the import must decompress to a manipulable image
	# (a VRAM-compressed import would make get_image()/get_pixel unusable).
	var _r01_body: Texture2D = _r01_vis["body"]
	var _r01_recolor_ok := false
	if _r01_body != null:
		var _r01_img := _r01_body.get_image()
		# a non-empty image proves the import decompresses to a usable form for
		# get_pixel-based recoloring; player_visual_appearance_palette_applies
		# exercises the actual recolor.
		_r01_recolor_ok = _r01_img != null and not _r01_img.is_empty()
	harness._check("r01_export_safe_visual_resources",
		_r01_missing.is_empty() and _r01_prologue.size() > 0 and _r01_recolor_ok,
		"missing=%s prologue_cels=%d recolor_ok=%s" % [str(_r01_missing),
			_r01_prologue.size(), str(_r01_recolor_ok)])

	# Audio: all 4 context loops, 6 stems, 5 stingers load import-aware, the grid
	# is stamped, and the streams are DUPLICATES so the shared cached import
	# resource is never mutated.
	var _r01_manifest: Dictionary = MusicManifest.load_manifest()
	var _r01_ctx: Dictionary = MusicManifest.load_context_streams(_r01_manifest)
	var _r01_stems: Dictionary = MusicManifest.load_stem_streams(_r01_manifest)
	var _r01_stingers: Dictionary = MusicManifest.load_stinger_streams(_r01_manifest)
	var _r01_ctx_stream: AudioStream = _r01_ctx.get("surface_day")
	var _r01_grid_ok: bool = _r01_ctx_stream != null and _r01_ctx_stream.loop \
		and _r01_ctx_stream.bpm > 0.0
	# the shared cached import resource keeps its import default (loop=false),
	# proving load_context_streams duplicated before stamping.
	var _r01_shared = ResourceLoader.load(
		"res://audio/music/rendered/contexts/coheronia_surface_day.ogg", "AudioStream")
	var _r01_no_mutate: bool = _r01_shared != null and not _r01_shared.loop
	harness._check("r01_export_safe_audio_resources",
		_r01_ctx.size() == 4 and _r01_stems.size() == 6 and _r01_stingers.size() == 5
		and _r01_grid_ok and _r01_no_mutate,
		"contexts=%d stems=%d stingers=%d grid=%s cache_unmutated=%s" % [
			_r01_ctx.size(), _r01_stems.size(), _r01_stingers.size(),
			str(_r01_grid_ok), str(_r01_no_mutate)])

	# --- R-02: save integrity — atomic write / validate / .bak / quarantine ---
	# The write+recover mechanism (shared by shell and world saves) is exercised
	# on an isolated scratch path so the primitive is proven without touching the
	# real profile.
	var _r02_p := "user://r02_scratch.json"
	for _r02_sfx in ["", ".bak", ".corrupt", ".tmp"]:
		if FileAccess.file_exists(_r02_p + _r02_sfx):
			DirAccess.remove_absolute(_r02_p + _r02_sfx)
	# atomic write v1, then v2 -> the prior good file is preserved as .bak.
	var _r02_w1: bool = GameState._atomic_write_json(_r02_p, {"v": 1})
	var _r02_w2: bool = GameState._atomic_write_json(_r02_p, {"v": 2})
	var _r02_live = GameState._json_object_or_null(_r02_p)
	var _r02_bak = GameState._json_object_or_null(_r02_p + ".bak")
	var _r02_backup_ok: bool = _r02_w1 and _r02_w2 \
		and _r02_live is Dictionary and int(_r02_live.get("v", -1)) == 2 \
		and _r02_bak is Dictionary and int(_r02_bak.get("v", -1)) == 1
	# corrupt the live file -> recover reads v1 from .bak and quarantines primary.
	var _r02_cf := FileAccess.open(_r02_p, FileAccess.WRITE)
	if _r02_cf != null:
		_r02_cf.store_string("{ not valid json ,,,")
		_r02_cf.close()
	var _r02_rec: Dictionary = GameState._load_json_recover(_r02_p)
	var _r02_recover_ok: bool = str(_r02_rec.get("status")) == "recovered" \
		and int((_r02_rec.get("data") as Dictionary).get("v", -1)) == 1 \
		and FileAccess.file_exists(_r02_p + ".corrupt")
	# corrupt again with NO backup -> quarantined + empty + surfaced, never silent.
	for _r02_sfx3 in [".bak", ".corrupt"]:
		if FileAccess.file_exists(_r02_p + _r02_sfx3):
			DirAccess.remove_absolute(_r02_p + _r02_sfx3)
	var _r02_cf2 := FileAccess.open(_r02_p, FileAccess.WRITE)
	if _r02_cf2 != null:
		_r02_cf2.store_string("still not json")
		_r02_cf2.close()
	var _r02_rec2: Dictionary = GameState._load_json_recover(_r02_p)
	var _r02_quarantine_ok: bool = str(_r02_rec2.get("status")) == "quarantined" \
		and (_r02_rec2.get("data") as Dictionary).is_empty() \
		and FileAccess.file_exists(_r02_p + ".corrupt")
	# a write whose temp cannot be created fails cleanly (false) and leaves no live
	# file -- this is what makes create_world observable.
	var _r02_write_fail: bool = not GameState._atomic_write_json(
		"user://r02_missing_dir/deep/x.json", {"v": 0})
	for _r02_sfx4 in ["", ".bak", ".corrupt", ".tmp"]:
		if FileAccess.file_exists(_r02_p + _r02_sfx4):
			DirAccess.remove_absolute(_r02_p + _r02_sfx4)
	harness._check("r02_atomic_write_backup_recover_quarantine",
		_r02_backup_ok and _r02_recover_ok and _r02_quarantine_ok and _r02_write_fail,
		"backup=%s recover=%s quarantine=%s write_fail=%s" % [str(_r02_backup_ok),
			str(_r02_recover_ok), str(_r02_quarantine_ok), str(_r02_write_fail)])

	# --- R-02: shell + world integration (recovery surfaced, schema, creation) ---
	# A corrupt profile must never read as a fresh empty one; a future schema is
	# surfaced without destroying data; failed world creation is observable.
	var _r02_saved_profile: Dictionary = GameState.profile.duplicate(true)
	var _r02_saved_chars: Array = GameState.characters.duplicate(true)
	# healthy shell + a good .bak (two saves), then truncate the live file.
	GameState.save_shell()
	GameState.save_shell()
	var _r02_scf := FileAccess.open(GameState.shell_path(), FileAccess.WRITE)
	if _r02_scf != null:
		_r02_scf.store_string("{ truncated shell")
		_r02_scf.close()
	GameState.load_shell()
	var _r02_shell_recovered: bool = GameState.shell_load_status == "recovered" \
		and GameState.characters.size() == _r02_saved_chars.size() \
		and FileAccess.file_exists(GameState.shell_path() + ".corrupt")
	# unsupported (future) schema is surfaced, data preserved (never destroyed).
	GameState._atomic_write_json(GameState.shell_path(), {
		"shell_version": "99.0", "profile": _r02_saved_profile,
		"characters": _r02_saved_chars})
	GameState.load_shell()
	var _r02_schema_surfaced: bool = GameState.shell_load_status == "unsupported_schema" \
		and GameState.characters.size() == _r02_saved_chars.size()
	# world file: create (observable success), give it a good .bak, corrupt it,
	# then recover from the backup with a surfaced status.
	var _r02_wid: String = GameState.create_world(WorldConfig.from_preset("folk_kingdom"))
	var _r02_create_ok: bool = _r02_wid != ""
	if _r02_create_ok:
		GameState._atomic_write_json(GameState.world_path(_r02_wid),
			GameState.load_world_file(_r02_wid))
		var _r02_wcf := FileAccess.open(GameState.world_path(_r02_wid), FileAccess.WRITE)
		if _r02_wcf != null:
			_r02_wcf.store_string("{ truncated world")
			_r02_wcf.close()
	var _r02_wdata: Dictionary = GameState.load_world_file(_r02_wid) if _r02_create_ok else {}
	var _r02_world_recovered: bool = _r02_create_ok \
		and GameState.world_load_status == "recovered" and not _r02_wdata.is_empty()
	if _r02_create_ok:
		GameState.delete_world(_r02_wid)
		for _r02_wsfx in [".bak", ".corrupt", ".tmp"]:
			if FileAccess.file_exists(GameState.world_path(_r02_wid) + _r02_wsfx):
				DirAccess.remove_absolute(GameState.world_path(_r02_wid) + _r02_wsfx)
	# restore the real shell state + a clean healthy shell.json (status -> ok).
	GameState.profile = _r02_saved_profile
	GameState.characters = _r02_saved_chars
	GameState.save_shell()
	GameState.load_shell()
	for _r02_ssfx in [".bak", ".corrupt", ".tmp"]:
		if FileAccess.file_exists(GameState.shell_path() + _r02_ssfx):
			DirAccess.remove_absolute(GameState.shell_path() + _r02_ssfx)
	harness._check("r02_shell_world_integrity",
		_r02_shell_recovered and _r02_schema_surfaced and _r02_create_ok
		and _r02_world_recovered,
		"shell_recovered=%s schema=%s create=%s world_recovered=%s" % [
			str(_r02_shell_recovered), str(_r02_schema_surfaced),
			str(_r02_create_ok), str(_r02_world_recovered)])

	# --- R-03: isolated verification (injected persistence root + split reporting) ---
	# This run must be isolated from the real profile: the persistence root is the
	# dedicated smoke root, not "user://", so nothing here can read or write the
	# player's shell/worlds. The root is re-pointable, and results split by suite.
	var _r03_root: String = GameState.persistence_root
	var _r03_isolated: bool = _r03_root != GameState.DEFAULT_PERSISTENCE_ROOT \
		and GameState.shell_path().begins_with(_r03_root) \
		and GameState.shell_path() != "user://shell.json"
	# set_persistence_root re-points shell + worlds cleanly, then restore.
	var _r03_probe := "user://r03_probe_root/"
	GameState.set_persistence_root(_r03_probe)
	var _r03_reroute: bool = GameState.shell_path() == _r03_probe.path_join("shell.json") \
		and GameState.worlds_dir() == _r03_probe.path_join("worlds")
	GameState.set_persistence_root(_r03_root)
	if DirAccess.dir_exists_absolute(_r03_probe):
		DirAccess.remove_absolute(_r03_probe.path_join("worlds"))
		DirAccess.remove_absolute(_r03_probe)
	# split reporting: names categorize into the expected suites and timing is live.
	var _r03_reporting: bool = harness._suite_for("shell_persists_characters") == "shell" \
		and harness._suite_for("r02_atomic_write_backup_recover_quarantine") == "save" \
		and harness._suite_for("fq09u1_live_clip_switch") == "audio" \
		and harness._suite_for("pr06_character_panel_runtime_render") == "ui" \
		and harness._suite_for("player_visual_all_ten_bodies_resolve") == "presentation" \
		and harness._suite_for("fq06_perks_persist") == "progression" \
		and harness._start_ms > 0 and harness._suites.size() >= 5
	harness._check("r03_isolated_verification",
		_r03_isolated and _r03_reroute and _r03_reporting,
		"root=%s isolated=%s reroute=%s reporting=%s suites=%s" % [_r03_root,
			str(_r03_isolated), str(_r03_reroute), str(_r03_reporting),
			str(harness._suites.keys())])
