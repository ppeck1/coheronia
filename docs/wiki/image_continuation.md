# Image Continuation

Generated: 2026-07-15

This page is the wiki handoff surface for future image work. It is meant for Codex, Claude Code, or another art agent that needs to continue the image pipeline without mistaking planned data for live gaps.

## Start Here

| Question | Best source | Why |
|---|---|---|
| What image files exist, what is missing, and what is deferred? | [IMAGE_INVENTORY_MATRIX.md](../IMAGE_INVENTORY_MATRIX.md) | Full runtime image inventory and deferred-work matrix. |
| What should the next image pass create? | [ASSET_ROADMAP.md](../ASSET_ROADMAP.md) | Asset sizes, conventions, priority notes, and prompt packs. |
| What UI art is live, placeholder-authored, or deferred? | [UI_ASSET_GAPS.md](../UI_ASSET_GAPS.md) | UI-specific consumer and placeholder status. |
| What visual canon constraints should art follow? | `docs/ART_DIRECTION_AND_CANON.md` | Tone, palette, meaning, and public-safety guidance. |
| Which content is live vs planned? | [Current Live](current_live.md), [Planned Data](planned_data.md), [Status Browser](status_browser.md) | Prevents future art from implying planned systems are implemented. |

## Current Image State

| Family | Current state | Continue only if |
|---|---|---|
| Current blocks | Covered with canonical art and variants where applicable. | A future terrain pass is explicitly requested. |
| Current items | Covered for current item ids. | A style refresh or new item ids land. |
| Live enemies | Covered for the six live enemy families. | New live enemies land, or a variant refresh is requested. |
| Player bodies | Covered for the five live species and presentation variants. | A body/style refresh is requested. |
| Player gear overlays | Deferred; hooks exist, no PNGs yet. | The next pass is explicitly about authored equipment overlays. |
| UI hooks | Partly live and partly placeholder-authored. | A UI replacement pass is scoped. |
| Opening frames | Deferred; plotted fallback remains live. | Opening cel art is explicitly scoped. |
| Future enemies / ancestries / systems | Planned only. | The system is promoted to live work or the operator explicitly asks for concept art. |

## Recommended Next Image Work

1. Use [IMAGE_INVENTORY_MATRIX.md](../IMAGE_INVENTORY_MATRIX.md) to confirm the current missing/deferred list.
2. Use [ASSET_ROADMAP.md](../ASSET_ROADMAP.md) for exact dimensions, naming, and prompt constraints.
3. Use `docs/ART_DIRECTION_AND_CANON.md` for palette, tone, and canon.
4. Stage generated candidates outside the runtime tree.
5. Bring only final PNGs into `art/generated/<category>/`.
6. Run the repo's image validation and full repo validation before declaring the pass ready.

## Public And IP Safety

- Do not use another named game, studio, character, sprite, UI, or asset sheet as a visual target.
- Do not request imitation of any living artist, commercial game, or copyrighted franchise.
- Do not copy silhouettes, sprites, UI frames, icons, palettes, maps, enemies, bosses, or exact composition from another game.
- Use Coheronia's own language instead: side-view pixel art, mythic frontier, labor-centered settlement, restrained palette, readable at native pixel scale.
- Do not bake words, logos, signatures, title text, creator names, or UI copy into generated images.
- Before public upload, scan all wiki/source docs for named-game comparison language. Replace it with generic technical language such as "side-view rear wall tiles" or "rear cave wall tiles."

## Quick Prompt For A Future Image Agent

```text
Continue Coheronia image work from the current repo state. First read docs/wiki/image_continuation.md, docs/IMAGE_INVENTORY_MATRIX.md, docs/ASSET_ROADMAP.md, docs/UI_ASSET_GAPS.md, and docs/ART_DIRECTION_AND_CANON.md. Do not create art for planned-only systems unless explicitly asked. Do not reference or imitate any named commercial game, studio, character, sprite, UI, asset sheet, or living artist. Use Coheronia's own art direction: side-view pixel art, mythic frontier, labor-centered settlement, restrained palette, readable at native pixel scale. Stage candidates outside runtime folders; commit only final PNGs under art/generated/<category>/ after validation.
```

## Related Pages

- [Current Live](current_live.md)
- [Planned Data](planned_data.md)
- [Status Browser](status_browser.md)
- [Wiki Overview](wiki.md)
