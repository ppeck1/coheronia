from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PNG = ROOT / "png"
WEB = ROOT / "web"
PREVIEW = ROOT / "preview"

SKY_TOP = (7, 26, 46, 255)
SKY_MID = (11, 38, 57, 255)
SKY_LOW = (19, 47, 53, 255)
INK = (233, 251, 255, 255)
LINE = (189, 239, 255, 235)
WARM = (255, 208, 109, 255)
WARM_CORE = (255, 246, 207, 255)

POINTS = {
    "root": (284, 666),
    "left": (374, 424),
    "crown": (520, 286),
    "hearth": (652, 560),
    "right": (792, 382),
    "low": (558, 752),
    "small": (446, 570),
}

LINES = [
    ("root", "left"),
    ("left", "crown"),
    ("crown", "hearth"),
    ("hearth", "right"),
    ("left", "hearth"),
    ("hearth", "low"),
    ("low", "root"),
]


def lerp(a, b, t):
    return int(a + (b - a) * t)


def star(draw, x, y, r, fill, core=None):
    pts = [
        (x, y - r),
        (x + r * 0.24, y - r * 0.24),
        (x + r, y),
        (x + r * 0.24, y + r * 0.24),
        (x, y + r),
        (x - r * 0.24, y + r * 0.24),
        (x - r, y),
        (x - r * 0.24, y - r * 0.24),
    ]
    draw.polygon(pts, fill=fill)
    if core:
        cr = max(1, int(r * 0.26))
        draw.rectangle((x - cr, y - cr, x + cr, y + cr), fill=core)


def make_icon(size, transparent=False, maskable=False):
    scale = size / 1024
    canvas_size = 1024
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if not transparent:
        radius = 176
        draw.rounded_rectangle((0, 0, 1024, 1024), radius=radius, fill=(6, 19, 31, 255))
        for y in range(56, 968):
            t = (y - 56) / 912
            if t < 0.55:
                lt = t / 0.55
                col = tuple(lerp(SKY_TOP[i], SKY_MID[i], lt) for i in range(4))
            else:
                lt = (t - 0.55) / 0.45
                col = tuple(lerp(SKY_MID[i], SKY_LOW[i], lt) for i in range(4))
            draw.line((56, y, 968, y), fill=col)
        draw.rounded_rectangle((56, 56, 968, 968), radius=136, outline=(233, 251, 255, 34), width=24)
        draw.rounded_rectangle((92, 92, 932, 932), radius=104, outline=(255, 207, 114, 40), width=10)
        draw.rectangle((150, 200, 874, 224), fill=(215, 243, 255, 18))
        draw.rectangle((150, 800, 874, 824), fill=(215, 243, 255, 18))
        draw.rectangle((200, 150, 224, 874), fill=(215, 243, 255, 18))
        draw.rectangle((800, 150, 824, 874), fill=(215, 243, 255, 18))

    if maskable:
        # Keep the live mark well inside the central safe zone.
        shrink = 0.82
        offset = 1024 * (1 - shrink) / 2
        points = {
            key: (int(x * shrink + offset), int(y * shrink + offset))
            for key, (x, y) in POINTS.items()
        }
    else:
        points = POINTS

    glow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    hx, hy = points["hearth"]
    gd.ellipse((hx - 220, hy - 220, hx + 220, hy + 220), fill=(255, 178, 74, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(42))
    img.alpha_composite(glow)

    line_layer = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    ld = ImageDraw.Draw(line_layer)
    for a, b in LINES:
        ld.line((*points[a], *points[b]), fill=(215, 247, 255, 42), width=34)
    for a, b in LINES:
        ld.line((*points[a], *points[b]), fill=LINE, width=15)
    img.alpha_composite(line_layer)

    stars = {
        "crown": 64,
        "left": 56,
        "root": 50,
        "hearth": 74,
        "right": 48,
        "low": 44,
        "small": 32,
    }
    star_layer = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    sd = ImageDraw.Draw(star_layer)
    for key, r in stars.items():
        x, y = points[key]
        if key == "hearth":
            star(sd, x, y, r, WARM, WARM_CORE)
        else:
            star(sd, x, y, r, INK, (255, 255, 255, 255))
    star_layer = star_layer.filter(ImageFilter.GaussianBlur(0.4))
    img.alpha_composite(star_layer)

    noise = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    nd = ImageDraw.Draw(noise)
    for x, y, s, col in [
        (276, 254, 12, (165, 223, 255, 56)),
        (734, 294, 12, (165, 223, 255, 56)),
        (386, 724, 12, (165, 223, 255, 56)),
        (612, 214, 10, (165, 223, 255, 50)),
        (246, 598, 10, (165, 223, 255, 50)),
        (770, 676, 10, (255, 230, 169, 118)),
        (464, 810, 8, (255, 230, 169, 110)),
    ]:
        nd.rectangle((x, y, x + s, y + s), fill=col)
    img.alpha_composite(noise)

    resample = Image.Resampling.LANCZOS if size >= 64 else Image.Resampling.BOX
    out = img.resize((size, size), resample)
    if size <= 32:
        # Boost tiny favicon contrast after downsampling.
        px = out.load()
        for y in range(size):
            for x in range(size):
                r, g, b, a = px[x, y]
                if a and r > 130 and g > 150 and b > 150:
                    px[x, y] = (min(255, r + 24), min(255, g + 20), min(255, b + 12), a)
    return out


def save_all():
    PNG.mkdir(parents=True, exist_ok=True)
    WEB.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)

    targets = [
        ("favicon-16x16.png", 16, False, False),
        ("favicon-32x32.png", 32, False, False),
        ("favicon-48x48.png", 48, False, False),
        ("favicon-64x64.png", 64, False, False),
        ("icon-128x128.png", 128, False, False),
        ("apple-touch-icon.png", 180, False, False),
        ("android-chrome-192x192.png", 192, False, False),
        ("android-chrome-512x512.png", 512, False, False),
        ("maskable-icon-512x512.png", 512, False, True),
        ("transparent-mark-512x512.png", 512, True, False),
    ]
    for name, size, transparent, maskable in targets:
        make_icon(size, transparent=transparent, maskable=maskable).save(PNG / name)

    make_icon(48).save(
        WEB / "favicon.ico",
        sizes=[(16, 16), (32, 32), (48, 48)],
    )

    preview = Image.new("RGBA", (1440, 900), (245, 248, 250, 255))
    pd = ImageDraw.Draw(preview)
    try:
        font = ImageFont.truetype("DejaVuSans.ttf", 28)
        small = ImageFont.truetype("DejaVuSans.ttf", 18)
    except OSError:
        font = small = None
    pd.text((48, 42), "Coheronia constellation icon pack", fill=(15, 31, 42, 255), font=font)
    pd.text((48, 84), "Square favicon/app icon, transparent mark, and install-ready web files.", fill=(67, 82, 94, 255), font=small)
    placements = [
        ("16px, enlarged", "favicon-16x16.png", 80, 170, 8),
        ("32px, enlarged", "favicon-32x32.png", 260, 162, 5),
        ("48px, enlarged", "favicon-48x48.png", 480, 146, 4),
        ("64px, enlarged", "favicon-64x64.png", 720, 146, 3),
        ("128px", "icon-128x128.png", 1000, 170, 1),
        ("180px", "apple-touch-icon.png", 1180, 144, 1),
        ("512px, scaled", "android-chrome-512x512.png", 80, 500, 0.5),
        ("transparent mark", "transparent-mark-512x512.png", 500, 500, 0.5),
        ("maskable 512px", "maskable-icon-512x512.png", 920, 500, 0.5),
    ]
    for label, name, x, y, scale in placements:
        icon = Image.open(PNG / name).convert("RGBA")
        if scale != 1:
            icon = icon.resize((int(icon.width * scale), int(icon.height * scale)), Image.Resampling.NEAREST if icon.width <= 64 else Image.Resampling.LANCZOS)
        bg = (x - 18, y - 18, x + icon.width + 18, y + icon.height + 18)
        pd.rounded_rectangle(bg, radius=18, fill=(255, 255, 255, 255), outline=(215, 224, 230, 255), width=2)
        preview.alpha_composite(icon, (x, y))
        pd.text((x, y + icon.height + 28), label, fill=(32, 47, 58, 255), font=small)
    preview.convert("RGB").save(PREVIEW / "coheronia-icon-preview.png", quality=95)


if __name__ == "__main__":
    save_all()
