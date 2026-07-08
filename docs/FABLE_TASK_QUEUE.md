# Coheronia Fable Task Queue

Status: planning queue for future Fable / Claude Code increments.

This queue starts from the signed v0.6 state. Fable should take one queue item
at a time, re-read the current repo state before editing, and close each item
with validator, capsule doctor, Godot smoke where relevant, docs, run ledger,
and outbox packets.

## Queue Rules

- Work from `B:\dev\Coheronia\coheronia_fable_oneshot_repo`, not the wrapper
  folder.
- Keep each item bounded. Do not combine unrelated systems into one giant pass.
- Prefer data-driven definitions for items, equipment, visual assets, ores,
  recipes, skill nodes, and stations.
- Preserve current v0.6 playability: shell, save/load, character inventory,
  mining, placement, Town Hall, C/L/R, enemies, XP, and smoke checks.
- Add smoke coverage for every new system boundary, especially save migration.
- Use the term ancestry in player-facing text.

## Recommended Order

| ID | Priority | State | Work Item | Why It Comes Here |
|---|---|---|---|---|
| FQ-00 | P0 | Done | v0.6.1 closeout repair | Clears known review issues before new work stacks on top. |
| FQ-01 | P0 | Done | Player health, damage, healing, and death loop | Combat, armor, enemies, magic, and UI all depend on clear survivability rules. |
| FQ-02 | P0 | Done | Background trees and pass-through flora | Fixes a high-friction traversal issue and sets up a true foreground/background world model. |
| FQ-03 | P0 | Done | Equipment data model and character-owned gear slots | Sword, tools, armor, rings, amulet, and accessory need one shared foundation before balancing. |
| FQ-04 | P1 | Done | First combat gear slice: sword, armor mitigation, toolbelt display | Turns equipment into visible gameplay without building every item tier at once. |
| FQ-05 | P1 | Done | Mana or Attunement system MVP | Establishes how magic users work before adding spells or ancestry-specific magic. |
| FQ-06 | P1 | Done | Visual player skill tree navigator | Player XP needs visible choices; start with navigation and one live lane. |
| FQ-07 | P1 | Done | Visual asset pipeline with color fallback | Lets art improve incrementally while preserving current simple-color rendering. |
| FQ-08 | P1 | Done | Block and enemy damage visuals | Makes mining/combat feedback readable before more combat depth arrives. |
| FQ-09 | P1 | Done | Visual inventory, toolbelt, and village panels | Converts text-heavy UI to image grids with labels and descriptors. |
| FQ-10 | P1 | Ready | More ores and metallurgy data | Expands mining goals, but should stay data-first before full forge balance. |
| FQ-11 | P1 | Ready after FQ-10 | Workbench, furnace, and anvil station chain | Makes ore useful through buildable progression stations. |
| FQ-12 | P1 | Ready | Farming and food stability | Current bush support groundwork is ideal for plantable crops and settlement food pressure. |
| FQ-13 | P2 | Ready after FQ-01 | Enemy variety and combat pressure | Add thornrat, ore tick, and raider torchbearer once health/combat rules are clearer. |
| FQ-14 | P2 | Ready | Goal panel, tutorial prompts, and playtest checklist | Raises playability by telling players what to do next. |
| FQ-15 | P2 | Ready after several systems | Map, scouting, and navigation | Larger worlds will need player orientation and exploration goals. |

## FQ-00 - v0.6.1 Closeout Repair

Goal: clean up the small issues found in v0.6 review before adding new systems.

Scope:

- Fix legacy pre-v0.6 character migration so importing old world inventory does
  not also duplicate role starter items.
- Add smoke coverage for the full legacy migration plus role-grant sequence.
- Update Atlas and BOH outbox packets with the real closeout commit hash.
- Align packet profiles with the public repo manifest.
- Remove the trailing blank line issue in the v0.6 work-order doc.

Likely files:

- `scripts/main/game_root.gd`
- `scripts/main/smoke_test.gd`
- `.project/atlas_outbox/20260704_coheronia_v06_increment.json`
- `.project/boh_outbox/20260704_coheronia_v06_increment.json`
- `docs/WORK_ORDER_V0_6_CHARACTER_INVENTORY_WORLD_TOOLS.md`

Acceptance:

- Old-format world inventory migrates once.
- Starter items do not duplicate during migration.
- `git diff --check` is clean.
- Validator, capsule doctor, and Godot smoke pass.

## FQ-01 - Player Health, Damage, Healing, And Death Loop

Goal: make player survivability a real loop rather than a hidden number.

Scope:

- Add clearer health UI: current/max health, recent damage feedback, low-health
  state, and recovery messaging.
- Decide and document the first healing sources: food, rest near the Town Hall,
  bandage/medicine later, or slow passive recovery only in safe conditions.
- Establish a simple death or collapse consequence: respawn at Town Hall,
  temporary debuff, dropped fraction of carried resources, or durability loss.
- Make enemy contact damage and invulnerability frames visible and tunable.
- Preserve ancestry health effects and save/load.

Likely files:

- `scripts/player/player.gd`
- `scripts/main/game_root.gd`
- `scripts/ui/hud.gd`
- `data/enemies.json`
- `data/character_data.json`
- `scripts/main/smoke_test.gd`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- Taking damage updates health UI and cannot instantly drain all health through
  repeated same-frame hits.
- Healing source works and is visible.
- Collapse/respawn path is deterministic and documented.
- Save/load preserves current health and max-health modifiers.

## FQ-02 - Background Trees And Pass-Through Flora

Goal: let the player walk past background trees instead of being forced to jump
over or chop through every tree.

Scope:

- Split trees into at least two concepts:
  - foreground wood blocks: solid, mineable, useful for building/crafting
  - background tree/flora visuals: non-solid, decorative, can be walked past
- Add a background visual layer behind player/world actors.
- Keep tree density meaningful without turning the surface into a wall.
- Decide whether background trees can be harvested through a separate action
  later; do not overbuild that in the first pass.

Likely files:

- `scripts/world/world_gen.gd`
- `scripts/world/world.gd`
- `data/blocks.json`
- `data/world_settings.json`
- `scripts/main/smoke_test.gd`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- Surface generation creates pass-through background trees.
- Player movement is not blocked by background trees.
- Foreground wood still exists, mines, drops wood, and supports axe behavior.
- Tree density slider affects the intended surfaces and smoke covers it.

## FQ-03 - Equipment Data Model And Character-Owned Gear Slots

Goal: create the shared equipment foundation before adding many gear behaviors.

Scope:

- Add a data-driven item/equipment definition surface.
- Add character-owned gear slots:
  - weapon
  - axe
  - pickaxe
  - helmet
  - torso
  - feet
  - ring_1
  - ring_2
  - ring_3
  - ring_4
  - amulet
  - accessory
- Preserve current pick and axe behavior through migration into the new gear
  shape.
- Keep backpack inventory separate from equipped gear.
- Add minimal UI showing equipped slots, even if no drag/drop exists yet.

Likely files:

- `data/items.json` or a new `data/equipment.json`
- `scripts/shell/game_state.gd`
- `scripts/save/save_manager.gd`
- `scripts/player/player.gd`
- `scripts/ui/hud.gd`
- `scripts/inventory/inventory.gd`
- `scripts/main/smoke_test.gd`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- Current characters migrate to starter pickaxe and current axe state without
  losing inventory.
- Gear slots save/load with the character across worlds.
- Empty slots are valid and visible.
- Smoke verifies at least one equipped item round-trips.

## FQ-04 - First Combat Gear Slice

Goal: make sword and armor matter in live gameplay.

Scope:

- Add a starter sword or crude sword item.
- Add simple melee attack behavior against current enemy scenes.
- Add armor mitigation from helmet, torso, and feet slots.
- Keep rings, amulet, and accessory as data/slot-ready but mostly inert unless
  one small test item is easy.
- Show weapon/armor state in the visual equipment UI.

Likely files:

- `data/equipment.json`
- `data/recipes.json`
- `scripts/player/player.gd`
- `scripts/entities/simple_threat.gd`
- `scripts/ui/hud.gd`
- `scripts/main/smoke_test.gd`

Acceptance:

- Sword can damage an enemy.
- Armor reduces incoming damage by a visible, data-defined amount.
- Equipment effects save/load and do not break ancestry health modifiers.

## FQ-05 - Mana Or Attunement System MVP

Goal: define the player magic resource before adding spells.

Preferred design direction: call the resource Attunement unless a better
Coheronia-specific term emerges. It should support magic users without making
non-magic ancestries feel wrong.

Scope:

- Add player resource fields: current attunement, max attunement, regen or
  recovery condition.
- Add data hooks for ancestry, equipment, and future perks to modify it.
- Add one harmless first active use, such as a small light pulse or self-heal,
  so the resource is testable.
- Do not add a full spellbook yet.

Likely files:

- `scripts/player/player.gd`
- `scripts/main/game_root.gd`
- `scripts/ui/hud.gd`
- `data/ancestries.json`
- `data/equipment.json`
- `scripts/main/smoke_test.gd`
- `docs/FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md`

Acceptance:

- Attunement displays, spends, recovers, and saves/loads.
- A non-magic character can still play normally.
- A future magic-user lane has a documented extension point.

## FQ-06 - Visual Player Skill Tree Navigator

Goal: make player progression navigable as a visual tree.

Scope:

- Add data-driven skill node definitions: id, lane, title, description,
  position, cost, prerequisites, effect key.
- Create a skill tree panel with pan/zoom or at least scrollable 2D layout.
- Start with one live lane, preferably Miner or Warden.
- Show locked, available, and purchased states.
- Do not implement every perk lane in one pass.

Likely files:

- `data/progression/perks.json`
- `scripts/data/progression_registry.gd`
- `scripts/ui/hud.gd` or a new `scripts/ui/skill_tree.gd`
- `project.godot`
- `scripts/main/smoke_test.gd`

Acceptance:

- Player can open the skill tree.
- A node can be selected and inspected.
- One perk can be purchased or marked available from real player XP.
- State persists and smoke verifies the core path.

## FQ-07 - Visual Asset Pipeline With Color Fallback

Goal: allow art to improve one asset at a time without breaking current simple
color rendering.

Scope:

- Add a data-driven visual reference per block, item, enemy, station, and
  possibly ancestry.
- If an image exists, render the image.
- If the image is missing, fall back to the current generated single-color or
  simple drawn shape.
- Create a standard asset-template folder with prompt notes, target sizes,
  naming rules, and review checklist for local Ollama/image-model iteration.
- Do not require Ollama to run inside the game or validation path.

Suggested paths:

- `art/source_templates/`
- `art/generated/blocks/`
- `art/generated/items/`
- `art/generated/enemies/`
- `art/generated/ui/`
- `data/visual_assets.json`

Likely files:

- `scripts/world/world.gd`
- `scripts/entities/simple_threat.gd`
- `scripts/ui/hud.gd`
- `scripts/validate_repo.py`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- Missing images do not crash and use the fallback.
- At least one block and one item can render from image if present.
- Validator reports missing optional assets as informational, not failure.
- Asset naming/template docs are clear enough for manual one-by-one art passes.

## FQ-08 - Block And Enemy Damage Visuals

Goal: make destruction readable before it completes.

Scope:

- Add mining damage stages for blocks, such as cracks or tint overlays.
- Add enemy hurt feedback: health bar, tint flash, shrinking/weakening posture,
  or visible damage stage.
- Keep block damage transient unless explicitly saved; do not create huge save
  files for every partially mined block unless required.
- Ensure visual damage resets when the player changes target or stops mining.

Likely files:

- `scripts/player/player.gd`
- `scripts/world/world.gd`
- `scripts/entities/simple_threat.gd`
- `scripts/ui/hud.gd`
- `scripts/main/smoke_test.gd`

Acceptance:

- A stone block visibly changes before breaking.
- Enemy damage is visible before death.
- Mining/combat visuals do not alter drop counts or save/load behavior.

## FQ-09 - Visual Inventory, Toolbelt, And Village Panels

Goal: replace text-heavy panels with icon grids and clear labels.

Scope:

- Inventory: grid of item icons with count and descriptor below or on hover.
- Toolbelt: icon slots with selected-slot highlight.
- Town Hall/village: visual stockpile grid, station buttons with icons, and
  clear disabled states.
- Use fallback visuals from FQ-07 when no asset has been supplied yet.
- Keep keyboard/mouse behavior simple and stable.

Likely files:

- `scripts/ui/hud.gd`
- `scripts/inventory/inventory.gd`
- `data/visual_assets.json`
- `data/items.json`
- `scripts/main/smoke_test.gd`

Acceptance:

- Inventory panel still opens with I and reflects current counts.
- Hotbar/toolbelt remains usable during play.
- Town Hall panel clearly shows stockpile and station actions.
- Smoke verifies counts after mine, craft, deposit, and load.

## FQ-10 - More Ores And Metallurgy Data

Goal: make mining progression richer before balancing the full station chain.

Scope:

- Add ore families as data, such as copper, iron, coal, tin, silver, crystal,
  and a generic rare ore placeholder.
- Update generation to support ore families by depth/band/noise channel.
- Keep current `ore` behavior compatible or migrate it cleanly to a starter
  ore.
- Add drops and display names; avoid making every ore immediately useful.

Likely files:

- `data/blocks.json`
- `data/world_settings.json`
- `scripts/world/world_gen.gd`
- `scripts/world/block_registry.gd`
- `scripts/validate_repo.py`
- `scripts/main/smoke_test.gd`

Acceptance:

- Several ore types generate at expected bands.
- Existing tier-2 pick ore gate still works.
- Smoke covers at least one common and one deeper ore.

## FQ-11 - Workbench, Furnace, And Anvil Station Chain

Goal: turn ores into a real crafting progression.

Scope:

- Add buildable or craftable stations:
  - workbench for basic recipes
  - furnace for smelting ore with fuel
  - anvil for metal tools, weapon, and armor crafting
- Gate ore use behind furnace outputs, such as ingots.
- Gate metal gear behind the anvil.
- Tie station presence to Town Hall/village UI without requiring complex NPCs.

Likely files:

- `data/blocks.json`
- `data/recipes.json`
- `scripts/settlement/town_hall.gd`
- `scripts/ui/hud.gd`
- `scripts/world/world.gd`
- `scripts/main/smoke_test.gd`

Acceptance:

- Player cannot use raw ore directly for metal gear.
- Furnace consumes ore plus fuel and produces an intermediate.
- Anvil consumes intermediates and creates a tool/gear item.
- Station state saves/loads.

## FQ-12 - Farming And Food Stability

Goal: add a reliable food path beyond berry bushes.

Scope:

- Add seeds, crop blocks, tilled/farm soil, and regrowth timers.
- Use the existing `requires_support` groundwork where appropriate.
- Tie crop harvest to food and settlement pressure.
- Add a simple farm or food-yard score for future base levels.

Likely files:

- `data/blocks.json`
- `data/recipes.json`
- `scripts/world/world.gd`
- `scripts/player/player.gd`
- `scripts/settlement/settlement_model.gd`
- `scripts/main/smoke_test.gd`

Acceptance:

- Player can plant, wait, harvest, and gain food.
- Food reserve affects settlement survival as before.
- Crops do not float or regrow into invalid cells.

## FQ-13 - Enemy Variety And Combat Pressure

Goal: make the world feel less empty and make combat systems matter.

Scope:

- Add one surface enemy, one underground enemy, and one raider variant:
  - thornrat
  - ore_tick
  - raider_torchbearer
- Give each a distinct role, spawn condition, damage profile, and drop.
- Keep density conservative until health/combat tuning is proven.

Likely files:

- `data/enemies.json`
- `scripts/data/enemy_registry.gd`
- `scripts/main/game_root.gd`
- `scripts/entities/simple_threat.gd`
- `scripts/main/smoke_test.gd`

Acceptance:

- Each new enemy can spawn in the intended condition.
- Each can damage or pressure the player/base in a distinct way.
- Drops enter inventory or stockpile correctly.

## FQ-14 - Goal Panel, Tutorial Prompts, And Playtest Checklist

Goal: make the game easier to play without external notes.

Scope:

- Add a compact current-goal panel.
- Surface early objectives:
  - gather wood/stone
  - light the hall
  - deposit resources
  - craft first tool/station
  - survive night
- Add a playtest checklist document for the operator.
- Keep prompts based on actual game state, not static tutorial text.

Likely files:

- `scripts/ui/hud.gd`
- `scripts/main/game_root.gd`
- `scripts/settlement/settlement_model.gd`
- `docs/PLAYTEST_CHECKLIST.md`
- `scripts/main/smoke_test.gd`

Acceptance:

- Goal panel advances from real state changes.
- Prompts can be hidden or are unobtrusive.
- Operator can play the first loop without reading the handoff doc.

## FQ-15 - Map, Scouting, And Navigation

Goal: prepare larger worlds for exploration.

Scope:

- Add a simple map or minimap panel.
- Track discovered surface/cave bands.
- Mark Town Hall, player, major ore pockets, and enemy pressure if known.
- Add scouting hooks for future perks.

Likely files:

- `scripts/world/world.gd`
- `scripts/main/game_root.gd`
- `scripts/ui/hud.gd`
- `data/progression/perks.json`
- `scripts/main/smoke_test.gd`

Acceptance:

- Player can open a map panel.
- Town Hall and player position are visible.
- Discovered state persists or is intentionally documented as transient.

## Additional Big-Ticket Playability Items

These are worth adding after the first queue wave, but they should not jump
ahead of FQ-00 through FQ-03 unless the operator explicitly changes priority.

| Item | Why It Matters | Best Prerequisite |
|---|---|---|
| Audio and hit/mining feedback | Makes repeated actions feel responsive. | FQ-08 |
| Pause/settings/keybinds panel | Necessary for longer play sessions. | Any time |
| Save-slot management | Safer testing across characters/worlds. | FQ-03 |
| Build preview and placement validity tint | Reduces frustration while building. | FQ-07 |
| Crafting search/filter | Needed once recipes grow. | FQ-11 |
| Local quest/contracts layer | Gives reasons to travel, fight, trade, and build. | FQ-14 |
| Subject/NPC labor MVP | Makes the settlement feel inhabited. | FQ-11 or FQ-12 |
| Weather readability | Storm danger should be visible before damage lands. | FQ-01 |
| Balancing dashboard | Speeds tuning for XP, ore, damage, hunger, raids. | Several systems live |

## Suggested First Fable Prompt

```text
You are working in B:\dev\Coheronia\coheronia_fable_oneshot_repo.

Read README.md, docs/HANDOFF.md, docs/VARIABLE_MATRIX.md, and
docs/FABLE_TASK_QUEUE.md. Take only FQ-00. Do not start new feature work.

Goal: close the v0.6.1 repair pass. Fix legacy character migration so old
world inventory does not duplicate role starter items; add smoke coverage for
that full path; update Atlas/BOH outbox packet metadata with the actual pushed
closeout commit and public repo profile; remove the EOF whitespace issue.

Validation:
- python scripts/validate_repo.py
- python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo
- COHERONIA_SMOKE=1 waited Godot run; verify user://smoke_results.json PASS
- git diff --check

Closeout: update docs only if behavior or evidence changed, write/adjust run
ledger evidence, and commit only after green validation.
```
