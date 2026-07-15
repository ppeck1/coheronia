#!/usr/bin/env python3
"""Restore the exact runtime skin palette in authored player variants.

PlayerVisual's appearance bridge deliberately recolors exact palette entries
inside species-specific skin regions. Image-generation output is normalized to
Coheronia's small palette, but its near-match skin tones must be mapped back to
the configured byte-exact colors before promotion.

The script uses the canonical body's known skin pixels as spatial samples,
chooses the closest luminance-preserving source-color assignment, and replaces
those source colors throughout the variant. Replacing whole palette entries
keeps the visible color count bounded and avoids a partially recolored face or
arm when the same generated tone is reused on adjacent pixels.
"""

from __future__ import annotations

import argparse
import itertools
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_PLAYERS = ROOT / "art" / "generated" / "players"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_PLAYERS)
    parser.add_argument("--output-dir", required=True, type=Path)
    return parser


def _rgb(raw_hex: str) -> tuple[int, int, int]:
    return tuple(bytes.fromhex(raw_hex))


def _luminance(color: tuple[int, int, int]) -> float:
    red, green, blue = color
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def _distance(left: tuple[int, int, int],
              right: tuple[int, int, int]) -> int:
    return sum((a - b) ** 2 for a, b in zip(left, right))


def _region_points(regions: list, width: int, height: int):
    for raw in regions:
        if not isinstance(raw, list) or len(raw) != 4:
            continue
        x0, y0, region_width, region_height = map(int, raw)
        for y in range(max(0, y0), min(height, y0 + region_height)):
            for x in range(max(0, x0), min(width, x0 + region_width)):
                yield x, y


def _best_mapping(candidates: set[tuple[int, int, int]],
                  palette: list[tuple[int, int, int]]):
    if len(candidates) < len(palette):
        raise ValueError(
            f"only {len(candidates)} sampled colors for {len(palette)} targets"
        )
    ordered_targets = sorted(palette, key=_luminance)
    best_cost: int | None = None
    best_mapping: dict[tuple[int, int, int], tuple[int, int, int]] = {}
    for choice in itertools.combinations(candidates, len(ordered_targets)):
        ordered_sources = sorted(choice, key=_luminance)
        cost = sum(
            _distance(source, target)
            for source, target in zip(ordered_sources, ordered_targets)
        )
        if best_cost is None or cost < best_cost:
            best_cost = cost
            best_mapping = dict(zip(ordered_sources, ordered_targets))
    return best_mapping


def _base_id(path: Path) -> str:
    base, sep, suffix = path.stem.rpartition("_")
    if not sep or len(suffix) != 2 or not suffix.isdigit():
        raise ValueError(f"not a player variant name: {path.name}")
    return base


def main() -> int:
    args = _parser().parse_args()
    config = json.loads(
        (ROOT / "data" / "player_visuals.json").read_text(encoding="utf-8")
    )
    rigs = config.get("rigs", {})
    args.output_dir.mkdir(parents=True, exist_ok=True)
    processed = 0

    for path in sorted(args.source_dir.glob("*_??.png")):
        body_id = _base_id(path)
        species_id = body_id.split("_", 1)[0]
        rig = rigs.get(species_id, {})
        palette = [_rgb(raw) for raw in rig.get("skin_palette", [])]
        regions = rig.get("skin_regions", [])
        canonical_path = args.source_dir / f"{body_id}.png"
        if not palette or not canonical_path.is_file():
            raise ValueError(f"missing rig palette or canonical for {body_id}")

        canonical = Image.open(canonical_path).convert("RGBA")
        variant = Image.open(path).convert("RGBA")
        if canonical.size != variant.size:
            raise ValueError(f"{path.name}: canvas differs from canonical")

        canonical_skin_points = []
        for x, y in _region_points(regions, variant.width, variant.height):
            canonical_pixel = canonical.getpixel((x, y))
            if canonical_pixel[3] and canonical_pixel[:3] in palette:
                canonical_skin_points.append((x, y))
        candidates = {
            variant.getpixel((x, y))[:3]
            for x, y in canonical_skin_points
            if variant.getpixel((x, y))[3]
        }
        mapping = _best_mapping(candidates, palette)

        pixels = []
        source_pixels = (
            variant.get_flattened_data()
            if hasattr(variant, "get_flattened_data")
            else variant.getdata()
        )
        for red, green, blue, alpha in source_pixels:
            replacement = mapping.get((red, green, blue), (red, green, blue))
            pixels.append((*replacement, alpha))
        variant.putdata(pixels)

        hits = {color: 0 for color in palette}
        for x, y in _region_points(regions, variant.width, variant.height):
            color = variant.getpixel((x, y))[:3]
            if color in hits:
                hits[color] += 1
        missing = [color for color, count in hits.items() if count == 0]
        if missing:
            raise ValueError(f"{path.name}: restored palette misses {missing}")

        output_path = args.output_dir / path.name
        variant.save(output_path)
        processed += 1
        pretty_mapping = ", ".join(
            f"#{''.join(f'{c:02x}' for c in source)}->"
            f"#{''.join(f'{c:02x}' for c in target)}"
            for source, target in sorted(mapping.items(), key=lambda item: _luminance(item[0]))
        )
        print(f"{path.name}: {pretty_mapping}; region hits={list(hits.values())}")

    print(f"Wrote {processed} palette-restored player variants to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
