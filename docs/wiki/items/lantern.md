# Lantern

Generated: 2026-07-15

> `Item` page. Current status: `complete`.

![Lantern](../../../art/generated/items/lantern.png)

| Field | Value |
|---|---|
| ID | `lantern` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; world block |
| Player-facing? | Yes |
| Description | Bright, far-reaching light. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/lantern.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Lantern is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Lantern](../blocks/lantern.md) | 1x | Current block harvest result. |
| Recipe output | Lantern | 1x at [Town Hall](../stations/town_hall.md) | Output route: inventory. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Placement | World block placement | - | Placeable into the world as a block. |
| Light | Placed light source | - | Emits light with radius 160. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Lantern](../blocks/lantern.md)

## Notes

- No additional manual notes.
