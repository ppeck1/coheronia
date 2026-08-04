# Current Live

Generated: 2026-07-31

This page lists wiki surfaces that represent current live behavior or currently obtainable data. Source-only entries appear here only when they are live or defined in current data; planning notes are kept on [Planned Data](planned_data.md).

## Complete Item Loops

| Item | Why it is current-live |
|---|---|
| [Dirt](items/dirt.md) | Obtainable and placeable. |
| [Wood](items/wood.md) | Obtainable and used by recipes and station builds. |
| [Stone](items/stone.md) | Obtainable and used by recipes and station builds. |
| [Coal](items/coal.md) | Obtainable fuel and crafting input. |
| [Ore](items/ore.md) | Obtainable and used for lantern crafting. |
| [Copper Ore](items/copper_ore.md) | Obtainable and smelted. |
| [Tin Ore](items/tin_ore.md) | Obtainable and smelted. |
| [Iron Ore](items/iron_ore.md) | Obtainable and smelted. |
| [Silver Ore](items/silver_ore.md) | Obtainable and smelted. |
| [Copper Ingot](items/copper_ingot.md) | Produced and consumed by bronze alloying. |
| [Tin Ingot](items/tin_ingot.md) | Produced and consumed by bronze alloying. |
| [Iron Ingot](items/iron_ingot.md) | Produced and consumed by anvil gear. |
| [Crop Seeds](items/crop_seeds.md) | Obtainable and plantable. |
| [Food](items/food.md) | Obtainable, edible, and convertible to seeds. |
| [Torch](items/torch.md) | Craftable and placeable. |
| [Lantern](items/lantern.md) | Craftable and placeable. |

## Current Source-Only Items

| Item | Current source | Current live limitation |
|---|---|---|
| [Raw Crystal](items/crystal.md) | Raw crystal block | No downstream sink yet. |
| [Silver Ingot](items/silver_ingot.md) | `smelt_silver` | No downstream sink yet. |
| [Bronze Ingot](items/bronze_ingot.md) | `alloy_bronze` | No downstream sink yet. |
| [Slime Gel](items/slime_gel.md), [Wet Fiber](items/wet_fiber.md), [Tiny Core](items/tiny_core.md) | Surface Slime | Live drops with no sinks yet. |
| [Raw Meat](items/meat.md), [Thorn Quill](items/thorn_quill.md), [Hide Scrap](items/hide_scrap.md) | Thornrat | Live drops with no sinks yet. |
| [Crawler Chitin](items/chitin.md), [Cave Silk](items/silk.md), [Crawler Eyes](items/eyes.md) | Cave Crawler | Live drops with no sinks yet. |
| [Ore Flecks](items/ore_flecks.md), [Tick Shell](items/shell.md) | Ore Tick | Live drops with no sinks yet. |
| [Raider Coins](items/coins.md), [Weapon Scrap](items/scrap_weapons.md) | Raider Basic | Live drops with no sinks yet. |
| [Oil Rags](items/oil_rags.md), [Torch Heads](items/torch_heads.md) | Raider Torchbearer | Live drops with no sinks yet. |

## Current Presentation Systems

| Surface | Current live state |
|---|---|
| Primary HUD | A native 19-asset layered dock kit is the preferred runtime path. Contract v2 positions every runtime child from JSON, protects vessel keep-outs, validates state-family geometry and alpha rules, and permits manifest-declared non-interactive decorative layers. Health, attunement, icons, counts, hotkeys, visible labels, actions, and interaction states remain runtime-driven. Map and Events are independent movable modules and can remain open together. **Dock slots are cursor-selectable** (click to select; number keys still work). The **settler info panel** (click any citizen or its Town Hall row) shows name, role, days alive, four stats, and a live needs/coherence/want report, and is itself a **movable/resizable Edit-mode widget**. The **Town Hall stockpile is a drag-and-drop grid** like the player inventory — drag stacks in to deposit and out to withdraw, or click to pull (Left = all, Right = half, Shift+Left = choose an amount), with the Town Hall as the sole authority. |
| Sky & lighting | A presentation-only **sun and moon** ride a fixed arc anchored in world space, hidden entirely underground. The moon runs a **true ~29-day continuous synodic cycle** through every named phase (New → Waxing Crescent → First Quarter → Waxing Gibbous → Full → …, named on the night clock). Torches, lava, and the sun/moon share one soft **radial-glow** lighting helper (bright core, feathered edge), and each body casts a large soft light — a warm sun and a subtle cooler-blue moon that pools moonlight on the ground at night. A **per-column depth shader** darkens each terrain fragment by its own depth below the local sky line, so a mined shaft or cross-section viewed from the surface reads **dark** (lit only at the surface lip, open shafts, and torch/lava pockets) while the surface stays fully lit. |
| Equipped character presentation | Crude helmet, torso, and feet have authored overlays for all ten current bodies. The basic pick, forged pick, and crude axe have authored three-phase swing overlays for all ten bodies. Other equipment retains a rig-aware procedural fallback. |
| Opening presentation | All eight opening scenes have authored cel pools, with ten PNGs total. Deterministic plotted scenes remain available as fallback. |

Presentation defects that do not invalidate the gameplay state are tracked on [Known Issues](known_issues.md).

## Current World & Settlement Mechanics

| Mechanic | Current live state |
|---|---|
| Bounded persistent citizens | Each settler has a saved home/guard post, a hard movement clamp, an ancestry identity drawn through the player sprite pipeline, and four stats. Stats bite: Vigor scales move speed, Guard scales a defender's hit. A defender role guards a post and engages threats; the visible roster tracks the population authority. The info panel shows needs as **green ✓ / red ✗** chips (hover a ✗ for what's wrong and how to fix it) and defines each want. |
| Settler jobs & work zones | Farmhands **harvest and replant** (a seed pouch keeps a seed from each harvest to sow on tilled soil); haulers carry ground drops to the stockpile; repairers fix the hall; defenders hold a post. Any settler can be given a **work zone** — *Set work zone* on its panel, then drag a rectangle in the world — and it then works only inside that zone (clamped to the settlement bounds). |
| Doors | Doors are a **full-height (3-tall × 1-wide) unit** that opens/closes and mines as one, leaving a character-height opening the player and every settler can walk through when open. Placed via the `door` item; recognized by the housing rule. |
| Block gravity | Free-standing gravity blocks (tree trunk/leaves, via the `has_gravity` flag) **fall when their footing is cut** — mine through a trunk and the severed top and canopy drop as wood/leaf ground items, while the grounded base stays. Cohesive terrain (stone, dirt, ore) never falls. |
| Housing-capped growth | An enclosed, doored room is recognized as a house and caps population growth at `min(base-level cap, housing)`, so building is required to grow. |

## Live Species

[Human](characters/species/human.md), [Dwarf](characters/species/dwarf.md), [Elf](characters/species/elf.md), [Goblin](characters/species/goblin.md), and [Orc](characters/species/orc.md) are live species entries through `data/character_data.json`.

## Related Pages

- [Items](items.md)
- [Recipes](recipes.md)
- [Status Browser](status_browser.md)
- [Known Issues](known_issues.md)
- [Wiki Overview](wiki.md)
