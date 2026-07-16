# Coal

Generated: 2026-07-15

> `Item` page. Current status: `complete`.

![Coal](../../../art/generated/items/coal.png)

| Field | Value |
|---|---|
| ID | `coal` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | Fuel for future smelting. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/coal.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Coal is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Coal Seam](../blocks/coal.md) | 1x | Current block harvest result. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Torch Bundle | 1x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Recipe input | Smelt Copper | 1x at [Furnace](../stations/furnace.md) | Live crafting dependency. |
| Recipe input | Smelt Tin | 1x at [Furnace](../stations/furnace.md) | Live crafting dependency. |
| Recipe input | Smelt Iron | 1x at [Furnace](../stations/furnace.md) | Live crafting dependency. |
| Recipe input | Smelt Silver | 1x at [Furnace](../stations/furnace.md) | Live crafting dependency. |
| Recipe input | Alloy Bronze | 1x at [Furnace](../stations/furnace.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Coal Seam](../blocks/coal.md)

## Notes

- No additional manual notes.
