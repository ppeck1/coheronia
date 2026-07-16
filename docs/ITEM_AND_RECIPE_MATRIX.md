# Coheronia Item And Recipe Matrix

Generated: 2026-07-15

## Scope

- Audit target: `B:\dev\Coheronia\coheronia_fable_oneshot_repo` only.
- Double-checked against `data/items.json`, `data/blocks.json`, `data/recipes.json`, `data/equipment.json`, `data/enemies.json`, `data/character_data.json`, plus the live consumers in `scripts/player/player.gd`, `scripts/settlement/town_hall.gd`, `scripts/world/block_registry.gd`, `scripts/ui/hud.gd`, and `scripts/validate_repo.py`.
- This report separates true live-obtainable items from defined metadata/icon surfaces that exist in data or art but are not yet reachable in normal play.

## Headline Summary

- Inventory/resource item metadata entries: **43** total; **34** live-obtainable now; **9** defined but not currently obtainable.
- Equipment entries: **13** total; **11** live-obtainable now; **2** defined but not currently obtainable.
- Recipe surfaces present: hand crafting, Town Hall forging/crafting, buildable stations (`workbench`, `furnace`, `anvil`), station recipes, and code-routed equip recipes.
- Defined-but-not-live inventory ids: grass, farm_soil, crop_seedling, crop_ripe, berry_bush, pick, axe, sword, armor.
- Defined-but-not-live equipment ids: ring_band, amulet_focus.

## Inventory / Resource Item Matrix

| Item id | Display name | Kind | Live-obtainable now? | Current sources | Created by recipe(s) | Used by recipe(s) / build(s) | Relevant gameplay notes | Notes |
|---|---|---|---|---|---|---|---|---|
| armor | Armor | Generic forge-icon metadata | No | none | none | none | Generic icon/meta entry, not the actual equipment item id |  |
| axe | Axe | Generic forge-icon metadata | No | none | none | none | Generic icon/meta entry, not the actual equipment item id |  |
| berry_bush | Berry Bush | Block-state metadata only | No | none | none | none | Preferred tool: axe; World/block state exists live, but inventory version is not currently granted |  |
| bronze_ingot | Bronze Ingot | Processed metal | Yes | Recipe: Alloy Bronze (furnace) | Alloy Bronze [alloy_bronze] | none | Alloyed from copper and tin at the furnace. |  |
| chitin | Crawler Chitin | Enemy drop | Yes | Enemy drop: Cave Crawler (65%) | none | none | A curved armor plate from a cave crawler. |  |
| coal | Coal | Ore-family resource | Yes | Block drop: Coal Seam x1 | none | Torch Bundle [workbench_torch_bundle]; Smelt Copper [smelt_copper]; Smelt Tin [smelt_tin]; Smelt Iron [smelt_iron]; Smelt Silver [smelt_silver]; Alloy Bronze [alloy_bronze]; Build station: Furnace | Mine gate: tool tier 1; Preferred tool: pick; Deposit-able to Town Hall stockpile |  |
| coins | Raider Coins | Enemy drop | Yes | Enemy drop: Raider Basic (75%) | none | none | Worn coinage taken from raiders. |  |
| copper_ingot | Copper Ingot | Processed metal | Yes | Recipe: Smelt Copper (furnace) | Smelt Copper [smelt_copper] | Alloy Bronze [alloy_bronze] | Smelted at the furnace. Alloys into bronze. |  |
| copper_ore | Copper Ore | Ore-family resource | Yes | Block drop: Copper Ore x1 | none | Smelt Copper [smelt_copper] | Mine gate: tool tier 1; Preferred tool: pick; Deposit-able to Town Hall stockpile |  |
| crop_ripe | Ripe Crop | Block-state metadata only | No | none | none | none | World/block state exists live, but inventory version is not currently granted |  |
| crop_seedling | Sprouting Crop | Block-state metadata only | No | none | none | none | World/block state exists live, but inventory version is not currently granted |  |
| crop_seeds | Crop Seeds | Farming input | Yes | Block drop: Sprouting Crop x1; Block drop: Ripe Crop x1; Recipe: Crop Seeds (hand) | Crop Seeds [craft_seeds] | none | Planted on tilled soil with G |  |
| crystal | Raw Crystal | Ore-family resource | Yes | Block drop: Raw Crystal x1 | none | none | Mine gate: tool tier 2; Preferred tool: pick; Deposit-able to Town Hall stockpile |  |
| dirt | Dirt | Block-backed resource | Yes | Role start: Homesteader x10; Block drop: Dirt x1; Block drop: Grass x1; Block drop: Tilled Soil x1 | none | none | Placeable block; Deposit-able to Town Hall stockpile |  |
| eyes | Crawler Eyes | Enemy drop | Yes | Enemy drop: Cave Crawler (5%) | none | none | A glossy alchemical reagent from a cave crawler. |  |
| farm_soil | Tilled Soil | Block-state metadata only | No | none | none | none | World/block state exists live, but inventory version is not currently granted |  |
| food | Food | Consumable food | Yes | Block drop: Ripe Crop x3; Block drop: Berry Bush x2 | none | Crop Seeds [craft_seeds] | Eaten with H; heals 25 health; Deposit-able to Town Hall stockpile |  |
| grass | Grass | Block-state metadata only | No | none | none | none | World/block state exists live, but inventory version is not currently granted |  |
| hide_scrap | Hide Scrap | Enemy drop | Yes | Enemy drop: Thornrat (5%) | none | none | A scrap of tough hide. |  |
| iron_ingot | Iron Ingot | Processed metal | Yes | Recipe: Smelt Iron (furnace) | Smelt Iron [smelt_iron] | Iron Sword [anvil_iron_sword]; Iron Armor Set [anvil_iron_armor]; Build station: Anvil | Smelted at the furnace. Anvil stock for iron gear. |  |
| iron_ore | Iron Ore | Ore-family resource | Yes | Block drop: Iron Ore x1 | none | Smelt Iron [smelt_iron] | Mine gate: tool tier 2; Preferred tool: pick; Deposit-able to Town Hall stockpile |  |
| lantern | Lantern | Placeable light | Yes | Block drop: Lantern x1; Recipe: Lantern (town_hall) | Lantern [craft_lantern] | none | Placeable block; Light radius 160 |  |
| meat | Raw Meat | Enemy drop | Yes | Enemy drop: Thornrat (65%) | none | none | Thornrat meat. Butcher's yield. |  |
| oil_rags | Oil Rags | Enemy drop | Yes | Enemy drop: Raider Torchbearer (60%) | none | none | Oily rags from a torchbearer. Raid fuel. |  |
| ore | Ore | Block-backed resource | Yes | Block drop: Ore x1 | none | Lantern [craft_lantern] | Mine gate: tool tier 2; Preferred tool: pick; Deposit-able to Town Hall stockpile |  |
| ore_flecks | Ore Flecks | Enemy drop | Yes | Enemy drop: Ore Tick (70%) | none | none | Metal residue scraped from an ore tick. |  |
| pick | Pick | Generic forge-icon metadata | No | none | none | none | Generic icon/meta entry, not the actual equipment item id |  |
| scrap_weapons | Weapon Scrap | Enemy drop | Yes | Enemy drop: Raider Basic (40%) | none | none | Broken blades and bent points fit only for salvage. |  |
| shell | Tick Shell | Enemy drop | Yes | Enemy drop: Ore Tick (30%) | none | none | The hard shell of an ore tick. |  |
| silk | Cave Silk | Enemy drop | Yes | Enemy drop: Cave Crawler (30%) | none | none | Pale fiber spun by cave crawlers. |  |
| silver_ingot | Silver Ingot | Processed metal | Yes | Recipe: Smelt Silver (furnace) | Smelt Silver [smelt_silver] | none | Smelted at the furnace. |  |
| silver_ore | Silver Ore | Ore-family resource | Yes | Block drop: Silver Ore x1 | none | Smelt Silver [smelt_silver] | Mine gate: tool tier 2; Preferred tool: pick; Deposit-able to Town Hall stockpile |  |
| slime_gel | Slime Gel | Enemy drop | Yes | Enemy drop: Surface Slime (70%) | none | none | Sticky residue from slimes. |  |
| stone | Stone | Block-backed resource | Yes | Role start: Prospector x2; Block drop: Stone x1; Recipe: Stone Block (hand) | Stone Block [craft_stone_block] | Torch [craft_torch]; Stone Block [craft_stone_block]; Basic Pick Upgrade [basic_pick_upgrade]; Axe [craft_axe]; Crude Sword [craft_sword]; Crude Armor Set [craft_armor_set]; Build station: Workbench; Build station: Furnace; Build station: Anvil | Placeable block; Mine gate: tool tier 1; Preferred tool: pick; Deposit-able to Town Hall stockpile |  |
| sword | Sword | Generic forge-icon metadata | No | none | none | none | Generic icon/meta entry, not the actual equipment item id |  |
| thorn_quill | Thorn Quill | Enemy drop | Yes | Enemy drop: Thornrat (30%) | none | none | A barbed quill from a thornrat. |  |
| tin_ingot | Tin Ingot | Processed metal | Yes | Recipe: Smelt Tin (furnace) | Smelt Tin [smelt_tin] | Alloy Bronze [alloy_bronze] | Smelted at the furnace. Alloys into bronze. |  |
| tin_ore | Tin Ore | Ore-family resource | Yes | Block drop: Tin Ore x1 | none | Smelt Tin [smelt_tin] | Mine gate: tool tier 1; Preferred tool: pick; Deposit-able to Town Hall stockpile |  |
| tiny_core | Tiny Core | Enemy drop | Yes | Enemy drop: Surface Slime (5%) | none | none | A faintly humming mote. |  |
| torch | Torch | Placeable light | Yes | Role start: Prospector x3; Block drop: Torch x1; Recipe: Torch (hand); Recipe: Torch Bundle (workbench) | Torch [craft_torch]; Torch Bundle [workbench_torch_bundle] | none | Placeable block; Light radius 96 |  |
| torch_heads | Torch Heads | Enemy drop | Yes | Enemy drop: Raider Torchbearer (40%) | none | none | Pitch-soaked torch heads. |  |
| wet_fiber | Wet Fiber | Enemy drop | Yes | Enemy drop: Surface Slime (25%) | none | none | Damp plant strands. |  |
| wood | Wood | Block-backed resource | Yes | Role start: Homesteader x5; Block drop: Wood x1; Block drop: Tree Trunk x1; Recipe: Wood Block (hand) | Wood Block [craft_wood_block] | Torch [craft_torch]; Wood Block [craft_wood_block]; Lantern [craft_lantern]; Basic Pick Upgrade [basic_pick_upgrade]; Axe [craft_axe]; Crude Sword [craft_sword]; Crude Armor Set [craft_armor_set]; Torch Bundle [workbench_torch_bundle]; Build station: Workbench | Placeable block; Preferred tool: axe; Deposit-able to Town Hall stockpile |  |

## Equipment / Gear Matrix

| Item id | Display name | Slot type | Live-obtainable now? | Current source | Effects | Dedicated item icon present? | Relevant notes | Notes |
|---|---|---|---|---|---|---|---|---|
| amulet_focus | Focus Amulet | amulet | No | none | attunement_bonus x10 | No | Code-supported attunement item, but docs say not yet acquirable in play |  |
| axe_crude | Crude Axe | axe | Yes | Forge result: Axe (Town Hall) | axe_tier x1 | No | Shown through equipped axe slot once axe tier reaches 1 |  |
| feet_crude | Crude Boots | feet | Yes | Forge result: Crude Armor Set (Town Hall) | armor x1 | No | Town Hall armor-set forge equips directly |  |
| feet_iron | Iron Boots | feet | Yes | Craft result: Iron Armor Set (anvil) | armor x2 | No | Anvil recipe equips directly from stockpile ingots |  |
| helmet_crude | Crude Helm | helmet | Yes | Forge result: Crude Armor Set (Town Hall) | armor x1 | No | Town Hall armor-set forge equips directly |  |
| helmet_iron | Iron Helm | helmet | Yes | Craft result: Iron Armor Set (anvil) | armor x2 | No | Anvil recipe equips directly from stockpile ingots |  |
| pick_basic | Basic Pick | pickaxe | Yes | Default character equipment: starter pickaxe slot | pick_tier x1 | No | Starter pickaxe slot on new characters |  |
| pick_forged | Forged Pick | pickaxe | Yes | Forge result: Basic Pick Upgrade (Town Hall) | pick_tier x2 | No | Shown through equipped pickaxe slot once pick tier reaches 2 |  |
| ring_band | Plain Band | ring | No | none | none | No | Schema/smoke item only; no normal acquisition path |  |
| sword_crude | Crude Sword | weapon | Yes | Forge result: Crude Sword (Town Hall) | attack_damage x3 | No | Town Hall forge equips directly; no backpack item step |  |
| sword_iron | Iron Sword | weapon | Yes | Craft result: Iron Sword (anvil) | attack_damage x5 | No | Anvil recipe equips directly from stockpile ingots |  |
| torso_crude | Crude Cuirass | torso | Yes | Forge result: Crude Armor Set (Town Hall) | armor x2 | No | Town Hall armor-set forge equips directly |  |
| torso_iron | Iron Cuirass | torso | Yes | Craft result: Iron Armor Set (anvil) | armor x4 | No | Anvil recipe equips directly from stockpile ingots |  |

## Station Build Matrix

| Station id | Display name | Built from | Prerequisite | Build cost | Unlocks | Notes |
|---|---|---|---|---|---|---|
| workbench | Workbench | Town Hall stockpile | none | wood x12, stone x6 | Torch Bundle | Built state persists in settlement save data |
| furnace | Furnace | Town Hall stockpile | workbench | stone x16, coal x4 | Smelt Copper; Smelt Tin; Smelt Iron; Smelt Silver; Alloy Bronze | Built state persists in settlement save data |
| anvil | Anvil | Town Hall stockpile | furnace | stone x10, iron_ingot x3 | Iron Sword; Iron Armor Set | Built state persists in settlement save data |

## Recipe Matrix

| Recipe id | Display name | Where crafted | Inputs | Gameplay result | Output route | Double-check note | Notes |
|---|---|---|---|---|---|---|---|
| craft_torch | Torch | Hand crafting / player inventory | wood x1, stone x1 | torch x3 | Added to player inventory | Standard craft route |  |
| craft_wood_block | Wood Block | Hand crafting / player inventory | wood x1 | wood x1 | Added to player inventory | Standard craft route |  |
| craft_stone_block | Stone Block | Hand crafting / player inventory | stone x1 | stone x1 | Added to player inventory | Standard craft route |  |
| craft_seeds | Crop Seeds | Hand crafting / player inventory | food x1 | crop_seeds x2 | Added to player inventory | Standard craft route |  |
| craft_lantern | Lantern | Town Hall stockpile panel | ore x2, wood x1 | lantern x1 | Added to player inventory | Standard craft route |  |
| basic_pick_upgrade | Basic Pick Upgrade | Town Hall stockpile panel | wood x3, stone x5 | Upgrade live pick tier to 2; equipped view becomes `pick_forged` | Special forge path on Town Hall; code also passes through recipe outputs | JSON declares `tool_tier_2_pick x1`, but the player-facing result is the upgraded pick tier/equipped `pick_forged` state |  |
| craft_axe | Axe | Town Hall stockpile panel | wood x4, stone x2 | Unlock/equip `axe_crude` by setting axe tier to 1 | Special forge path on Town Hall | Recipe outputs are empty in JSON; `town_hall.forge_axe()` supplies the gameplay result |  |
| craft_sword | Crude Sword | Town Hall stockpile panel | wood x2, stone x3 | Equip `sword_crude` to weapon slot | Special forge path on Town Hall | Recipe outputs are empty in JSON; `town_hall.forge_sword()` equips the item directly |  |
| craft_armor_set | Crude Armor Set | Town Hall stockpile panel | wood x6, stone x4 | Equip `helmet_crude`, `torso_crude`, and `feet_crude` | Special forge path on Town Hall | Recipe outputs are empty in JSON; `town_hall.forge_armor()` equips the set directly |  |
| workbench_torch_bundle | Torch Bundle | Workbench station (stockpile) | wood x2, coal x1 | torch x6 | Added to player inventory | Standard craft route |  |
| smelt_copper | Smelt Copper | Furnace station (stockpile) | copper_ore x2, coal x1 | copper_ingot x1 | Added to Town Hall stockpile | Used for smelting/alloying; stockpile keeps the ingots/bronze |  |
| smelt_tin | Smelt Tin | Furnace station (stockpile) | tin_ore x2, coal x1 | tin_ingot x1 | Added to Town Hall stockpile | Used for smelting/alloying; stockpile keeps the ingots/bronze |  |
| smelt_iron | Smelt Iron | Furnace station (stockpile) | iron_ore x2, coal x1 | iron_ingot x1 | Added to Town Hall stockpile | Used for smelting/alloying; stockpile keeps the ingots/bronze |  |
| smelt_silver | Smelt Silver | Furnace station (stockpile) | silver_ore x2, coal x1 | silver_ingot x1 | Added to Town Hall stockpile | Used for smelting/alloying; stockpile keeps the ingots/bronze |  |
| alloy_bronze | Alloy Bronze | Furnace station (stockpile) | copper_ingot x1, tin_ingot x1, coal x1 | bronze_ingot x2 | Added to Town Hall stockpile | Used for smelting/alloying; stockpile keeps the ingots/bronze |  |
| anvil_iron_sword | Iron Sword | Anvil station (stockpile) | iron_ingot x3 | weapon -> sword_iron | Equips directly to player slots | Slot occupancy and slot/type fit are checked before stockpile inputs are consumed |  |
| anvil_iron_armor | Iron Armor Set | Anvil station (stockpile) | iron_ingot x5 | helmet -> helmet_iron, torso -> torso_iron, feet -> feet_iron | Equips directly to player slots | Slot occupancy and slot/type fit are checked before stockpile inputs are consumed |  |

## Double-Check Findings

- `grass`, `farm_soil`, `crop_seedling`, `crop_ripe`, and `berry_bush` all have metadata/art coverage, but their live world blocks currently drop something else, so they are not normal inventory items yet.
- `pick`, `axe`, `sword`, and `armor` are generic icon/meta entries in `items.json`, not the actual equipment ids used by the live gear system (`pick_basic`, `pick_forged`, `axe_crude`, `sword_crude`, etc.).
- `ring_band` and `amulet_focus` are real equipment definitions, but neither has a normal acquisition recipe/path today. `amulet_focus` is explicitly described in repo docs as not yet acquirable in play.
- `basic_pick_upgrade` is the one recipe whose JSON output does not match the player-facing item model cleanly: the intended result is the pick-tier upgrade / `pick_forged` equipped state, while the JSON still declares `tool_tier_2_pick` as an output token.
- `craft_axe`, `craft_sword`, and `craft_armor_set` are also special-cased: their JSON outputs are empty, and the real results come from the Town Hall forge code path.

## Notes

- 
- 
- 
