#!/usr/bin/env python3
"""S-07.1b (F10): deterministic generator for tool/weapon swing overlays.

Authors the 16x32 transparent swing overlays the character renderer composites
on the `weapon_or_swing` layer (see scripts/player/player_visual.gd). Each frame
is a rightward-aim pose (the engine rotates it around the shoulder toward the
target), for the three swing phases the renderer reads:

    phase 0 = windup  (arm cocked up-and-back)
    phase 1 = recovery/follow-through (arm mid, ahead)
    phase 2 = impact  (arm extended forward on the strike, with a motion streak)

Files are convention-discovered as
    <tool_id>_<body_id>_swing_<phase>.png    (body_id = <species>[_female])
so this writes one per tool x species x body-variant x phase. Masculine and
feminine share a species rig, so their frames are identical by construction.

The arm is drawn in each species' own skin palette so the swing matches the
body; tools carry per-tier tints. Pure/deterministic (no randomness), so
`--check`-style regeneration is byte-stable.

Usage:
  python scripts/art/gen_tool_swing_frames.py            # write into art/generated/player_gear
  python scripts/art/gen_tool_swing_frames.py --out DIR  # write elsewhere (drafts)
  python scripts/art/gen_tool_swing_frames.py --species human --tools sword_crude
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data" / "player_visuals.json"
DEFAULT_OUT = ROOT / "art" / "generated" / "player_gear"

W, H = 16, 32
# BODY_RECT is Rect2(-8,-16,16,32): a PNG pixel (px,py) is local (px-8, py-16).
ORIGIN = (8, 16)

# The engine rotates the whole overlay around the shoulder toward the aim, so the
# pose is authored COMPACTLY inside the 16x32 frame (a rightward reach from the
# right shoulder would fall off-frame). Poses are tuned in HUMAN frame space and
# shifted by each species' shoulder delta. Per phase: the hand and the tool tip.
HUMAN_SHOULDER = (13.0, 8.0)   # (shoulder [5,-8]) + ORIGIN
PHASES = {
    # windup: tool cocked up and back over the shoulder.
    0: dict(hand=(11.0, 5.0), tip=(8.5, 1.0), impact=False),
    # recovery / follow-through: swung across, mid, pointing down and in.
    1: dict(hand=(10.5, 12.0), tip=(6.0, 15.0), impact=False),
    # impact: arm extended into the strike, tool leading down-and-out.
    2: dict(hand=(12.0, 14.0), tip=(15.0, 20.0), impact=True),
}

WOOD = (107, 74, 43, 255)
WOOD_HI = (140, 100, 58, 255)
STEEL = (178, 184, 198, 255)
STEEL_HI = (228, 234, 244, 255)
STEEL_SH = (120, 126, 140, 255)

# This generator OWNS the sword swing family (the weapons that had no authored
# swing art and previously fell back to the code-drawn arc). The pick/axe swing
# overlays are hand-authored and are deliberately NOT generated here, so a plain
# run never clobbers them. The pick/axe head kinds remain supported by the
# renderer below only for optional experimentation via --tools.
TOOL_LIBRARY = {
    "pick_basic": dict(kind="pick", tint=STEEL, hi=STEEL_HI),
    "pick_forged": dict(kind="pick", tint=(196, 202, 214, 255), hi=(236, 242, 250, 255)),
    "axe_crude": dict(kind="axe", tint=STEEL, hi=STEEL_HI),
    "sword_crude": dict(kind="sword", tint=STEEL, hi=STEEL_HI),
    "sword_iron": dict(kind="sword", tint=(150, 160, 178, 255), hi=(214, 224, 240, 255)),
    "sword_bronze": dict(kind="sword", tint=(190, 138, 74, 255), hi=(226, 178, 112, 255)),
    "sword_obsidian": dict(kind="sword", tint=(70, 62, 92, 255), hi=(138, 120, 172, 255)),
}
# Default output set: the four sword tiers only.
DEFAULT_TOOLS = ["sword_crude", "sword_iron", "sword_bronze", "sword_obsidian"]
SPECIES = ["human", "dwarf", "elf", "goblin", "orc"]


def load_rigs() -> dict:
    return json.loads(DATA.read_text(encoding="utf-8"))["rigs"]


def _hex(s: str) -> tuple[int, int, int, int]:
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


def _shoulder_px(rig: dict) -> tuple[float, float]:
    sh = rig.get("shoulder", [5, -8])
    return (float(sh[0]) + ORIGIN[0], float(sh[1]) + ORIGIN[1])


def _lighten(c, f=0.28):
    return (min(255, int(c[0] + (255 - c[0]) * f)),
            min(255, int(c[1] + (255 - c[1]) * f)),
            min(255, int(c[2] + (255 - c[2]) * f)), 255)


def _thick_line(d: ImageDraw.ImageDraw, a, b, color, width):
    d.line([a, b], fill=color, width=width)


def _unit(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy) or 1.0
    return (dx / n, dy / n)


def render_frame(tool: str, rig: dict, phase: int) -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    p = PHASES[phase]
    tdef = TOOL_LIBRARY[tool]
    palette = rig.get("skin_palette", ["c9955a"])
    skin = _hex(str(palette[0]))
    skin_hi = _hex(str(palette[1])) if len(palette) > 1 else _lighten(skin)

    shoulder = _shoulder_px(rig)
    # Shift the human-tuned pose by this species' shoulder delta.
    dx = shoulder[0] - HUMAN_SHOULDER[0]
    dy = shoulder[1] - HUMAN_SHOULDER[1]
    hand = (p["hand"][0] + dx, p["hand"][1] + dy)
    tip = (p["tip"][0] + dx, p["tip"][1] + dy)

    tdir = _unit(hand, tip)          # hand -> tool direction
    perp = (-tdir[1], tdir[0])

    # Forearm: a 2px skin limb from the shoulder to the hand, with a 1px highlight.
    _thick_line(d, shoulder, hand, skin, 2)
    _thick_line(d,
                (shoulder[0] - perp[0], shoulder[1] - perp[1]),
                (hand[0] - perp[0], hand[1] - perp[1]), skin_hi, 1)

    kind = tdef["kind"]
    steel, steel_hi = tdef["tint"], tdef["hi"]

    if kind == "sword":
        # A blade continuing past the tip, a bright edge, and a small crossguard.
        blade_end = (tip[0] + tdir[0] * 3.0, tip[1] + tdir[1] * 3.0)
        _thick_line(d, hand, blade_end, steel, 2)
        _thick_line(d, (hand[0] - perp[0], hand[1] - perp[1]),
                    (blade_end[0] - perp[0], blade_end[1] - perp[1]), steel_hi, 1)
        _thick_line(d, (hand[0] + perp[0] * 2, hand[1] + perp[1] * 2),
                    (hand[0] - perp[0] * 2, hand[1] - perp[1] * 2), WOOD_HI, 1)
    else:
        # Pick/axe: a wooden haft then a steel head at the tip.
        _thick_line(d, hand, tip, WOOD, 2)
        _thick_line(d, (hand[0] - perp[0], hand[1] - perp[1]),
                    (tip[0] - perp[0], tip[1] - perp[1]), WOOD_HI, 1)
        if kind == "pick":
            # An asymmetric spike across the head: long leading, short trailing.
            lead = (tip[0] + perp[0] * 3.0, tip[1] + perp[1] * 3.0)
            back = (tip[0] - perp[0] * 2.0, tip[1] - perp[1] * 2.0)
            _thick_line(d, back, lead, steel, 2)
            d.point([lead], fill=steel_hi)
        else:  # axe: a blade wedge on the leading side of the tip
            base1 = (tip[0] - tdir[0] * 1.5, tip[1] - tdir[1] * 1.5)
            base2 = (tip[0] + tdir[0] * 1.5, tip[1] + tdir[1] * 1.5)
            edge1 = (base1[0] + perp[0] * 4.0, base1[1] + perp[1] * 4.0)
            edge2 = (base2[0] + perp[0] * 4.0, base2[1] + perp[1] * 4.0)
            d.polygon([base1, base2, edge2, edge1], fill=steel)
            _thick_line(d, edge1, edge2, steel_hi, 1)

    # Impact frame: a faint motion streak arcing behind the tool so the strike
    # reads as speed, not a still pose.
    if p["impact"]:
        streak = (steel[0], steel[1], steel[2], 90)
        s0 = (shoulder[0] + (hand[0] - shoulder[0]) * 0.4 - perp[0] * 3.0,
              shoulder[1] + (hand[1] - shoulder[1]) * 0.4 - perp[1] * 3.0)
        _thick_line(d, s0, (tip[0] - perp[0] * 2.0, tip[1] - perp[1] * 2.0), streak, 1)

    return img


def body_ids(species: str) -> list[str]:
    return [species, f"{species}_female"]


def generate(out_dir: Path, tools: list[str], species: list[str]) -> int:
    rigs = load_rigs()
    out_dir.mkdir(parents=True, exist_ok=True)
    n = 0
    for tool in tools:
        for sp in species:
            rig = rigs[sp]
            for body_id in body_ids(sp):
                for phase in (0, 1, 2):
                    img = render_frame(tool, rig, phase)
                    img.save(out_dir / f"{tool}_{body_id}_swing_{phase}.png")
                    n += 1
    return n


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate tool/weapon swing overlays")
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    ap.add_argument("--tools", nargs="*", default=DEFAULT_TOOLS)
    ap.add_argument("--species", nargs="*", default=SPECIES)
    args = ap.parse_args()
    count = generate(Path(args.out), args.tools, args.species)
    print(f"wrote {count} swing frames -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
