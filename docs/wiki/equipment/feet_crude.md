# Crude Boots

Generated: 2026-07-16

> `Equipment` page. Current status: `complete`.

| Field | Value |
|---|---|
| ID | `feet_crude` |
| Page type | Equipment |
| Slot type | feet |
| Current status | complete |
| Description | Reinforced footwraps. Every bit helps. |
| Stat effects | armor=1 |
| Visual surface | No dedicated backpack-style equipment icon family is currently in use. |
| Player gear overlay hook | `art/generated/player_gear/<item_id>_<body_id>.png` or `<item_id>.png` |
| Authored overlay coverage | 10 body-specific static overlays (one per current body id). |
| Fallback / placeholder | Procedural equipped presentation when a matching overlay cannot resolve. |

## Summary

Crude Boots is a live equipment entry with an active source route and slot effect.

## Acquisition

| Source type | Source | Station | Notes |
|---|---|---|---|
| Town Hall consumes stockpile inputs and equips the crude armor set directly | Crude Armor Set | [Town Hall](../stations/town_hall.md) | Routes into `feet`. |

## Current Use

| Slot | Effects | Notes |
|---|---|---|
| feet | armor=1 | Live gear effects apply when equipped. |

## Related Pages

- [Equipment](../equipment.md)
- [Wiki Overview](../wiki.md)

## Notes

- This page documents the current live route only. It does not change mechanics.
