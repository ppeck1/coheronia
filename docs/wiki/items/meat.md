# Raw Meat

Generated: 2026-07-31

> `Item` page. Current status: `complete`.

![Raw Meat](../../../art/generated/items/meat.png)

| Field | Value |
|---|---|
| ID | `meat` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | Thornrat meat. Cook it at the furnace for food. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/meat.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Raw Meat is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Thornrat](../enemies/thornrat.md) | 65% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Cook Meat | 2x at [Furnace](../stations/furnace.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- Proposed future sink: prepared food branch.
