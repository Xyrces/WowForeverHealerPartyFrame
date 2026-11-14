"""Reproduce the radial cleanse assets from the public geometry constants.

These are original, analytically rasterized UI shapes, not enlarged game art.
The 256px, uncompressed RGBA TGA files use power-of-two dimensions supported
by the client. Runtime rendering tints the neutral fill, rim, and glow layers.
No third-party packages are needed. Run with --check to verify checked-in art.
"""

import argparse
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
MEDIA = ROOT / "WowfPartyFrames" / "Media"
PIXELS = 256
PADDING = 4


def assets(style, count, index):
    inner = 44 if style == "quadrants" else 56
    outer = inner + 20
    first = math.radians(-90 + (index - 1) * 180 / count + 2)
    last = math.radians(-90 + index * 180 / count - 2)
    art_size = 2 * (outer + PADDING)
    scale = PIXELS / art_size
    coordinates = [(pixel + 0.5) / scale - art_size / 2 for pixel in range(PIXELS)]
    sin_first, cos_first = math.sin(first), math.cos(first)
    sin_last, cos_last = math.sin(last), math.cos(last)
    # BGRA, top-left origin, eight alpha bits. TGA image type2 is uncompressed.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, PIXELS, PIXELS, 32, 0x28)
    layers = {name: bytearray(header) for name in ("fill", "rim", "glow")}

    def alpha(distance):
        return round(255 * min(1, max(0, distance * scale + 0.5)))

    for y in coordinates:
        for x in coordinates:
            radius = math.hypot(x, y)
            distance = min(outer - radius, radius - inner,
                           cos_first * y - sin_first * x,
                           sin_last * x - cos_last * y)
            shade = round(235 - 30 * min(1, max(0, (radius - inner) / 20)))
            fill = alpha(distance)
            rim = alpha(0.55 - abs(distance))
            # Glow follows the sector's edges, not its rectangular image bounds.
            glow = round(180 * math.exp(-0.5 * (distance / 1.2) ** 2)) if abs(distance) < PADDING else 0
            layers["fill"].extend((shade, shade, shade, fill))
            layers["rim"].extend((255, 255, 255, rim))
            layers["glow"].extend((255, 255, 255, glow))
    return {f"cleanse-{style}-{count}-{index}-{name}.tga": bytes(data) for name, data in layers.items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify assets without changing them")
    args = parser.parse_args()
    if not args.check:
        MEDIA.mkdir(parents=True, exist_ok=True)
    written = 0
    for style in ("quadrants", "buttons"):
        for count in (2, 3, 4):
            for index in range(1, count + 1):
                for name, contents in assets(style, count, index).items():
                    path = MEDIA / name
                    if args.check:
                        if not path.is_file() or path.read_bytes() != contents:
                            raise SystemExit(f"Asset is missing or stale: {path.relative_to(ROOT)}")
                    else:
                        path.write_bytes(contents)
                    written += 1
    print(f"{'Verified' if args.check else 'Generated'} {written} radial TGA assets ({PIXELS} x {PIXELS})")


if __name__ == "__main__":
    main()
