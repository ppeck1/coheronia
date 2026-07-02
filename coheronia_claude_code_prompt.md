# Claude Code / Fable Prompt — Coheronia v0.1 One-Shot Build

You are working on **Coheronia**, a Godot 4 2D side-view survival settlement sandbox.

The goal is a constrained one-shot implementation of a playable MVP. Do not broaden scope.

## Non-negotiable success rule

The prototype is successful when it proves the **Coherence / Load / Resilience settlement loop through play**, not when it has many systems.

## Operator context

- The intended Project Ops Capsule root is:

```text
B:\Projects\LLM_Modules\Project_Ops_Capsule
```

- This project is already represented in Project Atlas MCP. Do not create a duplicate Atlas project identity. Queue an outbox event for the existing project key unless the repo manifest says otherwise.
- Old build/reference files may exist in a neighboring folder and are also copied under `reference/g1v5/`. Treat the old archive as reference/spec context, not accepted implementation truth. The attached old archive described scenes/scripts that were not present in the archive.
- This repo is the new working scaffold.

## Required protocol

Follow the Project Ops Capsule rule:

```text
Every run records evidence; only signable runs update accepted truth.
```

Before coding:

```text
1. Inspect repo state and tree.
2. Run:
   python scripts/validate_repo.py
3. Run capsule doctor, preferring the canonical local capsule root if present:
   python B:\Projects\LLM_Modules\Project_Ops_Capsule\scripts\capsule_doctor.py . --profile private_repo
   If that path is unavailable, run:
   python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile private_repo
4. Read:
   docs/GAME_FEATURE_OUTLINE.md
   docs/MVP_VERTICAL_SLICE.md
   docs/VARIABLE_MATRIX.md
   docs/HANDOFF.md
   data/blocks.json
   data/recipes.json
   data/settlement_rules.json
5. Produce a brief implementation plan in your own working notes before coding.
```

During coding:

```text
- Implement only the v0.1 MVP in docs/MVP_VERTICAL_SLICE.md.
- Prefer small Godot scripts with clear responsibilities.
- Preserve data-driven block definitions where feasible.
- Keep placeholder art acceptable.
- Do not introduce multiplayer, online services, cloud save, a custom engine, ECS framework, full NPC simulation, large crafting tree, dialogue, quest system, mobile port, or complex combat.
- Do not mutate reference/g1v5/ or _protocol/Project_Ops_Capsule/ except by explicit operator instruction.
```

## Game identity

Coheronia is a 2D side-view survival settlement sandbox where the player physically reshapes terrain while indirectly managing a settlement through three systemic pressures:

```text
Coherence
Load
Resilience
```

The player loop is:

```text
Explore → gather → mine → build → light → shelter → store resources → settlement state changes → threats/pressure emerge → repair/adapt → repeat
```

## Must build for v0.1

Build a runnable Godot 4 project with:

```text
Main playable scene
Player movement and jump
Procedural block terrain
Block mining
Block hardness/mining time
Block placement from inventory
Inventory counts and selected item/hotbar
Torch placement
Dynamic visible torch lighting
Town Hall object
Town Hall interaction panel or UI surface
Town Hall stockpile
C/L/R calculation from actual game state
HUD showing health, selected item, inventory/resource counts, C/L/R bars, day/night or pressure state, and event log
Simple threat or pressure event
F5 save and F9 load
Save/load preservation of terrain edits, inventory, player position, Town Hall stockpile, time/pressure state, and C/L/R inputs or recomputed values
README updates
docs/HANDOFF.md updates
docs/VARIABLE_MATRIX.md updates
.project run ledger
.project Atlas outbox event
.project BOH packet if appropriate
```

## Should build only if cheap

```text
Day/night cycle
One simple enemy type
Basic torch crafting
Debug overlay showing C/L/R inputs
Settlement status labels: Stable, Strained, Critical, Exposed, Well-lit, Undersupplied
```

## Must not build yet

```text
Multiplayer
Online services
Full NPC AI
Full colony simulation
Large crafting tree
Polished art pipeline
Dialogue system
Quest system
Procedural biomes
Advanced pathfinding
Modding system
Mobile port
Cloud save
Complex combat
Unrequested architecture rewrites
```

## Required C/L/R behavior

C/L/R must be connected to actual game state. Decorative bars do not satisfy the MVP.

Use these MVP inputs:

```text
shelter_score: nearby solid blocks around/above Town Hall
light_score: torches/light near Town Hall or shelter zone
stockpile_score: Town Hall stored resources
defense_score: stone/defensive blocks near Town Hall
damage_score: Town Hall or shelter damage
threat_score: active enemy or pressure event severity
scarcity_penalty: low supply reserve
population_pressure: abstract population support load
```

Acceptable simple formulas:

```text
Coherence = shelter_score + light_score + stockpile_score - damage_score - population_pressure
Load = threat_score + scarcity_penalty + damage_score + population_pressure - light_score * 0.25
Resilience = stockpile_score + defense_score + shelter_score + light_score * 0.5 - damage_score
```

Clamp values to 0-100. Show them in the HUD.

## Required block behavior

Use or preserve the fields from `data/blocks.json`:

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

At minimum:

```text
dirt mines quickly
wood mines modestly
stone mines slower than dirt/wood
torch emits visible light
town_hall_core is protected or not normally mineable
```

## Suggested Godot structure

Prefer this structure unless there is a strong reason not to:

```text
scenes/main/Main.tscn
scenes/player/Player.tscn
scenes/world/World.tscn
scenes/settlement/TownHall.tscn
scenes/ui/HUD.tscn
scenes/entities/SimpleThreat.tscn
scripts/main/game_root.gd
scripts/player/player.gd
scripts/world/world.gd
scripts/world/world_gen.gd
scripts/world/block_registry.gd
scripts/settlement/settlement_model.gd
scripts/settlement/town_hall.gd
scripts/inventory/inventory.gd
scripts/save/save_manager.gd
scripts/ui/hud.gd
```

Small deviations are fine if the final project is clear and runnable.

## Validation and closeout

You may mark the run SIGNABLE only if the v0.1 acceptance checks are verified.

Required checks:

```text
Godot project opens
Main scene launches
No missing script/resource references
Player can move and jump
Player can mine at least dirt/stone/wood
Harder block takes longer than softer block
Inventory increases from mining
Player can place at least one solid block
Player can place a torch
Torch visibly emits light
Town Hall exists
Player can interact with Town Hall
Resources can affect Town Hall stockpile
C/L/R bars visibly update from game state
At least one pressure/threat event affects C/L/R
F5/F9 save/load preserves core state
README updated
HANDOFF updated
VARIABLE_MATRIX updated
Run ledger written
Atlas outbox event queued
BOH outbox packet queued or explicitly deferred
```

If Godot is unavailable in the terminal environment, do not claim full SIGNABLE. Mark PARTIAL and document the exact unverified manual checks.

## Required closeout artifacts

At closeout, update/create:

```text
README.md
docs/HANDOFF.md
docs/VARIABLE_MATRIX.md
.project/runs/<run-id>.md
.project/atlas_outbox/<run-id>.json
.project/boh_outbox/<run-id>.json
```

Do not push to GitHub automatically.

End your response with:

```text
Run State: SIGNABLE | PARTIAL | BLOCKED | FAILED
Validation Summary: <concise evidence>
Changed Files: <scoped list>
Next Operator Action: <one clear action>
```
