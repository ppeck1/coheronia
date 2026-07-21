# Coheronia Presentation Recovery Matrix

Status: planning authority for the presentation recovery arc (PR-00 opened
2026-07-20). `docs/FABLE_TASK_QUEUE.md` and `docs/HANDOFF.md` point here for
the current work; this file owns the row-level scope, lanes, and acceptance
checks.

## Ground Rules For This Arc

- **Lane separation is mandatory.** Rows marked `code` are Claude/code-safe:
  code, data contracts, validators, diagnostics, and docs only. Rows marked
  `art` require separate image production and are queued in the
  [image-production follow-up matrix](#image-production-follow-up-matrix)
  below -- a code lane must never generate, redraw, replace, or "improve"
  final production PNGs.
- Every fix that touches a visual surface requires native-size screenshot
  review in addition to validators and the smoke suite (the standard set in
  `docs/wiki/known_issues.md`).
- Preserve the image-first fallback rule everywhere: missing or unresolved
  art keeps the procedural/legacy fallback and never crashes or blocks
  gameplay.
- One row at a time, closed with validator + Capsule Doctor + smoke +
  updated evidence, per the queue rules in `docs/FABLE_TASK_QUEUE.md`.

## Verified Baseline (PR-00, 2026-07-20)

Original planning baseline (branch `main` at commit `f545daf`): validator,
strict asset audit, HUD-kit runtime verify, and Capsule Doctor all PASS; the
Godot 4.6.1 waited-GUI smoke was **FAIL 332/334** with two red checks
(`fq17_hud_edit_direct_manipulation`, `fq09_inventory_board_drag_and_sort`).
The `fq09u1_live_clip_switch` check passed that run -- older docs that named it
as one of the red pair are superseded.

**PR-00 resolved 2026-07-20.** The smoke is now **334/334 PASS** on a fresh
waited-GUI run. Both root causes were in `scripts/ui/hud.gd`; no smoke
assertion was weakened:

| Failing check | Root cause | Fix |
|---|---|---|
| `fq17_hud_edit_direct_manipulation` (`reset=false`; the earlier `visibility`/`grip` reds were profile-state contamination the same bug wrote back into `shell.json`) | `_hud_default_sizes["crest"]` was captured in `_register_hud_widgets()` during `_ready`, before the crest container laid out, so it stored a `(250,40)` stub instead of the real `(250,184)`. `reset_hud_layout` restored the stub and re-saved it, poisoning the profile. | New `_hud_natural_size()` derives the default from `get_combined_minimum_size()`, so reset restores the content-driven `(250,184)` and matches the live size. |
| `fq09_inventory_board_drag_and_sort` (`drag_payload=false`) | `_clear_children` used deferred `queue_free()`, leaving old cells in the tree while the board re-added cells with identical names (`InventoryDockSlot%d`); Godot renamed the fresh cells to dodge the collision, so the name-based lookup only found the stale queued-for-deletion cell. | `_clear_children` now `remove_child`s each node immediately before `queue_free()`, so rebuilt cells keep their exact names. |

## Recovery Matrix

| ID | Lane | Row | Current defect / goal | Primary code & contract surfaces | Acceptance |
|---|---|---|---|---|---|
| PR-00 | code | Smoke harness truth repair | **DONE 2026-07-20.** Two red assertions (`fq17_hud_edit_direct_manipulation` reset, `fq09_inventory_board_drag_and_sort` drag payload) kept the 334-suite at FAIL; both fixed in `scripts/ui/hud.gd` (natural default size + immediate child removal). | `scripts/ui/hud.gd` (`_hud_natural_size`, `_clear_children`) | Met: both checks green, no assertion weakened, fresh waited run **334/334 PASS**. |
| PR-01 | code | Terminology migration (masculine/feminine) | **DONE 2026-07-20.** Canonical ids `masculine`/`feminine`; legacy `default`/`female` are read-time aliases through `BlockRegistry.normalize_body_variant`; PNG filenames unchanged (canonical -> filename via data-owned `body_variant_asset_suffix`). | `data/player_visuals.json`, `data/character_data.json`, `scripts/world/block_registry.gd`, consumers (`player`, `player_visual`, `game_state`, `shell_ui`, `hud`), `scripts/validate_repo.py`, `scripts/wiki/generate_wiki.py`, smoke, character wiki pages | Met: legacy input re-saves canonical; all ten bodies resolve for both canonical and legacy inputs to the same filenames; validator + smoke 334/334. |
| PR-02 | code | Character preview/rendering contract | **DONE 2026-07-20.** The body/gear resolution rules and compositing order are now written up in `docs/CHARACTER_RENDERING_CONTRACT.md` (validator-required authority); `CHARACTER_LAYER_ORDER` is the single source of the layer order and is exposed in `presentation_snapshot()`. No rendering change. | `docs/CHARACTER_RENDERING_CONTRACT.md`, `scripts/player/player_visual.gd` (`CHARACTER_LAYER_ORDER`, `presentation_snapshot()`), `scripts/validate_repo.py`, smoke | Met: documented compositing contract; `pr02_character_render_contract` pins the snapshot key set + layer order + drawn slots; `_draw` untouched; suite green. |
| PR-03A | code | Gear overlay resolution/refresh hardening | **DONE 2026-07-20.** Root cause: `_gear_texture`/`_tool_swing_texture` keyed off `_resolved_body_id`, so a valid character whose body texture was unresolved (cleared cache / once-missing load) silently dropped every authored overlay to procedural. Fix: resolve gear against `effective_body_id()` (resolved body, else the intended body) and refresh presentation at the equip/forge boundaries. Presentation only; normal-case resolution byte-identical. **This closes overlay *resolution/refresh* only, not *alignment* — see PR-03B.** | `scripts/player/player_visual.gd` (`effective_body_id`, `refresh_presentation`, `_gear_texture`/`_tool_swing_texture`), `scripts/player/player.gd` (`apply_equipment`/`equip_item`/`swap_weapon`) | Met: `pr03_gear_overlay_resolves_all_bodies` (ten bodies resolve body-specific gear) + `pr03_gear_survives_body_texture_miss` (gear survives a body miss via the intended body id and recovers on refresh); suite 337/337. |
| PR-03B | code | Gear overlay alignment (helmet) | **DONE 2026-07-20.** The crude helmet floated ~6px above the head on goblin/dwarf (opaque-top gap 6 vs <=3 for human/elf/orc). Fixed with a data-owned per-rig, per-slot `gear_offset` (`data/player_visuals.json`) applied to the overlay draw rect in `player_visual.gd` (`gear_overlay_offset`/`_gear_rect`); goblin+dwarf get a `helmet` nudge of `[0,5]`, every other body/slot is identity so aligned bodies never move. No PNG edited. The non-human crude *torso* sitting at the waist was judged a plausible loincloth style (rig chest anchor does not cleanly apply) and recorded for the art lane, not shifted. | `data/player_visuals.json` (`gear_offset`), `scripts/player/player_visual.gd`, `scripts/validate_repo.py`, `scripts/art/verify_gear_alignment.py`, smoke | Met: `verify_gear_alignment.py` enforces helmet/head contact (<=4px) across all ten body ids; `pr03b_gear_overlay_offset_applied` smoke pins the runtime offsets; before/after contact sheet reviewed (goblin/dwarf helmet now on the head, others unchanged); suite 338/338. |
| PR-04 | code | Directional action animation (code half) | **DONE 2026-07-20.** Replaced the uniform 3-pose loop with a data-driven **windup -> impact -> recovery** cycle aimed at the target vector (up/down/diagonal, not only rightward). Items own an `action_profile` (windup/impact/recovery fractions, arc, direction mode) in `equipment.json`; the pick/axe swing PNGs are drawn rotated toward the aim, and the sword (no authored frames) uses the same contract via a presentation-only attack swing. Mining/combat timing and effects untouched (frame baselines stay green). No image production. | `data/equipment.json` (`action_profile`), `scripts/world/block_registry.gd` (`action_profile`), `scripts/player/player_visual.gd` (`swing_direction`/`swing_progress`/`swing_phase_kind`/`_draw_action_swing`), `scripts/player/player.gd` (presentation-only `attack_swing`), `scripts/validate_repo.py`, smoke | Met: `pr04_swing_direction_follows_target` (6 directions), `pr04_action_profile_phases` (pick vs axe differ by profile), `pr04_sword_uses_action_contract`; contact-sheet/arc diagnostic reviewed; suite 341/341. Remaining swing *art* (smoother authored arcs, sword frames) stays in the image matrix. |
| PR-05 | code | Menu and character-selection preview | **DONE 2026-07-21.** Creation and character-select now compose the live figure through the **same** `PlayerVisual` the world uses (no reimplementation). A parent-independent `apply_preview_character(dict)` derives body/trim colour from `appearance` exactly like `Player.apply_character`, fills preview gear from the character's own equipment slots (normalized like the live `equipped_dict()`), and funnels into `set_character_visual()` + the shared `_draw`; with no `Player` parent, `visible_gear_ids()` returns the preview gear and `presentation_snapshot()` stays swing-safe. The creation form shows a live 6x preview refreshed on every figure-affecting selector; each select row shows the stored character at 3x with its gear. | `scripts/player/player_visual.gd` (`apply_preview_character`, `_preview_gear`, `DRAWN_GEAR_SLOTS`), `scripts/shell/shell_ui.gd` (`_make_character_preview`/`_apply_preview`/`_update_create_preview`, create + select screens), `scripts/validate_repo.py`, `docs/CHARACTER_RENDERING_CONTRACT.md` (Preview Consumers), smoke | Met: `pr05_preview_matches_world_render` proves the parentless preview's rendering-contract snapshot equals the world's for an identical character exercising body art + appearance recolour + four gear slots; validator pins the reuse; `07_character_create` shot reviewed; suite 342/342. |
| PR-06 | code (+ art deferred) | Character HUD rebuild | **DONE 2026-07-21 (code lane).** The Character panel is rebuilt on runtime children inside the existing native `ornate` chrome: a composed figure drawn through the **shared** PlayerVisual render path (`_make_character_figure` -> `apply_preview_character` on a dict assembled from live state, so the panel figure reflects the live worn gear and can never drift), live identity (name/species/body/look/appearance/role/traits), live status (health, attunement, attack, carried), and **all 13 equipment slots** from `player.equipped_dict()` shown with empty slots as an em dash. The body is cleared+repopulated on every open (`_clear_children`), so nothing is baked. No new PNGs; no chrome replacement (art lane stays PR-10). | `scripts/ui/hud.gd` (`_build_character_panel`/`_refresh_character_panel`/`_make_character_figure`/`character_figure_snapshot`, reuses `_module_content_host` ornate chrome, `_equipment_board_slots`, `_equipment_tooltip`), `scripts/player/player_visual.gd` (`apply_preview_character`, PR-05), `scripts/main/hud_visual_qa.gd` (captures), `scripts/validate_repo.py`, smoke | Met: `pr06_character_panel_runtime_render` proves the figure draws through the shared path with the live worn gear, all 13 slot names render, status/identity read live, and re-equipping + reopening updates figure/names/status (no baked values); HUD-QA shots `08_character_panel`/`09_character_panel_wide` (1280x720 + 1600x900) reviewed; suite 343/343. |
| PR-07 | code | Backdrop seam/contour skirt | **DONE 2026-07-21.** The backdrop's distant scenery was anchored to the flat AVERAGE surface line, so where the real per-column terrain top sat below the mean the distant band floated on a flat line with sky/void in the gap (the seam). A **world-space contour skirt** (`_draw_contour_skirt`) now fills, following `world.surface` per column, the band from the distant horizon down to the ACTUAL surface with a mid-ground foothill tone (`MID_COL`) so the far terrain descends into valleys to meet the ground, and backs everything below the surface contour with the under-earth tone (`UNDER_COL`) so no void shows behind terrain at any camera height. `contour_top_px(col)` is the per-column top (clamped off-world so edges never void); horizon/under metrics are anchored deferred-safe (`_recompute_metrics` from `_ready`/`_process`, since the world may generate its surface before or after the backdrop's `_ready`). No PNG touched; the skirt is world-locked (no parallax, never swims) while the distant strips keep their parallax. | `scripts/world/world_backdrop.gd` (`_draw_contour_skirt`, `contour_top_px`, `_recompute_metrics`), `world.surface`, `scripts/main/hud_visual_qa.gd`, `scripts/validate_repo.py`, smoke | Met: `pr07_backdrop_contour_skirt_follows_surface` (skirt top == per-column surface line; peak higher on screen than valley; off-world clamps to the edge; `light_mask == 0` and z-behind-walls unchanged); HUD-QA world captures reviewed (contoured backdrop meets terrain, flat floating band gone); parallax of the distant strips preserved; no-save/no-collision unchanged. |
| PR-08 | code | Skill panel resize | **DONE 2026-07-21.** The panel was a fixed 540x420 with a cramped 500x180 graph -- small at 1280x720 and unable to grow. It is now **viewport-relative**: `_apply_layout` sizes it to a clamped fraction of the logical viewport (`panel_size_for` = `VIEWPORT_FRACTION` clamped to `MIN_PANEL`/`MAX_PANEL`, never past the viewport minus a margin) and re-centres it on every `size_changed`; the graph `ScrollContainer` and the inspector now expand to fill (widths no longer fixed at 500, `MIN_GRAPH_HEIGHT` floor), so the star-map takes the extra room and stays usable as lanes grow. No perk data, node layout (`NODE_SIZE`/`SPACING`), purchase path, persistence, or inspector format changed. **Follow-up (fix `ccd3f2a`): character-create form scroll/fixed actions** -- the PR-05 preview + many selectors had made the character-create form overflow the viewport, clipping the Create/Back buttons; `shell_ui.gd` `_show_char_create` now wraps the form in a `ScrollContainer` and keeps the Create/Back row outside it (pinned), preview preserved. | `scripts/ui/skill_tree_panel.gd` (`_apply_layout`/`panel_size_for`/`panel_size`, `VIEWPORT_FRACTION`/`MIN_PANEL`/`MAX_PANEL`, scroll+inspector expand), `scripts/shell/shell_ui.gd` (`_show_char_create` scroll + pinned actions), `scripts/main/hud_visual_qa.gd`, `scripts/validate_repo.py`, smoke | Met: `pr08_skill_panel_viewport_relative` (fits with a margin at 640x360 and 1280x720, roomier than the old 540x420, live panel adopts the computed size); `pr08_char_create_form_scrolls_actions_pinned` (Create/Back outside the scroll and reachable, PR-05 preview preserved inside it, default character creates); existing `fq06_panel_opens_and_inspects` + `fq09s_constellation_links_match_prereqs` (purchase/inspection/star-map) stay green; HUD-QA `10_skill_panel`/`11_skill_panel_small` + shots `07_character_create` (1280x720) / `07b_character_create_small` (640x360) reviewed; suite 346/346. |
| PR-09 | code (deferred) | Later skill expansion | Only the Miner lane is live; six lanes are planned data. Expansion is data + panel scaling work that must wait for PR-08 and its own queue item. | `data/progression/perks.json`, `scripts/ui/skill_tree_panel.gd`, `scripts/main/game_root.gd` (`try_purchase_perk`) | Planning row only in this arc -- do not start; record lane order and effect-key readiness when scoped. |
| PR-10 | art | HUD chrome/image follow-up | Provisional chrome still shows padding, masking, and oversized opaque-region defects in some framed panel states and captures. This is image production through the studio contract -- not a code row. | `docs/wiki/hud_asset_replacement_studio.md`, `art/generated/ui_painted/` (19-asset kit), `hud_dock_layout.json` | Via image matrix: one contract-safe PNG at a time, hash-verified promotion, every open-panel combination inspected at target window sizes. |

Sequencing note: PR-00 (verification truth) should land before or alongside
any presentation fix, so every later row closes against a green suite. PR-01
and PR-04's rewrite half are explicitly **not started** in the PR-00 planning
tranche, per operator instruction.

## Terminology Contract (PR-01 landed 2026-07-20)

Body-variant terminology is migrated. The contract now in force:

1. **Canonical ids**: `masculine`, `feminine`. These are the only ids in
   `data/character_data.json` `body_variants` (display names "Masculine" /
   "Feminine") and `data/player_visuals.json`
   `body_variants`/`default_body_variant` (`masculine`).
2. **Legacy aliases**: `default -> masculine`, `female -> feminine`, held in
   the data-owned `player_visuals.json` `body_variant_aliases`.
   `BlockRegistry.normalize_body_variant` is the single alias authority —
   every caller (game_state, player, player_visual, shell UI, hud, smoke)
   routes through it, and invalid/missing values return the canonical default
   (`masculine`).
3. **Asset suffix map preserves existing filenames**: no PNG was renamed.
   `player_visuals.json` `body_variant_asset_suffix`
   (`masculine -> ""`, `feminine -> "_female"`) maps canonical ids to the
   existing `<species>` / `<species>_female` files; `player_body_id` and the
   wiki generator both resolve through it.
4. **New saves write canonical ids**: character creation normalizes to
   `masculine`/`feminine` on write.
5. **Legacy saves normalize on load**: `game_state` normalizes each stored
   `body_variant` on shell load and re-saves canonical; no save-version bump.

Validator enforcement: `scripts/validate_repo.py` requires the canonical id
lists plus the exact `body_variant_aliases` and `body_variant_asset_suffix`
maps, and derives player-body filenames through the suffix map. Smoke proves
the alias contract (`normalize_body_variant` of `default`/`female`/invalid ->
canonical), that a character created with the legacy `"female"` id re-saves
`"feminine"`, and that all ten bodies resolve for both canonical and legacy
inputs to the same `<species>`/`<species>_female` files while storing the
canonical id.

## Image-Production Follow-Up Matrix

Rows for a separate art-production lane (Codex/operator). No code-lane run
may produce these files. Every candidate goes through
`scripts/art/prepare_pixel_asset.py` normalization and
`scripts/art/verify_pixel_assets.py`, and HUD assets go through the studio's
hash-verified promotion.

| Asset ids | Target size | Current defect | Source/contract path | Acceptance checks |
|---|---|---|---|---|
| `sword_crude_<body_id>_swing_0..2`, `sword_iron_<body_id>_swing_0..2` for all ten body ids (60 PNGs) | 16x32 transparent | No authored sword attack sequence; combat uses code-drawn fallback motion | `data/player_visuals.json` tool-swing convention; `docs/ASSET_ROADMAP.md`; `art/generated/player_gear/` | Resolves per body/phase via `_tool_swing_texture`; pixel verifier green; cross-body alignment + facing screenshot review |
| Existing `pick_basic/pick_forged/axe_crude_<body_id>_swing_0..2` replacements (only where PR-04 diagnosis proves the PNG itself is misanchored) | 16x32 transparent | Hand anchors/arc continuity defects that code-side timing cannot fix | Same convention; PR-04 findings list the exact ids | Replaced ids re-verify; anchors land on the rig's shoulder/hand line; no regression on untouched ids |
| `helmet_iron_<body_id>`, `torso_iron_<body_id>`, `feet_iron_<body_id>` (30 PNGs) | 16x32 transparent | Iron armor equips with procedural fallback only (crude set is the only authored family) | `data/equipment.json` ids; gear convention in `data/player_visuals.json` | Resolves via `_gear_texture` body-specific path; pixel verifier green; layering respects the PR-02 compositing order |
| Crude *torso* consistency (`torso_crude_<non-human>`): the non-human crude torsos render as a waist/loincloth garment while the human crude torso is a chest vest. PR-03B fixed the helmet float in code (a `gear_offset`); the torso was left as-is because the low placement reads as a plausible primitive-armor style and the rig chest anchor does not cleanly apply. Only re-author if the operator wants a consistent chest garment across bodies. | 16x32 transparent | Style inconsistency (human chest vest vs non-human waist wrap), not a code-transform defect | `art/generated/player_gear/torso_crude_*`; `data/player_visuals.json` rig `torso` anchor | Re-authored torsos read consistently at the intended body zone; pixel verifier green; contact-sheet review across all ten bodies |
| HUD kit replacements (19 ids in `art/generated/ui_painted/` per the kit manifest, e.g. `dock_left_cap`, `dock_right_cap`, `dock_mid_tile`, `dock_center_block`, slot/button/vessel families) | native RGBA per `hud_dock_layout.json` geometry | Padding, masking, and oversized opaque-region defects in framed panel states and captures (PR-10) | `docs/wiki/hud_asset_replacement_studio.md` (one prompt per asset; safe promotion tool) | Hash-verified promotion; `sync_hud_kit.py --verify-runtime` green; every open-panel combination inspected at 640x360 and 1280x720 |
| Framed-panel chrome (`panel_frame_plain`, `panel_frame_ornate`, `chip_frame`, `corner_medallion`) | native RGBA | Same padding/mask family of defects on module frames | Same studio contract | Same as above, plus Map/Events/Crest/Goal open-combination review |

## Closeout Standard For Every Row

1. `python scripts/validate_repo.py`
2. `python scripts/asset_audit.py --strict` (when assets/data touched)
3. `python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo`
4. Waited-GUI Godot smoke with a freshness-checked `smoke_results.json`
5. Native-size screenshot review for any visual change
6. Update this matrix's row state, `docs/HANDOFF.md`, and the queue with the
   actual pass/fail evidence -- never aspirational numbers.
