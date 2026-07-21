# Run Ledger: 20260721_coheronia_pr06_character_hud

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code PR-06 implementation + verification run |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | PR-06 - Character HUD rebuild on runtime children (code lane) |
| Start Commit | 2cbe6af |
| End Commit | 420411a |
| Started At | 2026-07-21T07:35:00-04:00 |
| Ended At | 2026-07-21T07:55:00-04:00 |

## User Request

Continue the Presentation Recovery arc. Start PR-06: rebuild the Character
HUD/panel on runtime UI children using the existing native HUD chrome; reuse
the PR-02/PR-05 shared PlayerVisual render path for the figure; show live
identity/status/equipment from runtime state, not baked text or duplicated
rendering. Code lane only - no image production, no chrome replacement, no new
PNGs. Close with validator, Capsule Doctor, wiki links, git diff --check, a
waited Godot smoke, and screenshot evidence at relevant viewport sizes.

## What Shipped

- **Runtime-children rebuild** (`hud.gd`): `_build_character_panel` now holds a
  persistent `_character_body` inside the existing native `ornate` chrome
  (`_module_content_host`); `_refresh_character_panel` clears it
  (`_clear_children`) and repopulates on every open, so nothing is baked. The
  old `_character_info` static summary label is removed.
- **Composed figure through the shared path**: `_make_character_figure` builds a
  framed, magnified `PlayerVisual` and drives it with `apply_preview_character`
  (PR-05) on a dict assembled from live `player` state - species, body_variant,
  visual_variant, appearance, and `equipped_dict()` - so the panel figure shows
  the live worn gear and cannot drift from the in-world character. No rendering
  is reimplemented.
- **Live identity + status**: name/species/body/look/appearance/role/traits and
  health/attunement/attack/carried, all read from runtime.
- **All 13 equipment slots** from `_equipment_board_slots()` shown with the live
  equipped item display name (empty slots as an em dash), reusing
  `_equipment_tooltip` for hover detail.
- **Accessor** `character_figure_snapshot()` exposes the figure's
  rendering-contract snapshot for the smoke.
- Presentation only: no equipment/gameplay/save change; no image production; no
  HUD chrome replacement (art lane stays PR-10).

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| Waited-GUI Godot 4.6.1 smoke | PASS 343/343 | `pr06_character_panel_runtime_render`: open=true fig=true slots=true(miss=[]) live=true no_baked=true (figure draws live worn gear via the shared path; all 13 slots render; identity/status live; re-equip+reopen updates figure/names/status) |
| `scripts/validate_repo.py` | PASS | exit 0; new "character HUD panel rebuilt on runtime children via the render path" check (shared-path reuse pinned; forbids resurrecting `_character_info`) |
| `capsule_doctor.py . --profile public_repo` | PASS | Result: healthy |
| `scripts/wiki/check_links.py` | PASS | 5366 local links across 367 files |
| `git diff --check` | PASS | clean |
| HUD-QA screenshots | PASS | `08_character_panel` (1280x720) + `09_character_panel_wide` (1600x900): composed figure with gear, live identity/status, all 13 slots; both viewport sizes reviewed |

## Deliberately Deferred

- HUD chrome / new panel PNGs remain art-lane (PR-10), not touched here.
- `docs/VARIABLE_MATRIX.html` was hand-synced for the two changed rows only (the
  PR-06 row + the runtime-verification row); the broad wiki regen drift stays
  out of scope, so the rest of the wiki HTML remains a step behind until a
  dedicated regen pass.

## Git Closeout

Implementation commit `420411a` (10 files: hud.gd, smoke_test, hud_visual_qa,
validate_repo, + HANDOFF/matrix/queue/VARIABLE_MATRIX(.md+.html)/contract docs).
Evidence-only commit follows. Not pushed (operator controls push separately).

## Remaining Risks / Next Action

Next code-lane row is **PR-07** (backdrop seam/contour skirt in
`world_backdrop.gd`). `fq09u1_live_clip_switch` cold-profile flakiness in the
music lane persists (passed this run).

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260721_coheronia_pr06_character_hud.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260721_coheronia_pr06_character_hud.json`
