# Run Ledger: 20260721_coheronia_pr05_shared_preview

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code PR-05 implementation + verification run |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | PR-05 - menu/character-select preview through the shared render path |
| Start Commit | f745352 |
| End Commit | d6e1127 |
| Started At | 2026-07-21T07:12:00-04:00 |
| Ended At | 2026-07-21T07:30:00-04:00 |

## User Request

Continue the Presentation Recovery arc. After PR-04 shipped, start PR-05:
render the composed live character in the creation/selection UI through the
shared `player_visual.gd` path (reuse, do not reimplement) so what you pick
equals what you get; prove preview == in-world with a snapshot-compare smoke.

## What Shipped

- **Parent-independent entry point** `player_visual.gd`
  `apply_preview_character(character)`: derives body/trim colour from
  `appearance` exactly like `Player.apply_character`, fills `_preview_gear`
  from the character's own equipment slots (normalized like the live
  `equipped_dict()`, filtered to the new `DRAWN_GEAR_SLOTS` const), and funnels
  into `set_character_visual()` + the shared `_draw`. With no live `Player`
  parent, `refresh_facing()` early-returns (the preview magnify scale is never
  overwritten), `visible_gear_ids()` returns `_preview_gear`, and every
  swing/action snapshot field resolves to its idle value, so
  `presentation_snapshot()` is null-safe.
- **shell_ui.gd previews** `_make_character_preview`/`_apply_preview`: the
  creation form shows a live 6x figure refreshed on every figure-affecting
  selector (species, body, look, appearance); each character-select row shows
  the stored character at 3x with its equipped gear.
- **Contract** gained a **Preview Consumers** section documenting the reuse.
- Presentation only: no equipment/gameplay/save change; no image production.

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| Waited-GUI Godot 4.6.1 smoke | PASS 342/342 | fresh `smoke_results.json`; `pr05_preview_matches_world_render`: parentless=true meaningful=true diffs=[] (parentless preview snapshot == world snapshot for dwarf/feminine/ash + 4 gear slots) |
| `scripts/validate_repo.py` | PASS | exit 0; new "character creation/select preview reuses the render path" + contract Preview Consumers check |
| `capsule_doctor.py . --profile public_repo` | PASS | Result: healthy |
| `git diff --check` | PASS | clean |
| `07_character_create` shot | PASS | live composed human/masculine/tan figure atop the create form, matching the selectors; reviewed at 1280x720 |

## Deliberately Deferred

- **Pre-existing wiki drift**: regenerating `docs/wiki` via
  `scripts/wiki/generate_wiki.py` surfaced ~180 stale files (bumped `Generated:`
  dates, nav-card links missing from older pages, a new `authority_sigil` page)
  unrelated to PR-05. Left for a dedicated wiki-regen pass; **not** folded into
  this row. Consequence: `docs/VARIABLE_MATRIX.html` lags its `.md` by the PR-05
  row until that pass runs.
- Authored smoother swing/sword frames and HUD chrome remain art-lane (PR-10).

## Git Closeout

Implementation commit `d6e1127` (9 files: player_visual, shell_ui, smoke_test,
validate_repo, + HANDOFF/matrix/queue/VARIABLE_MATRIX/contract docs). Evidence-
only commit follows.

## Remaining Risks / Next Action

Next code-lane row is **PR-06** (Character HUD rebuild on runtime children
against the PR-02 contract + existing native chrome). `fq09u1_live_clip_switch`
cold-profile flakiness in the music lane persists (passed this run).

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260721_coheronia_pr05_shared_preview.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260721_coheronia_pr05_shared_preview.json`
