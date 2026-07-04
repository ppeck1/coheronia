# Run Ledger: 20260704_coheronia_v06_increment

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude Code (Fable 5) orchestrator + 3 sequential sonnet implementation agents |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Started At | 2026-07-03T14:30:00-04:00 |
| Ended At | 2026-07-04T00:30:00-04:00 |

## User Request

"Work from the following file, with an array of agents/subagents in a token saving method when appropriate, also add a verification loop" — executing `docs/WORK_ORDER_V0_6_CHARACTER_INVENTORY_WORLD_TOOLS.md` (committed as `673f598`).

## Scope

The work order's six waves, implemented in its recommended commit split:

1. `01d19e3` Wave A/D — ancestry detail panel in character creation (new `ancestry_detail.gd` pure text builder; descriptions added to all 12 ancestries) and world-builder clarity (`ui_help` section in world_settings.json: axis/gen/preset help; size dimensions from data).
2. `871bf3e` Wave B/C — character-owned carried state (inventory, hotbar slot, tool tier) in `user://shell.json` with one-time legacy migration and once-per-character role items; world saves retire player inventory keys; openable inventory panel on new `toggle_inventory` (I) action with panel-exclusivity and layered Esc.
3. `51468f4` Wave E/F — data-driven `requires_support` bush rule enforced on mine/load-sweep/regrowth; `preferred_tool` block fields; `craft_axe` hall recipe forging an axe that mines axe-preferred blocks 1.4x faster; character-owned `{pick, axe}` tool state with conservative legacy migration (axe not granted free).
4. Closeout — this ledger, docs, outbox packets.

## Non-Goals (per work order)

No NPC simulation, no paper-doll equipment, no drag/drop grid, no research bench or perk UI, no new biomes, no multiplayer/cloud, no art pass. Player XP explicitly stays world-owned for v0.6 (documented in HANDOFF and VARIABLE_MATRIX).

## Agent Protocol Notes

Three sequential sonnet agents matching the commit split (sequential because all waves touch smoke_test.gd and several share player/hud/save files — no merge conflicts possible). Each agent carried the work-order section as authoritative spec, ran its own validator+smoke loop until green, and the orchestrator re-verified independently before each commit. Orchestrator fixed one inconsistency inline after Wave E/F: the brief had told the agent legacy characters migrate to axe tier 1, contradicting the craft-only axe design; corrected to `{pick: N, axe: 0}` with the smoke assertion updated, then re-verified 122/122.

## Files Changed

- `data/ancestries.json` (descriptions), `data/world_settings.json` (ui_help), `data/blocks.json` (preferred_tool, requires_support), `data/recipes.json` (craft_axe)
- `scripts/data/ancestry_detail.gd` (new)
- `scripts/shell/shell_ui.gd` (detail panel, world-builder help), `scripts/shell/game_state.gd` (carried fields, save_character_carried)
- `scripts/save/save_manager.gd` (carried-state boundary, legacy_player_carried)
- `scripts/main/game_root.gd` (carried load/apply, items_granted, toggle_inventory/Esc, forge_axe handler)
- `scripts/player/player.gd` (axe_tier, per-block preferred-tool speed), `scripts/inventory/inventory.gd` (unchanged interface)
- `scripts/ui/hud.gd` (inventory panel, tool display, forge-axe button), `scripts/settlement/town_hall.gd` (forge_axe)
- `scripts/world/world.gd` (support rule: break cascade, load sweep, regrowth guard), `scripts/world/block_registry.gd` (accessors)
- `project.godot` (toggle_inventory input action)
- `scripts/validate_repo.py` (descriptions, ui_help, requires_support, preferred_tool, craft_axe checks)
- `scripts/main/smoke_test.gd` (90 -> 122 checks)
- `README.md`, `docs/HANDOFF.md`, `docs/VARIABLE_MATRIX.md`, `.project/` run artifacts

## Mutation Surface Audit

| Surface | Result | Evidence |
|---|---|---|
| Canonical docs | PASS | README/HANDOFF/VARIABLE_MATRIX updated; work order preserved as spec |
| Data contracts | PASS | new fields validator-required; audited in VARIABLE_MATRIX |
| Protected paths | PASS | reference/g1v5/ and _protocol/ untouched |
| Atlas event | PASS | `.project/atlas_outbox/20260704_coheronia_v06_increment.json` |
| BOH packet | PASS | `.project/boh_outbox/20260704_coheronia_v06_increment.json` |
| Git closeout | PASS | committed on main; pushed after final green per work order |

## README Audit

State: updated (v0.6 title/state/highlights, ancestry panel, carried-state ownership, controls I key, play loop, smoke 122, limitations)

## Variable Matrix Audit

State: updated (v0.6 ownership boundary table, tool/support block fields, carried-state authorities, ui_help surface, validation hooks)

## Validation Commands

| Command | Result | Evidence |
|---|---|---|
| `git status --short --branch` / `git remote -v` | PASS | `main...origin/main`, origin = github.com/ppeck1/coheronia |
| `python scripts/validate_repo.py` | PASS | `RESULT scaffold_valid` at baseline, after every wave, and at closeout |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` at baseline |
| `COHERONIA_SMOKE=1` waited windowed run | PASS | `user://smoke_results.json` PASS at every wave gate |

Smoke progression: 90 (v0.5 baseline) -> 94 (A/D) -> 106 (B/C) -> 122 (E/F, re-verified after orchestrator's legacy-axe fix).

## Wave Acceptance Evidence

- Wave B: two characters, one world — distinct inventories both directions (`wave_b_char_a/b_distinct_inventory`); inventory survives a second world; role items granted once (exact-count assertion); legacy character + old-format save migrates without crash.
- Wave C: `toggle_inventory` device-bound; panel opens/closes reliably and shows "Dirt x13" after a known add; town-panel exclusivity kept.
- Wave E: mining the support removes the bush and yields food; load sweep resurrects nothing; regrowth into unsupported air re-schedules.
- Wave F: baseline mining frames unchanged (dirt 21 / wood 33 / stone 66); axe forges for 4 wood + 2 stone; wood 33 -> 24 frames with axe; stone/ore unaffected; `{pick: 2, axe: 1}` round-trips; legacy tier-3 pick migrates to `{pick: 3, axe: 0}`.

## Repair Iterations

- Orchestrator-corrected inconsistency: legacy tool migration granted a free axe (per a flawed brief line); fixed to axe 0 across three code sites and one assertion, re-ran smoke to 122/122.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260704_coheronia_v06_increment.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260704_coheronia_v06_increment.json`

## Git Closeout

State: committed and pushed to `origin/main` after final green validation, per the work order's push gate.

## Remaining Risks

- Smoke mutates the real `user://shell.json`; interrupted runs can leave test characters behind (tests clean up on completion).
- Player position/health/XP remain world-owned; cross-world leveling deferred.
- Inventory panel is read-only; axe has a single tier.
- Feel/tuning (axe pacing, bush support harshness) untested by human play.

## Next Action

Operator playthrough of v0.6 (two characters swapping worlds, forge the axe, harvest supported bushes, use the I panel). Recommended next increment: farming on the `requires_support` groundwork plus a compact crafting menu, then the research bench MVP.
