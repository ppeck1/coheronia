# Sapper Picks

Generated: 2026-07-30

> `Item` page. Current status: `source-only`.

![Sapper Picks](../../../art/generated/items/picks.png)

| Field | Value |
|---|---|
| ID | `picks` |
| Page type | Item |
| Current status | source-only |
| Storage | inventory |
| Player-facing? | Yes |
| Description | A bundle of raider digging picks. |
| Status explanation | A live source exists, but the current game still lacks a meaningful downstream sink. |
| Image path | `art/generated/items/picks.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Sapper Picks is live and obtainable, but it still ends in a source-only branch.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Raider Sapper](../enemies/raider_sapper.md) | 50% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

No meaningful live downstream use is currently defined.

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- Recommended first implementation sink: tool repair or iron salvage.
