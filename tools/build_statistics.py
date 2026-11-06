#!/usr/bin/env python3
"""Build per-country statistics from the pinned Natural Earth source.

Every number this script writes comes from one file whose name, version, retrieval
date, licence and URL are recorded in the output: the Natural Earth 1:50m Admin 0
Countries layer at the commit the atlas is already pinned to. **Nothing is typed from
memory, estimated, interpolated or rounded to fill a gap.** A value that the source
does not give as an exact integer is not written at all, and the reason is reported.

Indicators (deliberately three):

* `population` — the source's own `POP_EST`, in people, with its `POP_YEAR`.
* `gdp_usd`    — the source's `GDP_MD` (millions of US dollars) multiplied by
                 1,000,000, with its `GDP_YEAR`. The multiplication is recorded as
                 `source_scale`, so the arithmetic can be checked rather than trusted.
* `area_km2`   — **derived**, not a source field: the spherical area of the committed
                 1:50m outline. It is flagged `derived` with its method, and the game
                 labels it as derived wherever it is shown.

Usage:

    python3 tools/build_statistics.py                  # rewrite the folders and the pack
    python3 tools/build_statistics.py --check          # fail when either is stale
    python3 tools/build_statistics.py --report docs/STATISTICS_REPORT.md
    python3 tools/build_statistics.py --self-test      # fixture checks on the rules

The builder never touches `countries.json`, `geometry.json`, `coast.json` or the
per-country identity/geometry/sources files: it writes `statistics.json` per folder
plus `data/world/statistics.json`, which `tools/build_country_pack.py` then folds into
the manifest.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORLD = ROOT / "data" / "world"
FOLDERS = WORLD / "countries"
CROSSWALK = WORLD / "statistics_crosswalk.json"
PACK = WORLD / "statistics.json"
DEFAULT_SOURCE = ROOT / "data" / "source" / "ne_50m_admin_0_countries.geojson"

SCHEMA = 1
R_EARTH_KM = 6371.0088
SCALE = 200  # the geometry's quantisation, 1/200 degree

NOTICE = ("Baseline reference data for the 2026 scenario start, not live. Each value "
          "carries the year the source records it for.")

## Indicator definitions, in display order. `unit` is what a reader sees; `field` is
## where the number comes from; `scale` is the only arithmetic applied.
INDICATORS = (
    {"key": "population", "label": "Population", "unit": "people", "field": "POP_EST",
     "year_field": "POP_YEAR", "scale": 1, "derived": False, "digit_group": 0},
    {"key": "gdp_usd", "label": "GDP", "unit": "USD", "field": "GDP_MD",
     "year_field": "GDP_YEAR", "scale": 1_000_000, "derived": False, "digit_group": 0},
    {"key": "area_km2", "label": "Area", "unit": "km2", "field": None,
     "year_field": None, "scale": 1, "derived": True,
     "method": "spherical area of the committed 1:50m outline (land inside the outline)"},
)


class Rejection(Exception):
    """A source value that cannot be written as an exact integer."""


def read_json(path: pathlib.Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical(doc: dict) -> str:
    """One serialisation, so a rebuild is byte-identical."""
    return json.dumps(doc, indent=2, ensure_ascii=False) + "\n"


# --- the source ------------------------------------------------------------


def load_source(path: pathlib.Path) -> tuple[dict[str, dict], str]:
    if not path.exists():
        raise SystemExit(
            f"no source file at {path}. Run tools/fetch_world_atlas.py first; this builder "
            "never downloads or invents data on its own.")
    raw = path.read_bytes()
    payload = json.loads(raw.decode("utf-8"))
    features = payload.get("features")
    if not isinstance(features, list) or not features:
        raise SystemExit(f"{path} has no features array")
    rows = {}
    for feature in features:
        props = feature.get("properties") or {}
        code = props.get("ADM0_A3")
        if not code:
            raise SystemExit("a source row has no ADM0_A3 code")
        if code in rows:
            raise SystemExit(f"duplicate source row for {code}")
        rows[code] = props
    return rows, hashlib.sha256(raw).hexdigest()


def source_block(crosswalk: dict, sha256: str) -> dict:
    src = crosswalk["source"]
    return {
        "id": src["id"],
        "dataset": src["dataset"],
        "repository": src["repository"],
        "commit": src["commit"],
        "version": src["version"],
        "licence": src["licence"],
        "url": src["url"],
        "retrieved": src["retrieved"],
        "file": src["file"],
        "sha256": sha256,
        "attribution": "Made with Natural Earth. Free vector and raster map data.",
        "estimate_note": ("Natural Earth publishes POP_EST and GDP_MD as its own estimates, each with "
                          "the year it refers to in POP_YEAR / GDP_YEAR. This project does not adjust, "
                          "annualise or re-estimate them."),
    }


# --- value extraction ------------------------------------------------------


def exact_int(value: object, field: str) -> int:
    """Accept only an exact integer. Floats are rejected rather than rounded: rounding
    a population would be inventing precision the source does not have."""
    if isinstance(value, bool) or value is None:
        raise Rejection(f"{field} is not a number")
    if isinstance(value, float):
        raise Rejection(f"{field} is fractional ({value!r}), not an exact integer")
    if not isinstance(value, int):
        raise Rejection(f"{field} is {type(value).__name__}, not a number")
    if value < 0:
        raise Rejection(f"{field} is negative ({value}), which the source uses as a no-data sentinel")
    if value >= 2 ** 63:
        raise Rejection(f"{field} does not fit in a signed 64-bit integer ({value})")
    return value


def indicator_value(entry: dict, props: dict) -> dict:
    field = entry["field"]
    if field is None:
        raise Rejection("derived indicator")
    raw = props.get(field)
    value = exact_int(raw, field) * entry["scale"]
    if value >= 2 ** 63:
        raise Rejection(f"{field} scaled by {entry['scale']} overflows a signed 64-bit integer")
    year = props.get(entry["year_field"])
    if not isinstance(year, int) or isinstance(year, bool) or not (1900 <= year <= 2100):
        raise Rejection(f"{entry['year_field']} is missing or implausible ({year!r})")
    return {"value": value, "year": year, "source_field": field,
            "source_value": raw, "source_scale": entry["scale"]}


# --- derived area ----------------------------------------------------------


def ring_area_km2(ring: list[int]) -> float:
    """Spherical polygon area of one ring, in square kilometres.

    Longitudes are unwrapped first, so a ring that crosses the antimeridian is measured
    as the short way round rather than as most of the planet.
    """
    count = len(ring) // 2
    if count < 3:
        return 0.0
    lons = [ring[i * 2] / SCALE for i in range(count)]
    lats = [ring[i * 2 + 1] / SCALE for i in range(count)]
    unwrapped = [lons[0]]
    for index in range(1, count):
        delta = lons[index] - lons[index - 1]
        if delta > 180.0:
            delta -= 360.0
        elif delta < -180.0:
            delta += 360.0
        unwrapped.append(unwrapped[-1] + delta)
    total = 0.0
    for index in range(count):
        lon1 = math.radians(unwrapped[index])
        lon2 = math.radians(unwrapped[(index + 1) % count])
        lat1 = math.radians(lats[index])
        lat2 = math.radians(lats[(index + 1) % count])
        total += (lon2 - lon1) * (math.sin(lat1) + math.sin(lat2))
    return abs(total * R_EARTH_KM * R_EARTH_KM / 2.0)


def polygon_area_km2(polygon: list[list[int]]) -> float:
    """Outer ring minus its holes, which is how the geometry stores a polygon."""
    if not polygon:
        return 0.0
    area = ring_area_km2(polygon[0])
    for hole in polygon[1:]:
        area -= ring_area_km2(hole)
    return max(area, 0.0)


def geometry_area_km2(doc: dict) -> int:
    total = 0.0
    for polygon in doc.get("polygons", []):
        total += polygon_area_km2(polygon)
    return int(round(total))


# --- documents -------------------------------------------------------------


def build_record(country_id: str, props: dict, geometry_doc: dict | None,
                 source: dict) -> tuple[dict | None, list[dict], dict]:
    """One country's statistics document, plus what was rejected and what was found."""
    found: dict[str, dict] = {}
    rejections: list[dict] = []
    for entry in INDICATORS:
        if entry["derived"]:
            if geometry_doc is None:
                rejections.append({"indicator": entry["key"], "reason": "no geometry in the pack"})
                continue
            area = geometry_area_km2(geometry_doc)
            if area <= 0:
                rejections.append({"indicator": entry["key"],
                                   "reason": "the committed outline encloses no measurable area"})
                continue
            found[entry["key"]] = {
                "value": area, "year": None, "derived": True,
                "method": entry["method"],
                "as_of_label": "map outline",
            }
            continue
        try:
            value = indicator_value(entry, props)
        except Rejection as rejection:
            rejections.append({"indicator": entry["key"], "reason": str(rejection),
                               "source_value": props.get(entry["field"])})
            continue
        found[entry["key"]] = {
            "value": value["value"], "year": value["year"], "derived": False,
            "source_field": value["source_field"],
            "source_value": value["source_value"],
            "source_scale": value["source_scale"],
        }
    if not found:
        return None, rejections, {"has_data": False}
    doc = {
        "schema": SCHEMA,
        "kind": "statistics",
        "id": country_id,
        "source": source,
        "notice": NOTICE,
        "indicators": {entry["key"]: found[entry["key"]] for entry in INDICATORS
                       if entry["key"] in found},
        "notes": [
            "This file is generated by tools/build_statistics.py. Edit the pipeline, never this file.",
            "A value the source does not give as an exact integer is absent, not zero and not rounded.",
            "area_km2 is derived from the committed outline and is labelled as derived wherever shown.",
        ],
    }
    coverage = {"has_data": True,
                "population": "population" in found,
                "gdp_usd": "gdp_usd" in found,
                "area_km2": "area_km2" in found}
    return doc, rejections, coverage


def build_all(source_rows: dict[str, dict], crosswalk: dict, registry: dict,
              geometry: dict, source: dict) -> dict:
    entries = crosswalk["entries"]
    ids = [record["id"] for record in registry["countries"]]
    documents: dict[str, dict] = {}
    rejections: list[dict] = []
    coverage: dict[str, dict] = {}
    unmatched_registry: list[str] = []
    matched_codes: set[str] = set()

    for country_id in ids:
        code = entries.get(country_id)
        if not code:
            unmatched_registry.append(country_id)
            continue
        props = source_rows.get(code)
        if props is None:
            unmatched_registry.append(country_id)
            continue
        matched_codes.add(code)
        geometry_doc = geometry["countries"].get(country_id)
        doc, rejected, covered = build_record(country_id, props, geometry_doc, source)
        for item in rejected:
            rejections.append({"country_id": country_id, "source_code": code, **item})
        coverage[country_id] = covered
        if doc is not None:
            documents[country_id] = doc

    excluded = [{"code": code, "name": props.get("NAME", "")}
                for code, props in source_rows.items() if code not in matched_codes]
    return {
        "documents": documents,
        "rejections": rejections,
        "coverage": coverage,
        "unmatched_registry": unmatched_registry,
        "excluded_source_rows": excluded,
        "ids_with_data": sorted(documents),
    }


def pack_from_folder_documents(documents: dict[str, dict]) -> tuple[dict, dict]:
    """Assemble the runtime pack from the per-country documents that are on disk.

    Same code path for the builder and for `tools/build_country_pack.py`, so the pack
    cannot disagree with the folders it claims to be built from.
    """
    source = None
    countries = {}
    ids = sorted(documents)
    for country_id in ids:
        doc = documents[country_id]
        source = source if source is not None else doc["source"]
        entry = {}
        for key in ("population", "gdp_usd", "area_km2"):
            indicator = doc.get("indicators", {}).get(key)
            if indicator is None:
                continue
            entry[key] = {k: v for k, v in indicator.items() if k != "source_value"}
        countries[country_id] = entry
    if source is None:
        raise ValueError("no statistics documents to build a pack from")
    pack = {
        "schema": SCHEMA,
        "notice": NOTICE,
        "source": source,
        "indicators": [
            {"key": entry["key"], "label": entry["label"], "unit": entry["unit"],
             "derived": entry["derived"], "source_field": entry["field"]}
            for entry in INDICATORS
        ],
        "countries": countries,
    }
    counts = {
        "records_with_data": len(countries),
        "population": sum(1 for c in countries.values() if "population" in c),
        "gdp_usd": sum(1 for c in countries.values() if "gdp_usd" in c),
        "area_km2": sum(1 for c in countries.values() if "area_km2" in c),
    }
    return pack, counts


def pack_document(built: dict, source: dict) -> dict:
    countries = {}
    for country_id in built["ids_with_data"]:
        doc = built["documents"][country_id]
        entry = {}
        for key in ("population", "gdp_usd", "area_km2"):
            indicator = doc["indicators"].get(key)
            if indicator is None:
                continue
            entry[key] = {k: v for k, v in indicator.items() if k != "source_value"}
        countries[country_id] = entry
    return {
        "schema": SCHEMA,
        "notice": NOTICE,
        "source": source,
        "indicators": [
            {"key": entry["key"], "label": entry["label"], "unit": entry["unit"],
             "derived": entry["derived"], "source_field": entry["field"]}
            for entry in INDICATORS
        ],
        "countries": countries,
    }


def counts_block(built: dict, pack: dict) -> dict:
    coverage = built["coverage"]
    return {
        "records_with_data": len(built["ids_with_data"]),
        "population": sum(1 for c in coverage.values() if c.get("population")),
        "gdp_usd": sum(1 for c in coverage.values() if c.get("gdp_usd")),
        "area_km2": sum(1 for c in coverage.values() if c.get("area_km2")),
        "rejected_values": len(built["rejections"]),
        "unmatched_registry": len(built["unmatched_registry"]),
        "excluded_source_rows": len(built["excluded_source_rows"]),
        "crosswalk_exceptions": len(built_crosswalk_exceptions(built)),
        "pack_sha256": hashlib.sha256(canonical(pack).encode("utf-8")).hexdigest(),
    }


def built_crosswalk_exceptions(built: dict) -> dict:
    return built.get("crosswalk_exceptions", {})


# --- crosswalk checks ------------------------------------------------------


def verify_crosswalk_without_source(crosswalk: dict, registry: dict) -> list[str]:
    """The half of the crosswalk check that needs no source bytes.

    Used where the git-ignored source file is absent (a fresh clone, CI). It catches a
    crosswalk that has drifted from the registry — a missing record, a duplicate code, an
    exception without a reason or a verified name — and it is explicit that it is not the
    full check: only `verify_crosswalk` can catch a code that the source does not contain.
    """
    problems: list[str] = []
    entries = crosswalk.get("entries")
    if not isinstance(entries, dict):
        return ["the crosswalk has no 'entries' object"]
    registry_ids = {record.get("id") for record in registry.get("countries", [])}
    missing = sorted(registry_ids - set(entries))
    extra = sorted(set(entries) - registry_ids)
    if missing:
        problems.append(f"{len(missing)} registry records have no crosswalk entry: "
                        f"{', '.join(missing[:8])}")
    if extra:
        problems.append(f"{len(extra)} crosswalk entries match no registry record: "
                        f"{', '.join(extra[:8])}")
    seen: dict[str, str] = {}
    for country_id, code in sorted(entries.items()):
        if not isinstance(code, str) or not code.strip():
            problems.append(f"{country_id}: the entry is not a source code")
            continue
        if code in seen:
            problems.append(f"{code} is used twice: {seen[code]} and {country_id}")
        seen[code] = country_id
    exceptions = crosswalk.get("exceptions") or {}
    for country_id, entry in sorted(exceptions.items()):
        if country_id not in entries:
            problems.append(f"exception {country_id} has no entry")
            continue
        if not isinstance(entry, dict):
            problems.append(f"exception {country_id} is not an object")
            continue
        if not str(entry.get("reason") or "").strip():
            problems.append(f"exception {country_id} records no reason")
        if not str(entry.get("verified_name") or "").strip():
            problems.append(f"exception {country_id} has no verified source name")
        if entry.get("code") != entries[country_id]:
            problems.append(f"exception {country_id} disagrees with its entry")
    return problems


def verify_crosswalk(crosswalk: dict, source_rows: dict[str, dict], registry: dict) -> list[str]:
    """The crosswalk must be a bijection with the source, and every entry must point at
    a row whose own name agrees with the registry record. Failures are errors."""
    problems: list[str] = []
    entries = crosswalk.get("entries")
    if not isinstance(entries, dict):
        return ["the crosswalk has no 'entries' object"]
    ids = [record["id"] for record in registry["countries"]]
    missing = [country_id for country_id in ids if country_id not in entries]
    if missing:
        problems.append(f"{len(missing)} registry records are absent from the crosswalk: {missing[:5]}")
    extra = [country_id for country_id in entries if country_id not in set(ids)]
    if extra:
        problems.append(f"{len(extra)} crosswalk entries are not registry records: {extra[:5]}")
    codes = [entries[country_id] for country_id in entries]
    if len(set(codes)) != len(codes):
        problems.append("two registry records point at the same source row")
    unknown = [code for code in codes if code not in source_rows]
    if unknown:
        problems.append(f"{len(unknown)} crosswalk codes are not source rows: {unknown[:5]}")

    names = {record["id"]: record["name"] for record in registry["countries"]}

    def fold(text: str) -> str:
        import unicodedata

        decomposed = unicodedata.normalize("NFKD", text or "")
        return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).lower()

    for country_id, code in entries.items():
        props = source_rows.get(code)
        if props is None or country_id not in names:
            continue
        wanted = fold(names[country_id])
        candidates = [fold(str(props.get(key) or "")) for key in
                      ("NAME", "NAME_LONG", "NAME_CIAWF", "BRK_NAME", "FORMAL_EN", "ADMIN")]
        if not any(candidate and (candidate == wanted or wanted in candidate or candidate in wanted)
                   for candidate in candidates):
            problems.append(f"{country_id} points at {code} ({props.get('NAME')}), whose name does "
                            "not agree with the registry record")
    for country_id, exception in crosswalk.get("exceptions", {}).items():
        props = source_rows.get(exception.get("code", ""))
        if props is None:
            problems.append(f"the exception for {country_id} points at a source row that does not exist")
        elif exception.get("verified_name") != props.get("NAME"):
            problems.append(f"the exception for {country_id} records the name "
                            f"{exception.get('verified_name')!r}, the source says {props.get('NAME')!r}")
    if not crosswalk.get("source", {}).get("retrieved"):
        problems.append("the crosswalk does not record a retrieval date")
    return problems


# --- report ----------------------------------------------------------------


def build_report(built: dict, crosswalk: dict, source: dict, pack_counts: dict) -> str:
    lines: list[str] = []
    add = lines.append
    add("# Country statistics — sources, coverage and matching")
    add("")
    add("Generated by `python3 tools/build_statistics.py --report docs/STATISTICS_REPORT.md`.")
    add("Do not edit by hand: CI runs the same command and fails when this file is stale.")
    add("")
    add(f"**{NOTICE}**")
    add("")
    add("## The source")
    add("")
    add("| Field | Value |")
    add("| --- | --- |")
    for label, key in (("Dataset", "dataset"), ("Publisher / repository", "repository"),
                       ("Version", "version"), ("Commit", "commit"), ("Retrieved", "retrieved"),
                       ("Licence", "licence"), ("Source file", "file"),
                       ("File SHA-256", "sha256")):
        add(f"| {label} | `{source.get(key, '')}` |")
    add(f"| URL | {source.get('url', '')} |")
    add("")
    add("Natural Earth publishes `POP_EST` and `GDP_MD` as its own **estimates**, each with the")
    add("year it refers to in `POP_YEAR` / `GDP_YEAR`. They are copied as they are: not adjusted,")
    add("not annualised, not re-estimated. `GDP_MD` is recorded in millions of US dollars, and the")
    add("pipeline multiplies by 1,000,000 and records that it did (`source_scale`).")
    add("")
    add("## Indicators")
    add("")
    add("| Indicator | Unit | From | Derived? | Records with a value |")
    add("| --- | --- | --- | --- | --- |")
    for entry in INDICATORS:
        source_field = entry["field"] or "the committed outline"
        add(f"| {entry['label']} | {entry['unit']} | `{source_field}` | "
            f"{'yes — ' + entry.get('method', '') if entry['derived'] else 'no'} | "
            f"{pack_counts.get(entry['key'], 0)} of {pack_counts.get('records_with_data', 0)} |")
    add("")
    add("## Matching")
    add("")
    add("| Measurement | Value |")
    add("| --- | --- |")
    add(f"| Registry records | {len(built['coverage'])} |")
    add(f"| Matched to a source row | {len(built['coverage']) - len(built['unmatched_registry'])} |")
    add(f"| Registry records with no match | {len(built['unmatched_registry'])} |")
    add(f"| Source rows not used | {len(built['excluded_source_rows'])} |")
    add(f"| Records with at least one value | {len(built['ids_with_data'])} |")
    add(f"| Values rejected | {len(built['rejections'])} |")
    add("")
    add("The join is by code, through the committed crosswalk "
        "`data/world/statistics_crosswalk.json`. Names are never the key; the crosswalk "
        "records the source row's own name so a reviewer can check each entry.")
    add("")
    exceptions = crosswalk.get("exceptions", {})
    add(f"### The {len(exceptions)} code differences, all verified against the source file")
    add("")
    add("| Registry ID | Source code | Source name | Why |")
    add("| --- | --- | --- | --- |")
    for country_id in sorted(exceptions):
        exception = exceptions[country_id]
        add(f"| `{country_id}` | `{exception['code']}` | {exception['verified_name']} | "
            f"{exception.get('reason', '')} |")
    add("")
    if built["unmatched_registry"]:
        add("### Registry records with no source row (shown as not available)")
        add("")
        for country_id in built["unmatched_registry"]:
            add(f"- `{country_id}`")
        add("")
    else:
        add("No registry record is unmatched: every one of the "
            f"{len(built['coverage'])} records joins to exactly one source row.")
        add("")
    if built["excluded_source_rows"]:
        add("### Source rows deliberately not used")
        add("")
        add("| Code | Name |")
        add("| --- | --- |")
        for row in built["excluded_source_rows"]:
            add(f"| `{row['code']}` | {row['name']} |")
        add("")
    else:
        add("No source row was excluded. The pinned file contains one row per map unit: it has "
            "no \"World\" row, no income-group row and no regional total, so there was no "
            "aggregate to filter out. Rows that could not be matched would be listed here.")
        add("")
    add("## Values rejected, with the reason")
    add("")
    if not built["rejections"]:
        add("None.")
    else:
        add("| Record | Indicator | Source value | Reason |")
        add("| --- | --- | --- | --- |")
        for item in built["rejections"]:
            raw = item.get("source_value")
            add(f"| `{item['country_id']}` | {item['indicator']} | "
                f"{'—' if raw is None else f'`{raw}`'} | {item['reason']} |")
    add("")
    add("A rejected value is **not** rounded, copied or borrowed from a parent unit: the indicator "
        "is simply absent for that record, and the game shows \"Not available\".")
    add("")
    add("## Coverage by indicator")
    add("")
    add("| Indicator | Records | Missing |")
    add("| --- | --- | --- |")
    for entry in INDICATORS:
        with_value = pack_counts.get(entry["key"], 0)
        add(f"| {entry['label']} | {with_value} | {pack_counts.get('records_with_data', 0) - with_value} |")
    add("")
    add("Real zeros are kept and are not missing values: two uninhabited territories have a "
        "population of 0 in the source, and their files say `0`.")
    add("")
    add("## Reproducing this file")
    add("")
    add("```bash")
    add("python3 tools/fetch_world_atlas.py                        # pinned source bytes")
    add("python3 tools/build_statistics.py --report docs/STATISTICS_REPORT.md")
    add("python3 tools/build_country_pack.py")
    add("```")
    add("")
    return "\n".join(lines)


# --- writing ---------------------------------------------------------------


def write_folders(built: dict, folders_dir: pathlib.Path, dry_run: bool = False) -> list[str]:
    written = []
    for country_id in built["ids_with_data"]:
        path = folders_dir / country_id / "statistics.json"
        text = canonical(built["documents"][country_id])
        written.append(str(path))
        if not dry_run:
            path.write_text(text, encoding="utf-8")
    # A record with no data must not keep a stale file.
    for folder in sorted(folders_dir.iterdir()) if folders_dir.is_dir() else []:
        if not folder.is_dir() or folder.name in built["documents"]:
            continue
        stale = folder / "statistics.json"
        if stale.exists():
            stale.unlink()
    return written


def read_existing(folders_dir: pathlib.Path) -> dict[str, str]:
    found = {}
    if not folders_dir.is_dir():
        return found
    for folder in sorted(folders_dir.iterdir()):
        path = folder / "statistics.json"
        if path.exists():
            found[folder.name] = path.read_text(encoding="utf-8")
    return found


# --- self-test -------------------------------------------------------------


def self_test() -> int:
    """The rules the data has to obey, checked against fixtures rather than hopes."""
    failures = 0

    def expect(condition: bool, message: str) -> None:
        nonlocal failures
        if not condition:
            print(f"FAIL {message}")
            failures += 1

    entry = INDICATORS[0]
    for value, why in ((10192317.3, "fractional"), ("163046161", "text"), (None, "missing"),
                       (-99, "negative"), (True, "boolean"), (2 ** 70, "overflow")):
        try:
            exact_int(value, "POP_EST")
            expect(False, f"{why} value should be rejected")
        except Rejection:
            expect(True, f"{why} value rejected")
    expect(exact_int(0, "POP_EST") == 0, "zero is a real value, not a missing one")
    expect(exact_int(163046161, "POP_EST") == 163046161, "an exact integer passes")

    good = {"POP_EST": 163046161, "POP_YEAR": 2019, "GDP_MD": 302571, "GDP_YEAR": 2019}
    value = indicator_value(INDICATORS[1], good)
    expect(value["value"] == 302571000000, "GDP is scaled from millions by exactly 1,000,000")
    expect(value["source_value"] == 302571, "the unscaled source value is kept for audit")
    for broken, why in (({**good, "GDP_YEAR": None}, "missing year"),
                        ({**good, "GDP_YEAR": 1801}, "implausible year")):
        try:
            indicator_value(INDICATORS[1], broken)
            expect(False, f"{why} should be rejected")
        except Rejection:
            expect(True, f"{why} rejected")

    doc = {"polygons": [[[0, 0, 200, 0, 200, 200, 0, 200]]]}
    area = geometry_area_km2(doc)
    expect(11500 <= area <= 13300,
           f"a one-degree square is about 12,400 km2 at the equator; got {area}")

    empty, rejections, coverage = build_record("XXX", {"POP_EST": None}, None, {})
    expect(empty is None, "a record with no usable value produces no file")
    expect(not coverage["has_data"], "and is reported as having no data")
    expect(len(rejections) == 3, "each missing indicator is reported separately")

    print(f"self-test: {'ok' if failures == 0 else str(failures) + ' failures'}")
    return 0 if failures == 0 else 1


# --- main ------------------------------------------------------------------


def build(source_dir: pathlib.Path) -> dict:
    crosswalk = read_json(CROSSWALK)
    registry = read_json(WORLD / "countries.json")
    geometry = read_json(WORLD / "geometry.json")
    rows, sha256 = load_source(source_dir / "ne_50m_admin_0_countries.geojson")
    problems = verify_crosswalk(crosswalk, rows, registry)
    if problems:
        raise SystemExit("the crosswalk does not match the source:\n  " + "\n  ".join(problems))
    source = source_block(crosswalk, sha256)
    built = build_all(rows, crosswalk, registry, geometry, source)
    built["crosswalk_exceptions"] = crosswalk.get("exceptions", {})
    pack = pack_document(built, source)
    counts = counts_block(built, pack)
    return {"built": built, "pack": pack, "counts": counts, "crosswalk": crosswalk, "source": source}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", default=str(DEFAULT_SOURCE.parent))
    parser.add_argument("--folders", default=str(FOLDERS))
    parser.add_argument("--report", help="write the Markdown report to this path")
    parser.add_argument("--check-report", help="fail when the report at this path is stale")
    parser.add_argument("--check", action="store_true", help="fail when the output is stale")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv[1:])

    if args.self_test:
        return self_test()

    result = build(pathlib.Path(args.source_dir))
    built, pack, counts = result["built"], result["pack"], result["counts"]
    pack_text = canonical(pack)

    if args.check:
        stale: list[str] = []
        existing = read_existing(pathlib.Path(args.folders))
        for country_id in built["ids_with_data"]:
            if existing.get(country_id) != canonical(built["documents"][country_id]):
                stale.append(f"{country_id}/statistics.json")
        for country_id in existing:
            if country_id not in built["documents"]:
                stale.append(f"{country_id}/statistics.json (should not exist)")
        if not PACK.exists() or PACK.read_text(encoding="utf-8") != pack_text:
            stale.append("data/world/statistics.json")
        if stale:
            print(f"statistics are stale ({len(stale)} files); run tools/build_statistics.py")
            for name in stale[:10]:
                print(f"  {name}")
            return 1
        print(f"statistics are up to date: {counts['records_with_data']} records, "
              f"population {counts['population']}, gdp {counts['gdp_usd']}, area {counts['area_km2']}, "
              f"rejected {counts['rejected_values']}")
        return 0

    write_folders(built, pathlib.Path(args.folders))
    PACK.write_text(pack_text, encoding="utf-8")
    print(f"wrote {len(built['ids_with_data'])} statistics.json files and data/world/statistics.json")
    print(f"  population {counts['population']} · gdp {counts['gdp_usd']} · area {counts['area_km2']} "
          f"· rejected {counts['rejected_values']}")
    for item in built["rejections"]:
        print(f"  rejected {item['country_id']} {item['indicator']}: {item['reason']}")

    document = build_report(built, result["crosswalk"], result["source"], counts)
    if args.report:
        path = pathlib.Path(args.report)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(document, encoding="utf-8")
        print(f"wrote {path}")
    if args.check_report:
        path = pathlib.Path(args.check_report)
        if not path.exists() or path.read_text(encoding="utf-8") != document:
            print(f"{path} is stale; run tools/build_statistics.py --report {path}")
            return 1
        print(f"{path} is up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
