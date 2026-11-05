#!/usr/bin/env python3
"""Render the committed atlas data to a PNG so a reviewer can look at the map.

This is **not** a screenshot of the game. The build environment for Milestone 02
had no GPU, no display server and no OpenGL/Vulkan driver, so the Godot
application could not be rendered at all (see docs/evidence/README.md). What this
script does instead is honest and reproducible: it reads the *same* committed
`data/world/geometry.json` and `data/world/countries.json` the game loads, takes
the *same* map colours out of `src/ui/theme/palette.gd`, and rasterises the
polygons with the equirectangular projection the game uses.

It proves the polygons, the projection, the fills, the borders, the hole
handling and the selection highlight. It cannot prove anything about Control
layout, fonts, tweens or the engine's renderer.

Usage (Pillow is needed):

    python3 tools/render_atlas_evidence.py --out docs/evidence
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

WIDTH = 2048
HEIGHT = 1024
CAPTION_HEIGHT = 64
SELECTED = "BGD"
LABEL_MAX_RANK = 2
FONT_CANDIDATES = (
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
)

ROOT = pathlib.Path(__file__).resolve().parent.parent
PALETTE_PATTERN = re.compile(r'^\s+KEY_([A-Z0-9_]+): "(#[0-9A-Fa-f]{6})",\s*$')
PALETTE_START = re.compile(r"^const _(MIDNIGHT|PARCHMENT)[^=]*= \{")


def load_palettes() -> dict[str, dict[str, str]]:
    """Map palette name -> {KEY_NAME: "#RRGGBB"} straight from palette.gd."""
    palettes: dict[str, dict[str, str]] = {}
    current: dict[str, str] | None = None
    for line in (ROOT / "src/ui/theme/palette.gd").read_text(encoding="utf-8").splitlines():
        start = PALETTE_START.match(line)
        if start:
            current = {}
            palettes[start.group(1).lower()] = current
            continue
        if current is None:
            continue
        if line.strip() == "}":
            current = None
            continue
        entry = PALETTE_PATTERN.match(line)
        if entry:
            current[entry.group(1)] = entry.group(2).lower()
    missing = [name for name in ("midnight", "parchment") if name not in palettes]
    if missing:
        raise SystemExit(f"could not read palettes from palette.gd: {missing}")
    return palettes


def load_data() -> tuple[dict, dict]:
    geometry = json.loads((ROOT / "data/world/geometry.json").read_text(encoding="utf-8"))
    countries = json.loads((ROOT / "data/world/countries.json").read_text(encoding="utf-8"))
    return geometry, countries


def project(longitude: float, latitude: float) -> tuple[float, float]:
    """Equirectangular, matching MapProjection: lon -180..180, lat -90..90."""
    x = (longitude + 180.0) / 360.0 * WIDTH
    y = (90.0 - latitude) / 180.0 * HEIGHT
    return x, y


def ring_points(flat: list[int], scale: int) -> list[tuple[float, float]]:
    return [project(flat[i] / scale, flat[i + 1] / scale) for i in range(0, len(flat), 2)]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="docs/evidence", help="output directory")
    args = parser.parse_args(argv[1:])

    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print("Pillow is required: pip install pillow", file=sys.stderr)
        return 1

    palettes = load_palettes()
    geometry, countries = load_data()
    scale = int(geometry["scale"])
    records = {record["id"]: record for record in countries["countries"]}
    manifest = json.loads((ROOT / "data/world/manifest.json").read_text(encoding="utf-8"))

    font_path = next((path for path in FONT_CANDIDATES if pathlib.Path(path).exists()), None)
    label_font = (ImageFont.truetype(font_path, 15) if font_path
                  else ImageFont.load_default())
    caption_font = (ImageFont.truetype(font_path, 17) if font_path
                    else ImageFont.load_default())
    small_font = (ImageFont.truetype(font_path, 14) if font_path
                  else ImageFont.load_default())

    out_dir = ROOT / args.out if not pathlib.Path(args.out).is_absolute() else pathlib.Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []

    for palette_name, colours in palettes.items():
        image = Image.new("RGB", (WIDTH, HEIGHT + CAPTION_HEIGHT), colours["MAP_WATER"])
        draw = ImageDraw.Draw(image)

        for country_id, entry in geometry["countries"].items():
            selected = country_id == SELECTED
            fill = colours["MAP_SELECTED"] if selected else colours["MAP_LAND"]
            border = (colours["MAP_BORDER_SELECTED"] if selected
                      else colours["MAP_BORDER"])
            for polygon in entry["polygons"]:
                for index, flat in enumerate(polygon):
                    points = ring_points(flat, scale)
                    if len(points) < 3:
                        continue
                    # Ring 0 is the outline, the rest are holes: the view paints
                    # holes in the sea colour instead of doing polygon booleans.
                    draw.polygon(points, fill=colours["MAP_WATER"] if index else fill)
                    draw.line(points + [points[0]], fill=border, width=1)

        for country_id, record in records.items():
            if record.get("label_rank", 9) > LABEL_MAX_RANK or not record.get("label"):
                continue
            x, y = project(record["label"][0], record["label"][1])
            text = record["name"].upper()
            width = draw.textlength(text, font=label_font)
            if x - width / 2 < 4 or x + width / 2 > WIDTH - 4 or not 8 < y < HEIGHT - 8:
                continue
            draw.text((x - width / 2, y - 8), text, font=label_font,
                      fill=colours["MAP_LABEL"])

        # Caption strip: what this file is, and what it is not.
        draw.rectangle([0, HEIGHT, WIDTH, HEIGHT + CAPTION_HEIGHT],
                       fill=colours["MAP_LAND"])
        banner = (f"DATA RENDER — NOT AN ENGINE SCREENSHOT · {palette_name} palette · "
                  f"{len(records)} countries · equirectangular (lon/lat) · source: "
                  f"{manifest['source']['dataset']} {manifest['source']['version']}")
        draw.text((24, HEIGHT + 12), banner, font=caption_font,
                  fill=colours["MAP_LABEL"])
        footer = ("Drawn by tools/render_atlas_evidence.py from data/world/geometry.json "
                  "with colours read from src/ui/theme/palette.gd.")
        draw.text((24, HEIGHT + 36), footer, font=small_font, fill=colours["MAP_LABEL"])

        path = out_dir / f"atlas-{palette_name}.png"
        image.save(path)
        written.append(path)

    for path in written:
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
