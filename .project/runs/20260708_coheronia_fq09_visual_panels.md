# Run Ledger: 20260708_coheronia_fq09_visual_panels

## Constitutional Rule

Every run records evidence; only signable runs update accepted truth.

## Run Identity

| Field | Value |
|---|---|
| Project | Coheronia |
| Project ID | coheronia-game |
| Agent | Claude (Fable 5) orchestrator + sonnet review agent (recon skipped: HUD surfaces fully in-session) |
| Capsule Version | 0.2 |
| Run State | SIGNABLE |
| Queue Item | FQ-09 (docs/FABLE_TASK_QUEUE.md) |
| Started At | 2026-07-08T07:10:00-04:00 |
| Ended At | 2026-07-08T07:55:00-04:00 |

## User Request

"proceed" — continue the queue with the same agent pipeline: FQ-09, visual
inventory, toolbelt, and village panels.

## Agent Protocol Notes

Recon skipped (every HUD/registry surface was already read in-session); the
sonnet review agent ran as the correction loop. Review found no must-fix; two
should-fix items (items.json added to the validator's required files with a
schema check; station button icons now re-resolve on every panel refresh
instead of binding once at build) and four nits (stale fq07 comment, redundant
font override, the stockpile (empty) label moved out of the grid into a
toggled label, an intentional-shared-StyleBox comment) were applied, then the
full loop re-ran green.

## Scope (design decisions, now documented)

1. Item metadata: new data/items.json — display names, one-line descriptions
   (tooltips), and fallback swatch colors for non-block item ids (food,
   drops, forge icons) plus icon colors for block items.
   BlockRegistry.display_name now falls back blocks -> items.json -> id,
   improving every log and tooltip surface; item_description feeds hovers.
2. Icons everywhere via BlockRegistry.item_icon(id): FQ-07 art when present,
   else a generated 16x16 swatch (items.json color, else a stable
   hash-derived hue so unknown ids still get distinct icons). Cached;
   cleared together with the FQ-07 visual cache so late-arriving art is
   picked up.
3. Toolbelt: five PanelContainer slot tiles — always-visible icon, count
   label, numbered tooltip, and a gold border StyleBox on the selected slot
   (shared instances, documented). The text line keeps the extras +
   tool/gear summary; per-item text moved into the tiles.
4. Inventory panel: 6-column icon grid of stacks (count under each tile,
   display name + descriptor on hover) ABOVE the existing detail text, which
   is unchanged so all prior text assertions (wave_c, fq03, fq04) still hold.
5. Town Hall panel: the stockpile text list became an icon grid (with a
   toggled "(empty)" label outside the grid); station buttons carry item
   icons re-resolved on every refresh; disabled/crafted states keep the
   engine dimming plus the existing state text.
6. Keyboard/mouse behavior unchanged: I inventory, 1-5 hotbar, E/T town,
   K skills, Esc chain untouched.

## Validation Evidence

| Check | Result | Evidence |
|---|---|---|
| `python scripts/validate_repo.py` | PASS | incl. the new items.json requirement + schema check |
| `capsule_doctor.py . --profile public_repo` | PASS | `Result: healthy` |
| `COHERONIA_SMOKE=1` waited windowed Godot run | PASS | 183/183 (was 179), zero failures; fresh results file verified by LastWriteTime |
| `git diff --check` | PASS | exit 0 |

New smoke checks (4): fq09_toolbelt_slots_live (per-slot counts match the
inventory; selected highlight follows the selected slot 0 -> 2),
fq09_inventory_grid_reflects_counts (panel open, grid dirt=7/wood=2/stone=0),
fq09_town_stockpile_grid (grid mirrors the hall stockpile),
fq09_counts_after_mine_craft_deposit_load (mine +1 dirt -> craft_torch
produces 3 torches in the grid -> deposit raises the stockpile grid (torches
correctly not depositable) -> load restores grid to the saved inventory
exactly). The fq07 hotbar item check was rewritten to art-vs-fallback
semantics (hotbar_icon_is_art) because slots now always display an icon.

## Review Findings And Resolutions

- SHOULD-FIX (fixed): data/items.json was not validator-required despite
  being a runtime-loaded data file — added to REQUIRED_FILES with a minimal
  schema check, matching repo precedent.
- SHOULD-FIX (fixed): station Button.icon values were bound once at build
  and survived clear_visual_cache — refresh_town_panel now re-resolves all
  station icons via _refresh_station_icons.
- NIT (fixed): stale fq07 comment claimed hotbar icons "stay hidden".
- NIT (fixed): redundant double font-size override in _make_item_tile.
- NIT (fixed): the stockpile "(empty)" label now lives outside the grid and
  toggles, instead of occupying a single grid cell.
- NIT (fixed): the intentionally shared slot StyleBox instances carry a
  clone-before-mutating comment.
- Review confirmations: queue_free tile rebuilds leak nothing and the
  one-frame coexistence is harmless; the two icon caches resolve through one
  visual cache so the art-equality smoke logic cannot falsely fail;
  display_name chain is backwards-compatible; the town panel grows within
  screen bounds at 1080p (low-resolution clipping is a pre-existing concern).

## Acceptance vs FQ-09

- Inventory panel still opens with I and reflects current counts (binding in
  input_actions_bound; fq09_inventory_grid_reflects_counts; the legacy text
  assertions all still pass).
- Hotbar/toolbelt remains usable during play (same key handling; slot tiles
  update live; fq09_toolbelt_slots_live).
- Town Hall panel clearly shows stockpile and station actions (icon grid +
  icon-carrying buttons with crafted/disabled states).
- Smoke verifies counts after mine, craft, deposit, and load
  (fq09_counts_after_mine_craft_deposit_load).
- FQ-07 fallbacks used everywhere — the repo still ships zero art and every
  icon renders from swatches.

## Project Atlas Sync

State: queued — `.project/atlas_outbox/20260708_coheronia_fq09_visual_panels.json`

## BOH Sync

State: queued — `.project/boh_outbox/20260708_coheronia_fq09_visual_panels.json`

## Git Closeout

Implementation commit `59a00e2` (code, data, docs), then this evidence-only
commit; both pushed to origin/main.

## Remaining Risks

- items.json swatch colors intentionally diverge slightly from the world
  tile palette (icons vs terrain); acceptable until real art replaces both.
- The town panel is taller now; at very low resolutions it may clip — a
  pre-existing layout concern worth a pass when UI scaling arrives.
- Tooltips require mouse hover; no gamepad/keyboard inspection path yet.

## Next Action

FQ-10 (more ores and metallurgy data) is next in the queue.
