#!/usr/bin/env python3
"""Render integer-zoom contact sheets for Coheronia sprite review."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
ASSET_ROOT = ROOT / "art" / "generated"
DEFAULT_CATEGORIES = (
    "blocks", "items", "enemies", "players", "player_gear", "structures",
    "ui", "back_walls",
)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source-root", type=Path, default=ASSET_ROOT,
                        help="category root (defaults to art/generated)")
    parser.add_argument("--category", action="append", choices=DEFAULT_CATEGORIES)
    parser.add_argument("--columns", type=int, default=5)
    return parser


def main() -> int:
    args = _parser().parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    categories = tuple(args.category or DEFAULT_CATEGORIES)
    columns = max(1, args.columns)

    for category in categories:
        files = sorted((args.source_root / category).glob("*.png"))
        if not files:
            continue
        cell_width = 150
        cell_height = 145
        rows = (len(files) + columns - 1) // columns
        sheet = Image.new(
            "RGBA", (columns * cell_width, rows * cell_height),
            (24, 27, 35, 255),
        )
        draw = ImageDraw.Draw(sheet)

        for index, file_path in enumerate(files):
            image = Image.open(file_path).convert("RGBA")
            scale = max(1, min(96 // image.width, 96 // image.height))
            preview = image.resize(
                (image.width * scale, image.height * scale),
                Image.Resampling.NEAREST,
            )
            cell_x = (index % columns) * cell_width
            cell_y = (index // columns) * cell_height
            x = cell_x + (cell_width - preview.width) // 2
            sheet.alpha_composite(preview, (x, cell_y + 8))
            draw.text(
                (cell_x + 4, cell_y + 108), file_path.stem,
                fill=(245, 245, 245, 255),
            )
            draw.text(
                (cell_x + 4, cell_y + 124),
                f"{image.width}x{image.height}",
                fill=(170, 180, 190, 255),
            )

        output_path = args.output / f"{category}_contact.png"
        sheet.save(output_path)
        print(output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
