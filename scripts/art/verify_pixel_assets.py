#!/usr/bin/env python3
"""Verify Coheronia's repo-native pixel-art contracts.

This complements scripts/asset_audit.py: the audit checks runtime ids, pools,
and dimensions, while this verifier checks palette, alpha, cutout corners, and
the explicit tile-edge rules that a PNG header cannot prove.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "art" / "generated"
PIXEL_CATEGORIES = {
    "blocks", "items", "enemies", "players", "player_gear", "structures",
    "ui", "back_walls",
}
CUTOUT_CATEGORIES = {"items", "enemies", "players", "player_gear", "structures"}
HARD_ALPHA_CATEGORIES = PIXEL_CATEGORIES - {"ui"}
BOTH_EDGE_BLOCKS = {
    "dirt", "stone", "ore", "wood", "coal", "copper_ore", "tin_ore",
    "iron_ore", "silver_ore", "crystal", "farm_soil",
}
HORIZONTAL_EDGE_BLOCKS = {"grass"}
CUTOUT_BLOCKS = {
    "berry_bush", "crop_ripe", "crop_seedling", "lantern", "torch",
    "tree_leaves", "tree_trunk",
}
OPAQUE_BLOCKS = BOTH_EDGE_BLOCKS | HORIZONTAL_EDGE_BLOCKS | {"town_hall_core"}


def _pixels(image: Image.Image):
    return (
        image.get_flattened_data()
        if hasattr(image, "get_flattened_data")
        else image.getdata()
    )


def _base_id(path: Path) -> str:
    stem = path.stem
    base, sep, suffix = stem.rpartition("_")
    return base if sep and len(suffix) == 2 and suffix.isdigit() else stem


def _expected_size(raw_sizes: dict, category: str):
    raw = raw_sizes.get(category)
    if isinstance(raw, list):
        return int(raw[0]), int(raw[1])
    if isinstance(raw, int):
        return raw, raw
    return None


def _edges_match(image: Image.Image, horizontal: bool, vertical: bool) -> bool:
    if horizontal and any(
        image.getpixel((0, y)) != image.getpixel((image.width - 1, y))
        for y in range(image.height)
    ):
        return False
    if vertical and any(
        image.getpixel((x, 0)) != image.getpixel((x, image.height - 1))
        for x in range(image.width)
    ):
        return False
    return True


def _alpha_bbox(image: Image.Image):
    return image.getchannel("A").getbbox()


def _skin_palette_hits(image: Image.Image, rig: dict):
    palette = {
        tuple(bytes.fromhex(str(raw_color)))
        for raw_color in rig.get("skin_palette", [])
    }
    hits = set()
    for raw_region in rig.get("skin_regions", []):
        if not isinstance(raw_region, list) or len(raw_region) != 4:
            continue
        x0, y0, width, height = map(int, raw_region)
        for y in range(max(0, y0), min(image.height, y0 + height)):
            for x in range(max(0, x0), min(image.width, x0 + width)):
                color = image.getpixel((x, y))[:3]
                if color in palette:
                    hits.add(color)
    return palette, hits


def _verify_painted(problems: list[str]) -> int:
    """FQ-20 painted-chrome lane: free-size RGBA renders sliced from the
    blueprint mockup. Exempt from the pixel-art palette/alpha contract; must
    simply be readable RGBA, bounded (<=320px), and non-empty."""
    directory = ASSET_ROOT / "ui_painted"
    checked = 0
    if not directory.is_dir():
        return checked
    for path in sorted(directory.glob("*.png")):
        checked += 1
        rel = path.relative_to(ROOT).as_posix()
        try:
            image = Image.open(path).convert("RGBA")
        except Exception as exc:  # pragma: no cover - exercised on bad files
            problems.append(f"{rel}: unreadable PNG ({exc})")
            continue
        if image.width > 320 or image.height > 320:
            problems.append(f"{rel}: {image.width}x{image.height} exceeds 320px chrome bound")
        if _alpha_bbox(image) is None:
            problems.append(f"{rel}: fully transparent")
    return checked


def main() -> int:
    manifest = json.loads(
        (ROOT / "data" / "visual_assets.json").read_text(encoding="utf-8")
    )
    sizes = manifest.get("target_sizes", {})
    player_visuals = json.loads(
        (ROOT / "data" / "player_visuals.json").read_text(encoding="utf-8")
    )
    player_rigs = player_visuals.get("rigs", {})
    problems: list[str] = []
    checked = 0

    for category in sorted(PIXEL_CATEGORIES):
        directory = ASSET_ROOT / category
        if not directory.is_dir():
            continue
        expected = _expected_size(sizes, category)
        for path in sorted(directory.glob("*.png")):
            checked += 1
            rel = path.relative_to(ROOT).as_posix()
            try:
                image = Image.open(path).convert("RGBA")
            except Exception as exc:  # pragma: no cover - exercised on bad files
                problems.append(f"{rel}: unreadable PNG ({exc})")
                continue

            if expected and image.size != expected:
                problems.append(
                    f"{rel}: {image.width}x{image.height} != "
                    f"{expected[0]}x{expected[1]}"
                )

            pixels = list(_pixels(image))
            alphas = {pixel[3] for pixel in pixels}
            if category in HARD_ALPHA_CATEGORIES and not alphas.issubset({0, 255}):
                problems.append(f"{rel}: soft alpha values {sorted(alphas - {0, 255})}")
            colors = {pixel[:3] for pixel in pixels if pixel[3] != 0}
            if len(colors) > 16:
                problems.append(f"{rel}: {len(colors)} visible colors > 16")

            base_id = _base_id(path)
            is_cutout = category in CUTOUT_CATEGORIES or (
                category == "blocks" and base_id in CUTOUT_BLOCKS
            )
            if is_cutout:
                corners = (
                    image.getpixel((0, 0))[3],
                    image.getpixel((image.width - 1, 0))[3],
                    image.getpixel((0, image.height - 1))[3],
                    image.getpixel((image.width - 1, image.height - 1))[3],
                )
                if any(corners):
                    problems.append(f"{rel}: cutout corners are not transparent")
                if 0 not in alphas:
                    problems.append(f"{rel}: cutout has no transparent pixels")
                if all(pixel[3] == 0 for pixel in pixels):
                    problems.append(f"{rel}: cutout has no visible pixels")

            if category == "blocks" and base_id in OPAQUE_BLOCKS \
                    and alphas != {255}:
                problems.append(f"{rel}: opaque block contract has transparency")

            if category == "blocks" and base_id in BOTH_EDGE_BLOCKS:
                if alphas != {255}:
                    problems.append(f"{rel}: homogeneous tile is not fully opaque")
                if not _edges_match(image, True, True):
                    problems.append(f"{rel}: opposite tile edges do not match")
            elif category == "blocks" and base_id in HORIZONTAL_EDGE_BLOCKS:
                if alphas != {255}:
                    problems.append(f"{rel}: crowned terrain tile is not fully opaque")
                if not _edges_match(image, True, False):
                    problems.append(f"{rel}: horizontal tile edges do not match")
            elif category == "back_walls":
                if alphas != {255}:
                    problems.append(f"{rel}: backing wall is not fully opaque")
                if not _edges_match(image, True, True):
                    problems.append(f"{rel}: backing-wall edges do not match")

            # Full-body alternatives must preserve the body's established
            # species scale and ground line. Exact canvas dimensions alone do
            # not catch a dwarf or goblin suddenly filling all 32 rows.
            if category == "players" and base_id != path.stem:
                canonical_path = directory / f"{base_id}.png"
                if canonical_path.is_file():
                    canonical = Image.open(canonical_path).convert("RGBA")
                    canonical_box = _alpha_bbox(canonical)
                    variant_box = _alpha_bbox(image)
                    if canonical_box and variant_box:
                        canonical_width = canonical_box[2] - canonical_box[0]
                        canonical_height = canonical_box[3] - canonical_box[1]
                        variant_width = variant_box[2] - variant_box[0]
                        variant_height = variant_box[3] - variant_box[1]
                        if abs(variant_height - canonical_height) > 2:
                            problems.append(
                                f"{rel}: body height {variant_height} drifts from "
                                f"canonical {canonical_height} by more than 2px"
                            )
                        if abs(variant_box[3] - canonical_box[3]) > 1:
                            problems.append(
                                f"{rel}: ground line {variant_box[3]} drifts from "
                                f"canonical {canonical_box[3]} by more than 1px"
                            )
                        if variant_width > canonical_width + 3:
                            problems.append(
                                f"{rel}: body width {variant_width} exceeds "
                                f"canonical {canonical_width} by more than 3px"
                            )

            # Appearance recoloring is an exact-color bridge. Generated
            # near-matches are visually plausible but make Pale/Umber/Ash a
            # silent no-op, so every body and Look must retain the full rig
            # palette inside its configured skin regions.
            if category == "players":
                species_id = base_id.split("_", 1)[0]
                rig = player_rigs.get(species_id, {})
                expected_skin, present_skin = _skin_palette_hits(image, rig)
                missing_skin = expected_skin - present_skin
                if missing_skin:
                    missing_hex = ", ".join(
                        "#" + "".join(f"{channel:02x}" for channel in color)
                        for color in sorted(missing_skin)
                    )
                    problems.append(
                        f"{rel}: missing exact skin palette colors in rig "
                        f"regions ({missing_hex})"
                    )

    checked += _verify_painted(problems)

    if problems:
        print(f"FAIL pixel assets: {len(problems)} problem(s) across {checked} PNGs")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print(f"PASS pixel assets: {checked} PNGs satisfy size/palette/alpha/edge contracts"
        " (painted chrome via the FQ-20 light pass)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
