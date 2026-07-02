# Coheronia v0.1 — MVP Vertical Slice Contract

This is the only accepted implementation scope for the first Claude Code / Fable one-shot.

## Success statement

The prototype is successful when it proves the **Coherence / Load / Resilience settlement loop through play**, not when it has many systems.

## Required playable loop

```text
Spawn → move → mine blocks → collect resources → place blocks/torches → shelter Town Hall → deposit resources → C/L/R changes → pressure event occurs → player adapts → save/load preserves state.
```

## Must build

- Runnable Godot 4 project.
- Main playable scene.
- Player movement and jump.
- Procedural block terrain.
- Block mining with hardness/mining time.
- Block placement from inventory.
- Inventory counts and selected item/hotbar.
- Torch placement.
- Dynamic visible torch lighting.
- Town Hall object.
- Town Hall interaction panel or UI surface.
- Town Hall stockpile.
- C/L/R calculation from actual game state.
- HUD showing health, selected item, inventory/resource counts, C/L/R bars, day/night or pressure state, and event log.
- Simple threat or pressure event.
- F5 save and F9 load.
- Save/load preserves core state: terrain edits, inventory, player position, Town Hall stockpile, time/pressure state, and C/L/R or recomputable inputs.
- README updated with run instructions, controls, and known limitations.
- docs/HANDOFF.md updated.
- docs/VARIABLE_MATRIX.md updated.
- .project run ledger recorded.
- Atlas outbox event queued.
- BOH packet queued if appropriate.

## Should build if cheap

- Day/night cycle.
- One simple enemy type.
- Basic torch crafting.
- Debug overlay showing C/L/R inputs.
- Settlement status labels such as Stable, Strained, Critical, Exposed, Well-lit, Undersupplied.

## Must not build yet

- Multiplayer.
- Online services.
- Full NPC AI.
- Full colony simulation.
- Large crafting tree.
- Polished art pipeline.
- Dialogue system.
- Quest system.
- Procedural biomes.
- Advanced pathfinding.
- Modding system.
- Mobile port.
- Cloud save.
- Complex combat.
- Unrequested engine/framework rewrites.

## Minimum acceptance checks

The final run may be marked SIGNABLE only if all checks below pass or are explicitly documented with a narrow justified exception.

| Check | Required result |
|---|---|
| Godot project opens | PASS |
| Main scene launches | PASS |
| No missing scripts/resources | PASS |
| Player can move and jump | PASS |
| Player can mine at least dirt/stone/wood | PASS |
| Harder block takes longer than softer block | PASS |
| Player inventory increases from mining | PASS |
| Player can place at least one solid block | PASS |
| Player can place torch | PASS |
| Torch visibly emits light | PASS |
| Town Hall exists | PASS |
| Player can interact with Town Hall | PASS |
| Player can deposit resources or resources affect Town Hall stockpile | PASS |
| C/L/R bars visibly update from game state | PASS |
| At least one pressure/threat event affects C/L/R | PASS |
| Save/load preserves core state | PASS |
| README/HANDOFF/VARIABLE_MATRIX updated | PASS |
| Run ledger and outbox packets written | PASS |

## C/L/R MVP rule

C/L/R must be connected to world state. Decorative bars do not satisfy the MVP.

Accepted inputs for v0.1:

```text
shelter_score: nearby solid blocks around/above Town Hall
light_score: torches/light near Town Hall
stockpile_score: stored resources at Town Hall
defense_score: stone/defensive blocks near Town Hall
damage_score: Town Hall or shelter damage
threat_score: active enemy/pressure event severity
scarcity_penalty: low supply reserve
population_pressure: abstract population support load
```

## Technical preference

Prefer small, explicit Godot scripts over an abstract architecture. Keep data-driven block and recipe definitions where feasible.

Use placeholder art. Mechanics have priority.
