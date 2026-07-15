#!/usr/bin/env python3
"""FQ-13P3 — generate legacy demonstration player cosmetic variants.

Writes <body_id>_NN.png cosmetic variants next to the canonical player body art
so the FQ-13P full-body-pool mechanic has real pools to select from. Each variant
recolors only the darker "garment" pixels (hat/trousers/boots) via an HSV hue
replacement, leaving the lighter skin untouched — a deliberate placeholder
alternate outfit, replaceable one PNG at a time. Deterministic and idempotent.

These are variant 1..N; the canonical <body_id>.png stays variant 0.

The repo now ships reviewed authored variants. This helper therefore refuses to
overwrite an existing `_NN.png` unless `--force-demo` is passed explicitly.

Run: python scripts/gen_player_variants.py [--force-demo]
"""
from __future__ import annotations
import argparse
import colorsys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PLAYERS = ROOT / "art" / "generated" / "players"

# body_id -> list of garment hues (degrees) for _01, _02, ...
VARIANTS = {
    "human": [210, 130],   # a blue outfit, then a green outfit
}
GARMENT_LUMA_MAX = 0.52  # pixels darker than this are treated as garment


def luma(r, g, b):
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0


def recolor(img: Image.Image, hue_deg: float) -> Image.Image:
    out = img.copy()
    px = out.load()
    h = (hue_deg % 360) / 360.0
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if luma(r, g, b) > GARMENT_LUMA_MAX:
                continue  # keep skin / bright pixels
            _, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            nr, ng, nb = colorsys.hsv_to_rgb(h, max(s, 0.35), v)
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force-demo", action="store_true",
                        help="overwrite reviewed variants with demo hue swaps")
    args = parser.parse_args()
    for body_id, hues in VARIANTS.items():
        base_path = PLAYERS / f"{body_id}.png"
        if not base_path.is_file():
            print(f"skip {body_id}: no canonical {base_path.name}")
            continue
        base = Image.open(base_path).convert("RGBA")
        for i, hue in enumerate(hues, start=1):
            output_path = PLAYERS / f"{body_id}_{i:02d}.png"
            if output_path.is_file() and not args.force_demo:
                print(f"keep art/generated/players/{output_path.name} "
                      "(reviewed variant already exists)")
                continue
            variant = recolor(base, hue)
            assert variant.size == base.size, body_id
            variant.save(output_path)
            print(f"wrote art/generated/players/{body_id}_{i:02d}.png (hue {hue})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
