# Basic Pick

Generated: 2026-07-16

> `Equipment` page. Current status: `complete`.

| Field | Value |
|---|---|
| ID | `pick_basic` |
| Page type | Equipment |
| Slot type | pickaxe |
| Current status | complete |
| Description | The starter pick every settler carries. |
| Stat effects | pick_tier=1 |
| Visual surface | No dedicated backpack-style equipment icon family is currently in use. |
| Player gear overlay hook | `art/generated/player_gear/<item_id>_<body_id>.png` or `<item_id>.png` |
| Authored overlay coverage | 30 body/phase swing overlays (10 body ids x phases 0/1/2). |
| Fallback / placeholder | Procedural equipped presentation when a matching overlay cannot resolve. |

## Summary

Basic Pick is a live equipment entry with an active source route and slot effect.

## Acquisition

| Source type | Source | Station | Notes |
|---|---|---|---|
| Default loadout | Character setup | - | Default character loadout via the shell/game state. |

## Current Use

| Slot | Effects | Notes |
|---|---|---|
| pickaxe | pick_tier=1 | Live gear effects apply when equipped. |

## Related Pages

- [Equipment](../equipment.md)
- [Wiki Overview](../wiki.md)

## Notes

- This page documents the current live route only. It does not change mechanics.
