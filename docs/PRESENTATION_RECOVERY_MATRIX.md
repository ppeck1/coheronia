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
| PR-05 | code | Menu and character-selection preview | Creation/selection UI does not present the composed live character through the same rendering path the world uses, so what you pick and what you get can diverge. | `scripts/shell/shell_ui.gd`, `scripts/player/player_visual.gd` (reuse, not reimplement), PR-02 contract | The creation/selection preview renders through the shared path; snapshot-compare proves preview == in-world result for identical inputs; smoke covered. |
| PR-06 | code + art | Character HUD rebuild | The Character panel/HUD presentation of the player (summary, equipment, composed look) predates the native HUD kit and the gear-overlay program. Code lane: rebuild on runtime children + PR-02 contract with existing chrome. Art lane: any new chrome PNGs (image matrix). | `scripts/ui/hud.gd` Character panel, `art/generated/ui_painted/` kit + `hud_dock_layout.json` geometry authority, `docs/wiki/hud_asset_replacement_studio.md` | Panel shows the composed character + all 13 slots from runtime state; no baked values; fallbacks intact; smoke + screenshot review. |
| PR-07 | code | Backdrop seam/contour skirt | `world_backdrop.gd` anchors the painted horizon to the AVERAGE surface line; terrain above/below the mean meets the backdrop at a visible seam. Goal: a contour skirt that follows the per-column surface so no seam or void shows at any camera position. | `scripts/world/world_backdrop.gd` (`_horizon_py`/`_under_py`, `_draw`, `_strip`), `world.surface` | No visible seam at valley floors or peaks in screenshot review; parallax stability preserved; `light_mask = 0` and no-save/no-collision guarantees unchanged. |
| PR-08 | code | Skill panel resize | `skill_tree_panel.gd` is fixed at 540x420 with a 500x180 scroll canvas -- cramped at 1280x720 and unable to grow with lane expansion. | `scripts/ui/skill_tree_panel.gd` (`_ready` anchors/offsets, `NODE_SIZE`/`SPACING`) | Viewport-relative sizing at 640x360 and 1280x720; existing purchase/persistence/inspection smoke green; star-map treatment preserved. |
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
