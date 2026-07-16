#!/usr/bin/env python3
"""Render native-size HUD-kit review aids without touching runtime assets.

The composite proves how authored chrome behaves with representative runtime
children. The guide turns JSON rectangles and foreground keep-outs into a file
that can be attached to an image-editing task.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art" / "source_templates" / "hud_dock"
LAYOUT = SOURCE / "hud_dock_layout.json"
COMPOSITE_NAME = "hud_dock_composite_preview.png"
GUIDE_NAME = "hud_dock_runtime_guide.png"


def _rect(raw: list[int]) -> tuple[int, int, int, int]:
    x, y, width, height = map(int, raw)
    return x, y, x + width, y + height


def _local_rect(raw: list[int], origin: tuple[int, int]) -> tuple[int, int, int, int]:
    x, y, right, bottom = _rect(raw)
    return x + origin[0], y + origin[1], right + origin[0], bottom + origin[1]


def _open_asset(name: str) -> Image.Image:
    with Image.open(SOURCE / name) as raw:
        return raw.convert("RGBA")


def _paste(canvas: Image.Image, image: Image.Image, raw_rect: list[int]) -> None:
    x, y, right, bottom = _rect(raw_rect)
    target_size = (right - x, bottom - y)
    if image.size != target_size:
        image = image.resize(target_size, Image.Resampling.NEAREST)
    canvas.alpha_composite(image, (x, y))


def _masked_fill(mask_name: str, fraction: float, color: tuple[int, int, int, int]) -> Image.Image:
    mask = _open_asset(mask_name).getchannel("A")
    cutoff = int(round(mask.height * (1.0 - fraction)))
    for y in range(cutoff):
        for x in range(mask.width):
            mask.putpixel((x, y), 0)
    fill = Image.new("RGBA", mask.size, color)
    fill.putalpha(Image.eval(mask, lambda value: value * color[3] // 255))
    return fill


def render_composite(layout: dict) -> Image.Image:
    width, height = map(int, layout["native_size"])
    canvas = Image.new("RGBA", (width, height), (69, 89, 119, 255))
    layers = sorted(layout["decorative_layers"], key=lambda layer: int(layer["z"]))
    for layer in layers:
        if int(layer["z"]) <= 0:
            _paste(canvas, _open_asset(layer["asset"]), layer["rect"])

    health = layout["health"]
    attunement = layout["attunement"]
    _paste(canvas, _masked_fill("health_fill_mask.png", 0.62, (210, 29, 24, 255)), health["fill_rect"])
    _paste(
        canvas,
        _masked_fill("attunement_fill_mask.png", 0.74, (31, 153, 242, 255)),
        attunement["fill_rect"],
    )
    for vessel, prefix in ((health, "health"), (attunement, "attunement")):
        _paste(canvas, _open_asset(f"{prefix}_frame.png"), vessel["frame_rect"])
        _paste(canvas, _open_asset(f"{prefix}_glass_overlay.png"), vessel["glass_rect"])

    for layer in layers:
        if int(layer["z"]) > 0:
            _paste(canvas, _open_asset(layer["asset"]), layer["rect"])

    slot_states = [
        "slot_selected.png",
        "slot_hover.png",
        "slot_normal.png",
        "slot_disabled.png",
        "slot_normal.png",
    ]
    slot_colors = [(137, 91, 52, 255), (111, 79, 48, 255), (123, 132, 146, 255),
                   (205, 121, 36, 255), (70, 102, 65, 255)]
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default()
    content = layout["slot_content"]
    for index, (outer, state, color) in enumerate(zip(layout["slots"], slot_states, slot_colors)):
        _paste(canvas, _open_asset(state), outer)
        ox, oy = int(outer[0]), int(outer[1])
        icon_rect = _local_rect(content["icon_rect"], (ox, oy))
        draw.rounded_rectangle(icon_rect, radius=3, fill=color, outline=(224, 205, 153, 255))
        draw.text((icon_rect[0] + 9, icon_rect[1] + 8), "◆", font=font, fill=(244, 232, 196, 255))
        hotkey = _local_rect(content["hotkey_rect"], (ox, oy))
        count = _local_rect(content["count_rect"], (ox, oy))
        draw.text((hotkey[0] + 2, hotkey[1] + 1), str(index + 1), font=font,
                  fill=(226, 190, 110, 255))
        draw.text((count[0] + 8, count[1] + 1), str((index + 1) * 3), font=font,
                  fill=(245, 245, 242, 255))

    icon_names = {
        "inventory": "button_icon_inventory.png",
        "character": "button_icon_character.png",
        "skills": "button_icon_skills.png",
        "town_hall": "button_icon_town_hall.png",
    }
    labels = {"inventory": "Inventory", "character": "Character", "skills": "Skills", "town_hall": "Town Hall"}
    button_content = layout["button_content"]
    for name, outer in layout["buttons"].items():
        _paste(canvas, _open_asset("button_frame_normal.png"), outer)
        origin = (int(outer[0]), int(outer[1]))
        icon_rect = _local_rect(button_content["icon_rect"], origin)
        _paste(canvas, _open_asset(icon_names[name]), [icon_rect[0], icon_rect[1],
                                                       icon_rect[2] - icon_rect[0],
                                                       icon_rect[3] - icon_rect[1]])
        label_rect = _local_rect(button_content["label_rect"], origin)
        label = labels[name]
        if name == "town_hall":
            draw.text((label_rect[0] + 8, label_rect[1] + 1), "Town", font=font,
                      fill=(222, 218, 204, 255))
            draw.text((label_rect[0] + 10, label_rect[1] + 11), "Hall", font=font,
                      fill=(222, 218, 204, 255))
        else:
            text_width = draw.textbbox((0, 0), label, font=font)[2]
            draw.text((label_rect[0] + max(0, (label_rect[2] - label_rect[0] - text_width) // 2),
                       label_rect[1] + 6), label, font=font, fill=(222, 218, 204, 255))

    for vessel, value in ((health, "62 / 100"), (attunement, "37 / 50")):
        x, y, right, bottom = _rect(vessel["label_rect"])
        text_width = draw.textbbox((0, 0), value, font=font)[2]
        draw.text((x + (right - x - text_width) // 2, y + 4), value, font=font,
                  fill=(247, 247, 244, 255))
    chip = _rect(layout["selected_item_chip_rect"])
    draw.rectangle(chip, fill=(8, 18, 27, 235), outline=(80, 139, 160, 255), width=2)
    draw.text((chip[0] + 9, chip[1] + 10), "Pick tier 2 · Axe tier 1", font=font,
              fill=(230, 231, 226, 255))
    progress = _rect(layout["mining_progress_rect"])
    draw.rectangle(progress, fill=(12, 16, 19, 240), outline=(72, 75, 74, 255))
    draw.rectangle((progress[0] + 1, progress[1] + 1,
                    progress[0] + int((progress[2] - progress[0] - 2) * 0.58), progress[3] - 1),
                   fill=(199, 155, 64, 255))
    return canvas


def render_guide(layout: dict) -> Image.Image:
    width, height = map(int, layout["native_size"])
    guide = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(guide)
    font = ImageFont.load_default()

    def zone(raw: list[int], color: tuple[int, int, int, int], label: str) -> None:
        rect = _rect(raw)
        draw.rectangle(rect, fill=color, outline=color[:3] + (255,), width=1)
        draw.text((rect[0] + 2, rect[1] + 2), label, font=font, fill=(255, 255, 255, 255))

    for name, color in (("health", (190, 35, 35, 70)), ("attunement", (35, 110, 210, 70))):
        vessel = layout[name]
        zone(vessel["frame_rect"], color, "TRIM KEEP-OUT")
        zone(vessel["fill_rect"], color[:3] + (105,), "runtime fill")
        zone(vessel["label_rect"], color[:3] + (145,), "value")

    slot_content = layout["slot_content"]
    for index, outer in enumerate(layout["slots"]):
        zone(outer, (196, 135, 35, 50), f"slot {index + 1}")
        origin = (int(outer[0]), int(outer[1]))
        for key, color in (("icon_rect", (232, 181, 73, 105)),
                           ("count_rect", (245, 238, 210, 105)),
                           ("hotkey_rect", (212, 177, 88, 105))):
            x, y, right, bottom = _local_rect(slot_content[key], origin)
            zone([x, y, right - x, bottom - y], color, key.replace("_rect", ""))

    button_content = layout["button_content"]
    for name, outer in layout["buttons"].items():
        zone(outer, (39, 166, 104, 45), name)
        origin = (int(outer[0]), int(outer[1]))
        for key, color in (("icon_rect", (70, 206, 137, 105)),
                           ("label_rect", (111, 226, 165, 105))):
            x, y, right, bottom = _local_rect(button_content[key], origin)
            zone([x, y, right - x, bottom - y], color, key.replace("_rect", ""))

    zone(layout["selected_item_chip_rect"], (137, 66, 194, 75), "runtime selected-item chip")
    zone(layout["mining_progress_rect"], (170, 92, 205, 105), "runtime mining progress")
    return guide


def main() -> int:
    parser = argparse.ArgumentParser(description="Render native HUD kit composite and geometry guide")
    parser.add_argument("--output-dir", type=Path, default=SOURCE)
    args = parser.parse_args()
    layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
    args.output_dir.mkdir(parents=True, exist_ok=True)
    composite_path = args.output_dir / COMPOSITE_NAME
    guide_path = args.output_dir / GUIDE_NAME
    render_composite(layout).save(composite_path)
    render_guide(layout).save(guide_path)
    print(f"wrote {composite_path}")
    print(f"wrote {guide_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
