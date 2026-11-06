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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_country_pack  # noqa: E402
import country_folders  # noqa: E402

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


def load_capitals(path: str) -> dict[str, dict]:
    """Capital city name *and* location keyed by Natural Earth admin-0 code.

    The location comes from the same populated-places feature that supplies the
    name, so the map never has a capital name from one place and a point from
    another. Coordinates are quantised exactly like country geometry (`quantise_point`).
    """
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    best: dict[str, tuple[int, dict]] = {}
    for feature in data["features"]:
        props = feature["properties"]
        if not props.get("adm0cap"):
            continue
        code = clean(props.get("adm0_a3"))
        name = clean(props.get("name"))
        lon = props.get("longitude", props.get("LONGITUDE"))
        lat = props.get("latitude", props.get("LATITUDE"))
        if not code or not name or lon is None or lat is None:
            continue
        rank = int(props.get("scalerank", 10))
        current = best.get(code)
        # Prefer the lowest scalerank; ignore "capital alt" duplicates.
        if current is None or rank < current[0]:
            best[code] = (rank, {
                "name": name,
                "point": quantise_point(float(lon), float(lat)),
            })
    return {code: entry for code, (_rank, entry) in best.items()}


def quantise_point(lon: float, lat: float) -> list[float]:
    """Snap a single coordinate to the 1/SCALE grid used by all geometry."""
    return [round(round(lon * SCALE) / SCALE, 3), round(round(lat * SCALE) / SCALE, 3)]


def _cross(origin: tuple[int, int], first: tuple[int, int],
           second: tuple[int, int]) -> int:
    return ((first[0] - origin[0]) * (second[1] - origin[1])
            - (first[1] - origin[1]) * (second[0] - origin[0]))


def _proper_crossing(a: tuple[int, int], b: tuple[int, int],
                     c: tuple[int, int], d: tuple[int, int]) -> bool:
    """True when the two segments cross in their interiors (integer-exact)."""
    d1 = _cross(a, b, c)
    d2 = _cross(a, b, d)
    d3 = _cross(c, d, a)
    d4 = _cross(c, d, b)
    return (((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0))
            and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)))


def find_self_intersections(points: list[tuple[int, int]]) -> list[tuple[int, int]]:
    """Segment pairs that cross, found through a coarse spatial grid.

    Comparing every segment with every other is O(n^2); Russia has thousands of
    points, so segments are bucketed into ~0.16 degree cells first and only
    compared inside a shared cell. The result is exact: the grid only prunes
    pairs that cannot possibly touch.
    """
    count = len(points)
    if count < 4:
        return []
    segments = [(points[i], points[(i + 1) % count]) for i in range(count)]
    cells: dict[tuple[int, int], list[int]] = {}
    for index, (start, end) in enumerate(segments):
        x0, x1 = sorted((start[0], end[0]))
        y0, y1 = sorted((start[1], end[1]))
        for cell_x in range(x0 // 32, x1 // 32 + 1):
            for cell_y in range(y0 // 32, y1 // 32 + 1):
                cells.setdefault((cell_x, cell_y), []).append(index)
    found: set[tuple[int, int]] = set()
    for bucket in cells.values():
        for first in range(len(bucket)):
            for second in range(first + 1, len(bucket)):
                i, j = bucket[first], bucket[second]
                if abs(i - j) <= 1 or (i == 0 and j == count - 1):
                    continue
                key = (min(i, j), max(i, j))
                if key in found:
                    continue
                if _proper_crossing(*segments[i], *segments[j]):
                    found.add(key)
    return sorted(found)


def repair_ring(flat: list[int]) -> tuple[list[int], int]:
    """Remove quantisation hairpins that make a ring self-intersecting.

    Rounding to 1/200 degree can collapse a sub-kilometre cape into a spike: the
    outline doubles back and crosses itself, which no triangulator will accept.
    The fix is to drop the single vertex that creates the spike, and only when it
    removes crossings *and* changes the enclosed area by less than 0.5 %. The
    real outline is preserved up to the quantisation grid; nothing is inflated,
    hulled or reshaped. Returns (flat ring, vertices removed).
    """
    points = [(flat[i], flat[i + 1]) for i in range(0, len(flat), 2)]
    if len(points) > 1 and points[0] == points[-1]:
        points = points[:-1]
    removed = 0
    for _attempt in range(64):
        crossings = find_self_intersections(points)
        if not crossings:
            break
        before = _polygon_area_int(points)
        candidates: list[int] = []
        for i, j in crossings[:8]:
            for vertex in (i, i + 1, j, (j + 1) % len(points)):
                if vertex not in candidates:
                    candidates.append(vertex)
        best: tuple[tuple[int, float], int] | None = None
        for vertex in candidates:
            trial = points[:vertex] + points[vertex + 1:]
            if len(trial) < 3:
                continue
            remaining = len(find_self_intersections(trial))
            if remaining >= len(crossings):
                continue
            after = _polygon_area_int(trial)
            delta = abs(after - before) / max(before, 1)
            if delta > 0.005:
                continue
            score = (remaining, delta)
            if best is None or score < best[0]:
                best = (score, vertex)
        if best is None:
            break
        points = points[:best[1]] + points[best[1] + 1:]
        removed += 1
    closed = points + [points[0]]
    flat_out: list[int] = []
    for x, y in closed:
        flat_out.extend((x, y))
    return flat_out, removed


def _polygon_area_int(points: list[tuple[int, int]]) -> float:
    total = 0
    for index in range(len(points)):
        x0, y0 = points[index]
        x1, y1 = points[(index + 1) % len(points)]
        total += x0 * y1 - x1 * y0
    return abs(total) / 2.0


def build(source_dir: str, out_dir: str, retrieved: str, generated: str | None = None) -> dict:
    countries_path = os.path.join(source_dir, "ne_50m_admin_0_countries.geojson")
    places_path = os.path.join(source_dir, "ne_50m_populated_places_simple.geojson")
    with open(countries_path, encoding="utf-8") as handle:
        source = json.load(handle)
    capitals = load_capitals(places_path)

    records: list[dict] = []
    geometry: dict[str, dict] = {}
    entries: list[dict] = []
    seen: dict[str, int] = {}
    dropped_rings = 0
    kept_rings = 0
    repaired_rings = 0
    repaired_vertices = 0
    repairs: list[dict] = []
    vertices = 0
    polygons_total = 0

    for feature_index, feature in enumerate(source["features"]):
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
        record_repairs: list[dict] = []
        dropped_here = 0
        repaired_here = 0
        repaired_vertices_here = 0
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
                    dropped_here += 1
                    continue
                flat = quantise(ring)
                if not flat:
                    dropped_rings += 1
                    dropped_here += 1
                    continue
                flat, removed = repair_ring(flat)
                if removed:
                    repaired_rings += 1
                    repaired_vertices += removed
                    repaired_here += 1
                    repaired_vertices_here += removed
                    repair = {
                        "ring": len(rings_out),
                        "removed_vertices": removed,
                        "area_before": round(ring_area(ring), 6),
                        "area_after": round(_polygon_area_int(
                            [(flat[i], flat[i + 1]) for i in range(0, len(flat) - 2, 2)])
                            / (SCALE * SCALE), 6),
                    }
                    record_repairs.append(repair)
                    repairs.append({"id": country_id, **repair})
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
            "capital": (capitals.get(adm0 or "") or {}).get("name"),
            "capital_point": (capitals.get(adm0 or "") or {}).get("point"),
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
        entries.append({
            "record": record,
            "geometry": geometry[country_id],
            "adm0": adm0,
            "formal_name": clean(props.get("FORMAL_EN")),
            "scale": SCALE,
            "source_index": feature_index,
            "repairs": record_repairs,
            "dropped_rings": dropped_here,
            "repaired_rings": repaired_here,
            "repaired_vertices": repaired_vertices_here,
        })

    records.sort(key=lambda item: item["name"])
    source_block = {
        "dataset": "Natural Earth 1:50m Cultural Vectors — Admin 0 Countries",
        "repository": SOURCE_REPO,
        "commit": SOURCE_COMMIT,
        "version": SOURCE_VERSION,
        "licence": SOURCE_LICENCE,
        "url": SOURCE_URL,
        "capital_url": CAPITALS_URL,
        "retrieved": retrieved,
    }
    folders_dir = os.path.join(out_dir, "countries")
    country_folders.write_folders(folders_dir, entries, source_block,
                                  generated or dt.date.today().isoformat())
    # The pack is built *from the folders*, not from the lists above, so the tree and
    # the thing the game loads can never disagree.
    documents = build_country_pack.build_documents(folders_dir)
    build_country_pack.write_pack(documents, out_dir)
    manifest = json.loads(documents["manifest.json"])
    return manifest


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--retrieved", default=dt.date.today().isoformat())
    parser.add_argument("--generated", default=None,
                        help="folder generation stamp (default: today); set it to reproduce an "
                             "existing tree byte-for-byte")
    args = parser.parse_args(argv)
    manifest = build(args.source_dir, args.out, args.retrieved, args.generated)
    counts = manifest["counts"]
    print(f"countries={counts['countries']} polygons={counts['polygons']} "
          f"rings={counts['rings']} vertices={counts['vertices']} "
          f"dropped_rings={counts['dropped_rings']}")
    for name in ("countries.json", "geometry.json", "manifest.json"):
        path = os.path.join(args.out, name)
        print(f"  {name}: {os.path.getsize(path) / 1024:.0f} KiB")
    folder_root = os.path.join(args.out, "countries")
    print(f"  countries/: {len(os.listdir(folder_root))} folders")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
