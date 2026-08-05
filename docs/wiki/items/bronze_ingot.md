# Bronze Ingot

Generated: 2026-08-05

> `Item` page. Current status: `complete`.

![Bronze Ingot](../../../art/generated/items/bronze_ingot.png)

| Field | Value |
|---|---|
| ID | `bronze_ingot` |
| Page type | Item |
| Current status | complete |
| Storage | stockpile |
| Player-facing? | Yes |
| Description | Alloyed from copper and tin at the furnace. Forged into bronze gear at the anvil. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/bronze_ingot.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Bronze Ingot is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Recipe output | Alloy Bronze | 2x at [Furnace](../stations/furnace.md) | Output route: stockpile. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Bronze Sword | 3x at [Anvil](../stations/anvil.md) | Live crafting dependency. |
| Recipe input | Bronze Armor Set | 5x at [Anvil](../stations/anvil.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- No additional manual notes.
