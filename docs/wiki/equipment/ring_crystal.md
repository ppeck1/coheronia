# Attuned Ring

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

> `Equipment` page. Current status: `complete`.

| Field | Value |
|---|---|
| ID | `ring_crystal` |
| Page type | Equipment |
| Slot type | ring |
| Current status | complete |
| Description | A silver ring set with a raw crystal. It draws attunement strongly. |
| Stat effects | attunement_bonus=8 |
| Visual surface | No dedicated backpack-style equipment icon family is currently in use. |
| Player gear overlay hook | `art/generated/player_gear/<item_id>_<body_id>.png` or `<item_id>.png` |
| Authored overlay coverage | No authored body-specific overlay in the current coverage set. |
| Fallback / placeholder | Procedural equipped presentation when a matching overlay cannot resolve. |

## Summary

Attuned Ring is a live equipment entry with an active source route and slot effect.

## Acquisition

| Source type | Source | Station | Notes |
|---|---|---|---|
| Recipe equip route | Attuned Ring | [Workbench](../stations/workbench.md) | Equips into `ring_1`. |

## Current Use

| Slot | Effects | Notes |
|---|---|---|
| ring | attunement_bonus=8 | Live gear effects apply when equipped. |

## Related Pages

- [Equipment](../equipment.md)
- [Wiki Overview](../wiki.md)

## Notes

- This page documents the current live route only. It does not change mechanics.
