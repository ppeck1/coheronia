#!/usr/bin/env python3
"""Procedural scenic-backdrop art generator (biome-aware, pixel-art).

Reads data/biomes.json for each biome's layer ids/sizes/format and renders the
tiling parallax art the in-game backdrop (scripts/world/world_backdrop.gd) draws
behind the world: an opaque full-frame sky gradient with a horizon glow, a band
of elongated pixel clouds, and stacked mountain/hill silhouette strips with
atmospheric perspective (far = light + hazy, near = dark).

Design goals (one coherent pixel-art scene, varied across seeds and along a strip):

  * ONE contour language. Ridgelines are tileable value noise sampled on a
    CIRCLE (the ring closes once across the strip width, so the left and right
    edges are the same sample -> a seamless horizontal tile with NO repeated
    triangular-summit rhythm). Distant = broad connected masses; middle = the
    same mass with a few nested slope/shadow contours; near = simpler darker
    forms with a jagged treeline.
  * ONE pixel treatment. Strips are rasterized at NATIVE resolution with HARD
    stepped edges (no supersample/LANCZOS downscale) and a small set of flat
    tones (quantized bands + ordered dither). Clouds share that edge scale and
    palette discipline: elongated contour masses, a restrained underside, and a
    few internal marks -- never sphere-lit airbrush, never mountain-shaped.

Tuning has one home below: STYLE (shared discipline) + PROFILES (per-biome sky
and per-layer shape/palette). data/biomes.json stays authoritative for the
runtime layer CONTRACT (ids, sizes, format, parallax, rise); this file never
restates those. Each layer has its own independent seed stream, so retuning one
layer never rearranges the others.

    python scripts/art/gen_backgrounds.py            # canonical surface art + preview
    python scripts/art/gen_backgrounds.py --all      # every biome in biomes.json
    python scripts/art/gen_backgrounds.py --seed 42  # PREVIEW an alt seed to build/
                                                      # (never overwrites canonical art)
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BG_DIR = ROOT / "art/generated/backgrounds"
BUILD = ROOT / "build"

# --- Shared style discipline (the one knob set every layer obeys) -------------
# Keep this tiny: it is the "pixel scale + tone treatment" the whole scene
# shares. Per-layer SHAPE and PALETTE live in PROFILES.
STYLE = {
    "dither": 0.85,     # ordered-dither strength folded into every band quantize
    "field": 256,       # value-noise lattice size (periodic); covers all ring radii
}
# 4x4 ordered (Bayer) dither matrix, centred to [-0.5, 0.5).
_BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6],
                    [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0 - 0.5


# --- Per-biome profiles: sky + per-layer shape/palette ------------------------
# kind "range" = broad mountain mass (+ optional nested contours / snow / haze);
# kind "hills" = simpler near form (+ treeline); art ending "clouds" = cloud band.
# feat_px = approximate major-feature wavelength in PIXELS, so every strip shares
#   one contour SCALE regardless of its declared width (far = broad, near = small).
PROFILES = {
    "surface": {
        "sky": {
            "stops": [(0.0, (24, 38, 92)), (0.40, (40, 76, 150)), (0.70, (80, 126, 188)),
                      (0.86, (196, 192, 178)), (1.0, (218, 206, 184))],
            "glow": {"y": 0.86, "color": (244, 216, 168), "strength": 0.42, "spread": 0.09},
        },
        "surface_clouds": {
            "seed": 7, "count": 9,
            "body": (238, 242, 249), "shadow": (198, 206, 223), "rim": (250, 252, 255),
            "length": (150, 360), "thick": (16, 34), "band": (0.30, 0.78),
            "underside": 3, "marks": 2, "feat_px": 46,
        },
        "surface_range_far": {
            "kind": "range", "seed": 903,
            "grad": [(0.0, (166, 180, 208)), (0.5, (130, 148, 186)), (1.0, (102, 122, 164))],
            "rim": (210, 221, 240), "rim_px": 1, "bands": 4,
            "base_frac": 0.90, "amp": 0.46, "feat_px": 300, "octaves": 4,
            "haze": 0.08, "see_through": 0.06,
            "snow": True, "snow_col": (234, 240, 248),
        },
        "surface_range_mid": {
            "kind": "range", "seed": 517,
            "grad": [(0.0, (84, 104, 146)), (0.5, (58, 78, 120)), (1.0, (36, 54, 96))],
            "rim": (128, 152, 192), "rim_px": 1, "bands": 4,
            "base_frac": 0.82, "amp": 0.58, "feat_px": 232, "octaves": 4,
            "relief_var": 0.42,
            "haze": 0.06, "see_through": 0.0,
            "contours": 2, "contour_step": 0.16, "contour_shade": 0.9,
        },
        "surface_hills_near": {
            "kind": "hills", "seed": 277,
            "grad": [(0.0, (84, 116, 82)), (0.4, (54, 78, 58)), (0.72, (32, 48, 40)),
                     (1.0, (15, 25, 23))],
            "rim": (104, 138, 96), "rim_px": 1, "bands": 3, "dither": 0.35,
            "base_frac": 0.60, "amp": 0.44, "feat_px": 170, "octaves": 4,
            "treeline": 0.07,
        },
    },
}


# --- Tileable value noise (cosine-interpolated, sampled on a ring) ------------
def _value_field(seed: int, g: int) -> np.ndarray:
    """A g x g lattice of random scalars in [0,1); indexed with wrap, so it is a
    periodic (toroidal) noise field."""
    return np.random.default_rng(seed).random((g, g))


def _sample_field(field: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    """Cosine-interpolated value noise at float coords (vectorised, wrapping).
    Easing S(t)=0.5(1-cos(pi t)) gives smooth lattice interpolation."""
    g = field.shape[0]
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    sx = 0.5 * (1.0 - np.cos(np.pi * (x - x0)))
    sy = 0.5 * (1.0 - np.cos(np.pi * (y - y0)))
    x0 %= g; y0 %= g
    x1 = (x0 + 1) % g; y1 = (y0 + 1) % g
    v00 = field[y0, x0]; v10 = field[y0, x1]
    v01 = field[y1, x0]; v11 = field[y1, x1]
    a = v00 * (1 - sx) + v10 * sx
    b = v01 * (1 - sx) + v11 * sx
    return a * (1 - sy) + b * sy


def _fbm_ring(w: int, seed: int, feat_px: float, octaves: int = 4,
              gain: float = 0.5, lacunarity: float = 2.0) -> np.ndarray:
    """Seamless 0..1 profile of length `w`: fractal value noise read around a
    circle so the ends meet. The base octave crosses ~w/feat_px lattice cells per
    loop (feat_px = major-feature wavelength in px), so the SAME feat_px gives the
    SAME on-screen feature size on any strip width. Octaves add finer, decorrelated
    detail. The traversal closes at x=w==x=0, so the strip tiles with no seam."""
    g = STYLE["field"]
    field = _value_field(seed, g)
    orng = np.random.default_rng(seed ^ 0x9E3779B9)   # independent octave offsets
    ang = 2.0 * np.pi * (np.arange(w) / float(w))
    out = np.zeros(w)
    amp, norm = 1.0, 0.0
    cells = max(1.0, w / float(feat_px))              # base ring circumference (cells)
    for o in range(octaves):
        radius = (cells * lacunarity ** o) / (2.0 * np.pi)
        ox, oy = orng.uniform(0, g, size=2)
        out += amp * _sample_field(field, ox + radius * np.cos(ang),
                                   oy + radius * np.sin(ang))
        norm += amp
        amp *= gain
    out /= norm
    lo, hi = np.percentile(out, 3), np.percentile(out, 97)   # robust full-relief stretch
    return np.clip((out - lo) / max(1e-6, hi - lo), 0.0, 1.0)


# --- Colour helpers -----------------------------------------------------------
def _grad(frac: np.ndarray, stops: list) -> np.ndarray:
    """Multi-stop vertical gradient -> (...,3), interpolated per channel."""
    pos = np.array([s[0] for s in stops])
    cols = np.array([s[1] for s in stops], float)
    return np.stack([np.interp(frac, pos, cols[:, c]) for c in range(3)], axis=-1)


def _quantize(frac: np.ndarray, bands: int, dither: float | None = None) -> np.ndarray:
    """Flatten a 0..1 field into `bands` flat steps with ordered dither so the
    tone treatment reads as deliberate pixel-art banding, not a smooth ramp.
    `dither` overrides the shared STYLE strength (near hills use less so the green
    reads as flat planes, not a busy grain)."""
    h, w = frac.shape
    amt = STYLE["dither"] if dither is None else dither
    dith = _BAYER[np.arange(h)[:, None] % 4, np.arange(w)[None, :] % 4] * amt
    return np.clip(np.floor((frac + dith / bands) * bands) / bands, 0.0, 1.0)


# --- Mountain / hill strip ----------------------------------------------------
def _make_strip(w: int, height: int, cfg: dict) -> Image.Image:
    """A silhouette strip rasterised at NATIVE resolution with hard stepped edges
    and flat quantized tones. The ridgeline is tileable ring noise (broad masses,
    no triangle rhythm). Optional nested contours (middle), atmospheric haze +
    hard snow caps (far), and a jagged treeline (near) all fold into the SAME tone
    ladder so every layer shares one shading treatment."""
    H = float(height)
    prof = _fbm_ring(w, cfg["seed"], cfg["feat_px"], cfg.get("octaves", 4))
    if cfg.get("kind") == "hills" and cfg.get("treeline"):
        # a soft low-frequency fringe = organic forest edge (its own seed stream).
        # Wider wavelength = a few gentle lobes, not a busy row of tiny bumps.
        prof = np.clip(prof + cfg["treeline"] *
                       (_fbm_ring(w, cfg["seed"] + 991, cfg["feat_px"] * 0.5, 2) - 0.5), 0, 1)
    # Per-column relief envelope: a very-broad second ring scales the amplitude up
    # and down across the strip so whole massifs read taller/shorter (and so wider
    # at the base) -- more mass-to-mass variation WITHOUT adding high-frequency
    # peakiness. 0 = uniform relief.
    amp = cfg["amp"]
    rv = cfg.get("relief_var", 0.0)
    if rv:
        slow = _fbm_ring(w, cfg["seed"] + 701, cfg["feat_px"] * 2.6, 2)
        amp = cfg["amp"] * ((1.0 - rv) + rv * 2.0 * slow)
    ridge = np.clip(cfg["base_frac"] - amp * prof, 0.02, 0.98) * H   # crest y (px)

    yy = np.arange(height)[:, None]
    dist = yy - ridge[None, :]                                   # px below the crest
    frac = np.clip(dist / np.maximum(1.0, H - ridge[None, :]), 0, 1)

    # atmospheric haze: lift the fill toward the sky tone near the crest (far ranges)
    if cfg.get("haze"):
        frac = np.clip(frac - cfg["haze"] * (1.0 - frac), 0, 1)

    # nested slope/shadow contours (middle): step the tone down one notch below
    # each inner contour line, so the mass reads as a few folded planes.
    shade = np.zeros_like(frac)
    for k in range(1, cfg.get("contours", 0) + 1):
        inner = ridge + k * cfg["contour_step"] * H + \
            (_fbm_ring(w, cfg["seed"] + 37 * k, cfg["feat_px"] * 0.6, 3) - 0.5) * 0.04 * H
        shade += (yy >= inner[None, :]).astype(float)
    bands = cfg.get("bands", 4)
    fq = _quantize(frac, bands, cfg.get("dither"))
    if cfg.get("contours"):
        fq = np.clip(fq + shade * (cfg.get("contour_shade", 0.9) / bands), 0, 1)
    col = _grad(fq, cfg["grad"])

    # hard rim highlight: the top rim_px rows of the mass catch the light (a flat
    # stepped band, not a soft falloff).
    rim_px = cfg.get("rim_px", 0)
    if rim_px:
        rim = (dist >= 0) & (dist < rim_px)
        col = np.where(rim[..., None], np.array(cfg["rim"], float)[None, None, :], col)

    # hard snow caps on just the tallest tips (far range): small flat white shapes.
    if cfg.get("snow"):
        snowline = np.percentile(ridge, 24)
        span = max(1.0, snowline - float(ridge.min()))
        peak = np.clip((snowline - ridge) / span, 0, 1)          # 0 at snowline..1 at tip
        depth = (1.0 + 2.5 * peak)[None, :]
        cap = (dist >= 0) & (dist < depth) & (peak[None, :] > 0.55)
        col = np.where(cap[..., None], np.array(cfg["snow_col"], float)[None, None, :], col)

    see = cfg.get("see_through", 0.0)
    alpha = np.where(dist >= 0, 255.0 * (1.0 - see * (1.0 - frac)), 0.0)
    img = np.dstack([np.clip(col, 0, 255), alpha]).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


# --- Clouds -------------------------------------------------------------------
def _make_clouds(w: int, height: int, cfg: dict) -> Image.Image:
    """Elongated pixel clouds: each cloud is one horizontal contour mass (a
    lozenge top envelope lumped by tileable noise) with a FLAT base, a restrained
    darker underside, and a couple of internal marks. Hard edges, 2-3 flat tones,
    tiles in x. Not sphere-lit, not mountain-shaped."""
    rng = np.random.default_rng(cfg.get("seed", 7))
    H = float(height)
    body = np.array(cfg.get("body", (238, 242, 249)), float)
    shadow = np.array(cfg.get("shadow", (198, 206, 223)), float)
    rim = np.array(cfg.get("rim", (250, 252, 255)), float)
    img = np.zeros((height, w, 4), float)
    # deformation noise shared across the band so each cloud's lumps match the
    # scene's edge scale and wrap seamlessly at the strip join.
    defo = _fbm_ring(w, cfg["seed"] + 5, cfg.get("feat_px", 46), 3)
    n = max(3, cfg.get("count", 9) + int(rng.integers(-1, 3)))
    lo_b, hi_b = cfg.get("band", (0.30, 0.78))
    base_len = cfg.get("length", (150, 360))
    base_thick = cfg.get("thick", (16, 34))
    # A few RECOGNIZABLE cloud proportions so they do not all read as one flat
    # lozenge. Each type scales the base length/thickness and sets the top-contour
    # power (low = broad flat top, high = fuller rounded crown). `w` = pick weight.
    types = cfg.get("types", [
        {"w": 3, "len": (0.95, 1.25), "thick": (0.85, 1.05), "pow": 0.72},  # bank (flat)
        {"w": 2, "len": (1.35, 1.85), "thick": (0.45, 0.65), "pow": 0.95},  # long thin streak
        {"w": 2, "len": (0.55, 0.80), "thick": (1.35, 1.75), "pow": 0.48},  # tall rounded puff
    ])
    weights = np.array([t["w"] for t in types], float)
    weights /= weights.sum()
    xcol = np.arange(w)
    for i in range(n):
        t = types[int(rng.choice(len(types), p=weights))]
        cx = (i + 0.5) / n * w + rng.uniform(-0.40, 0.40) * (w / n)
        L = rng.uniform(*base_len) * rng.uniform(*t["len"])
        thick = rng.uniform(*base_thick) * rng.uniform(*t["thick"])
        cy = rng.uniform(lo_b, hi_b) * H
        flip = -1.0 if rng.random() < 0.5 else 1.0    # break left/right symmetry
        # wrapped signed distance from the cloud centre, in [-w/2, w/2]
        dxc = ((xcol - cx + w / 2.0) % w) - w / 2.0
        u = dxc / L + 0.5                              # 0..1 across the cloud span
        inside = (u > 0.0) & (u < 1.0)
        env = np.sqrt(np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1))   # rounded ends
        env = env ** t["pow"]
        lump = 0.60 + 0.40 * defo                      # noisy top, restrained
        tilt = 1.0 + 0.10 * flip * (u - 0.5)           # gentle asymmetric lean
        top = cy - env * thick * lump * tilt
        base = cy + np.minimum(2.0, env * 2.0)         # nearly flat underside
        for x in np.nonzero(inside)[0]:
            t0 = int(np.ceil(top[x]))
            b0 = int(np.floor(base[x]))
            if b0 < t0 or t0 >= height or b0 < 0:
                continue
            t0 = max(0, t0); b0 = min(height - 1, b0)
            img[t0:b0 + 1, x, :3] = body
            img[t0:b0 + 1, x, 3] = 255.0
            img[t0, x, :3] = rim                       # 1px lit top edge
            und = cfg.get("underside", 3)
            if und and b0 - und >= t0:
                img[b0 - und + 1:b0 + 1, x, :3] = shadow   # restrained underside band
        # a few internal marks: short darker strokes a little above the base
        for _ in range(cfg.get("marks", 2)):
            mu = rng.uniform(0.28, 0.72)
            mx = int((cx + (mu - 0.5) * L) % w)
            mlen = int(rng.uniform(0.10, 0.22) * L)
            my = int(cy - thick * rng.uniform(0.10, 0.30))
            for xx in range(mx, mx + mlen):
                c = xx % w
                if 0 <= my < height and img[my, c, 3] > 0:
                    img[my, c, :3] = shadow
    return Image.fromarray(img.astype(np.uint8), "RGBA")


# --- Sky ----------------------------------------------------------------------
def _make_sky(w: int, height: int, cfg: dict) -> Image.Image:
    """A restrained vertical gradient with a warm horizon glow and a faint dither
    to break 8-bit banding. Opaque; the day/night CanvasModulate tints it in game."""
    pos = np.array([s[0] for s in cfg["stops"]])
    cols = np.array([s[1] for s in cfg["stops"]], float)
    yf = np.linspace(0, 1, height)
    grad = np.stack([np.interp(yf, pos, cols[:, c]) for c in range(3)], axis=-1)
    img = np.repeat(grad[:, None, :], w, axis=1)
    g = cfg["glow"]
    gw = np.exp(-(((np.arange(height) - g["y"] * height) / (g["spread"] * height)) ** 2))
    gw = (gw * g["strength"])[:, None, None]
    img = img * (1 - gw) + np.array(g["color"], float)[None, None, :] * gw
    img += np.random.default_rng(7).uniform(-1.2, 1.2, img.shape)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


# --- Dispatch + preview -------------------------------------------------------
def _layer_image(w: int, h: int, art: str, pal: dict, seed_shift: int = 0) -> Image.Image:
    cfg = dict(pal[art])
    if seed_shift:
        cfg["seed"] = int(cfg.get("seed", 0)) + seed_shift
    if art.endswith("clouds"):
        return _make_clouds(w, h, cfg)
    return _make_strip(w, h, cfg)


def _seam_check(img: Image.Image, out: Path, crop: int = 80) -> None:
    """Emit a join montage: the strip's RIGHT edge butted against its LEFT edge,
    so a seam in SHAPE or COLOUR at the x-wrap is visible (periodic formulas alone
    are not proof of an invisible pixel seam)."""
    w = img.width
    c = min(crop, w // 2)
    left = img.crop((0, 0, c, img.height))
    right = img.crop((w - c, 0, w, img.height))
    canvas = Image.new("RGBA", (c * 2 + 2, img.height), (255, 0, 255, 255))
    canvas.alpha_composite(right.convert("RGBA"), (0, 0))         # ...right | left...
    canvas.alpha_composite(left.convert("RGBA"), (c + 2, 0))
    canvas.convert("RGB").save(out)


def _preview(biome: dict, pal: dict, sky: Image.Image, out: Path,
             seed_shift: int = 0, pan: float = 0.0) -> None:
    """Full-scene composite at the game's native 640x360 frame, honouring each
    layer's declared order, dimensions, rise, and parallax (via `pan`, a fake
    camera x) so composition can be judged offline. The running game is the final
    authority."""
    W, H = sky.size
    canvas = sky.convert("RGBA")
    horizon = int(H * 0.64)
    for layer in biome["layers"]:
        lw, lh = int(layer["width"]), int(layer["height"])
        img = _layer_image(lw, lh, layer["art"], pal, seed_shift)
        rise = float(layer.get("rise", 0.0))
        par = float(layer.get("parallax", 0.3))
        bottom = horizon - rise
        scroll = pan * par
        x = -(scroll % lw)
        while x < W:
            canvas.alpha_composite(img, (int(round(x)), int(bottom - lh)))
            x += lw
    earth = Image.new("RGBA", (W, H - horizon), (26, 30, 30, 255))
    canvas.alpha_composite(earth, (0, horizon))
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out)
    print(f"  preview -> {out.relative_to(ROOT)}")


def build(biomes: dict, only: str | None, preview: bool,
          seed_shift: int = 0) -> int:
    """Write canonical art when seed_shift==0; otherwise write a PREVIEW-ONLY set
    to build/ and never touch the canonical assets."""
    canonical = seed_shift == 0
    if canonical:
        BG_DIR.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(parents=True, exist_ok=True)
    for name, biome in biomes["biomes"].items():
        if only and name != only:
            continue
        pal = PROFILES.get(name)
        if pal is None:
            print(f"  (no profile for biome '{name}'; skipping art)")
            continue
        sky_spec = biome["sky"]
        sky = _make_sky(int(sky_spec["width"]), int(sky_spec["height"]), pal["sky"])
        if canonical:
            sky.save(BG_DIR / f"{sky_spec['art']}.png")
            print(f"  {name}/{sky_spec['art']} {sky.size} RGB")
        for layer in biome["layers"]:
            img = _layer_image(int(layer["width"]), int(layer["height"]),
                               layer["art"], pal, seed_shift)
            if canonical:
                img.save(BG_DIR / f"{layer['art']}.png")
                print(f"  {name}/{layer['art']} {img.size} RGBA")
                _seam_check(img, BUILD / f"seam_{layer['art']}.png")
        if preview:
            tag = "" if canonical else f"_seed{seed_shift}"
            _preview(biome, pal, sky, BUILD / f"backdrop_preview_{name}{tag}.png",
                     seed_shift)
            _preview(biome, pal, sky, BUILD / f"backdrop_pan_{name}{tag}.png",
                     seed_shift, pan=900.0)
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="every biome (default: surface)")
    ap.add_argument("--no-preview", action="store_true")
    ap.add_argument("--seed", type=int, default=0,
                    help="preview an ALTERNATE seed to build/ (never overwrites canonical art)")
    args = ap.parse_args()
    biomes = json.loads((ROOT / "data/biomes.json").read_text(encoding="utf-8"))
    only = None if args.all else biomes.get("default_biome", "surface")
    return build(biomes, only, not args.no_preview, seed_shift=args.seed)


if __name__ == "__main__":
    raise SystemExit(main())
