"""Battle art: one two-frame sheet per foe in assets/foes/<id>.png (2 x 96x96,
frame 2 a small idle shift) and assets/foes/foes.json. People and the things
LPC can dress are composed from the character layers' front idle frame at
1.5x; the animals and anomalies are drawn with Pillow. Anomalies get the
"wrong" treatment: harder contrast and glowing eyes. Called by build_art.main()."""
import json
import os
import random
from PIL import Image, ImageDraw

FW = 96
OUT = (18, 12, 16, 255)

_sheet = None
_adult = None
_outline = None


def _new():
    return Image.new("RGBA", (FW, FW), (0, 0, 0, 0))


def _person(layers, frame=0, scale=1.5, dx=0, dy=0, into=None):
    """The front-facing idle frame of an LPC layer stack, scaled and bottom-aligned."""
    cell = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    for _walk, idle in layers:
        cell.alpha_composite(_sheet(idle).crop((frame * 64, 128, frame * 64 + 64, 192)))
    size = int(64 * scale)
    cell = cell.resize((size, size), Image.NEAREST)
    im = into or _new()
    im.alpha_composite(cell, ((FW - size) // 2 + dx, FW - size + dy))
    return im


def _glow_eyes(d, x, y, gap, col=(255, 230, 60), r=2):
    for ex in (x, x + gap):
        d.ellipse([ex - r - 3, y - r - 3, ex + r + 3, y + r + 3], fill=col + (50,))
        d.ellipse([ex - r - 1, y - r - 1, ex + r + 1, y + r + 1], fill=col + (150,))
        d.ellipse([ex - r, y - r, ex + r, y + r], fill=col + (255,))


def _wrong(im):
    """The anomaly treatment: contrast pushed and colours snapped to few steps."""
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if a < 255:
                px[x, y] = (r, g, b, a)
                continue
            out = []
            for v in (r, g, b):
                v = int((v - 128) * 1.5 + 128)
                v = max(0, min(255, v))
                out.append((v // 48) * 48 + 16 if v < 240 else 255)
            px[x, y] = (out[0], out[1], out[2], a)
    return im


def _shift(im, dx=0, dy=0):
    out = _new()
    out.alpha_composite(im, (dx, dy))
    return out


def _dog(d, x0, y0, body=(110, 86, 60), dark=(70, 54, 40), w=56, mangy=False, grey=False):
    """A dog facing the viewer: round chest, head above, forelegs, teeth."""
    cx = x0 + w // 2
    d.ellipse([x0, y0 + 20, x0 + w, y0 + 56], fill=body)
    d.rectangle([x0 + 8, y0 + 50, x0 + 14, y0 + 66], fill=body)
    d.rectangle([x0 + w - 15, y0 + 50, x0 + w - 9, y0 + 66], fill=body)
    d.rectangle([x0 + 6, y0 + 62, x0 + 16, y0 + 66], fill=dark)
    d.rectangle([x0 + w - 17, y0 + 62, x0 + w - 7, y0 + 66], fill=dark)
    d.ellipse([cx - 16, y0, cx + 16, y0 + 30], fill=body)
    d.polygon([(cx - 16, y0 + 6), (cx - 22, y0 - 6), (cx - 8, y0 + 2)], fill=dark)
    d.polygon([(cx + 16, y0 + 6), (cx + 22, y0 - 6), (cx + 8, y0 + 2)], fill=dark)
    d.ellipse([cx - 8, y0 + 16, cx + 8, y0 + 30], fill=dark)
    d.rectangle([cx - 7, y0 + 24, cx + 7, y0 + 29], fill=(40, 24, 24))
    for tx in range(cx - 6, cx + 7, 3):
        d.polygon([(tx, y0 + 24), (tx + 1, y0 + 27), (tx + 2, y0 + 24)], fill=(240, 236, 220))
    d.ellipse([cx - 4, y0 + 15, cx + 4, y0 + 20], fill=(30, 20, 20))
    for ex in (cx - 9, cx + 6):
        d.rectangle([ex, y0 + 9, ex + 3, y0 + 12], fill=(230, 200, 60) if not grey else (220, 220, 230))
        d.point((ex + 1, y0 + 10), fill=(20, 20, 20, 255))
    if mangy:
        rnd = random.Random(4)
        for _ in range(16):
            px, py = rnd.randrange(x0 + 4, x0 + w - 4), rnd.randrange(y0 + 24, y0 + 54)
            d.rectangle([px, py, px + 2, py + 1], fill=(170, 130, 110))


def _owl(d, cx, base, body=(200, 180, 140), face=(240, 232, 210), wings_up=False, eyes=2, horned=False, glow=False):
    d.ellipse([cx - 20, base - 56, cx + 20, base - 4], fill=body)
    if wings_up:
        d.polygon([(cx - 18, base - 40), (cx - 46, base - 70), (cx - 40, base - 20)], fill=body)
        d.polygon([(cx + 18, base - 40), (cx + 46, base - 70), (cx + 40, base - 20)], fill=body)
    else:
        d.polygon([(cx - 20, base - 44), (cx - 30, base - 14), (cx - 18, base - 10)], fill=(160, 140, 110))
        d.polygon([(cx + 20, base - 44), (cx + 30, base - 14), (cx + 18, base - 10)], fill=(160, 140, 110))
    for y in range(base - 30, base - 8, 6):
        d.line([(cx - 10, y), (cx + 10, y)], fill=(170, 150, 110))
    d.ellipse([cx - 16, base - 70, cx + 16, base - 42], fill=face)
    if horned:
        d.polygon([(cx - 14, base - 62), (cx - 20, base - 80), (cx - 6, base - 66)], fill=body)
        d.polygon([(cx + 14, base - 62), (cx + 20, base - 80), (cx + 6, base - 66)], fill=body)
    d.polygon([(cx - 2, base - 54), (cx + 2, base - 54), (cx, base - 48)], fill=(80, 60, 40))
    for x in (cx - 9, cx + 4):
        d.rectangle([x, base - 4, x + 4, base], fill=(90, 70, 40))
    positions = [(cx - 7, base - 58), (cx + 7, base - 58)]
    if eyes > 2:
        positions += [(cx - 12, base - 50), (cx + 12, base - 50), (cx - 3, base - 64), (cx + 3, base - 52)][:eyes - 2]
    for (x, y) in positions:
        if glow:
            _glow_eyes(d, x, y, 0, (255, 220, 50), 2)
        else:
            d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(30, 20, 20))
            d.point((x - 1, y - 1), fill=(240, 240, 240, 255))


def _little_man(d, cx, base, h=50, arms_up=True, grey=(176, 182, 190), dark=(110, 116, 128), eyes=True):
    """The Kelly creature: big head, thin body, long arms, pointed ears."""
    hw = 14
    d.ellipse([cx - hw, base - h, cx + hw, base - h + 24], fill=grey)
    d.polygon([(cx - hw, base - h + 10), (cx - hw - 8, base - h - 2), (cx - hw + 4, base - h + 4)], fill=grey)
    d.polygon([(cx + hw, base - h + 10), (cx + hw + 8, base - h - 2), (cx + hw - 4, base - h + 4)], fill=grey)
    d.rectangle([cx - 7, base - h + 22, cx + 7, base - 10], fill=grey)
    d.line([(cx, base - h + 24), (cx, base - 12)], fill=dark)
    for sx in (-1, 1):
        d.rectangle([cx + sx * 4 - 2, base - 12, cx + sx * 4 + 2, base - 2], fill=grey)
        d.rectangle([cx + sx * 6 - 3, base - 3, cx + sx * 6 + 3, base], fill=dark)
        if arms_up:
            d.line([(cx + sx * 7, base - h + 26), (cx + sx * 20, base - h + 10), (cx + sx * 24, base - h - 6)], fill=grey, width=3)
            for f in range(3):
                d.line([(cx + sx * 24, base - h - 6), (cx + sx * (22 + f * 3), base - h - 14 + f * 2)], fill=grey, width=2)
        else:
            d.line([(cx + sx * 7, base - h + 26), (cx + sx * 26, base - h + 22), (cx + sx * 36, base - h + 10)], fill=grey, width=3)
            for f in range(3):
                d.line([(cx + sx * 36, base - h + 10), (cx + sx * (38 + f * 2), base - h + 2 + f * 3)], fill=grey, width=2)
    if eyes:
        _glow_eyes(d, cx - 6, base - h + 11, 12, (255, 230, 60), 3)
    d.line([(cx - 3, base - h + 19), (cx + 3, base - h + 19)], fill=dark)


def _static(im, seed, dark=False):
    rnd = random.Random(seed)
    px = im.load()
    for y in range(FW):
        for x in range(FW):
            if px[x, y][3]:
                v = rnd.choice((20, 60, 120, 200, 240))
                if dark:
                    v = v // 2
                px[x, y] = (v, v, v, 255)
    return im


def _silhouette_person(d, cx, base, h, col):
    d.ellipse([cx - 8, base - h, cx + 8, base - h + 16], fill=col)
    d.rectangle([cx - 12, base - h + 16, cx + 12, base - 24], fill=col)
    d.rectangle([cx - 10, base - 24, cx - 2, base], fill=col)
    d.rectangle([cx + 2, base - 24, cx + 10, base], fill=col)
    d.rectangle([cx - 18, base - h + 18, cx - 12, base - 30], fill=col)
    d.rectangle([cx + 12, base - h + 18, cx + 18, base - 30], fill=col)


def _gull(d, x, y, flap):
    d.ellipse([x, y, x + 20, y + 12], fill=(240, 240, 244))
    d.ellipse([x + 14, y - 4, x + 24, y + 4], fill=(240, 240, 244))
    d.polygon([(x + 23, y), (x + 30, y + 1), (x + 23, y + 3)], fill=(240, 180, 60))
    if flap:
        d.polygon([(x + 4, y + 4), (x - 12, y - 10), (x + 10, y + 1)], fill=(170, 170, 180))
        d.polygon([(x + 14, y + 4), (x + 32, y - 8), (x + 16, y + 1)], fill=(170, 170, 180))
    else:
        d.polygon([(x + 4, y + 6), (x - 12, y + 12), (x + 10, y + 2)], fill=(170, 170, 180))
        d.polygon([(x + 14, y + 6), (x + 32, y + 12), (x + 16, y + 2)], fill=(170, 170, 180))
    d.point((x + 18, y - 1), fill=(20, 20, 20, 255))


def _gun(d, x0, y0, x1, y1):
    d.line([(x0, y0), (x1, y1)], fill=(60, 60, 68), width=3)
    d.line([(x0, y0), (x0 + (x1 - x0) // 3, y0 + (y1 - y0) // 3)], fill=(120, 76, 40), width=4)


PANTS = "Pants 03 - Pants"
OVERALLS = "Pants 05 - Overalls"
BUTTONED = "Shirt 07 - Buttoned Longsleeve Shirt"
LONG = "Shirt 01 - Longsleeve Shirt"
TEE = "Shirt 04 - T-shirt"
BTEE = "Shirt 08 - Buttoned T-shirt"
CARDIGAN = "Sweater 01 - Cardigan"
BOOTS = ("Shoes 02 - Boots", "Black")
HELM = "Characters/Head Accessories/Helm 01 - Bascinet, Open/Silver/"
BRIM = "Characters/Head Accessories/Helm 05 - Kettle Helm/Copper/"


def _foes():
    F = {}

    # --- Point Pleasant
    def stray_dog(f):
        im = _new()
        d = ImageDraw.Draw(im)
        _dog(d, 20, 26 + (2 if f else 0), mangy=True)
        return im
    F["stray_dog"] = stray_dog

    def shotgun_man(f):
        layers = _adult("Tawny", hair="Short 06 - Balding", hair_colour="Gray", shirt=(LONG, "Denim"), pants=(OVERALLS, "Charcoal"), beard=("Facial Hair 01 - Walrus Mustache", "Gray"), shoes=BOOTS)
        im = _person(layers, f)
        d = ImageDraw.Draw(im)
        _gun(d, 24, 66, 72, 46)
        return im
    F["shotgun_man"] = shotgun_man

    def dark_suit(f):
        layers = _adult("Porcelain", hair="Short 02 - Parted", hair_colour="Black", shirt=(LONG, "Black"), over=(CARDIGAN, "Black"), pants=(PANTS, "Black"), shoes=BOOTS)
        im = _person(layers, f)
        d = ImageDraw.Draw(im)
        d.rectangle([30, 16, 66, 22], fill=(20, 16, 20))          # hat brim
        d.rectangle([36, 4, 60, 18], fill=(20, 16, 20))
        d.rectangle([40, 27, 56, 33], fill=(248, 240, 232))       # no eyes: a smooth band
        d.line([(38, 39), (58, 39)], fill=(40, 10, 20), width=2)  # the too-wide smile
        if f:
            d.line([(37, 38), (59, 38)], fill=(40, 10, 20), width=2)
        return _wrong(im)
    F["dark_suit"] = dark_suit

    def wrong_owl(f):
        im = _new()
        d = ImageDraw.Draw(im)
        _owl(d, 48, 94, eyes=6 if f else 5, glow=True)
        return _wrong(im)
    F["wrong_owl"] = wrong_owl

    def igloo_crawler(f):
        im = _new()
        d = ImageDraw.Draw(im)
        grey = (150, 150, 146)
        d.ellipse([10, 46, 86, 90], fill=grey)
        for x in (12, 30, 54, 72):
            d.rectangle([x, 70 + (3 if f and x in (30, 72) else 0), x + 10, 94], fill=(120, 120, 118))
        d.ellipse([28, 28 + (2 if f else 0), 68, 62 + (2 if f else 0)], fill=grey)
        rnd = random.Random(2)
        for _ in range(60):
            x, y = rnd.randrange(12, 84), rnd.randrange(30, 90)
            d.point((x, y), fill=rnd.choice([(200, 200, 196, 255), (100, 100, 98, 255)]))
        _glow_eyes(d, 38, 44 + (2 if f else 0), 16, (255, 240, 120), 2)
        return _wrong(im)
    F["igloo_crawler"] = igloo_crawler

    def static_shade(f):
        im = _new()
        d = ImageDraw.Draw(im)
        _silhouette_person(d, 48, 94, 84, (128, 128, 128))
        return _static(im, 7 + f)
    F["static_shade"] = static_shade

    def mothman(f):
        im = _new()
        d = ImageDraw.Draw(im)
        grey = (84, 86, 96)
        d.polygon([(12, 94), (8, 20), (38, 6), (34, 94)], fill=(60, 62, 72))
        d.polygon([(84, 94), (88, 20), (58, 6), (62, 94)], fill=(60, 62, 72))
        d.rectangle([36, 20, 60, 94], fill=grey)
        d.ellipse([34, 4, 62, 30], fill=grey)
        if f:
            d.polygon([(8, 20), (2, 10), (14, 18)], fill=(60, 62, 72))
            d.polygon([(88, 20), (94, 10), (82, 18), ], fill=(60, 62, 72))
        _glow_eyes(d, 41, 17, 14, (255, 40, 30), 3)
        return _wrong(im)
    F["mothman"] = mothman

    # --- Sandown
    def hut_man(f):
        layers = _adult("Ivory", hair="Short 06 - Balding", hair_colour="Gray", shirt=(LONG, "Teal"), over=(CARDIGAN, "Orange"), pants=(PANTS, "Purple"), shoes=BOOTS)
        im = _person(layers, f)
        d = ImageDraw.Draw(im)
        rnd = random.Random(9)
        px = im.load()
        for y in range(44, 76):
            for x in range(30, 66):
                if px[x, y][3] and (x // 5 + y // 5) % 2:
                    px[x, y] = rnd.choice([(230, 60, 50, 255), (60, 120, 220, 255), (240, 220, 80, 255), (60, 170, 90, 255), (200, 80, 180, 255)])
        d.polygon([(32, 20), (48, -8), (64, 20)], fill=(240, 210, 60))
        d.rectangle([28, 18, 68, 22], fill=(220, 190, 50))
        return _wrong(im)
    F["hut_man"] = hut_man

    def gull_swarm(f):
        im = _new()
        d = ImageDraw.Draw(im)
        _gull(d, 10, 20, f)
        _gull(d, 50, 44, not f)
        _gull(d, 24, 70, f)
        return im
    F["gull_swarm"] = gull_swarm

    def arcade_lads(f):
        a = _adult("Peach", hair="Short 01 - Buzzcut", hair_colour="Blonde", shirt=(LONG, "Cyan"), over=(CARDIGAN, "Cerise"), pants=(PANTS, "Royal"), shoes=("Shoes 01 - Shoes", "White"))
        b = _adult("Tan", hair="Short 04 - Cowlick", hair_colour="Black", shirt=(LONG, "Lemon"), over=(CARDIGAN, "Emerald"), pants=(PANTS, "Purple"), shoes=("Shoes 01 - Shoes", "White"))
        im = _person(a, f, 1.2, -18, 0)
        im = _person(b, (f + 1) % 3, 1.2, 18, 0, im)
        return im
    F["arcade_lads"] = arcade_lads

    # --- Kelly
    def little_man(f):
        im = _new()
        d = ImageDraw.Draw(im)
        _little_man(d, 48, 94, arms_up=True)
        if f:
            _glow_eyes(d, 42, 55, 12, (255, 240, 120), 3)
        return _wrong(im)
    F["little_man"] = little_man

    def floater(f):
        im = _new()
        d = ImageDraw.Draw(im)
        base = 72 if f else 74
        _little_man(d, 48, base, arms_up=False)
        for i in range(3):
            d.ellipse([30 + i * 12, 80 + i * 2, 50 + i * 12, 86 + i * 2], fill=(180, 200, 220, 50))
        return _wrong(im)
    F["floater"] = floater

    def eyeshine(f):
        im = _new()
        d = ImageDraw.Draw(im)
        d.ellipse([22, 20, 74, 94], fill=(16, 14, 22, 120))
        d.ellipse([30, 14, 66, 50], fill=(20, 18, 28, 150))
        _glow_eyes(d, 40, 32 + (1 if f else 0), 16, (255, 236, 90), 3 if not f else 2)
        return im
    F["eyeshine"] = eyeshine

    def owl_wrong_ky(f):
        im = _new()
        d = ImageDraw.Draw(im)
        _owl(d, 48, 94, body=(120, 96, 70), face=(190, 170, 130), wings_up=not f, horned=True, glow=True)
        return _wrong(im)
    F["owl_wrong_ky"] = owl_wrong_ky

    def hound_pack(f):
        im = _new()
        d = ImageDraw.Draw(im)
        _dog(d, 2, 36 + (2 if f else 0), body=(60, 44, 34), dark=(40, 30, 24), w=44)
        _dog(d, 48, 28 + (0 if f else 2), body=(160, 130, 90), dark=(110, 84, 54), w=46)
        return im
    F["hound_pack"] = hound_pack

    def fair_monkey(f):
        im = _new()
        d = ImageDraw.Draw(im)
        brown = (120, 86, 50)
        d.ellipse([36, 20, 60, 42], fill=brown)
        d.ellipse([40, 28, 56, 42], fill=(220, 190, 160))
        d.ellipse([30, 24, 38, 32], fill=brown)
        d.ellipse([58, 24, 66, 32], fill=brown)
        d.rectangle([40, 42, 56, 70], fill=(200, 50, 50))          # the tiny jacket
        d.rectangle([47, 44, 49, 68], fill=(240, 220, 120))
        d.line([(40, 44), (24, 60 + (4 if f else 0))], fill=brown, width=4)
        d.line([(56, 44), (72, 60 - (4 if f else 0))], fill=brown, width=4)
        d.rectangle([40, 70, 46, 92], fill=brown)
        d.rectangle([50, 70, 56, 92], fill=brown)
        d.arc([56, 50, 84, 94], 200, 340, fill=brown, width=3)
        for ex in (44, 51):
            d.rectangle([ex, 31, ex + 2, 33], fill=(30, 20, 20))
        d.line([(44, 38), (52, 38)], fill=(60, 30, 30))
        return im
    F["fair_monkey"] = fair_monkey

    def drunk_local(f):
        layers = _adult("Tawny", hair="Short 06 - Balding", hair_colour="Brown", shirt=(BTEE, "Garnet"), pants=(OVERALLS, "Charcoal"), beard=("Facial Hair 07 - Medium Beard", "Brown"), shoes=BOOTS)
        layers.append((BRIM + "Walk.png", BRIM + "Idle.png"))
        im = _person(layers, f, 1.5, -3 if f else 3, 0)
        d = ImageDraw.Draw(im)
        _gun(d, 26 + (-3 if f else 3), 70, 70 + (-3 if f else 3), 40)
        return im
    F["drunk_local"] = drunk_local

    def mp_patrol(f):
        layers = _adult("Peach", hair="Short 01 - Buzzcut", hair_colour="Brown", shirt=(BUTTONED, "Olivine"), pants=(PANTS, "Olivine"), shoes=BOOTS)
        layers.append((HELM + "Walk.png", HELM + "Idle.png"))
        im = _person(layers, f)
        d = ImageDraw.Draw(im)
        d.rectangle([64, 52, 72, 62], fill=(50, 50, 56))
        d.polygon([(68, 52), (96, 30 + (4 if f else 0)), (96, 62)], fill=(255, 240, 180, 110))
        d.rectangle([40, 0, 56, 4], fill=(240, 240, 240))
        return im
    F["mp_patrol"] = mp_patrol

    def cave_breath(f):
        im = _new()
        d = ImageDraw.Draw(im)
        rnd = random.Random(3 + f)
        for _ in range(26):
            x, y, r = rnd.randrange(4, 80), rnd.randrange(10, 80), rnd.randrange(8, 20)
            d.ellipse([x, y, x + r, y + r], fill=(210, 224, 236, 90))
        d.ellipse([30, 26, 66, 70], fill=(228, 238, 246, 170))
        d.ellipse([38, 40, 44, 48], fill=(90, 110, 130, 200))
        d.ellipse([52, 40, 58, 48], fill=(90, 110, 130, 200))
        d.ellipse([44, 54, 52, 66 + (3 if f else 0)], fill=(90, 110, 130, 200))
        return im
    F["cave_breath"] = cave_breath

    def coyote(f):
        im = _new()
        d = ImageDraw.Draw(im)
        _dog(d, 22, 30 + (2 if f else 0), body=(176, 150, 110), dark=(120, 100, 70), w=52, grey=True)
        d.polygon([(30, 20), (24, 2), (40, 16)], fill=(176, 150, 110))
        d.polygon([(66, 20), (72, 2), (56, 16)], fill=(176, 150, 110))
        return im
    F["coyote"] = coyote

    def the_tall_one(f):
        im = _new()
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, 95, 95], fill=(236, 230, 214))
        d.rectangle([8, 6, 87, 95], fill=(18, 16, 24))
        d.rectangle([46, 6, 50, 95], fill=(236, 230, 214))
        d.rectangle([8, 50, 87, 54], fill=(236, 230, 214))
        _little_man(d, 48, 95, h=96 if not f else 94, arms_up=True, grey=(190, 196, 204), dark=(120, 126, 140))
        d.rectangle([46, 6, 50, 95], fill=(236, 230, 214, 160))
        d.rectangle([8, 50, 87, 54], fill=(236, 230, 214, 160))
        return _wrong(im)
    F["the_tall_one"] = the_tall_one

    def the_hunters(f):
        a = _adult("Peach", hair="Short 01 - Buzzcut", hair_colour="Brown", shirt=(LONG, "Orange"), pants=(PANTS, "Swamp"), beard=("Facial Hair 07 - Medium Beard", "Brown"), shoes=BOOTS)
        b = _adult("Tan", hair="Short 03 - Curly", hair_colour="Black", shirt=(LONG, "Fern"), pants=(PANTS, "Umber"), beard=("Facial Hair 06 - Trimmed Beard", "Black"), shoes=BOOTS)
        im = _person(a, f, 1.2, -18, 0)
        im = _person(b, (f + 2) % 3, 1.2, 18, 0, im)
        d = ImageDraw.Draw(im)
        _gun(d, 8, 70, 40, 36)
        _gun(d, 56, 72, 88, 38)
        d.rectangle([44, 56, 52, 70], fill=(60, 60, 70))
        d.ellipse([42, 48, 54, 60], fill=(255, 240, 170))
        if f:
            d.ellipse([40, 46, 56, 62], fill=(255, 240, 170, 90))
        return im
    F["the_hunters"] = the_hunters

    def roof_walker(f):
        im = _new()
        d = ImageDraw.Draw(im)
        for y in range(0, 60):
            t = y / 60.0
            d.line([(0, y), (95, y)], fill=(int(40 + 160 * t), int(40 + 120 * t), int(80 + 60 * t), 255))
        d.polygon([(0, 95), (0, 70), (48, 52), (95, 70), (95, 95)], fill=(24, 20, 28))
        d.line([(0, 70), (48, 52), (95, 70)], fill=(60, 50, 60))
        _little_man(d, 48, 56, h=48, arms_up=f, grey=(24, 20, 28), dark=(24, 20, 28), eyes=False)
        _glow_eyes(d, 42, 18, 12, (255, 230, 60), 3)
        return _wrong(im)
    F["roof_walker"] = roof_walker

    return F


def build_foes(assets, sheet, adult, outline):
    global _sheet, _adult, _outline
    _sheet, _adult, _outline = sheet, adult, outline
    out = os.path.join(assets, "foes")
    os.makedirs(out, exist_ok=True)
    index = {}
    for name, fn in _foes().items():
        sheet_im = Image.new("RGBA", (FW * 2, FW), (0, 0, 0, 0))
        for f in range(2):
            frame = fn(f)
            if name not in ("eyeshine", "cave_breath", "static_shade"):
                frame = outline(frame, OUT)
            sheet_im.alpha_composite(frame, (f * FW, 0))
        sheet_im.save(os.path.join(out, name + ".png"))
        index[name] = {"w": FW, "h": FW, "frames": 2}
    with open(os.path.join(out, "foes.json"), "w") as f:
        json.dump(index, f, indent=1, sort_keys=True)
    print("foes:", len(index))
