# Copper Ingot

Generated: 2026-07-21

> `Item` page. Current status: `complete`.

![Copper Ingot](../../../art/generated/items/copper_ingot.png)

| Field | Value |
|---|---|
| ID | `copper_ingot` |
| Page type | Item |
| Current status | complete |
| Storage | stockpile |
| Player-facing? | Yes |
| Description | Smelted at the furnace. Alloys into bronze. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/copper_ingot.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Copper Ingot is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Recipe output | Smelt Copper | 1x at [Furnace](../stations/furnace.md) | Output route: stockpile. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Alloy Bronze | 1x at [Furnace](../stations/furnace.md) | Live crafting dependency. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- No additional manual notes.
