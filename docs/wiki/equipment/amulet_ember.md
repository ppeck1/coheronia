# Ember Amulet

Generated: 2026-08-06

> `Equipment` page. Current status: `complete`.

| Field | Value |
|---|---|
| ID | `amulet_ember` |
| Page type | Equipment |
| Slot type | amulet |
| Current status | complete |
| Description | A capstone talisman of hellstone and obsidian around a living crystal. Wards the wearer and deepens attunement far. |
| Stat effects | attunement_bonus=12, armor=2 |
| Visual surface | No dedicated backpack-style equipment icon family is currently in use. |
| Player gear overlay hook | `art/generated/player_gear/<item_id>_<body_id>.png` or `<item_id>.png` |
| Authored overlay coverage | No authored body-specific overlay in the current coverage set. |
| Fallback / placeholder | Procedural equipped presentation when a matching overlay cannot resolve. |

## Summary

Ember Amulet is a live equipment entry with an active source route and slot effect.

## Acquisition

| Source type | Source | Station | Notes |
|---|---|---|---|
| Recipe equip route | Ember Amulet | [Workbench](../stations/workbench.md) | Equips into `amulet`. |

## Current Use

| Slot | Effects | Notes |
|---|---|---|
| amulet | attunement_bonus=12, armor=2 | Live gear effects apply when equipped. |

## Related Pages

- [Equipment](../equipment.md)
- [Wiki Overview](../wiki.md)

## Notes

- This page documents the current live route only. It does not change mechanics.
