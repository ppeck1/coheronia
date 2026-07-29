# World Depths And Fluids Artwork Review

Status: preview-only Stage 1-3 package. No live `art/generated` assets were
replaced.

## Stage 1 Contract Audit

Target canonical runtime paths after approval:

| ID | Category | Canonical file | Contract |
|---|---|---|---|
| `deepstone` | block | `art/generated/blocks/deepstone.png` | 16x16 RGBA PNG, fully opaque, max 16 visible colors |
| `bedrock` | block | `art/generated/blocks/bedrock.png` | 16x16 RGBA PNG, fully opaque, max 16 visible colors |
| `hellstone` | block | `art/generated/blocks/hellstone.png` | 16x16 RGBA PNG, fully opaque, max 16 visible colors |
| `obsidian` | block | `art/generated/blocks/obsidian.png` | 16x16 RGBA PNG, fully opaque, max 16 visible colors |
| `water` | block | `art/generated/blocks/water.png` | 16x16 RGBA PNG, hard alpha only, max 16 visible colors |
| `lava` | block | `art/generated/blocks/lava.png` | 16x16 RGBA PNG, fully opaque, max 16 visible colors |
| `bucket` | item | `art/generated/items/bucket.png` | 16x16 RGBA PNG, transparent cutout, hard alpha only, max 16 visible colors |

Runtime behavior found:

- Block and item registries are authoritative in `data/blocks.json` and `data/items.json`.
- Asset discovery is convention-based via `data/visual_assets.json`: `art/generated/<category>/<id>.png`.
- Block variant pools are consumed as `<id>_01.png`, `<id>_02.png`, and so on, up to 8, selected per cell from world seed and position.
- Item icons are canonical-only. Item `_NN` variant pools are not consumed at runtime.
- Liquids use one full-cell block texture, then `world.gd` builds 8 bottom-anchored fill tiles at runtime.
- Partial liquid tiles add a bright top surface line in code.
- Mismatched block art is nearest-neighbor resized to 16x16 by `_normalize_art`, but final files should still be exact 16x16.
- Imports for existing art use Godot texture import with `compress/mode=0`, no mipmaps, and `process/fix_alpha_border=true`.
- Current final-art validator requires hard alpha for generated pixel assets. Runtime fallback water supports soft alpha, but a promoted `water.png` with soft alpha would fail `scripts/art/verify_pixel_assets.py`.

Current fallback state:

- `deepstone`, `bedrock`, `hellstone`, `obsidian`, `water`, and `lava` have no canonical files in `art/generated/blocks`.
- `bucket` has no canonical file in `art/generated/items`.
- Rendering falls back to code-drawn block colors/shapes and item swatches.

## Stage 2 Preview Package

Contact sheets:

- `contact_sheets/deepstone_variations.png`
- `contact_sheets/bedrock_variations.png`
- `contact_sheets/hellstone_variations.png`
- `contact_sheets/obsidian_variations.png`
- `contact_sheets/water_variations.png`
- `contact_sheets/lava_variations.png`
- `contact_sheets/bucket_state_variations.png`
- `contact_sheets/all_native_preview_board.png`

Individual preview files:

- Native PNGs: `individual_previews/native/`
- 8x nearest-neighbor previews: `individual_previews/zoom_8x/`
- Gameplay-scale context previews: `individual_previews/context/`
- Candidate source PNGs by category: `variants/blocks/` and `variants/items/`

## Stage 3 Recommendation Matrix

| Target | Preferred | Why | Watchpoint |
|---|---|---|---|
| `deepstone` | B | Strong compressed strata and mineral seams; reads older than stone without looking valuable. | Slight seam color could be reduced if it competes with ore. |
| `bedrock` | B | Heavy interlocked plates, low detail, structurally final. | Very dark in caves, but that supports the boundary role. |
| `hellstone` | B | Controlled masonry-like heat cracks, distinct from lava and not over-glowing. | May benefit from one extra charred chip before final export. |
| `obsidian` | B | Best balance of black-glass mass, sparse blue/violet facets, and non-stone identity. | Keep highlights sparse so it does not become crystal. |
| `water` | C | Clearest hard-alpha partial-fill read, calm bands, low wallpaper risk. | Hard-alpha constraint means no true authored translucency unless validator changes. |
| `lava` | D | Best hazardous molten read, dark crust islands, compatible with hellstone and glow. | Could be toned down one step if paired with very hot lighting. |
| `bucket` empty/water/lava | B | Practical forged-steel silhouette, strongest hotbar readability, same base silhouette across states. | Runtime currently shows only `bucket`; content-state UI needs Claude Code's separate work. |

## Stage 4 Gate

No approved native-resolution exports were promoted to `art/generated`.

Recommended promotion after approval:

- Copy chosen block candidates to canonical block paths.
- Copy only the approved empty-bucket base to `art/generated/items/bucket.png` unless code has an approved bucket-content visual hook.
- If multiple terrain variants are approved, export them as consecutive block pools (`<id>_01.png`, `<id>_02.png`, ...). Do not create item-state `_NN` pools for bucket states because items do not consume variant pools.

## Validation Results

Commands run from repo root:

- `python scripts/validate_repo.py` - PASS
- `python scripts/asset_audit.py --strict` - PASS, clean
- `python scripts/art/verify_pixel_assets.py` - PASS, 386 generated PNGs
- `python scripts/art/gen_world_depths_fluid_variations.py` - PASS, generated preview artifacts and checked candidate size, palette, and alpha

Runtime screenshots:

- Existing captures inspected: `docs/screenshots/19_hell_biome.png`, `20_world_depths_biome.png`, `21_lava_flow_pour.png`, `23_water_surface_lake.png`, `24_lava_water_obsidian.png`.
- No new runtime screenshot was captured because no live assets were integrated.

## Files Added

- `scripts/art/gen_world_depths_fluid_variations.py`
- `art/source_templates/world_depths_fluids/REVIEW_REPORT.md`
- `art/source_templates/world_depths_fluids/variants/**`
- `art/source_templates/world_depths_fluids/contact_sheets/**`
- `art/source_templates/world_depths_fluids/individual_previews/**`

## Files Modified

- None in live gameplay, data, docs, wiki, simulation, or canonical art paths.

## Unresolved Issues

- Bucket content-state artwork is ready as a visual language, but no final UI/runtime hook should be chosen here.
- Authored water transparency is technically ambiguous: runtime can render alpha, but final generated pixel assets must use hard alpha unless the verifier is intentionally changed by the technical owner.
- Godot `.import` files for new canonical exports will need to be generated by the editor/import pass after approval.

Claude Code's documentation and simulation work was not overwritten.
