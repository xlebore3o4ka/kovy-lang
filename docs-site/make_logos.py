#!/usr/bin/env python3
"""Generate transparent, theme-specific header logos from the supplied PNGs.

The source files use a flat background colour (cream for the light logo, black
for the dark one).  We remove that colour, estimate partial alpha on the
anti-aliased edges, crop the mark to a square and write 256 px header logos.
The browser favicon intentionally stays on the original `favicon.png`.

Usage:
    python3 make_logos.py
    python3 make_logos.py --light /path/orange_logo_1.png --dark /path/orange_logo_2.png
"""

from __future__ import annotations

import argparse
import math
from collections import Counter
from pathlib import Path

from PIL import Image

PROJECT_DIR = Path(__file__).resolve().parent
ASSETS = PROJECT_DIR / "assets"
DEFAULT_LIGHT = PROJECT_DIR / "design" / "orange_logo_1.png"
DEFAULT_DARK = PROJECT_DIR / "design" / "orange_logo_2.png"


def distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


def foreground_colors(im: Image.Image, bg: tuple[int, int, int]) -> list[tuple[int, int, int]]:
    """Pick the two dominant non-background colours (the mark and the accent)."""
    colors = im.getcolors(maxcolors=1 << 24) or []
    candidates: list[tuple[int, tuple[int, int, int, int]]] = []
    for count, color in colors:
        if color[3] == 0:
            continue
        if distance(color[:3], bg) < 40:
            continue
        candidates.append((count, color))
    candidates.sort(key=lambda item: item[0], reverse=True)

    result: list[tuple[int, int, int]] = []
    for _, color in candidates:
        rgb = color[:3]
        if all(distance(rgb, existing) > 60 for existing in result):
            result.append(rgb)
        if len(result) == 2:
            break
    if len(result) < 2:
        raise SystemExit("could not find two foreground colours")
    return result


def strip_background(im: Image.Image, tolerance: int = 7) -> Image.Image:
    """Replace the flat background with transparency and unmix edge pixels."""
    im = im.convert("RGBA")
    width, height = im.size
    px = im.load()
    bg = px[0, 0][:3]
    fg = foreground_colors(im, bg)

    vectors: list[tuple[tuple[int, int, int], tuple[float, float, float], float]] = []
    for color in fg:
        vec = tuple(color[i] - bg[i] for i in range(3))
        norm = sum(component * component for component in vec)
        vectors.append((color, vec, norm))

    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    dst = out.load()

    for y in range(height):
        for x in range(width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue

            d = (r - bg[0], g - bg[1], b - bg[2])
            d2 = d[0] * d[0] + d[1] * d[1] + d[2] * d[2]
            if d2 <= tolerance * tolerance:
                continue

            best_color = fg[0]
            best_alpha = 0.0
            best_residual = float("inf")

            for color, vec, norm in vectors:
                alpha = (d[0] * vec[0] + d[1] * vec[1] + d[2] * vec[2]) / norm
                alpha = max(0.0, min(1.0, alpha))
                residual = (
                    (d[0] - alpha * vec[0]) ** 2
                    + (d[1] - alpha * vec[1]) ** 2
                    + (d[2] - alpha * vec[2]) ** 2
                )
                if residual < best_residual:
                    best_residual = residual
                    best_color = color
                    best_alpha = alpha

            if best_alpha <= 0.02:
                continue

            dst[x, y] = (*best_color, round(best_alpha * 255))

    return out


def square_crop(im: Image.Image, padding: float) -> Image.Image:
    """Crop to a square around the visible mark, with the given relative padding."""
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise SystemExit("empty image after background removal")

    x0, y0, x1, y1 = bbox
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    side = math.ceil(max(x1 - x0, y1 - y0) * (1 + 2 * padding))

    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    # `im` is pasted whole, so shift it by the side/2 - content-centre offset.
    left = round(side / 2 - cx)
    top = round(side / 2 - cy)
    canvas.paste(im, (left, top), im)
    return canvas


def save_icon(im: Image.Image, path: Path, size: int = 256) -> None:
    resized = im.resize((size, size), Image.LANCZOS)
    resized.save(path, optimize=True)
    print(f"wrote {path.relative_to(PROJECT_DIR)} ({size}x{size})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--light", type=Path, default=DEFAULT_LIGHT)
    parser.add_argument("--dark", type=Path, default=DEFAULT_DARK)
    args = parser.parse_args()

    ASSETS.mkdir(parents=True, exist_ok=True)

    for theme, source in (("light", args.light), ("dark", args.dark)):
        if not source.exists():
            raise SystemExit(f"source image not found: {source}")
        transparent = strip_background(Image.open(source))
        save_icon(square_crop(transparent, 0.08), ASSETS / f"logo-{theme}.png")


if __name__ == "__main__":
    main()