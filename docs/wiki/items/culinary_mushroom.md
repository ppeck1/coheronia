# Culinary Mushroom

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

> `Item` page. Current status: `complete`.

| Field | Value |
|---|---|
| ID | `culinary_mushroom` |
| Page type | Item |
| Current status | complete |
| Storage | inventory |
| Player-facing? | Yes |
| Description | An edible cave mushroom from a Sporekin. Cook two into food at the Town Hall. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/culinary_mushroom.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Culinary Mushroom is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Sporekin](../enemies/sporekin.md) | 70% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Cook Mushrooms | 2x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- No additional manual notes.
