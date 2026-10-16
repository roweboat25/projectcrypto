"""The creature foes, painted as pixel art at the full 96x96 battle frame.
Painters still think in a 48-unit space (the first version drew at 48px and
doubled); Pix scales every coordinate by K, so a radius of 7 is 14 pixels and
half units (12.5) address single pixels. Shading is per pixel: blobs are lit
as spheres with ordered dither between the ramp tones, a rim pass lifts the
lit edge and sinks the shadow edge of every shape, fur is laid as strands and
the outline is one pixel of darkened local colour, in the manner of DS-era
battle sprites. art_foes.frame-level recipes call creature(name, frame); run
this file on its own to rebuild only the creature sheets without an LPC
checkout."""
import json
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageChops

K = 2             # pixels per painter unit
S = 96            # the frame; painters address 0..48
FW = 96
OUT = (18, 12, 16, 255)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0


def ramp(base, steps=(-70, -35, 0, 35, 70)):
    """Five tones around a base colour: deep shadow, shadow, base, light,
    highlight. Shadows keep more blue so they read cool; lights lose blue so
    they read warm, the way hand-painted sprites shift hue with value."""
    out = []
    for s in steps:
        if s < 0:
            sh = (s, s * 0.92, s * 0.68)
        else:
            sh = (s, s * 0.94, s * 0.72)
        out.append(tuple(max(0, min(255, int(c + d))) for c, d in zip(base, sh)))
    return out


def _sc(v):
    return int(round(v * K))


def _pts(pts):
    return [(_sc(x), _sc(y)) for x, y in pts]


def _box(box):
    x0, y0, x1, y1 = box
    return [_sc(x0), _sc(y0), _sc(x1) + K - 1, _sc(y1) + K - 1]


def _rgba(col):
    return col if len(col) == 4 else col + (255,)


class Pix:
    def __init__(self):
        self.im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    # --- forms ---
    def blob(self, cx, cy, rx, ry, rp, light=(-0.35, -0.4), rim=True, spec=True):
        """An ellipse lit as a sphere: the surface normal against a light from
        `light` picks a tone from the ramp, with an ordered dither where tones
        meet, a specular dot toward the light and a thin lifted rim on the
        shadow side so the form separates from what is behind it."""
        cx, cy, rx, ry = cx * K, cy * K, rx * K, ry * K
        if rx < 1 or ry < 1:
            return
        x0, x1 = max(0, int(cx - rx) - 1), min(S - 1, int(cx + rx) + 1)
        y0, y1 = max(0, int(cy - ry) - 1), min(S - 1, int(cy + ry) + 1)
        if x1 < x0 or y1 < y0:
            return
        ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
        nx = (xs + 0.5 - cx) / rx
        ny = (ys + 0.5 - cy) / ry
        d2 = nx * nx + ny * ny
        inside = d2 <= 1.0
        z = np.sqrt(np.clip(1.0 - d2, 0, 1))
        lx, ly, lz = light[0] * 1.7, light[1] * 1.7, 0.9
        n = (lx * lx + ly * ly + lz * lz) ** 0.5
        lx, ly, lz = lx / n, ly / n, lz / n
        shade = nx * lx + ny * ly + z * lz          # -1 .. 1
        t = (shade + 1.0) * 0.5
        idx = t * 4.4 - 0.5                          # tone index, continuous
        if spec:
            idx = np.where(shade > 0.93, 4.6, idx)
        if rim:
            edge = (z < 0.28) & (shade < 0.25)
            idx = np.where(edge, np.maximum(idx, 1.6), idx)
            idx = np.where((z < 0.14) & (shade < -0.1), idx + 0.9, idx)
        idx = np.clip(idx, 0, 4)
        lo = np.floor(idx)
        frac = idx - lo
        th = np.tile(BAYER, (S // 4 + 2, S // 4 + 2))[y0:y1 + 1, x0:x1 + 1]
        pick = np.where(frac > th, np.minimum(lo + 1, 4), lo).astype(np.int32)
        pal = np.array([rp[i][:3] for i in range(5)], dtype=np.uint8)
        rgb = pal[pick]
        out = np.zeros((y1 - y0 + 1, x1 - x0 + 1, 4), dtype=np.uint8)
        out[..., :3] = rgb
        out[..., 3] = np.where(inside, 255, 0)
        patch = Image.fromarray(out, "RGBA")
        self.im.paste(patch, (x0, y0), patch)

    def _ell(self, cx, cy, rx, ry):
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).ellipse([_sc(cx - rx), _sc(cy - ry), _sc(cx + rx), _sc(cy + ry)], fill=255)
        return m

    @staticmethod
    def _and(a, b):
        return ImageChops.multiply(a, b)

    def fur(self, rp, seed, density=0.18, box=None, length=2):
        """Lay short strands over the painted area: darker ones in the shadow
        tones, lighter ones in the lit tones, so a coat reads as hair."""
        rnd = random.Random(seed)
        x0, y0, x1, y1 = box or (0, 0, 48, 48)
        x0, y0, x1, y1 = max(0, _sc(x0)), max(0, _sc(y0)), min(S, _sc(x1)), min(S, _sc(y1))
        px = self.im.load()
        base = self.im.copy().load()
        dens = density * 0.55
        for y in range(y0, y1):
            for x in range(x0, x1):
                if base[x, y][3] < 200 or rnd.random() > dens:
                    continue
                r, g, b, a = base[x, y]
                lum = (r + g + b) / 3
                dark = rnd.random() < (0.55 if lum < 128 else 0.4)
                f = 0.86 if dark else 1.12
                for k in range(length):
                    yy = y + k
                    if yy >= y1 or base[x, yy][3] < 200:
                        break
                    rr, gg, bb, aa = base[x, yy]
                    px[x, yy] = (min(255, int(rr * f)), min(255, int(gg * f)), min(255, int(bb * f)), 255)

    # --- flat marks, in painter units ---
    def poly(self, pts, col):
        self.d.polygon(_pts(pts), fill=_rgba(col))

    def line(self, pts, col, w=1):
        self.d.line(_pts(pts), fill=_rgba(col), width=max(1, _sc(w)))

    def fline(self, pts, col, w=1):
        """A line one real pixel wide (or w pixels), for fine detail."""
        self.d.line(_pts(pts), fill=_rgba(col), width=w)

    def rect(self, box, col):
        self.d.rectangle(_box(box), fill=_rgba(col))

    def ell(self, box, fill):
        x0, y0, x1, y1 = box
        self.d.ellipse([_sc(x0), _sc(y0), _sc(x1), _sc(y1)], fill=_rgba(fill))

    def dot(self, x, y, col):
        self.d.rectangle([_sc(x), _sc(y), _sc(x) + K - 1, _sc(y) + K - 1], fill=_rgba(col))

    def pix(self, x, y, col):
        """One real pixel at painter coordinates (half units reach every pixel)."""
        self.d.point((_sc(x), _sc(y)), fill=_rgba(col))

    def eye(self, x, y, col=(255, 230, 60), r=1, glow=True):
        x, y, r = _sc(x), _sc(y), _sc(r)
        if glow:
            self.d.ellipse([x - r - 5, y - r - 5, x + r + 5, y + r + 5], fill=col + (50,))
            self.d.ellipse([x - r - 3, y - r - 3, x + r + 3, y + r + 3], fill=col + (110,))
            self.d.ellipse([x - r - 1, y - r - 1, x + r + 1, y + r + 1], fill=col + (200,))
        self.d.ellipse([x - r, y - r, x + r, y + r], fill=col + (255,))
        core = tuple(min(255, c + 90) for c in col)
        self.d.ellipse([x - r // 2, y - r // 2, x + r // 2, y + r // 2], fill=core + (255,))
        self.d.point((x - r // 2, y - r // 2), fill=(255, 255, 255, 255))

    def animal_eye(self, x, y, iris=(200, 160, 40)):
        """A 6x6 eye: dark almond, iris, slit pupil, a wet highlight."""
        x, y = _sc(x), _sc(y)
        self.d.ellipse([x - 3, y - 2, x + 3, y + 3], fill=(20, 14, 12, 255))
        ir = ramp(iris)
        self.d.ellipse([x - 2, y - 1, x + 2, y + 2], fill=ir[2] + (255,))
        self.d.rectangle([x - 2, y + 1, x + 2, y + 2], fill=ir[1] + (255,))
        self.d.rectangle([x - 1, y - 1, x, y + 2], fill=(16, 10, 10, 255))
        self.d.point((x - 2, y - 1), fill=(250, 250, 250, 255))
        self.d.point((x + 1, y), fill=ir[3] + (255,))

    def inner_line(self, pts, rp):
        """A crease: a dark line one pixel wide, used for ribs, fingers, folds."""
        self.d.line(_pts(pts), fill=rp[0] + (255,), width=1)

    def crease(self, pts, rp):
        """A fold: shadow line with a lit line beside it, for cloth and hide."""
        self.d.line(_pts(pts), fill=rp[0] + (255,), width=1)
        self.d.line([(x + 1, y + 1) for x, y in _pts(pts)], fill=rp[3] + (255,), width=1)

    # --- shaded parts ---
    def cyl(self, x0, y0, x1, y1, rp, light=-0.4, axis="v"):
        """A box shaded as a cylinder: legs, arms, barrels, necks. The light
        falls from the left (negative) across a vertical cylinder."""
        bx0, by0, bx1, by1 = _box((x0, y0, x1, y1))
        bx0, by0 = max(0, bx0), max(0, by0)
        bx1, by1 = min(S - 1, bx1), min(S - 1, by1)
        if bx1 < bx0 or by1 < by0:
            return
        ys, xs = np.mgrid[by0:by1 + 1, bx0:bx1 + 1]
        if axis == "v":
            u = (xs + 0.5 - (bx0 + bx1 + 1) / 2) / max(1, (bx1 - bx0 + 1) / 2)
        else:
            u = (ys + 0.5 - (by0 + by1 + 1) / 2) / max(1, (by1 - by0 + 1) / 2)
        u = np.clip(u, -1, 1)
        z = np.sqrt(1 - u * u)
        shade = u * light * 1.2 + z * 0.85
        idx = np.clip((shade + 0.2) * 3.2 - 0.6, 0, 4)
        self._paint_idx(idx, bx0, by0, np.ones_like(u, dtype=bool), rp)

    def shade_poly(self, pts, rp, light=(-0.35, -0.5), span=(0.6, 3.4)):
        """A polygon filled with a dithered gradient from the lit corner to
        the shadow corner, for wings, ears, hats and cloth."""
        sp = _pts(pts)
        xs_ = [x for x, _ in sp]
        ys_ = [y for _, y in sp]
        bx0, bx1, by0, by1 = max(0, min(xs_)), min(S - 1, max(xs_)), max(0, min(ys_)), min(S - 1, max(ys_))
        if bx1 <= bx0 or by1 <= by0:
            return
        m = Image.new("L", (S, S), 0)
        ImageDraw.Draw(m).polygon(sp, fill=255)
        mask = np.array(m)[by0:by1 + 1, bx0:bx1 + 1] > 0
        ys, xs = np.mgrid[by0:by1 + 1, bx0:bx1 + 1]
        u = (xs - bx0) / max(1, bx1 - bx0)
        v = (ys - by0) / max(1, by1 - by0)
        lx, ly = light
        n = abs(lx) + abs(ly)
        t = 1 - ((u if lx < 0 else 1 - u) * abs(lx) + (v if ly < 0 else 1 - v) * abs(ly)) / n
        idx = span[0] + t * (span[1] - span[0])
        self._paint_idx(idx, bx0, by0, mask, rp)

    def _paint_idx(self, idx, bx0, by0, mask, rp):
        h, w = idx.shape
        lo = np.floor(idx)
        frac = idx - lo
        th = np.tile(BAYER, (S // 4 + 2, S // 4 + 2))[by0:by0 + h, bx0:bx0 + w]
        pick = np.where(frac > th, np.minimum(lo + 1, 4), lo).astype(np.int32)
        pal = np.array([rp[i][:3] for i in range(5)], dtype=np.uint8)
        out = np.zeros((h, w, 4), dtype=np.uint8)
        out[..., :3] = pal[pick]
        out[..., 3] = np.where(mask, 255, 0)
        patch = Image.fromarray(out, "RGBA")
        self.im.paste(patch, (bx0, by0), patch)

    def arc(self, box, start, end, col, w=1):
        x0, y0, x1, y1 = box
        self.d.arc([_sc(x0), _sc(y0), _sc(x1), _sc(y1)], start, end, fill=_rgba(col), width=w)

    def scallops(self, x0, x1, y0, y1, rp, pitch=3, r=1.5, seed=0):
        """Rows of little arcs over the painted area, offset every other row:
        feathers on a breast, scales on a hide. Only lands on painted pixels."""
        keep = self.im.copy()
        row = 0
        y = y0
        while y < y1:
            off = pitch / 2 if row % 2 else 0
            x = x0 + off
            while x < x1:
                self.arc([x - r, y - r, x + r, y + r], 20, 160, rp[0], 1)
                self.arc([x - r, y - r * 0.6, x + r, y + r * 0.6], 200, 340, rp[3], 1)
                x += pitch
            y += pitch * 0.75
            row += 1
        a = np.array(self.im)
        k = np.array(keep)
        a[k[..., 3] < 200] = k[k[..., 3] < 200]
        self.im = Image.fromarray(a, "RGBA")
        self.d = ImageDraw.Draw(self.im)

    def erase_ell(self, box):
        x0, y0, x1, y1 = box
        self.d.ellipse([_sc(x0), _sc(y0), _sc(x1), _sc(y1)], fill=(0, 0, 0, 0))

    def claw(self, x, y, dx, dy, col=(40, 34, 36)):
        """A curved claw a few pixels long from (x, y) toward (dx, dy)."""
        self.fline([(x, y), (x + dx * 0.6, y + dy * 0.6), (x + dx, y + dy + 0.5)], col, 1)
        self.pix(x + dx * 0.3, y + dy * 0.3 - 0.5, tuple(min(255, c + 90) for c in col[:3]))

    # --- finishing ---
    def finish(self, light=(-1, -1)):
        """Edge lighting over the whole figure: the pixel row along a lit
        edge is lifted, along a shadow edge sunk, so flat polygons (wings,
        ears, clothes) get the same roundness as the blobs."""
        a = np.array(self.im)
        alpha = a[..., 3] >= 200
        pad = np.pad(alpha, 2, constant_values=False)
        rgb = a[..., :3].astype(np.float32)
        up = pad[1:-3, 2:-2]
        left = pad[2:-2, 1:-3]
        down = pad[3:-1, 2:-2]
        right = pad[2:-2, 3:-1]
        down2 = pad[4:, 2:-2]
        lit = alpha & (~up | ~left)
        shade = alpha & (~down | ~right) & ~lit
        shade2 = alpha & ~down2 & ~shade & ~lit
        rgb[lit] = np.minimum(255, rgb[lit] * 1.18 + 10)
        rgb[shade] = rgb[shade] * 0.68
        rgb[shade2] = rgb[shade2] * 0.86
        a[..., :3] = rgb.astype(np.uint8)
        self.im = Image.fromarray(a, "RGBA")
        self.d = ImageDraw.Draw(self.im)

    def outline(self, col=OUT):
        """One pixel of outline around the figure, coloured from the pixel it
        borders (darkened), so the line belongs to the form rather than
        sitting on it."""
        a = np.array(self.im)
        alpha = a[..., 3] >= 200
        pad = np.pad(alpha, 1, constant_values=False)
        rgbpad = np.pad(a[..., :3], ((1, 1), (1, 1), (0, 0)))
        out = a.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = pad[1 + dy:S + 1 + dy, 1 + dx:S + 1 + dx]
            hit = ~alpha & nb & (out[..., 3] < 200)
            src = rgbpad[1 + dy:S + 1 + dy, 1 + dx:S + 1 + dx].astype(np.float32)
            mixed = src * 0.22 + np.array(col[:3], dtype=np.float32) * 0.5
            out[hit, :3] = np.clip(mixed[hit], 0, 255).astype(np.uint8)
            out[hit, 3] = 255
        self.im = Image.fromarray(out, "RGBA")
        self.d = ImageDraw.Draw(self.im)

    def big(self):
        return self.im


# ---------- creatures ----------

def dog(p, cx, base, coat, w=26, mangy=False, ears="flop", eyes=(200, 160, 40), teeth=True, f=0, lean=False):
    """A dog facing the viewer, head low and forward: haunches behind, a deep
    chest, forelegs with paws and claws, a head with brow, ears, muzzle, nose
    and a bared mouth, all in fur."""
    rp = ramp(coat)
    pale = ramp(tuple(min(255, c + 46) for c in coat))
    dark = ramp(tuple(max(0, c - 30) for c in coat))
    bob = 1 if f else 0
    hw = w // 2
    # tail, curled up behind the left haunch
    p.line([(cx - hw + 2, base - 14), (cx - hw - 4, base - 22 + bob), (cx - hw - 2, base - 28 + bob)], rp[1], 2)
    p.fline([(cx - hw + 1, base - 15), (cx - hw - 3, base - 22 + bob)], rp[3], 1)
    # haunches behind the chest, hind paws under them
    for sx in (-1, 1):
        p.blob(cx + sx * (hw - 3), base - 11, 8, 9, dark)
        hx = cx + sx * (hw - 1)
        p.blob(hx, base - 1.5, 3, 1.5, dark, rim=False)
        for k in (-1.5, 0, 1.5):
            p.pix(hx + k, base - 0.5, (40, 34, 36))
    # chest and the pale bib
    p.blob(cx, base - 14 + bob, hw, 11 if not lean else 9, rp)
    if lean:
        p.blob(cx, base - 11 + bob, hw - 4, 6, pale, rim=False)
    else:
        p.blob(cx, base - 10 + bob, hw - 6, 5, pale, rim=False)
    p.fur(rp, 11 + f, 0.16, (cx - hw, base - 24, cx + hw, base - 4), length=2)
    # forelegs: cylinders with paws and claws
    for sx in (-1, 1):
        lx = cx + sx * (hw - 6)
        p.cyl(lx - 2.5, base - 11, lx + 2.5, base - 2, rp, light=-0.5)
        p.crease([(lx - 1, base - 7), (lx + 1, base - 7)], rp)
        p.blob(lx, base - 1.5, 3.5, 1.8, rp, rim=False)
        for k in (-2, -0.5, 1, 2.5):
            p.pix(lx + k, base - 0.5, (40, 34, 36))
            p.pix(lx + k, base, (40, 34, 36))
    # ribs on a mangy dog, and bare patches
    if mangy:
        for i in range(4):
            y = base - 18 + i * 2.5 + bob
            p.fline([(cx - 8, y), (cx - 3, y + 1)], rp[0], 1)
            p.fline([(cx + 3, y + 1), (cx + 8, y)], rp[0], 1)
        for (px_, py_) in ((cx - hw + 1, base - 9), (cx + hw - 2, base - 14), (cx - hw + 6, base - 22)):
            p.blob(px_, py_, 1.6, 1.2, ramp((150, 120, 116)), rim=False, spec=False)
    # head, low and forward
    hy = base - 27 + bob
    p.blob(cx, hy, 8.5, 7.5, rp)
    # ears
    if ears == "flop":
        for sx in (-1, 1):
            p.shade_poly([(cx + sx * 8, hy - 3), (cx + sx * 13, hy + 6), (cx + sx * 6, hy + 4)], rp)
            p.poly([(cx + sx * 9, hy), (cx + sx * 11.5, hy + 5), (cx + sx * 7.5, hy + 3.5)], rp[0])
        if mangy:
            p.erase_ell([cx + 10, hy + 2, cx + 13, hy + 5])
    else:
        for sx in (-1, 1):
            p.shade_poly([(cx + sx * 8, hy - 3), (cx + sx * 10.5, hy - 14), (cx + sx * 2, hy - 5)], rp, light=(-0.4 * sx, -0.6))
            p.poly([(cx + sx * 7.5, hy - 4), (cx + sx * 9, hy - 11), (cx + sx * 4, hy - 5.5)], ramp((150, 100, 100))[1] if not mangy else rp[0])
            p.fline([(cx + sx * 8, hy - 3), (cx + sx * 10.5, hy - 14)], rp[0], 1)
        if mangy:
            p.erase_ell([cx + 8.5, hy - 10, cx + 11, hy - 7])
    # brow ridge, eyes, scowl lines
    p.rect([cx - 7, hy - 3, cx + 7, hy - 2], rp[1])
    p.shade_poly([(cx - 7.5, hy - 4), (cx - 1, hy - 3), (cx - 1, hy - 1), (cx - 7.5, hy - 1)], rp, span=(0.2, 2.2))
    p.shade_poly([(cx + 1, hy - 3), (cx + 7.5, hy - 4), (cx + 7.5, hy - 1), (cx + 1, hy - 1)], rp, span=(0.2, 2.2))
    p.animal_eye(cx - 4, hy - 0.5, eyes)
    p.animal_eye(cx + 4, hy - 0.5, eyes)
    p.fline([(cx - 6.5, hy - 2.5), (cx - 2, hy - 1.5)], rp[0], 1)
    p.fline([(cx + 6.5, hy - 2.5), (cx + 2, hy - 1.5)], rp[0], 1)
    if mangy:
        p.fline([(cx - 7, hy + 1), (cx - 5, hy + 3)], rp[0], 1)
    # muzzle, pushed forward and down so it reads as a snout
    p.blob(cx, hy + 6, 6, 5, pale if not mangy else rp, light=(-0.3, -0.6))
    p.shade_poly([(cx - 3, hy + 2.5), (cx + 3, hy + 2.5), (cx + 2.5, hy + 5.5), (cx - 2.5, hy + 5.5)], ramp((36, 26, 28)), span=(1, 3.5))
    p.pix(cx - 2, hy + 3, (90, 70, 74))
    p.pix(cx - 1.5, hy + 3, (90, 70, 74))
    p.pix(cx - 1.5, hy + 4.5, (16, 10, 12))
    p.pix(cx + 1.5, hy + 4.5, (16, 10, 12))
    if teeth:
        p.rect([cx - 4.5, hy + 8, cx + 4.5, hy + 9.5], (46, 18, 24))
        p.rect([cx - 3, hy + 9, cx + 3, hy + 10], (150, 50, 60))
        for tx in (-4, -2.5, -1, 0.5, 2, 3.5):
            p.pix(cx + tx, hy + 8, (244, 240, 226))
            p.pix(cx + tx, hy + 8.5, (220, 212, 196))
        p.pix(cx - 4, hy + 9, (244, 240, 226))
        p.pix(cx + 3.5, hy + 9, (244, 240, 226))
    else:
        p.fline([(cx - 3.5, hy + 8), (cx, hy + 8.5), (cx + 3.5, hy + 8)], (50, 30, 30), 1)
    p.fur(rp, 17 + f, 0.14, (cx - 10, hy - 8, cx + 10, hy + 4), length=2)


def owl(p, cx, base, coat, face, f=0, eyes=2, horned=False, wings="half", glow=False):
    rp = ramp(coat)
    fp = ramp(face)
    dk = ramp(tuple(max(0, c - 40) for c in coat))
    bob = 1 if f else 0
    # wings, feathered in rows
    if wings == "up":
        for sx in (-1, 1):
            pts = [(cx + sx * 8, base - 26), (cx + sx * 22, base - 44 + bob * 2), (cx + sx * 20, base - 14), (cx + sx * 10, base - 8)]
            p.shade_poly(pts, rp, light=(-0.5 * sx, -0.4))
            for i in range(4):
                p.inner_line([(cx + sx * (10 + i * 3), base - 11 - i * 2), (cx + sx * (18 + i * 1.5), base - 30 - i * 4 + bob * 2)], rp)
            for k in range(3):
                p.erase_ell([cx + sx * (10 + k * 4) - 1.5, base - 11 + k * 1.2, cx + sx * (10 + k * 4) + 1.5, base - 7 + k * 1.2])
    else:
        for sx in (-1, 1):
            pts = [(cx + sx * 8, base - 28), (cx + sx * 16.5, base - 20), (cx + sx * 14.5, base - 5), (cx + sx * 8, base - 8)]
            p.shade_poly(pts, rp, light=(-0.5 * sx, -0.4))
            for i in range(4):
                p.inner_line([(cx + sx * (9.5 + i * 1.5), base - 9 - i * 3), (cx + sx * (11 + i * 1.5), base - 25 + i * 1.5)], rp)
            for k in range(3):
                p.erase_ell([cx + sx * (9 + k * 2.2) - 1.2, base - 7 + k * 0.6, cx + sx * (9 + k * 2.2) + 1.2, base - 4 + k * 0.6])
    # body and breast feathers
    p.blob(cx, base - 18 + bob, 10, 15, rp)
    p.blob(cx, base - 15 + bob, 6.5, 10, fp, rim=False, spec=False)
    p.scallops(cx - 7, cx + 7, base - 26 + bob, base - 6, dk, pitch=3, r=1.3)
    # feet: three toes each with a claw
    for sx in (-1, 1):
        fx = cx + sx * 4
        for t, tx in enumerate((-2.5, 0, 2.5)):
            p.line([(fx, base - 3.5), (fx + tx, base - 0.5)], (120, 96, 56), 1)
            p.claw(fx + tx, base - 0.5, tx * 0.3, 1.2)
    # head
    p.blob(cx, base - 34 + bob, 9.5, 8.5, rp)
    # facial discs ringed in dark feathers
    for sx in (-1, 1):
        p.blob(cx + sx * 4, base - 34 + bob, 5, 6, fp, light=(-0.2, -0.3), rim=False)
        p.arc([cx + sx * 4 - 5, base - 40 + bob, cx + sx * 4 + 5, base - 28 + bob], 0, 360, dk[0], 1)
    if horned:
        for sx in (-1, 1):
            p.shade_poly([(cx + sx * 8, base - 38 + bob), (cx + sx * 12.5, base - 49 + bob), (cx + sx * 3, base - 40 + bob)], rp, light=(-0.5 * sx, -0.6))
            p.fline([(cx + sx * 7, base - 39 + bob), (cx + sx * 11.5, base - 47 + bob)], dk[0], 1)
    # beak
    p.shade_poly([(cx - 1.5, base - 34.5 + bob), (cx + 1.5, base - 34.5 + bob), (cx, base - 29.5 + bob)], ramp((110, 80, 44)), span=(1, 3.5))
    # eyes
    pos = [(cx - 4, base - 35 + bob), (cx + 4, base - 35 + bob)]
    extra = [(cx - 6.5, base - 31 + bob), (cx + 6.5, base - 31 + bob), (cx, base - 39.5 + bob), (cx + 2, base - 31 + bob)]
    pos += extra[:max(0, eyes - 2)]
    for (x, y) in pos:
        if glow:
            p.arc([x - 2.5, y - 2.5, x + 2.5, y + 2.5], 0, 360, (60, 40, 20), 1)
            p.eye(x, y, (255, 220, 50), 1.5)
        else:
            p.animal_eye(x, y, (240, 200, 40))
    p.fur(rp, 21 + f, 0.08, (cx - 12, base - 44, cx + 12, base - 26))


def little_man(p, cx, base, skin, h=36, arms="up", f=0, eyes=True, glow=(255, 236, 90), claws=True):
    """The Kelly creature: a big domed head with huge pointed ears, lamp eyes,
    a thin silvery body and long arms that end in claws. Hovers a little."""
    rp = ramp(skin, steps=(-90, -45, 0, 45, 90))
    bob = 1 if f else 0
    top = base - h + bob
    # legs, thin, with splayed feet
    for sx in (-1, 1):
        p.line([(cx + sx * 3, base - 14), (cx + sx * 5, base - 2)], rp[1], 2)
        p.fline([(cx + sx * 2.5, base - 14), (cx + sx * 4.5, base - 3)], rp[3], 1)
        p.pix(cx + sx * 4, base - 8, rp[0])
        p.blob(cx + sx * 5, base - 1, 3, 1.2, rp, rim=False)
    # torso, ribbed
    p.blob(cx, base - 18, 5, 8, rp)
    p.inner_line([(cx, base - 24), (cx, base - 12)], rp)
    for i in range(3):
        y = base - 22 + i * 3
        p.fline([(cx - 3.5, y), (cx - 1, y + 1)], rp[0], 1)
        p.fline([(cx + 1, y + 1), (cx + 3.5, y)], rp[0], 1)
    # arms, jointed, with claws
    for sx in (-1, 1):
        if arms == "up":
            pts = [(cx + sx * 4, base - 22), (cx + sx * 12, base - 30), (cx + sx * 16, top + 2)]
        else:
            pts = [(cx + sx * 4, base - 22), (cx + sx * 14, base - 20), (cx + sx * 20, base - 30)]
        p.line(pts, rp[1], 2)
        p.fline(pts, rp[3], 1)
        p.blob(pts[1][0], pts[1][1], 1.6, 1.6, rp, rim=False)
        ex, ey = pts[-1]
        if claws:
            for k in range(3):
                dx, dy = sx * (k * 2 - 1.5), -4.5 - (k % 2) * 2
                if arms != "up":
                    dx, dy = sx * (2 + k * 0.8), -3 + (k - 1) * 2.2
                p.line([(ex, ey), (ex + dx * 0.6, ey + dy * 0.6)], rp[1], 1)
                p.claw(ex + dx * 0.6, ey + dy * 0.6, dx * 0.5, dy * 0.5, rp[0])
    # head, domed
    p.blob(cx, top + 8, 9, 8, rp, light=(-0.3, -0.6))
    # ears, huge, with the inner fold
    for sx in (-1, 1):
        p.shade_poly([(cx + sx * 8, top + 6), (cx + sx * 17.5, top - 1.5), (cx + sx * 7, top + 12)], rp, light=(-0.5 * sx, -0.5))
        p.poly([(cx + sx * 9, top + 7), (cx + sx * 14.5, top + 1.5), (cx + sx * 8, top + 10)], rp[0])
        p.fline([(cx + sx * 9.5, top + 7.5), (cx + sx * 13.5, top + 3)], rp[1], 1)
    # mouth, a thin line with the suggestion of teeth
    p.fline([(cx - 2.5, top + 13), (cx + 2.5, top + 13)], rp[0], 1)
    for k in (-1.5, 0, 1.5):
        p.pix(cx + k, top + 13.5, rp[3])
    if eyes:
        for sx in (-1, 1):
            p.arc([cx + sx * 4 - 3, top + 4, cx + sx * 4 + 3, top + 10], 0, 360, rp[0], 1)
            p.eye(cx + sx * 4, top + 7, glow, 2)


def mothman(p, cx, base, f=0):
    grey = ramp((88, 90, 104))
    dark = ramp((52, 54, 68))
    bob = 1 if f else 0
    # wings, folded like a cape, tips above the shoulders, scalloped below
    for sx in (-1, 1):
        pts = [(cx + sx * 6, base - 40), (cx + sx * 20, base - 46 - bob * 2), (cx + sx * 21, base - 6), (cx + sx * 9, base - 2)]
        p.shade_poly(pts, dark, light=(-0.6 * sx, -0.5), span=(0.3, 3.0))
        p.shade_poly([(cx + sx * 6, base - 40), (cx + sx * 13, base - 43 - bob), (cx + sx * 14, base - 4), (cx + sx * 9, base - 2)], dark, light=(0.6 * sx, -0.6), span=(1.0, 3.4))
        for i in range(3):
            p.inner_line([(cx + sx * (9 + i * 4), base - 38), (cx + sx * (10.5 + i * 4), base - 6)], dark)
            p.fline([(cx + sx * (9.5 + i * 4), base - 37), (cx + sx * (11 + i * 4), base - 8)], dark[2], 1)
        for k in range(4):
            x = cx + sx * (10 + k * 3)
            p.erase_ell([x - 1.8, base - 5 + (k % 2), x + 1.8, base - 1 + (k % 2)])
    # body: furred thorax, banded abdomen
    p.blob(cx, base - 30 + bob, 7, 10, grey)
    p.blob(cx, base - 14 + bob, 6, 10, grey, light=(-0.4, -0.2))
    for i in range(4):
        y = base - 20 + i * 3.5 + bob
        p.arc([cx - 5.5, y - 2, cx + 5.5, y + 2], 10, 170, grey[0], 1)
    p.fur(grey, 31 + f, 0.3, (cx - 8, base - 42, cx + 8, base - 20), length=2)
    # legs
    for sx in (-1, 1):
        p.cyl(cx + sx * 3.5 - 1.5, base - 6, cx + sx * 3.5 + 1.5, base, grey)
        p.rect([cx + sx * 3.5 - 2, base - 0.5, cx + sx * 3.5 + 2, base], grey[0])
    # a head that is mostly neck and eyes, with feathered antennae
    p.blob(cx, base - 42 + bob, 6, 6, grey)
    for sx in (-1, 1):
        p.fline([(cx + sx * 2, base - 47 + bob), (cx + sx * 6, base - 52 + bob)], grey[0], 1)
        for k in range(3):
            p.pix(cx + sx * (3 + k * 1.3), base - 49.5 - k * 1.2 + bob, grey[3])
    p.eye(cx - 3, base - 43 + bob, (255, 50, 40), 2)
    p.eye(cx + 3, base - 43 + bob, (255, 50, 40), 2)


def crawler(p, cx, base, f=0):
    """The igloo crawler: a pale hunched thing on too many legs, the colour of
    the TNT bunkers' concrete, with a lump of a head and lamp eyes."""
    rp = ramp((150, 150, 144))
    bob = 1 if f else 0
    for i, lx in enumerate((-18, -11, -4, 4, 11, 18)):
        jog = 2 if (i + f) % 2 else 0
        a0 = (cx + lx // 2, base - 10)
        a1 = (cx + lx, base - 14 - jog)
        a2 = (cx + lx + (2 if lx > 0 else -2), base)
        p.line([a0, a1, a2], rp[1], 2)
        p.fline([a0, a1], rp[3], 1)
        p.blob(a1[0], a1[1], 1.6, 1.6, rp, rim=False)
        p.pix(a2[0], a2[1], rp[0])
    p.blob(cx, base - 14 + bob, 16, 9, rp)
    p.blob(cx - 2, base - 24 + bob, 8, 7, rp)
    for i in range(5):
        p.crease([(cx - 12 + i * 6, base - 20 + bob), (cx - 10 + i * 6, base - 8 + bob)], rp)
    for i in range(3):
        p.arc([cx - 13 + i * 2, base - 21 + bob + i * 3, cx + 13 - i * 2, base - 9 + bob + i * 3], 20, 160, rp[0], 1)
    p.fline([(cx - 5, base - 19 + bob), (cx - 2, base - 17 + bob), (cx + 1, base - 19 + bob)], rp[0], 1)
    for k in (-4, -1, 2):
        p.pix(cx + k, base - 18 + bob, (90, 80, 76))
    p.eye(cx - 5, base - 25 + bob, (255, 240, 140), 1)
    p.eye(cx + 1, base - 25 + bob, (255, 240, 140), 1)
    p.fur(rp, 41, 0.22, (cx - 16, base - 32, cx + 16, base - 4), length=1)


def monkey(p, cx, base, f=0):
    fur_ = ramp((120, 86, 50))
    face = ramp((222, 192, 160))
    red = ramp((200, 50, 50))
    bob = 1 if f else 0
    # tail
    p.line([(cx + 6, base - 14), (cx + 16, base - 22), (cx + 18, base - 8), (cx + 14, base - 2)], fur_[1], 2)
    p.fline([(cx + 6, base - 14.5), (cx + 15.5, base - 22), (cx + 17.5, base - 8)], fur_[3], 1)
    # legs
    for sx in (-1, 1):
        p.cyl(cx + sx * 4 - 1.5, base - 12, cx + sx * 4 + 1.5, base - 1, fur_)
        p.blob(cx + sx * 4.5, base - 0.8, 2.5, 1.2, fur_, rim=False)
    # the tiny jacket with gold trim and buttons
    p.blob(cx, base - 18 + bob, 6.5, 7.5, red)
    p.fline([(cx - 2.5, base - 24 + bob), (cx - 2.5, base - 12 + bob)], (240, 210, 110), 1)
    p.fline([(cx + 2.5, base - 24 + bob), (cx + 2.5, base - 12 + bob)], (240, 210, 110), 1)
    p.rect([cx - 1.5, base - 23 + bob, cx + 1.5, base - 12 + bob], (250, 236, 200))
    for k in range(3):
        p.pix(cx - 1, base - 21 + k * 3 + bob, (240, 200, 60))
        p.pix(cx + 1, base - 21 + k * 3 + bob, (240, 200, 60))
    # arms
    p.line([(cx - 5, base - 22 + bob), (cx - 13, base - 14 + (3 if f else 0))], fur_[1], 2)
    p.line([(cx + 5, base - 22 + bob), (cx + 13, base - 14 - (3 if f else 0))], fur_[1], 2)
    p.blob(cx - 13, base - 14 + (3 if f else 0), 1.8, 1.5, face, rim=False)
    p.blob(cx + 13, base - 14 - (3 if f else 0), 1.8, 1.5, face, rim=False)
    # head with ear tufts and a fez
    p.blob(cx, base - 30 + bob, 7.5, 6.5, fur_)
    p.blob(cx - 6, base - 30 + bob, 2.2, 2.2, fur_)
    p.blob(cx + 6, base - 30 + bob, 2.2, 2.2, fur_)
    p.blob(cx, base - 29 + bob, 4.5, 4.5, face, rim=False)
    p.animal_eye(cx - 2, base - 31 + bob, (60, 40, 30))
    p.animal_eye(cx + 2, base - 31 + bob, (60, 40, 30))
    p.pix(cx - 0.5, base - 28.5 + bob, face[1])
    p.pix(cx + 0.5, base - 28.5 + bob, face[1])
    p.fline([(cx - 2, base - 26.5 + bob), (cx, base - 26 + bob), (cx + 2, base - 26.5 + bob)], (90, 40, 40), 1)
    p.shade_poly([(cx - 4, base - 35 + bob), (cx + 4, base - 35 + bob), (cx + 3, base - 40 + bob), (cx - 3, base - 40 + bob)], ramp((190, 40, 60)))
    p.fline([(cx + 1, base - 40 + bob), (cx + 4, base - 43 + bob)], (240, 200, 60), 1)
    p.pix(cx + 4, base - 43 + bob, (250, 220, 80))
    p.fur(fur_, 51 + f, 0.2, (cx - 10, base - 38, cx + 10, base - 24))


def gull(p, x, y, flap):
    body = ramp((236, 236, 240))
    wing = ramp((180, 184, 196))
    p.blob(x, y, 5, 3, body, light=(-0.3, -0.5))
    p.blob(x + 4, y - 2, 2.2, 2.2, body)
    p.shade_poly([(x + 6, y - 2.5), (x + 9.5, y - 1), (x + 6, y - 0.5)], ramp((230, 170, 50)), span=(1.5, 3.8))
    p.pix(x + 9, y - 1, (200, 60, 40))
    if flap:
        p.shade_poly([(x - 2, y - 1), (x - 11, y - 8), (x - 9, y - 1), (x + 1, y + 1)], wing, light=(0.3, -0.7))
        p.shade_poly([(x + 2, y - 1), (x + 10, y - 8), (x + 9, y - 1), (x + 1, y + 1)], wing, light=(-0.3, -0.7), span=(0.3, 2.6))
        for k in range(3):
            p.fline([(x - 4 - k * 2, y - 1 - k * 1.8), (x - 6 - k * 2, y - 1)], wing[0], 1)
            p.fline([(x + 4 + k * 2, y - 1 - k * 1.8), (x + 6 + k * 2, y - 1)], wing[0], 1)
    else:
        p.shade_poly([(x - 2, y), (x - 12, y + 5), (x - 8, y + 1), (x + 1, y + 1)], wing, light=(0.3, -0.7))
        p.shade_poly([(x + 2, y), (x + 11, y + 5), (x + 8, y + 1), (x + 1, y + 1)], wing, light=(-0.3, -0.7), span=(0.3, 2.6))
        for k in range(3):
            p.fline([(x - 4 - k * 2, y + 0.5 + k), (x - 6 - k * 2, y + 2.5 + k)], wing[0], 1)
            p.fline([(x + 4 + k * 2, y + 0.5 + k), (x + 6 + k * 2, y + 2.5 + k)], wing[0], 1)
    p.pix(x + 5, y - 3, (20, 20, 20))
    p.pix(x + 4.5, y - 3.5, (250, 250, 250))


# ---------- people ----------

def person(p, cx, base, skin, hair, top, pants, f=0, hat=None, beard=None, gun=None, h=38,
           eyes=True, mouth="line", lean=0, boots=(50, 40, 36), bulk=0):
    """A person facing the viewer: boots, trousers, a jacket or shirt with
    sleeves and a collar, hands, a head with a face, hair and maybe a hat or
    beard. Frame 2 shifts the weight and the gun."""
    sk, hr, tp, pt = ramp(skin), ramp(hair), ramp(top), ramp(pants)
    bt = ramp(boots)
    cx += lean if f else 0
    bob = 1 if f else 0
    top_y = base - h + bob
    bw = 6 + bulk
    # legs and boots
    for sx in (-1, 1):
        lx = cx + sx * 3
        p.cyl(lx - 2.5, base - 16, lx + 2.5, base - 3, pt, light=-0.5)
        p.crease([(lx - 1.5, base - 9), (lx + 1, base - 9)], pt)
        p.cyl(lx - 3, base - 4.5, lx + 3, base, bt, light=-0.5)
        p.rect([lx - 3, base - 4.5, lx + 3, base - 4.5], bt[3])
        p.fline([(lx - 2.5, base - 1), (lx + 2.5, base - 1)], bt[0], 1)
    # body: jacket, collar, buttons, belt
    p.blob(cx, base - 24 + bob, bw, 10, tp)
    p.shade_poly([(cx - bw + 1, base - 18 + bob), (cx + bw - 1, base - 18 + bob), (cx + bw - 1, base - 14.5 + bob), (cx - bw + 1, base - 14.5 + bob)], tp, span=(0.3, 2.0))
    p.inner_line([(cx, base - 31 + bob), (cx, base - 16 + bob)], tp)
    p.fline([(cx + 0.5, base - 31 + bob), (cx + 0.5, base - 16 + bob)], tp[3], 1)
    p.poly([(cx - 3.5, base - 33 + bob), (cx, base - 29 + bob), (cx + 3.5, base - 33 + bob), (cx + 2.5, base - 34 + bob), (cx, base - 31 + bob), (cx - 2.5, base - 34 + bob)], tp[0])
    for k in range(3):
        p.pix(cx - 1, base - 27 + k * 3 + bob, tp[4])
    p.rect([cx - bw + 1, base - 16 + bob, cx + bw - 1, base - 15 + bob], (40, 30, 28))
    p.pix(cx, base - 15.5 + bob, (200, 180, 90))
    p.crease([(cx - bw + 2, base - 22 + bob), (cx - bw + 4, base - 17 + bob)], tp)
    p.crease([(cx + bw - 2, base - 22 + bob), (cx + bw - 4, base - 17 + bob)], tp)
    # arms and hands
    for sx in (-1, 1):
        ax = cx + sx * (bw + 1)
        p.cyl(ax - 1.5, base - 31 + bob, ax + 1.5, base - 19 + bob, tp, light=-0.5 * sx)
        p.crease([(ax - 1, base - 25 + bob), (ax + 1, base - 25 + bob)], tp)
        p.blob(ax + sx * 0.5, base - 17.5 + bob, 1.8, 1.8, sk, rim=False)
    # head and face
    hy = top_y + 7
    p.blob(cx, hy, 5.5, 6.5, sk, light=(-0.3, -0.5))
    p.cyl(cx - 1.5, hy + 5, cx + 1.5, hy + 7.5, sk)
    if hair is not None:
        p.blob(cx, hy - 3, 5.5, 3.5, hr)
        p.rect([cx - 5.5, hy - 4, cx + 5.5, hy - 2], hr[2])
        for k in range(5):
            p.pix(cx - 4.5 + k * 2.2, hy - 1.5, hr[1])
        p.fline([(cx - 4, hy - 5), (cx + 1, hy - 5.5)], hr[3], 1)
    if beard:
        bd = ramp(beard)
        p.shade_poly([(cx - 5, hy + 1), (cx + 5, hy + 1), (cx + 3.5, hy + 6.5), (cx, hy + 7.5), (cx - 3.5, hy + 6.5)], bd, span=(0.6, 3.2))
        p.fur(bd, 61 + f, 0.3, (cx - 5, hy + 1, cx + 5, hy + 8), length=2)
    if eyes:
        for sx in (-1, 1):
            p.pix(cx + sx * 2 - 0.5, hy - 0.5, (250, 248, 246))
            p.pix(cx + sx * 2, hy - 0.5, (30, 24, 24))
            p.pix(cx + sx * 2 - 0.5, hy, (30, 24, 24))
            p.pix(cx + sx * 2, hy, (30, 24, 24))
            p.fline([(cx + sx * 3, hy - 1.5), (cx + sx * 1, hy - 1.5)], sk[0], 1)
        p.pix(cx, hy + 1, sk[1])
        p.pix(cx + 0.5, hy + 1, sk[0])
    if mouth == "line":
        p.fline([(cx - 1.5, hy + 3), (cx + 1.5, hy + 3)], sk[0], 1)
    elif mouth == "wide":
        p.fline([(cx - 5, hy + 3), (cx + 5, hy + 3)], (60, 10, 20), 2)
        for k in range(5):
            p.pix(cx - 4 + k * 2, hy + 2.5, (240, 236, 230))
    if hat == "brim":
        p.shade_poly([(cx - 8.5, hy - 4), (cx + 8.5, hy - 4), (cx + 8.5, hy - 2.5), (cx - 8.5, hy - 2.5)], hr, span=(0, 2))
        p.shade_poly([(cx - 5.5, hy - 10), (cx + 5.5, hy - 10), (cx + 5.5, hy - 4), (cx - 5.5, hy - 4)], hr, span=(0.6, 3.4))
        p.fline([(cx - 5, hy - 5.5), (cx + 5, hy - 5.5)], hr[0], 1)
        p.fline([(cx - 5, hy - 10), (cx + 1, hy - 10.5)], hr[0], 1)
    elif hat == "fedora":
        fd = ramp((40, 36, 46))
        p.shade_poly([(cx - 8.5, hy - 3.5), (cx + 8.5, hy - 3.5), (cx + 8, hy - 1.5), (cx - 8, hy - 1.5)], fd, span=(0, 2.2))
        p.shade_poly([(cx - 5.5, hy - 11), (cx + 5.5, hy - 11), (cx + 5.5, hy - 3.5), (cx - 5.5, hy - 3.5)], fd, span=(0.6, 3.6))
        p.fline([(cx - 3, hy - 11), (cx + 3, hy - 11)], fd[0], 1)
        p.rect([cx - 5.5, hy - 5.5, cx + 5.5, hy - 4.5], (70, 20, 34))
    elif hat == "helmet":
        hm = ramp((110, 116, 90))
        p.blob(cx, hy - 3, 7.5, 5.5, hm, light=(-0.3, -0.6))
        p.rect([cx - 6.5, hy - 1.5, cx + 6.5, hy - 1], (236, 236, 230))
        p.fline([(cx - 6, hy - 1), (cx - 5, hy + 4)], (60, 56, 50), 1)
        p.fline([(cx + 6, hy - 1), (cx + 5, hy + 4)], (60, 56, 50), 1)
        p.fur(hm, 71, 0.15, (cx - 8, hy - 9, cx + 8, hy - 1), length=1)
    elif hat == "cone":
        cn = ramp((240, 210, 60))
        p.shade_poly([(cx - 6.5, hy - 4), (cx, hy - 19), (cx + 6.5, hy - 4)], cn, light=(-0.5, -0.4), span=(1, 3.8))
        for k in range(3):
            y = hy - 7 - k * 4
            w = 6.5 * (y - (hy - 19)) / 15
            p.fline([(cx - w, y), (cx + w, y)], (90, 60, 170), 1)
        p.rect([cx - 7.5, hy - 4, cx + 7.5, hy - 3], (220, 190, 50))
        p.blob(cx, hy - 19, 1.6, 1.6, ramp((230, 60, 50)), rim=False)
    if gun:
        gx0, gy0, gx1, gy1 = gun
        shift = -2 if f else 0
        x0, y0, x1, y1 = cx + gx0, base + gy0 + shift, cx + gx1, base + gy1 + shift
        mx, my = x0 + (x1 - x0) * 0.4, y0 + (y1 - y0) * 0.4
        p.line([(x0, y0), (mx, my)], (80, 56, 40), 2.5)
        p.fline([(x0 + 0.5, y0 - 0.5), (mx, my - 1)], (130, 96, 64), 1)
        p.line([(mx, my), (x1, y1)], (60, 62, 70), 1.5)
        p.fline([(mx, my - 0.5), (x1, y1 - 0.5)], (150, 154, 164), 1)
        p.pix(x1, y1, (30, 30, 36))


def eyeshine(p, cx, base, f=0):
    """Something low in the dark, mostly not there: a soft black shape and two lamps."""
    for i, (r, a) in enumerate(((16, 60), (12, 110), (8, 160))):
        p.ell([cx - r, base - 26 - r // 2 + i, cx + r, base - 2 + i], fill=(12, 10, 18, a))
    p.ell([cx - 9, base - 38 + (1 if f else 0), cx + 9, base - 22], fill=(14, 12, 20, 190))
    r = 2 if not f else 1
    p.eye(cx - 4, base - 31 + (1 if f else 0), (255, 236, 90), r)
    p.eye(cx + 4, base - 31 + (1 if f else 0), (255, 236, 90), r)


def cave_breath(p, cx, base, f=0):
    """Mist with a face in it: layered translucent puffs and three dark holes."""
    rnd = random.Random(3 + f)
    for _ in range(26):
        x, y, r = rnd.randrange(2, 40), rnd.randrange(4, 40), rnd.randrange(3, 10)
        p.ell([x, y, x + r, y + r], fill=(210, 224, 236, 60))
    for _ in range(14):
        x, y, r = rnd.randrange(8, 36), rnd.randrange(8, 36), rnd.randrange(2, 5)
        p.ell([x, y, x + r, y + r], fill=(236, 244, 250, 70))
    p.ell([cx - 11, base - 36, cx + 11, base - 12], fill=(228, 238, 246, 150))
    p.ell([cx - 8, base - 33, cx + 6, base - 20], fill=(240, 246, 250, 120))
    p.ell([cx - 6, base - 30, cx - 3, base - 26], fill=(90, 110, 130, 210))
    p.ell([cx + 2, base - 30, cx + 5, base - 26], fill=(90, 110, 130, 210))
    p.ell([cx - 2, base - 23, cx + 2, base - 17 + (2 if f else 0)], fill=(90, 110, 130, 210))


def static_shade(p, cx, base, f=0):
    """A person-shaped hole full of television snow."""
    person(p, cx, base, (128, 128, 128), (128, 128, 128), (128, 128, 128), (128, 128, 128), f=f, eyes=False, mouth="", h=40)
    rnd = random.Random(7 + f)
    px = p.im.load()
    cells = {}
    for y in range(S):
        for x in range(S):
            if px[x, y][3]:
                key = (x // 2, y // 2)
                if key not in cells:
                    cells[key] = rnd.choice((30, 70, 120, 170, 220, 250))
                v = cells[key]
                px[x, y] = (v, v, v, 255)
    if f:
        for y in range(K * 10, K * 14):
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
            p.ell([12 + i * 8, 40 + i, 24 + i * 8, 44 + i], fill=(180, 200, 220, 60))
    elif name == "the_tall_one":
        p.rect([0, 0, 47, 47], (236, 230, 214, 255))
        p.rect([4, 3, 43, 47], (18, 16, 24, 255))
        little_man(p, 24, 47, (190, 196, 204), h=46 if not f else 45, f=f)
        p.rect([23, 3, 24, 47], (236, 230, 214, 170))
        p.rect([4, 25, 43, 26], (236, 230, 214, 170))
    elif name == "roof_walker":
        for y in range(0, 30):
            t = y / 30.0
            p.rect([0, y, 47, y], (int(40 + 160 * t), int(40 + 120 * t), int(80 + 60 * t), 255))
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
        p.ell([21, base - 19, 27, base - 13], fill=(255, 240, 170, 255))
        p.ell([19, base - 21, 29, base - 11], fill=(255, 240, 170, 40))
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
        for y in range(K * (base - 34), K * (base - 14)):
            for x in range(K * 16, K * 33):
                if px[x, y][3] and (x // 6 + y // 6) % 2:
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
        p.finish()
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
                v = int((v - 128) * 1.25 + 128)
                v = max(0, min(255, v))
                out.append((v // 32) * 32 + 10 if v < 240 else 255)
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
