# Coheronia Image Inventory Matrix

Generated: 2026-07-16

## Scope

- Audit target: this repository only.
- Wrapper-only and local working images outside the repository were excluded.
- `.import` sidecars were excluded; this report inventories authored image assets and screenshot/reference images.

## Headline Summary

- Runtime PNGs present in `art/generated/`: **399**
- Pixel-contract PNGs verified by `scripts/art/verify_pixel_assets.py`: **386** (large backgrounds/opening and contract-specific surfaces use their dedicated checks)
- Documentation screenshots present: **10**
- SVG icons/reference vectors present: **2**
- Validation status: `scripts/asset_audit.py --strict`, `scripts/art/verify_pixel_assets.py`, and `scripts/validate_repo.py` all passed on 2026-07-16.
- Immediate presentation need: harden gear-overlay refresh/alignment, refine tool/weapon swings, and replace provisional HUD chrome through its native kit contract. Gameplay-safe procedural and legacy fallbacks remain available.

## Category Matrix

| Category | Base ids present | PNG files present | Current status | Target size | Helpful note | Notes |
|---|---:|---:|---|---|---|---|
| blocks | 20 | 77 | Live and covered | 16x16 px | World tile; missing art falls back to generated block texture. |  |
| items | 81 | 81 | Current and planned-data icon set authored | 16x16 px | Inventory/drop icon; missing art falls back to generated swatch icon. |  |
| enemies | 6 | 24 | Live and covered | 16x16 px | Enemy sprite; missing art falls back to code-drawn hostile shape. |  |
| players | 10 | 30 | Live and covered | 16x32 px | Player body; appearance recolor and Look selector consume these pools. |  |
| player_gear | 60 naming bases | 120 | Partially authored and live | 16x32 px | 30 crude-armor statics + 90 three-phase pick/axe overlays; unresolved equipment falls back procedurally. |  |
| structures | 1 | 1 | Live and covered | 56x48 px | Town Hall structure sprite; missing art falls back to procedural hall rendering. |  |
| ui | 15 | 15 | 10 live, 5 placeholder-authored | 32x32 px | HUD / panel hooks; some are live, others are reserved placeholders. |  |
| ui_painted | 36 | 36 | Native 19-asset HUD kit live; older painted/sliced assets retained as fallbacks | mixed native RGBA | `hud_dock_layout.json` owns primary dock geometry; see the HUD Asset Replacement Studio. |  |
| opening | 8 | 10 | Eight authored scene pools live | 640 px wide | Scene 1 has three frames; the other seven have one; missing art falls back to plotted scenes. |  |
| backgrounds | 3 | 3 | Live and covered | 640 px wide | Backdrop layers; missing art falls back to code-drawn sky and silhouettes. |  |
| back_walls | 2 | 2 | Live and covered | 16x16 px | Natural backing-wall tile; missing art falls back to darkened block texture. |  |

## Runtime Inventory

| Category | Asset id | Present | Files on disk | Variant / frame status | Runtime consumer / fallback | Notes |
|---|---|---|---|---|---|---|
| blocks | berry_bush | Live | berry_bush.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | coal | Live | coal.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | copper_ore | Live | copper_ore.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | crop_ripe | Live | crop_ripe.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | crop_seedling | Live | crop_seedling.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | crystal | Live | crystal.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | dirt | Live | dirt.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | farm_soil | Live | farm_soil.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | grass | Live | grass.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | iron_ore | Live | iron_ore.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | lantern | Live | lantern.png | Canonical only | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | ore | Live | ore.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | silver_ore | Live | silver_ore.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | stone | Live | stone.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | tin_ore | Live | tin_ore.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | torch | Live | torch.png | Canonical only | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | town_hall_core | Live | town_hall_core.png | Canonical only | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | tree_leaves | Live | tree_leaves.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | tree_trunk | Live | tree_trunk.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| blocks | wood | Live | wood.png; 3 extra PNGs | 3 live variants | Consumed as terrain/block art; missing file would fall back to generated tile art. |  |
| items | armor | Live | armor.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | axe | Live | axe.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | berry_bush | Live | berry_bush.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | bronze_ingot | Live | bronze_ingot.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | chitin | Live | chitin.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | coal | Live | coal.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | coins | Live | coins.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | copper_ingot | Live | copper_ingot.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | copper_ore | Live | copper_ore.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | crop_ripe | Live | crop_ripe.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | crop_seedling | Live | crop_seedling.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | crop_seeds | Live | crop_seeds.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | crystal | Live | crystal.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | dirt | Live | dirt.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | eyes | Live | eyes.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | farm_soil | Live | farm_soil.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | food | Live | food.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | grass | Live | grass.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | hide_scrap | Live | hide_scrap.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | iron_ingot | Live | iron_ingot.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | iron_ore | Live | iron_ore.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | lantern | Live | lantern.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | meat | Live | meat.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | oil_rags | Live | oil_rags.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | ore | Live | ore.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | ore_flecks | Live | ore_flecks.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | pick | Live | pick.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | scrap_weapons | Live | scrap_weapons.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | shell | Live | shell.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | silk | Live | silk.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | silver_ingot | Live | silver_ingot.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | silver_ore | Live | silver_ore.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | slime_gel | Live | slime_gel.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | stone | Live | stone.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | sword | Live | sword.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | thorn_quill | Live | thorn_quill.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | tin_ingot | Live | tin_ingot.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | tin_ore | Live | tin_ore.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | tiny_core | Live | tiny_core.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | torch | Live | torch.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | torch_heads | Live | torch_heads.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | wet_fiber | Live | wet_fiber.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| items | wood | Live | wood.png | Canonical only | Consumed in inventory and drops; missing file would fall back to the generated icon surface. |  |
| enemies | cave_crawler | Live | cave_crawler.png; 3 extra PNGs | 3 live variants | Consumed by enemy renderer; missing file would fall back to code-drawn enemy art. |  |
| enemies | ore_tick | Live | ore_tick.png; 3 extra PNGs | 3 live variants | Consumed by enemy renderer; missing file would fall back to code-drawn enemy art. |  |
| enemies | raider_basic | Live | raider_basic.png; 3 extra PNGs | 3 live variants | Consumed by enemy renderer; missing file would fall back to code-drawn enemy art. |  |
| enemies | raider_torchbearer | Live | raider_torchbearer.png; 3 extra PNGs | 3 live variants | Consumed by enemy renderer; missing file would fall back to code-drawn enemy art. |  |
| enemies | surface_slime | Live | surface_slime.png; 3 extra PNGs | 3 live variants | Consumed by enemy renderer; missing file would fall back to code-drawn enemy art. |  |
| enemies | thornrat | Live | thornrat.png; 3 extra PNGs | 3 live variants | Consumed by enemy renderer; missing file would fall back to code-drawn enemy art. |  |
| players | dwarf | Live | dwarf.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| players | dwarf_female | Live | dwarf_female.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| players | elf | Live | elf.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| players | elf_female | Live | elf_female.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| players | goblin | Live | goblin.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| players | goblin_female | Live | goblin_female.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| players | human | Live | human.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| players | human_female | Live | human_female.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| players | orc | Live | orc.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| players | orc_female | Live | orc_female.png; 2 extra PNGs | 2 live variants | Consumed by player visual system; appearance recolor and Look selector use the canonical body plus variants. |  |
| structures | town_hall | Live | town_hall.png | Canonical only | Consumed by Town Hall rendering; missing file would fall back to the procedural hall. |  |
| ui | button_character | Live | button_character.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| ui | button_goals | Placeholder-authored | button_goals.png | Canonical only | Authored and validated, but currently reserved rather than required by active UI flow. |  |
| ui | button_inventory | Live | button_inventory.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| ui | button_settings | Placeholder-authored | button_settings.png | Canonical only | Authored and validated, but currently reserved rather than required by active UI flow. |  |
| ui | button_skills | Live | button_skills.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| ui | button_town_hall | Live | button_town_hall.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| ui | cursor_drag_invalid | Placeholder-authored | cursor_drag_invalid.png | Canonical only | Authored and validated, but currently reserved rather than required by active UI flow. |  |
| ui | cursor_drag_valid | Placeholder-authored | cursor_drag_valid.png | Canonical only | Authored and validated, but currently reserved rather than required by active UI flow. |  |
| ui | dock_backplate | Live | dock_backplate.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| ui | orb_attunement_frame | Live | orb_attunement_frame.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| ui | orb_fill_mask | Live | orb_fill_mask.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| ui | orb_health_frame | Live | orb_health_frame.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| ui | slot_inventory | Live | slot_inventory.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| ui | slot_inventory_invalid | Placeholder-authored | slot_inventory_invalid.png | Canonical only | Authored and validated, but currently reserved rather than required by active UI flow. |  |
| ui | slot_inventory_selected | Live | slot_inventory_selected.png | Canonical only | Consumed by live HUD/panel hooks. |  |
| backgrounds | surface_far_terrain | Live | surface_far_terrain.png | Canonical only | Consumed by `world_backdrop.gd`; missing file would fall back to code-drawn sky/silhouettes. |  |
| backgrounds | surface_mid_silhouette | Live | surface_mid_silhouette.png | Canonical only | Consumed by `world_backdrop.gd`; missing file would fall back to code-drawn sky/silhouettes. |  |
| backgrounds | surface_sky | Live | surface_sky.png | Canonical only | Consumed by `world_backdrop.gd`; missing file would fall back to code-drawn sky/silhouettes. |  |
| back_walls | dirt_wall | Live | dirt_wall.png | Canonical only | Consumed by backing-wall texture hook; missing file would fall back to darkened block texture. |  |
| back_walls | stone_wall | Live | stone_wall.png | Canonical only | Consumed by backing-wall texture hook; missing file would fall back to darkened block texture. |  |

## Still To Create / Deferred Work

| Surface | Id / convention | Current state | When it matters | Size / shape | Helpful note | Notes |
|---|---|---|---|---|---|---|
| player_gear | uncovered `<item_id>_<body_id>.png` | Crude helmet/torso/feet are authored across ten bodies; swords, iron armor, rings, amulet, and accessory remain procedural | When an uncovered equipment family is approved | 16x32 transparent | Validate each body and transition; do not overwrite current families casually. |  |
| player_gear | `<tool_id>_<body_id>_swing_<phase>.png` | Basic/forged pick and crude axe cover phases 0/1/2 across ten bodies; sword sequence absent | Motion/alignment polish or approved weapon expansion | 16x32 transparent | Current known issue is stepped motion and intermittent resolution/alignment, not an empty directory. |  |
| opening | `opening_<scene_id>_NN.png` | Eight scene pools / ten PNGs present; plotted fallback live | Approved animation or scene-variant expansion | 640x360 | Wordless only; engine owns all text overlays. |  |
| backgrounds | cave_far | Planned only; no file yet | When cave backdrop wiring expands beyond current surface layers | 640 px wide scenic layer | Not an immediate gap; roadmap marks this as future environment art. |  |
| backgrounds | deep_cavern_far | Planned only; no file yet | When deep-cavern backdrop wiring lands | 640 px wide scenic layer | Not an immediate gap; roadmap marks this as future environment art. |  |
| back_walls | ore_cave_wall | Planned only; no file yet | When ore-cave environment visuals are scoped | 16x16 seamless opaque tile | Future wall family, not a broken current asset. |  |
| back_walls | fungal_wall | Planned only; no file yet | When fungal environment visuals are scoped | 16x16 seamless opaque tile | Future wall family, not a broken current asset. |  |
| back_walls | crystal_wall | Planned only; no file yet | When crystal environment visuals are scoped | 16x16 seamless opaque tile | Future wall family, not a broken current asset. |  |
| back_walls | timber_wall | Planned only; no file yet | When constructed/interior wall visuals are scoped | 16x16 seamless opaque tile | Future wall family, not a broken current asset. |  |
| future systems | workbench, furnace, anvil | Planned only; do not create early | With FQ-11 station art | 16x16 blocks or possible multi-tile | Roadmap explicitly says not to produce these before their systems are live unless requested. |  |
| future systems | ash_wasp, mudling, hollow_stag, lantern_leech, stoneback_beetle, sporekin, burrow_maw, raider_sapper, hungry_deserter, false_taxman, hollow_king, world_worm | Planned only; do not create early | Later enemy waves | 16x16+ | These are roadmap/planned enemies, not missing live runtime sprites. |  |
| future systems | mining/chop arc, placement pulse, hurt/collapse feedback, forge confirmation | Planned only; do not create early | With the scoped action-FX art pass | Small transparent overlays | Effects are still listed as future action art. |  |
| future systems | deep_dwarf, deep_elf, deep_goblin, gnome, deep_gnome, lizardfolk, dragonkin types | Planned only; do not create early | Phase C-E ancestry expansion | 16x32 | Current five live species are fully covered; these are later-phase ancestry bodies. |  |
| future systems | goals/map glyphs and reserved HUD replacements | Partially placeholder-authored; full replacement art deferred | When those UI consumers become active | 32x32 | Several UI hooks already exist as authored placeholders, but they are not urgent missing art. |  |

## Non-Runtime / Reference Images Present

| Path | Type | Present | Purpose | Helpful note | Notes |
|---|---|---|---|---|---|
| icon.svg | Repo icon | Yes | Project root icon asset | Vector, not part of `art/generated`. |  |
| reference/g1v5/icon.svg | Reference icon | Yes | Reference copy under `reference/` | Reference/supporting asset rather than gameplay art. |  |
| docs/screenshots/01_settlement_day.png | Screenshot | Yes | README / documentation capture | Documentation-only image. |  |
| docs/screenshots/02_night_torchlight.png | Screenshot | Yes | README / documentation capture | Documentation-only image. |  |
| docs/screenshots/03_inventory.png | Screenshot | Yes | README / documentation capture | Documentation-only image. |  |
| docs/screenshots/04_town_hall.png | Screenshot | Yes | README / documentation capture | Documentation-only image. |  |
| docs/screenshots/05_skill_tree.png | Screenshot | Yes | README / documentation capture | Documentation-only image. |  |
| docs/screenshots/06_shell_title.png | Screenshot | Yes | README / documentation capture | Documentation-only image. |  |
| docs/screenshots/07_character_create.png | Screenshot | Yes | README / documentation capture | Documentation-only image. |  |
| docs/screenshots/08_world_create.png | Screenshot | Yes | README / documentation capture | Documentation-only image. |  |
| docs/screenshots/09_underground_midday_torch.png | Screenshot | Yes | README / documentation capture | Documentation-only image. |  |
| docs/screenshots/10_vessel_damage_states.png | Screenshot | Yes | README / HUD runtime-state capture | Documentation-only image. |  |

## Notes

- 
- 
- 
