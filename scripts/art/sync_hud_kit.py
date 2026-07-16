#!/usr/bin/env python3
"""Validate authored HUD-kit PNGs and copy them into the runtime directory.

This is intentionally separate from build_hud_kit_placeholders.py. Art made by
an image editor or image model belongs in art/source_templates/hud_dock; this
tool never redraws or resizes it.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art" / "source_templates" / "hud_dock"
GENERATED = ROOT / "art" / "generated" / "ui_painted"
LAYOUT_NAME = "hud_dock_layout.json"
MASK_NAMES = {"health_fill_mask.png", "attunement_fill_mask.png"}
VARIANT_SEPARATOR = "__"
THEME_ID_PATTERN = re.compile(r"[a-z0-9_]{1,48}")


def load_contract() -> tuple[Path, dict, dict[str, tuple[int, int]]]:
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
    return layout_path, layout, sizes


def discover_variants(
    contract: dict[str, tuple[int, int]],
) -> tuple[dict[str, tuple[str, str]], list[str]]:
    variants: dict[str, tuple[str, str]] = {}
    errors: list[str] = []
    for path in sorted(SOURCE.glob(f"*{VARIANT_SEPARATOR}*.png")):
        base_stem, separator, theme_id = path.stem.partition(VARIANT_SEPARATOR)
        base_name = f"{base_stem}.png"
        if separator != VARIANT_SEPARATOR or base_name not in contract:
            errors.append(
                f"{path.name}: themed HUD asset must extend a contracted base asset"
            )
            continue
        if THEME_ID_PATTERN.fullmatch(theme_id) is None:
            errors.append(
                f"{path.name}: theme id must match [a-z0-9_] and be 1-48 characters"
            )
            continue
        variants[path.name] = (base_name, theme_id)
    return variants, errors


def _rect(raw: object, label: str) -> tuple[int, int, int, int]:
    if not isinstance(raw, list) or len(raw) != 4:
        raise ValueError(f"{label} must be [x, y, width, height]")
    if any(not isinstance(value, int) for value in raw):
        raise ValueError(f"{label} must use integer coordinates")
    x, y, width, height = raw
    if width <= 0 or height <= 0:
        raise ValueError(f"{label} must have positive dimensions")
    return x, y, width, height


def _rect_inside(
    raw: object, bounds: tuple[int, int], label: str
) -> tuple[int, int, int, int]:
    rect = _rect(raw, label)
    x, y, width, height = rect
    if x < 0 or y < 0 or x + width > bounds[0] or y + height > bounds[1]:
        raise ValueError(f"{label} {list(rect)} exceeds {bounds[0]}x{bounds[1]}")
    return rect


def validate_layout(layout: dict, sizes: dict[str, tuple[int, int]]) -> list[str]:
    errors: list[str] = []
    try:
        if int(layout.get("version", 0)) != 2:
            raise ValueError("layout version must be 2")
        visual_variants = layout.get("visual_variants")
        if not isinstance(visual_variants, dict):
            raise ValueError("visual_variants must describe optional themed assets")
        if visual_variants.get("separator") != VARIANT_SEPARATOR:
            raise ValueError(
                f"visual_variants.separator must remain {VARIANT_SEPARATOR!r}"
            )
        if visual_variants.get("fallback") != "required base asset" \
                or visual_variants.get("asset_local") is not True:
            raise ValueError("visual_variants must use asset-local required-base fallback")
        native_raw = layout.get("native_size")
        if not isinstance(native_raw, list) or len(native_raw) != 2:
            raise ValueError("native_size must be [width, height]")
        native = (int(native_raw[0]), int(native_raw[1]))
        if native != (1280, 176):
            raise ValueError(f"native_size must remain 1280x176, found {native}")

        required = layout.get("required_assets")
        if not isinstance(required, list) or set(required) != set(sizes):
            raise ValueError("required_assets must name every asset_sizes entry exactly once")

        layers = layout.get("decorative_layers")
        if not isinstance(layers, list) or not layers:
            raise ValueError("decorative_layers must contain at least the backplate and trim")
        roles: set[str] = set()
        for index, layer in enumerate(layers):
            if not isinstance(layer, dict):
                raise ValueError(f"decorative_layers[{index}] must be an object")
            asset = layer.get("asset")
            if asset not in sizes:
                raise ValueError(f"decorative_layers[{index}] has unknown asset {asset!r}")
            if not isinstance(layer.get("name"), str) or not layer["name"]:
                raise ValueError(f"decorative_layers[{index}] needs a node name")
            if not isinstance(layer.get("z"), int):
                raise ValueError(f"decorative_layers[{index}].z must be an integer")
            role = layer.get("role")
            if not isinstance(role, str) or not role:
                raise ValueError(f"decorative_layers[{index}] needs a role")
            roles.add(role)
            rect = _rect_inside(layer.get("rect"), native, f"decorative_layers[{index}].rect")
            if (rect[2], rect[3]) != sizes[asset]:
                raise ValueError(
                    f"decorative layer {asset} rect size {(rect[2], rect[3])} "
                    f"does not match asset size {sizes[asset]}"
                )
        if not {"backplate", "foreground_trim"}.issubset(roles):
            raise ValueError("decorative_layers must define backplate and foreground_trim roles")

        dock = layout.get("dock", {})
        if not isinstance(dock, dict):
            raise ValueError("dock must be an object")
        _rect_inside(dock.get("rect"), native, "dock.rect")
        for vessel_name in ("health", "attunement"):
            vessel = layout.get(vessel_name, {})
            if not isinstance(vessel, dict):
                raise ValueError(f"{vessel_name} must be an object")
            for key in ("frame_rect", "fill_rect", "glass_rect", "label_rect"):
                _rect_inside(vessel.get(key), native, f"{vessel_name}.{key}")

        slots = layout.get("slots")
        if not isinstance(slots, list) or len(slots) != 5:
            raise ValueError("slots must contain exactly five rectangles")
        slot_rects = [_rect_inside(raw, native, f"slots[{i}]") for i, raw in enumerate(slots)]
        slot_size = (slot_rects[0][2], slot_rects[0][3])
        if any((rect[2], rect[3]) != slot_size for rect in slot_rects):
            raise ValueError("all slot rectangles must share one size")
        slot_content = layout.get("slot_content", {})
        if not isinstance(slot_content, dict):
            raise ValueError("slot_content must be an object")
        for key in ("icon_rect", "count_rect", "hotkey_rect"):
            _rect_inside(slot_content.get(key), slot_size, f"slot_content.{key}")

        buttons = layout.get("buttons")
        if not isinstance(buttons, dict) or set(buttons) != {
            "inventory", "character", "skills", "town_hall"
        }:
            raise ValueError("buttons must define inventory, character, skills, and town_hall")
        button_rects = [
            _rect_inside(raw, native, f"buttons.{name}") for name, raw in buttons.items()
        ]
        button_size = (button_rects[0][2], button_rects[0][3])
        if any((rect[2], rect[3]) != button_size for rect in button_rects):
            raise ValueError("all button rectangles must share one size")
        button_content = layout.get("button_content", {})
        if not isinstance(button_content, dict):
            raise ValueError("button_content must be an object")
        for key in ("icon_rect", "label_rect"):
            _rect_inside(button_content.get(key), button_size, f"button_content.{key}")

        _rect_inside(layout.get("selected_item_chip_rect"), native, "selected_item_chip_rect")
        _rect_inside(layout.get("mining_progress_rect"), native, "mining_progress_rect")
    except (TypeError, ValueError) as exc:
        errors.append(f"layout: {exc}")
    return errors


def _alpha_coverage(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    occupied = sum(1 for value in alpha.tobytes() if value > 0)
    return occupied / float(image.width * image.height)


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_asset(
    path: Path, expected_size: tuple[int, int], rule: dict | None = None
) -> list[str]:
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
            if image.mode == "RGBA" and isinstance(rule, dict):
                coverage = _alpha_coverage(image)
                minimum = rule.get("min_coverage")
                maximum = rule.get("max_coverage")
                if minimum is not None and coverage < float(minimum):
                    errors.append(
                        f"{path.name}: alpha coverage {coverage:.3f} is below {float(minimum):.3f}"
                    )
                if maximum is not None and coverage > float(maximum):
                    errors.append(
                        f"{path.name}: alpha coverage {coverage:.3f} exceeds {float(maximum):.3f}"
                    )
                if bool(rule.get("binary_alpha", False)):
                    values = set(image.getchannel("A").tobytes())
                    if not values.issubset({0, 255}) or values != {0, 255}:
                        errors.append(
                            f"{path.name}: mask alpha must use both and only 0/255"
                        )
                padding = rule.get("safe_padding")
                if padding is not None:
                    bbox = image.getchannel("A").getbbox()
                    pad = int(padding)
                    if bbox is None or bbox[0] < pad or bbox[1] < pad \
                            or bbox[2] > image.width - pad or bbox[3] > image.height - pad:
                        errors.append(
                            f"{path.name}: occupied pixels must preserve {pad}px transparent padding"
                        )
                for index, raw_rect in enumerate(rule.get("transparent_rects", [])):
                    try:
                        x, y, width, height = _rect_inside(
                            raw_rect, image.size, f"{path.name}.transparent_rects[{index}]"
                        )
                    except ValueError as exc:
                        errors.append(str(exc))
                        continue
                    if image.getchannel("A").crop((x, y, x + width, y + height)).getbbox():
                        errors.append(
                            f"{path.name}: protected rectangle {raw_rect} must remain transparent"
                        )
    except (OSError, ValueError) as exc:
        errors.append(f"{path.name}: unreadable image ({exc})")
    return errors


def validate_relationships(
    layout: dict, theme_overrides: dict[str, dict[str, str]] | None = None
) -> list[str]:
    errors: list[str] = []
    contexts: list[tuple[str, dict[str, str]]] = [("default", {})]
    contexts.extend(sorted((theme, assets) for theme, assets in
                           (theme_overrides or {}).items()))

    for context_name, overrides in contexts:
        cache: dict[str, Image.Image] = {}

        def opened(name: str) -> Image.Image:
            resolved_name = overrides.get(name, name)
            if resolved_name not in cache:
                with Image.open(SOURCE / resolved_name) as raw:
                    cache[resolved_name] = raw.convert("RGBA")
            return cache[resolved_name]

        for relationship in layout.get("mask_relationships", []):
            try:
                mask_name = str(relationship["mask"])
                frame_name = str(relationship["frame"])
                glass_name = str(relationship["glass"])
                offset = relationship.get("frame_offset")
                if not isinstance(offset, list) or len(offset) != 2:
                    raise ValueError(f"{frame_name}: frame_offset must be [x, y]")
                ox, oy = int(offset[0]), int(offset[1])
                mask = opened(mask_name).getchannel("A")
                frame = opened(frame_name).getchannel("A")
                glass = opened(glass_name).getchannel("A")
                if glass.size != mask.size:
                    raise ValueError(f"{glass_name}: glass and mask dimensions differ")
                for y in range(mask.height):
                    for x in range(mask.width):
                        if mask.getpixel((x, y)) > 0:
                            if not (0 <= x + ox < frame.width
                                    and 0 <= y + oy < frame.height):
                                raise ValueError(
                                    f"{frame_name}: mask clearance exceeds frame canvas"
                                )
                            if frame.getpixel((x + ox, y + oy)) > 0:
                                raise ValueError(
                                    f"{frame_name}: frame paints inside the runtime fill aperture"
                                )
                        if glass.getpixel((x, y)) > 0 and mask.getpixel((x, y)) == 0:
                            raise ValueError(
                                f"{glass_name}: glass paints outside its fill mask"
                            )
            except (KeyError, OSError, ValueError) as exc:
                errors.append(f"mask relationship ({context_name}): {exc}")

        for family_name, names in layout.get("state_families", {}).items():
            try:
                if not isinstance(names, list) or len(names) < 2:
                    raise ValueError(f"{family_name}: state family needs at least two assets")
                base = opened(str(names[0])).getchannel("A").point(
                    lambda value: 255 if value else 0
                )
                for name in names[1:]:
                    current = opened(str(name)).getchannel("A").point(
                        lambda value: 255 if value else 0
                    )
                    if current.size != base.size or current.tobytes() != base.tobytes():
                        raise ValueError(
                            f"{family_name}: {name} changes the occupied silhouette"
                        )
            except (OSError, ValueError) as exc:
                errors.append(f"state family ({context_name}): {exc}")
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check or promote authored Coheronia HUD-kit assets without resizing them."
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="validate source assets only")
    mode.add_argument("--sync", action="store_true", help="validate, then copy to runtime")
    mode.add_argument(
        "--verify-runtime",
        action="store_true",
        help="validate source assets, then require byte-identical runtime copies",
    )
    parser.add_argument(
        "--asset",
        action="append",
        help=("limit the operation to one base or <base>__<theme>.png asset; "
              "repeat for several (default: all)"),
    )
    return parser.parse_args()


def main() -> int:
    try:
        layout_path, layout, contract = load_contract()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"HUD kit contract error: {exc}")
        return 1

    variants, variant_errors = discover_variants(contract)
    available_names = set(contract) | set(variants)
    args = parse_args()
    names = args.asset or sorted(available_names)
    errors: list[str] = validate_layout(layout, contract) + variant_errors
    for name in names:
        if name not in available_names:
            errors.append(f"unknown HUD asset: {name}")
    alpha_rules = layout.get("alpha_rules", {})
    for name in names:
        if name not in available_names:
            continue
        base_name = variants.get(name, (name, ""))[0]
        rule = alpha_rules.get(base_name) if isinstance(alpha_rules, dict) else None
        errors.extend(validate_asset(SOURCE / name, contract[base_name], rule))
    theme_overrides: dict[str, dict[str, str]] = {}
    for variant_name, (base_name, theme_id) in variants.items():
        theme_overrides.setdefault(theme_id, {})[base_name] = variant_name
    errors.extend(validate_relationships(layout, theme_overrides))
    if errors:
        print("HUD kit validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    if args.sync:
        GENERATED.mkdir(parents=True, exist_ok=True)
        if args.asset is None:
            expected_variants = set(variants)
            for runtime_variant in GENERATED.glob(f"*{VARIANT_SEPARATOR}*.png"):
                if runtime_variant.name not in expected_variants:
                    runtime_variant.unlink()
        for name in names:
            shutil.copy2(SOURCE / name, GENERATED / name)
        shutil.copy2(layout_path, GENERATED / LAYOUT_NAME)
        for name in names:
            if _sha256(SOURCE / name) != _sha256(GENERATED / name):
                print(f"HUD kit sync failed: runtime hash mismatch for {name}")
                return 1
        if _sha256(layout_path) != _sha256(GENERATED / LAYOUT_NAME):
            print("HUD kit sync failed: runtime layout hash mismatch")
            return 1
        print(f"synced {len(names)} validated HUD asset(s) to {GENERATED}")
    elif args.verify_runtime:
        mismatches = [
            name for name in names
            if not (GENERATED / name).is_file()
            or _sha256(SOURCE / name) != _sha256(GENERATED / name)
        ]
        if _sha256(layout_path) != _sha256(GENERATED / LAYOUT_NAME):
            mismatches.append(LAYOUT_NAME)
        if args.asset is None:
            unexpected_variants = sorted(
                path.name for path in GENERATED.glob(f"*{VARIANT_SEPARATOR}*.png")
                if path.name not in variants
            )
            mismatches.extend(
                f"unexpected runtime themed asset: {name}"
                for name in unexpected_variants
            )
        if mismatches:
            print("HUD kit runtime verification failed:")
            for name in mismatches:
                print(f"- source/runtime mismatch: {name}")
            return 1
        print(f"verified {len(names)} source/runtime HUD asset hash(es) + layout")
    else:
        print(f"validated {len(names)} authored HUD asset(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
