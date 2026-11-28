#!/usr/bin/env python3
"""Generate the 1200x630 Open Graph card for the Kovy docs site."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

PROJECT_DIR = Path(__file__).resolve().parent
ASSETS = PROJECT_DIR / "assets"

WIDTH, HEIGHT = 1200, 630
BACKGROUND = (10, 12, 16)
TEXT = (238, 240, 244)
TEXT_SOFT = (176, 182, 195)
ACCENT = (232, 183, 106)


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    names = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/TTF/DejaVuSans.ttf",
        "/usr/share/fonts/noto/NotoSans-Bold.ttf" if bold else "/usr/share/fonts/noto/NotoSans-Regular.ttf",
    ]
    for name in names:
        if Path(name).exists():
            return ImageFont.truetype(name, size)
    return ImageFont.load_default()


def main() -> None:
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), (*BACKGROUND, 255))

    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for x in range(0, WIDTH, 40):
        draw.line([(x, 0), (x, HEIGHT)], fill=(255, 255, 255, 8))
    for y in range(0, HEIGHT, 40):
        draw.line([(0, y), (WIDTH, y)], fill=(255, 255, 255, 8))
    draw.rectangle([0, 0, 7, HEIGHT], fill=(*ACCENT, 190))
    canvas = Image.alpha_composite(canvas, overlay)

    logo = Image.open(ASSETS / "logo-dark.png").convert("RGBA")
    logo = logo.resize((176, 176), Image.LANCZOS)
    canvas.alpha_composite(logo, (84, 66))

    draw = ImageDraw.Draw(canvas)
    draw.text((84, 272), "Kovy", font=load_font(112, bold=True), fill=(*TEXT, 255))
    draw.text(
        (88, 410),
        "A small language, documented precisely.",
        font=load_font(38),
        fill=(*TEXT_SOFT, 255),
    )
    draw.text(
        (88, 474),
        "Syntax  ·  semantics  ·  every diagnostic",
        font=load_font(26),
        fill=(*ACCENT, 255),
    )
    draw.text(
        (88, 540),
        "xlebore3o4ka.github.io/kovy-lang",
        font=load_font(22),
        fill=(*TEXT_SOFT, 190),
    )

    canvas.convert("RGB").save(ASSETS / "og-image.png", optimize=True)
    print(f"wrote {(ASSETS / 'og-image.png').relative_to(PROJECT_DIR)} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()