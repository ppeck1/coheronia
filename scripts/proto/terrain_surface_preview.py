#!/usr/bin/env python3
"""PROTOTYPE — terrain surface shaping, Stage S1 (offline profile preview).

Offline preview ONLY. Touches nothing in the game: no collision, movement,
targeting, fluid, saves, or rendering. It prototypes the deterministic surface
profile from docs/WORK_ORDER_TERRAIN_SURFACE_SHAPING.md so we can judge the look +
the invariants before any engine change:

  * d(u) = clamp(b(u) + a*N(x_world/lambda), 0, 2)  -- INWARD only (0..2 native px
    recessed into the top face), so it can never add ground into a neighbour's air.
  * SHARED world-space boundary endpoints: a tile's left/right edge is read from
    ONE world-boundary function, so adjacent tiles meet exactly -> no cracks.
  * 3 samples/tile (left/mid/right) joined by straight segments; endpoints
    quantized to native px -> a small, bounded, reusable profile set.
  * Own noise channel (surface_shape_version offsets it), deterministic from
    seed + version + world x.

Exposed natural surfaces only (grass/dirt/selected stone TOP faces); constructed/
protected/buried interfaces keep square shapes (shown flat here). This softens an
edge by up to 2 px; it does NOT bridge a full 16px terrain step (out of scope).

    python scripts/proto/terrain_surface_preview.py
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"

T = 16                 # tile width in native px
PX = T                 # render 1 native px = 1 image px (montage upscales 2x)
MAX_D = 2              # max inward displacement (native px)
LAM = 11.0             # noise wavelength (native px) — how gradually d changes
BASE = 1.0             # d around this...
AMP = 1.15             # ...+/- this * noise, then clamped to [0,2]

SKY = (104, 150, 204)
GRASS = (96, 150, 74)
GRASS_TOP = (120, 172, 92)     # 1px lit lip on the shaped surface
DIRT = (132, 96, 60)
STONE = (122, 126, 134)
BG = (26, 30, 36)


def _field(seed: int, g: int = 1024) -> np.ndarray:
    return np.random.default_rng(seed & 0xFFFFFFFF).random(g)


def _vnoise(field: np.ndarray, x: float) -> float:
    """1D cosine-interpolated value noise in [0,1), wrapping (deterministic)."""
    g = len(field)
    x0 = math.floor(x)
    f = x - x0
    s = 0.5 * (1.0 - math.cos(math.pi * f))
    return field[x0 % g] * (1.0 - s) + field[(x0 + 1) % g] * s


def d_boundary(field: np.ndarray, version: int, x_world: float) -> int:
    """Inward displacement (native px, quantized 0..MAX_D) at a WORLD-pixel
    boundary x. Shared by the two tiles meeting at x -> seam-free."""
    n = 2.0 * _vnoise(field, x_world / LAM + version * 7.0) - 1.0      # [-1,1]
    return int(round(min(MAX_D, max(0.0, BASE + AMP * n))))


def tile_profile(field: np.ndarray, version: int, col: int) -> tuple[int, int, int]:
    """(left, mid, right) inward px for a tile, endpoints from the shared world
    boundary so neighbours agree; mid sampled at the tile centre."""
    left = d_boundary(field, version, col * T)
    right = d_boundary(field, version, (col + 1) * T)
    mid = d_boundary(field, version, col * T + T / 2.0)
    return left, mid, right


def _d_at(profile: tuple[int, int, int], u: int) -> int:
    """Segment height at local px u in [0,T): left->mid->right, rounded to px."""
    left, mid, right = profile
    if u < T / 2:
        d = left + (mid - left) * (u / (T / 2.0))
    else:
        d = mid + (right - mid) * ((u - T / 2.0) / (T / 2.0))
    return int(round(d))


# --- A small illustrative terrain surface (flat runs + a couple of 16px steps) --
def _surface_y(col: int) -> int:
    y = 4
    if 11 <= col <= 18:
        y += 1
    if col >= 22:
        y += 1
    return y


def render_strip(seed: int, version: int, cols: int, rows: int, shaped: bool) -> Image.Image:
    field = _field(seed + 0x5EED)            # own noise channel
    W, H = cols * PX, rows * PX
    img = Image.new("RGB", (W, H), SKY)
    px = img.load()
    for col in range(cols):
        y0 = _surface_y(col)
        prof = tile_profile(field, version, col) if shaped else (0, 0, 0)
        for u in range(T):
            x = col * PX + u
            d = _d_at(prof, u) if shaped else 0           # recess the grass TOP
            top = y0 * PX + d
            for y in range(H):
                if y < top:
                    continue                               # sky (recessed/air)
                cell = y // PX
                if cell == y0:
                    px[x, y] = GRASS_TOP if y < top + 1 else GRASS
                elif cell in (y0 + 1, y0 + 2):
                    px[x, y] = DIRT
                else:
                    px[x, y] = STONE
    return img


def _seam_ok(seed: int, version: int, cols: int) -> bool:
    """Adjacent tiles must share their boundary value exactly (no crack)."""
    field = _field(seed + 0x5EED)
    for col in range(cols - 1):
        if tile_profile(field, version, col)[2] != tile_profile(field, version, col + 1)[0]:
            return False
    return True


def _max_angle(seed: int, version: int, cols: int) -> float:
    field = _field(seed + 0x5EED)
    worst = 0.0
    for col in range(cols):
        left, mid, right = tile_profile(field, version, col)
        worst = max(worst, abs(mid - left), abs(right - mid))       # rise over T/2 px
    return math.degrees(math.atan2(worst, T / 2.0))


def _profile_set(seed: int, version: int, cols: int) -> set:
    field = _field(seed + 0x5EED)
    return {tile_profile(field, version, c) for c in range(cols)}


def _scale2x(im: Image.Image) -> Image.Image:
    return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


def _montage(rows, row_labels, title, out):
    pad, top, lh = 12, 24, 14
    w = max(sum(im.width for im in r) + pad * (len(r) + 1) for r in rows)
    h = top + sum(max(im.height for im in r) + lh + pad for r in rows) + pad
    canvas = Image.new("RGB", (w, h), (18, 18, 22))
    d = ImageDraw.Draw(canvas)
    d.text((8, 8), title, fill=(235, 235, 235))
    y = top
    for r, lab in zip(rows, row_labels):
        d.text((8, y), lab, fill=(190, 205, 190))
        y += lh
        x = pad
        for im in r:
            canvas.paste(im, (x, y))
            x += im.width + pad
        y += max(im.height for im in r) + pad
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    print(f"  preview -> {out.relative_to(ROOT)}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cols", type=int, default=28)
    ap.add_argument("--rows", type=int, default=9)
    ap.add_argument("--version", type=int, default=1)
    args = ap.parse_args()
    seeds = [1, 7, 42]
    ok = True

    # Compare: flat (square tops) vs shaped, same seed.
    flat = _scale2x(render_strip(seeds[0], args.version, args.cols, args.rows, False))
    shaped = _scale2x(render_strip(seeds[0], args.version, args.cols, args.rows, True))
    _montage([[flat], [shaped]],
             ["BEFORE — square tops (no shaping)",
              "AFTER — 0-2px inward micro-relief (exposed grass tops)"],
             "S1 terrain surface shaping — before/after (game scale, 2x)",
             BUILD / "terrain_s1_compare.png")

    # Variety across seeds (shaped).
    imgs = [_scale2x(render_strip(s, args.version, args.cols, args.rows, True)) for s in seeds]
    _montage([[im] for im in imgs], [f"seed {s}" for s in seeds],
             "S1 terrain surface shaping — variety across seeds",
             BUILD / "terrain_s1_seeds.png")

    for s in seeds:
        seam = _seam_ok(s, args.version, args.cols)
        # determinism: recompute profile set, must be stable
        det = _profile_set(s, args.version, args.cols) == _profile_set(s, args.version, args.cols)
        ok &= seam and det
        print(f"  seed {s}: seam_free={seam} deterministic={det} "
              f"profiles={len(_profile_set(s, args.version, args.cols))} "
              f"max_angle={_max_angle(s, args.version, args.cols):.1f}deg")
    # version independence: a different surface_shape_version gives a different surface
    diff_ver = _profile_set(seeds[0], args.version, args.cols) != _profile_set(seeds[0], args.version + 1, args.cols)
    print(f"  version changes the surface: {diff_ver}")
    print(f"  all seam-free & deterministic: {ok}")
    return 0 if (ok and diff_ver) else 1


if __name__ == "__main__":
    raise SystemExit(main())
