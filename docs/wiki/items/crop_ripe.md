# Ripe Crop

Generated: 2026-07-21

> `Item` page. Current status: `source-only`.

![Ripe Crop](../../../art/generated/items/crop_ripe.png)

| Field | Value |
|---|---|
| ID | `crop_ripe` |
| Page type | Item |
| Current status | source-only |
| Storage | world block metadata |
| Player-facing? | World-only |
| Description | Harvest (mine) for food and a seed. |
| Status explanation | This id exists on the world-state side; mining or harvesting it resolves to other carried items instead of preserving this token in the backpack. |
| Image path | `art/generated/items/crop_ripe.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Ripe Crop is a world-state item token, not a normal carried resource.

## Acquisition

No live acquisition route is currently defined.

## Current Uses

No meaningful live downstream use is currently defined.

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Ripe Crop](../blocks/crop_ripe.md)

## Notes

- Current runtime behavior resolves this token through the world block, not the backpack.
