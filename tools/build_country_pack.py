#!/usr/bin/env python3
"""Build the runtime atlas pack from the per-country folders.

The pack is the three compact files the game loads (`countries.json`,
`geometry.json`, `manifest.json`). It is **generated from** `data/world/countries/`
and never edited by hand, so the human-readable tree and the thing a phone loads
cannot drift apart.

Usage:

    python3 tools/build_country_pack.py                     # rewrite the pack
    python3 tools/build_country_pack.py --check             # fail if it is stale
    python3 tools/build_country_pack.py --folders /tmp/x --out /tmp/y --check

`--check` rebuilds the pack in memory from the folders and compares it with the
committed bytes, printing both hashes. CI runs it on every push: a hand-edited
folder, a stale pack or a tampered file all fail the build.
"""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import country_folders as folders  # noqa: E402
import build_statistics  # noqa: E402  (same folder)

SCALE = 200
MIN_RING_AREA_DEG2 = 0.0025

FILTER_REGIONS = ["Africa", "Asia", "Europe", "North America", "Oceania", "South America"]

PROCESSING_STEPS = [
    "read GeoJSON with Python's json module",
    f"projected nothing: coordinates are stored as quantised lon/lat in 1/{SCALE} degrees",
    "dropped consecutive duplicate vertices and rings with fewer than 3 points",
    "dropped holes smaller than the minimum ring area",
    "capital names joined from ne_50m_populated_places_simple by adm0_a3 where adm0cap=1",
    "ISO alpha-2/alpha-3 accepted only when the source value is a plain code; else stored as null",
    "search keys folded to lowercase ASCII in the pipeline",
    "one folder per record written, then this pack built from those folders",
]

KNOWN_LIMITATIONS = [
    "1:50m generalisation: coastlines and borders are simplified for world-scale display.",
    "Quantised to 0.005 degrees; sub-pixel detail below that resolution is intentionally lost.",
    "Natural Earth's map unit for Palestine is TYPE 'Indeterminate' with SOVEREIGNT 'Israel'; "
    "both source fields are preserved verbatim and no stance is taken.",
    "Disputed and dependent territories keep Natural Earth's TYPE/SOVEREIGNT/NOTE values; "
    "no sovereignty is inferred by this project.",
    "Population and GDP are Natural Earth's own estimates, copied into statistics.json with the "
    "source's POP_YEAR / GDP_YEAR; they are baseline reference data, not live figures.",
    "Area in statistics.json is derived from the simplified 1:50m outline, so it is approximate "
    "and is labelled as derived wherever it is shown; it is not an official land-area figure.",
]


def _record_from(tree: dict, country_id: str) -> dict:
    """One pack record, in the exact key order the game has always used."""
    identity = tree["identity"][country_id]
    geometry = tree["geometry"][country_id]
    capital = tree["capital"][country_id]
    name = identity["name"]
    name_long = identity["name_long"]
    search = folders.fold(" ".join(filter(None, [
        name, name_long, identity.get("iso_a2"), identity.get("iso_a3"),
        identity.get("adm0_code"), identity.get("formal_name"),
    ])))
    return {
        "id": identity["id"],
        "name": name,
        "name_long": name_long,
        "iso_a2": identity.get("iso_a2"),
        "iso_a3": identity.get("iso_a3"),
        # Milestone 06: whether the code is the record's own officially assigned one,
        # and which picker group the record belongs to. Both come from committed
        # crosswalks derived from the same source, and both are additive fields.
        "code_status": identity.get("code_status") or "none",
        "picker_group": identity.get("picker_group") or "",
        "region": identity.get("region"),
        "subregion": identity.get("subregion"),
        "capital": (capital or {}).get("name"),
        "capital_point": (capital or {}).get("point"),
        "type": identity.get("type"),
        "sovereignty": identity.get("sovereignty"),
        "note": identity.get("note"),
        "label": geometry.get("label"),
        "label_rank": geometry.get("label_rank", 10),
        "tiny": bool(geometry.get("tiny", False)),
        "bbox": geometry["bbox"],
        "filter_region": bool(identity.get("filter_region")),
        "search": search,
    }


def build_documents(folders_dir: str, generated: str | None = None) -> dict:
    """Build every pack document from the folders. Pure function of the tree."""
    tree = folders.read_folders(folders_dir)
    ids = tree["ids"]
    if not ids:
        raise ValueError("the folder tree is empty")

    retrieved = {tree["sources"][i].get("retrieved") for i in ids}
    if len(retrieved) != 1:
        raise ValueError(f"the folders disagree about the retrieval date: {sorted(retrieved)}")
    stamp_dates = {tree["sources"][i].get("folder_generated") for i in ids}
    if len(stamp_dates) != 1:
        raise ValueError("the folders were built on different dates")
    build_date = generated or sorted(stamp_dates)[0]

    records = [_record_from(tree, country_id) for country_id in ids]
    records.sort(key=lambda item: item["name"])

    ordered = sorted(ids, key=lambda i: (tree["sources"][i].get("source_index", 0), i))
    geometry_out: dict[str, dict] = {}
    for country_id in ordered:
        doc = tree["geometry"][country_id]
        geometry_out[country_id] = {"bbox": doc["bbox"], "polygons": doc["polygons"]}

    counts = {
        "countries": len(records),
        "polygons": sum(len(doc["polygons"]) for doc in geometry_out.values()),
        "rings": sum(len(polygon) for doc in geometry_out.values() for polygon in doc["polygons"]),
        "dropped_rings": sum(int(tree["geometry"][i].get("dropped_rings", 0)) for i in ids),
        "repaired_rings": sum(int(tree["geometry"][i].get("repaired_rings", 0)) for i in ids),
        "repaired_vertices": sum(int(tree["geometry"][i].get("repaired_vertices", 0)) for i in ids),
        "capital_points": sum(1 for record in records if record.get("capital_point")),
        "vertices": sum(len(ring) // 2 for doc in geometry_out.values()
                        for polygon in doc["polygons"] for ring in polygon),
    }

    repairs: list[dict] = []
    for country_id in sorted(ids):
        for repair in tree["geometry"][country_id].get("repairs", []):
            repairs.append({"id": country_id, **{key: repair[key] for key in
                                                 ("ring", "removed_vertices", "area_before",
                                                  "area_after")}})

    first_source = tree["sources"][ids[0]]
    source_block = {
        "dataset": first_source["dataset"],
        "repository": first_source["repository"],
        "commit": first_source["commit"],
        "version": first_source["version"],
        "licence": first_source["licence"],
        "url": first_source["url"],
        "capital_url": first_source.get("capital_url"),
        "retrieved": first_source["retrieved"],
    }

    countries_text = json.dumps({"schema": folders.PACK_SCHEMA, "countries": records},
                                ensure_ascii=False, separators=(",", ":")) + "\n"
    geometry_text = json.dumps({"schema": folders.PACK_SCHEMA, "scale": SCALE,
                                "countries": geometry_out},
                               separators=(",", ":")) + "\n"

    statistics_documents = {country_id: tree["statistics"][country_id]
                            for country_id in ids if tree["statistics"].get(country_id)}
    statistics_text = ""
    statistics_block = None
    if statistics_documents:
        statistics_pack, statistics_counts = build_statistics.pack_from_folder_documents(
            statistics_documents)
        statistics_text = json.dumps(statistics_pack, ensure_ascii=False, indent=2) + "\n"
        statistics_block = {
            "file": "statistics.json",
            "schema": statistics_pack["schema"],
            "source_id": statistics_pack["source"]["id"],
            "source_version": statistics_pack["source"]["version"],
            "retrieved": statistics_pack["source"]["retrieved"],
            "notice": statistics_pack["notice"],
            "records_with_data": statistics_counts["records_with_data"],
            "population": statistics_counts["population"],
            "gdp_usd": statistics_counts["gdp_usd"],
            "area_km2": statistics_counts["area_km2"],
            "sha256": folders.sha256_text(statistics_text),
            "report": "docs/STATISTICS_REPORT.md",
            "builder": "tools/build_statistics.py",
        }

    manifest = {
        "schema": folders.PACK_SCHEMA,
        "generated": build_date,
        "source": source_block,
        "processing": {
            "scale": SCALE,
            "min_ring_area_deg2": MIN_RING_AREA_DEG2,
            "steps": PROCESSING_STEPS,
        },
        "counts": counts,
        "repairs": repairs,
        "known_limitations": KNOWN_LIMITATIONS,
        "folders": {
            "layout": "countries/<STABLE_ID>/",
            "count": len(ids),
            "required_files": list(folders.REQUIRED_FILES),
            "optional_files": list(folders.OPTIONAL_FILES),
            "guide": "docs/COUNTRY_FOLDER_GUIDE.md",
            "validator": "tools/validate_country_folders.py",
        },
        "statistics": statistics_block,
        "pack": {
            "built_from": "countries/",
            "records": len(records),
            "countries_sha256": folders.sha256_text(countries_text),
            "geometry_sha256": folders.sha256_text(geometry_text),
            "builder": "tools/build_country_pack.py",
        },
    }
    manifest_text = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    documents = {
        "countries.json": countries_text,
        "geometry.json": geometry_text,
        "manifest.json": manifest_text,
        "counts": counts,
    }
    if statistics_text:
        documents["statistics.json"] = statistics_text
    return documents


def write_pack(documents: dict, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    for name, text in documents.items():
        if not name.endswith(".json"):
            continue
        with open(os.path.join(out_dir, name), "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)


def check_pack(documents: dict, out_dir: str) -> int:
    """Compare the rebuilt pack with what is committed. 0 = identical."""
    problems = 0
    for name in ("countries.json", "geometry.json", "manifest.json", "statistics.json"):
        path = os.path.join(out_dir, name)
        try:
            with open(path, encoding="utf-8") as handle:
                committed = handle.read()
        except OSError as error:
            print(f"missing pack file: {path} ({error})")
            problems += 1
            continue
        wanted = documents[name]
        committed_hash = folders.sha256_text(committed)
        rebuilt_hash = folders.sha256_text(wanted)
        same = committed == wanted
        print(f"{name:16} committed {committed_hash[:16]} rebuilt {rebuilt_hash[:16]} "
              f"{'identical' if same else 'DIFFERENT'}")
        if not same:
            problems += 1
            for index, (a, b) in enumerate(zip(committed.splitlines(), wanted.splitlines())):
                if a != b:
                    print(f"  first difference on line {index + 1}:")
                    print(f"    committed: {a[:160]}")
                    print(f"    rebuilt  : {b[:160]}")
                    break
    return problems


def main(argv: list[str]) -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folders", default=os.path.join(root, "data/world/countries"))
    parser.add_argument("--out", default=os.path.join(root, "data/world"))
    parser.add_argument("--generated", default=None,
                        help="build date recorded in the manifest (default: the date in the folders)")
    parser.add_argument("--check", action="store_true",
                        help="fail if the committed pack does not match the folders")
    args = parser.parse_args(argv)

    try:
        documents = build_documents(args.folders, args.generated)
    except ValueError as error:
        print(f"pack build failed: {error}")
        return 1
    counts = documents["counts"]
    print(f"folders={counts['countries']} polygons={counts['polygons']} "
          f"vertices={counts['vertices']} capitals={counts['capital_points']}")
    if args.check:
        problems = check_pack(documents, args.out)
        if problems:
            print(f"pack is stale: {problems} file(s) differ from the folders")
            print("run: python3 tools/build_country_pack.py")
            return 1
        print("pack matches the folders")
        return 0
    write_pack(documents, args.out)
    print(f"wrote the pack to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
