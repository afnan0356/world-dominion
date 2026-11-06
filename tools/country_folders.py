#!/usr/bin/env python3
"""Read and write per-country data folders.

The atlas is organised so that **every record has its own folder**, named by its
stable id, holding plain files a person can read and diff:

    data/world/countries/<STABLE_ID>/
        identity.json   names, aliases, codes, region, source type, status note
        geometry.json   that record's quantised polygons, bbox and label anchor
        capital.json    only when the source has one (never an empty placeholder)
        sources.json    dataset, commit, licence, attribution, processing notes
        README.md       generated, plain English, one short page

The game does not read these folders at runtime. It reads the compact pack
(`countries.json`, `geometry.json`, `manifest.json` next to them), which is
**generated from the folders** by this module. That keeps phone load time the
same as before, keeps the folder tree as the human source of truth, and lets CI
prove the pack matches the folders by rebuilding it and comparing hashes.

Everything here is deterministic: fixed key order, `indent=2`, sorted folder
iteration, no timestamps that change on every run.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil

FOLDER_SCHEMA = 1
PACK_SCHEMA = 1

REQUIRED_FILES = ("identity.json", "geometry.json", "sources.json", "README.md")
OPTIONAL_FILES = ("capital.json", "statistics.json")

# Names that Windows refuses (or silently redirects) as file or folder names,
# even with an extension added. Uppercase because our ids are uppercase.
RESERVED_NAMES = {
    "CON", "PRN", "AUX", "NUL",
    "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
    "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
}

# Stable ids are ASCII letters and digits, optionally with a "-N" disambiguation
# suffix. No spaces, no dots, no case tricks: a folder name must survive Windows,
# macOS, Linux and Android unchanged.
ID_PATTERN = re.compile(r"^[A-Z0-9][A-Z0-9-]{0,31}$")


def is_safe_id(country_id: str) -> bool:
    """True when `country_id` can be used verbatim as a folder name everywhere."""
    if not isinstance(country_id, str) or not country_id:
        return False
    if not ID_PATTERN.match(country_id):
        return False
    if country_id.upper() in RESERVED_NAMES:
        return False
    if country_id.endswith(".") or country_id.endswith(" ") or "--" in country_id:
        return False
    return True


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: str) -> str:
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def dump_json(value) -> str:
    """The one JSON style used by every generated file in this tree."""
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def folder_path(folders_dir: str, country_id: str) -> str:
    return os.path.join(folders_dir, country_id)


# --- Writing ---------------------------------------------------------------
# The pipeline calls `write_folders` once; nothing else writes these files. Hand
# edits are detected by CI, which rebuilds the pack from the folders and
# regenerates every README, then compares bytes.


def write_folders(folders_dir: str, entries: list[dict], source: dict,
                  generated: str) -> dict:
    """Write one folder per country, replacing the tree that is there.

    `entries` are dicts with the keys `record`, `geometry`, `adm0`, `formal_name`
    and `repairs` (the per-record list of repair notes).
    """
    # `statistics.json` is written by tools/build_statistics.py, not by this pipeline.
    # Rebuilding the atlas must not silently delete it: keep the bytes, rewrite the
    # files this pipeline owns, and put the statistics back. If the source changed,
    # `tools/build_statistics.py --check` fails and asks for a rebuild.
    preserved: dict[str, bytes] = {}
    if os.path.isdir(folders_dir):
        for name in sorted(os.listdir(folders_dir)):
            path = os.path.join(folders_dir, name)
            statistic_file = os.path.join(path, "statistics.json")
            if os.path.isdir(path) and os.path.exists(statistic_file):
                with open(statistic_file, "rb") as handle:
                    preserved[name] = handle.read()
        # Remove *.json / README.md only, so a deliberate extra note is not lost
        # by accident -- but the validator still flags unexpected files.
        for name in sorted(os.listdir(folders_dir)):
            path = os.path.join(folders_dir, name)
            if os.path.isdir(path):
                shutil.rmtree(path)
    os.makedirs(folders_dir, exist_ok=True)

    written = 0
    for entry in sorted(entries, key=lambda item: item["record"]["id"]):
        record = entry["record"]
        country_id = record["id"]
        if not is_safe_id(country_id):
            raise ValueError(f"country id {country_id!r} is not a portable folder name")
        path = folder_path(folders_dir, country_id)
        os.makedirs(path, exist_ok=True)

        identity = _identity_document(entry)
        geometry = _geometry_document(entry)
        capital = _capital_document(entry) if (record.get("capital")
                                               and record.get("capital_point")) else None
        sources = _sources_document(entry, source, generated)
        _write_text(os.path.join(path, "identity.json"), dump_json(identity))
        _write_text(os.path.join(path, "geometry.json"), dump_json(geometry))
        if capital is not None:
            _write_text(os.path.join(path, "capital.json"), dump_json(capital))
        _write_text(os.path.join(path, "sources.json"), dump_json(sources))
        kept = preserved.get(country_id)
        statistics = None
        if kept is not None:
            with open(os.path.join(path, "statistics.json"), "wb") as handle:
                handle.write(kept)
            statistics = json.loads(kept.decode("utf-8"))
        _write_text(os.path.join(path, "README.md"),
                    readme_document(identity, geometry, capital, sources, statistics))
        written += 1
    return {"folders": written}


def _write_text(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def _identity_document(entry: dict) -> dict:
    record = entry["record"]
    return {
        "schema": FOLDER_SCHEMA,
        "kind": "identity",
        "id": record["id"],
        "name": record["name"],
        "name_long": record["name_long"],
        "formal_name": entry.get("formal_name"),
        "adm0_code": entry.get("adm0"),
        "iso_a2": record["iso_a2"],
        "iso_a3": record["iso_a3"],
        "region": record["region"],
        "subregion": record["subregion"],
        "type": record["type"],
        "sovereignty": record["sovereignty"],
        "note": record["note"],
        "filter_region": record["filter_region"],
    }


def _geometry_document(entry: dict) -> dict:
    record = entry["record"]
    geometry = entry["geometry"]
    return {
        "schema": FOLDER_SCHEMA,
        "kind": "geometry",
        "id": record["id"],
        "scale": entry["scale"],
        "bbox": record["bbox"],
        "label": record["label"],
        "label_rank": record["label_rank"],
        "tiny": record["tiny"],
        "polygons": geometry["polygons"],
        "rings": sum(len(polygon) for polygon in geometry["polygons"]),
        "vertices": sum(len(ring) // 2 for polygon in geometry["polygons"] for ring in polygon),
        "dropped_rings": int(entry.get("dropped_rings", 0)),
        "repaired_rings": int(entry.get("repaired_rings", 0)),
        "repaired_vertices": int(entry.get("repaired_vertices", 0)),
        "repairs": entry.get("repairs", []),
    }


def _capital_document(entry: dict) -> dict:
    record = entry["record"]
    return {
        "schema": FOLDER_SCHEMA,
        "kind": "capital",
        "id": record["id"],
        "name": record["capital"],
        "point": record["capital_point"],
        "source_field": "ne_50m_populated_places_simple.feature where adm0cap = 1",
    }


def _sources_document(entry: dict, source: dict, generated: str) -> dict:
    record = entry["record"]
    return {
        "schema": FOLDER_SCHEMA,
        "kind": "sources",
        "id": record["id"],
        "dataset": source["dataset"],
        "repository": source["repository"],
        "commit": source["commit"],
        "version": source["version"],
        "licence": source["licence"],
        "attribution": "Made with Natural Earth. Free vector and raster map data.",
        "url": source["url"],
        "capital_url": source.get("capital_url"),
        "retrieved": source["retrieved"],
        # Position of this record's feature in the pinned source file. The pack keeps
        # that order so a rebuild is byte-identical; the folders themselves are read
        # in id order, which is what a person expects to see.
        "source_index": int(entry.get("source_index", 0)),
        "source_record": {
            "admin": record["name_long"],
            "adm0_code": entry.get("adm0"),
            "iso_a3": record["iso_a3"],
            "iso_a2": record["iso_a2"],
        },
        "processing": [
            "quantised to 1/200 degree lon/lat, consecutive duplicate vertices dropped",
            "rings with fewer than 3 points dropped; holes below 0.0025 deg2 dropped",
            "self-intersections repaired by removing the spike vertex (see geometry.json)",
            "capital name and point joined from the populated-places file by adm0_a3",
        ],
        "repairs": {
            "count": len(entry.get("repairs", [])),
            "recorded_in": "geometry.json",
        },
        "folder_generated": generated,
        "notes": [
            "This file is generated. Edit the pipeline, never this file.",
            "Values are exactly what the pinned source commit contains; missing source "
            "values stay null and are listed in README.md.",
        ],
    }


def readme_document(identity: dict, geometry: dict, capital: dict | None,
                    sources: dict, statistics: dict | None = None) -> str:
    """One short, plain-English page per record, built from that record's documents.

    Taking the documents (not the build's internal state) means the validator can
    regenerate this page from what is on disk and compare it byte for byte.
    """
    name = identity["name"]
    missing = []
    if not capital:
        missing.append("capital city (the source has no capital for this unit)")
    if not identity.get("iso_a2"):
        missing.append("ISO alpha-2 code (the source value is not a plain two-letter code)")
    if not identity.get("iso_a3"):
        missing.append("ISO alpha-3 code (the source has none for this unit)")
    if not identity.get("note"):
        missing.append("status note (the source records no note for this unit)")
    polygons = len(geometry["polygons"])
    vertices = int(geometry.get("vertices", 0))
    repairs = geometry.get("repairs", [])

    lines: list[str] = []
    add = lines.append
    add(f"# {name} — `{identity['id']}`")
    add("")
    add(f"This folder holds everything WORLD DOMINION knows about **{name}** "
        f"({identity['name_long']}). The folder name is the stable id the game uses "
        "everywhere, including in save files.")
    add("")
    add("## What is in here")
    add("")
    add("| File | What it holds |")
    add("| --- | --- |")
    add("| `identity.json` | Names, codes, region, the source's own `type` and status note |")
    add(f"| `geometry.json` | {polygons} polygon(s), {vertices} points, outline bbox and label anchor |")
    if capital:
        add("| `capital.json` | Capital city name and its coordinates |")
    if statistics:
        add("| `statistics.json` | Sourced population and GDP, plus the area derived from the outline |")
    add("| `sources.json` | Where the data came from, which commit, licence, how it was processed |")
    add("| `README.md` | This page |")
    add("")
    add("## What the source says about this unit")
    add("")
    add(f"* Region: {identity.get('region') or 'not recorded'}"
        + (f" — {identity['subregion']}" if identity.get("subregion") else ""))
    add(f"* Source type: {identity.get('type') or 'not recorded'}")
    add(f"* Sovereignty field: {identity.get('sovereignty') or 'not recorded'}")
    add(f"* Status note: {identity.get('note') or 'none recorded'}")
    capital_name = (capital or {}).get("name")
    add(f"* Capital: {capital_name or 'not recorded in the source'}")
    add("")
    add("## What is missing, and why")
    add("")
    if missing:
        for item in missing:
            add(f"* {item}")
    else:
        add("* Nothing that this milestone collects is missing for this record.")
    add("* Economy, government, military and society figures: **not collected at all** yet. "
        "They are planned systems, and this project does not invent numbers.")
    add("* The two sourced figures below are Natural Earth's own estimates, each with the year "
        "the source records them for; they are not live and not updated by the game.")
    add("")
    add("## Key figures (baseline reference data, not live)")
    add("")
    indicators = (statistics or {}).get("indicators", {})
    if not indicators:
        add("* **Not available.** The source records no usable figure for this unit, and this "
            "project does not estimate, borrow from a parent unit or round a value to fill the gap.")
    else:
        add("| Figure | Value | As of |")
        add("| --- | --- | --- |")
        population = indicators.get("population")
        gdp = indicators.get("gdp_usd")
        area = indicators.get("area_km2")
        population_cell = "Not available"
        population_year = "—"
        if population:
            population_cell = "{:,} people".format(population["value"])
            population_year = str(population["year"])
        gdp_cell = "Not available"
        gdp_year = "—"
        if gdp:
            gdp_cell = "{:,} US dollars".format(gdp["value"])
            gdp_year = str(gdp["year"])
        area_cell = "Not available"
        area_asof = "—"
        if area:
            area_cell = "{:,} km² (derived, approximate)".format(area["value"])
            area_asof = "map outline"
        add("| Population | " + population_cell + " | " + population_year + " |")
        add("| GDP | " + gdp_cell + " | " + gdp_year + " |")
        add("| Area | " + area_cell + " | " + area_asof + " |")
        add("")
        add("Population and GDP come from the source file named below. The area is **derived** from "
            "this record's simplified outline, so it is approximate and is not an official land-area "
            "figure; it is labelled as derived wherever the game shows it.")
    add("")
    add("## Where it came from")
    add("")
    add(f"* Dataset: {sources['dataset']}")
    add(f"* Repository: `{sources['repository']}` at commit `{sources['commit']}`")
    add(f"* Licence: {sources['licence']}")
    add(f"* Retrieved: {sources['retrieved']}")
    add("")
    if repairs:
        add("## Repairs made while building this record")
        add("")
        for repair in repairs:
            add(f"* Ring {repair['ring']}: removed {repair['removed_vertices']} spike "
                f"vertex/vertices to remove a self-intersection "
                f"(area {repair['area_before']} → {repair['area_after']} deg²).")
        add("")
    add("## How this folder was made")
    add("")
    add("1. `tools/fetch_world_atlas.py` downloads the pinned source files (not committed).")
    add("2. `tools/build_world_atlas.py` writes this folder from the source, then builds the "
        "runtime pack from all the folders.")
    add("3. `tools/validate_country_folders.py` checks the tree; CI fails on any drift.")
    add("")
    add("The file is generated. Do not hand-edit it: CI rebuilds the tree and compares bytes.")
    add("")
    return "\n".join(lines)


# --- Reading ---------------------------------------------------------------


def read_folders(folders_dir: str) -> dict:
    """Read the folder tree back.

    Returns `{"ids": [...], "identity": {id: doc}, "geometry": {...},
    "capital": {...}, "sources": {...}, "files": {id: [names]}}`.
    Raises ValueError with a precise message when a required file is unreadable.
    """
    if not os.path.isdir(folders_dir):
        raise ValueError(f"no country folder tree at {folders_dir}")
    result = {"ids": [], "identity": {}, "geometry": {}, "capital": {},
              "statistics": {}, "sources": {}, "files": {}}
    for name in sorted(os.listdir(folders_dir)):
        path = os.path.join(folders_dir, name)
        if not os.path.isdir(path):
            continue
        names = sorted(os.listdir(path))
        result["files"][name] = names
        for required in ("identity.json", "geometry.json", "sources.json"):
            if required not in names:
                raise ValueError(f"{name}/ is missing {required}")
            with open(os.path.join(path, required), encoding="utf-8") as handle:
                doc = json.load(handle)
            result[required.split(".")[0]][name] = doc
        capital_path = os.path.join(path, "capital.json")
        result["capital"][name] = None
        if os.path.exists(capital_path):
            with open(capital_path, encoding="utf-8") as handle:
                result["capital"][name] = json.load(handle)
        statistics_path = os.path.join(path, "statistics.json")
        result["statistics"][name] = None
        if os.path.exists(statistics_path):
            with open(statistics_path, encoding="utf-8") as handle:
                result["statistics"][name] = json.load(handle)
        result["ids"].append(name)
    return result


def fold(text: str) -> str:
    """The search-key folding the pipeline uses (kept byte-compatible)."""
    import unicodedata

    decomposed = unicodedata.normalize("NFKD", text)
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).lower()
