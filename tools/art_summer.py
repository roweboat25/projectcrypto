"""Season 1 additions to the art library: Sandown, Isle of Wight, late May.
Summer ground and plants from the LPC Revised summer sheets, seaside things
drawn in code, and the island's people. Imported by build_art.py."""
import random
from PIL import Image, ImageDraw

T = 32
TS = "Terrain/terrain_summer.png"
TRS = "Terrain/trees_summer.png"
PLS = "Terrain/plants_summer.png"
CS = "Terrain/cliff_summer.png"

# ------------------------------------------------------------------ tiles
# (sheet, col, row) or a name special_tile_summer draws
SUMMER_TILES = {
    "grass": (TS, 3, 1),
    "grass2": (TS, 4, 1),
    "grass3": (TS, 5, 1),
    "grass_tuft": (TS, 3, 2),
    "grass_tuft2": (TS, 4, 2),
    "earth": (TS, 4, 3),
    "earth2": (TS, 3, 3),
    "earth3": (TS, 5, 3),
    "sand": (TS, 4, 6),
    "sand2": (TS, 3, 6),
    "sand3": (TS, 5, 6),
    "sea": (TS, 12, 17),
    "sea2": (TS, 13, 17),
    "sea3": (TS, 14, 17),
    "sea_top": (TS, 12, 11),      # grass bank above water (brook, lake)
    "sea_top2": (TS, 13, 11),
    "sea_top3": (TS, 14, 11),
    "beach_top": (TS, 1, 20),     # sand above water (the tide line)
    "shingle": "shingle",
    "shingle2": "shingle2",
    "chalk": "chalk",
    "chalk2": "chalk2",
    "fairway": "fairway",
    "fairway2": "fairway2",
    "pier_deck": "pier_deck",
    "pier_deck2": "pier_deck2",
    "promenade": "promenade",
    "promenade2": "promenade2",
    "sky": "sky",
    "sky2": "sky2",
    "cloud": "cloud",
    "sea_deep": "sea_deep",
    "sea_deep2": "sea_deep2",
    "wet_sand": "wet_sand",
    "wet_sand2": "wet_sand2",
    "lino": "lino",
    "lino2": "lino2",
    "stage_boards": "stage_boards",
}


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


def special_tile_summer(name, base_tile):
    if name.startswith("shingle"):
        im = Image.new("RGBA", (T, T), (150, 140, 126, 255) if name == "shingle" else (144, 136, 124, 255))
        return _speckle(im, 3 if name == "shingle" else 5, 70, [(176, 166, 150), (120, 112, 104), (190, 184, 170), (132, 120, 108), (104, 96, 90)])
    if name.startswith("chalk"):
        im = Image.new("RGBA", (T, T), (226, 226, 218, 255) if name == "chalk" else (218, 218, 210, 255))
        return _speckle(im, 8 if name == "chalk" else 9, 30, [(200, 200, 192), (240, 240, 236), (180, 184, 176)])
    if name.startswith("fairway"):
        return _mul(base_tile(TS, 3 if name == "fairway" else 4, 1).convert("RGBA"), 0.95, 1.08, 0.8, 12)
    if name.startswith("pier_deck"):
        im = Image.new("RGBA", (T, T), (128, 112, 92, 255) if name == "pier_deck" else (122, 108, 90, 255))
        d = ImageDraw.Draw(im)
        for y in range(0, T, 8):
            d.line([(0, y), (T - 1, y)], fill=(78, 66, 54, 255))
            d.line([(0, y + 1), (T - 1, y + 1)], fill=(150, 134, 110, 255))
        d.line([(10 if name == "pier_deck" else 22, 0), (10 if name == "pier_deck" else 22, T - 1)], fill=(78, 66, 54, 255))
        return im
    if name.startswith("promenade"):
        im = Image.new("RGBA", (T, T), (206, 190, 176, 255) if name == "promenade" else (200, 186, 172, 255))
        d = ImageDraw.Draw(im)
        d.line([(0, 15), (31, 15)], fill=(178, 162, 150, 255))
        d.line([(15, 0), (15, 31)], fill=(178, 162, 150, 255))
        return im
    if name.startswith("sky"):
        im = Image.new("RGBA", (T, T), (120, 170, 220, 255) if name == "sky" else (116, 166, 216, 255))
        return im
    if name == "cloud":
        im = Image.new("RGBA", (T, T), (120, 170, 220, 255))
        d = ImageDraw.Draw(im)
        d.ellipse([2, 10, 20, 26], fill=(236, 242, 250, 255))
        d.ellipse([12, 6, 30, 24], fill=(236, 242, 250, 255))
        d.ellipse([8, 14, 26, 28], fill=(236, 242, 250, 255))
        return im
    if name.startswith("sea_deep"):
        return _mul(base_tile(TS, 12 if name == "sea_deep" else 13, 17).convert("RGBA"), 0.7, 0.8, 0.95)
    if name.startswith("wet_sand"):
        return _mul(base_tile(TS, 4 if name == "wet_sand" else 3, 6).convert("RGBA"), 0.82, 0.8, 0.78)
    if name.startswith("lino"):
        im = Image.new("RGBA", (T, T), (190, 176, 140, 255) if name == "lino" else (182, 170, 136, 255))
        d = ImageDraw.Draw(im)
        for x in range(0, T, 8):
            for y in range(0, T, 8):
                if (x + y) % 16 == 0:
                    d.rectangle([x, y, x + 7, y + 7], fill=(170, 150, 120, 255))
        return im
    if name == "stage_boards":
        im = Image.new("RGBA", (T, T), (70, 56, 48, 255))
        d = ImageDraw.Draw(im)
        for y in range(0, T, 8):
            d.line([(0, y), (T - 1, y)], fill=(48, 38, 32, 255))
        return im
    raise KeyError(name)


# ------------------------------------------------------------------ LPC crops
# name: (sheet, (x, y, w, h), solid rows)
SUMMER_PROPS = {
    "tree_summer": (TRS, (128, 0, 96, 128), 1),
    "tree_summer2": (TRS, (320, 0, 96, 160), 1),
    "tree_tall_summer": (TRS, (416, 32, 96, 160), 1),
    "tree_round": (TRS, (224, 32, 96, 96), 1),
    "bush_big": (TRS, (320, 160, 96, 96), 1),
    "pine_summer": (TRS, (128, 384, 96, 128), 1),
    "bush": (PLS, (0, 0, 32, 32), 1),
    "bush2": (PLS, (32, 0, 32, 32), 1),
    "bush_dark": (PLS, (64, 0, 32, 32), 1),
    "bush_dark2": (PLS, (96, 0, 32, 32), 1),
    "fern": (PLS, (128, 64, 64, 64), 0),
    "tuft": (PLS, (256, 0, 32, 64), 0),
    "tuft2": (PLS, (288, 0, 32, 64), 0),
    "reeds": (PLS, (384, 0, 32, 64), 0),
    "reeds2": (PLS, (416, 0, 32, 64), 0),
    "lily": (PLS, (384, 64, 32, 32), 0),
    "flowers_small": (PLS, (448, 0, 32, 32), 0),
    "flowers_small2": (PLS, (480, 0, 32, 32), 0),
    "tunnel_mouth": (CS, (192, 288, 96, 96), 2),
}


# ------------------------------------------------------------------ drawn props
def summer_custom_props(outline, crop):
    """Seaside and holiday-camp things LPC has no sheet for, plus the vehicles of the trip."""
    P = {}

    def new(w, h):
        return Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # chalk cliff faces: the LPC cliff lightened to Culver's white
    for name, rect, solid in (("chalk_cliff", (0, 64, 128, 64), 2), ("chalk_cliff_small", (0, 32, 64, 96), 2), ("chalk_cliff_end", (96, 64, 32, 64), 2)):
        im = crop(CS, *rect)
        px = im.load()
        for y in range(im.size[1]):
            for x in range(im.size[0]):
                r, g, b, a = px[x, y]
                lum = (0.3 * r + 0.59 * g + 0.11 * b)
                v = min(255, int(lum * 0.9 + 110))
                px[x, y] = (v, v, min(255, v - 4), a)
        P[name] = (im, solid)

    # deckchairs: striped canvas on a wooden frame, two colours
    for name, stripe in (("deckchair", (230, 70, 60)), ("deckchair_blue", (50, 90, 170)), ("deckchair_green", (50, 140, 80))):
        im = new(32, 36)
        d = ImageDraw.Draw(im)
        d.line([(4, 34), (12, 8)], fill=(120, 90, 50), width=2)
        d.line([(27, 34), (19, 8)], fill=(120, 90, 50), width=2)
        d.polygon([(8, 10), (24, 10), (26, 30), (6, 30)], fill=stripe)
        for y in range(12, 30, 4):
            d.line([(7, y), (25, y)], fill=(240, 236, 220), width=2)
        d.line([(2, 34), (30, 34)], fill=(120, 90, 50), width=2)
        P[name] = (outline(im), 1)

    # beach huts: a little gabled shed with a coloured door
    for name, body, door in (("beach_hut", (240, 236, 220), (60, 120, 200)), ("beach_hut_pink", (238, 190, 200), (200, 60, 90)),
                             ("beach_hut_yellow", (244, 222, 120), (60, 140, 90))):
        im = new(64, 64)
        d = ImageDraw.Draw(im)
        d.rectangle([4, 20, 59, 62], fill=body)
        d.polygon([(0, 22), (32, 2), (63, 22)], fill=(110, 80, 60))
        d.rectangle([24, 30, 39, 62], fill=door)
        d.rectangle([30, 46, 32, 49], fill=(240, 220, 120))
        for x in range(8, 60, 12):
            d.line([(x, 24), (x, 60)], fill=(200, 196, 180))
        d.rectangle([44, 32, 54, 42], fill=(170, 200, 220))
        P[name] = (outline(im), 2)

    # bunting: a string of triangle flags, walk-under
    im = new(96, 24)
    d = ImageDraw.Draw(im)
    d.line([(0, 4), (48, 10), (95, 4)], fill=(60, 50, 40))
    cols = [(230, 70, 60), (60, 120, 200), (244, 222, 120), (50, 160, 90), (240, 240, 240)]
    for i, x in enumerate(range(4, 96, 12)):
        y = 4 + int(6 * (1 - abs(x - 48) / 48))
        d.polygon([(x, y), (x + 8, y), (x + 4, y + 10)], fill=cols[i % 5])
    P["bunting"] = (im, 0)

    # bandstand: an octagonal roof on iron pillars
    im = new(128, 112)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 86, 121, 110], fill=(170, 160, 150))
    d.rectangle([6, 84, 121, 88], fill=(200, 192, 180))
    for x in (14, 44, 82, 112):
        d.rectangle([x, 30, x + 3, 86], fill=(50, 90, 70))
    d.line([(12, 60), (116, 60)], fill=(50, 90, 70), width=2)
    d.polygon([(0, 34), (64, 0), (127, 34)], fill=(60, 110, 80))
    d.polygon([(0, 34), (127, 34), (120, 40), (8, 40)], fill=(40, 80, 60))
    d.rectangle([60, 0, 67, 8], fill=(220, 200, 120))
    P["bandstand"] = (outline(im), 2)

    # Punch and Judy booth: striped canvas tower with a stage opening
    im = new(64, 96)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 10, 55, 94], fill=(230, 60, 50))
    for x in range(8, 56, 12):
        d.rectangle([x, 10, x + 5, 94], fill=(240, 236, 220))
    d.polygon([(4, 12), (32, 0), (60, 12)], fill=(200, 40, 40))
    d.rectangle([16, 22, 47, 44], fill=(30, 20, 30))
    d.rectangle([14, 20, 49, 24], fill=(240, 220, 120))
    d.ellipse([24, 28, 32, 36], fill=(240, 200, 170))
    d.ellipse([34, 30, 42, 38], fill=(240, 200, 170))
    P["punch_judy"] = (outline(im), 1)

    # arcade machines: a cabinet with a lit screen, and the penny falls
    for name, body, glow in (("arcade_machine", (60, 60, 90), (90, 220, 120)), ("arcade_machine_red", (120, 40, 50), (240, 200, 80))):
        im = new(32, 52)
        d = ImageDraw.Draw(im)
        d.rectangle([4, 4, 27, 50], fill=body)
        d.rectangle([7, 8, 24, 24], fill=glow)
        d.rectangle([9, 11, 22, 13], fill=(20, 20, 30))
        d.rectangle([6, 28, 25, 34], fill=(30, 30, 40))
        d.ellipse([10, 29, 14, 33], fill=(240, 60, 60))
        d.ellipse([17, 29, 21, 33], fill=(60, 120, 240))
        P[name] = (outline(im), 1)
    im = new(64, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 10, 61, 46], fill=(160, 120, 60))
    d.rectangle([6, 2, 57, 22], fill=(220, 230, 240))
    d.rectangle([8, 24, 55, 36], fill=(200, 180, 120))
    for x in range(10, 56, 6):
        d.ellipse([x, 26, x + 4, 30], fill=(190, 140, 60))
        d.ellipse([x + 2, 31, x + 6, 35], fill=(210, 160, 70))
    d.rectangle([4, 38, 59, 44], fill=(90, 60, 30))
    P["penny_falls"] = (outline(im), 1)

    # mechanical fortune teller: a glass case with a turbaned figure
    im = new(32, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 2, 29, 62], fill=(120, 40, 60))
    d.rectangle([5, 6, 26, 40], fill=(90, 70, 120))
    d.ellipse([10, 12, 21, 23], fill=(240, 200, 170))
    d.rectangle([9, 8, 22, 14], fill=(220, 60, 60))
    d.rectangle([8, 24, 23, 38], fill=(60, 40, 90))
    d.ellipse([12, 30, 19, 37], fill=(240, 240, 250))
    d.rectangle([5, 44, 26, 50], fill=(230, 200, 100))
    d.rectangle([12, 54, 19, 58], fill=(30, 30, 30))
    P["fortune_teller"] = (outline(im), 1)

    # pier railings and a pier lamp
    im = new(96, 32)
    d = ImageDraw.Draw(im)
    for x in range(2, 96, 16):
        d.rectangle([x, 4, x + 2, 30], fill=(230, 232, 236))
    d.rectangle([0, 6, 95, 8], fill=(230, 232, 236))
    d.rectangle([0, 18, 95, 19], fill=(200, 204, 210))
    P["pier_rail"] = (outline(im), 1)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 4, 16, 30], fill=(230, 232, 236))
    d.rectangle([14, 6, 16, 8], fill=(200, 204, 210))
    for y in (6, 18):
        d.rectangle([14, y, 16, y + 1], fill=(200, 204, 210))
    P["pier_rail_post"] = (outline(im), 1)
    im = new(32, 96)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 20, 17, 92], fill=(70, 90, 110))
    d.rectangle([10, 88, 21, 94], fill=(70, 90, 110))
    d.ellipse([8, 4, 23, 22], fill=(255, 240, 190))
    d.rectangle([12, 0, 19, 6], fill=(70, 90, 110))
    P["pier_lamp"] = (outline(im), 1)

    # ice cream cart, a windbreak, a buoy, a stack of deckchairs, a dinghy
    im = new(64, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 22, 57, 46], fill=(240, 236, 220))
    d.rectangle([6, 22, 57, 28], fill=(230, 70, 60))
    for x in range(6, 58, 8):
        d.rectangle([x, 22, x + 3, 28], fill=(240, 236, 220))
    d.rectangle([28, 4, 31, 22], fill=(120, 90, 50))
    d.rectangle([8, 0, 55, 8], fill=(230, 70, 60))
    d.ellipse([12, 44, 24, 55], fill=(40, 40, 50))
    d.ellipse([40, 44, 52, 55], fill=(40, 40, 50))
    d.rectangle([12, 30, 24, 40], fill=(120, 200, 230))
    d.rectangle([30, 32, 52, 36], fill=(60, 60, 80))
    P["ice_cream_cart"] = (outline(im), 1)
    im = new(96, 40)
    d = ImageDraw.Draw(im)
    for x in (2, 32, 62, 92):
        d.rectangle([x, 6, x + 2, 38], fill=(120, 90, 50))
    for i, x in enumerate(range(4, 92, 10)):
        d.rectangle([x, 10, x + 9, 34], fill=[(230, 70, 60), (60, 120, 200), (244, 222, 120)][i % 3])
    P["windbreak"] = (outline(im), 1)
    im = new(32, 40)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 14, 27, 38], fill=(230, 70, 60))
    d.rectangle([4, 24, 27, 30], fill=(240, 240, 240))
    d.rectangle([14, 2, 17, 16], fill=(60, 60, 70))
    d.ellipse([12, 0, 19, 7], fill=(255, 220, 80))
    P["buoy"] = (outline(im), 1)
    im = new(48, 48)
    d = ImageDraw.Draw(im)
    for i in range(6):
        d.rectangle([4 + i, 40 - i * 5, 43 - i, 44 - i * 5], fill=(120, 90, 50) if i % 2 else (230, 70, 60))
    P["deckchair_stack"] = (outline(im), 1)
    im = new(64, 40)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 14), (61, 14), (52, 36), (12, 36)], fill=(240, 236, 220))
    d.polygon([(2, 14), (61, 14), (58, 20), (6, 20)], fill=(60, 120, 200))
    d.rectangle([14, 22, 50, 25], fill=(120, 90, 50))
    d.rectangle([24, 28, 40, 31], fill=(120, 90, 50))
    P["dinghy"] = (outline(im), 1)

    # gulls: three on a post and one on the ground, walk-under
    im = new(32, 24)
    d = ImageDraw.Draw(im)
    d.ellipse([8, 8, 24, 20], fill=(240, 240, 244))
    d.ellipse([18, 4, 28, 12], fill=(240, 240, 244))
    d.polygon([(27, 8), (32, 9), (27, 11)], fill=(240, 180, 60))
    d.polygon([(6, 12), (16, 6), (18, 14)], fill=(150, 150, 160))
    d.line([(14, 20), (14, 23)], fill=(240, 180, 60))
    d.line([(18, 20), (18, 23)], fill=(240, 180, 60))
    P["gull"] = (outline(im), 0)

    # a red K6 telephone box and a pillar box
    im = new(32, 72)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 6, 27, 70], fill=(200, 30, 30))
    d.rectangle([2, 2, 29, 10], fill=(170, 20, 20))
    d.rectangle([8, 12, 23, 56], fill=(200, 220, 230))
    for y in range(12, 56, 8):
        d.line([(8, y), (23, y)], fill=(170, 20, 20))
    d.line([(15, 12), (15, 56)], fill=(170, 20, 20))
    d.rectangle([6, 6, 25, 10], fill=(240, 230, 200))
    P["phone_box"] = (outline(im), 1)
    im = new(32, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 10, 23, 54], fill=(200, 30, 30))
    d.ellipse([6, 2, 25, 16], fill=(170, 20, 20))
    d.rectangle([10, 24, 21, 27], fill=(30, 20, 20))
    d.rectangle([6, 50, 25, 55], fill=(40, 40, 46))
    P["pillar_box"] = (outline(im), 1)

    # VACANCIES sign on a post, a golf flag, a stile, a mower
    im = new(32, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 20, 17, 54], fill=(40, 40, 46))
    d.rectangle([2, 4, 29, 20], fill=(240, 236, 220))
    d.rectangle([5, 8, 26, 10], fill=(60, 60, 90))
    d.rectangle([5, 13, 26, 15], fill=(60, 60, 90))
    P["vacancies_sign"] = (outline(im), 1)
    im = new(32, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([15, 4, 17, 62], fill=(240, 240, 240))
    d.polygon([(17, 6), (30, 12), (17, 18)], fill=(230, 60, 50))
    d.ellipse([10, 58, 22, 63], fill=(40, 60, 30))
    P["golf_flag"] = (outline(im), 0)
    im = new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 10, 7, 46], fill=(120, 90, 50))
    d.rectangle([24, 10, 27, 46], fill=(120, 90, 50))
    d.rectangle([2, 16, 29, 19], fill=(140, 110, 60))
    d.rectangle([2, 30, 29, 33], fill=(140, 110, 60))
    d.rectangle([8, 36, 23, 40], fill=(140, 110, 60))
    P["stile"] = (outline(im), 0)
    im = new(64, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 18, 50, 34], fill=(50, 120, 60))
    d.rectangle([44, 6, 48, 20], fill=(60, 60, 70))
    d.line([(46, 6), (62, 2)], fill=(60, 60, 70), width=3)
    d.ellipse([4, 28, 16, 39], fill=(30, 30, 36))
    d.ellipse([38, 28, 50, 39], fill=(30, 30, 36))
    d.rectangle([2, 20, 10, 26], fill=(80, 80, 90))
    P["mower"] = (outline(im), 1)

    # the drained pool, a swing, a slide, the empty outdoor stage
    im = new(160, 96)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 159, 95], fill=(200, 196, 190))
    d.rectangle([8, 8, 151, 87], fill=(150, 190, 200))
    d.rectangle([12, 12, 147, 83], fill=(120, 160, 172))
    d.rectangle([12, 60, 147, 83], fill=(100, 130, 140))
    d.rectangle([70, 14, 74, 60], fill=(200, 196, 190))
    for x in (20, 50, 100, 130):
        d.line([(x, 20), (x + 8, 50)], fill=(90, 110, 120))
    d.rectangle([140, 10, 146, 30], fill=(220, 220, 220))
    P["pool_empty"] = (im, 3)
    im = new(64, 64)
    d = ImageDraw.Draw(im)
    d.line([(4, 62), (20, 6)], fill=(60, 60, 70), width=3)
    d.line([(59, 62), (43, 6)], fill=(60, 60, 70), width=3)
    d.rectangle([18, 4, 45, 8], fill=(60, 60, 70))
    d.line([(26, 8), (26, 44)], fill=(90, 90, 100))
    d.line([(37, 8), (37, 44)], fill=(90, 90, 100))
    d.rectangle([22, 44, 41, 48], fill=(230, 70, 60))
    P["swing"] = (outline(im), 1)
    im = new(64, 64)
    d = ImageDraw.Draw(im)
    d.polygon([(4, 60), (24, 10), (34, 10), (60, 60)], fill=(60, 120, 200))
    d.rectangle([24, 4, 34, 12], fill=(60, 60, 70))
    d.line([(44, 12), (56, 56)], fill=(60, 60, 70), width=2)
    for y in range(16, 60, 8):
        d.line([(26 + (y - 16) // 4, y), (36 + (y - 16) // 4, y)], fill=(230, 236, 240))
    P["slide"] = (outline(im), 1)
    im = new(128, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 24, 127, 62], fill=(90, 70, 60))
    d.rectangle([0, 22, 127, 28], fill=(120, 96, 80))
    for x in range(0, 128, 16):
        d.line([(x, 28), (x, 62)], fill=(70, 54, 46))
    d.rectangle([4, 0, 9, 24], fill=(60, 60, 70))
    d.rectangle([118, 0, 123, 24], fill=(60, 60, 70))
    d.rectangle([4, 0, 123, 6], fill=(200, 60, 60))
    d.rectangle([12, 6, 115, 12], fill=(240, 236, 220))
    P["outdoor_stage"] = (outline(im), 2)

    # the camp sign, a chalet number plate and a zoo cage
    im = new(96, 80)
    d = ImageDraw.Draw(im)
    d.rectangle([44, 30, 51, 78], fill=(120, 90, 50))
    d.rectangle([2, 2, 93, 34], fill=(244, 222, 120))
    d.rectangle([6, 6, 89, 30], fill=(200, 60, 60))
    d.rectangle([12, 12, 83, 16], fill=(244, 222, 120))
    d.rectangle([20, 20, 75, 24], fill=(244, 222, 120))
    d.ellipse([80, 0, 95, 15], fill=(255, 220, 80))
    P["camp_sign"] = (outline(im), 1)
    im = new(96, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 8, 95, 62], fill=(60, 60, 66))
    d.rectangle([4, 14, 91, 58], fill=(90, 80, 60))
    for x in range(4, 96, 8):
        d.line([(x, 8), (x, 62)], fill=(140, 140, 150))
    d.rectangle([0, 8, 95, 11], fill=(140, 140, 150))
    d.ellipse([30, 30, 64, 52], fill=(220, 140, 50))
    d.rectangle([34, 36, 60, 38], fill=(40, 30, 20))
    d.rectangle([40, 42, 54, 44], fill=(40, 30, 20))
    P["zoo_cage"] = (outline(im), 2)

    # the Hut's insides: a wall of dials, a rack of shells, a wall of children's drawings, a costume rail, a gun on its mount
    im = new(64, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 63, 47], fill=(70, 72, 80))
    for i, (x, y) in enumerate(((8, 6), (26, 6), (44, 6), (8, 26), (26, 26), (44, 26))):
        d.ellipse([x, y, x + 12, y + 12], fill=(220, 220, 200))
        d.line([(x + 6, y + 6), (x + 6 + [4, -3, 2, -5, 5, 0][i], y + 6 + [-3, -4, 5, 1, -1, -5][i])], fill=(40, 40, 50))
    P["dial_panel"] = (im, 0)
    im = new(96, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 4, 95, 46], fill=(80, 70, 60))
    for y in (10, 24, 38):
        d.line([(0, y), (95, y)], fill=(50, 44, 40), width=2)
        for x in range(4, 96, 12):
            d.rectangle([x, y - 6, x + 7, y - 1], fill=(130, 120, 90))
    P["shell_rack"] = (outline(im), 1)
    im = new(64, 32)
    d = ImageDraw.Draw(im)
    rnd = random.Random(3)
    for x in range(2, 60, 14):
        y = rnd.randrange(0, 8)
        d.rectangle([x, y, x + 11, y + 14], fill=(240, 236, 220))
        d.ellipse([x + 3, y + 3, x + 8, y + 8], fill=rnd.choice([(230, 70, 60), (60, 120, 200), (244, 222, 120), (50, 160, 90)]))
        d.line([(x + 2, y + 11), (x + 9, y + 11)], fill=(100, 100, 110))
    P["drawings_wall"] = (im, 0)
    im = new(96, 52)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 4, 91, 7], fill=(120, 120, 130))
    d.rectangle([4, 4, 7, 50], fill=(120, 120, 130))
    d.rectangle([88, 4, 91, 50], fill=(120, 120, 130))
    for i, x in enumerate(range(10, 86, 9)):
        d.rectangle([x, 8, x + 7, 40], fill=[(230, 70, 60), (244, 222, 120), (60, 120, 200), (50, 160, 90), (240, 240, 240), (120, 60, 140)][i % 6])
    P["costume_rail"] = (outline(im), 1)
    im = new(96, 64)
    d = ImageDraw.Draw(im)
    d.ellipse([8, 30, 87, 62], fill=(90, 92, 96))
    d.rectangle([28, 20, 67, 44], fill=(70, 72, 80))
    d.rectangle([44, 0, 51, 28], fill=(60, 62, 70))
    d.rectangle([40, 24, 55, 32], fill=(80, 82, 90))
    P["gun_mount"] = (outline(im), 2)
    im = new(96, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 10, 95, 62], fill=(120, 122, 126))
    d.rectangle([0, 10, 95, 16], fill=(150, 152, 156))
    d.rectangle([30, 22, 65, 62], fill=(30, 28, 32))
    d.rectangle([30, 22, 65, 26], fill=(80, 80, 86))
    P["battery_door"] = (outline(im), 2)

    # the vehicles of the trip: a jet, an Island Line tube carriage, a hovercraft, a ferry
    im = new(176, 64)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([10, 22, 170, 44], 10, fill=(236, 238, 242))
    d.polygon([(10, 33), (0, 28), (0, 38)], fill=(236, 238, 242))
    d.polygon([(150, 22), (175, 6), (175, 22)], fill=(60, 80, 140))
    d.polygon([(60, 44), (110, 44), (140, 60), (90, 60)], fill=(210, 212, 220))
    d.polygon([(60, 22), (110, 22), (130, 10), (90, 10)], fill=(200, 202, 212))
    d.rectangle([10, 32, 170, 35], fill=(60, 80, 140))
    for x in range(30, 150, 8):
        d.rectangle([x, 26, x + 3, 30], fill=(80, 120, 180))
    d.ellipse([90, 46, 118, 58], fill=(90, 90, 100))
    P["jet"] = (outline(im), 1)
    im = new(160, 48)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 4, 159, 40], 6, fill=(200, 40, 40))
    d.rectangle([0, 14, 159, 30], fill=(230, 230, 220))
    for x in range(8, 152, 16):
        d.rectangle([x, 12, x + 10, 26], fill=(90, 110, 140))
    d.rectangle([70, 10, 76, 36], fill=(120, 20, 20))
    d.rectangle([0, 38, 159, 42], fill=(60, 60, 70))
    for x in (12, 40, 110, 138):
        d.ellipse([x, 38, x + 10, 47], fill=(40, 40, 48))
    P["tube_carriage"] = (outline(im), 1)
    im = new(128, 56)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 30, 127, 54], 12, fill=(40, 40, 46))
    d.rounded_rectangle([8, 10, 110, 36], 6, fill=(236, 238, 242))
    d.rectangle([8, 22, 110, 26], fill=(200, 40, 40))
    for x in range(16, 100, 12):
        d.rectangle([x, 13, x + 7, 20], fill=(80, 120, 180))
    d.rectangle([100, 0, 124, 30], fill=(60, 60, 70))
    d.ellipse([104, 4, 120, 20], fill=(120, 120, 130))
    P["hovercraft"] = (outline(im), 1)
    im = new(160, 72)
    d = ImageDraw.Draw(im)
    d.polygon([(0, 40), (159, 40), (150, 70), (10, 70)], fill=(40, 60, 100))
    d.rectangle([20, 20, 140, 42], fill=(236, 238, 242))
    d.rectangle([40, 6, 110, 22], fill=(220, 222, 230))
    d.rectangle([90, 0, 100, 10], fill=(200, 40, 40))
    for x in range(26, 136, 12):
        d.rectangle([x, 26, x + 6, 34], fill=(80, 120, 180))
    d.rectangle([0, 40, 159, 44], fill=(200, 40, 40))
    P["ferry"] = (outline(im), 1)
    # a cloud, drawn big, for the sky strip
    im = new(96, 48)
    d = ImageDraw.Draw(im)
    for x, y, w, h in ((4, 20, 40, 26), (24, 8, 50, 36), (54, 18, 40, 28)):
        d.ellipse([x, y, x + w, y + h], fill=(240, 244, 250))
    P["cloud_big"] = (im, 0)
    # a sea wave crest for the crossing
    im = new(64, 16)
    d = ImageDraw.Draw(im)
    d.line([(0, 12), (12, 4), (24, 12), (36, 4), (48, 12), (60, 4)], fill=(220, 236, 244), width=2)
    P["wave"] = (im, 0)
    # a coach (bank holiday) and a British police car
    im = new(96, 40)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2, 8, 93, 34], 6, fill=(240, 240, 236))
    d.rectangle([2, 20, 93, 26], fill=(60, 120, 200))
    for x in range(10, 90, 12):
        d.rectangle([x, 11, x + 8, 18], fill=(90, 110, 140))
    for x in (12, 72):
        d.ellipse([x, 30, x + 10, 39], fill=(30, 28, 34))
    P["coach"] = (outline(im), 1)

    return P


# ------------------------------------------------------------------ facades
SUMMER_FACADES = {
    "pavilion": dict(w=14, h=3, siding="white", shade=0, roof="navy", roof_h=2, door="blue", door_x=6, windows=[1, 2, 3, 10, 11, 12], doors=[6], tall=True, neon="neon_amber"),
    "stage_door": dict(w=4, h=2, siding="grey", shade=3, roof="grey", roof_h=1, door="dark", door_x=1, windows=[]),
    "beach_cafe": dict(w=7, h=2, siding="teal", shade=0, roof="rust", roof_h=1, door="white", door_x=3, windows=[1, 5], neon="neon_red"),
    "deckchair_hut": dict(w=4, h=2, siding="green", shade=1, roof="brown", roof_h=1, door="white", door_x=1, windows=[3]),
    "zoo_gate": dict(w=8, h=2, siding="green", shade=2, roof="grey", roof_h=1, door="brown", door_x=3, windows=[0, 7]),
    "guest_house": dict(w=8, h=3, siding="peach", shade=0, roof="slate", roof_h=2, door="blue", door_x=3, windows=[1, 5, 6], tall=True),
    "pub": dict(w=8, h=2, siding="white", shade=2, roof="brown", roof_h=2, door="green", door_x=3, windows=[1, 6], neon="neon_amber"),
    "newsagent": dict(w=5, h=2, siding="red", shade=1, roof="grey", roof_h=1, door="white", door_x=2, windows=[0, 4]),
    "charity_shop": dict(w=5, h=2, siding="blue", shade=0, roof="grey", roof_h=1, door="white", door_x=2, windows=[0, 4]),
    "chemist": dict(w=5, h=2, siding="white", shade=0, roof="navy", roof_h=1, door="green", door_x=2, windows=[0, 4], neon="neon_amber"),
    "library_uk": dict(w=8, h=3, siding="grey", shade=2, roof="slate", roof_h=2, door="brown", door_x=3, windows=[1, 6], tall=True),
    "church_hall": dict(w=8, h=2, siding="white", shade=1, roof="slate", roof_h=2, door="brown", door_x=3, windows=[1, 6]),
    "church_stone": dict(w=6, h=4, siding="grey", shade=2, roof="slate", roof_h=2, door="brown", door_x=2, windows=[0, 5], tall=True, steeple=True),
    "station": dict(w=10, h=2, siding="green", shade=2, roof="grey", roof_h=2, door="white", door_x=4, windows=[1, 2, 7, 8]),
    "record_shop": dict(w=5, h=2, siding="yellow", shade=0, roof="grey", roof_h=1, door="dark", door_x=2, windows=[0, 4]),
    "clubhouse": dict(w=9, h=2, siding="white", shade=0, roof="brown", roof_h=2, door="green", door_x=4, windows=[1, 2, 6, 7]),
    "groundsman": dict(w=4, h=2, siding="green", shade=3, roof="rust", roof_h=1, door="dark", door_x=1, windows=[]),
    "hide": dict(w=4, h=2, siding="brown", shade=3, roof="brown", roof_h=1, door="dark", door_x=1, windows=[3]),
    "chalet": dict(w=5, h=2, siding="yellow", shade=1, roof="orange", roof_h=1, door="white", door_x=2, windows=[0, 4]),
    "ballroom": dict(w=12, h=3, siding="peach", shade=1, roof="orange", roof_h=2, door="white", door_x=5, windows=[1, 2, 3, 8, 9, 10], tall=True, neon="neon_red"),
    "camp_office": dict(w=6, h=2, siding="white", shade=1, roof="orange", roof_h=1, door="blue", door_x=2, windows=[0, 4]),
    "green_room": dict(w=5, h=2, siding="grey", shade=1, roof="grey", roof_h=1, door="dark", door_x=2, windows=[0]),
    "costume_store": dict(w=5, h=2, siding="grey", shade=2, roof="grey", roof_h=1, door="dark", door_x=2, windows=[]),
    "clifftop_pub": dict(w=8, h=2, siding="grey", shade=1, roof="slate", roof_h=2, door="red", door_x=3, windows=[1, 6], neon="neon_amber"),
    "warden_hut": dict(w=4, h=2, siding="green", shade=2, roof="brown", roof_h=1, door="brown", door_x=1, windows=[3]),
    "battery": dict(w=8, h=3, siding="grey", shade=3, roof="grey", roof_h=1, door="dark", door_x=3, windows=[], tall=True),
    "the_hut": dict(w=4, h=2, siding="grey", shade=3, roof="grey", roof_h=1, door="dark", door_x=1, windows=[]),
    "coastguard": dict(w=5, h=3, siding="white", shade=0, roof="navy", roof_h=1, door="blue", door_x=2, windows=[0, 4], tall=True),
    "arcade": dict(w=8, h=2, siding="red", shade=0, roof="navy", roof_h=1, door="white", door_x=3, windows=[1, 2, 5, 6], neon="neon_red"),
}


# ------------------------------------------------------------------ people
TEE = "Shirt 04 - T-shirt"
POLO = "Shirt 09 - Polo"
SHORTS = "Shorts 01 - Shorts"
SHOES = ("Shoes 01 - Shoes", "Black")


def summer_characters(adult, child, LONG, BUTTONED, CARDIGAN):
    return {
        # the two children of 1973, now in their late twenties
        "colin": adult("Peach", hair="Short 03 - Curly", hair_colour="Chestnut", shirt=(POLO, "Olivine"), pants=("Pants 03 - Pants", "Denim"), shoes=SHOES),
        "fay": adult("Porcelain", head="Head 01 - Feminine", fem=True, hair="Medium 01 - Page", hair_colour="Ash Brown", hair_behind=True, shirt=(TEE, "Lavender"), over=(CARDIGAN, "Dove"), pants=("Pants 03 - Pants", "Charcoal"), shoes=SHOES),
        # the seafront and pier
        "stage_mgr": adult("Tan", hair="Short 02 - Parted", hair_colour="Black", shirt=(BUTTONED, "Black"), pants=("Pants 03 - Pants", "Black"), shoes=SHOES),
        "arcade_man": adult("Honey", hair="Short 01 - Buzzcut", hair_colour="Brown", shirt=(TEE, "Red"), pants=("Pants 03 - Pants", "Denim"), beard=("Facial Hair 05 - Horseshoe Mustache", "Brown"), shoes=SHOES),
        "deckchair_man": adult("Bronze", head="Head 03 - Elderly", hair="Short 06 - Balding", hair_colour="White", shirt=(BUTTONED, "Sky"), pants=("Pants 04 - Cuffed Pants", "Beige"), shoes=SHOES),
        "cafe_woman": adult("Peach", head="Head 01 - Feminine", fem=True, hair="Medium 02 - Curly", hair_colour="Orange", shirt=(TEE, "White"), over=(CARDIGAN, "Pink"), pants=("Pants 03 - Pants", "Navy"), shoes=SHOES),
        "professor": adult("Ivory", head="Head 03 - Elderly", hair="Short 02 - Parted", hair_colour="Gray", shirt=(BUTTONED, "Garnet"), over=(CARDIGAN, "Tan"), pants=("Pants 03 - Pants", "Chocolate"), beard=("Facial Hair 03 - Handlebar Mustache", "Gray"), shoes=SHOES),
        "keeper": adult("Brown", hair="Short 05 - Natural", hair_colour="Black", shirt=(POLO, "Forest"), pants=("Pants 03 - Pants", "Umber"), shoes=("Shoes 02 - Boots", "Black")),
        # the town
        "landlady": adult("Peach", head="Head 03 - Elderly", fem=True, hair="Medium 04 - Bangs & Bun", hair_colour="Gray", shirt=(BUTTONED, "Lavender"), over=(CARDIGAN, "Mauve"), pants=("Pants 03 - Pants", "Charcoal"), glasses="Brass", shoes=SHOES),
        "publican": adult("Tawny", hair="Short 06 - Balding", hair_colour="Brown", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Black"), pants=("Pants 03 - Pants", "Black"), beard=("Facial Hair 01 - Walrus Mustache", "Brown"), shoes=SHOES),
        "newsagent": adult("Bronze", hair="Short 07 - Flat Top", hair_colour="Black", shirt=(BUTTONED, "Mint"), pants=("Pants 03 - Pants", "Charcoal"), glasses="Steel", shoes=SHOES),
        "volunteer": adult("Porcelain", head="Head 03 - Elderly", fem=True, hair="Medium 02 - Curly", hair_colour="White", shirt=(BUTTONED, "Pink"), over=(CARDIGAN, "Sky"), pants=("Pants 03 - Pants", "Navy"), glasses="Brass", shoes=SHOES),
        "chemist": adult("Tan", hair="Short 02 - Parted", hair_colour="Gray", shirt=(BUTTONED, "White"), over=(CARDIGAN, "White"), pants=("Pants 03 - Pants", "Charcoal"), glasses="Steel", shoes=SHOES),
        "archivist": adult("Peach", head="Head 01 - Feminine", fem=True, hair="Medium 07 - Bob, Side Part", hair_colour="Chestnut", shirt=(BUTTONED, "Ivory"), over=(CARDIGAN, "Forest"), pants=("Pants 03 - Pants", "Chocolate"), glasses="Brass", shoes=SHOES),
        "vicar": adult("Ivory", hair="Short 06 - Balding", hair_colour="Gray", shirt=(BUTTONED, "Black"), over=(CARDIGAN, "Black"), pants=("Pants 03 - Pants", "Black"), shoes=SHOES),
        "stationmaster": adult("Honey", head="Head 03 - Elderly", hair="Short 02 - Parted", hair_colour="White", shirt=(BUTTONED, "Sky"), over=(CARDIGAN, "Navy"), pants=("Pants 03 - Pants", "Navy"), beard=("Facial Hair 02 - Chevron Mustache", "White"), shoes=SHOES),
        "holidaymaker": adult("Peach", hair="Short 04 - Cowlick", hair_colour="Blonde", shirt=(TEE, "Sky"), pants=(SHORTS, "Beige"), shoes=SHOES),
        "holidaymaker2": adult("Tawny", head="Head 01 - Feminine", fem=True, hair="Medium 08 - Bob, Bangs", hair_colour="Black", shirt=(TEE, "Coral"), pants=(SHORTS, "Denim"), shoes=SHOES),
        "mod": adult("Peach", hair="Short 02 - Parted", hair_colour="Black", shirt=(POLO, "Red"), over=(CARDIGAN, "Olivine"), pants=("Pants 03 - Pants", "Charcoal"), shoes=SHOES),
        # the Levels
        "secretary": adult("Porcelain", head="Head 03 - Elderly", hair="Short 02 - Parted", hair_colour="Gray", shirt=(POLO, "Ivory"), over=(CARDIGAN, "Navy"), pants=("Pants 03 - Pants", "Beige"), glasses="Brass", shoes=SHOES),
        "groundsman": adult("Tan", hair="Short 01 - Buzzcut", hair_colour="Brown", shirt=(TEE, "Forest"), pants=("Pants 05 - Overalls", "Denim"), beard=("Facial Hair 07 - Medium Beard", "Brown"), shoes=("Shoes 02 - Boots", "Black")),
        "birder": adult("Peach", head="Head 03 - Elderly", fem=True, hair="Medium 04 - Bangs & Bun", hair_colour="White", shirt=(LONG, "Olivine"), over=(CARDIGAN, "Swamp"), pants=("Pants 03 - Pants", "Umber"), glasses="Steel", shoes=("Shoes 02 - Boots", "Black")),
        # the holiday camp
        "camp_boss": adult("Peach", hair="Short 06 - Balding", hair_colour="Gray", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Tan"), pants=("Pants 03 - Pants", "Charcoal"), shoes=SHOES),
        "yellowcoat": adult("Honey", hair="Short 04 - Cowlick", hair_colour="Chestnut", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Mustard"), pants=("Pants 03 - Pants", "Navy"), shoes=SHOES),
        "yellowcoat2": adult("Brown", head="Head 01 - Feminine", fem=True, hair="Medium 09 - Twists", hair_colour="Black", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Mustard"), pants=("Pants 03 - Pants", "Navy"), shoes=SHOES),
        "caretaker": adult("Tawny", head="Head 03 - Elderly", hair="Short 05 - Natural", hair_colour="Gray", shirt=(LONG, "Denim"), pants=("Pants 05 - Overalls", "Charcoal"), shoes=("Shoes 02 - Boots", "Black")),
        # Culver Down
        "nt_warden": adult("Peach", head="Head 01 - Feminine", fem=True, hair="Medium 01 - Page", hair_colour="Chestnut", shirt=(POLO, "Forest"), pants=("Pants 03 - Pants", "Umber"), shoes=("Shoes 02 - Boots", "Black")),
        "coastguard": adult("Bronze", hair="Short 01 - Buzzcut", hair_colour="Black", shirt=(LONG, "Navy"), over=(CARDIGAN, "Navy"), pants=("Pants 03 - Pants", "Navy"), beard=("Facial Hair 06 - Trimmed Beard", "Black"), shoes=("Shoes 02 - Boots", "Black")),
        "shepherd": adult("Ivory", head="Head 03 - Elderly", hair="Short 06 - Balding", hair_colour="White", shirt=(BUTTONED, "Beige"), over=(CARDIGAN, "Oak"), pants=("Pants 04 - Cuffed Pants", "Umber"), beard=("Facial Hair 07 - Medium Beard", "White"), shoes=("Shoes 02 - Boots", "Black")),
        "pub_landlord": adult("Tan", hair="Short 03 - Curly", hair_colour="Gray", shirt=(BUTTONED, "Garnet"), pants=("Pants 03 - Pants", "Black"), beard=("Facial Hair 04 - Lampshade Mustache", "Gray"), shoes=SHOES),
        # the road
        "hover_woman": adult("Porcelain", head="Head 03 - Elderly", fem=True, hair="Medium 07 - Bob, Side Part", hair_colour="White", shirt=(BUTTONED, "Sky"), over=(CARDIGAN, "Tan"), pants=("Pants 03 - Pants", "Navy"), shoes=SHOES),
    }
