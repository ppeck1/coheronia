# Future Progression, Research, and Base Levels Work Order

Status: future implementation reference. This document is a planning matrix for later builds and is **not integrated as live gameplay yet**.

Design goal: Coheronia should progress on three linked RPG/civilization axes:

1. The player grows as an adventurer, builder, ruler, and survivor.
2. The base grows from camp to city-state.
3. The civilization researches systems that change what can be built, governed, defended, and explored.

Progression should not be only "numbers go up." It should feed the central fantasy: you level yourself, your settlement, and eventually the civilization you rule.

## Progression Layer Matrix

| Layer | What Levels | Main XP Source | Unlocks |
|---|---|---|---|
| Player | Character | Enemies, mining, crafting, exploration, civic acts, survival events | Perks, combat options, movement, survival skills |
| Base | Town Hall / settlement | Stockpiles, population support, survived raids, structures, C/L/R milestones | Building radius, population cap, civic structures, defenses |
| Research | Civilization knowledge | Resources, workstations, subjects, bosses, ruins, biome samples | Recipes, tools, blocks, automation, laws, governance systems |
| Ancestry | Civilization identity | Ancestry-specific achievements and biome success | Ancestry civics, settlement traits, environmental advantages |
| World | Global pressure | Days survived, bosses defeated, depth reached, base level | Harder raids, deeper ores, new events, biome escalation |

## Player XP Matrix

Player XP should come from more than combat so peaceful builders, miners, and rulers can progress.

| XP Type | Sources | Unlock Direction |
|---|---|---|
| Combat XP | Enemies, raids, bosses, defending subjects | Health, weapon handling, active abilities, threat control |
| Labor XP | Mining, woodcutting, hauling, building, repairing | Speed, stamina, reach, tool handling, placement efficiency |
| Survival XP | Storms, hunger, cave trips, harsh biomes, poison/cold/heat | Resistance, food efficiency, weather tolerance, emergency recovery |
| Civic XP | Depositing resources, repairing the hall, feeding subjects, resolving crises | Leadership perks, morale effects, legitimacy, command radius |
| Exploration XP | Discovering biomes, ruins, caves, bosses, rare resources | Map reveal, rare-resource detection, travel bonuses, scouting |
| Craft XP | Crafting, upgrading tools, building workstations, using rare drops | Recipe quality, durability, station efficiency, experimentation |

## Player Perk Lane Matrix

| Lane | Theme | Example Perks |
|---|---|---|
| Miner | Deep extraction | Faster stone/ore mining, safer tunnels, ore sense |
| Builder | Physical construction | Longer placement reach, faster block placement, structural bonuses |
| Warden | Defense and combat | More health, better threat damage, guard-command bonuses |
| Forager | Food and ecology | More berry/plant yield, better farming starts, rare plant sensing |
| Ruler | Governance | Better subject morale, lower rebellion pressure, faster base XP |
| Explorer | Movement and discovery | Fall resistance, biome reveal, better cave navigation |
| Artisan | Crafting quality | Tool durability, station output, rare recipe chance |

Implementation note: perk lanes should not hard-lock roles. Let a player mix lanes, but make ancestry and settlement choices create natural bias.

## Base Level Matrix

The base should level like the civilization's heart, not just a bigger chest.

| Base Level | Name | Required Signals | Unlocks |
|---|---|---|---|
| 1 | Camp | Town Hall placed, basic shelter | Basic stockpile, shelter scoring, primitive repairs |
| 2 | Hamlet | Stable food reserve, first settlers, safe light | Population growth, basic farms, basic walls/fences |
| 3 | Village | Supported population, workshop, steady C/L/R | Research bench, civic roles, better storage |
| 4 | Town | Defenses, industry, multiple districts | Districts, militia, trade hooks, laws |
| 5 | Keep | Survived organized raids, stone defenses, civic legitimacy | Advanced defenses, ruler systems, civic upgrades |
| 6 | City-State | Large supported population, multiple biome links, boss/relic milestone | Laws, factions, large raids, formal governance, major research |

## Base XP Source Matrix

| Base XP Source | Examples | Why It Matters |
|---|---|---|
| Stockpile value | Food, stone, ore, wood, rare materials | Measures survival capacity |
| Structure quality | Roofed hall, walls, light coverage, defenses | Makes building matter spatially |
| Population support | Settlers fed, housed, protected | Connects growth to responsibility |
| C/L/R stability | Healthy averages over time, recovery after shocks | Rewards resilient design, not only expansion |
| Events survived | Storms, raids, boss attacks, shortages | Turns crisis recovery into progress |
| Civic milestones | First farm, workshop, shrine, barracks, market | Makes new systems push base identity |
| Biome links | Road/tunnel/outpost to a new biome | Encourages world expansion |

## Research Domain Matrix

Research should be partly material and partly experiential. Rare enemy drops should be excellent research inputs, but rare drops should unlock optional systems, recipes, trophies, or upgrades rather than block core progression.

| Research Domain | Inputs | Unlocks |
|---|---|---|
| Craft Research | Ore, wood, stone, crafted samples, tool use | Tools, stations, blocks, durability upgrades |
| Survival Research | Food, weather exposure, biome samples, medicine plants | Farming, medicine, clothing, shelter upgrades |
| Military Research | Enemy drops, raids survived, damaged walls, trophies | Walls, traps, militia gear, watchtowers |
| Civic Research | Population, morale, ledgers, relics, disputes | Laws, roles, legitimacy systems, governance upgrades |
| Arcane / Natural Research | Crystals, spores, rare plants, boss relics | Lights, rituals, ancestry systems, civic wards |
| Engineering Research | Gears, scrap, stone plates, workshop output | Automation, pumps, lifts, signal towers |
| Boss Research | Boss trophies, special relics, world scars | Major system unlocks and region progression |

## Research Flow Matrix

| Step | Player Action | Settlement Meaning |
|---|---|---|
| Discover | Find enemy, biome, ruin, resource, or crisis | The world reveals a question |
| Collect | Bring samples, drops, records, or relics home | The settlement can study it |
| Support | Provide workstation, subject role, light, food, safety | Research needs civilization support |
| Choose | Spend time/resources on a domain | The player steers development |
| Unlock | Gain recipe, law, structure, district, or ability | Research changes future play |

## Ancestry Progression Extension Matrix

Extend `docs/FUTURE_ANCESTRIES_AND_BIOMES.md` with these columns when implementation begins.

| New Column | Purpose |
|---|---|
| Player XP Bias | Which actions this ancestry learns fastest |
| Base XP Bias | What kind of settlement growth they favor |
| Research Affinity | Which research tree they accelerate |
| Civic Tension | What causes Load, unrest, or rebellion pressure |
| Signature Unlock | One late-game ancestry-flavored unlock |

| Ancestry | XP Bias | Base Bias | Research Affinity | Civic Tension | Signature Unlock |
|---|---|---|---|---|---|
| Human | All-around | Mixed settlement | Civics/diplomacy | No specialization | Charter Government |
| Dwarf | Mining/crafting | Stone halls | Tools/masonry | Weak food ecology | Deep Forge |
| Deep Dwarf | Deep mining/endurance | Underground fortress | Deep masonry/ore | Surface exposure | Root-Hall Citadel |
| Elf | Exploration/forestry | Living settlement | Nature/farming | Heavy industry | Grove Wardens |
| Deep Elf | Caves/stealth | Hidden city | Crystals/darkness | Daylight exposure | Umbral Archive |
| Orc | Combat/endurance | Fortified frontier | War/defense | Diplomacy friction | War Hall |
| Goblin | Traps/scavenging | Salvage camp | Traps/scrap | Low trust | Junkworks |
| Deep Goblin | Tunnels/salvage | Underground den | Trapworks/mines | Open-field weakness | Warren Engine |
| Gnome | Crafting/automation | Workshop town | Machines | Weak militia | Civic Engine |
| Deep Gnome | Precision/caverns | Hidden workshop | Crystals/automation | Food scarcity | Crystal Loom |
| Lizardfolk | Survival/swamp | Wetland village | Medicine/food | Cold climates | Reedwater Granary |
| Dragonkin | Combat/rulership | Authority seat | Elemental/civic | High food/social pressure | Dragon Throne |

## Base District Matrix

Base leveling should eventually become spatial through districts.

| District | Built From | Unlocks / Effects |
|---|---|---|
| Hall Core | Town Hall, storage, light | Base level, rule, legitimacy |
| Farm / Food Yard | Soil, water, fences, seed crops | Food stability, population growth |
| Workshop | Wood, stone, workstations | Craft research, tool quality |
| Forge | Stone, ore, fuel, heat | Tools, armor, masonry, metal blocks |
| Barracks / Watch | Beds, weapons, defense blocks | Militia, raid response, threat reduction |
| Market / Storehouse | Stockpiles, paths, coin/trade later | Trade, reserves, subject satisfaction |
| Shrine / Civic Site | Relics, symbols, light | Legitimacy, morale, laws |
| Library / Archive | Paper/ledger/relics, research bench | Research speed, civic memory |
| Gate / Wall | Stone, towers, traps | Defense score, raid pathing |

## Laws / Decrees Matrix

Rulership should become gameplay through laws and decrees, not only passive bonuses.

| Decree Type | Example | Benefit | Cost / Risk |
|---|---|---|---|
| Labor | Emergency Mining Order | Faster ore production | Higher Load, morale loss |
| Food | Rationing | Longer food reserves | Lower Coherence |
| Defense | Curfew | Fewer night casualties | Lower happiness/trade |
| Civic | Festival | Morale/Coherence boost | Food/stockpile cost |
| Expansion | Frontier Charter | Faster outpost growth | More raid attention |
| Justice | Harsh Punishments | Lower theft/rebellion short-term | Legitimacy risk |

## Factions and Reputation Matrix

| Faction Surface | Why It Matters |
|---|---|
| Subjects | Base morale, loyalty, labor, rebellion |
| Raiders | Raid patterns, diplomacy, deserter choices |
| Traders | Future economy, rare materials, reputation |
| Ancestry groups | Mixed population strengths/tensions |
| Wilderness / ecology | Overharvesting, animal aggression, nature systems |
| Boss-linked forces | Hollow King governance pressure, World-Worm extraction consequences |

## World Scale and Region Planning

The current standard world sizes are too small for the long-term plan. Once biomes, deep starts, ruins, caves, bosses, outposts, and multiple settlement shapes exist, generation should shift toward region-based planning.

| Region Type | Purpose |
|---|---|
| Home region | Starting settlement and first shelter loop |
| Nearby wilderness | Food, wood, basic enemies |
| Cave region | Early mining and underground danger |
| Biome region | Ancestry/environment identity |
| Ruin region | Research/events/lore/civic discoveries |
| Raider region | Camps, raid logic, social conflict |
| Boss region | Milestone challenge and system unlock |
| Deep region | Late-game mining, world instability, deep ancestries |

## World Size Guidance

| World Tier | Intended Use |
|---|---|
| Small | Prototype/testing only |
| Medium | Early playable loop |
| Large | Current best default for v0.4 |
| Standard Future | Should be much larger than current large; enough room for several surface biomes and cave systems |
| Region Future | Generated as linked regions/biome bands rather than one simple width/height preset |

## Threat Escalation Matrix

| Escalation Trigger | Response |
|---|---|
| Base level increases | Larger or smarter raids |
| Research tier increases | New enemy counters and resource needs |
| Deeper mining | Geological threats, cave enemies, World-Worm attention |
| Food surplus/population growth | More subject pressure and raider interest |
| Low legitimacy | Rebellion, deserters, false taxmen, civic crisis |
| Boss defeated | Unlocks new systems and raises world stakes |

## Additional Systems To Plan

These are not the obvious tools/workstations/blocks/ores/vendors/subjects list. They are higher-level connective systems that will keep RPG progression from becoming loose stat clutter.

| System | Why It Matters |
|---|---|
| Perks / skill trees | Player levels need choices |
| Base districts | Base leveling should be spatial, not abstract |
| Laws / decrees | Turns rulership into active gameplay |
| Reputation / legitimacy | More interesting than simple morale alone |
| Factions | Connects enemies, subjects, traders, and ancestry groups |
| Subject education | Research can depend on who lives in the settlement |
| Biome discovery gates | Progression should require going places |
| Boss-gated systems | Bosses should unlock new systemic layers |
| Threat escalation budgets | Base growth should attract new pressure |
| Save migration/versioning | More systems means compatibility risk |
| Difficulty budgets | Enemy density, base growth, research speed, hunger, and raids need separate tuning |
| Quest/contracts layer | Gives civilized reasons to travel, fight, trade, or build |
| Outposts | Lets large worlds support multiple regions without abandoning the home base |
| Maps/scouting | Makes region growth legible |

## Suggested Implementation Phases

| Phase | Goal | Notes |
|---|---|---|
| Phase A | Data models only | Add player XP, base XP, research domain schema; no broad gameplay yet |
| Phase B | Player XP MVP | Award XP for combat, mining, building, survival, exploration; one perk lane |
| Phase C | Base levels MVP | Camp -> Hamlet -> Village; unlock population cap/farms/research bench |
| Phase D | Research MVP | Research bench plus craft/survival/military domains |
| Phase E | Districts | Make base level depend on spatial structures |
| Phase F | Ancestry progression | Add XP/research/base biases from ancestry doc |
| Phase G | Laws and legitimacy | Add decrees, morale, loyalty, rebellion pressure |
| Phase H | Region/world scale | Expand generation beyond current size presets |
| Phase I | Boss-gated systems | Hollow King -> governance; World-Worm -> deep mining/foundations |

## Future Data Shape

When ready to implement, split this into data files such as:

```text
data/progression/player_xp.json
data/progression/base_levels.json
data/progression/research_domains.json
data/progression/perks.json
data/progression/laws.json
```

Example base-level shape:

```json
{
  "id": "hamlet",
  "level": 2,
  "display_name": "Hamlet",
  "requires": {
    "population": 3,
    "food_reserve": 8,
    "light_score": 16,
    "shelter_score": 12
  },
  "unlocks": {
    "population_cap": 8,
    "structures": ["basic_farm", "fence"],
    "research_domains": ["survival"]
  }
}
```

Example XP event shape:

```json
{
  "event_id": "enemy_defeated",
  "xp_type": "combat",
  "base_amount": 10,
  "scales_with": ["enemy_tier", "world_difficulty.enemy"],
  "also_awards": {
    "base_xp": 2
  }
}
```

## Implementation Notes

- Keep progression readable in the HUD, but avoid turning the game into a pure menu loop.
- Let physical building remain the source of truth for base progress.
- Let research depend on settlement support: workstations, subjects, light, food, safety, and samples.
- Avoid single-track progression. A builder, explorer, miner, defender, or ruler should all have viable paths.
- Tie boss rewards to new systems, not only stronger gear.
