# Food

Generated: 2026-07-21

> `Item` page. Current status: `complete`.

![Food](../../../art/generated/items/food.png)

| Field | Value |
|---|---|
| ID | `food` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | Restores health when eaten (H). |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/food.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Food is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Ripe Crop](../blocks/crop_ripe.md) | 3x | Current block harvest result. |
| Block drop | [Berry Bush](../blocks/berry_bush.md) | 2x | Current block harvest result. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Crop Seeds | 1x at [Hand](../stations/hand.md) | Live crafting dependency. |
| Consume | Healing use | - | Consumable healing item. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- No additional manual notes.
