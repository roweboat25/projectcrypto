"""Ground detail for the overworld: fringe tiles that let a soft ground (snow,
grass, sand, dirt) spill over a hard one at their seams, and decals (drifts,
footprints, tufts, flowers, cracks, stones) scattered over plain ground. All
drawn from the base tiles in build_art's atlas with Pillow, no new sheets.
map_builder.gd places them: see FAMILIES there for which tile is which."""
import math
import random

from PIL import Image, ImageDraw

T = 32

# soft grounds that get fringes, with the base tile the fringe is cut from
FRINGE = {"snow": "snow", "grass": "grass", "dry_grass": "dry_grass", "sand": "sand", "dirt": "dirt", "earth": "earth", "fairway": "fairway", "cement": "cement"}
KERB = {"cement"}   # a straight kerb instead of a ragged fringe
SIDES = ["n", "s", "e", "w", "ne", "nw", "se", "sw"]
# decals per ground family: three each
DECALS = ["snow", "grass", "dry_grass", "sand", "asphalt", "cement", "dirt", "earth", "gravel", "fairway", "promenade", "mud"]

DETAIL_TILES = {}
for _fam in FRINGE:
    for _s in SIDES:
        DETAIL_TILES["%s_fr_%s" % (_fam, _s)] = "detail"
for _fam in DECALS:
    for _i in (1, 2, 3):
        DETAIL_TILES["%s_dc_%d" % (_fam, _i)] = "detail"
for _i in (1, 2, 3, 4):
    DETAIL_TILES["mottle_%d" % _i] = "detail"


def _depth(i, seed, base=9, amp=3):
    rnd = random.Random(seed * 97 + i)
    return max(4, base + int(amp * math.sin(i * 0.75 + seed)) + rnd.randint(-2, 2))


def fringe(base_im, side, seed):
    """The soft tile masked to a ragged band along one side, over a thin shadow
    so it reads as lying on top of the hard ground."""
    mask = Image.new("L", (T, T), 0)
    mp = mask.load()
    shadow = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    sp = shadow.load()
    if side in ("n", "s", "e", "w"):
        for i in range(T):
            d = _depth(i, seed)
            for k in range(d):
                x, y = (i, k) if side == "n" else (i, T - 1 - k) if side == "s" else (k, i) if side == "w" else (T - 1 - k, i)
                mp[x, y] = 255
            for k in (d, d + 1):
                if k < T:
                    x, y = (i, k) if side == "n" else (i, T - 1 - k) if side == "s" else (k, i) if side == "w" else (T - 1 - k, i)
                    sp[x, y] = (0, 0, 0, 90 if k == d else 40)
    else:
        # an outer corner: a quarter blob tucked into that corner
        cx = 0 if "w" in side else T - 1
        cy = 0 if "n" in side else T - 1
        r = 9
        for y in range(T):
            for x in range(T):
                dist = math.hypot(x - cx, y - cy) + random.Random(seed + x * 31 + y).randint(-1, 1)
                if dist < r:
                    mp[x, y] = 255
                elif dist < r + 2:
                    sp[x, y] = (0, 0, 0, 80 if dist < r + 1 else 35)
    out = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    out.alpha_composite(shadow)
    soft = base_im.copy()
    soft.putalpha(mask)
    out.alpha_composite(soft)
    return out


def kerb(base_im, side, seed):
    """A straight kerb: a strip of the paving with a lit top and a shadow below."""
    out = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    strip = base_im.copy()
    mask = Image.new("L", (T, T), 0)
    md = ImageDraw.Draw(mask)
    d = 5
    box = {"n": [0, 0, T - 1, d - 1], "s": [0, T - d, T - 1, T - 1], "w": [0, 0, d - 1, T - 1], "e": [T - d, 0, T - 1, T - 1]}
    if side not in box:
        cx = 0 if "w" in side else T - d
        cy = 0 if "n" in side else T - d
        box[side] = [cx, cy, cx + d - 1, cy + d - 1]
    md.rectangle(box[side], fill=255)
    strip.putalpha(mask)
    out.alpha_composite(strip)
    od = ImageDraw.Draw(out)
    b = box[side]
    if side == "n":
        od.line([(0, b[3]), (T - 1, b[3])], fill=(0, 0, 0, 110))
        od.line([(0, b[3] + 1), (T - 1, b[3] + 1)], fill=(0, 0, 0, 50))
        od.line([(0, 0), (T - 1, 0)], fill=(255, 255, 255, 70))
    elif side == "s":
        od.line([(0, b[1]), (T - 1, b[1])], fill=(255, 255, 255, 70))
        od.line([(0, b[1] - 1), (T - 1, b[1] - 1)], fill=(0, 0, 0, 60))
    elif side == "w":
        od.line([(b[2], 0), (b[2], T - 1)], fill=(0, 0, 0, 110))
        od.line([(b[2] + 1, 0), (b[2] + 1, T - 1)], fill=(0, 0, 0, 50))
    elif side == "e":
        od.line([(b[0], 0), (b[0], T - 1)], fill=(255, 255, 255, 70))
        od.line([(b[0] - 1, 0), (b[0] - 1, T - 1)], fill=(0, 0, 0, 60))
    return out


def mottle(i):
    """A soft light or dark blotch that breaks up flat ground."""
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    rnd = random.Random(40 + i)
    col = (255, 255, 255) if i % 2 else (0, 0, 0)
    px = im.load()
    cx, cy = rnd.randint(10, 22), rnd.randint(10, 22)
    rx, ry = rnd.randint(9, 15), rnd.randint(7, 12)
    for y in range(T):
        for x in range(T):
            dd = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 + rnd.random() * 0.25
            if dd < 1.0:
                px[x, y] = col + (int(26 * (1.0 - dd)) + 6,)
    return im


def _tone(base_im, f):
    px = base_im.load()
    r, g, b, _ = px[8, 8]
    return (max(0, min(255, int(r * f))), max(0, min(255, int(g * f))), max(0, min(255, int(b * f))), 255)


def decal(fam, i, base_im):
    """Small marks that break up a plain stretch of ground."""
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(hash((fam, i)) & 0xFFFF)
    dark = _tone(base_im, 0.72)
    light = _tone(base_im, 1.18)
    if fam == "snow":
        if i == 1:   # a drift ridge
            d.line([(4, 20), (12, 14), (22, 15), (29, 11)], fill=(255, 255, 255, 220), width=2)
            d.line([(5, 22), (13, 16), (23, 17), (30, 13)], fill=dark[:3] + (120,), width=1)
        elif i == 2:  # footprints
            for k in range(4):
                x = 6 + k * 6
                y = 10 + (k % 2) * 7
                d.ellipse([x, y, x + 3, y + 5], fill=dark[:3] + (170,))
        else:         # twigs and a pebble
            d.line([(8, 24), (16, 18)], fill=(90, 70, 50, 255), width=1)
            d.line([(12, 21), (14, 24)], fill=(90, 70, 50, 255), width=1)
            d.ellipse([20, 20, 25, 24], fill=(120, 118, 124, 255))
            d.point((21, 21), fill=(170, 168, 174, 255))
    elif fam in ("grass", "dry_grass", "fairway"):
        if i == 1:   # tufts
            for k in range(5):
                x, y = rnd.randint(3, 27), rnd.randint(6, 28)
                d.line([(x, y), (x - 2, y - 5)], fill=dark, width=1)
                d.line([(x, y), (x + 1, y - 6)], fill=dark, width=1)
                d.line([(x, y), (x + 3, y - 4)], fill=light, width=1)
        elif i == 2:  # flowers
            cols = [(250, 250, 240, 255), (250, 220, 90, 255), (230, 120, 150, 255)] if fam == "grass" else [(240, 230, 170, 255)]
            for k in range(4):
                x, y = rnd.randint(4, 26), rnd.randint(4, 26)
                d.point((x, y + 2), fill=dark)
                d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=rnd.choice(cols))
                d.point((x, y), fill=(255, 240, 120, 255))
        else:         # a darker patch and a stone
            d.ellipse([6, 10, 24, 22], fill=dark[:3] + (90,))
            d.ellipse([14, 14, 20, 18], fill=(110, 108, 100, 255))
            d.point((15, 15), fill=(160, 158, 150, 255))
    elif fam == "sand":
        if i == 1:   # ripples
            for k in range(3):
                y = 7 + k * 9
                d.line([(2, y), (10, y - 2), (18, y + 1), (30, y - 1)], fill=light[:3] + (200,), width=1)
                d.line([(2, y + 1), (10, y - 1), (18, y + 2), (30, y)], fill=dark[:3] + (90,), width=1)
        elif i == 2:  # shells
            for k in range(3):
                x, y = rnd.randint(4, 26), rnd.randint(6, 26)
                d.pieslice([x - 3, y - 3, x + 3, y + 3], 180, 360, fill=(245, 236, 220, 255))
                d.line([(x - 2, y), (x + 2, y)], fill=(210, 190, 170, 255))
        else:         # seaweed and a pebble
            d.line([(6, 22), (12, 16), (18, 20), (26, 14)], fill=(70, 90, 60, 255), width=2)
            d.ellipse([8, 8, 13, 12], fill=(120, 118, 124, 255))
    elif fam in ("asphalt", "promenade", "cement"):
        if i == 1:   # a crack
            pts = [(4, 26)]
            for k in range(6):
                pts.append((pts[-1][0] + rnd.randint(2, 6), pts[-1][1] - rnd.randint(1, 5)))
            d.line(pts, fill=(14, 12, 16, 230), width=1)
            d.line([(p[0] + 1, p[1]) for p in pts], fill=light[:3] + (60,), width=1)
        elif i == 2:  # a tar patch or a stain
            d.rectangle([8, 10, 24, 22], fill=dark[:3] + (160,))
            d.rectangle([9, 11, 23, 21], fill=dark[:3] + (60,))
        else:         # a manhole, or a drain on paving
            d.ellipse([9, 9, 23, 23], fill=(60, 58, 60, 255))
            d.ellipse([11, 11, 21, 21], outline=(96, 92, 94, 255))
            d.line([(13, 16), (19, 16)], fill=(96, 92, 94, 255))
            d.line([(16, 13), (16, 19)], fill=(96, 92, 94, 255))
    elif fam in ("dirt", "earth", "mud", "gravel"):
        if i == 1:   # stones
            for k in range(4):
                x, y = rnd.randint(3, 26), rnd.randint(3, 26)
                d.ellipse([x, y, x + 4, y + 3], fill=(120, 110, 100, 255))
                d.point((x + 1, y + 1), fill=(170, 160, 150, 255))
        elif i == 2:  # wheel ruts
            d.line([(0, 12), (32, 10)], fill=dark[:3] + (170,), width=2)
            d.line([(0, 22), (32, 20)], fill=dark[:3] + (170,), width=2)
            d.line([(0, 14), (32, 12)], fill=light[:3] + (80,), width=1)
        else:         # a puddle
            d.ellipse([6, 12, 26, 24], fill=(70, 80, 100, 200))
            d.ellipse([9, 14, 19, 18], fill=(130, 150, 180, 140))
    return im


def make(name, base_tile):
    """base_tile(name) -> Image of a tile already in the atlas."""
    if name.startswith("mottle_"):
        return mottle(int(name.split("_")[1]))
    if "_fr_" in name:
        fam, side = name.split("_fr_")
        if fam in KERB:
            return kerb(base_tile(FRINGE[fam]), side, SIDES.index(side) + 1)
        return fringe(base_tile(FRINGE[fam]), side, SIDES.index(side) + 1)
    fam, i = name.split("_dc_")
    return decal(fam, int(i), base_tile(fam))
