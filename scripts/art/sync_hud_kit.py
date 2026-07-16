#!/usr/bin/env python3
"""Validate authored HUD-kit PNGs and copy them into the runtime directory.

This is intentionally separate from build_hud_kit_placeholders.py. Art made by
an image editor or image model belongs in art/source_templates/hud_dock; this
tool never redraws or resizes it.
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art" / "source_templates" / "hud_dock"
GENERATED = ROOT / "art" / "generated" / "ui_painted"
LAYOUT_NAME = "hud_dock_layout.json"
MASK_NAMES = {"health_fill_mask.png", "attunement_fill_mask.png"}


def load_contract() -> tuple[Path, dict[str, tuple[int, int]]]:
    layout_path = SOURCE / LAYOUT_NAME
    layout = json.loads(layout_path.read_text(encoding="utf-8"))
    raw_sizes = layout.get("asset_sizes")
    if not isinstance(raw_sizes, dict) or not raw_sizes:
        raise ValueError(f"{layout_path} has no asset_sizes contract")
    sizes: dict[str, tuple[int, int]] = {}
    for name, raw_size in raw_sizes.items():
        if not isinstance(name, str) or not name.endswith(".png"):
            raise ValueError(f"invalid HUD asset name in contract: {name!r}")
        if not isinstance(raw_size, list) or len(raw_size) != 2:
            raise ValueError(f"invalid size for {name}: {raw_size!r}")
        sizes[name] = (int(raw_size[0]), int(raw_size[1]))
    return layout_path, sizes


def validate_asset(path: Path, expected_size: tuple[int, int]) -> list[str]:
    errors: list[str] = []
    if not path.is_file():
        return [f"missing: {path}"]
    try:
        with Image.open(path) as image:
            image.load()
            if image.format != "PNG":
                errors.append(f"{path.name}: expected PNG, found {image.format}")
            if image.mode != "RGBA":
                errors.append(f"{path.name}: expected RGBA, found {image.mode}")
            if image.size != expected_size:
                errors.append(
                    f"{path.name}: expected {expected_size[0]}x{expected_size[1]}, "
                    f"found {image.width}x{image.height}"
                )
            if image.mode == "RGBA" and path.name in MASK_NAMES:
                alpha_min, alpha_max = image.getchannel("A").getextrema()
                if alpha_min != 0 or alpha_max != 255:
                    errors.append(
                        f"{path.name}: fill mask must contain both fully transparent "
                        "and fully opaque pixels"
                    )
    except (OSError, ValueError) as exc:
        errors.append(f"{path.name}: unreadable image ({exc})")
    return errors


def parse_args(asset_names: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check or promote authored Coheronia HUD-kit assets without resizing them."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="validate source assets only")
    mode.add_argument("--sync", action="store_true", help="validate, then copy to runtime")
    parser.add_argument(
        "--asset",
        action="append",
        choices=asset_names,
        help="limit the operation to one asset; repeat for several (default: all)",
    )
    return parser.parse_args()


def main() -> int:
    try:
        layout_path, contract = load_contract()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"HUD kit contract error: {exc}")
        return 1

    args = parse_args(sorted(contract))
    names = args.asset or sorted(contract)
    errors: list[str] = []
    for name in names:
        errors.extend(validate_asset(SOURCE / name, contract[name]))
    if errors:
        print("HUD kit validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    if args.sync:
        GENERATED.mkdir(parents=True, exist_ok=True)
        for name in names:
            shutil.copy2(SOURCE / name, GENERATED / name)
        shutil.copy2(layout_path, GENERATED / LAYOUT_NAME)
        print(f"synced {len(names)} validated HUD asset(s) to {GENERATED}")
    else:
        print(f"validated {len(names)} authored HUD asset(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
