#!/usr/bin/env python3
"""Calm-body water tiles for the liquid sim.

Water is not dirt or stone: a pool must read as ONE continuous body spanning many
cells, NOT a grid of individually-decorated blocks. So unlike the mottled-rock
generator, every water tile is a single DEAD-FLAT uniform blue -- no ripples, no
per-tile marks, no gradient. Any in-tile lightening would sit at some height in
every cell and read as "lightening at every level" through the depth, which is
exactly the per-block individuality we want gone.

Water still gets a three-tile pool (`water_01..._03.png`, hashed per cell) plus a
representative `water.png` icon, but the three tiles are BYTE-IDENTICAL -- the
pool only exists to feed the runtime's variant path; there is deliberately no
variety, so a filled pool is perfectly uniform.

The only bright mark on water is the single waterline where the body meets air.
That is NOT baked in here (it would repeat on every submerged tile and stripe the
depth) -- the runtime lightens only the true top-surface row of a pool. See
world.gd `_liquid_fill_textures`'s surface pass and blocks.json
`liquid_surface_sheen`.

This is the authoritative source for the live water tiles; the earlier pass-2
review package (build_world_depths_fluids_pass2.py) no longer promotes them.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "generated" / "blocks"
TILE = 16
VARIANTS = 3

RGBA = tuple[int, int, int, int]

# One base blue shared by every tile so a body of water is a single flat colour
# no matter how many cells it spans.
BASE: RGBA = (32, 84, 138, 255)


def _tile() -> Image.Image:
    # Dead flat, fully opaque: no ripples, marks, or gradient -- the pool is one
    # thing. The surface waterline is added by the runtime only where it meets air.
    return Image.new("RGBA", (TILE, TILE), BASE)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    pool = [_tile() for _ in range(VARIANTS)]
    pool[0].save(OUT / "water.png")                 # representative icon
    for i, img in enumerate(pool):
        img.save(OUT / f"water_{i + 1:02d}.png")    # in-world pool
    print(f"PASS: wrote water.png + _01..._{VARIANTS:02d}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
