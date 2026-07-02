# Coheronia — Desired Feature Outline

This document preserves the intended whole-game feature set so future coding agents do not infer the design from a narrow MVP alone.

The MVP is constrained separately in `docs/MVP_VERTICAL_SLICE.md`.

## 1. Core identity

Coheronia is a 2D side-view survival settlement sandbox built around destructible terrain, physical building, settlement pressure, and three systemic variables:

```text
Coherence
Load
Resilience
```

The player is not only surviving as an individual. The player shapes a living settlement system. Terrain, buildings, light, storage, threats, and population pressure feed back into settlement state.

Primary loop:

```text
Explore → gather → mine → build → light → shelter → store resources →
settlement state changes → threats/pressure emerge → repair/adapt → repeat
```

Design identity:

```text
A world where structure matters.
```

## 2. Physical world

Desired long-term features:

- Procedural 2D tile terrain.
- Surface, underground, and cavern layers.
- Foreground and background tile layers.
- Mining and placement.
- Different block hardness values.
- Harder blocks take longer to mine.
- Some blocks require stronger tools.
- Blocks may drop resources different from themselves.
- Blocks can block or emit light.
- Blocks can carry settlement tags such as structure, defense, light, fuel, reserve, or anchor.

Required data fields:

```text
block_id
display_name
hardness
required_tool_tier
drops
is_placeable
is_solid
blocks_light
emits_light
light_radius
settlement_tags
```

Example block roles:

| Block | Role |
|---|---|
| Dirt | Fast temporary shaping block |
| Grass | Surface dirt variant |
| Wood | Early construction and fuel |
| Stone | Durable structure and defense |
| Ore | Progression resource |
| Torch | Light source and safety object |
| Town Hall Core | Protected settlement anchor |

## 3. Light and darkness

Lighting is a survival and settlement mechanic, not cosmetic-only presentation.

Desired features:

- Day/night cycle.
- Natural surface daylight.
- Underground darkness.
- Placeable torches.
- Dynamic torch lighting.
- Darkness affects threat pressure.
- Darkness increases Load.
- Lit shelter increases Coherence.
- Lit defensive paths increase Resilience.

MVP target:

```text
Torch item → place torch object/block → visible light source → Town Hall light score affects C/L/R.
```

Later features:

- Lanterns.
- Campfires.
- Fuel-based light.
- Light decay.
- Threats attracted to or repelled by light.
- Settlement darkness debt.
- Emergency beacon structures.

## 4. Player interaction

Desired features:

- Move left/right.
- Jump.
- Gravity/fall.
- Mine blocks.
- Place blocks.
- Use tools.
- Pick up drops.
- Use hotbar.
- Interact with Town Hall.
- Place torches.
- Take damage.
- Heal.
- Die/respawn with some penalty later.

MVP controls:

| Action | Suggested input |
|---|---|
| Move | A/D or arrow keys |
| Jump | Space |
| Mine | Left click / hold |
| Place | Right click |
| Select hotbar | 1-9 |
| Interact | E |
| Save | F5 |
| Load | F9 |
| Debug overlay | F3 |

## 5. Inventory and resources

Inventory connects the physical world to settlement systems.

Desired features:

- Player inventory.
- Hotbar.
- Stackable resources.
- Mining adds resources.
- Placement consumes resources.
- Town Hall stockpile.
- Deposit and withdrawal.
- Crafting consumes resources.
- Scarcity affects C/L/R.
- Surplus improves Resilience.

Core resource types:

| Resource | Use |
|---|---|
| Dirt | Temporary building/fill |
| Stone | Durable building/defense |
| Wood | Construction/crafting/fuel |
| Ore | Tool progression |
| Food | Settlement survival |
| Torch | Safety and light |

## 6. Building and shelter

Building changes settlement state.

Desired features:

- Player creates structures from blocks.
- Town Hall shelter detection.
- Shelter checks roof, walls, light, and safe access path.
- Defensive structures increase Resilience.
- Broken/exposed structures increase Load.
- Organized structures increase Coherence.

MVP rule:

Use a simple radius or bounding-zone check around Town Hall. Do not implement a complex building-recognition engine yet.

## 7. Settlement core

The settlement is anchored by a Town Hall.

Desired features:

- Town Hall object exists in world.
- Town Hall stores settlement state.
- Player deposits resources.
- C/L/R computed from actual world/resource conditions.
- Settlement has population count.
- Population consumes resources later.
- Buildings and events affect C/L/R.

MVP target:

```text
Town Hall + stockpile + population number + C/L/R calculation + status HUD + one simple threat/pressure loop.
```

## 8. Coherence / Load / Resilience

C/L/R is the signature mechanic.

### Coherence

Measures organization, legibility, and functionality.

Increases with shelter, light, stored resources, connected structures, repaired damage, and met needs.

Decreases with exposure, darkness, scarcity, unfinished/broken structures, threat damage, and unmet needs.

### Load

Measures strain, backlog, pressure, and instability.

Increases with scarcity, damage, darkness, threats, unsupported population, weather/events, and unresolved tasks.

Decreases with repair, storage, shelter, lighting, defense, and resolved threats.

### Resilience

Measures ability to absorb shocks.

Increases with reserves, defenses, protected Town Hall, redundant light, food reserve, tool/crafting capacity, and safe paths.

Decreases with empty storage, broken defense, breached shelter, no light, unsupported population, and repeated crises.

MVP formula inputs:

```text
shelter_score
light_score
stockpile_score
defense_score
damage_score
threat_score
scarcity_penalty
population_pressure
```

Anti-drift rule:

```text
C/L/R must be connected to actual game state. It cannot be decorative bars.
```

## 9. Threats and events

Desired features:

- Night pressure.
- Enemy raids.
- Wildlife.
- Environmental hazards.
- Storms.
- Cave danger.
- Resource shortage events.
- Settlement injuries later.
- Repair/recovery loop.

MVP recommendation:

Use one simple enemy or abstract pressure event. It should affect Load and/or Resilience and be mitigated by light, shelter, or defense.

Future enemy implementation notes are tracked in `docs/FUTURE_ENEMY_DESIGN.md`. They describe planned surface, underground, raider, mini-boss, and major-boss families that still need integration.

## 10. NPCs and population

NPCs are future scope unless extremely cheap.

Desired features:

- Settlers live near Town Hall.
- Settlers consume food.
- Settlers can be assigned roles.
- Settlers gather, repair, guard, craft, or rest later.
- Injuries/fear increase Load.
- Shelter and supplies increase Coherence.

MVP rule:

Use abstract population values only. Do not build full NPC AI in v0.1.

Future ancestry and biome planning is tracked in `docs/FUTURE_ANCESTRIES_AND_BIOMES.md`. It defines planned ancestry bones, biome affinities, deep-underground spawn rules, player effects, settlement effects, and phased implementation order.

## 11. Crafting and tools

Desired features:

- Basic crafting menu.
- Recipes.
- Tool tiers.
- Better tools mine faster.
- Some blocks require better tools.
- Workbench/furnace/storage later.

MVP minimum:

- Torch recipe if cheap.
- Tool-tier architecture present.
- Block hardness present.

## 12. Progression arc

Long-term arc:

```text
Claim site → gather and light → shelter Town Hall → stockpile resources → survive first pressure → reinforce → expand → automate/assign settlers → withstand larger instability.
```

MVP arc:

```text
Spawn → find Town Hall → gather dirt/stone/wood → place torches → build shelter → deposit resources → survive one threat pulse.
```

## 13. UI

Desired UI:

- Health.
- Inventory/hotbar.
- Selected item.
- Mining progress.
- C/L/R bars.
- Town Hall status.
- Day/night indicator.
- Threat warning.
- Resource stockpile.
- Debug overlay.
- Save/load confirmation.
- Event log.

MVP UI:

```text
Health
Selected item
Inventory counts
Coherence / Load / Resilience
Town Hall stockpile
Day/night indicator
Basic event log
```

## 14. Persistence

Desired features:

- Save/load.
- World seed.
- Terrain deltas.
- Inventory.
- Town Hall stockpile.
- C/L/R state or recomputed values.
- Time of day.
- Player position.
- Threat state later.

MVP requirement:

```text
F5 saves, F9 loads, and terrain edits/inventory/Town Hall state/player position survive reload.
```

## 15. Art and audio

For v0.1, placeholder art is acceptable.

Desired feel:

- Cozy but precarious.
- Warm light against darkness.
- Readable terrain.
- Low clutter.
- Clear silhouettes.
- Fable-like settlement tone.

MVP rule:

Do not let art block mechanics.

## 16. Technical architecture

Preferred structure:

```text
scenes/main
scenes/player
scenes/world
scenes/settlement
scenes/ui
scenes/entities
scripts/main
scripts/player
scripts/world
scripts/settlement
scripts/inventory
scripts/save
scripts/ui
scripts/data
data/blocks.json
data/recipes.json
data/settlement_rules.json
```

Anti-drift rule:

Do not invent multiplayer, online services, an ECS framework, complex modding system, mobile port, cloud save, or polished asset pipeline for v0.1.
