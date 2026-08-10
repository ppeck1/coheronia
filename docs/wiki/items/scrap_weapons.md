# Weapon Scrap

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

> `Item` page. Current status: `complete`.

![Weapon Scrap](../../../art/generated/items/scrap_weapons.png)

| Field | Value |
|---|---|
| ID | `scrap_weapons` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | Broken blades and bent points. Reclaim them into iron at the furnace. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/scrap_weapons.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Weapon Scrap is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Raider Basic](../enemies/raider_basic.md) | 40% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Reclaim Iron | 3x at [Furnace](../stations/furnace.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- Proposed future sink: salvage into iron.
