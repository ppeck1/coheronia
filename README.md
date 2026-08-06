# Coheronia — Systems-Driven Survival Settlement Sandbox

Dig, build, and light a side-view frontier settlement — then keep it alive as a tiny civilization sim scores your shelter, food, light, and defenses in real time and answers with settlers, raids, and storms. Visible citizens with their own ancestries, names, and stats farm, haul, repair, and **defend** the settlement, working against the same world you dig.

![Daytime settlement with the Town Hall, torch line, and live HUD](docs/screenshots/01_settlement_day.png)

`Godot 4.6 · GDScript · data-driven design · procedural world depths · leveled liquid physics · adaptive music · 532-check in-engine smoke suite`

> **New here?** Start with **[🎮 For players](#players)** below — the core loop, the controls, and what everything does.

Pick the section that fits you:

- **[🎮 For players](#players)** — how to run it, the controls, the loop, and a look at the world.
- **[🛠️ For developers](#developers)** — architecture, data authorities, the repo layout, and how to build & verify.
- **[🧭 How it's built](#how-its-built)** — the engineering approach, verification, and evidence trail.
- **[📓 Changelog](#changelog)** · **[🗺️ Roadmap](#roadmap)** · **[⚠️ Known issues](#known-issues)**

---

<a name="players"></a>
<details open>
<summary><h2>🎮 For players</h2></summary>

### What it is

Coheronia sits between a survival sandbox and a civilization pressure sim. Minute to minute you **mine tunnels, roof the hall, place torches, and haul food home**. The settlement quietly grades everything you build into three live pressures — **Coherence, Load, and Resilience** — computed from the real world (shelter blocks, light sources, stockpile, threats). A coherent, fed, lit settlement attracts settlers and grows from **Camp → Hamlet → Village**; a neglected one starves, empties, and cracks under night raids and storms.

Dig straight down and the world becomes a **vertical descent** — stone, then deepstone, then a **hell biome** of hellstone, obsidian, and pooled **lava** that flows, glows, and burns. Water flows too, fills lakes, and turns lava into obsidian on contact. Swim in it, drown in it, scoop it into a bucket.

### Run it

Requires [Godot 4.6+](https://godotengine.org/). No plugins, no imports, no build step.

```
<path-to-godot-4.6> --path <this-repo-root>
```

Or open the folder in the Godot editor and press **Play**. On first launch a short animated prologue plays — press any key to advance, **Esc** to skip.

### Controls

| Action | Key(s) |
|---|---|
| Move left / right | **A** / **D**  (or **←** / **→**) |
| Jump · swim up in liquid | **Space**  (hold to swim up) |
| Mine block · attack enemy | **Left mouse**  (hold) |
| Place block · use held item (bucket, sapling, door) | **Right mouse** |
| Farm — till soil, plant a seed, harvest | **G** |
| Select hotbar slot | **1 – 9** |
| Interact — Town Hall, doors | **E** |
| Town Hall panel | **T** |
| Inventory | **I** |
| Crafting | **C** |
| Skills (your Calling) | **K** |
| Map | **M** |
| Goals | **O** |
| Eat food | **H** |
| Attunement pulse (light ability) | **R** |
| Swap weapon | **W** |
| **Zoom the view in / out** | **Mouse wheel**, or **+** / **−** |
| **Fullscreen** | **F11** |
| Quick save · load | **F5** / **F9** |
| Pause — settings, keybinds, save, restore, quit | **Esc** |

**Esc** opens a real pause menu (it closes an open panel first). Its **Settings** screen holds **View Zoom** and **Fullscreen** toggles, Music/SFX volume, and full keyboard **rebinding** — all saved to your profile. Prefer more of the map on screen? Scroll out, or drag the **View Zoom** slider.

### The first loop

The in-game **Goals** panel (**O**) walks you through it from real progress — it only advances when you actually do the thing:

1. **Gather** wood and stone (hold **Left mouse** on trees and rock).
2. **Light the hall** — craft torches (**C**) and place them (**Right mouse**).
3. **Deposit** resources at the Town Hall (**E** / **T**).
4. **Forge a tool or build a station** at the crafting panel (**C**).
5. **Survive the night** — threats scale after dark; torches, walls, and a defender hold the line.

### A look at the world

| | |
|---|---|
| ![Night, torchlight, and real-time light occlusion](docs/screenshots/02_night_torchlight.png)<br>*Night falls — torchlight holds the line* | ![Deep underground in the hell biome beside a glowing lava lake](docs/screenshots/19_hell_biome.png)<br>*Dig deep enough and you reach the hell biome — hellstone, obsidian, and pooled lava* |
| ![A generated above-ground pond reading as one calm body of water](docs/screenshots/23_water_surface_lake.png)<br>*Water flows and fills lakes* | ![The player submerged in a water pool with the Breath gauge draining](docs/screenshots/26_swim_breath.png)<br>*Swim below the surface and your Breath gauge drains — surface before it runs out* |
| ![A visible farmhand settler harvesting a row of ripe crops](docs/screenshots/16_farmhand.png)<br>*A visible farmhand works the land and stocks the larder* | ![The settler info panel showing name, role, days alive, and stats](docs/screenshots/37_settler_panel.png)<br>*Click any settler to see its name, ancestry, job, and stats* |
| ![The unified crafting panel opened with C](docs/screenshots/15_crafting.png)<br>*Press **C** — every recipe grouped by station, with have/need per input* | ![The inventory board with loadout, backpack, and dock](docs/screenshots/03_inventory.png)<br>*Open the inventory with **I** — drag and drop stacks, gear, and the hotbar dock* |
| ![The Calling skill panel shown as two Path cards](docs/screenshots/05_skill_tree.png)<br>*Your **Calling** (**K**) — two Paths of tiered skills, every one wired to a real effect* | ![World creation with size, seed, preset, and rule controls](docs/screenshots/08_world_create.png)<br>*Create a world — size, seed, preset, difficulty, and rule toggles* |

### What you can do

- **Mine, build, and light** a side-view world with hardness-timed mining, crack-stage feedback, tool tiers, and torches/lanterns that carve real light out of the dark.
- **Descend** through deterministic strata into caves and a hell biome; **lava and water** flow as real fluids, fill lakes, react into obsidian, and can drown or burn you.
- **Grow a settlement** that reacts: a day/night cycle, night raids drawn to fat stockpiles, crop-eating thornrats, cave crawlers, storms mitigated by real roof coverage, and a population that arrives and leaves based on how well you're doing.
- **Assign settlers** to four jobs — **farmhand**, **hauler**, **repairer**, and **defender** — and give any of them a work zone to tend.
- **Craft a full gear ladder** — crude → bronze → iron → deep obsidian/hellstone weapons and armor, plus silver/crystal rings and an ember amulet — by smelting depth-banded ores at the furnace and forging at the anvil and workbench.
- **Farm** a renewable food supply (till soil, sow seeds, harvest, replant) and a **renewable forest** (plant tree seeds that grow back).
- **Grow your character** across a permanent **Calling** (Oathbound, Wayfarer, or Runewright) with two Paths of tiered skills, plus scouting, an attunement light-pulse, and directed **Contracts**.

### Watch it

**📖 Prologue** — the opening cinematic and story intro:

[![Coheronia Prologue](https://img.youtube.com/vi/QQ2BuoXqErk/maxresdefault.jpg)](https://youtu.be/QQ2BuoXqErk)

**🎮 Gameplay** — the latest gameplay demonstration: [youtu.be/ydgF0356CXw](https://youtu.be/ydgF0356CXw)

</details>

---

<a name="developers"></a>
<details>
<summary><h2>🛠️ For developers</h2></summary>

Coheronia is a data-driven Godot 4.6 project: blocks, recipes, enemies, equipment, ancestries, progression, and world presets are JSON authorities, and the systems read from them. State ownership is explicit, and an in-engine smoke harness exercises the real game.

### Architecture at a glance

| Concern | Implementation | Where |
|---|---|---|
| **Simulation from world state** | Shelter, light, stockpile, threats, and population feed Coherence, Load, and Resilience — computed from real world state, never faked. | [`scripts/settlement/`](scripts/settlement) · [`docs/VARIABLE_MATRIX.md`](docs/VARIABLE_MATRIX.md) |
| **Visible subject simulation** | A bounded citizenry with four assignable jobs works against the same world/stockpile authorities as the aggregate sim; the abstract population stays the single food-accounting authority, so a settler is never charged food twice. | [`scripts/entities/subject.gd`](scripts/entities/subject.gd) · [`scripts/world/world.gd`](scripts/world/world.gd) |
| **Persistent state ownership** | Characters own inventory, loadout, and progression (they carry between worlds); worlds own terrain deltas and settlement simulation. | [`scripts/shell/`](scripts/shell) · [`scripts/inventory/`](scripts/inventory) |
| **Data-first design** | Blocks, recipes, enemies, equipment, ancestries, and world presets are JSON authorities validated by a repo linter; most balance changes never touch code. | [`data/`](data) · [`scripts/validate_repo.py`](scripts/validate_repo.py) |
| **Procedural world depths** | Deterministic terrain from a seed: fraction-based strata (stone → deepstone → hell), a mixed cavern/tunnel carve pass, lava/water as data-driven blocks. Saves store `world_seed` + player edits only; a `gen_version` stamp keeps existing worlds byte-identical as the generator evolves. | [`scripts/world/world_gen.gd`](scripts/world/world_gen.gd) · [`data/world_settings.json`](data/world_settings.json) |
| **Leveled liquid physics** | Lava and water flow as a deterministic, mass-conserving cellular automaton: per-cell fill level, pour-down/equalize-sideways, sleep-when-settled, partial-fill rendering, a lava+water→obsidian reaction, and a scoop/pour bucket. Generated liquid is sealed in rock (mine to release). | [`scripts/world/fluid_sim.gd`](scripts/world/fluid_sim.gd) · [`data/blocks.json`](data/blocks.json) |
| **Runtime UI composition** | HUD chrome is separate from live values; inventory mutations are validated at the UI boundary. | [`scripts/ui/hud.gd`](scripts/ui/hud.gd) · [`scripts/ui/inventory_slot_cell.gd`](scripts/ui/inventory_slot_cell.gd) |
| **Verification as a feature** | Validators and an in-engine smoke harness exercise saves, physics, UI, and system contracts. | [`docs/HANDOFF.md`](docs/HANDOFF.md) · [`scripts/main/smoke_test.gd`](scripts/main/smoke_test.gd) |

### Characters are data

A character is a persistent object that outlives any single world, defined entirely in JSON — the creation screen is a view onto these files. No code changes to add or tune a trait, a Calling, or a body rig:

```jsonc
// data/character_data.json
{ "id": "miner", "display_name": "Born Miner",
  "description": "+20% mining speed.", "effects": { "mine_speed_mult": 1.2 } }

{ "id": "oathbound", "display_name": "Oathbound",
  "description": "Sworn defender of the settlement.",
  "paths": ["warden", "vanguard"],
  "innate": { "name": "Resolve",
              "description": "Reduces hostile-creature damage; stronger during a settlement assault." } }

// data/player_visuals.json — the dwarf body rig
"dwarf": {
  "skin_palette": ["f3ab36", "ca811c"],
  "skin_regions": [[6, 8, 6, 5], [1, 18, 4, 7], [10, 18, 4, 7]],
  "shoulder": [5, -3], "torso_size": [12, 8], "feet_width": 5 }
```

Three authorities drive it: [`data/character_data.json`](data/character_data.json) (creation contract, species, traits, Callings, palettes), [`data/ancestries.json`](data/ancestries.json) (twelve ancestries — five live, the rest validated data awaiting their phases), and [`data/player_visuals.json`](data/player_visuals.json) (the 16×32 body rig). Persistence lives in `user://shell.json` (profile + characters), separate from `user://worlds/<id>.json`.

### Repo layout

```text
scenes/shell + scripts/shell     persistent shell: characters, worlds, world builder
scenes/main  + scripts/main      game root (day/night, storms, threats, progression),
                                 smoke suite, screenshot tour
scripts/world                    deterministic generation, block grid, lighting, fluids,
                                 data-authority registry
scripts/player                   movement, mining, combat, equipment, attunement, perks
scripts/entities                 visible subject actors: bounded roam, jobs, stats
scripts/settlement               Town Hall + the Coherence/Load/Resilience model
scripts/ui                       layered HUD-kit assembly, movable modules, panels
data/*.json                      the actual game design: blocks, recipes, enemies,
                                 ancestries, progression, equipment, presets, items
docs/                            handoff, variable matrix, task queue, wiki, design
```

```text
data/*.json ───────► registries / validators ───────► world, player, settlement systems
shell profile ─────► character state ───► inventory / equipment / dock ───► runtime HUD
world save ─────────► terrain deltas + simulation ───► smoke harness + evidence docs
```

Persistence: `user://shell.json` (profile + characters) and `user://worlds/<id>.json` (one file per world: config + terrain deltas + simulation state).

### Build & verify

No build step — run it straight from the project:

```powershell
& <path-to-godot-4.6> --path <this-repo-root>
```

Validators plus the in-engine smoke suite (run windowed so the frame capture and rendering checks resolve):

```powershell
python scripts/validate_repo.py
python scripts/asset_audit.py --strict
python scripts/art/sync_hud_kit.py --verify-runtime
python scripts/art/verify_gear_alignment.py

$env:COHERONIA_SMOKE = "1"
Start-Process -FilePath "<path-to-godot-4.6>" -ArgumentList @("--path", "<this-repo-root>") -Wait
# results: user://smoke_results.json
```

The smoke suite asserts **532 checks** against the real game (input map, physics, saves), windowed clean 532/532 (2026-08-06). One check, `r06_texture_prep_delegates`, fails only under the *headless* display server — a texture-scaling detail with no window — and passes windowed, so a headless 531/532 is expected. GitHub Actions builds and smokes a Linux/X11 export on every push.

### Regenerate the screenshots

The staged capture tour renders the README shots to `user://shots/` and quits. Run it **windowed** (not `--headless`) so the frame capture resolves; the camera uses your saved **View Zoom**, so shots reflect the in-game view.

```powershell
$env:COHERONIA_SHOTS = "1"
Start-Process -FilePath "<path-to-godot-4.6>" -ArgumentList @("--path", "<this-repo-root>") -Wait
# shots land in %APPDATA%\Godot\app_userdata\Coheronia\shots
# copy the keepers into docs/screenshots/, then re-import: <godot> --headless --import --path <repo>
```

### Explore the build wiki

[Open the Coheronia Wiki](docs/wiki/wiki.md) for the repo-backed reference on live systems, inventory and crafting routes, HUD asset rules, image coverage, planned data, and known limitations. GitHub renders this Markdown entrypoint directly; the repo also includes a richer local [visual wiki wrapper](docs/wiki/index.html).

</details>

---

<a name="how-its-built"></a>
<details>
<summary><h2>🧭 How it's built</h2></summary>

Coheronia is an experiment in disciplined, AI-orchestrated development — every increment is scoped, implemented against explicit data authorities, reviewed independently, and checked in-engine. The repository exposes both the playable architecture and the evidence trail behind it.

- **Self-verifying build.** A smoke suite runs the *real game* — real input map, real physics, real saves — and asserts **532 checks** across mining, save/load round-trips, legacy migrations, UI panel contents, HUD-kit layering, physics traversal, armor math, the Calling identity system (three Callings → six Paths → 72 tiered skills, all wired to real hooks), the full metal-gear ladder, adaptive-music transitions, the character-rendering contract, the visible-subject labor loop, directed-goal contracts, the procedural world depths (fractional strata, caves, and the hell/lava biome in every world size), the leveled liquid physics (lava and water pour, conserve mass, settle, react into obsidian, and burn the player and enemies), level-aware submersion with a breath/drowning gauge, plant-on-tilled-soil farming, per-column underground depth shading, and event stingers. Windowed clean **532/532** (2026-08-06); the exported artifact runs green with six `res://` fixture checks skipped only under read-only export.
- **Evidence over claims.** Increment scope, decisions, review findings, and validation state are summarized in [`docs/HANDOFF.md`](docs/HANDOFF.md) and traced in [`docs/VARIABLE_MATRIX.md`](docs/VARIABLE_MATRIX.md) (every variable, its authority, and its consumers).
- **Independent review loop.** Each change was reviewed by a separate agent pass before commit; findings (from save-corruption edge cases to invisible-tint rendering bugs) are documented and fixed in the ledgers.
- **Task queue discipline.** Work follows [`docs/FABLE_TASK_QUEUE.md`](docs/FABLE_TASK_QUEUE.md) one bounded increment at a time, each documented in the handoff and variable matrix.
- **Determinism & save-safety.** Terrain regenerates from `world_seed` + player edits, gated by a `gen_version` stamp so existing worlds stay byte-identical as the generator evolves; saves are atomic with `.bak` recovery and are never silently discarded on corruption.

</details>

---

<a name="changelog"></a>
<details>
<summary><h2>📓 Changelog</h2></summary>

Dated shipped milestones, newest first (full detail in [`docs/HANDOFF.md`](docs/HANDOFF.md)):

- **2026-08-06 — Performance, underground generation & view settings.** Three fixes. **Performance:** the biggest framerate drain was that every farmhand settler (and every crop-eating threat) scanned the *entire* world cell grid — up to ~100k cells — *every physics frame* to find the nearest crop/soil in its work zone; the searches now iterate only the bounded work-zone rect (same result, a fraction of the cost). **Underground lava & enemies (new `gen_version 4`):** generated lava now **pools to a depth in coherent lakes** instead of scattering single-cell blocks, tiny liquid pockets are pruned, and cave enemies only spawn in a genuine open-air chamber (existing worlds byte-identical). **View settings:** set **how much of the map is on screen** (camera zoom) and toggle **fullscreen** as persisted preferences — a Settings slider/toggle plus live **mouse-wheel / `+` / `-`** zoom and **`F11`** in-game. Source smoke **532/532** (windowed clean).
- **2026-08-05 — The Calling system.** Turned the vestigial "role" concept into a real, character-owned identity — three permanent Callings (**Oathbound**, **Wayfarer**, **Runewright**), each with an innate effect and two Paths of twelve tiered skills, **every one wired to a real gameplay hook**. Progression carries between worlds; a reachability-safe tier gate never forces an inert purchase. Source smoke **529/529**. Authority: [`docs/CALLING_EFFECT_MATRIX.md`](docs/CALLING_EFFECT_MATRIX.md).
- **2026-08-04 — Underground lighting, fixed.** A mined shaft viewed from the surface now reads **dark**, lit only where light actually reaches, via a per-column depth shader that keeps normal 2D lighting. Source smoke **509/509**.
- **2026-07-31 — Settler work + panel clarity.** Farmhands replant from a seed pouch; any settler can be given a drag-to-define **work zone**; needs read as green ✓ / red ✗ chips with fix-it reasons; ore falls when undermined. Source smoke **508/508**.
- **2026-07-30 — Settlement Coherence (M1–M5).** Turned the abstract population into a **bounded, persistent citizenry**: home/guard posts, movement clamps, transferable stockpile, doors, housing that caps growth, ancestry identities, a **defender** role, wall-breaking raiders, a lava slime, and a sun/moon lunar cycle. Plus a lighting/sky pass and full-height doors. Source smoke **498/498** (+56 checks).
- **2026-07-28/29 — Liquid Physics + World Depths.** Bigger, deeper worlds through data-driven strata into caves and a hell biome; lava and water as a leveled, mass-conserving fluid sim with lakes, a lava+water→obsidian reaction, sealed generated liquid, a scoop/pour bucket, swim/breath, and authored depth-block art with rising lava bubbles. Source smoke **418→442**.
- **2026-07-24 — Contracts + balance (R-09).** Data-driven directed goals with a persisted lifecycle that observes live state, a Contracts panel, and a deterministic balance report.
- **through 2026-07-24 — R-08 subject labor + R-00–07 foundations.** Visible farmhand/repairer/hauler settlers and a loose ground-drop layer; export-safe loading, atomic saves, pinned CI, the pause/settings/keybinds surface, and the unified crafting panel.
- **2026-07-21 — Presentation recovery (PR-00–08).** Character-rendering contract, gear resolution/alignment, directional action animation, the runtime-children Character panel, and the viewport-relative skill tree.

</details>

---

<a name="roadmap"></a>
<details>
<summary><h2>🗺️ Roadmap</h2></summary>

The full adaptive-music arc, the opening cinematic, and the first real art pass are done; the active queue ([`docs/FABLE_TASK_QUEUE.md`](docs/FABLE_TASK_QUEUE.md)) continues in bounded increments:

- **Next up** — the next code arc is intentionally unselected; stabilization and playtesting come first.
- **More enemies** from a 16-entry design roster (mini-bosses and the hollow_king / world_worm bosses remain), each landing with its gameplay consumer.
- **Art backlog** — polish the HUD chrome one contract-safe PNG at a time; extend body-specific gear beyond the covered crude armor/pick/axe families; refine action poses.
- **Deeper systems** sketched in [`docs/FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md`](docs/FUTURE_PROGRESSION_RESEARCH_AND_BASE_LEVELS.md): a research bench, more perk lanes, underground-start generation for deep ancestries, and a civic layer (laws, districts, factions). Ancestries beyond the five playable ones exist as validated data awaiting their phases.

</details>

---

<a name="known-issues"></a>
<details>
<summary><h2>⚠️ Known issues</h2></summary>

- **Gear overlays resolve and align; motion still needs a pass.** Body-specific gear stays visible across load/world-transition/forge refreshes and seats correctly, and swings play a data-driven windup→impact→recovery. What remains is art: pick/axe art snaps through three poses, and the sword has no authored attack sequence yet.
- **The HUD architecture is stabilized, but the art is provisional.** The primary dock separates static chrome from runtime values; some framed-panel states still show padding/masking defects, and the legacy painted/sliced constructions remain fallback code.
- **Smoke is green, with one environment-specific check.** Windowed **532/532** (2026-08-06). `r06_texture_prep_delegates` fails only under the headless display server (a texture-scaling detail with no window) and passes windowed.
- **Several systems remain partly abstract.** Beyond the visible farmhand/repairer/hauler/defender settlers, the settlement is still driven by an abstract population count layered under the visible actors (the single food-accounting authority). Enemies walk and hop without pathfinding; the adaptive score is one suite still being balanced; and current finite maps have one surface biome.

Full status: [`docs/wiki/known_issues.md`](docs/wiki/known_issues.md).

</details>
