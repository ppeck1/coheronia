# Run Ledger: 20260721_coheronia_pr07_backdrop_skirt

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code PR-07 implementation + verification run |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | PR-07 - backdrop seam/contour skirt (code lane) |
| Start Commit | fdd59a7 |
| End Commit | 951b5c1 |
| Started At | 2026-07-21T08:00:00-04:00 |
| Ended At | 2026-07-21T08:25:00-04:00 |

## User Request

Continue the Presentation Recovery arc. Start PR-07: diagnose and fix the
visible gap between the dynamic backdrop and the variable terrain by adding a
structural contour/skirt layer behind the foreground terrain -- not by cropping
or replacing backdrop art. Code lane only: no image production, no new or edited
PNGs.

## Diagnosis

`world_backdrop.gd` anchors its distant scenery (sky art + far/mid terrain
strips) to the flat AVERAGE surface line (`_horizon_py`). Backing walls (z=-2)
fill each column from `surface[x]+1` down, so the backdrop is only visible in the
open sky above the per-column surface. Where the real terrain top sits below the
mean (valleys), the distant band floats on a flat line and sky/void shows in the
gap down to the terrain -- the seam. The under-earth fill only reached the
DEEPEST valley line, so nothing followed the actual per-column contour.

## What Shipped

- **World-space contour skirt** (`_draw_contour_skirt`): following
  `world.surface` per column, a mid-ground foothill (`MID_COL`) fills from the
  distant horizon down to the ACTUAL surface (so the far terrain descends into
  valleys to meet the ground), and under-earth (`UNDER_COL`) backs everything
  below the surface contour (so no void shows behind terrain at any camera
  height). Drawn in the backdrop node behind the walls/blocks; cosmetic fills
  only.
- **`contour_top_px(col)`**: the pure, side-effect-free per-column top in world
  pixels (`surface[col] * tile`), clamped off-world so edges never void; smoke
  pins it.
- **Deferred-safe anchoring** (`_recompute_metrics` from `_ready` and
  `_process`): the world generates its surface either before or after the
  backdrop's `_ready` depending on setup order. Previously, when `_ready` ran
  first (the smoke's Main flow), the horizon anchor silently fell back to the
  480px default and the skirt drew nothing. Now `_world` is captured
  unconditionally and metrics anchor as soon as the surface exists.
- No PNG touched; the skirt is world-locked (no parallax, never swims) while the
  distant strips keep their parallax. `light_mask = 0`, z-behind-walls, no-save
  and no-collision are unchanged.

## Verification and Recovery Loops

| Check | Result | Evidence |
|---|---|---|
| Waited-GUI Godot 4.6.1 smoke | PASS 344/344 | `pr07_backdrop_contour_skirt_follows_surface`: follows=true clamped=true inert=true peak=400.0 valley=528.0 (skirt top == per-column surface; peak higher on screen than valley; off-world clamps to the edge; light_mask==0 + z-behind-walls) |
| Recovery loop | FIXED | first smoke run FAILED (peak==valley==480 default) -- the backdrop's `_ready` ran before the world generated its surface, so the anchor never captured the world; fixed with deferred-safe `_recompute_metrics` + unconditional `_world` capture, then 344/344 |
| `scripts/validate_repo.py` | PASS | exit 0; new "backdrop contour skirt follows the per-column surface" check (pins the skirt + `light_mask = 0`) |
| `capsule_doctor.py . --profile public_repo` | PASS | Result: healthy |
| `scripts/wiki/check_links.py` | PASS | 5366 local links across 367 files |
| `git diff --check` | PASS | clean |
| HUD-QA world captures | PASS | resource/map shots (`01_resources_100`, `05_map_open`): the backdrop now follows the terrain contour; the flat floating distant band is gone. NOTE: the first capture pass was taken before the deferred-metrics fix, when the skirt was silently skipped -- re-captured after the fix to review the real result. |

## Deliberately Deferred

- Final native-scale visual judgment is the operator's; the code-lane structural
  fix is complete and smoke-verified. HUD chrome / backdrop art remain PR-10.

## Git Closeout

Implementation commit `951b5c1` (8 files: world_backdrop, smoke_test,
validate_repo, + HANDOFF/matrix/queue/VARIABLE_MATRIX(.md+.html)). Evidence-only
commit follows. Not pushed (operator controls push separately).

## Remaining Risks / Next Action

Next code-lane row is **PR-08** (skill panel resize in `skill_tree_panel.gd`).
`fq09u1_live_clip_switch` cold-profile flakiness in the music lane persists
(passed this run).

## Project Atlas Sync

State: queued - `.project/atlas_outbox/20260721_coheronia_pr07_backdrop_skirt.json`

## BOH Sync

State: queued - `.project/boh_outbox/20260721_coheronia_pr07_backdrop_skirt.json`
