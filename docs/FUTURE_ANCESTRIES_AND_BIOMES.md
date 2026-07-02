# Future Ancestries and Biomes Work Order

Status: future implementation reference. This document is a planning matrix for later builds and is **not integrated as live gameplay yet**.

Preferred term: **ancestries**. Avoid "races" in player-facing systems.

## Core Rule

Each ancestry should have six design bones:

| Bone | Purpose |
|---|---|
| Physical | How the body plays and moves |
| Cultural | How the civilization tends to develop |
| Environmental | Where the ancestry thrives or struggles |
| Innate | One memorable biological or inherited ability |
| Constraint | A deliberate tradeoff that shapes playstyle |
| Spawn Logic | Where the ancestry naturally starts |

Important rule: **Deep ancestries spawn underground** by default. They should not begin in normal surface biomes unless a custom world explicitly overrides that.

## Ancestry Matrix

| Ancestry | Spawn Band | Preferred Biomes | Physical Bone | Cultural Bone | Environmental Bone | Innate Bone | Constraint Bone |
|---|---|---|---|---|---|---|---|
| Human | Surface | Plains, forest edge, riverlands, mixed terrain | Balanced | Adaptable, civic | Anywhere | Fast learning | No specialization |
| Dwarf | Surface / mountain edge | Mountains, foothills, caves | Heavy, sturdy | Industry, masonry | Stone, ore, caves | Master Craftsman | Slower movement, lower jump |
| Deep Dwarf | Underground | Early caves, deep stone, ore caves | Very sturdy, compact | Fortress, mining clans | Deep stone, ore | Stone Sense | Weak surface farming/forestry |
| Elf | Surface | Forests, ancient groves | Agile, light | Harmony, forestry | Trees, animals, plants | Nature Sense | Lower hauling/carry efficiency |
| Deep Elf | Underground | Crystal caves, fungal caves, dark caverns | Agile, precise | Secrecy, hidden cities | Darkness, crystals, fungi | Dark Vision | Sunlight/bright surface penalty |
| Orc | Surface | Harsh plains, badlands, mountains | Powerful, durable | Expansion, endurance | Harsh terrain | War Cry | Lower stealth/diplomacy finesse |
| Goblin | Surface / shallow underground | Ruins, caves, scrap fields | Small, quick | Ingenuity, scavenging | Salvage, traps | Scavenger | Fragile, lower trust/coherence |
| Deep Goblin | Underground | Ruins, abandoned mines, cave networks | Small, fast crawler | Tunnel gangs, salvage dens | Tight caves, scrap, traps | Improvisation | Very fragile, poor open-field defense |
| Gnome | Surface | Hills, meadows, workshop towns | Small, careful | Engineering, invention | Hills, machines | Tinkering | Weak melee, lower durability |
| Deep Gnome | Underground | Crystal caves, machine ruins | Small, precise | Automation, hidden workshops | Crystals, mechanisms | Precision Tinkering | Poor surface survival |
| Lizardfolk | Surface | Swamps, rivers, wetlands | Strong, amphibious | Survival, clans | Water, reeds, mud | Amphibious | Cold penalty |
| Dragonkin | Surface / special | Volcanic, mountain, desert, swamp, tundra, caverns by type | Large, imposing | Pride, legacy, authority | Elemental terrain | Breath Ability | High food need, long cooldown |

## Recommended First Implementation Set

| Priority | Ancestry | Reason |
|---|---|---|
| 1 | Human | Baseline, easiest to balance |
| 2 | Dwarf | Mining/building identity fits current game |
| 3 | Elf | Forest/food/nature contrast |
| 4 | Goblin | Traps/salvage contrast |
| 5 | Orc | Combat/defense contrast |
| 6 | Deep Elf | First required underground-start ancestry |
| 7 | Lizardfolk | First biome-specialist surface ancestry |
| 8 | Dragonkin | Save for later because breath systems are more complex |

## Biome Affinity Scale

| Mark | Meaning |
|---|---|
| `+++` | Native / ideal |
| `++` | Strong |
| `+` | Usable |
| `0` | Neutral |
| `-` | Poor |
| `--` | Hostile |

## Biome Matrix

| Biome | Human | Dwarf | Deep Dwarf | Elf | Deep Elf | Orc | Goblin | Deep Goblin | Gnome | Deep Gnome | Lizardfolk | Dragonkin |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Plains | ++ | + | - | + | - | ++ | + | - | ++ | - | 0 | + |
| Forest | ++ | 0 | -- | +++ | - | + | + | - | + | - | + | 0 |
| Ancient Forest | + | - | -- | +++ | - | 0 | 0 | - | + | - | + | 0 |
| Hills | ++ | ++ | 0 | + | - | ++ | + | 0 | +++ | 0 | 0 | + |
| Mountains | + | +++ | ++ | 0 | + | +++ | + | + | ++ | ++ | - | ++ |
| Badlands | + | ++ | + | - | 0 | +++ | ++ | + | 0 | 0 | - | ++ |
| Desert | + | 0 | - | - | - | ++ | 0 | - | 0 | - | -- | Fire +++ |
| Swamp | 0 | - | - | + | 0 | + | ++ | + | - | - | +++ | Poison +++ |
| Riverlands | ++ | + | - | ++ | - | + | + | - | ++ | - | +++ | + |
| Snow / Tundra | + | ++ | + | + | - | ++ | - | - | 0 | - | -- | Ice +++ |
| Surface Ruins | ++ | + | 0 | 0 | 0 | ++ | +++ | ++ | ++ | + | 0 | + |
| Early Caves | + | +++ | +++ | - | ++ | + | ++ | +++ | + | ++ | - | Crystal ++ |
| Ore Caves | 0 | +++ | +++ | -- | ++ | + | ++ | +++ | + | +++ | - | Crystal +++ |
| Fungal Caves | - | ++ | ++ | - | +++ | 0 | ++ | +++ | 0 | ++ | 0 | Poison ++ |
| Crystal Caves | 0 | ++ | +++ | - | +++ | 0 | + | ++ | + | +++ | - | Crystal +++ |
| Deep Caverns | - | ++ | +++ | -- | +++ | 0 | + | +++ | - | +++ | -- | Crystal ++ |
| Volcanic | - | + | + | -- | 0 | ++ | 0 | 0 | - | 0 | -- | Fire +++ |

## Spawn Rules Matrix

| Ancestry | Default Spawn Type | Valid Start Biomes |
|---|---|---|
| Human | Surface settlement | Plains, forest edge, riverlands, hills |
| Dwarf | Mountain settlement | Foothills, mountains, cave mouth |
| Deep Dwarf | Underground settlement | Early cave, ore cave, deep stone |
| Elf | Forest settlement | Forest, ancient forest, river forest |
| Deep Elf | Underground settlement | Crystal cave, fungal cave, dark cavern |
| Orc | Frontier camp | Badlands, harsh plains, mountains |
| Goblin | Scrapyard camp | Ruins, cave mouth, rough hills |
| Deep Goblin | Underground den | Cave ruins, abandoned mine, early cave |
| Gnome | Hill workshop | Hills, meadow, riverland |
| Deep Gnome | Underground workshop | Crystal cave, machine ruin, ore cave |
| Lizardfolk | Wetland camp | Swamp, riverlands, marsh |
| Dragonkin | Elemental enclave | Depends on ancestry type |

## Dragonkin Type Matrix

| Dragonkin Type | Spawn Biome | Breath | Resistance | Settlement Bias | Constraint |
|---|---|---|---|---|---|
| Fire | Volcanic, desert | Cone flame | Heat/fire | Forge, intimidation, land clearing | High food, fire risk |
| Ice | Tundra, snow mountains | Frost burst | Cold | Preservation, defense, slow enemies | Poor hot climates |
| Lightning | Storm mountains | Chain lightning | Shock/storm | Power, signal towers, machinery | Unstable near water |
| Poison | Swamp | Gas cloud | Poison/sickness | Alchemy, disease resistance | Diplomacy penalty |
| Acid | Marsh, caves | Corrosion spray | Acid | Siege, mining, armor break | Damages structures if careless |
| Crystal | Crystal caves | Beam | Pressure/darkness | Mining, sensing, civic prestige | Poor farming affinity |

## Player Effect Matrix

| Ancestry | Player Advantages | Player Constraints |
|---|---|---|
| Human | +5% learning/tech speed, +5% diplomacy, no terrain penalties | No exceptional peak |
| Dwarf | +1 hotbar slot, +20% stone/ore mining, knockback resistance, better tool durability | 90% movement speed, 85% jump |
| Deep Dwarf | +25% ore mining, better underground visibility, reduced fall damage on stone | Surface farming/wood gathering penalty |
| Elf | Higher jump, better forest movement, reduced fall damage, plant detection | Lower carry/hauling efficiency |
| Deep Elf | Dark vision, mushroom/crystal harvest bonus, faster underground movement | Sunlight/bright surface stamina penalty |
| Orc | +25 health, melee bonus, stamina endurance, faster tree clearing | Lower stealth/diplomacy finesse |
| Goblin | Smaller hitbox, cheaper traps, material recovery chance | Lower health |
| Deep Goblin | Fastest crawl/tunnel movement, scrap bonus, trap bonus underground | Fragile, weak surface morale |
| Gnome | Faster crafting, cheaper machines/traps, automation bonus later | Weak melee, lower health |
| Deep Gnome | Crystal/machine bonus, precision crafting, automation bonus | Poor surface survival |
| Lizardfolk | Swim speed, water breathing, poison resistance, swamp movement | Cold increases food/stamina cost |
| Dragonkin | Elemental breath, matching resistance, intimidation | High food need, long cooldown, larger body |

## Settlement Effect Matrix

| Ancestry | Settlement Advantages | Settlement Constraints |
|---|---|---|
| Human | Faster civic upgrades, better mixed-population Coherence, diplomacy bonus | No terrain specialization |
| Dwarf | Stone structures add more Resilience, ore/stone stockpiles count more, better tool economy | Lower food/forest efficiency |
| Deep Dwarf | Underground homes reduce Load, mines produce more, deep defenses stronger | Surface settlements gain less Coherence |
| Elf | Trees/food ecology recover faster, animals less aggressive, forest shelter adds Coherence | Stone-heavy industry adds more Load |
| Deep Elf | Darkness does not increase Load as much, fungal/crystal economy stronger | Surface daylight settlements less efficient |
| Orc | Raids cause less fear, militia stronger, expansion pressure reduced | Diplomacy and subtle governance harder |
| Goblin | Repairs/traps cheaper, salvage improves Resilience, ruins become valuable | Lower baseline Coherence/trust |
| Deep Goblin | Underground traps/repairs excellent, abandoned mines easier to reclaim | Surface defense weaker |
| Gnome | Workshops, automation, civic machines cheaper | Weak militia without defenses |
| Deep Gnome | Underground automation and crystal devices stronger | Food production harder |
| Lizardfolk | Swamp food/water economy stronger, sickness/poison pressure lower | Cold settlements consume more |
| Dragonkin | Ruler legitimacy/intimidation bonus, elemental infrastructure later | Higher food demand and social pressure |

## Suggested Implementation Phases

| Phase | Goal | Ancestries |
|---|---|---|
| Phase A | Data model only | All ancestries |
| Phase B | First playable effects | Human, Dwarf, Elf, Goblin, Orc |
| Phase C | Underground starts | Deep Elf, Deep Dwarf, Deep Goblin |
| Phase D | Biome pressure | Lizardfolk, Gnome, Deep Gnome |
| Phase E | Elemental systems | Dragonkin |
| Phase F | Civilization interaction | Mixed populations, diplomacy, legitimacy, rebellion |

## Future Data Shape

When ready to implement, distill this document into `data/ancestries.json` or expand `data/character_data.json`. Suggested keys:

```json
{
  "id": "dwarf",
  "display_name": "Dwarf",
  "spawn_band": "surface_mountain",
  "preferred_biomes": ["mountains", "foothills", "cave_mouth"],
  "bones": {
    "physical": "Heavy, sturdy",
    "cultural": "Industry, masonry",
    "environmental": "Stone, ore, caves",
    "innate": "Master Craftsman",
    "constraint": "Slower movement, lower jump"
  },
  "player_effects": {
    "hotbar_slots_bonus": 1,
    "stone_ore_mining_mult": 1.2,
    "move_speed_mult": 0.9,
    "jump_mult": 0.85
  },
  "settlement_effects": {
    "stone_resilience_mult": 1.1,
    "ore_stockpile_value_mult": 1.1
  }
}
```

## Implementation Notes

- Keep ancestry choices meaningful without locking any ancestry out of a core game system.
- Give each ancestry one signature strength and one real constraint.
- Let ancestry affect both the player avatar and the civilization being ruled.
- Deep ancestry starts require underground-safe spawn generation, initial light/shelter rules, and starting resources that prevent unfair immediate failure.
- Avoid copying published RPG race descriptions, rule text, or setting-specific lore. Use folklore/fantasy archetypes as broad inspiration and build Coheronia-specific identity over time.
