#!/usr/bin/env python3
"""Generate `docs/DATA_COMPLETENESS.md`: what each record has, and what it does not.

The report is built from the per-country folders, so it can only ever describe
data that actually exists. There is no score and no percentage of "quality":
those imply a precision nobody measured. It answers one plain question per
record — which sections are present, and which identity fields are empty.

Usage:

    python3 tools/report_data_completeness.py            # rewrite the document
    python3 tools/report_data_completeness.py --check    # fail if it is stale
"""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import country_folders as folders  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDERS_DIR = os.path.join(ROOT, "data/world/countries")
DOC = os.path.join(ROOT, "docs/DATA_COMPLETENESS.md")

# Fields a player can actually see in the dossier. A missing one is a gap worth
# naming; `note` is deliberately excluded because the source only fills it for a
# handful of disputed or dependent units.
TRACKED_FIELDS = ("name", "name_long", "iso_a2", "iso_a3", "region", "subregion",
                  "type", "sovereignty", "label")

FIELD_LABELS = {
    "name": "short name", "name_long": "long name", "iso_a2": "ISO alpha-2",
    "iso_a3": "ISO alpha-3", "region": "region", "subregion": "subregion",
    "type": "source type", "sovereignty": "sovereignty field", "label": "label anchor",
}


def collect() -> list[dict]:
    tree = folders.read_folders(FOLDERS_DIR)
    rows = []
    for country_id in tree["ids"]:
        identity = tree["identity"][country_id]
        geometry = tree["geometry"][country_id]
        capital = tree["capital"][country_id]
        missing = []
        for field in TRACKED_FIELDS:
            source_value = geometry.get(field) if field == "label" else identity.get(field)
            if source_value in (None, "", []):
                missing.append(FIELD_LABELS[field])
        if not capital:
            missing.append("capital")
        currency = tree["currency"].get(country_id)
        if not currency:
            missing.append("currency")
        statistics = tree["statistics"].get(country_id) or {}
        figures = statistics.get("indicators") or {}
        for key, label in (("population", "population"), ("gdp_usd", "GDP"), ("area_km2", "area")):
            if key not in figures:
                missing.append(label)
        rows.append({
            "id": country_id,
            "name": identity["name"],
            "identity": True,
            "geometry": bool(geometry.get("polygons")),
            "capital": bool(capital),
            "sources": True,
            "population": "population" in figures,
            "gdp_usd": "gdp_usd" in figures,
            "area_km2": "area_km2" in figures,
            "statistics": bool(figures),
            "currency": bool(currency),
            "polygons": len(geometry.get("polygons") or []),
            "vertices": int(geometry.get("vertices", 0)),
            "missing": missing,
        })
    rows.sort(key=lambda row: row["name"])
    return rows


def document(rows: list[dict]) -> str:
    total = len(rows)
    with_capital = sum(1 for row in rows if row["capital"])
    with_geometry = sum(1 for row in rows if row["geometry"])
    field_gaps: dict[str, int] = {}
    for row in rows:
        for item in row["missing"]:
            field_gaps[item] = field_gaps.get(item, 0) + 1

    lines: list[str] = []
    add = lines.append
    add("# Data completeness")
    add("")
    add("**Generated from `data/world/countries/` by "
        "`tools/report_data_completeness.py`.** Do not edit by hand: CI regenerates it "
        "and fails if the committed copy differs.")
    add("")
    add("## How to read this page")
    add("")
    add("Every record has its own folder (see [COUNTRY_FOLDER_GUIDE.md]"
        "(COUNTRY_FOLDER_GUIDE.md)). A record's folder always holds its identity, its "
        "geometry and its source block. A capital is only present when the dataset has "
        "one — the file is absent rather than filled with a placeholder. Nothing else "
        "is collected yet, so nothing else appears here.")
    add("")
    add("There is deliberately **no completeness score**. A percentage would suggest "
        "that the sections are comparable and that the missing parts are equal, and "
        "neither is true.")
    add("")
    add("## Totals")
    add("")
    add("| Section | Records with it | Records without it |")
    add("| --- | --- | --- |")
    add(f"| Identity (`identity.json`) | {total} | 0 |")
    add(f"| Geometry (`geometry.json`) | {with_geometry} | {total - with_geometry} |")
    add(f"| Capital (`capital.json`) | {with_capital} | {total - with_capital} |")
    add(f"| Sources (`sources.json`) | {total} | 0 |")
    add(f"| Statistics (`statistics.json`) | {sum(1 for row in rows if row['statistics'])} | "
        f"{total - sum(1 for row in rows if row['statistics'])} |")
    add(f"| — Population | {sum(1 for row in rows if row['population'])} | "
        f"{total - sum(1 for row in rows if row['population'])} |")
    add(f"| — GDP (current US$ as the source states it) | {sum(1 for row in rows if row['gdp_usd'])} | "
        f"{total - sum(1 for row in rows if row['gdp_usd'])} |")
    add(f"| — Area (derived from the outline) | {sum(1 for row in rows if row['area_km2'])} | "
        f"{total - sum(1 for row in rows if row['area_km2'])} |")
    add(f"| Currency (`currency.json`) | {sum(1 for row in rows if row['currency'])} | "
        f"{total - sum(1 for row in rows if row['currency'])} |")
    add("")
    add("## Empty fields")
    add("")
    add("A field is listed here when the dataset itself has no value for it. The game "
        "shows these as \"Not recorded in source\" rather than filling them in.")
    add("")
    add("| Field | Records where it is empty |")
    add("| --- | --- |")
    for label in sorted(field_gaps):
        add(f"| {label} | {field_gaps[label]} |")
    add("")
    add("## Future sections")
    add("")
    add("`statistics.json` exists because a real, licensed source file provides population and "
        "GDP for these records, and the outline provides the area. Its values are Natural Earth's "
        "own estimates with the year the source records them for; they are baseline reference data "
        "for the 2026 scenario start and are **not live**. See "
        "[STATISTICS_REPORT.md](STATISTICS_REPORT.md) for the source, the matching and every "
        "rejected value.")
    add("")
    add("`currency.json` exists because Unicode CLDR names a current currency for the "
        "record's own ISO alpha-2 region and gives it an English name. Where the source names "
        "none, or leaves more than one open, the file is absent, the reason is recorded in "
        "`data/world/currency_crosswalk.json`, and the dossier says \"Not available\". See "
        "[CURRENCY_REPORT.md](CURRENCY_REPORT.md) for the source, the matching and every "
        "unmatched record.")
    add("")
    add("Economy, politics, military and society files do **not** exist for any record, because no "
        "sourced data for them has been collected. When a system ships real data, its file appears "
        "in these folders with its own schema version and source block, and a column appears in the "
        "table below — not before.")
    add("")
    add("## Every record")
    add("")
    add("| Record | ID | Polygons | Points | Capital | Population | GDP | Area | Empty fields |")
    add("| --- | --- | ---: | ---: | --- | :---: | :---: | :---: | --- |")
    for row in rows:
        missing = ", ".join(row["missing"]) if row["missing"] else "—"
        marker = lambda present: "yes" if present else "**no**"
        add(f"| {row['name']} | `{row['id']}` | {row['polygons']} | {row['vertices']} | "
            f"{'yes' if row['capital'] else 'no'} | {marker(row['population'])} | "
            f"{marker(row['gdp_usd'])} | {marker(row['area_km2'])} | {missing} |")
    add("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    rows = collect()
    text = document(rows)
    if args.check:
        try:
            with open(DOC, encoding="utf-8") as handle:
                committed = handle.read()
        except OSError:
            print(f"{DOC} is missing; run python3 tools/report_data_completeness.py")
            return 1
        if committed != text:
            print("DATA_COMPLETENESS.md is stale; run "
                  "python3 tools/report_data_completeness.py")
            return 1
        print(f"DATA_COMPLETENESS.md is up to date ({len(rows)} records)")
        return 0
    with open(DOC, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print(f"wrote {DOC} ({len(rows)} records)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
