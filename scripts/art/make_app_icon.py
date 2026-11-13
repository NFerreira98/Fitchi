#!/usr/bin/env python3
"""Generates Fitchi's app icon: a hi-bit pixel-art bear in a red workout sweatband,
peeking over a counter.

The bear is drawn procedurally on a 64x64 grid (shapes → cel shading → selective
outline), then upscaled with nearest-neighbour to 1024x1024 so pixels stay crisp.
Pure standard library: no Pillow needed.

Usage:  python3 scripts/art/make_app_icon.py [output.png ...]
With no arguments, writes the iOS and watchOS AppIcon PNGs in the asset catalogs.
"""

from __future__ import annotations

import math
import struct
import sys
import zlib
from pathlib import Path

GRID = 64
SCALE = 16  # 64 × 16 = 1024

# ---------------------------------------------------------------- palette
SKY = [(124, 176, 255), (110, 162, 247), (98, 148, 238), (88, 134, 228), (80, 122, 218)]
CLOUD = (250, 252, 255)
CLOUD_SHADE = (212, 228, 255)
SPARKLE = (255, 236, 140)
SPARKLE_CORE = (255, 255, 235)

FUR = (214, 158, 98)
FUR_SHADE = (180, 124, 72)
FUR_LIGHT = (236, 188, 128)
OUTLINE = (92, 56, 36)
INNER_EAR = (244, 170, 160)
MUZZLE = (247, 222, 182)
MUZZLE_SHADE = (228, 196, 152)
NOSE = (64, 38, 30)
EYE = (44, 28, 24)
EYE_SHINE = (255, 255, 255)
BLUSH = (252, 150, 150)

BAND = (226, 52, 58)
BAND_LIGHT = (255, 104, 100)
BAND_SHADE = (176, 30, 44)

COUNTER = (246, 132, 120)
COUNTER_LIGHT = (255, 172, 156)
COUNTER_SHADE = (214, 100, 96)
COUNTER_TRIM = (255, 214, 120)


def ellipse(x: float, y: float, cx: float, cy: float, rx: float, ry: float) -> bool:
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def render() -> list[list[tuple[int, int, int]]]:
    px: list[list[tuple[int, int, int]]] = [[SKY[0]] * GRID for _ in range(GRID)]
    bear = [[False] * GRID for _ in range(GRID)]  # which pixels belong to the bear (for outline)

    # ---- sky: banded gradient, light at top
    for y in range(GRID):
        band = SKY[min(len(SKY) - 1, y * len(SKY) // 52)]
        for x in range(GRID):
            px[y][x] = band

    # ---- clouds
    def cloud(cx: float, cy: float, w: float) -> None:
        for y in range(GRID):
            for x in range(GRID):
                sx, sy = x + 0.5, y + 0.5
                blob = (
                    ellipse(sx, sy, cx, cy, w, w * 0.45)
                    or ellipse(sx, sy, cx - w * 0.45, cy + 0.6, w * 0.55, w * 0.35)
                    or ellipse(sx, sy, cx + w * 0.2, cy - w * 0.25, w * 0.5, w * 0.38)
                )
                if blob:
                    lower = sy > cy + w * 0.12
                    px[y][x] = CLOUD_SHADE if lower else CLOUD

    cloud(10, 9, 6.5)
    cloud(56, 30, 5)

    # ---- sparkle (4-point star), top right
    sx0, sy0 = 52, 9
    for d in range(-4, 5):
        for (x, y) in ((sx0 + d, sy0), (sx0, sy0 + d)):
            px[y][x] = SPARKLE if abs(d) > 1 else SPARKLE_CORE
    for (x, y) in ((sx0 - 1, sy0 - 1), (sx0 + 1, sy0 - 1), (sx0 - 1, sy0 + 1), (sx0 + 1, sy0 + 1)):
        px[y][x] = SPARKLE
    for (x, y) in ((44, 16), (59, 18), (8, 22)):
        px[y][x] = SPARKLE_CORE

    # ---- bear head + ears
    head = (32.0, 34.0, 18.0, 15.0)
    ears = [(17.0, 21.5, 6.8), (47.0, 21.5, 6.8)]

    def in_head(x: float, y: float, dx: float = 0, dy: float = 0) -> bool:
        cx, cy, rx, ry = head
        return ellipse(x, y, cx + dx, cy + dy, rx, ry)

    def in_ear(x: float, y: float, dx: float = 0, dy: float = 0) -> bool:
        return any(math.hypot(x - (ex + dx), y - (ey + dy)) <= r for ex, ey, r in ears)

    for y in range(GRID):
        for x in range(GRID):
            sx, sy = x + 0.5, y + 0.5
            if not (in_head(sx, sy) or in_ear(sx, sy)):
                continue
            bear[y][x] = True
            # cel shading: rim away from the top-left light is shadow, rim facing it is highlight
            lit = in_head(sx, sy, -2.2, -2.2) or in_ear(sx, sy, -1.4, -1.4)
            core = in_head(sx, sy, 1.6, 1.6) or in_ear(sx, sy, 1.2, 1.2)
            px[y][x] = FUR if (lit and core) else (FUR_SHADE if not lit else FUR_LIGHT)
            # inner ears
            for ex, ey, _ in ears:
                if math.hypot(sx - (ex + (1 if ex < 32 else -1)), sy - (ey + 0.8)) <= 3.6:
                    px[y][x] = INNER_EAR

    # ---- red workout sweatband across the forehead: four pixels deep in every column,
    # bowing down toward the sides as it follows the round head (symmetric about x = 31.5)
    for x in range(GRID):
        drop = round(0.0075 * (x + 0.5 - 32) ** 2)
        for row, colour in enumerate((BAND_LIGHT, BAND, BAND, BAND_SHADE)):
            y = 26 + drop + row
            if bear[y][x] and in_head(x + 0.5, y + 0.5):
                px[y][x] = colour

    # ---- muzzle
    for y in range(GRID):
        for x in range(GRID):
            sx, sy = x + 0.5, y + 0.5
            if ellipse(sx, sy, 32, 41.5, 8.6, 5.8):
                px[y][x] = MUZZLE if ellipse(sx, sy, 31.4, 40.9, 8.0, 5.2) else MUZZLE_SHADE

    # ---- blush
    for y in range(GRID):
        for x in range(GRID):
            sx, sy = x + 0.5, y + 0.5
            if ellipse(sx, sy, 18.0, 39.5, 2.9, 1.7) or ellipse(sx, sy, 46.0, 39.5, 2.9, 1.7):
                px[y][x] = BLUSH

    # ---- eyes: 3×4 rounded, with a two-pixel shine (mirrored around x = 31.5)
    for ex in (23, 38):
        for dy in range(4):
            for dx in range(3):
                if dy == 0 and dx != 1:
                    continue  # round the top
                px[31 + dy][ex + dx] = EYE
        px[32][ex] = EYE_SHINE
        px[34][ex + 2] = EYE_SHINE  # tiny secondary glint

    # ---- nose + "ω" smile (mirrored around x = 31.5)
    for (x, y) in ((30, 37), (31, 37), (32, 37), (33, 37), (31, 38), (32, 38)):
        px[y][x] = NOSE
    px[37][31] = (120, 84, 70)  # nose shine
    for (x, y) in ((31, 39), (32, 39), (30, 40), (33, 40), (29, 40), (34, 40), (28, 39), (35, 39)):
        px[y][x] = NOSE

    # ---- selective outline around the bear silhouette
    outline_cells = []
    for y in range(GRID):
        for x in range(GRID):
            if not bear[y][x]:
                continue
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if not (0 <= nx < GRID and 0 <= ny < GRID) or not bear[ny][nx]:
                    outline_cells.append((x, y))
                    break
    for x, y in outline_cells:
        px[y][x] = OUTLINE

    # ---- counter the bear peeks over
    top = 49
    for y in range(top, GRID):
        for x in range(GRID):
            if y == top:
                px[y][x] = COUNTER_TRIM
            elif y == top + 1:
                px[y][x] = COUNTER_LIGHT
            elif y >= GRID - 4:
                px[y][x] = COUNTER_SHADE
            else:
                px[y][x] = COUNTER

    # ---- paws resting on the counter
    for pcx in (21.5, 42.5):
        cells = []
        for y in range(GRID):
            for x in range(GRID):
                sx, sy = x + 0.5, y + 0.5
                if ellipse(sx, sy, pcx, 50.5, 5.6, 3.8):
                    cells.append((x, y))
        cellset = set(cells)
        for x, y in cells:
            sx, sy = x + 0.5, y + 0.5
            edge = any((nx, ny) not in cellset for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
            if edge:
                px[y][x] = OUTLINE
            else:
                px[y][x] = FUR_LIGHT if sy < 49.6 else FUR
        # toe lines
        for dx in (-2, 1):
            px[52][int(pcx) + dx] = FUR_SHADE

    return px


def write_png(path: Path, px: list[list[tuple[int, int, int]]]) -> None:
    size = GRID * SCALE
    rows = bytearray()
    for y in range(size):
        rows.append(0)  # filter: none
        src = px[y // SCALE]
        for x in range(size):
            rows.extend(src[x // SCALE])

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))  # 8-bit RGB, opaque
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    targets = [Path(p) for p in sys.argv[1:]] or [
        root / "Apps/Phone/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
        root / "Apps/Watch/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
    ]
    image = render()
    for target in targets:
        write_png(target, image)
        print(f"wrote {target}")


if __name__ == "__main__":
    main()
