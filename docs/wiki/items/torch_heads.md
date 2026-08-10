# Torch Heads

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

> `Item` page. Current status: `complete`.

![Torch Heads](../../../art/generated/items/torch_heads.png)

| Field | Value |
|---|---|
| ID | `torch_heads` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | Pitch-soaked torch heads. Bundle with oil rags and wood into torches. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/torch_heads.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Torch Heads is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Enemy drop | [Raider Torchbearer](../enemies/raider_torchbearer.md) | 40% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Raid Torches | 2x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)

## Notes

- Proposed future sink: upgraded torches or fire trap branch.
