# Image Continuation

Generated: 2026-07-16

This page is the wiki handoff surface for future image work. It is meant for Codex, Claude Code, or another art agent that needs to continue the image pipeline without mistaking planned data for live gaps.

## Start Here

| Question | Best source | Why |
|---|---|---|
| What image files exist, what is missing, and what is deferred? | [IMAGE_INVENTORY_MATRIX.md](../IMAGE_INVENTORY_MATRIX.md) | Full runtime image inventory and deferred-work matrix. |
| What should the next image pass create? | [ASSET_ROADMAP.md](../ASSET_ROADMAP.md) | Asset sizes, conventions, priority notes, and prompt packs. |
| How is primary HUD chrome replaced safely? | [HUD Asset Replacement Studio](hud_asset_replacement_studio.md) | Exact native canvases, alpha rules, per-file prompts, and safe promotion commands. |
| What legacy/reserved UI art is live, placeholder-authored, or deferred? | [UI_ASSET_GAPS.md](../UI_ASSET_GAPS.md) | Legacy UI consumer and placeholder status. |
| What visual canon constraints should art follow? | `docs/ART_DIRECTION_AND_CANON.md` | Tone, palette, meaning, and public-safety guidance. |
| Which content is live vs planned? | [Current Live](current_live.md), [Planned Data](planned_data.md), [Status Browser](status_browser.md) | Prevents future art from implying planned systems are implemented. |

## Current Image State

| Family | Current state | Continue only if |
|---|---|---|
| Current blocks | Covered with canonical art and variants where applicable. | A future terrain pass is explicitly requested. |
| Current items | Covered for current item ids. | A style refresh or new item ids land. |
| Live enemies | Covered for the six live enemy families. | New live enemies land, or a variant refresh is requested. |
| Player bodies | Covered for the five live species and presentation variants. | A body/style refresh is requested. |
| Player gear overlays | Partially authored: crude armor plus basic/forged pick and crude-axe swings cover all ten bodies (120 PNGs). Other equipment falls back procedurally. | An uncovered equipment id or an approved style/alignment revision is scoped. |
| Primary HUD | Native 19-asset layered kit is live under `art/generated/ui_painted/`; runtime masks, values, icons, counts, labels, and state remain separate. | Use the HUD Asset Replacement Studio contract one file or state family at a time. |
| Legacy/reserved UI hooks | Retained as fallback or future-consumer surfaces. | A named consumer or fallback cleanup is explicitly scoped. |
| Opening frames | Eight authored pools / ten cels are live; plotted rendering remains fallback. | Approved animation or scene-variant expansion is scoped. |
| Future enemies / ancestries / systems | Planned only. | The system is promoted to live work or the operator explicitly asks for concept art. |

## Recommended Next Image Work

1. Use [IMAGE_INVENTORY_MATRIX.md](../IMAGE_INVENTORY_MATRIX.md) to confirm the current missing/deferred list.
2. For the primary dock, use the [HUD Asset Replacement Studio](hud_asset_replacement_studio.md); its authored source directory and sync tool are the authority.
3. For other families, use [ASSET_ROADMAP.md](../ASSET_ROADMAP.md) for dimensions, naming, and prompt constraints.
4. Use `docs/ART_DIRECTION_AND_CANON.md` for palette, tone, and canon.
5. Stage generated candidates outside the runtime tree unless the family has an explicit authored-source boundary.
6. Promote only validated final PNGs and run the image validation, repository validator, and appropriate visual/smoke checks.

## Public And IP Safety

- Do not use another named game, studio, character, sprite, UI, or asset sheet as a visual target.
- Do not request imitation of any living artist, commercial game, or copyrighted franchise.
- Do not copy silhouettes, sprites, UI frames, icons, palettes, maps, enemies, bosses, or exact composition from another game.
- Use Coheronia's own language instead: side-view pixel art, mythic frontier, labor-centered settlement, restrained palette, readable at native pixel scale.
- Do not bake words, logos, signatures, title text, creator names, or UI copy into generated images.
- Before public upload, scan all wiki/source docs for named-game comparison language. Replace it with generic technical language such as "side-view rear wall tiles" or "rear cave wall tiles."

## Quick Prompt For A Future Image Agent

```text
Continue Coheronia image work from the current repo state. First read docs/wiki/image_continuation.md, docs/wiki/known_issues.md, docs/wiki/hud_asset_replacement_studio.md, docs/IMAGE_INVENTORY_MATRIX.md, docs/ASSET_ROADMAP.md, docs/UI_ASSET_GAPS.md, and docs/ART_DIRECTION_AND_CANON.md. Confirm what is already authored before generating anything. Do not create art for planned-only systems unless explicitly asked. Do not reference or imitate any named commercial game, studio, character, sprite, UI, asset sheet, or living artist. Use Coheronia's own art direction: side-view pixel art, mythic frontier, labor-centered settlement, restrained palette, readable at native pixel scale. Respect each family's authored-source and runtime-promotion contract; commit only validated final PNGs.
```

## Related Pages

- [Current Live](current_live.md)
- [Known Issues](known_issues.md)
- [HUD Asset Replacement Studio](hud_asset_replacement_studio.md)
- [Planned Data](planned_data.md)
- [Status Browser](status_browser.md)
- [Wiki Overview](wiki.md)
