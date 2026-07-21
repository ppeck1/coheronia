# Crude Cuirass

Generated: 2026-07-21

> `Equipment` page. Current status: `complete`.

| Field | Value |
|---|---|
| ID | `torso_crude` |
| Page type | Equipment |
| Slot type | torso |
| Current status | complete |
| Description | Bound wood and stone plates over the chest. |
| Stat effects | armor=2 |
| Visual surface | No dedicated backpack-style equipment icon family is currently in use. |
| Player gear overlay hook | `art/generated/player_gear/<item_id>_<body_id>.png` or `<item_id>.png` |
| Authored overlay coverage | 10 body-specific static overlays (one per current body id). |
| Fallback / placeholder | Procedural equipped presentation when a matching overlay cannot resolve. |

## Summary

Crude Cuirass is a live equipment entry with an active source route and slot effect.

## Acquisition

| Source type | Source | Station | Notes |
|---|---|---|---|
| Town Hall consumes stockpile inputs and equips the crude armor set directly | Crude Armor Set | [Town Hall](../stations/town_hall.md) | Routes into `torso`. |

## Current Use

| Slot | Effects | Notes |
|---|---|---|
| torso | armor=2 | Live gear effects apply when equipped. |

## Related Pages

- [Equipment](../equipment.md)
- [Wiki Overview](../wiki.md)

## Notes

- This page documents the current live route only. It does not change mechanics.
