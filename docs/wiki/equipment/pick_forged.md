# Forged Pick

Generated: 2026-07-15

> `Equipment` page. Current status: `complete`.

| Field | Value |
|---|---|
| ID | `pick_forged` |
| Page type | Equipment |
| Slot type | pickaxe |
| Current status | complete |
| Description | Town Hall forged. Unlocks ore and mines faster. |
| Stat effects | pick_tier=2 |
| Visual surface | No dedicated backpack-style equipment icon family is currently in use. |
| Player gear overlay hook | `art/generated/player_gear/<item_id>_<body_id>.png` or `<item_id>.png` |
| Fallback / placeholder | Procedural equipped presentation when no overlay art exists. |

## Summary

Forged Pick is a live equipment entry with an active source route and slot effect.

## Acquisition

| Source type | Source | Station | Notes |
|---|---|---|---|
| Consumes the stockpile recipe, emits internal token `tool_tier_2_pick`, then upgrades the equipped pick state to `pick_forged` | Basic Pick Upgrade | [Town Hall](../stations/town_hall.md) | Routes into `pickaxe`. |

## Current Use

| Slot | Effects | Notes |
|---|---|---|
| pickaxe | pick_tier=2 | Live gear effects apply when equipped. |

## Related Pages

- [Equipment](../equipment.md)
- [Wiki Overview](../wiki.md)

## Notes

- This page documents the current live route only. It does not change mechanics.
