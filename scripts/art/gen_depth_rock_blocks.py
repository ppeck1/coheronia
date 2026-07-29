#!/usr/bin/env python3
"""Mottled-rock tiles for the deep-world special blocks (deepstone, hellstone,
obsidian).

Matches the look of the authored ore/stone blocks: a finely mottled 16x16 rock
base, plus a few short mineral cracks and scattered flecks placed anywhere in the
tile at varied angles. Fully deterministic -- a fixed per-tile seed drives the
mottle, cracks, and flecks, so a tile always renders identically and re-running
never churns the bytes.

Each block gets a SIX-tile in-world pool (`<id>_01..._06.png`, hashed per cell)
plus a representative `<id>.png` icon (a copy of the first pool tile). The larger
pool + anywhere-placed cracks stop the tiling from reading as a regular grid of
identical marks. This is the authoritative source for these live tiles; the
earlier pass-2 review package (build_world_depths_fluids_pass2.py) no longer
promotes them.
"""

from __future__ import annotations

import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "generated" / "blocks"
TILE = 16
VARIANTS = 6

RGB = tuple[int, int, int]

# Directions a crack can run (orthogonal, diagonal, and a couple of shallow
# slopes) so the fissures never all share one angle.
_DIRS = [(1, 0), (0, 1), (1, 1), (1, -1), (-1, 1), (2, 1), (1, 2), (2, -1)]


# Per material: a mottle palette (base rock, sampled per pixel with weights that
# favour the mid tones so it reads as fine grain); a crack/fleck palette (dark ->
# bright, weighted toward the DIM end so bright marks stay occasional); whether
# marks glow (hellstone embers bleed a warm halo); how many cracks/flecks; and
# whether the cracks are brighter than the base (mineral) or darker (a fissure).
MATERIALS: dict[str, dict] = {
    "deepstone": {  # dense dark blue-grey rock, darker/bluer than stone
        "mottle": [(38, 44, 54), (46, 53, 65), (56, 64, 77), (67, 76, 91), (32, 37, 46)],
        "mottle_weights": [5, 8, 7, 3, 4],
        "vein": [(28, 32, 40), (36, 41, 51), (74, 82, 96)],   # dark fissures + rare glint
        "vein_weights": [6, 4, 1],
        "glow": False,
        "crack_counts": [1, 3, 3, 2],   # weights for 0,1,2,3 cracks
        "crack_len": (4, 9),
        "bright_cracks": False,
        "flecks": (0, 2),
    },
    "hellstone": {  # charred basalt with molten ember cracks
        "mottle": [(36, 21, 19), (46, 26, 23), (56, 32, 27), (68, 39, 32), (28, 17, 15)],
        "mottle_weights": [6, 8, 7, 3, 4],
        "vein": [(110, 38, 20), (170, 60, 24), (220, 96, 32), (252, 150, 60)],
        "vein_weights": [5, 5, 3, 1],
        "glow": True,
        "crack_counts": [2, 4, 3, 1],
        "crack_len": (3, 7),
        "bright_cracks": True,
        "flecks": (2, 6),
    },
    "obsidian": {  # blue-violet volcanic glass with facet highlights
        "mottle": [(16, 13, 22), (22, 18, 30), (30, 25, 42), (40, 33, 56), (52, 44, 74)],
        "mottle_weights": [6, 8, 7, 3, 3],
        "vein": [(56, 54, 86), (90, 84, 130), (130, 122, 176), (172, 166, 214)],
        "vein_weights": [4, 5, 3, 1],
        "glow": False,
        "crack_counts": [2, 4, 3, 1],
        "crack_len": (3, 6),
        "bright_cracks": True,
        "flecks": (1, 4),
    },
}


def _mottle(rng: random.Random, spec: dict) -> Image.Image:
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 255))
    px = img.load()
    palette: list[RGB] = spec["mottle"]
    weights: list[int] = spec["mottle_weights"]
    for y in range(TILE):
        for x in range(TILE):
            c = rng.choices(palette, weights=weights, k=1)[0]
            px[x, y] = (c[0], c[1], c[2], 255)
    return img


def _blend(a, c: RGB, t: float):
    return (int(a[0] + (c[0] - a[0]) * t), int(a[1] + (c[1] - a[1]) * t),
            int(a[2] + (c[2] - a[2]) * t), 255)


def _put(px, x: int, y: int, c: RGB) -> None:
    if 0 <= x < TILE and 0 <= y < TILE:
        px[x, y] = (c[0], c[1], c[2], 255)


def _halo(px, cx: int, cy: int, warm: RGB) -> None:
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = cx + dx, cy + dy
        if 0 <= nx < TILE and 0 <= ny < TILE:
            px[nx, ny] = _blend(px[nx, ny], warm, 0.35)


def _crack(rng: random.Random, px, spec: dict) -> None:
    """A short 1px fissure from a random start, in a random direction, with a
    little wander and the odd gap -- placed ANYWHERE in the tile."""
    vein: list[RGB] = spec["vein"]
    vweights: list[int] = spec["vein_weights"]
    glow: bool = spec["glow"]
    length = rng.randint(*spec["crack_len"])
    x = float(rng.randrange(TILE))
    y = float(rng.randrange(TILE))
    dx, dy = rng.choice(_DIRS)
    if rng.random() < 0.5:
        dx, dy = -dx, -dy
    inv = 1.0 / max(abs(dx), abs(dy))
    dx, dy = dx * inv, dy * inv
    for i in range(length):
        if rng.random() < 0.18:            # a gap breaks the line up
            x += dx
            y += dy
            continue
        c = rng.choices(vein, weights=vweights, k=1)[0]
        ix, iy = int(round(x)), int(round(y))
        _put(px, ix, iy, c)
        if glow and c is vein[-1]:
            _halo(px, ix, iy, vein[1])
        # perpendicular wander so cracks aren't perfectly straight
        if rng.random() < 0.3:
            x += -dy * 0.6
            y += dx * 0.6
        x += dx
        y += dy


def _flecks(rng: random.Random, px, spec: dict) -> None:
    vein: list[RGB] = spec["vein"]
    glow: bool = spec["glow"]
    for _ in range(rng.randint(*spec["flecks"])):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        tone = rng.randrange(1, len(vein))
        _put(px, x, y, vein[tone])
        if glow and tone >= len(vein) - 1:
            _halo(px, x, y, vein[1])


def _tile(material: str, variant: int) -> Image.Image:
    spec = MATERIALS[material]
    rng = random.Random("%s::%d" % (material, variant))
    img = _mottle(rng, spec)
    px = img.load()
    n_cracks = rng.choices([0, 1, 2, 3], weights=spec["crack_counts"], k=1)[0]
    for _ in range(n_cracks):
        _crack(rng, px, spec)
    _flecks(rng, px, spec)
    return img


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for material in MATERIALS:
        pool = [_tile(material, v) for v in range(VARIANTS)]
        pool[0].save(OUT / f"{material}.png")            # representative icon
        for i, img in enumerate(pool):
            img.save(OUT / f"{material}_{i + 1:02d}.png")  # in-world pool
        print(f"PASS: wrote {material}.png + _01..._{VARIANTS:02d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
