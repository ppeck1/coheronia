# Coheronia Art Direction And Canon

Status: canon and visual-direction authority for FQ-09C and later art work.

This document distinguishes shipped mechanics from story interpretation and
planned possibilities. It must not be used to describe planned content as
already playable.

## Canon Status Legend

- **Hard canon**: the stable premise all future writing and art should respect.
- **In-world belief**: an interpretation held by settlers; it may remain
  mysterious rather than becoming an objective lore fact.
- **Live mechanic**: behavior that exists in the current game.
- **Planned possibility**: direction that may guide future work but is not live.

## Core Identity

**Hard canon:** Coheronia is the act of making a broken world coherent through
shelter, light, food, work, defense, and shared law.

It is not originally a lost kingdom waiting for its rightful monarch. It is a
founding principle that can become a settlement, a people, and eventually a
polity wherever scattered people build something capable of holding.

The player is a founder and may become a ruler by deeds. The player is not a
prophesied monarch and does not inherit a finished realm.

## Backstory v0.1

The old world did not end in fire. It unraveled.

Roads remained, but no longer led anywhere safe. Borders survived on maps
after they ceased to protect. Storehouses emptied, halls went dark, and old
oaths shrank to the reach of a single fire.

The scattered peoples carried what remained: craft, seed, iron, memory,
anger, and hope. Humans preserved civic memory and helped convene the first
hall. Dwarves carried stonecraft. Elves carried the old knowledge of living
systems. Orcs carried endurance and the discipline to hold contested ground.
Goblins carried salvage, traps, and the useful art of making broken things
serve again. No ancestry carried enough to endure alone.

The founding story begins with a hall—not a throne or temple, but a promise
with a roof. Around it came a hearth, a stockpile, a torchline, and the first
fragile laws of living together.

Where shelter, food, work, and courage aligned, the settlers felt the world
answer. Some called that answering pattern Attunement: the sense that broken
things still remembered how to belong.

Storms test every roof. Hunger tests every storehouse. Raiders test every
surplus. The dark measures every light.

Coheronia is not yet a kingdom.

It is the beginning of one.

## What Is Known And What Is Believed

**Live mechanic:** Coherence, Load, and Resilience are settlement-state values
computed from material conditions such as shelter, light, stock, population,
damage, scarcity, and threats. They are not decorative lore statistics.

**In-world belief:** Settlers disagree about whether coherence is only the
result of people organizing well or whether the world itself responds to that
order. The story may preserve this uncertainty.

**Live mechanic:** Attunement is the universal player magic resource and
currently powers a harmless light pulse. It is not rare, ancestry-exclusive,
or a replacement for food, roofs, tools, and defense.

## Gameplay-Fiction Mapping

| Gameplay state | Fictional meaning |
|---|---|
| Shelter and roofs | A maintained boundary between a people and exposure |
| Food and stockpiles | Trust made material; survival beyond the next hour |
| Torches and lanterns | Inhabited space, vigilance, and shared safety |
| Town Hall | The first civic anchor: a promise with a roof |
| Coherence | How successfully the settlement holds together now |
| Load | Hunger, darkness, damage, threats, weather, and social pressure |
| Resilience | The capacity to absorb a shock without coming apart |
| Attunement | Sensitivity to the remaining pattern beneath disorder |
| Caves | The unknown beneath the settlement and the cost of deeper reach |

## Ancestry Boundary

Use **ancestry** in all player-facing writing. `species` remains a legacy
compatibility key in code and persisted character data; it is not the preferred
fiction or UI term.

The live playable ancestries are Human, Dwarf, Elf, Goblin, and Orc. Deep
variants, Gnome, Lizardfolk, and Dragonkin are planned data, not live content.
Do not place planned ancestries in the opening prologue or present their art as
shipped.

Ancestries carry cultural traditions and survival knowledge, not moral
alignment. No ancestry is solely responsible for founding or saving Coheronia.

## Tone

- Hopeful under pressure.
- Material, tactile, and labor-centered.
- Frontier myth rather than glossy high fantasy.
- Civilization under load rather than stakes-free cozy decoration.
- Dangerous without grimdark nihilism.
- Sincere without parody or inflated prophecy.

A torchline is heroic. A roof is a civic and moral act. A stocked shelf can be
as meaningful as a sword.

## Visual North Star

**Mythic Frontier Pixel Diorama**

The game should resemble a small, living side-view world built from readable
pixel clusters and lit like a founding legend. The highest contrast belongs to
actors, interactable objects, danger, and maintained light. Scenery supports
those subjects with lower saturation and contrast.

## Production Rules

- World blocks, item icons, and current enemy sprites: 16 x 16 pixels.
- UI icons: 32 x 32 pixels.
- Prologue panels and full-scene background masters: 640 x 360 pixels,
  integer-scaled 2x to the current 1280 x 720 viewport.
- Use nearest-neighbor scaling and crisp integer pixel clusters.
- Preserve a consistent side-view horizon and light direction within each
  environment family.
- Use a limited family palette and a consistent one-pixel outline policy.
- Judge every gameplay sprite at 100% zoom, not only enlarged.
- Keep scenery quieter than foreground actors and interactables.
- Render all text in Godot UI. Never bake dialogue, labels, the title, or
  `By Paul Peck` into generated images.
- Never rely on color alone to communicate gameplay state.

## Palette Roles

| Role | Palette family | Meaning |
|---|---|---|
| Maintained civilization | amber, warm parchment, restrained brass | hearths, lamps, inhabited rooms, civic UI |
| Exposure and unknown space | indigo, blue-black, cool slate | night, storms, cave openings, distance |
| Attunement insight | star-white, pale cyan, muted violet | brief lines, pulses, constellations, remembered pattern |
| Material world | moss, loam, timber, stone, iron | work, shelter, terrain, tools, settlement growth |
| Danger | controlled rust, bruised red, sickly accents | threats and damage without overwhelming the full palette |

Attunement should look as though the world is briefly remembering how to hold
together. Use lines, pulses, linked points, hearth-light, and restrained
constellation geometry—not generic fireballs or neon bloom.

## Environment Planes

Future environment rendering must keep three planes distinct:

1. **Scenic backdrop** -- sky, distant terrain, silhouettes, and optional
   parallax. It is cosmetic, non-colliding, and never mined or saved.
2. **Backing walls** -- Terraria-style rear tiles behind foreground cells.
   They visually establish caves and constructed rooms and participate in the
   daylight/underground rule. Natural walls should be deterministic. A later
   construction slice may make walls placeable, removable, and persisted.
3. **Foreground blocks** -- the current world `cells`: mined, placed,
   colliding where defined, and saved through terrain deltas.

Do not revive the retired FQ-02 `BackgroundFlora`, `background_cells`,
`bg_trunk`, or `bg_canopy` model. Trees remain unified foreground world cells
under the FQ-09R rule.

A background image alone does not fix underground daylight. Surface ambient
light should belong to sky-exposed space; caves and wall-backed rooms require
dark ambient treatment plus local torch, lantern, and Attunement light.

## Repeated Motifs

- founding hall
- promise with a roof
- hearth and shared fire
- stockpile
- torchline
- broken road or map
- cave mouth
- first beam and foundation stone
- constellation or linked points

## Avoid

- glossy mobile-game fantasy
- neon science-fiction UI
- generic fireball magic
- excessive skulls or grimdark decay
- painterly noise that destroys pixel readability
- tiny overdesigned armor silhouettes
- random style changes between asset families
- text baked into generated art
- presenting planned ancestries or systems as live
