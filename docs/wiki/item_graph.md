# Item Graph

Generated: 2026-07-15

## Scope

- Wiki-local visual companion to `docs/ITEM_GRAPH.md`.
- Source data: `data/items.json`, `data/equipment.json`, `data/recipes.json`, `data/blocks.json`, and the current route notes in the wiki recipe pages.
- This page exists because the strict audit graph can appear as raw graph source in some static viewers. The HTML version of this page contains a rendered, self-contained SVG graph.

## What The Graph Shows

| Cluster | Meaning |
|---|---|
| Live sources | Starting gear, block drops, crop drops, and enemy drops that can enter current play. |
| Backpack and stockpile | Player inventory, settlement stockpile, and equipment results. |
| Crafting routes | Hand crafting, Town Hall, Workbench, Furnace, and Anvil routes. |
| Pressure points | Live outputs that still need stronger downstream sinks. |
| Planned-only | Data hooks that are present for planning but are not current gameplay. |

## Planning Notes

- `crystal`, `silver_ingot`, and `bronze_ingot` are live or craftable outputs that still need stronger downstream meaning.
- Live enemy drops are well represented as sources, but most still need first-class sinks.
- Town Hall routes can produce equipment directly rather than normal backpack items, so recipe review should use the recipe pages instead of raw item ids alone.
- Planned-only hooks stay separated from current live routes so future work does not accidentally imply shipped gameplay.

## Related Pages

- [Current Live](current_live.md)
- [Recipes](recipes.md)
- [Items](items.md)
- [Equipment](equipment.md)
- [Status Browser](status_browser.md)
- [Wiki Overview](wiki.md)
- [Strict Item Graph Audit](../ITEM_GRAPH.md)
