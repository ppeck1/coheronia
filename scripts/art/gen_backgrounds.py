#!/usr/bin/env python3
"""Procedural scenic-backdrop art generator (biome-aware).

Reads data/biomes.json for each biome's layer ids/sizes and renders the tiling
parallax art the in-game backdrop (scripts/world/world_backdrop.gd) draws behind
the world: an opaque full-frame sky gradient with a horizon glow, soft cloud
bands, and stacked mountain/hill silhouette strips with atmospheric perspective
(far = light and hazy, near = dark), snow caps on the far range, and a jagged
near treeline. Ridgelines are sums of integer-frequency sines so every strip
tiles seamlessly left<->right.

Palettes are sampled from the prologue frames (art/generated/opening) so the
world reads as one place. The art is authored at a neutral daytime base; the
game's day/night CanvasModulate tints it to dusk/night for free. Adding a biome
= a new entry in biomes.json + a palette here.

    python scripts/art/gen_backgrounds.py            # surface + a preview PNG
    python scripts/art/gen_backgrounds.py --all      # every biome in biomes.json
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BG_DIR = ROOT / "art/generated/backgrounds"

# Per-biome palettes keyed by layer art id (+ a "sky" entry). Daytime base tones.
PALETTES = {
    "surface": {
        "sky": {
            # A deeper, more saturated true-blue (cooler/indigo lean) so the pale
            # grey-blue mountains clearly read AGAINST the sky instead of blending
            # into it; warm horizon kept for the glow.
            "stops": [(0.0, (24, 38, 92)), (0.40, (40, 76, 150)), (0.70, (80, 126, 188)),
                      (0.86, (196, 192, 178)), (1.0, (218, 206, 184))],
            "glow": {"y": 0.86, "color": (244, 216, 168), "strength": 0.42, "spread": 0.09},
        },
        "surface_clouds": {"count": 9, "seed": 7, "base": (240, 244, 250),
                           "light_dir": (-0.55, -0.72), "bump": 0.11, "levels": 4},
        "surface_range_far": {
            "grad": [(0.0, (150, 166, 198)), (0.45, (126, 144, 182)), (1.0, (102, 122, 164))],
            "rim": (206, 218, 238), "haze": 0.22, "haze_col": (150, 170, 202),
            "see_through": 0.10, "seed": 903, "snow": True, "bands": 6,
            "style": "peaks", "peaks": 7, "peak_w": (0.032, 0.070), "peak_h": (0.52, 0.80),
            "foot": 0.12, "jag": 0.06, "sharp": 1.28, "base_frac": 0.88},
        "surface_range_mid": {
            "grad": [(0.0, (86, 106, 146)), (0.45, (60, 80, 122)), (1.0, (38, 56, 98))],
            "rim": (132, 156, 194), "haze": 0.05, "haze_col": (120, 142, 182),
            "see_through": 0.0, "seed": 517, "snow": True, "bands": 6,
            "style": "peaks", "peaks": 6, "peak_w": (0.05, 0.11), "peak_h": (0.40, 0.70),
            "foot": 0.10, "jag": 0.045, "sharp": 1.3, "base_frac": 0.82},
        "surface_hills_near": {
            "grad": [(0.0, (86, 118, 84)), (0.35, (58, 82, 60)), (0.7, (34, 50, 42)),
                     (1.0, (16, 26, 24))],
            "rim": (104, 138, 96), "haze": 0.0, "seed": 277, "amp": 0.42,
            "base_frac": 0.64, "treeline": True, "bands": 7},
    },
}


def _sines(x: float, w: int, freqs, falloff: float, rng) -> np.ndarray:
    out = np.zeros(w)
    amp, total = 1.0, 0.0
    for f in freqs:
        out += amp * np.sin(2 * np.pi * f * x / w + rng.uniform(0, 2 * np.pi))
        total += amp
        amp *= falloff
    return out / total               # -1..1


def _ridge(w: int, height: int, cfg: dict, k: int = 1) -> np.ndarray:
    """Ridge-top y (in px, 0 = strip top) per column; tiles because every term is an
    integer-frequency sine. `k` = width / 640: all frequencies scale by k so a wider
    strip keeps the SAME feature size but a longer (k*640) tiling period — far less
    visible repetition — instead of just stretching."""
    rng = np.random.default_rng(cfg["seed"])
    x = np.arange(w)
    h = _sines(x, w, tuple(f * k for f in (1, 2, 3, 4, 6)), 0.56, rng)
    detail = cfg.get("detail", 0.0)
    if detail:
        ridged = 1.0 - np.abs(_sines(x, w, tuple(f * k for f in (6, 10, 16)), 0.72, rng))
        h += detail * 0.40 * (ridged * 2.0 - 1.0)
    if cfg.get("treeline"):                               # organic forest edge
        for f, a in ((29, 0.10), (47, 0.07), (83, 0.05)):
            h += a * np.sin(2 * np.pi * (f * k) * x / w + rng.uniform(0, 2 * np.pi))
    h = np.clip(h, -1.4, 1.4)
    frac = np.clip(cfg["base_frac"] - 0.5 * cfg["amp"] * h, 0.02, 0.98)
    return frac * height


def _smooth(a: np.ndarray, k: int) -> np.ndarray:
    """Periodic moving-average smoothing (keeps the strip tileable)."""
    if k < 2:
        return a
    ker = np.ones(k) / k
    pad = np.concatenate([a[-k:], a, a[:k]])
    return np.convolve(pad, ker, "same")[k:-k]


def _blur2d(a: np.ndarray, k: int) -> np.ndarray:
    """Separable box blur (for softening the cloud height field before shading)."""
    if k < 2:
        return a
    ker = np.ones(k) / k
    a = np.apply_along_axis(lambda m: np.convolve(m, ker, "same"), 1, a)
    a = np.apply_along_axis(lambda m: np.convolve(m, ker, "same"), 0, a)
    return a


def _grad(frac: np.ndarray, stops: list) -> np.ndarray:
    """Smooth multi-stop vertical gradient -> (...,3), interpolated per channel."""
    pos = np.array([s[0] for s in stops])
    cols = np.array([s[1] for s in stops], float)
    return np.stack([np.interp(frac, pos, cols[:, c]) for c in range(3)], axis=-1)


def _peaks(w: int, height: int, cfg: dict, k: int = 1) -> np.ndarray:
    """ANGULAR mountains: tall triangular summits punching up out of a jagged range
    floor (rolling foothills + sharp ridged sub-crests). `foot`/`jag` set the range
    chaos, `sharp` the flank angularity (higher = pointier). `k` = width/640 scales
    frequencies + peak count so a wider strip keeps the same peak SIZE but a longer
    tiling period (less visible repetition)."""
    rng = np.random.default_rng(cfg["seed"])
    x = np.arange(w)
    H = float(height)
    baseline = cfg.get("base_frac", 0.8) * H
    roll = _sines(x, w, tuple(f * k for f in (2, 3, 5)), 0.6, rng) * 0.5 + 0.5
    ridged = 1.0 - np.abs(_sines(x, w, tuple(f * k for f in (8, 13, 21, 33)), 0.72, rng))
    ry = baseline - (cfg.get("foot", 0.26) * roll + cfg.get("jag", 0.20) * ridged) * H
    for _ in range(int(round(cfg.get("peaks", 7) * k))):
        px = rng.uniform(0, w)
        pw = rng.uniform(*cfg.get("peak_w", (0.04, 0.09))) * w / k   # constant px size
        ph = rng.uniform(*cfg.get("peak_h", (0.5, 0.95))) * H
        dx = np.minimum(np.abs(x - px), w - np.abs(x - px))
        tent = np.clip(1.0 - dx / pw, 0.0, 1.0) ** cfg.get("sharp", 1.15)
        ry = np.minimum(ry, baseline - ph * tent)
    ry += 0.010 * H * _sines(x, w, tuple(f * k for f in (45, 67)), 0.7, rng)
    return np.clip(ry, 0.02 * H, 0.98 * H)


def _make_strip(w: int, height: int, cfg: dict) -> Image.Image:
    """Supersampled so ridge edges anti-alias smoothly on downscale; filled with a
    multi-stop gradient plus an atmospheric haze blend toward the crest, soft rim
    light, and softly-tapered snow. Colour is defined for EVERY pixel (only alpha
    masks the ridge) so the downscale never bleeds a dark fringe along the crest."""
    ss = 3
    W, H = w * ss, height * ss
    k = max(1, round(w / 640))              # tiling-period multiplier (wider = less repeat)
    if cfg.get("style") == "peaks":
        ry = _peaks(W, H, cfg, k)           # angular mountains (kept crisp, no smoothing)
    else:
        ry = _smooth(_ridge(W, H, cfg, k), 3 * ss + 1)   # rolling hills / forest
    yy = np.arange(H)[:, None]
    dist = yy - ry[None, :]                                   # px below the crest
    frac = np.clip(dist / np.maximum(1.0, H - ry[None, :]), 0, 1)
    # Optional dithered banding of the fill gradient so the mountains carry the SAME
    # pixel-art tone treatment as the clouds (quantized bands + ordered dither).
    bands = cfg.get("bands", 0)
    if bands:
        bayer = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])
                 + 0.5) / 16.0 - 0.5
        dith = bayer[np.arange(H)[:, None] % 4, np.arange(W)[None, :] % 4] * 0.8
        fq = np.clip(np.floor((frac + dith / bands) * bands) / bands, 0, 1)
        col = _grad(fq, cfg["grad"])
    else:
        col = _grad(frac, cfg["grad"])
    # atmospheric haze: colour lifts toward the sky tone near the crest
    haze = cfg.get("haze", 0.0)
    if haze:
        hc = np.array(cfg.get("haze_col", (210, 220, 236)), float)
        m = ((1.0 - frac) * haze)[..., None]
        col = col * (1 - m) + hc[None, None, :] * m
    # soft rim light just under the crest
    rim = np.clip(1.0 - dist / (3.0 * ss), 0, 1) * (dist >= 0)
    col = col * (1 - 0.45 * rim[..., None]) + np.array(cfg["rim"], float)[None, None, :] * (0.45 * rim[..., None])
    # soft snow caps hugging the higher peaks
    if cfg.get("snow"):
        # Cap only the TIPS of the tallest peaks (white-capped at times), not whole
        # mountains: snowline at the upper third of the range, and only a few px down
        # from each qualifying summit.
        snowline = np.percentile(ry, 34)
        span = max(1.0, snowline - float(ry.min()))
        peak = np.clip((snowline - ry) / span, 0, 1)      # 0 at snowline .. 1 at the tip
        depth = np.maximum(1.0, (2.0 + 5.0 * peak)[None, :] * ss)
        snow = np.clip(1.0 - dist / depth, 0, 1) ** 1.5 * (dist >= 0) * (peak[None, :] > 0.18)
        col = col * (1 - snow[..., None]) + 246.0 * snow[..., None]
    alpha = np.where(dist >= 0, 255.0 * (1.0 - cfg.get("see_through", 0.0) * (1.0 - frac)), 0.0)
    img = np.dstack([np.clip(col, 0, 255), alpha]).astype(np.uint8)
    return Image.fromarray(img, "RGBA").resize((w, height), Image.LANCZOS)


def _make_clouds(w: int, height: int, cfg: dict) -> Image.Image:
    """Chunky pixel-art cumulus: each cloud is a union of round bumps (pillowy top)
    on a flat base, hard-edged (no soft alpha), shaded with three FLAT tone bands
    from a bright top down to a shadowed underside. Reads as blocky pixel clouds,
    not a soft airbrush, and tiles in x."""
    rng = np.random.default_rng(cfg.get("seed", 7))
    xx = np.arange(w)[None, :]
    yy = np.arange(height)[:, None]
    hf = np.zeros((height, w))                          # cloud thickness (sphere height)
    # Chaotic quantity + free vertical placement: a varied number of clouds scattered
    # across the WHOLE sky band (not a single height), each with very different bump
    # counts/sizes. Slots keep the big clouds from merging into a slab; a handful of
    # random small puffs add extra chaos.
    n = max(3, cfg.get("count", 6) + int(rng.integers(-1, 3)))
    for i in range(n):
        cx = (i + 0.5) / n * w + rng.uniform(-0.42, 0.42) * (w / n)
        cw = rng.uniform(52, 116)
        base = rng.uniform(height * 0.32, height * 0.80)   # free vertical, margin from edges
        bumps = int(rng.integers(3, 8))
        for b in range(bumps):
            jitter = rng.uniform(-0.18, 0.18)
            bx = cx + ((b + 0.5) / bumps - 0.5 + jitter) * cw
            r = cw * rng.uniform(0.14, 0.34)
            rx = r * rng.uniform(0.85, 1.5)                # elliptical + varied so no
            ry = r * rng.uniform(0.7, 1.1)                 # bump is a perfect circle
            by = base - r * rng.uniform(0.15, 1.1)
            dx = np.minimum(np.abs(xx - bx), w - np.abs(xx - bx))
            d = (dx / rx) ** 2 + ((yy - by) / ry) ** 2
            hf = np.maximum(hf, np.sqrt(np.maximum(0.0, 1.0 - d)) * min(rx, ry))
    for _ in range(int(rng.integers(1, 4))):               # a few scattered small wisps
        bx, by = rng.uniform(0, w), rng.uniform(height * 0.15, height * 0.9)
        rx, ry = rng.uniform(10, 26), rng.uniform(7, 16)
        dx = np.minimum(np.abs(xx - bx), w - np.abs(xx - bx))
        d = (dx / rx) ** 2 + ((yy - by) / ry) ** 2
        hf = np.maximum(hf, np.sqrt(np.maximum(0.0, 1.0 - d)) * min(rx, ry))
    mask = hf > 0.6
    # Rounded VOLUME shading from the thickness gradient lit by a direction. The height
    # field is BLURRED first so the shading reads as one cohesive cloud volume rather
    # than a pile of separate spheres; quantized + ordered-dithered for a pixel look.
    hn = _blur2d(hf, 7) / max(1.0, float(hf.max()))
    gy, gx = np.gradient(hn)
    ld = np.array(cfg.get("light_dir", (-0.55, -0.72)), float)
    lz = 0.55
    lvec = np.array([ld[0], ld[1], lz])
    lvec /= np.linalg.norm(lvec)
    bz = cfg.get("bump", 0.11)
    nx, ny = -gx, -gy
    nl = np.sqrt(nx * nx + ny * ny + bz * bz) + 1e-6
    diff = (nx * lvec[0] + ny * lvec[1] + bz * lvec[2]) / nl
    # bright cloud, gentle directional shading (not a heavy grey)
    shade = np.clip(0.74 + 0.42 * np.clip(diff, -0.3, 1.0), 0.5, 1.12)
    levels = float(cfg.get("levels", 4))
    bayer = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0 - 0.5
    dith = bayer[yy[:, 0] % 4][:, xx[0] % 4] * 0.5      # subtle dither, not noise
    q = np.clip(np.floor((shade + dith / levels) * levels) / levels, 0.46, 1.12)
    base_col = np.array(cfg.get("base", (240, 244, 250)), float)
    img = np.zeros((height, w, 4), float)
    img[..., :3] = np.clip(base_col[None, None, :] * q[..., None], 0, 255)
    img[..., 3] = np.where(mask, 255.0, 0.0)            # hard pixel edges
    return Image.fromarray(img.astype(np.uint8), "RGBA")


def _make_sky(w: int, height: int, cfg: dict) -> Image.Image:
    stops = cfg["stops"]
    grad = np.zeros((height, 3))
    for i, y in enumerate(np.linspace(0, 1, height)):
        for j in range(len(stops) - 1):
            y0, c0 = stops[j]
            y1, c1 = stops[j + 1]
            if y0 <= y <= y1:
                t = (y - y0) / max(1e-6, y1 - y0)
                grad[i] = np.array(c0) * (1 - t) + np.array(c1) * t
                break
        else:
            grad[i] = np.array(stops[-1][1])
    img = np.repeat(grad[:, None, :], w, axis=1)
    g = cfg["glow"]
    gw = np.exp(-(((np.arange(height) - g["y"] * height) / (g["spread"] * height)) ** 2))
    gw = (gw * g["strength"])[:, None, None]
    img = img * (1 - gw) + np.array(g["color"], float)[None, None, :] * gw
    # ordered-ish dither breaks 8-bit banding across the smooth gradient
    img += np.random.default_rng(7).uniform(-1.4, 1.4, img.shape)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def _layer_image(w: int, h: int, art: str, pal: dict) -> Image.Image:
    if art.endswith("clouds"):
        return _make_clouds(w, h, pal[art])
    return _make_strip(w, h, pal[art])


def _preview(biome: dict, pal: dict, sky: Image.Image, out: Path) -> None:
    W, H = sky.size
    canvas = sky.convert("RGBA")
    horizon = int(H * 0.64)
    for layer in biome["layers"]:
        img = _layer_image(int(layer["width"]), int(layer["height"]),
                           layer["art"], pal)
        if layer.get("anchor") == "sky":
            y = int(layer.get("anchor_y", 40))
        else:
            y = horizon - img.height
        canvas.alpha_composite(img, (0, y))
    # a dark earth band so the preview reads as a full frame
    earth = Image.new("RGBA", (W, H - horizon), (26, 30, 30, 255))
    canvas.alpha_composite(earth, (0, horizon))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out)
    print(f"  preview -> {out.relative_to(ROOT)}")


def build(biomes: dict, only: str | None, preview: bool) -> int:
    BG_DIR.mkdir(parents=True, exist_ok=True)
    for name, biome in biomes["biomes"].items():
        if only and name != only:
            continue
        pal = PALETTES.get(name)
        if pal is None:
            print(f"  (no palette for biome '{name}'; skipping art)")
            continue
        sky_spec = biome["sky"]
        sky = _make_sky(int(sky_spec["width"]), int(sky_spec["height"]), pal["sky"])
        sky.save(BG_DIR / f"{sky_spec['art']}.png")
        print(f"  {name}/{sky_spec['art']} {sky.size} RGB")
        for layer in biome["layers"]:
            img = _layer_image(int(layer["width"]), int(layer["height"]),
                               layer["art"], pal)
            img.save(BG_DIR / f"{layer['art']}.png")
            print(f"  {name}/{layer['art']} {img.size} RGBA")
        if preview:
            _preview(biome, pal, sky, ROOT / f"build/backdrop_preview_{name}.png")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="every biome (default: surface)")
    ap.add_argument("--no-preview", action="store_true")
    args = ap.parse_args()
    biomes = json.loads((ROOT / "data/biomes.json").read_text(encoding="utf-8"))
    only = None if args.all else biomes.get("default_biome", "surface")
    return build(biomes, only, not args.no_preview)


if __name__ == "__main__":
    raise SystemExit(main())
