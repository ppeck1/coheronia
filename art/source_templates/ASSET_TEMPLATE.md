# Coheronia Asset Template (FQ-07)

Art improves one asset at a time. The game renders an image when it exists and
falls back to the current generated colors/shapes when it does not, so a
half-finished art pass never breaks anything.

## Naming Rules

- Path convention: `art/generated/<category>/<id>.png`
  - `<category>`: `blocks`, `items`, `enemies`, `ui`
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

## Target Sizes

| Category | Size (px) | Notes |
|---|---|---|
| blocks | 16 x 16 | opaque unless the block is see-through (bush/torch style); the ONLY category with automatic nearest-neighbor resize to the tile |
| items | 16 x 16 | transparent background; the HUD TextureRect scales the display, the file should still be 16 x 16 |
| enemies | 16 x 16 | transparent background; drawn centered at RAW size — an oversized sprite overflows the entity, so match the size exactly |
| ui | 32 x 32 | panel icons; transparent background; no automatic resize |

## Prompt Notes (local Ollama / image-model iteration)

Ollama or any local image model runs OUTSIDE the game and outside validation —
generate PNGs into a scratch folder, review, then copy the keepers into
`art/generated/<category>/`.

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
