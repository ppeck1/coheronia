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
| FQ-09R | P0 | Done | Review hardening: unified trees, creation-rule clarity, no new mechanics | Fix current review findings before adding ore/furnace/farming systems. |
| FQ-09S | P0 | Done | Skill tree visual treatment pass | Improve the existing skill tree presentation without adding new progression mechanics. |
| FQ-09V | P1 | Done | Visual variant pipeline | Adds deterministic per-id sprite variety without bloating saves or changing mechanics. |
| FQ-09C | P0 | Done | Canon lock, art-direction bible, and opening cinematic | Establishes what the game means, how it looks, and `By Paul Peck` before further asset or feature work. |
| FQ-09W | P0 | Done | Scene backdrops, underground darkness, and backing-wall foundation | Fixes global daylight underground and creates fallback-safe visual planes before final environment art. |
| FQ-09A | P1 | Done | Future asset manifest and prompt packs | Gives future art/model agents a concrete asset map after the opening/background runtime contracts are real. |
| FQ-09M | P1 | Done | Lightweight action animation pass | Makes actions readable while preserving existing timing, saves, and mechanics. |
| FQ-09U1 | P1 | Done (operator listening approval 2026-07-10; spike executed in-lane) | Adaptive context music foundation | Seamless bar-quantized day/night/underground/crisis music from existing game truth; the hybrid adaptive score's horizontal layer. |
| FQ-09U2 | P1 | Done | Settlement-responsive music layering | Synchronized stems weighted by pressure/Coherence/Resilience/Attunement; the vertical layer. |
| FQ-09U3 | P2 | Done | Music stingers, ducking, and audio settings | Event one-shots over brief ducking, volume settings, pause behavior, final asset validation. |
| FQ-10 | P1 | Done | More ores and metallurgy data | Expands mining goals after the presentation-foundation sequence closes. |
| FQ-11 | P1 | Done | Workbench, furnace, and anvil station chain | Makes ore useful through buildable progression stations. |
| FQ-12 | P1 | Done | Farming and food stability | Current bush support groundwork is ideal for plantable crops and settlement food pressure. |
| FQ-13 | P2 | Done | Enemy variety and combat pressure | Add thornrat, ore tick, and raider torchbearer once health/combat rules are clearer. |
| FQ-13P0 | P2 | Done | Visual asset & variant audit | Runtime audit (`docs/UI_ASSET_GAPS.md` + `scripts/asset_audit.py`) + player-variation decision. Gates P1–P4. |
| FQ-13P1 | P2 | Done | Consume enemy variant pools | Deterministic, lifetime-stable per-enemy sprite variants via `simple_threat._select_sprite`; audit now 0 findings. |
| FQ-13P2 | P2 | Done | UI placeholder art + slot hook | 15 generated UI placeholders (`gen_ui_placeholders.py`); hotbar slot frames consume `slot_inventory*`; audit UI-aware. |
| FQ-13P3 | P2 | Done | Player full-body cosmetic pool | Character-owned `visual_variant` (never world-saved); `player_visual` variant selection; demo `human` pool; creation "Look" control. |
| FQ-13P4 | P2 | Done | Opening/block variation follow-through | Opening variant-vs-animation-frame distinction (`frame_semantics`); item-icon stability; audit animation-aware. Closes the FQ-13P arc. |
| FQ-14 | P2 | Done | Goal panel, tutorial prompts, and playtest checklist | State-driven current-goal panel (prefix-latching), toggle_goals (O), docs/PLAYTEST_CHECKLIST.md. |
| FQ-15 | P2 | Done | Map, scouting, and navigation | Schematic map panel (M), discovered bands persisted, hall/player/ore/threat markers, biome_reveal scouting hook. |
| FQ-16 | P1 | Done | Blueprint player-state dock | Single bottom dock with live health/attunement vessels, five-slot toolbelt, safe margins, and modal dock hiding. |
| FQ-17 | P1 | Done | Configurable nonmodal HUD layout | Default-locked Crest/Goal/Events/Map/Edit profile with bounded move, discrete scale, lock, reset, and visibility persistence. |
| FQ-18 | P1 | Done | HUD navigation and Character summary | Dock action buttons for Inventory/Character/Skills/Town Hall, centered read-only Character panel, modal exclusion, and smoke coverage. |
| FQ-19 | P1 | Done | Blueprint art-consumer and contextual information pass | Final dock/orb/slot/button art consumed (`gen_hud_final_art.py`); masked liquid vessels with damage/recovery/low/regen/use/core effects; framed Crest/Goal/Events with the exact clock; contextual right-band stack (item/save/interact); `canvas_items` stretch renders the same composition at 640×360 and 1280×720. Mini-map stays schematic (final art deferred). |
| FQ-20 | P1 | Done | HUD command center, direct manipulation, painted chrome | Painted mockup chrome sliced into `ui_painted/` (`slice_hud_chrome.py`) and consumed everywhere with fallbacks (dock plate, orbs, slots, glyph buttons, crest medallion, module frames, mini-map border, chips); module toggles moved INTO the dock (command center; corner toolbar retired); edit mode = direct drag + corner-grip continuous resize (locks removed, layout v3). Two operator polish loops: real liquid drain (nine-patch squash bug), systematic padding, slot corners, orb extraction fixes. |
| FQ-21 | P1 | Done | One-piece full-width dock band | The dock is FOUR native-aspect mockup pieces (left cap · mirror-tiled plate · fixed center block with a uniformly rebuilt slot track · right cap) spanning the viewport edge-to-edge — nothing stretched, nothing color-keyed. Slicer writes `dock_band_geometry.json`; hud.gd loads it (no hand-synced coordinates). Vessel sockets (`vessel_socket`/`replace_vessel_fill`) are the plug-in point for the planned liquid mechanics. Values render ON the glass; nav buttons are invisible zones over the baked art; runtime selection is a gold frame overlay. |

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

## FQ-09R - Review Hardening: Unified Trees, Creation Rules, No New Mechanics

Goal: close current review findings before new systems are stacked on top.

Scope:

- Tree model:
  - Replace the split behavior with one consistent tree rule: all generated
    trees should have leaves, let the player walk in front of/past them, and
    be harvestable.
  - Do not leave one class of tree as "walk past but not harvestable" and
    another as "solid harvestable trunk"; that makes the world rules feel
    arbitrary.
  - Use the existing mining/axe/wood-drop concepts where possible. The goal is
    to make trees consistent, not to add a separate forestry or chopping
    minigame.
  - Tree visuals should read as trees at 8-16bit scale: trunk plus leaves, with
    enough depth layering that the player can pass in front of them.
- Character/world creation:
  - Surface already-live rules in creation or adjacent help text where relevant:
    character-owned carried inventory, role starter grants once, equipment
    follows the character, inventory loss on collapse/death, and world-owned
    position/health/progression.
  - Avoid implying that future mechanics already exist.
- Hardening rule:
  - Do not add new mechanics in this pass. Reuse existing inputs, panels, log
    messages, data fields, and smoke hooks.

Likely files:

- `scripts/world/world_gen.gd`
- `scripts/world/world.gd`
- `scripts/main/game_root.gd`
- `scripts/main/smoke_test.gd`
- `scripts/shell/shell_ui.gd`
- `scripts/data/ancestry_detail.gd`
- `data/world_settings.json`
- `docs/HANDOFF.md`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- Smoke proves generated trees have leaves.
- Smoke proves the player can walk in front of/past trees without collision.
- Smoke proves trees are harvestable through the existing mining/axe path and
  still yield wood.
- Creation/help text mentions already-live collapse inventory loss and
  character/world ownership boundaries.
- Validator, diff check, and Godot smoke pass.

## FQ-09S - Skill Tree Visual Treatment Pass

Goal: make the existing skill tree feel like a Skyrim-style star map filtered
through an 8-16bit Coheronia aesthetic, without adding new perks, currencies,
or progression rules.

Scope:

- Keep `data/progression/perks.json`, point rules, prerequisite rules, save
  ownership, and live Miner-lane behavior unchanged unless a review bug is
  found.
- Rework only presentation and navigation:
  - dark sky/deep cave backdrop
  - pixel/star node styling
  - faint constellation links between prerequisites
  - clear owned/available/locked states
  - small icons or glyph-like labels if they use existing/fallback art rules
  - readable inspector text and purchase button state
- Preserve keyboard/mouse behavior: K opens/closes, Esc closes first, click
  selects, Learn buys only through the current `try_purchase_perk` path.

Likely files:

- `scripts/ui/skill_tree_panel.gd`
- `data/progression/perks.json` only if wording needs clarification
- `scripts/main/smoke_test.gd`
- `docs/HANDOFF.md`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- The panel visually reads as a star/constellation tree at 8-16bit scale.
- Existing smoke checks for purchase, persistence, state, and inspection still
  pass.
- New smoke or test hooks cover any added visual state that affects behavior.
- No new live mechanics, no new perk effects, no new progression economy.

## FQ-09V - Visual Variant Pipeline

Goal: let one data id have multiple optional visual variants so terrain and
items look less repetitive without adding save bloat or changing gameplay.

Scope:

- Extend the FQ-07 image-first pipeline to support optional variant pools per
  visual id, such as four dirt block sprites or several stone/grass/wood
  treatments.
- Select block variants deterministically from world seed and cell position so
  the same world renders the same visual variety without recording variant
  choices in saves.
- Keep the current one-file convention (`art/generated/<category>/<id>.png`)
  valid as the default path.
- Add a clear convention for variant files, such as
  `art/generated/blocks/dirt_01.png` through `dirt_04.png`, or explicit pools
  in `data/visual_assets.json`.
- Preserve fallback behavior: missing variants or missing pools must use the
  existing single asset/fallback color path.
- Do not add new blocks, ores, stations, crops, enemies, or balance changes in
  this pass.

Likely files:

- `data/visual_assets.json`
- `scripts/world/block_registry.gd`
- `scripts/world/world.gd`
- `scripts/validate_repo.py`
- `scripts/main/smoke_test.gd`
- `art/source_templates/ASSET_TEMPLATE.md`
- `docs/HANDOFF.md`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- A block id can resolve several variant images when present.
- Variant selection is deterministic by world seed/cell and does not enter the
  save format.
- A one-image asset still works exactly as before.
- Missing variants fall back cleanly.
- Smoke covers deterministic selection and fallback behavior.

## FQ-09C - Canon Lock, Art Direction, And Opening Cinematic (Done)

Goal: make Coheronia's founding identity visible before the title menu and
lock the narrative/art rules that later image work must follow.

Work order:

- `docs/WORK_ORDER_FQ_09C_CANON_ART_PROLOGUE.md`

Authority docs:

- `docs/ART_DIRECTION_AND_CANON.md`
- `docs/OPENING_STORYBOARD.md`

Shipped as an eight-scene, ~42s "Coheronia DOS Vector Cinematic" with a
puppet acting layer: authored at 640x360 on a SubViewport, integer-scaled 2x
nearest, plotted per tick by a deterministic 10 Hz `(scene, tick) -> draw
commands` renderer (`scripts/shell/prologue_canvas.gd`) driven by a
data-driven controller (`scripts/shell/prologue.gd`), with articulated
keyframed figures (`scripts/shell/prologue_puppets.gd`) that walk in,
gesture, patrol and freeze, hammer with strike sparks, raise the roof beam,
kneel to source the attunement pulse, and work the settlement — plus hard
integer-zoom camera cuts. Every scene genuinely animates; no image files are
used or required. A per-scene cel-shot hook (FQ-09V frame pools under
`art/generated/opening/`) lets future hand-authored animation replace any
shot at 8 fps without touching the sequence.

Acceptance (all proven by smoke + waited GUI passes):

- Exact scene order/copy/timing match `docs/OPENING_STORYBOARD.md` (42.0s).
- Clean-profile autoplay, completion, Escape skip (stops clock and audio),
  single-step advance, title-menu replay, and seen-flag behavior are proven.
- `COHERONIA`, `By Paul Peck`, and `Where civilization pushes back.` are
  engine-rendered on the title card and the persistent title screen.
- `COHERONIA_SMOKE=1` and `COHERONIA_SHOTS=1` keep deterministic entry;
  `COHERONIA_PROLOGUE_DEBUG=1` gives shortened review sessions.
- Placeholder-safe audio cue hooks resolve `res://audio/opening/<cue>.ogg`
  when present; absent audio never blocks or crashes the cinematic.
- Validator, capsule doctor, full Godot smoke, and `git diff --check` pass.

## FQ-09W - Scene Backdrops, Underground Darkness, And Backing Walls (Done)

Goal: give the side-view world deliberate scenic depth and stop global
daylight from making mined underground space appear sunlit.

Shipped: a scenic backdrop plane (`scripts/world/world_backdrop.gd` — sky
gradient to the deepest valley line, far/mid silhouette strips with stepped
parallax, light_mask 0, optional `art/generated/backgrounds/` hooks), a
`BackgroundWalls` TileMapLayer (dirt/stone wall tiles derived from the
pristine generated surface + dirt depth each setup — zero physics/occlusion
layers, never saved, `art/generated/back_walls/` hooks with darkened-block
fallbacks), and depth-aware ambient: a live column-skylight model
(`world.sky_line(x)`, cached, invalidated per column on block change) drives
`game_root.ambient_target_color()` from the day/night/storm base toward
`CAVE_TINT` over a 6-cell fade band — mining an open shaft re-admits
daylight; a sealed column at the same depth stays dark. Documented
approximation: no lateral light bleed (directional-shadow sunlight was
assessed and rejected for this slice — occluders are tileset-level and only
on blocks_light blocks). 7 fq09w_* smoke checks (suite 210); screenshot tour
gained `09_underground_midday_torch`.

Planning authority:

- `docs/ART_DIRECTION_AND_CANON.md` (Environment Planes)
- `art/source_templates/BACKGROUND_TEMPLATE.md`

Scope:

- Add a cosmetic scenic-backdrop plane behind the world with code-drawn
  fallback plus optional surface/parallax image hooks.
- Add a dedicated non-colliding `BackgroundWalls` TileMapLayer behind the
  existing foreground Blocks layer.
- Generate natural dirt/stone backing walls deterministically from seed and
  terrain so mining foreground blocks reveals a cave wall rather than the
  default clear viewport.
- Keep first-slice natural walls immutable and derived; do not add wall drops,
  placement, removal, `wall_deltas`, or a save-version change yet.
- Replace day-white underground ambience with roof-aware sunlight if Godot
  directional shadows are reliable against the existing block occluders.
  Use a smooth depth-aware ambient fallback only if that path is demonstrably
  unreliable, and document the approximation.
- Add fallback-safe planned asset categories/paths for full-scene backgrounds
  and 16 x 16 backing-wall tiles.
- Add a midday underground-with-torch verification shot.
- Do not resurrect retired FQ-02 background flora or `background_cells`.

Likely files:

- `scenes/world/World.tscn`
- `scripts/world/world.gd`
- `scripts/world/world_gen.gd`
- new `scripts/world/world_backdrop.gd`
- `scenes/main/Main.tscn`
- `scripts/main/game_root.gd`
- `data/visual_assets.json`
- `art/source_templates/BACKGROUND_TEMPLATE.md`
- `scripts/main/smoke_test.gd`
- `scripts/main/screenshot_tour.gd`
- `docs/HANDOFF.md`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- Surface view has an intentional fallback backdrop with no blank edges.
- A mined underground chamber reveals backing walls while foreground
  `block_at` remains air and collision/mining behavior is unchanged.
- Underground space is visibly dark at midday; torches and lanterns brighten
  it locally; an open shaft can admit roof-aware sunlight when supported.
- Backing walls have no foreground collision, drops, deltas, settlement tags,
  or shelter/light-score effects.
- Same seed/config produces the same natural backing-wall map.
- Old world saves load unchanged; no wall state is falsely persisted.
- Missing optional images return to code-drawn fallbacks.
- Existing night/storm, torch, save, smoke, and screenshot behavior remains
  green.

Deferred follow-on: player-placeable/removable constructed walls with their
own wall deltas, drops, recipes, save migration, and daylight semantics. Do not
hide that larger gameplay boundary inside this visual-foundation slice.

## FQ-09A - Future Asset Manifest And Prompt Packs (Done)

Goal: give future human and LLM art passes a concrete asset map covering live
assets and planned near-term content before new systems multiply the art needs.

Shipped as `docs/ASSET_ROADMAP.md` (validator-required, with locked
live/planned separation and the no-baked-text rule): pipeline facts for any
art agent, live tables for every renderable id (blocks, items, enemies,
equipment icons, back walls, backgrounds, opening cel-frame scenes) with
path/size/transparency/fallback/priority/prompt-note columns, the
drawn-shape actors that still need a renderer extension (player, town hall,
pulse), honest planned tables keyed to their queue items, and per-category
prompt packs under a shared style preamble derived from
`docs/ART_DIRECTION_AND_CANON.md`. Decision recorded: no
`data/asset_manifest.json` — nothing consumes one; the roadmap is the
manifest.

Scope:

- Add an asset roadmap or manifest, preferably `docs/ASSET_ROADMAP.md` for
  human readability plus `data/asset_manifest.json` only if code/validation
  will consume it.
- List live asset ids from current data: blocks, items, enemies, equipment,
  UI icons, and any current player/shell visual surfaces that are still drawn
  shapes.
- List planned near-term ids from the queue and future docs: ore families,
  station blocks, ingots, crops/seeds, enemy variants, tools, armor, UI icons,
  player/ancestry sprites, and action-effect sprites.
- Include the locked prologue panel ids, scenic background layers, and backing
  wall ids from `docs/OPENING_STORYBOARD.md` and
  `art/source_templates/BACKGROUND_TEMPLATE.md`.
- Treat `docs/ART_DIRECTION_AND_CANON.md` as the style/meaning authority for
  every prompt pack; do not reinvent tone, palette roles, or magic language.
- For each entry, record category, data id, intended file path, target size,
  transparency/opacity rule, current fallback behavior, priority, and prompt
  note.
- Add prompt-pack sections that another LLM/image model can use without
  inventing naming rules.
- Keep the manifest honest: planned items must be marked planned, not live.

Likely files:

- `docs/ASSET_ROADMAP.md`
- `art/source_templates/ASSET_TEMPLATE.md`
- `data/visual_assets.json` only if needed for examples
- `scripts/validate_repo.py` only if a machine-readable manifest is added
- `docs/HANDOFF.md`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- The roadmap separates live assets from planned assets.
- Naming and prompt instructions are specific enough for another LLM to create
  candidates without extra repo archaeology.
- Future planned items include ore, furnace/anvil/workbench, crops, enemies,
  tools, armor, UI icons, player/ancestry sprites, and action visuals.
- Opening, scenic-background, and backing-wall entries follow their locked
  dimensions, transparency, fallback, layering, and no-baked-text rules.
- Validator remains green; any new manifest schema is validated if introduced.

## FQ-09M - Lightweight Action Animation Pass (Done)

Goal: add readable action motion/feedback while preserving the current gameplay
timing, save ownership, and mechanics.

Shipped: one reusable self-freeing effect node (`scripts/fx/action_fx.gd` —
five deterministic stepped-10 Hz kinds in the "action_fx" group, all under
0.4 s) plus a stepped tool-swing arc in `player._draw` (pick/axe glyph
cycling raise/mid/strike with mining progress toward the target side;
`swing_phase()` hook, -1 when idle). Wired: placement pulse on
`try_place` success, cast ring at the attunement fire moment, hit sparks on
player and enemy landed hits, dust at collapse fall/respawn and enemy death,
and one `_craft_confirm_fx` choke point for all four hall forges (at the
hall) and hand crafting (at the player). Zero timing/drops/damage/save
changes — all pre-existing baselines pass unchanged. 7 `fq09m_*` smoke
checks (suite 217).

Scope:

- Add small presentation-only animations for common actions:
  - mining/chopping swing or tool arc
  - block placement pulse
  - attunement pulse cast/readability
  - player hurt/collapse feedback
  - enemy hit feedback if FQ-08 visuals need polish
  - crafting/forge confirmation feedback
- Keep animations lightweight: timers, tweens, code-drawn effects, or optional
  FQ-07/FQ-09V art hooks are fine; no new animation framework unless the local
  codebase clearly wants it.
- Do not change mining frame counts, damage numbers, drops, recipes, save data,
  or input bindings.
- Respect reduced visual clutter: actions should become easier to read, not
  noisier.

Likely files:

- `scripts/player/player.gd`
- `scripts/entities/simple_threat.gd`
- `scripts/world/world.gd`
- `scripts/ui/hud.gd`
- `scripts/settlement/town_hall.gd`
- `scripts/main/smoke_test.gd`
- `data/visual_assets.json` only for optional effect hooks
- `docs/HANDOFF.md`
- `docs/VARIABLE_MATRIX.md`

Acceptance:

- Mining/chopping/placing/casting/hurt/crafting actions have visible feedback.
- Existing behavior and smoke expectations for timing, drops, combat, and
  saves remain green.
- Any animation state is transient and does not enter world or character saves.
- Smoke or test hooks prove at least the behavior-preserving paths and any
  exposed visual state that could affect gameplay.

## FQ-09U1 - Adaptive Context Music Foundation (Done)

Authority: `docs/WORK_ORDER_FQ_09U_ADAPTIVE_MUSIC.md` (operator-approved
hybrid adaptive score) + `audio/source_templates/MUSIC_TEMPLATE.md` +
`data/music_manifest.json`.

Gates cleared: the operator approved the rendered suite by listening
("Music is beautiful") on 2026-07-10, and the Godot 4.6 spike was executed
in-lane in two parts — a headless ClassDB probe of the real binary
(AudioStreamInteractive clips/transitions/constants,
AudioStreamPlaybackInteractive.switch_to_clip_by_name +
get_current_clip_index, AudioStreamSynchronized per-stream volumes) and a
live in-smoke behavior proof (fq09u1_live_clip_switch: a next-bar
same-position crossfade genuinely reached the requested clip during real
playback). The Synchronized-inside-Interactive nesting question remains
FQ-09U2's opening spike.

Shipped: `scripts/audio/music_manifest.gd` (dedicated loader — OGGs via
AudioStreamOggVorbis.load_from_file, no import pass, musical grid stamped
onto each stream), `scripts/audio/adaptive_music_director.gd` +
`scenes/audio/AdaptiveMusicDirector.tscn` under Main (ContextPlayer live;
LayerPlayer/StingerPlayer reserved), a runtime-created Music bus,
crisis > underground > surface_night > surface_day resolution from existing
game truth (0.5 s poll + the settlement `updated` signal; storms feed
pressure), data-defined hysteresis (0.60/2 s enter, 0.35/6 s exit) with a
one-bar minimum hold and no re-requests, deterministic `evaluate(state,
delta)` for tests, debug/smoke accessors, and silent-safe missing-asset
behavior. Music state is transient — save round-trips carry no music keys.
9 fq09u1_* smoke checks (suite 226).

## FQ-09U2 - Settlement-Responsive Music Layering (Done)

Opened with the mandated spike, finding RECORDED: an
AudioStreamSynchronized group DOES play as a clip inside an
AudioStreamInteractive in Godot 4.6.1 (fq09u2_nesting_spike_recorded,
live playback probe). U2 nevertheless ships the parallel design — the
suite has ONE shared phase-locked stem set, not per-context sets — with
nesting available to future increments.

Shipped: the LayerPlayer carries an AudioStreamSynchronized of the six
stems (runtime-validated to the exact 53.333 s grid length; any mismatch
disables layering with a warning while context music plays on), started in
the same frame as the context stream so equal-length loops stay
phase-aligned by construction. Data-defined mix (`stem_mix` in the
manifest): each stem's volume moves smoothly (6 dB/s, never snapping)
toward lerp(min_db, max_db, source) where sources are settlement
resilience (foundation), coherence (hearth), the director's pressure score
(pressure stem, with a storm floor as the storm texture), player
attunement ratio (attunement), mining/movement activity (motion), and the
collapse edge (fracture wakes only past pressure 0.7). Debug hooks:
layering_enabled / stem_targets / stem_volumes. No save keys.
8 fq09u2_* smoke checks (suite 234), all deterministic except the live
nesting probe.

## FQ-09U3 - Music Stingers, Ducking, And Audio Settings

Dawn/nightfall/raid/Attunement/base-advance stingers over temporary
music-bus ducking (never stopping the music); music/SFX volume settings;
pause behavior; final audio asset validation (exact duration and sample
rate). Details in the work order.

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

## FQ-15 - Map, Scouting, And Navigation  [DONE]

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

## Presentation Recovery Arc (Active)

FQ-00 through FQ-21 are complete (see the table above). The active work is
the presentation recovery arc planned in
`docs/PRESENTATION_RECOVERY_MATRIX.md` -- that file is the row-level
authority for scope, lanes, and acceptance. Summary:

| ID | Lane | Row | State |
|---|---|---|---|
| PR-00 | code | Smoke harness truth repair (`fq17_hud_edit_direct_manipulation`, `fq09_inventory_board_drag_and_sort`) | Done 2026-07-20 |
| PR-01 | code | Terminology migration: canonical `masculine`/`feminine`, legacy aliases `default`/`female` (no PNG renames) | Done 2026-07-20 |
| PR-02 | code | Character preview/rendering contract (`docs/CHARACTER_RENDERING_CONTRACT.md`) | Done 2026-07-20 |
| PR-03A | code | Gear overlay resolution/refresh hardening (effective body id + refresh boundaries) | Done 2026-07-20 |
| PR-03B | code | Gear overlay alignment (goblin/dwarf helmet float) -- data-owned per-rig/slot `gear_offset` | Done 2026-07-20 |
| PR-04 | code + art | Directional action animation (code: anchors/mirroring/timing with existing art; art: new frames via image matrix) | Planned |
| PR-05 | code | Menu and character-selection preview through the shared render path | Planned |
| PR-06 | code + art | Character HUD rebuild on runtime children | Planned |
| PR-07 | code | Backdrop seam/contour skirt | Planned |
| PR-08 | code | Skill panel resize | Planned |
| PR-09 | code | Later skill expansion | Deferred (after PR-08) |
| PR-10 | art | HUD chrome/image follow-up via the HUD Asset Replacement Studio | Art lane only |

Lane rule: `code` rows are Claude/code-safe (code, data contracts,
validators, diagnostics, docs). `art` rows require separate image
production and are queued in the matrix's image-production follow-up table
with exact asset ids, sizes, defects, contract paths, and acceptance
checks -- a code lane never produces final PNGs.

## Current Fable Continuation

```text
You are working in B:\dev\Coheronia\coheronia_fable_oneshot_repo.

Read README.md, docs/HANDOFF.md, docs/FABLE_TASK_QUEUE.md, and
docs/PRESENTATION_RECOVERY_MATRIX.md. FQ-00 through FQ-21 are done; the
native HUD-kit stabilization is merged. PR-00 (smoke truth), PR-01
(masculine/feminine terminology migration), PR-02 (character
preview/rendering contract), PR-03A (gear overlay resolution/refresh
hardening), and PR-03B (gear overlay alignment) are done -- the suite is
338/338. Overlays now resolve against effective_body_id() with a
refresh_presentation() hook, and a data-owned per-rig/slot gear_offset in
data/player_visuals.json aligns the goblin/dwarf crude helmet onto the head
(verify_gear_alignment.py enforces helmet/head contact; other bodies/slots
are identity). The non-human crude torso waist placement was left for the
art lane as a plausible loincloth style.

The next code-lane row is PR-04 (directional action animation), code half:
polish the pick/axe swing anchors, left/right mirroring, phase timing, and
arc continuity in player_visual.gd (_draw_swing, refresh_facing) using the
EXISTING 90 swing PNGs. Do NOT change mining/combat timing (the frame
baselines must stay green) and do NOT produce new frames -- new pose frames
and the sword swing families are the art lane in the image-production matrix.
Presentation only.

Rows marked art are image production and are NOT code-lane work. Close
every row with validator, Capsule Doctor, a waited Godot smoke, and real
pass/fail evidence in the docs.
```
