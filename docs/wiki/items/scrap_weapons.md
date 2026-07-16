# Weapon Scrap

Generated: 2026-07-15

> `Item` page. Current status: `source-only`.

![Weapon Scrap](../../../art/generated/items/scrap_weapons.png)

| Field | Value |
|---|---|
| ID | `scrap_weapons` |
| Page type | Item |
| Current status | source-only |
| Storage | inventory |
| Player-facing? | Yes |
| Description | Broken blades and bent points fit only for salvage. |
| Status explanation | A live source exists, but the current game still lacks a meaningful downstream sink. |
| Image path | `art/generated/items/scrap_weapons.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Weapon Scrap is live and obtainable, but it still ends in a source-only branch.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Raider Basic](../enemies/raider_basic.md) | 40% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

No meaningful live downstream use is currently defined.

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
