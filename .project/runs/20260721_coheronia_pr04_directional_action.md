# Run Ledger: 20260721_coheronia_pr04_directional_action

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code PR-04 closeout (verification + commit) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | PR-04 - directional action animation (code half) |
| Start Commit | 429ae9a |
| End Commit | e925051 |
| Started At | 2026-07-21T06:55:00-04:00 |
| Ended At | 2026-07-21T07:10:00-04:00 |

## User Request

Continue the Presentation Recovery arc. PR-04 (directional action
animation) was implemented but left uncommitted in the working tree at
session resume; verify the suite still passes on the current tree and
close it out per the standard evidence + commit pattern.

## What Shipped

- **Data-driven swing cycle**: the uniform 3-pose loop (which only read
  rightward) is replaced by a **windup -> impact -> recovery** cycle aimed
  at the target vector. Items own an `action_profile`
  (windup/impact/recovery fractions, arc, direction mode) in
  `data/equipment.json`; `BlockRegistry.action_profile` merges a default so
  every item resolves a profile.
- **Aim-following draw** in `player_visual.gd`: `swing_direction()`
  (mirror-aware, so up/down/diagonal targets read directionally),
  `swing_progress()`, `swing_phase_kind()`, and `_draw_action_swing()` draw
  the pick/axe swing PNGs rotated toward the aim.
- **Sword path**: no authored sword frames exist, so a presentation-only
  `attack_swing` timer on `player.gd` (set when a melee hit lands, never
  touching damage or timing) drives the same contract.
- **Snapshot**: `presentation_snapshot()` gains `action_kind`,
  `action_item`, `swing_phase_kind`, `swing_direction`.
- Mining/combat mechanics and frame baselines are unchanged; no image
  production. Remaining swing *art* (smoother authored arcs, real sword
  frames) stays in the image matrix (PR-10 lane).

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| Waited-GUI Godot 4.6.1 smoke | PASS 341/341 | fresh `smoke_results.json` (result=PASS, failed=0); lineage 338 (PR-03B) -> 341 (+pr04_swing_direction_follows_target, +pr04_action_profile_phases, +pr04_sword_uses_action_contract) |
| `scripts/validate_repo.py` | PASS | exit 0; includes "action animation profiles" |
| `capsule_doctor.py . --profile public_repo` | PASS | Result: healthy |
| `git diff --check` | PASS | clean (only LF->CRLF advisories) |

## Deliberately Deferred

- Authored smoother swing arcs and real sword frames -> image matrix (PR-10).
- The non-human crude torso waist placement (loincloth read) stays an art
  lane note from PR-03B, unchanged here.

## Git Closeout

Implementation commit `e925051` (15 files: equipment.json, block_registry,
player, player_visual, smoke_test, validate_repo, plus HANDOFF / queue /
matrix / VARIABLE_MATRIX / README / known_issues docs). Evidence-only commit
follows. Not pushed (awaiting operator go-ahead).

## Remaining Risks / Next Action

Next code-lane row is **PR-05** (menu and character-selection preview through
the shared render path). `fq09u1_live_clip_switch` cold-profile flakiness in
the music lane persists (passed this run).

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260721_coheronia_pr04_directional_action.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260721_coheronia_pr04_directional_action.json`
