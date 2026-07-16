# Skills

Generated: 2026-07-15

## Scope

- Source data: `data/progression/perks.json`.
- Live UI consumer: `scripts/ui/skill_tree_panel.gd`.
- Save and point economy are runtime-owned; this wiki page is a planning and review surface only.

## Current Runtime Shape

| Field | Current state |
|---|---|
| Point rule | One perk point per player level above 1. |
| Live lane | Miner. |
| Planned lanes | Builder, Warden, Forager, Ruler, Explorer, Artisan. |
| Purchase state | Stored in the world save progression state. |
| UI surface | Skill Constellations panel, opened from the live HUD path. |
| Visual treatment | Star-map presentation over data-driven perk nodes. |

## Live Miner Lane

| Perk | Cost | Effect key | Effect value | Requires | Implementation status |
|---|---:|---|---:|---|---|
| Stone Recovery | 1 | `mining_speed` | 1.15 | none | Live mechanical value. |
| Deep Sense | 1 | `detect_ore_range` | 1.20 | Stone Recovery | Groundwork; needs ore sensing feature before it is meaningful in play. |
| Tunnel Safety | 2 | `cave_safety` | 1.20 | Stone Recovery | Groundwork; needs cave hazard feature before it is meaningful in play. |

## Planned Lanes

| Lane | Theme | Gate | Current status |
|---|---|---|---|
| Builder | Physical construction, placement reach, structural bonuses | labor | Planned data only. |
| Warden | Defense, threat control, guard command | combat | Planned data only. |
| Forager | Food, ecology, yield, farming, rare plant sensing | survival | Planned data only. |
| Ruler | Governance, morale, legitimacy, base growth | civic | Planned data only. |
| Explorer | Movement, discovery, fall resistance, biome reveal | exploration | Planned data only. |
| Artisan | Crafting quality, durability, station efficiency | craft | Planned data only. |

## Serious Work Needed

| Area | Why it matters | Suggested next wiki-ready definition |
|---|---|---|
| Lane ownership | Planned lanes exist, but their gameplay loops are unevenly defined. | Add one acceptance note per lane: source of XP, first useful perk, and live system dependency. |
| Effect semantics | Some effect keys are groundwork without shipped consumers. | Split each perk into `live consumer`, `stub consumer`, or `no consumer yet`. |
| Image direction | The star-map panel has a clear mood, but no authored skill icon set is documented. | Add a future `art/generated/skills/<perk_id>.png` convention only after runtime code agrees. |
| Balance | Current costs are simple and readable, but not yet tied to a broad progression curve. | Record target time-to-first-perk, time-to-branch, and total points by milestone. |
| Public wording | Planned perks should not read like shipped features. | Keep planned lanes marked as planned data until their consumers exist. |

## Continuation Prompt For Skill Work

```text
Continue Coheronia skill-system planning from the current repo state. Read docs/wiki/skills.md, data/progression/perks.json, scripts/ui/skill_tree_panel.gd, and the live progression/save code before editing. Keep wiki wording separated from runtime changes. Do not imply planned lanes are shipped gameplay. For every proposed skill addition, document the effect key, live consumer, XP gate, prerequisite, cost, and art need. Avoid references to named commercial games, studios, characters, sprite sheets, UI styles, or living artists.
```

## Related Pages

- [Current Live](current_live.md)
- [Planned Data](planned_data.md)
- [Image Continuation](image_continuation.md)
- [Status Browser](status_browser.md)
- [Wiki Overview](wiki.md)
