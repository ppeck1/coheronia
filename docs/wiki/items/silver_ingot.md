# Silver Ingot

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

> `Item` page. Current status: `complete`.

![Silver Ingot](../../../art/generated/items/silver_ingot.png)

| Field | Value |
|---|---|
| ID | `silver_ingot` |
| Page type | Item |
| Current status | complete |
| Storage | stockpile |
| Player-facing? | Yes |
| Description | Smelted at the furnace. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/silver_ingot.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Silver Ingot is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Recipe output | Smelt Silver | 1x at [Furnace](../stations/furnace.md) | Output route: stockpile. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Silver Ring | 2x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Recipe input | Attuned Ring | 1x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Recipe input | Focus Amulet | 1x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- No additional manual notes.
