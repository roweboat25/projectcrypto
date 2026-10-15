"""Season 1 additions to the art library: the rest of Point Pleasant.
Imported by build_art.py, which merges these tables into its own."""
from PIL import Image, ImageDraw

T = 32
TI = "Terrain/terrain_winter_ice.png"
TW = "Terrain/terrain_winter.png"
O = "Objects/Furniture/"
S = "Objects/Small Items/"
WI = "Objects/Wall Items/"
TR = "Terrain/trees_winter.png"

# extra tiles: (sheet, col, row) or a name special_tile_extra draws
EXTRA_TILES = {
    "ice": (TI, 3, 3),
    "ice2": (TI, 4, 3),
    "ice3": (TI, 3, 4),
    "water_red": "water_red",
    "water_red2": "water_red2",
    "gravel": "gravel",
    "gravel2": "gravel2",
    "rail": "rail",
    "concrete_dark": "concrete_dark",
    "mud": (TW, 4, 6),
    "mud2": (TW, 5, 6),
}

# extra LPC crops: name: (sheet, (x, y, w, h), solid rows)
EXTRA_PROPS = {
    "fence_v": ("Structure/Fences/Plain Fence A.png", (96, 0, 32, 96), 1),
    "bar_stool": (O + "Seating/Bar Stools.png", (32, 0, 32, 32), 1),
    "bar_stool_blue": (O + "Seating/Bar Stools.png", (64, 0, 32, 32), 1),
    "loveseat": (O + "Seating/Loveseat, Small - Casual Solid A.png", (0, 0, 64, 48), 1),
    "ladder": (O + "Ladder.png", (0, 0, 32, 96), 1),
    "chest": (O + "Chest.png", (0, 0, 32, 32), 1),
    "christmas_tree": (O + "Christmas Tree.png", (0, 0, 64, 96), 1),
    "workbench": (O + "Workbench, Carpentry.png", (0, 0, 96, 64), 2),
    "table_workshop": (O + "Table, Workshop.png", (0, 0, 96, 64), 2),
    "trough": (O + "Trough.png", (0, 0, 64, 32), 1),
    "lumber": (S + "Lumber.png", (0, 0, 64, 32), 1),
    "bucket": (S + "Buckets.png", (0, 0, 32, 32), 1),
    "basket": (S + "Baskets A.png", (0, 0, 32, 32), 1),
    "campfire": (S + "Fire, Camp.png", (0, 0, 32, 32), 1),
    "tabletop_photo": (S + "Tabletop Portraits.png", (0, 0, 32, 32), 0),
    "pillows": (S + "Pillows.png", (0, 0, 32, 32), 0),
    "portrait_wall": (WI + "Paintings, Portraits.png", (0, 0, 32, 32), 0),
    "mirror_wall": (WI + "Mirrors.png", (0, 0, 32, 32), 0),
    "wall_lamp": (WI + "Lighting, Wall.png", (0, 0, 32, 32), 0),
    "graffiti": (WI + "Graffiti.png", (0, 0, 64, 32), 0),
    "bed_double": (O + "Beds/Beds, Double B.png", (0, 0, 96, 96), 2),
    "tree_bare": (TR, (32, 192, 96, 128), 1),
    "rock_cliff": ("Terrain/Rocks, Cliffs.png", (0, 64, 96, 64), 2),
    "drain": ("Structure/Misc/Drain A.png", (0, 96, 32, 32), 0),
}


def outline(im, col=(28, 20, 24, 255)):
    px = im.load()
    w, h = im.size
    base = im.copy().load()
    for y in range(h):
        for x in range(w):
            if base[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and base[nx, ny][3] and base[nx, ny] != col:
                    px[x, y] = col
                    break
    return im


def special_tile_extra(name, base_tile):
    """base_tile(sheet, col, row) -> Image. Draws tiles LPC has no winter version of."""
    if name.startswith("water_red"):
        im = base_tile(TW, 12 if name == "water_red" else 13, 17).convert("RGBA")
        px = im.load()
        for y in range(T):
            for x in range(T):
                r, g, b, a = px[x, y]
                px[x, y] = (min(255, int(r * 0.9 + 90)), int(g * 0.45), int(b * 0.4), a)
        return im
    if name.startswith("gravel"):
        im = Image.new("RGBA", (T, T), (118, 112, 104, 255) if name == "gravel" else (112, 108, 100, 255))
        d = ImageDraw.Draw(im)
        import random
        rnd = random.Random(7 if name == "gravel" else 11)
        for _ in range(40):
            x, y = rnd.randrange(T), rnd.randrange(T)
            c = rnd.choice([(140, 134, 126), (96, 92, 88), (160, 156, 150), (130, 120, 110)])
            d.point((x, y), fill=c + (255,))
        return im
    if name == "rail":
        im = Image.new("RGBA", (T, T), (96, 84, 70, 255))
        d = ImageDraw.Draw(im)
        for x in range(2, T, 8):
            d.rectangle([x, 0, x + 4, T - 1], fill=(74, 56, 40, 255))
        d.rectangle([0, 7, T - 1, 9], fill=(150, 150, 160, 255))
        d.rectangle([0, 22, T - 1, 24], fill=(150, 150, 160, 255))
        return im
    if name == "concrete_dark":
        im = Image.new("RGBA", (T, T), (96, 98, 100, 255))
        d = ImageDraw.Draw(im)
        d.line([(0, 15), (31, 15)], fill=(80, 82, 84, 255))
        d.line([(15, 0), (15, 31)], fill=(80, 82, 84, 255))
        d.line([(4, 20), (12, 28)], fill=(70, 72, 74, 255))
        return im
    raise KeyError(name)


def extra_custom_props():
    """Landmarks and 1994 things drawn in code: the water tower, the obelisk, the floodwall,
    the igloos, a barge, a trailer, a barn, a tree stand and small street furniture."""
    P = {}

    def new(w, h):
        return Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # water tower: four legs, a tank with the town name band, snow on top
    im = new(96, 176)
    d = ImageDraw.Draw(im)
    for x in (10, 30, 60, 80):
        d.line([(x, 70), (x + (8 if x < 48 else -8), 172)], fill=(70, 74, 80), width=3)
    d.line([(14, 110), (82, 110)], fill=(70, 74, 80), width=2)
    d.line([(16, 140), (80, 140)], fill=(70, 74, 80), width=2)
    d.rounded_rectangle([8, 18, 87, 72], 10, fill=(150, 158, 170))
    d.rectangle([8, 40, 87, 48], fill=(120, 60, 60))
    d.ellipse([8, 4, 87, 30], fill=(176, 184, 196))
    d.ellipse([12, 4, 83, 22], fill=(236, 240, 246))
    d.rectangle([44, 52, 52, 172], fill=(86, 90, 96))
    P["water_tower"] = (outline(im), 2)

    # the Tu-Endie-Wei obelisk on a stepped base
    im = new(48, 112)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 96, 45, 110], fill=(150, 150, 150))
    d.rectangle([8, 84, 39, 97], fill=(170, 170, 172))
    d.polygon([(16, 84), (31, 84), (28, 10), (19, 10)], fill=(196, 196, 200))
    d.polygon([(19, 10), (28, 10), (23, 0)], fill=(220, 220, 226))
    d.polygon([(28, 10), (31, 84), (27, 84)], fill=(160, 160, 166))
    d.rectangle([10, 86, 37, 90], fill=(236, 240, 246))
    P["obelisk"] = (outline(im), 1)

    # floodwall: a long concrete section, and a stair section
    im = new(96, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 10, 95, 63], fill=(130, 134, 138))
    d.rectangle([0, 0, 95, 12], fill=(160, 164, 168))
    d.rectangle([0, 0, 95, 4], fill=(236, 240, 246))
    for x in range(0, 96, 24):
        d.line([(x, 12), (x, 63)], fill=(104, 108, 112))
    d.line([(0, 40), (95, 40)], fill=(104, 108, 112))
    P["floodwall"] = (outline(im), 2)
    im = new(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 10, 63, 63], fill=(130, 134, 138))
    d.rectangle([0, 0, 63, 12], fill=(160, 164, 168))
    for i in range(8):
        y = 12 + i * 6
        d.rectangle([14, y, 49, y + 5], fill=(170 - i * 6, 174 - i * 6, 178 - i * 6))
        d.line([(14, y), (49, y)], fill=(104, 108, 112))
    d.rectangle([12, 10, 14, 63], fill=(90, 94, 98))
    d.rectangle([49, 10, 51, 63], fill=(90, 94, 98))
    P["floodwall_stairs"] = (outline(im), 0)
    im = new(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 10, 63, 63], fill=(130, 134, 138))
    d.rectangle([0, 0, 63, 12], fill=(160, 164, 168))
    d.rectangle([16, 14, 47, 63], fill=(70, 60, 40))
    for y in range(18, 60, 8):
        d.line([(16, y), (47, y)], fill=(50, 42, 30))
    d.rectangle([28, 30, 35, 36], fill=(200, 180, 60))
    P["floodgate"] = (outline(im), 2)

    # a TNT area igloo: an earth mound with a steel door at the front
    im = new(128, 96)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 10, 127, 110], fill=(96, 92, 80))
    d.ellipse([0, 10, 127, 110], outline=(70, 66, 58))
    d.chord([0, 10, 127, 110], 180, 360, fill=(226, 232, 240))
    d.ellipse([10, 22, 117, 96], fill=(108, 102, 88))
    d.rectangle([0, 60, 127, 95], fill=(108, 102, 88))
    d.rectangle([44, 48, 83, 95], fill=(120, 124, 128))
    d.rectangle([52, 56, 75, 95], fill=(40, 42, 48))
    d.rectangle([52, 56, 63, 95], fill=(84, 78, 72))
    d.rectangle([60, 74, 62, 78], fill=(200, 200, 210))
    P["igloo"] = (outline(im), 2)
    im = new(128, 96)
    d = ImageDraw.Draw(im)
    d.ellipse([0, 10, 127, 110], fill=(96, 92, 80))
    d.chord([0, 10, 127, 110], 180, 360, fill=(226, 232, 240))
    d.rectangle([0, 60, 127, 95], fill=(108, 102, 88))
    d.rectangle([44, 48, 83, 95], fill=(120, 124, 128))
    d.rectangle([52, 56, 75, 95], fill=(84, 78, 72))
    d.line([(52, 56), (75, 95)], fill=(60, 56, 50), width=2)
    d.line([(75, 56), (52, 95)], fill=(60, 56, 50), width=2)
    P["igloo_shut"] = (outline(im), 2)

    # a river barge, seen from above, sitting in the water
    im = new(192, 64)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 8, 191, 60], 8, fill=(70, 50, 40))
    d.rectangle([8, 14, 183, 54], fill=(90, 66, 50))
    for x in range(16, 176, 28):
        d.ellipse([x, 20, x + 22, 46], fill=(40, 40, 46))
        d.ellipse([x + 4, 24, x + 18, 42], fill=(60, 60, 66))
    d.rectangle([150, 2, 190, 18], fill=(200, 60, 50))
    d.rectangle([156, 0, 184, 6], fill=(236, 240, 246))
    P["barge"] = (outline(im), 2)
    im = new(96, 40)
    d = ImageDraw.Draw(im)
    d.polygon([(4, 20), (20, 6), (92, 6), (92, 34), (20, 34)], fill=(230, 230, 236))
    d.rectangle([30, 10, 60, 30], fill=(60, 80, 110))
    d.rectangle([34, 14, 56, 22], fill=(150, 176, 194))
    P["johnboat"] = (outline(im), 1)

    # a trailer on cinder blocks
    im = new(160, 96)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 20, 155, 84], fill=(190, 186, 176))
    d.rectangle([4, 12, 155, 26], fill=(150, 146, 140))
    d.rectangle([4, 10, 155, 16], fill=(236, 240, 246))
    for x in range(12, 150, 12):
        d.line([(x, 26), (x, 84)], fill=(160, 156, 146))
    d.rectangle([24, 40, 50, 62], fill=(60, 70, 90))
    d.rectangle([100, 40, 126, 62], fill=(60, 70, 90))
    d.rectangle([70, 44, 86, 84], fill=(90, 70, 50))
    for x in (14, 76, 138):
        d.rectangle([x, 84, x + 10, 94], fill=(110, 110, 110))
    d.rectangle([80, 62, 83, 66], fill=(200, 180, 60))
    P["trailer"] = (outline(im), 3)

    # a tobacco barn / a farm barn in red, gable end facing the road
    im = new(192, 176)
    d = ImageDraw.Draw(im)
    d.polygon([(0, 70), (96, 10), (191, 70)], fill=(120, 44, 40))
    d.polygon([(0, 70), (96, 10), (191, 70), (191, 78), (96, 20), (0, 78)], fill=(236, 240, 246))
    d.rectangle([0, 70, 191, 170], fill=(150, 56, 50))
    for x in range(0, 192, 16):
        d.line([(x, 70), (x, 170)], fill=(120, 44, 40))
    d.rectangle([70, 96, 121, 170], fill=(60, 44, 36))
    d.line([(70, 96), (121, 170)], fill=(90, 66, 50), width=3)
    d.line([(121, 96), (70, 170)], fill=(90, 66, 50), width=3)
    d.rectangle([86, 40, 105, 60], fill=(40, 30, 26))
    P["barn"] = (outline(im), 4)

    # a hunter's tree stand in a bare tree
    im = new(64, 128)
    d = ImageDraw.Draw(im)
    d.rectangle([28, 30, 35, 126], fill=(70, 54, 40))
    for y, x1, x2 in ((40, 12, 50), (28, 18, 44), (18, 24, 38)):
        d.line([(31, y + 10), (x1, y - 10)], fill=(70, 54, 40), width=3)
        d.line([(31, y + 10), (x2, y - 10)], fill=(70, 54, 40), width=3)
    d.rectangle([14, 56, 49, 66], fill=(110, 90, 60))
    d.rectangle([14, 44, 16, 66], fill=(110, 90, 60))
    d.rectangle([47, 44, 49, 66], fill=(110, 90, 60))
    for y in range(70, 124, 10):
        d.rectangle([24, y, 39, y + 3], fill=(130, 110, 80))
    P["tree_stand"] = (outline(im), 1)

    # chain-link fence, horizontal and vertical, and a roadside cross
    im = new(96, 48)
    d = ImageDraw.Draw(im)
    for x in (2, 48, 93):
        d.rectangle([x, 0, x + 2, 47], fill=(120, 124, 130))
    d.rectangle([0, 2, 95, 4], fill=(140, 144, 150))
    for x in range(0, 96, 6):
        d.line([(x, 6), (x + 6, 46)], fill=(170, 174, 180, 200))
        d.line([(x + 6, 6), (x, 46)], fill=(170, 174, 180, 200))
    P["chain_fence"] = (outline(im), 1)
    im = new(32, 96)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 0, 16, 95], fill=(120, 124, 130))
    for y in range(0, 96, 6):
        d.line([(8, y), (22, y + 6)], fill=(170, 174, 180, 200))
        d.line([(22, y), (8, y + 6)], fill=(170, 174, 180, 200))
    P["chain_fence_v"] = (outline(im), 2)
    im = new(32, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 8, 17, 60], fill=(230, 230, 230))
    d.rectangle([5, 18, 26, 21], fill=(230, 230, 230))
    d.ellipse([10, 50, 21, 62], fill=(200, 60, 70))
    P["roadside_cross"] = (outline(im), 1)

    # a culvert mouth under the road, a bench, a picnic table, a bulletin board, a newspaper box
    im = new(96, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 95, 20], fill=(100, 96, 88))
    d.ellipse([24, 6, 71, 46], fill=(120, 124, 128))
    d.ellipse([32, 14, 63, 42], fill=(20, 20, 26))
    d.rectangle([0, 30, 95, 47], fill=(140, 150, 160, 160))
    P["culvert"] = (outline(im), 1)
    im = new(64, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 6, 61, 12], fill=(120, 90, 60))
    d.rectangle([2, 14, 61, 20], fill=(120, 90, 60))
    d.rectangle([6, 20, 10, 30], fill=(60, 60, 66))
    d.rectangle([53, 20, 57, 30], fill=(60, 60, 66))
    d.rectangle([2, 4, 61, 7], fill=(236, 240, 246))
    P["bench"] = (outline(im), 1)
    im = new(96, 56)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 10, 87, 30], fill=(130, 100, 70))
    d.rectangle([8, 8, 87, 12], fill=(236, 240, 246))
    d.rectangle([0, 36, 95, 44], fill=(120, 90, 60))
    d.rectangle([20, 30, 24, 50], fill=(100, 76, 50))
    d.rectangle([71, 30, 75, 50], fill=(100, 76, 50))
    P["picnic_table"] = (outline(im), 2)
    im = new(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 4, 59, 44], fill=(110, 80, 50))
    d.rectangle([8, 8, 55, 40], fill=(170, 140, 90))
    for (x, y, c) in ((11, 11, (240, 240, 230)), (30, 12, (250, 230, 150)), (14, 26, (230, 200, 200)), (36, 24, (240, 240, 230))):
        d.rectangle([x, y, x + 14, y + 11], fill=c)
    d.rectangle([10, 44, 14, 62], fill=(90, 66, 40))
    d.rectangle([49, 44, 53, 62], fill=(90, 66, 40))
    P["bulletin_board"] = (outline(im), 1)
    im = new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 4, 27, 40], fill=(40, 70, 130))
    d.rectangle([7, 8, 24, 20], fill=(200, 210, 220))
    d.rectangle([9, 11, 22, 13], fill=(60, 60, 70))
    d.rectangle([9, 15, 18, 17], fill=(60, 60, 70))
    d.rectangle([6, 40, 10, 46], fill=(40, 40, 46))
    d.rectangle([21, 40, 25, 46], fill=(40, 40, 46))
    P["newspaper_box"] = (outline(im), 1)

    # a reflector taped to a tree (red herring), a dead dog under a tarp, a deer
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([8, 8, 23, 23], fill=(220, 40, 50))
    d.ellipse([12, 12, 19, 19], fill=(255, 120, 120))
    d.rectangle([6, 14, 25, 17], fill=(120, 120, 120, 160))
    P["clue_reflector"] = (im, 0)
    im = new(48, 32)
    d = ImageDraw.Draw(im)
    d.polygon([(2, 28), (10, 10), (38, 8), (46, 26)], fill=(60, 80, 140))
    d.line([(10, 10), (46, 26)], fill=(40, 60, 110))
    P["clue_tarp"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 10, 27, 22], fill=(90, 150, 200, 150))
    d.ellipse([9, 13, 22, 19], fill=(180, 220, 250, 200))
    P["clue_cold"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 10, 25, 26], fill=(60, 60, 70, 180))
    d.line([(10, 14), (22, 22)], fill=(230, 200, 60), width=2)
    d.line([(22, 14), (10, 22)], fill=(230, 200, 60), width=2)
    d.ellipse([13, 15, 18, 20], fill=(230, 200, 60))
    P["clue_glyph"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    for (x, y) in ((6, 12), (16, 8), (22, 18), (10, 22)):
        d.ellipse([x, y, x + 6, y + 5], fill=(80, 70, 60))
    P["clue_pellets"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([8, 6, 23, 28], 3, fill=(220, 60, 40))
    d.rectangle([10, 12, 21, 15], fill=(230, 230, 60))
    d.rectangle([10, 19, 21, 22], fill=(230, 230, 60))
    P["clue_vest"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    for (x, y) in ((6, 8), (16, 14), (10, 22), (22, 6)):
        d.rectangle([x, y, x + 4, y + 10], fill=(180, 180, 190))
        d.rectangle([x, y, x + 4, y + 2], fill=(200, 60, 50))
    P["clue_cans"] = (im, 0)
    im = new(32, 48)
    d = ImageDraw.Draw(im)
    d.ellipse([6, 18, 25, 40], fill=(150, 110, 70))
    d.rectangle([8, 36, 11, 46], fill=(90, 66, 40))
    d.rectangle([20, 36, 23, 46], fill=(90, 66, 40))
    d.ellipse([16, 8, 28, 20], fill=(150, 110, 70))
    d.line([(22, 8), (26, 0)], fill=(110, 90, 60), width=2)
    d.line([(24, 8), (30, 2)], fill=(110, 90, 60), width=2)
    P["deer"] = (outline(im), 1)

    # a 1994 television and a CB/ham radio set, for rooms
    im = new(48, 40)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2, 4, 45, 36], 4, fill=(70, 60, 50))
    d.rounded_rectangle([7, 8, 34, 31], 3, fill=(40, 60, 70))
    d.rectangle([37, 10, 42, 14], fill=(200, 200, 200))
    d.rectangle([37, 18, 42, 22], fill=(200, 200, 200))
    d.line([(20, 4), (12, -4)], fill=(120, 120, 120), width=2)
    d.line([(26, 4), (34, -4)], fill=(120, 120, 120), width=2)
    P["tv"] = (outline(im), 1)
    im = new(64, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 10, 61, 36], fill=(60, 64, 70))
    d.rectangle([6, 14, 30, 24], fill=(30, 40, 50))
    d.rectangle([8, 16, 28, 18], fill=(90, 200, 120))
    for x in (36, 46, 56):
        d.ellipse([x, 16, x + 6, 22], fill=(160, 160, 170))
    d.rectangle([36, 28, 60, 32], fill=(40, 44, 50))
    d.rectangle([30, 0, 33, 10], fill=(120, 120, 130))
    P["radio_set"] = (outline(im), 1)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 10, 27, 28], fill=(60, 44, 36))
    d.rectangle([6, 12, 25, 26], fill=(80, 60, 48))
    d.rectangle([8, 14, 23, 18], fill=(220, 200, 160))
    P["filing_cabinet"] = (outline(im), 1)
    im = new(32, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 4, 27, 60], fill=(96, 100, 104))
    for y in (10, 24, 38, 52):
        d.rectangle([8, y, 23, y + 8], fill=(130, 134, 138))
        d.rectangle([14, y + 3, 17, y + 5], fill=(200, 200, 210))
    P["filing_tall"] = (outline(im), 1)
    im = new(64, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 20, 59, 44], fill=(150, 150, 156))
    d.rectangle([10, 6, 53, 26], fill=(60, 60, 70))
    d.rectangle([14, 10, 49, 22], fill=(220, 230, 240))
    P["microfiche"] = (outline(im), 1)
    im = new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 10, 27, 44], fill=(120, 60, 40))
    d.rectangle([8, 14, 23, 20], fill=(200, 160, 120))
    d.rectangle([8, 24, 23, 40], fill=(90, 44, 30))
    P["pie_case"] = (outline(im), 1)
    im = new(64, 40)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 8, 61, 36], fill=(44, 40, 36))
    for i, c in enumerate(((220, 200, 60), (60, 160, 220), (220, 80, 60), (120, 200, 90))):
        d.rectangle([6 + i * 14, 12, 16 + i * 14, 30], fill=c)
    P["bottles_shelf"] = (outline(im), 1)
    im = new(96, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 20, 95, 60], fill=(80, 56, 40))
    d.rectangle([0, 16, 95, 24], fill=(110, 80, 56))
    for x in (12, 40, 68):
        d.rectangle([x, 28, x + 16, 36], fill=(60, 40, 30))
    P["bar_counter"] = (outline(im), 1)
    im = new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 4, 25, 44], fill=(90, 94, 98))
    d.ellipse([9, 8, 22, 21], fill=(230, 230, 236))
    d.line([(15, 14), (15, 9)], fill=(40, 40, 46))
    d.line([(15, 14), (19, 14)], fill=(40, 40, 46))
    d.rectangle([10, 26, 21, 40], fill=(60, 64, 70))
    P["time_clock"] = (outline(im), 1)
    im = new(64, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 8, 61, 60], fill=(50, 40, 34))
    for y in (14, 30, 46):
        for x in range(6, 58, 10):
            d.rectangle([x, y, x + 7, y + 12], fill=(150, 150, 160))
    P["cells_rack"] = (outline(im), 1)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 6, 23, 26], fill=(200, 200, 210))
    d.rectangle([10, 8, 21, 12], fill=(60, 60, 70))
    for y in (15, 18, 21):
        d.line([(11, y), (20, y)], fill=(120, 120, 130))
    P["typewriter"] = (outline(im), 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([4, 10, 27, 28], 3, fill=(80, 60, 50))
    d.rectangle([6, 4, 25, 12], fill=(40, 40, 46))
    d.ellipse([12, 16, 19, 23], fill=(200, 200, 210))
    P["camera_bag"] = (outline(im), 0)
    im = new(64, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 6, 61, 28], fill=(120, 100, 80))
    d.rectangle([4, 8, 59, 26], fill=(230, 220, 200))
    for i in range(6):
        d.rectangle([6 + i * 9, 10, 12 + i * 9, 24], fill=(200, 180, 150))
    P["morgue_drawers"] = (outline(im), 1)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 2, 25, 30], fill=(230, 230, 236))
    d.rectangle([8, 4, 23, 12], fill=(220, 60, 60))
    for y in (16, 20, 24):
        d.line([(9, y), (22, y)], fill=(100, 100, 110))
    P["calendar"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 10, 27, 26], fill=(70, 70, 76))
    d.rectangle([6, 12, 25, 24], fill=(60, 140, 90))
    d.rectangle([8, 14, 23, 16], fill=(200, 255, 200))
    P["scanner"] = (outline(im), 0)
    im = new(32, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([14, 0, 17, 60], fill=(120, 124, 130))
    for y in (6, 20, 34):
        d.line([(4, y), (27, y)], fill=(120, 124, 130), width=2)
    d.rectangle([10, 58, 21, 63], fill=(80, 84, 90))
    P["antenna"] = (outline(im), 1)
    im = new(48, 48)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 45, 45], fill=(150, 130, 100))
    d.ellipse([8, 8, 39, 39], fill=(190, 170, 130))
    d.ellipse([18, 18, 29, 29], fill=(50, 40, 30))
    P["well"] = (outline(im), 1)
    im = new(96, 96)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 30, 87, 90], fill=(170, 160, 150))
    d.polygon([(0, 34), (48, 4), (95, 34)], fill=(100, 70, 60))
    d.polygon([(0, 34), (48, 4), (95, 34), (95, 40), (48, 10), (0, 40)], fill=(236, 240, 246))
    d.rectangle([38, 56, 57, 90], fill=(80, 60, 50))
    d.rectangle([16, 44, 30, 58], fill=(60, 70, 90))
    d.rectangle([66, 44, 80, 58], fill=(60, 70, 90))
    P["shed"] = (outline(im), 2)
    im = new(64, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 12, 63, 30], fill=(100, 70, 50))
    for x in range(0, 64, 8):
        d.line([(x, 12), (x, 30)], fill=(80, 56, 40))
    d.rectangle([0, 10, 63, 14], fill=(236, 240, 246))
    P["pier_planks"] = (im, 0)
    im = new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([12, 4, 19, 46], fill=(90, 70, 50))
    d.ellipse([8, 0, 23, 12], fill=(236, 240, 246))
    P["piling"] = (outline(im), 1)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    for x in (6, 14, 22):
        d.line([(x, 28), (x, 8)], fill=(120, 100, 60), width=2)
        d.ellipse([x - 3, 2, x + 3, 12], fill=(110, 70, 40))
    P["cattails"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([4, 12, 27, 28], fill=(236, 240, 246))
    d.ellipse([8, 4, 23, 18], fill=(236, 240, 246))
    d.ellipse([12, 8, 14, 10], fill=(30, 30, 30))
    d.ellipse([17, 8, 19, 10], fill=(30, 30, 30))
    d.rectangle([14, 11, 17, 13], fill=(230, 120, 40))
    P["snowman"] = (outline(im), 1)
    im = new(48, 40)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([4, 14, 43, 34], 5, fill=(70, 60, 50))
    d.ellipse([30, 6, 44, 20], fill=(70, 60, 50))
    d.rectangle([8, 30, 12, 38], fill=(50, 40, 34))
    d.rectangle([34, 30, 38, 38], fill=(50, 40, 34))
    d.line([(4, 18), (0, 10)], fill=(70, 60, 50), width=3)
    P["dog"] = (outline(im), 1)
    im = new(48, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 12, 45, 24], fill=(60, 60, 66))
    d.ellipse([6, 18, 18, 30], fill=(30, 30, 34))
    d.ellipse([30, 18, 42, 30], fill=(30, 30, 34))
    d.line([(24, 12), (32, 2)], fill=(60, 60, 66), width=2)
    d.rectangle([2, 10, 45, 13], fill=(220, 40, 50))
    P["bicycle"] = (outline(im), 1)
    return P


# storefronts and larger buildings built from the siding/roof/door recipe
EXTRA_FACADES = {
    "variety": dict(w=8, h=2, siding="yellow", shade=1, roof="brown", roof_h=2, door="white", door_x=3, windows=[1, 5, 6], neon="neon_amber"),
    "hotel": dict(w=10, h=4, siding="rust", shade=2, roof="slate", roof_h=2, door="dark", door_x=4, windows=[1, 2, 7, 8], tall=True),
    "library": dict(w=8, h=3, siding="grey", shade=1, roof="navy", roof_h=2, door="brown", door_x=3, windows=[1, 6], tall=True),
    "funeral": dict(w=7, h=3, siding="white", shade=2, roof="slate", roof_h=2, door="dark", door_x=3, windows=[1, 5], tall=True),
    "school": dict(w=12, h=3, siding="peach", shade=1, roof="brown", roof_h=2, door="dark", door_x=5, windows=[1, 2, 3, 8, 9, 10], tall=True),
    "bait_shop": dict(w=5, h=2, siding="green", shade=3, roof="rust", roof_h=1, door="brown", door_x=1, windows=[3]),
    "pump_house": dict(w=4, h=2, siding="grey", shade=3, roof="grey", roof_h=1, door="dark", door_x=1, windows=[]),
    "tavern": dict(w=8, h=2, siding="brown", shade=3, roof="rust", roof_h=2, door="red", door_x=3, windows=[1, 6], neon="neon_red"),
    "farmhouse": dict(w=7, h=3, siding="white", shade=1, roof="grey", roof_h=2, door="brown", door_x=3, windows=[1, 5], tall=True),
    "church_old": dict(w=5, h=3, siding="grey", shade=3, roof="grey", roof_h=2, door="dark", door_x=2, windows=[0, 4], tall=True, steeple=True),
    "warden": dict(w=5, h=2, siding="green", shade=2, roof="brown", roof_h=1, door="brown", door_x=2, windows=[0, 4]),
    "power_plant": dict(w=12, h=5, siding="grey", shade=3, roof="slate", roof_h=2, door="dark", door_x=5, windows=[1, 3, 8, 10], tall=True),
    "crew_cabin": dict(w=5, h=2, siding="blue", shade=2, roof="grey", roof_h=1, door="white", door_x=2, windows=[0, 4]),
    "radio_den": dict(w=6, h=2, siding="teal", shade=3, roof="brown", roof_h=2, door="brown", door_x=2, windows=[0, 4]),
}


def extra_characters(adult, child, LONG, BUTTONED, CARDIGAN):
    return {
        "ham": adult("Peach", head="Head 03 - Elderly", hair="Short 06 - Balding", hair_colour="Gray", shirt=(BUTTONED, "Beige"), over=(CARDIGAN, "Olivine"), pants=("Pants 03 - Pants", "Charcoal"), glasses="Brass"),
        "widow": adult("Porcelain", head="Head 03 - Elderly", fem=True, hair="Medium 04 - Bangs & Bun", hair_colour="White", shirt=(LONG, "Black"), over=(CARDIGAN, "Charcoal"), pants=("Pants 03 - Pants", "Black")),
        "nightclerk": adult("Tawny", hair="Short 03 - Curly", hair_colour="Black", shirt=(BUTTONED, "Lavender"), over=(CARDIGAN, "Plum"), pants=("Pants 03 - Pants", "Charcoal")),
        "warden": adult("Honey", hair="Short 04 - Cowlick", hair_colour="Chestnut", shirt=(LONG, "Forest"), over=(CARDIGAN, "Swamp"), pants=("Pants 04 - Cuffed Pants", "Umber"), beard=("Facial Hair 06 - Trimmed Beard", "Chestnut")),
        "towboat": adult("Bronze", hair="Short 01 - Buzzcut", hair_colour="Charcoal", shirt=(LONG, "Navy"), over=(CARDIGAN, "Orange"), pants=("Pants 05 - Overalls", "Denim"), beard=("Facial Hair 05 - Horseshoe Mustache", "Charcoal")),
        "bait": adult("Peach", head="Head 03 - Elderly", hair="Short 06 - Balding", hair_colour="White", shirt=(BUTTONED, "Denim"), over=(CARDIGAN, "Oak"), pants=("Pants 05 - Overalls", "Charcoal"), beard=("Facial Hair 07 - Medium Beard", "White")),
        "undertaker": adult("Ivory", hair="Short 02 - Parted", hair_colour="Gray", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Black"), pants=("Pants 03 - Pants", "Black")),
        "librarian": adult("Brown", head="Head 01 - Feminine", fem=True, hair="Medium 09 - Twists", hair_colour="Black", shirt=(BUTTONED, "Mint"), over=(CARDIGAN, "Navy"), pants=("Pants 03 - Pants", "Charcoal"), glasses="Steel"),
        "barkeep": adult("Tan", hair="Short 05 - Natural", hair_colour="Brown", shirt=(LONG, "Garnet"), over=(CARDIGAN, "Black"), pants=("Pants 03 - Pants", "Black"), beard=("Facial Hair 01 - Walrus Mustache", "Brown")),
        "hollis": adult("Peach", hair="Short 03 - Curly", hair_colour="Blonde", shirt=(LONG, "Olivine"), over=(CARDIGAN, "Bronze"), pants=("Pants 04 - Cuffed Pants", "Umber"), beard=("Facial Hair 07 - Medium Beard", "Blonde")),
        "farmer": adult("Tawny", head="Head 03 - Elderly", hair="Short 06 - Balding", hair_colour="Gray", shirt=(BUTTONED, "Beige"), over=(CARDIGAN, "Coffee"), pants=("Pants 05 - Overalls", "Denim")),
        "hunter": adult("Honey", hair="Short 01 - Buzzcut", hair_colour="Brown", shirt=(LONG, "Orange"), over=(CARDIGAN, "Swamp"), pants=("Pants 04 - Cuffed Pants", "Charcoal"), beard=("Facial Hair 02 - Chevron Mustache", "Brown")),
        "teen": adult("Peach", head="Head 01 - Feminine", fem=True, hair="Medium 01 - Page", hair_colour="Chestnut", hair_behind=True, shirt=(LONG, "Purple"), over=(CARDIGAN, "Denim"), pants=("Pants 03 - Pants", "Denim")),
        "teen2": adult("Tan", hair="Short 04 - Cowlick", hair_colour="Black", shirt=(LONG, "Red"), over=(CARDIGAN, "Navy"), pants=("Pants 03 - Pants", "Denim")),
        "dwight": adult("Peach", hair="Short 02 - Parted", hair_colour="Brown", shirt=(BUTTONED, "Ivory"), over=(CARDIGAN, "Leather"), pants=("Pants 03 - Pants", "Chocolate")),
        "harmon": adult("Porcelain", head="Head 01 - Feminine", fem=True, hair="Medium 02 - Curly", hair_colour="Ash Brown", shirt=(BUTTONED, "Pink"), over=(CARDIGAN, "Tan"), pants=("Pants 03 - Pants", "Charcoal"), glasses="Brass"),
        "cook": adult("Bronze", hair="Short 08 - Flat Top, Fade", hair_colour="Black", shirt=(LONG, "White"), pants=("Pants 03 - Pants", "Charcoal")),
        "nurse": adult("Brown", head="Head 01 - Feminine", fem=True, hair="Medium 07 - Bob, Side Part", hair_colour="Charcoal", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Sky"), pants=("Pants 03 - Pants", "Navy")),
        "penrose": adult("Porcelain", head="Head 03 - Elderly", hair="Short 02 - Parted", hair_colour="Gray", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Charcoal"), pants=("Pants 03 - Pants", "Black")),
        "dot": adult("Peach", head="Head 03 - Elderly", fem=True, hair="Medium 02 - Curly", hair_colour="White", shirt=(BUTTONED, "Lavender"), over=(CARDIGAN, "Mauve"), pants=("Pants 03 - Pants", "Charcoal"), glasses="Brass"),
    }
