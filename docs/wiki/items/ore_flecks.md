# Ore Flecks

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

> `Item` page. Current status: `complete`.

![Ore Flecks](../../../art/generated/items/ore_flecks.png)

| Field | Value |
|---|---|
| ID | `ore_flecks` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | Metal residue scraped from an ore tick. Reclaim it into ore at the furnace. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/ore_flecks.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Ore Flecks is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Ore Tick](../enemies/ore_tick.md) | 70% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Reclaim Ore | 4x at [Furnace](../stations/furnace.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- Proposed future sink: salvage into trace metals.
