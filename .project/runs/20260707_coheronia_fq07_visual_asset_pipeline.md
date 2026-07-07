# Run Ledger: 20260707_coheronia_fq07_visual_asset_pipeline

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + sonnet review agent (recon skipped: all target surfaces already mapped in-session) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-07 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-07T16:45:00-04:00 |
| Ended At | 2026-07-07T17:30:00-04:00 |

## User Request

"proceed" — continue the queue with the same agent pipeline: FQ-07, visual
asset pipeline with color fallback.

## Agent Protocol Notes

Token-saving variation: the Explore recon step was skipped because every
target surface (world._make_block_texture, simple_threat._draw, BlockRegistry,
hud bottom-left) had already been read or quoted verbatim earlier in the same
session; the sonnet review agent still ran as the correction loop. Review
found no must-fix; three should-fix and three nits were applied (typed-var
mismatch; invisible overbright hurt tint replaced with a subtractive red
tint; smoke temp art renamed to gitignored smoke_tmp_* names routed through
the explicit-override path — which the smoke now also exercises; validator
category-type guard; template doc corrections for per-category resize
behavior and the export-build caveat), then the loop re-ran green.

## Scope (design decisions, now documented)

1. Data surface: data/visual_assets.json — asset_root (art/generated),
   documented convention art/generated/<category>/<id>.png, per-category
   target sizes, and explicit path overrides per id. Categories: blocks,
   items, enemies, ui.
2. Loading: BlockRegistry.visual_texture(category, id) uses
   Image.load_from_file + ImageTexture — deliberately NOT the Godot import
   system, so the plain non-editor runs this repo always uses pick up new
   art with no import pass (an exported PCK build would need an import-aware
   path; documented caveat, out of scope). Misses cache as null;
   clear_visual_cache resets.
3. Render sites, all fallback-preserving: block tileset textures (image
   nearest-neighbor resized to the tile so stray dimensions cannot corrupt
   the tileset; collision/occlusion untouched — they derive from block data,
   not textures), enemy sprites (drawn centered at raw size; damage shown as
   a subtractive red tint because overbright modulate clamps invisible in
   the compatibility renderer — review fix), and a new 5-slot hotbar item
   icon strip (TextureRect per slot, hidden without art, so the text hotbar
   remains the fallback).
4. Workflow docs: art/source_templates/ASSET_TEMPLATE.md — naming rules,
   per-category sizes with the resize-is-blocks-only clarification, prompt
   skeletons for local Ollama/image-model iteration (explicitly outside the
   game and validation), and a review checklist. art/generated/* committed
   with .gitkeep files; smoke temp art (smoke_tmp_*.png) gitignored.
5. Validator policy: broken explicit visual_assets.json references FAIL
   (data bug); convention-path gaps print INFO lines and never fail — art
   arrives one asset at a time.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. visual assets schema; 17 INFO lines list pending optional assets without failing |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 173/173 (was 169), zero failures; fresh results file verified by LastWriteTime; no temp art left behind |
| `git diff --check` | PASS | exit 0 |

New smoke checks (4): fq07_visual_assets_loads (four categories),
fq07_missing_assets_fall_back (null lookups, generated block texture still
renders, icons hidden — no crash), fq07_block_renders_from_image (a
runtime-written magenta PNG wins pixel-for-pixel via the explicit-override
path, and the generated dirt-brown returns after removal),
fq07_item_renders_from_image (item art lights its hotbar icon; removal hides
it). The section self-cleans and starts by removing any leftover from a
previously killed run.

## Review Findings And Resolutions

- SHOULD-FIX (fixed): `var art: Texture2D` returned from a function typed
  `-> ImageTexture` — editor static-checker error; now cast to ImageTexture.
- SHOULD-FIX (fixed): the enemy hurt tint used overbright modulate
  (Color(1+h,...)), which clamps to white and made damage invisible on the
  art path — replaced with a subtractive red tint.
- SHOULD-FIX (fixed): smoke temp art used real asset filenames
  (blocks/dirt.png), risking untracked leftovers colliding with future real
  art — renamed to gitignored smoke_tmp_* files mapped through explicit
  visual_assets overrides, which additionally exercises the override path.
- NIT (fixed): validator crashed on a non-dict category value — isinstance
  guard added.
- NIT (fixed): ASSET_TEMPLATE.md wrongly implied all categories auto-resize
  — now states blocks-only, with the enemy raw-size warning.
- NIT (fixed): the non-exported-run assumption behind Image.load_from_file
  is now documented in the template and HANDOFF.

## Acceptance vs FQ-07

- Missing images do not crash and use the fallback
  (fq07_missing_assets_fall_back; the whole 169-check legacy suite runs on
  fallbacks — the repo ships zero art).
- At least one block and one item render from image when present
  (fq07_block_renders_from_image pixel-verified; fq07_item_renders_from_image
  hotbar icon; enemies additionally supported).
- Validator reports missing optional assets as informational, not failure
  (INFO lines; exit 0; broken explicit refs still fail as real data bugs).
- Asset naming/template docs cover naming rules, target sizes, prompt notes
  for local model iteration, and a review checklist; Ollama is required
  nowhere in the game or validation path.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260707_coheronia_fq07_visual_asset_pipeline.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260707_coheronia_fq07_visual_asset_pipeline.json`

## Git Closeout

Implementation commit `717a5a5` (code, data, art scaffolding, docs), then
this evidence-only commit; both pushed to origin/main.

## Remaining Risks

- The repo ships no actual art; the pipeline is proven by smoke only. First
  real art pass will exercise it at scale (FQ-08 damage visuals and FQ-09
  visual panels build on this).
- Art loads bypass the import system by design — an exported build would not
  see art/generated files (documented; this repo never exports).
- Block art appears at world entry (tileset build time); no hot-reload.
- Player and Town Hall visuals remain drawn shapes — image support for them
  is future work when their art lands.

## Next Action

FQ-08 (block and enemy damage visuals) is next in the queue.
