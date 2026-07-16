# Orc

Generated: 2026-07-15

> `Ancestry` page. Current status: `planned`.

| Field | Value |
|---|---|
| ID | `orc` |
| Page type | Ancestry |
| Status | planned |
| Implementation phase | B |
| Implementation priority | 5 |
| Spawn band | surface |
| Preferred biomes | badlands, plains, mountains |
| Description | Frontier-hardened warriors who drove Coheronia's expansion into rough and contested lands. |
| Visual families | Default: 1 canonical image + 2 variants; Female: 1 canonical image + 2 variants |

## Summary

Orc is a validated ancestry definition loaded from `data/ancestries.json`. The matching species is live/playable through `data/character_data.json`; expanded ancestry-system fields remain planned.

## Body Art Reference

This ancestry currently maps to live player body art, so the current wiki mirrors those authored visuals here.

### Default body (orc)

![Orc Default - orc (Canonical image)](../../../../art/generated/players/orc.png)
![Orc Default - orc_01 (Variant 1)](../../../../art/generated/players/orc_01.png)
![Orc Default - orc_02 (Variant 2)](../../../../art/generated/players/orc_02.png)

| Asset id | Role | File |
|---|---|---|
| `orc` | Canonical image | `../../../../art/generated/players/orc.png` |
| `orc_01` | Variant 1 | `../../../../art/generated/players/orc_01.png` |
| `orc_02` | Variant 2 | `../../../../art/generated/players/orc_02.png` |

### Female body (orc_female)

![Orc Female - orc_female (Canonical image)](../../../../art/generated/players/orc_female.png)
![Orc Female - orc_female_01 (Variant 1)](../../../../art/generated/players/orc_female_01.png)
![Orc Female - orc_female_02 (Variant 2)](../../../../art/generated/players/orc_female_02.png)

| Asset id | Role | File |
|---|---|---|
| `orc_female` | Canonical image | `../../../../art/generated/players/orc_female.png` |
| `orc_female_01` | Variant 1 | `../../../../art/generated/players/orc_female_01.png` |
| `orc_female_02` | Variant 2 | `../../../../art/generated/players/orc_female_02.png` |

## Effects

| Bucket | Effect | Value |
|---|---|---|
| player_effects | health_bonus | 25 |
| player_effects | stamina_endurance_mult | 1.1 |
| player_effects | tree_clearing_speed_mult | 1.15 |
| player_effects | stealth_mult | 0.8 |
| player_effects | diplomacy_mult | 0.8 |
| player_effects | notes | ['melee bonus', 'stamina endurance', 'faster tree clearing', 'lower stealth/diplomacy finesse'] |
| settlement_effects | raid_fear_reduction | 0.8 |
| settlement_effects | militia_strength_mult | 1.1 |
| settlement_effects | expansion_pressure_reduction | 0.8 |
| settlement_effects | notes | ['diplomacy and subtle governance harder'] |

## Related Pages

- [Character Types](../../character_types.md)
