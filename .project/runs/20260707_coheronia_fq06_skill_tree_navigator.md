# Run Ledger: 20260707_coheronia_fq06_skill_tree_navigator

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + Explore recon agent + sonnet review agent |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-06 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-07T13:20:00-04:00 |
| Ended At | 2026-07-07T14:05:00-04:00 |

## User Request

"proceed" — continue the queue with the same agent pipeline: FQ-06, visual
player skill tree navigator.

## Agent Protocol Notes

Same pipeline: Explore recon mapped perks.json (7 planning lanes with no
consumers), progression_registry, the progression save surface, HUD panel
patterns, the Esc chain, and free keybindings; the orchestrator implemented
and drove the Windows verification loop; a sonnet review agent hunted defects
on the diff. Two real defects were caught by the verification loop itself
before review: (1) the new panel script used class_name, which plain
(non-editor) runs never register — the smoke silently ran the OLD build and
returned a stale results file; caught by the freshness check, fixed by
switching to the repo's preload pattern; (2) apply_progression_state's perk
re-apply clamped attunement against a stale pre-gear max during load,
breaking the FQ-05 surplus invariant (169-suite caught it at 168/169) — fixed
by restoring attunement after progression in apply_state. Review then found
no must-fix; two should-fix and two nits were applied.

## Scope (design decisions, now documented)

1. Node schema: every perk in data/progression/perks.json (7 lanes x 3) now
   carries id, display_name (title), description, effect_key, effect_value,
   cost, position [x, y], prerequisites (same-lane ids), xp_type_gate —
   validator-enforced (unique ids, cost >= 1, [x,y] positions, same-lane
   prereqs, 7 lanes). schema_version 0.5 -> 0.6 with a documented point_rule.
2. Perk economy: one perk point per player level above 1
   (perk_points_total = player_level - 1, floored availability); spent points
   derive from purchased costs. purchased_perks is world-owned progression
   state (like XP/levels per the v0.6 ownership decision); unknown ids are
   dropped on load (silent refund on data renames).
3. Live lane: Miner. stone_recovery (root, cost 1, mining_speed x1.15) is
   fully live through player.perk_mine_speed_mult in effective_mine_speed;
   deep_sense and tunnel_safety are prerequisite-gated branches whose
   planning effect keys (detect_ore_range, cave_safety) stay inert until
   their systems ship. All other lanes: data-complete, planned.
4. Effect application: game_root._apply_purchased_perk_effects recomputes a
   combined dict (mining_speed multiplies, attunement_bonus adds) and pushes
   it via player.apply_perk_effects. The attunement_bonus path makes the
   FQ-05 perk join point live code inside max_attunement() — adding a
   magic perk is now data-only.
5. UI: scripts/ui/skill_tree_panel.gd (preloaded, no class_name — plain runs
   never depend on the editor's global class cache). Scrollable node canvas
   laid out from data grid positions; state-colored buttons ([OWNED]/[LOCKED]
   markers, purchased/available/locked from game_root.perk_state); inspector
   with title/state/cost/effect/prerequisite names/description; learn button
   backed by real points; planned lanes listed. Toggled with K
   (toggle_skills), mutually exclusive with inventory/town panels, first in
   the Esc close chain.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. the new perk node schema block (safe int-cost parsing, list guards) |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 169/169 (was 163), zero failures; fresh results file verified by LastWriteTime |
| `git diff --check` | PASS | exit 0 |

New smoke checks (6): fq06_perks_json_loads (7 lanes, lane injection, miner
prereq shape), fq06_states_and_zero_points (level 1: root available, child
locked, purchase refused at 0 points), fq06_purchase_applies_effect (level 3:
buy succeeds, 1 point left, effective_mine_speed x1.15 exactly),
fq06_prereqs_and_cost_gate (children unlock; 2-cost node unaffordable at 1
point; re-purchase refused), fq06_perks_persist (world-save round-trip
restores purchases, level, and the live effect), fq06_panel_opens_and_inspects
(open/close, node selection, PURCHASED/AVAILABLE states, prerequisite names
and description in the inspector). The toggle_skills binding joined
input_actions_bound.

## Review Findings And Resolutions

- Caught pre-review by the verification loop: class_name cache gotcha (stale
  smoke run detected by the results-file freshness check) and the
  attunement-clamp load-ordering regression (suite 168/169) — both fixed and
  documented above.
- SHOULD-FIX (fixed): validator crashed with a raw ValueError on non-numeric
  perk cost — now routed through fail() with try/except.
- SHOULD-FIX (fixed): panel indexed position[0]/[1] unchecked — a
  short/empty position array now falls back to [0, 0].
- NIT (fixed): perk_points_available floored at 0 so hand-edited overspent
  saves display 0 rather than a negative count.
- NIT (fixed): apply_progression_state no longer clears purchased_perks
  before its registry null-guard — a null registry leaves purchases
  untouched instead of wiping them into the next save.
- NIT (accepted, documented): smoke (e) injects player_level directly, so
  its saved xp_totals do not correspond to level 3 — a test scaffold
  property; the section restores and saves the pre-test progression so all
  later sections see a converged world.

## Acceptance vs FQ-06

- Player can open the skill tree (K; fq06_panel_opens_and_inspects covers
  open and close; Esc chain closes it first).
- A node can be selected and inspected (inspector shows title, state, cost,
  effect key x value, prerequisite display names, description).
- One perk can be purchased from real player XP-derived levels
  (fq06_purchase_applies_effect: level 3 -> 2 points -> stone_recovery
  bought, mining measurably faster).
- State persists and smoke verifies the core path (fq06_perks_persist:
  purchases + level + live effect survive the world-save round-trip).
- Locked, available, and purchased states all render and gate correctly;
  only one lane implemented per queue scope.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260707_coheronia_fq06_skill_tree_navigator.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260707_coheronia_fq06_skill_tree_navigator.json`

## Git Closeout

Implementation commit `ff3a0ea` (code, data, docs), then this evidence-only
commit; both pushed to origin/main.

## Remaining Risks

- Only mining_speed is a live effect; the other 20 nodes are data-complete
  but inert until their systems ship. No refund/respec exists.
- Perk point pacing (1 per level on the 100 x 1.35^n curve) is untested by
  human play; a level-100 cap on the recalc loop bounds total points.
- The panel is scrollable but has no pan/zoom or drawn prerequisite edges;
  FQ-09's visual panel pass is the natural upgrade point.
- Godot gotcha recorded for future increments: new scripts must NOT rely on
  class_name — plain (non-editor) runs never regenerate the global class
  cache; use the preload pattern.

## Next Action

FQ-07 (visual asset pipeline with color fallback) is next in the queue.
