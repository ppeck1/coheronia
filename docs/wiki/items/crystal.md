# Raw Crystal

Generated: 2026-08-05

> `Item` page. Current status: `complete`.

![Raw Crystal](../../../art/generated/items/crystal.png)

| Field | Value |
|---|---|
| ID | `crystal` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | A deep, faceted crystal. Needs a tier-2 pick. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/crystal.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Raw Crystal is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Raw Crystal](../blocks/crystal.md) | 1x | Current block harvest result. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Ember Amulet | 2x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Recipe input | Attuned Ring | 1x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Recipe input | Focus Amulet | 1x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Raw Crystal](../blocks/crystal.md)

## Notes

- No additional manual notes.
