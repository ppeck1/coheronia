# Coheronia - Handoff

## Current State (2026-07-22 release foundations: R-00..R-05 done, R-07 next)

**The presentation recovery arc is open.** FQ-00 through FQ-21 are complete;
the native HUD-kit stabilization is merged. The active planning authority is
`docs/PRESENTATION_RECOVERY_MATRIX.md` (rows PR-00 through PR-10 with
code-vs-art lane separation, the locked masculine/feminine terminology
compatibility plan, and the image-production follow-up matrix). The queue's
"Presentation Recovery Arc" section in `docs/FABLE_TASK_QUEUE.md` mirrors it.

**Verified 2026-07-20 baseline** (branch `main`, commit `f545daf`): static
validator PASS, strict asset audit PASS (clean), HUD-kit runtime verify PASS
(19 hashes + layout), Capsule Doctor `public_repo` PASS (healthy). The
waited-GUI Godot 4.6.1 smoke started this arc at **332/334 FAIL**
(`fq17_hud_edit_direct_manipulation` reset + `fq09_inventory_board_drag_and_sort`
drag payload; the `fq09u1_live_clip_switch` check that older docs misnamed as
red actually passed).

**PR-00 done 2026-07-20 — smoke back to 334/334 PASS.** Both root causes were
in `scripts/ui/hud.gd`, fixed without weakening any assertion: (1)
`_hud_default_sizes["crest"]` was captured before the crest laid out (a
`(250,40)` stub), so `reset_hud_layout` restored the wrong size and re-saved it
into `shell.json` (that stale write is what intermittently flipped the check's
`visibility`/`grip` sub-flags too) — a new `_hud_natural_size()` derives the
default from `get_combined_minimum_size()`; (2) `_clear_children` used deferred
`queue_free()`, so rebuilt board cells collided on names like
`InventoryDockSlot1` and Godot renamed the fresh ones — it now `remove_child`s
before freeing. See `docs/PRESENTATION_RECOVERY_MATRIX.md` (PR-00).

**Terminology (PR-01 done 2026-07-20):** body-variant ids are now canonical
`masculine`/`feminine`. The legacy `default`/`female` survive only as
read-time aliases in `BlockRegistry.normalize_body_variant` (data-owned
`body_variant_aliases`); no PNG was renamed — canonical ids map to the
existing `<species>`/`<species>_female` filenames via the data-owned
`body_variant_asset_suffix`. New saves write canonical ids; legacy shells
normalize on load and re-save canonical. `data/character_data.json` and
`data/player_visuals.json`, `block_registry`, the visual/creation consumers,
`validate_repo.py`, the wiki generator, the smoke, and the character wiki
pages were updated together.

**Character rendering contract (PR-02 done 2026-07-20):** the body/gear
resolution rules and the back-to-front compositing order are written up in
`docs/CHARACTER_RENDERING_CONTRACT.md` (validator-required authority) so the
in-world `PlayerVisual`, the creation preview, and the Character panel can all
compose the same character. `player_visual.gd` gained
`CHARACTER_LAYER_ORDER` (the single source of the layer order, exposed in
`presentation_snapshot()`); the `pr02_character_render_contract` smoke check
pins the snapshot key set, the layer order, and the drawn slots. No rendering
change — `_draw` is untouched. PR-02 also made the fq19 map/events geometry
check start from the default layout (like fq17) so it is independent of any HUD
size a prior run persisted into `shell.json`.

**Gear overlay resolution/refresh + alignment (PR-03A + PR-03B done
2026-07-20):** the intermittent "gear fails to appear / incomplete-looking
character" defect is fixed (PR-03A — `effective_body_id()` + refresh at the
equip/forge boundaries). PR-03B fixed overlay *alignment*: the crude helmet
floated ~6px above the head on the shorter bodies (goblin, dwarf) because
overlays are drawn full-frame at `BODY_RECT`; a data-owned per-rig, per-slot
`gear_offset` in `data/player_visuals.json` (applied via
`player_visual.gd` `gear_overlay_offset`/`_gear_rect`) now nudges the
goblin/dwarf helmet `[0,5]` onto the head, with every other body/slot identity
so aligned bodies never move. No PNG was edited.
`scripts/art/verify_gear_alignment.py` enforces helmet/head contact (<=4px)
across all ten body ids; `pr03b_gear_overlay_offset_applied` pins the runtime
offsets; a before/after contact sheet was reviewed. The non-human crude *torso*
waist placement reads as a plausible loincloth style (rig chest anchor does not
cleanly apply) and is recorded for the art lane, not shifted in code. See
`docs/PRESENTATION_RECOVERY_MATRIX.md` (PR-03A/PR-03B).

**Directional action animation (PR-04 done 2026-07-20, code half):** tool/weapon
use now plays a data-driven **windup -> impact -> recovery** cycle aimed at the
target vector instead of a uniform 3-pose loop that only read rightward. Items
own an `action_profile` in `data/equipment.json` (windup/impact/recovery
fractions, arc, direction mode; `BlockRegistry.action_profile` merges a
default); `player_visual.gd` computes `swing_direction()` (mirror-aware, so
up/down/diagonal targets read directionally), `swing_progress()`,
`swing_phase_kind()`, and draws the pick/axe swing PNGs rotated toward the aim.
The sword has no authored frames, so a presentation-only `attack_swing` timer on
`player.gd` (set when a melee hit lands, never touching damage/timing) drives the
same procedural contract. Mining/combat mechanics and the frame baselines are
unchanged. `presentation_snapshot()` gained `action_kind`, `action_item`,
`swing_phase_kind`, `swing_direction`. Smoke:
`pr04_swing_direction_follows_target` (six directions),
`pr04_action_profile_phases` (pick vs axe differ by profile), and
`pr04_sword_uses_action_contract`. No image production; new swing *art* stays in
the image matrix. Suite **341/341** (two consecutive runs).
`_gear_texture`/`_tool_swing_texture` used to key off `_resolved_body_id`, so a
valid character whose body texture was momentarily unresolved (a cleared visual
cache or a once-missing load during a character/load/world-transition/forge
refresh) silently dropped every authored overlay to the procedural fallback.
They now resolve against `effective_body_id()` — the resolved body when one
loaded, otherwise the character's intended body id — so authored gear stays
visible; and `player_visual.refresh_presentation()` re-resolves at the
equip/forge boundaries (`apply_equipment`/`equip_item`/`swap_weapon`).
Presentation only — no equipment/gameplay change, and normal-case resolution is
byte-identical (when the body resolves, `effective_body_id == resolved_body_id`).
`effective_body_id` is now in `presentation_snapshot()`. Smoke:
`pr03_gear_overlay_resolves_all_bodies` (ten bodies resolve their body-specific
crude gear) and `pr03_gear_survives_body_texture_miss` (gear survives a forced
body-texture miss via the intended body id and recovers after a refresh). The
suite is now **341/341** (including the PR-03B alignment and PR-04 action checks).

**Creation/select preview through the shared render path (PR-05 done
2026-07-21):** the character-creation screen and every character-select row now
compose the live figure through **the same** `PlayerVisual` the world draws, so
what you pick equals what you get -- no rule is reimplemented. A parent-
independent `apply_preview_character(character)` in `player_visual.gd` derives
body/trim colour from `appearance` exactly like `Player.apply_character`, fills
the preview gear from the character's own equipment slots (normalized like the
live `equipped_dict()`, filtered to the drawn `DRAWN_GEAR_SLOTS`), and funnels
into `set_character_visual()` + the shared `_draw`. With no `Player` parent,
`refresh_facing()` early-returns (the preview's magnify scale is never
overwritten), `visible_gear_ids()` returns `_preview_gear`, and every
swing/action snapshot field resolves to its idle value, so
`presentation_snapshot()` is null-safe. `shell_ui.gd` gained
`_make_character_preview`/`_apply_preview`; the creation form shows a live 6x
preview refreshed on every figure-affecting selector and each select row shows
the stored character at 3x with its gear. Smoke:
`pr05_preview_matches_world_render` proves the parentless preview's rendering-
contract snapshot equals the world's for a dwarf/feminine/ash character with
four gear slots (body art + appearance recolour + gear all exercised). The
validator pins the reuse (`apply_preview_character` present, screens wired); the
contract gained a **Preview Consumers** section. Suite **342/342**. Presentation
only.

**Character HUD rebuilt on runtime children (PR-06 done 2026-07-21, code
lane):** the Character panel is rebuilt from runtime state on every open inside
the existing native `ornate` chrome -- no baked summary, no duplicated
rendering. `hud.gd` `_build_character_panel` now holds a persistent
`_character_body` that `_refresh_character_panel` clears (`_clear_children`) and
repopulates with: a composed figure drawn through the **same** PlayerVisual
render path as the world and the creation preview (`_make_character_figure` ->
`apply_preview_character` on a dict assembled from live `player` state incl.
`equipped_dict()`, so the figure shows the live worn gear and can never drift);
live identity (name/species/body/look/appearance/role/traits); live status
(health, attunement, attack, carried); and **all 13 equipment slots**
(`_equipment_board_slots`) with each empty slot shown as an em dash. The old
`_character_info` baked label is gone. `character_figure_snapshot()` exposes the
figure's rendering-contract snapshot for the smoke. Smoke:
`pr06_character_panel_runtime_render` proves the figure draws through the shared
path with the live worn gear, all 13 slot names render, status/identity read
live, and re-equipping + reopening updates figure/names/status (no baked
values). HUD-QA captures `08_character_panel` (1280x720) and
`09_character_panel_wide` (1600x900) reviewed. The validator pins the runtime-
children rebuild + shared-path reuse and forbids resurrecting `_character_info`.
Code lane only -- no image production, no chrome replacement (art stays PR-10).
Suite **343/343**. Presentation only.

**Backdrop seam/contour skirt (PR-07 done 2026-07-21):** the backdrop's distant
scenery was anchored to the flat AVERAGE surface line, so where the real
per-column terrain top sat below the mean the distant band floated on a flat
line with sky/void showing in the gap down to the terrain -- the seam.
`world_backdrop.gd` now draws a **world-space contour skirt**
(`_draw_contour_skirt`): following `world.surface` per column, it fills the band
from the distant horizon down to the ACTUAL surface with the mid-ground foothill
tone (`MID_COL`) so the far terrain descends into valleys to meet the ground,
and backs everything below the surface contour with the under-earth tone
(`UNDER_COL`) so no void shows behind terrain at any camera height.
`contour_top_px(col)` is the pure per-column top (clamped off-world so edges
never void). The horizon/under metrics are now anchored **deferred-safe**
(`_recompute_metrics` from `_ready` and `_process`) because the world generates
its surface either before or after the backdrop's `_ready` depending on setup
order -- previously the anchor silently fell back to the 480px default whenever
`_ready` ran first (the smoke's Main flow), which is why the skirt appeared to
do nothing until this fix. No PNG touched; the skirt is world-locked (no
parallax, never swims) while the distant strips keep their parallax; `light_mask
= 0`, z-behind-walls, no-save and no-collision are unchanged. Smoke:
`pr07_backdrop_contour_skirt_follows_surface` (skirt top == per-column surface;
peak higher on screen than valley; off-world clamps to the edge; cosmetic
guarantees intact). HUD-QA world captures reviewed (contoured backdrop meets the
terrain, flat floating band gone). Suite **344/344**. Presentation only.

**Skill panel viewport-relative (PR-08 done 2026-07-21, code lane complete):**
`skill_tree_panel.gd` was a fixed 540x420 with a cramped 500x180 graph -- small
at 1280x720 and unable to grow. It is now **viewport-relative**: `_apply_layout`
sizes the panel to `panel_size_for(viewport)` (a `VIEWPORT_FRACTION` clamped to
`MIN_PANEL`/`MAX_PANEL`, never past the viewport minus `VIEWPORT_MARGIN`) and
re-centres it on every `get_viewport().size_changed`; the graph
`ScrollContainer` and the inspector label now `EXPAND_FILL` (widths no longer
pinned to 500, a `MIN_GRAPH_HEIGHT` floor) so the star-map takes the extra room
and stays usable as lanes grow. The stretch mode is `canvas_items`+`expand`, so
the logical viewport is ~1280x720 and a same-aspect 640x360 window just renders
that layout scaled to fit -- `panel_size_for` is verified to fit both. No perk
data, node layout (`NODE_SIZE`/`SPACING`), purchase path, persistence, or
inspector format changed. Smoke: `pr08_skill_panel_viewport_relative` (fits with
a margin at 640x360 and 1280x720, roomier than the old 540x420, live panel
adopts the computed size); `fq06_panel_opens_and_inspects` and
`fq09s_constellation_links_match_prereqs` stay green. HUD-QA `10_skill_panel`
(1280x720) + `11_skill_panel_small` (640x360) reviewed. Presentation only.

**PR-08 follow-up -- character-create form scroll/fixed actions (fix `ccd3f2a`,
2026-07-21):** the PR-05 live preview plus the many creation selectors had made
the character-create form taller than the viewport, so its bottom clipped and
the Create/Back buttons were pushed off-screen and unreachable. `shell_ui.gd`
`_show_char_create` now wraps the long form in a `ScrollContainer` (mirroring
`_show_world_create`) and keeps the Create/Back action row added to `_content`
**after** the scroll, so it stays pinned and reachable at any viewport size; the
PR-05 preview and selector refresh are unchanged (the preview scrolls with the
form). Smoke `pr08_char_create_form_scrolls_actions_pinned` proves the action
row sits outside the scroll (never clipped), the preview is preserved inside the
scrollable form, and a default character can be created straight from the
screen; the shots tour gained `07b_character_create_small` (640x360). Suite
**346/346**.

**The presentation recovery arc's code lane is complete (PR-00..PR-08).** The
only remaining rows are non-code: PR-09 (later skill expansion) is
deferred/planning-only, and PR-10 (HUD chrome / image production) is an art
lane.

## Historical State (2026-07-16 public refresh)

**The native HUD-kit stabilization is merged locally and verified at 322/322.**

The follow-up contract-v2 hardening makes non-interactive decorative layers
manifest-driven, positions every slot/button runtime child from JSON, restores
visible runtime action labels, protects both vessel rectangles from foreground
trim, validates alpha/state-family contracts, verifies source/runtime hashes,
and generates a native composite plus color-coded authoring guide. Final chrome
art remains intentionally provisional.
The primary bottom dock now selects a 19-asset native RGBA kit plus one JSON
geometry authority before the older FQ-21 sliced band and FQ-19 modular
fallbacks. Health/attunement fills and all icons, counts, hotkeys, labels,
selection, and FX remain runtime children. The command-center module row is a
separate movable widget; Map and Events have independent defaults and can stay
open together. A safe authored-source -> runtime promotion tool and one prompt
per dock asset live in `docs/wiki/hud_asset_replacement_studio.md`.
Every required static HUD asset is also the fallback for an optional
`<base>__<theme>.png` sibling. Theme selection prefers an explicit character
HUD theme and otherwise uses ancestry/species; incomplete or invalid theme
packs fall back asset-by-asset without touching runtime content or behavior.

The tree also contains eight authored opening-scene pools (ten PNGs) and 120
body-specific player-gear PNGs: crude helmet/torso/feet plus three phases for
basic pick, forged pick, and crude axe across all ten bodies. Gameplay-safe
fallbacks remain intact.

**Open presentation defects:** some character/load transitions can fail to
resolve or align a matching gear overlay; pick/axe motion is still a stepped
three-pose sequence; swords lack an equivalent authored swing; and the current
HUD/framed-panel chrome still needs padding, masking, and opaque-region polish.
These are tracked publicly in `docs/wiki/known_issues.md`. Equipment state and
effects remain functional when the visual fallback is used.

**Latest release evidence:** static validator, strict asset audit, pixel-asset
verification (386 PNGs), public-profile capsule doctor, and diff check pass.
An isolated Godot run passed 322/322 on the required rerun after the documented
single `fq09u1_live_clip_switch` cold-run flake.

**Publication governance note:** the `public_repo` profile says not to commit
raw `.project/runs`, Atlas outbox, or BOH outbox artifacts, while historical
versions of those directories are already tracked and the README describes the
audit trail. This predates the HUD publication candidate. No new raw evidence
files are part of this refresh, but the owner should explicitly choose whether
to sanitize the historical artifacts or revise the public profile/checklist to
make that publication intentional.

## Historical FQ-21 State

**FQ-21 (one-piece full-width dock band) implemented and verified — the dock
is now four native-aspect pieces sliced whole from the operator's blueprint
mockup, spanning the screen edge-to-edge: left health-orb cap, mirror-tiled
plate, a fixed center block with a uniformly rebuilt slot track, and the
right attunement-crystal cap. Nothing is stretched, nothing is color-keyed,
and every runtime coordinate comes from the slicer's geometry sidecar** (run
`20260715_coheronia_fq21_one_piece_band`; lineage: … -> FQ-20 (`a6661f6`) ->
FQ-21; Godot 4.6.1 stable). Suite at 319/319.

## FQ-21 Additions

- **Band pieces** (`slice_hud_chrome.py`): `dock_left_cap` (punched glass,
  de-reddened bevel), `dock_right_cap` (baked crystal kept; charge is a
  luminous bottom-up overlay), `dock_mid_tile` (the one clean grain segment,
  mirror-extended so tiling reads as paneling, then TILED — never
  stretched), `dock_center_block` (nav buttons with baked labels; the slot
  track refilled with tiled plate and five clean frames at even pitch,
  because the baked slots varied and slot 3 was painted selected).
- **Geometry sidecar** `dock_band_geometry.json`: glass/crystal centers and
  radii, slot rects, button zones — written by the slicer, loaded by hud.gd
  (`_load_band_geometry`). Hand-synced coordinates are gone; they were the
  root of the masking misalignments.
- **hud.gd band mode** (`_build_dock_band`; the FQ-19/20 modular
  construction remains the fallback): full-width anchored band, health
  liquid UNDER the punched cap, charge overlay OVER the crystal, values ON
  the glass (blueprint), slot overlays (icon centered / count bottom-right /
  key top-left; selection = gold border overlay), invisible click zones over
  the baked buttons (hover sheen), command chips between the pedestals, the
  summary as a floating chip, mining progress floating above the plate.
- **Vessel sockets** for the operator's planned liquid mechanics:
  `vessel_socket(kind)` exposes glass geometry + the fill node;
  `replace_vessel_fill(kind, node)` swaps any Range-derived control in —
  `update_health`/`update_attunement` only ever drive the Range interface.
  Smoke-proven (`fq21_vessel_socket` swaps a stub in and back).
- **Smoke** 319: `fq21_dock_band_one_piece`, `fq21_vessel_socket`; fq13p2 /
  fq18 / fq20 checks evolved for band mode.

## FQ-20 Additions

- **Painted chrome** (`scripts/art/slice_hud_chrome.py` → thirteen assets in
  `art/generated/ui_painted/`, sliced deterministically from
  `art/source_templates/COHERONIA_HUD_BLUEPRINT_MOCKUP.png`): module frames
  (plain + ornate with the corner medallion), chip frame, riveted dock plate,
  slot frames (normal + gold selected), four nav glyph buttons, and both orb
  rings with the glass punched for the runtime liquid (per-orb geometry in
  `PAINTED_ORB_GEOMETRY`). New `ui_painted` manifest category, audit statuses
  (`UI_PAINTED_CONSUMED`), and a dedicated light verifier pass (free-size
  RGBA, ≤320px, non-empty — exempt from the pixel-art palette contract).
  Every consumer keeps the FQ-19 generated art then code-drawn fallbacks.
  The mini-map now wears the ornate frame as a NinePatch border overlay.
- **Command center**: the five module toggles (Crest/Goal/Events/Map/Edit)
  are chip buttons INSIDE the dock panel — the screen-corner module toolbar
  is retired. Chips mirror live open/closed state both directions
  (`_sync_command_center`, `set_pressed_no_signal`).
- **Direct manipulation**: in edit mode every widget drags immediately (the
  per-widget locks are gone — edit mode itself is the gate) and resizes
  continuously from a bottom-right corner grip (0.5x-2.0x, snapped 0.01); a
  full-screen overlay draws gold outlines + grips. Layout schema v3 (drops
  `locked`, continuous `scale`); older versions fall back to defaults
  one-time. The nudge/scale buttons remain as precision aids.
- **Smoke** (suite 318): `fq17_hud_edit_direct_manipulation` (evolved),
  `fq20_painted_chrome_consumed`, `fq20_dock_command_center`.
- **Concurrent-lane note**: during this run a separate Codex session wrote
  opening cels (`art/generated/opening/`) and player-gear overlays
  (`art/generated/player_gear/`) plus wiki files. None of that is part of
  FQ-20; it was deliberately left uncommitted for its own review.

## FQ-19 Additions

- **Final HUD art** (`scripts/art/gen_hud_final_art.py`, deterministic PIL):
  ornate 9-slice `dock_backplate` (reused as the framed-module style for
  crest/goal/events), gem-crowned orb frames, disk `orb_fill_mask`, three slot
  frames, and six glyph buttons — one iron/brass language, 32×32, ≤16 colors,
  stretch-safe edges. `gen_ui_placeholders.py` now preserves existing files
  unless `--force-placeholder`. Ten UI ids are consumed (`UI_CONSUMED`);
  every consumer keeps its code-drawn fallback.
- **Blueprint dock band** (Photo 1/2, tightened after operator review of the
  first render): the two resource orbs are their OWN 96px flanking objects
  beside one central backplate panel (nav glyphs · five key-numbered slots,
  selected slot rides 3px higher · summary lines) — not decorations inside a
  single wide plate. The whole band is the movable "dock" widget.
- **HUD layout schema v2** (`HUD_LAYOUT_VERSION`): layouts saved before the
  stretch-mode/coordinate-space change loaded widgets off-position on live
  profiles; a version mismatch now falls back to the blueprint defaults
  (one-time reset; new edits re-save under v2).
- **Resource vessels**: masked bottom-up liquid (`TextureProgressBar` +
  `orb_fill_mask`); health damage flash / recovery glow / low-health pulse
  (<25%); attunement regeneration shimmer, outward use-pulse, and a rotating
  geometric core that burns bright at full charge.
- **Framed crest** (name/level title, chip+bar+value C/L/R rows), **goal
  panel** (headline, subgoal, milestone strip), and the **exact clock** in the
  events header (`Day N • Phase HH:MM`; day maps 06:00-20:00, night wraps to
  06:00; ticks once per real second).
- **Contextual right-band stack**: selected-item announcement, save toast
  (`notify_saved()`, fired by the real F5 path), and the `[E] Town Hall`
  interaction prompt — fixed priority order, auto-hide tweens, top edge pinned
  dynamically below the live Events panel. The dock's persistent save line was
  retired (the controls hint still teaches F5/F9).
- **Resolution QA**: `canvas_items` stretch (aspect `expand`) in
  `project.godot` — 640×360 and 1280×720 now render the identical accepted
  composition (the small window scales instead of re-flowing). Mini-map stays
  the schematic FQ-15 panel: final map art is not ready, explicitly deferred.
- **Smoke** (7 `fq19_*` checks, suite 316): events/map exclusion + framing,
  day/phase header, exact-clock phases, dock final-art consumption, vessel
  liquid + all six effect states, crest/goal blueprint treatment, and the
  contextual stack (order/eventing/auto-hide/clearance). The contextual check
  runs at the END of the suite: its real-time waits must not shift the live
  music clip-switch timing (fq09u1 flaked once from exactly that).

## FQ-11 Additions

- **Three buildable craft stations** (`data/recipes.json` `stations`):
  `workbench` -> `furnace` -> `anvil`, each with a `prereq` and a
  `build_cost` spent from the stockpile. Built state (`stations_built`) is
  settlement-owned on the Town Hall and saved in `to_dict`/`from_dict`
  (pre-FQ-11 saves default to nothing built). `town_hall.build_station`
  gates on prerequisite + affordability; a station's recipes stay locked
  until it is built.
- **Unified station crafting** (`town_hall.craft_station`): inputs come from
  the stockpile; outputs route by recipe — smelted ingots (`output_to:
  stockpile`) stay in the stockpile, anvil gear (`equip_slots`) equips onto
  the player with an empty-slot + fit check BEFORE inputs are consumed (a
  full slot or data regression cannot eat the stockpile), everything else
  goes to inventory. `BlockRegistry` gained `station_defs`/`station_def`/
  `recipes_for_station`.
- **The metallurgy chain**: the furnace smelts raw ore + coal into ingots
  (`smelt_copper`/`smelt_tin`/`smelt_iron`/`smelt_silver`) and alloys bronze
  (`alloy_bronze`: copper + tin ingots); the anvil forges iron gear from
  ingots (`anvil_iron_sword` -> `sword_iron` attack 5; `anvil_iron_armor` ->
  the iron helm/cuirass/boots). **Metal gate**: no recipe turns raw ore into
  gear — you must smelt first, then forge. The crude wood/stone gear
  (town_hall) is unchanged; iron is the anvil-gated upgrade. New ores + coal
  are now depositable; ingots are new `items.json` entries; iron gear is new
  in `equipment.json`. The workbench hosts a basic `workbench_torch_bundle`
  (wood + coal -> torches).
- **UI** (`hud.gd`): the Town Hall panel gained a data-driven, scrollable
  station section rebuilt on every refresh — Build buttons (annotated when a
  prerequisite is missing or the stockpile is short) and, once built, each
  station's recipes as craft buttons (disabled when unaffordable or, for
  gear, when the slot is filled). Wired through `game_root`
  (`build_station_requested`/`craft_station_requested`).
- **Smoke** (7 `fq11_*` checks, suite total 269): station gating, the build
  chain, furnace smelting (ore + coal -> ingot in the stockpile), anvil
  forging iron gear from ingots, the metal gate (raw ore alone cannot forge
  the sword), the bronze alloy, and `stations_built` round-tripping through
  save/load.

## FQ-10 Additions

- **Six ore families** in `data/blocks.json`: `coal`, `copper_ore`,
  `tin_ore` (shallow, tier-1 pick), `iron_ore`, `silver_ore`, `crystal`
  (deeper, tier-2 pick gate). Each drops itself, is pick-preferred, blocks
  light, and is non-placeable. The generic `ore` block is unchanged — it
  stays the tier-2 starter vein. New ores are raw materials with no consumer
  yet (FQ-11 furnace/ingots will use them); "avoid making every ore
  immediately useful" is respected.
- **Data-defined generation** (`data/world_settings.json` `ore_table`,
  validator-enforced): per-family `min_depth`/`max_depth` band, `frequency`,
  `threshold`, and a unique `seed_offset`. `WorldGen._build_ore_families`
  builds one FastNoiseLite per family (seeded `world_seed + seed_offset`);
  `_ore_family_at` returns the first family whose depth band contains the
  cell and whose channel clears its threshold, else `stone`. Families are
  applied **only to cells that would be stone** — the generic `ore` decision
  runs first and is byte-identical, so every prior ore check still passes.
  `ore_abundance` lowers all thresholds (richer worlds expose more) and 0
  disables all ore. Thresholds were calibrated to FastNoiseLite's real
  output range (0.58-0.72; values above ~0.75 almost never occur — the first
  pass used 0.78-0.87 and produced near-zero deeper ore).
- **Fallback rendering**: distinct `BLOCK_COLORS` in `world.gd` (coal near-
  black, copper orange, tin pale, iron brown-gray, silver light, crystal
  cyan) and `data/items.json` icon swatches so the ores read distinctly
  before art lands; the image-first pipeline picks up
  `art/generated/blocks/<id>.png` when authored (roadmap-tracked).
- **Smoke** (5 `fq10_*` checks, suite total 262): all six families generate
  at meaningful counts in a large rich world; the generic vein survives
  alongside them; deterministic ore-family layout across two same-seed
  setups; the tier gate (iron behind tier-2, coal at tier-1); and
  `ore_abundance` 0 clearing every ore. Ore families are terrain cells like
  any block — regenerated from seed, mined cells persist as normal air
  deltas, and no save-schema change (all existing save round-trips stay
  green).

## FQ-09U3 Additions

- **Event stingers over temporary ducking** (`scripts/audio/
  adaptive_music_director.gd`): `play_stinger(kind)` fires a one-shot on the
  StingerPlayer (routed to the SFX bus) while a per-frame duck envelope
  lowers the Music bus UNDER it — the bed dips, the stinger never does, and
  the music is never stopped. Per-kind cooldowns (`stinger_config.
  cooldown_seconds`, default 8 s) stop event spam; the duck attacks fast and
  releases slow (`duck_attack_db_per_sec`/`duck_release_db_per_sec`) toward
  `duck_db` (-9). Five kinds load from the manifest (dawn, nightfall,
  raid_warning, attunement, base_advance).
- **The event surface**: `_wire_events` connects game_root's narrow
  `music_event(kind)` signal (nightfall/dawn/raid_warning/base_advance) and
  the player's `attunement_pulsed` to the stingers. **Resume fix**: wiring
  is now `call_deferred` — the director is a child of Main, so its `_ready`
  runs before game_root assigns its `@onready var player`; connecting at
  `_ready` saw a null `root.player` and silently dropped the attunement
  stinger (the check fired +1 instead of +2). Deferring runs the wiring
  after the full `_ready` cascade, when the player node is live.
- **Audio settings** (`scripts/audio/audio_settings.gd`, new): the single
  bus-volume authority. `AudioSettings.apply(profile[, duck_db])` creates
  the Music and SFX buses at runtime and sets their volumes from
  profile-level `music_volume`/`sfx_volume` linear keys; the optional
  `duck_db` is folded into the Music bus. `set_music_volume`/`set_sfx_volume`
  persist to the profile. Volume state is profile-level, never a world-save
  key.
- **Pause behavior**: the director runs `process_mode = ALWAYS`, so the
  score keeps breathing and the duck/cooldown envelope keeps ticking under
  any future pause, and settings keep applying.
- **Final asset validation**: `validate_repo.py` requires the five stinger
  OGGs; the music asset verifier confirms durations/sample rates/headroom
  (operator listening approval was granted 2026-07-10).
- **Smoke** (8 `fq09u3_*` checks, suite total 257): stinger assets loaded as
  short non-looping one-shots; a fired stinger ducking the Music bus while
  the context loop plays on; the duck releasing; per-kind cooldowns;
  **`music_event("nightfall")` + `attunement_pulsed` each firing their
  stinger** (the deferred-wiring proof); volume settings reaching the buses
  and round-tripping; and the world save carrying zero music/volume/stinger
  keys.

## Codex Art Integration (same closeout — see docs/HANDOFF_ART_INTEGRATION_2026-07-12.md)

- **55 generated PNGs** landed under `art/generated/` (11 blocks, 16 item
  icons, 12 enemy sprites with variants, 10 player bodies — the
  `<species>` and `<species>_female` files, now the canonical masculine and
  feminine variants — Town Hall + core, 3 backgrounds, 2 back walls) plus
  their runtime wiring:
  `data/player_visuals.json` + `scripts/player/player_visual.gd` (16x32 body
  art with constrained species/appearance recolor, gear-overlay hooks,
  procedural fallback), the `PlayerVisual` child in `scenes/player/
  Player.tscn`, Town Hall art (`scripts/settlement/town_hall.gd`, nearest
  filtering, `Rect2(-28,-48,56,48)`, procedural fallback preserved), and
  backdrop nearest-filtering/native-strip sizing (`scripts/world/
  world_backdrop.gd`). Player collision (12x28) and the action/facing/
  three-phase swing interface are unchanged; base bodies stay unarmored
  (armor is a future overlay). New validator art-contract checks cover the
  Town Hall structure/core, surface sky, backdrop strips, and player-visual
  contracts.
- This lane was verified independently by Codex (validator, diff-check,
  capsule doctor, rendered visual QA) and shared the dirty tree with U3;
  three files (`smoke_test.gd`, `validate_repo.py`, `player.gd`) carry hunks
  from both lanes, so they could not be split — U3 and art committed
  together per operator decision.

## FQ-09U2 Additions

- **Spike finding (recorded, mandated first step)**: an
  AudioStreamSynchronized group DOES play as a clip inside an
  AudioStreamInteractive in this exact Godot 4.6.1 binary — proven live in
  the smoke with generated WAV tones (fq09u2_nesting_spike_recorded).
  U2 still ships the parallel LayerPlayer design because the suite has ONE
  shared phase-locked stem set, not per-context sets; nesting is now a
  proven option for future increments.
- **The stem bed**: `MusicManifest.load_stem_streams` loads the six stems
  (runtime OGG load, loop + grid stamped); the director validates every
  loop against the exact manifest length (53.333 s, ±0.05) and builds an
  AudioStreamSynchronized on the LayerPlayer, started in the same frame as
  the context stream — equal-length loops on one mix clock stay
  phase-aligned for the whole session. Any missing/mismatched stem
  disables layering with a warning; the context music is untouched
  (fail-safe by construction).
- **Data-defined mix** (`stem_mix` in `data/music_manifest.json`,
  validator-enforced): per-stem {source, min_db, max_db}; volume targets
  are lerp(min, max, source value) with sources drawn from live truth —
  settlement resilience (foundation), coherence (hearth), the director's
  pressure score (pressure stem; a storm lifts it to the
  storm_pressure_floor_db texture), player attunement ratio (attunement),
  mining/movement activity (motion), and the collapse edge (fracture wakes
  only past pressure 0.7). Volumes move smoothly at smoothing_db_per_sec
  (6 dB/s) and never snap. Debug hooks: `layering_enabled()`,
  `stem_targets()`, `stem_volumes()`.
- **Smoke** (8 `fq09u2_*` checks, suite total 234): the nesting spike
  record; the live stem bed (six loops, exact lengths, playing on the
  Music bus); targets following settlement coherence/resilience; pressure
  and collapse-edge fracture behavior; the storm texture floor; smoothing
  verified to the decimal (-40 -> -37.00 at 6 dB/s x 0.5 s); a
  deliberately length-mismatched set disabling layering while context
  music plays on; and save round-trips carrying zero stem/music keys with
  the layer bed surviving load.

## FQ-09U1 Additions

- **Gates cleared**: operator listening approval of the rendered suite
  ("Music is beautiful", 2026-07-10); the Godot 4.6 spike executed in-lane
  in two parts — a headless ClassDB probe of the real binary confirmed the
  exact API surface (AudioStreamInteractive set_clip_*/add_transition with
  TRANSITION_FROM_TIME_NEXT_BAR/NEXT_BEAT, TO_TIME_SAME_POSITION,
  FADE_CROSS, CLIP_ANY; AudioStreamPlaybackInteractive
  switch_to_clip_by_name + get_current_clip_index; AudioStreamSynchronized
  per-stream volumes), and the live half runs inside the smoke
  (fq09u1_live_clip_switch proves a next-bar same-position crossfade
  actually reaches the requested clip during real playback). The
  Synchronized-inside-Interactive nesting question is deliberately deferred
  to open FQ-09U2.
- **`scripts/audio/music_manifest.gd`**: dedicated loader for
  `data/music_manifest.json` (no BlockRegistry service-locator creep).
  Context OGGs load via `AudioStreamOggVorbis.load_from_file` — the FQ-07
  no-import rule applied to audio — with loop=true and the musical grid
  (bpm 72, bar_beats 4, beat_count 64) stamped onto each stream so the
  interactive resource can quantize to bars. Missing/broken files are never
  fatal anywhere in the path.
- **`scripts/audio/adaptive_music_director.gd` +
  `scenes/audio/AdaptiveMusicDirector.tscn`** (instanced in Main between
  SaveManager and HUD; ContextPlayer live, LayerPlayer/StingerPlayer
  reserved for U2/U3): builds one AudioStreamInteractive with the four
  named context clips and any->clip transitions (next-bar + same-position +
  1-bar crossfade; crisis entry escalates to next-beat), creates the
  "Music" bus at runtime and routes through it. Context resolution reads
  existing game truth on a 0.5 s poll — `is_night`, `storm_active`,
  `current_threat_severity()`, player health ratio, and the cave-spawn
  underground rule — plus the settlement `updated` signal for load;
  pressure = max(threat/norm, load/norm, inverse health) + storm bonus, all
  divisors data-defined. Priority crisis > underground > surface_night >
  surface_day with data-defined hysteresis (enter 0.60/2 s, exit
  0.35/6 s), a one-bar minimum context hold, and never re-requesting the
  current or pending clip. The state machine core is a deterministic
  `evaluate(state, delta)` the smoke drives directly with synthetic
  snapshots. Missing assets disable audio silently while the state machine
  keeps working; music state is transient and appears nowhere in saves.
- **Smoke** (9 `fq09u1_*` checks, suite total 226): manifest/stream grid
  metadata; director live on the Music bus with a 4-clip interactive
  stream; night/dawn/underground resolution; crisis enter hysteresis
  (brief spike never enters, sustained does); crisis exit threshold AND
  delay; no re-request churn; the LIVE clip-switch spike proof; missing
  assets silent-safe (an override-manifest director instance); and save
  round-trips carrying zero music keys with the director surviving load.

## FQ-09M Additions

- **`scripts/fx/action_fx.gd`** (new, validator-required): one reusable
  self-freeing effect node — five deterministic kinds (place_pulse,
  hit_spark, cast_ring, dust_puff, forge_spark) drawn at stepped 10 Hz
  visual updates with no randomness, all under 0.4 s, members of the
  "action_fx" group, spawned via a null-safe static
  `ActionFx.spawn(parent, kind, at[, tint])`. Presentation only: effects
  free themselves, never enter saves, and never touch gameplay numbers.
- **Tool swing**: `player._draw` gains a stepped swing arc while a mining
  target is active — arm plus pick/axe glyph (axe when the target is
  axe-preferred and an axe is carried) cycling raise/mid/strike six
  pose-steps per second toward the target side. `swing_phase()` is the
  smoke hook (-1 idle). Reads mining state, never writes it — the mining
  frame baselines (dirt 21 / trunk 33 / stone 66 / axe 24) pass unchanged.
- **Wiring**: placement pulse at the placed cell on `try_place` success;
  star-white cast ring at the attunement fire moment (joining the existing
  light fade); hit sparks on every landed player/enemy hit (plus the
  existing tint flash and hurt bar); dust puffs where the player falls and
  respawns and where an enemy dies; one `game_root._craft_confirm_fx`
  choke point for all four hall forges (burst at the hall) and hand
  crafting via `_on_player_crafted` (burst at the player).
- **Smoke** (7 `fq09m_*` checks, suite total 217): swing tracks mining
  state and resets with it; placing spawns exactly one pulse; the cast
  ring appears at fire; a landed hit sparks and a collapse adds fall+
  respawn dust; enemy hits spark; a successful hand craft fires the
  confirmation; and every effect self-frees within its lifetime
  (transient by construction). All pre-existing timing/drop/damage/save
  checks run after the section and stay green.

## FQ-09U Asset Intake (Codex lane, same run — runtime still not wired)

- The Codex lane rendered the full adaptive suite into the repo per the
  FQ-09U0 contract: 4 context loops (`audio/music/rendered/contexts/`),
  6 phase-locked stems (`.../stems/`), 5 stingers (`.../stingers/`), the
  source patch `audio/music/source_m8str0/coheronia_adaptive_suite.m8patch`,
  a repeatable renderer (`scripts/audio/render_adaptive_score.py`) and a
  mechanical verifier (`scripts/audio/verify_music_assets.py`).
- Codex's verification: every loop decodes to exactly 2,560,000 samples at
  48 kHz (= 16 bars at 72 BPM), stingers under 8 s, all 63 stem
  combinations below full scale; validator + capsule doctor + diff check
  green with the assets present.
- **Boundaries preserved**: runtime adaptive playback is NOT wired —
  nothing in the game reads these files until FQ-09U1. The spec's human
  gate stands: **operator listening approval is pending** (the patch marks
  it explicitly). FQ-09U1's remaining gates: Godot 4.6 audio spike
  evidence + that listening approval.
- Operator-side `.rar` packaging archives found next to the OGGs were
  ignore-listed (`audio/**/*.rar`), not committed — only OGGs, the patch,
  and tooling are tracked.

## FQ-09U0 Additions (planning only — no runtime audio code)

- **Operator decision recorded**: the hybrid adaptive score model is
  approved (horizontal bar-quantized context switching + later vertical
  stem layering + event stingers, all on native Godot 4.6
  AudioStreamInteractive/AudioStreamSynchronized — no middleware, no
  runtime AI generation). Queue placement: FQ-09U1/U2/U3 join after FQ-09M
  and before FQ-10; no silent queue bypass.
- **`docs/WORK_ORDER_FQ_09U_ADAPTIVE_MUSIC.md`**: the three bounded
  runtime increments with the musical state model resolved against
  verified symbols (`settlement_model.updated(coherence, load_value,
  resilience, inputs, labels)` on the 5 s tick, `current_threat_severity()`,
  the cave-spawn underground rule, `world.sky_line`), the anti-thrash
  hysteresis table, agent division (Paul approves by listening; Codex owns
  the Godot spike + M8str0 tooling; Claude Code implements; independent
  review), gating (spike evidence + M8-AUDIO-01 review before U1), the
  file map, and the risk register. Noted explicitly: game_root emits no
  signals today, so U1 adds only a narrow nightfall/dawn/storm/raid event
  surface.
- **`audio/source_templates/MUSIC_TEMPLATE.md`**: the locked production
  contract (72 BPM, 4/4, 16 bars = 53.333 s, D Dorian family, shared
  phrase grid at bars 1/5/9/13, WAV masters -> OGG runtime, exact naming),
  canon-derived mood vocabulary (palette roles mapped to instrumentation),
  context and stem briefs, prompt packs for the music-authoring LLM and
  the three bounded Codex M8str0 increments (M8-AUDIO-01 loop-locked
  recording, -02 stem buses, -03 Coheronia template), and the render
  checklist ending in operator approval by ear.
- **`data/music_manifest.json`**: the machine contract (contexts, priority,
  transition quantize/fades, pressure normalization, hysteresis
  thresholds, stem/stinger paths), validator-checked for the musical grid,
  all four contexts, and crisis_exit < crisis_enter; marked
  planning-status until the U1 loader consumes it.
- **Directory skeleton**: `audio/music/source_m8str0/`,
  `audio/music/rendered/{contexts,stems,stingers}/`, `audio/opening/`
  (the FQ-09C cue hook target now exists on disk) — all validator-required.
- Docs-only + data + validator: suite stays 210/210; the asset roadmap
  gained the audio families table.

## FQ-09A Additions

- **`docs/ASSET_ROADMAP.md`** (validator-required, phrase-locked): the
  concrete asset map for future human/LLM art passes. Pipeline facts (drop a
  PNG at the convention path, live next entry, fallback always available,
  FQ-09V variant pools, INFO-only validator gaps, no baked text ever); live
  tables for every renderable id — 11 blocks, 16 item icons, 3 live enemies,
  9 equipment icons, 2 back walls, 3 backdrop layers, 8 opening cel-frame
  scenes — each with path, size, transparency rule, current fallback,
  priority (P1 terrain/player/hall visibility wins first), and a per-id
  prompt note; the drawn-shape actors that need a small renderer extension
  before art can land (player, town hall, attunement pulse); honest planned
  tables keyed to their queue items (FQ-10 ores, FQ-11 stations/ingots,
  FQ-12 farming, FQ-13+ enemies by mvp_expansion_order, FQ-09M action
  effects, cave walls/backgrounds, phase C-E ancestry sprites, FQ-14/15 UI);
  and per-category prompt packs (blocks/walls, items, enemies, ancestry
  sprites, opening cel frames, backgrounds) under one shared style preamble
  derived from the canon bible's palette roles, production rules, and avoid
  list.
- **Decision**: no `data/asset_manifest.json` — the FQ-09A scope adds a
  machine manifest only if code/validation consumes one, and nothing does;
  the runtime resolves everything by convention, so the roadmap doc is the
  manifest. `art/generated/ui/` stays reserved (documented: produce nothing
  for it until a consumer lands).
- No code, data, or smoke changes: suite stays 210/210; `validate_repo.py`
  gains the roadmap as a required file with a live/planned/prompt-pack/
  no-baked-text phrase lock.

## FQ-09W Additions

- **Scenic backdrop** (`scripts/world/world_backdrop.gd`, z -10 inside the
  world canvas so day/night/storm CanvasModulate applies): code-drawn sky
  gradient bands reaching the deepest valley line (no terrain height exposes
  a void), far/mid silhouette ridges with 2px-stepped parallax stable in
  world space, and a deep earth tone below everything. `light_mask = 0` so
  torches never paint glow onto distant scenery. Optional image hooks:
  `art/generated/backgrounds/surface_sky.png` (640x360 full frame),
  `surface_far_terrain.png` / `surface_mid_silhouette.png` (tiling strips);
  missing files always fall back to the code-drawn planes.
- **Natural backing walls**: a `BackgroundWalls` TileMapLayer (z -2, behind
  Blocks) filled each `setup` from the PRISTINE generated surface — a
  dirt-wall band for the configured dirt depth, stone wall below, nothing at
  or above the surface row. Deterministic from seed/config by construction;
  never enters cells/deltas/saves; the wall tileset has zero physics and
  zero occlusion layers, so walls provably cannot affect collision,
  lighting, shelter, or settlement math. Mining a below-surface block
  reveals the wall instead of the viewport. Tiles come from
  `art/generated/back_walls/dirt_wall.png`/`stone_wall.png` when present,
  else the matching block texture pushed darker and fully opaque.
  `world.wall_at(cell)` is the visual-only query.
- **Underground darkness (column-skylight ambient)**: `world.sky_line(x)` =
  first solid cell from the top of the LIVE column (cached per column,
  invalidated by any block change there). `game_root.ambient_darkness_factor()`
  fades 0 -> 1 over `CAVE_FADE_CELLS` (6) below the player's local sky line,
  and `ambient_target_color()` pushes the day/night/storm base toward
  `CAVE_TINT` (0.10, 0.11, 0.16) by that factor — the existing tint lerp
  smooths transitions at cave mouths. Mining an open shaft re-admits real
  daylight to the shaft floor; a sealed column at the same depth stays dark.
  Documented approximation: no lateral light bleed; roof-awareness is
  per-column. The directional-shadow sunlight path was assessed and not
  taken this slice: occluders are tileset-level and exist only on
  blocks_light blocks, so a DirectionalLight2D would need an occluder
  redesign (recorded as the future path to true skylight).
- **Torches stay the readable local lights**: PointLight2D behavior, light
  radii, `light_score`, shelter/occlusion math, mining, collision, and the
  save format are all untouched; old saves load unchanged (no new keys).
- **Smoke** (7 `fq09w_*` checks, suite total 210): deterministic wall map
  across two same-seed setups with correct dirt/stone banding and an inert
  tileset (0 physics / 0 occlusion layers); mined cells reveal walls while
  staying normal air deltas; midday underground darkness vs full-day
  surface (asserted on the ambient target, not the smoothing lerp); an open
  shaft admits daylight while a sealed neighbor column stays dark; backdrop
  z-order behind walls behind blocks with null image hooks falling back;
  the back_walls art hook resolves and falls back with temp art; and the
  saved world restores cleanly. The screenshot tour gained
  `09_underground_midday_torch` (mined chamber, dark ambient, one torch).

The canon bible (`docs/ART_DIRECTION_AND_CANON.md`) and the cinematic
storyboard (`docs/OPENING_STORYBOARD.md`) are the locked authorities for all
later art/writing work. The opening shipped as a genuinely animated
eight-scene DOS-style cinematic — a first static-panel implementation was
operator-rejected mid-run and rebuilt (see FQ-09C Additions).

v0.6 executed the six waves of `docs/WORK_ORDER_V0_6_CHARACTER_INVENTORY_WORLD_TOOLS.md` in three implementation commits (A/D, B/C, E/F) plus closeout. FQ-00 through FQ-09 followed from `docs/FABLE_TASK_QUEUE.md`.

## FQ-09C Additions

- **Opening cinematic ("Coheronia DOS Vector Cinematic")**: eight data-driven
  scenes, ~42s, playing automatically on a clean profile before the title.
  Authored at 640x360 on a SubViewport and integer-scaled 2x
  nearest-neighbor into the 1280x720 viewport, so every plotted line lands on
  a hard pixel grid. `scripts/shell/prologue.gd` owns narrative data (`SCENES`:
  id, phase, duration, overlay text, audio cue, animation cues), the 10 Hz
  tick clock, text overlays, input, audio hooks, and the finished/skip
  contract; `scripts/shell/prologue_canvas.gd` is a pure deterministic
  `(scene, tick) -> draw command list` renderer built from quantized
  primitives (plot_line/plot_path, dissolve_path, pulse_ring, palette cycle,
  stepped offsets, pose-shifted rect silhouettes, ordered hall assembly).
  Every scene animates beyond fading: contours plot, roads dissolve in
  discrete segments, the river detaches in steps, fire cycles at 3 ticks per
  frame, torches palette-cycle, eyes appear for two ticks, storms cross in
  6px jumps, the hall assembles beam by beam (the deliberate inversion of the
  unraveling scene) with a white ridge-lock flash, the attunement front
  re-illuminates contours in quantized radius steps, and the settlement
  schematic layers parallax with a stepped amber light boundary.
- **Puppet acting layer** (`scripts/shell/prologue_puppets.gd`): articulated
  filled-quad figures (legs/torso/head/arms, optional two-segment tool arm
  with hammer/pick/crate/beam props) posed by keyframe tracks; interpolation
  quantizes angles to 5-degree steps and positions to whole pixels so acting
  stays stepped. Ancestry identity by proportion (human/dwarf/elf/orc/goblin
  specs). The scenes act: the five peoples walk in and behave in scene 3
  (gesture, pack set-down, scanning, planted breathing, hand-warming), a
  watch paces and freezes toward the cave eyes in scene 4, two builders
  hammer on staggered loops with strike sparks while the orc walks the roof
  beam in and raises it in scene 5, the founder walks out, kneels, and
  touches the ground to source the pulse in scene 6, and a digger/carrier/
  tender work the settlement in scene 7. Hard camera cuts come from an
  integer-zoom command transform (`_apply_cam`): scene 3 punches in on the
  fire circle, scene 5 opens tight on the foundation stones.
- **Cel-shot hook (future art path)**: a scene id resolving a frame pool via
  `BlockRegistry.visual_variant_textures("opening", id)` (FQ-09V `<id>_01`
  convention or explicit array) plays those authored 640x360 frames at 8 fps
  instead of the plotted shot; removal falls back cleanly. No frames ship —
  this is how individual shots get upgraded to hand-authored cel animation
  later (FQ-09A prompt packs) without touching the sequence.
- **Text and authorship lock**: all copy is engine-rendered in a stable
  lower-quarter band with hard quarter-alpha step reveals — nothing textual
  in imagery. The title card steps in `COHERONIA` / `By Paul Peck` /
  `Where civilization pushes back.` as three separate labels; the persistent
  title screen shows the same three lines (authorship in amber) plus the new
  `Prologue` replay button between Play and Quit.
- **Flow and persistence**: any key or primary click advances exactly one
  scene (keys via `_unhandled_input`, clicks via the root's `_gui_input` with
  a STOP mouse filter — the overlay can never click through to title
  buttons); Escape skips; completion or skip writes only the profile-level
  `prologue_seen` flag via the idempotent `GameState.mark_prologue_seen()`;
  `finished(completed)` emits exactly once, and finishing stops the tick
  clock and any playing audio. `COHERONIA_SMOKE=1` bypasses (unchanged
  shell path), `COHERONIA_SHOTS=1` keeps its exact pre-prologue title tour,
  and `COHERONIA_PROLOGUE_DEBUG=1` shortens scenes and shows
  scene-id/phase/tick for review.
- **Audio hooks**: placeholder-safe cue ids (`cue_opening_01_drone_bell` …
  `cue_opening_08_title_chord`) resolved against
  `res://audio/opening/<id>.ogg`; absent files are silently skipped. No
  audio assets ship yet.
- **No image dependency**: the cinematic ships zero PNGs; the cel-shot hook
  above is the only image path and it is optional per scene
  (documented in `data/visual_assets.json`).
- **Smoke** (13 `fq09c_*` checks, suite total 203): smoke-bypass proof, exact
  scene order/copy, title-card authorship lines, completion emits once,
  skip finishes safely with the clock and audio stopped, profile seen-flag
  round-trip (operator value restored), replay isolation, data-driven
  timing/cues (42.0s), 640x360/10 Hz surface constants, every scene's command
  list changes across ticks (a fade-only scene would fail), deterministic
  replotting, the cel-shot hook (temp pool plays, removal falls back), and
  the title screen's authorship/replay wiring.

## FQ-09 Additions

- **Toolbelt**: five slot tiles (icon + count + numbered tooltip) with a gold border on the selected slot. Icons come from `BlockRegistry.item_icon` — FQ-07 art when present, else a generated color swatch (`data/items.json` color, else a stable hash-derived hue) — so every slot always reads visually. The text line below keeps the extras + tool/gear summary.
- **Inventory panel**: a 6-column icon grid of stacks (count under each tile, display name + descriptor on hover) sits above the existing text block, which is unchanged so all prior panel assertions still hold.
- **Town Hall panel**: the stockpile text list became an icon grid; station buttons carry item icons; disabled/crafted states keep the engine dimming plus the existing state text.
- **`data/items.json` (new)**: display names, descriptions, and swatch colors for non-block item ids (food, drops, forge icons) plus icon colors for block items. `BlockRegistry.display_name` now falls back blocks -> items.json -> id, improving every log/tooltip surface.
- Keyboard/mouse behavior unchanged: I toggles inventory, hotbar keys 1-5 select, E/T town panel, K skills — all pre-existing bindings and the Esc chain untouched.

## FQ-09V Additions

- **Variant pools**: one visual id may now ship several interchangeable images — either the file convention `art/generated/<category>/<id>_01.png` … (consecutive from `_01`, first gap ends the scan, max 8) or an explicit **array** entry in `data/visual_assets.json` (`BlockRegistry.visual_variant_textures(category, id)`; validator fails broken/empty pool entries, same rule as single paths).
- **Deterministic block variety**: `world._build_tileset` creates one atlas source per variant (identical physics/occlusion on every variant), and `_set_tile` picks `posmod(hash(Vector3i(cell.x, cell.y, world_seed)), n)` — the same world always renders the same variety and the choice never enters `cells`, deltas, or saves. Pool-less blocks keep exactly one source built by the unchanged `_make_block_texture` path.
- **Fallback intact**: a single `<id>.png` behaves exactly as in FQ-07 (an explicit array's first entry doubles as the id's canonical single image for `visual_texture` consumers like the HUD); ids with no art keep their generated colors/shapes. `world.rebuild_tileset()` (smoke/dev hook) rebuilds sources from the art on disk and re-derives the crack-overlay opacity masks; gameplay still loads art once at world entry.
- The repo still ships zero art; smoke proves both directions with self-cleaning `smoke_tmp_*` temp files (5 `fq09v_*` checks, suite total 190).

## FQ-09S Additions

- **Star-map treatment (presentation only)**: the skill tree panel wears a deep night-sky backdrop with a thin cool border; the node canvas draws a deterministic starfield (fixed seed, ~110 dim pixels), faint constellation link lines between prerequisite nodes (brighter when both ends are owned, soft white toward an available node, near-invisible toward locked), and a small pixel star glyph above each node (a 4-arm crosshair; owned nodes get a larger 8-arm star). Node buttons became dark plaques with state-colored borders and text instead of whole-button modulate.
- **Nothing mechanical moved**: perk data, point economy, prerequisites, save ownership, K/Esc/click behavior, the `purchase_requested` -> `try_purchase_perk` path, and the inspector text format are byte-identical; `[OWNED]`/`[LOCKED]` markers and `STATE_COLORS` semantics kept. The only wording change is the planned-lanes line ("Planned constellations: …") and the title ("SKILL CONSTELLATIONS — MINER LANE"), neither smoke-asserted.
- **New hook + check**: `link_count()` exposes how many constellation links the canvas draws; `fq09s_constellation_links_match_prereqs` (suite total 185) proves it equals the live lane's prerequisite-pair count derived from the same data, so presentation can never invent or drop an edge.

## FQ-09R Additions

- **Unified tree rule (replaces the FQ-02 split)**: every generated tree is now a `tree_trunk` column (3-5 tall, wood hardness 0.55, axe-preferred, drops 1 wood per cell) topped by a `tree_leaves` canopy (3x2, fast to clear, no drops). Both blocks are non-solid and non-placeable: the player walks in front of/past every tree with no collision, and harvests any tree through the existing mining/axe path. There is no walkable-but-not-harvestable tree class anymore.
- **Retired FQ-02 surfaces**: `background_cells`, the `BackgroundFlora` TileMapLayer, `bg_trunk`/`bg_canopy`, `WorldGen._grow_background_tree`, `world.background_at`, and the `generation.tree_foreground_ratio` config key + "Solid Tree Ratio" world-builder slider are all removed. Trees live in `cells` like any block: regenerated from seed+config, mined cells persist as normal `air` deltas, and the Town Hall stamp clears its footprint. Placed `wood` blocks are untouched (still solid, buildable, roof/shelter material).
- **Creation-rule clarity**: the character create form states that backpack, tools, equipment, ancestry, role, and traits follow the character between worlds, role starter items are granted once, and collapse loses a fraction of carried stacks (wording matches the live destroy-not-drop behavior). The world create form states that terrain, stockpile, threats, storms, base level, player level, position, and current health belong to the world, and that entering with another character uses that character's carried gear. No future mechanics are implied.
- **Smoke**: the 8 `fq02_*` checks are replaced by 8 `fq09r_*` checks (suite total unchanged at 183); the wood mining/axe baselines now harvest `tree_trunk` (same hardness, same wood drop, same frame expectations).
- **Skill tree direction**: FQ-09S should be a presentation-only pass: Skyrim-style constellation/star-map vibes with 8-16bit readability, using the existing perk data, point economy, Miner lane, K/Esc behavior, and `try_purchase_perk` purchase path.

## FQ-08 Additions

- **Block damage stages**: `player.mine_damage_stage()` (0-3 from mining progress) drives a crack overlay drawn on the target cell while mining — deterministic per cell (seeded from the target, no flicker), denser cracks per stage, layered over the existing highlight/progress bar. Purely transient: never enters `cells`/deltas/saves, resets via the existing `_reset_mining` on target change or release, and `apply_state` now clears in-memory progress so a load can never resurrect partial damage.
- **Crack sprite mask (post-FQ-09R hardening)**: crack segments are rasterized pixel by pixel through `world.block_opaque_mask(block_id)` — a cached BitMap of the tile texture's opaque pixels (art or generated fallback) — so degradation never draws outside the visible sprite: a thin `tree_trunk` bar, leaves, a bush, or a torch only crack where their pixels actually are. Solid tiles are fully opaque, so their crack layout is unchanged. The same principle already held elsewhere: the Town Hall damage overlay covers exactly its drawn wall rect, and enemy hurt tints ride the sprite/fallback shape.
- **Enemy hurt feedback**: a mini health bar appears above any damaged enemy (both the FQ-07 art path and the drawn-rect fallback, which also keep their tint/lighten cues); `health_bar_ratio()` exposes the fill. Damage is clearly visible well before death.
- Drops, mining frame counts, and save/load behavior are untouched — verified by dedicated checks plus the unchanged legacy baselines.

## FQ-07 Additions

- **Image-first rendering with safe fallback**: `BlockRegistry.visual_texture(category, id)` resolves `data/visual_assets.json` explicit entries or the `art/generated/<category>/<id>.png` convention, loading via `Image.load_from_file` (no editor import pass — plain runs pick up new art immediately, matching how this repo is always run). Misses are cached as null and every render site keeps its existing generated look: `world._make_block_texture` (blocks, with nearest-neighbor resize to tile size), `simple_threat._draw` (enemies, hurt tint preserved via modulate), and a new 5-slot hotbar icon strip (items; icons hidden without art, so the text hotbar stays the fallback).
- **Asset workflow docs**: `art/source_templates/ASSET_TEMPLATE.md` — naming rules (data ids, lowercase snake_case), target sizes (16px blocks/items/enemies, 32px ui), prompt skeletons for local Ollama/image-model iteration (which stays entirely outside the game and validation), and a review checklist for one-by-one art passes.
- **Validator policy**: broken explicit `visual_assets.json` references fail; convention-path gaps print INFO lines and never fail — art arrives incrementally.
- The repo ships zero art: everything renders from fallbacks today, and the smoke proves both directions (image wins when present, fallback returns when removed) with self-cleaning temp files.

## FQ-06 Additions

- **Perk node schema**: every node in `data/progression/perks.json` (7 lanes x 3) gained description, cost, grid position, and same-lane prerequisites (validator-enforced, unique ids). The **Miner lane is live**: `stone_recovery` (root, `mining_speed` x1.15 -> `effective_mine_speed`), with `deep_sense` and `tunnel_safety` as prerequisite-gated branches whose planning effect keys stay inert until ore-sensing/cave-hazard systems ship.
- **Perk economy**: one point per player level above 1 (`perk_points_total = player_level - 1`); spent points derive from purchased costs. `purchased_perks` is world-owned progression state (like XP/levels); unknown ids are dropped on load. `game_root.try_purchase_perk` gates on state ("purchased"/"available"/"locked" via prerequisites) and affordability, then recomputes combined effects onto the player — `mining_speed` multiplies, `attunement_bonus` adds into `max_attunement()` (the FQ-05 join point is now live code, awaiting a node that carries it).
- **Skill tree panel** (`scripts/ui/skill_tree_panel.gd`, K / `toggle_skills`): scrollable node canvas laid out from data positions, state-colored buttons with [OWNED]/[LOCKED] markers, an inspector (title, state, cost, effect, prerequisites, description), a learn button backed by real points, and the planned lanes listed. Mutually exclusive with the inventory/town panels; Esc closes it first in the chain.

## FQ-05 Additions

- **Attunement resource**: current pool world-saved next to health (pre-FQ-05 saves default to full); `player.max_attunement()` is computed live as base (`player_defaults.base_max_attunement` 50) + ancestry `attunement_bonus` + gear `attunement_bonus` sum, so modifiers can never go stale. Constant slow regen everywhere (`attunement_regen_per_sec` 2.0, scaled by ancestry `attunement_regen_mult`). New HUD bar directly under health.
- **First active use**: `attune_pulse` (R) releases a harmless light pulse — spends `attunement_pulse_cost` (15), gated by its own cooldown (1s), a lazy PointLight2D on the player fades over 4s. Insufficient attunement logs a message and spends nothing.
- **Data hooks**: ancestry `player_effects.attunement_bonus`/`attunement_regen_mult` (read by `apply_ancestry_effects`; no live ancestry sets them, so non-magic characters play exactly as before), equipment `effects.attunement_bonus` (summed like armor; `amulet_focus` is the first carrier, not yet acquirable in play), and a documented perk join point inside `max_attunement()`. Extension points written up in `docs/FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md`.
- All five tuning keys live in `player_defaults` and are validator-required.

## FQ-04 Additions

- **Crude sword**: `sword_crude` (weapon slot, `attack_damage: 3`) forged at the Town Hall via the new `craft_sword` recipe (2 wood + 3 stone). `player.attack_damage()` returns the equipped weapon's damage (1 bare-handed) and feeds `_try_hit_threat` -> `threat.take_hit`, so a fresh slime (3 hp) dies to one sword strike instead of three punches.
- **Crude armor set**: `helmet_crude`/`torso_crude`/`feet_crude` (armor 1/2/1) forged in one craft via `craft_armor_set` (6 wood + 4 stone). `player.armor_total()` sums the `armor` effect over all equipped items; `take_damage` applies flat mitigation with a minimum 1-health chip per landed hit so armor can never grant immunity. Enemy contact damage, i-frames, collapse, and ancestry health modifiers are untouched.
- **Forge flow**: `town_hall.forge_sword`/`forge_armor` follow the forge_axe pattern (stockpile inputs via a shared `_consume_recipe_inputs` helper, occupancy guards on the weapon/torso slots, equip via `player.equip_item`); two new town-panel buttons with crafted-state refresh; XP via `tool_crafted`.
- **Visible state**: the toolbelt line shows "Weapon <name> · Armor N"; the inventory panel's EQUIPMENT section gained an "Attack N · Armor N" summary. Rings, amulet, and accessory remain inert slot-ready data.

## FQ-03 Additions

- **Equipment data surface**: new `data/equipment.json` defines 12 gear slots (weapon, axe, pickaxe, helmet, torso, feet, ring_1-4, amulet, accessory — each with `accepts` slot_type) and item defs with `slot_type` + `effects`: `pick_basic` (pick_tier 1), `pick_forged` (pick_tier 2), `axe_crude` (axe_tier 1), and the inert `ring_band`. Loaded by the `BlockRegistry` autoload with helper functions (slots, items, `item_fits_slot`, `normalize_equipment`, `pick_item_for_tier`/`axe_item_for_tier`). Validator enforces the slot list, required items, and slot_type coherence.
- **Authority model**: `player.tool_tier`/`axe_tier` remain the live mining authority — mining, `forge_pick`/`forge_axe`, and all prior smoke checks are untouched. Equipment is the persistence/display shape: `player.equipped_dict()` derives the pickaxe/axe slots from the live tiers (so display and saves can never drift from behavior); the 10 other slots live in `player.equipment` and are slot-ready data for FQ-04. `player.equip_item(slot, item)` validates slot/item fit; tool slots route to the tiers.
- **Character-owned persistence**: character records gain an `equipment` dict (new characters: `pick_basic` + 11 empty). `save_character_carried` gained an optional 5th equipment param (`{}` = leave stored gear untouched, keeping legacy 4-arg callers safe); `save_manager.save_game` passes `player.equipped_dict()`. Both carried-state load paths apply the dict; pre-FQ-03 characters keep tiers/inventory and gain gear on migration/first save. Backpack inventory stays fully separate from equipped gear.
- **Minimal UI**: the inventory panel (I) gained a read-only EQUIPMENT section listing all 12 slots with item names or `(empty)`.

## FQ-02 Additions (superseded by FQ-09R)

- FQ-02 introduced a foreground/background tree split: solid mineable `wood` columns vs. pass-through `bg_trunk`/`bg_canopy` visuals on a separate `BackgroundFlora` layer, controlled by `generation.tree_foreground_ratio`. **FQ-09R replaced this split with one unified tree rule** (see FQ-09R Additions); the background layer, ratio key, and slider no longer exist.
- Still true from FQ-02: trees generate on their own seed channel, tree density is world-builder controlled, and mining frame contracts (dirt 21 / trunk-at-wood-hardness 33 / stone 66; with axe 24) plus wood drops, axe preference, bush support/regrowth, and save/load were preserved through both passes.

## v0.6 Additions

- **Wave A — ancestry details**: character creation shows a compact data-driven panel per ancestry (`scripts/data/ancestry_detail.gd`, pure `build_panel_text` used by UI and smoke): description, live player effects formatted from `player_effects` keys, tradeoffs, spawn band, biome affinity summary; non-live ancestries labeled "[Planned — not playable yet]". All 12 ancestries gained one-line `description` fields (validator-required).
- **Wave D — world builder clarity**: new `ui_help` section in `data/world_settings.json` (validator-required) with `axis_help` for all six difficulty axes, `gen_help` for generation sliders, and `preset_descriptions` with deviations; the create screen shows preset description/deviations, size dimensions from data, and one-line help under each slider.
- **Wave B — character-owned inventory**: carried state (inventory counts, hotbar slot, tool tiers) lives on the character record in `user://shell.json` (`carried_inventory`, `carried_slot`, `carried_tool_tiers` {pick, axe}, legacy `carried_tool_tier` alias, `items_granted`). World saves retired `player.inventory/selected_slot/tool_tier` and keep terrain, hall stockpile, time, threats, storms, base/settlement state, progression, player position and health, and summary. Role starter items grant once per character. F5 and Esc persist both world and carried state. No world save version bump (dropped keys tolerate `.get` defaults; `ACCEPTED_VERSIONS` still `["0.5", "0.4"]`).
- **Wave C — openable inventory**: new `toggle_inventory` action (I) opens a HUD panel listing all carried stacks plus a tool line; inventory and Town Hall panels are mutually exclusive; Esc closes open panels before falling through to save-and-exit.
- **Wave E — bush support rule**: `berry_bush` has `requires_support: true` (generic flag read by `world.gd`): mining the support breaks the bush with normal drops and schedules regrowth; the post-delta load sweep cleans unsupported bushes without granting items; regrowth re-schedules when support is missing.
- **Wave F — differentiated tools**: blocks gained `preferred_tool` (wood/berry_bush -> axe; stone/ore -> pick). The `craft_axe` recipe (4 wood + 2 stone, town_hall station) forges an axe via a second hall button, awarding `tool_crafted` XP. With an axe, axe-preferred blocks mine 1.4x faster; stone/ore and the tier-2 pick gate are untouched (baseline mining-frame assertions unchanged: dirt 21 / wood 33 / stone 66; wood with axe 24). Tool state persists as character-owned `{pick, axe}`.

## Explicit Decisions

- **Player XP/level stay world-owned in v0.6.** Carried inventory moved to the character, but `xp_totals`, `player_level`, `base_xp`, and `base_level` remain in the world save. Revisit if characters should level across worlds.
- **Legacy migration is conservative**: a pre-v0.6 character (no `carried_inventory` key) adopts the world save's player inventory/hotbar/pick tier once, then the character record is authoritative. Legacy `carried_tool_tier` maps to `{pick: N, axe: 0}` — the axe must still be crafted; nobody gets one free.
- Unsupported-bush cleanup during load grants no drops (avoids inventory changes on load); mining the support does grant drops (keeps the food loop fair).

## Validation Status (2026-07-20)

| Check | State | Evidence |
|---|---|---|
| Repo identity | PASS | `main...origin/main` at `f545daf`; project_id `coheronia-game` |
| JSON/scaffold validator | PASS | `python scripts/validate_repo.py` 2026-07-20 -- all file/json/contract checks green, `INFO 0 optional visual assets pending` |
| Strict runtime-asset audit | PASS | `python scripts/asset_audit.py --strict` 2026-07-20 -- "Clean: no findings or data bugs."; all block/item/enemy/player/gear/ui/opening/background categories LIVE or intentionally reserved |
| HUD-kit runtime verify | PASS | `python scripts/art/sync_hud_kit.py --verify-runtime` 2026-07-20 -- 19 source/runtime hashes + layout verified |
| Pixel-art verifier | PASS 386 PNGs | `python scripts/art/verify_pixel_assets.py` 2026-07-20 -- size/palette/alpha/edge contracts satisfied (painted chrome via the FQ-20 light pass) |
| Capsule doctor | PASS | `public_repo` profile 2026-07-20: healthy |
| Automated smoke | **PASS 341/341** | isolated waited Windows Godot 4.6.1 runs (2026-07-20, post PR-04). PR-03B added `pr03b_gear_overlay_offset_applied`; PR-04 added `pr04_swing_direction_follows_target`, `pr04_action_profile_phases`, `pr04_sword_uses_action_contract` (+3). The `fq17`/`fq19` layout checks reset to the default layout at their own start (profile-state independent). The real-time `fq09u1_live_clip_switch` adaptive-music check occasionally cold-flakes and passes on rerun. No assertion weakened. |
| Music asset verifier (Codex lane) | PASS | `scripts/audio/verify_music_assets.py`: loops exactly 2,560,000 samples @ 48 kHz, stingers < 8 s, 63 stem combinations below full scale; operator listening approval GRANTED 2026-07-10 |
| Manual GUI passes | PASS | FQ-09C: clean-profile autoplay/replay/advance/skip with real input and screenshots. FQ-09W: screenshot tour re-run reviewed frame by frame — day settlement with backdrop (sky reaching the deepest valley, no torch glow on distant ridges), night torchlight, and the new `09_underground_midday_torch` chamber shot (dark ambient, torch-lit walls). Authored-art closeout: isolated hidden/windowed tour wrote and visually passed all nine frames at 2026-07-14 15:04, including varied terrain/flora and inventory icons. |

## Known Risks / Gotchas

- The Windows Godot GUI binary does not reliably run smoke through a direct headless invocation. Use `Start-Process -Wait` and verify `user://smoke_results.json`.
- The smoke run mutates the real `user://shell.json` profile; its tests create and delete their own characters/worlds. If a smoke run is killed mid-test, stray "Smoke"/"Legacy" test characters may remain in the shell. The FQ-09C seen-flag check restores the profile's prior `prologue_seen` value.
- FQ-09C: cinematic composition keeps meaningful action above canvas y≈272 because the lower-quarter text band overlays the pixel surface; new scene content should respect that line. Audio cues are placeholder ids with no shipped assets. The scene 3/5 figures and hall geometry are hand-plotted coordinates in `prologue_canvas.gd` — adjust there, not via images.
- A character's backpack now follows them between worlds — dropping items "in a world" for another character is no longer possible (no ground-drop mechanic exists).
- Player position/health are still world-owned: entering a world last played by another character starts from that world's saved position/health with the entering character's inventory/tools/traits.
- The inventory panel is read-only; hotbar contents remain the fixed block set.
- Axe tiers stop at 1; only the pick has a tier-2 upgrade path.
- Raider pressure, XP pacing, and base-level thresholds remain untested by human play.
- FQ-11 stations are surfaced in the Town Hall panel's scrollable station
  section (below the existing forge buttons), so build/craft buttons can sit
  below the fold and need scrolling — a future UI pass could tab or reorganize
  the panel. The station chain, ingot economy, and iron gear balance
  (sword_iron attack 5 vs crude 3; iron armor 2/4/2) are data-tunable in
  `recipes.json`/`equipment.json` and untested by human play. The metal gate
  (no raw-ore -> gear recipe) is validator- and smoke-enforced. Ingots and
  built stations live in settlement/save state only; no new world-gen or
  block placement. The visual review of the built-station buttons was limited
  to confirming the panel renders without layout breakage (the shots tour
  captures the panel unscrolled).
- FQ-10 changes underground composition on regenerated terrain: worlds saved
  before FQ-10 regenerate with the six new ore families where plain stone used
  to sit (deterministic from seed+config; terrain deltas still overlay cleanly).
  Cosmetic/economy only, no data loss. The new ores have no recipe consumer
  yet (FQ-11), drop themselves as raw items, and are gated to the reachable
  tier-1/tier-2 pick range. Ore density feel at the default `ore_abundance` is
  data-tunable in `world_settings.json` `ore_table` and untested by human play.
- FQ-09R changes the tree layout of regenerated terrain (as FQ-02 did before it): worlds saved earlier regenerate with unified `tree_trunk`/`tree_leaves` trees where solid wood columns or background flora used to stand. Terrain deltas still apply cleanly (they overlay regenerated cells); an old "air" delta where a tree used to stand may sit oddly next to new trees. Cosmetic only; no data loss. Old world configs may still carry a stored `tree_foreground_ratio` key; it is simply ignored.
- Generated trees no longer contribute to shelter/roof/occlusion math (trunk and leaves are non-solid and do not block light); only placed solid blocks such as `wood` do. Wood supply per tree site rose slightly (every tree is now harvestable), untested by human play.
- Mining a low trunk cell leaves the upper trunk/canopy cells floating (no support rule on trees, mirroring the old floating wood columns). Cosmetic; each floating cell remains harvestable.
- Equipment UI remains read-only (`player.equip_item` is the API; no drag/drop). Rings, amulet, and accessory still have no live effects; ring_band exists only for the round-trip smoke.
- FQ-04 armor is flat mitigation with a 1-health minimum chip; there is no unequip flow for forged gear in play (forge guards prevent duplicates). Combat feel (sword damage 3, armor total 4 vs slime 8) is untested by human play; all numbers are data-tunable in `data/equipment.json`.
- FQ-05 attunement has exactly one use (the light pulse); no live ancestry or acquirable gear modifies it yet — the hooks are data-ready and smoke-proven but dormant. The pulse light is cosmetic (does not affect `light_score`, night spawns, or occlusion safety math).
- FQ-06: only the Miner lane's `mining_speed` effect is live; `detect_ore_range`, `cave_safety`, and all non-miner lane effect keys are inert data awaiting their systems. There is no perk refund/respec. Perk points come only from player levels; XP pacing (100 x 1.35^n) means points arrive slowly — untested by human play.
- FQ-07: art loads bypass the Godot import system (`Image.load_from_file`) by design for plain non-editor runs — an exported build would need an import-aware path (out of scope; this repo never exports). The block tileset reads art at `world.setup`/tileset-build time; dropping in new art requires re-entering the world (no hot-reload). Player bodies and the Town Hall use image-first hooks with procedural fallbacks. The later gear program added 120 body-specific overlays; intermittent resolution/alignment remains a presentation defect.
- FQ-09W's underground darkness is a documented approximation: the ambient
  follows the PLAYER's column skylight (no lateral light bleed, no per-cell
  darkness — the whole canvas darkens when the player is buried, so surface
  areas at the screen edge darken too while underground). True per-cell
  skylight (directional shadows or cell connectivity) is the recorded future
  path and would require extending occluders beyond blocks_light blocks.
  Natural backing walls are visual-only and immutable this slice; placeable/
  removable constructed walls (drops, wall deltas, save migration) remain a
  deliberately separate future gameplay task.
- A hypothetical pick tier above 2 has no matching equipment item; the gear shape would record the highest defined pick (`pick_forged`) while the live tier is preserved in `carried_tool_tiers`. No real character can exceed tier 2 today (forge caps at 2).

## Authored Sprite Coverage (2026-07-14, post-FQ-15)

- The repo now carries 189 runtime PNGs. All 20 rendered block ids, all 43
  inventory/live-drop ids, and all six live enemy ids have canonical art.
- Seventeen high-repetition block ids have three deterministic per-cell looks;
  all six enemy families have three lifetime-stable looks; all ten player body
  ids have two selectable alternatives beyond canonical.
- The five formerly metadata-less live drops (`chitin`, `silk`, `eyes`,
  `coins`, `scrap_weapons`) now have item names/colors/descriptions, and the
  asset audit independently derives live drop ids from `enemies.json`.
- The character-creation Look control reads the selected body's real pool size
  instead of offering hard-coded no-op values.
- `scripts/art/prepare_pixel_asset.py` is the repeatable source normalizer;
  `scripts/art/verify_pixel_assets.py` enforces dimensions, <=16-color pixel
  palettes, hard alpha/corners, material-specific tile edges, player scale,
  and exact appearance-palette compatibility. Generated bodies pass through
  `scripts/art/restore_player_skin_palette.py` before promotion. Strict audit
  also rejects sequence gaps and pools above the runtime maximum.
- At this historical checkpoint, player gear, final UI replacements, and opening
  cels were deliberately deferred for the reasons recorded in
  `docs/HANDOFF_ART_INTEGRATION_2026-07-14.md`. The current repository now has
  120 player-gear overlays, ten opening PNGs across eight cel pools, and the
  19-asset layered HUD kit described at the top of this handoff.

## Next Action

FQ-00 through FQ-21 are complete (full lineage in `docs/FABLE_TASK_QUEUE.md`
and the historical sections above). The active queue is the **presentation
recovery arc** planned in `docs/PRESENTATION_RECOVERY_MATRIX.md`. PR-00 (smoke
harness truth repair), PR-01 (masculine/feminine terminology migration), PR-02
(character preview/rendering contract), PR-03A (gear overlay resolution/refresh
hardening), PR-03B (gear overlay alignment), PR-04 (directional action
animation, code half), PR-05 (creation/select preview through the shared
render path), PR-06 (Character HUD rebuilt on runtime children, code lane),
PR-07 (backdrop seam/contour skirt), and PR-08 (skill panel viewport-relative)
are **done** -- the suite is 346/346 (PR-08 plus the character-create
scroll/fixed-actions follow-up). **The presentation recovery arc's code
lane (PR-00..PR-08) is complete.**

The **Release Foundations** arc (`docs/WORK_ORDER_RELEASE_FOUNDATIONS.md`, rows
R-00..R-10) is now the active code-lane sequence.

**R-00 (Export-readiness audit) done 2026-07-21.** A Windows `--export-pack`
plus an isolated `--main-pack` run proved that imported PNG/OGG resources
loaded through raw file APIs fail from a packed build (import remap), while
`data/*.json` loads fine (no importer); the failure surface (all authored art
procedural, adaptive music disabled with a real-time hang) and the responsible
loaders/paths were recorded per category.

**R-01 (Export-safe runtime resources) done 2026-07-21.** The two centralized
raw loaders are now import-aware. `BlockRegistry._texture_from_file` loads via
`ResourceLoader` (export-safe) and rebuilds a CPU-resident `ImageTexture` so the
world tileset, appearance recolor, and HUD keep a manipulable texture, with a
`FileAccess`/`Image.load_from_file` fallback for non-imported/temp files (never
present in an exported PCK). `MusicManifest` loads streams via `ResourceLoader`
and **duplicates** them before stamping loop/BPM/grid, so the shared cached
import resource is never mutated. A committed minimal Windows `export_presets.cfg`
(now tracked; `.gitignore` updated) needs no special include filters. Two new
smoke checks (`r01_export_safe_visual_resources`, `r01_export_safe_audio_resources`)
run through the runtime loaders. **Source waited-GUI smoke 348/348** (the two new
checks green). Export templates `4.6.1.stable` installed; a real Windows
executable was built and launched with the export smoke — canonical art loads
(enemy pools, UI/HUD kit, backdrop, bodies/gear), all **4 context loops + 6 stems
+ 5 stingers** load with music enabled and **no disabled-music hang**, and
appearance recoloring is correct in the export. Artifact:
`coheronia.exe` (95.9 MB) + `coheronia.pck` (9.6 MB), built to a temporary
ignored output directory. Six checks that write temp fixture PNGs into `res://`
fail **only in the exported PCK** because `res://` is read-only there; they are
green in source and exercise a dev-only hot-reload capability, not shipped game
content (their handling is an explicit R-03 acceptance item).

**R-02 (Save integrity) done 2026-07-21.** All shell/world persistence in
`scripts/shell/game_state.gd` now goes through `_atomic_write_json` (write a
validated temp, back the current file up to `.bak`, then rename into place — a
crash or bad serialization never damages the live save, and the final rename
restores the `.bak` if it fails) and `_load_json_recover` (a corrupt primary is
quarantined to `.corrupt`, the `.bak` is tried, and the outcome is surfaced via
`shell_load_status` / `world_load_status` as `ok`/`missing`/`recovered`/
`quarantined`/`unsupported_schema`). `save_shell` and `_write_world` write
atomically; `load_shell`/`load_world_file`/`list_worlds` recover and surface; a
recovered save re-persists to heal. `create_world` returns `""` on write failure
(observable) and the shell world-create flow + `ensure_play_context` guard it. An
unknown/future `shell_version` is surfaced without destroying data. No corrupt
save silently becomes a fresh empty profile. Smoke:
`r02_atomic_write_backup_recover_quarantine` + `r02_shell_world_integrity`.
**Source waited-GUI smoke 350/350**; validator + Capsule Doctor + wiki links +
`git diff --check` green.

**R-03 (Isolated verification) done 2026-07-21.** The persistence root is
injectable: `GameState.persistence_root` derives `shell_path()` / `worlds_dir()`,
`set_persistence_root()` re-points and reloads, and `_ready` honors a
`COHERONIA_PERSIST_ROOT` env or auto-routes any automated/capture flag
(`COHERONIA_SMOKE`/`SMOKE_FOCUS`/`HUD_QA`/`SHOTS`) to `user://smoke_root/` — so a
test/capture run never reads or writes the player's real profile (verified: the
Metis test character survives smoke runs untouched). The smoke now records split
reporting: per-suite tallies (`shell`/`save`/`world`/`ui`/`presentation`/
`progression`/`audio`), `skipped`/`skipped_names`, `duration_sec`, `commit`
(from `COHERONIA_COMMIT`), and `persistence_root`. The six temp-art fixture
checks that write into `res://` now `_check_res_fixture` — they **skip** under an
exported build (read-only `res://`) and run their assertions unchanged in source.
Smoke `r03_isolated_verification`. **Source waited-GUI smoke 351/351** (0 skipped;
consecutive runs stable); the **exported `.exe` smoke is 345/345 + 6 skipped**
(fully green — this closes the R-01 deferred fixture item). validator + Capsule
Doctor + wiki links + `git diff --check` green.

**R-04 (CI and release automation) done 2026-07-22.** `requirements.txt` pins the
Python environment (`Pillow>=10.0,<12`; everything else is stdlib).
`scripts/ci/verify.py` is a single verifier command: it runs the static gate
(`validate_repo`, strict `asset_audit`, HUD-kit runtime hashes, gear alignment,
Capsule Doctor `public_repo`, wiki links) and, given `--godot`, the waited
in-engine **source** smoke plus (with `--export`) a real export whose artifact is
then **launched in smoke mode** (`COHERONIA_SMOKE=1`, absolute
`COHERONIA_RESULTS_PATH` outside `user://`). Source and exported results go to
separate files (`build/source_smoke_results.json`,
`build/export_smoke_results.json`; `smoke_test.gd` `_write_result_file` honors
`COHERONIA_RESULTS_PATH`). The verifier requires **source 351/351 with zero
skips** and requires the **exported** run to launch, pass every non-skipped
check, and skip **exactly** the six read-only `res://` fixtures
(`fq07_block_renders_from_image`, `fq07_item_renders_from_image`,
`fq09v_variant_pools_resolve`, `fq09c_cel_shot_hook`, `fq09w_wall_art_hook`,
`fq21_hud_theme_asset_fallback`) — any skip outside that allowlist, any missing
allowlist skip, a non-skipped failure, or a launch failure fails the run. It
stamps `build_info.json` (commit/built-at/godot/preset) and exits non-zero on any
failure. `.github/workflows/ci.yml` runs a `static` job that gates a `godot` job
pinned to **Godot 4.6.1-stable** (matching export templates, `xvfb` import +
smoke, real `Linux/X11` export **and execution of the exported artifact** via the
verifier); both result files + `build_info.json` + the artifact are uploaded, and
the smoke/export step and job carry finite `timeout-minutes` (20 / 30) so a hang
fails rather than hanging the runner. Any failing step blocks. A native
`Linux/X11` preset was added to `export_presets.cfg` so the runner exports without
cross-compilation (Windows Desktop preset unchanged). Evidence: local
`verify.py --godot … --export` gave **source smoke 351/351** (0 skipped; per-suite
world 174 / ui 51 / presentation 66 / audio 25 / progression 18 / save 15 /
shell 2), export **OK**, then the **exported artifact launched → export smoke
345/345 with exactly the six allowlist skips** (set-equal verified); static gate
green; YAML parses; `build/` stays gitignored.

**R-05 (Public repository and release cleanup) done 2026-07-22.** Untracked the
165 raw private ledgers (`.project/runs`, Atlas/BOH outbox) the `public_repo`
profile forbids (`git rm --cached` + ignore rules; `.gitkeep` skeletons kept; no
history rewrite); removed the duplicate root prompt and every workstation path in
tracked docs (`<repo-root>`/`<godot-binary>`/`<python>`/`<workstation-path>`);
added `.gitattributes`, `CONTRIBUTING.md`, and a split license (`LICENSE` MIT for
code/tooling/engineering-config; `LICENSE-ASSETS.md` reserves art/audio/video/
screenshots/reference-media and authored creative/narrative content, data schemas
and generic config MIT, engineering docs MIT unless carrying reserved creative
content); removed the orphaned 64 MB gameplay `.mp4` (README keeps the YouTube
link). A separate PR-07 correctness follow-up redrew the backdrop contour skirt as
per-column quads (was a self-intersecting polygon that dropped the whole
under-earth backing at high camera angles) with a deterministic geometry smoke
check and a before/after capture. Source smoke **352/352**, exported **346/346 +
6 skipped**, zero triangulation errors; static/wiki green.

**R-07, playability baseline: all four slices done (slices 1-2 pushed; 3-4 local).**
Control model unchanged (left click = mine/attack, right click = place/use).
Slice 1 (pause/settings/keybinds, `0160ada`) and slice 2 (save management: delete
confirmation + in-game Restore, `183a311`) are pushed. Slice 3 (build preview +
reasoned invalid-placement feedback, `ded9d0f`) is local: `player.place_reason`
authority, `try_place` emits the reason (no silent fails), and `build_preview.gd`
draws a green/red aim ghost on a `follow_viewport` CanvasLayer (undimmed by the
world tint). Slice 4 (crafting navigation) is local and uncommitted:
`scripts/ui/craft_panel.gd` is a unified Crafting panel (C toggles, Esc closes)
grouping every recipe by source (Hand/Town Hall/Workbench/Furnace/Anvil) with
have/need gating and Build rows for unbuilt stations; `game_root` routes crafts by
station (Town Hall gear -> special `forge_*` methods); a `GameState.craft_panel_open`
flag freezes player input while open. The Town Hall panel is trimmed to
deposit/status/Repair and the dead forge/lantern/station-build plumbing removed
(rg-verified). Empty-output forge/anvil recipes carry an explicit `icon` item id
(existing art) so every visible craft row has a real icon or a documented no-icon
state (`CraftPanel.recipe_icon_id`). No build mode, flipped actions, instructional
text, or art. Source smoke **369/369**, exported **363/363 + 6 skipped**, VERIFY
PASS. R-06 (ownership
decomposition of `hud.gd`/`game_root.gd`) is deferred. See
`docs/WORK_ORDER_RELEASE_FOUNDATIONS.md`.

**PR-09** remains deferred/planning-only. **PR-10**, iron gear, sword/tool
frames, HUD chrome, and all other final visual assets remain art-lane work
through the image-production matrix and
`docs/wiki/hud_asset_replacement_studio.md` -- never code-lane work.

Big-ticket playability items (pause/settings/keybinds, save-slot management,
build-preview tint, quest/contracts, subject/NPC labor MVP) remain queued in
`docs/FABLE_TASK_QUEUE.md` behind the recovery arc. The operator playtest
pass is `docs/PLAYTEST_CHECKLIST.md`. Close every increment with validator,
Capsule Doctor, a freshness-checked waited Godot smoke, screenshot review
for visual changes, and real pass/fail evidence in the docs.
