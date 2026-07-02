# Run Ledger: 20260702_coheronia_v02_increment

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Fable 5) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Started At | 2026-07-02T12:05:00-04:00 |
| Ended At | 2026-07-02T12:40:00-04:00 |

## User Request

"Continue with the build per the specs outlined." Operator-authorized continuation past the signed v0.1 slice.

## Scope

v0.2 increment, drawn from the GAME_FEATURE_OUTLINE and the documented v0.1 limitations (the HANDOFF's own v0.2 candidates):

1. Tool-tier progression: ore gated to tier 2; pick upgrade forged at the Town Hall from stockpile (`basic_pick_upgrade` recipe, station `town_hall`); tiers scale mining speed (+50%/tier).
2. Food loop: `berry_bush` block drops food; food depositable; settlers eat 2 food at each dawn; shortage feeds a food-aware `scarcity_penalty`.
3. Per-tile light occlusion: `blocks_light` tiles get occluder polygons; torch lights cast shadows.
4. Threat persistence: save version 0.2 carries `threats: [{x, y, hp}]`; v0.1 saves still accepted.

## Non-Goals

Everything on the MVP contract's "must not build yet" list remains excluded (no NPC AI, crafting menu UI, biomes, pathfinding, etc.).

## Files Changed

- `data/blocks.json` (ore tier 1→2; berry_bush added)
- `data/recipes.json` (pick recipe output renamed tool_tier_2_pick)
- `scripts/world/world_gen.gd` (berry bush pass on separate RNG stream — same-seed terrain unchanged)
- `scripts/world/world.gd` (occlusion layer + per-tile occluders, shadowed torch lights, bush texture/color)
- `scripts/player/player.gd` (effective_mine_speed, hand-station guard on craft)
- `scripts/settlement/town_hall.gd` (food depositable, forge_pick, consume_food)
- `scripts/settlement/settlement_model.gd` (food-aware scarcity_penalty)
- `scripts/main/game_root.gd` (dawn food consumption, forge wiring, serialize/apply_threats)
- `scripts/save/save_manager.gd` (version 0.2 + 0.1 back-compat, threats key)
- `scripts/ui/hud.gd` (forge button, food/pick-tier display)
- `scripts/main/smoke_test.gd` (11 new checks; screenshot framed at the hall)
- `README.md`, `docs/HANDOFF.md`, `docs/VARIABLE_MATRIX.md`
- `.project/` run artifacts

## Mutation Surface Audit

| Surface | Result | Evidence |
|---|---|---|
| Canonical docs | PASS | README/HANDOFF/VARIABLE_MATRIX updated; outline/MVP contract untouched |
| Data contracts | PASS | blocks/recipes changes audited in VARIABLE_MATRIX |
| Protected paths | PASS | reference/g1v5/ and _protocol/ untouched |
| Atlas event | PASS | `.project/atlas_outbox/20260702_coheronia_v02_increment.json` |
| BOH packet | PASS | `.project/boh_outbox/20260702_coheronia_v02_increment.json` |
| Git closeout | PASS | committed on main |

## README Audit

State: updated

## Variable Matrix Audit

State: updated (ore tier change, berry_bush/food, effective_mine_speed, scarcity formula, save 0.2/threats, new v0.2 table)

## Validation Commands

| Command | Result | Evidence |
|---|---|---|
| `COHERONIA_SMOKE=1` headless run | PASS | `SMOKE RESULT: PASS (34/34 passed)`, exit 0 |
| `COHERONIA_SMOKE=1` windowed run | PASS | 34/34 + hall-framed screenshot reviewed |
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid` (run at closeout) |
| capsule doctor | PASS | usable_with_warnings (only: no git remote, expected) |

## Verification Evidence

New v0.2 checks (deterministic seed 12345): ore exists and is NOT mineable at tier 1 (`ore_gated_by_tool_tier`); forging at the hall consumes stockpile wood 3 + stone 5 and sets tier 2 (`forge_pick_upgrade`); tier 2 mines dirt in 14 frames vs 21 at tier 1 (`tier2_mines_faster`); ore mineable after forge in 64 frames; berry bush found and mined for 2 food; occlusion layer present in the TileSet and torch lights shadow-enabled; deposit includes food; dawn consumption eats food 2→0; save/load restores 1 live threat and tool tier 2. Screenshot: torch-lit Town Hall at night with the restored slime approaching, dark occluded terrain, HUD showing "Pick tier 2" and food events in the log. All 23 pre-existing checks still pass unchanged (mining frames identical: 21/33/66).

## Repair Iterations

None required for gameplay code (34/34 on first run). One evidence-quality tweak: screenshot now teleports the player to the hall first so lighting/shadows are visible.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260702_coheronia_v02_increment.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260702_coheronia_v02_increment.json`

## Git Closeout

State: committed (implementation + closeout on `main`; not pushed, push_policy manual)

## Remaining Risks

- Feel/tuning still unverified by human play (now including food pacing: 2/dawn vs ~0.07 bushes/column).
- Berry bushes are finite; long sessions can exhaust surface food (documented; regrowth is a v0.3 candidate).
- Occlusion adds shadow-casting lights; unmeasured perf impact with very many torches (expected fine at this scale).

## Next Action

Operator playthrough of v0.2 (forge the pick, keep settlers fed through a few dawns), then pick v0.3 scope from the HANDOFF candidates.
