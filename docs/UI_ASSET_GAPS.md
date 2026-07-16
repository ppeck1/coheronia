# Coheronia — Runtime Asset & Variant Audit (FQ-13P0)

State: refreshed on 2026-07-16 after native HUD-kit stabilization, authored
opening cels, and the 120-file player-gear integration. Regenerate
the machine portion any time with
`python scripts/asset_audit.py` (add `--strict` to fail on data bugs); the UI
placeholders are (re)built with `python scripts/gen_ui_placeholders.py` and the
legacy demo player variants can be inspected with
`python scripts/gen_player_variants.py` (it preserves reviewed files unless
`--force-demo` is explicitly passed).

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
| blocks | `world._build_tileset` / `_set_tile` (tileset source per variant) | ✅ (all live ids) | ✅ (17 pools) | per-cell `posmod(hash(x,y,seed))` | code-drawn `_make_block_texture` |
| items | `hud.item_icon` / `visual_texture("items", …)` | ✅ | ❌ (none authored) | canonical only | `item_fallback_color` swatch |
| enemies | `simple_threat._select_sprite` (once at creation) → variant pool, else `visual_texture` | ✅ (all 6 live ids) | ✅ (6 pools) | per-instance `posmod(hash(id:cell:seed))`, fixed for life | canonical → family-tinted drawn rect |
| players | `player_visual._select_body_texture` → variant pool, else `visual_texture("players", body_id)` | ✅ (all 10 body ids) | ✅ (10 pools) | character-owned `visual_variant` (0 = canonical, k>0 = pool[k-1] wrapped) | canonical → same-species default → drawn 16×32 rig |
| player_gear | `player_visual._gear_texture` / `_tool_swing_texture` (body-specific → generic) | ✅ partial (30 crude-armor statics + 90 pick/axe swing PNGs) | phases are authored action frames, not variant pools | equipped item/body id and swing phase | rig-aware procedural gear overlay |
| structures | `visual_texture("structures", "town_hall")` | ✅ | ❌ | canonical only | drawn hall |
| backgrounds | `world_backdrop.layer_texture` → `visual_texture("backgrounds", id)` | ✅ | ❌ | canonical only | gradient/silhouette |
| back_walls | `world._make_wall_texture` → `visual_texture("back_walls", id)` | ✅ | ❌ | canonical only | darkened block texture |
| ui | `hud._load_hud_kit_layout` / `_build_hud_kit` first, then legacy painted/modular paths | ✅ (19-asset native kit plus legacy hooks) | n/a | Contract-v2 JSON owns outer and inner runtime rectangles, alpha rules, trim keep-outs, state families, and decorative layers; runtime values/actions remain children | FQ-21 sliced band -> FQ-19 modular/code fallback |
| opening | `prologue.gd` authored-cel hook | ✅ eight pools / ten PNGs | frames = **animation** | ordered `(tick*8/TICK_HZ) % n` @ 8fps | `prologue_canvas` plot |

### HUD sub-surfaces

**Current primary path (2026-07-16):** the dock consumes 19 native-size RGBA
layers from `art/generated/ui_painted/`, with every rectangle owned by
`hud_dock_layout.json`. Authored source lives in
`art/source_templates/hud_dock/` and promotes through
`scripts/art/sync_hud_kit.py`. Health/attunement fills, labels, item icons,
counts, hotkeys, selection, hover/press state, and FX are runtime children.
The command-center module controls are outside the primary dock, and Map and
Events may remain open together. The FQ-21/FQ-20/FQ-19 material below records
fallback/history rather than the current art-authoring target.

The HUD now has one primary bottom player-state dock. Settlement, goal, event,
and map modules remain independently toggleable:

| Surface | Today | Reserved hook id(s) |
|---|---|---|
| HUD ornament / dock | **final 9-sliced metal backplate consumed (FQ-19)**; same frame reused by crest/goal/events modules | `dock_backplate` ✅ |
| Health orb | masked bottom-up liquid + damage flash / recovery glow / low pulse (FQ-19) | `orb_health_frame` ✅, `orb_fill_mask` ✅ |
| Attunement orb | masked liquid + regen shimmer, outward use-pulse, rotating full-charge core (FQ-19) | `orb_attunement_frame` ✅, `orb_fill_mask` ✅ |
| Events / time | framed top-right panel with the exact settlement clock (`Day N • Phase HH:MM`) | future event glyphs |
| Inventory slots | final slot frames consumed; key number + raised selected slot (FQ-19) | `slot_inventory` ✅, `slot_inventory_selected` ✅, `slot_inventory_invalid` (authored, reserved) |
| Equipment slots | code-drawn cells | (reuse `slot_inventory*`) |
| Panel / nav buttons | **four dock glyph buttons consumed (FQ-19)**, text fallback kept | `button_inventory` ✅, `button_character` ✅, `button_town_hall` ✅, `button_skills` ✅; `button_goals`, `button_settings` (authored, reserved) |
| Drag cursors | none (panels read-only) | `cursor_drag_valid`, `cursor_drag_invalid` (authored, reserved) |
| Status icons | none | (deferred — enumerate when statuses land) |
| Contextual stack | code-drawn framed entries: selected item, save toast, interaction prompt (FQ-19) | (none needed — text surfaces) |

**FQ-20 painted chrome lane** (`art/generated/ui_painted/`, sliced from the
operator's blueprint mockup by `scripts/art/slice_hud_chrome.py`): thirteen
free-size RGBA renders — `panel_frame_plain`/`panel_frame_ornate` (module
frames; the ornate one also borders the mini-map), `corner_medallion` (crest
ornament), `chip_frame` (contextual entries + command-center toggles),
`dock_plate`, `slot_frame`/`slot_frame_selected`, four `button_*` glyphs, and
both `orb_*_frame` rings with punched glass (geometry in hud.gd
`PAINTED_ORB_GEOMETRY`). All thirteen are LIVE (`UI_PAINTED_CONSUMED` in
`asset_audit.py`); each consumer falls back to the FQ-19 generated art, then
the code-drawn style. The lane is exempt from the 32×32/16-color contract and
is verified by a dedicated light pass in `verify_pixel_assets.py`.

FQ-19 replaced the placeholder look with final art for the ten consumed ids:
`scripts/art/gen_hud_final_art.py` is the deterministic authority (one shared
iron/brass material language, 32×32, ≤16 colors, stretch-safe 9-slice edges).
`scripts/gen_ui_placeholders.py` now preserves existing files by default and
only rewrites the placeholder look with an explicit `--force-placeholder`.
The centralized status authority remains `RESERVED_UI_IDS`/`UI_CONSUMED` in
`scripts/asset_audit.py`. Every consumer keeps its code-drawn fallback, so a
missing PNG is never an error. Still `PLACEHOLDER_AUTHORED` (reserved, not
consumed): `slot_inventory_invalid`, `button_goals`, `button_settings`, and
both drag cursors.

## Authored coverage result

- All 20 rendered block ids have canonical PNGs. Seventeen material/flora ids
  also have three deterministic variants; only `torch`, `lantern`, and
  `town_hall_core` remain intentionally canonical-only.
- All 43 inventory/live-drop ids have canonical icons. The five formerly
  metadata-less live drops (`chitin`, `silk`, `eyes`, `coins`,
  `scrap_weapons`) now have `items.json` names/colors/descriptions;
  `asset_audit.py` also derives ids from live enemy drops so future omissions
  remain visible even before metadata is backfilled.
- All six live enemies have a canonical sprite and three variants.
- All ten player body ids have a canonical body and two selectable Look
  alternatives. Every Look preserves its rig's exact skin-palette entries, so
  the live appearance recolor works for canonical and alternate art. No
  data-referenced block/item/live-enemy fallback remains.
- Player gear now includes 120 body-specific PNGs: crude helmet/torso/feet for
  all ten body ids and phases 0/1/2 for basic pick, forged pick, and crude axe.
  Other equipment remains on the procedural fallback; overlay refresh/alignment
  after some transitions is a known presentation defect.
- Opening art now includes all eight scene pools (ten PNGs total); the plotted
  cinematic remains the deterministic fallback.

## Placeholder hooks (`PLACEHOLDER_REQUIRED`)

- `art/generated/ui/*` — the fifteen reserved HUD/orb/slot/button/cursor ids
  are now **authored** deliberate placeholders (FQ-13P2). Two are consumed
  (`slot_inventory*`); the rest are `PLACEHOLDER_AUTHORED`, reserved for the HUD
  redesign.
- `art/generated/player_gear/*` — partially authored (120 PNGs); uncovered
  equipment and any unresolved body-specific lookup use procedural fallback.
- `art/generated/opening/*` — eight authored pools / ten PNGs live; the
  code-plotted cinematic remains a fallback, not the only presentation.

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

**Operator-confirmed (2026-07-14): full-body pool.** The operator selected the
full-body-pool direction over layered composition; that is the authority for the
player-variation slice. Layered composition remains the documented future
upgrade only.

**Built (FQ-13P3).** `player_visual._select_body_texture` reads the character's
`visual_variant` (0 = canonical `<body_id>.png`; k>0 = the k-th
`<body_id>_NN.png` pool entry, wrapped by pool size, falling back to canonical).
The index is character-owned (`game_state.create_character` /
`player.apply_character`), persisted in the shell character record, **never in
world saves**, and legacy characters get a stable default from
`default_visual_variant(id)`. All ten body ids now ship two authored
alternatives. The creation screen's Look control (`shell_ui.gd`) reads the real
pool length and disables itself if a future body has no alternates, so the UI
cannot offer absent/no-op values.

## Variant vs animation frame semantics (FQ-13P4)

The `<id>_NN.png` convention is shared for **file discovery**, but the runtime
consumes it two ways that must never be conflated (`visual_assets.json`
`frame_semantics`):

- **Variant** (an alternate visual *form* — pick one, hold it): `blocks` (per
  cell `posmod(hash(x,y,seed))`), `enemies` (per instance at spawn), `players`
  (character-owned `visual_variant`). `VARIANT_CONSUMERS` in `asset_audit.py`.
- **Animation** (a *moment in time* — play frames in order): `opening`, whose
  `prologue.gd` cel hook loops `(tick*8/TICK_HZ) % n` at 8fps for the scene.
  `ANIMATION_CATEGORIES` in `asset_audit.py` reports these as `frames=N ANIMATION`.

Item icons are intentionally **canonical-only** (no pool): `item_icon` is cached,
so an inventory stack never shows a different icon between refreshes.

## Audit tool

`python scripts/asset_audit.py` prints the per-category status table, the
`FALLBACK_ONLY` list, the reserved UI hooks, and two note classes:
- **FINDINGS** — informational gaps (e.g. `AVAILABLE_NOT_CONSUMED`); never fail.
- **DATA BUGS** — variant sequence gaps, pools above the runtime maximum of
  eight, wrong dimensions, unreadable PNGs;
  `--strict` exits non-zero on these. (Manifest-entry→missing-file is also hard-
  failed by `scripts/validate_repo.py`.)

Current state: **0 findings, 0 data bugs** (enemy pools consumed as of FQ-13P1).

## What remains temporary (tracked)

| Surface | State | Resolved by |
|---|---|---|
| Enemy sprite variety | ✅ LIVE | done — FQ-13P1 wired the enemy variant pools |
| Current block/item/live-enemy canonicals | ✅ LIVE | all data-referenced ids authored in the 2026-07-14 art run |
| HUD slot frames | ✅ LIVE | done — FQ-13P2 (consumed `slot_inventory*`) |
| HUD orbs / nav buttons / dock / cursors | `PLACEHOLDER_AUTHORED` | orb frames are LIVE in the bottom dock; dock art, fill mask, buttons, and cursors remain replaceable hooks |
| Player cosmetic variants | ✅ LIVE | two alternatives for every current body; dynamic creation Look range |
| Block variant pools | ✅ LIVE | three variants for 17 high-repetition block ids |
| Item icons | ✅ stable by design | canonical-only, cached (FQ-13P4) |
| Opening cel shots | ✅ LIVE (animation semantics) | eight pools / ten PNGs; plotted fallback retained |
| Player gear overlays | PARTIAL / known polish issue | 120 crude-armor/tool PNGs live; extend uncovered ids and harden refresh/alignment |
| Primary HUD chrome | LIVE contract / provisional art | replace only through the 19-asset HUD Asset Replacement Studio workflow |

**FQ-13P arc status: complete (P0–P4).** The audit + tooling, enemy variant
consumption, deliberate UI placeholders, player cosmetics, and the
variant-vs-animation formalization are all live. The 2026-07-14 art run closes
the current canonical and high-repetition variation backlog. Remaining image
work is deliberately gated: uncovered player gear and swing polish, native-kit
HUD replacement art, optional opening animation expansion, and assets for
future systems.
