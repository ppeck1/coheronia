# Coheronia — Handoff

## Current state

**v0.1 MVP vertical slice implemented and verified** (run `20260702_coheronia_mvp_v01_oneshot` + input repair run `20260702_coheronia_input_repair`, Godot 4.6.1 stable).

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
| Acceptance smoke test | PASS 23/23 | headless and windowed runs, exit 0 (includes real input-binding check) |
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

Human playthrough for feel/tuning (day length 100 s, night at 65%, threat DPS 4). Then decide v0.2 scope — candidates from `docs/GAME_FEATURE_OUTLINE.md`: pick-upgrade UI at the Town Hall, per-tile light occlusion, threat persistence in saves, population that consumes stockpile.

## Closeout expectation for next run

End with SIGNABLE / PARTIAL / BLOCKED / FAILED. Only SIGNABLE if the acceptance table in `docs/MVP_VERTICAL_SLICE.md` is verified (the smoke test covers it: `COHERONIA_SMOKE=1` + exit code 0).
