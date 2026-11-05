#!/usr/bin/env python3
"""Build the WORLD DOMINION runtime world atlas from Natural Earth source data.

This is an *offline* authoring step. The game never runs Python: it loads the two
JSON files this script writes. Keeping the pipeline here means the transformation
is reviewable and reproducible.

Source (public domain, see docs/DATA_SOURCES.md):
    nvkelso/natural-earth-vector @ ca96624a56bd078437bca8184e78163e5039ad19
      geojson/ne_50m_admin_0_countries.geojson
      geojson/ne_50m_populated_places_simple.geojson

Usage:
    python3 tools/build_world_atlas.py --source-dir /path/to/geojson \
        --out data/world

Outputs:
    data/world/countries.json   metadata + attribution + per-country bbox
    data/world/geometry.json    compact quantised polygon geometry
    data/world/manifest.json    machine-readable provenance recorded in-game
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import os
import sys
import unicodedata

# --- Policy constants ------------------------------------------------------

SCHEMA_VERSION = 1

# Coordinates are stored as integers in 1/SCALE degrees. 200 -> 0.005 deg
# (~550 m at the equator): far finer than one screen pixel at the zoom levels
# the atlas supports, and small enough to keep the file compact.
SCALE = 200

# Rings smaller than this bounding-box area (in square degrees) are dropped
# unless they are the largest ring of a country — this removes specks of dust
# without deleting island countries.
MIN_RING_AREA_DEG2 = 0.0025

SOURCE_REPO = "nvkelso/natural-earth-vector"
SOURCE_COMMIT = "ca96624a56bd078437bca8184e78163e5039ad19"
SOURCE_VERSION = "5.2.0-pre"
SOURCE_LICENCE = "Public Domain (Natural Earth Terms of Use)"
SOURCE_URL = (
    "https://github.com/nvkelso/natural-earth-vector/"
    f"blob/{SOURCE_COMMIT}/geojson/ne_50m_admin_0_countries.geojson"
)
CAPITALS_URL = (
    "https://github.com/nvkelso/natural-earth-vector/"
    f"blob/{SOURCE_COMMIT}/geojson/ne_50m_populated_places_simple.geojson"
)

# Regions exposed as filters. Natural Earth's CONTINENT field is the documented
# classification we rely on; anything outside this list (Antarctica, Seven seas)
# is still selectable, just not filterable.
FILTER_REGIONS = ["Africa", "Asia", "Europe", "North America", "Oceania", "South America"]


def fold(text: str) -> str:
    """Lowercase, accent-free search key (search must not care about diacritics)."""
    decomposed = unicodedata.normalize("NFKD", text)
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).lower()


def clean(value):
    """Natural Earth uses -99 for 'no value' in several text fields."""
    if value is None:
        return None
    if isinstance(value, str):
        value = value.strip()
        if value in ("", "-99", "-099", "-9"):
            return None
        return value
    if isinstance(value, (int, float)) and value == -99:
        return None
    return value


def iso_code(value, length: int):
    """ISO codes must be plain A-Z of the expected length; Natural Earth has
    values like 'CN-TW' in the ISO_A2 column, which is not an alpha-2 code."""
    text = clean(value)
    if text is None or len(text) != length or not text.isalpha() or not text.isupper():
        return None
    return text


def ring_area(points: list[list[float]]) -> float:
    area = 0.0
    for index in range(len(points) - 1):
        x0, y0 = points[index]
        x1, y1 = points[index + 1]
        area += x0 * y1 - x1 * y0
    return abs(area) / 2.0


def ring_bbox(points: list[list[float]]) -> list[float]:
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return [round(min(xs), 3), round(min(ys), 3), round(max(xs), 3), round(max(ys), 3)]


def quantise(ring: list[list[float]]) -> list[int]:
    """Round to 1/SCALE degrees, drop repeats, keep rings flat and closed."""
    out: list[int] = []
    last = None
    for lon, lat in ring:
        x = int(round(float(lon) * SCALE))
        y = int(round(float(lat) * SCALE))
        if (x, y) == last:
            continue
        out.extend((x, y))
        last = (x, y)
    # Rings stay closed (first point repeated) so borders can be stroked without
    # the renderer having to special-case the seam.
    return out if len(out) >= 8 else []


def polygons_of(geometry: dict) -> list[list[list[list[float]]]]:
    """Normalise Polygon / MultiPolygon into a list of polygons ([:ring])."""
    kind = geometry.get("type")
    if kind == "Polygon":
        return [geometry["coordinates"]]
    if kind == "MultiPolygon":
        return list(geometry["coordinates"])
    raise ValueError(f"unsupported geometry type {kind!r}")


def load_capitals(path: str) -> dict[str, str]:
    """Capital city names keyed by Natural Earth admin-0 code (ADM0_A3)."""
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    best: dict[str, tuple[int, str]] = {}
    for feature in data["features"]:
        props = feature["properties"]
        if not props.get("adm0cap"):
            continue
        code = clean(props.get("adm0_a3"))
        name = clean(props.get("name"))
        if not code or not name:
            continue
        rank = int(props.get("scalerank", 10))
        current = best.get(code)
        # Prefer the lowest scalerank; ignore "capital alt" duplicates.
        if current is None or rank < current[0]:
            best[code] = (rank, name)
    return {code: name for code, (_rank, name) in best.items()}


def build(source_dir: str, out_dir: str, retrieved: str) -> dict:
    countries_path = os.path.join(source_dir, "ne_50m_admin_0_countries.geojson")
    places_path = os.path.join(source_dir, "ne_50m_populated_places_simple.geojson")
    with open(countries_path, encoding="utf-8") as handle:
        source = json.load(handle)
    capitals = load_capitals(places_path)

    records: list[dict] = []
    geometry: dict[str, dict] = {}
    seen: dict[str, int] = {}
    dropped_rings = 0
    kept_rings = 0
    vertices = 0
    polygons_total = 0

    for feature in source["features"]:
        props = feature["properties"]
        admin = clean(props.get("ADMIN")) or clean(props.get("NAME"))
        if not admin:
            continue
        iso_a3 = iso_code(props.get("ISO_A3"), 3)
        iso_a2 = iso_code(props.get("ISO_A2"), 2)
        adm0 = clean(props.get("ADM0_A3"))
        country_id = (iso_a3 or adm0 or "").upper()
        if not country_id:
            continue
        # Stable ids: ISO alpha-3 when the source has one, else Natural Earth's
        # admin-0 code. Duplicates are disambiguated with a numeric suffix and
        # recorded, never silently merged.
        if country_id in seen:
            seen[country_id] += 1
            country_id = f"{country_id}-{seen[country_id]}"
        else:
            seen[country_id] = 1

        polygons_out: list[list[list[int]]] = []
        bbox = [180.0, 90.0, -180.0, -90.0]
        for polygon in polygons_of(feature["geometry"]):
            rings_out: list[list[int]] = []
            ring_areas = []
            for ring_index, ring in enumerate(polygon):
                if len(ring) < 4:
                    continue
                area = ring_area(ring)
                ring_areas.append((ring_index, area))
                if ring_index > 0 and area < MIN_RING_AREA_DEG2:
                    dropped_rings += 1
                    continue
                flat = quantise(ring)
                if not flat:
                    dropped_rings += 1
                    continue
                rings_out.append(flat)
                kept_rings += 1
                vertices += len(flat) // 2
            if not rings_out:
                continue
            polygons_out.append(rings_out)
            for lon, lat in [(p[0], p[1]) for p in polygon[0]]:
                bbox[0] = min(bbox[0], lon)
                bbox[1] = min(bbox[1], lat)
                bbox[2] = max(bbox[2], lon)
                bbox[3] = max(bbox[3], lat)
            polygons_total += 1

        if not polygons_out:
            continue

        name = clean(props.get("NAME")) or admin
        name_long = clean(props.get("NAME_LONG")) or name
        record = {
            "id": country_id,
            "name": name,
            "name_long": name_long,
            "iso_a2": iso_a2,
            "iso_a3": iso_a3,
            "region": clean(props.get("CONTINENT")),
            "subregion": clean(props.get("SUBREGION")),
            "capital": capitals.get(adm0 or ""),
            "type": clean(props.get("TYPE")),
            "sovereignty": clean(props.get("SOVEREIGNT")),
            "note": clean(props.get("NOTE_BRK")) or clean(props.get("NOTE_ADM0")),
            "label": [round(float(props["LABEL_X"]), 3), round(float(props["LABEL_Y"]), 3)]
            if props.get("LABEL_X") is not None
            else None,
            "label_rank": int(props.get("LABELRANK", 10)),
            "tiny": int(props.get("TINY", 0)) > 0,
            "bbox": [round(v, 3) for v in bbox],
            "filter_region": clean(props.get("CONTINENT")) in FILTER_REGIONS,
            "search": fold(" ".join(filter(None, [name, name_long, iso_a2, iso_a3, adm0,
                                                   clean(props.get("FORMAL_EN"))]))),
        }
        records.append(record)
        geometry[country_id] = {"bbox": record["bbox"], "polygons": polygons_out}

    records.sort(key=lambda item: item["name"])
    manifest = {
        "schema": SCHEMA_VERSION,
        "generated": dt.date.today().isoformat(),
        "source": {
            "dataset": "Natural Earth 1:50m Cultural Vectors — Admin 0 Countries",
            "repository": SOURCE_REPO,
            "commit": SOURCE_COMMIT,
            "version": SOURCE_VERSION,
            "licence": SOURCE_LICENCE,
            "url": SOURCE_URL,
            "capital_url": CAPITALS_URL,
            "retrieved": retrieved,
        },
        "processing": {
            "scale": SCALE,
            "min_ring_area_deg2": MIN_RING_AREA_DEG2,
            "steps": [
                "read GeoJSON with Python's json module",
                f"projected nothing: coordinates are stored as quantised lon/lat in 1/{SCALE} degrees",
                "dropped consecutive duplicate vertices and rings with fewer than 3 points",
                "dropped holes smaller than the minimum ring area",
                "capital names joined from ne_50m_populated_places_simple by adm0_a3 where adm0cap=1",
                "ISO alpha-2/alpha-3 accepted only when the source value is a plain code; else stored as null",
                "search keys folded to lowercase ASCII in the pipeline",
            ],
        },
        "counts": {
            "countries": len(records),
            "polygons": polygons_total,
            "rings": kept_rings,
            "dropped_rings": dropped_rings,
            "vertices": vertices,
        },
        "known_limitations": [
            "1:50m generalisation: coastlines and borders are simplified for world-scale display.",
            "Quantised to 0.005 degrees; sub-pixel detail below that resolution is intentionally lost.",
            "Natural Earth's map unit for Palestine is TYPE 'Indeterminate' with SOVEREIGNT 'Israel'; "
            "both source fields are preserved verbatim and no stance is taken.",
            "Disputed and dependent territories keep Natural Earth's TYPE/SOVEREIGNT/NOTE values; "
            "no sovereignty is inferred by this project.",
            "Population, GDP and income fields from the source are deliberately not imported.",
        ],
    }

    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, "countries.json"), "w", encoding="utf-8") as handle:
        json.dump({"schema": SCHEMA_VERSION, "countries": records}, handle,
                  ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")
    with open(os.path.join(out_dir, "geometry.json"), "w", encoding="utf-8") as handle:
        json.dump({"schema": SCHEMA_VERSION, "scale": SCALE, "countries": geometry}, handle,
                  separators=(",", ":"))
        handle.write("\n")
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    return manifest


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--retrieved", default=dt.date.today().isoformat())
    args = parser.parse_args(argv)
    manifest = build(args.source_dir, args.out, args.retrieved)
    counts = manifest["counts"]
    print(f"countries={counts['countries']} polygons={counts['polygons']} "
          f"rings={counts['rings']} vertices={counts['vertices']} "
          f"dropped_rings={counts['dropped_rings']}")
    for name in ("countries.json", "geometry.json", "manifest.json"):
        path = os.path.join(args.out, name)
        print(f"  {name}: {os.path.getsize(path) / 1024:.0f} KiB")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
