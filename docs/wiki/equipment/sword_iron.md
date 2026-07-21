# Iron Sword

Generated: 2026-07-21

> `Equipment` page. Current status: `complete`.

| Field | Value |
|---|---|
| ID | `sword_iron` |
| Page type | Equipment |
| Slot type | weapon |
| Current status | complete |
| Description | Anvil-forged from iron ingots. Bites deeper than crude steel. |
| Stat effects | attack_damage=5 |
| Visual surface | No dedicated backpack-style equipment icon family is currently in use. |
| Player gear overlay hook | `art/generated/player_gear/<item_id>_<body_id>.png` or `<item_id>.png` |
| Authored overlay coverage | No authored body-specific overlay in the current coverage set. |
| Fallback / placeholder | Procedural equipped presentation when a matching overlay cannot resolve. |

## Summary

Iron Sword is a live equipment entry with an active source route and slot effect.

## Acquisition

| Source type | Source | Station | Notes |
|---|---|---|---|
| Recipe equip route | Iron Sword | [Anvil](../stations/anvil.md) | Equips into `weapon`. |

## Current Use

| Slot | Effects | Notes |
|---|---|---|
| weapon | attack_damage=5 | Live gear effects apply when equipped. |

## Related Pages

- [Equipment](../equipment.md)
- [Weapons](../weapons.md)
- [Wiki Overview](../wiki.md)

## Notes

- This page documents the current live route only. It does not change mechanics.
