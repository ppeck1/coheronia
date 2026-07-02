# Future Enemy Design Notes

Status: planned future implementation. These notes are design-confirmed material for later builds, but most of the content below is **not integrated as live gameplay yet**. Current v0.4 gameplay has the existing simple night slime pressure unit only.

## Existing Confirmed Enemies

| Enemy | Status | Primary Role |
|---|---|---|
| `surface_slime` | Design-confirmed | Early surface nuisance, basic crafting source |
| `cave_crawler` | Design-confirmed | Underground ambush enemy, chitin/silk source |
| `raider_basic` | Design-confirmed | Settlement raid unit targeting player, Town Hall, or subjects |

## Enemy Families

### 1. Surface / Ecological

Purpose:

- Pressure food production.
- Encourage fencing and storage.
- Supply early crafting materials.

Recommended:

- Surface Slime
- Thornrat
- Ash Wasp
- Mudling
- Hollow Stag

### 2. Underground

Purpose:

- Make mining preparation meaningful.
- Reward deeper exploration.
- Supply advanced crafting materials.

Recommended:

- Cave Crawler
- Ore Tick
- Lantern Leech
- Stoneback Beetle
- Sporekin
- Burrow Maw

### 3. Raider / Social

Purpose:

- Pressure settlement defense.
- Connect combat to governance.
- Drive city infrastructure.

Recommended:

- Raider Basic
- Raider Torchbearer
- Raider Sapper
- Hungry Deserter
- False Taxman

## Enemy Tables

### Surface

| Enemy | Location | Density | Major Drops |
|---|---|---|---|
| Surface Slime | Grass, ponds | 1-3 / 100 tiles | Slime Gel (70%), Wet Fiber (25%), Tiny Core (5%) |
| Thornrat | Grasslands, farms | 1-2 / 120 tiles | Meat, Thorn Quill, Hide Scrap |
| Ash Wasp | Burned forest | Nest / 250 tiles | Wax, Wings, Venom |
| Mudling | Swamps | 1-2 / 150 wet tiles | Clay, Mud, Reed Fiber |
| Hollow Stag | Deep forest | Rare | Venison, Hide, Antlers |

### Underground

| Enemy | Location | Density | Major Drops |
|---|---|---|---|
| Cave Crawler | Early caves | 2-4 / 100 cave tiles | Chitin, Silk, Eyes |
| Ore Tick | Ore veins | 1-3 / ore pocket | Ore Flecks, Shell |
| Lantern Leech | Cave pools | 1-2 / 180 tiles | Glow Gland, Oil |
| Stoneback Beetle | Stone caverns | 1 / 200-300 tiles | Stone Plates |
| Sporekin | Fungal caves | 2-5 / cluster | Spores, Fungal Thread |
| Burrow Maw | Mine shafts | 1 / 350-500 tiles | Teeth, Hide |

### Raiders

| Enemy | Purpose | Major Drops |
|---|---|---|
| Raider Basic | Early raids | Coins, Scrap Weapons |
| Torchbearer | Fire attacks | Oil Rags, Torch Heads |
| Sapper | Wall destruction | Picks, Fuse Cord |
| Hungry Deserter | Moral choice | Recruit opportunity |
| False Taxman | Governance event | Forged Seal, Coin |

## Mini Bosses

### Broodmother Crawler

- Underground nest.
- Summons cave crawlers.
- Destroying nest reduces local spawn density.
- Unlocks advanced chitin crafting.

Guaranteed:

- Brood Chitin

Possible:

- Eggs
- Silk Bundle
- Brood Venom
- Matriarch Eye
- Rare Nest Core

### Bandit Standard-Bearer

- Leads organized raids.
- Buffs nearby raiders.
- Influences future raid frequency.

Guaranteed:

- Torn War Banner

Possible:

- Orders
- Coin Pouch
- Fine Blade
- Captured Map

### Rotroot Boar

- Ancient forests.
- Destroys farms and fences.
- Encourages agricultural defenses.

## Major Bosses

### The Hollow King

Theme:

- Failed rulership.
- Collapse of authority.
- Governance under pressure.

Mechanics:

1. Summons hollow subjects.
2. Drains morale/resources.
3. Terrain destruction and darkness.

Major Rewards:

- Hollow Crown Fragment
- Royal Ledger
- Authority Sigil
- Crownstone Core

Unlocks:

- Advanced rulership systems.
- Civic upgrades.
- Governance mechanics.

### The World-Worm

Theme:

- Deep mining.
- Geological instability.
- Extraction consequences.

Mechanics:

- Tunnel collapse.
- Burrowing attacks.
- Earthquakes.

Unlocks:

- Deep mining.
- Reinforced foundations.
- Advanced masonry.

## World Density

| Region | Density |
|---|---|
| Safe Town | 0-1 / 150 tiles |
| Surface Wilderness | 1-3 / 100 |
| Forest | 2-4 / 100 |
| Swamp | 2-5 / 100 |
| Early Cave | 3-6 / 100 |
| Ore Cave | 4-7 / 100 |
| Deep Cave | 5-9 / 100 |
| Raider Camp | 4-10 |
| Early Raid | 2-5 |
| Mid Raid | 6-12 |
| Late Raid | 12-20 |

## Difficulty Scaling

| Difficulty | Density | Loot |
|---|---|---|
| Peaceful | 0.25x | 0.75x |
| Easy | 0.6x | 1.0x |
| Normal | 1.0x | 1.0x |
| Hard | 1.4x | 1.1x |
| Brutal | 1.8x | 1.25x |

## Loot Philosophy

- Common: 45-100%.
- Uncommon: 15-45%.
- Rare: 3-12%.

Rare drops should unlock optional systems, recipes, trophies, or upgrades rather than block progression.

## Recommended MVP Expansion Order

1. Surface Slime
2. Cave Crawler
3. Raider Basic
4. Thornrat
5. Ore Tick
6. Raider Torchbearer
7. Broodmother Crawler (mini boss)
8. Bandit Standard-Bearer (mini boss)

Future flagship bosses:

- The Hollow King
- The World-Worm
