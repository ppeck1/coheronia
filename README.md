# Coheronia — v0.1 Playable Vertical Slice

Coheronia is a Godot 4 2D side-view survival settlement sandbox. The player physically reshapes terrain while indirectly managing a settlement through three systemic pressures: **Coherence / Load / Resilience**.

Current state: **v0.3 implemented and verified** (Godot 4.6.1). The C/L/R settlement loop is connected to actual world state: shelter blocks, torch light, stockpile, defense blocks, hall damage, threats, scarcity, and population pressure around the Town Hall all feed the HUD bars.

- v0.2 added tool-tier progression (forge a tier-2 pick at the Town Hall to mine ore and mine faster), the food loop (berry bushes → food → settlers eat at dawn), per-tile light occlusion, and threat persistence in saves.
- v0.3 adds **berry regrowth** (bushes regrow ~90 s after harvest), **dynamic population** (settlers arrive when the settlement is coherent and food-rich, leave when starved; population drives food need and pressure), a **storm event** (daytime hazard that damages the hall unless you build a roof over it), **lanterns** (2 ore + 1 wood at the Town Hall; brighter than torches, hotbar slot 5), and UX polish (mining progress at the cursor, active-threat warning, save-availability hint).

## Running the game

1. Open this folder as a project in Godot 4.6+ (tested with 4.6.1).
2. Run the main scene (`res://scenes/main/Main.tscn`, set as the project main scene).

Or from a terminal:

```powershell
& <path-to-godot-4.6> --path <this-repo-root>
```

## Controls

| Action | Input |
|---|---|
| Move | A/D or arrow keys |
| Jump | Space |
| Mine (hold) | Left mouse button |
| Place selected block | Right mouse button |
| Select hotbar slot | 1–5 |
| Interact with Town Hall (open/close panel) | E (or T) |
| Craft torch (1 wood + 1 stone → 3 torches) | C |
| Save | F5 |
| Load | F9 |
| Debug overlay (raw C/L/R inputs) | F3 |

## The loop

Spawn near the Town Hall → mine dirt/wood/stone (harder blocks take longer) and berry bushes for food (they regrow in ~90 s) → place blocks to shelter the hall, including a **roof**: storms roll in some days and damage the hall wherever it lacks overhead cover → place torches for light (walls block light, so caves need torches) → deposit resources at the hall (E → Deposit) → forge the tier-2 pick (3 wood + 5 stone) to mine ore and mine ~50% faster, then craft lanterns (2 ore + 1 wood) for brighter light → keep food stocked: settlers eat ⌈population/2⌉ food at every dawn; a fed, coherent settlement attracts new settlers (up to 8), a starved one loses them (down to 1) → watch Coherence/Load/Resilience react → survive the night pressure event (slimes approach the hall and gnaw it; walls block them, light reduces how many spawn, and you can whack them with the mine action) → repair the hall with stockpiled stone → repeat.

## Architecture

```text
scenes/main/Main.tscn            root scene wiring all instances
scenes/world/World.tscn          block grid + TileMapLayer + torch lights
scenes/player/Player.tscn        movement, mining, placement, crafting
scenes/settlement/TownHall.tscn  stockpile, damage, repair, population
scenes/ui/HUD.tscn               code-built HUD (bars, log, town panel)
scenes/entities/SimpleThreat.tscn night slime
scripts/main/game_root.gd        orchestration, day/night, threat event
scripts/main/smoke_test.gd       automated acceptance test (COHERONIA_SMOKE=1)
scripts/world/block_registry.gd  autoload; loads data/*.json (authoritative)
scripts/world/world_gen.gd       seeded terrain generation
scripts/world/world.gd           grid, mining/placement API, terrain deltas
scripts/inventory/inventory.gd   stackable counts
scripts/settlement/settlement_model.gd  C/L/R from world state (formulas
                                 evaluated from data/settlement_rules.json)
scripts/save/save_manager.gd     F5/F9 JSON persistence in user://
```

Block behavior (hardness, drops, light, tags) comes from `data/blocks.json`; recipes from `data/recipes.json`; C/L/R formulas, tick rate, and clamps from `data/settlement_rules.json`.

## Validation

```powershell
python scripts/validate_repo.py
python B:\Projects\LLM_Modules\Project_Ops_Capsule\scripts\capsule_doctor.py . --profile private_repo
```

Automated acceptance smoke test (47 checks — input bindings, movement, mining timing, tool-tier forge/gating, food loop + regrowth, population dynamics and bounds, lantern crafting, placement, torch light + occlusion, storm damage + roof mitigation, deposit, C/L/R reaction, threat event, save/load round trip incl. threat/storm/regrow persistence; saves a screenshot in windowed runs):

```powershell
$env:COHERONIA_SMOKE = "1"
& <path-to-godot-4.6> --path <this-repo-root>          # windowed, with screenshot
& <path-to-godot-4.6> --headless --path <this-repo-root>  # headless
```

Exit code 0 = all checks passed.

## Known limitations (v0.3)

- Placeholder art: colored tiles and `_draw()` rectangles; no animation or audio.
- Population is an abstract number (1–8); settlers are not simulated as NPCs.
- Two hazards (night slime, daytime storm); the slime has trivial movement (walk + hop), no pathfinding.
- Single save slot (`user://coheronia_save.json`). Save version 0.3; v0.1/v0.2 saves still load (new state simply absent).
- Torch crafting is hotkey-only (C); pick and lantern are crafted via the Town Hall panel. No general crafting menu.
- World is finite (240×80 tiles) with a single surface biome.

## Protocol

This repo is governed by the Project Ops Capsule (`.project/`, `_protocol/Project_Ops_Capsule/`):

```text
Every run records evidence; only signable runs update accepted truth.
```

Run ledgers live in `.project/runs/`; Atlas/BOH outbox packets in `.project/atlas_outbox/` and `.project/boh_outbox/`. Do not mutate `reference/g1v5/` or `_protocol/Project_Ops_Capsule/`. Do not push to GitHub automatically.
