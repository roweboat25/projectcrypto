#!/usr/bin/env python3
"""Builds the game's 2D art from Liberated Pixel Cup (LPC Revised) sources.

Sources: https://github.com/ElizaWy/LPC (CC-BY 3.0 / OGA-BY 3.0).
Set LPC_SRC to a checkout of that repo. Every sheet this script touches is
copied into assets/lpc_src/ so the repository stays self-contained, and
assets/CREDITS.md is written from the Credits.txt files next to them.

Outputs:
  assets/tiles/tiles.png + atlas.json + tileset.tres   32px tile atlas
  assets/props/<name>.png + props.json                 scenery and furniture
  assets/facades/<name>.png + facades.json             storefronts built from siding, roof, door and windows
  assets/sprites/<name>.png                            9x4 walk sheets, 64px cells
  assets/portraits/<name>.png                          96px dialogue portraits
Set GEN_PORTRAITS to a folder of generated <name>.png/.jpg faces to use them;
anyone without one gets a close-up of their sprite.
"""
import json
import os
import shutil
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art_extra  # noqa: E402
import art_summer  # noqa: E402
import art_kelly  # noqa: E402
import art_foes  # noqa: E402

from PIL import Image, ImageDraw

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ASSETS = os.path.join(ROOT, "assets")
SRC = os.environ.get("LPC_SRC", "")
LOCAL = os.path.join(ASSETS, "lpc_src")
GEN_PORTRAITS = os.environ.get("GEN_PORTRAITS", "")
T = 32

_used = set()


def src(rel):
    """Path to a source sheet, copying it into assets/lpc_src on first use."""
    _used.add(rel)
    local = os.path.join(LOCAL, rel)
    if os.path.exists(local):
        return local
    if not SRC:
        sys.exit(f"missing {rel}: set LPC_SRC to an ElizaWy/LPC checkout")
    os.makedirs(os.path.dirname(local), exist_ok=True)
    shutil.copy(os.path.join(SRC, rel), local)
    return local


_cache = {}


def sheet(rel):
    if rel not in _cache:
        _cache[rel] = Image.open(src(rel)).convert("RGBA")
    return _cache[rel]


def crop(rel, x, y, w, h):
    return sheet(rel).crop((x, y, x + w, y + h))


def tile(rel, tx, ty):
    return crop(rel, tx * T, ty * T, T, T)


def shade(im, factor):
    """Darken (factor < 1) or lighten an RGBA image, keeping alpha."""
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            px[x, y] = (min(255, int(r * factor)), min(255, int(g * factor)), min(255, int(b * factor)), a)
    return im


# ------------------------------------------------------------------ tiles
W = "Structure/Walls/"
F = "Structure/Floor/"
TW = "Terrain/terrain_winter.png"
PW = W + "Painted Walls.png"


def wall(color, group=0):
    """Painted Walls: 3 columns per colour, 4 rows per group (top, mid, bottom, single)."""
    c = 3 * color
    r = 4 * group
    return {"top": (PW, c, r), "mid": (PW, c, r + 1), "bot": (PW, c, r + 2), "one": (PW, c, r + 3)}


TILES = {
    # winter ground
    "snow": (TW, 3, 1),
    "snow2": (TW, 4, 1),
    "snow3": (TW, 5, 1),
    "snow_drift": (TW, 3, 2),
    "snow_drift2": (TW, 4, 2),
    "snow_drift3": (TW, 5, 2),
    "snow_rock": (TW, 3, 3),
    "snow_rock2": (TW, 4, 3),
    "dirt": (TW, 3, 5),
    "dirt2": (TW, 4, 5),
    "dirt3": (TW, 5, 5),
    "dirt4": (TW, 3, 6),
    "dirt_snow": (TW, 9, 3),
    "dirt_snow2": (TW, 10, 3),
    "dirt_snow3": (TW, 9, 4),
    "water": (TW, 12, 17),
    "water2": (TW, 13, 17),
    "water3": (TW, 14, 17),
    "water_snow_top": (TW, 12, 11),
    "water_snow_top2": (TW, 13, 11),
    "water_snow_top3": (TW, 14, 11),
    # roads: Gritty Dirt darkened in code
    "asphalt": "asphalt",
    "asphalt2": "asphalt2",
    "asphalt_line": "asphalt_line",
    "cement": ("Structure/Platforms/Cement Platform A.png", 1, 2),
    "cement_b": ("Structure/Platforms/Cement Platform A.png", 1, 3),
    "cement_edge": ("Structure/Platforms/Cement Platform A.png", 1, 4),
    "cement_crack": ("Structure/Platforms/Cement Platform A.png", 1, 5),
    # interior floors
    "wood_dark": (F + "Wood Floor A.png", 0, 3),
    "wood_dark2": (F + "Wood Floor A.png", 0, 4),
    "wood_warm": (F + "Wood Floor A.png", 2, 0),
    "wood_warm2": (F + "Wood Floor A.png", 2, 1),
    "wood_grey": (F + "Wood Floor A.png", 1, 3),
    "wood_grey2": (F + "Wood Floor A.png", 1, 4),
    "tile_white": (F + "Tile B.png", 0, 0),
    "tile_blue": (F + "Tile B.png", 1, 0),
    "tile_grey": (F + "Tile C.png", 2, 2),
    "tile_grey2": (F + "Tile C.png", 3, 2),
    "tile_dark": (F + "Tile C.png", 2, 6),
    "tile_cream": (F + "Tile A.png", 0, 0),
    "carpet_navy": (F + "Geometric Carpet C.png", 2, 1),
    "carpet_red": (F + "Geometric Carpet C.png", 8, 1),
    "diamond_dark": (F + "Diamond Tile A.png", 2, 1),
    "herringbone": (F + "Herringbone A.png", 1, 0),
    "subfloor": (F + "Subfloor.png", 0, 0),
    # interior walls
    "brick_grey_top": (W + "Brick Wall A.png", 3, 0),
    "brick_grey_mid": (W + "Brick Wall A.png", 3, 1),
    "brick_grey_bot": (W + "Brick Wall A.png", 3, 2),
    "brick_red_top": (W + "Brick Wall A.png", 3, 3),
    "brick_red_bot": (W + "Brick Wall A.png", 3, 5),
    "stone_top": (W + "Jagged Stone Walls.png", 0, 6),
    "stone_mid": (W + "Jagged Stone Walls.png", 0, 7),
    "stone_bot": (W + "Jagged Stone Walls.png", 0, 8),
    "drywall_top": (W + "Drywall.png", 0, 0),
    "drywall_mid": (W + "Drywall.png", 0, 1),
    "drywall_bot": (W + "Drywall.png", 0, 2),
    # windows (Stone Windows A: columns dark / day / lit; rows 1-2 = 2-tall window)
    "window_dark_top": ("Structure/Windows/Stone Windows A.png", 0, 1),
    "window_dark_bot": ("Structure/Windows/Stone Windows A.png", 0, 2),
    "window_lit_top": ("Structure/Windows/Stone Windows A.png", 2, 1),
    "window_lit_bot": ("Structure/Windows/Stone Windows A.png", 2, 2),
    "window_day_top": ("Structure/Windows/Stone Windows A.png", 1, 1),
    "window_day_bot": ("Structure/Windows/Stone Windows A.png", 1, 2),
    # door frames (Doorframe A: 3x2 per frame, cols 0-2 cream, 3-5 grey)
    "frame_l_top": ("Structure/Doors/32x48px Doors/Doorframe A.png", 3, 0),
    "frame_r_top": ("Structure/Doors/32x48px Doors/Doorframe A.png", 5, 0),
    "frame_c_top": ("Structure/Doors/32x48px Doors/Doorframe A.png", 4, 0),
    "frame_l_bot": ("Structure/Doors/32x48px Doors/Doorframe A.png", 3, 1),
    "frame_r_bot": ("Structure/Doors/32x48px Doors/Doorframe A.png", 5, 1),
    "frame_c_bot": ("Structure/Doors/32x48px Doors/Doorframe A.png", 4, 1),
    "void": None,
}
TILES.update(art_extra.EXTRA_TILES)
TILES.update(art_summer.SUMMER_TILES)
TILES.update(art_kelly.KELLY_TILES)
# painted walls, by colour index (3-column blocks left to right) and row group
WALL_COLOURS = {
    "grey": wall(3, 0),
    "cream": wall(2, 0),
    "blue": wall(0, 0),
    "purple": wall(5, 1),
    "navy": wall(4, 1),
    "peach": wall(1, 0),
}
for _name, _parts in WALL_COLOURS.items():
    for _part, _loc in _parts.items():
        TILES[f"wall_{_name}_{_part}"] = _loc

ATLAS_COLS = 16
SOLID_PREFIXES = ("wall_", "brick_", "stone_", "drywall_", "window_", "frame_", "void", "water", "cement_edge") + art_kelly.SOLID_KELLY


def special_tile(name):
    if name in art_extra.EXTRA_TILES and isinstance(art_extra.EXTRA_TILES[name], str):
        return art_extra.special_tile_extra(name, tile)
    if name in art_summer.SUMMER_TILES and isinstance(art_summer.SUMMER_TILES[name], str):
        return art_summer.special_tile_summer(name, tile)
    if name in art_kelly.KELLY_TILES:
        return art_kelly.special_tile_kelly(name, tile)
    if name == "void":
        return Image.new("RGBA", (T, T), (6, 6, 10, 255))
    base = shade(tile(F + "Gritty Dirt.png", 1, 1), 0.42)
    if name == "asphalt2":
        base = shade(tile(F + "Gritty Dirt.png", 1, 1), 0.46)
    if name == "asphalt_line":
        d = ImageDraw.Draw(base)
        d.rectangle([14, 4, 17, 14], fill=(196, 160, 60, 255))
        d.rectangle([14, 20, 17, 30], fill=(196, 160, 60, 255))
    return base


def build_tiles():
    names = list(TILES)
    rows = (len(names) + ATLAS_COLS - 1) // ATLAS_COLS
    atlas = Image.new("RGBA", (ATLAS_COLS * T, rows * T), (0, 0, 0, 0))
    index = {}
    for i, name in enumerate(names):
        ax, ay = i % ATLAS_COLS, i // ATLAS_COLS
        loc = TILES[name]
        im = special_tile(name) if loc is None or isinstance(loc, str) else tile(*loc)
        atlas.alpha_composite(im, (ax * T, ay * T))
        index[name] = [ax, ay]
    out = os.path.join(ASSETS, "tiles")
    os.makedirs(out, exist_ok=True)
    atlas.save(os.path.join(out, "tiles.png"))
    with open(os.path.join(out, "atlas.json"), "w") as f:
        json.dump(index, f, indent=1, sort_keys=True)
    write_tileset(os.path.join(out, "tileset.tres"), index)
    print("tiles:", len(names), atlas.size)


def write_tileset(path, index):
    lines = [
        '[gd_resource type="TileSet" load_steps=2 format=3]', '',
        '[ext_resource type="Texture2D" path="res://assets/tiles/tiles.png" id="1_tiles"]', '',
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_main"]',
        'texture = ExtResource("1_tiles")',
        f'texture_region_size = Vector2i({T}, {T})',
    ]
    h = T // 2
    for name, (x, y) in sorted(index.items(), key=lambda kv: (kv[1][1], kv[1][0])):
        lines.append(f"{x}:{y}/0 = 0")
        if name.startswith(SOLID_PREFIXES):
            lines.append(f"{x}:{y}/0/physics_layer_0/polygon_0/points = "
                         f"PackedVector2Array({-h}, {-h}, {h}, {-h}, {h}, {h}, {-h}, {h})")
    lines += ['', '[resource]', f'tile_size = Vector2i({T}, {T})',
              'physics_layer_0/collision_layer = 1', 'physics_layer_0/collision_mask = 1',
              'sources/0 = SubResource("TileSetAtlasSource_main")', '']
    with open(path, "w") as f:
        f.write("\n".join(lines))


# ------------------------------------------------------------------ props
O = "Objects/Furniture/"
S = "Objects/Small Items/"
WI = "Objects/Wall Items/"
TR = "Terrain/trees_winter.png"
PL = "Terrain/plants_winter.png"
# name: (sheet, (x, y, w, h) in pixels, solid rows of 32px from the bottom)
PROPS = {
    # outdoors, winter
    "tree_snow": (TR, (128, 0, 96, 128), 1),
    "tree_snow2": (TR, (320, 0, 96, 160), 1),
    "tree_tall": (TR, (416, 32, 96, 160), 1),
    "tree_dead": (TR, (224, 32, 96, 96), 1),
    "pine_snow": (TR, (128, 384, 96, 128), 1),
    "pine_snow2": (TR, (224, 384, 96, 128), 1),
    "pine_small": (TR, (320, 416, 96, 128), 1),
    "pine_tall": (TR, (416, 352, 96, 160), 1),
    "bush_snow": (PL, (0, 0, 32, 32), 1),
    "bush_snow2": (PL, (32, 0, 32, 32), 1),
    "bush_berry": (PL, (192, 0, 32, 32), 1),
    "tuft_snow": (PL, (256, 0, 32, 64), 0),
    "tuft_snow2": (PL, (288, 0, 32, 64), 0),
    "grass_tall_snow": (PL, (352, 0, 32, 64), 0),
    "shrub_green": (PL, (0, 64, 32, 64), 1),
    "lamp_post": (O + "Lighting, Outdoors.png", (0, 0, 32, 96), 1),
    "lamp_post_off": (O + "Lighting, Outdoors.png", (32, 0, 32, 96), 1),
    "mailboxes": (WI + "Mailboxes (tiling).png", (32, 32, 32, 32), 1),
    "fence_h": ("Structure/Fences/Plain Fence A.png", (0, 0, 96, 32), 1),
    "fence_iron": ("Structure/Fences/Ornamental Fence B.png", (0, 0, 96, 32), 1),
    "rock_big": ("Terrain/Rocks, Cliffs.png", (0, 0, 64, 64), 1),
    "rock_small": ("Terrain/Rocks, Cliffs.png", (96, 64, 32, 32), 1),
    "crate": (O + "Crate.png", (0, 0, 32, 64), 1),
    "barrel": (O + "Barrel.png", (0, 0, 32, 64), 1),
    "bin": (O + "Bin.png", (64, 0, 32, 64), 1),
    "chimney": ("Structure/Roofing/Brick Chimney A.png", (32, 0, 32, 64), 0),
    "chimney_dark": ("Structure/Roofing/Brick Chimney A.png", (128, 128, 32, 64), 0),
    # whole houses
    "house_brick": ("Structure/Structures/Brick House A.png", (64, 0, 192, 224), 4),
    "house_brick_b": ("Structure/Structures/Brick House B.png", (0, 0, 192, 192), 4),
    "house_panel": ("Structure/Structures/Paneled House A.png", (0, 0, 160, 160), 3),
    # interiors
    "counter": (O + "Countertop.png", (64, 0, 64, 64), 1),
    "counter_l": (O + "Countertop.png", (0, 0, 32, 64), 1),
    "counter_r": (O + "Countertop.png", (160, 0, 32, 64), 1),
    "desk_wood": (O + "Desk, Office.png", (0, 0, 64, 64), 2),
    "desk_long_wood": (O + "Desk, Office.png", (0, 0, 192, 64), 2),
    "desk_grey": (O + "Desk, Office.png", (0, 128, 64, 64), 2),
    "chair_office": (O + "Seating/Chair, Office.png", (0, 0, 32, 32), 1),
    "chair_office_back": (O + "Seating/Chair, Office.png", (0, 32, 32, 32), 1),
    "chair_front": (O + "Seating/Chair, Dining E.png", (0, 0, 32, 32), 1),
    "chair_back": (O + "Seating/Chair, Dining E.png", (32, 0, 32, 32), 1),
    "table": (O + "Table, Card.png", (0, 0, 96, 64), 2),
    "table_wood": (O + "Table, Card.png", (0, 128, 96, 64), 2),
    "table_rough": (O + "Table, Rough Wood.png", (0, 0, 96, 64), 2),
    "sofa_brown": (O + "Seating/Sofa, Casual A.png", (320, 128, 96, 48), 1),
    "sofa_grey": (O + "Seating/Sofa, Casual A.png", (0, 0, 96, 48), 1),
    "armchair_grey": (O + "Seating/Sofa, Casual A.png", (96, 0, 64, 48), 1),
    "shelf": (O + "Shelf.png", (0, 0, 96, 32), 1),
    "bookcase": (O + "Cabinet.png", (64, 96, 64, 64), 1),
    "cabinet": (O + "Cabinet.png", (0, 0, 64, 64), 1),
    "copy_machine": (O + "Copy Machine.png", (0, 0, 64, 64), 1),
    "water_cooler": (O + "Water Cooler.png", (0, 0, 32, 64), 1),
    "vending": (O + "Vending Machine.png", (0, 0, 64, 64), 1),
    "fridge": (O + "Fridge.png", (0, 0, 32, 64), 1),
    "oven": (O + "Oven, Modern.png", (0, 0, 32, 64), 1),
    "sink": (O + "Sink, Countertop.png", (0, 0, 32, 64), 1),
    "coffee_maker": (S + "Coffee Maker.png", (0, 0, 32, 64), 1),
    "dishes": (S + "Dishes A.png", (0, 0, 32, 32), 0),
    "phone": (S + "Rotary Phones.png", (0, 0, 32, 32), 0),
    "paper": (S + "Loose Paper.png", (32, 64, 32, 32), 0),
    "paper2": (S + "Loose Paper.png", (0, 32, 32, 32), 0),
    "box": (S + "Boxes.png", (0, 0, 32, 32), 1),
    "lamp_floor": (O + "Lighting, Floor.png", (0, 0, 32, 64), 1),
    "lamp_table": (S + "Lighting, Table.png", (160, 32, 32, 32), 0),
    "end_table": (O + "End Table.png", (0, 0, 32, 32), 1),
    "planter": (O + "Planter.png", (0, 0, 32, 64), 1),
    "rug_red": (O + "Rugs/Swirling Vine Rug.png", (0, 64, 96, 64), 0),
    "rug_blue": (O + "Rugs/Swirling Vine Rug.png", (0, 0, 96, 64), 0),
    "painting": (WI + "Paintings, Landscape.png", (0, 0, 64, 32), 0),
    "poster": (WI + "Posters.png", (0, 32, 32, 32), 0),
    "poster2": (WI + "Posters.png", (96, 32, 32, 32), 0),
    "curtain": (WI + "Curtains.png", (0, 0, 64, 96), 0),
    "bed_single": (O + "Beds/Beds, Single B.png", (256, 192, 64, 96), 2),
    "bed_wood": (O + "Beds/Beds, Single C.png", (0, 0, 64, 96), 2),
    "dresser": (O + "Dresser.png", (160, 0, 64, 64), 1),
    "mirror_standing": (O + "Mirror, Standing.png", (0, 0, 64, 64), 1),
    "clock": (O + "Clock, Grandfather.png", (0, 0, 32, 96), 1),
    "fireplace": (O + "Fireplace.png", (0, 0, 96, 96), 1),
    "stone_slab": (O + "Stone Slab.png", (0, 0, 64, 32), 1),
    "pillar": ("Structure/Pillars/Stone Pillar A.png", (192, 0, 32, 96), 1),
    "bars": ("Structure/Doors/32x48px Doors/Barred Prison Door A.png", (224, 0, 32, 48), 1),
}

PROPS.update(art_extra.EXTRA_PROPS)
PROPS.update(art_summer.SUMMER_PROPS)
PROPS.update(art_kelly.KELLY_PROPS)


def trim(im):
    bbox = im.getbbox()
    if bbox is None:
        return im
    return im.crop((0, bbox[1], im.size[0], bbox[3]))


def build_props():
    out = os.path.join(ASSETS, "props")
    os.makedirs(out, exist_ok=True)
    for f in os.listdir(out):
        if f.endswith(".png"):
            os.remove(os.path.join(out, f))
    index = {}
    for name, (rel, rect, solid) in PROPS.items():
        im = crop(rel, *rect)
        if im.getbbox() is None:
            print("  WARNING empty prop", name)
        im = trim(im)
        im.save(os.path.join(out, name + ".png"))
        index[name] = {"w": im.size[0], "h": im.size[1], "solid": solid}
    for name, (im, solid) in list(custom_props().items()) + list(art_extra.extra_custom_props().items()) + list(art_summer.summer_custom_props(outline, crop).items()) + list(art_kelly.kelly_custom_props(outline, crop).items()):
        im.save(os.path.join(out, name + ".png"))
        index[name] = {"w": im.size[0], "h": im.size[1], "solid": solid}
    with open(os.path.join(out, "props.json"), "w") as f:
        json.dump(index, f, indent=1, sort_keys=True)
    print("props:", len(index))


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


def custom_props():
    """Things LPC has no sheet for: 1994 cars, a gas pump, a phone booth, a jukebox, pews."""
    P = {}

    def new(w, h):
        return Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # cars seen from above-front: a station wagon (the Office's), a sedan with no plates, a pickup
    for name, body, light, long in (("wagon", (112, 92, 60), (150, 128, 86), True), ("sedan", (24, 24, 30), (54, 54, 64), False),
                                    ("pickup", (120, 40, 36), (160, 70, 60), False), ("buick", (60, 90, 130), (96, 130, 170), False)):
        w = 80 if long else 64
        im = new(w, 40)
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([3, 12, w - 4, 34], 6, fill=body)
        d.rounded_rectangle([14, 4, w - 14, 22], 5, fill=light)
        d.rectangle([17, 7, w - 17, 18], fill=(150, 176, 194))
        d.line([w // 2, 7, w // 2, 18], fill=light)
        d.rectangle([5, 24, w - 6, 30], fill=light)
        for x in (10, w - 16):
            d.ellipse([x, 30, x + 10, 39], fill=(30, 28, 34))
            d.ellipse([x + 3, 33, x + 7, 36], fill=(120, 120, 130))
        d.rectangle([4, 16, 7, 19], fill=(255, 230, 160))
        d.rectangle([w - 8, 16, w - 5, 19], fill=(255, 230, 160))
        # snow on the roof
        d.rounded_rectangle([16, 5, w - 16, 9], 2, fill=(226, 236, 244))
        P[name] = (outline(im), 1)

    # gas pump
    im = new(32, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([8, 6, 23, 44], fill=(150, 40, 40))
    d.rectangle([10, 9, 21, 20], fill=(230, 230, 220))
    d.rectangle([12, 12, 19, 14], fill=(40, 40, 50))
    d.rectangle([12, 16, 19, 18], fill=(40, 40, 50))
    d.rectangle([24, 14, 27, 34], fill=(40, 40, 50))
    d.rectangle([10, 24, 21, 40], fill=(120, 28, 28))
    d.rectangle([4, 44, 27, 47], fill=(90, 90, 100))
    P["gas_pump"] = (outline(im), 1)

    # gas canopy post and sign pole
    im = new(32, 96)
    d = ImageDraw.Draw(im)
    d.rectangle([13, 10, 18, 92], fill=(190, 196, 206))
    d.rectangle([2, 0, 29, 12], fill=(226, 60, 60))
    d.rectangle([4, 2, 27, 10], fill=(250, 240, 220))
    d.rectangle([8, 5, 23, 7], fill=(226, 60, 60))
    P["gas_sign"] = (outline(im), 1)

    # phone booth
    im = new(32, 64)
    d = ImageDraw.Draw(im)
    d.rectangle([3, 2, 28, 62], fill=(40, 70, 140))
    d.rectangle([6, 8, 25, 50], fill=(170, 200, 220))
    d.rectangle([8, 10, 23, 48], fill=(120, 160, 200))
    d.rectangle([5, 52, 26, 60], fill=(30, 50, 100))
    d.rectangle([3, 2, 28, 6], fill=(230, 230, 230))
    P["phone_booth"] = (outline(im), 1)

    # mailbox (US blue)
    im = new(32, 48)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([6, 6, 25, 30], 6, fill=(40, 60, 130))
    d.rectangle([9, 12, 22, 16], fill=(20, 30, 70))
    d.rectangle([9, 30, 12, 46], fill=(40, 60, 130))
    d.rectangle([19, 30, 22, 46], fill=(40, 60, 130))
    P["mailbox"] = (outline(im), 1)

    # jukebox
    im = new(32, 64)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([3, 4, 28, 62], 8, fill=(150, 60, 40))
    d.rounded_rectangle([7, 8, 24, 30], 6, fill=(240, 200, 90))
    d.rectangle([9, 14, 22, 26], fill=(80, 40, 60))
    d.rectangle([6, 36, 25, 48], fill=(230, 80, 80))
    d.rectangle([6, 50, 25, 58], fill=(60, 30, 30))
    for y in (38, 42, 46):
        d.line([(8, y), (23, y)], fill=(255, 230, 160))
    P["jukebox"] = (outline(im), 1)

    # pew (church bench)
    im = new(64, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 61, 10], fill=(110, 70, 40))
    d.rectangle([2, 10, 61, 18], fill=(140, 92, 54))
    d.rectangle([2, 18, 61, 22], fill=(90, 56, 30))
    for x in (4, 56):
        d.rectangle([x, 20, x + 3, 30], fill=(90, 56, 30))
    P["pew"] = (outline(im), 1)

    # altar
    im = new(64, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 14, 59, 44], fill=(220, 214, 200))
    d.rectangle([4, 14, 59, 20], fill=(240, 236, 226))
    d.rectangle([8, 24, 55, 40], fill=(150, 40, 50))
    d.rectangle([28, 2, 35, 20], fill=(210, 180, 90))
    d.rectangle([24, 6, 39, 9], fill=(210, 180, 90))
    P["altar"] = (outline(im), 1)

    # diner booth and stools
    im = new(64, 48)
    d = ImageDraw.Draw(im)
    d.rectangle([2, 4, 14, 44], fill=(190, 50, 60))
    d.rectangle([49, 4, 61, 44], fill=(190, 50, 60))
    d.rectangle([16, 14, 47, 36], fill=(230, 230, 220))
    d.rectangle([18, 16, 45, 34], fill=(200, 200, 190))
    d.rectangle([2, 4, 14, 10], fill=(230, 90, 100))
    d.rectangle([49, 4, 61, 10], fill=(230, 90, 100))
    P["booth"] = (outline(im), 1)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([8, 6, 23, 18], fill=(190, 50, 60))
    d.rectangle([14, 18, 17, 28], fill=(180, 180, 190))
    d.rectangle([10, 27, 21, 30], fill=(120, 120, 130))
    P["stool"] = (outline(im), 1)

    # neon sign (a glowing bar used over doors), and a bulletin board
    im = new(64, 24)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, 63, 23], 4, fill=(30, 24, 36))
    d.rounded_rectangle([4, 4, 59, 19], 3, fill=(224, 48, 60))
    d.rounded_rectangle([8, 8, 55, 15], 2, fill=(255, 170, 170))
    P["neon_red"] = (im, 0)
    im = new(64, 24)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, 63, 23], 4, fill=(30, 24, 36))
    d.rounded_rectangle([4, 4, 59, 19], 3, fill=(232, 166, 74))
    d.rounded_rectangle([8, 8, 55, 15], 2, fill=(255, 230, 170))
    P["neon_amber"] = (im, 0)

    # clue marks on the ground: prints, a melted ring, a glow, a film canister, fur
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    for (x, y) in ((6, 8), (18, 4), (10, 20), (22, 16)):
        d.ellipse([x, y, x + 5, y + 8], fill=(110, 120, 140, 200))
        d.line([(x + 2, y), (x + 2, y - 4)], fill=(110, 120, 140, 200), width=2)
        d.line([(x, y + 1), (x - 3, y - 2)], fill=(110, 120, 140, 200))
        d.line([(x + 5, y + 1), (x + 8, y - 2)], fill=(110, 120, 140, 200))
    P["clue_prints"] = (im, 0)
    im = new(64, 48)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 6, 61, 42], fill=(70, 60, 50, 230))
    d.ellipse([10, 12, 53, 36], fill=(40, 36, 32, 240))
    P["clue_ring"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.ellipse([2, 10, 29, 28], fill=(80, 200, 180, 120))
    d.ellipse([8, 14, 23, 24], fill=(140, 240, 220, 160))
    P["clue_glow"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([10, 10, 21, 24], 2, fill=(40, 40, 46))
    d.rectangle([12, 8, 19, 11], fill=(200, 190, 60))
    d.line([(21, 16), (30, 20)], fill=(90, 70, 40), width=2)
    P["clue_film"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    for (x, y) in ((8, 10), (14, 14), (20, 9), (12, 20)):
        d.line([(x, y), (x + 4, y - 6)], fill=(150, 150, 160), width=2)
        d.line([(x + 2, y + 1), (x + 7, y - 3)], fill=(170, 170, 180), width=1)
    P["clue_fur"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([4, 4, 27, 27], fill=(120, 150, 180, 160))
    d.line([(8, 8), (14, 24)], fill=(230, 240, 250), width=2)
    d.line([(14, 6), (20, 22)], fill=(230, 240, 250), width=2)
    d.line([(20, 8), (26, 24)], fill=(230, 240, 250), width=2)
    P["clue_scratch"] = (im, 0)
    im = new(32, 32)
    d = ImageDraw.Draw(im)
    d.rectangle([6, 20, 25, 26], fill=(120, 110, 100))
    d.rectangle([8, 16, 12, 20], fill=(90, 80, 70))
    d.rectangle([19, 16, 23, 20], fill=(90, 80, 70))
    P["clue_bed"] = (im, 0)
    return P


# ---------------------------------------------------------------- facades
SIDING = W + "Siding, Plain.png"
ROOF = "Structure/Roofing/Flat Shingle Roof A.png"
DOORS = "Structure/Doors/32x48px Doors/12 Panel Door A.png"
WINDOWS = "Structure/Windows/Stone Windows A.png"
# siding colour blocks are 5 columns wide: left edge, three middles, right edge; row groups of 3 by shade
SIDING_COLOURS = {"white": 0, "grey": 1, "brown": 2, "rust": 3, "yellow": 4, "green": 5, "teal": 6, "blue": 7, "red": 8, "peach": 9}
# roof colour blocks: (col offset, row offset) of the 12x4 block
ROOF_COLOURS = {"grey": (0, 0), "brown": (12, 0), "slate": (0, 4), "rust": (12, 4), "navy": (0, 8), "orange": (12, 8)}
# closed doors: (col, row) of the 32x48 door
DOOR_COLOURS = {"tan": (7, 0), "brown": (7, 3), "dark": (7, 21), "red": (21, 0), "blue": (21, 3), "green": (21, 6), "white": (21, 12), "grey": (21, 18)}

# name: dict(w, h (wall tiles tall), siding, shade (0 light .. 3 dark), roof, roof_h, door (colour), door_x (tile), windows [tile x...], window (dark/day/lit), sign colour
FACADES = {
    "diner": dict(w=9, h=2, siding="red", shade=1, roof="grey", roof_h=2, door="white", door_x=4, windows=[1, 2, 6, 7], neon="neon_red"),
    "register": dict(w=7, h=3, siding="brown", shade=2, roof="slate", roof_h=2, door="dark", door_x=3, windows=[1, 5], tall=True),
    "sheriff": dict(w=7, h=2, siding="white", shade=1, roof="navy", roof_h=2, door="blue", door_x=3, windows=[1, 5]),
    "gas": dict(w=6, h=2, siding="white", shade=0, roof="rust", roof_h=1, door="red", door_x=1, windows=[3, 4], neon="neon_amber"),
    "motel": dict(w=12, h=2, siding="teal", shade=2, roof="brown", roof_h=2, door="white", door_x=1, windows=[3, 5, 7, 9, 11], doors=[1, 4, 8], neon="neon_red"),
    "church": dict(w=6, h=4, siding="white", shade=0, roof="slate", roof_h=2, door="brown", door_x=2, windows=[0, 5], tall=True, steeple=True),
    "garage": dict(w=5, h=2, siding="grey", shade=3, roof="grey", roof_h=1, door="dark", door_x=2, windows=[]),
}

FACADES.update(art_extra.EXTRA_FACADES)
FACADES.update(art_summer.SUMMER_FACADES)
FACADES.update(art_kelly.KELLY_FACADES)


def siding_tile(colour, shade, part, row):
    c = SIDING_COLOURS[colour] * 5
    col = {"l": c, "m": c + 1 + (row % 3), "r": c + 4}[part]
    return tile(SIDING, col, shade * 3 + row)


def roof_tile(colour, part, row):
    cx, cy = ROOF_COLOURS[colour]
    col = {"l": cx + 1, "m": cx + 2, "r": cx + 3}[part]
    return tile(ROOF, col, cy + row)


def build_facade(name, spec):
    w, h = spec["w"], spec["h"]
    rh = spec["roof_h"]
    steeple = 3 if spec.get("steeple") else 0
    H = steeple + rh + h
    im = Image.new("RGBA", (w * T, H * T), (0, 0, 0, 0))
    # roof
    for y in range(rh):
        rrow = 0 if y == 0 else (2 if y == rh - 1 else 1)
        if rh == 1:
            rrow = 2
        for x in range(w):
            part = "l" if x == 0 else ("r" if x == w - 1 else "m")
            im.alpha_composite(roof_tile(spec["roof"], part, rrow), (x * T, (steeple + y) * T))
    # walls
    for y in range(h):
        wrow = 0 if y == 0 else (2 if y == h - 1 else 1)
        for x in range(w):
            part = "l" if x == 0 else ("r" if x == w - 1 else "m")
            im.alpha_composite(siding_tile(spec["siding"], spec["shade"], part, wrow), (x * T, (steeple + rh + y) * T))
    wall_top = (steeple + rh) * T
    # windows: 2 tall when the wall is 3+ tall, else the short window
    for x in spec["windows"]:
        if spec.get("tall"):
            win = crop(WINDOWS, 0, 32, 32, 64)
            im.alpha_composite(win, (x * T, wall_top + (h - 2) * T - 16))
        else:
            win = crop(WINDOWS, 0, 96, 32, 32)
            im.alpha_composite(win, (x * T, wall_top + 6))
    # doors
    dc, dr = DOOR_COLOURS[spec["door"]]
    door = crop(DOORS, dc * T, dr * T, 32, 48)
    for x in spec.get("doors", [spec["door_x"]]):
        im.alpha_composite(door, (x * T, H * T - 48))
    # steeple: a narrow white tower with a dark roof cap
    if steeple:
        sx = (w // 2) * T
        for y in range(3):
            wrow = 0 if y == 0 else 1
            im.alpha_composite(siding_tile(spec["siding"], 1, "l", wrow).crop((0, 0, 16, 32)), (sx, y * T))
            im.alpha_composite(siding_tile(spec["siding"], 1, "r", wrow).crop((16, 0, 32, 32)), (sx + 16, y * T))
        d = ImageDraw.Draw(im)
        d.polygon([(sx - 6, 8), (sx + 16, -20), (sx + 38, 8)], fill=(50, 54, 70))
        d.rectangle([sx + 14, 10, sx + 17, 22], fill=(220, 210, 180))
        d.rectangle([sx + 10, 14, sx + 21, 16], fill=(220, 210, 180))
        im.alpha_composite(crop(WINDOWS, 0, 96, 32, 32), (sx, 40))
    return im, {"w": w * T, "h": H * T, "wall_h": h * T, "solid_h": (rh + h) * T, "door_x": spec["door_x"] * T, "doors": [x * T for x in spec.get("doors", [spec["door_x"]])], "neon": spec.get("neon", "")}


def build_facades():
    out = os.path.join(ASSETS, "facades")
    os.makedirs(out, exist_ok=True)
    index = {}
    for name, spec in FACADES.items():
        im, info = build_facade(name, spec)
        im.save(os.path.join(out, name + ".png"))
        index[name] = info
    with open(os.path.join(out, "facades.json"), "w") as f:
        json.dump(index, f, indent=1, sort_keys=True)
    print("facades:", len(index))


# ------------------------------------------------------------- characters
C = "Characters/"
MT = C + "Clothing/Masculine, Thin/"
FT = C + "Clothing/Feminine, Thin/"


def layer_paths(kind, item, colour=None):
    base = f"{kind}/{item}" if item else kind
    if colour:
        base = f"{base}/{colour}"
    return base + "/Walk.png", base + "/Idle.png"


# Output sheet: 4 rows (down, left, right, up) x 9 columns (idle, walk 1-8), 64px cells.
LPC_ROWS = {"up": 0, "left": 1, "down": 2, "right": 3}
OUT_ROWS = ["down", "left", "right", "up"]


def compose(layers, out_path, tint_regions=None):
    walk = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    idle = Image.new("RGBA", (192, 256), (0, 0, 0, 0))
    for wrel, irel in layers:
        w = sheet(wrel)
        if w.size != walk.size:
            w = w.crop((0, 0, 512, 256))
        walk.alpha_composite(w)
        idle.alpha_composite(sheet(irel).crop((0, 0, 192, 256)))
    if tint_regions:
        walk = tint(walk, tint_regions, 8)
        idle = tint(idle, tint_regions, 3)
    out = Image.new("RGBA", (9 * 64, 4 * 64), (0, 0, 0, 0))
    for r, d in enumerate(OUT_ROWS):
        lr = LPC_ROWS[d]
        out.alpha_composite(idle.crop((0, lr * 64, 64, lr * 64 + 64)), (0, r * 64))
        for f in range(8):
            out.alpha_composite(walk.crop((f * 64, lr * 64, f * 64 + 64, lr * 64 + 64)), ((f + 1) * 64, r * 64))
    out.save(out_path)


def tint(im, regions, cols):
    """Recolour inside a band of each cell (dresses the children, who have no clothing layers).
    regions: list of (y0, y1, (r, g, b)) in cell coordinates."""
    px = im.load()
    for cy in range(4):
        for cx in range(cols):
            for (y0, y1, rgb) in regions:
                for y in range(cy * 64 + y0, cy * 64 + y1):
                    for x in range(cx * 64, cx * 64 + 64):
                        r, g, b, a = px[x, y]
                        if a == 0:
                            continue
                        lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
                        lum = 0.45 + lum * 0.7
                        px[x, y] = (min(255, int(rgb[0] * lum)), min(255, int(rgb[1] * lum)), min(255, int(rgb[2] * lum)), a)
    return im


def adult(skin, head="Head 02 - Masculine", hair=None, hair_colour="Black", shirt=("Shirt 01 - Longsleeve Shirt", "Gray"),
          pants=("Pants 03 - Pants", "Charcoal"), shoes=("Shoes 02 - Boots", "Black"), over=None, glasses=None,
          beard=None, fem=False, hair_behind=False):
    cl = FT if fem else MT
    body = "Body 01 - Feminine, Thin" if fem else "Body 02 - Masculine, Thin"
    layers = []
    if hair_behind and hair:
        layers.append(layer_paths(C + "Hair", hair + "/_Behind", hair_colour))
    layers.append(layer_paths(C + "Body", body, skin))
    if shoes:
        layers.append(layer_paths(cl + "Feet", shoes[0], shoes[1]))
    if pants:
        layers.append(layer_paths(cl + "Legs", pants[0], pants[1]))
    if shirt:
        layers.append(layer_paths(cl + "Torso", shirt[0], shirt[1]))
    if over:
        layers.append(layer_paths(cl + "Torso 2", over[0], over[1]))
    layers.append(layer_paths(C + "Head", head, skin))
    if beard:
        layers.append(layer_paths(C + "Hair", beard[0], beard[1]))
    if hair:
        layers.append(layer_paths(C + "Hair", hair, hair_colour))
    if glasses:
        layers.append(layer_paths(C + "Head Accessories", "Eyewear 01 - Glasses", glasses))
    return layers


def child(skin):
    return [
        (C + "Children/Body/" + skin + "/walk.png", C + "Children/Body/" + skin + "/idle.png"),
        (C + "Children/Head/Head 01 - Default/" + skin + "/walk.png", C + "Children/Head/Head 01 - Default/" + skin + "/idle.png"),
    ]


BUTTONED = "Shirt 07 - Buttoned Longsleeve Shirt"
LONG = "Shirt 01 - Longsleeve Shirt"
CARDIGAN = "Sweater 01 - Cardigan"
# Winter 1994, so everyone wears a cardigan over a shirt as a stand-in for a coat.
CHARACTERS = {
    # the party
    "player": adult("Tan", hair="Short 02 - Parted", hair_colour="Brown", shirt=(BUTTONED, "Dove"), over=(CARDIGAN, "Navy"), pants=("Pants 03 - Pants", "Charcoal")),
    "miriam": adult("Peach", head="Head 01 - Feminine", fem=True, hair="Medium 04 - Bangs & Bun", hair_colour="Blonde", shirt=(LONG, "Ivory"), over=(CARDIGAN, "Tan"), pants=("Pants 03 - Pants", "Chocolate"), glasses="Steel"),
    "teddy": adult("Honey", hair="Short 04 - Cowlick", hair_colour="Chestnut", shirt=(BUTTONED, "Linen"), over=(CARDIGAN, "Leather"), pants=("Pants 04 - Cuffed Pants", "Umber"), beard=("Facial Hair 06 - Trimmed Beard", "Chestnut")),
    "june": adult("Tawny", head="Head 01 - Feminine", fem=True, hair="Medium 01 - Page", hair_colour="Raven", hair_behind=True, shirt=(LONG, "Charcoal"), over=(CARDIGAN, "Forest"), pants=("Pants 03 - Pants", "Black")),
    "ruth": adult("Porcelain", head="Head 03 - Elderly", fem=True, hair="Medium 04 - Bangs & Bun", hair_colour="Gray", shirt=(BUTTONED, "Mauve"), over=(CARDIGAN, "Plum"), pants=("Pants 03 - Pants", "Charcoal")),
    "elijah": adult("Brown", hair="Short 05 - Natural", hair_colour="Charcoal", shirt=(BUTTONED, "Smoke"), over=(CARDIGAN, "Charcoal"), pants=("Pants 03 - Pants", "Black")),
    "dale": adult("Peach", hair="Short 01 - Buzzcut", hair_colour="Orange", shirt=(LONG, "Olivine"), over=(CARDIGAN, "Swamp"), pants=("Pants 04 - Cuffed Pants", "Umber"), beard=("Facial Hair 07 - Medium Beard", "Orange")),
    "vera": adult("Porcelain", head="Head 01 - Feminine", fem=True, hair="Medium 07 - Bob, Side Part", hair_colour="Platinum", shirt=(LONG, "Black"), over=(CARDIGAN, "Black"), pants=("Pants 03 - Pants", "Black"), glasses="Iron"),
    # Point Pleasant
    "marlene": adult("Peach", head="Head 01 - Feminine", fem=True, hair="Medium 08 - Bob, Bangs", hair_colour="Blonde", shirt=(LONG, "Pink"), over=(CARDIGAN, "Salmon"), pants=("Pants 03 - Pants", "Black"), shoes=("Shoes 01 - Shoes", "White")),
    "regulars": adult("Tawny", hair="Short 06 - Balding", hair_colour="Gray", shirt=(BUTTONED, "Ochre"), over=(CARDIGAN, "Oak"), pants=("Pants 05 - Overalls", "Denim"), beard=("Facial Hair 01 - Walrus Mustache", "Gray")),
    "editor": adult("Porcelain", head="Head 03 - Elderly", hair="Short 02 - Parted", hair_colour="White", shirt=(BUTTONED, "Ivory"), over=(CARDIGAN, "Sepia"), pants=("Pants 03 - Pants", "Charcoal"), glasses="Brass"),
    "deputy": adult("Tan", hair="Short 01 - Buzzcut", hair_colour="Brown", shirt=(BUTTONED, "Tawny"), pants=("Pants 03 - Pants", "Chocolate"), beard=("Facial Hair 02 - Chevron Mustache", "Brown")),
    "earl": adult("Honey", hair="Short 06 - Balding", hair_colour="Brown", shirt=(LONG, "Denim"), over=(CARDIGAN, "Navy"), pants=("Pants 05 - Overalls", "Charcoal")),
    "clerk": adult("Bronze", hair="Short 07 - Flat Top", hair_colour="Black", shirt=(BUTTONED, "Mint"), over=(CARDIGAN, "Olivine"), pants=("Pants 03 - Pants", "Charcoal")),
    "kid": child("Peach"),
}
# children are tinted into a coat and jeans by cell band
TINTS = {"kid": [(38, 52, (200, 70, 50)), (52, 61, (60, 70, 110))]}
CHARACTERS.update({
    "pastor": adult("Ivory", head="Head 03 - Elderly", hair="Short 06 - Balding", hair_colour="White", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Black"), pants=("Pants 03 - Pants", "Black")),
    "walt": adult("Peach", head="Head 03 - Elderly", hair="Short 05 - Natural", hair_colour="Gray", shirt=(BUTTONED, "Garnet"), over=(CARDIGAN, "Coffee"), pants=("Pants 05 - Overalls", "Umber"), beard=("Facial Hair 07 - Medium Beard", "Gray")),
    "suit": adult("Porcelain", hair="Short 02 - Parted", hair_colour="Black", shirt=(BUTTONED, "White"), over=(CARDIGAN, "Black"), pants=("Pants 03 - Pants", "Black"), glasses="Iron"),
})
KID_HAIR = {"kid": (216, 179, 90)}
CHARACTERS.update(art_extra.extra_characters(adult, child, LONG, BUTTONED, CARDIGAN))
CHARACTERS.update(art_summer.summer_characters(adult, child, LONG, BUTTONED, CARDIGAN))
CHARACTERS.update(art_kelly.kelly_characters(adult, child, LONG, BUTTONED, CARDIGAN))
TINTS.update(art_kelly.KELLY_TINTS)
KID_HAIR.update(art_kelly.KELLY_KID_HAIR)


def build_characters():
    out = os.path.join(ASSETS, "sprites")
    os.makedirs(out, exist_ok=True)
    for name, layers in CHARACTERS.items():
        compose(layers, os.path.join(out, name + ".png"), TINTS.get(name))
    for name, colour in KID_HAIR.items():
        p = os.path.join(out, name + ".png")
        im = Image.open(p)
        add_child_hair(im, colour)
        im.save(p)
    sh = Image.new("RGBA", (32, 12), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([3, 1, 28, 10], fill=(0, 0, 0, 90))
    sh.save(os.path.join(out, "shadow.png"))
    print("characters:", len(CHARACTERS))


def add_child_hair(im, colour):
    """Children's heads are bald in the source; paint a simple cap on each frame."""
    px = im.load()
    w, h = im.size
    for cy in range(h // 64):
        for cx in range(w // 64):
            ox, oy = cx * 64, cy * 64
            top = None
            for y in range(64):
                if any(px[ox + x, oy + y][3] > 0 for x in range(64)):
                    top = y
                    break
            if top is None:
                continue
            for y in range(top, top + 7):
                xs = [x for x in range(64) if px[ox + x, oy + y][3] > 0]
                if not xs:
                    continue
                x0, x1 = min(xs), max(xs)
                for x in range(x0, x1 + 1):
                    s = 1.0 if (x + y) % 3 else 0.8
                    px[ox + x, oy + y] = (int(colour[0] * s), int(colour[1] * s), int(colour[2] * s), 255)
                if y < top + 5:
                    for x in (x0 - 1, x1 + 1):
                        if 0 <= x < 64:
                            px[ox + x, oy + y] = (colour[0], colour[1], colour[2], 255)


# -------------------------------------------------------------- portraits
PORTRAIT_BG = (14, 20, 36, 255)


def build_portraits():
    out = os.path.join(ASSETS, "portraits")
    os.makedirs(out, exist_ok=True)
    done = set()
    if GEN_PORTRAITS and os.path.isdir(GEN_PORTRAITS):
        for f in sorted(os.listdir(GEN_PORTRAITS)):
            if not f.lower().endswith((".jpg", ".png")):
                continue
            name = os.path.splitext(f)[0]
            im = Image.open(os.path.join(GEN_PORTRAITS, f)).convert("RGB")
            side = min(im.size)
            im = im.crop(((im.size[0] - side) // 2, 0, (im.size[0] - side) // 2 + side, side))
            im = im.resize((96, 96), Image.LANCZOS)
            im = im.quantize(48, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
            im.save(os.path.join(out, name + ".png"))
            done.add(name)
    sprites = os.path.join(ASSETS, "sprites")
    for name in CHARACTERS:
        if name in done or os.path.exists(os.path.join(out, name + ".png")) and GEN_PORTRAITS:
            continue
        sp = Image.open(os.path.join(sprites, name + ".png"))
        head = sp.crop((16, 8, 48, 40)).resize((96, 96), Image.NEAREST)
        bg = Image.new("RGBA", (96, 96), PORTRAIT_BG)
        bg.alpha_composite(head)
        bg.save(os.path.join(out, name + ".png"))
    print("portraits:", len(CHARACTERS), "generated:", len(done))


# ---------------------------------------------------------------- credits
def write_credits():
    lines = ["# Art credits", "",
             "Tiles, houses, furniture and character parts come from the LPC Revised project",
             "(https://github.com/ElizaWy/LPC), licensed CC-BY 3.0 / OGA-BY 3.0.",
             "The source sheets used are kept under assets/lpc_src/. Their authors,",
             "from the Credits.txt files that accompany them:", ""]
    seen = set()
    for rel in sorted(_used):
        d = os.path.dirname(rel)
        while d and d not in seen:
            seen.add(d)
            for cname in ("Credits.txt", "credit.txt", "Credit.txt"):
                p = os.path.join(SRC or LOCAL, d, cname)
                if os.path.exists(p):
                    with open(p, errors="replace") as f:
                        text = f.read().strip()
                    lines += [f"## {d}", "", "```", text[:4000], "```", ""]
                    local = os.path.join(LOCAL, d, cname)
                    if SRC and not os.path.exists(local):
                        os.makedirs(os.path.dirname(local), exist_ok=True)
                        shutil.copy(p, local)
                    break
            d = os.path.dirname(d)
    lines += ["## Files used", ""] + [f"- {r}" for r in sorted(_used)]
    with open(os.path.join(ASSETS, "CREDITS.md"), "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    build_tiles()
    build_props()
    build_facades()
    build_characters()
    build_portraits()
    art_foes.build_foes(ASSETS, sheet, adult, outline)
    write_credits()


if __name__ == "__main__":
    main()
