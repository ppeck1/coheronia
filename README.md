# Coheronia — Systems-Driven Survival Settlement Sandbox

**A portfolio case study in data-driven Godot architecture, verified gameplay systems, and AI-orchestrated engineering.**

Dig, build, and light a side-view frontier settlement — then keep it alive as a tiny civilization sim scores your shelter, food, light, and defenses in real time and answers with settlers, raids, and storms.

![Daytime settlement with the Town Hall, torch line, and live HUD](docs/screenshots/01_settlement_day.png)

`Godot 4.6 · GDScript · data-driven design · 346-check in-engine smoke suite · adaptive music · layered image-first UI pipeline`

## What it is

Coheronia sits between a survival sandbox and a civilization pressure sim. Minute to minute you mine tunnels, roof the hall, place torches, and haul food home. The settlement model turns those physical acts into three live pressures — **Coherence, Load, and Resilience** — computed from real world state (shelter blocks, light sources, stockpile, threats), never faked. A coherent, fed, lit settlement attracts settlers and ratchets from Camp to Hamlet to Village; a neglected one starves, empties, and cracks under night raids and storms.

It is also a **portfolio project in AI-orchestrated software engineering**: every increment is scoped in a task queue, implemented against explicit data authorities, reviewed independently, and checked in-engine. The repository exposes both the playable architecture and the evidence trail: state ownership, validation commands, variable matrix, handoff, and an inspectable project wiki.

## Portfolio lens

| Architecture concern | Concrete implementation | Evidence in this repository |
|---|---|---|
| **Simulation from world state** | Shelter, light, stockpile, threats, and population feed Coherence, Load, and Resilience. | [`scripts/settlement/`](scripts/settlement) · [`docs/VARIABLE_MATRIX.md`](docs/VARIABLE_MATRIX.md) |
| **Persistent state ownership** | Characters own inventory, loadout, and progression; worlds own terrain deltas and settlement simulation. | [`scripts/shell/`](scripts/shell) · [`scripts/inventory/`](scripts/inventory) |
| **Data-first design** | Blocks, recipes, enemies, equipment, ancestries, and world presets are JSON authorities. | [`data/`](data) · [`scripts/validate_repo.py`](scripts/validate_repo.py) |
| **Runtime UI composition** | HUD chrome is separate from live values; inventory mutations are validated at the UI boundary. | [`scripts/ui/hud.gd`](scripts/ui/hud.gd) · [`scripts/ui/inventory_slot_cell.gd`](scripts/ui/inventory_slot_cell.gd) |
| **Verification as a feature** | Validators and an in-engine smoke harness exercise saves, physics, UI, and system contracts. | [`docs/HANDOFF.md`](docs/HANDOFF.md) · [`scripts/main/smoke_test.gd`](scripts/main/smoke_test.gd) |

## Screenshots

*Captured 2026-07-23 from the live build.*

| | |
|---|---|
| ![The unified crafting panel opened with C](docs/screenshots/15_crafting.png)<br>*Press **C** for the unified crafting panel — every recipe grouped by source (Hand, Town Hall, and each built station), with have/need per input and Build rows for stations you haven't raised yet* | ![Town Hall panel with deposit, status, and repair](docs/screenshots/04_town_hall.png)<br>*The Town Hall now keeps deposit, settlement status, and structural repair; crafting and station building moved to the crafting panel* |
| ![Night falls — torch light holds the line](docs/screenshots/02_night_torchlight.png)<br>*Night, torchlight, and real-time light occlusion* | ![World creation with size, seed, preset, and rule controls](docs/screenshots/08_world_create.png)<br>*World creation exposes size, seed, preset, difficulty, generation, and rule toggles — all data-driven* |
| ![The inventory board with loadout, backpack, and dock](docs/screenshots/03_inventory.png)<br>*Open the inventory with **I** to drag and drop carried stacks, dock assignments, and compatible equipment; use **Sort** to organize the backpack* | ![Runtime-driven health and attunement vessels at partial charge](docs/screenshots/10_vessel_damage_states.png)<br>*The native HUD keeps vessel fills, values, slots, icons, counts, and actions live at runtime* |
| ![Character panel showing the composed figure and all equipment slots](docs/screenshots/13_character.png)<br>*The Character panel is rebuilt on runtime children — the composed figure renders through the same `PlayerVisual` the world draws, beside live identity, status, and all 13 equipment slots* | ![Viewport-relative skill constellation tree](docs/screenshots/05_skill_tree.png)<br>*The skill tree is a viewport-relative star map that scales from 640×360 to 1280×720; nodes, prerequisites, and perk spending come straight from JSON* |
| ![Character creation with a live composed preview](docs/screenshots/07_character_create.png)<br>*Character creation shows a live figure through the shared render path — what you pick is what you get — in a scrolling form with a pinned Create/Back action row* | ![Underground at midday held back by torchlight](docs/screenshots/09_underground_midday_torch.png)<br>*Roof-aware cave darkness: dig deep and daylight stays behind you unless you open a shaft; torches hold the dark off locally* |

*The in-world sprites, every current inventory/live-drop icon, all six live enemy families, all ten player bodies, the Town Hall, parallax backdrops, eight opening-scene cel pools, and 120 body-specific crude-gear/tool overlays are real generated pixel art. High-repetition terrain, flora, ores, enemies, and player bodies also have runtime-selected visual pools. Missing or unresolved images keep a procedural fallback, while the primary dock uses a 19-asset layered kit whose runtime values and states remain separate from its PNG chrome.*


## 📖 Prologue

[![Coheronia Prologue](https://img.youtube.com/vi/QQ2BuoXqErk/maxresdefault.jpg)](https://youtu.be/QQ2BuoXqErk)

Watch the opening cinematic and story introduction.

Direct link: [prologue](docs/screenshots/clips/coheronia.prologue.07162026.1125.mp4) 


## 🎮 Gameplay

[![Coheronia Gameplay](https://img.youtube.com/vi/KoWppfdjSX8/maxresdefault.jpg)](https://youtu.be/KoWppfdjSX8)

Watch the latest gameplay demonstration: [https://youtu.be/KoWppfdjSX8](https://youtu.be/KoWppfdjSX8)

> The screenshots on this page (captured 2026-07-23) are the definitive reference for the current interface — the native HUD and inventory board, the unified crafting panel, the repair-only Town Hall, the rebuilt Character panel, the viewport-relative skill tree, and the contour backdrop.

---

## Explore the build wiki

[Open the Coheronia Wiki](docs/wiki/wiki.md) for the repo-backed reference on live systems, inventory and crafting routes, HUD asset rules, image coverage, planned data, and known limitations. For a portfolio presentation with the visual wiki embedded, visit [Coheronia on ppeck.me](https://ppeck.me/projects/coheronia/). GitHub renders this Markdown entrypoint directly; the repository also includes a richer local [visual wiki wrapper](docs/wiki/index.html).

## Feature highlights

- **Persistent shell and inventory** — characters and worlds are separate persistent objects. Characters own their backpack, dock layout, hotbar selection, tools, and 12 gear slots and carry them between worlds; the openable **I** inventory board supports drag-and-drop backpack/dock organization, compatible equipment swaps, unequipping back to the backpack, item detail, sorting, and the five-slot dock while each world file owns its terrain history, settlement, threats, and progression.
- **Deterministic, configurable world generation** — seed + settings always produce the same world: terrain amplitude/frequency, ore/tree/bush density on independent seed channels, three world sizes, and unified leafy trees the player walks in front of and harvests for wood, so the surface stays walkable.
- **Survival loop with teeth** — hardness-timed mining with crack-stage feedback, tool tiers (forged pick, axe, crude sword and armor with flat mitigation), a metallurgy chain that smelts depth-banded ores into ingots at the furnace and forges iron gear at the anvil, berry bushes that need soil and regrow, plantable farming (till soil, sow seeds, ripen, harvest food) as a reliable food path, food, health, i-frames, collapse penalties, and passive recovery near the hall.
- **A settlement that reacts** — day/night cycle, night threats scaled by six difficulty axes, raiders drawn to fat stockpiles (plus torchbearers that burn the hall faster), crop-eating thornrats that pressure your farms and ore ticks that cling to the veins, cave crawlers underground, storms mitigated by real roof coverage, population 1–8 that eats, leaves, and arrives based on computed Coherence.
- **A world with depth** — a parallax scenic backdrop behind everything, natural backing walls revealed by mining (deterministic from the seed, provably unable to affect collision or lighting), and roof-aware cave darkness at any hour: dig deep and the daylight stays behind you unless you open a shaft to the sky, while your torches hold the dark off locally.
- **An adaptive score** — one original suite composed as a single piece in four states (day, night, underground, crisis) plus six phase-locked stems, switching seamlessly at the next musical bar from real game state: pressure builds it toward crisis with hysteresis so the music never thrashes, the hearth harmony swells with settlement Coherence, the work pulse follows your pick, the fracture layer wakes only at the collapse edge — and it all crossfades home when the settlement holds. Event stingers (dawn, nightfall, raid, attunement, base advance) ring out over a brief music-bus duck without ever stopping the score, Music/Sound sliders on the title screen set the runtime buses, and the whole director keeps breathing through pause. Native Godot `AudioStreamInteractive` + `AudioStreamSynchronized` — no middleware.
- **Progression stack** — six XP types feed player levels; levels grant perk points spent in a visual skill tree; base levels gate population; Attunement (the magic resource) regenerates and powers a first light-pulse ability, with ancestry/equipment/perk hooks already live.
- **Animated opening cinematic** — an eight-scene, ~42s founding myth plays before the title on first launch (any key advances, Esc skips, replayable from the menu): a DOS-style plotted world with keyframed puppet acting — roads unravel, the five peoples gather at a fire, builders raise the first hall beam by beam, the founder kneels and the world answers — rendered entirely in code at 640×360 with hard camera cuts and engine-rendered text: *COHERONIA · By Paul Peck · Where civilization pushes back.*
- **Learns as you play** — a compact, state-driven goal panel walks the first loop (gather → light the hall → deposit → forge a tool/build a station → survive the night) from real game state, not scripted tutorial text: it advances only when you actually do the thing, never regresses, re-derives the right step after a save/reload, and tucks away with a keypress (**O**).
- **Scoutable world** — a schematic map panel (**M**) reveals the world band by band *as you explore* — nothing is X-rayed. It marks the Town Hall, your position, ore pockets, and live enemy pressure inside scouted bands only; discovered regions persist compactly in the world save, and the explorer "Biome Reveal" perk widens each step's scouted band. Map and Events are independent movable modules and can remain open together.
- **Authored visual coverage with real variety** — all data-referenced blocks, inventory/live-drop icons, and live enemies now have canonical pixel art; seventeen high-repetition block ids carry three deterministic per-cell looks, every enemy family carries three lifetime-stable looks, and every player body offers two authored alternatives beyond its canonical form. Items deliberately stay canonical-only so a stack never changes icon during a refresh.
- **Everything is data** — blocks, recipes, enemies, 12 ancestries, XP curves, base levels, perk lanes, equipment, world presets, and item metadata are JSON authorities validated by a repo linter; most balance changes never touch code.

## Characters are data

A character is a persistent object that outlives any single world, and it is
defined entirely in JSON — the creation screen above is just a view onto these
files. Three authorities drive it:

- **[`data/character_data.json`](data/character_data.json)** — the creation
  contract: player tuning defaults, the five playable species, body variants,
  the trait pool (pick up to two), starter roles, and skin/trim appearance
  palettes.
- **[`data/ancestries.json`](data/ancestries.json)** — twelve ancestry
  definitions with lore, effect keys, spawn bands, and biome affinities; the
  five above are live and playable, the rest are validated data awaiting their
  phases (deep variants, gnome, lizardfolk, dragonkin).
- **[`data/player_visuals.json`](data/player_visuals.json)** — the 16×32 body
  rig: per-species skin palettes and regions, appearance recolor, and the
  optional gear/tool-swing overlay conventions.

A trait, a role, and a body rig look like this — no code changes to add or
tune one:

```jsonc
// data/character_data.json
{ "id": "miner", "display_name": "Born Miner",
  "description": "+20% mining speed.", "effects": { "mine_speed_mult": 1.2 } }

{ "id": "homesteader", "display_name": "Homesteader",
  "description": "Starts with building materials.",
  "starting_items": { "dirt": 10, "wood": 5 } }

// data/player_visuals.json — the dwarf body rig
"dwarf": {
  "skin_palette": ["f3ab36", "ca811c"],
  "skin_regions": [[6, 8, 6, 5], [1, 18, 4, 7], [10, 18, 4, 7]],
  "shoulder": [5, -3], "torso_size": [12, 8], "feet_width": 5
}
```

Characters own their backpack, hotbar, tools, 12 equipment slots, ancestry,
role, and traits and carry them between worlds; each world file owns its
terrain history, settlement, and progression. Persistence lives in
`user://shell.json` (profile + characters), separate from
`user://worlds/<id>.json`.

## The engineering story

This repo doubles as an experiment in disciplined AI-driven development:

- **Self-verifying build.** A smoke suite runs the *real game* — real input map, real physics, real saves — and asserts 346 checks across mining, save/load round-trips, legacy migrations, UI panel contents, Map/Events coexistence, HUD-kit layering, physics traversal, armor math, adaptive-music transitions, the character-rendering contract, body-specific gear resolution and alignment, directional action animation, the shared-path creation/character-select preview, the runtime-children Character panel, the backdrop contour skirt, the viewport-relative skill panel, and event stingers. The full suite is at **346/346** on 2026-07-21 (the real-time `fq09u1_live_clip_switch` adaptive-music check occasionally cold-flakes and passes on rerun; the `fq19_map_events_coexist` geometry check is sensitive to a contaminated persisted `shell.json` and passes from a clean profile).
- **Evidence over claims.** Increment scope, decisions, review findings, and validation state are summarized in [`docs/HANDOFF.md`](docs/HANDOFF.md). Historical raw protocol artifacts are still tracked; their fit with the current public-repository profile is explicitly flagged for owner review rather than silently presented as settled policy.
- **Independent review loop.** Each change was reviewed by a separate agent pass before commit; findings (from save-corruption edge cases to invisible-tint rendering bugs) are documented and fixed in the ledgers.
- **Task queue discipline.** Work follows [`docs/FABLE_TASK_QUEUE.md`](docs/FABLE_TASK_QUEUE.md) one bounded increment at a time — FQ-00 through FQ-09 plus the FQ-09R/S/V/C/W/A/M and U0–U3 refinements (skill-tree star map, variant art pools, the opening cinematic, backdrops and cave darkness, the asset roadmap, action effects, and the full adaptive-music arc) on top of the v0.1–v0.6 foundation, each documented in [`docs/HANDOFF.md`](docs/HANDOFF.md) and [`docs/VARIABLE_MATRIX.md`](docs/VARIABLE_MATRIX.md).

## Run it

Requires [Godot 4.6+](https://godotengine.org/). No plugins, no imports, no build step.

```powershell
& <path-to-godot-4.6> --path <this-repo-root>
```

Or open the folder in the Godot editor and press Play.

| Action | Input |
|---|---|
| Move / jump | A/D or arrows · Space |
| Mine / hit | Hold left mouse |
| Place block | Right mouse |
| Hotbar | 1–5 |
| Town Hall | E or T |
| Inventory / Skill tree | I / K |
| Goals / Map | O / M |
| Eat food / Attunement pulse | H / R |
| Craft torch | C |
| Save / Load | F5 / F9 |
| Save & exit to shell | Esc |

**Verify the build** (validators + the 346-check in-engine suite):

```powershell
python scripts/validate_repo.py
python scripts/asset_audit.py --strict
python scripts/art/sync_hud_kit.py --verify-runtime
python scripts/art/verify_gear_alignment.py
python _protocol/Project_Ops_Capsule/scripts/capsule_doctor.py . --profile public_repo

$env:COHERONIA_SMOKE = "1"
Start-Process -FilePath "<path-to-godot-4.6>" -ArgumentList @("--path", "<this-repo-root>") -Wait
# results: user://smoke_results.json
```

**Regenerate the README screenshots** (staged capture tour — 15 shots across the shell and gameplay tours, including the character-create screen at 1280×720 and 640×360; run windowed, not `--headless`, so the frame capture resolves):

```powershell
$env:COHERONIA_SHOTS = "1"
Start-Process -FilePath "<path-to-godot-4.6>" -ArgumentList @("--path", "<this-repo-root>") -Wait
# shots land in user://shots/ (Windows: %APPDATA%\Godot\app_userdata\Coheronia\shots)
# then copy the keepers into docs/screenshots/
```

## Architecture at a glance

```text
data/*.json ───────► registries / validators ───────► world, player, settlement systems
                                                    │
shell profile ───► character state ───► inventory / equipment / dock ───► runtime HUD
                                                    │
world save ──────► terrain deltas + simulation ────┴──► smoke harness + evidence docs
```

```text
scenes/shell + scripts/shell     persistent shell: characters, worlds, world builder
scenes/main  + scripts/main      game root (day/night, storms, threats, progression),
                                 smoke suite, screenshot tour
scripts/world                    deterministic generation, block grid, lighting,
                                 data-authority registry
scripts/player                   movement, mining, combat, equipment, attunement, perks
scripts/settlement               Town Hall + the Coherence/Load/Resilience model
scripts/ui                       layered HUD-kit assembly, movable modules,
                                 icon-grid panels, skill tree
data/*.json                      the actual game design: blocks, recipes, enemies,
                                 ancestries, progression, equipment, presets, items
docs/                            handoff, variable matrix, task queue, future design
.project/                        historical protocol records; public-profile
                                 governance review is pending
```

Persistence: `user://shell.json` (profile + characters) and `user://worlds/<id>.json` (one file per world: config + terrain deltas + simulation state).

## Roadmap

The full adaptive-music arc, the opening cinematic, and the first real art pass
are done; the active queue ([`docs/FABLE_TASK_QUEUE.md`](docs/FABLE_TASK_QUEUE.md))
continues in bounded increments:

- **Shipped since the last art pass** — **FQ-10–15** added ore families, metallurgy stations, farming, three pressure-specific enemies, deterministic visual pools, the state-driven goal panel, and persistent scouting. **FQ-16–21** added the player-state dock, movable HUD modules, dock navigation, runtime vessels, and several painted-chrome experiments; the native 19-asset HUD kit supersedes the fragile sliced-band path, keeps Map and Events independent, and retains the older constructions only as fallbacks. The **presentation recovery arc (PR-00–PR-08)** then completed the code lane: harness truth repair, masculine/feminine terminology, the character-rendering contract, gear resolution/alignment, directional action animation, the shared-path creation/character-select preview, the runtime-children Character panel, the backdrop contour skirt, and the viewport-relative skill panel. The **Release Foundations arc (R-00–R-07)** hardened the project for release — export-safe resource loading, atomic saves, isolated verification, pinned CI that builds *and launches* the exported artifact, public-repo cleanup, and a **playability baseline**: pause/settings/keybinds, save-slot management with delete confirmation and in-game restore, a build-preview placement ghost with reasoned invalid-placement feedback, and a unified crafting panel with the Town Hall trimmed to repair. **R-08** then began the subject-labor MVP with a first **visible farmhand settler** that roams near the Town Hall, harvests ripe crops into the stockpile, and idles hungry when the settlement runs out of food.
- **Next up** — the rest of the subject-labor MVP (hauler/repairer jobs, multiple subjects, assignment), then a data-defined contracts and balance layer on the goal system.
- **More enemies** from a 16-entry design roster (mini-bosses and the hollow_king / world_worm bosses remain), each landing with its gameplay consumer.
- **Art backlog** — polish the current HUD chrome one contract-safe PNG at a time via the [`HUD Asset Replacement Studio`](docs/wiki/hud_asset_replacement_studio.md); extend body-specific gear beyond the currently covered crude armor, pick, and axe families; refine action poses; and expand opening-scene animation only where it improves the existing authored cel pools.
- **Deeper systems** sketched in [`docs/FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md`](docs/FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md): the research bench MVP, perk-spending across more lanes, underground-start generation for deep ancestries, and the civic layer (laws, districts, factions, legitimacy). Ancestries beyond the five playable ones exist as validated data awaiting their phases.

## Known issues and limitations

- **Gear overlays resolve and align (PR-03A + PR-03B).** The repository ships 120 body-specific PNGs for crude helmet/torso/feet overlays and three-phase basic-pick, forged-pick, and crude-axe swings. These *resolve* against the character's *effective body id* — the resolved body when one loaded, otherwise the intended body — so authored gear stays visible across character/load/world-transition/forge refresh paths instead of dropping to the procedural fallback; a `refresh_presentation()` hook re-resolves at the equip/forge boundaries. Overlay *placement* is corrected by a data-owned per-rig `gear_offset` that nudges the goblin/dwarf crude helmet onto the head (aligned bodies stay put); `scripts/art/verify_gear_alignment.py` enforces helmet/head contact. Action animation (PR-04) now plays a data-driven windup→impact→recovery swing aimed at the target — up/down/diagonal, not only rightward — with per-item `action_profile` timing, and the sword animates through the same contract via a presentation-only attack swing; smoother authored swing frames remain an art-lane item. See `docs/CHARACTER_RENDERING_CONTRACT.md` and the known-issues page.
- **Tool and weapon motion needs another pass.** Pick and axe art currently snaps through three authored poses. The anchors, arc continuity, mirroring, and timing need polish, and the sword does not yet have an equivalent authored attack sequence.
- **The HUD architecture is stabilized, but the art is provisional.** The primary dock now separates static chrome from runtime values and uses JSON-owned native geometry. Some framed panel states still show padding, masking, or oversized opaque-region defects, particularly in automated captures; the legacy painted/sliced constructions remain fallback code, not the target design.
- **Full smoke is green (376/376 source; the exported artifact launches and runs 370/370, with six `res://`-fixture checks skipped only under read-only export, 2026-07-23).** The **presentation recovery arc's code lane (PR-00 through PR-08) is complete**, tracked in `docs/PRESENTATION_RECOVERY_MATRIX.md`: smoke-harness truth repair; masculine/feminine terminology migration; the character-rendering contract; gear-overlay resolution and alignment; directional action animation; the shared-path creation/character-select preview (what you pick is what you get); the Character panel rebuilt on runtime children through that same render path; a backdrop contour skirt that follows the per-column surface so the distant scenery meets the terrain with no seam; and a viewport-relative skill panel — plus a character-create form that scrolls with a pinned Create/Back action row. The two remaining arc rows are non-code: later skill-lane expansion (deferred) and HUD chrome/image production (art lane). Two runtime notes: the real-time `fq09u1_live_clip_switch` music check occasionally cold-flakes and passes on rerun, and `fq19_map_events_coexist` is sensitive to a contaminated persisted `shell.json` and passes from a clean profile.
- **Several systems remain partly abstract.** Beyond the first visible farmhand settler (R-08 slice 1), the settlement is still driven by an abstract population count rather than individual NPCs — the visible subject is layered on top of that unchanged model, which stays the single food-accounting authority so a settler is never charged food twice. Enemies walk and hop without pathfinding; the adaptive score is one suite still being balanced; and current finite maps have one surface biome.

---

*Built with the Project Ops Capsule protocol: every run records evidence; only signable runs update accepted truth.*
