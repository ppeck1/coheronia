# Lava Slime

Generated from repo data by `scripts/wiki/generate_wiki.py` (see git history for dates).

> `Enemy` page. Current status: `live`.

| Field | Value |
|---|---|
| ID | `lava_slime` |
| Page type | Enemy |
| Status | live |
| Family | underground |
| Location | Lava pools in the hell layer |
| Role | Molten dweller of the lava layer; leaves obsidian and hellstone |
| Image path | `art/generated/enemies/lava_slime.png` |
| Visual family | 1 canonical image + 3 variants |
| Fallback / placeholder | Code-drawn hostile shape fallback when authored sprite art is absent. |
| hp | 4 |
| contact_damage | 10 |
| speed | 26 |
| hp_mult | 1.2 |

## Summary

Lava Slime is a live enemy entry loaded from `data/enemies.json`.

## Visual Family

### Enemy art and variants

![Lava Slime - lava_slime (Canonical image)](../../../art/generated/enemies/lava_slime.png)
![Lava Slime - lava_slime_01 (Variant 1)](../../../art/generated/enemies/lava_slime_01.png)
![Lava Slime - lava_slime_02 (Variant 2)](../../../art/generated/enemies/lava_slime_02.png)
![Lava Slime - lava_slime_03 (Variant 3)](../../../art/generated/enemies/lava_slime_03.png)

| Asset id | Role | File |
|---|---|---|
| `lava_slime` | Canonical image | `../../../art/generated/enemies/lava_slime.png` |
| `lava_slime_01` | Variant 1 | `../../../art/generated/enemies/lava_slime_01.png` |
| `lava_slime_02` | Variant 2 | `../../../art/generated/enemies/lava_slime_02.png` |
| `lava_slime_03` | Variant 3 | `../../../art/generated/enemies/lava_slime_03.png` |

## Drops

| Drop | Chance | Notes |
|---|---|---|
| [Slime Gel](../items/slime_gel.md) | 60% | Live drop table. |
| [Obsidian](../items/obsidian.md) | 30% | Live drop table. |
| [Hellstone](../items/hellstone.md) | 15% | Live drop table. |

## Related Pages

- [Bestiary](../bestiary.md)
- [Items](../items.md)
- [Wiki Overview](../wiki.md)
