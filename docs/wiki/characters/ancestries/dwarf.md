# Dwarf

Generated: 2026-07-15

> `Ancestry` page. Current status: `planned`.

| Field | Value |
|---|---|
| ID | `dwarf` |
| Page type | Ancestry |
| Status | planned |
| Implementation phase | B |
| Implementation priority | 2 |
| Spawn band | surface_mountain |
| Preferred biomes | mountains, foothills, early_caves |
| Description | Mountain-born craftspeople who shaped Coheronia's first stone halls and ore routes. |
| Visual families | Default: 1 canonical image + 2 variants; Female: 1 canonical image + 2 variants |

## Summary

Dwarf is a validated ancestry definition loaded from `data/ancestries.json`. The matching species is live/playable through `data/character_data.json`; expanded ancestry-system fields remain planned.

## Body Art Reference

This ancestry currently maps to live player body art, so the current wiki mirrors those authored visuals here.

### Default body (dwarf)

![Dwarf Default - dwarf (Canonical image)](../../../../art/generated/players/dwarf.png)
![Dwarf Default - dwarf_01 (Variant 1)](../../../../art/generated/players/dwarf_01.png)
![Dwarf Default - dwarf_02 (Variant 2)](../../../../art/generated/players/dwarf_02.png)

| Asset id | Role | File |
|---|---|---|
| `dwarf` | Canonical image | `../../../../art/generated/players/dwarf.png` |
| `dwarf_01` | Variant 1 | `../../../../art/generated/players/dwarf_01.png` |
| `dwarf_02` | Variant 2 | `../../../../art/generated/players/dwarf_02.png` |

### Female body (dwarf_female)

![Dwarf Female - dwarf_female (Canonical image)](../../../../art/generated/players/dwarf_female.png)
![Dwarf Female - dwarf_female_01 (Variant 1)](../../../../art/generated/players/dwarf_female_01.png)
![Dwarf Female - dwarf_female_02 (Variant 2)](../../../../art/generated/players/dwarf_female_02.png)

| Asset id | Role | File |
|---|---|---|
| `dwarf_female` | Canonical image | `../../../../art/generated/players/dwarf_female.png` |
| `dwarf_female_01` | Variant 1 | `../../../../art/generated/players/dwarf_female_01.png` |
| `dwarf_female_02` | Variant 2 | `../../../../art/generated/players/dwarf_female_02.png` |

## Effects

| Bucket | Effect | Value |
|---|---|---|
| player_effects | hotbar_slots_bonus | 1 |
| player_effects | stone_ore_mining_mult | 1.2 |
| player_effects | move_speed_mult | 0.9 |
| player_effects | jump_mult | 0.85 |
| player_effects | notes | ['knockback resistance', 'better tool durability'] |
| settlement_effects | stone_resilience_mult | 1.1 |
| settlement_effects | ore_stockpile_value_mult | 1.1 |
| settlement_effects | notes | ['lower food/forest efficiency'] |

## Related Pages

- [Character Types](../../character_types.md)
