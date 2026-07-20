#!/usr/bin/env python3
"""PR-03B semi-automated helmet/head-contact check.

Verifies that every live body's authored crude helmet overlay, after its
data-owned rig ``gear_offset``, sits on the head instead of floating above it.
Reads the shipped PNGs for analysis only -- it never edits, regenerates, or
replaces any game asset. Run alongside the other art verifiers.

Contract: for each of the ten body ids, the helmet overlay's opaque top row
(shifted by ``rigs.<species>.gear_offset.helmet`` dy) must land within
``MAX_HELMET_GAP`` pixels of the body art's opaque top row, i.e. the helmet
caps the head rather than floating in the empty space above a shorter rig.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
# Helmet opaque top must be within this many pixels of the body opaque top.
MAX_HELMET_GAP = 4


def opaque_top(path: Path) -> int | None:
    image = Image.open(path).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    for y in range(height):
        if any(pixels[x, y][3] > 10 for x in range(width)):
            return y
    return None


def fail(message: str) -> None:
    print(f"FAIL gear helmet alignment: {message}")
    sys.exit(1)


def main() -> None:
    player_visuals = json.loads(
        (ROOT / "data/player_visuals.json").read_text(encoding="utf-8"))
    suffixes = player_visuals.get("body_variant_asset_suffix", {})
    species = player_visuals.get("live_species", [])
    rigs = player_visuals.get("rigs", {})

    checked = 0
    for species_id in species:
        rig = rigs.get(species_id, {})
        helmet_dy = 0
        raw = rig.get("gear_offset", {}).get("helmet")
        if isinstance(raw, list) and len(raw) >= 2:
            helmet_dy = int(raw[1])
        for suffix in suffixes.values():
            body_id = f"{species_id}{suffix}"
            body_path = ROOT / "art/generated/players" / f"{body_id}.png"
            helmet_path = ROOT / "art/generated/player_gear" / f"helmet_crude_{body_id}.png"
            if not body_path.is_file() or not helmet_path.is_file():
                continue
            body_top = opaque_top(body_path)
            helmet_top = opaque_top(helmet_path)
            if body_top is None or helmet_top is None:
                continue
            checked += 1
            gap = abs((helmet_top + helmet_dy) - body_top)
            if gap > MAX_HELMET_GAP:
                fail(
                    f"{body_id}: helmet opaque top {helmet_top}+offset {helmet_dy}"
                    f"={helmet_top + helmet_dy} vs body top {body_top} (gap {gap}"
                    f" > {MAX_HELMET_GAP}); tune rigs.{species_id}.gear_offset.helmet")
    if checked == 0:
        fail("no body/helmet pairs found to check")
    print(f"PASS gear helmet alignment: {checked} body ids within "
          f"{MAX_HELMET_GAP}px head contact")


if __name__ == "__main__":
    main()
