# Run Ledger: 20260715_coheronia_fq20_command_center_chrome

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code FQ-20 implementation + verification run |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-20 — HUD command center, direct manipulation, painted chrome (merged per operator) |
| Started At | 2026-07-15T12:20:00-04:00 |
| Ended At | 2026-07-15T16:10:00-04:00 |

## User Request

Merge the command-center/direct-manipulation pass and the painted-chrome pass
into one FQ-20 and proceed. End goal (recorded in operator direction): drag
and drop anything in the player UI, stretch any component, the dock as the
absolute command center for open/closed, recycle the beautiful rendered
assets from the blueprint mockup, better borders on the mini-map and all UI.

## What Shipped

- **`scripts/art/slice_hud_chrome.py`** (new, deterministic): slices thirteen
  painted chrome assets out of the operator's blueprint mockup (copied into
  `art/source_templates/`): plain + ornate module frames (edge-strip rebuild
  with mirrored clean strips kills the baked text), corner medallion, chip
  frame, riveted dock plate, slot frames, four nav glyph buttons, and both
  orb rings — background removed geometrically (a color flood eats the dark
  iron), annotation ink inpainted, glass punched from liquid-blob-measured
  geometry.
- **`ui_painted` asset lane**: manifest category + convention, audit
  `UI_PAINTED_CONSUMED` statuses, dedicated light verifier pass (free-size
  RGBA, <=320px, non-empty; exempt from the 32x32/16-color pixel contract).
- **hud.gd consumption with full fallback chains** (painted -> FQ-19 generated
  -> code-drawn): dock plate, blueprint-proportioned slots (56px) and glyph
  buttons (40px), painted orbs with `PAINTED_ORB_GEOMETRY` glass mapping,
  ornate crest + corner medallion, plain goal/events frames, chip-framed
  contextual entries, and an ornate NinePatch border on the mini-map.
- **Command center**: module toggles (Crest/Goal/Events/Map/Edit) moved into
  the dock as chip buttons; the corner toolbar retired; two-way state sync.
- **Direct manipulation**: drag any widget immediately in edit mode (locks
  removed), continuous corner-grip resize (0.5x–2.0x), full-screen edit
  overlay with gold outlines/grips, layout schema v3.

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| Isolated waited Godot smoke | PASS 318/318 | lineage 316 -> 318 (fq17 evolved to direct manipulation; +fq20_painted_chrome_consumed, +fq20_dock_command_center) |
| `scripts/asset_audit.py --strict` | PASS | clean; thirteen ui_painted ids LIVE |
| `scripts/art/verify_pixel_assets.py` | PASS 208 PNGs | painted lane via the light pass |
| `scripts/validate_repo.py` | PASS | exit 0 |
| Capsule doctor, `public_repo` | PASS | `Result: healthy` |
| `git diff --check` | PASS | line-ending notices only |
| Rendered tour 1280x720 | PASS | crest/events/dock regions cropped and reviewed; ornate-margin and medallion-clip polish applied from the review |
| Slice iteration | 4 debug rounds | flood-kill of dark iron caught; strip-mirror fix for baked header text; attunement glass center from blob extents (a crystal is not a part-filled liquid) |
| Independent review agent | DONE | 0 must-fix. 1 should-fix applied: button-up now always settles an in-flight drag/resize even over exempt zones (state-leak). Notes: orb fill overflow covered by ring art (verified in tour); geometry-provenance comment added to PAINTED_ORB_GEOMETRY; toggle-chip signal loop and resize degeneracy independently confirmed safe. |

## Concurrent-Lane Boundary

During this run a separate Codex session generated files OUTSIDE its wiki
scope: `art/generated/opening/opening_0*.png` cels and three
`art/generated/player_gear/*_crude_human.png` overlays (14:33–15:32), plus
the wiki dirs and docs exports. Those pass the repo gates but are NOT part of
FQ-20: this run commits explicit FQ-20 paths only and leaves all concurrent
work uncommitted for its own review. Flagged to the operator.

## Deliberately Deferred

- Diablo-1-style drag-drop inventory (FQ-22 candidate; consumes the reserved
  cursor + invalid-slot art).
- Painted chrome for the modal panels (town hall / inventory / character /
  skills) — module frames only in this pass.
- `button_goals`/`button_settings` remain unconsumed reserved ids.

## Git Closeout

Implementation commit + evidence commit + push per the standing pattern,
staging explicit FQ-20 paths only (concurrent Codex work excluded). Hashes
recorded in the packets.

## Remaining Risks / Next Action

`fq09u1_live_clip_switch` remains timing-flaky on cold isolated profiles
(one flake this run, clean re-run) — worth a hardening pass in its own lane.
Operator visual approval of the painted chrome in motion is the acceptance
that matters; captures shipped with the closeout report.

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260715_coheronia_fq20_command_center_chrome.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260715_coheronia_fq20_command_center_chrome.json`
