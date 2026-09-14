# Cave Oil

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

> `Item` page. Current status: `complete`.

![Cave Oil](../../../art/generated/items/oil.png)

| Field | Value |
|---|---|
| ID | `oil` |
| Page type | Item |
| Current status | complete |
| Storage | inventory |
| Player-facing? | Yes |
| Description | Flammable oil from a Lantern Leech. Lantern fuel — craft a lantern with a glow gland. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/oil.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Cave Oil is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Lantern Leech](../enemies/lantern_leech.md) | 55% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Glowlamp Lantern | 1x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- Recommended first implementation sink: lantern fuel or fire weapons.
