# Ore

Generated: 2026-07-15

> `Item` page. Current status: `complete`.

![Ore](../../../art/generated/items/ore.png)

| Field | Value |
|---|---|
| ID | `ore` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | Raw ore. Needs a tier-2 pick. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/ore.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Ore is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Ore](../blocks/ore.md) | 1x | Current block harvest result. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Lantern | 2x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Ore](../blocks/ore.md)

## Notes

- No additional manual notes.
