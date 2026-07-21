# Ore Flecks

Generated: 2026-07-21

> `Item` page. Current status: `source-only`.

![Ore Flecks](../../../art/generated/items/ore_flecks.png)

| Field | Value |
|---|---|
| ID | `ore_flecks` |
| Page type | Item |
| Current status | source-only |
| Storage | inventory |
| Player-facing? | Yes |
| Description | Metal residue scraped from an ore tick. |
| Status explanation | A live source exists, but the current game still lacks a meaningful downstream sink. |
| Image path | `art/generated/items/ore_flecks.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Ore Flecks is live and obtainable, but it still ends in a source-only branch.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Ore Tick](../enemies/ore_tick.md) | 70% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

No meaningful live downstream use is currently defined.

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- Proposed future sink: salvage into trace metals.
