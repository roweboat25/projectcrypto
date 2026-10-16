"""The creature foes, painted as pixel art: each is drawn at 48x48 with a small
kit (shaded blobs, fur dither, ramps) and scaled 2x nearest to the 96x96 battle
frame, so it reads like the 32px LPC people once the game doubles it again.
art_foes.frame-level recipes call creature(name, frame); run this file on its
own to rebuild only the creature sheets without an LPC checkout."""
import json
import os
import random
from PIL import Image, ImageDraw

S = 48            # drawing size; the battle frame is 2x this
FW = 96
OUT = (18, 12, 16, 255)


def ramp(base, steps=(-70, -35, 0, 35, 70)):
    """Five tones around a base colour: deep shadow, shadow, base, light, highlight."""
    out = []
    for s in steps:
        out.append(tuple(max(0, min(255, c + s)) for c in base))
    return out


class Pix:
    def __init__(self):
        self.im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def blob(self, cx, cy, rx, ry, rp, light=(-0.35, -0.4)):
        """An ellipse shaded as a rounded form: shadow crescent away from the light,
        highlight crescent toward it, plus a rim of deep shadow at the bottom."""
        d = self.d
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=rp[1])
        # shadow side: the base ellipse minus an offset ellipse
        ox, oy = int(-light[0] * rx * 0.9), int(-light[1] * ry * 0.9)
        mask = Image.new("L", (S, S), 0)
        md = ImageDraw.Draw(mask)
        md.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
        md.ellipse([cx - rx + ox, cy - ry + oy, cx + rx + ox, cy + ry + oy], fill=0)
        self.im.paste(Image.new("RGBA", (S, S), rp[0]), (0, 0), mask)
        # base in the middle
        mid = Image.new("L", (S, S), 0)
        mdd = ImageDraw.Draw(mid)
        mdd.ellipse([cx - rx + ox, cy - ry + oy, cx + rx + ox, cy + ry + oy], fill=255)
        mdd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
        inner = Image.new("L", (S, S), 0)
        ind = ImageDraw.Draw(inner)
        ind.ellipse([cx - rx + ox, cy - ry + oy, cx + rx + ox, cy + ry + oy], fill=255)
        self.im.paste(Image.new("RGBA", (S, S), rp[2]), (0, 0), self._and(inner, self._ell(cx, cy, rx, ry)))
        # highlight toward the light
        hx, hy = int(light[0] * rx * 0.45), int(light[1] * ry * 0.45)
        hi = self._and(self._ell(cx + hx, cy + hy, int(rx * 0.55), int(ry * 0.55)), self._ell(cx, cy, rx, ry))
        self.im.paste(Image.new("RGBA", (S, S), rp[3]), (0, 0), hi)

    def _ell(self, cx, cy, rx, ry):
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
        return m

    @staticmethod
    def _and(a, b):
        from PIL import ImageChops
        return ImageChops.multiply(a, b)

    def fur(self, rp, seed, density=0.18, box=None):
        """Scatter darker and lighter pixels over the painted area for a coat."""
        rnd = random.Random(seed)
        px = self.im.load()
        x0, y0, x1, y1 = box or (0, 0, S, S)
        x0, y0, x1, y1 = max(0, x0), max(0, y0), min(S, x1), min(S, y1)
        for y in range(y0, y1):
            for x in range(x0, x1):
                if px[x, y][3] == 0 or rnd.random() > density:
                    continue
                r, g, b, a = px[x, y]
                if (r, g, b) == rp[2]:
                    px[x, y] = rnd.choice([rp[1], rp[3]]) + (255,)
                elif (r, g, b) == rp[1]:
                    px[x, y] = rnd.choice([rp[0], rp[2]]) + (255,)

    def poly(self, pts, col):
        self.d.polygon(pts, fill=col)

    def line(self, pts, col, w=1):
        self.d.line(pts, fill=col, width=w)

    def rect(self, box, col):
        self.d.rectangle(box, fill=col)

    def dot(self, x, y, col):
        self.d.point((x, y), fill=col)

    def eye(self, x, y, col=(255, 230, 60), r=1, glow=True):
        if glow:
            self.d.ellipse([x - r - 2, y - r - 2, x + r + 2, y + r + 2], fill=col + (70,))
            self.d.ellipse([x - r - 1, y - r - 1, x + r + 1, y + r + 1], fill=col + (160,))
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=col + (255,))
        if r >= 1:
            self.dot(x - r + 1 if r > 1 else x, y - r + 1 if r > 1 else y, (255, 255, 255, 255))

    def animal_eye(self, x, y, iris=(200, 160, 40)):
        self.d.rectangle([x - 1, y - 1, x + 1, y + 1], fill=(20, 14, 12, 255))
        self.dot(x, y, iris + (255,))
        self.dot(x - 1, y - 1, (240, 240, 240, 255))

    def outline(self, col=OUT):
        px = self.im.load()
        base = self.im.copy().load()
        for y in range(S):
            for x in range(S):
                if base[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < S and 0 <= ny < S and base[nx, ny][3] >= 200:
                        px[x, y] = col
                        break

    def inner_line(self, pts, rp):
        """A crease: a dark line one pixel wide, used for ribs, fingers, folds."""
        self.d.line(pts, fill=rp[0] + (255,), width=1)

    def big(self):
        return self.im.resize((FW, FW), Image.NEAREST)


# ---------- creatures ----------

def dog(p, cx, base, coat, w=26, mangy=False, ears="flop", eyes=(200, 160, 40), teeth=True, f=0, lean=False):
    """A dog facing the viewer, head low and forward: chest blob, haunches
    behind, head, muzzle, ears, forelegs, a bared mouth."""
    rp = ramp(coat)
    pale = ramp(tuple(min(255, c + 40) for c in coat))
    bob = 1 if f else 0
    # haunches behind the chest
    p.blob(cx - w // 2 + 4, base - 12, 8, 9, rp)
    p.blob(cx + w // 2 - 4, base - 12, 8, 9, rp)
    # chest
    p.blob(cx, base - 13 + bob, w // 2, 11 if not lean else 9, rp)
    if lean:
        p.blob(cx, base - 10 + bob, w // 2 - 4, 6, pale)
    # forelegs
    for sx in (-1, 1):
        lx = cx + sx * (w // 2 - 6)
        p.rect([lx - 2, base - 10, lx + 2, base - 1], rp[1] + (255,))
        p.rect([lx - 2, base - 10, lx - 1, base - 1], rp[2] + (255,))
        p.rect([lx - 3, base - 2, lx + 3, base], rp[0] + (255,))
    # ribs on a mangy dog
    if mangy:
        for i in range(3):
            y = base - 16 + i * 3 + bob
            p.inner_line([(cx - 7, y), (cx - 3, y + 1)], rp)
            p.inner_line([(cx + 3, y + 1), (cx + 7, y)], rp)
    # head, low and forward
    hy = base - 26 + bob
    p.blob(cx, hy, 8, 7, rp)
    # ears
    if ears == "flop":
        p.poly([(cx - 9, hy - 2), (cx - 13, hy + 6), (cx - 6, hy + 4)], rp[1] + (255,))
        p.poly([(cx + 9, hy - 2), (cx + 13, hy + 6), (cx + 6, hy + 4)], rp[1] + (255,))
        if mangy:  # one torn ear
            p.poly([(cx + 9, hy - 2), (cx + 11, hy + 1), (cx + 7, hy + 2)], rp[1] + (255,))
    else:
        p.poly([(cx - 8, hy - 3), (cx - 10, hy - 13), (cx - 2, hy - 5)], rp[1] + (255,))
        p.poly([(cx + 8, hy - 3), (cx + 10, hy - 13), (cx + 2, hy - 5)], rp[1] + (255,))
        p.poly([(cx - 7, hy - 4), (cx - 8, hy - 10), (cx - 4, hy - 5)], rp[0] + (255,))
        p.poly([(cx + 7, hy - 4), (cx + 8, hy - 10), (cx + 4, hy - 5)], rp[0] + (255,))
    # brow shadow and eyes
    p.rect([cx - 7, hy - 3, cx + 7, hy - 2], rp[1] + (255,))
    p.animal_eye(cx - 4, hy - 1, eyes)
    p.animal_eye(cx + 4, hy - 1, eyes)
    if mangy:
        p.inner_line([(cx - 7, hy - 5), (cx - 2, hy - 3)], rp)
        p.inner_line([(cx + 7, hy - 5), (cx + 2, hy - 3)], rp)
    # muzzle, pushed forward and down so it reads as a snout
    p.blob(cx, hy + 6, 6, 5, pale if not mangy else rp)
    p.rect([cx - 2, hy + 3, cx + 1, hy + 5], (30, 20, 20, 255))
    p.dot(cx - 2, hy + 3, (70, 50, 50, 255))
    if teeth:
        p.rect([cx - 4, hy + 8, cx + 4, hy + 9], (40, 20, 24, 255))
        for tx in (cx - 3, cx - 1, cx + 1, cx + 3):
            p.dot(tx, hy + 8, (240, 236, 220, 255))
    else:
        p.line([(cx - 3, hy + 8), (cx + 3, hy + 8)], (50, 30, 30, 255))
    p.fur(rp, 11 + f, 0.14, (cx - w, base - 40, cx + w, base))


def owl(p, cx, base, coat, face, f=0, eyes=2, horned=False, wings="half", glow=False):
    rp = ramp(coat)
    fp = ramp(face)
    bob = 1 if f else 0
    # wings
    if wings == "up":
        for sx in (-1, 1):
            pts = [(cx + sx * 8, base - 26), (cx + sx * 22, base - 44 + bob * 2), (cx + sx * 20, base - 14), (cx + sx * 10, base - 8)]
            p.poly(pts, rp[1] + (255,))
            for i in range(3):
                p.inner_line([(cx + sx * (10 + i * 4), base - 12 - i * 2), (cx + sx * (18 + i * 2), base - 30 - i * 4 + bob * 2)], rp)
    else:
        for sx in (-1, 1):
            pts = [(cx + sx * 8, base - 28), (cx + sx * 16, base - 20), (cx + sx * 14, base - 6), (cx + sx * 8, base - 8)]
            p.poly(pts, rp[1] + (255,))
            for i in range(3):
                p.inner_line([(cx + sx * (10 + i * 2), base - 10 - i * 4), (cx + sx * (12 + i * 2), base - 24 + i)], rp)
    # body
    p.blob(cx, base - 18 + bob, 10, 15, rp)
    # breast feathers
    for y in range(base - 24 + bob, base - 6, 3):
        for x in range(cx - 6, cx + 7, 3):
            p.dot(x + (1 if (y // 3) % 2 else 0), y, rp[0] + (255,))
            p.dot(x + (1 if (y // 3) % 2 else 0), y - 1, rp[3] + (255,))
    # feet
    for sx in (-1, 1):
        for t in range(3):
            p.line([(cx + sx * 4, base - 3), (cx + sx * (2 + t * 2), base)], (90, 70, 40, 255))
    # head
    p.blob(cx, base - 34 + bob, 9, 8, rp)
    # facial disc
    p.blob(cx - 4, base - 34 + bob, 5, 6, fp, light=(-0.2, -0.3))
    p.blob(cx + 4, base - 34 + bob, 5, 6, fp, light=(-0.2, -0.3))
    if horned:
        p.poly([(cx - 8, base - 38 + bob), (cx - 12, base - 48 + bob), (cx - 3, base - 40 + bob)], rp[1] + (255,))
        p.poly([(cx + 8, base - 38 + bob), (cx + 12, base - 48 + bob), (cx + 3, base - 40 + bob)], rp[1] + (255,))
    # beak
    p.poly([(cx - 1, base - 34 + bob), (cx + 1, base - 34 + bob), (cx, base - 30 + bob)], (70, 50, 30, 255))
    # eyes
    pos = [(cx - 4, base - 35 + bob), (cx + 4, base - 35 + bob)]
    extra = [(cx - 6, base - 31 + bob), (cx + 6, base - 31 + bob), (cx, base - 39 + bob), (cx + 2, base - 31 + bob)]
    pos += extra[:max(0, eyes - 2)]
    for (x, y) in pos:
        if glow:
            p.eye(x, y, (255, 220, 50), 1)
        else:
            p.animal_eye(x, y, (240, 200, 40))
    p.fur(rp, 21 + f, 0.1)


def little_man(p, cx, base, skin, h=36, arms="up", f=0, eyes=True, glow=(255, 236, 90), claws=True):
    """The Kelly creature: a big domed head with huge pointed ears, lamp eyes,
    a thin silvery body and long arms that end in claws. Hovers a little."""
    rp = ramp(skin)
    bob = 1 if f else 0
    top = base - h + bob
    # legs, thin
    for sx in (-1, 1):
        p.line([(cx + sx * 3, base - 14), (cx + sx * 5, base - 2)], rp[1] + (255,), 2)
        p.rect([cx + sx * 5 - 2, base - 2, cx + sx * 5 + 2, base], rp[0] + (255,))
    # torso
    p.blob(cx, base - 18, 5, 8, rp)
    p.inner_line([(cx, base - 24), (cx, base - 12)], rp)
    # arms
    for sx in (-1, 1):
        if arms == "up":
            pts = [(cx + sx * 4, base - 22), (cx + sx * 12, base - 30), (cx + sx * 16, top + 2)]
        else:
            pts = [(cx + sx * 4, base - 22), (cx + sx * 14, base - 20), (cx + sx * 20, base - 30)]
        p.line(pts, rp[1] + (255,), 2)
        p.line(pts[:2], rp[2] + (255,), 1)
        ex, ey = pts[-1]
        if claws:
            for k in range(3):
                p.line([(ex, ey), (ex + sx * (k * 2 - 1), ey - 4 - (k % 2) * 2)], rp[1] + (255,), 1)
    # head
    p.blob(cx, top + 8, 9, 8, rp)
    # ears
    for sx in (-1, 1):
        p.poly([(cx + sx * 8, top + 6), (cx + sx * 17, top - 1), (cx + sx * 7, top + 12)], rp[1] + (255,))
        p.poly([(cx + sx * 9, top + 7), (cx + sx * 14, top + 2), (cx + sx * 8, top + 10)], rp[0] + (255,))
    # mouth
    p.line([(cx - 2, top + 13), (cx + 2, top + 13)], rp[0] + (255,))
    if eyes:
        p.eye(cx - 4, top + 7, glow, 2)
        p.eye(cx + 4, top + 7, glow, 2)


def mothman(p, cx, base, f=0):
    grey = ramp((88, 90, 104))
    dark = ramp((56, 58, 70))
    bob = 1 if f else 0
    # wings, folded like a cape, tips above the shoulders
    for sx in (-1, 1):
        pts = [(cx + sx * 6, base - 40), (cx + sx * 20, base - 46 - bob * 2), (cx + sx * 21, base - 6), (cx + sx * 9, base - 2)]
        p.poly(pts, dark[1] + (255,))
        p.poly([(cx + sx * 6, base - 40), (cx + sx * 13, base - 43 - bob), (cx + sx * 14, base - 4), (cx + sx * 9, base - 2)], dark[2] + (255,))
        for i in range(4):
            p.inner_line([(cx + sx * (9 + i * 3), base - 36), (cx + sx * (10 + i * 3), base - 6)], dark)
    # body
    p.blob(cx, base - 24 + bob, 7, 18, grey)
    p.rect([cx - 5, base - 4, cx - 2, base], grey[0] + (255,))
    p.rect([cx + 2, base - 4, cx + 5, base], grey[0] + (255,))
    # a head that is mostly neck and eyes
    p.blob(cx, base - 42 + bob, 6, 6, grey)
    p.eye(cx - 3, base - 43 + bob, (255, 50, 40), 2)
    p.eye(cx + 3, base - 43 + bob, (255, 50, 40), 2)
    p.fur(grey, 31 + f, 0.12)


def crawler(p, cx, base, f=0):
    """The igloo crawler: a pale hunched thing on too many legs, the colour of
    the TNT bunkers' concrete, with a lump of a head and lamp eyes."""
    rp = ramp((150, 150, 144))
    bob = 1 if f else 0
    for i, lx in enumerate((-18, -11, -4, 4, 11, 18)):
        jog = 2 if (i + f) % 2 else 0
        p.line([(cx + lx // 2, base - 10), (cx + lx, base - 14 - jog), (cx + lx + (2 if lx > 0 else -2), base)], rp[1] + (255,), 2)
    p.blob(cx, base - 14 + bob, 16, 9, rp)
    p.blob(cx - 2, base - 24 + bob, 8, 7, rp)
    for i in range(5):
        p.inner_line([(cx - 12 + i * 6, base - 20 + bob), (cx - 10 + i * 6, base - 8 + bob)], rp)
    p.eye(cx - 5, base - 25 + bob, (255, 240, 140), 1)
    p.eye(cx + 1, base - 25 + bob, (255, 240, 140), 1)
    p.fur(rp, 41, 0.2)


def monkey(p, cx, base, f=0):
    fur_ = ramp((120, 86, 50))
    face = ramp((222, 192, 160))
    red = ramp((200, 50, 50))
    bob = 1 if f else 0
    # tail
    p.line([(cx + 6, base - 14), (cx + 16, base - 22), (cx + 18, base - 8), (cx + 14, base - 2)], fur_[1] + (255,), 2)
    # legs
    for sx in (-1, 1):
        p.line([(cx + sx * 3, base - 12), (cx + sx * 4, base - 1)], fur_[1] + (255,), 3)
        p.rect([cx + sx * 4 - 2, base - 1, cx + sx * 4 + 2, base], fur_[0] + (255,))
    # the tiny jacket
    p.blob(cx, base - 18 + bob, 6, 7, red)
    p.rect([cx, base - 24 + bob, cx, base - 12 + bob], (240, 220, 120, 255))
    # arms
    p.line([(cx - 5, base - 22 + bob), (cx - 13, base - 14 + (3 if f else 0))], fur_[1] + (255,), 2)
    p.line([(cx + 5, base - 22 + bob), (cx + 13, base - 14 - (3 if f else 0))], fur_[1] + (255,), 2)
    # head
    p.blob(cx, base - 30 + bob, 7, 6, fur_)
    p.blob(cx - 5, base - 30 + bob, 2, 2, fur_)
    p.blob(cx + 5, base - 30 + bob, 2, 2, fur_)
    p.blob(cx, base - 29 + bob, 4, 4, face)
    p.animal_eye(cx - 2, base - 31 + bob, (40, 30, 20))
    p.animal_eye(cx + 2, base - 31 + bob, (40, 30, 20))
    p.line([(cx - 2, base - 27 + bob), (cx + 2, base - 27 + bob)], (60, 30, 30, 255))


def gull(p, x, y, flap):
    body = ramp((236, 236, 240))
    wing = ramp((180, 184, 196))
    p.blob(x, y, 5, 3, body, light=(-0.3, -0.5))
    p.blob(x + 4, y - 2, 2, 2, body)
    p.poly([(x + 6, y - 2), (x + 9, y - 1), (x + 6, y - 1)], (230, 170, 50, 255))
    if flap:
        p.poly([(x - 2, y - 1), (x - 11, y - 8), (x - 9, y - 1), (x + 1, y + 1)], wing[2] + (255,))
        p.poly([(x + 2, y - 1), (x + 10, y - 8), (x + 9, y - 1), (x + 1, y + 1)], wing[1] + (255,))
    else:
        p.poly([(x - 2, y), (x - 12, y + 5), (x - 8, y + 1), (x + 1, y + 1)], wing[2] + (255,))
        p.poly([(x + 2, y), (x + 11, y + 5), (x + 8, y + 1), (x + 1, y + 1)], wing[1] + (255,))
    p.dot(x + 5, y - 3, (20, 20, 20, 255))


# ---------- the frames ----------

# ---------- people ----------

def person(p, cx, base, skin, hair, top, pants, f=0, hat=None, beard=None, gun=None, h=38,
           eyes=True, mouth="line", lean=0, boots=(50, 40, 36), bulk=0):
    """A person facing the viewer: boots, trousers, a jacket or shirt with
    sleeves, hands, a head with hair and maybe a hat or beard. Frame 2 shifts
    the weight and the gun."""
    sk, hr, tp, pt = ramp(skin), ramp(hair), ramp(top), ramp(pants)
    cx += lean if f else 0
    bob = 1 if f else 0
    top_y = base - h + bob
    bw = 6 + bulk
    # legs and boots
    for sx in (-1, 1):
        lx = cx + sx * 3
        p.rect([lx - 2, base - 15, lx + 2, base - 3], pt[2] + (255,))
        p.rect([lx - 2, base - 15, lx - 1, base - 3], pt[1] + (255,))
        p.rect([lx - 3, base - 4, lx + 3, base], boots + (255,))
        p.rect([lx - 3, base - 4, lx + 3, base - 4], ramp(boots)[3] + (255,))
    # body
    p.blob(cx, base - 24 + bob, bw, 10, tp)
    p.inner_line([(cx, base - 32 + bob), (cx, base - 16 + bob)], tp)
    # arms
    for sx in (-1, 1):
        ax = cx + sx * (bw + 1)
        p.line([(ax, base - 30 + bob), (ax + sx, base - 18 + bob)], tp[1] + (255,), 3)
        p.line([(ax - sx, base - 30 + bob), (ax, base - 20 + bob)], tp[3] + (255,), 1)
        p.rect([ax - 1 + sx, base - 18 + bob, ax + 1 + sx, base - 16 + bob], sk[2] + (255,))
    # head
    hy = top_y + 7
    p.blob(cx, hy, 5, 6, sk)
    # hair cap
    if hair is not None:
        p.blob(cx, hy - 3, 5, 3, hr)
        p.rect([cx - 5, hy - 4, cx + 5, hy - 2], hr[2] + (255,))
    if beard:
        bd = ramp(beard)
        p.rect([cx - 4, hy + 2, cx + 4, hy + 5], bd[2] + (255,))
        p.rect([cx - 3, hy + 5, cx + 3, hy + 6], bd[1] + (255,))
    if eyes:
        p.dot(cx - 2, hy, (30, 24, 24, 255))
        p.dot(cx + 2, hy, (30, 24, 24, 255))
    if mouth == "line":
        p.line([(cx - 1, hy + 3), (cx + 1, hy + 3)], sk[0] + (255,))
    elif mouth == "wide":
        p.line([(cx - 5, hy + 3), (cx + 5, hy + 3)], (60, 10, 20, 255), 2)
    if hat == "brim":
        p.rect([cx - 8, hy - 4, cx + 8, hy - 3], hr[0] + (255,))
        p.rect([cx - 5, hy - 9, cx + 5, hy - 4], hr[1] + (255,))
    elif hat == "fedora":
        p.rect([cx - 8, hy - 3, cx + 8, hy - 2], (24, 20, 26, 255))
        p.rect([cx - 5, hy - 10, cx + 5, hy - 3], (34, 30, 38, 255))
        p.rect([cx - 5, hy - 5, cx + 5, hy - 4], (60, 20, 30, 255))
    elif hat == "helmet":
        p.blob(cx, hy - 3, 7, 5, ramp((110, 116, 90)))
        p.rect([cx - 6, hy - 1, cx + 6, hy - 1], (240, 240, 240, 255))
    elif hat == "cone":
        p.poly([(cx - 6, hy - 4), (cx, hy - 18), (cx + 6, hy - 4)], (240, 210, 60, 255))
        p.poly([(cx - 3, hy - 4), (cx, hy - 11), (cx + 1, hy - 4)], (255, 240, 140, 255))
        p.rect([cx - 7, hy - 4, cx + 7, hy - 3], (220, 190, 50, 255))
        p.dot(cx, hy - 18, (230, 60, 50, 255))
    if gun:
        gx0, gy0, gx1, gy1 = gun
        shift = -2 if f else 0
        p.line([(cx + gx0, base + gy0 + shift), (cx + gx1, base + gy1 + shift)], (70, 50, 40, 255), 3)
        p.line([(cx + gx0, base + gy0 + shift), (cx + gx1, base + gy1 + shift)], (120, 110, 110, 255), 1)


def eyeshine(p, cx, base, f=0):
    """Something low in the dark, mostly not there: a soft black shape and two lamps."""
    for i, (r, a) in enumerate(((16, 60), (12, 110), (8, 160))):
        p.d.ellipse([cx - r, base - 26 - r // 2 + i, cx + r, base - 2 + i], fill=(12, 10, 18, a))
    p.d.ellipse([cx - 9, base - 38 + (1 if f else 0), cx + 9, base - 22], fill=(14, 12, 20, 190))
    r = 2 if not f else 1
    p.eye(cx - 4, base - 31 + (1 if f else 0), (255, 236, 90), r)
    p.eye(cx + 4, base - 31 + (1 if f else 0), (255, 236, 90), r)


def cave_breath(p, cx, base, f=0):
    """Mist with a face in it: layered translucent puffs and three dark holes."""
    rnd = random.Random(3 + f)
    for _ in range(18):
        x, y, r = rnd.randrange(2, 40), rnd.randrange(4, 40), rnd.randrange(4, 10)
        p.d.ellipse([x, y, x + r, y + r], fill=(210, 224, 236, 70))
    p.d.ellipse([cx - 11, base - 36, cx + 11, base - 12], fill=(228, 238, 246, 150))
    p.d.ellipse([cx - 8, base - 33, cx + 6, base - 20], fill=(240, 246, 250, 120))
    p.d.ellipse([cx - 6, base - 30, cx - 3, base - 26], fill=(90, 110, 130, 210))
    p.d.ellipse([cx + 2, base - 30, cx + 5, base - 26], fill=(90, 110, 130, 210))
    p.d.ellipse([cx - 2, base - 23, cx + 2, base - 17 + (2 if f else 0)], fill=(90, 110, 130, 210))


def static_shade(p, cx, base, f=0):
    """A person-shaped hole full of television snow."""
    person(p, cx, base, (128, 128, 128), (128, 128, 128), (128, 128, 128), (128, 128, 128), f=f, eyes=False, mouth="", h=40)
    rnd = random.Random(7 + f)
    px = p.im.load()
    for y in range(S):
        for x in range(S):
            if px[x, y][3]:
                v = rnd.choice((30, 70, 120, 170, 220, 250))
                px[x, y] = (v, v, v, 255)
    if f:
        for y in range(10, 14):
            for x in range(S):
                if px[x, y][3]:
                    px[x, y] = (240, 240, 240, 255)


def creature(name, f):
    """One 96x96 frame of a creature foe, outlined, or None when the foe is not drawn here."""
    p = Pix()
    base = 46
    if name == "stray_dog":
        dog(p, 24, base, (104, 82, 58), w=26, mangy=True, ears="point", f=f)
    elif name == "coyote":
        dog(p, 24, base, (176, 150, 110), w=24, ears="point", f=f, lean=True, eyes=(230, 200, 60), teeth=False)
    elif name == "hound_pack":
        dog(p, 14, base, (60, 44, 34), w=20, ears="point", f=f, eyes=(220, 170, 60))
        dog(p, 33, base - 2, (160, 130, 90), w=22, ears="point", f=1 - f, eyes=(220, 170, 60))
    elif name == "wrong_owl":
        owl(p, 24, base, (200, 180, 140), (240, 232, 210), f=f, eyes=6 if f else 5, glow=True)
    elif name == "owl_wrong_ky":
        owl(p, 24, base, (120, 96, 70), (190, 170, 130), f=f, horned=True, wings="up" if not f else "half", glow=True)
    elif name == "little_man":
        little_man(p, 24, base - 2, (176, 182, 190), f=f)
    elif name == "floater":
        little_man(p, 24, base - 10, (176, 182, 190), arms="out", f=f)
        for i in range(3):
            p.d.ellipse([12 + i * 8, 40 + i, 24 + i * 8, 44 + i], fill=(180, 200, 220, 60))
    elif name == "the_tall_one":
        p.rect([0, 0, 47, 47], (236, 230, 214, 255))
        p.rect([4, 3, 43, 47], (18, 16, 24, 255))
        little_man(p, 24, 47, (190, 196, 204), h=46 if not f else 45, f=f)
        p.rect([23, 3, 24, 47], (236, 230, 214, 170))
        p.rect([4, 25, 43, 26], (236, 230, 214, 170))
    elif name == "roof_walker":
        for y in range(0, 30):
            t = y / 30.0
            p.line([(0, y), (47, y)], (int(40 + 160 * t), int(40 + 120 * t), int(80 + 60 * t), 255))
        p.poly([(0, 47), (0, 35), (24, 26), (47, 35), (47, 47)], (24, 20, 28, 255))
        p.line([(0, 35), (24, 26), (47, 35)], (60, 50, 60, 255))
        little_man(p, 24, 28, (24, 20, 28), h=24, arms="up" if f else "out", f=f, eyes=False)
        p.eye(21, 9 + (1 if f else 0), (255, 230, 60), 1)
        p.eye(27, 9 + (1 if f else 0), (255, 230, 60), 1)
    elif name == "mothman":
        mothman(p, 24, base, f)
    elif name == "igloo_crawler":
        crawler(p, 24, base, f)
    elif name == "fair_monkey":
        monkey(p, 24, base, f)
    elif name == "gull_swarm":
        gull(p, 10, 10, f)
        gull(p, 28, 22, not f)
        gull(p, 14, 36, f)
    elif name == "shotgun_man":
        person(p, 24, base, (214, 170, 130), (160, 160, 160), (70, 90, 130), (60, 60, 66), f=f, beard=(150, 150, 150), gun=(-10, -24, 12, -8), bulk=1)
    elif name == "drunk_local":
        person(p, 24, base, (214, 170, 130), (110, 80, 50), (150, 40, 40), (60, 60, 66), f=f, hat="brim", beard=(110, 80, 50), gun=(-12, -18, 10, -26), lean=3)
    elif name == "mp_patrol":
        person(p, 24, base, (230, 190, 160), (100, 70, 40), (110, 116, 80), (100, 106, 70), f=f, hat="helmet")
        p.rect([cx_r(24) + 9, base - 22, cx_r(24) + 12, base - 17], (50, 50, 56, 255))
        p.poly([(cx_r(24) + 12, base - 22), (47, base - 34 + (2 if f else 0)), (47, base - 16)], (255, 240, 180, 90))
    elif name == "the_hunters":
        person(p, 14, base, (230, 190, 160), (100, 70, 40), (210, 120, 40), (70, 80, 50), f=f, beard=(100, 70, 40), gun=(-8, -22, 8, -10))
        person(p, 34, base - 1, (190, 140, 100), (30, 26, 26), (70, 110, 60), (110, 80, 50), f=1 - f, beard=(30, 26, 26), gun=(-8, -22, 8, -10))
        p.rect([22, base - 16, 26, base - 8], (60, 60, 70, 255))
        p.d.ellipse([21, base - 19, 27, base - 13], fill=(255, 240, 170, 255))
        p.d.ellipse([19, base - 21, 29, base - 11], fill=(255, 240, 170, 40))
    elif name == "arcade_lads":
        person(p, 14, base, (240, 200, 170), (220, 190, 90), (40, 190, 210), (40, 60, 180), f=f, boots=(230, 230, 230))
        person(p, 34, base, (200, 150, 110), (30, 26, 26), (230, 220, 80), (110, 50, 150), f=1 - f, boots=(230, 230, 230))
        p.line([(8, base - 26), (14, base - 32)], (220, 40, 140, 255), 2)
        p.line([(28, base - 26), (34, base - 32)], (40, 160, 90, 255), 2)
    elif name == "dark_suit":
        person(p, 24, base, (248, 240, 232), (20, 16, 20), (24, 22, 28), (24, 22, 28), f=f, hat="fedora", eyes=False, mouth="wide", h=40)
        p.rect([20, base - 36, 28, base - 34], (248, 240, 232, 255))
        p.rect([23, base - 30, 25, base - 20], (200, 30, 40, 255))
    elif name == "hut_man":
        person(p, 24, base, (236, 200, 170), (160, 160, 160), (230, 120, 40), (120, 60, 150), f=f, hat="cone", h=40)
        rnd = random.Random(9)
        px = p.im.load()
        for y in range(base - 34, base - 14):
            for x in range(16, 33):
                if px[x, y][3] and (x // 3 + y // 3) % 2:
                    px[x, y] = rnd.choice([(230, 60, 50, 255), (60, 120, 220, 255), (240, 220, 80, 255), (60, 170, 90, 255), (200, 80, 180, 255)])
    elif name == "eyeshine":
        eyeshine(p, 24, base, f)
    elif name == "cave_breath":
        cave_breath(p, 24, base, f)
    elif name == "static_shade":
        static_shade(p, 24, base, f)
    else:
        return None
    if name not in ("roof_walker", "the_tall_one", "eyeshine", "cave_breath"):
        p.outline()
    im = p.big()
    if name in WRONG:
        im = wrong(im)
    return im


def cx_r(x):
    return x


WRONG = {"wrong_owl", "owl_wrong_ky", "little_man", "floater", "the_tall_one", "roof_walker", "mothman", "igloo_crawler", "dark_suit", "hut_man"}
NAMES = ["stray_dog", "coyote", "hound_pack", "wrong_owl", "owl_wrong_ky", "little_man", "floater", "the_tall_one",
         "roof_walker", "mothman", "igloo_crawler", "fair_monkey", "gull_swarm",
         "shotgun_man", "drunk_local", "mp_patrol", "the_hunters", "arcade_lads", "dark_suit", "hut_man",
         "eyeshine", "cave_breath", "static_shade"]


def wrong(im):
    """The anomaly treatment: contrast pushed and colours snapped to few steps."""
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 255:
                continue
            out = []
            for v in (r, g, b):
                v = int((v - 128) * 1.3 + 128)
                v = max(0, min(255, v))
                out.append((v // 40) * 40 + 12 if v < 240 else 255)
            px[x, y] = (out[0], out[1], out[2], a)
    return im


def sheet(name):
    im = Image.new("RGBA", (FW * 2, FW), (0, 0, 0, 0))
    for f in range(2):
        fr = creature(name, f)
        im.alpha_composite(fr, (f * FW, 0))
    return im


def main():
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    out = os.path.join(root, "assets", "foes")
    for name in NAMES:
        sheet(name).save(os.path.join(out, name + ".png"))
    print("creatures:", len(NAMES))


if __name__ == "__main__":
    main()
