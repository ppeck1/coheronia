# Oil Rags

Generated: 2026-07-29

> `Item` page. Current status: `complete`.

![Oil Rags](../../../art/generated/items/oil_rags.png)

| Field | Value |
|---|---|
| ID | `oil_rags` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | Oily rags from a torchbearer. Bundle with torch heads into torches. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/oil_rags.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Oil Rags is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Raider Torchbearer](../enemies/raider_torchbearer.md) | 60% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Raid Torches | 1x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- Proposed future sink: lantern fuel, torch gel, or fire trap.
