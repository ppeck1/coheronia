# Run Ledger: 20260709_coheronia_fq09r_review_hardening

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + 2 haiku recon scouts + sonnet review agent |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09R (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-09T13:00:00-04:00 |
| Ended At | 2026-07-09T14:05:00-04:00 |

## User Request

"proceed" — take only FQ-09R with the swarm pipeline: cheap scouts for
read-only recon, one implementation lane, independent diff review, then
orchestrator verification. Hard constraints: no new ores, stations, farming,
animation, or progression mechanics.

## Agent Protocol Notes

Scout A (haiku, read-only) mapped the tree generation/rendering/smoke surface
and produced the load-bearing insight that `can_mine` never checks `is_solid`
(berry_bush precedent), so a unified tree could be non-solid cells in the
normal block grid — no new mechanics needed. Scout B (haiku, read-only)
audited the pre-existing uncommitted creation notes and found one wording
discrepancy ("drops" vs the live destroy-not-drop behavior). The orchestrator
implemented one coherent patch, then a sonnet review agent reviewed the full
diff: verdict SIGNABLE, zero blockers, one nit (fixed) and one pre-existing
should-fix (recorded below as a remaining risk).

## Prior State Note

The working tree already carried an earlier session's FQ-09R start: the two
shell_ui.gd creation notes and doc updates marking FQ-09R "in review". This
run audited that half (fixing the wording bug), implemented the missing tree
unification half, and closed the item.

## Scope (design decisions, now documented)

1. Unified tree rule: every tree site from the tree seed channel grows a
   `tree_trunk` column (3-5 tall) topped by a `tree_leaves` canopy (3x2,
   up to 6 cells) — both generated into `cells` like any block.
2. New blocks (data-only, reusing existing block fields): `tree_trunk`
   (hardness 0.55 = wood, axe-preferred, drops 1 wood, non-solid,
   non-placeable, no occlusion) and `tree_leaves` (hardness 0.15, no drops,
   otherwise identical flags). Non-solid means no collision polygon — the
   player walks in front of/past every tree; in-cells means the existing
   mining/axe/drop path harvests them unchanged.
3. Placed `wood` is untouched: still solid, buildable, roof/shelter material.
   Frame baselines survive because tree_trunk shares wood's hardness (dirt 21
   / trunk 33 / stone 66 / with axe 24).
4. FQ-02 surfaces retired: `background_cells`, `BackgroundFlora` layer,
   `bg_trunk`/`bg_canopy`, `world.background_at`, `_grow_background_tree`,
   `generation.tree_foreground_ratio` (default, ui_help, "Solid Tree Ratio"
   slider). Old world configs carrying the stored ratio key are ignored
   harmlessly (verified: nothing reads it).
5. Mined tree cells persist as normal "air" deltas; trees regenerate from
   seed+config; the Town Hall stamp clears its footprint through the normal
   cells path. Tree ids can never enter deltas (not placeable, not regrown).
6. Creation-rule clarity: character form note (backpack/tools/equipment/
   ancestry/role/traits follow the character; role starter items once;
   "Collapse loses a fraction of carried stacks" — wording fixed from
   "drops", matching the live destroy-not-drop behavior) and world form note
   (world owns terrain/stockpile/threats/storms/base level/player level/
   position/current health; entering with another character uses that
   character's carried gear). Scout B fact-checked every claim against live
   code paths.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | new tree blocks pass preferred_tool policy; 2 new INFO fallback-art lines only |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 183/183 at 2026-07-09T13:45:16; frames dirt=21 trunk=33 stone=66, axe 33->24 |
| `git diff --check` | PASS | exit 0 |

Smoke changes: the 8 fq02_* checks are replaced by 8 fq09r_* checks (suite
total unchanged at 183): density-zero clears trunks and leaves; default
generation produces trees with leaves (54 trunks / 84 leaves at seed 777);
every tree cell is non-solid and bare-hand mineable (0 violations of 138);
density 2.0 grows more trunks than default (54 -> 84); mining a trunk yields
exactly 1 wood and leaves an air cell; clearing a leaf changes no inventory
count; a surface trunk is found on flat terrain; the player walks past it
using only move_right (x=2279.0 past target 2216.0). The baseline mining and
wave_f axe checks now harvest tree_trunk on the same wood-hardness contract.

## Review Findings And Resolutions

- Verdict: SIGNABLE, zero blockers. Removed symbols fully purged from live
  code; no consumer of the old "background" generate key; bush placement
  semantics proven equivalent; old wood deltas and stored ratio keys safe;
  all 8 fq09r checks non-vacuous (null guards fail the check rather than
  skip it).
- NIT (fixed): VARIABLE_MATRIX's historical v0.6 paragraph said "wood 33 ->
  24 frames"; now notes the wave_f harvest target moved to tree_trunk at the
  same hardness.
- SHOULD-FIX (pre-existing, deferred): smoke_test.gd's baseline mining has no
  null guard between `mineable_blocks_found` and the `_mine_cell` calls — a
  find failure would crash the suite rather than fail cleanly. Identical risk
  existed before FQ-09R (recorded here; candidate for a future smoke-hygiene
  pass).

## Acceptance vs FQ-09R

- Smoke proves generated trees have leaves (fq09r_trees_have_leaves).
- Smoke proves the player walks in front of/past trees without collision
  (fq09r_player_walks_past_tree; non-solid blocks build no collision
  polygons — fq09r_trees_passable_and_harvestable).
- Smoke proves trees are harvestable through the existing mining/axe path and
  yield wood (fq09r_harvest_trunk_yields_wood; wave_f axe speed-up on
  tree_trunk).
- No walk-past-but-not-harvestable tree class remains anywhere.
- Creation/help text mentions live collapse inventory loss and character/
  world ownership boundaries without implying future mechanics.
- Validator, capsule doctor, waited Godot smoke, and git diff --check all
  pass.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260709_coheronia_fq09r_review_hardening.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260709_coheronia_fq09r_review_hardening.json`

## Git Closeout

Implementation commit `f12946c` (code, data, docs), then this evidence-only
commit. Not pushed (push only on explicit operator request).

## Remaining Risks

- Generated trees no longer count toward shelter/roof/occlusion math (trunk
  and leaves are non-solid, non-occluding); only placed solid blocks do.
  Slight C/L/R input drift near tree lines is intentional and unobserved in
  smoke; untested by human play.
- Wood supply rose: every tree is now harvestable (previously ~40% of sites).
  Economy numbers are data-tunable if play shows surplus.
- Mining a low trunk cell leaves upper trunk/canopy cells floating (no
  support rule on trees, mirroring old floating wood columns); cosmetic, each
  floating cell remains harvestable.
- Pre-FQ-09R worlds regenerate with unified trees where old solid columns or
  background flora stood; deltas overlay cleanly — cosmetic only.
- Pre-existing smoke hygiene: missing null guard around the baseline
  `_mine_cell` calls (see review findings).

## Next Action

FQ-09S (skill tree visual treatment pass) is next in the queue.
