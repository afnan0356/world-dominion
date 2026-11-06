#!/usr/bin/env python3
"""Deep validation of the committed world atlas, with a reviewable report.

`tools/check_atlas_data.py` is the fast CI smoke alarm: it proves the files exist,
parse, and agree with each other. This script is the full audit a developer runs
before regenerating or extending the data. It checks the schema, identifier and
ISO rules, geometry integrity, cross-file consistency and dataset provenance, then
writes a Markdown report that a reviewer can read without opening the JSON.

Errors fail the run (exit 1). Findings that describe an honest property of the
source — a missing capital, a territory with no ISO code — are reported as
coverage, not errors, because inventing values to make the table look complete is
forbidden (see docs/DATA_SOURCES.md).

Usage:

    python3 tools/validate_world_atlas.py                 # check, print summary
    python3 tools/validate_world_atlas.py --report docs/DATA_QUALITY.md
    python3 tools/validate_world_atlas.py --check-report docs/DATA_QUALITY.md

`--check-report` additionally fails when the file on disk is stale, which is how
CI keeps the committed report honest.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from collections import Counter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build_world_atlas import find_self_intersections  # noqa: E402  (same folder)

ROOT = pathlib.Path(__file__).resolve().parent.parent
REGISTRY_SOURCE = ROOT / "src/core/world/country_registry.gd"
FOLD_ENTRY = re.compile(r'"([^"]+)":\s*"([^"]+)"')
WORLD = ROOT / "data/world"
ID_PATTERN = re.compile(r"^[A-Z]{3}(-[0-9]+)?$")
ISO_A2 = re.compile(r"^[A-Z]{2}$")
ISO_A3 = re.compile(r"^[A-Z]{3}$")
REQUIRED_SOURCE_FIELDS = (
    "dataset", "repository", "commit", "version", "licence", "url", "retrieved",
)
MAX_REGION_MISSING = 0
MIN_COUNTRIES = 200
BBOX_TOLERANCE = 0.02  # degrees; records are rounded to 3 decimals


def load_accent_folds() -> dict[str, str]:
    """Read the accent-folding table out of CountryRegistry so validation folds
    names exactly the way the game's search does, instead of guessing."""
    folds: dict[str, str] = {}
    inside = False
    for line in REGISTRY_SOURCE.read_text(encoding="utf-8").splitlines():
        if "ACCENT_FOLDS" in line and "{" in line:
            inside = True
            continue
        if inside:
            if line.strip() == "}":
                break
            for entry in FOLD_ENTRY.findall(line):
                folds[entry[0]] = entry[1]
    return folds


def fold(text: str, folds: dict[str, str]) -> str:
    lowered = text.lower()
    return "".join(folds.get(character, character) for character in lowered)


class Report:
    """Collects findings so one pass can both fail CI and write the document."""

    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.sections: list[tuple[str, list[str]]] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warning(self, message: str) -> None:
        self.warnings.append(message)

    def section(self, title: str, lines: list[str]) -> None:
        self.sections.append((title, lines))


def load(report: Report) -> dict | None:
    payload = {}
    for key, filename in (("countries", "countries.json"),
                          ("geometry", "geometry.json"),
                          ("manifest", "manifest.json"),
                          ("coast", "coast.json")):
        path = WORLD / filename
        try:
            payload[key] = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            report.error(f"{filename} is missing from data/world")
            return None
        except json.JSONDecodeError as error:
            report.error(f"{filename} is not valid JSON: {error}")
            return None
    return payload


def validate_registry(countries: list[dict], report: Report) -> dict:
    folds = load_accent_folds()
    stats = {"missing": Counter(), "types": Counter(), "regions": Counter()}
    by_id: dict[str, dict] = {}
    for index, record in enumerate(countries):
        where = f"record #{index}"
        if not isinstance(record, dict):
            report.error(f"{where} is not an object")
            continue
        country_id = record.get("id")
        name = record.get("name")
        if not isinstance(country_id, str) or not ID_PATTERN.match(country_id):
            report.error(f"{where} has an unusable id {country_id!r}")
            continue
        where = country_id
        if country_id in by_id:
            report.error(f"duplicate country id {country_id}")
            continue
        by_id[country_id] = record
        if not isinstance(name, str) or not name.strip():
            report.error(f"{where} has no display name")
        if not record.get("region"):
            report.error(f"{where} has no region")
        # A record may legitimately have no code: `code_status == "none"` says the pinned
        # source has none of its own, and inventing one is exactly what this project
        # refuses to do. Any *other* status with an empty code is still an error, and a
        # "none" record that shows a code is an error too.
        status = record.get("code_status")
        if status not in ("iso-official", "user-assigned", "none"):
            report.error(f"{where} has an unknown code_status {status!r}")
        for key, pattern, label in (("iso_a2", ISO_A2, "alpha-2"), ("iso_a3", ISO_A3, "alpha-3")):
            value = record.get(key)
            # An empty code is legitimate only when the data says so: a "none" record has
            # neither code, and a "user-assigned" record may have one of the two (Kosovo
            # has XK and no three-letter code anywhere in the source).
            if status == "none":
                if value not in (None, ""):
                    report.error(f"{where} says it has no code but shows {value!r} "
                                 f"as its ISO {label} code")
                stats["missing"][key] += 1
                continue
            if value in (None, ""):
                if status != "user-assigned":
                    report.error(f"{where} has no ISO {label} code but is not recorded "
                                 "as having none")
                stats["missing"][key] += 1
                continue
            if not isinstance(value, str) or not pattern.match(value):
                report.error(f"{where} has a malformed ISO {label} code {value!r}")
        iso_a3 = record.get("iso_a3")
        if iso_a3 and country_id.isalpha() and len(country_id) == 3 and iso_a3 != country_id:
            report.warning(f"{where}: id and ISO alpha-3 disagree ({country_id} vs {iso_a3})")
        for key in ("capital", "capital_point", "subregion", "note", "name_long"):
            if record.get(key) is None:
                stats["missing"][key] += 1
        capital_point = record.get("capital_point")
        if capital_point is not None:
            if (not isinstance(capital_point, list) or len(capital_point) != 2
                    or not all(isinstance(value, (int, float)) for value in capital_point)):
                report.error(f"{where} has a malformed capital_point {capital_point!r}")
            else:
                point_lon, point_lat = float(capital_point[0]), float(capital_point[1])
                if not (-180.0 <= point_lon <= 180.0 and -90.0 <= point_lat <= 90.0):
                    report.error(f"{where} places its capital outside the world")
                if record.get("capital") is None:
                    report.error(f"{where} has capital coordinates but no capital name")
            stats["capital_points"] = stats.get("capital_points", 0) + 1
        if record.get("label") is None:
            stats["missing"]["label"] += 1
        stats["types"][str(record.get("type"))] += 1
        stats["regions"][str(record.get("region"))] += 1
        bbox = record.get("bbox")
        if not (isinstance(bbox, list) and len(bbox) == 4):
            report.error(f"{where} has no usable bbox")
        else:
            min_lon, min_lat, max_lon, max_lat = (float(value) for value in bbox)
            if max_lon <= min_lon or max_lat <= min_lat:
                report.error(f"{where} has a degenerate bbox {bbox}")
            if not (-180.0 <= min_lon <= 180.0 and -180.0 <= max_lon <= 180.0
                    and -90.0 <= min_lat <= 90.0 and -90.0 <= max_lat <= 90.0):
                report.error(f"{where} has a bbox outside the world {bbox}")
            label = record.get("label")
            if isinstance(label, list) and len(label) == 2:
                lon, lat = float(label[0]), float(label[1])
                if not (min_lon - 1.0 <= lon <= max_lon + 1.0
                        and min_lat - 1.0 <= lat <= max_lat + 1.0):
                    report.warning(f"{where} labels the country outside its own bbox")
        search = record.get("search")
        if not isinstance(search, str) or not search.strip():
            report.error(f"{where} has no search key")
        elif isinstance(name, str) and fold(name, folds) not in search:
            report.error(f"{where} search key does not contain its own name")
        else:
            for key, token in (("iso_a2", record.get("iso_a2")), ("iso_a3", record.get("iso_a3"))):
                if token and token.lower() not in search:
                    report.error(f"{where} search key does not contain its {key}")
    if len(by_id) < MIN_COUNTRIES:
        report.error(f"only {len(by_id)} countries; the atlas must cover at least {MIN_COUNTRIES}")

    # ISO codes must identify one unit each, otherwise search by code is ambiguous.
    for key in ("iso_a2", "iso_a3"):
        seen: dict[str, str] = {}
        for country_id, record in by_id.items():
            code = record.get(key)
            if not code:
                continue
            if code in seen:
                report.error(f"ISO {key} {code} is used by both {seen[code]} and {country_id}")
            seen[code] = country_id

    # Two records with the same folded display name would be indistinguishable in
    # search results; that is a data defect, not a stylistic one.
    folded: dict[str, list[str]] = {}
    for country_id, record in by_id.items():
        name = fold(str(record.get("name", "")).strip(), folds)
        folded.setdefault(name, []).append(country_id)
    for name, ids in folded.items():
        if len(ids) > 1:
            report.error(f"countries {ids} share the display name {name!r}")
    return {"by_id": by_id, **stats}


def validate_geometry(geometry: dict, by_id: dict[str, dict], report: Report) -> dict:
    scale = geometry.get("scale")
    if not isinstance(scale, int) or scale <= 0:
        report.error("geometry.json has no positive integer 'scale'")
        return {}
    entries = geometry.get("countries")
    if not isinstance(entries, dict):
        report.error("geometry.json has no 'countries' object")
        return {}
    missing_geometry = sorted(set(by_id) - set(entries))
    orphan_geometry = sorted(set(entries) - set(by_id))
    for country_id in missing_geometry:
        report.error(f"{country_id} has a registry record but no geometry")
    for country_id in orphan_geometry:
        report.error(f"{country_id} has geometry but no registry record")

    polygons = rings = vertices = 0
    quirks = {"unclosed": 0, "degenerate_area": 0, "antimeridian": 0, "empty_polygon": 0,
              "self_intersecting": 0}
    worst_bbox = 0.0
    for country_id, entry in entries.items():
        if not isinstance(entry, dict) or not isinstance(entry.get("polygons"), list):
            report.error(f"{country_id} has no polygon list")
            continue
        country_polygons = entry["polygons"]
        if not country_polygons:
            quirks["empty_polygon"] += 1
            report.error(f"{country_id} has an empty polygon list")
        computed = [180.0, 90.0, -180.0, -90.0]
        for polygon_index, polygon in enumerate(country_polygons):
            polygons += 1
            if not isinstance(polygon, list) or not polygon:
                report.error(f"{country_id} polygon {polygon_index} is empty")
                continue
            for ring_index, flat in enumerate(polygon):
                rings += 1
                where = f"{country_id} polygon {polygon_index} ring {ring_index}"
                if not isinstance(flat, list) or len(flat) < 6 or len(flat) % 2:
                    report.error(f"{where} is not a flat even-length coordinate list")
                    continue
                points = [(flat[i] / scale, flat[i + 1] / scale)
                          for i in range(0, len(flat), 2)]
                vertices += len(points)
                if points[0] != points[-1]:
                    quirks["unclosed"] += 1
                    report.error(f"{where} is not closed")
                body = points[:-1]
                area = 0.0
                for i in range(len(body)):
                    x1, y1 = body[i]
                    x2, y2 = body[(i + 1) % len(body)]
                    area += x1 * y2 - x2 * y1
                if abs(area / 2.0) < 1e-9:
                    quirks["degenerate_area"] += 1
                    report.error(f"{where} encloses no area")
                for i in range(len(body)):
                    x1 = body[i][0]
                    x2 = body[(i + 1) % len(body)][0]
                    if abs(x2 - x1) > 180.0:
                        quirks["antimeridian"] += 1
                        report.error(f"{where} crosses the antimeridian without being split")
                        break
                integer_ring = [(int(round(lon * scale)), int(round(lat * scale)))
                                for lon, lat in body]
                crossings = find_self_intersections(integer_ring)
                if crossings:
                    quirks["self_intersecting"] = quirks.get("self_intersecting", 0) + 1
                    report.error(f"{where} still crosses itself at {crossings[0]}")
                for lon, lat in points:
                    if not (-180.0 <= lon <= 180.0 and -90.0 <= lat <= 90.0):
                        report.error(f"{where} has a coordinate outside the world")
                        break
                    computed[0] = min(computed[0], lon)
                    computed[1] = min(computed[1], lat)
                    computed[2] = max(computed[2], lon)
                    computed[3] = max(computed[3], lat)
        recorded = by_id.get(country_id, {}).get("bbox")
        if isinstance(recorded, list) and len(recorded) == 4:
            drift = max(abs(computed[i] - float(recorded[i])) for i in range(4))
            worst_bbox = max(worst_bbox, drift)
            if drift > BBOX_TOLERANCE:
                report.error(f"{country_id} bbox disagrees with its geometry by {drift:.3f} degrees")
    return {"polygons": polygons, "rings": rings, "vertices": vertices,
            "quirks": quirks, "worst_bbox_drift": worst_bbox,
            "missing_geometry": missing_geometry, "orphan_geometry": orphan_geometry}


def validate_manifest(manifest: dict, registry: dict, geometry: dict, report: Report) -> None:
    source = manifest.get("source")
    if not isinstance(source, dict):
        report.error("manifest.json has no 'source' object")
        return
    for key in REQUIRED_SOURCE_FIELDS:
        if not str(source.get(key, "")).strip():
            report.error(f"the manifest does not record '{key}'")
    licence = str(source.get("licence", ""))
    if "Public Domain" not in licence and "CC0" not in licence:
        report.error(f"licence {licence!r} is not recorded as redistributable")
    if not str(source.get("url", "")).startswith("https://"):
        report.error("the source URL must be an https link")
    counts = manifest.get("counts", {})
    measured = {
        "countries": len(registry["by_id"]),
        "polygons": geometry.get("polygons", 0),
        "rings": geometry.get("rings", 0),
        "vertices": geometry.get("vertices", 0),
    }
    for key, value in measured.items():
        if counts.get(key) != value:
            report.error(f"the manifest's {key} count ({counts.get(key)}) is stale; measured {value}")
    if not manifest.get("known_limitations"):
        report.error("the manifest must record the dataset's known limitations")
    if not manifest.get("processing", {}).get("steps"):
        report.error("the manifest must record the processing steps")


def validate_coast(coast: dict, registry: dict, geometry: dict, report: Report) -> dict:
    """Coastline hints must describe the geometry, not extend it.

    The rule the hint file exists to obey: a segment shared by two records is a land
    border, a segment used by exactly one record is coastline, and a record with no
    coastline segment is landlocked. Nothing is drawn that the source does not
    contain, so a country without coastline simply gets a plain border.
    """
    if not isinstance(coast, dict) or not isinstance(coast.get("countries"), dict):
        report.error("coast.json has no 'countries' object")
        return {}
    summary = coast.get("summary", {})
    countries = coast["countries"]
    if len(countries) != len(registry["by_id"]):
        report.error(f"coast.json describes {len(countries)} records, the registry has "
                     f"{len(registry['by_id'])}")
    unknown = sorted(set(countries) - set(registry["by_id"]))
    if unknown:
        report.error(f"coast.json names ids that are not in the registry: {unknown[:5]}")
    missing = sorted(set(registry["by_id"]) - set(countries))
    if missing:
        report.error(f"coast.json has no entry for {len(missing)} records: {missing[:5]}")
    # Each value is one digit per ring: 1 = entirely coastline, 2 = coast and
    # shared border, 0 = entirely shared border. A record has a coast if any of its
    # rings carries a 1 or a 2.
    for country_id, digits in countries.items():
        text = str(digits)
        if text and set(text) - {"0", "1", "2"}:
            report.error(f"coast.json entry for {country_id} has codes other than 0/1/2: {text!r}")
    coded_rings = sum(len(str(value)) for value in countries.values())
    if coded_rings != geometry.get("rings"):
        report.error(f"coast.json codes {coded_rings} rings, geometry has {geometry.get('rings')}")
    with_coast = sum(1 for value in countries.values() if set(str(value)) & {"1", "2"})
    landlocked = len(countries) - with_coast
    if summary.get("rings") not in (None, geometry.get("rings")):
        report.error(f"coast.json counts {summary.get('rings')} rings, geometry has "
                     f"{geometry.get('rings')}")
    if summary.get("shared_segments", 0) > summary.get("segments", 0):
        report.error("coast.json claims more shared segments than segments")
    return {
        "with_coast": with_coast,
        "landlocked": landlocked,
        "summary": summary,
        "scale": int(coast.get("scale", 0)),
        "method": str(coast.get("method", "")),
    }


def build_report(payload: dict, registry: dict, geometry: dict) -> str:
    countries = payload["countries"]["countries"]
    manifest = payload["manifest"]
    source = manifest["source"]
    lines: list[str] = []
    add = lines.append

    add("# World atlas data quality report")
    add("")
    add("Generated by `python3 tools/validate_world_atlas.py --report docs/DATA_QUALITY.md`.")
    add("Do not edit by hand: CI runs the same command and fails when this file is stale.")
    add("")
    add("## Dataset")
    add("")
    add("| Field | Value |")
    add("| --- | --- |")
    for label, key in (("Dataset", "dataset"), ("Repository", "repository"), ("Commit", "commit"),
                       ("Version", "version"), ("Licence", "licence"), ("Retrieved", "retrieved")):
        add(f"| {label} | `{source.get(key, '')}` |")
    add("")
    add("## Volume")
    add("")
    add("| Measurement | Value |")
    add("| --- | --- |")
    add(f"| Countries and territories | {len(registry['by_id'])} |")
    add(f"| Polygons | {geometry.get('polygons', 0)} |")
    add(f"| Rings | {geometry.get('rings', 0)} |")
    add(f"| Vertices | {geometry.get('vertices', 0)} |")
    add(f"| Coordinate quantisation | 1/{payload['geometry']['scale']}° |")
    add(f"| Worst bbox drift against geometry | {geometry.get('worst_bbox_drift', 0.0):.4f}° |")
    add(f"| Records with a sourced capital and a capital point | {registry.get('capital_points', 0)} |")
    add(f"| Records with no sourced capital | {len(registry['by_id']) - registry.get('capital_points', 0)} |")
    add("")
    add("## Political classification, as the source states it")
    add("")
    add("| `type` | Records |")
    add("| --- | --- |")
    for key, value in sorted(registry["types"].items(), key=lambda item: -item[1]):
        add(f"| {key} | {value} |")
    add("")
    add("This project does not arbitrate sovereignty. Disputed and indeterminate units keep Natural")
    add("Earth's `TYPE`, `SOVEREIGNT` and `NOTE` verbatim, and no geometry is reassigned.")
    add("")
    add("## Region coverage")
    add("")
    add("| Region | Records |")
    add("| --- | --- |")
    for key, value in sorted(registry["regions"].items()):
        add(f"| {key} | {value} |")
    add("")
    add("## Field coverage (source gaps, not defects)")
    add("")
    add("| Field | Records without a value |")
    add("| --- | --- |")
    total = len(registry["by_id"])
    for key, value in sorted(registry["missing"].items()):
        add(f"| `{key}` | {value} of {total} |")
    add("")
    add("A blank in these columns means the source does not record the value. The game shows the gap")
    add("explicitly; it never fills one in. Notable source gaps: Natural Earth stores `-99` for the ISO")
    add("codes of France, Norway, Kosovo, Somaliland, Northern Cyprus and a few dependent territories, and")
    add("stores `CN-TW` as Taiwan's alpha-2 code, which is not an ISO alpha-2 code — all of these are")
    add("recorded as absent rather than repaired.")
    add("")
    add("## Geometry checks")
    add("")
    add("| Check | Result |")
    add("| --- | --- |")
    quirks = geometry.get("quirks", {})
    add(f"| Unclosed rings | {quirks.get('unclosed', 0)} |")
    add(f"| Zero-area rings | {quirks.get('degenerate_area', 0)} |")
    add(f"| Rings crossing the antimeridian unsplit | {quirks.get('antimeridian', 0)} |")
    add(f"| Rings that still cross themselves | {quirks.get('self_intersecting', 0)} |")
    add(f"| Rings repaired by the build (quantisation hairpins) | {manifest.get('counts', {}).get('repaired_rings', 0)} |")
    add(f"| Vertices removed by those repairs | {manifest.get('counts', {}).get('repaired_vertices', 0)} |")
    add(f"| Countries with no polygons | {quirks.get('empty_polygon', 0)} |")
    add(f"| Registry records without geometry | {len(geometry.get('missing_geometry', []))} |")
    add(f"| Geometry entries without a registry record | {len(geometry.get('orphan_geometry', []))} |")
    add("")
    add("## Geometry repairs applied by the build")
    add("")
    repairs = manifest.get("repairs", [])
    if not repairs:
        add("None: every ring was already a simple polygon.")
    else:
        add("| Unit | Ring | Vertices removed | Area before (deg²) | Area after (deg²) |")
        add("| --- | --- | --- | --- | --- |")
        for repair in repairs:
            add(f"| {repair['id']} | {repair['ring']} | {repair['removed_vertices']} | "
                f"{repair['area_before']:.6f} | {repair['area_after']:.6f} |")
        add("")
        add("A repair removes a single vertex that rounding to the 1/200° grid turned into a "
            "self-crossing hairpin. It is accepted only when it removes the crossing and changes "
            "the enclosed area by less than 0.5 %, so the outline is preserved to within the "
            "quantisation grid rather than being reshaped.")
    add("")
    coast = payload.get("coast", {})
    coast_summary = coast.get("summary", {})
    coast_countries = coast.get("countries", {})
    with_coast = sum(1 for value in coast_countries.values() if set(str(value)) & {"1", "2"})
    add("## Coastline hints")
    add("")
    add("The map draws a coastline only where the source contains one. A segment used by two")
    add("records is a shared land border; a segment used by exactly one record is coast. Each")
    add("record stores one digit per ring (1 = entirely coast, 2 = coast and shared border,")
    add("0 = entirely shared border), and every count below is taken from that, never")
    add("guessed. **No coastline is invented**: a record with no coast segment is drawn with a")
    add("plain border and no waterline, and the dossier says nothing about a coast it does not")
    add("have.")
    add("")
    add("| Measurement | Value |")
    add("| --- | --- |")
    add(f"| Records with at least one coastline segment | {with_coast} |")
    add(f"| Records with none (landlocked or fully enclosed) | {len(coast_countries) - with_coast} |")
    add(f"| Rings classified from shared segments | {coast_summary.get('rings', 0)} |")
    add(f"| Rings that are entirely coastline | {coast_summary.get('fully_coastal', 0)} |")
    add(f"| Rings that are entirely shared land border | {coast_summary.get('fully_shared', 0)} |")
    add(f"| Rings that mix coast and land border | {coast_summary.get('mixed', 0)} |")
    add(f"| Segments examined | {coast_summary.get('segments', 0)} |")
    add(f"| Segments shared by two records | {coast_summary.get('shared_segments', 0)} |")
    add("")
    add("The classification is only as good as the quantisation: two neighbouring outlines")
    add("agree exactly because both were rounded to the same 1/200° grid, so a border segment")
    add("that fails to match is counted as coastline. That errs towards drawing a coast rather")
    add("than a border — visible and harmless — instead of drawing a border across open water.")
    add("")
    add("## Git-visible source quirks the game must tolerate")
    add("")
    add("| Unit | Quirk |")
    add("| --- | --- |")
    for country_id in sorted(registry["by_id"]):
        record = registry["by_id"][country_id]
        notes = []
        if not record.get("iso_a3"):
            notes.append("no ISO alpha-3 in source")
        if not record.get("iso_a2"):
            notes.append("no ISO alpha-2 in source")
        if not record.get("capital"):
            notes.append("no capital in source")
        if record.get("type") not in (None, "Sovereign country"):
            notes.append(f"`type` = {record.get('type')}")
        if notes:
            add(f"| {record['name']} (`{country_id}`) | {', '.join(notes)} |")
    add("")
    add("## Findings from this run")
    add("")
    return "\n".join(lines) + "\n"


def build_findings(errors: list[str], warnings: list[str]) -> str:
    lines = ["### Errors", ""]
    lines.extend([f"- {item}" for item in errors] or ["- none"])
    lines.extend(["", "### Warnings", ""])
    lines.extend([f"- {item}" for item in warnings] or ["- none"])
    lines.append("")
    return "\n".join(lines) + "\n"


def validate_start_eligibility(registry: dict, report: Report) -> dict:
    """Check the start-nation rule against the data it names.

    The rule file lists the dataset's own `type` values. It is hand-maintained, so
    the failure modes are its own: a value the dataset never uses (a typo, or an
    upstream rename), an empty list (the game could not start at all), or a rule
    that would make every record playable. None of these is a data error in the
    atlas, so they are reported as errors here — a rule that names nothing cannot
    be reviewed.
    """
    path = ROOT / "data/world/start_eligibility.json"
    result = {"eligible_types": [], "counts": {}, "eligible": 0, "ineligible": 0}
    if not path.exists():
        report.errors.append("start_eligibility.json is missing")
        return result
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        report.errors.append(f"start_eligibility.json is not valid JSON ({error})")
        return result
    types = payload.get("eligible_types")
    if not isinstance(types, list) or not types:
        report.errors.append("start_eligibility.json lists no eligible types")
        return result
    used = registry["types"]
    for entry in types:
        name = str(entry)
        if name not in used:
            report.errors.append(
                f"start_eligibility.json names the type '{name}', which no record uses")
        result["eligible_types"].append(name)
    for record in registry["by_id"].values():
        if record.get("type") in result["eligible_types"]:
            result["eligible"] += 1
            result["counts"][record["type"]] = result["counts"].get(record["type"], 0) + 1
        else:
            result["ineligible"] += 1
    if result["eligible"] == 0:
        report.errors.append("start_eligibility.json leaves no record playable")
    if not isinstance(payload.get("reason"), str) or not payload["reason"].strip():
        report.errors.append("start_eligibility.json has no neutral reason to show players")
    return result


def build_eligibility(eligibility: dict) -> str:
    lines: list[str] = []
    if not eligibility["eligible_types"]:
        return ""
    add = lines.append
    add("## Starting-nation rule")
    add("")
    add("Which records may start a campaign, read from `data/world/start_eligibility.json`. "
        "The rule lists the dataset's own type values and names no individual place; the full "
        "generated list is [START_NATIONS.md](START_NATIONS.md).")
    add("")
    add("| Eligible source type | Records |")
    add("| --- | --- |")
    for name in eligibility["eligible_types"]:
        add(f"| `{name}` | {eligibility['counts'].get(name, 0)} |")
    add("")
    add(f"**{eligibility['eligible']}** of {eligibility['eligible'] + eligibility['ineligible']} "
        "records can start a campaign under this rule; the rest stay browsable, searchable and "
        "readable in the dossier. The rule is a default for owner review, not a final decision.")
    add("")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", help="write the Markdown report to this path")
    parser.add_argument("--check-report", help="fail when the report at this path is stale")
    args = parser.parse_args(argv[1:])

    report = Report()
    payload = load(report)
    if payload is None:
        print("\n".join(report.errors), file=sys.stderr)
        return 1
    countries = payload["countries"].get("countries")
    if not isinstance(countries, list):
        print("countries.json has no 'countries' array", file=sys.stderr)
        return 1
    registry = validate_registry(countries, report)
    geometry = validate_geometry(payload["geometry"], registry["by_id"], report)
    validate_manifest(payload["manifest"], registry, geometry, report)
    eligibility = validate_start_eligibility(registry, report)
    validate_coast(payload["coast"], registry, geometry, report)

    for message in report.errors:
        print(f"error: {message}", file=sys.stderr)
    for message in report.warnings[:20]:
        print(f"warning: {message}", file=sys.stderr)
    if len(report.warnings) > 20:
        print(f"warning: … and {len(report.warnings) - 20} more", file=sys.stderr)

    document = (build_report(payload, registry, geometry)
                + build_eligibility(eligibility)
                + build_findings(report.errors, report.warnings))

    if args.report:
        path = pathlib.Path(args.report)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(document, encoding="utf-8")
        print(f"wrote {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}")

    if args.check_report:
        path = pathlib.Path(args.check_report)
        current = path.read_text(encoding="utf-8") if path.exists() else ""
        if current != document:
            print(f"{path} is stale; re-run with --report {path}", file=sys.stderr)
            return 1

    if report.errors:
        print(f"FAIL: {len(report.errors)} error(s), {len(report.warnings)} warning(s)")
        return 1
    print(f"atlas data valid: {len(registry['by_id'])} countries, "
          f"{geometry['polygons']} polygons, {geometry['vertices']} vertices, "
          f"{len(report.warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
