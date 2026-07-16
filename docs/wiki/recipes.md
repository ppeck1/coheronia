# Recipes

Generated: 2026-07-15

This page is the first-class recipe index for the current Coheronia wiki. It separates recipe behavior from station pages so crafting continuity can be reviewed directly.

## Recipe Index

| Recipe | Station | Inputs | Raw outputs | Result route | Actual result in play |
|---|---|---|---|---|---|
| [Torch](recipes/craft_torch.md) | hand | `wood x1`, `stone x1` | `torch x3` | inventory | Adds torches to player inventory. |
| [Wood Block](recipes/craft_wood_block.md) | hand | `wood x1` | `wood x1` | inventory | Identity craft; returns a carried wood item. |
| [Stone Block](recipes/craft_stone_block.md) | hand | `stone x1` | `stone x1` | inventory | Identity craft; returns a carried stone item. |
| [Crop Seeds](recipes/craft_seeds.md) | hand | `food x1` | `crop_seeds x2` | inventory | Converts food into plantable seeds. |
| [Lantern](recipes/craft_lantern.md) | town_hall | `ore x2`, `wood x1` | `lantern x1` | inventory | Adds a placeable lantern to player inventory. |
| [Basic Pick Upgrade](recipes/basic_pick_upgrade.md) | town_hall | `wood x3`, `stone x5` | `tool_tier_2_pick x1` | code-routed pick upgrade | Upgrades the equipped pick to `pick_forged`; the raw output is an internal token. |
| [Axe](recipes/craft_axe.md) | town_hall | `wood x4`, `stone x2` | none | code-routed equip | Equips `axe_crude`. |
| [Crude Sword](recipes/craft_sword.md) | town_hall | `wood x2`, `stone x3` | none | code-routed equip | Equips `sword_crude`. |
| [Crude Armor Set](recipes/craft_armor_set.md) | town_hall | `wood x6`, `stone x4` | none | code-routed equip | Equips crude helmet, torso, and feet armor. |
| [Torch Bundle](recipes/workbench_torch_bundle.md) | workbench | `wood x2`, `coal x1` | `torch x6` | inventory | Adds torches to player inventory. |
| [Smelt Copper](recipes/smelt_copper.md) | furnace | `copper_ore x2`, `coal x1` | `copper_ingot x1` | stockpile | Adds copper ingot to Town Hall stockpile. |
| [Smelt Tin](recipes/smelt_tin.md) | furnace | `tin_ore x2`, `coal x1` | `tin_ingot x1` | stockpile | Adds tin ingot to Town Hall stockpile. |
| [Smelt Iron](recipes/smelt_iron.md) | furnace | `iron_ore x2`, `coal x1` | `iron_ingot x1` | stockpile | Adds iron ingot to Town Hall stockpile. |
| [Smelt Silver](recipes/smelt_silver.md) | furnace | `silver_ore x2`, `coal x1` | `silver_ingot x1` | stockpile | Adds silver ingot to stockpile; no downstream live sink yet. |
| [Alloy Bronze](recipes/alloy_bronze.md) | furnace | `copper_ingot x1`, `tin_ingot x1`, `coal x1` | `bronze_ingot x2` | stockpile | Adds bronze ingots to stockpile; no downstream live sink yet. |
| [Iron Sword](recipes/anvil_iron_sword.md) | anvil | `iron_ingot x3` | none | `equip_slots` | Equips `sword_iron`. |
| [Iron Armor Set](recipes/anvil_iron_armor.md) | anvil | `iron_ingot x5` | none | `equip_slots` | Equips iron helmet, torso, and feet armor. |

## Routing Notes

- Inventory recipes create carried items.
- Stockpile recipes add outputs to the Town Hall stockpile rather than the backpack.
- Equip-route recipes can have empty raw JSON outputs because code applies the actual equipment result.
- `basic_pick_upgrade` is the special bridge case: the raw token `tool_tier_2_pick` is internal, while the player-facing result is `pick_forged`.

## Related Pages

- [Crafting Stations](stations.md)
- [Items](items.md)
- [Equipment](equipment.md)
- [Internal Tokens](internal_tokens.md)
- [Wiki Overview](wiki.md)
