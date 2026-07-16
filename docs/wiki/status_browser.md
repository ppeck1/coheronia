# Status Browser

Generated: 2026-07-15

This page gives the wiki a quick current-vs-planned browser. It is intentionally classification-first: use it when you need to know whether a page describes live behavior, planned data, internal implementation glue, or source-only material.

## Status Groups

| Status | Meaning | Browse |
|---|---|---|
| complete | Live source and meaningful live downstream use. | [Current Live](current_live.md) |
| source-only | Live or defined source exists, but no meaningful downstream sink exists yet. | [Current Live](current_live.md) and [Planned Data](planned_data.md) |
| dead | Defined in current data, but not obtainable in current play. | [Planned Data](planned_data.md) |
| planned | Referenced only by planned data. Not live gameplay. | [Planned Data](planned_data.md) |
| internal | Runtime bridge token, not a player-facing object. | [Internal Tokens](internal_tokens.md) |

## Practical Use

- Start with [Current Live](current_live.md) for player-facing or currently obtainable things.
- Use [Planned Data](planned_data.md) for future sink notes, planned enemy drops, dead equipment definitions, and design pressure.
- Use [Internal Tokens](internal_tokens.md) for implementation bridges such as `tool_tier_2_pick`.
- Use [Recipes](recipes.md) when a status question depends on route behavior rather than item identity.

## Related Pages

- [Items](items.md)
- [Recipes](recipes.md)
- [Crafting Stations](stations.md)
- [Wiki Overview](wiki.md)
