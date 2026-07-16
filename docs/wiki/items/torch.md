# Torch

Generated: 2026-07-15

> `Item` page. Current status: `complete`.

![Torch](../../../art/generated/items/torch.png)

| Field | Value |
|---|---|
| ID | `torch` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; world block |
| Player-facing? | Yes |
| Description | Light. Keeps the dark honest. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/torch.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Torch is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Torch](../blocks/torch.md) | 1x | Current block harvest result. |
| Starting role | [Prospector](../characters/roles/prospector.md) | 3x | Granted during character setup. |
| Recipe output | Torch | 3x at [Hand](../stations/hand.md) | Output route: inventory. |
| Recipe output | Torch Bundle | 6x at [Workbench](../stations/workbench.md) | Output route: inventory. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Placement | World block placement | - | Placeable into the world as a block. |
| Light | Placed light source | - | Emits light with radius 96. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Torch](../blocks/torch.md)

## Notes

- No additional manual notes.
