# Coheronia Work Order - v0.6 Character, Inventory, World Builder, Plants, Tools

Paste this prompt to Fable/Claude Code from the repo root:

```text
You are working in:
<repo-root>

Coheronia is currently at v0.5, signed and closed out. Your task is the next
bounded increment: v0.6 character identity, character-owned inventory,
openable inventory UI, world-builder clarity, berry-bush support rules, and a
small first pass at differentiated tools.

Do not restart the project. Do not create a new Godot project. Work with the
existing Godot 4.6.1 codebase and its Project Ops Capsule protocol.

Important current-state facts:
- The repo root is the inner folder above, not <workstation-path>
- Current state is documented in README.md, docs/HANDOFF.md, and
  docs/VARIABLE_MATRIX.md.
- v0.5 smoke is 90/90 and covers enemies, XP/base levels, ancestry effects,
  shell/world persistence, mining/placement, food/regrowth, and save/load.
- Existing character creation already has species, traits, role, and
  appearance, but the species/race choices do not explain their gameplay
  differences clearly enough.
- Existing player inventory is saved inside a world save. This means a
  character entering a world last played by another character can inherit that
  world's player inventory/state. v0.6 must correct that boundary.
- Existing HUD has a compact hotbar/toolbelt display, but there is no true
  openable inventory panel.
- Berry bushes are non-solid object blocks and can visually float if their
  supporting block is mined.
- Tools are currently represented mostly as player.tool_tier and a forged pick
  upgrade. v0.6 should introduce a small, data-aligned tool direction without
  building a giant equipment system.

Before coding:
1. Confirm repo identity:
   git status --short --branch
   git remote -v
2. Run baseline validation:
   python scripts/validate_repo.py
   python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo
   If plain python is unavailable on this machine, use:
   <python>
3. Read these files before implementation:
   README.md
   docs/HANDOFF.md
   docs/VARIABLE_MATRIX.md
   docs/GAME_FEATURE_OUTLINE.md
   data/character_data.json
   data/ancestries.json
   data/world_settings.json
   data/blocks.json
   data/recipes.json
   scripts/shell/shell_ui.gd
   scripts/shell/game_state.gd
   scripts/save/save_manager.gd
   scripts/player/player.gd
   scripts/inventory/inventory.gd
   scripts/ui/hud.gd
   scripts/world/world.gd
   scripts/world/world_gen.gd
   scripts/main/smoke_test.gd
4. Produce a short plan before edits. Keep the work in waves and commit after
   green verification for each wave.

Primary goals:

Wave A - Character creation race/ancestry details
- Add clear race/ancestry details to character creation.
- When the species/race option changes, show a compact detail panel sourced
  from data, not hardcoded duplicate prose.
- The panel should include:
  - display name and description
  - live v0.5 player effects, such as human XP bonus, dwarf mining/move/jump
    changes, elf jump, orc health, goblin health reduction
  - any important weaknesses/tradeoffs
  - spawn band or future/deep ancestry note when relevant
  - biome affinity summary if it can be made compact
- Character select rows may also show a small summary of ancestry and role.
- Keep non-live/deep ancestry text honest: if it is not playable yet, label it
  as planned/reserved rather than implying it works.

Target files likely include:
data/character_data.json
data/ancestries.json
scripts/data/ancestry_registry.gd
scripts/shell/shell_ui.gd
scripts/main/smoke_test.gd

Wave B - Character-owned inventory across worlds
- Move the source of truth for character-carried inventory out of world state
  and into character state in user://shell.json.
- Minimum character-owned fields:
  - inventory counts
  - selected hotbar/toolbelt slot
  - tool state or tool ids/tier, depending on the tool design chosen in Wave E
- Strongly consider whether player XP and player_level should also be
  character-owned. If you keep XP world-owned for v0.6, document that decision
  explicitly in HANDOFF and VARIABLE_MATRIX.
- Starter role items must be granted once per character, not once per new world.
  Avoid duplicating homesteader items every time a character enters an empty
  world.
- Entering a world as character A must load A's carried inventory. Entering the
  same world as character B must load B's carried inventory. A world should not
  transfer one character's backpack to another.
- World state should continue to own terrain, Town Hall stockpile, time,
  threats, storm state, base/settlement state, and world summary.
- Preserve backward compatibility:
  - Old world saves that still contain player.inventory should not crash.
  - Old characters without carried inventory should get sane defaults.
  - Migration should be conservative and documented.
- F5 save, Esc save-to-shell, and any relevant explicit save path should persist
  both the world state and the current character-carried state.

Target files likely include:
scripts/shell/game_state.gd
scripts/save/save_manager.gd
scripts/main/game_root.gd
scripts/player/player.gd
scripts/inventory/inventory.gd
scripts/main/smoke_test.gd

Acceptance checks for this wave:
- Smoke creates two characters and one world; each character keeps a distinct
  inventory when entering/leaving the same world.
- Character A's inventory survives entering a second world.
- Role starter items are not duplicated on repeated entry.
- Old/missing character inventory defaults cleanly.

Wave C - True openable inventory in addition to toolbelt
- Keep the current hotbar/toolbelt as quick-use slots.
- Add an openable inventory panel, toggled by a new input action such as I.
- The panel should show all carried item stacks, not only the current hotbar
  and extra food/ore.
- The panel should be usable while playing:
  - open/close reliably
  - show current counts after mining, drops, crafting, deposits, and loads
  - not break Town Hall panel behavior
- Do not overbuild drag/drop if time is tight. A readable, openable inventory
  panel is enough for v0.6. If toolbelt assignment is added, keep it simple and
  test it.

Target files likely include:
project.godot
scripts/ui/hud.gd
scripts/player/player.gd
scripts/main/game_root.gd
scripts/main/smoke_test.gd

Wave D - World builder details
- Add further details to the world creation screen so players understand what
  presets and sliders actually do.
- For presets, show the selected preset description and/or notable difficulty,
  rule, and generation changes.
- For size, show dimensions or practical meaning.
- For difficulty axes, show short, concrete effects:
  - enemy: threat count/hp/spawn pressure
  - ruler: population pressure
  - survival: food demand/storm pressure
  - economy: stockpile/scarcity scaling
  - social: stored/reserved for later social simulation
  - impressionability: population growth threshold
- For generation sliders, explain terrain, ore, tree, bush, and dirt-depth
  effects without overwhelming the screen.
- Keep this screen compact and scrollable. Avoid a lore wall.

Target files likely include:
data/world_settings.json
scripts/shell/world_config.gd
scripts/shell/shell_ui.gd

Wave E - Berry bush support rule
- Fix berry bushes floating when the block underneath is mined.
- Define and implement a simple support rule:
  - berry_bush requires a solid support block directly below, or
  - berry_bush breaks/harvests when unsupported and schedules/handles regrowth
    consistently.
- Apply this rule when:
  - a support block is mined
  - terrain is loaded from deltas
  - a bush regrows
  - a player places/removes blocks around plants, if relevant
- Preserve current food loop and regrowth behavior unless the support rule
  requires a small documented change.

Target files likely include:
scripts/world/world.gd
scripts/world/world_gen.gd
data/blocks.json
scripts/main/smoke_test.gd

Acceptance checks for this wave:
- Mine the block directly below a berry bush; the bush does not remain floating.
- Save/load after unsupported-bush cleanup does not resurrect a floating bush.
- Regrowth does not place a bush into unsupported air.

Wave F - Additional tools, first playable slice
- Add a small first pass for differentiated tools. Do not build a giant gear
  system yet.
- Preserve existing pick progression and ore gate.
- Recommended v0.6 slice:
  - represent at least a pickaxe and axe as carried tools/items
  - pickaxe remains best for stone/ore
  - axe improves wood/tree/plant harvesting
  - existing forged pick upgrade should still work or migrate cleanly to the
    new tool representation
  - expose current equipped/available tool state in the hotbar/inventory UI
- Prefer data-driven shape where practical:
  - data/blocks.json may gain preferred_tool or tool_tags
  - data/recipes.json may gain tool recipes/upgrades
  - player.gd should avoid hardcoded one-off branches if a small data helper is
    cleaner
- Award existing craft/labor XP consistently for tool use/crafting.

Target files likely include:
data/blocks.json
data/recipes.json
scripts/player/player.gd
scripts/world/block_registry.gd
scripts/settlement/town_hall.gd
scripts/ui/hud.gd
scripts/save/save_manager.gd
scripts/main/smoke_test.gd

Acceptance checks for this wave:
- Pickaxe behavior remains at least as good as v0.5 for dirt/stone/ore.
- Axe has a visible gameplay effect on wood or plant harvesting.
- Save/load preserves tool state.
- Existing tier-2 pick/ore flow remains green.

Non-goals for v0.6:
- No full NPC simulation.
- No complex equipment paper-doll.
- No drag/drop inventory grid unless it falls out cheaply.
- No full research bench or perk spending UI.
- No new biome generation.
- No multiplayer/cloud save/online services.
- No broad art pass.

Validation and closeout:
- Extend scripts/validate_repo.py for any new data fields/files.
- Extend scripts/main/smoke_test.gd with checks for:
  - ancestry detail data/selection path where feasible
  - character inventory isolation across worlds
  - openable inventory panel toggle/update behavior
  - berry bush support cleanup
  - tool differentiation and tool save/load
- Run:
  python scripts/validate_repo.py
  python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo
- Run Godot smoke using the local Godot binary:
  $env:COHERONIA_SMOKE = "1"
  Start-Process -FilePath "<godot-binary>" -ArgumentList @("--path", "<repo-root>") -Wait
  Then verify user://smoke_results.json reports PASS.
- Update README.md, docs/HANDOFF.md, docs/VARIABLE_MATRIX.md.
- Write a new .project/runs/<run-id>.md ledger with exact evidence.
- Queue Atlas/BOH outbox packets if the repo protocol expects them; otherwise
  explicitly document deferral.
- Commit in coherent commits. Do not push until the final smoke and protocol
  closeout are green.

Recommended commit split:
1. v0.6 Wave A/D: shell creation details and world builder details
2. v0.6 Wave B/C: character-owned inventory and openable inventory UI
3. v0.6 Wave E/F: supported plants and first differentiated tools
4. v0.6 closeout: docs, run ledger, validation evidence
```
