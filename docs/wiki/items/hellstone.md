# Hellstone

Generated: 2026-08-04

> `Item` page. Current status: `complete`.

![Hellstone](../../../art/generated/items/hellstone.png)

| Field | Value |
|---|---|
| ID | `hellstone` |
| Page type | Item |
| Current status | complete |
| Storage | inventory; stockpile input |
| Player-facing? | Yes |
| Description | Ember-veined rock from the deep hell layer. Needs a tier-2 pick. |
| Status explanation | A live source and a live downstream use both exist. |
| Image path | `art/generated/items/hellstone.png` |
| Fallback / placeholder | Generated 16x16 swatch via `BlockRegistry.item_icon()` if the canonical item icon is absent. |

## Summary

Hellstone is a live item with both acquisition and active use in the current build.

## Acquisition

| Source type | Source | Quantity / chance | Notes |
|---|---|---|---|
| Block drop | [Hellstone](../blocks/hellstone.md) | 1x | Current block harvest result. |
| Enemy drop | [Lava Slime](../enemies/lava_slime.md) | 15% drop chance | Live acquisition only if the enemy is live. |

## Current Uses

| Use type | Use | Quantity | Notes |
|---|---|---|---|
| Recipe input | Hellstone Armor Set | 6x at [Anvil](../stations/anvil.md) | Live crafting dependency. |
| Recipe input | Ember Amulet | 2x at [Workbench](../stations/workbench.md) | Live crafting dependency. |
| Stockpile | Town Hall deposit | - | Depositable into the Town Hall stockpile. |

## Related Pages

- [Items](../items.md)
- [Wiki Overview](../wiki.md)
- [Hellstone](../blocks/hellstone.md)

## Notes

- No additional manual notes.
