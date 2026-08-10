# Fuse Cord

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

> `Item` page. Current status: `source-only`.

![Fuse Cord](../../../art/generated/items/fuse_cord.png)

| Field | Value |
|---|---|
| ID | `fuse_cord` |
| Page type | Item |
| Current status | source-only |
| Storage | inventory |
| Player-facing? | Yes |
| Description | Oiled cord a sapper uses to breach walls. |
| Status explanation | A live source exists, but the current game still lacks a meaningful downstream sink. |
| Image path | `art/generated/items/fuse_cord.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Fuse Cord is live and obtainable, but it still ends in a source-only branch.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Raider Sapper](../enemies/raider_sapper.md) | 35% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

No meaningful live downstream use is currently defined.

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- Recommended first implementation sink: demolition or trap recipes.
