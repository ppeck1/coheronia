# Coheronia Asset Roadmap And Prompt Packs

Status: FQ-09A authority — the concrete asset map for future human and LLM
art passes. Style, tone, palette, and meaning come from
`docs/ART_DIRECTION_AND_CANON.md`; naming, sizes, and review rules from
`art/source_templates/ASSET_TEMPLATE.md`; plane separation and wall/backdrop
rules from `art/source_templates/BACKGROUND_TEMPLATE.md`. This document
never overrides those authorities — it maps them onto every current and
near-term asset id.

Decision (per the FQ-09A scope rule): no `data/asset_manifest.json` is
introduced, because no code or validation consumes one — the runtime already
resolves every asset by convention. This human-readable roadmap is the
manifest.

## How The Pipeline Works (for any art agent)

- Drop a PNG at `art/generated/<category>/<id>.png` and it is live on the
  next world entry / app start. No Godot import step, no code change, no
  manifest edit (`Image.load_from_file` at runtime).
- Missing art is never an error: every id below renders today from a
  generated color/shape/code-drawn fallback. Art replaces fallbacks one file
  at a time.
- Variant pools (FQ-09V): `<id>_01.png` … `<id>_08.png` (consecutive, first
  gap ends the scan) render as deterministic per-cell variety for blocks and
  as 8 fps cel frames for opening scenes.
- The validator treats convention-path gaps as INFO only; it fails only
  broken explicit entries in `data/visual_assets.json` (which you normally
  never need to touch).
- Never bake words into any image. `COHERONIA`, `By Paul Peck`, the tagline,
  and all copy are engine-rendered — an image containing text is rejected.
- Author at 100% target size and judge at 100% zoom; nearest-neighbor
  scaling only.

Priorities: **P1** = biggest visible win first (terrain, player, hall);
**P2** = core loop surfaces (items, live enemies, stations when they land);
**P3** = presentation polish (opening cel frames, backgrounds, UI icons).
Planned ids must not be produced before their systems exist unless the
operator asks — the manifest stays honest.

## Live Assets (render today from fallbacks; art drops in directly)

### Blocks — `art/generated/blocks/<id>.png`, 16x16

| Id | Transparency | Current fallback | Priority | Prompt note |
|---|---|---|---|---|
| dirt | opaque | flat loam color + edge shade | P1 | packed loam, small stones; supports `_01.._08` variants |
| grass | opaque | flat green + edge shade | P1 | dirt body with a living green crown edge |
| stone | opaque | flat gray + edge shade | P1 | cool gray facets, one-pixel cracks; variants welcome |
| ore | opaque | flat brass + edge shade | P1 | stone body with warm metallic flecks |
| wood | opaque | flat timber + edge shade | P2 | placed plank/beam block (building material, not a tree) |
| tree_trunk | transparent | 6px bark bar | P2 | slim rounded trunk bar, bark shading; player passes in front |
| tree_leaves | transparent | clipped blob + flecks | P2 | leafy cluster, clipped corners, moss-family greens |
| berry_bush | transparent | rounded bush + red dots | P2 | low bush on visible soil contact; 3-4 red berries |
| torch | transparent | stick + flame pixels | P1 | short stake, small amber flame, no glow halo (engine lights it) |
| lantern | transparent | hook + housing | P2 | hanging brass housing, warm core, no baked rays |
| town_hall_core | opaque | flat violet + edge shade | P3 | civic keystone block: timber-and-banner reading, not arcane |

### Items — `art/generated/items/<id>.png`, 16x16, transparent

Live ids (icon grids, hotbar, forge buttons): `dirt`, `grass`, `wood`,
`stone`, `ore`, `torch`, `lantern`, `berry_bush`, `food`, `slime_gel`,
`wet_fiber`, `tiny_core`, `pick`, `axe`, `sword`, `armor`.
Fallback: items.json color swatch (hash-hue for unknown ids). Priority P2.
Prompt note: single readable object silhouette centered on transparency;
block-material items may reuse their block texture reading at icon scale;
`food` is a humble ration (berries/bread), never a golden buff icon.

### Enemies — `art/generated/enemies/<id>.png`, 16x16, transparent

| Id | Family | Fallback | Priority | Prompt note |
|---|---|---|---|---|
| surface_slime | surface | violet rect + hurt bar | P2 | soft dome slime, faint core, side-view |
| cave_crawler | underground | green rect | P2 | low many-legged crawler, cool slate/moss |
| raider_basic | raider | rust rect | P2 | hooded human silhouette, rust accent, crude blade |

Engine draws hurt tint and health bar; sprites must leave headroom for both.

### Equipment / UI icons — `art/generated/items/<id>.png` today (16x16)

Live equipment ids that surface in panels: `pick_basic`, `pick_forged`,
`axe_crude`, `sword_crude`, `helmet_crude`, `torso_crude`, `feet_crude`,
`ring_band`, `amulet_focus`. Priority P3 (text panels work fine).
`art/generated/ui/` (32x32) is reserved: nothing reads it yet — do not
produce ui-category files until a consumer lands.

### Backing walls — `art/generated/back_walls/<id>.png`, 16x16, seamless

| Id | Status | Fallback | Priority | Prompt note |
|---|---|---|---|---|
| dirt_wall | live | darkened dirt texture | P1 | seamless packed-earth rear wall, ~40-50% value of dirt, opaque |
| stone_wall | live | darkened stone texture | P1 | seamless rough stone rear wall, quieter than foreground stone |

Rules: opaque centers (underground air must never read as sky), edge-tiling
continuity, visually quieter and darker than the matching foreground block.

### Scenic backgrounds — `art/generated/backgrounds/<id>.png`

| Id | Status | Shape | Priority | Prompt note |
|---|---|---|---|---|
| surface_sky | live | 640x360 full frame, opaque | P3 | day-neutral sky field; engine tints day/night/storm — author neutral, no sun/moon, no baked lighting events |
| surface_far_terrain | live | tiling strip, transparent top | P3 | distant ridge silhouettes, low contrast/saturation |
| surface_mid_silhouette | live | tiling strip, transparent top | P3 | nearer tree/hill silhouettes, still below foreground contrast |

### Opening cinematic cel frames — `art/generated/opening/<scene_id>_01.png` …

Eight scene ids (FQ-09C; 640x360 masters, up to 8 frames each, played at
8 fps in place of the code-plotted shot; the puppet/plotted rendering is the
permanent fallback): `opening_01_first_star`, `opening_02_unraveling_roads`,
`opening_03_scattered_peoples`, `opening_04_darkness_measures_light`,
`opening_05_first_hall_raised`, `opening_06_attunement_pulse`,
`opening_07_civilization_pushes_back`, `opening_08_title_card`.
Priority P3, in storyboard order. Every frame is wordless; scene copy,
title, and `By Paul Peck` remain engine labels. Composition, beats, and
palette per scene are locked in `docs/OPENING_STORYBOARD.md` — frames
re-draw those beats as hand-authored animation, they do not invent new ones.
Keep meaningful action above the lower-quarter text band.

## Drawn-Shape Actors (live surfaces with no art path yet)

These render as code-drawn rects/polygons today. They need a small renderer
extension (an image-capable path like the enemy sprite one) before art can
land — flag the code change in the same increment that produces the sprites.

| Surface | Today | Planned asset shape |
|---|---|---|
| Player | 12x28 body + trim rects colored by appearance (tan/pale/umber/ash) | per-ancestry sprite (human, dwarf, elf, goblin, orc) with appearance recolor masks; side-view, ~16x32 |
| Town Hall | drawn wall/roof/door/chimney rects + damage overlay | founding timber hall sprite, damage states preserved as overlay |
| Attunement pulse | radial gradient light | optional star-white ring sprite (structural, no fireball) |

## Planned Assets (systems not live yet — do not produce early)

| Family | Ids | Arrives with | Size |
|---|---|---|---|
| Ore blocks | copper, iron, coal, tin, silver, crystal, rare-ore placeholder | FQ-10 | 16x16 blocks (+ item icons) |
| Stations | workbench, furnace, anvil | FQ-11 | 16x16 blocks (possibly multi-tile) |
| Intermediates | ingots per metal family | FQ-11 | 16x16 items |
| Farming | seeds, crop growth-stage blocks, tilled soil | FQ-12 | 16x16 |
| Enemies (next) | thornrat, ore_tick, raider_torchbearer, then broodmother_crawler, bandit_standard_bearer | FQ-13+ (mvp_expansion_order) | 16x16 |
| Enemies (data-planned) | ash_wasp, mudling, hollow_stag, lantern_leech, stoneback_beetle, sporekin, burrow_maw, raider_sapper, hungry_deserter, false_taxman; bosses hollow_king, world_worm | later waves | 16x16+ |
| Action effects | mining/chop arc, placement pulse, hurt/collapse feedback, forge confirmation | FQ-09M | small transparent overlays |
| Back walls | ore_cave_wall, fungal_wall, crystal_wall, timber_wall | with their environments | 16x16 seamless |
| Backgrounds | cave_far, deep_cavern_far | with cave backdrop wiring | 640x360 |
| Ancestry sprites (deep/planned) | deep_dwarf, deep_elf, deep_goblin, gnome, deep_gnome, lizardfolk, dragonkin (6 dragonkin types) | phase C-E ancestries | 16x32 |
| UI icons | goal panel, map/minimap glyphs | FQ-14/FQ-15 | 32x32 |

## Prompt Packs

Use the shared preamble, then the category block, then the per-id note from
the tables above. Iterate locally (Ollama or any image model) entirely
outside the game and validation; only the final PNG enters the repo.

### Shared preamble (every prompt)

> Coheronia, "Mythic Frontier Pixel Diorama": side-view pixel art for a
> survival settlement game. Crisp integer pixel clusters, limited family
> palette, one-pixel outline policy, readable at 100% zoom. Palette roles:
> amber/warm parchment/brass = maintained civilization; indigo/blue-black/
> cool slate = exposure and the unknown; star-white/pale cyan/muted violet =
> attunement insight; moss/loam/timber/stone/iron = the material world;
> controlled rust/bruised red = danger only. Hopeful under pressure,
> frontier myth, labor-centered. NEVER: glossy mobile fantasy, neon
> sci-fi, generic fireball magic, grimdark decay, painterly noise,
> baked-in text of any kind.

### Blocks / back walls (16x16)

> One 16x16 side-view terrain tile of <id>: <per-id note>. Flat readable
> material, subtle 1px edge shading, tiles seamlessly with itself.
> [back walls only:] This is a REAR cave wall: 40-50% the value of its
> foreground block, fully opaque, visually quiet.
> [variants:] Produce N interchangeable variants sharing silhouette,
> palette, and edge treatment.

### Items / equipment icons (16x16, transparent)

> One 16x16 inventory icon of <id>: <per-id note>. Single centered object
> silhouette on transparency, 1px outline, readable against dark UI panels.

### Enemies (16x16, transparent)

> One 16x16 side-view creature sprite of <id> (<family> family): <per-id
> note>. Strong silhouette, one accent color from its family palette, no
> background, leaves 2px headroom for an engine-drawn health bar.

### Player / ancestry sprites (16x32, transparent — needs renderer extension)

> One 16x32 side-view settler sprite: <ancestry> (<build notes: human
> balanced/upright; dwarf low/compact/heavy; elf narrow/vertical; orc
> broad/grounded; goblin small/quick>). Practical frontier work clothes,
> tool-belt reading, no armor spectacle. Two recolorable regions matching
> the appearance body/trim masks.

### Opening cel frames (640x360, wordless)

> Frame <n> of <=8 for cinematic scene <scene_id>: <storyboard beat from
> docs/OPENING_STORYBOARD.md>. 640x360 pixel-art master in the "Coheronia
> DOS Vector Cinematic" register: predominantly black/blue-black negative
> space, ~30% cool monoline structure, ~10% amber/star-white accents,
> hard-edged indexed color, no gradients or bloom. Absolutely no letters,
> numerals, or logos anywhere. Keep the lower quarter compositionally calm
> (engine text band).

### Scenic backgrounds (640x360 / tiling strips)

> <surface_sky | far terrain strip | mid silhouette strip>: side-view
> backdrop plane, contrast and saturation clearly below gameplay sprites,
> no baked light sources or weather (the engine tints day/night/storm),
> no implied walkable terrain, [strips:] tiles horizontally, transparent
> above the ridge line.

## Audio Assets (FQ-09U program — planned; authored in M8str0)

Music production has its own authority pair:
`docs/WORK_ORDER_FQ_09U_ADAPTIVE_MUSIC.md` (architecture, state model,
gating) and `audio/source_templates/MUSIC_TEMPLATE.md` (production
contract, mood vocabulary, prompt packs, render checklist), with
`data/music_manifest.json` as the machine contract. Nothing at runtime
consumes these until FQ-09U1.

| Family | Ids | Arrives with | Contract |
|---|---|---|---|
| Context loops | coheronia_surface_day, coheronia_surface_night, coheronia_underground, coheronia_crisis | FQ-09U1 | one adaptive suite: 72 BPM, 4/4, 16 bars (53.333 s), shared key family and phrase grid, OGG |
| Stems | stem_foundation, stem_hearth, stem_motion, stem_pressure, stem_attunement, stem_fracture | FQ-09U2 | phase-locked 16-bar layers, any subset musical |
| Stingers | stinger_dawn, stinger_nightfall, stinger_raid_warning, stinger_attunement, stinger_base_advance | FQ-09U3 | one-shots under 8 s, built from suite material |
| Opening cues | cue_opening_01_drone_bell … cue_opening_08_title_chord (`audio/opening/<id>.ogg`) | live hooks since FQ-09C (silent-skip) | restrained one-shots per the storyboard's sound direction |

## Review Gate

Every candidate passes `art/source_templates/ASSET_TEMPLATE.md`'s checklist
(and BACKGROUND_TEMPLATE's for walls/backdrops) before entering the repo:
correct path/size, seamless where required, readable at 100%, quieter than
foreground where applicable, no text, fallback still works when the file is
removed. Validator, smoke, screenshot tour, and `git diff --check` stay
green — the smoke's art checks prove both directions (image wins when
present, fallback returns on removal).
