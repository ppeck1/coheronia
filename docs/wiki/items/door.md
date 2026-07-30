# Door

Generated: 2026-07-29

> `Item` page. Current status: `source-only`.

| Field | Value |
|---|---|
| ID | `door` |
| Page type | Item |
| Current status | source-only |
| Storage | inventory |
| Player-facing? | Yes |
| Description | A wooden door. Place it in a wall; Place again on it to open or close it. Houses need at least one. |
| Status explanation | A live source exists, but the current game still lacks a meaningful downstream sink. |
| Image path | `art/generated/items/door.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Door is live and obtainable, but it still ends in a source-only branch.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Door](../blocks/door.md) | 1x | Current block harvest result. |
| Block drop | [Open Door](../blocks/door_open.md) | 1x | Current block harvest result. |
| Recipe output | Door | 1x at [Hand](../stations/hand.md) | Output route: inventory. |

## Current Uses

No meaningful live downstream use is currently defined.

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Door](../blocks/door.md)

## Notes

- No additional manual notes.
