#!/usr/bin/env python3
"""Normalize reviewed image-model output into Coheronia's pixel contracts.

Transparent sources must have their chroma key removed first with the installed
imagegen helper. This script then crops, scales, palette-reduces, hardens alpha,
and optionally makes opposite tile edges identical.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    parser.add_argument("--palette", type=int, default=16)
    parser.add_argument("--transparent", action="store_true")
    parser.add_argument("--tileable", action="store_true")
    parser.add_argument("--tileable-horizontal", action="store_true")
    parser.add_argument("--tileable-vertical", action="store_true")
    parser.add_argument("--anchor", choices=("center", "bottom"), default="center")
    parser.add_argument("--padding", type=int, default=0)
    parser.add_argument("--headroom", type=int, default=0)
    return parser


def _hard_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    source_pixels = (
        rgba.get_flattened_data()
        if hasattr(rgba, "get_flattened_data")
        else rgba.getdata()
    )
    for red, green, blue, alpha in source_pixels:
        pixels.append((red, green, blue, 255 if alpha >= 128 else 0))
    rgba.putdata(pixels)
    return rgba


def _palette_reduce(image: Image.Image, colors: int) -> Image.Image:
    return image.quantize(
        colors=max(2, colors),
        method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE,
    ).convert("RGBA")


def _fit_transparent(source: Image.Image, width: int, height: int,
                     colors: int, padding: int, headroom: int,
                     anchor: str) -> Image.Image:
    source = _hard_alpha(source)
    alpha_box = source.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("transparent source has no opaque subject pixels")
    subject = source.crop(alpha_box)
    inner_width = max(1, width - 2 * padding)
    inner_height = max(1, height - 2 * padding - headroom)
    scale = min(inner_width / subject.width, inner_height / subject.height)
    fitted_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(fitted_size, Image.Resampling.BOX)
    subject = _hard_alpha(_palette_reduce(subject, colors))
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = (width - subject.width) // 2
    if anchor == "bottom":
        y = height - padding - subject.height
    else:
        y = headroom + (inner_height - subject.height) // 2
    canvas.alpha_composite(subject, (x, y))
    return canvas


def _fit_opaque(source: Image.Image, width: int, height: int,
                colors: int) -> Image.Image:
    rgba = source.convert("RGBA")
    source_ratio = rgba.width / rgba.height
    target_ratio = width / height
    if source_ratio > target_ratio:
        crop_width = round(rgba.height * target_ratio)
        left = (rgba.width - crop_width) // 2
        rgba = rgba.crop((left, 0, left + crop_width, rgba.height))
    elif source_ratio < target_ratio:
        crop_height = round(rgba.width / target_ratio)
        top = (rgba.height - crop_height) // 2
        rgba = rgba.crop((0, top, rgba.width, top + crop_height))
    rgba = rgba.resize((width, height), Image.Resampling.BOX)
    rgba = _palette_reduce(rgba, colors)
    opaque = Image.new("RGBA", (width, height), (0, 0, 0, 255))
    opaque.paste(rgba.convert("RGB"))
    return opaque


def _make_tileable(image: Image.Image, horizontal: bool,
                   vertical: bool) -> Image.Image:
    result = image.copy()
    pixels = result.load()
    if horizontal:
        for y in range(result.height):
            pixels[result.width - 1, y] = pixels[0, y]
    if vertical:
        for x in range(result.width):
            pixels[x, result.height - 1] = pixels[x, 0]
    return result


def main() -> int:
    args = _parser().parse_args()
    source = Image.open(args.input)
    if args.transparent:
        result = _fit_transparent(
            source, args.width, args.height, args.palette, args.padding,
            args.headroom, args.anchor,
        )
    else:
        result = _fit_opaque(source, args.width, args.height, args.palette)
    horizontal = args.tileable or args.tileable_horizontal
    vertical = args.tileable or args.tileable_vertical
    if horizontal or vertical:
        result = _make_tileable(result, horizontal, vertical)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
