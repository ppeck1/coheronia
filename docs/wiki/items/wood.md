# Wood

Generated: 2026-07-15

> `Item` page. Current status: `complete`.

![Wood](../../../art/generated/items/wood.png)

| Field | Value |
|---|---|
| ID | `wood` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input; world block |
| Player-facing? | Yes |
| Description | Building material and fuel. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/wood.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Wood is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Wood](../blocks/wood.md) | 1x | Current block harvest result. |
| Block drop | [Tree Trunk](../blocks/tree_trunk.md) | 1x | Current block harvest result. |
| Starting role | [Homesteader](../characters/roles/homesteader.md) | 5x | Granted during character setup. |
| Recipe output | Wood Block | 1x at [Hand](../stations/hand.md) | Output route: inventory. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Torch | 1x at [Hand](../stations/hand.md) | Live crafting dependency. |
| Recipe input | Wood Block | 1x at [Hand](../stations/hand.md) | Live crafting dependency. |
| Recipe input | Lantern | 1x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Recipe input | Basic Pick Upgrade | 3x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Recipe input | Axe | 4x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Recipe input | Crude Sword | 2x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Recipe input | Crude Armor Set | 6x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Recipe input | Torch Bundle | 2x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Placement | World block placement | - | Placeable into the world as a block. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Wood](../blocks/wood.md)

## Notes

- No additional manual notes.
