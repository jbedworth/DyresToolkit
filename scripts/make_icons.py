"""Draw the threat label's icons: a heater shield (tank view) and two crossed
swords (DPS and healer view).

Each icon is two 64x64 32-bit TGAs with alpha (John, 2026-11-11: "can we make
the shield/swords icon itself use the color scheme"):

- <Name>Fill.tga: a white-to-grey fill. Threat.lua tints it with
  SetVertexColor in the label's status color, so the grey shade (lighter at
  the top, a lit bevel at the upper-left edges) stays in every color.
- <Name>Edge.tga: a dark outline drawn above the fill with no tint, so the
  icon reads on any background.

Pure Python (no image library): each shape is a signed distance field (in
pixels, negative inside), sampled 4x4 per pixel for smooth edges. The output
is the same on every run. Run from the repository root:

    python scripts/make_icons.py            # writes Textures/*.tga
    python scripts/make_icons.py --preview DIR   # also PNG previews
"""

import argparse
import math
import struct
import zlib
from pathlib import Path

SIZE = 64
SAMPLES = 4
OUTLINE = 4.0
EDGE_SHADE = 0.08
# Light from the upper left (y grows down), for the bevel.
LIGHT = (-0.6, -0.8)
BEVEL = 5.0
ICONS = ("Shield", "Swords")
TEXTURES = tuple(f"Textures/{icon}{layer}.tga" for icon in ICONS for layer in ("Fill", "Edge"))
# The label's status colors (Threat.lua): green, yellow, red, blue, orange
# (LOSING), and white (a secret status).
COLORS = (
    ("green", (0.2, 1, 0.2)),
    ("yellow", (1, 0.85, 0)),
    ("red", (1, 0.2, 0.2)),
    ("blue", (0.3, 0.6, 1)),
    ("orange", (1, 0.5, 0)),
    ("white", (1, 1, 1)),
)


# Distance fields ---------------------------------------------------------------------

def polygon_distance(points, x, y):
    """Signed distance from (x, y) to a closed polygon: negative inside."""
    best = math.inf
    inside = False
    count = len(points)
    for index in range(count):
        ax, ay = points[index]
        bx, by = points[(index + 1) % count]
        ex, ey = bx - ax, by - ay
        wx, wy = x - ax, y - ay
        length = ex * ex + ey * ey
        t = 0.0 if length == 0 else max(0.0, min(1.0, (wx * ex + wy * ey) / length))
        dx, dy = wx - ex * t, wy - ey * t
        best = min(best, dx * dx + dy * dy)
        if (ay > y) != (by > y) and x < ax + (y - ay) * ex / ey:
            inside = not inside
    distance = math.sqrt(best)
    return -distance if inside else distance


def bezier(p0, p1, p2, steps):
    """Points along a quadratic curve, p0 left out."""
    out = []
    for step in range(1, steps + 1):
        t = step / steps
        u = 1 - t
        out.append((u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                    u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1]))
    return out


# The shield: a flat top, straight sides, and curves to a point.
TOP, LEFT, RIGHT, SIDE_END, POINT = 8.0, 12.0, 52.0, 28.0, (32.0, 59.0)
SHIELD = ([(LEFT, TOP), (RIGHT, TOP), (RIGHT, SIDE_END)]
          + bezier((RIGHT, SIDE_END), (RIGHT, 48.0), POINT, 16)
          + bezier(POINT, (LEFT, 48.0), (LEFT, SIDE_END), 16))
# The face's rim: a band this deep inside the edge, split from the face by a
# thin dark line.
RIM = 6.5


def shield(x, y):
    return polygon_distance(SHIELD, x, y)


def sword_parts(length):
    """A sword along +u from its pommel (u = 0) to its tip (u = length), in
    (u, v) with v across: pommel, grip, cross guard, blade."""
    blade_from, blade_half, taper = 15.0, 4.2, 11.0
    return {
        "grip": [(2.0, -2.3), (11.0, -2.3), (11.0, 2.3), (2.0, 2.3)],
        "guard": [(11.0, -9.0), (14.5, -9.0), (15.5, -7.5), (15.5, 7.5), (14.5, 9.0), (11.0, 9.0)],
        "blade": [(blade_from, -blade_half), (length - taper, -blade_half), (length, 0.0),
                  (length - taper, blade_half), (blade_from, blade_half)],
    }


class Sword:
    POMMEL = 4.4

    def __init__(self, start, end):
        self.start = start
        dx, dy = end[0] - start[0], end[1] - start[1]
        self.length = math.hypot(dx, dy)
        self.axis = (dx / self.length, dy / self.length)
        self.parts = sword_parts(self.length)

    def local(self, x, y):
        wx, wy = x - self.start[0], y - self.start[1]
        ax, ay = self.axis
        return wx * ax + wy * ay, -wx * ay + wy * ax

    def distance(self, x, y):
        u, v = self.local(x, y)
        best = math.hypot(u, v) - self.POMMEL
        for points in self.parts.values():
            best = min(best, polygon_distance(points, u, v))
        return best

    def shade(self, x, y):
        """The fill's grey: the blade two-tone across its ridge, the hilt
        darker."""
        u, v = self.local(x, y)
        if u >= 15.5:
            return 1.0 if v < -0.4 else 0.7 if v > 0.4 else 0.85
        if 11.0 <= u < 15.5:
            return 0.9
        return 0.62 if u >= 2.0 + 0.6 else 0.85


# Sword B lies on top of sword A.
SWORD_A = Sword((11.0, 53.0), (55.0, 9.0))
SWORD_B = Sword((53.0, 53.0), (9.0, 9.0))


# Layers ------------------------------------------------------------------------------

def clamp(value):
    return max(0.0, min(1.0, value))


def bevel(distance_at, x, y, depth):
    """Light on the edges' slope (BEVEL px wide) facing LIGHT."""
    inside = -distance_at(x, y)
    if inside <= 0 or inside >= depth:
        return 0.0
    step = 0.5
    gx = distance_at(x + step, y) - distance_at(x - step, y)
    gy = distance_at(x, y + step) - distance_at(x, y - step)
    norm = math.hypot(gx, gy) or 1.0
    facing = (gx * LIGHT[0] + gy * LIGHT[1]) / norm
    return facing * (1 - inside / depth)


def shield_shade(x, y):
    inside = -shield(x, y)
    vertical = (y - TOP) / (POINT[1] - TOP)
    if inside < RIM:
        base = 1.0 - 0.12 * vertical
    else:
        base = 0.96 - 0.2 * vertical
    return clamp(base + 0.22 * bevel(shield, x, y, BEVEL))


def swords_shade(x, y):
    sword = SWORD_B if SWORD_B.distance(x, y) < 0.5 else SWORD_A
    return clamp(sword.shade(x, y) + 0.2 * bevel(sword.distance, x, y, 2.5))


def coverage(test, px, py):
    """The share of a pixel's 4x4 samples where test(x, y) holds."""
    hits = 0
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            if test(px + (sx + 0.5) / SAMPLES, py + (sy + 0.5) / SAMPLES):
                hits += 1
    return hits / (SAMPLES * SAMPLES)


def ring(distance, x, y):
    value = distance(x, y)
    return 0 <= value < OUTLINE


def shield_layers():
    fill, edge = [], []
    for py in range(SIZE):
        for px in range(SIZE):
            cx, cy = px + 0.5, py + 0.5
            fill.append((shield_shade(cx, cy), coverage(lambda x, y: shield(x, y) < 0.5, px, py)))
            outline = coverage(lambda x, y: ring(shield, x, y), px, py)
            # The thin line between rim and face, half as dark.
            line = coverage(lambda x, y: RIM - 0.6 <= -shield(x, y) < RIM + 0.6, px, py) * 0.55
            edge.append((EDGE_SHADE, max(outline, line)))
    return fill, edge


def swords_layers():
    fill, edge = [], []
    for py in range(SIZE):
        for px in range(SIZE):
            cx, cy = px + 0.5, py + 0.5
            fill.append((swords_shade(cx, cy), coverage(
                lambda x, y: SWORD_A.distance(x, y) < 0.5 or SWORD_B.distance(x, y) < 0.5, px, py)))
            # A's outline hides under B; B's outline crosses A.
            edge.append((EDGE_SHADE, coverage(
                lambda x, y: ring(SWORD_B.distance, x, y)
                or (ring(SWORD_A.distance, x, y) and SWORD_B.distance(x, y) >= 0), px, py)))
    return fill, edge


def layers():
    """{"Textures/ShieldFill.tga": [(grey, alpha), ...], ...}, rows from the top."""
    shield_fill, shield_edge = shield_layers()
    swords_fill, swords_edge = swords_layers()
    return {
        "Textures/ShieldFill.tga": shield_fill, "Textures/ShieldEdge.tga": shield_edge,
        "Textures/SwordsFill.tga": swords_fill, "Textures/SwordsEdge.tga": swords_edge,
    }


# Files -------------------------------------------------------------------------------

def byte(value):
    return int(round(clamp(value) * 255))


def tga(pixels):
    """An uncompressed 32-bit TGA, rows from the top (descriptor 0x28)."""
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    body = bytearray()
    for grey, alpha in pixels:
        value = byte(grey)
        body += bytes((value, value, value, byte(alpha)))
    return header + bytes(body)


def png(width, height, rows):
    """An 8-bit RGB PNG from rows of (r, g, b) floats."""
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for r, g, b in row:
            raw += bytes((byte(r), byte(g), byte(b)))

    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def composite(fill, edge, color, background):
    """The icon as the client draws it: the tinted fill, then the edge."""
    out = []
    for (grey, fill_alpha), (shade, edge_alpha) in zip(fill, edge):
        pixel = [background[i] * (1 - fill_alpha) + grey * color[i] * fill_alpha for i in range(3)]
        pixel = [pixel[i] * (1 - edge_alpha) + shade * edge_alpha for i in range(3)]
        out.append(pixel)
    return out


def shrink(pixels, size):
    """A box-filtered SIZE -> size copy (the icon at its size on screen)."""
    out = []
    scale = SIZE / size
    for y in range(size):
        for x in range(size):
            total, weight = [0.0, 0.0, 0.0], 0.0
            y0, y1, x0, x1 = y * scale, (y + 1) * scale, x * scale, (x + 1) * scale
            for sy in range(int(y0), min(SIZE, math.ceil(y1))):
                wy = min(y1, sy + 1) - max(y0, sy)
                for sx in range(int(x0), min(SIZE, math.ceil(x1))):
                    w = wy * (min(x1, sx + 1) - max(x0, sx))
                    pixel = pixels[sy * SIZE + sx]
                    for i in range(3):
                        total[i] += pixel[i] * w
                    weight += w
            out.append([value / weight for value in total])
    return out


def preview(all_layers, background, big=2, small=20, small_zoom=4):
    """A sheet: each color's shield and swords at 128 px, then at about the
    size they take on screen (20 px), drawn 4x larger to show the pixels."""
    pad = 12
    cell = SIZE * big
    small_cell = small * small_zoom
    columns = len(COLORS)
    width = pad + columns * (cell + pad)
    height = pad + 2 * (cell + pad) + 2 * (small_cell + pad)
    canvas = [[background] * width for _ in range(height)]

    def paste(pixels, side, zoom, left, top):
        for y in range(side * zoom):
            row = canvas[top + y]
            for x in range(side * zoom):
                row[left + x] = pixels[(y // zoom) * side + x // zoom]

    for column, (_, color) in enumerate(COLORS):
        left = pad + column * (cell + pad)
        for row, icon in enumerate(ICONS):
            pixels = composite(all_layers[f"Textures/{icon}Fill.tga"], all_layers[f"Textures/{icon}Edge.tga"],
                               color, background)
            paste(pixels, SIZE, big, left, pad + row * (cell + pad))
            top = pad + 2 * (cell + pad) + row * (small_cell + pad)
            paste(shrink(pixels, small), small, small_zoom, left + (cell - small_cell) // 2, top)
    return png(width, height, canvas)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--preview", type=Path, help="also write PNG previews here")
    args = parser.parse_args()
    all_layers = layers()
    for name, pixels in all_layers.items():
        path = args.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(tga(pixels))
    if args.preview:
        args.preview.mkdir(parents=True, exist_ok=True)
        for label, background in (("dark", (0.1, 0.1, 0.1)), ("light", (0.9, 0.9, 0.9))):
            (args.preview / f"icons_{label}.png").write_bytes(preview(all_layers, background))


if __name__ == "__main__":
    main()
