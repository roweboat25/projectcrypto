"""Season 1 additions to the art library: Kelly, Kentucky, August 1994.
Tobacco and karst country drawn over the LPC Revised summer sheets, the
farm's siege props, the courthouse square, the depot and the people of the
Pennyrile. Imported by build_art.py, which merges these tables into its own."""
import random
from PIL import Image, ImageDraw

T = 32
TS = "Terrain/terrain_summer.png"
TRS = "Terrain/trees_summer.png"
PLS = "Terrain/plants_summer.png"
RG = "Terrain/Rocks, Grasslands.png"
F = "Structure/Floor/"
W = "Structure/Walls/"
S = "Objects/Small Items/"

OUT = (28, 20, 24, 255)

# ------------------------------------------------------------------ tiles
# every Kelly tile is drawn or tinted in special_tile_kelly
KELLY_TILES = {name: name for name in (
    "tobacco_field", "tobacco_field2", "tobacco_cut",
    "dry_grass", "dry_grass2", "dry_grass3",
    "red_clay", "red_clay2",
    "limestone", "limestone2",
    "creek_bed", "sink_edge", "sink_pit",
    "cave_floor", "cave_floor2", "cave_wall",
    "railbed", "courthouse_paving", "courthouse_paving2", "motel_lot",
    "porch_boards", "farm_floor",
)}
# tiles the map walker may not cross
SOLID_KELLY = ("sink_pit", "cave_wall")


def _speckle(im, seed, n, colours):
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    for _ in range(n):
        d.point((rnd.randrange(T), rnd.randrange(T)), fill=rnd.choice(colours) + (255,))
    return im


def _mul(im, rf, gf, bf, add=0):
    px = im.load()
    for y in range(T):
        for x in range(T):
            r, g, b, a = px[x, y]
            px[x, y] = (min(255, int(r * rf + add)), min(255, int(g * gf + add)), min(255, int(b * bf + add)), a)
    return im


def _leaf(d, x, y, col, dark):
    """A broad tobacco leaf pair seen from above."""
    d.ellipse([x - 4, y - 2, x + 1, y + 2], fill=col)
    d.ellipse([x, y - 2, x + 5, y + 2], fill=col)
    d.ellipse([x - 2, y - 4, x + 3, y], fill=col)
    d.point((x, y), fill=dark)


def special_tile_kelly(name, base_tile):
    rnd = random.Random(hash(name) & 0xffff)
    if name.startswith("tobacco_field"):
        im = base_tile(TS, 4 if name == "tobacco_field" else 3, 3).convert("RGBA")
        _mul(im, 0.9, 0.84, 0.8)
        d = ImageDraw.Draw(im)
        off = 0 if name == "tobacco_field" else 8
        for y in (6, 22):
            for x in range(4 + off // 2, T, 12):
                _leaf(d, (x + off) % T, y, (58, 112, 46), (34, 70, 30))
                d.point(((x + off) % T + 1, y + 1), fill=(96, 150, 70, 255))
        return im
    if name == "tobacco_cut":
        im = base_tile(TS, 4, 3).convert("RGBA")
        _mul(im, 0.92, 0.86, 0.8)
        d = ImageDraw.Draw(im)
        for y in (6, 22):
            for x in range(3, T, 8):
                d.line([(x, y - 3), (x, y + 2)], fill=(120, 100, 60, 255))
                d.point((x + 1, y + 2), fill=(70, 56, 36, 255))
        return im
    if name.startswith("dry_grass"):
        col = {"dry_grass": 3, "dry_grass2": 4, "dry_grass3": 5}[name]
        return _mul(base_tile(TS, col, 1).convert("RGBA"), 1.18, 1.02, 0.6, 14)
    if name.startswith("red_clay"):
        return _mul(base_tile(TS, 4 if name == "red_clay" else 5, 3).convert("RGBA"), 1.25, 0.72, 0.55)
    if name.startswith("limestone"):
        im = Image.new("RGBA", (T, T), (196, 194, 180, 255) if name == "limestone" else (190, 188, 174, 255))
        _speckle(im, 11 if name == "limestone" else 12, 50, [(214, 212, 198), (170, 168, 154), (150, 150, 140), (224, 222, 210)])
        d = ImageDraw.Draw(im)
        d.line([(0, 20), (10, 24), (18, 23)] if name == "limestone" else [(14, 2), (20, 9), (31, 12)], fill=(160, 158, 146, 255))
        return im
    if name == "creek_bed":
        im = Image.new("RGBA", (T, T), (176, 160, 130, 255))
        _speckle(im, 21, 40, [(150, 136, 110), (196, 182, 150), (130, 120, 100)])
        d = ImageDraw.Draw(im)
        for _ in range(7):
            x, y, r = rnd.randrange(2, 28), rnd.randrange(2, 28), rnd.randrange(2, 4)
            d.ellipse([x, y, x + r + 2, y + r], fill=(150, 146, 136, 255))
            d.point((x + 1, y), fill=(190, 186, 176, 255))
        return im
    if name == "sink_edge":
        im = base_tile(TS, 3, 1).convert("RGBA")
        px = im.load()
        for y in range(T):
            for x in range(T):
                # the ground gives way toward the bottom right, with a crumbling lip
                depth = (x + y * 2) / 3.0 - 16 + rnd.randrange(-2, 3)
                if depth > 8:
                    px[x, y] = (8, 8, 12, 255)
                elif depth > 3:
                    px[x, y] = (72, 58, 42, 255) if depth > 5 else (104, 84, 56, 255)
        return im
    if name == "sink_pit":
        im = Image.new("RGBA", (T, T), (8, 8, 12, 255))
        return _speckle(im, 31, 6, [(16, 16, 22), (12, 12, 18)])
    if name.startswith("cave_floor"):
        im = Image.new("RGBA", (T, T), (76, 74, 72, 255) if name == "cave_floor" else (70, 70, 68, 255))
        return _speckle(im, 41 if name == "cave_floor" else 42, 60, [(92, 90, 86), (60, 58, 56), (104, 100, 94), (50, 50, 50)])
    if name == "cave_wall":
        im = base_tile(W + "Jagged Stone Walls.png", 0, 7).convert("RGBA")
        return _mul(im, 0.5, 0.5, 0.48)
    if name == "railbed":
        im = Image.new("RGBA", (T, T), (128, 120, 110, 255))
        _speckle(im, 51, 70, [(150, 142, 130), (100, 94, 88), (170, 164, 150), (90, 84, 80)])
        d = ImageDraw.Draw(im)
        for x in range(1, T, 8):
            d.rectangle([x, 4, x + 4, 27], fill=(84, 60, 40, 255))
        for y in (8, 22):
            d.line([(0, y), (31, y)], fill=(60, 60, 66, 255))
            d.line([(0, y + 1), (31, y + 1)], fill=(150, 150, 158, 255))
        return im
    if name.startswith("courthouse_paving"):
        im = Image.new("RGBA", (T, T), (208, 200, 184, 255) if name == "courthouse_paving" else (202, 196, 180, 255))
        _speckle(im, 61 if name == "courthouse_paving" else 62, 20, [(190, 184, 170), (220, 214, 200)])
        d = ImageDraw.Draw(im)
        d.line([(0, 15), (31, 15)], fill=(172, 164, 150, 255))
        d.line([(15 if name == "courthouse_paving" else 7, 0), (15 if name == "courthouse_paving" else 7, 15)], fill=(172, 164, 150, 255))
        d.line([(23, 16), (23, 31)], fill=(172, 164, 150, 255))
        return im
    if name == "motel_lot":
        im = base_tile(F + "Gritty Dirt.png", 1, 1).convert("RGBA")
        return _mul(im, 0.6, 0.6, 0.62, 10)
    if name == "porch_boards":
        im = base_tile(F + "Wood Floor A.png", 1, 3).convert("RGBA")
        return _mul(im, 1.05, 1.02, 0.96, 16)
    if name == "farm_floor":
        im = base_tile(F + "Wood Floor A.png", 0, 3).convert("RGBA")
        _mul(im, 0.96, 0.9, 0.82)
        d = ImageDraw.Draw(im)
        d.line([(4, 9), (12, 9)], fill=(60, 44, 30, 255))
        d.line([(20, 25), (29, 25)], fill=(60, 44, 30, 255))
        return im
    raise KeyError(name)


# ------------------------------------------------------------------ LPC crops
KELLY_PROPS = {
    "oak_summer": (TRS, (128, 256, 96, 128), 1),
    "oak_summer2": (TRS, (320, 256, 96, 160), 1),
    "cedar": (TRS, (416, 352, 96, 160), 1),
    "dry_creek_rocks": (RG, (128, 192, 64, 64), 0),
    "limestone_rock": (RG, (64, 192, 64, 64), 1),
    "honeysuckle": (PLS, (128, 64, 64, 64), 0),
}


# ------------------------------------------------------------------ drawn props
def _new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def _boards(d, box, col, dark, step=6, vertical=True):
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=col)
    if vertical:
        for x in range(x0 + step, x1, step):
            d.line([(x, y0), (x, y1)], fill=dark)
    else:
        for y in range(y0 + step, y1, step):
            d.line([(x0, y), (x1, y)], fill=dark)


def _gable(d, x0, x1, y_eave, peak, col, dark):
    d.polygon([(x0, y_eave), ((x0 + x1) // 2, peak), (x1, y_eave)], fill=col)
    d.line([(x0, y_eave), ((x0 + x1) // 2, peak)], fill=dark)
    d.line([((x0 + x1) // 2, peak), (x1, y_eave)], fill=dark)


def _smoke(d, x, y, seed=1):
    rnd = random.Random(seed)
    for i in range(5):
        r = 3 + i
        cx = x + rnd.randrange(-3, 4) + i * 2
        cy = y - i * 7
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(210, 206, 200, 150 - i * 20))


def _eyes(d, x, y, gap=6, col=(255, 230, 60), r=1):
    for ex in (x, x + gap):
        d.ellipse([ex - r - 2, y - r - 2, ex + r + 2, y + r + 2], fill=col + (70,))
        d.ellipse([ex - r - 1, y - r - 1, ex + r + 1, y + r + 1], fill=col + (140,))
        d.ellipse([ex - r, y - r, ex + r, y + r], fill=col + (255,))


def kelly_custom_props(outline, crop):
    """Kelly's farm, karst and courthouse square, drawn in the house style."""
    P = {}
    BARN = (54, 44, 40)
    BARN_D = (36, 28, 26)
    TIN = (140, 134, 126)
    TIN_D = (96, 92, 88)
    WOOD = (140, 100, 60)
    WOOD_D = (96, 66, 38)
    PALE = (228, 222, 206)

    # tobacco barns: tall dark board barns with hinged vent slats, one of them curing (smoke)
    for name, smoke in (("tobacco_barn", False), ("tobacco_barn_smoke", True)):
        im = _new(128, 136)
        d = ImageDraw.Draw(im)
        _boards(d, (4, 48, 123, 134), BARN, BARN_D, 6)
        for x in range(10, 120, 18):
            d.rectangle([x, 56, x + 2, 126], fill=(72, 60, 52))      # open vent slats
        d.rectangle([52, 86, 75, 134], fill=(26, 20, 20))
        d.line([(52, 86), (75, 134)], fill=(72, 60, 52))
        d.line([(75, 86), (52, 134)], fill=(72, 60, 52))
        _gable(d, 0, 127, 50, 8, TIN, TIN_D)
        d.polygon([(0, 50), (127, 50), (123, 56), (4, 56)], fill=TIN_D)
        for x in range(16, 112, 16):
            d.line([(x, 50), (64, 8)], fill=TIN_D)
        if smoke:
            d.rectangle([92, 20, 99, 40], fill=(60, 54, 52))
            _smoke(d, 96, 14, 2)
            d.rectangle([10, 60, 118, 66], fill=(90, 70, 50))        # a warm band of curing leaf glow at the slats
        P[name] = (outline(im), 3)

    # hay bale (round, 1x1)
    im = _new(32, 30)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 29, 28], fill=(214, 184, 100))
    d.ellipse([8, 8, 23, 22], fill=(190, 158, 80))
    d.ellipse([13, 13, 18, 17], fill=(150, 120, 60))
    d.arc([4, 4, 27, 26], 200, 340, fill=(240, 214, 130))
    P["hay_bale"] = (outline(im), 1)

    # corn crib: slatted wire-sided crib on posts, 2x2
    im = _new(64, 72)
    d = ImageDraw.Draw(im)
    for x in (6, 54):
        d.rectangle([x, 56, x + 3, 70], fill=WOOD_D)
    d.rectangle([4, 20, 59, 58], fill=(200, 164, 70))
    for y in range(22, 58, 5):
        d.line([(4, y), (59, y)], fill=(110, 90, 50))
    for x in range(8, 58, 10):
        d.line([(x, 20), (x, 58)], fill=WOOD_D)
    d.polygon([(0, 22), (32, 4), (63, 22)], fill=TIN)
    d.line([(0, 22), (32, 4), (63, 22)], fill=TIN_D)
    P["corn_crib"] = (outline(im), 2)

    # smokehouse: a 2x2 log hut with a drifting smoke wisp
    im = _new(64, 92)
    d = ImageDraw.Draw(im)
    _boards(d, (4, 40, 59, 90), (112, 84, 54), (70, 50, 32), 7, vertical=False)
    for x in (4, 59):
        for y in range(44, 90, 7):
            d.rectangle([x - 1, y - 2, x + 1, y + 1], fill=(90, 64, 40))
    d.rectangle([24, 62, 39, 90], fill=(50, 38, 30))
    d.rectangle([26, 64, 37, 88], fill=(40, 30, 24))
    d.polygon([(0, 42), (32, 20), (63, 42)], fill=(80, 74, 70))
    d.line([(0, 42), (32, 20), (63, 42)], fill=(50, 46, 44))
    d.rectangle([40, 24, 46, 38], fill=(60, 54, 52))
    _smoke(d, 44, 18, 3)
    P["smokehouse"] = (outline(im), 2)

    # chicken house: a low shed with a ramp, 2x1
    im = _new(64, 52)
    d = ImageDraw.Draw(im)
    _boards(d, (4, 18, 59, 44), (196, 190, 170), (150, 144, 126), 6)
    d.rectangle([40, 28, 52, 44], fill=(40, 30, 24))
    d.polygon([(40, 44), (52, 44), (60, 50), (30, 50)], fill=WOOD)
    d.rectangle([10, 24, 20, 32], fill=(60, 60, 70))
    d.polygon([(0, 20), (63, 20), (63, 12), (0, 8)], fill=TIN)
    d.line([(0, 8), (63, 12)], fill=TIN_D)
    P["chicken_house"] = (outline(im), 1)

    # porch post with pale pellet pocks, a porch swing, a rocking chair, a screen door
    im = _new(16, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([5, 0, 10, 62], fill=PALE)
    d.line([(10, 0), (10, 62)], fill=(190, 184, 168))
    for (x, y) in ((6, 18), (8, 24), (7, 31), (9, 40), (6, 47)):
        d.point((x, y), fill=(250, 248, 240))
        d.point((x, y + 1), fill=(140, 130, 110))
    P["porch_post"] = (outline(im), 1)
    im = _new(64, 48)
    d = ImageDraw.Draw(im)
    for x in (10, 52):
        d.line([(x, 0), (x, 22)], fill=(90, 90, 100))
    d.rectangle([4, 20, 59, 28], fill=(190, 184, 168))
    d.rectangle([4, 28, 59, 38], fill=(220, 214, 200))
    for x in range(8, 60, 7):
        d.line([(x, 21), (x, 27)], fill=(160, 154, 140))
    d.rectangle([2, 36, 61, 40], fill=(170, 164, 150))
    P["porch_swing"] = (outline(im), 1)
    im = _new(32, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 2, 23, 22], fill=WOOD)
    for y in range(5, 20, 4):
        d.line([(9, y), (22, y)], fill=WOOD_D)
    d.rectangle([6, 22, 25, 28], fill=(160, 120, 70))
    for x in (7, 23):
        d.line([(x, 28), (x, 36)], fill=WOOD_D)
    d.arc([2, 30, 29, 42], 180, 360, fill=WOOD_D, width=2)
    P["rocking_chair"] = (outline(im), 1)
    im = _new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 0, 27, 47], fill=(150, 150, 140))
    d.rectangle([7, 3, 24, 44], fill=(80, 90, 90))
    for y in range(3, 44, 3):
        d.line([(7, y), (24, y)], fill=(96, 106, 104))
    d.rectangle([4, 22, 27, 25], fill=(150, 150, 140))
    d.rectangle([20, 26, 22, 30], fill=(40, 40, 40))
    P["screen_door"] = (outline(im), 1)

    # the shotgun leaning on a wall, a kerosene lamp, a hung lantern
    im = _new(16, 48)
    d = ImageDraw.Draw(im)
    d.line([(4, 44), (11, 4)], fill=(60, 60, 68), width=2)
    d.polygon([(2, 46), (8, 24), (12, 26), (7, 46)], fill=(110, 70, 36))
    d.line([(9, 26), (12, 10)], fill=(90, 90, 100))
    P["shotgun"] = (outline(im), 0)
    im = _new(16, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 26, 12, 30], fill=(150, 130, 60))
    d.rectangle([5, 20, 10, 26], fill=(180, 160, 80))
    d.ellipse([2, 6, 13, 22], fill=(240, 230, 170, 220))
    d.rectangle([6, 10, 9, 18], fill=(255, 220, 110))
    d.rectangle([5, 2, 10, 7], fill=(150, 130, 60))
    P["kerosene_lamp"] = (outline(im), 0)
    im = _new(16, 40)
    d = ImageDraw.Draw(im)
    d.line([(8, 0), (8, 8)], fill=(80, 80, 90))
    d.arc([3, 6, 12, 14], 180, 360, fill=(80, 80, 90))
    d.rectangle([3, 14, 12, 18], fill=(70, 70, 80))
    d.rectangle([3, 18, 12, 32], fill=(250, 230, 150, 230))
    d.rectangle([6, 22, 9, 29], fill=(255, 200, 90))
    d.rectangle([2, 32, 13, 35], fill=(70, 70, 80))
    P["lantern_hung"] = (outline(im), 0)

    # windows: boarded (siege preparation) and open-lit; a wall decal of pellet scars; handprints on a door
    im = _new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 29, 29], fill=(40, 48, 60))
    d.rectangle([2, 2, 29, 29], outline=PALE, width=2)
    for y, tilt in ((6, 2), (15, -2), (24, 1)):
        d.polygon([(0, y + tilt), (31, y - tilt), (31, y - tilt + 6), (0, y + tilt + 6)], fill=(150, 110, 64))
        d.line([(0, y + tilt + 6), (31, y - tilt + 6)], fill=WOOD_D)
        for x in (4, 26):
            d.point((x, y + 3), fill=(40, 40, 46))
    P["boarded_window"] = (outline(im), 0)
    im = _new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 29, 29], fill=(255, 226, 140))
    d.rectangle([2, 2, 29, 29], outline=PALE, width=2)
    d.line([(15, 2), (15, 29)], fill=PALE)
    d.line([(2, 15), (29, 15)], fill=PALE)
    d.rectangle([4, 4, 13, 13], fill=(255, 240, 180))
    P["window_open"] = (im, 0)
    im = _new(32, 24)
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    for _ in range(14):
        x, y = rnd.randrange(2, 30), rnd.randrange(2, 22)
        d.point((x, y), fill=(250, 246, 236, 255))
        d.point((x + 1, y + 1), fill=(120, 110, 96, 255))
    P["pellet_scars"] = (im, 0)
    im = _new(24, 24)
    d = ImageDraw.Draw(im)
    for (x, y) in ((4, 8), (13, 10)):
        d.ellipse([x, y + 3, x + 6, y + 10], fill=(210, 206, 196, 190))
        for i in range(4):
            d.line([(x + 1 + i * 2, y + 4), (x + 1 + i * 2, y - 1 + (i % 2))], fill=(210, 206, 196, 190))
    P["handprints"] = (im, 0)

    # sinkholes: dark pits with a crumbling grass rim
    for name, size in (("sinkhole", 96), ("sinkhole_small", 64)):
        im = _new(size, size)
        d = ImageDraw.Draw(im)
        d.ellipse([2, 6, size - 3, size - 3], fill=(104, 84, 56))
        d.ellipse([6, 10, size - 7, size - 6], fill=(60, 48, 36))
        d.ellipse([10, 14, size - 11, size - 10], fill=(8, 8, 12))
        rnd = random.Random(size)
        for _ in range(size // 4):
            a = rnd.random() * 6.283
            import math
            r = size / 2 - 3
            x, y = size / 2 + math.cos(a) * r, size / 2 + 2 + math.sin(a) * (r - 2)
            d.line([(x, y), (x + rnd.randrange(-2, 3), y - rnd.randrange(2, 5))], fill=(90, 140, 60, 255))
        P[name] = (im, size // 32)

    # cave mouth: a limestone arch, black inside, cold air drawn as a pale wisp
    im = _new(128, 112)
    d = ImageDraw.Draw(im)
    d.polygon([(0, 110), (0, 50), (20, 20), (60, 4), (100, 10), (127, 40), (127, 110)], fill=(190, 186, 170))
    for (x, y, w, h) in ((8, 50, 30, 20), (50, 14, 40, 18), (96, 40, 26, 22), (30, 80, 20, 12), (100, 76, 22, 14)):
        d.ellipse([x, y, x + w, y + h], fill=(206, 202, 186))
        d.arc([x, y, x + w, y + h], 20, 160, fill=(160, 156, 142))
    d.polygon([(36, 110), (36, 60), (50, 40), (76, 36), (92, 58), (92, 110)], fill=(10, 8, 12))
    d.polygon([(36, 110), (36, 68), (44, 60), (44, 110)], fill=(30, 28, 32))
    for i in range(3):
        d.ellipse([50 + i * 10, 92 - i * 10, 70 + i * 12, 100 - i * 8], fill=(220, 230, 240, 60))
    P["cave_mouth"] = (outline(im), 3)

    # owl tree: the LPC dead oak with a hollow and a pale owl face in it
    im = crop(TRS, 0, 256, 96, 128)
    d = ImageDraw.Draw(im)
    d.ellipse([40, 70, 56, 92], fill=(26, 20, 18))
    d.ellipse([44, 76, 52, 86], fill=(190, 170, 130))
    d.point((46, 79), fill=(20, 20, 20, 255))
    d.point((50, 79), fill=(20, 20, 20, 255))
    P["owl_tree"] = (im, 1)

    # kudzu: a draped mass of vine over whatever it has eaten
    im = _new(96, 80)
    d = ImageDraw.Draw(im)
    rnd = random.Random(9)
    for _ in range(40):
        x, y, r = rnd.randrange(0, 86), rnd.randrange(10, 70), rnd.randrange(6, 14)
        d.ellipse([x, y, x + r, y + r], fill=rnd.choice([(52, 110, 44), (70, 134, 54), (40, 90, 36)]))
    for x in range(6, 92, 12):
        d.line([(x, 70), (x + 2, 78)], fill=(40, 90, 36), width=2)
    P["kudzu"] = (outline(im), 1)

    # a single tobacco plant and a stack of tobacco sticks
    im = _new(32, 40)
    d = ImageDraw.Draw(im)
    d.line([(16, 38), (16, 8)], fill=(80, 120, 50), width=2)
    for (x, y, w) in ((4, 30, 13), (15, 26, 14), (3, 20, 14), (15, 16, 13), (7, 10, 10), (15, 8, 10)):
        d.ellipse([x, y - 4, x + w, y + 4], fill=(70, 128, 52))
        d.line([(x + 1, y), (x + w - 1, y)], fill=(100, 160, 70))
    d.ellipse([12, 2, 20, 8], fill=(230, 190, 210))
    P["tobacco_plant"] = (outline(im), 0)
    im = _new(64, 40)
    d = ImageDraw.Draw(im)
    for i in range(6):
        y = 34 - i * 4
        d.rectangle([4 + (i % 2) * 2, y, 58 - (i % 2) * 2, y + 3], fill=(170, 140, 90) if i % 2 else (150, 120, 76))
    for x in (6, 56):
        d.rectangle([x, 8, x + 3, 38], fill=WOOD_D)
    P["tobacco_sticks"] = (outline(im), 1)

    # grain silo: 2x5 ribbed steel
    im = _new(64, 168)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 24, 55, 166], fill=(186, 190, 196))
    d.rectangle([8, 24, 18, 166], fill=(206, 210, 216))
    d.rectangle([46, 24, 55, 166], fill=(140, 144, 152))
    for y in range(32, 166, 12):
        d.line([(8, y), (55, y)], fill=(120, 124, 132))
    d.ellipse([6, 8, 57, 40], fill=(150, 154, 160))
    d.rectangle([28, 0, 35, 12], fill=(120, 124, 132))
    d.rectangle([56, 60, 60, 166], fill=(90, 94, 100))
    for y in range(64, 166, 8):
        d.line([(56, y), (60, y)], fill=(170, 174, 180))
    P["grain_silo"] = (outline(im), 2)

    # railroad crossing crossbuck, a depot bench, a freight car
    im = _new(32, 80)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 20, 17, 78], fill=(230, 230, 230))
    d.polygon([(2, 8), (6, 4), (30, 28), (26, 32)], fill=(240, 240, 240))
    d.polygon([(26, 4), (30, 8), (6, 32), (2, 28)], fill=(240, 240, 240))
    d.line([(6, 8), (26, 28)], fill=(30, 30, 30))
    d.line([(26, 8), (6, 28)], fill=(30, 30, 30))
    d.ellipse([10, 36, 21, 47], fill=(200, 40, 40))
    P["railroad_crossing_sign"] = (outline(im), 1)
    im = _new(64, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 61, 10], fill=(60, 90, 60))
    d.rectangle([2, 12, 61, 18], fill=(80, 110, 80))
    for x in (6, 54):
        d.rectangle([x, 18, x + 3, 30], fill=(40, 40, 46))
    P["depot_bench"] = (outline(im), 1)
    im = _new(192, 72)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 58, 191, 60], fill=(60, 60, 66))
    d.rectangle([4, 10, 187, 56], fill=(120, 48, 40))
    for x in range(8, 188, 10):
        d.line([(x, 10), (x, 56)], fill=(96, 36, 30))
    d.rectangle([84, 16, 107, 56], fill=(80, 30, 26))
    d.rectangle([84, 16, 107, 20], fill=(60, 60, 66))
    d.rectangle([12, 16, 60, 24], fill=(220, 214, 200))
    d.rectangle([0, 4, 191, 12], fill=(90, 36, 30))
    for x in (16, 40, 140, 164):
        d.ellipse([x, 60, x + 12, 71], fill=(40, 40, 48))
    d.rectangle([0, 60, 191, 63], fill=(60, 60, 66))
    P["rail_car"] = (outline(im), 2)

    # checkers table (two chairs' worth of square), a rural mailbox, the Greyhound sign
    im = _new(32, 36)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 6, 29, 28], fill=WOOD)
    for y in range(8, 26, 4):
        for x in range(4, 28, 4):
            if ((x + y) // 4) % 2:
                d.rectangle([x, y, x + 3, y + 3], fill=(200, 60, 50))
            else:
                d.rectangle([x, y, x + 3, y + 3], fill=(30, 30, 34))
    d.rectangle([4, 28, 7, 34], fill=WOOD_D)
    d.rectangle([24, 28, 27, 34], fill=WOOD_D)
    P["checkers_table"] = (outline(im), 1)
    im = _new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 22, 17, 46], fill=(120, 90, 60))
    d.rounded_rectangle([4, 6, 27, 22], 5, fill=(150, 150, 150))
    d.rectangle([4, 14, 27, 22], fill=(120, 120, 120))
    d.rectangle([26, 2, 29, 12], fill=(200, 40, 40))
    d.rectangle([8, 16, 20, 18], fill=(230, 230, 230))
    P["mailbox_rural"] = (outline(im), 1)
    im = _new(64, 72)
    d = ImageDraw.Draw(im)
    d.rectangle([28, 30, 35, 70], fill=(90, 94, 100))
    d.rectangle([2, 2, 61, 30], fill=(30, 50, 120))
    d.rectangle([4, 4, 59, 28], fill=(240, 240, 240))
    d.rectangle([4, 4, 59, 12], fill=(30, 50, 120))
    d.polygon([(10, 22), (18, 17), (30, 15), (44, 14), (52, 18), (44, 20), (30, 19), (18, 21)], fill=(30, 50, 120))
    d.rectangle([12, 15, 36, 17], fill=(240, 240, 240))
    P["greyhound_sign"] = (outline(im), 1)

    # courthouse lawn cannon, Edgar Cayce's grave, a smoking bbq pit
    im = _new(64, 40)
    d = ImageDraw.Draw(im)
    d.ellipse([34, 20, 56, 39], fill=(60, 56, 50))
    d.ellipse([40, 26, 50, 34], fill=(90, 84, 76))
    d.polygon([(4, 14), (50, 24), (50, 30), (4, 22)], fill=(50, 56, 56))
    d.ellipse([2, 13, 10, 22], fill=(30, 36, 36))
    d.rectangle([30, 14, 44, 24], fill=(70, 74, 74))
    P["courthouse_lawn_cannon"] = (outline(im), 1)
    im = _new(64, 48)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([20, 4, 43, 36], 6, fill=(180, 176, 164))
    d.rectangle([24, 12, 39, 14], fill=(110, 106, 96))
    d.rectangle([26, 18, 37, 19], fill=(110, 106, 96))
    d.rectangle([26, 23, 37, 24], fill=(110, 106, 96))
    d.rectangle([16, 36, 47, 40], fill=(150, 146, 136))
    d.rectangle([2, 38, 14, 44], fill=(170, 166, 154))
    d.rectangle([49, 38, 61, 44], fill=(170, 166, 154))
    d.rectangle([28, 42, 35, 46], fill=(220, 90, 90))
    P["cayce_grave"] = (outline(im), 1)
    im = _new(64, 72)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 44, 57, 70], fill=(150, 90, 60))
    for y in range(48, 70, 6):
        d.line([(6, y), (57, y)], fill=(110, 64, 40))
    d.rectangle([2, 38, 61, 46], fill=(60, 60, 66))
    d.rectangle([8, 36, 55, 40], fill=(240, 130, 40))
    d.rectangle([12, 37, 51, 39], fill=(255, 200, 80))
    _smoke(d, 30, 32, 4)
    P["bbq_pit"] = (outline(im), 1)

    # pawn sign (three balls), a gun rack, feed sacks
    im = _new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 26, 17, 46], fill=(40, 40, 46))
    d.rectangle([2, 8, 29, 11], fill=(40, 40, 46))
    for x in (4, 13, 22):
        d.ellipse([x, 12, x + 7, 19], fill=(240, 190, 50))
    d.ellipse([12, 0, 19, 7], fill=(240, 190, 50))
    P["pawn_sign"] = (outline(im), 0)
    im = _new(64, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 61, 38], fill=(110, 80, 50))
    d.rectangle([5, 5, 58, 35], fill=(80, 56, 36))
    for i, y in enumerate((10, 19, 28)):
        d.line([(8, y + 2), (56, y - 1)], fill=(60, 60, 70), width=2)
        d.polygon([(8, y), (24, y + 1), (24, y + 5), (8, y + 5)], fill=(130, 80, 40))
    P["gun_rack"] = (outline(im), 1)
    im = _new(64, 40)
    d = ImageDraw.Draw(im)
    for (x, y, c) in ((4, 14, (200, 170, 120)), (30, 16, (190, 150, 100)), (16, 2, (210, 180, 130))):
        d.rounded_rectangle([x, y, x + 28, y + 22], 5, fill=c)
        d.rectangle([x + 6, y + 8, x + 22, y + 14], fill=(150, 60, 50))
        d.line([(x + 2, y + 3), (x + 26, y + 3)], fill=(140, 110, 70))
    P["feed_sacks"] = (outline(im), 1)

    # the fair tent, the monkey cage, the fort's chain fence with its sign
    im = _new(128, 100)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 56, 121, 98], fill=(230, 60, 50))
    for x in range(6, 122, 16):
        d.rectangle([x, 56, x + 7, 98], fill=(240, 236, 220))
    d.polygon([(0, 58), (64, 8), (127, 58)], fill=(200, 40, 40))
    for x in range(16, 120, 24):
        d.line([(x, 58), (64, 8)], fill=(240, 236, 220))
    d.rectangle([62, 0, 66, 10], fill=(90, 70, 40))
    d.polygon([(66, 0), (80, 4), (66, 8)], fill=(244, 222, 120))
    d.rectangle([50, 66, 77, 98], fill=(40, 24, 30))
    P["fair_tent"] = (outline(im), 3)
    im = _new(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 12, 59, 60], fill=(60, 56, 56))
    d.rectangle([8, 16, 55, 56], fill=(40, 36, 36))
    for x in range(8, 58, 6):
        d.line([(x, 12), (x, 60)], fill=(150, 150, 160))
    d.rectangle([4, 10, 59, 14], fill=(160, 160, 170))
    for x in (6, 54):
        d.rectangle([x, 56, x + 4, 63], fill=(40, 40, 48))
    d.ellipse([24, 28, 40, 44], fill=(130, 90, 50))
    d.ellipse([28, 32, 36, 40], fill=(220, 190, 160))
    d.rectangle([6, 2, 57, 10], fill=(200, 50, 50))
    d.rectangle([12, 5, 51, 7], fill=(240, 220, 120))
    P["monkey_cage"] = (outline(im), 1)
    im = _new(96, 56)
    d = ImageDraw.Draw(im)
    for x in (2, 48, 93):
        d.rectangle([x, 4, x + 2, 54], fill=(150, 150, 160))
    d.rectangle([0, 6, 95, 8], fill=(150, 150, 160))
    for x in range(0, 96, 6):
        d.line([(x, 8), (x + 6, 54)], fill=(170, 170, 180))
        d.line([(x + 6, 8), (x, 54)], fill=(170, 170, 180))
    d.rectangle([30, 14, 65, 36], fill=(240, 240, 240))
    d.rectangle([33, 17, 62, 21], fill=(200, 40, 40))
    d.rectangle([36, 25, 59, 27], fill=(40, 40, 46))
    d.rectangle([36, 30, 59, 32], fill=(40, 40, 46))
    P["fort_fence"] = (outline(im), 1)

    # electronics and files: a scanner radio, a big tape deck, a hospital file cart, a card catalog
    im = _new(32, 24)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 6, 29, 22], fill=(40, 40, 46))
    d.rectangle([5, 9, 18, 13], fill=(240, 120, 40))
    for x in (21, 25):
        d.ellipse([x, 10, x + 3, 13], fill=(120, 120, 130))
    d.rectangle([5, 16, 26, 18], fill=(80, 80, 90))
    d.line([(26, 6), (30, 0)], fill=(120, 120, 130))
    P["scanner_radio"] = (outline(im), 0)
    im = _new(64, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 61, 30], fill=(140, 136, 130))
    for x in (10, 36):
        d.ellipse([x, 8, x + 18, 26], fill=(60, 60, 66))
        d.ellipse([x + 6, 14, x + 12, 20], fill=(180, 180, 190))
    d.rectangle([28, 6, 35, 12], fill=(220, 60, 60))
    d.rectangle([4, 26, 59, 28], fill=(90, 90, 96))
    P["tape_deck_big"] = (outline(im), 1)
    im = _new(64, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 6, 59, 46], fill=(190, 192, 200))
    for y in (10, 26):
        for x in range(8, 56, 6):
            d.rectangle([x, y, x + 4, y + 12], fill=(200, 180, 120) if x % 12 else (220, 200, 150))
            d.line([(x, y), (x + 4, y)], fill=(170, 140, 90))
    d.rectangle([4, 22, 59, 24], fill=(150, 152, 160))
    for x in (8, 50):
        d.ellipse([x, 46, x + 6, 54], fill=(40, 40, 48))
    P["hospital_file_cart"] = (outline(im), 1)
    im = _new(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 61, 62], fill=(110, 76, 44))
    for y in range(6, 60, 10):
        for x in range(6, 60, 14):
            d.rectangle([x, y, x + 10, y + 7], fill=(140, 100, 58))
            d.rectangle([x + 3, y + 2, x + 7, y + 3], fill=(240, 230, 200))
            d.point((x + 5, y + 5), fill=(220, 190, 90, 255))
    P["library_card_catalog"] = (outline(im), 1)

    # the siege kit: a net bundle, a rope coil, a can of lamp oil, a salt sack
    im = _new(32, 24)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 4, 29, 22], fill=(120, 110, 80))
    for x in range(4, 30, 4):
        d.line([(x, 6), (x + 6, 20)], fill=(70, 64, 46))
        d.line([(x + 6, 6), (x, 20)], fill=(70, 64, 46))
    d.rectangle([12, 2, 19, 8], fill=(90, 80, 60))
    P["net_bundle"] = (outline(im), 0)
    im = _new(32, 24)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 4, 29, 22], fill=(200, 170, 110))
    d.ellipse([6, 7, 25, 19], fill=(170, 140, 90))
    d.ellipse([11, 10, 20, 16], fill=(90, 70, 46))
    d.arc([2, 4, 29, 22], 0, 360, fill=(150, 120, 70))
    P["rope_coil"] = (outline(im), 0)
    im = _new(16, 28)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 8, 13, 26], fill=(200, 50, 40))
    d.rectangle([5, 2, 10, 8], fill=(150, 150, 150))
    d.rectangle([4, 12, 11, 18], fill=(240, 230, 200))
    d.line([(10, 4), (14, 10)], fill=(150, 150, 150))
    P["lamp_oil_can"] = (outline(im), 0)
    im = _new(32, 28)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([3, 6, 28, 26], 5, fill=(236, 232, 220))
    d.rectangle([6, 12, 25, 18], fill=(60, 110, 180))
    d.rectangle([8, 14, 23, 16], fill=(240, 240, 240))
    d.rectangle([10, 2, 21, 7], fill=(200, 196, 186))
    P["salt_sack"] = (outline(im), 0)

    # trail signs: eyeshine in the dark, a burned circle, a spinning compass, burned trash, owl pellets, raccoon prints
    im = _new(16, 8)
    d = ImageDraw.Draw(im)
    _eyes(d, 4, 4, 7)
    P["eyeshine"] = (im, 0)
    im = _new(96, 96)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 8, 91, 88], fill=(50, 42, 36, 180))
    d.ellipse([12, 16, 83, 80], fill=(30, 26, 24, 230))
    d.ellipse([30, 32, 65, 64], fill=(70, 60, 50, 200))
    rnd = random.Random(13)
    for _ in range(30):
        x, y = rnd.randrange(14, 82), rnd.randrange(18, 78)
        d.point((x, y), fill=(90, 80, 70, 255))
    P["burned_circle"] = (im, 0)
    im = _new(16, 16)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 14, 14], fill=(200, 190, 150))
    d.ellipse([3, 3, 12, 12], fill=(240, 236, 220))
    d.line([(4, 11), (11, 4)], fill=(220, 40, 40))
    d.line([(4, 4), (11, 11)], fill=(220, 40, 40, 120))
    d.line([(7, 2), (7, 13)], fill=(220, 40, 40, 80))
    P["compass_spinning"] = (outline(im), 0)
    im = _new(48, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 14, 45, 30], fill=(40, 36, 34))
    for (x, y, c) in ((8, 12, (90, 80, 70)), (20, 6, (140, 50, 40)), (30, 10, (60, 60, 66)), (14, 18, (190, 170, 120))):
        d.rectangle([x, y, x + 10, y + 8], fill=c)
    d.line([(20, 8), (30, 8)], fill=(30, 26, 24))
    P["trash_pile_burned"] = (outline(im), 0)
    im = _new(24, 16)
    d = ImageDraw.Draw(im)
    for (x, y) in ((2, 6), (12, 3), (8, 10)):
        d.ellipse([x, y, x + 8, y + 5], fill=(110, 100, 90))
        d.point((x + 3, y + 2), fill=(230, 226, 216, 255))
    P["owl_pellets"] = (im, 0)
    im = _new(32, 32)
    d = ImageDraw.Draw(im)
    for (x, y) in ((6, 6), (18, 14), (8, 22)):
        d.ellipse([x, y + 3, x + 6, y + 8], fill=(90, 70, 50, 200))
        for i in range(5):
            d.line([(x + i * 1.5, y + 3), (x + i * 1.5, y)], fill=(90, 70, 50, 200))
    P["raccoon_prints"] = (im, 0)

    # vehicles: a 1950s pickup, an MP jeep, a tractor, a rusted car in the weeds
    def car(w, body, light, cab, rounded=8):
        im = _new(w, 40)
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([3, 12, w - 4, 34], rounded, fill=body)
        d.rounded_rectangle([cab[0], 4, cab[1], 22], 5, fill=light)
        d.rectangle([cab[0] + 3, 7, cab[1] - 3, 18], fill=(150, 176, 194))
        d.rectangle([5, 24, w - 6, 30], fill=light)
        for x in (10, w - 16):
            d.ellipse([x, 30, x + 10, 39], fill=(30, 28, 34))
            d.ellipse([x + 3, 33, x + 7, 36], fill=(120, 120, 130))
        d.rectangle([4, 16, 7, 19], fill=(255, 230, 160))
        d.rectangle([w - 8, 16, w - 5, 19], fill=(255, 230, 160))
        return im, d
    im, d = car(64, (70, 110, 90), (110, 150, 130), (10, 34), 10)
    d.rectangle([38, 8, 60, 22], fill=(50, 80, 66))
    for y in (11, 15, 19):
        d.line([(40, y), (58, y)], fill=(80, 110, 96))
    P["pickup_old"] = (outline(im), 1)
    im, d = car(64, (80, 90, 56), (110, 120, 76), (14, 50), 3)
    d.rectangle([6, 14, 57, 32], fill=(80, 90, 56))
    d.rectangle([18, 8, 46, 12], fill=(220, 220, 220))
    d.rectangle([24, 9, 40, 11], fill=(80, 90, 56))
    d.rectangle([17, 7, 47, 17], outline=(60, 66, 40))
    d.rectangle([19, 9, 45, 16], fill=(150, 176, 194))
    d.rectangle([4, 20, 59, 23], fill=(240, 240, 240))
    d.rectangle([26, 20, 37, 23], fill=(80, 90, 56))
    P["jeep_mp"] = (outline(im), 1)
    im = _new(64, 56)
    d = ImageDraw.Draw(im)
    d.ellipse([34, 18, 62, 50], fill=(30, 28, 34))
    d.ellipse([42, 26, 54, 42], fill=(120, 120, 130))
    d.ellipse([2, 32, 20, 52], fill=(30, 28, 34))
    d.ellipse([7, 38, 15, 46], fill=(120, 120, 130))
    d.rectangle([8, 22, 50, 38], fill=(200, 50, 40))
    d.rectangle([30, 10, 44, 24], fill=(220, 70, 50))
    d.rectangle([24, 2, 28, 18], fill=(50, 50, 56))
    d.rectangle([38, 4, 50, 8], fill=(40, 40, 46))
    d.ellipse([32, 22, 40, 30], fill=(60, 60, 66))
    P["tractor"] = (outline(im), 1)
    im, d = car(64, (120, 80, 50), (150, 110, 70), (14, 50), 6)
    d.rectangle([17, 7, 47, 18], fill=(90, 100, 100))
    rnd = random.Random(5)
    for _ in range(30):
        x, y = rnd.randrange(4, 60), rnd.randrange(12, 34)
        d.point((x, y), fill=(150, 70, 30, 255))
    for x in range(4, 62, 10):
        d.line([(x, 38), (x + 2, 28)], fill=(90, 140, 60), width=2)
    P["rusted_car"] = (outline(im), 1)

    # water tower is in art_extra already; a lamp-lit cupola prop for the courthouse roof and a platform roof for the depot
    im = _new(64, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([16, 24, 47, 54], fill=(236, 232, 220))
    for x in (20, 30, 40):
        d.rectangle([x, 30, x + 5, 48], fill=(60, 70, 90))
    d.polygon([(10, 26), (32, 4), (54, 26)], fill=(60, 64, 80))
    d.rectangle([30, 0, 33, 6], fill=(230, 200, 100))
    P["cupola"] = (outline(im), 0)
    im = _new(192, 48)
    d = ImageDraw.Draw(im)
    d.polygon([(0, 2), (191, 2), (191, 20), (0, 20)], fill=(110, 60, 50))
    for x in range(0, 192, 12):
        d.line([(x, 2), (x, 20)], fill=(80, 44, 36))
    d.rectangle([0, 20, 191, 24], fill=(60, 36, 30))
    for x in (8, 94, 180):
        d.rectangle([x, 24, x + 3, 46], fill=(120, 100, 70))
    P["platform_roof"] = (outline(im), 0)

    return P


# ------------------------------------------------------------------ facades
KELLY_FACADES = {
    "farmhouse_ky": dict(w=10, h=3, siding="white", shade=0, roof="grey", roof_h=2, door="green", door_x=4, windows=[1, 2, 7, 8], tall=True, neon=""),
    "courthouse": dict(w=12, h=4, siding="rust", shade=1, roof="slate", roof_h=2, door="dark", door_x=5, windows=[1, 2, 3, 8, 9, 10], doors=[5, 6], tall=True),
    "police_station_ky": dict(w=7, h=2, siding="grey", shade=1, roof="navy", roof_h=2, door="blue", door_x=3, windows=[1, 5]),
    "newspaper_ky": dict(w=6, h=2, siding="brown", shade=1, roof="grey", roof_h=2, door="dark", door_x=2, windows=[0, 4, 5]),
    "library_ky": dict(w=8, h=3, siding="rust", shade=2, roof="slate", roof_h=2, door="brown", door_x=3, windows=[1, 6], tall=True),
    "hospital_records": dict(w=6, h=2, siding="rust", shade=3, roof="grey", roof_h=1, door="grey", door_x=2, windows=[4]),
    "bbq_joint": dict(w=5, h=2, siding="brown", shade=3, roof="rust", roof_h=1, door="red", door_x=2, windows=[0, 4], neon="neon_red"),
    "pawn_shop_ky": dict(w=5, h=2, siding="grey", shade=3, roof="brown", roof_h=1, door="dark", door_x=2, windows=[0, 4], neon="neon_amber"),
    "motor_court": dict(w=12, h=2, siding="peach", shade=1, roof="brown", roof_h=2, door="white", door_x=1, windows=[3, 6, 10], doors=[1, 5, 8], neon="neon_amber"),
    "motor_court_office": dict(w=5, h=2, siding="peach", shade=0, roof="brown", roof_h=1, door="white", door_x=2, windows=[0, 4], neon="neon_red"),
    "truck_stop": dict(w=9, h=2, siding="white", shade=1, roof="rust", roof_h=2, door="red", door_x=4, windows=[1, 2, 6, 7], neon="neon_red"),
    "fairgrounds_office": dict(w=5, h=2, siding="yellow", shade=1, roof="grey", roof_h=1, door="white", door_x=2, windows=[0, 4]),
    "feed_store": dict(w=8, h=2, siding="green", shade=2, roof="grey", roof_h=2, door="brown", door_x=3, windows=[1, 6]),
    "general_store_ky": dict(w=7, h=2, siding="white", shade=1, roof="brown", roof_h=2, door="brown", door_x=3, windows=[1, 5], neon="neon_red"),
    "baptist_church": dict(w=6, h=4, siding="white", shade=0, roof="grey", roof_h=2, door="white", door_x=2, windows=[0, 5], tall=True, steeple=True),
    "neighbour_house": dict(w=8, h=3, siding="white", shade=1, roof="grey", roof_h=2, door="brown", door_x=3, windows=[1, 6], tall=True),
    "neighbour_house2": dict(w=8, h=3, siding="yellow", shade=0, roof="slate", roof_h=2, door="green", door_x=3, windows=[1, 6], tall=True),
    "depot": dict(w=10, h=2, siding="red", shade=2, roof="grey", roof_h=2, door="dark", door_x=4, windows=[1, 2, 7, 8]),
    "hunting_cabin": dict(w=5, h=2, siding="brown", shade=3, roof="brown", roof_h=1, door="dark", door_x=2, windows=[0, 4]),
    "cave_entrance_hut": dict(w=4, h=2, siding="grey", shade=2, roof="grey", roof_h=1, door="brown", door_x=1, windows=[3]),
}


# ------------------------------------------------------------------ people
TEE = "Shirt 04 - T-shirt"
POLO = "Shirt 09 - Polo"
BTEE = "Shirt 08 - Buttoned T-shirt"
SHORTS = "Shorts 01 - Shorts"
SHOES = ("Shoes 01 - Shoes", "Black")
BOOTS = ("Shoes 02 - Boots", "Black")
OVERALLS = "Pants 05 - Overalls"
PANTS = "Pants 03 - Pants"
HELM = "Characters/Head Accessories/Helm 01 - Bascinet, Open/"
BRIM = "Characters/Head Accessories/Helm 05 - Kettle Helm/"


# the farm kid is dressed by cell band like the Point Pleasant kid, and gets a hair cap
KELLY_TINTS = {"farm_kid": [(38, 52, (70, 110, 170)), (52, 61, (90, 70, 50))]}
KELLY_KID_HAIR = {"farm_kid": (120, 80, 40)}


def _hat(layers, base):
    layers.append((base + "Walk.png", base + "Idle.png"))
    return layers


def kelly_characters(adult, child, LONG, BUTTONED, CARDIGAN):
    return {
        # the farm
        "lacy_cousin": adult("Tawny", head="Head 03 - Elderly", hair="Short 06 - Balding", hair_colour="White", shirt=(BTEE, "Linen"), pants=(OVERALLS, "Denim"), shoes=BOOTS),
        "farm_kid": child("Honey"),
        "tobacco_hand": adult("Brown", hair="Short 01 - Buzzcut", hair_colour="Black", shirt=(TEE, "Olivine"), pants=(PANTS, "Denim"), shoes=BOOTS),
        "tobacco_hand2": adult("Peach", hair="Short 04 - Cowlick", hair_colour="Blonde", shirt=(TEE, "Red"), pants=(OVERALLS, "Charcoal"), shoes=BOOTS),
        "neighbour_woman": adult("Peach", head="Head 01 - Feminine", fem=True, hair="Medium 02 - Curly", hair_colour="Ash Brown", shirt=(TEE, "Lavender"), pants=(PANTS, "Denim"), shoes=SHOES),
        "neighbour_man": adult("Honey", hair="Short 06 - Balding", hair_colour="Brown", shirt=(BTEE, "Sky"), pants=(PANTS, "Beige"), beard=("Facial Hair 02 - Chevron Mustache", "Brown"), shoes=SHOES),
        # the square
        "desk_sergeant": adult("Tan", hair="Short 01 - Buzzcut", hair_colour="Gray", shirt=(BUTTONED, "Cornflower"), pants=(PANTS, "Navy"), beard=("Facial Hair 02 - Chevron Mustache", "Gray"), shoes=BOOTS),
        "deputy_ky": adult("Bronze", hair="Short 07 - Flat Top", hair_colour="Black", shirt=(BUTTONED, "Cornflower"), pants=(PANTS, "Navy"), shoes=BOOTS),
        "ledger_editor": adult("Porcelain", head="Head 01 - Feminine", fem=True, hair="Medium 07 - Bob, Side Part", hair_colour="Gray", shirt=(BUTTONED, "Ivory"), pants=(PANTS, "Charcoal"), glasses="Brass", shoes=SHOES),
        "librarian_ky": adult("Brown", head="Head 01 - Feminine", fem=True, hair="Medium 09 - Twists", hair_colour="Black", shirt=(POLO, "Mint"), pants=(PANTS, "Chocolate"), glasses="Steel", shoes=SHOES),
        "records_clerk": adult("Peach", hair="Short 02 - Parted", hair_colour="Chestnut", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Dove"), pants=(PANTS, "Charcoal"), glasses="Iron", shoes=SHOES),
        "bbq_man": adult("Brown", hair="Short 05 - Natural", hair_colour="Charcoal", shirt=(TEE, "White"), over=("Accessory 01 - Suspenders", "Black"), pants=(PANTS, "Charcoal"), beard=("Facial Hair 06 - Trimmed Beard", "Charcoal"), shoes=BOOTS),
        "pawn_man": adult("Tawny", hair="Short 06 - Balding", hair_colour="Gray", shirt=(BUTTONED, "Beige"), over=("Accessory 01 - Suspenders", "Leather"), pants=(PANTS, "Black"), beard=("Facial Hair 05 - Horseshoe Mustache", "Gray"), shoes=SHOES),
        "old_man_checkers": adult("Peach", head="Head 03 - Elderly", hair="Short 06 - Balding", hair_colour="White", shirt=(BTEE, "Sky"), over=("Accessory 01 - Suspenders", "Navy"), pants=(PANTS, "Beige"), shoes=SHOES),
        "old_man_checkers2": adult("Brown", head="Head 03 - Elderly", hair="Short 05 - Natural", hair_colour="White", shirt=(BTEE, "Mustard"), pants=(PANTS, "Chocolate"), beard=("Facial Hair 01 - Walrus Mustache", "White"), shoes=SHOES),
        "baptist_preacher": adult("Ivory", hair="Short 02 - Parted", hair_colour="Gray", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Black"), pants=(PANTS, "Black"), shoes=SHOES),
        "cemetery_keeper": adult("Tan", head="Head 03 - Elderly", hair="Short 03 - Curly", hair_colour="Gray", shirt=(LONG, "Forest"), pants=(OVERALLS, "Umber"), shoes=BOOTS),
        # the road and the motor court
        "motel_owner": adult("Honey", head="Head 01 - Feminine", fem=True, hair="Medium 04 - Bangs & Bun", hair_colour="Chestnut", shirt=(POLO, "Coral"), pants=(PANTS, "Beige"), shoes=SHOES),
        "truck_stop_waitress": adult("Peach", head="Head 01 - Feminine", fem=True, hair="Medium 08 - Bob, Bangs", hair_colour="Orange", shirt=(TEE, "Pink"), pants=(PANTS, "Black"), shoes=SHOES),
        "trucker": adult("Tawny", hair="Short 01 - Buzzcut", hair_colour="Brown", shirt=(TEE, "Navy"), pants=(PANTS, "Denim"), beard=("Facial Hair 07 - Medium Beard", "Brown"), shoes=BOOTS),
        "fair_manager": adult("Bronze", hair="Short 02 - Parted", hair_colour="Black", shirt=(BUTTONED, "Lemon"), pants=(PANTS, "Chocolate"), beard=("Facial Hair 03 - Handlebar Mustache", "Black"), shoes=SHOES),
        "feed_clerk": adult("Peach", hair="Short 04 - Cowlick", hair_colour="Brown", shirt=(BTEE, "Apple"), pants=(OVERALLS, "Denim"), shoes=BOOTS),
        "store_keeper_ky": adult("Honey", head="Head 03 - Elderly", hair="Short 02 - Parted", hair_colour="Gray", shirt=(BUTTONED, "Ivory"), over=("Accessory 01 - Suspenders", "Leather"), pants=(PANTS, "Umber"), glasses="Brass", shoes=SHOES),
        "depot_agent": adult("Porcelain", head="Head 03 - Elderly", hair="Short 06 - Balding", hair_colour="White", shirt=(BUTTONED, "Sky"), over=(CARDIGAN, "Navy"), pants=(PANTS, "Navy"), glasses="Steel", shoes=SHOES),
        "retired_mp": adult("Ivory", head="Head 03 - Elderly", hair="Short 01 - Buzzcut", hair_colour="White", shirt=(BUTTONED, "Olivine"), pants=(PANTS, "Umber"), shoes=BOOTS),
        # the woods and the cave
        "hunter_ky": adult("Peach", hair="Short 01 - Buzzcut", hair_colour="Brown", shirt=(LONG, "Orange"), pants=(PANTS, "Swamp"), beard=("Facial Hair 07 - Medium Beard", "Brown"), shoes=BOOTS),
        "hunter_ky2": adult("Tan", hair="Short 03 - Curly", hair_colour="Black", shirt=(LONG, "Fern"), pants=(PANTS, "Umber"), beard=("Facial Hair 06 - Trimmed Beard", "Black"), shoes=BOOTS),
        "cave_guide": adult("Brown", head="Head 01 - Feminine", fem=True, hair="Medium 01 - Page", hair_colour="Charcoal", hair_behind=True, shirt=(POLO, "Tan"), pants=(PANTS, "Umber"), shoes=BOOTS),
        # the 1955 echoes
        "mp_patrol": _hat(adult("Peach", hair="Short 01 - Buzzcut", hair_colour="Brown", shirt=(BUTTONED, "Olivine"), pants=(PANTS, "Olivine"), shoes=BOOTS), HELM + "Silver/"),
        "drunk_local": _hat(adult("Tawny", hair="Short 06 - Balding", hair_colour="Brown", shirt=(BTEE, "Garnet"), pants=(OVERALLS, "Charcoal"), beard=("Facial Hair 07 - Medium Beard", "Brown"), shoes=BOOTS), BRIM + "Copper/"),
    }
