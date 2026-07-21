# Run Ledger: 20260721_coheronia_pr08_skill_panel_resize

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code PR-08 implementation + verification run |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | PR-08 - skill panel resize (code lane) |
| Start Commit | 707d047 |
| End Commit | 195fffd |
| Started At | 2026-07-21T08:30:00-04:00 |
| Ended At | 2026-07-21T09:05:00-04:00 |

## User Request

Continue the Presentation Recovery arc. Start PR-08: make the Skills panel
responsive and usable. Resize/restructure `skill_tree_panel.gd` so it fits
cleanly at 640x360 and 1280x720, using viewport-relative sizing/margins and
keeping the graph usable as it grows. Preserve the star-map, purchase flow,
persistence, and inspector behaviour. No new perks/lanes/mechanics/art/PNGs.

## What Shipped

- **Viewport-relative sizing**: `_apply_layout` sizes the panel to
  `panel_size_for(viewport)` -- a `VIEWPORT_FRACTION` (0.9) clamped to
  `MIN_PANEL` (480x300) / `MAX_PANEL` (1100x660), then bounded to the viewport
  minus `VIEWPORT_MARGIN` -- and re-centres it on every
  `get_viewport().size_changed`. `panel_size_for` is a pure function so the
  smoke can pin it at the target sizes.
- **Graph fills the room**: the graph `ScrollContainer` and the inspector label
  now `EXPAND_FILL` (widths no longer pinned to 500, a `MIN_GRAPH_HEIGHT` floor);
  the star-map takes the extra space and stays usable as lanes grow, with the
  ScrollContainer still panning the larger canvas.
- Stretch mode is `canvas_items`+`expand`, so the logical viewport is ~1280x720
  and a same-aspect 640x360 window renders the layout scaled to fit; both target
  sizes are verified to fit with a margin.
- No perk data, node layout (`NODE_SIZE`/`SPACING`), purchase path, persistence,
  or inspector text format changed -- presentation only.

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| Waited-GUI Godot 4.6.1 smoke | PASS 345/345 | `pr08_skill_panel_viewport_relative`: s360=(576,324) fits 640x360, s720=(1100,648) fits 1280x720, roomier than 540x420, live panel adopts the computed size; `fq06_panel_opens_and_inspects` + `fq09s_constellation_links_match_prereqs` green |
| Recovery loop 1 (parse) | FIXED | first smoke never wrote results (stale file) -- a `:=` inferred `var _pr08_panel := hud.skill_panel()` in the smoke could not infer the untyped return, a compile error that cascaded (game_root/world) and aborted the run; changed to `=`. Diagnosed via a headless run capturing stderr (`Parse Error at smoke_test.gd:2579`). |
| Recovery loop 2 (flake) | ISOLATED | with the parse fixed, `fq19_map_events_coexist` failed consistently (context-stack `offset_top` = 3877, off-screen). It is unrelated to the skill panel; clearing the persisted `shell.json` (contaminated by this run's killed/hung Godot instances and QA window resizes -- a corrupt HUD layout `reset_hud_layout()` cannot fully neutralise) made the suite 345/345. Recorded as a `fq19` robustness note; not a PR-08 regression. |
| `scripts/validate_repo.py` | PASS | exit 0; new "skill panel is viewport-relative" check (pins `panel_size_for`/`_apply_layout`/`size_changed`/`VIEWPORT_FRACTION`, forbids the old 540x420 / 500x180) |
| `capsule_doctor.py . --profile public_repo` | PASS | Result: healthy |
| `scripts/wiki/check_links.py` | PASS | 5366 local links across 367 files |
| `git diff --check` | PASS | clean |
| HUD-QA screenshots | PASS | `10_skill_panel` (1280x720, roomy star-map filling the panel) + `11_skill_panel_small` (640x360, same layout scaled to fit with margins) reviewed |

## Deliberately Deferred

- PR-09 (later skill expansion) stays deferred/planning-only; PR-10 (HUD chrome)
  is an art lane. Node/graph scaling (NODE_SIZE/SPACING) intentionally unchanged
  so the star-map layout is byte-identical; the ScrollContainer handles growth.

## Git Closeout

Implementation commit `195fffd` (9 files: skill_tree_panel, smoke_test,
hud_visual_qa, validate_repo, + HANDOFF/matrix/queue/VARIABLE_MATRIX(.md+.html)).
Evidence-only commit follows. Not pushed (operator controls push separately).

## Follow-up (2026-07-21, after this ledger)

The PR-08 push was held for operator review; during the hold the operator
reported that the **character-create screen** was unusable -- the PR-05 live
preview plus the many creation selectors made the form taller than the viewport,
so its bottom clipped and the Create/Back buttons were unreachable. Fixed in
`shell_ui.gd` `_show_char_create` (wrap the form in a `ScrollContainer`, keep the
Create/Back action row pinned outside it; PR-05 preview preserved) -- fix commit
`ccd3f2a`, with a dedicated ledger
`.project/runs/20260721_coheronia_pr08b_char_create_scroll.md`. Re-verified: the
full waited-GUI smoke is now **346/346** (adds
`pr08_char_create_form_scrolls_actions_pinned`), from a clean shell profile;
validator + Capsule Doctor + wiki links green. So the accepted verification
count for the PR-08 line is **346/346** as of `ccd3f2a`, superseding the
345/345 recorded above at `195fffd`.

## Remaining Risks / Next Action

**The presentation recovery arc's code lane (PR-00..PR-08) is complete.**
Remaining rows are non-code: PR-09 deferred, PR-10 art lane. Next work is an
operator-chosen arc/queue item or the big-ticket playability backlog.
`fq09u1_live_clip_switch` cold-flakiness and the `fq19` persisted-`shell.json`
sensitivity both persist (both pass from a clean profile).

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260721_coheronia_pr08_skill_panel_resize.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260721_coheronia_pr08_skill_panel_resize.json`
