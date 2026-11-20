"""Draw the fallback proc arcs: Textures/ProcArc.tga (right of the caster)
and its mirror Textures/ProcArcLeft.tga (left), 256 x 256, 32-bit, top-left
origin.

Since 2.11.0 each AddOn passes its own proc art (John, 2026-11-18: "each
client of the 'toolkit platform' APIs could provide their own artwork");
these are only what a proc gets when its AddOn passes none, or art that does
not pass (Procs.lua, "Art"). So they are plain: one smooth white crescent,
a bright core with a soft glow, thinner and fading at its tips. Procs.lua
tints it with each proc's color (the StatusBar color). Our own art.

The crescent keeps the ratios every proc art must keep (Procs.lua): the
ring center 8/128 in from the flat side (CENTER_X), 118/128 of the height
(OUTER_SPAN); the art stays within radii 178 to 236 of 256.

Pure Python, standard library only, 4 x 4 samples per texel; the output is
the same on every run. Run from the repository root:

    python scripts/make_proc_arcs.py                 # writes Textures/*.tga
    python scripts/make_proc_arcs.py --preview DIR   # also PNG previews
"""

import argparse
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIZE = 256
SUPER = 4
CENTER_X, CENTER_Y = SIZE * 8 / 128, SIZE / 2
MIN_R, MAX_R = 178, 236
MID_R = (MIN_R + MAX_R) / 2
SPAN = math.radians(33.5)
CORE = 5.0       # half-width of the solid core at the middle, in texels
EDGE = 2.0       # the core's soft edge
GLOW = 11.0      # the glow's falloff
GLOW_ALPHA = 0.45
TIP_FADE = 0.22  # the last part of each half that fades out


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def coverage(x, y):
    """The crescent's alpha at one sample point (texel units, right arc)."""
    dx, dy = x - CENTER_X, y - CENTER_Y
    r, a = math.hypot(dx, dy), math.atan2(dy, dx)
    t = abs(a) / SPAN
    if t >= 1 or r < MIN_R or r > MAX_R:
        return 0.0
    thin = 1 - 0.6 * t * t
    d = abs(r - MID_R)
    core = 1 - smoothstep(CORE * thin, CORE * thin + EDGE, d)
    glow = GLOW_ALPHA * math.exp(-(d / (GLOW * thin)) ** 2)
    fade = 1 - smoothstep(1 - TIP_FADE, 1, t)
    # Inside the band's radii only, with a soft stop at each.
    keep = smoothstep(MIN_R, MIN_R + 4, r) * (1 - smoothstep(MAX_R - 4, MAX_R, r))
    return min(1.0, max(core, glow)) * fade * keep


def crescent(mirror):
    """Rows of RGBA floats: white, alpha the averaged coverage."""
    texture = []
    for y in range(SIZE):
        row = []
        for x in range(SIZE):
            total = 0.0
            for sy in range(SUPER):
                for sx in range(SUPER):
                    px = x + (sx + 0.5) / SUPER
                    py = y + (sy + 0.5) / SUPER
                    total += coverage(SIZE - px if mirror else px, py)
            row.append((1.0, 1.0, 1.0, total / (SUPER * SUPER)))
        texture.append(row)
    return texture


def write_tga(file, texture):
    header = bytes((0, 0, 2)) + bytes(9) + struct.pack("<HH", SIZE, SIZE) + bytes((32, 0x28))
    body = bytearray()
    for row in texture:
        for r, g, b, a in row:
            body += bytes((round(b * 255), round(g * 255), round(r * 255), round(a * 255)))
    file.write_bytes(header + bytes(body))


def write_preview(file, texture, tint):
    """The texture tinted, over a dark background, as PNG."""
    rows = []
    for row in texture:
        line = bytearray(b"\x00")
        for r, g, b, a in row:
            line += bytes(int(30 * (1 - a) + 255 * v * t * a) for v, t in zip((r, g, b), tint))
        rows.append(bytes(line))
    chunk = lambda kind, data: (struct.pack(">I", len(data)) + kind + data
                                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))
    file.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b""))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write PNG previews here")
    args = parser.parse_args()
    for name, mirror in (("ProcArc", False), ("ProcArcLeft", True)):
        texture = crescent(mirror)
        write_tga(ROOT / "Textures" / f"{name}.tga", texture)
        if args.preview:
            args.preview.mkdir(parents=True, exist_ok=True)
            write_preview(args.preview / f"{name}.png", texture, (0.62, 0.8, 1.0))
        print(f"Textures/{name}.tga")


if __name__ == "__main__":
    main()
