# Crude Axe

Generated: 2026-07-16

> `Equipment` page. Current status: `complete`.

| Field | Value |
|---|---|
| ID | `axe_crude` |
| Page type | Equipment |
| Slot type | axe |
| Current status | complete |
| Description | Town Hall crafted. Chops wood and plants faster. |
| Stat effects | axe_tier=1 |
| Visual surface | No dedicated backpack-style equipment icon family is currently in use. |
| Player gear overlay hook | `art/generated/player_gear/<item_id>_<body_id>.png` or `<item_id>.png` |
| Authored overlay coverage | 30 body/phase swing overlays (10 body ids x phases 0/1/2). |
| Fallback / placeholder | Procedural equipped presentation when a matching overlay cannot resolve. |

## Summary

Crude Axe is a live equipment entry with an active source route and slot effect.

## Acquisition

| Source type | Source | Station | Notes |
|---|---|---|---|
| Town Hall sets `axe_tier = 1`; the live equipment representation reads as `axe_crude` | Axe | [Town Hall](../stations/town_hall.md) | Routes into `axe`. |

## Current Use

| Slot | Effects | Notes |
|---|---|---|
| axe | axe_tier=1 | Live gear effects apply when equipped. |

## Related Pages

- [Equipment](../equipment.md)
- [Wiki Overview](../wiki.md)

## Notes

- This page documents the current live route only. It does not change mechanics.
