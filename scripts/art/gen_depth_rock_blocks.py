#!/usr/bin/env python3
"""Mottled-rock tiles for the deep-world special blocks (hellstone, obsidian).

Matches the look of the authored ore blocks (iron_ore / silver_ore / copper_ore
...): a finely mottled 16x16 rock base with an embedded, broken diagonal mineral
vein. Fully deterministic -- a fixed per-tile seed drives the mottle and vein, so
the same tile always renders identically and re-running never churns the bytes.

Each block gets `<id>_01/_02/_03.png` (the registry's per-cell in-world variant
pool) plus a representative `<id>.png` icon (a copy of the first pool tile),
exactly the dirt/stone/ore convention. This is the authoritative source for the
hellstone and obsidian live tiles; the earlier pass-2 review package
(build_world_depths_fluids_pass2.py) no longer promotes them.
"""

from __future__ import annotations

import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "generated" / "blocks"
TILE = 16

RGB = tuple[int, int, int]


# Per material: a mottle palette (base rock, sampled per pixel with weights that
# favour the mid tones so it reads as fine stone grain) and a vein palette
# (dark -> bright mineral, painted along a broken diagonal). `glow` adds a warm
# halo around the brightest vein pixels so hellstone's cracks read as molten.
MATERIALS: dict[str, dict] = {
    "hellstone": {
        # charred basalt: near-black reds with a few warmer grains
        "mottle": [(38, 22, 20), (48, 27, 24), (58, 33, 28), (70, 40, 33), (86, 49, 38)],
        "mottle_weights": [5, 7, 8, 4, 2],
        "vein": [(120, 40, 20), (196, 74, 26), (236, 110, 36), (255, 158, 66)],
        "glow": True,
    },
    "obsidian": {
        # glassy volcanic glass: blue-violet blacks
        "mottle": [(16, 13, 22), (22, 18, 30), (30, 25, 42), (40, 33, 56), (52, 44, 74)],
        "mottle_weights": [6, 8, 7, 3, 2],
        # cool glassy facet highlights rather than a warm ore streak
        "vein": [(58, 56, 90), (92, 86, 134), (134, 126, 182), (176, 170, 220)],
        "glow": False,
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


def _blend(a: tuple[int, int, int, int], c: RGB, t: float) -> tuple[int, int, int, int]:
    return (
        int(a[0] + (c[0] - a[0]) * t),
        int(a[1] + (c[1] - a[1]) * t),
        int(a[2] + (c[2] - a[2]) * t),
        255,
    )


def _paint_vein(rng: random.Random, img: Image.Image, spec: dict) -> None:
    """A broken diagonal chain of mineral specks over the mottled base."""
    px = img.load()
    vein: list[RGB] = spec["vein"]
    glow: bool = spec["glow"]
    down_right = rng.random() < 0.5
    # Start somewhere along the top / side so the diagonal crosses the tile.
    x = float(rng.randint(-2, TILE - 3) if down_right else rng.randint(2, TILE + 1))
    y = float(rng.randint(-2, 3))
    step = 1.0
    while y < TILE + 2:
        # Break the vein up: skip a stretch now and then.
        if rng.random() < 0.22:
            x += (step if down_right else -step)
            y += step
            continue
        cx = int(round(x + rng.uniform(-0.7, 0.7)))
        cy = int(round(y))
        # A little cluster: bright centre, cooler shoulders.
        for dx, dy, tone in ((0, 0, 3), (1 if down_right else -1, 0, 1),
                             (0, 1, 2), (1 if down_right else -1, 1, 0)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < TILE and 0 <= ny < TILE and rng.random() < 0.85:
                px[nx, ny] = (vein[tone][0], vein[tone][1], vein[tone][2], 255)
                if glow and tone >= 2:
                    _halo(px, nx, ny, vein[1])
        x += (step if down_right else -step) + rng.uniform(-0.35, 0.35)
        y += step


def _halo(px, cx: int, cy: int, warm: RGB) -> None:
    """Bleed a faint warm glow into the 4-neighbours of a bright ember pixel."""
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = cx + dx, cy + dy
        if 0 <= nx < TILE and 0 <= ny < TILE:
            px[nx, ny] = _blend(px[nx, ny], warm, 0.4)


def _tile(material: str, variant: int) -> Image.Image:
    spec = MATERIALS[material]
    rng = random.Random("%s::%d" % (material, variant))
    img = _mottle(rng, spec)
    _paint_vein(rng, img, spec)
    return img


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for material in MATERIALS:
        pool = [_tile(material, v) for v in range(3)]
        pool[0].save(OUT / f"{material}.png")            # representative icon
        for i, img in enumerate(pool):
            img.save(OUT / f"{material}_{i + 1:02d}.png")  # in-world pool
        print(f"PASS: wrote {material}.png + _01/_02/_03")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
