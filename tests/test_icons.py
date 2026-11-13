"""The threat label's icon textures (2.9.0). Run:
python3 -m unittest discover -s tests -p test_icons.py

scripts/make_icons.py draws them; these tests run its drawing in memory and
read the output. No image library is needed.
"""

import importlib.util
import struct
import unittest
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("make_icons", ROOT / "scripts" / "make_icons.py")
assert SPEC is not None and SPEC.loader is not None
icons = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(icons)
BUILDER_SPEC = importlib.util.spec_from_file_location("build_release", ROOT / "scripts" / "build_release.py")
assert BUILDER_SPEC is not None and BUILDER_SPEC.loader is not None
builder = importlib.util.module_from_spec(BUILDER_SPEC)
BUILDER_SPEC.loader.exec_module(builder)

HEADER = 18


def pixels(data):
    """(b, g, r, a) tuples, rows from the top."""
    body = data[HEADER:]
    return [tuple(body[index:index + 4]) for index in range(0, len(body), 4)]


class IconTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layers = icons.layers()
        cls.files = {}
        for name, layer in cls.layers.items():
            cls.files[name] = icons.tga(layer)

    def test_four_textures_64_square_32_bit_with_alpha(self):
        self.assertEqual(sorted(self.files), sorted(icons.TEXTURES))
        self.assertEqual(set(icons.TEXTURES) <= set(builder.MEDIA_FILES), True, "all are packaged")
        for name, data in self.files.items():
            with self.subTest(name=name):
                builder._validate_tga(name, data)
                id_length, color_map, kind, width, height, depth, descriptor = struct.unpack(
                    "<BBB9xHHBB", data[:HEADER])
                self.assertEqual((id_length, color_map, kind), (0, 0, 2))
                self.assertEqual((width, height, depth), (64, 64, 32))
                self.assertEqual(descriptor, 0x28, "8 alpha bits, rows from the top")
                self.assertEqual(len(data), HEADER + 64 * 64 * 4)

    def test_alpha_has_clear_solid_and_smooth_edges(self):
        for name, data in self.files.items():
            with self.subTest(name=name):
                alphas = [pixel[3] for pixel in pixels(data)]
                self.assertEqual(alphas[0], 0, "the corner is clear")
                self.assertIn(255, alphas, "a solid part")
                partial = sum(1 for alpha in alphas if 0 < alpha < 255)
                self.assertGreater(partial, 40, "smoothed (supersampled) edges")
                # Nothing touches the border, so filtering cannot bleed.
                border = [alphas[i] for i in range(64)] + [alphas[63 * 64 + i] for i in range(64)]
                border += [alphas[row * 64] for row in range(64)] + [alphas[row * 64 + 63] for row in range(64)]
                self.assertEqual(max(border), 0)

    def test_fill_is_grey_and_shaded_edge_is_dark(self):
        for icon in icons.ICONS:
            with self.subTest(icon=icon):
                fill = [pixel for pixel in pixels(self.files[f"Textures/{icon}Fill.tga"]) if pixel[3] == 255]
                self.assertTrue(all(b == g == r for b, g, r, _ in fill), "grey, so the tint keeps its hue")
                greys = [pixel[0] for pixel in fill]
                self.assertEqual(max(greys), 255, "a white top, for the full tint")
                self.assertLess(min(greys), 200, "a shade, not flat")
                edge = [pixel for pixel in pixels(self.files[f"Textures/{icon}Edge.tga"]) if pixel[3] > 0]
                self.assertTrue(all(b == g == r and r < 40 for b, g, r, _ in edge), "a dark outline")

    def test_outline_rings_the_fill(self):
        for icon in icons.ICONS:
            with self.subTest(icon=icon):
                fill = [pixel[3] for pixel in pixels(self.files[f"Textures/{icon}Fill.tga"])]
                edge = [pixel[3] for pixel in pixels(self.files[f"Textures/{icon}Edge.tga"])]
                outside = [index for index, alpha in enumerate(fill) if alpha == 0]
                self.assertTrue(any(edge[index] == 255 for index in outside), "the outline lies outside the fill")

    def test_committed_textures_are_the_script_output(self):
        for name, data in self.files.items():
            with self.subTest(name=name):
                self.assertEqual((ROOT / name).read_bytes(), data, "run scripts/make_icons.py")

    def test_previews_are_png(self):
        sheet = icons.preview(self.layers, (0.1, 0.1, 0.1))
        self.assertEqual(sheet[:8], b"\x89PNG\r\n\x1a\n")
        width, height = struct.unpack(">II", sheet[16:24])
        self.assertEqual(width, 12 + len(icons.COLORS) * (128 + 12))
        self.assertGreater(height, 2 * 128)
        self.assertEqual(len(icons.COLORS), 6)
        zlib.decompress(sheet[sheet.index(b"IDAT") + 4:sheet.index(b"IEND") - 8])


if __name__ == "__main__":
    unittest.main()
