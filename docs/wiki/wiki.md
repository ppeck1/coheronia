# Coheronia Wiki

Generated: 2026-07-16

## Scope

- Audit target: the Coheronia inner repository only.
- Canonical wiki source: `docs/wiki/wiki.md`.
- Visual wrapper: `docs/wiki/index.html`.
- Generated from current runtime data where possible: `data/items.json`, `data/equipment.json`, `data/recipes.json`, `data/blocks.json`, `data/enemies.json`, `data/character_data.json`, `data/visual_assets.json`, plus the live consumers in `scripts/world/block_registry.gd`, `scripts/settlement/town_hall.gd`, `scripts/player/player.gd`, and `scripts/ui/hud.gd`.
- Manual notes are used only for proposed or future behavior such as recommended new sinks.

## Publication Metadata

| Field | Value |
|---|---|
| Generated | 2026-07-16 |
| Source state | Public documentation refresh after native HUD-kit, authored gear-overlay, and opening-cel integration. |
| Base repo commit | `250a677` before this publication refresh. |
| Publication branch | `agent/update-public-docs-hud` |
| Validator | PASS on 2026-07-16; see publication handoff for the final command set. |
| Wiki link check | PASS on 2026-07-16 local recursive Markdown/HTML target check. |

This wiki is generated from current Coheronia repo data and includes live, internal, and planned-data references. Planned-data pages are not live gameplay unless marked as live.

## Purpose

- Track what exists now.
- Track where each thing lives at runtime.
- Track whether it is actually player-facing.
- Track what has a real sink versus what is only a source today.
- Track which surfaces have authored images, placeholder art, or code fallbacks.
- Support planning and maintenance rather than player-facing lore.

## Wiki Home Structure

| Section | What it answers | Planning use |
|---|---|---|
| Runtime image and placeholder rules | What image surfaces exist and how fallback behaves | Prevents false "missing art" reports and keeps placeholder surfaces explicit |
| Core resources, processed materials, farming, enemy drops | What items exist, where they live, and whether they matter today | Tracks sink coverage and dead ends |
| Equipment | What gear exists, how it is acquired, and which authored overlays currently ship | Tracks equip-path clarity, current visual coverage, and remaining gaps |
| Source-only, dead, and internal tokens | What should not be mistaken for real backpack items | Prevents maintenance drift and data confusion |
| Enemy chance tables | What enemies currently drop | Keeps balance and source-planning visible |
| Recipe routing reference | What crafting routes exist and where results go | Prevents recipe/data/code drift |
| First-class recipe pages | Station, inputs, raw outputs, result route, and actual result in play | Makes crafting continuity reviewable without digging through station pages |
| Status browser pages | Current-live, planned-data, dead, source-only, and internal slices | Keeps current reference separate from future planning |
| Visual surface index | What art families are covered versus deferred | Tracks image coverage at the system level |
| Rendered item graph | What the current source-to-craft-to-equipment flow looks like | Gives reviewers a real graph instead of raw graph source in static viewers |
| Skills | What perk lanes are live, planned, or groundwork only | Makes the skill-system work queue visible without implying planned lanes are shipped |
| Planned-only data hooks | What is referenced but not implemented | Makes future work visible without pretending it is live |
| Current maintenance priorities | What still needs attention | Turns the page into a live planning surface |

## Image Coverage Dashboard

| Surface family | Live coverage now | Placeholder or fallback used now | Missing or deferred images | Maintenance note |
|---|---|---|---|---|
| Item icons | Fully covered for all 43 current item ids via `art/generated/items/<id>.png` | Generated 16x16 swatch fallback still exists in `BlockRegistry.item_icon()` | none for current live item ids | Item icons are canonical-only by design; this is stable, not incomplete. |
| Block/world art | Covered for current live blocks | Generated block-texture fallback exists | no live blockers | Variant pools are already live for many blocks. |
| Enemy sprites | Covered for all 6 live enemies | Code-drawn hostile fallback exists | only planned enemy families | No live enemy image gap right now. |
| Equipment icons | No dedicated live backpack-style equipment icon family in use | Text-only equipment panels and procedural equipped visuals | still deferred by design | This is intentionally not the same thing as item-icon coverage. |
| Player gear overlays | 120 authored body-specific PNGs: crude helmet/torso/feet plus three-phase basic-pick, forged-pick, and crude-axe swings across ten bodies | Generic/rig-aware procedural presentation remains for uncovered or unresolved equipment | swords, iron armor, rings, amulet, accessory, plus alignment/refresh hardening | Current coverage is substantial but an intermittent load/refresh presentation defect remains. |
| UI art | Primary 19-asset native HUD kit is live under `art/generated/ui_painted/`; legacy reserved hooks also remain | FQ-21 sliced band, FQ-19 modular construction, and code styles are fallback paths | final polish for primary chrome and framed panels | Runtime values/states remain separate from PNGs by contract. |
| Opening scenes | Eight authored scene pools / ten PNGs are live | Deterministic plotted prologue remains the resilience fallback | optional approved animation/variant expansion | Scene 1 has three frames; the other seven currently use one authored cel each. |
| Backgrounds and back walls | Covered for current live surfaces | Code-drawn sky / silhouette and darkened wall fallback exists | cave/deep-cave families still future | No current maintenance blocker. |

## Status Legend

| Field | Meaning |
|---|---|
| Storage | Where the thing actually lives now: inventory, stockpile, equipment slot, world block, UI surrogate icon, or internal token. |
| Player-facing? | `Yes`, `No`, `World-only`, or `UI-only`. This prevents world-state metadata from being mistaken for backpack items. |
| Sink status | `complete` = live source and live downstream use; `source-only` = live source but no meaningful downstream sink yet; `dead` = defined but not obtainable now; `planned` = referenced only by planned systems; `internal` = runtime token, not a real player item. |
| Image ref | The authored runtime image convention or file family currently used. |
| Placeholder / fallback | What the engine shows when authored art is absent. |

## Wiki Map

- Generated category pages now live under `docs/wiki/`:
  - `items.md`
  - `equipment.md`
  - `weapons.md`
  - `blocks.md`
  - `bestiary.md`
  - `character_types.md`
  - `stations.md`
  - `recipes.md`
  - `status_browser.md`
  - `current_live.md`
  - `planned_data.md`
  - `internal_tokens.md`
  - `item_graph.md`
  - `skills.md`
  - `image_continuation.md`
  - `hud_asset_replacement_studio.md`
  - `known_issues.md`
- Generated leaf pages now live under:
  - `docs/wiki/items/`
  - `docs/wiki/equipment/`
  - `docs/wiki/blocks/`
  - `docs/wiki/enemies/`
  - `docs/wiki/characters/`
  - `docs/wiki/stations/`
  - `docs/wiki/recipes/`
- [ITEM_AND_RECIPE_MATRIX.md](../ITEM_AND_RECIPE_MATRIX.md) is the strict inventory/recipe audit.
- [Item Graph](item_graph.md) is the rendered wiki-local acquisition and crafting graph.
- [Skills](skills.md) is the skill tree status and future-work planning page.
- [ITEM_GRAPH.md](../ITEM_GRAPH.md) is the strict acquisition and crafting graph audit.
- [IMAGE_INVENTORY_MATRIX.md](../IMAGE_INVENTORY_MATRIX.md) is the full runtime image inventory.
- [Image Continuation](image_continuation.md) is the wiki handoff page for future image work and public/IP-safety checks.
- [HUD Asset Replacement Studio](hud_asset_replacement_studio.md) is the drop-in HUD template contract with a ready-to-paste ChatGPT instruction for every dock asset.
- [Known Issues](known_issues.md) separates active presentation defects from intentional scope limits.
- This page is the readable maintenance layer above those audits.

## Runtime Image And Placeholder Rules

| Surface | Current authored path | Current state | Placeholder / fallback behavior | Why it matters |
|---|---|---|---|---|
| Inventory and drop icons | `art/generated/items/<id>.png` | All 43 current item ids have canonical 16x16 PNGs | `BlockRegistry.item_icon()` falls back to a generated 16x16 swatch from `data/items.json` color, or a stable hash-derived hue for unknown ids | Missing item art is not a runtime break, but the fallback should be treated as temporary unless the surface is intentionally abstract. |
| Block/world art | `art/generated/blocks/<id>.png` plus optional `_01.._03` variants | Live and covered | Falls back to generated block texture | Helps separate world blocks from inventory items. |
| Enemy sprites | `art/generated/enemies/<id>.png` plus optional `_01.._03` variants | Live and covered | Falls back to code-drawn hostile shapes | Live enemies are visually safe even if art regresses. |
| Equipment item icons | no live 16x16 dedicated equipment icon family in use | Deferred | Equipment panels stay text-based | Important because equipment ids should not be assumed to have backpack-style icons. |
| Player gear overlays | `art/generated/player_gear/<item_id>_<body_id>.png` and `<tool_id>_<body_id>_swing_<phase>.png` | 120 body-specific crude-armor/tool PNGs live | Body-specific -> generic -> rig-aware procedural fallback | Current unresolved ids and intermittent refresh/alignment are tracked on Known Issues. |
| Primary HUD kit | authored `art/source_templates/hud_dock/` -> runtime `art/generated/ui_painted/` | 19 required native RGBA layers plus `hud_dock_layout.json` live | FQ-21 sliced band -> FQ-19 modular dock -> code styles | Use the HUD Asset Replacement Studio; do not regenerate assembled mockup slices. |
| Legacy UI hooks | `art/generated/ui/<id>.png` | 10 live, 5 deliberate placeholders | Code styles or text where supported | Retained for fallback/reserved consumers rather than primary dock authoring. |
| Opening scenes | `art/generated/opening/<scene_id>_01.png`... | Eight pools / ten PNGs live | Falls back to plotted prologue scenes | Authored cels are preferred without removing deterministic fallback. |

## Core Resource And Progression Items

| Item | Storage | Player-facing? | Current source | Current gameplay use | System role | Sink status | Recommended next sink | Image ref | Placeholder / fallback | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| `dirt` | inventory; stockpile input; world block | Yes | Homesteader start; drops from `dirt`, `grass`, `farm_soil` | Placeable terrain and Town Hall stockpile material | building | complete | none required now | `items/dirt.png` | generated swatch if icon missing | Also resolves two world-state items into a real inventory item. |
| `wood` | inventory; stockpile input; world block | Yes | Homesteader start; drops from `wood`, `tree_trunk` | Torch craft, Town Hall crafting, station build | building; fuel; progression | complete | none required now | `items/wood.png` | generated swatch if icon missing | Preferred gather tool on source blocks is `axe`. |
| `stone` | inventory; stockpile input; world block | Yes | Prospector start; drop from `stone` | Torch craft, Town Hall crafting, station build | building; progression | complete | none required now | `items/stone.png` | generated swatch if icon missing | Requires pick tier 1. |
| `coal` | inventory; stockpile input | Yes | Drop from `coal` | Furnace fuel, torch bundle, station build | metallurgy; fuel | complete | none required now | `items/coal.png` | generated swatch if icon missing | Requires pick tier 1. |
| `ore` | inventory; stockpile input | Yes | Drop from `ore` | Lantern craft | progression; light | complete | proposed: civic metalwork or advanced lantern branch | `items/ore.png` | generated swatch if icon missing | Requires pick tier 2. |
| `copper_ore` | inventory; stockpile input | Yes | Drop from `copper_ore` | `smelt_copper` | metallurgy | complete | none required now | `items/copper_ore.png` | generated swatch if icon missing | Requires pick tier 1. |
| `tin_ore` | inventory; stockpile input | Yes | Drop from `tin_ore` | `smelt_tin` | metallurgy | complete | none required now | `items/tin_ore.png` | generated swatch if icon missing | Requires pick tier 1. |
| `iron_ore` | inventory; stockpile input | Yes | Drop from `iron_ore` | `smelt_iron` | metallurgy; combat progression | complete | none required now | `items/iron_ore.png` | generated swatch if icon missing | Requires pick tier 2. |
| `silver_ore` | inventory; stockpile input | Yes | Drop from `silver_ore` | `smelt_silver` | metallurgy; future attunement/economy hook | complete | proposed: silver-only civic or attunement branch | `items/silver_ore.png` | generated swatch if icon missing | Requires pick tier 2. |
| `crystal` | inventory; stockpile input | Yes | Drop from `crystal` | none now | attunement; future magic hook | source-only | proposed: amulet, beacon, pulse catalyst | `items/crystal.png` | generated swatch if icon missing | Live source with no real sink yet. |

## Processed Materials

| Item | Storage | Player-facing? | Current source | Current gameplay use | System role | Sink status | Recommended next sink | Image ref | Placeholder / fallback | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| `copper_ingot` | stockpile | Yes | `smelt_copper` | `alloy_bronze` | metallurgy | complete | none required now | `items/copper_ingot.png` | generated swatch if icon missing | Does not currently route through backpack inventory. |
| `tin_ingot` | stockpile | Yes | `smelt_tin` | `alloy_bronze` | metallurgy | complete | none required now | `items/tin_ingot.png` | generated swatch if icon missing | Does not currently route through backpack inventory. |
| `iron_ingot` | stockpile | Yes | `smelt_iron` | `anvil` build, iron sword, iron armor | metallurgy; combat | complete | none required now | `items/iron_ingot.png` | generated swatch if icon missing | Current top-tier live metal sink. |
| `silver_ingot` | stockpile | Yes | `smelt_silver` | none now | metallurgy; future economy/attunement hook | source-only | proposed: amulet, coinage, ritual civic item | `items/silver_ingot.png` | generated swatch if icon missing | Live output with no downstream recipe. |
| `bronze_ingot` | stockpile | Yes | `alloy_bronze` | none now | metallurgy; future tools/economy hook | source-only | proposed: ring, tools, civic item | `items/bronze_ingot.png` | generated swatch if icon missing | Live alloy output with no downstream recipe. |

## Farming, Food, And Light

| Item | Storage | Player-facing? | Current source | Current gameplay use | System role | Sink status | Recommended next sink | Image ref | Placeholder / fallback | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| `crop_seeds` | inventory | Yes | Drops from `crop_seedling`, `crop_ripe`; `craft_seeds` | Planting | farming | complete | none required now | `items/crop_seeds.png` | generated swatch if icon missing | The real carried seed item. |
| `food` | inventory; stockpile input | Yes | Drops from `crop_ripe`, `berry_bush` | Eat for healing; convert to seeds | food; farming | complete | proposed: cooked food branch or feast sink | `items/food.png` | generated swatch if icon missing | Important live sustain loop. |
| `torch` | inventory; world block | Yes | Prospector start; drop from torch block; `craft_torch`; `workbench_torch_bundle` | Placeable light | light; exploration | complete | none required now | `items/torch.png` | generated swatch if icon missing | World block emits radius 96. |
| `lantern` | inventory; world block | Yes | Drop from lantern block; `craft_lantern` | Placeable strong light | light; settlement safety | complete | proposed: upgraded lantern branch | `items/lantern.png` | generated swatch if icon missing | World block emits radius 160. |

## Live Enemy Drop Materials

| Item | Storage | Player-facing? | Current source | Current gameplay use | System role | Sink status | Recommended next sink | Image ref | Placeholder / fallback | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| `slime_gel` | inventory | Yes | Surface Slime 70% | none now | combat drop; future crafting | source-only | proposed: adhesive, torch gel, weak healing | `items/slime_gel.png` | generated swatch if icon missing | Good early candidate for a first low-tier alchemy sink. |
| `wet_fiber` | inventory | Yes | Surface Slime 25% | none now | combat drop; future crafting | source-only | proposed: rope, bandage, thatch mix | `items/wet_fiber.png` | generated swatch if icon missing | Could bridge surface enemies into utility craft. |
| `tiny_core` | inventory | Yes | Surface Slime 5% | none now | rare drop; future attunement | source-only | proposed: Focus Amulet or attunement reagent | `items/tiny_core.png` | generated swatch if icon missing | Rare enough to support a meaningful future magic sink. |
| `meat` | inventory | Yes | Thornrat 65% | none now | food; combat drop | source-only | proposed: prepare into food | `items/meat.png` | generated swatch if icon missing | Currently not edible through a dedicated meat system. |
| `thorn_quill` | inventory | Yes | Thornrat 30% | none now | combat drop; future ranged/trap hook | source-only | proposed: darts, spikes, trap ammo | `items/thorn_quill.png` | generated swatch if icon missing | Natural fit for light combat crafting. |
| `hide_scrap` | inventory | Yes | Thornrat 5% | none now | combat drop; future armor hook | source-only | proposed: leather strips, light armor | `items/hide_scrap.png` | generated swatch if icon missing | Rare enough to stay valuable if armor sinks arrive. |
| `chitin` | inventory | Yes | Cave Crawler 65% | none now | combat drop; future armor hook | source-only | proposed: chitin armor, shield plates | `items/chitin.png` | generated swatch if icon missing | Good underground gear-material candidate. |
| `silk` | inventory | Yes | Cave Crawler 30% | none now | combat drop; future cloth/attunement hook | source-only | proposed: bandage, cloth, attunement wrap | `items/silk.png` | generated swatch if icon missing | Could bridge caves to support and magic systems. |
| `eyes` | inventory | Yes | Cave Crawler 5% | none now | rare drop; future attunement hook | source-only | proposed: tracking charm, pulse reagent | `items/eyes.png` | generated swatch if icon missing | Rare monster-organ sink candidate. |
| `ore_flecks` | inventory | Yes | Ore Tick 70% | none now | metallurgy salvage hook | source-only | proposed: salvage into trace metals | `items/ore_flecks.png` | generated swatch if icon missing | Helps ore enemies feed progression if given a refinery sink. |
| `shell` | inventory | Yes | Ore Tick 30% | none now | combat drop; future armor/decor hook | source-only | proposed: shield trim, civic decor | `items/shell.png` | generated swatch if icon missing | Visually strong but currently inert. |
| `coins` | inventory | Yes | Raider Basic 75% | none now | economy hook | source-only | proposed: trader, tax, settlement economy | `items/coins.png` | generated swatch if icon missing | A natural future economy sink. |
| `scrap_weapons` | inventory | Yes | Raider Basic 40% | none now | combat salvage hook | source-only | proposed: salvage into iron | `items/scrap_weapons.png` | generated swatch if icon missing | Strong candidate for metallurgy loop closure. |
| `oil_rags` | inventory | Yes | Raider Torchbearer 60% | none now | fire/light hook | source-only | proposed: lantern fuel, torch gel, fire trap | `items/oil_rags.png` | generated swatch if icon missing | Strong overlap with light and combat systems. |
| `torch_heads` | inventory | Yes | Raider Torchbearer 40% | none now | fire/light hook | source-only | proposed: upgraded torch craft, fire trap | `items/torch_heads.png` | generated swatch if icon missing | Natural paired sink with oil rags. |

## Equipment

| Item | Storage | Player-facing? | Current source | Current gameplay use | System role | Sink status | Recommended next sink | Image ref | Placeholder / fallback | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| `pick_basic` | equipment slot | Yes | Default character gear | Entry mining tool | mining progression | complete | refine swing continuity | 30 body/phase swing overlays; no dedicated equipment icon | procedural fallback if a matching overlay cannot resolve | Three phases across all ten current bodies; intermittent refresh/alignment remains under review. |
| `pick_forged` | equipment slot | Yes | `basic_pick_upgrade` | Tier-2 mining | mining progression | complete | refine swing continuity | 30 body/phase swing overlays; no dedicated equipment icon | procedural fallback if a matching overlay cannot resolve | Player-facing Town Hall upgrade; three phases across all ten bodies. |
| `axe_crude` | equipment slot | Yes | `craft_axe` | Wood and plant harvesting | gathering progression | complete | refine swing continuity | 30 body/phase swing overlays; no dedicated equipment icon | procedural fallback if a matching overlay cannot resolve | Three phases across all ten bodies. |
| `sword_crude` | equipment slot | Yes | `craft_sword` | Early combat weapon | combat progression | complete | none required now | no dedicated equipment icon; no `player_gear` overlay yet | procedural equipped presentation | Direct-equip Town Hall weapon. |
| `helmet_crude` | equipment slot | Yes | `craft_armor_set` | Early armor | combat progression | complete | harden load/refresh alignment | 10 body-specific static overlays; no dedicated equipment icon | procedural fallback if a matching overlay cannot resolve | One authored overlay for each current body id. |
| `torso_crude` | equipment slot | Yes | `craft_armor_set` | Early armor | combat progression | complete | harden load/refresh alignment | 10 body-specific static overlays; no dedicated equipment icon | procedural fallback if a matching overlay cannot resolve | One authored overlay for each current body id. |
| `feet_crude` | equipment slot | Yes | `craft_armor_set` | Early armor | combat progression | complete | harden load/refresh alignment | 10 body-specific static overlays; no dedicated equipment icon | procedural fallback if a matching overlay cannot resolve | One authored overlay for each current body id. |
| `sword_iron` | equipment slot | Yes | `anvil_iron_sword` | Better combat weapon | combat progression | complete | none required now | no dedicated equipment icon; no `player_gear` overlay yet | procedural equipped presentation | Current best live weapon. |
| `helmet_iron` | equipment slot | Yes | `anvil_iron_armor` | Better armor | combat progression | complete | none required now | no dedicated equipment icon; no `player_gear` overlay yet | procedural equipped presentation | Current best live helm. |
| `torso_iron` | equipment slot | Yes | `anvil_iron_armor` | Better armor | combat progression | complete | none required now | no dedicated equipment icon; no `player_gear` overlay yet | procedural equipped presentation | Current best live torso armor. |
| `feet_iron` | equipment slot | Yes | `anvil_iron_armor` | Better armor | combat progression | complete | none required now | no dedicated equipment icon; no `player_gear` overlay yet | procedural equipped presentation | Current best live boots. |
| `ring_band` | equipment definition only | No | none | none now | future economy/accessory hook | dead | proposed: bronze/silver ring base item | no live consumer; no art required yet | no acquisition path | Defined but not obtainable. |
| `amulet_focus` | equipment definition only | No | none | none now | future attunement hook | dead | proposed: silver + crystal + tiny core sink | no live consumer; no art required yet | no acquisition path | Defined but not obtainable. |

## Source-Only, Dead, And Internal Tokens

| Id | Storage | Player-facing? | Current source | Current gameplay use | System role | Sink status | Recommended next sink | Image ref | Placeholder / fallback | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| `grass` | world block metadata; item metadata | World-only | grass world block | none as carried item | world-state surface | source-only | none; keep as world-only unless block pickup becomes a feature | `items/grass.png`; `blocks/grass.png` | item icon fallback swatch if art missing | Harvest resolves to `dirt`, not `grass`. |
| `farm_soil` | world block metadata; item metadata | World-only | tilled soil world block | none as carried item | farming world-state | source-only | none; keep as world-only unless shovel/soil pickup lands | `items/farm_soil.png`; `blocks/farm_soil.png` | item icon fallback swatch if art missing | Harvest resolves to `dirt`. |
| `crop_seedling` | world block metadata; item metadata | World-only | growing crop block | none as carried item | farming world-state | source-only | none; keep as world-only unless transplanting is added | `items/crop_seedling.png`; `blocks/crop_seedling.png` | item icon fallback swatch if art missing | Harvest resolves to `crop_seeds`. |
| `crop_ripe` | world block metadata; item metadata | World-only | ripe crop block | none as carried item | farming world-state | source-only | none; keep as world-only unless produce pickup is added | `items/crop_ripe.png`; `blocks/crop_ripe.png` | item icon fallback swatch if art missing | Harvest resolves to `food` and `crop_seeds`. |
| `berry_bush` | world block metadata; item metadata | World-only | berry bush block | none as carried item | world-state food source | source-only | none; keep as world-only unless bush pickup is added | `items/berry_bush.png`; `blocks/berry_bush.png` | item icon fallback swatch if art missing | Harvest resolves to `food`. |
| `pick` | UI surrogate icon | UI-only | `items.json` metadata and `art/generated/items/pick.png` | Town Hall forge button icon | UI surrogate for equipment | source-only | none; this should remain a surrogate, not a real gear item | `items/pick.png` | generated swatch if icon missing | Not the same thing as `pick_basic` or `pick_forged`. |
| `axe` | UI surrogate icon | UI-only | `items.json` metadata and `art/generated/items/axe.png` | Town Hall forge button icon | UI surrogate for equipment | source-only | none; this should remain a surrogate, not a real gear item | `items/axe.png` | generated swatch if icon missing | Not the same thing as `axe_crude`. |
| `sword` | UI surrogate icon | UI-only | `items.json` metadata and `art/generated/items/sword.png` | Town Hall forge button icon | UI surrogate for equipment | source-only | none; this should remain a surrogate, not a real gear item | `items/sword.png` | generated swatch if icon missing | Not the same thing as `sword_crude` or `sword_iron`. |
| `armor` | UI surrogate icon | UI-only | `items.json` metadata and `art/generated/items/armor.png` | Town Hall forge button icon | UI surrogate for equipment | source-only | none; this should remain a surrogate, not a real gear item | `items/armor.png` | generated swatch if icon missing | Not the same thing as actual armor-piece ids. |
| `tool_tier_2_pick` | internal recipe token | No | Raw output token in `basic_pick_upgrade` | none directly | internal bridge token | internal | none; ideally stay invisible or be normalized away in future cleanup | no image needed | no player-facing surface | The real gameplay result is `pick_forged`. |

## Live Enemy Chance Tables

| Enemy | Drop chances now | Why it matters now | Image ref | Placeholder / fallback |
|---|---|---|---|---|
| Surface Slime | `slime_gel 70%`, `wet_fiber 25%`, `tiny_core 5%` | Earliest source of future utility and attunement materials | `enemies/surface_slime.png` plus variants | code-drawn hostile shape if art missing |
| Thornrat | `meat 65%`, `thorn_quill 30%`, `hide_scrap 5%` | Earliest farm-pressure enemy; obvious future food/leather sink source | `enemies/thornrat.png` plus variants | code-drawn hostile shape if art missing |
| Cave Crawler | `chitin 65%`, `silk 30%`, `eyes 5%` | Earliest underground material loop | `enemies/cave_crawler.png` plus variants | code-drawn hostile shape if art missing |
| Ore Tick | `ore_flecks 70%`, `shell 30%` | Bridges combat into metallurgy if given salvage sinks | `enemies/ore_tick.png` plus variants | code-drawn hostile shape if art missing |
| Raider Basic | `coins 75%`, `scrap_weapons 40%` | Natural seed for economy and salvage systems | `enemies/raider_basic.png` plus variants | code-drawn hostile shape if art missing |
| Raider Torchbearer | `oil_rags 60%`, `torch_heads 40%` | Natural seed for fire, fuel, and advanced light systems | `enemies/raider_torchbearer.png` plus variants | code-drawn hostile shape if art missing |

## Recipe Routing Reference

| Recipe id | Station | Inputs | Raw outputs | Result route | Result in play | Why it matters |
|---|---|---|---|---|---|---|
| `craft_torch` | `hand` | `wood x1`, `stone x1` | `torch x3` | inventory | Adds torches to player inventory | Core early survival sink. |
| `craft_wood_block` | `hand` | `wood x1` | `wood x1` | inventory | Identity craft | Mostly a UI/contract surface, not real transformation. |
| `craft_stone_block` | `hand` | `stone x1` | `stone x1` | inventory | Identity craft | Mostly a UI/contract surface, not real transformation. |
| `craft_seeds` | `hand` | `food x1` | `crop_seeds x2` | inventory | Adds seeds to player inventory | Current farming loop closer. |
| `craft_lantern` | `town_hall` | `ore x2`, `wood x1` | `lantern x1` | inventory | Adds lantern to player inventory | Main deep-ore light sink. |
| `basic_pick_upgrade` | `town_hall` | `wood x3`, `stone x5` | `tool_tier_2_pick x1` | code-routed pick upgrade | Upgrades equipped pick to `pick_forged` | Important special case: JSON token is not the real player-facing item. |
| `craft_axe` | `town_hall` | `wood x4`, `stone x2` | none in raw JSON | code-routed equip | Equips `axe_crude` | Important special case: no raw `outputs`, real result comes from code. |
| `craft_sword` | `town_hall` | `wood x2`, `stone x3` | none in raw JSON | code-routed equip | Equips `sword_crude` | Important special case: no raw `outputs`, real result comes from code. |
| `craft_armor_set` | `town_hall` | `wood x6`, `stone x4` | none in raw JSON | code-routed equip | Equips crude armor set | Important special case: no raw `outputs`, real result comes from code. |
| `workbench_torch_bundle` | `workbench` | `wood x2`, `coal x1` | `torch x6` | inventory | Adds torches to player inventory | Light/fuel station sink. |
| `smelt_copper` | `furnace` | `copper_ore x2`, `coal x1` | `copper_ingot x1` | stockpile | Adds ingot to stockpile | Starts metallurgy. |
| `smelt_tin` | `furnace` | `tin_ore x2`, `coal x1` | `tin_ingot x1` | stockpile | Adds ingot to stockpile | Starts metallurgy. |
| `smelt_iron` | `furnace` | `iron_ore x2`, `coal x1` | `iron_ingot x1` | stockpile | Adds ingot to stockpile | Feeds current top-tier live combat gear. |
| `smelt_silver` | `furnace` | `silver_ore x2`, `coal x1` | `silver_ingot x1` | stockpile | Adds ingot to stockpile | Currently ends in a stockpile dead-end. |
| `alloy_bronze` | `furnace` | `copper_ingot x1`, `tin_ingot x1`, `coal x1` | `bronze_ingot x2` | stockpile | Adds alloy to stockpile | Currently ends in a stockpile dead-end. |
| `anvil_iron_sword` | `anvil` | `iron_ingot x3` | none in raw JSON | `equip_slots` | Equips `sword_iron` | First explicit gear-upgrade anvil sink. |
| `anvil_iron_armor` | `anvil` | `iron_ingot x5` | none in raw JSON | `equip_slots` | Equips iron armor set | First explicit gear-upgrade armor sink. |

## Visual Surface Index

| Surface family | Current state | Missing or deferred | Planning note |
|---|---|---|---|
| Item icons | Fully covered for all 43 current item ids | none required for current live item ids | Stable and canonical-only by design. |
| Enemy sprites | Covered for all 6 live enemy ids | planned enemy families only | No immediate live-image blocker. |
| Player bodies | Covered for all 10 live body ids plus look variants | planned ancestry bodies only | Safe for current shell and gameplay. |
| Equipment overlays | 120 body-specific PNGs live for crude armor and basic/forged pick + crude axe swings | uncovered equipment families and refresh/alignment hardening | Continue from current coverage; do not regenerate already-authored families without an approved style pass. |
| Equipment item icons | No live consumer | still deferred | Do not mistake this for a bug; the game currently does not use backpack-style equipment icons. |
| UI | Primary native 19-asset HUD kit live; legacy/reserved UI hooks retained | primary chrome polish and framed-panel defect cleanup | Runtime content remains separate; use the HUD Asset Replacement Studio. |
| Opening art | Eight authored scene pools / ten PNGs live | optional approved animation/variant expansion | Plotted fallback remains safe and deterministic. |
| Backdrops and back walls | live and covered for current surfaces | future cave/deep-cave/background families | Not a current blocker. |

## Planned-Only Data Hooks

These are intentionally separated from live content. They are not implemented current mechanics.

| Item id | Status | Referenced by | Chance | Why it matters | Recommended first implementation sink |
|---|---|---|---|---|---|
| `antlers` | planned, not implemented | Hollow Stag | 5% | rare prestige material hook | trophy, ritual focus, high-tier trade |
| `clay` | planned, not implemented | Mudling | 60% | construction/material branch hook | bricks, pottery, furnace upgrade |
| `forged_seal` | planned, not implemented | False Taxman | 30% | economy/politics hook | civic quest or treasury sink |
| `fungal_thread` | planned, not implemented | Sporekin | 35% | cave cloth/alchemy hook | wraps, filters, attunement cloth |
| `fuse_cord` | planned, not implemented | Raider Sapper | 35% | trap/explosive hook | demolition or trap recipes |
| `glow_gland` | planned, not implemented | Lantern Leech | 45% | advanced light hook | cave lamp or alchemy light |
| `hide` | planned, not implemented | Burrow Maw; Hollow Stag | 50%; 25% | stronger leather branch hook | medium armor or packs |
| `mud` | planned, not implemented | Mudling | 30% | low-tier construction hook | clay prep or farming amendment |
| `oil` | planned, not implemented | Lantern Leech | 55% | light/fuel hook | lantern fuel or fire weapons |
| `picks` | planned, not implemented | Raider Sapper | 50% | salvage/tool hook | tool repair or iron salvage |
| `reed_fiber` | planned, not implemented | Mudling | 10% | weaving/rope hook | rope, nets, matting |
| `spores` | planned, not implemented | Sporekin | 65% | fungal/alchemy hook | medicine, poison, farming catalyst |
| `stone_plates` | planned, not implemented | Stoneback Beetle | 80% | heavy armor/fortification hook | armor, barricade plating |
| `teeth` | planned, not implemented | Burrow Maw | 50% | combat trophy hook | dagger, charm, trophy |
| `venison` | planned, not implemented | Hollow Stag | 70% | premium food hook | feast or trade good |
| `venom` | planned, not implemented | Ash Wasp | 5% | poison/alchemy hook | toxin, trap, advanced craft |
| `wax` | planned, not implemented | Ash Wasp | 60% | candle/light hook | candles, seals, polish |
| `wings` | planned, not implemented | Ash Wasp | 35% | light craft/alchemy hook | fletching or charm craft |

## Current Maintenance Priorities

| Priority | Why it matters |
|---|---|
| Add first real sinks for live enemy drops | The largest cluster of current `source-only` items is combat loot. |
| Add first downstream sinks for `silver_ingot`, `bronze_ingot`, and `crystal` | Metallurgy and attunement progression currently stop early. |
| Decide whether `ring_band` and `amulet_focus` should stay dead or become near-term goals | They are already defined and create obvious planning pressure. |
| Decide whether any world-only metadata items should remain non-inventory forever | `grass`, `farm_soil`, `crop_seedling`, `crop_ripe`, and `berry_bush` are easy to misunderstand without a deliberate policy. |
| Harden authored `player_gear` refresh/alignment and extend only uncovered equipment families | Crude armor and three tool families already have 120 PNGs; the active problem is reliable presentation and polished motion, not an empty asset directory. |
| Replace provisional HUD chrome through the native kit contract | Geometry and runtime separation are stabilized; the remaining work is asset and framed-panel polish with screenshot review. |

## Notes

- No mechanics were changed to produce this wiki.
- Current sink recommendations are proposals only and are not live gameplay behavior.
- Future-sink ideas are centralized in `planned_data.md`; strict current item pages should describe current sources, current uses, and current limitations without embedding planning bullets.
