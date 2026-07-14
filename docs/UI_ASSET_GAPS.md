# Coheronia — Runtime Asset & Variant Audit (FQ-13P0)

State: audited against the working tree at FQ-13 (run
`20260714_coheronia_fq13_enemy_variety`). Regenerate the machine portion any
time with `python scripts/asset_audit.py` (add `--strict` to fail on data bugs).

This document is the human authority for the FQ-13P visual-consolidation arc: it
records, per category, what art exists, what the runtime actually consumes, and
what each unfinished surface's explicit state is. `scripts/asset_audit.py` is the
machine authority for the mechanical facts (file inventory, sequence gaps,
dimensions, orphaned variant pools); this doc adds the runtime-consumer mapping
and the design decisions the script cannot infer from the filesystem.

## Status vocabulary

| Status | Meaning |
|---|---|
| `LIVE` | canonical image (and/or its variants) is loaded and drawn at runtime |
| `AVAILABLE_NOT_CONSUMED` | valid files exist on disk but no runtime path reads them |
| `PLACEHOLDER_REQUIRED` | player-facing surface with no asset and no styled hook yet |
| `FALLBACK_ONLY` | no asset; a code-drawn color/shape fallback covers it (acceptable) |
| `DEFERRED` | intentionally code-drawn / future work (e.g. opening cinematic cels) |

## The visual pipeline (unchanged by this audit)

- **Authority**: `data/visual_assets.json` — `asset_root` (`art/generated`),
  per-category `<id>.png` convention, optional explicit path/array overrides,
  `target_sizes`, and the FQ-09V variant convention.
- **Canonical load**: `BlockRegistry.visual_texture(category, id)` →
  `_texture_from_file` (via `Image.load_from_file`, cached, misses cached as
  null). Missing images are never an error — callers fall back.
- **Variant pool**: `BlockRegistry.visual_variant_textures(category, id)` — an
  explicit array, else the consecutive `<id>_01.png … <id>_08.png` convention
  (first gap ends the scan, capped at `MAX_VARIANTS = 8`).
- **Determinism**: block variant choice is `posmod(hash(Vector3i(cell.x, cell.y,
  world_seed)), n)` — stable per seed+cell, never saved.

## Category audit

Runtime-consumer column names the exact call site. "Canonical live" = the
single `<id>.png` path is read; "Variants live" = the `_NN` pool is read.

| Category | Runtime consumer | Canonical live | Variants live | Selection rule | Fallback rule |
|---|---|---|---|---|---|
| blocks | `world._build_tileset` / `_set_tile` (tileset source per variant) | ✅ | ✅ (mechanism) | per-cell `posmod(hash(x,y,seed))` | code-drawn `_make_block_texture` |
| items | `hud.item_icon` / `visual_texture("items", …)` | ✅ | ❌ (none authored) | canonical only | `item_fallback_color` swatch |
| enemies | `simple_threat._draw` → `visual_texture("enemies", id)` | ✅ | **❌ NOT CONSUMED** | canonical only | family-tinted drawn rect |
| players | `player_visual.sync_from_player` → `visual_texture("players", body_id)` | ✅ | ❌ (none authored) | species+presentation body id | drawn 16×32 body rig |
| player_gear | (none — overlays are drawn) | ❌ | ❌ | — | procedural gear overlay |
| structures | `visual_texture("structures", "town_hall")` | ✅ | ❌ | canonical only | drawn hall |
| backgrounds | `world_backdrop.layer_texture` → `visual_texture("backgrounds", id)` | ✅ | ❌ | canonical only | gradient/silhouette |
| back_walls | `world._make_wall_texture` → `visual_texture("back_walls", id)` | ✅ | ❌ | canonical only | darkened block texture |
| ui | (none) | ❌ | ❌ | — | code-drawn HUD |
| opening | (none — code-plotted) | ❌ | ❌ | — | `prologue_canvas` plot |

### HUD sub-surfaces (all currently code-drawn — no asset category yet)

The spec calls these out individually; today the HUD (`scripts/ui/hud.gd`) draws
them procedurally with no image hook, so each is `PLACEHOLDER_REQUIRED` for the
redesigned HUD:

| Surface | Today | Reserved hook id(s) |
|---|---|---|
| HUD ornament / dock | code-drawn bars | `dock_backplate` |
| Health orb | code-drawn | `orb_health_frame`, `orb_fill_mask` |
| Attunement orb | code-drawn | `orb_attunement_frame`, `orb_fill_mask` |
| Inventory slots | code-drawn cells | `slot_inventory`, `slot_inventory_selected`, `slot_inventory_invalid` |
| Equipment slots | code-drawn cells | (reuse `slot_inventory*`) |
| Panel / nav buttons | text buttons + item-icon glyphs | `button_inventory`, `button_character`, `button_town_hall`, `button_skills`, `button_goals`, `button_settings` |
| Drag cursors | none (panels read-only) | `cursor_drag_valid`, `cursor_drag_invalid` |
| Status icons | none | (deferred — enumerate when statuses land) |

The reserved UI-hook ids are the centralized authority in
`scripts/asset_audit.py` (`RESERVED_UI_IDS`); they are intentionally **not** yet
added to `visual_assets.json`, because the manifest validator requires every
entry to map to an existing file. They are added to the manifest the moment the
first placeholder PNG for each is authored (FQ-13P1+).

## Findings (informational — do not fail the build)

- **`AVAILABLE_NOT_CONSUMED`: enemy variant pools.** `cave_crawler_01..03`,
  `raider_basic_01..03`, `surface_slime_01..03` (nine 16×16 PNGs) exist and are
  valid, but `simple_threat._draw` reads only the canonical `<id>.png`. This is
  the headline gap: **FQ-13P1** wires `visual_variant_textures("enemies", id)`
  with a lifetime-stable, deterministic per-enemy selection (add `"enemies"` to
  `VARIANT_CONSUMERS` in `asset_audit.py` when done).
- **Blocks: variant mechanism live but no pools authored.** The per-cell
  selection path is fully live; there are simply no `<block>_NN.png` files yet.
  Dropping in e.g. `stone_01.png`/`stone_02.png` activates variety with zero
  code change — a low-risk future art task, not a gap to fix in code.

## FALLBACK_ONLY (referenced in data, no canonical art — code-drawn, acceptable)

Everything added since the first art pass renders from code fallbacks and is
safe, but is the natural authored-art backlog:

- **blocks**: `coal`, `copper_ore`, `tin_ore`, `iron_ore`, `silver_ore`,
  `crystal` (FQ-10 ores); `farm_soil`, `crop_seedling`, `crop_ripe` (FQ-12).
- **items**: the five ingots (FQ-11); `crop_seeds` and the crop/soil display
  items (FQ-12); `meat`, `thorn_quill`, `hide_scrap`, `ore_flecks`, `shell`,
  `oil_rags`, `torch_heads` (FQ-13 drops).
- **enemies**: `thornrat`, `ore_tick`, `raider_torchbearer` (FQ-13) — no
  canonical or variant art; family-tinted drawn-rect fallback only.

## Placeholder hooks (`PLACEHOLDER_REQUIRED`)

- `art/generated/ui/*` — the fifteen reserved HUD/orb/slot/button/cursor ids
  above. Empty category today (`.gitkeep` only).
- `art/generated/player_gear/*` — empty; gear is drawn procedurally.
- `art/generated/opening/*` — `DEFERRED` (the cinematic is code-plotted by
  design; cel-shot upgrade is optional per `opening_convention`).

## Player cosmetic-variation decision (bounded approach)

The FQ-13P spec requires choosing one bounded approach for optional player
cosmetic variation **before implementation**. Decision for this arc:

> **Full-body pool**, reusing the existing FQ-09V `<id>_NN.png` convention:
> `art/generated/players/<species>_<presentation>_01.png`,
> `…_02.png`, … (e.g. `human_masculine_01.png`). `human.png`/`human_female.png`
> remain the canonical single (variant 0).

Rationale: it reuses `visual_variant_textures` verbatim (no new layer
compositor, z-ordering, or per-layer palette machinery), keeps `player_visual`'s
single-texture resolve almost unchanged, and each character simply stores a
`visual_variant` index. `Masculine`/`Feminine` stay **semantic presentation**
fields, never a variant axis.

Persistence & determinism (design for FQ-13P-player, not built in P0):
- Character-owned integer `visual_variant` (presentation-only; **never** enters
  world saves — mirrors the block-variant no-save rule).
- Legacy characters get a deterministic default from a stable hash of the
  character id (no appearance change across loads).
- Selection at draw time is `variant % pool_size`, so a character with variant 3
  and a 2-image pool falls back cleanly to the canonical single.
- Creation UI later exposes prev/next (or a repeatable "randomize") preview.

The layered cosmetic-pool approach (base + hair/beard/trim layers) is recorded
as the **documented future upgrade** if mix-and-match cosmetics are wanted; it is
explicitly out of scope for this bounded slice.

**Operator review requested:** confirm the full-body-pool direction (vs.
layered) before FQ-13P wires player variation, since it sets the sprite-authoring
shape for every species×presentation.

## Audit tool

`python scripts/asset_audit.py` prints the per-category status table, the
`FALLBACK_ONLY` list, the reserved UI hooks, and two note classes:
- **FINDINGS** — informational gaps (e.g. `AVAILABLE_NOT_CONSUMED`); never fail.
- **DATA BUGS** — variant sequence gaps, wrong dimensions, unreadable PNGs;
  `--strict` exits non-zero on these. (Manifest-entry→missing-file is also hard-
  failed by `scripts/validate_repo.py`.)

Current state: **3 findings** (the enemy pools), **0 data bugs**.

## What remains temporary (tracked)

| Surface | State | Resolved by |
|---|---|---|
| Enemy sprite variety | `AVAILABLE_NOT_CONSUMED` | FQ-13P1 (wire enemy variant pools) |
| New FQ-10/11/12/13 sprites | `FALLBACK_ONLY` | authored-art backlog (`docs/ASSET_ROADMAP.md`) |
| HUD orbs / slots / buttons / dock | `PLACEHOLDER_REQUIRED` | FQ-13P (HUD redesign + generated placeholders) |
| Player cosmetic variants | not built | FQ-13P-player (full-body pool, pending operator OK) |
| Block variant pools | mechanism live, no files | art backlog (drop-in, no code) |
| Opening cel shots | `DEFERRED` | optional per `opening_convention` |
