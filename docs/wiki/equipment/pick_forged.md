# Forged Pick

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

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
| Authored overlay coverage | 30 body/phase swing overlays (10 body ids x phases 0/1/2). |
| Fallback / placeholder | Procedural equipped presentation when a matching overlay cannot resolve. |

## Summary

Forged Pick is a live equipment entry with an active source route and slot effect.

## Acquisition

| Source type | Source | Station | Notes |
|---|---|---|---|
| Consumes the stockpile recipe and upgrades the live pick tier to 2 (equipped view -> `pick_forged`) | Basic Pick Upgrade | [Town Hall](../stations/town_hall.md) | Routes into `pickaxe`. |

## Current Use

| Slot | Effects | Notes |
|---|---|---|
| pickaxe | pick_tier=2 | Live gear effects apply when equipped. |

## Related Pages

- [Equipment](../equipment.md)
- [Wiki Overview](../wiki.md)

## Notes

- This page documents the current live route only. It does not change mechanics.
