#!/usr/bin/env python3
"""Generates Listening Tree's icon, About banner and splash screen.

    python3 branding/make-branding.py

Writes into branding/overlay/, which mirrors paths in the Audacity source and is
copied over it by scripts/prepare-source.sh. The generated files are committed,
so you only need to run this after changing the design below.

Needs Python 3 with Pillow and fontTools, the `rsvg-convert` tool (librsvg) and
the Inter font (any OpenType/TrueType file; set LT_BRAND_FONT to its path).
On a Mac: `brew install librsvg` and `python3 -m pip install pillow fonttools`.
"""

import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
OVERLAY = HERE / "overlay"

# --- Palette ---------------------------------------------------------------------
GREEN_TOP = "#2B7A5B"
GREEN_BOTTOM = "#0C3A2B"
GREEN_DEEP = "#0B3226"
CREAM = "#F4E6BE"

FONT_CANDIDATES = [
    os.environ.get("LT_BRAND_FONT", ""),
    "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf",
    "/Library/Fonts/Inter-SemiBold.otf",
    str(Path.home() / "Library/Fonts/Inter-SemiBold.otf"),
]


# --- The glyph: a tree whose canopy is sound waves --------------------------------
# Drawn in a 64 x 64 box (y grows downwards). Everything is a filled outline
# (no strokes), as Icon Composer expects.

def _fmt(pts):
    return " ".join(f"L{x:.3f},{y:.3f}" for x, y in pts)


def _arc_band(cx, cy, r, width, a0, a1, steps=64):
    """Ring segment with round ends. Angles in degrees, 0 = right, 90 = up."""
    ro, ri = r + width / 2, r - width / 2

    def pt(radius, deg):
        rad = math.radians(deg)
        return cx + radius * math.cos(rad), cy - radius * math.sin(rad)

    outer = [pt(ro, a0 + (a1 - a0) * i / steps) for i in range(steps + 1)]
    inner = [pt(ri, a1 - (a1 - a0) * i / steps) for i in range(steps + 1)]
    cap = width / 2
    return (f"M{outer[0][0]:.3f},{outer[0][1]:.3f} {_fmt(outer[1:])} "
            f"A{cap:.3f},{cap:.3f} 0 0 0 {inner[0][0]:.3f},{inner[0][1]:.3f} {_fmt(inner[1:])} "
            f"A{cap:.3f},{cap:.3f} 0 0 0 {outer[0][0]:.3f},{outer[0][1]:.3f} Z")


def _thick_curve(p0, p1, p2, w0, w1, steps=40):
    """Quadratic Bezier p0 -> p2 (control p1) drawn as a tapering band, round at the p2 end."""
    def at(t):
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        dx = 2 * (1 - t) * (p1[0] - p0[0]) + 2 * t * (p2[0] - p1[0])
        dy = 2 * (1 - t) * (p1[1] - p0[1]) + 2 * t * (p2[1] - p1[1])
        n = math.hypot(dx, dy) or 1.0
        return x, y, -dy / n, dx / n

    left, right = [], []
    for i in range(steps + 1):
        t = i / steps
        x, y, nx, ny = at(t)
        hw = (w0 + (w1 - w0) * t) / 2
        left.append((x + nx * hw, y + ny * hw))
        right.append((x - nx * hw, y - ny * hw))
    cap = w1 / 2
    return (f"M{left[0][0]:.3f},{left[0][1]:.3f} {_fmt(left[1:])} "
            f"A{cap:.3f},{cap:.3f} 0 0 0 {right[-1][0]:.3f},{right[-1][1]:.3f} "
            f"{_fmt(list(reversed(right[:-1])))} Z")


def glyph_paths():
    cx, cy = 32.0, 36.0  # centre of the waves, where the branches meet
    paths = []
    # Canopy: three sound waves.
    for r in (11.0, 18.5, 26.0):
        paths.append(_arc_band(cx, cy, r, 3.4, 26, 154))

    def polar(r, deg):
        return cx + r * math.cos(math.radians(deg)), cy - r * math.sin(math.radians(deg))

    # Trunk, rising to the centre of the waves.
    paths.append(_thick_curve((32.0, 60.5), (32.0, 46.0), polar(7.4, 90), 6.2, 2.6))
    # Two branches reaching towards the first wave.
    paths.append(_thick_curve((32.0, 43.0), (29.4, 38.5), polar(7.6, 137), 3.0, 2.2))
    paths.append(_thick_curve((32.0, 43.0), (34.6, 38.5), polar(7.6, 43), 3.0, 2.2))
    # Roots.
    paths.append(_thick_curve((32.0, 56.5), (28.6, 60.4), (24.4, 61.4), 3.6, 2.0))
    paths.append(_thick_curve((32.0, 56.5), (35.4, 60.4), (39.6, 61.4), 3.6, 2.0))
    return paths


def glyph_svg(fill="#000000", size=64):
    body = "\n".join(f'  <path d="{d}" fill="{fill}"/>' for d in glyph_paths())
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 64 64" fill="none" '
            f'xmlns="http://www.w3.org/2000/svg">\n{body}\n</svg>\n')


def glyph_group(fill, x, y, scale):
    body = "".join(f'<path d="{d}" fill="{fill}"/>' for d in glyph_paths())
    return f'<g transform="translate({x:.2f},{y:.2f}) scale({scale:.4f})">{body}</g>'


# --- Text as outlines (so the splash looks the same without the font installed) ---

def text_path(text, font_path, size, x, baseline, fill, letter_spacing=0.0):
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont

    font = TTFont(font_path)
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    upem = font["head"].unitsPerEm
    scale = size / upem
    hmtx = font["hmtx"]
    out = []
    pen_x = x
    for ch in text:
        name = cmap.get(ord(ch))
        if name is None:
            continue
        svg_pen = SVGPathPen(glyph_set)
        glyph_set[name].draw(TransformPen(svg_pen, (scale, 0, 0, -scale, pen_x, baseline)))
        d = svg_pen.getCommands()
        if d:
            out.append(f'<path d="{d}" fill="{fill}"/>')
        pen_x += hmtx[name][0] * scale + letter_spacing
    return "".join(out), pen_x - x


def find_font():
    for candidate in FONT_CANDIDATES:
        if candidate and Path(candidate).is_file():
            return candidate
    sys.exit("Inter SemiBold not found; set LT_BRAND_FONT to a font file")


# --- Rendering helpers --------------------------------------------------------------

def render_svg(svg_text, out_png, width, height):
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as f:
        f.write(svg_text)
        tmp = f.name
    try:
        subprocess.run(["rsvg-convert", "-w", str(width), "-h", str(height), "-o", str(out_png), tmp], check=True)
    finally:
        os.unlink(tmp)


def app_icon_svg():
    # macOS icon grid: 1024 canvas, 824 rounded square, corner radius about 185.
    glyph = glyph_group(CREAM, 512 - 32 * 9.4, 512 - 35 * 9.4, 9.4)
    return f'''<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{GREEN_TOP}"/>
      <stop offset="1" stop-color="{GREEN_BOTTOM}"/>
    </linearGradient>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity="0.25"/>
    </filter>
  </defs>
  <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)" filter="url(#shadow)"/>
  {glyph}
</svg>
'''


def write_app_icon():
    icon_dir = OVERLAY / "share/icons/AppIcon"
    icon_dir.mkdir(parents=True, exist_ok=True)

    # Icon Composer bundle (used with Xcode 26's actool): a glyph layer on a gradient.
    bundle = icon_dir / "AppIcon.icon"
    (bundle / "Assets").mkdir(parents=True, exist_ok=True)
    glyph = glyph_svg()
    (bundle / "Assets/ListeningTree.svg").write_text(glyph)
    # Replace Audacity's glyph too, so nothing of the Audacity logo is left in the bundle.
    (bundle / "Assets/Audacity.svg").write_text(glyph)
    icon_json = {
        # Same keys as Audacity's own icon.json, so Xcode's actool accepts the file.
        "fill": {"automatic-gradient": "srgb:0.10980,0.38431,0.28235,1.00000"},
        "groups": [{
            "layers": [{
                "fill": {"solid": "srgb:0.95686,0.90196,0.74510,1.00000"},
                "image-name": "ListeningTree.svg",
                "name": "ListeningTree",
                "position": {"scale": 9.6, "translation-in-points": [0, 0]},
            }],
            "shadow": {"kind": "neutral", "opacity": 0.5},
            "translucency": {"enabled": True, "value": 0.15},
        }],
        "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
    }
    (bundle / "icon.json").write_text(json.dumps(icon_json, indent=2) + "\n")

    # PNGs (window icon etc.) and a fallback .icns for builds without Xcode 26.
    with tempfile.TemporaryDirectory() as tmp:
        master = Path(tmp) / "icon1024.png"
        render_svg(app_icon_svg(), master, 1024, 1024)
        img = Image.open(master).convert("RGBA")
        for size in (16, 24, 32, 48, 64, 96, 128, 256, 512):
            img.resize((size, size), Image.LANCZOS).save(icon_dir / f"AU4_AppIcon_{size}x{size}.png", optimize=True)
        img.save(icon_dir / "AU4_AppIcon.icns", sizes=[(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)])
        img.save(icon_dir / "AU4_AppIcon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
        shutil.copy(master, HERE / "icon-1024.png")


def write_about_banner(font):
    w, h = 1440, 288
    words, width = text_path("Listening Tree", font, 92, 0, 0, CREAM, letter_spacing=-1.0)
    glyph_size = 170
    gap = 36
    total = glyph_size + gap + width
    x0 = (w - total) / 2
    glyph = glyph_group(CREAM, x0, (h - glyph_size) / 2, glyph_size / 64)
    text_x = x0 + glyph_size + gap
    words, _ = text_path("Listening Tree", font, 92, text_x, h / 2 + 33, CREAM, letter_spacing=-1.0)
    svg = f'''<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" xmlns="http://www.w3.org/2000/svg">
  <rect width="{w}" height="{h}" fill="{GREEN_DEEP}"/>
  {glyph}
  {words}
</svg>
'''
    out = OVERLAY / "src/appshell/resources/AboutBanner.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    render_svg(svg, out, w, h)


def write_splash(font):
    # 800 x 380. The app draws "Version x.y.z" at (38, 322) and a second line under it.
    w, h = 800, 380
    title, _ = text_path("Listening Tree", font, 58, 38, 150, CREAM, letter_spacing=-0.6)
    big = glyph_group(CREAM, 470, 40, 330 / 64)
    svg = f'''<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{GREEN_BOTTOM}"/>
      <stop offset="1" stop-color="{GREEN_TOP}"/>
    </linearGradient>
  </defs>
  <rect width="{w}" height="{h}" fill="url(#bg)"/>
  <g opacity="0.22">{big}</g>
  {title}
</svg>
'''
    out = OVERLAY / "src/appshell/resources/LoadingScreen.svg"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(svg)


def main():
    if not shutil.which("rsvg-convert"):
        sys.exit("rsvg-convert not found (brew install librsvg)")
    font = find_font()
    (HERE / "glyph.svg").write_text(glyph_svg(fill=CREAM))
    write_app_icon()
    write_about_banner(font)
    write_splash(font)
    print(f"Wrote branding into {OVERLAY.relative_to(HERE.parent)}")


if __name__ == "__main__":
    main()
