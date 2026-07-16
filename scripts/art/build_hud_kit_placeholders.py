#!/usr/bin/env python3
"""Build the temporary Coheronia HUD-kit contract without mockup slicing.

These deliberately restrained placeholders establish filenames, alpha masks,
native dimensions, and integer layout geometry. They can be replaced one-for-
one by authored art without changing hud.gd.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art" / "source_templates" / "hud_dock"
GENERATED = ROOT / "art" / "generated" / "ui_painted"
W, H = 1280, 176


def _save(name: str, image: Image.Image) -> None:
    for directory in (SOURCE, GENERATED):
        directory.mkdir(parents=True, exist_ok=True)
        image.save(directory / name)


def _dock_layers() -> tuple[Image.Image, Image.Image]:
    back = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(back)
    d.rectangle((88, 44, W - 89, 163), fill=(25, 26, 27, 248))
    d.rectangle((88, 55, W - 89, 151), fill=(55, 38, 27, 255))
    for x in range(96, W - 96, 32):
        d.rectangle((x, 58, x + 25, 148), fill=(69, 45, 29, 255))
        d.line((x + 4, 60, x + 4, 146), fill=(93, 61, 37, 170))
        d.line((x + 22, 60, x + 22, 146), fill=(30, 25, 23, 220))
    trim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    t = ImageDraw.Draw(trim)
    t.rectangle((88, 44, W - 89, 55), fill=(47, 48, 46, 255))
    t.line((88, 44, W - 89, 44), fill=(143, 121, 78, 255), width=2)
    t.line((88, 55, W - 89, 55), fill=(10, 13, 15, 255), width=3)
    t.rectangle((88, 151, W - 89, 163), fill=(38, 39, 38, 255))
    t.line((88, 151, W - 89, 151), fill=(104, 87, 60, 255), width=2)
    t.line((88, 162, W - 89, 162), fill=(7, 9, 10, 255), width=3)
    for x in range(110, W - 100, 64):
        t.ellipse((x - 2, 48, x + 2, 52), fill=(151, 130, 89, 255))
    # Foreground trim renders above vessel frames. Keep both complete vessel
    # rectangles clear so a replacement rail can never butcher their chrome.
    t.rectangle((8, 8, 167, 167), fill=(0, 0, 0, 0))
    t.rectangle((1112, 8, 1271, 167), fill=(0, 0, 0, 0))
    return back, trim


def _vessel_frame(right_facing: bool, angular: bool = False) -> Image.Image:
    image = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    center = (80, 80)
    if angular:
        outer = [(80, 3), (137, 24), (157, 80), (137, 137),
                 (80, 157), (23, 137), (3, 80), (23, 24)]
        inner = [(80, 20), (126, 36), (140, 80), (126, 124),
                 (80, 140), (34, 124), (20, 80), (34, 36)]
        d.polygon(outer, fill=(32, 35, 38, 255), outline=(151, 129, 82, 255))
        d.polygon(inner, fill=(0, 0, 0, 0), outline=(10, 13, 16, 255), width=5)
    else:
        d.ellipse((3, 3, 157, 157), fill=(32, 35, 38, 255),
                  outline=(151, 129, 82, 255), width=3)
        d.ellipse((20, 20, 140, 140), fill=(0, 0, 0, 0),
                  outline=(10, 13, 16, 255), width=6)
    # Re-punch the live window after drawing the chassis.
    d.ellipse((26, 26, 134, 134), fill=(0, 0, 0, 0))
    connector = (0, 61, 24, 119) if right_facing else (136, 61, 159, 119)
    d.rectangle(connector, fill=(43, 44, 43, 255), outline=(12, 14, 15, 255), width=3)
    d.rectangle((54, 140, 106, 158), fill=(29, 31, 32, 255),
                outline=(111, 91, 57, 255), width=2)
    return image


def _round_mask(size: int = 108) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(image).ellipse((1, 1, size - 2, size - 2),
                                  fill=(255, 255, 255, 255))
    return image


def _facet_mask(size: int = 108) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    d.polygon([(54, 1), (94, 17), (107, 54), (94, 91), (54, 107),
               (14, 91), (1, 54), (14, 17)], fill=(255, 255, 255, 255))
    return image


def _glass(size: int = 108, angular: bool = False) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    if angular:
        d.line((18, 31, 52, 10, 89, 30), fill=(211, 238, 255, 80), width=2)
        d.line((54, 8, 54, 99), fill=(189, 228, 250, 42), width=2)
    else:
        d.arc((5, 5, size - 6, size - 6), 200, 330,
              fill=(220, 235, 240, 96), width=2)
        d.line((31, 20, 31, 61), fill=(235, 244, 246, 56), width=3)
    return image


def _slot(border: tuple[int, int, int, int], disabled: bool = False) -> Image.Image:
    image = Image.new("RGBA", (76, 84), (17, 18, 20, 245))
    d = ImageDraw.Draw(image)
    d.rectangle((1, 1, 74, 82), outline=border, width=3)
    d.rectangle((7, 8, 68, 76), outline=(10, 11, 12, 255), width=2)
    if disabled:
        d.rectangle((4, 4, 71, 79), fill=(8, 9, 11, 150))
    return image


def _button_frame(border: tuple[int, int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (54, 104), (22, 23, 25, 235))
    d = ImageDraw.Draw(image)
    d.rectangle((1, 1, 52, 102), outline=border, width=2)
    d.rectangle((7, 9, 46, 96), outline=(9, 11, 12, 255), width=2)
    return image


def _button_icon(kind: str) -> Image.Image:
    image = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)
    ink = (213, 180, 107, 255)
    if kind == "inventory":
        d.rectangle((6, 11, 26, 26), outline=ink, width=2)
        d.arc((10, 4, 22, 16), 180, 360, fill=ink, width=2)
    elif kind == "character":
        d.ellipse((11, 4, 21, 14), outline=ink, width=2)
        d.rectangle((8, 16, 24, 28), outline=ink, width=2)
    elif kind == "skills":
        d.polygon([(16, 3), (20, 12), (29, 16), (20, 20), (16, 29),
                   (12, 20), (3, 16), (12, 12)], outline=ink)
    else:
        d.polygon([(4, 15), (16, 5), (28, 15)], outline=ink)
        d.rectangle((7, 14, 25, 28), outline=ink, width=2)
        d.rectangle((14, 19, 19, 28), outline=ink, width=1)
    return image


def main() -> int:
    back, trim = _dock_layers()
    assets = {
        "dock_backplate.png": back,
        "dock_foreground_trim.png": trim,
        "health_frame.png": _vessel_frame(False),
        "health_glass_overlay.png": _glass(),
        "health_fill_mask.png": _round_mask(),
        "attunement_frame.png": _vessel_frame(True, True),
        "attunement_glass_overlay.png": _glass(angular=True),
        "attunement_fill_mask.png": _facet_mask(),
        "slot_normal.png": _slot((92, 80, 61, 255)),
        "slot_selected.png": _slot((221, 178, 72, 255)),
        "slot_hover.png": _slot((151, 185, 202, 255)),
        "slot_disabled.png": _slot((67, 69, 72, 255), True),
        "button_frame_normal.png": _button_frame((91, 78, 58, 255)),
        "button_frame_hover.png": _button_frame((207, 171, 91, 255)),
        "button_frame_pressed.png": _button_frame((242, 195, 77, 255)),
    }
    for kind in ("inventory", "character", "skills", "town_hall"):
        assets[f"button_icon_{kind}.png"] = _button_icon(kind)
    for name, image in assets.items():
        _save(name, image)

    required_assets = sorted(assets)
    layout = {
        "version": 2,
        "native_size": [W, H],
        "required_assets": required_assets,
        "asset_sizes": {
            name: [image.width, image.height]
            for name, image in sorted(assets.items())
        },
        "decorative_layers": [
            {
                "name": "DockBackplate",
                "asset": "dock_backplate.png",
                "rect": [0, 0, W, H],
                "z": 0,
                "role": "backplate",
            },
            {
                "name": "DockForegroundTrim",
                "asset": "dock_foreground_trim.png",
                "rect": [0, 0, W, H],
                "z": 3,
                "role": "foreground_trim",
            },
        ],
        "alpha_rules": {
            "dock_backplate.png": {
                "min_coverage": 0.25,
                "max_coverage": 0.75,
            },
            "dock_foreground_trim.png": {
                "min_coverage": 0.01,
                "max_coverage": 0.15,
                "transparent_rects": [[8, 8, 160, 160], [1112, 8, 160, 160]],
            },
            "health_fill_mask.png": {"binary_alpha": True},
            "attunement_fill_mask.png": {"binary_alpha": True},
            "health_glass_overlay.png": {"max_coverage": 0.15},
            "attunement_glass_overlay.png": {"max_coverage": 0.15},
            "button_icon_inventory.png": {"safe_padding": 2},
            "button_icon_character.png": {"safe_padding": 2},
            "button_icon_skills.png": {"safe_padding": 2},
            "button_icon_town_hall.png": {"safe_padding": 2},
        },
        "mask_relationships": [
            {
                "mask": "health_fill_mask.png",
                "frame": "health_frame.png",
                "frame_offset": [26, 26],
                "glass": "health_glass_overlay.png",
            },
            {
                "mask": "attunement_fill_mask.png",
                "frame": "attunement_frame.png",
                "frame_offset": [26, 26],
                "glass": "attunement_glass_overlay.png",
            },
        ],
        "state_families": {
            "slots": [
                "slot_normal.png",
                "slot_selected.png",
                "slot_hover.png",
                "slot_disabled.png",
            ],
            "buttons": [
                "button_frame_normal.png",
                "button_frame_hover.png",
                "button_frame_pressed.png",
            ],
        },
        "dock": {
            "rect": [0, 0, W, H],
            "backplate_rect": [0, 0, W, H],
            "foreground_trim_rect": [0, 0, W, H],
            "safe_bottom": 8,
        },
        "control_rail_y": 48,
        "health": {
            "frame_rect": [8, 8, 160, 160],
            "fill_rect": [34, 34, 108, 108],
            "glass_rect": [34, 34, 108, 108],
            "label_rect": [48, 79, 80, 18],
        },
        "attunement": {
            "frame_rect": [1112, 8, 160, 160],
            "fill_rect": [1138, 34, 108, 108],
            "glass_rect": [1138, 34, 108, 108],
            "label_rect": [1152, 79, 80, 18],
        },
        "slots": [[435 + i * 82, 48, 76, 84] for i in range(5)],
        "slot_content": {
            "icon_rect": [23, 20, 30, 30],
            "count_rect": [45, 60, 24, 16],
            "hotkey_rect": [7, 6, 16, 14],
        },
        "buttons": {
            "inventory": [311, 48, 54, 104],
            "character": [371, 48, 54, 104],
            "skills": [851, 48, 54, 104],
            "town_hall": [911, 48, 54, 104],
        },
        "button_content": {
            "icon_rect": [11, 16, 32, 32],
            "label_rect": [3, 66, 48, 28],
        },
        "selected_item_chip_rect": [176, 8, 246, 32],
        "mining_progress_rect": [550, 28, 180, 10],
    }
    text = json.dumps(layout, indent=2) + "\n"
    for directory in (SOURCE, GENERATED):
        (directory / "hud_dock_layout.json").write_text(text, encoding="utf-8")
    print(f"wrote {len(assets)} HUD-kit assets + layout to source and runtime")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
