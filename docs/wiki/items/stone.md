# Stone

Generated: 2026-07-15

> `Item` page. Current status: `complete`.

![Stone](../../../art/generated/items/stone.png)

| Field | Value |
|---|---|
| ID | `stone` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input; world block |
| Player-facing? | Yes |
| Description | Sturdy building material. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/stone.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Stone is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Stone](../blocks/stone.md) | 1x | Current block harvest result. |
| Starting role | [Prospector](../characters/roles/prospector.md) | 2x | Granted during character setup. |
| Recipe output | Stone Block | 1x at [Hand](../stations/hand.md) | Output route: inventory. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Torch | 1x at [Hand](../stations/hand.md) | Live crafting dependency. |
| Recipe input | Stone Block | 1x at [Hand](../stations/hand.md) | Live crafting dependency. |
| Recipe input | Basic Pick Upgrade | 5x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Recipe input | Axe | 2x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Recipe input | Crude Sword | 3x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Recipe input | Crude Armor Set | 4x at [Town Hall](../stations/town_hall.md) | Live crafting dependency. |
| Placement | World block placement | - | Placeable into the world as a block. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Stone](../blocks/stone.md)

## Notes

- No additional manual notes.
