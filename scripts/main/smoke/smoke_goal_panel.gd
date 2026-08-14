extends Node
## S-07.3 smoke domain module - FQ-14 state-driven goal panel.
## Order-preserving extraction; harness owns _check() (via harness.*).


func run(ctx) -> void:
	# S-07.3 ctx seam (work order §11): unpack the handles this cluster uses.
	var harness = ctx.harness
	var root = ctx.root
	var hud = ctx.hud
	# --- FQ-14: state-driven goal panel ---
	var _g14_script = preload("res://scripts/main/goal_tracker.gd")
	var _g14 = _g14_script.new()
	var _g14_start: String = str(_g14.current()["id"])
	_g14.note({"gather": true})
	var _g14_after_gather: String = str(_g14.current()["id"])
	_g14.note({"light": true})
	_g14.note({"deposit": true})
	_g14.note({"craft": true})
	var _g14_before_survive: String = str(_g14.current()["id"])
	_g14.note({"survive": true})
	var _g14_after_survive: String = str(_g14.current()["id"])   # M5-B: onboarding continues
	_g14.note({"house": true})
	_g14.note({"defend": true})
	harness._check("fq14_goals_advance_in_order",
		_g14_start == "gather" and _g14_after_gather == "light"
		and _g14_before_survive == "survive" and _g14_after_survive == "house"
		and _g14.all_done() and bool(_g14.current()["all_done"]),
		"start=%s after_gather=%s before_survive=%s after_survive=%s done=%s" % [
			_g14_start, _g14_after_gather, _g14_before_survive, _g14_after_survive,
			str(_g14.all_done())])

	# prefix-latch: a later objective latches earlier ones; a transient clear of
	# an earlier condition never regresses the panel.
	var _g14b = _g14_script.new()
	_g14b.note({"deposit": true})
	var _g14b_after: String = str(_g14b.current()["id"])
	_g14b.note({"gather": false, "light": false, "deposit": false})
	harness._check("fq14_goals_prefix_latch",
		_g14b.is_done("gather") and _g14b.is_done("light") and _g14b.is_done("deposit")
		and _g14b_after == "craft" and str(_g14b.current()["id"]) == "craft",
		"after=%s still_craft=%s" % [_g14b_after, str(str(_g14b.current()["id"]) == "craft")])

	# game_root derives the objectives from real state and drives the HUD panel;
	# the panel is built, populated, and unobtrusive (ignores mouse input).
	var _g14_snap: Dictionary = root._goal_snapshot()
	root._refresh_goals()
	harness._check("fq14_goal_panel_wired",
		_g14_snap.has("gather") and _g14_snap.has("light") and _g14_snap.has("deposit")
		and _g14_snap.has("craft") and _g14_snap.has("survive")
		and hud._goal_label != null and hud._goal_label.text != ""
		and hud._goal_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"keys=%d text=%s" % [_g14_snap.size(), hud._goal_label.text])

	# survive derives from real state (day_count); the panel hides/shows.
	var _g14_saved_day: int = root.day_count
	root.day_count = 2
	var _g14_survive: bool = bool(root._goal_snapshot().get("survive", false))
	root.day_count = _g14_saved_day
	hud._goal_visible = true
	hud._goal_panel.visible = true
	var _g14_shown: bool = hud.goal_panel_visible()
	hud._goal_visible = false
	hud._goal_panel.visible = false
	var _g14_hidden: bool = hud.goal_panel_visible()
	hud._goal_panel.visible = true
	harness._check("fq14_goal_survive_and_toggle",
		_g14_survive and _g14_shown and not _g14_hidden,
		"survive_day2=%s shown=%s hidden=%s" % [
			str(_g14_survive), str(_g14_shown), str(_g14_hidden)])

	# S-07 onboarding-truth contract: the shipped goal model is exactly the seven
	# ordered objectives, the live snapshot covers all seven, the panel total is 7
	# (not the retired 5), and the craft objective routes to the unified crafting
	# panel (C) — never the retired "Town Hall to forge" instruction. Guards the
	# README / PLAYTEST_CHECKLIST reconciliation against silent drift.
	var _s07_goal_ids: Array = []
	for _s07_goal in _g14_script.GOALS:
		_s07_goal_ids.append(str(_s07_goal["id"]))
	var _s07_expected_ids: Array = ["gather", "light", "deposit", "craft",
		"survive", "house", "defend"]
	var _s07_craft_hint := ""
	for _s07_craft_goal in _g14_script.GOALS:
		if str(_s07_craft_goal["id"]) == "craft":
			_s07_craft_hint = str(_s07_craft_goal["hint"])
	var _s07_snap: Dictionary = root._goal_snapshot()
	var _s07_snap_covers := true
	for _s07_id in _s07_expected_ids:
		if not _s07_snap.has(_s07_id):
			_s07_snap_covers = false
	var _s07_craft_route_ok: bool = _s07_craft_hint.contains("(C)") \
		and not _s07_craft_hint.contains("Town Hall")
	harness._check("s07_goal_contract",
		_s07_goal_ids == _s07_expected_ids
		and int(_g14_script.new().current().get("total", 0)) == 7
		and _s07_snap_covers and _s07_craft_route_ok,
		"ids=%s total=%d snap_covers=%s craft_hint=%s" % [
			str(_s07_goal_ids),
			int(_g14_script.new().current().get("total", 0)),
			str(_s07_snap_covers), _s07_craft_hint])
