# Current Live

Generated: 2026-07-16

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
| Primary HUD | A native 19-asset layered dock kit is the preferred runtime path. Contract v2 positions every runtime child from JSON, protects vessel keep-outs, validates state-family geometry and alpha rules, and permits manifest-declared non-interactive decorative layers. Health, attunement, icons, counts, hotkeys, visible labels, actions, and interaction states remain runtime-driven. Map and Events are independent movable modules and can remain open together. |
| Equipped character presentation | Crude helmet, torso, and feet have authored overlays for all ten current bodies. The basic pick, forged pick, and crude axe have authored three-phase swing overlays for all ten bodies. Other equipment retains a rig-aware procedural fallback. |
| Opening presentation | All eight opening scenes have authored cel pools, with ten PNGs total. Deterministic plotted scenes remain available as fallback. |

Presentation defects that do not invalidate the gameplay state are tracked on [Known Issues](known_issues.md).

## Live Species

[Human](characters/species/human.md), [Dwarf](characters/species/dwarf.md), [Elf](characters/species/elf.md), [Goblin](characters/species/goblin.md), and [Orc](characters/species/orc.md) are live species entries through `data/character_data.json`.

## Related Pages

- [Items](items.md)
- [Recipes](recipes.md)
- [Status Browser](status_browser.md)
- [Known Issues](known_issues.md)
- [Wiki Overview](wiki.md)
