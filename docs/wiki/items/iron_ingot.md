# Iron Ingot

Generated: 2026-07-21

> `Item` page. Current status: `complete`.

![Iron Ingot](../../../art/generated/items/iron_ingot.png)

| Field | Value |
|---|---|
| ID | `iron_ingot` |
| Page type | Item |
| Current status | complete |
| Storage | stockpile |
| Player-facing? | Yes |
| Description | Smelted at the furnace. Anvil stock for iron gear. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/iron_ingot.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Iron Ingot is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Recipe output | Smelt Iron | 1x at [Furnace](../stations/furnace.md) | Output route: stockpile. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Iron Sword | 3x at [Anvil](../stations/anvil.md) | Live crafting dependency. |
| Recipe input | Iron Armor Set | 5x at [Anvil](../stations/anvil.md) | Live crafting dependency. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- No additional manual notes.
