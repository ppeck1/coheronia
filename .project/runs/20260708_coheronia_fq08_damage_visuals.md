# Run Ledger: 20260708_coheronia_fq08_damage_visuals

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + sonnet review agent (recon skipped: all target surfaces already in-session) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-08 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-07T23:40:00-04:00 |
| Ended At | 2026-07-08T07:05:00-04:00 |

## User Request

"prcoeed" [proceed] — continue the queue with the same agent pipeline:
FQ-08, block and enemy damage visuals.

## Agent Protocol Notes

Recon skipped (player mining state, player._draw, simple_threat._draw, and
the smoke boundaries were all read verbatim earlier in the session); the
sonnet review agent ran as the correction loop. Review found no must-fix and
no should-fix — three nits, all applied (reused member RNG so _draw never
heap-allocates; crack endpoints clamped inside the tile; smoke comment
clarified that both reset paths — genuine target switch and the
can_mine/reach guard — are valid). Full verification re-ran green.

## Scope (design decisions, now documented)

1. Block damage stages: player.mine_damage_stage() maps mining progress to
   stages 0 (untouched) through 3 (about to break) and drives a crack
   overlay drawn on the target cell in player._draw — deterministic per cell
   (member RNG re-seeded from hash(mine_target) each frame, so cracks never
   flicker), stage x 3 short lines clamped inside the tile, layered over the
   existing highlight + progress bar, visible only while the mine action is
   held.
2. Transience guarantee: the overlay is pure runtime state — it never enters
   cells/deltas/saves; it resets through the existing _reset_mining on
   target change, reach/can_mine failure, and mouse release; and
   save_manager.apply_state now calls player._reset_mining() so in-memory
   partial progress can never survive a load. world.gd is untouched — no
   per-block damage storage, no save growth.
3. Enemy hurt feedback: a mini health bar (dark backing + red fill from the
   new health_bar_ratio()) appears above any enemy with hp < max_hp, on both
   the FQ-07 art path and the drawn-rect fallback; the existing tint/lighten
   cues remain. simple_threat._draw's art early-return became if/else so the
   bar draws once in both paths.
4. Non-goals honored: drops, mining frame counts, and save/load semantics
   unchanged; hud.gd needed no changes (its mining progress bar already
   exists).

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | all checks green |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 179/179 (was 173), zero failures; fresh results file verified by LastWriteTime |
| `git diff --check` | PASS | exit 0 |

New smoke checks (6): fq08_stone_found, fq08_block_damage_stages (stage 0 ->
2 at 60% of required mining time), fq08_stage_resets (retarget and
_reset_mining both zero the stage), fq08_damage_never_saved (50% partial
damage, save + load: block still stone, stage 0), fq08_drops_unchanged
(finishing the mine yields exactly one stone), fq08_enemy_hurt_visible
(hurt-bar ratio 1.00 -> 0.67 after a non-lethal hit, enemy alive, zero
inventory delta — drops roll only on death).

## Review Findings And Resolutions

- No must-fix, no should-fix.
- NIT (fixed): per-frame RandomNumberGenerator allocation in _draw —
  replaced with a reused member RNG re-seeded per frame (identical output).
- NIT (fixed): crack line endpoints could overshoot the tile by up to 5px —
  clamped to the tile rect.
- NIT (fixed): the reset smoke check's comment now names both legitimate
  reset paths so a future reader does not assume only the target-switch
  branch is exercised.
- Review confirmations: hash(Vector2i) is stable within a run (deterministic
  cracks); stage math has no off-by-one (ratio 1.0 clamps to stage 3); the
  _draw restructure is behaviorally neutral for the art path; no caller
  depends on mining continuity across a load; frame-count baselines
  untouched.

## Acceptance vs FQ-08

- A stone block visibly changes before breaking (crack overlay stages 1-3;
  fq08_block_damage_stages).
- Enemy damage is visible before death (hurt bar + existing tint;
  fq08_enemy_hurt_visible at 2/3 hp).
- Mining/combat visuals do not alter drop counts or save/load behavior
  (fq08_drops_unchanged exact single drop; fq08_damage_never_saved; legacy
  frame baselines dirt 21 / wood 33 / stone 66 still green in the same run).
- Visual damage resets when the player changes target or stops mining
  (fq08_stage_resets), and additionally on load.
- Block damage is transient by design — zero bytes added to saves.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260708_coheronia_fq08_damage_visuals.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260708_coheronia_fq08_damage_visuals.json`

## Git Closeout

Implementation commit `f3d8997` (code, docs), then this evidence-only
commit; both pushed to origin/main.

## Remaining Risks

- Crack look (line count, alpha, clamping) is programmer art; FQ-07's asset
  pipeline can later supply real crack overlay sprites per stage if wanted.
- Enemy hurt bars draw at a fixed 16px width — oversized future enemy art
  would want a wider bar (same raw-size caveat as the FQ-07 template).
- Feedback feel (stage thresholds at 25/50/75%) untested by human play.

## Next Action

FQ-09 (visual inventory, toolbelt, and village panels) is next in the queue.
