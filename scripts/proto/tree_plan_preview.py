#!/usr/bin/env python3
"""PROTOTYPE — staged procedural tree plan, Stages S1-S3 (block aesthetic).

Offline debug preview ONLY. Touches nothing in the game: no world generation,
saves, gen_version, gravity, or rendering. It implements the *pure seeded tree
planner* from the tree plan for two archetypes ("spreading", "upright") and:

  S1  trunk + primary branches -> a four-connected, rooted WOOD cell set.
  S2  a noisy crown contour (tip + apex lobes + an adaptive central bridge, two
      coherent fields) quantized to LEAF cells by sub-cell coverage; every leaf
      that joins the rooted wood+leaf graph is kept -- INCLUDING pockets enclosed
      by wood. Floating leaf blobs that never reach rooted wood are dropped.
  S3  (re-anchored to BLOCK pixel art, APPROVED aesthetic) render_block: the S2
      crown mass drawn as full-cell tiles, a solid continuous trunk, flat per-cell
      3-tone greens from broad directional masks (top-left light, lower/interior
      dark), modest +/-1 cell organic edge, a short fork hint, and a crown cleanup
      (main connected mass + enclosed-hole fill). Fixed day palette. NOT painterly:
      no celestial light, no circular depth rings, no exposed branch slivers.

    python scripts/proto/tree_plan_preview.py            # both archetypes -> build/
    python scripts/proto/tree_plan_preview.py --seed 30  # one specific root seed

Outputs (build/, git-ignored): tree_s2_<arch>.png (cell footprint),
tree_block_<arch>.png (approved render), tree_compare_<arch>.png (S2 vs block).

POSSIBLE EDITS / FOLLOW-UPS (approved to leave as-is for now):
  * Tall-trunk top-heaviness: the tallest seeds (e.g. upright H9) put a normal
    crown on a long trunk -> slightly mushroom-ish. Tie crown fullness to trunk
    height (taller -> a touch bigger crown) if every seed must pass.
  * `_flags()` are advisory only; wire a reject+reroll (or archetype reselect) if
    a hard "no sparse/mushroom" guarantee is wanted at generation time.
  * Add the third archetype ("windswept"): data profile + a one-sided lean/crown
    bias; geometry + renderer already support it.
  * Palette/contrast and trunk width are single constants (LGREEN/BGREEN/DGREEN,
    WOOD*, the trunk `whalf`); easy biome re-skins later.
  * Edge-variation amount lives in _vary_edge (trim/add probabilities); crown
    fullness in the profile lobes + `tau` + the pit/hole fill.

PORTING (LATER, separately authorized — needs a work order + gen_version/economy
decisions): plan_tree is the canonical planner to port to GDScript; render_block
is the art. S4/S5 (saplings, gravity, persistence, version gate) touch the engine
and are out of scope here.
"""
from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build"

CELL = 32          # on-screen px per world cell (16 world * 2 camera zoom)
SUB = 3            # sub-cell samples per axis for coverage quantization
TRUNK_COL = (120, 86, 50)
BRANCH_COL = (150, 112, 68)
EDGE_COL = (70, 48, 26)
LEAF_COL = (74, 116, 60)
LEAF_EDGE = (44, 74, 40)
POCKET_COL = (96, 140, 74)      # retained enclosed pocket (highlighted for review)
GROUND_COL = (58, 92, 52)
BG_COL = (26, 30, 36)

LEAF_SEED_DROP = 0.35           # matches world.gd LEAF_SEED_DROP_CHANCE (for E[seeds])

# --- Archetype profiles: shared geometry + a few controls with a clear visual
# effect. Examples are exploratory bounds, NOT balance values. ---
SPREADING = {
    "archetype_id": "spreading",
    "height": (6, 8), "lean": 0.7, "bend_amp": 0.8, "bend_freq": 1.4,
    "primary_branch_count": 2, "branch_span": 0.95, "branch_beta": 1.0,
    "branch_elev_deg": (44, 58), "branch_arc": 0.55, "branch_bend": 0.7,
    # crown
    "crown_w": 2.5, "crown_h": 1.95, "apex_scale": 1.3, "bridge_margin": 1.15,
    "tau": 0.10, "q": 0.38, "rough_low": 0.26, "rough_mid": 0.16,
    # S3 pixel-art controls
    "r0": 0.46, "r_min": 0.28, "taper": 0.5, "branch_r": 0.44,
    "reveal": 0.08, "terminal_r": 0.95, "depth": (0.15, 0.5, 0.9), "r_support": 3,
}
UPRIGHT = {
    "archetype_id": "upright",
    "height": (7, 9), "lean": 0.35, "bend_amp": 0.5, "bend_freq": 1.2,
    "primary_branch_count": 2, "branch_span": 0.7, "branch_beta": 1.2,
    "branch_elev_deg": (62, 76), "branch_arc": 0.4, "branch_bend": 0.5,
    "crown_w": 2.05, "crown_h": 2.05, "apex_scale": 1.3, "bridge_margin": 0.95,
    "tau": 0.12, "q": 0.38, "rough_low": 0.24, "rough_mid": 0.15,
    "r0": 0.46, "r_min": 0.28, "taper": 0.5, "branch_r": 0.44,
    "reveal": 0.08, "terminal_r": 0.95, "depth": (0.15, 0.5, 0.9), "r_support": 3,
}
ARCHETYPES = {"spreading": SPREADING, "upright": UPRIGHT}


# --- Stable seeded channels (NOT Python's hash(), which is not reproducible) ---
def _rng(world_seed: int, rx: int, ry: int, archetype: str, channel: str):
    key = f"{world_seed}|{rx}|{ry}|{archetype}|{channel}".encode()
    return np.random.default_rng(int.from_bytes(hashlib.sha256(key).digest()[:8], "big"))


def _coh(rng, octaves=4):
    """A small coherent scalar field on u in [0,1] -> [-1,1] (seeded sine sum)."""
    freqs, amps = [1, 2, 3, 5][:octaves], [1.0, 0.5, 0.33, 0.2][:octaves]
    phase = rng.uniform(0, 2 * math.pi, len(freqs))
    tot = sum(amps)
    return lambda u: sum(a * math.sin(2 * math.pi * f * u + p)
                         for f, a, p in zip(freqs, amps, phase)) / tot


def _field2d(rng, g=64):
    return rng.random((g, g))


def _sample2d(field, x, y):
    """Cosine-interpolated 2D value noise at float (x,y) -> [0,1], wrapping."""
    g = field.shape[0]
    x0, y0 = math.floor(x), math.floor(y)
    sx = 0.5 * (1 - math.cos(math.pi * (x - x0)))
    sy = 0.5 * (1 - math.cos(math.pi * (y - y0)))
    x0 %= g; y0 %= g; x1 = (x0 + 1) % g; y1 = (y0 + 1) % g
    a = field[y0, x0] * (1 - sx) + field[y0, x1] * sx
    b = field[y1, x0] * (1 - sx) + field[y1, x1] * sx
    return a * (1 - sy) + b * sy


# --- The pure planner: (world_seed, root, profile) -> rooted wood + leaf cells --
def plan_tree(world_seed: int, root: tuple[int, int], cfg: dict) -> dict:
    x0, yg = root
    aid = cfg["archetype_id"]
    rt = _rng(world_seed, x0, yg, aid, "trunk")
    H = int(rt.integers(cfg["height"][0], cfg["height"][1] + 1))
    lean = cfg["lean"] * rt.uniform(0.5, 1.0) * (1 if rt.random() < 0.5 else -1)
    nA = _coh(_rng(world_seed, x0, yg, aid, "trunk_noise"))

    def T(t):                                   # trunk centerline
        x = x0 + lean * t + cfg["bend_amp"] * t * (1 - t) * nA(cfg["bend_freq"] * t)
        return x, yg - H * t

    trunk_line = [T(t) for t in np.linspace(1.0 / H, 1.0, H * 6)]
    trunk_cells = _rasterize([(float(x0), float(yg - 1))] + trunk_line)

    rb = _rng(world_seed, x0, yg, aid, "branches")
    n = cfg["primary_branch_count"]
    branch_cells: list[tuple[int, int]] = []
    tips: list[tuple[float, float]] = []
    branch_lines: list[list] = []
    for i, ti in enumerate(sorted(rb.uniform(0.40, 0.82, n))):
        side = (1 if i % 2 == 0 else -1) * (-1 if rb.random() < 0.5 else 1)
        elev = math.radians(rb.uniform(*cfg["branch_elev_deg"]))
        d = (side * math.cos(elev), -math.sin(elev))        # up and out (y down)
        nrm = (-d[1], d[0])
        L = max(2.2, H * cfg["branch_span"] * ((1 - ti) ** cfg["branch_beta"]) * rb.uniform(0.85, 1.15))
        nB = _coh(_rng(world_seed, x0, yg, aid, f"branch{i}"))
        pts = []
        for u in np.linspace(0, 1, 28):
            bx, by = T(ti)
            arc, bend = cfg["branch_arc"] * math.sin(math.pi * u), cfg["branch_bend"] * u * (1 - u) * nB(u)
            pts.append((bx + u * L * d[0] + (arc + bend) * nrm[0],
                        by + u * L * d[1] + (arc + bend) * nrm[1]))
        branch_cells.extend(_rasterize([T(ti)] + pts))
        branch_lines.append(pts)
        tips.append(pts[-1])
    tips.append(T(1.0))                                     # apex lobe at crown top

    wood = _dedup(trunk_cells + branch_cells)
    trunk_set = set(trunk_cells)
    plan = {"root": root, "archetype": aid, "height": H, "lean": lean, "cfg": cfg,
            "world_seed": world_seed,
            "wood": wood, "trunk": [c for c in wood if c in trunk_set],
            "branch": [c for c in wood if c not in trunk_set], "tips": tips,
            "trunk_line": [(float(x0), float(yg - 1))] + trunk_line,
            "branch_lines": branch_lines}
    _plan_canopy(plan, world_seed, cfg)
    return plan


def _plan_canopy(plan: dict, world_seed: int, cfg: dict) -> None:
    """S2: build a noisy crown field from tip/apex lobes + an adaptive central
    bridge, quantize to leaf cells by sub-cell coverage, keep every leaf in the
    rooted wood+leaf graph (incl. wood-enclosed pockets); drop floating blobs."""
    x0, yg = plan["root"]
    aid = plan["archetype"]
    tips = plan["tips"]
    rw, rh = cfg["crown_w"], cfg["crown_h"]
    # lobes: (cx, cy, rx, ry). apex (last tip) is larger.
    lobes = [(tx, ty, rw, rh) for tx, ty in tips]
    lobes[-1] = (lobes[-1][0], lobes[-1][1], rw * cfg["apex_scale"], rh * cfg["apex_scale"])
    cxs = [t[0] for t in tips]; cys = [t[1] for t in tips]
    bx, by = sum(cxs) / len(cxs), sum(cys) / len(cys)       # adaptive central bridge
    span = max(max(cxs) - min(cxs), max(cys) - min(cys)) / 2.0 + cfg["bridge_margin"]
    lobes.append((bx, by, span, span * 0.8))

    fl = _field2d(_rng(world_seed, x0, yg, aid, "canopy_low"))
    fm = _field2d(_rng(world_seed, x0, yg, aid, "canopy_mid"))

    def F(x, y):
        base = max(1.0 - math.hypot((x - cx) / rx, (y - cy) / ry) for cx, cy, rx, ry in lobes)
        n_low = 2 * _sample2d(fl, x / 3.0, y / 3.0) - 1
        n_mid = 2 * _sample2d(fm, x / 1.6, y / 1.6) - 1
        return base + cfg["rough_low"] * n_low + cfg["rough_mid"] * n_mid

    wood = set(plan["wood"])
    minx = int(math.floor(min(l[0] - l[2] for l in lobes)))
    maxx = int(math.ceil(max(l[0] + l[2] for l in lobes)))
    miny = int(math.floor(min(l[1] - l[3] for l in lobes)))
    maxy = int(math.ceil(max(l[1] + l[3] for l in lobes)))
    tau, q = cfg["tau"], cfg["q"]
    leaf_candidates: list[tuple[int, int]] = []
    for cy in range(miny, maxy + 1):
        for cx in range(minx, maxx + 1):
            if cy >= yg or (cx, cy) in wood:               # ground priority; wood > leaf
                continue
            hits = sum(1 for sy in range(SUB) for sx in range(SUB)
                       if F(cx + (sx + 0.5) / SUB - 0.5, cy + (sy + 0.5) / SUB - 0.5) > tau)
            if hits / (SUB * SUB) >= q:
                leaf_candidates.append((cx, cy))

    # Retention: rooted component over the wood+leaf union (4-neighbour) from the
    # base trunk cell. Keeps enclosed pockets; drops floating blobs.
    union = wood | set(leaf_candidates)
    start = (x0, yg - 1)
    seen = {start}
    stack = [start]
    while stack:
        cx, cy = stack.pop()
        for nb in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if nb in union and nb not in seen:
                seen.add(nb); stack.append(nb)
    leaf_set = {c for c in leaf_candidates if c in seen}
    dropped = [c for c in leaf_candidates if c not in seen]
    # Fill 1-cell pits so the crown reads FULLER (not holey / square-notched): an
    # air cell boxed in on >=3 sides by crown or wood joins the crown. Two passes.
    for _ in range(2):
        add = set()
        for cy2 in range(miny, maxy + 1):
            for cx2 in range(minx, maxx + 1):
                c = (cx2, cy2)
                if cy2 >= yg or c in leaf_set or c in wood:
                    continue
                if sum((cx2 + dx, cy2 + dy) in leaf_set or (cx2 + dx, cy2 + dy) in wood
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) >= 3:
                    add.add(c)
        leaf_set |= add
    pockets = [c for c in leaf_set
               if not any((c[0] + dx, c[1] + dy) in leaf_set
                          for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    # S3 branch_occlusion_mask eligibility: upper-crown wood cells inside the field
    # with a surviving leaf within Manhattan R_support (visual reach, not gameplay).
    R_support = cfg.get("r_support", 3)
    elig = set()
    if leaf_set:
        maxly = max(c[1] for c in leaf_set)
        leaves = list(leaf_set)
        for c in wood:
            if c[1] <= maxly and F(c[0], c[1]) > tau \
                    and min(abs(c[0] - lx) + abs(c[1] - ly) for lx, ly in leaves) <= R_support:
                elig.add(c)
    plan["leaf"] = sorted(leaf_set)
    plan["pockets"] = pockets
    plan["dropped_leaf_blobs"] = dropped
    plan["lobes"] = lobes
    plan["fl"] = fl
    plan["fm"] = fm
    plan["tau"] = tau
    plan["eligible_wood"] = elig


def _rasterize(points):
    """Float centerline -> ordered four-connected cells; a diagonal step inserts a
    deterministic orthogonal bridge so no woody cell is only diagonally attached."""
    out, prev = [], None
    for fx, fy in points:
        c = (int(round(fx)), int(round(fy)))
        if c == prev:
            continue
        if prev is not None and abs(c[0] - prev[0]) + abs(c[1] - prev[1]) == 2:
            out.append((c[0], prev[1]))
        out.append(c)
        prev = c
    return out


def _dedup(cells):
    seen, out = set(), []
    for c in cells:
        if c not in seen:
            seen.add(c); out.append(c)
    return out


def assert_rooted(plan: dict) -> bool:
    """Every wood AND leaf cell four-connected to the root ground cell."""
    x0, yg = plan["root"]
    union = set(plan["wood"]) | set(plan["leaf"])
    start = (x0, yg - 1)
    if start not in union:
        return False
    seen, stack = {start}, [start]
    while stack:
        cx, cy = stack.pop()
        for nb in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if nb in union and nb not in seen:
                seen.add(nb); stack.append(nb)
    return seen == union


# --- S3 (re-anchored): S2 block crown + organic edge + flat tonal patches ------
# Block-scale pixel art, NOT painterly. No celestial lighting, no circular depth
# rings, no exposed branch slivers. S3 = S2 plus (a) a +/-1-2px irregular crown
# edge, (b) 2-3 FLAT leaf tones from broad DIRECTIONAL masks (top-left light,
# lower/interior shadow), and (c) short fork HINTS only. Fixed day palette.
PXN = 16                               # native pixels per cell (tile authoring scale)
LGREEN = (122, 164, 96)                # lighter top/outer patches
BGREEN = (86, 132, 70)                 # base green (most of the crown)
DGREEN = (56, 96, 56)                  # darker underside/interior patches
WOOD = (120, 88, 52)
WOOD_DK = (94, 66, 40)
WOOD_LT = (140, 106, 66)


def _vary_edge(leaf: set, blocked: set, world_seed: int, root, aid: str) -> set:
    """Modest, tile-aligned +/-1 cell silhouette variation: trim a few convex
    perimeter cells and add a few adjacent ones. Deterministic; keeps the crown
    compact and connected (never opens an interior hole)."""
    rng = _rng(world_seed, root[0], root[1], aid, "edgevar")
    leaf = set(leaf)
    n4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
    # Only trim LONE spurs (cells poking out on >=3 sides) so trimming breaks a
    # too-uniform edge without thinning the mass; add a few edge bumps to keep the
    # silhouette from reading as a clean rectangle. Net bias: fuller, less square.
    spurs = sorted(c for c in leaf if sum((c[0] + dx, c[1] + dy) not in leaf for dx, dy in n4) >= 3)
    for c in spurs:
        if len(leaf) > 8 and rng.random() < 0.5:
            leaf.discard(c)
    cand = sorted({(c[0] + dx, c[1] + dy) for c in leaf for dx, dy in n4} - leaf - blocked)
    for c in cand:
        if c[1] < root[1] and rng.random() < 0.18:        # stay above ground
            leaf.add(c)
    return leaf


def _clean_crown(foliage: set, yg: int) -> set:
    """Keep only the crown's main connected mass (drop specks that linked only
    through a now-hidden below-crown branch) and fill fully-enclosed holes, so the
    crown reads as one solid leafy shape."""
    if not foliage:
        return foliage
    n4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
    top = min(foliage, key=lambda c: (c[1], c[0]))
    seen = {top}; st = [top]
    while st:
        x, y = st.pop()
        for dx, dy in n4:
            nb = (x + dx, y + dy)
            if nb in foliage and nb not in seen:
                seen.add(nb); st.append(nb)
    foliage = seen
    xs = [c[0] for c in foliage]; ys = [c[1] for c in foliage]
    minx, maxx, miny, maxy = min(xs) - 1, max(xs) + 1, min(ys) - 1, max(ys) + 1
    air = set(); st = []
    for x in range(minx, maxx + 1):
        for y in (miny, maxy):
            if (x, y) not in foliage:
                air.add((x, y)); st.append((x, y))
    for y in range(miny, maxy + 1):
        for x in (minx, maxx):
            if (x, y) not in foliage and (x, y) not in air:
                air.add((x, y)); st.append((x, y))
    while st:
        x, y = st.pop()
        for dx, dy in n4:
            nb = (x + dx, y + dy)
            if minx <= nb[0] <= maxx and miny <= nb[1] <= maxy and nb not in foliage and nb not in air:
                air.add(nb); st.append(nb)
    for y in range(miny, maxy + 1):
        for x in range(minx, maxx + 1):
            if (x, y) not in foliage and (x, y) not in air and y < yg:
                foliage.add((x, y))                          # enclosed hole -> fill
    return foliage


def render_block(plan: dict) -> Image.Image:
    """S2 crown mass -> clean BLOCK pixel art (the S2 read, plus tone + edge):
    full-cell leafy crown covering the upper wood, flat per-cell 3-tone greens from
    broad directional masks, a solid full-width trunk below the crown, +/-1 cell
    edge variation, and a short fork hint where the trunk meets the crown. No
    painterly edges, no circular rings, no dangling branches. Deterministic; fixed
    day palette."""
    x0, yg = plan["root"]
    aid = plan["archetype"]
    trunk_cells = set(plan["trunk"]); branch_cells = set(plan["branch"])
    leaf = _vary_edge(plan["leaf"], trunk_cells | branch_cells, plan["world_seed"], plan["root"], aid)
    if not leaf:
        leaf = {(x0, yg - 2)}
    crown_bottom0 = max(cy for _, cy in leaf)
    lx0, lx1 = min(cx for cx, _ in leaf), max(cx for cx, _ in leaf)
    # Foliage covers the upper wood: any trunk/branch cell within the crown span
    # and width reads as leaves, so no brown pokes through the canopy.
    foliage = set(leaf)
    for cx, cy in (trunk_cells | branch_cells):
        if cy <= crown_bottom0 and lx0 <= cx <= lx1:
            foliage.add((cx, cy))
    foliage = _clean_crown(foliage, yg)
    crown_bottom = max(cy for _, cy in foliage)
    visible_trunk = [c for c in trunk_cells if c[1] > crown_bottom]

    xs = [c[0] for c in foliage] + [c[0] for c in visible_trunk]
    ys = [c[1] for c in foliage] + [c[1] for c in visible_trunk]
    minx, maxx = min(xs) - 1, max(xs) + 1
    miny, maxy = min(ys) - 1, yg
    W, H = (maxx - minx + 1) * PXN, (maxy - miny + 1) * PXN
    img = np.zeros((H, W, 4))

    def fill(cx, cy, color, y0=0, y1=PXN, x0c=0, x1c=PXN):
        r, c = (cy - miny) * PXN, (cx - minx) * PXN
        if r < 0 or c < 0:
            return
        img[r + y0:r + y1, c + x0c:c + x1c, :3] = color
        img[r + y0:r + y1, c + x0c:c + x1c, 3] = 255

    for cx in range(minx, maxx + 1):                      # ground
        fill(cx, yg, GROUND_COL)

    # Solid full-width trunk (below the crown), with 2px side shade + a light streak.
    tl = np.array(plan["trunk_line"]); order = np.argsort(tl[:, 1])
    for cx, cy in visible_trunk:
        tx = float(np.interp(cy + 0.5, tl[order, 1], tl[order, 0]))
        off = int(round((tx - cx) * PXN))
        lo = max(0, 2 + off); hi = min(PXN, PXN - 2 + off)
        fill(cx, cy, WOOD, x0c=lo, x1c=hi)
        fill(cx, cy, WOOD_DK, x0c=lo, x1c=min(hi, lo + 1))
        fill(cx, cy, WOOD_DK, x0c=max(lo, hi - 1), x1c=hi)
        fill(cx, cy, WOOD_LT, x0c=lo + 2, x1c=min(hi, lo + 4))

    # Fork hint: the trunk pokes a few px up into the crown base so it reads joined.
    # Anchored to the trunk's OWN top cell/column (never floor()'d to a neighbour,
    # which used to drop a stray wood block beside a leaning trunk).
    if visible_trunk:
        cx, cy = min(visible_trunk, key=lambda c: c[1])
        txc = float(np.interp(cy - 0.5, tl[order, 1], tl[order, 0]))
        cen = int(round((txc - cx) * PXN)) + PXN // 2        # centre within this cell
        fill(cx, cy - 1, WOOD_DK, y0=PXN - 5, y1=PXN,
             x0c=max(0, cen - 2), x1c=min(PXN, cen + 2))

    # Crown: flat per-cell 3 tones from broad directional masks (top-left lighter,
    # lower/interior darker). Per-cell -> reads as tiles, not a painterly blob.
    cy0, cy1 = min(c[1] for c in foliage), max(c[1] for c in foliage)
    fx0, fx1 = min(c[0] for c in foliage), max(c[0] for c in foliage)
    tvals = {}
    for cx, cy in foliage:
        ny = (cy - cy0) / max(1, cy1 - cy0)
        nx = (cx - fx0) / max(1, fx1 - fx0)
        patch = 2 * _sample2d(plan["fm"], cx / 2.6 + 2, cy / 2.6 + 7) - 1
        tvals[(cx, cy)] = (1 - ny) + 0.35 * (1 - nx) + 0.5 * patch
    arr = sorted(tvals.values())
    lo = arr[int(0.28 * (len(arr) - 1))]; hi = arr[int(0.74 * (len(arr) - 1))]
    for (cx, cy), tv in tvals.items():
        col = LGREEN if tv >= hi else (DGREEN if tv <= lo else BGREEN)
        fill(cx, cy, col)
        if (cx, cy + 1) not in foliage and cy + 1 <= yg:   # underside shadow band
            fill(cx, cy, DGREEN, y0=PXN - 3, y1=PXN)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")


# --- Debug preview ------------------------------------------------------------
def _draw_tree(plan: dict) -> Image.Image:
    cells = plan["wood"] + plan["leaf"]
    xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
    x0, yg = plan["root"]
    minx, maxx = min(xs) - 1, max(xs) + 1
    miny, maxy = min(ys) - 1, yg + 1
    img = Image.new("RGB", ((maxx - minx + 1) * CELL, (maxy - miny + 1) * CELL), BG_COL)
    d = ImageDraw.Draw(img)

    def box(cx, cy, fill):
        px, py = (cx - minx) * CELL, (cy - miny) * CELL
        d.rectangle([px, py, px + CELL - 1, py + CELL - 1], fill=fill, outline=EDGE_COL)

    for cx in range(minx, maxx + 1):
        box(cx, yg, GROUND_COL)
    pockets = set(plan["pockets"])
    for c in plan["leaf"]:                                   # canopy behind
        px, py = (c[0] - minx) * CELL, (c[1] - miny) * CELL
        d.rectangle([px, py, px + CELL - 1, py + CELL - 1],
                    fill=POCKET_COL if c in pockets else LEAF_COL, outline=LEAF_EDGE)
    for c in plan["branch"]:                                 # wood on top (fork visible)
        box(c[0], c[1], BRANCH_COL)
    for c in plan["trunk"]:
        box(c[0], c[1], TRUNK_COL)
    return img


def _montage(imgs, labels, title, out):
    pad, top = 12, 26
    hmax = max(i.height for i in imgs)
    canvas = Image.new("RGB", (sum(i.width for i in imgs) + pad * (len(imgs) + 1),
                               hmax + top + pad), (18, 18, 22))
    d = ImageDraw.Draw(canvas)
    d.text((8, 8), title, fill=(235, 235, 235))
    x = pad
    for im, lab in zip(imgs, labels):
        canvas.paste(im, (x, top + (hmax - im.height)))
        d.text((x + 2, top - 14), lab, fill=(200, 200, 200))
        x += im.width + pad
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    print(f"  preview -> {out.relative_to(ROOT)}")


def _scale2x(im: Image.Image) -> Image.Image:
    up = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
    bg = Image.new("RGB", up.size, BG_COL)
    bg.paste(up, (0, 0), up)
    return bg


def _flags(plan: dict) -> str:
    """Cheap readability flags so a seed that reads as a blob/mushroom/cabbage/
    broken trunk can be rejected on the comparison sheet (visual gate, not auto)."""
    lx = [c[0] for c in plan["leaf"]]; ly = [c[1] for c in plan["leaf"]]
    f = []
    if not lx:
        return "NO-CROWN"
    cw, ch = max(lx) - min(lx) + 1, max(ly) - min(ly) + 1
    tx = [c[0] for c in plan["trunk"]]
    trunk_hi = min(c[1] for c in plan["trunk"])
    if cw > ch * 2.4:
        f.append("wide?")                                    # cabbage / mushroom cap
    if ch <= 2:
        f.append("flat?")
    if len(plan["leaf"]) < 5:
        f.append("sparse?")
    if max(tx) - min(tx) > 2:
        f.append("trunk-wobble?")                            # broken/zigzag trunk
    if min(ly) > trunk_hi + 1:
        f.append("mushroom?")                                # crown floats above trunk top
    return " ".join(f)


def _grid(rows, col_labels, row_labels, title, out):
    pad, top, lh = 12, 26, 14
    ncol = max(len(r) for r in rows)
    colw = [max((rows[r][c].width if c < len(rows[r]) else 0)
                for r in range(len(rows))) for c in range(ncol)]
    rowh = [max(im.height for im in r) for r in rows]
    W = sum(colw) + pad * (ncol + 1)
    H = top + sum(rowh) + (lh + pad) * len(rows) + pad
    canvas = Image.new("RGB", (W, H), (18, 18, 22))
    d = ImageDraw.Draw(canvas)
    d.text((8, 8), title, fill=(235, 235, 235))
    y = top
    for r, row in enumerate(rows):
        d.text((8, y), row_labels[r], fill=(170, 200, 170))
        y += lh
        x = pad
        for c in range(ncol):
            if c < len(row):
                canvas.paste(row[c], (x, y))
                if r == 0:
                    d.text((x + 2, top - 2), col_labels[c], fill=(200, 200, 200))
            x += colw[c] + pad
        y += rowh[r] + pad
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)
    print(f"  preview -> {out.relative_to(ROOT)}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--count", type=int, default=6)
    args = ap.parse_args()
    seeds = [args.seed] if args.seed is not None else list(range(args.count))
    ok = True

    # S2 cell footprint (unchanged baseline) + block render, per archetype.
    for aid, cfg in ARCHETYPES.items():
        s2, blk, labels = [], [], []
        for s in seeds:
            plan = plan_tree(s, (0, 0), cfg)
            ok &= assert_rooted(plan) and not plan["dropped_leaf_blobs"]
            s2.append(_draw_tree(plan))
            blk.append(_scale2x(render_block(plan)))
            labels.append(f"seed {s} H{plan['height']}  " + _flags(plan))
        _montage(blk, labels,
                 f"S3-block ({aid}) = S2 + organic edge + flat tone patches (fixed day palette)",
                 BUILD / f"tree_block_{aid}.png")
        _grid([s2, blk], [f"seed {s}" for s in seeds],
              ["S2 cells (baseline)", "S3-block (S2 + edge + tone)"],
              f"S2 vs S3-block comparison ({aid}); reject blob/mushroom/cabbage/broken-trunk",
              BUILD / f"tree_compare_{aid}.png")

    print(f"  all rooted (wood+leaf) & no floating blobs: {ok}")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
