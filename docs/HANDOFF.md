# Coheronia — Handoff

## Current state

**v0.3 implemented and verified** (run `20260702_coheronia_v03_increment`; lineage: `20260702_coheronia_mvp_v01_oneshot` → `20260702_coheronia_input_repair` → `20260702_coheronia_v02_increment`, Godot 4.6.1 stable).

v0.3 additions (operator-directed continuation with a subagent verification/optimization loop):

- **Berry regrowth:** harvested bushes regrow after 90 s (`world.bush_regrow`, ticked in `world._process`, persisted in saves; 10 s retry if the player built in the cell). Food is now sustainable.
- **Dynamic population (1–8):** settlers eat ⌈pop/2⌉ food at dawn; a starved dawn loses a settler, a fed dawn with coherence ≥ 55 (pre-meal snapshot) and food ≥ population gains one. Population drives food need and `population_pressure`.
- **Storm event:** 50%/day daytime hazard (18 s, severity 8) damaging the hall at up to 3 dps scaled by missing **roof coverage** — `settlement_model.roof_coverage()` counts solid cover above the hall only, so ground fill doesn't help; build a roof. Persisted across save/load.
- **Lanterns:** ore sink at the Town Hall (2 ore + 1 wood → light radius 160, hotbar slot 5) via the generic `town_hall.craft_from_stockpile()`.
- **UX:** mining progress bar at the target cell, "⚠ N threats active" in the time label (refreshed on kill/load), save-availability hint.

Verification loop: an independent subagent reviewed the uncommitted diff and returned 9 findings (1 likely-bug: HUD bottom box overflow; 4 minor: stale threat count, storm re-roll on old saves, save version not bumped, roof scan height cap; 4 smoke coverage gaps). All 9 were applied and the suite re-passed. One design flaw was also caught by the smoke test itself mid-build: storm exposure originally keyed on `shelter_score`, which the flattened ground under the hall saturates — storms could never hurt anyone. Rekeyed to roof coverage, giving each hazard a distinct counter (storm → roof, slime → walls, darkness → light).

v0.2 additions (all from the GAME_FEATURE_OUTLINE / documented v0.1 limitations, operator-authorized continuation):

- **Tool-tier progression:** ore now requires tool tier 2 (`data/blocks.json`); the Town Hall panel forges the tier-2 pick from the stockpile using the `basic_pick_upgrade` recipe (3 wood + 5 stone, station `town_hall`); tiers scale mining speed via `player.effective_mine_speed()` (+50%/tier).
- **Food loop:** `berry_bush` blocks (new in `data/blocks.json`, separate RNG stream so same-seed terrain is unchanged) drop food; food is depositable; settlers eat `DAILY_FOOD_NEED` (2) at each dawn; shortage feeds `scarcity_penalty` (now food-aware).
- **Light occlusion:** every `blocks_light` tile gets an `OccluderPolygon2D` in the runtime TileSet and torch `PointLight2D`s have `shadow_enabled` — walls block light, unlit caves are dark.
- **Threat persistence:** saves are version 0.2 (v0.1 saves still accepted) and carry `threats: [{x, y, hp}]`, restored on load.

**Input repair (post-oneshot):** the scaffold's `project.godot` stored input events as JSON-style dictionaries (`{"type": "InputEventKey", ...}`), which Godot 4 silently discards — every action existed but had zero device bindings, so real keyboard/mouse play was dead. The oneshot smoke test missed this because `Input.action_press()` triggers actions directly, bypassing the InputMap. Fixed by rewriting `[input]` with proper `Object(InputEventKey/InputEventMouseButton, ...)` serialization, and the smoke test now asserts every gameplay action has at least one real device event (`input_actions_bound`, 23/23 passing).

The playable loop works end to end: move/jump → hold-to-mine with hardness timing → inventory/hotbar → block and torch placement with dynamic visible light → Town Hall panel (deposit, repair) → C/L/R computed from actual world state on a 5 s tick → day/night cycle → night pressure event with slime threats that damage the hall → F5/F9 save/load preserving terrain deltas, inventory, player, stockpile, damage, and time.

Key implementation facts:

- `BlockRegistry` (autoload) is the only reader of `data/*.json`; block behavior, recipes, and C/L/R formulas stay data-authoritative. Formulas are evaluated from `data/settlement_rules.json` strings via Godot's `Expression` class.
- The world is a dictionary grid (`Vector2i -> block_id`) rendered through a `TileMapLayer` whose TileSet (colored tiles + collision polygons) is generated at runtime — no imported art assets.
- Saves persist `world_seed` + terrain deltas only; base terrain regenerates deterministically (`WorldGen.generate`).
- Torches create `PointLight2D` nodes; day/night is a `CanvasModulate` tint, so torch light is visually meaningful at night.
- `scripts/main/smoke_test.gd` runs when env `COHERONIA_SMOKE=1`: 22 automated acceptance checks through the real gameplay code paths, plus a screenshot in windowed runs. Exit code 0 = pass.

## Validation status

| Check | State | Evidence |
|---|---|---|
| JSON data parses / scaffold valid | PASS | `python scripts/validate_repo.py` → `RESULT scaffold_valid` |
| Capsule doctor | PASS | `usable_with_warnings` → now `usable` expected (git initialized this run) |
| Godot import, no missing refs | PASS | headless `--import` clean (only benign warning: nested `reference/g1v5` project ignored) |
| Acceptance smoke test | PASS 47/47 | headless and windowed runs, exit 0 (v0.3 adds regrowth, population dynamics + bounds, lantern, storm damage + roof mitigation, storm/regrow persistence checks) |
| Visual check (torch light, HUD bars, night tint) | PASS | `user://smoke_screenshot.png` reviewed |
| Manual human playthrough | NOT-CHECKED | recommended but not blocking; all mechanics covered by automated checks |

Smoke evidence highlights: mining frames dirt=21 wood=33 stone=66 (hardness ordering); C 31.2→53.2 when torches added near hall; Load 12.3→32.3 when night threat forced; save/load round trip restores terrain/player/stockpile/lights.

## Known risks / gotchas

- GDScript "inferred from Variant" warnings are treated as errors in Godot 4.6 defaults — use explicit type annotations when assigning from dynamically-typed member access.
- `project.godot` input events must use `Object(InputEventKey, ...)` serialization; dictionary-format entries parse without error but bind nothing. Programmatic `Input.action_press()` in tests does NOT exercise bindings — keep the `input_actions_bound` smoke check when adding actions.
- The Godot binary used for validation lives at `B:\dev\Coheronia\project.godot\Godot_v4.6.1-stable_win64.exe` (a folder confusingly named `project.godot` next to this repo; it is not part of this repo).
- Active threats are not saved; loading during a night despawns them (night pressure score re-derives from time).
- `reference/g1v5/` and `_protocol/Project_Ops_Capsule/` remain read-only reference; untouched this run.

## Next action

Human playthrough for feel/tuning (day 100 s, night at 65%; storm 50%/day, 18 s, 3 dps unroofed; ⌈pop/2⌉ food/dawn, bush regrow 90 s, pop 1–8 with growth at coherence ≥ 55). Then decide v0.4 scope — remaining candidates from `docs/GAME_FEATURE_OUTLINE.md`: farming/plantable bushes, tier-3 tools with a deeper stone layer, a workbench/crafting menu (recipe count now justifies it: 4), fuel-based light decay, settler role assignment (still abstract), threat variety (digger that breaks blocks).

## Closeout expectation for next run

End with SIGNABLE / PARTIAL / BLOCKED / FAILED. Only SIGNABLE if the acceptance table in `docs/MVP_VERTICAL_SLICE.md` is verified (the smoke test covers it: `COHERONIA_SMOKE=1` + exit code 0).
