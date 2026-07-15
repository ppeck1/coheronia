# Coheronia Asset Template (FQ-07)

Art improves one asset at a time. The game renders an image when it exists and
falls back to the current generated colors/shapes when it does not, so a
half-finished art pass never breaks anything.

## Naming Rules

- Path convention: `art/generated/<category>/<id>.png`
  - `<category>`: `blocks`, `items`, `enemies`, `players`, `player_gear`,
    `structures`, `ui`, `opening`, `backgrounds`, or `back_walls`
  - `<id>`: the exact data id — block ids from `data/blocks.json`
    (e.g. `dirt`, `wood`, `berry_bush`), item ids as used in inventories
    (e.g. `wood`, `torch`, `food`), enemy ids from `data/enemies.json`
    (e.g. `surface_slime`), UI keys as introduced.
- Lowercase snake_case, `.png` only. No spaces, no size suffixes.
- A non-convention path can be mapped explicitly in
  `data/visual_assets.json` under `categories.<category>.<id>` (path relative
  to the repo root). Explicit entries MUST exist — the validator fails on a
  broken explicit reference; convention gaps are informational only.
- Loading uses `Image.load_from_file` on real project files, NOT Godot's
  import system: this works for the plain non-exported runs this repo always
  uses, but an exported (PCK) build would not see these files — an
  import-aware path would be needed then (deliberately out of scope).

## Variants (FQ-09V)

One id may ship several interchangeable looks so terrain reads less
repetitive — entirely optional:

- File convention: `art/generated/<category>/<id>_01.png`, `<id>_02.png`, …
  numbered consecutively from `_01` (two digits). The first missing number
  ends the pool; at most 8 variants are read.
- Or map an explicit pool in `data/visual_assets.json`:
  `categories.<category>.<id>` may be an ARRAY of paths (each must exist —
  the validator fails on a broken pool entry, same rule as single paths).
- Blocks pick a variant deterministically from world seed + cell position:
  the same world always renders the same variety, and the choice is never
  saved. All variants of a block share identical physics/occlusion.
- A single `<id>.png` (no suffix) keeps working exactly as before, and ids
  with no art keep their generated fallback. Variants should share one
  silhouette; the mining crack mask derives from the id's base texture.
- Runtime semantics differ by category: blocks choose one variant per world
  cell, enemies choose one per spawned instance, and players use the
  character-owned Look value. Opening `_NN` files are animation frames, not
  random variants, and loop at 8 fps for their scene. Items are canonical-only.

## Target Sizes

| Category | Size (px) | Notes |
|---|---|---|
| blocks | 16 x 16 | opaque unless the block is see-through (bush/torch style); the ONLY category with automatic nearest-neighbor resize to the tile |
| items | 16 x 16 | transparent background; the HUD TextureRect scales the display, the file should still be 16 x 16 |
| enemies | 16 x 16 | transparent background; drawn centered at RAW size — an oversized sprite overflows the entity, so match the size exactly |
| players | 16 x 32 | transparent; right-facing authored stance, feet bottom-aligned; body pools use `<body_id>_NN.png`; every Look retains the rig's exact skin-palette bytes inside its skin regions |
| player_gear | 16 x 32 | transparent overlay; prefer `<item_id>_<body_id>.png`; generic `<item_id>.png` is safe only after alignment is checked on every live body |
| structures | 56 x 48 | transparent; current live id is `town_hall` |
| ui | 32 x 32 | panel icons; transparent background; no automatic resize |
| opening | 640 x 360 | optional wordless cel frames; `_NN` pools loop at 8 fps and replace the plotted shot while present |
| backgrounds | 640 x 360 sky or 640 px-wide strips | sky opaque; strips transparent above the ridge; native strip height varies |
| back_walls | 16 x 16 | opaque and seamless; quieter/darker than the matching foreground block |

Final sprite PNGs use hard alpha only (`0` or `255`), transparent corners for
cutouts, nearest-neighbor pixel clusters, and a restrained palette (normally no
more than 16 visible colors). Homogeneous terrain and wall tiles must repeat
without a visible opposite-edge seam; a crowned tile such as grass is
horizontally seamless but intentionally keeps distinct top and bottom edges.

## Prompt Notes (image-model iteration)

Image generation runs outside the game and outside validation. Generate into a
scratch folder, review the source, remove a flat chroma background for cutouts,
normalize to the exact target size/palette/alpha contract, then copy only the
approved PNG into `art/generated/<category>/`.

For generated player Looks, run
`scripts/art/restore_player_skin_palette.py --output-dir <staging>` before
promotion. Similar-looking skin colors are not sufficient: the runtime's
Pale/Umber/Ash bridge intentionally matches the exact colors declared in
`data/player_visuals.json`.

Suggested prompt skeleton:

> pixel art, 16x16, single game sprite of <subject>, flat 2D side view,
> limited palette, crisp 1px edges, transparent background, no text,
> no border, centered

Per-category subject hints:

- blocks: "a seamless <material> terrain tile" (drop "transparent background")
- items: "<item> as a small inventory icon"
- enemies: "<creature>, simple silhouette readable at small size"
- ui: "<concept> icon, bold silhouette"

## Review Checklist (before copying into art/generated/)

1. Correct size for the category (or accept nearest-neighbor resize).
2. Transparent background where required (blocks may be opaque).
3. Reads clearly at 100% zoom on the dark game background.
4. Filename matches the data id exactly (`<id>.png`).
5. Run the game once: the asset appears; nothing else changed.
6. Run `python scripts/validate_repo.py`: no FAIL (INFO lines about other
   missing assets are expected and fine).
7. Run `python scripts/asset_audit.py --strict`: no sequence gap, oversize
   pool, unreadable PNG, or wrong-dimension data bug.
8. Run `python scripts/art/verify_pixel_assets.py`: palette, hard alpha,
   transparent-corner, tile-edge, player-scale, and exact skin-palette
   contracts all pass.
9. Review a category contact sheet at native scale and at an integer zoom.

## Planned Full-Scene And Backing-Wall Assets

Opening panels, scenic environment backgrounds, and Terraria-style backing
walls have different dimensions, layering, and lighting responsibilities than
the four live sprite categories above. Their planning contract is:

- `docs/ART_DIRECTION_AND_CANON.md`
- `docs/OPENING_STORYBOARD.md`
- `art/source_templates/BACKGROUND_TEMPLATE.md`

The runtime consumes `backgrounds` and `back_walls` through FQ-09W. The FQ-09C
opening cel hook is also live but optional; the current wordless plotted
cinematic remains the permanent fallback when no cel pool exists. Explicit
`data/visual_assets.json` entries are unnecessary for convention-named files.
